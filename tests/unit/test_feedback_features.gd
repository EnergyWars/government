extends GutTest


var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.5) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _unlock_all() -> void:
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)


func _case(dept_id: String, step: int = 0) -> CaseFile:
	var case_file := CaseFile.new(dept_id)
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = step
	return case_file


func test_goal_reward_does_not_count_as_income() -> void:
	var goals := GoalTracker.new(state)
	state.cases_completed = 3
	var earned := state.money_earned
	var money := state.money
	assert_true(goals.claim())
	assert_eq(state.money_earned, earned)
	assert_almost_eq(state.money, money + float(GameConfig.GOALS[0].money), 0.001)


func test_grant_adds_money_without_income() -> void:
	state.grant(50.0)
	assert_eq(state.money, GameConfig.START_MONEY + 50.0)
	assert_eq(state.money_earned, 0.0)


func test_documents_know_their_next_special_stations() -> void:
	var licence := _case("business_licences")
	assert_true(licence.needs_inspection())
	licence.step = licence.route.find(GameConfig.INSPECTION)
	assert_false(licence.needs_inspection())
	var housing := _case("housing")
	assert_true(housing.needs_referral())
	housing.step = housing.route.find("general_services/review")
	assert_false(housing.needs_referral())
	var plain := _case("general_services")
	assert_false(plain.needs_inspection())
	assert_false(plain.needs_referral())
	assert_false(CaseFile.new().needs_referral())


func test_case_file_roundtrip_keeps_new_flags() -> void:
	var case_file := _case("general_services")
	case_file.invalid = true
	case_file.big = true
	var loaded := CaseFile.from_dict(case_file.to_dict())
	assert_true(loaded.invalid)
	assert_true(loaded.big)
	var legacy := CaseFile.from_dict({"dept": "general_services"})
	assert_false(legacy.invalid)
	assert_false(legacy.big)


func test_full_boxes_report_side_and_station() -> void:
	var dept := state.department("general_services")
	assert_true(Formulas.full_boxes(state, dept).is_empty())
	var review := state.station("general_services/review")
	for i in review.outbox_capacity():
		review.outbox.append(CaseFile.new("general_services"))
	var boxes := Formulas.full_boxes(state, dept)
	assert_eq(boxes.size(), 1)
	assert_eq(boxes[0].key, "general_services/review")
	assert_eq(boxes[0].side, "out")
	var reception := state.station(GameConfig.RECEPTION)
	for i in state.lobby_capacity():
		reception.inbox.append(CaseFile.new("general_services"))
	review.rejects = GameConfig.REJECT_CAPACITY
	var sides: Array[String] = []
	for box in Formulas.full_boxes(state, dept):
		sides.append("%s:%s" % [box.key, box.side])
	assert_true(sides.has("shared/reception:in"))
	assert_true(sides.has("general_services/review:rejects"))
	assert_true(sides.has("general_services/review:out"))


func test_final_station_outbox_is_never_a_jam() -> void:
	var counter := state.station(GameConfig.COUNTER)
	for i in counter.outbox_capacity():
		counter.outbox.append(CaseFile.new("general_services"))
	assert_true(Formulas.full_boxes(state, state.department("general_services")).is_empty())


func test_population_follows_served_and_lost_citizens() -> void:
	assert_eq(Formulas.population(state), GameConfig.POPULATION_BASE)
	state.cases_completed = 100
	assert_eq(Formulas.population(state), GameConfig.POPULATION_BASE + 100 * GameConfig.POPULATION_PER_CASE)
	state.cases_completed = 0
	state.citizens_lost = 500
	assert_eq(Formulas.population(state), GameConfig.POPULATION_BASE)


func test_settlement_ranks_rise_with_population() -> void:
	assert_eq(Formulas.settlement(state), "village")
	var expectations := {500: "small_town", 3000: "town", 10000: "city", 60000: "metropolis"}
	for cases in expectations:
		state.cases_completed = cases
		assert_eq(Formulas.settlement(state), expectations[cases], str(cases))


func test_demand_no_longer_grows_with_success() -> void:
	var before := Formulas.arrival_interval(state)
	state.cases_completed = 5000
	assert_eq(Formulas.arrival_interval(state), before)


func test_invalid_cases_start_after_minimum_and_are_deterministic() -> void:
	assert_false(Formulas.is_invalid_case(state, 3))
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var hits := 0
	for serial in 2000:
		if Formulas.is_invalid_case(state, serial):
			hits += 1
	assert_between(hits, 100, 300)
	assert_eq(Formulas.is_invalid_case(state, 7), Formulas.is_invalid_case(state, 7))


func test_created_cases_count_serials_and_skip_follow_ups_and_customs() -> void:
	state.cases_completed = 1000
	_unlock_all()
	var general := state.department("general_services")
	var before := state.cases_spawned
	var invalid := 0
	for i in 400:
		if sim.create_case(general).invalid:
			invalid += 1
	assert_eq(state.cases_spawned, before + 400)
	assert_gt(invalid, 0)
	for i in 100:
		assert_false(sim.create_case(general, true).invalid)
		assert_false(sim.create_case(state.department("customs")).invalid)


func test_invalid_case_is_rejected_at_the_review() -> void:
	var review := state.station("general_services/review")
	var case_file := _case("general_services", 1)
	case_file.invalid = true
	var job := StationJob.new(case_file, 1.0)
	job.progress = 1.0
	review.jobs[0] = job
	watch_signals(sim)
	var money := state.money
	assert_true(sim.finish_job(review, 0))
	assert_eq(review.rejects, 1)
	assert_eq(state.cases_rejected, 1)
	assert_eq(state.cases_completed, 0)
	assert_true(review.outbox.is_empty())
	assert_null(review.jobs[0])
	assert_gt(state.money, money)
	assert_signal_emitted_with_parameters(sim, "case_rejected", ["general_services"])


func test_full_reject_pile_blocks_the_review() -> void:
	var review := state.station("general_services/review")
	review.rejects = GameConfig.REJECT_CAPACITY
	var case_file := _case("general_services", 1)
	case_file.invalid = true
	var job := StationJob.new(case_file, 1.0)
	job.progress = 1.0
	review.jobs[0] = job
	assert_false(sim.finish_job(review, 0))
	assert_eq(review.jobs[0], job)
	assert_eq(review.rejects, GameConfig.REJECT_CAPACITY)


func test_invalid_flag_only_rejects_at_the_own_review() -> void:
	var counter := state.station(GameConfig.COUNTER)
	assert_true(counter.has_reject_pile())
	assert_true(state.station(GameConfig.RECEPTION).has_reject_pile())
	assert_false(state.station("general_services/signature").has_reject_pile())
	_unlock_all()
	assert_false(state.station("customs/review").has_reject_pile())
	assert_true(state.station("tax_services/review").has_reject_pile())


func test_player_carries_rejects_to_the_shredder() -> void:
	var review := state.station("general_services/review")
	review.rejects = 2
	state.player.position = layout.reject_point("general_services/review")
	assert_true(sim.move_complaints())
	assert_eq(state.player.rejects, 1)
	assert_eq(review.rejects, 1)
	state.player.position = layout.shredder_point()
	var money := state.money
	watch_signals(sim)
	assert_true(sim.move_complaints())
	assert_eq(state.player.rejects, 0)
	assert_almost_eq(state.money, money + GameConfig.REJECT_SHRED_REWARD, 0.001)
	assert_signal_emitted_with_parameters(sim, "complaint_shredded", [true])
	assert_false(sim.move_complaints())


func test_player_cannot_overload_with_rejects() -> void:
	var review := state.station("general_services/review")
	review.rejects = 3
	state.player.rejects = Formulas.carry_capacity(state)
	state.player.position = layout.reject_point("general_services/review")
	assert_false(sim.move_complaints())
	assert_eq(review.rejects, 3)


func test_shred_rejects_without_stock_does_nothing() -> void:
	assert_eq(sim.shred_rejects(3, true), 0)
	assert_eq(sim.shred_rejects(3, false), 0)


