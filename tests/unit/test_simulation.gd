extends GutTest

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(5)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	state.station("general_services/review").staff = 1
	_stop_arrivals()


func _stop_arrivals() -> void:
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9


func _case(dept_id: String = "general_services", complex: bool = false, urgent: bool = false) -> CaseFile:
	var case_file := CaseFile.new(dept_id, complex, urgent)
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func _at(key: String, case_file: CaseFile) -> CaseFile:
	case_file.step = case_file.route.find(key)
	return case_file


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func test_tick_counts_play_time() -> void:
	sim.tick(0.5)
	assert_almost_eq(state.play_time, 0.5, 0.0001)


func test_events_start_and_end() -> void:
	watch_signals(sim)
	assert_true(sim.eligible_events().is_empty())
	state.cases_completed = 20
	assert_eq(sim.eligible_events(), ["printer_jam"] as Array[String])
	state.event_cooldown = 0.0
	sim.tick(0.1)
	assert_eq(state.event_id, "printer_jam")
	assert_signal_emitted_with_parameters(sim, "event_started", ["printer_jam"])
	state.event_time_left = 0.05
	sim.tick(0.1)
	assert_eq(state.event_id, "")
	assert_signal_emitted_with_parameters(sim, "event_ended", ["printer_jam"])
	assert_between(state.event_cooldown, GameConfig.EVENT_MIN_COOLDOWN, GameConfig.EVENT_MAX_COOLDOWN)
	state.unlock_department("tax_services")
	state.cases_completed = 100
	var events := sim.eligible_events()
	for event_id in ["audit_visit", "printer_jam", "fire_drill"]:
		assert_true(events.has(event_id), event_id)
	assert_false(events.has("renovation"))


func test_citizens_arrive_on_schedule() -> void:
	watch_signals(sim)
	var dept := state.department("general_services")
	dept.arrival_timer = Formulas.arrival_interval(state) - 0.01
	sim.tick(0.02)
	assert_eq(state.citizens.size(), 1)
	assert_eq(state.ticket_line.size(), 1)
	assert_signal_emitted_with_parameters(sim, "case_arrived", ["general_services"])


func test_full_ticket_lines_turn_citizens_away() -> void:
	watch_signals(sim)
	var dept := state.department("general_services")
	for i in Formulas.ticket_line_capacity(state):
		assert_not_null(sim.spawn_case(dept))
	assert_null(sim.spawn_case(dept))
	assert_eq(state.citizens_lost, 1)
	assert_signal_emitted(sim, "citizen_left")


func test_impatient_cargo_leaves_the_dock() -> void:
	state.unlock_department("customs")
	var dock := state.station("customs/dock")
	var waiting := _case("customs")
	waiting.waited = GameConfig.BASE_PATIENCE
	dock.inbox.append(waiting)
	dock.inbox.append(_case("customs"))
	state.reputation = 5.0
	sim.tick(0.1)
	assert_eq(dock.inbox.size(), 1)
	assert_eq(state.citizens_lost, 1)
	assert_almost_eq(state.reputation, 5.0 + GameConfig.REP_CITIZEN_LEFT * GameConfig.REP_LOSS_FACTOR, 0.001)


func test_mayor_speech_keeps_cargo_waiting() -> void:
	state.unlock_department("customs")
	var dock := state.station("customs/dock")
	var waiting := _case("customs")
	waiting.waited = GameConfig.BASE_PATIENCE
	dock.inbox.append(waiting)
	state.boosts["mayor_speech"] = 10.0
	sim.tick(0.1)
	assert_true(dock.inbox.has(waiting))


func test_cases_age_everywhere() -> void:
	var queued := _case()
	var carried := _case()
	state.station("general_services/review").outbox.append(queued)
	state.player.items.append(carried)
	sim.tick(0.5)
	assert_almost_eq(queued.age, 0.5, 0.001)
	assert_almost_eq(carried.age, 0.5, 0.001)


func test_create_case_variants() -> void:
	state.unlock_department("customs")
	var cargo := sim.create_case(state.department("customs"))
	assert_true(GameConfig.CUSTOMS_VARIANTS.has(cargo.variant))
	assert_eq(cargo.route[0], "customs/dock")
	var follow_up := sim.create_case(state.department("general_services"), true)
	assert_true(follow_up.follow_up)
	assert_false(follow_up.complex)
	assert_eq(follow_up.route.size(), 3)
	var spawned := sim.spawn_case(state.department("customs"))
	assert_true(state.station("customs/dock").inbox.has(spawned))


