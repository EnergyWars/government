extends GutTest

const ALWAYS_COMPLAINS := 4.0

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


func test_demand_grows_with_success() -> void:
	assert_eq(Formulas.demand_growth(state), 1.0)
	state.cases_completed = 200
	assert_almost_eq(Formulas.demand_growth(state), 1.0 + GameConfig.DEMAND_GROWTH_SCALE * log(2.0) / log(10.0), 0.0001)
	var dept := state.department("general_services")
	var before := Formulas.arrival_interval(state, dept)
	state.cases_completed = 5000
	assert_lt(Formulas.arrival_interval(state, dept), before)


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
	assert_false(counter.has_reject_pile())
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


func test_shredder_intern_also_shreds_rejects() -> void:
	state.research["shredder_service"] = 1
	var review := state.station("general_services/review")
	review.rejects = 2
	_run(GameConfig.SHREDDER_DELAYS[1] + 6.0)
	assert_eq(review.rejects, 1)
	assert_eq(state.rejects_waiting(), 1)


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
	assert_eq(GameState.from_dict(data).station(GameConfig.COUNTER).rejects, 0)


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
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	var review := state.station("general_services/review")
	review.outbox.append(_case("general_services", 1))
	watch_signals(sim)
	sim.tick(0.05)
	assert_signal_emitted_with_parameters(sim, "case_piped", ["general_services/review", "general_services/signature", "general_services"])
	assert_true(review.outbox.is_empty())


func test_every_event_is_well_formed() -> void:
	for event_id in GameConfig.EVENTS:
		var event: Dictionary = GameConfig.EVENTS[event_id]
		assert_true(event.has("arrival") and event.has("department") and event.has("min_cases"), event_id)
		var mitigation := str(event.get("mitigation", ""))
		if not mitigation.is_empty():
			assert_true(GameConfig.RESEARCH.has(mitigation), event_id)
		assert_gt(Formulas.event_duration(state, event_id), 0.0, event_id)
	assert_gte(GameConfig.EVENTS.size(), 15)


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
	state.event_id = "rush_hour"
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


func test_events_change_drowsiness_and_patience() -> void:
	var review := state.station("general_services/review")
	var base_rate := Formulas.drowsiness_rate(state, review)
	var base_patience := Formulas.patience(state)
	state.event_id = "coffee_escalation"
	assert_eq(Formulas.drowsiness_rate(state, review), base_rate * 3.0)
	state.event_id = "monday_rush"
	assert_almost_eq(Formulas.patience(state), base_patience * 0.6, 0.0001)
	assert_eq(Formulas.event_arrival_multiplier(state, "general_services"), 2.5)
	state.event_id = ""
	assert_eq(Formulas.event_drowsy(state), 1.0)
	assert_eq(Formulas.event_patience(state), 1.0)


func test_renovation_and_ducks_affect_only_their_department() -> void:
	state.event_id = "renovation"
	state.event_scope = "housing"
	assert_eq(Formulas.event_arrival_multiplier(state, "housing"), 0.5)
	assert_eq(Formulas.event_arrival_multiplier(state, "general_services"), 1.0)
	state.event_id = "rubber_ducks"
	state.event_scope = "customs"
	assert_eq(Formulas.event_arrival_multiplier(state, "customs"), 1.0)


func test_research_shortens_mitigated_events() -> void:
	assert_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION)
	state.research["it_support"] = 2
	assert_almost_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION * 0.7, 0.001)
	assert_almost_eq(Formulas.event_duration(state, "fire_drill"), 20.0 * 0.7, 0.001)
	state.research["it_support"] = 3
	assert_almost_eq(Formulas.event_duration(state, "printer_jam"), GameConfig.EVENT_DURATION * 0.55, 0.001)
	assert_eq(Formulas.event_duration(state, "garden_shed"), 90.0)
	assert_eq(Formulas.event_duration(state, "authority_comparison"), GameConfig.EVENT_CHOICE_SECONDS)
	state.research["it_support"] = 0
	state.research["coffee_machine"] = 4
	assert_almost_eq(Formulas.event_duration(state, "coffee_escalation"), GameConfig.EVENT_DURATION * 0.4, 0.001)


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


func test_new_research_is_registered() -> void:
	assert_true(GameConfig.RESEARCH_ORDER.has("it_support"))
	assert_eq(GameConfig.RESEARCH_ORDER.size(), GameConfig.RESEARCH.size())
	assert_true(Icons.RESEARCH.has("it_support"))
	for event_id in GameConfig.EVENTS:
		assert_true(Icons.EVENTS.has(event_id), event_id)


