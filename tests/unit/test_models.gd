extends GutTest


func _case(dept_id: String = "general_services", complex: bool = false, urgent: bool = false) -> CaseFile:
	var case_file := CaseFile.new(dept_id, complex, urgent)
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func test_case_file_route_navigation() -> void:
	var case_file := _case()
	assert_eq(case_file.current_key(), GameConfig.RECEPTION)
	assert_eq(case_file.next_key(), "general_services/review")
	assert_false(case_file.is_final_step())
	case_file.step = case_file.route.size() - 1
	assert_eq(case_file.current_key(), GameConfig.COUNTER)
	assert_eq(case_file.next_key(), "")
	assert_true(case_file.is_final_step())
	case_file.step = case_file.route.size()
	assert_eq(case_file.current_key(), "")


func test_case_file_overdue_only_when_urgent() -> void:
	var normal := _case()
	normal.age = GameConfig.URGENT_DEADLINE + 1.0
	assert_false(normal.is_overdue())
	var urgent := _case("general_services", false, true)
	urgent.age = GameConfig.URGENT_DEADLINE - 1.0
	assert_false(urgent.is_overdue())
	urgent.age = GameConfig.URGENT_DEADLINE + 1.0
	assert_true(urgent.is_overdue())


func test_case_file_route_edits_only_affect_future_steps() -> void:
	var case_file := _case("customs")
	assert_eq(case_file.route, ["customs/dock", "customs/review", "customs/signature", "customs/clearance"] as Array[String])
	case_file.step = 1
	case_file.remove_from_route("customs/dock")
	assert_eq(case_file.route.size(), 4)
	case_file.remove_from_route("customs/signature")
	assert_eq(case_file.next_key(), "customs/clearance")
	case_file.insert_before(GameConfig.INSPECTION, "customs/clearance")
	assert_eq(case_file.next_key(), GameConfig.INSPECTION)
	case_file.insert_before(GameConfig.INSPECTION, "customs/clearance")
	assert_eq(case_file.route.count(GameConfig.INSPECTION), 1)
	case_file.insert_before("x", "missing")
	assert_false(case_file.route.has("x"))


func test_case_file_roundtrip_and_clamping() -> void:
	var case_file := _case("customs", true, true)
	case_file.suspicious = true
	case_file.variant = "electronics"
	case_file.follow_up = true
	case_file.step = 2
	case_file.flawed = true
	case_file.flagged = true
	case_file.scanned = true
	case_file.contraband = true
	case_file.produced = true
	case_file.age = 12.5
	case_file.waited = 3.0
	var copy := CaseFile.from_dict(case_file.to_dict())
	assert_eq(copy.to_dict(), case_file.to_dict())
	var data := case_file.to_dict()
	data.step = 99
	assert_eq(CaseFile.from_dict(data).step, 3)
	var empty := CaseFile.from_dict({})
	assert_eq(empty.dept_id, "")
	assert_eq(empty.step, 0)
	assert_true(empty.route.is_empty())


func test_station_job_progress() -> void:
	var job := StationJob.new(_case(), 2.0, true)
	assert_false(job.is_done())
	job.progress = 1.0
	assert_almost_eq(job.ratio(), 0.5, 0.001)
	job.progress = 5.0
	assert_true(job.is_done())
	assert_eq(job.ratio(), 1.0)
	var copy := StationJob.from_dict(job.to_dict())
	assert_eq(copy.required, 2.0)
	assert_eq(copy.progress, 5.0)
	assert_true(copy.by_specialist)
	assert_eq(StationJob.new(null, 0.0).required, 0.01)


func test_station_derives_kind_and_machine() -> void:
	var review := Station.new("general_services/review")
	assert_eq(review.kind, "review")
	assert_eq(review.dept_id, "general_services")
	assert_false(review.machine)
	assert_eq(review.staff, 0)
	assert_true(review.supports_specialists())
	var printer := Station.new("vehicle_registration/signature")
	assert_true(printer.machine)
	assert_eq(printer.staff, 1)
	assert_false(Station.new("building_permits/signature").machine)
	var reception := Station.new(GameConfig.RECEPTION)
	assert_true(reception.is_shared())
	assert_true(reception.is_entry())
	assert_false(reception.is_final())
	assert_true(Station.new(GameConfig.COUNTER).is_final())
	assert_true(Station.new("customs/dock").is_entry())
	assert_true(Station.new("customs/clearance").is_final())
	assert_eq(Station.new(GameConfig.INSPECTION).kind, "inspection")


func test_station_capacities() -> void:
	var station := Station.new("general_services/review")
	assert_eq(station.inbox_capacity(10), GameConfig.INBOX_BASE + GameConfig.INBOX_PER_DESK)
	assert_eq(station.outbox_capacity(), GameConfig.OUTBOX_BASE + GameConfig.OUTBOX_PER_DESK)
	assert_eq(Station.new(GameConfig.RECEPTION).inbox_capacity(10), 10)
	for i in station.outbox_capacity():
		station.outbox.append(_case())
	assert_false(station.has_outbox_space())
	assert_true(station.has_inbox_space(10))


func test_station_desks_and_specialists() -> void:
	var station := Station.new("general_services/review")
	station.add_specialist()
	station.add_desk()
	assert_eq(station.desks, 2)
	assert_eq(station.jobs.size(), 3)
	assert_false(station.is_specialist_desk(1))
	assert_true(station.is_specialist_desk(2))
	assert_true(station.is_staffed(2))
	assert_false(station.is_staffed(0))
	station.staff = 1
	assert_true(station.is_staffed(0))
	assert_eq(station.workers(), 2)
	var machine := Station.new("general_services/signature")
	machine.add_desk()
	assert_eq(machine.staff, 2)