func test_staffed_desk_processes_case() -> void:
	var review := state.station("general_services/review")
	review.inbox.append(_at("general_services/review", _case()))
	_run(6.0)
	assert_eq(review.outbox.size(), 1)
	assert_eq(review.active_jobs(), 0)


func test_unstaffed_desk_waits_for_player() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.inbox.append(_case())
	state.player.position = Vector2.ZERO
	_run(3.0)
	assert_eq(reception.outbox.size(), 0)
	assert_true(reception.needs_manual_work())
	state.player.position = layout.desk_work_point(GameConfig.RECEPTION, 0)
	_run(2.5)
	assert_eq(reception.outbox.size(), 1)
	assert_eq(reception.outbox[0].handled, 1)


func test_staff_work_does_not_count_as_hand_work() -> void:
	var review := state.station("general_services/review")
	review.inbox.append(_at("general_services/review", _case()))
	state.player.position = Vector2.ZERO
	_run(6.0)
	assert_eq(review.outbox.size(), 1)
	assert_eq(review.outbox[0].handled, 0)


func test_hand_made_case_pays_more() -> void:
	var counter := state.station(GameConfig.COUNTER)
	var manual := _at(GameConfig.COUNTER, _case())
	manual.handled = Formulas.hand_slots(manual) - 1
	counter.inbox.append(manual)
	state.player.position = layout.desk_work_point(GameConfig.COUNTER, 0)
	state.reputation = 0.0
	var money := state.money
	_run(3.0)
	assert_eq(state.cases_completed, 1)
	assert_eq(manual.handled, Formulas.hand_slots(manual))
	assert_almost_eq(state.money - money, 20.0 * (1.0 + GameConfig.HAND_REWARD_BONUS), 0.01)


func test_player_helps_at_a_staffed_desk() -> void:
	var review := state.station("general_services/review")
	var case_file := _at("general_services/review", _case())
	review.inbox.append(case_file)
	state.player.position = layout.desk_work_point("general_services/review", 0)
	_run(2.0)
	assert_eq(review.outbox.size(), 1)
	assert_eq(case_file.handled, 1)


func test_machines_are_not_helped_by_hand() -> void:
	state.unlock_department("tax_services")
	var signature := state.station("tax_services/signature")
	assert_true(signature.machine)
	signature.inbox.append(_at("tax_services/signature", _case("tax_services")))
	signature.staff = signature.desks
	state.player.position = layout.desk_work_point("tax_services/signature", 0)
	assert_false(sim.can_work_desk(signature, 0))
	assert_false(sim.work_at_desk(1.0))
	assert_true(signature.inbox.size() == 1)


func test_guidance_sends_player_to_help_with_a_backlog() -> void:
	var review := state.station("general_services/review")
	state.player.position = layout.desk_work_point("general_services/review", 0)
	review.inbox.append(_at("general_services/review", _case()))
	assert_ne(str(Guidance.next_task(state).get("action", "")), Guidance.WORK)
	for i in GameConfig.HELP_BACKLOG - 1:
		review.inbox.append(_at("general_services/review", _case()))
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WORK)
	assert_eq(task.key, "general_services/review")
	assert_eq(task.point, layout.desk_work_point("general_services/review", 0))


func test_player_works_only_at_the_desk_they_stand_at() -> void:
	var review := state.station("general_services/review")
	review.add_desk()
	review.inbox.append(_at("general_services/review", _case()))
	state.player.position = Vector2.ZERO
	assert_true(sim.player_desk().is_empty())
	assert_false(sim.work_at_desk(1.0))
	state.player.position = layout.desk_work_point("general_services/review", 1)
	assert_eq(sim.player_desk(), ["general_services/review", 1])
	assert_true(sim.work_at_desk(1.0))
	assert_not_null(review.jobs[1])
	assert_null(review.jobs[0])


func test_player_looks_over_the_shoulder_of_a_working_official() -> void:
	var review := state.station("general_services/review")
	review.inbox.append(_at("general_services/review", _case()))
	state.player.position = layout.desk_work_point("general_services/review", 0)
	assert_eq(sim.player_desk(), ["general_services/review", 0])
	assert_true(sim.work_at_desk(1.0))
	assert_not_null(review.jobs[0])
	review.moods[0].rest(DeskMood.ASLEEP)
	assert_true(sim.can_work_desk(review, 0))
	assert_eq(sim.player_desk(), ["general_services/review", 0])