func test_complaint_interns_leave_rejects_alone() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 1)
	var review := state.station("general_services/review")
	review.rejects = 2
	_run(30.0)
	assert_eq(review.rejects, 2)
	assert_eq(state.rejects_waiting(), 2)
	for unit in state.interns:
		assert_eq(unit.mood, ComplaintIntern.Mood.DESK)


func test_rejects_survive_saving() -> void:
	state.station("general_services/review").rejects = 4
	state.player.rejects = 2
	state.cases_rejected = 9
	state.cases_spawned = 77
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.station("general_services/review").rejects, 4)
	assert_eq(loaded.player.rejects, 2)
	assert_eq(loaded.cases_rejected, 9)
	assert_eq(loaded.cases_spawned, 77)
	var data := state.to_dict()
	data.stations["general_services/review"].rejects = 99
	assert_eq(GameState.from_dict(data).station("general_services/review").rejects, GameConfig.REJECT_CAPACITY)
	data.stations["shared/counter"].rejects = 3
	assert_eq(GameState.from_dict(data).station(GameConfig.COUNTER).rejects, 3)
	data.stations["general_services/signature"].rejects = 3
	assert_eq(GameState.from_dict(data).station("general_services/signature").rejects, 0)


func test_guidance_points_to_rejects_and_shredder() -> void:
	var review := state.station("general_services/review")
	review.rejects = 1
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.REJECT)
	assert_eq(task.point, layout.reject_point("general_services/review"))
	state.player.rejects = 1
	review.rejects = 0
	assert_eq(Guidance.next_task(state).action, Guidance.SHRED)


func test_layout_doors_are_on_both_sides_of_the_entrance() -> void:
	assert_lt(layout.door_in().x, layout.entrance.x)
	assert_gt(layout.door_out().x, layout.entrance.x)
	assert_eq(layout.door_in().y, layout.door_out().y)


func test_reject_point_sits_beside_the_output() -> void:
	var key := "general_services/review"
	assert_lt(layout.reject_point(key).x, layout.output_point(key).x)
	assert_eq(layout.reject_point(key).y, layout.output_point(key).y)


func test_tube_paths_connect_the_trays() -> void:
	var same_room := layout.tube_path("general_services/review", "general_services/signature")
	assert_eq(same_room.size(), 4)
	assert_eq(same_room[0], layout.output_point("general_services/review"))
	assert_eq(same_room[same_room.size() - 1], layout.input_point("general_services/signature"))
	var across := layout.tube_path(GameConfig.RECEPTION, "tax_services/review")
	assert_eq(across.size(), 6)
	assert_eq(across[across.size() - 1], layout.input_point("tax_services/review"))
	assert_eq(across[2].x, WorldLayout.SHAFT_X)
	assert_same(layout.tube_path(GameConfig.RECEPTION, "tax_services/review"), across)


func test_tube_gaps_lie_between_rooms() -> void:
	assert_eq(layout.room_slot(GameConfig.INSPECTION), "inspection")
	assert_eq(layout.room_slot(GameConfig.COUNTER), "")
	assert_eq(layout.room_slot("tax_services/review"), "tax_services")
	assert_eq(layout.tube_gap(GameConfig.COUNTER), layout.hall.position.y - WorldLayout.GAP * 0.5)
	assert_gt(layout.tube_gap("tax_services/review"), layout.room("tax_services").end.y)


func test_path_helpers_measure_and_interpolate() -> void:
	var path := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 50)])
	assert_eq(WorldLayout.path_length(path), 150.0)
	assert_eq(WorldLayout.path_point(path, 0.0), Vector2(0, 0))
	assert_eq(WorldLayout.path_point(path, 50.0), Vector2(50, 0))
	assert_eq(WorldLayout.path_point(path, 125.0), Vector2(100, 25))
	assert_eq(WorldLayout.path_point(path, 999.0), Vector2(100, 50))
	assert_eq(WorldLayout.path_point(path, -5.0), Vector2(0, 0))
	assert_eq(WorldLayout.path_length(PackedVector2Array([Vector2(1, 1)])), 0.0)
	assert_eq(WorldLayout.path_point(PackedVector2Array([Vector2(3, 3), Vector2(3, 3)]), 4.0), Vector2(3, 3))


func test_pneumatic_transport_announces_each_capsule() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	var review := state.station("general_services/review")
	review.outbox.append(_case("general_services", 1))
	watch_signals(sim)
	sim.tick(0.05)
	assert_signal_not_emitted(sim, "case_piped")
	assert_eq(review.outbox.size(), 1)
	state.set_upgrade("tube_station", 1, "general_services")
	sim.tick(0.05)
	assert_signal_emitted_with_parameters(sim, "case_piped", ["general_services/review", "general_services/signature", "general_services"])
	assert_true(review.outbox.is_empty())


func test_every_event_is_well_formed() -> void:
	for event_id in GameConfig.EVENTS:
		var event: Dictionary = GameConfig.EVENTS[event_id]
		assert_true(event.has("department") and event.has("min_cases"), event_id)
		assert_false(event.has("arrival") or event.has("patience"), event_id)
		var mitigation := str(event.get("mitigation", ""))
		if not mitigation.is_empty():
			assert_true(GameConfig.UPGRADES.has(mitigation), event_id)
			assert_false(GameConfig.is_room_upgrade(mitigation), event_id)
		assert_gt(Formulas.event_duration(state, event_id), 0.0, event_id)
	assert_gte(GameConfig.EVENTS.size(), 14)


func test_every_event_can_start() -> void:
	for event_id in GameConfig.EVENTS:
		var fresh := GameState.create_new(5)
		for dept_id in GameConfig.department_ids():
			fresh.unlock_department(dept_id)
		var simulation := Simulation.new(fresh)
		watch_signals(simulation)
		simulation.start_event(event_id)
		assert_eq(fresh.event_id, event_id)
		assert_gt(fresh.event_time_left, 0.0, event_id)
		assert_ne(fresh.event_scope, "random", event_id)
		assert_signal_emitted(simulation, "event_started")


func test_eligibility_depends_on_cases_departments_and_inspection() -> void:
	state.cases_completed = 500
	var events := sim.eligible_events()
	assert_true(events.has("printer_jam"))
	assert_false(events.has("inspector_audit"))
	assert_false(events.has("rubber_ducks"))
	assert_false(events.has("garden_shed"))
	state.unlock_department("business_licences")
	assert_true(sim.eligible_events().has("inspector_audit"))
	state.unlock_department("building_permits")
	assert_true(sim.eligible_events().has("garden_shed"))
	state.unlock_department("customs")
	assert_true(sim.eligible_events().has("rubber_ducks"))


func test_event_speed_respects_scope_and_pending_choice() -> void:
	_unlock_all()
	var general := state.station("general_services/review")
	var tax := state.station("tax_services/review")
	state.event_id = "printer_jam"
	assert_eq(Formulas.event_speed(state, general), 0.55)
	assert_eq(Formulas.event_speed(state, tax), 0.55)
	state.event_id = "system_crash"
	state.event_scope = "general_services"
	assert_eq(Formulas.event_speed(state, general), 0.4)
	assert_eq(Formulas.event_speed(state, tax), 1.0)
	assert_eq(Formulas.event_speed(state, state.station(GameConfig.RECEPTION)), 1.0)
	state.event_id = "inspector_audit"
	state.event_scope = GameConfig.INSPECTION
	assert_eq(Formulas.event_speed(state, state.station(GameConfig.INSPECTION)), 0.35)
	assert_eq(Formulas.event_speed(state, general), 1.0)
	state.event_id = "authority_comparison"
	state.event_scope = ""
	assert_eq(Formulas.event_speed(state, general), 1.0)
	state.event_choice = "prepare"
	assert_eq(Formulas.event_speed(state, general), 0.5)
	state.event_id = "audit_visit"
	assert_eq(Formulas.event_speed(state, general), 1.0)
	state.event_id = ""
	assert_eq(Formulas.event_speed(state, general), 1.0)