func test_translations_exist_for_new_texts() -> void:
	var keys: Array[String] = ["FMT_JAM", "JAM_SIDE_IN", "JAM_SIDE_OUT", "JAM_SIDE_REJECTS", "LEGEND_MARKERS", "FMT_POPULATION", "EVENT_CHOICE_PREPARE", "EVENT_CHOICE_IGNORE", "EVENT_CHOICE_CANCEL", "RESEARCH_IT_SUPPORT", "RESEARCH_DESC_IT_SUPPORT"]
	for rank in GameConfig.SETTLEMENT_RANKS:
		keys.append("SETTLEMENT_" + str(rank.id).to_upper())
	for index in Flavor.REJECT_COUNT:
		keys.append("REJECT_%d" % (index + 1))
	for key in keys:
		assert_ne(TranslationServer.translate(key), key, key)
	assert_ne(Flavor.reject(0), Flavor.reject(1))


func test_reception_skips_cases_for_saturated_departments() -> void:
	state.unlock_department("social_benefits")
	var reception := state.station(GameConfig.RECEPTION)
	var review := state.station("social_benefits/review")
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(sim.create_case(state.department("social_benefits")))
	var stuck := sim.create_case(state.department("social_benefits"))
	stuck.step = 0
	var other := sim.create_case(state.department("general_services"))
	other.step = 0
	reception.inbox.append_array([stuck, other])
	assert_true(sim.start_job(reception, 0))
	assert_eq(reception.jobs[0].case_file, other)
	assert_true(reception.inbox.has(stuck))


func test_reception_keeps_working_when_only_blocked_cases_wait() -> void:
	state.unlock_department("social_benefits")
	var reception := state.station(GameConfig.RECEPTION)
	var review := state.station("social_benefits/review")
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(sim.create_case(state.department("social_benefits")))
	reception.inbox.append(sim.create_case(state.department("social_benefits")))
	assert_false(sim.start_job(reception, 0))
	review.inbox.pop_back()
	assert_true(sim.start_job(reception, 0))


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


func test_collector_hire_cost_and_limit() -> void:
	state.money = 1.0e9
	var first := Formulas.collector_cost(state)
	assert_true(state.station("shared/counter") != null)
	for i in GameConfig.MAX_COLLECTORS:
		assert_true(game_actions().hire_collector())
	assert_false(game_actions().can_hire_collector())
	assert_eq(state.collectors.size(), GameConfig.MAX_COLLECTORS)
	assert_eq(first, GameConfig.COLLECTOR_COST)


func game_actions() -> GameActions:
	return GameActions.new(state, sim)


func test_collector_brings_rejects_to_shredder() -> void:
	state.add_collector()
	var station := state.station("general_services/review")
	station.rejects = 4
	var money := state.money
	_run(60.0, 0.1)
	assert_eq(station.rejects, 0)
	assert_eq(state.collectors[0].loaded, 0)
	assert_almost_eq(state.money, money + GameConfig.REJECT_SHRED_REWARD * 4.0, 0.001)


func test_collector_idles_without_rejects() -> void:
	var collector := state.add_collector()
	var start := collector.position
	_run(5.0, 0.1)
	assert_eq(collector.loaded, 0)
	assert_lt(collector.position.distance_to(layout.collector_home()), start.distance_to(layout.collector_home()) + 1.0)


func test_two_collectors_split_rejects() -> void:
	state.add_collector()
	state.add_collector()
	state.station("general_services/review").rejects = 6
	sim.tick(0.1)
	assert_ne(state.collectors[0].source, state.collectors[1].source if state.collectors[1].source != "" else "x")


func test_collectors_and_shred_counter_survive_save() -> void:
	var collector := state.add_collector()
	collector.loaded = 2
	state.cases_shredded = 3
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.collectors.size(), 1)
	assert_eq(restored.collectors[0].loaded, 2)
	assert_eq(restored.cases_shredded, 3)


func test_guidance_skips_reject_pickup_when_collector_exists() -> void:
	state.station("general_services/review").rejects = 2
	state.add_collector()
	var task := Guidance.next_task(state)
	assert_ne(task.get("action", ""), Guidance.REJECT)


func test_collector_translations() -> void:
	for key in ["STAFF_COLLECTORS", "STAFF_DESC_COLLECTORS", "FMT_COLLECTOR_INFO"]:
		assert_ne(TranslationServer.translate(key), key, key)