func test_player_can_work_every_desk_state() -> void:
	var review := state.station("general_services/review")
	review.inbox.append(_at("general_services/review", _case()))
	state.player.position = layout.desk_work_point("general_services/review", 0)
	assert_true(sim.can_work_desk(review, 0))
	review.staff = review.desks
	for rest_state in [DeskMood.ASLEEP, DeskMood.COFFEE, DeskMood.LUNCH, DeskMood.CHAT]:
		review.moods[0].rest(rest_state)
		assert_true(sim.can_work_desk(review, 0), str(rest_state))
		assert_eq(sim.player_desk(), ["general_services/review", 0], str(rest_state))
	assert_true(sim.work_at_desk(1.0))
	assert_not_null(review.jobs[0])


func test_player_can_work_the_photo_desk() -> void:
	var photo := state.station(GameConfig.PHOTO_STATION)
	assert_false(photo.machine)
	state.player.position = layout.desk_work_point(GameConfig.PHOTO_STATION, 0)
	assert_true(sim.can_work_desk(photo, 0))
	photo.staff = photo.desks
	photo.moods[0].rest(DeskMood.COFFEE)
	assert_true(sim.can_work_desk(photo, 0))
	assert_eq(sim.player_desk(), [GameConfig.PHOTO_STATION, 0])


func test_the_room_floor_is_no_work_field() -> void:
	var review := state.station("general_services/review")
	review.add_desk()
	review.inbox.append(_at("general_services/review", _case()))
	var area := layout.area("general_services/review")
	state.player.position = Vector2(area.get_center().x, area.end.y - 10.0)
	assert_true(sim.player_desk().is_empty())
	assert_false(sim.can_work_desk(review, -1))
	assert_false(sim.can_work_desk(review, review.desks))


func test_start_job_rules() -> void:
	var review := state.station("general_services/review")
	assert_false(sim.start_job(review, 0))
	review.inbox.append(_at("general_services/review", _case()))
	assert_true(sim.start_job(review, 0))
	review.inbox.append(_at("general_services/review", _case()))
	assert_false(sim.start_job(review, 0))
	assert_false(sim.finish_job(review, 0))


func test_regular_desks_take_complex_cases() -> void:
	var review := state.station("general_services/review")
	var complex := _at("general_services/review", _case("general_services", true))
	review.inbox.append(complex)
	sim.tick(0.01)
	assert_eq(review.jobs.size(), 1)
	assert_eq(review.jobs[0].case_file, complex)
	assert_almost_eq(review.jobs[0].required, Formulas.required_time(state, review, complex), 0.0001)


func test_reception_calls_by_ticket_number_not_urgency() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	var normal := _case()
	normal.phase = CaseFile.Phase.WAITING
	normal.ticket = 1
	normal.place = 0
	var urgent := _case("general_services", false, true)
	urgent.phase = CaseFile.Phase.WAITING
	urgent.ticket = 2
	urgent.place = 1
	state.citizens.append_array([urgent, normal])
	assert_true(sim.call_citizens())
	assert_eq(sim.desk_call(reception, 0), normal)
	assert_eq(urgent.phase, CaseFile.Phase.WAITING)


func test_full_outbox_blocks_finished_job() -> void:
	var review := state.station("general_services/review")
	for i in review.outbox_capacity():
		review.outbox.append(_at("general_services/review", _case()))
	var job := StationJob.new(_at("general_services/review", _case()), 1.0)
	job.progress = 1.0
	review.jobs[0] = job
	assert_false(sim.finish_job(review, 0))
	assert_eq(review.jobs[0], job)
	review.outbox.pop_back()
	assert_true(sim.finish_job(review, 0))
	assert_false(review.outbox[-1].produced)


func test_counter_completes_case_and_pays() -> void:
	watch_signals(sim)
	var counter := state.station(GameConfig.COUNTER)
	var job := StationJob.new(_at(GameConfig.COUNTER, _case()), 1.0)
	job.progress = 1.0
	counter.jobs[0] = job
	var money := state.money
	assert_true(sim.finish_job(counter, 0))
	assert_eq(state.cases_completed, 1)
	assert_gt(state.money, money)
	assert_signal_emitted(sim, "case_completed")


func test_signature_marks_result_produced() -> void:
	var case_file := _at("general_services/signature", _case())
	sim.apply_station_effect(state.station("general_services/signature"), case_file)
	assert_true(case_file.produced)


func test_review_sets_errors_by_chance() -> void:
	var review := state.station("general_services/review")
	state.department("general_services").thoroughness = 0
	var flawed := 0
	for i in 200:
		var case_file := _at("general_services/review", _case())
		sim.apply_station_effect(review, case_file)
		flawed += int(case_file.flawed)
	assert_between(flawed, 20, 120)