func test_events_change_work_speed_in_the_simulation() -> void:
	var review := state.station("general_services/review")
	review.staff = 1
	var job := StationJob.new(_case("general_services", 1), 100.0)
	review.jobs[0] = job
	state.event_id = "printer_jam"
	state.event_time_left = 100.0
	sim.tick(1.0)
	assert_almost_eq(job.progress, 0.55, 0.01)
	state.event_id = "fire_drill"
	var before := job.progress
	sim.tick(1.0)
	assert_eq(job.progress, before)


func test_events_change_drowsiness() -> void:
	var review := state.station("general_services/review")
	var base_rate := Formulas.drowsiness_rate(state, review)
	state.event_id = "coffee_escalation"
	assert_eq(Formulas.drowsiness_rate(state, review), base_rate * 3.0)
	state.event_id = ""
	assert_eq(Formulas.event_drowsy(state), 1.0)


func test_no_events_are_eligible_before_enough_cases() -> void:
	state.cases_completed = 0
	assert_true(sim.eligible_events().is_empty())
	state.event_cooldown = 0.0
	sim.tick(0.05)
	assert_eq(state.event_id, "")
	assert_eq(state.event_cooldown, GameConfig.EVENT_MIN_COOLDOWN)


func _mitigation(level: int, max_level: int) -> float:
	return 1.0 - (1.0 - GameConfig.EVENT_MIN_DURATION_FACTOR) * level / float(max_level)


func test_upgrades_shorten_mitigated_events() -> void:
	var it_max := int(GameConfig.upgrade("it_support").max)
	var fire_drill := float(GameConfig.EVENTS["fire_drill"].duration)
	assert_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION)
	var half := roundi(it_max * 0.5)
	state.set_upgrade("it_support", half)
	assert_almost_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION * _mitigation(half, it_max), 0.001)
	assert_almost_eq(Formulas.event_duration(state, "fire_drill"), fire_drill * _mitigation(half, it_max), 0.001)
	var most := roundi(it_max * 0.75)
	state.set_upgrade("it_support", most)
	assert_almost_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION * _mitigation(most, it_max), 0.001)
	assert_eq(Formulas.event_duration(state, "garden_shed"), float(GameConfig.EVENTS["garden_shed"].duration))
	assert_eq(Formulas.event_duration(state, "authority_comparison"), GameConfig.EVENT_CHOICE_SECONDS)
	state.set_upgrade("it_support", 1)
	assert_almost_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION * _mitigation(1, it_max), 0.001)
	assert_lt(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION)
	state.set_upgrade("it_support", 0)
	state.set_upgrade("coffee_machine", int(GameConfig.upgrade("coffee_machine").max))
	assert_almost_eq(Formulas.event_duration(state, "coffee_escalation"), GameConfig.EVENT_DURATION * GameConfig.EVENT_MIN_DURATION_FACTOR, 0.001)


func test_paperwork_mountain_fills_a_review_inbox() -> void:
	sim.start_event("paperwork_mountain")
	var review := state.station("general_services/review")
	assert_eq(review.inbox.size(), GameConfig.BACKLOG_CASES)
	for case_file in review.inbox:
		assert_eq(case_file.step, 1)
		assert_eq(case_file.current_key(), "general_services/review")


func test_paperwork_mountain_respects_inbox_space() -> void:
	var review := state.station("general_services/review")
	while review.has_inbox_space(state.lobby_capacity()):
		review.inbox.append(CaseFile.new("general_services"))
	var size := review.inbox.size()
	sim.start_event("paperwork_mountain")
	assert_eq(review.inbox.size(), size)


func test_garden_shed_adds_one_big_complex_case() -> void:
	_unlock_all()
	sim.start_event("garden_shed")
	var review := state.station("building_permits/review")
	assert_eq(review.inbox.size(), 1)
	var shed := review.inbox[0]
	assert_true(shed.big)
	assert_true(shed.complex)
	assert_false(shed.invalid)
	assert_false(shed.urgent)
	var normal := _case("building_permits", 1)
	normal.complex = true
	assert_almost_eq(Formulas.required_time(state, review, shed) / Formulas.required_time(state, review, normal), GameConfig.BIG_CASE_TIME_FACTOR, 0.001)
	assert_almost_eq(float(Formulas.case_outcome(state, shed).money) / float(Formulas.case_outcome(state, normal).money), GameConfig.BIG_CASE_REWARD_FACTOR, 0.001)


func test_authority_comparison_prepare_pays_reputation() -> void:
	sim.start_event("authority_comparison")
	assert_eq(state.event_time_left, GameConfig.EVENT_CHOICE_SECONDS)
	assert_true(sim.resolve_event("prepare"))
	assert_eq(state.event_choice, "prepare")
	assert_eq(state.event_time_left, GameConfig.EVENT_PREPARE_SECONDS)
	assert_false(sim.resolve_event("prepare"))
	var reputation := state.reputation
	watch_signals(sim)
	_run(GameConfig.EVENT_PREPARE_SECONDS + 1.0)
	assert_eq(state.event_id, "")
	assert_eq(state.event_choice, "")
	assert_almost_eq(state.reputation, reputation + GameConfig.EVENT_PREPARE_REPUTATION, 0.5)
	assert_signal_emitted_with_parameters(sim, "event_ended", ["authority_comparison"])


func test_authority_comparison_ignore_ends_without_reward() -> void:
	sim.start_event("authority_comparison")
	var reputation := state.reputation
	assert_true(sim.resolve_event("ignore"))
	assert_eq(state.event_id, "")
	assert_eq(state.reputation, reputation)
	assert_gt(state.event_cooldown, 0.0)


func test_unanswered_comparison_runs_out_quietly() -> void:
	sim.start_event("authority_comparison")
	var reputation := state.reputation
	_run(GameConfig.EVENT_CHOICE_SECONDS + 1.0)
	assert_eq(state.event_id, "")
	assert_eq(state.reputation, reputation)


func test_cancelling_the_meeting_costs_reputation() -> void:
	state.reputation = 10.0
	sim.start_event("staff_meeting")
	assert_true(sim.resolve_event("cancel"))
	assert_eq(state.event_id, "")
	assert_almost_eq(state.reputation, 10.0 - minf(GameConfig.EVENT_CANCEL_PENALTY * GameConfig.REP_LOSS_FACTOR, GameConfig.REP_MAX_LOSS_PER_MINUTE), 0.001)


func test_resolve_event_rejects_invalid_requests() -> void:
	assert_false(sim.resolve_event("cancel"))
	sim.start_event("printer_jam")
	assert_false(sim.resolve_event("cancel"))
	sim.start_event("staff_meeting")
	assert_false(sim.resolve_event("prepare"))
	assert_eq(state.event_id, "staff_meeting")


func test_event_scope_is_cleared_when_it_ends() -> void:
	_unlock_all()
	sim.start_event("system_crash")
	assert_true(state.unlocked_departments().any(func(dept: Department) -> bool: return dept.id == state.event_scope))
	state.event_time_left = 0.1
	sim.tick(0.5)
	assert_eq(state.event_id, "")
	assert_eq(state.event_scope, "")


func test_event_state_survives_saving() -> void:
	_unlock_all()
	sim.start_event("authority_comparison")
	sim.resolve_event("prepare")
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.event_id, "authority_comparison")
	assert_eq(loaded.event_choice, "prepare")
	sim.start_event("system_crash")
	loaded = GameState.from_dict(state.to_dict())
	assert_eq(loaded.event_scope, state.event_scope)
	var idle := GameState.create_new(1)
	var data := idle.to_dict()
	data.event_scope = "general_services"
	data.event_choice = "prepare"
	var restored := GameState.from_dict(data)
	assert_eq(restored.event_scope, "")
	assert_eq(restored.event_choice, "")