func _reject_piles_by_distance() -> Array[String]:
	var keys: Array[String] = []
	for key in state.ordered_station_keys():
		if state.station(key).has_reject_pile():
			keys.append(key)
	var shredder := layout.shredder_point()
	keys.sort_custom(func(a: String, b: String) -> bool: return shredder.distance_to(layout.reject_point(a)) < shredder.distance_to(layout.reject_point(b)))
	return keys


func test_collector_capacity_grows_with_trolleys() -> void:
	assert_eq(Formulas.collector_capacity(state), GameConfig.COLLECTOR_CAPACITY)
	state.research["trolleys"] = 2
	assert_eq(Formulas.collector_capacity(state), GameConfig.COLLECTOR_CAPACITY + 2 * GameConfig.COLLECTOR_CAPACITY_PER_LEVEL)
	assert_eq(Formulas.collector_capacity_limit(), GameConfig.COLLECTOR_CAPACITY + GameConfig.COLLECTOR_CAPACITY_PER_LEVEL * int(GameConfig.RESEARCH.trolleys.max_level))
	assert_eq(RejectCollector.from_dict({"loaded": 99}, Vector2.ZERO).loaded, Formulas.collector_capacity_limit())
	assert_eq(RejectCollector.from_dict({"loaded": -3}, Vector2.ZERO).loaded, 0)


func test_collector_prefers_nearly_full_piles_over_near_ones() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	var near := state.station(piles[0])
	var far := state.station(piles[piles.size() - 1])
	var collector := state.add_collector()
	collector.position = layout.collector_home()
	var capacity := Formulas.collector_capacity(state)
	near.rejects = 2
	far.rejects = 2
	assert_eq(sim.collector_target(collector, capacity), near.key)
	far.rejects = GameConfig.REJECT_CAPACITY - GameConfig.COLLECTOR_URGENT_MARGIN
	assert_eq(sim.collector_target(collector, capacity), far.key)


func test_collector_skips_far_piles_once_loaded() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	var far_key := piles[piles.size() - 1]
	assert_gt(2.0 * layout.shredder_point().distance_to(layout.reject_point(far_key)), GameConfig.COLLECTOR_MAX_DETOUR)
	var collector := state.add_collector()
	collector.position = layout.shredder_point()
	collector.loaded = 1
	state.station(far_key).rejects = 1
	assert_eq(sim.collector_target(collector, Formulas.collector_capacity(state)), "")
	state.station(far_key).rejects = GameConfig.REJECT_CAPACITY
	assert_eq(sim.collector_target(collector, Formulas.collector_capacity(state)), far_key)
	collector.loaded = Formulas.collector_capacity(state)
	assert_eq(sim.collector_target(collector, Formulas.collector_capacity(state)), "")


func test_collector_keeps_collecting_until_full() -> void:
	_unlock_all()
	var piles := _reject_piles_by_distance()
	var first := state.station(piles[0])
	var second := state.station(piles[1])
	first.rejects = 1
	second.rejects = GameConfig.REJECT_CAPACITY
	var collector := state.add_collector()
	collector.position = layout.reject_point(first.key)
	collector.source = first.key
	sim.tick(0.05)
	assert_eq(collector.loaded, 1)
	assert_eq(first.rejects, 0)
	sim.tick(0.05)
	assert_eq(collector.source, second.key)
	_run(120.0, 0.1)
	assert_eq(second.rejects, 0)
	assert_eq(collector.loaded, 0)
	assert_eq(state.production.total(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF), GameConfig.REJECT_CAPACITY + 1)


func test_collector_handles_a_vanished_pile() -> void:
	var collector := state.add_collector()
	collector.source = "nope"
	collector.position = layout.reject_point("nope")
	sim.tick(0.05)
	assert_eq(collector.source, "")
	assert_eq(collector.loaded, 0)


func test_roller_skates_speed_up_collectors() -> void:
	assert_eq(sim._collector_speed(), GameConfig.COLLECTOR_SPEED)
	state.boosts["roller_skates"] = 10.0
	assert_eq(sim._collector_speed(), GameConfig.COLLECTOR_SPEED * GameConfig.BOOST_RUNNER_SPEED)


func _fill_outbox(count: int) -> Station:
	var review := state.station("general_services/review")
	for i in count:
		review.outbox.append(_case("general_services", 1))
	return review