func test_referral_station_does_not_review_foreign_cases() -> void:
	state.unlock_department("housing")
	state.department("housing").thoroughness = 0
	for i in 50:
		var case_file := _at("general_services/review", _case("housing"))
		sim.apply_station_effect(state.station("general_services/review"), case_file)
		assert_false(case_file.flawed)


func test_customs_fast_lane_skips_scanner() -> void:
	state.unlock_department("customs")
	var review := state.station("customs/review")
	var clean := _at("customs/review", _case("customs"))
	sim.apply_station_effect(review, clean)
	assert_false(clean.flagged)
	assert_eq(clean.next_key(), "customs/clearance")
	state.department("customs").scan_all = true
	var scanned := _at("customs/review", _case("customs"))
	sim.apply_station_effect(review, scanned)
	assert_eq(scanned.next_key(), "customs/signature")


func test_customs_flags_suspicious_cargo_and_scanner_finds_contraband() -> void:
	watch_signals(sim)
	state.unlock_department("customs")
	var review := state.station("customs/review")
	var scanner := state.station("customs/signature")
	var flagged := 0
	var seized := 0
	for i in 60:
		var cargo := _at("customs/review", _case("customs"))
		cargo.suspicious = true
		sim.apply_station_effect(review, cargo)
		if not cargo.flagged:
			continue
		flagged += 1
		cargo.step += 1
		sim.apply_station_effect(scanner, cargo)
		assert_true(cargo.scanned)
		if cargo.contraband:
			seized += 1
			assert_eq(cargo.next_key(), GameConfig.INSPECTION)
	assert_gt(flagged, 20)
	assert_lt(flagged, 55)
	assert_gt(seized, 5)
	assert_signal_emitted(sim, "contraband_found")


func test_completing_contraband_and_smuggling() -> void:
	watch_signals(sim)
	state.unlock_department("customs")
	var seized := _case("customs")
	seized.contraband = true
	sim.complete_case(seized)
	assert_eq(state.contraband_seized, 1)
	for i in 40:
		var cargo := _case("customs")
		cargo.suspicious = true
		sim.complete_case(cargo)
	assert_signal_emitted(sim, "smuggling_missed")


func test_flawed_completion_is_counted() -> void:
	var flawed := _case()
	flawed.flawed = true
	sim.complete_case(flawed)
	assert_eq(state.cases_flawed, 1)


func test_social_benefits_schedule_follow_ups() -> void:
	state.unlock_department("social_benefits")
	var dept := state.department("social_benefits")
	sim.complete_case(_case("social_benefits"))
	assert_eq(dept.follow_ups.size(), 1)
	assert_between(dept.follow_ups[0], GameConfig.FOLLOW_UP_DELAY_MIN, GameConfig.FOLLOW_UP_DELAY_MAX)
	var review_case := _case("social_benefits")
	review_case.follow_up = true
	sim.complete_case(review_case)
	assert_eq(dept.follow_ups.size(), 1)
	dept.follow_ups[0] = 0.01
	sim.tick(0.05)
	assert_eq(dept.follow_ups, [0.0] as Array[float])
	assert_true(state.ticket_line.is_empty())
	dept.arrival_timer = Formulas.arrival_interval(state)
	sim.tick(0.01)
	assert_true(dept.follow_ups.is_empty())
	assert_eq(state.ticket_line.size(), 1)
	assert_true(state.ticket_line[0].follow_up)


func test_move_case_respects_target_space() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	var review := state.station("general_services/review")
	reception.outbox.append(_case())
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(_at("general_services/review", _case()))
	assert_false(sim.move_case(reception, 0))
	review.inbox.clear()
	assert_true(sim.move_case(reception, 0))
	assert_eq(review.inbox[0].step, 1)
	var finished := _at(GameConfig.COUNTER, _case())
	reception.outbox.append(finished)
	assert_false(sim.move_case(reception, 0))


func test_player_moves_within_world() -> void:
	state.player.position = layout.player_start()
	state.player.input = Vector2(1, 0)
	sim.tick(0.5)
	assert_almost_eq(state.player.position.x, layout.player_start().x + GameConfig.PLAYER_SPEED * 0.5, 0.01)
	state.player.input = Vector2(0, 50)
	sim.tick(100.0)
	assert_eq(state.player.position.y, layout.size.y - WorldLayout.MARGIN)