func test_upgrades_and_events_are_registered() -> void:
	assert_true(GameConfig.UPGRADES.has("it_support"))
	assert_eq(GameConfig.upgrade_ids().size(), GameConfig.UPGRADES.size())
	for upgrade_id in GameConfig.upgrade_ids():
		assert_true(Icons.UPGRADES.has(upgrade_id), upgrade_id)
	for event_id in GameConfig.EVENTS:
		assert_true(Icons.EVENTS.has(event_id), event_id)


func test_translations_exist_for_new_texts() -> void:
	var keys: Array[String] = ["FMT_JAM", "JAM_SIDE_IN", "JAM_SIDE_OUT", "JAM_SIDE_REJECTS", "LEGEND_MARKERS", "FMT_POPULATION", "EVENT_CHOICE_PREPARE", "EVENT_CHOICE_IGNORE", "EVENT_CHOICE_CANCEL", "TRACK_IT_SUPPORT", "TRACK_DESC_IT_SUPPORT"]
	for rank in GameConfig.SETTLEMENT_RANKS:
		keys.append("SETTLEMENT_" + str(rank.id).to_upper())
	for index in Flavor.REJECT_COUNT:
		keys.append("REJECT_%d" % (index + 1))
	for key in keys:
		assert_ne(TranslationServer.translate(key), key, key)
	assert_ne(Flavor.reject(0), Flavor.reject(1))


func _hall_citizen(dept_id: String, ticket: int) -> CaseFile:
	var citizen := sim.create_case(state.department(dept_id))
	citizen.phase = CaseFile.Phase.WAITING
	citizen.ticket = ticket
	citizen.place = ticket
	citizen.seated = true
	state.citizens.append(citizen)
	return citizen


func _fill_review(dept_id: String) -> Station:
	var review := state.station(dept_id + "/review")
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(sim.create_case(state.department(dept_id)))
	return review


func test_reception_skips_citizens_of_saturated_departments() -> void:
	state.unlock_department("social_benefits")
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	_fill_review("social_benefits")
	var stuck := _hall_citizen("social_benefits", 1)
	var other := _hall_citizen("general_services", 2)
	assert_true(sim.call_citizens())
	assert_eq(other.phase, CaseFile.Phase.CALLED)
	assert_eq(stuck.phase, CaseFile.Phase.WAITING)


func test_reception_waits_when_only_blocked_citizens_wait() -> void:
	state.unlock_department("social_benefits")
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	var review := _fill_review("social_benefits")
	var stuck := _hall_citizen("social_benefits", 1)
	assert_false(sim.call_citizens())
	review.inbox.pop_back()
	assert_true(sim.call_citizens())
	assert_eq(stuck.phase, CaseFile.Phase.CALLED)


func test_reception_keeps_files_without_citizen_for_saturated_departments() -> void:
	state.unlock_department("social_benefits")
	var reception := state.station(GameConfig.RECEPTION)
	var review := _fill_review("social_benefits")
	reception.inbox.append(sim.create_case(state.department("social_benefits")))
	assert_false(sim.start_job(reception, 0))
	review.inbox.pop_back()
	assert_true(sim.start_job(reception, 0))


func test_reception_desk_starts_while_other_desk_citizen_still_walks() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 2
	var walking := _hall_citizen("general_services", 1)
	var arrived := _hall_citizen("general_services", 2)
	for pair in [[walking, 0, 5.0], [arrived, 1, 0.0]]:
		var citizen: CaseFile = pair[0]
		citizen.phase = CaseFile.Phase.CALLED
		citizen.desk = pair[1]
		citizen.walk = pair[2]
		reception.inbox.append(citizen)
	sim._work_stations(0.1)
	assert_null(reception.jobs[0])
	assert_not_null(reception.jobs[1])


func test_player_shreds_normal_case_at_shredder() -> void:
	var case_file := sim.create_case(state.department("general_services"))
	state.player.items.append(case_file)
	state.player.position = layout.shredder_point()
	state.reputation = 5.0
	var before := state.reputation
	watch_signals(sim)
	assert_true(sim.move_complaints())
	assert_true(state.player.items.is_empty())
	assert_eq(state.cases_shredded, 1)
	assert_eq(state.citizens_lost, 1)
	assert_almost_eq(state.reputation, before - GameConfig.SHRED_CASE_PENALTY * GameConfig.REP_LOSS_FACTOR, 0.001)
	assert_signal_emitted(sim, "case_shredded")
	assert_signal_emitted(sim, "citizen_left")


func test_shredder_prefers_complaints_and_rejects_over_cases() -> void:
	state.player.position = layout.shredder_point()
	state.player.items.append(sim.create_case(state.department("general_services")))
	state.player.rejects = 1
	assert_true(sim.move_complaints())
	assert_eq(state.player.rejects, 0)
	assert_eq(state.player.items.size(), 1)
	assert_true(sim.move_complaints())
	assert_true(state.player.items.is_empty())


func test_no_case_shredding_away_from_shredder() -> void:
	state.player.items.append(sim.create_case(state.department("general_services")))
	state.player.position = Vector2(50, 50)
	assert_false(sim.move_complaints())
	assert_eq(state.player.items.size(), 1)


func game_actions() -> GameActions:
	return GameActions.new(state, sim)


func _reject_piles_by_distance() -> Array[String]:
	var keys: Array[String] = []
	for key in state.ordered_station_keys():
		if state.station(key).has_reject_pile():
			keys.append(key)
	var shredder := layout.shredder_point()
	keys.sort_custom(func(a: String, b: String) -> bool: return shredder.distance_to(layout.reject_point(a)) < shredder.distance_to(layout.reject_point(b)))
	return keys


func test_reject_runner_is_hired_through_the_runner_actions() -> void:
	state.money = 1.0e9
	var cost := Formulas.runner_cost(state)
	assert_true(game_actions().hire_runner(Runner.REJECT))
	assert_eq(state.runners.size(), 1)
	assert_eq(state.runners[0].role, Runner.REJECT)
	assert_eq(state.runners_in(Runner.REJECT), 1)
	assert_almost_eq(state.money, 1.0e9 - cost, 0.001)
	assert_eq(cost, GameConfig.RUNNER_COST * Formulas.early_discount(0))


func test_reject_runners_share_the_runner_limit() -> void:
	state.money = 1.0e12
	for i in GameConfig.MAX_RUNNERS:
		assert_true(game_actions().hire_runner(Runner.REJECT))
	assert_false(game_actions().can_hire_runner())
	assert_false(game_actions().hire_runner(Runner.REJECT))
	assert_eq(state.runners.size(), GameConfig.MAX_RUNNERS)


func test_automatic_hiring_never_picks_the_reject_task() -> void:
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	state.add_runner(Runner.OUTPUT)
	assert_ne(state.least_staffed_role(), Runner.REJECT)
	assert_ne(Formulas.weakest_runner_role(state), Runner.REJECT)
	assert_ne(state.add_runner().role, Runner.REJECT)


func test_collector_tracks_and_department_shredders_are_gone() -> void:
	for upgrade_id in ["collector_carts", "collector_speed", "shredder"]:
		assert_true(GameConfig.upgrade(upgrade_id).is_empty(), upgrade_id)
	assert_false(GameConfig.upgrade_ids().has("shredder"))
	assert_true(GameConfig.upgrade("shredder_blades").has("max"))


func test_reject_runner_brings_rejects_to_shredder() -> void:
	state.add_runner(Runner.REJECT)
	var station := state.station("general_services/review")
	station.rejects = 4
	var money := state.money
	watch_signals(sim)
	_run(60.0, 0.1)
	assert_eq(station.rejects, 0)
	assert_eq(state.runners[0].loaded, 0)
	assert_almost_eq(state.money, money + GameConfig.REJECT_SHRED_REWARD * 4.0, 0.001)
	assert_eq(state.production.total(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF), 4)
	assert_signal_emitted_with_parameters(sim, "complaint_shredded", [false])