func test_station_manual_work_detection() -> void:
	var station := Station.new("general_services/review")
	assert_false(station.needs_manual_work())
	station.inbox.append(_case())
	assert_true(station.needs_manual_work())
	station.inbox.clear()
	station.jobs[0] = StationJob.new(_case())
	assert_true(station.unstaffed_desks_busy())
	assert_true(station.needs_manual_work())
	assert_eq(station.active_jobs(), 1)
	station.staff = 1
	assert_false(station.needs_manual_work())
	assert_false(station.unstaffed_desks_busy())


func test_station_case_selection() -> void:
	var station := Station.new("general_services/review")
	var simple := _case()
	var complex := _case("general_services", true)
	var urgent := _case("general_services", false, true)
	station.inbox.append_array([simple, complex, urgent])
	assert_eq(station.take_next_case(true, false), urgent)
	assert_eq(station.take_next_case(false, false), simple)
	assert_eq(station.take_next_case(false, false), complex)
	assert_null(station.take_next_case(false, false))
	station.add_specialist()
	station.inbox.append_array([complex, simple])
	assert_eq(station.take_next_case(false, false), simple)
	assert_null(station.take_next_case(false, false))
	station.inbox.append(simple)
	assert_eq(station.take_next_case(false, true), complex)
	assert_eq(station.take_next_case(false, true), simple)


func test_station_all_cases_and_roundtrip() -> void:
	var station := Station.new("general_services/review")
	station.add_specialist()
	station.staff = 1
	station.level = 4
	station.inbox.append(_case())
	station.outbox.append(_case())
	station.jobs[1] = StationJob.new(_case(), 3.0, true)
	assert_eq(station.all_cases().size(), 3)
	var copy := Station.from_dict(station.to_dict())
	assert_eq(copy.to_dict(), station.to_dict())
	var data := station.to_dict()
	data.desks = 0
	data.staff = 50
	data.level = 999
	data.specialists = 50
	data.jobs = ["broken"]
	var clamped := Station.from_dict(data)
	assert_eq(clamped.desks, 1)
	assert_eq(clamped.staff, 1)
	assert_eq(clamped.level, GameConfig.MAX_STATION_LEVEL)
	assert_eq(clamped.specialists, GameConfig.MAX_SPECIALISTS)
	assert_eq(clamped.jobs.size(), 1 + GameConfig.MAX_SPECIALISTS)
	assert_null(clamped.jobs[0])
	var machine_data := Station.new("general_services/signature").to_dict()
	machine_data.staff = 0
	machine_data.specialists = 2
	var machine := Station.from_dict(machine_data)
	assert_eq(machine.staff, 1)
	assert_eq(machine.specialists, 0)


func test_department_roundtrip() -> void:
	var dept := Department.new("customs")
	assert_true(dept.is_customs())
	assert_eq(dept.station_keys().size(), 4)
	assert_eq(dept.config().id, "customs")
	dept.unlocked = true
	dept.supervisors = 2
	dept.thoroughness = 2
	dept.prioritize_urgent = false
	dept.scan_all = true
	dept.arrival_timer = 1.5
	dept.follow_ups.append(30.0)
	assert_eq(Department.from_dict(dept.to_dict()).to_dict(), dept.to_dict())
	var data := dept.to_dict()
	data.supervisors = 99
	data.thoroughness = -3
	var clamped := Department.from_dict(data)
	assert_eq(clamped.supervisors, GameConfig.MAX_SUPERVISORS)
	assert_eq(clamped.thoroughness, 0)
	assert_false(Department.new("tax_services").is_customs())


func test_carrier_movement_and_matching() -> void:
	var carrier := Carrier.new(Vector2.ZERO)
	assert_false(carrier.move_towards(Vector2(100, 0), 10.0, 1.0))
	assert_eq(carrier.position, Vector2(10, 0))
	assert_true(carrier.move_towards(Vector2(15, 0), 10.0, 1.0))
	var case_file := _case()
	carrier.items.append(case_file)
	assert_eq(carrier.items_for("general_services/review"), [case_file] as Array[CaseFile])
	assert_true(carrier.items_for(GameConfig.COUNTER).is_empty())
	assert_eq(Carrier.items_from([case_file.to_dict(), "junk"]).size(), 1)


func test_player_roundtrip() -> void:
	var player := Player.new(Vector2(10, 20))
	player.items.append(_case())
	var copy := Player.from_dict(player.to_dict(), Vector2.ZERO)
	assert_eq(copy.position, Vector2(10, 20))
	assert_eq(copy.items.size(), 1)
	assert_eq(Player.from_dict({}, Vector2(5, 5)).position, Vector2(5, 5))


func test_runner_roundtrip_restores_delivery() -> void:
	var runner := Runner.new(Vector2(1, 2))
	assert_eq(runner.task, Runner.Task.IDLE)
	var idle := Runner.from_dict(runner.to_dict(), Vector2.ZERO)
	assert_eq(idle.task, Runner.Task.IDLE)
	var case_file := _case()
	runner.items.append(case_file)
	runner.target = "general_services/review"
	var busy := Runner.from_dict(runner.to_dict(), Vector2.ZERO)
	assert_eq(busy.task, Runner.Task.TO_TARGET)
	assert_eq(busy.target, "general_services/review")
	runner.task = Runner.Task.TO_SOURCE
	runner.source = "a"
	runner.reserved = 2
	runner.clear_task()
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_eq(runner.source, "")
	assert_eq(runner.reserved, 0)