func test_player_picks_up_and_drops_files() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	var review := state.station("general_services/review")
	review.staff = 0
	var case_file := _case()
	reception.outbox.append(case_file)
	state.player.position = layout.output_point(GameConfig.RECEPTION)
	assert_true(sim.player_transfer())
	assert_eq(state.player.items, [case_file] as Array[CaseFile])
	assert_false(sim.player_transfer())
	state.player.position = layout.input_point("general_services/review")
	assert_true(sim.player_transfer())
	assert_true(state.player.items.is_empty())
	assert_eq(review.inbox, [case_file] as Array[CaseFile])
	assert_eq(case_file.handled, 1)


func test_player_hands_full_and_target_full() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	for i in Formulas.carry_capacity(state) + 2:
		reception.outbox.append(_case())
	state.player.position = layout.output_point(GameConfig.RECEPTION)
	_run(2.0)
	assert_eq(state.player.items.size(), Formulas.carry_capacity(state))
	assert_eq(reception.outbox.size(), 2)
	var review := state.station("general_services/review")
	review.staff = 0
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(_at("general_services/review", _case()))
	state.player.position = layout.input_point("general_services/review")
	assert_false(sim.player_transfer())


func test_player_opens_department_on_pad() -> void:
	watch_signals(sim)
	state.building_stage = 1
	state.reputation = 20.0
	state.money = 1000.0
	state.player.position = layout.pad_point("tax_services")
	_run(GameConfig.PAD_TIME * 0.5)
	assert_eq(state.player.pad_dept, "tax_services")
	assert_false(state.department("tax_services").unlocked)
	_run(GameConfig.PAD_TIME)
	assert_true(state.department("tax_services").unlocked)
	assert_almost_eq(state.money, 200.0, 50.0)
	assert_signal_emitted_with_parameters(sim, "department_unlocked", ["tax_services"])
	assert_eq(state.player.pad_dept, "")


func test_pad_requires_unlock_conditions() -> void:
	state.player.position = layout.pad_point("tax_services")
	_run(GameConfig.PAD_TIME * 2.0)
	assert_false(state.department("tax_services").unlocked)
	assert_eq(state.player.pad_progress, 0.0)
	assert_false(sim.unlock("tax_services"))


func test_runner_carries_files_between_stations() -> void:
	var runner := state.add_runner()
	var reception := state.station(GameConfig.RECEPTION)
	var review := state.station("general_services/review")
	review.staff = 0
	reception.outbox.append(_case())
	reception.outbox.append(_case())
	_run(20.0)
	assert_eq(review.inbox.size(), 2)
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_true(runner.items.is_empty())


func test_runners_reserve_files() -> void:
	var first := state.add_runner()
	var second := state.add_runner()
	state.station(GameConfig.RECEPTION).outbox.append(_case())
	assert_true(sim.assign_runner(first))
	assert_eq(first.reserved, 1)
	assert_eq(sim.reserved_for(GameConfig.RECEPTION, "general_services/review"), 1)
	assert_false(sim.assign_runner(second))


func test_runner_waits_when_target_is_full() -> void:
	var runner := state.add_runner()
	var review := state.station("general_services/review")
	review.staff = 0
	for i in review.inbox_capacity(state.lobby_capacity()) - 1:
		review.inbox.append(_at("general_services/review", _case()))
	runner.items.append_array([_case(), _case()])
	runner.task = Runner.Task.TO_TARGET
	runner.target = "general_services/review"
	runner.position = layout.input_point("general_services/review")
	sim.tick(0.05)
	assert_eq(runner.items.size(), 1)
	assert_eq(runner.task, Runner.Task.TO_TARGET)


func test_runner_gives_up_when_source_is_empty() -> void:
	var runner := state.add_runner()
	runner.task = Runner.Task.TO_SOURCE
	runner.source = GameConfig.RECEPTION
	runner.target = "general_services/review"
	runner.reserved = 1
	runner.position = layout.output_point(GameConfig.RECEPTION)
	sim.tick(0.05)
	assert_eq(runner.task, Runner.Task.IDLE)


func test_idle_runner_rests_in_the_lounge_only_without_any_work() -> void:
	var runner := state.add_runner()
	runner.position = Vector2(100, 100)
	assert_eq(sim.runner_standby(runner), "")
	_run(60.0)
	assert_lt(runner.position.distance_to(layout.runner_rest_point(0)), 1.0)
	assert_true(layout.runner_lounge().has_point(runner.position))
	var second := state.add_runner()
	second.position = Vector2(100, 100)
	_run(60.0)
	assert_lt(second.position.distance_to(layout.runner_rest_point(1)), 1.0)