func test_reject_runner_carries_up_to_its_runner_load() -> void:
	var station := state.station("general_services/review")
	station.rejects = GameConfig.REJECT_CAPACITY
	var runner := state.add_runner(Runner.REJECT)
	runner.level = 3
	runner.position = layout.reject_point(station.key)
	runner.source = station.key
	sim.tick(0.05)
	assert_eq(Formulas.runner_load(state, runner), Formulas.runner_capacity(state) + 3 * GameConfig.RUNNER_LEVEL_CAPACITY)
	assert_eq(runner.loaded, Formulas.runner_load(state, runner))
	assert_eq(station.rejects, GameConfig.REJECT_CAPACITY - runner.loaded)
	assert_eq(runner.source, "")


func test_reject_runner_capacity_grows_with_trolleys() -> void:
	var runner := state.add_runner(Runner.REJECT)
	assert_eq(Formulas.runner_load(state, runner), GameConfig.RUNNER_BASE_CAPACITY)
	state.set_upgrade("runner_trolleys", 2)
	assert_eq(Formulas.runner_load(state, runner), GameConfig.RUNNER_BASE_CAPACITY + 2)


func test_reject_runner_idles_without_rejects() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.shredder_point()
	var rest := layout.runner_rest_point(0)
	var start := runner.position.distance_to(rest)
	_run(3.0, 0.1)
	assert_eq(runner.loaded, 0)
	assert_eq(runner.source, "")
	assert_lt(runner.position.distance_to(rest), start)
	_run(30.0, 0.1)
	assert_lt(runner.position.distance_to(rest), 1.0)


func test_reject_runners_use_runner_speed() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.shredder_point()
	var rest := layout.runner_rest_point(0)
	var before := runner.position.distance_to(rest)
	sim.tick(0.1)
	assert_almost_eq(before - runner.position.distance_to(rest), Formulas.runner_speed(state) * 0.1, 0.01)
	state.boosts["roller_skates"] = 10.0
	runner.position = layout.shredder_point()
	sim.tick(0.1)
	assert_almost_eq(before - runner.position.distance_to(rest), Formulas.runner_speed(state) * 0.1, 0.01)
	assert_eq(Formulas.runner_speed(state), GameConfig.RUNNER_SPEED * GameConfig.BOOST_RUNNER_SPEED)


func test_two_reject_runners_split_rejects() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	state.station(piles[0]).rejects = 3
	state.station(piles[1]).rejects = 3
	var first := state.add_runner(Runner.REJECT)
	var second := state.add_runner(Runner.REJECT)
	sim.tick(0.05)
	assert_ne(first.source, "")
	assert_ne(second.source, "")
	assert_ne(first.source, second.source)


func test_reject_runner_survives_saving() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.loaded = 2
	runner.level = 4
	runner.dept_id = "tax_services"
	state.cases_shredded = 3
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.runners.size(), 1)
	assert_eq(restored.runners[0].role, Runner.REJECT)
	assert_eq(restored.runners[0].loaded, 2)
	assert_eq(restored.runners[0].level, 4)
	assert_eq(restored.runners[0].dept_id, "tax_services")
	assert_eq(restored.cases_shredded, 3)
	assert_false(state.to_dict().has("collectors"))


func test_reject_runner_load_is_clamped_when_loading() -> void:
	assert_eq(Runner.from_dict({"role": Runner.REJECT, "loaded": 999}, Vector2.ZERO).loaded, Formulas.runner_load_limit(0))
	assert_eq(Runner.from_dict({"role": Runner.REJECT, "level": 5, "loaded": 999}, Vector2.ZERO).loaded, Formulas.runner_load_limit(5))
	assert_eq(Runner.from_dict({"role": Runner.REJECT, "loaded": -3}, Vector2.ZERO).loaded, 0)
	assert_eq(Runner.from_dict({"role": Runner.REJECT}, Vector2.ZERO).loaded, 0)
	assert_eq(Runner.from_dict({"role": Runner.INTAKE}, Vector2.ZERO).loaded, 0)
	assert_eq(Formulas.runner_load_limit(0), GameConfig.RUNNER_BASE_CAPACITY + int(GameConfig.upgrade("runner_trolleys").max))


func test_runner_role_reject_is_saved_and_unknown_roles_are_replaced() -> void:
	assert_eq(Runner.from_dict({"role": "reject"}, Vector2.ZERO).role, Runner.REJECT)
	assert_eq(Runner.from_dict({"role": "collector"}, Vector2.ZERO).role, "")
	assert_eq(Runner.from_dict({"role": Runner.REJECT, "dept": "nope"}, Vector2.ZERO).dept_id, Runner.ALL_DEPARTMENTS)
	assert_eq(Runner.ROLES.size(), 5)
	assert_eq(Runner.ROLES[3], Runner.REJECT)
	assert_eq(Runner.CASE_ROLES.size(), 3)
	var data := state.to_dict()
	data.runners = [{"role": "bogus", "x": 5.0, "y": 6.0}]
	assert_eq(GameState.from_dict(data).runners[0].role, GameState.from_dict(data).least_staffed_role())


func test_guidance_skips_reject_pickup_when_reject_runner_exists() -> void:
	state.station("general_services/review").rejects = 2
	state.add_runner(Runner.INTAKE)
	assert_eq(Guidance.next_task(state).get("action", ""), Guidance.REJECT)
	state.add_runner(Runner.REJECT)
	var task := Guidance.next_task(state)
	assert_ne(task.get("action", ""), Guidance.REJECT)


func test_reject_translations() -> void:
	for key in ["RUNNER_ROLE_REJECT", "RUNNER_ROLE_SHORT_REJECT", "RUNNER_ROLE_DESC_REJECT", "FMT_STATS_REJECT_STATE", "FMT_STATUS_SHREDDER", "RUNNERS_INTRO"]:
		assert_ne(TranslationServer.translate(key), key, key)
	for key in ["STAFF_COLLECTORS", "STAFF_DESC_COLLECTORS", "FMT_COLLECTOR_INFO", "BOARD_COLLECTORS", "COLLECTORS_INTRO", "COLLECTORS_EMPTY", "FMT_COLLECTOR_NAME", "FMT_COLLECTOR_LOAD", "TRACK_COLLECTOR_CARTS", "TRACK_DESC_COLLECTOR_CARTS", "TRACK_COLLECTOR_SPEED", "TRACK_DESC_COLLECTOR_SPEED", "TRACK_SHREDDER", "TRACK_DESC_SHREDDER", "SPOT_DESC_DEPT_SHREDDER", "FMT_SPOT_SHREDDER", "STATUS_NO_SHREDDER", "FMT_STATUS_DEPT_SHREDDER", "UPGRADE_COLLECTOR"]:
		assert_eq(TranslationServer.translate(key), key, key)


func test_staff_room_has_no_collector_board() -> void:
	assert_false(GameConfig.BOARD_SPOTS.has("collectors"))
	assert_false(GameConfig.STAFF_ROOM_BOARDS.has("collectors"))
	assert_eq(GameConfig.STAFF_ROOM_BOARDS, ["coffee_interns", "phone_clerks", "training", "works_council"] as Array[String])
	for board in GameConfig.STAFF_ROOM_BOARDS:
		assert_true(layout.staff_room.encloses(layout.staff_board(board)), board)
	assert_true(UpgradeCatalog.entries_for_spot(state, "collectors").is_empty())
	assert_false(UpgradeCatalog.STAFF_SPOTS.has("collectors"))
	assert_false(UpgradeCatalog.STAFF_LIMITS.has("collectors"))
	assert_false(UpgradeCatalog.STAFF_GROWTH.has("collectors"))
	assert_eq(UpgradeCatalog.staff_count(state, "collectors"), 0)
	assert_eq(UpgradeCatalog.staff_cost(state, "collectors"), 0.0)
	assert_false(UpgradeCatalog.hire_staff(game_actions(), "collectors"))


func test_reject_runner_prefers_nearly_full_piles_over_near_ones() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	var near := state.station(piles[0])
	var far := state.station(piles[piles.size() - 1])
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.shredder_point()
	var capacity := Formulas.runner_load(state, runner)
	near.rejects = 2
	far.rejects = 2
	assert_eq(sim.reject_target(runner, capacity), near.key)
	far.rejects = GameConfig.REJECT_CAPACITY - GameConfig.REJECT_URGENT_MARGIN
	assert_eq(sim.reject_target(runner, capacity), far.key)