func test_tube_capacity_formula_and_research_gate() -> void:
	assert_eq(Formulas.tube_capacity(state), GameConfig.TUBE_BASE_CAPACITY)
	state.research["tube_capacity"] = 2
	assert_eq(Formulas.tube_capacity(state), GameConfig.TUBE_BASE_CAPACITY + 2 * GameConfig.TUBE_CAPACITY_PER_LEVEL)
	state.research["tube_capacity"] = 0
	state.money = 1.0e9
	state.reputation = 1.0e6
	assert_eq(Progression.research_block_reason(state, "tube_capacity"), "requires")
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	assert_eq(Progression.research_block_reason(state, "tube_capacity"), "")
	state.research["tube_capacity"] = 3
	assert_eq(Progression.research_block_reason(state, "tube_capacity"), "max")


func test_tube_holds_only_its_capacity() -> void:
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	var review := _fill_outbox(5)
	sim.tick(0.05)
	assert_eq(state.tube_parcels.size(), GameConfig.TUBE_BASE_CAPACITY)
	assert_eq(review.outbox.size(), 5 - GameConfig.TUBE_BASE_CAPACITY)


func test_tube_upgrade_raises_load() -> void:
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	state.research["tube_capacity"] = 1
	var review := _fill_outbox(8)
	sim.tick(0.05)
	assert_eq(state.tube_parcels.size(), Formulas.tube_capacity(state))
	assert_eq(review.outbox.size(), 8 - Formulas.tube_capacity(state))


func test_parcels_arrive_and_free_the_tube() -> void:
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	var review := _fill_outbox(4)
	var target := state.station("general_services/signature")
	_run(0.05)
	_run(3.5, 0.1)
	assert_true(review.outbox.is_empty())
	assert_true(state.tube_parcels.is_empty())
	assert_eq(target.inbox.size() + target.active_jobs() + target.outbox.size(), 4)


func test_parcel_waits_when_target_is_full() -> void:
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
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
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	_fill_outbox(2)
	sim.tick(0.05)
	assert_eq(state.carried_cases().size(), 2)
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.tube_parcels.size(), 2)
	assert_eq(restored.tube_parcels[0].tube_id(), state.tube_parcels[0].tube_id())
	assert_null(TubeParcel.from_dict({"from": "", "to": "x", "case": {}}))
	assert_null(TubeParcel.from_dict("bad"))


func test_tube_capacity_texts_and_icon_exist() -> void:
	assert_true(Icons.RESEARCH.has("tube_capacity"))
	for key in ["RESEARCH_TUBE_CAPACITY", "RESEARCH_DESC_TUBE_CAPACITY", "FMT_REQ_RESEARCH", "FMT_TUBE_CAPACITY"]:
		assert_ne(TranslationServer.translate(key), key, key)


func test_intern_walks_to_the_shredder_and_back() -> void:
	state.research["shredder_service"] = 3
	state.complaints = 1
	var delay: float = GameConfig.SHREDDER_DELAYS[3]
	_run(delay + 0.5, 0.1)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.TO_SHREDDER)
	assert_eq(state.complaints, 1)
	_run(5.0, 0.1)
	assert_eq(state.complaints, 0)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.DESK)
	assert_eq(state.intern.position, layout.intern_home())


func test_intern_training_formulas_and_gate() -> void:
	assert_eq(Formulas.intern_capacity(state), 1)
	assert_eq(Formulas.intern_stress_free(state), GameConfig.INTERN_STRESS_FREE)
	assert_almost_eq(Formulas.intern_cry_seconds(state), GameConfig.INTERN_CRY_SECONDS, 0.001)
	assert_eq(Formulas.intern_stress_factor(state), 1.0)
	state.research["intern_training"] = 2
	assert_eq(Formulas.intern_capacity(state), 3)
	assert_eq(Formulas.intern_stress_free(state), GameConfig.INTERN_STRESS_FREE + 2)
	assert_almost_eq(Formulas.intern_cry_seconds(state), GameConfig.INTERN_CRY_SECONDS * 0.49, 0.001)
	assert_almost_eq(Formulas.intern_stress_factor(state), 0.5625, 0.0001)
	state.research["intern_training"] = 0
	state.money = 1.0e9
	state.reputation = 1.0e6
	assert_eq(Progression.research_block_reason(state, "intern_training"), "requires")