func test_idle_runner_keeps_moving_next_to_upcoming_work() -> void:
	var runner := state.add_runner()
	runner.role = Runner.INTAKE
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 0
	reception.inbox.append(_case())
	assert_eq(sim.runner_standby(runner), GameConfig.RECEPTION)
	runner.position = layout.output_point(GameConfig.RECEPTION)
	_run(3.0)
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_false(layout.runner_lounge().has_point(runner.position))
	assert_lt(runner.position.distance_to(layout.output_point(GameConfig.RECEPTION)), GameConfig.RUNNER_PACE_DISTANCE * 2.0)
	var before := runner.position
	_run(GameConfig.RUNNER_PACE_SECONDS * 0.25)
	assert_ne(runner.position, before)
	runner.role = Runner.OUTPUT
	assert_eq(sim.runner_standby(runner), "")


func test_runner_standby_prefers_the_busiest_then_the_nearest_station() -> void:
	state.unlock_department("tax_services")
	var runner := state.add_runner()
	runner.role = Runner.INTERNAL
	var general := state.station("general_services/review")
	var tax := state.station("tax_services/review")
	general.staff = 0
	tax.staff = 0
	general.inbox.append(_at(general.key, _case()))
	tax.inbox.append(_at(tax.key, _case("tax_services")))
	tax.inbox.append(_at(tax.key, _case("tax_services")))
	runner.position = layout.output_point(general.key)
	assert_eq(sim.runner_standby(runner), tax.key)
	tax.inbox.pop_back()
	assert_eq(sim.runner_standby(runner), general.key)
	runner.position = layout.output_point(tax.key)
	assert_eq(sim.runner_standby(runner), tax.key)
	tax.inbox.clear()
	tax.jobs[0] = StationJob.new(_at(tax.key, _case("tax_services")), 5.0)
	assert_eq(sim.runner_standby(runner), tax.key)


func test_runner_idle_point_paces_near_the_standby_station() -> void:
	assert_eq(sim.runner_idle_point(3, ""), layout.runner_rest_point(3))
	var output := layout.output_point(GameConfig.RECEPTION)
	for time in [0.0, 0.4, 0.8, 1.2]:
		state.play_time = time
		var point := sim.runner_idle_point(0, GameConfig.RECEPTION)
		assert_lt(point.distance_to(output), GameConfig.RUNNER_PACE_DISTANCE * 1.6, str(time))
	state.play_time = 0.0
	var start := sim.runner_idle_point(0, GameConfig.RECEPTION)
	state.play_time = GameConfig.RUNNER_PACE_SECONDS * 0.25
	assert_ne(sim.runner_idle_point(0, GameConfig.RECEPTION), start)
	assert_ne(sim.runner_idle_point(1, GameConfig.RECEPTION), sim.runner_idle_point(0, GameConfig.RECEPTION))


func test_pneumatic_tubes_route_files_through_tubes() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	var runner := state.add_runner()
	runner.items.append(_case())
	runner.target = "general_services/review"
	runner.task = Runner.Task.TO_TARGET
	var idle := state.add_runner()
	idle.task = Runner.Task.TO_SOURCE
	state.station("general_services/review").staff = 0
	state.station(GameConfig.RECEPTION).outbox.append(_case())
	sim.tick(0.05)
	assert_eq(state.station("general_services/review").inbox.size(), 0)
	assert_eq(state.tube_parcels.size(), 1)
	assert_eq(idle.task, Runner.Task.IDLE)
	_run(20.0)
	assert_eq(state.station("general_services/review").inbox.size(), 2)
	assert_true(state.tube_parcels.is_empty())
	assert_true(runner.items.is_empty())


func test_full_loop_earns_money_with_staff() -> void:
	for key in state.stations:
		var station := state.stations[key]
		if not station.machine:
			station.staff = 1
	for role in Runner.CASE_ROLES:
		state.add_runner(role)
	_quiet_disruptions()
	state.department("general_services").arrival_timer = 0.0
	_run(180.0, 0.1)
	assert_gt(state.cases_completed, 5)
	assert_gt(state.money, GameConfig.START_MONEY)

func _quiet_disruptions() -> void:
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.complaint_letter_timer = 1e6
	state.dispute_timer = 1e6
	state.event_cooldown = 1e9
	for key in state.stations:
		for mood in state.stations[key].moods:
			mood.alert = 1e9