func test_reject_runner_skips_far_piles_once_loaded() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	var far_key := piles[piles.size() - 1]
	assert_gt(2.0 * layout.shredder_point().distance_to(layout.reject_point(far_key)), GameConfig.REJECT_MAX_DETOUR)
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.shredder_point()
	runner.loaded = 1
	var capacity := Formulas.runner_load(state, runner)
	state.station(far_key).rejects = 1
	assert_eq(sim.reject_target(runner, capacity), "")
	state.station(far_key).rejects = GameConfig.REJECT_CAPACITY
	assert_eq(sim.reject_target(runner, capacity), far_key)
	runner.loaded = capacity
	assert_eq(sim.reject_target(runner, capacity), "")


func test_reject_runner_only_serves_its_department() -> void:
	_unlock_all()
	var general := state.station("general_services/review")
	var tax := state.station("tax_services/review")
	general.rejects = 5
	tax.rejects = 1
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.shredder_point()
	var capacity := Formulas.runner_load(state, runner)
	runner.dept_id = "tax_services"
	assert_eq(sim.reject_target(runner, capacity), tax.key)
	runner.dept_id = "general_services"
	assert_eq(sim.reject_target(runner, capacity), general.key)
	runner.dept_id = "housing"
	assert_eq(sim.reject_target(runner, capacity), "")
	runner.dept_id = Runner.ALL_DEPARTMENTS
	assert_ne(sim.reject_target(runner, capacity), "")
	assert_true(runner.serves_rejects_of("anything"))
	runner.dept_id = "housing"
	assert_false(runner.serves_rejects_of("tax_services"))
	assert_true(runner.serves_rejects_of("housing"))


func test_reject_runner_keeps_collecting_until_full() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	var first := state.station(piles[0])
	var second := state.station(piles[1])
	first.rejects = 1
	second.rejects = GameConfig.REJECT_CAPACITY
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.reject_point(first.key)
	runner.source = first.key
	sim.tick(0.05)
	assert_eq(runner.loaded, 1)
	assert_eq(first.rejects, 0)
	sim.tick(0.05)
	assert_eq(runner.source, second.key)
	_run(240.0, 0.1)
	assert_eq(second.rejects, 0)
	assert_eq(runner.loaded, 0)
	assert_eq(state.production.total(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF), GameConfig.REJECT_CAPACITY + 1)


func test_reject_runner_handles_a_vanished_pile() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.source = "nope"
	runner.position = layout.reject_point("nope")
	sim.tick(0.05)
	assert_eq(runner.source, "")
	assert_eq(runner.loaded, 0)


func test_reject_runner_unloads_only_at_the_central_shredder() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.loaded = 2
	runner.position = layout.reject_point("general_services/review")
	var money := state.money
	sim.tick(0.05)
	assert_eq(runner.loaded, 2)
	assert_eq(state.money, money)
	runner.position = layout.shredder_point()
	sim.tick(0.05)
	assert_eq(runner.loaded, 0)
	assert_almost_eq(state.money, money + GameConfig.REJECT_SHRED_REWARD * 2.0, 0.001)


func test_reject_distances_are_cached_per_pile() -> void:
	var key := "general_services/review"
	var expected := layout.reject_point(key).distance_to(layout.shredder_point())
	assert_almost_eq(sim._reject_to_shredder(key), expected, 0.001)
	assert_true(sim._reject_detours.has(key))
	assert_almost_eq(sim._reject_to_shredder(key), expected, 0.001)


func test_normal_runners_leave_rejects_alone() -> void:
	var station := state.station("general_services/review")
	station.rejects = 3
	for role in Runner.CASE_ROLES:
		state.add_runner(role)
	_run(30.0, 0.1)
	assert_eq(station.rejects, 3)
	for runner in state.runners:
		assert_eq(runner.loaded, 0)
		assert_eq(runner.source, "")


func test_reject_runners_leave_files_alone() -> void:
	var review := _fill_outbox(2)
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.output_point(review.key)
	assert_false(sim.assign_runner(runner))
	assert_eq(sim.runner_standby(runner), "")
	_run(5.0, 0.1)
	assert_true(runner.items.is_empty())
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_eq(review.outbox.size(), 2)
	assert_false(runner.serves(review.outbox[0], review.key))


func test_runner_leaving_reject_duty_still_unloads_what_it_carries() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.loaded = 2
	runner.position = layout.shredder_point() + Vector2(30, 0)
	assert_true(game_actions().set_runner_role(0, Runner.INTAKE))
	var money := state.money
	state.station("general_services/review").rejects = 4
	_run(10.0, 0.1)
	assert_eq(runner.loaded, 0)
	assert_eq(runner.source, "")
	assert_eq(state.station("general_services/review").rejects, 4)
	assert_almost_eq(state.money, money + GameConfig.REJECT_SHRED_REWARD * 2.0, 0.001)


func test_changing_role_or_department_resets_the_reject_route() -> void:
	var runner := state.add_runner(Runner.REJECT)
	runner.source = "general_services/review"
	assert_true(game_actions().cycle_runner_department(0))
	assert_eq(runner.source, "")
	runner.source = "general_services/review"
	assert_true(game_actions().set_runner_role(0, Runner.INTERNAL))
	assert_eq(runner.source, "")
	assert_true(game_actions().set_runner_role(0, Runner.REJECT))
	assert_eq(runner.role, Runner.REJECT)
	assert_false(game_actions().set_runner_role(0, "collector"))


func test_runner_reset_route_keeps_carried_files() -> void:
	var runner := state.add_runner(Runner.INTAKE)
	runner.task = Runner.Task.TO_TARGET
	runner.target = "general_services/review"
	runner.items.append(_case("general_services"))
	runner.reset_route()
	assert_eq(runner.task, Runner.Task.TO_TARGET)
	runner.task = Runner.Task.TO_SOURCE
	runner.source = "x"
	runner.reset_route()
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_eq(runner.source, "")


func test_reject_runner_with_files_after_a_role_change_delivers_them() -> void:
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	var case_file := _case("general_services", 1)
	var runner := state.add_runner(Runner.REJECT)
	runner.items.append(case_file)
	runner.task = Runner.Task.TO_TARGET
	runner.target = signature.key
	runner.position = layout.input_point(signature.key)
	sim.tick(0.05)
	assert_true(runner.items.is_empty())
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_eq(review.outbox.size(), 0)


func _fill_outbox(count: int) -> Station:
	var review := state.station("general_services/review")
	for i in count:
		review.outbox.append(_case("general_services", 1))
	return review


func _connect_all_tubes() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)


func test_tube_capacity_formula_and_upgrade_gate() -> void:
	var config := GameConfig.upgrade("tube_capacity")
	assert_eq(Formulas.tube_capacity(state), GameConfig.TUBE_BASE_CAPACITY)
	state.set_upgrade("tube_capacity", 2)
	assert_eq(Formulas.tube_capacity(state), GameConfig.TUBE_BASE_CAPACITY + 2 * int(config.step))
	state.set_upgrade("tube_capacity", 0)
	state.money = 1.0e9
	state.reputation = 1.0e6
	assert_eq(Progression.upgrade_block_reason(state, "tube_capacity"), "requires")
	state.set_upgrade("pneumatic_tubes", 1)
	assert_eq(Progression.upgrade_block_reason(state, "tube_capacity"), "")
	state.set_upgrade("tube_capacity", int(config.max))
	assert_eq(Progression.upgrade_block_reason(state, "tube_capacity"), "max")
	assert_gte(int(config.max), 50)


func test_tube_holds_only_its_capacity() -> void:
	_connect_all_tubes()
	var review := _fill_outbox(5)
	sim.tick(0.05)
	assert_eq(state.tube_parcels.size(), GameConfig.TUBE_BASE_CAPACITY)
	assert_eq(review.outbox.size(), 5 - GameConfig.TUBE_BASE_CAPACITY)