func test_intern_training_offers_many_levels() -> void:
	var max_level := int(GameConfig.RESEARCH.intern_training.max_level)
	assert_gte(max_level, 8)
	state.research["shredder_service"] = 1
	state.money = 1.0e12
	state.reputation = 1.0e6
	var actions := game_actions()
	var previous := 0.0
	for level in max_level:
		var cost := Formulas.research_cost("intern_training", level)
		assert_gt(cost, previous)
		previous = cost
		var money := state.money
		assert_true(actions.buy_research("intern_training"), str(level))
		assert_almost_eq(state.money, money - cost, 0.01)
	assert_eq(state.research_level("intern_training"), max_level)
	assert_eq(Progression.research_block_reason(state, "intern_training"), "max")
	assert_false(actions.buy_research("intern_training"))
	assert_eq(Formulas.intern_capacity(state), 1 + max_level)
	assert_lt(Formulas.intern_stress_factor(state), 0.15)


func test_trained_intern_shreds_several_per_trip() -> void:
	state.research["shredder_service"] = 3
	state.research["intern_training"] = 2
	state.complaints = 5
	_run(GameConfig.SHREDDER_DELAYS[3] + 6.0, 0.1)
	assert_eq(state.complaints, 2)


func test_intern_stops_crying_by_himself() -> void:
	state.research["shredder_service"] = 1
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	_run(GameConfig.INTERN_CRY_SECONDS + 1.0, 0.5)
	assert_ne(state.intern.mood, ComplaintIntern.Mood.CRYING)
	assert_lte(GameConfig.INTERN_CRY_SECONDS, 20.0)


func test_helpers_share_stress_and_work() -> void:
	state.research["shredder_service"] = 1
	state.money = 1.0e9
	assert_true(game_actions().hire_helper())
	assert_eq(state.all_interns().size(), 2)
	assert_eq(state.helpers[0].slot, 1)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	_run(10.0, 0.5)
	var solo := (GameConfig.COMPLAINT_BOX_CAPACITY - GameConfig.INTERN_STRESS_FREE) * GameConfig.INTERN_STRESS_RATE * 10.0
	assert_lt(state.intern.stress, solo)


func test_helper_hiring_limits_and_save() -> void:
	state.money = 1.0e9
	assert_false(game_actions().can_hire_helper())
	state.research["shredder_service"] = 1
	for i in GameConfig.MAX_HELPERS:
		assert_true(game_actions().hire_helper())
	assert_false(game_actions().can_hire_helper())
	state.helpers[1].stress = 0.4
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.helpers.size(), GameConfig.MAX_HELPERS)
	assert_almost_eq(restored.helpers[1].stress, 0.4, 0.001)
	assert_eq(restored.helpers[1].slot, 2)
	assert_eq(Formulas.helper_cost(state), GameConfig.HELPER_COST * pow(GameConfig.HELPER_GROWTH, GameConfig.MAX_HELPERS))


func test_angry_visitor_stresses_the_calmest_intern() -> void:
	state.research["shredder_service"] = 1
	state.add_helper()
	state.intern.stress = 0.5
	var visitor := sim.spawn_visitor(true, false)
	visitor.phase = ComplaintVisitor.Phase.TO_INTERNS
	visitor.position = layout.vent_spot(visitor.slot)
	_run(3.0, 0.5)
	assert_gt(state.helpers[0].stress, 0.0)


func _leaver(patience_factor: float = 1.0) -> CaseFile:
	var waiting := _case("general_services")
	waiting.patience_factor = patience_factor
	waiting.waited = Formulas.citizen_patience(state, waiting)
	state.station(GameConfig.RECEPTION).inbox.append(waiting)
	return waiting


func test_patient_leaver_files_a_complaint() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	_leaver(ALWAYS_COMPLAINS)
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 1)
	assert_eq(state.visitors.size(), 1)
	assert_false(state.visitors[0].angry)
	assert_true(state.visitors[0].files_complaint)


func test_leaving_citizen_without_experience_does_not_complain() -> void:
	_leaver(ALWAYS_COMPLAINS)
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 1)
	assert_eq(state.visitors.size() + state.complaints, 0)


func test_leaving_citizen_files_directly_when_no_slot_is_free() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for i in GameConfig.VISITOR_SLOTS:
		sim.spawn_visitor(false, false)
	_leaver(ALWAYS_COMPLAINS)
	sim.tick(0.1)
	assert_eq(state.complaints + state.complaints_fended, 1)
	assert_eq(state.visitors.size(), GameConfig.VISITOR_SLOTS)