func test_tube_upgrade_raises_load() -> void:
	_connect_all_tubes()
	state.set_upgrade("tube_capacity", 1)
	var review := _fill_outbox(8)
	sim.tick(0.05)
	assert_eq(state.tube_parcels.size(), Formulas.tube_capacity(state))
	assert_eq(review.outbox.size(), 8 - Formulas.tube_capacity(state))


func test_parcels_arrive_and_free_the_tube() -> void:
	_connect_all_tubes()
	var review := _fill_outbox(4)
	var target := state.station("general_services/signature")
	_run(0.05)
	_run(3.5, 0.1)
	assert_true(review.outbox.is_empty())
	assert_true(state.tube_parcels.is_empty())
	assert_eq(target.inbox.size() + target.active_jobs() + target.outbox.size(), 4)


func test_parcel_waits_when_target_is_full() -> void:
	_connect_all_tubes()
	var target := state.station("general_services/signature")
	target.staff = 0
	for i in target.inbox_capacity(state.lobby_capacity()):
		target.inbox.append(_case("general_services", 2))
	_fill_outbox(1)
	_run(5.0, 0.1)
	assert_eq(state.tube_parcels.size(), 1)
	assert_eq(state.tube_parcels[0].left, 0.0)
	target.inbox.pop_back()
	_run(0.5, 0.1)
	assert_true(state.tube_parcels.is_empty())


func test_parcels_count_as_carried_and_survive_save() -> void:
	_connect_all_tubes()
	_fill_outbox(2)
	sim.tick(0.05)
	assert_eq(state.carried_cases().size(), 2)
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.tube_parcels.size(), 2)
	assert_eq(restored.tube_parcels[0].tube_id(), state.tube_parcels[0].tube_id())
	assert_null(TubeParcel.from_dict({"from": "", "to": "x", "case": {}}))
	assert_null(TubeParcel.from_dict("bad"))


func test_tube_capacity_texts_and_icon_exist() -> void:
	assert_true(Icons.UPGRADES.has("tube_capacity"))
	for key in ["TRACK_TUBE_CAPACITY", "TRACK_DESC_TUBE_CAPACITY", "FMT_REQ_UPGRADE", "FMT_STATUS_TUBE_HUB", "STATUS_TUBES_LOCKED"]:
		assert_ne(TranslationServer.translate(key), key, key)


func _intern_trip_seconds() -> float:
	return layout.intern_trip_length(1) / Formulas.intern_speed(state)


func _complaint_desk(count: int) -> void:
	state.set_upgrade("complaint_interns", count)


func test_intern_empties_the_box_and_walks_back() -> void:
	_complaint_desk(2)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 1
	var runner := state.interns[1]
	var trip := _intern_trip_seconds()
	assert_gt(trip, 1.0)
	var moods := []
	var elapsed := 0.0
	while elapsed < trip + 2.0:
		sim.tick(0.1)
		elapsed += 0.1
		if moods.is_empty() or moods.back() != runner.mood:
			moods.append(runner.mood)
	assert_eq(moods, [ComplaintIntern.Mood.TO_BOX, ComplaintIntern.Mood.TO_SHREDDER, ComplaintIntern.Mood.FROM_SHREDDER, ComplaintIntern.Mood.DESK])
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_shredded, 1)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)
	assert_eq(runner.position, layout.intern_home(1))


func test_box_runs_need_a_second_intern_and_the_track() -> void:
	_complaint_desk(2)
	state.complaints = 3
	_run(10.0, 0.1)
	assert_eq(state.complaints, 3)
	_complaint_desk(1)
	state.set_upgrade("intern_box_runs", 2)
	_run(10.0, 0.1)
	assert_eq(state.complaints, 3)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)


func test_intern_formulas_and_gates() -> void:
	assert_eq(state.interns.size(), 0)
	assert_eq(Formulas.intern_steadfast(state), GameConfig.INTERN_BASE_STEADFAST)
	assert_eq(Formulas.intern_run_size(state), 0)
	assert_almost_eq(Formulas.intern_speed(state), GameConfig.INTERN_SPEED, 0.001)
	state.set_upgrade("intern_steadfast", int(GameConfig.upgrade("intern_steadfast").max))
	assert_eq(Formulas.intern_steadfast(state), GameConfig.INTERN_MAX_STEADFAST)
	state.set_upgrade("intern_box_runs", 3)
	assert_eq(Formulas.intern_run_size(state), 3)
	state.set_upgrade("intern_speed", 10)
	assert_almost_eq(Formulas.intern_speed(state), GameConfig.INTERN_SPEED * (1.0 + 10 * GameConfig.INTERN_SPEED_STEP), 0.001)
	assert_almost_eq(Formulas.intern_trip_time(state), layout.intern_trip_length() / Formulas.intern_speed(state), 0.001)
	for upgrade_id: String in ["intern_steadfast", "intern_speed", "intern_box_runs"]:
		state.set_upgrade(upgrade_id, 0)
	state.money = 1.0e9
	state.reputation = 1.0e6
	assert_eq(Progression.upgrade_block_reason(state, "intern_steadfast"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "intern_speed"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "intern_box_runs"), "requires")
	_complaint_desk(1)
	assert_eq(Progression.upgrade_block_reason(state, "intern_steadfast"), "")
	assert_eq(Progression.upgrade_block_reason(state, "intern_speed"), "")
	assert_eq(Progression.upgrade_block_reason(state, "intern_box_runs"), "requires")
	_complaint_desk(2)
	assert_eq(Progression.upgrade_block_reason(state, "intern_box_runs"), "")


func test_intern_speed_offers_many_levels() -> void:
	var max_level := int(GameConfig.upgrade("intern_speed").max)
	assert_gte(max_level, 50)
	_complaint_desk(1)
	state.money = 1.0e12
	state.reputation = 1.0e6
	var actions := game_actions()
	var previous := 0.0
	for level in max_level:
		var cost := Formulas.track_cost("intern_speed", level)
		assert_gt(cost, previous)
		previous = cost
		var money := state.money
		assert_true(actions.buy_upgrade("intern_speed"), str(level))
		assert_almost_eq(state.money, money - cost, 0.01)
	assert_eq(state.upgrade_level("intern_speed"), max_level)
	assert_eq(Progression.upgrade_block_reason(state, "intern_speed"), "max")
	assert_false(actions.buy_upgrade("intern_speed"))
	assert_almost_eq(Formulas.intern_speed(state), GameConfig.INTERN_SPEED * (1.0 + max_level * GameConfig.INTERN_SPEED_STEP), 0.001)


func test_intern_carries_several_complaints_per_run() -> void:
	_complaint_desk(2)
	state.set_upgrade("intern_box_runs", 3)
	state.complaints = 5
	var runner := state.interns[1]
	var elapsed := 0.0
	while runner.mood != ComplaintIntern.Mood.FROM_SHREDDER and elapsed < 30.0:
		sim.tick(0.1)
		elapsed += 0.1
	assert_eq(runner.mood, ComplaintIntern.Mood.FROM_SHREDDER)
	assert_eq(state.complaints, 2)
	assert_eq(state.complaints_shredded, 3)
	assert_eq(runner.carried, 0)


func test_faster_interns_finish_the_run_sooner() -> void:
	_complaint_desk(2)
	state.set_upgrade("intern_box_runs", 1)
	var slow := _intern_trip_seconds()
	state.set_upgrade("intern_speed", int(GameConfig.upgrade("intern_speed").max))
	var fast := _intern_trip_seconds()
	assert_lt(fast, slow)
	state.complaints = 1
	_run(fast + 1.0, 0.1)
	assert_eq(state.complaints_shredded, 1)
	assert_eq(state.interns[1].mood, ComplaintIntern.Mood.DESK)


func test_crying_intern_waits_for_comfort() -> void:
	_complaint_desk(1)
	var intern := state.interns[0]
	intern.mood = ComplaintIntern.Mood.CRYING
	intern.handled = Formulas.intern_steadfast(state)
	intern.position = layout.intern_cry_point()
	_run(120.0, 0.5)
	assert_eq(intern.mood, ComplaintIntern.Mood.CRYING)
	assert_eq(intern.handled, Formulas.intern_steadfast(state))


func test_player_comforts_a_crying_intern() -> void:
	_complaint_desk(1)
	var intern := state.interns[0]
	intern.mood = ComplaintIntern.Mood.CRYING
	intern.handled = Formulas.intern_steadfast(state)
	intern.position = layout.intern_cry_point()
	state.player.position = intern.position
	watch_signals(sim)
	_run(GameConfig.INTERN_COMFORT_TIME + 0.5, 0.25)
	assert_ne(intern.mood, ComplaintIntern.Mood.CRYING)
	assert_eq(intern.handled, 0)
	assert_signal_emitted_with_parameters(sim, "intern_recovered", [0, true])


func test_interns_share_the_complaints() -> void:
	_complaint_desk(2)
	watch_signals(sim)
	for i in 3:
		sim.submit_complaint()
	assert_eq(state.complaints_absorbed, 3)
	assert_eq(state.complaints, 0)
	assert_eq(state.interns[0].handled, 2)
	assert_eq(state.interns[1].handled, 1)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.TO_LOO)
	assert_eq(state.breakdowns, 1)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [0])
	assert_signal_emitted_with_parameters(sim, "complaint_absorbed", [0])


func test_complaints_land_in_the_box_once_every_intern_is_crying() -> void:
	_complaint_desk(2)
	for unit in state.interns:
		unit.mood = ComplaintIntern.Mood.CRYING
	sim.submit_complaint()
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_absorbed, 0)
	state.interns[1].mood = ComplaintIntern.Mood.DESK
	sim.submit_complaint()
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_absorbed, 1)
	assert_eq(state.interns[1].handled, 1)


func test_full_box_sends_complaints_online() -> void:
	state.complaints = Formulas.complaint_cap(state)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY)
	assert_eq(GameConfig.COMPLAINT_BOX_CAPACITY, 6)
	watch_signals(sim)
	sim.submit_complaint()
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [true])
	assert_eq(state.complaints, Formulas.complaint_cap(state))
	assert_eq(state.negative_review_count(), 1)


func test_interns_follow_the_track_and_survive_saving() -> void:
	_complaint_desk(GameConfig.MAX_DESK_INTERNS)
	assert_eq(state.interns.size(), GameConfig.MAX_DESK_INTERNS)
	for index in state.interns.size():
		assert_eq(state.interns[index].slot, index)
	state.interns[1].handled = 1
	state.interns[1].mood = ComplaintIntern.Mood.CRYING
	state.interns[2].mood = ComplaintIntern.Mood.TO_BOX
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.interns.size(), GameConfig.MAX_DESK_INTERNS)
	assert_eq(restored.interns[1].handled, 1)
	assert_eq(restored.interns[1].mood, ComplaintIntern.Mood.CRYING)
	assert_eq(restored.interns[2].slot, 2)
	assert_eq(restored.interns[2].mood, ComplaintIntern.Mood.RETURNING)
	assert_eq(restored.interns_at_desk(), 1)
	data.interns[0].handled = 99
	assert_eq(GameState.from_dict(data).interns[0].handled, GameConfig.INTERN_MAX_STEADFAST)
	_complaint_desk(1)
	assert_eq(state.interns.size(), 1)
	assert_eq(GameState.from_dict(data).interns.size(), GameConfig.MAX_DESK_INTERNS)
	assert_eq(GameState.from_dict(state.to_dict()).interns.size(), 1)


func test_angry_visitor_yells_at_the_least_worn_intern() -> void:
	_complaint_desk(2)
	state.interns[0].handled = 1
	var visitor := sim.spawn_visitor(true, false)
	assert_false(visitor.is_stopped())
	visitor.position = layout.visitor_spot(visitor.slot)
	_run(GameConfig.VISITOR_ANGRY_TALK_SECONDS + 1.0, 0.5)
	assert_eq(state.interns[1].handled, 1)
	assert_eq(state.interns[0].handled, 1)
	assert_eq(state.complaints_absorbed, 1)
	assert_eq(state.complaints, 0)


func _leaver() -> CaseFile:
	var waiting := _case("general_services")
	waiting.phase = CaseFile.Phase.WAITING
	waiting.seated = true
	waiting.place = state.free_place(true)
	waiting.waited = GameConfig.SEAT_PATIENCE
	state.citizens.append(waiting)
	return waiting


func test_leaving_citizen_files_a_complaint() -> void:
	var leaver := _leaver()
	leaver.spot = Vector2(321, 654)
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 1)
	assert_eq(state.visitors.size(), 1)
	assert_true(state.visitors[0].angry)
	assert_true(state.visitors[0].files_complaint)
	assert_eq(state.visitors[0].position, Vector2(321, 654))


func test_leaving_citizen_files_directly_when_no_slot_is_free() -> void:
	for i in GameConfig.VISITOR_SLOTS:
		sim.spawn_visitor(false, false)
	_leaver()
	sim.tick(0.1)
	assert_eq(state.complaints + state.complaints_absorbed, 1)
	assert_eq(state.visitors.size(), GameConfig.VISITOR_SLOTS)


func test_every_leaver_complains() -> void:
	for i in 5:
		_leaver()
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 5)
	assert_eq(state.visitors.size() + state.complaints, 5)
	assert_eq(state.leave_complaint_cooldown, 0.0)


func test_full_complaint_box_turns_leavers_into_reviews() -> void:
	for i in GameConfig.VISITOR_SLOTS:
		sim.spawn_visitor(false, false)
	state.complaints = Formulas.complaint_cap(state)
	var reviews := state.reviews.size()
	_leaver()
	sim.tick(0.1)
	assert_eq(state.reviews.size(), reviews + 1)
	assert_lte(state.reviews.back().stars, GameConfig.REVIEW_NEGATIVE_MAX_STARS)


func test_only_some_leavers_complain() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	var attempts := 400
	var complained := 0
	for i in attempts:
		state.leave_complaint_cooldown = 0.0
		state.visitors.clear()
		if sim.complain_after_leaving(GameConfig.LEAVE_COMPLAINT_CHANCE, false):
			complained += 1
	var expected := attempts * GameConfig.LEAVE_COMPLAINT_CHANCE
	assert_between(complained, int(expected * 0.6), int(expected * 1.4))
	assert_eq(state.complaints, 0)


func test_complaint_box_track_raises_the_cap() -> void:
	var step := int(GameConfig.upgrade("complaint_box").step)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY)
	state.set_upgrade("complaint_box", 3)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + 3 * step)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	sim.file_complaint()
	assert_eq(state.complaints, GameConfig.COMPLAINT_BOX_CAPACITY + 1)


func test_new_intern_and_review_texts_exist() -> void:
	var keys: Array[String] = ["FMT_INTERN_NAME", "FMT_INTERN_STATUS", "FMT_REVIEWS_TITLE", "ACTION_REVIEW_DELETE", "ACTION_REVIEW_SUE", "FLOAT_REVIEW_POSTED", "FLOAT_REVIEW_DELETED", "FLOAT_REVIEW_WON", "FLOAT_REVIEW_LOST"]
	for upgrade_id: String in ["complaint_interns", "intern_steadfast", "intern_speed", "complaint_box", "intern_box_runs", "complaint_security", "security_training", "shredder_blades"]:
		keys.append("TRACK_" + upgrade_id.to_upper())
		keys.append("TRACK_DESC_" + upgrade_id.to_upper())
		assert_true(Icons.UPGRADES.has(upgrade_id), upgrade_id)
		assert_true(GameConfig.UPGRADES.has(upgrade_id), upgrade_id)
	for mood in ComplaintIntern.Mood.keys():
		keys.append("INTERN_MOOD_" + str(mood))
	for key in keys:
		assert_ne(TranslationServer.translate(key), key, key)