func test_complaints_of_leavers_are_bundled() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for i in 5:
		_leaver(ALWAYS_COMPLAINS)
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 5)
	assert_eq(state.visitors.size() + state.complaints, 1)
	assert_almost_eq(state.leave_complaint_cooldown, GameConfig.LEAVE_COMPLAINT_COOLDOWN - 0.1, 0.0001)
	state.leave_complaint_cooldown = 0.05
	_leaver(ALWAYS_COMPLAINS)
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 6)
	assert_eq(state.visitors.size() + state.complaints, 1)
	assert_eq(state.leave_complaint_cooldown, 0.0)
	_leaver(ALWAYS_COMPLAINS)
	sim.tick(0.1)
	assert_eq(state.citizens_lost, 7)
	assert_eq(state.visitors.size() + state.complaints, 2)


func test_only_some_leavers_complain() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	var attempts := 400
	var complained := 0
	for i in attempts:
		state.leave_complaint_cooldown = 0.0
		state.visitors.clear()
		if sim.complain_after_leaving(Formulas.leave_complaint_chance(_case("general_services")), false):
			complained += 1
	var expected := attempts * GameConfig.LEAVE_COMPLAINT_CHANCE
	assert_between(complained, int(expected * 0.6), int(expected * 1.4))
	assert_eq(state.complaints, 0)


func test_complaint_box_level_raises_the_cap() -> void:
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY)
	state.complaint_box_level = 3
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + 3 * GameConfig.COMPLAINT_BOX_PER_LEVEL)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	sim.file_complaint()
	assert_eq(state.complaints, GameConfig.COMPLAINT_BOX_CAPACITY + 1)


func test_complaint_tube_sends_complaints_slowly() -> void:
	state.research["shredder_service"] = 1
	state.research["complaint_tube"] = 2
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	state.complaints = 3
	watch_signals(sim)
	var delay: float = GameConfig.COMPLAINT_TUBE_DELAYS[2]
	_run(delay - 1.0, 0.5)
	assert_eq(state.complaints, 3)
	_run(2.0, 0.5)
	assert_eq(state.complaints, 2)
	assert_signal_emitted(sim, "complaint_piped")
	assert_eq(state.complaints_shredded, 1)


func test_complaint_tube_idle_without_research_or_complaints() -> void:
	state.complaints = 2
	_run(100.0, 1.0)
	assert_eq(state.complaints, 2)
	assert_eq(state.complaint_tube_timer, 0.0)
	state.research["complaint_tube"] = 1
	state.complaints = 0
	_run(100.0, 1.0)
	assert_eq(state.complaint_tube_timer, 0.0)


func test_complaint_tube_is_slower_than_intern_and_gated() -> void:
	assert_eq(GameConfig.COMPLAINT_TUBE_DELAYS.size(), int(GameConfig.RESEARCH.complaint_tube.max_level) + 1)
	for level in range(2, 4):
		assert_lt(GameConfig.COMPLAINT_TUBE_DELAYS[level], GameConfig.COMPLAINT_TUBE_DELAYS[level - 1])
	assert_gt(GameConfig.COMPLAINT_TUBE_DELAYS[3], GameConfig.SHREDDER_DELAYS[3])
	state.money = 1.0e9
	state.reputation = 1.0e6
	assert_eq(Progression.research_block_reason(state, "complaint_tube"), "requires")
	assert_gt(layout.complaint_tube_path().size(), 2)


func test_new_intern_and_review_texts_exist() -> void:
	var keys: Array[String] = ["STAFF_HELPERS", "STAFF_DESC_HELPERS", "FMT_HELPER_INFO", "LABEL_NEEDS_SHREDDER_SERVICE", "RESEARCH_COMPLAINT_TUBE", "RESEARCH_DESC_COMPLAINT_TUBE", "RESEARCH_INTERN_TRAINING", "RESEARCH_DESC_INTERN_TRAINING", "FMT_REVIEWS_TITLE", "ACTION_REVIEW_DELETE", "ACTION_REVIEW_SUE", "FLOAT_REVIEW_POSTED", "FLOAT_REVIEW_DELETED", "FLOAT_REVIEW_WON", "FLOAT_REVIEW_LOST"]
	for key in keys:
		assert_ne(TranslationServer.translate(key), key, key)
	for research_id in ["complaint_tube", "intern_training"]:
		assert_true(Icons.RESEARCH.has(research_id))
		assert_true(GameConfig.RESEARCH_ORDER.has(research_id))
