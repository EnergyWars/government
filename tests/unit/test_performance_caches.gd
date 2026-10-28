extends GutTest

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(21)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()


func _case(dept_id: String = "general_services", step: int = 1) -> CaseFile:
	var case_file := sim.create_case(state.department(dept_id))
	case_file.step = step
	return case_file


func test_upgrade_value_cache_follows_every_purchase() -> void:
	var base := state.upgrade_value("seating")
	assert_eq(base, Formulas.track_value("seating", 0))
	state.set_upgrade("seating", 3)
	assert_eq(state.upgrade_value("seating"), Formulas.track_value("seating", 3))
	assert_eq(Formulas.upgrade_value(state, "seating"), state.upgrade_value("seating"))
	state.set_upgrade("seating", 0)
	assert_eq(state.upgrade_value("seating"), base)


func test_room_upgrade_values_are_cached_per_room() -> void:
	state.set_upgrade("room_speed", 2, "general_services")
	assert_eq(state.upgrade_value("room_speed", "general_services"), Formulas.track_value("room_speed", 2))
	assert_eq(state.upgrade_value("room_speed", "tax_services"), Formulas.track_value("room_speed", 0))
	state.set_upgrade("room_speed", 1, "tax_services")
	assert_eq(state.upgrade_value("room_speed", "tax_services"), Formulas.track_value("room_speed", 1))
	assert_eq(state.upgrade_value("room_speed", "general_services"), Formulas.track_value("room_speed", 2))
	state.set_upgrade("lead_focus", 3, GameConfig.ROOM_HALL)
	assert_eq(state.upgrade_value("lead_focus", GameConfig.ROOM_HALL), Formulas.track_value("lead_focus", 3))
	assert_eq(state.upgrade_value("lead_focus", "general_services"), Formulas.track_value("lead_focus", 0))
	assert_eq(state.upgrade_value("room_speed", "general_services"), Formulas.track_value("room_speed", 2))


func test_office_rooms_are_cached() -> void:
	assert_same(GameConfig.office_rooms(), GameConfig.office_rooms())
	assert_false(GameConfig.office_rooms().is_empty())


func test_tray_sizes_follow_room_tray_purchases() -> void:
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	var reception := state.station(GameConfig.RECEPTION)
	assert_eq(review.tray_size, GameConfig.TRAY_BASE)
	state.set_upgrade("room_trays", 4, "general_services")
	assert_eq(review.tray_size, GameConfig.TRAY_BASE + 4)
	assert_eq(signature.tray_size, GameConfig.TRAY_BASE + 4)
	assert_eq(reception.tray_size, GameConfig.TRAY_BASE)
	assert_eq(review.outbox_capacity(), GameConfig.TRAY_BASE + 4)
	assert_eq(review.inbox_capacity(state.lobby_capacity()), GameConfig.TRAY_BASE + 4)
	review.add_desk()
	assert_eq(review.outbox_capacity(), GameConfig.TRAY_BASE + 4)
	state.set_upgrade("room_trays", 999, "general_services")
	assert_eq(review.tray_size, GameConfig.TRAY_MAX)
	state.set_upgrade("room_trays", 2, GameConfig.ROOM_HALL)
	assert_eq(reception.tray_size, GameConfig.TRAY_BASE + 2)
	assert_eq(state.station(GameConfig.COUNTER).tray_size, GameConfig.TRAY_BASE + 2)
	state.set_upgrade("room_trays", 0, "general_services")
	assert_eq(review.tray_size, GameConfig.TRAY_BASE)


func test_new_stations_get_their_room_tray_size() -> void:
	state.set_upgrade("room_trays", 3, "tax_services")
	state.set_upgrade("room_trays", 5, GameConfig.ROOM_MAIL)
	state.unlock_department("tax_services")
	assert_eq(state.station("tax_services/review").tray_size, GameConfig.TRAY_BASE + 3)
	assert_eq(state.station("tax_services/signature").tray_size, GameConfig.TRAY_BASE + 3)
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	var mailroom := state.ensure_mailroom()
	assert_not_null(mailroom)
	assert_eq(mailroom.tray_size, GameConfig.TRAY_BASE + 5)
	assert_eq(mailroom.outbox_capacity(), GameConfig.TRAY_BASE + 5)
	state.set_upgrade("room_trays", 7, "general_services")
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.station("general_services/review").tray_size, GameConfig.TRAY_BASE + 7)
	assert_eq(loaded.station("tax_services/review").tray_size, GameConfig.TRAY_BASE + 3)
	assert_eq(loaded.station(GameConfig.RECEPTION).tray_size, GameConfig.TRAY_BASE)


func test_room_stations_and_max_room_speed() -> void:
	state.unlock_department("tax_services")
	var keys: Array[String] = []
	for station in state.room_stations("general_services"):
		keys.append(station.key)
	assert_eq(keys, ["general_services/review", "general_services/signature"] as Array[String])
	var hall: Array[String] = []
	for station in state.room_stations(GameConfig.ROOM_HALL):
		hall.append(station.key)
	assert_has(hall, GameConfig.RECEPTION)
	assert_has(hall, GameConfig.COUNTER)
	assert_eq(hall.size(), 2)
	assert_true(state.room_stations(GameConfig.ROOM_KITCHEN).is_empty())
	assert_eq(state.max_room_speed(), 0)
	state.set_upgrade("room_speed", 3, "tax_services")
	state.set_upgrade("room_speed", 7, GameConfig.ROOM_HALL)
	assert_eq(state.max_room_speed(), 7)


func test_tube_links_follow_station_purchases() -> void:
	var from := GameConfig.RECEPTION
	var to := "general_services/review"
	assert_false(state.tube_link(from, to))
	assert_false(state.has_tube_station(GameConfig.ROOM_HALL))
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	assert_true(state.has_tube_station(GameConfig.ROOM_HALL))
	assert_false(state.tube_link(from, to))
	state.set_upgrade("tube_station", 1, "general_services")
	assert_true(state.tube_link(from, to))
	assert_false(state.tube_link("", to))
	assert_false(state.tube_link(from, ""))
	state.set_upgrade("pneumatic_tubes", 0)
	assert_false(state.tube_link(from, to))
	assert_false(state.has_tube_station(GameConfig.ROOM_HALL))


func test_unlocked_departments_refresh_when_a_department_opens() -> void:
	var before := state.unlocked_departments()
	assert_eq(before.size(), 1)
	assert_same(state.unlocked_departments(), before)
	state.unlock_department("tax_services")
	var after := state.unlocked_departments()
	assert_eq(after.size(), 2)
	assert_eq(after[1].id, "tax_services")
	state.department("tax_services").unlocked = false
	assert_eq(state.unlocked_departments().size(), 1)


func test_places_count_only_citizens_in_the_hall() -> void:
	state.station("general_services/review").inbox.append(_case())
	var seated := _case()
	seated.phase = CaseFile.Phase.WAITING
	seated.seated = true
	seated.place = 0
	var standing := _case()
	standing.phase = CaseFile.Phase.WAITING_DOC
	standing.place = 3
	var reserved := _case()
	reserved.phase = CaseFile.Phase.SERVED
	reserved.seated = true
	reserved.place = 1
	state.citizens.append_array([seated, standing, reserved])
	assert_eq(state.seated_citizens(), 2)
	assert_eq(state.standing_citizens(), 0)
	assert_eq(state.standing_citizens(GameConfig.HALL_PICKUP), 1)
	assert_eq(state.seated_citizens(GameConfig.HALL_PICKUP), 0)
	assert_eq(state.free_place(true), 2)
	assert_eq(state.free_place(false), 0)
	assert_eq(state.free_place(true, GameConfig.HALL_PICKUP), 0)
	assert_eq(state.places_left(GameConfig.HALL_INTAKE), GameConfig.WAITING_PLACES - 2)
	assert_eq(state.places_left(GameConfig.HALL_PICKUP), GameConfig.WAITING_PLACES - 1)
	assert_true(seated.is_in_hall())
	assert_false(reserved.is_in_hall())


func test_department_flow_matches_bottleneck_and_throughput() -> void:
	state.unlock_department("tax_services")
	for dept in state.unlocked_departments():
		var flow := Formulas.department_flow(state, dept)
		assert_eq(str(flow.bottleneck), Formulas.bottleneck(state, dept))
		assert_eq(float(flow.throughput), Formulas.department_throughput(state, dept))
		var expected := minf(Formulas.demand(state, dept), Formulas.department_transport(state, dept))
		for key in RouteBuilder.required_stations(dept.id):
			expected = minf(expected, Formulas.station_share(state, state.station(key), dept))
		assert_almost_eq(float(flow.throughput), expected, 0.000001)


func test_department_flow_without_a_station_has_no_throughput() -> void:
	var dept := state.department("general_services")
	state.stations.erase("general_services/signature")
	var flow := Formulas.department_flow(state, dept)
	assert_eq(float(flow.throughput), 0.0)
	assert_ne(str(flow.bottleneck), "general_services/signature")


func test_arrival_interval_is_shared_by_all_departments() -> void:
	state.unlock_department("tax_services")
	state.add_review(4)
	for dept in state.unlocked_departments():
		assert_almost_eq(Formulas.demand(state, dept), 1.0 / Formulas.arrival_interval(state), 0.000001)


func test_base_route_is_cached_and_matches_a_fresh_route() -> void:
	for dept_id in GameConfig.department_ids():
		var route := RouteBuilder.base_route(dept_id)
		assert_eq(route, RouteBuilder.build(CaseFile.new(dept_id)))
		assert_same(RouteBuilder.base_route(dept_id), route)


func test_department_config_and_station_keys_are_cached() -> void:
	for entry: Dictionary in GameConfig.DEPARTMENTS:
		assert_eq(GameConfig.department(str(entry.id)), entry)
		assert_same(GameConfig.department_station_keys(str(entry.id)), GameConfig.department_station_keys(str(entry.id)))
	assert_true(GameConfig.department("nope").is_empty())
	assert_true(GameConfig.department_station_keys("nope").is_empty())


func test_desk_reach_covers_every_desk_with_interaction_radius() -> void:
	var key := "general_services/review"
	for count in [1, 3, 9]:
		var reach := layout.desk_reach(key, count)
		assert_same(layout.desk_reach(key, count), reach)
		for desk in count:
			var point := layout.desk_position(key, desk)
			for offset: Vector2 in [Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS, 0), Vector2(0, -GameConfig.INTERACT_RADIUS)]:
				assert_true(reach.has_point(point + offset))
	assert_false(layout.desk_reach(key, 1).has_point(layout.desk_position(key, 0) + Vector2(GameConfig.INTERACT_RADIUS * 2.0, 0)))


func test_reject_detours_are_cached_per_pile() -> void:
	var key := "general_services/review"
	var point := layout.reject_point(key)
	assert_true(sim._reject_detours.is_empty())
	assert_almost_eq(sim._reject_to_shredder(key), point.distance_to(layout.shredder_point()), 0.001)
	assert_true(sim._reject_detours.has(key))
	sim._reject_detours[key] = 123.0
	assert_eq(sim._reject_to_shredder(key), 123.0)
	var other := "tax_services/review"
	assert_almost_eq(sim._reject_to_shredder(other), layout.reject_point(other).distance_to(layout.shredder_point()), 0.001)
	assert_eq(sim._reject_detours.size(), 2)


func test_claimed_sources_ignore_the_asking_reject_runner() -> void:
	var first := state.add_runner(Runner.REJECT)
	var second := state.add_runner(Runner.REJECT)
	first.source = "general_services/review"
	assert_true(sim._claimed_sources(second).has("general_services/review"))
	assert_false(sim._claimed_sources(first).has("general_services/review"))
	assert_true(sim._claimed_sources(first).is_empty())


func test_claimed_sources_only_count_reject_runners_heading_for_a_pile() -> void:
	var asking := state.add_runner(Runner.REJECT)
	var normal := state.add_runner(Runner.INTAKE)
	normal.source = "general_services/review"
	assert_true(sim._claimed_sources(asking).is_empty())
	var carrying := state.add_runner(Runner.REJECT)
	carrying.source = "general_services/review"
	carrying.task = Runner.Task.TO_TARGET
	assert_true(sim._claimed_sources(asking).is_empty())
	carrying.task = Runner.Task.IDLE
	assert_true(sim._claimed_sources(asking).has("general_services/review"))


func test_all_idle_desks_start_work_in_the_same_tick() -> void:
	var review := state.station("general_services/review")
	while review.desks < 3:
		review.add_desk()
	review.staff = 3
	for i in 3:
		review.inbox.append(_case())
	sim._work_stations(GameConfig.TICK)
	for desk in 3:
		assert_not_null(review.jobs[desk])
	assert_true(review.inbox.is_empty())


func test_idle_desks_without_work_stay_empty() -> void:
	var review := state.station("general_services/review")
	while review.desks < 3:
		review.add_desk()
	review.staff = 3
	sim._work_stations(GameConfig.TICK)
	for desk in 3:
		assert_null(review.jobs[desk])
	assert_false(sim.start_job(review, 0))


func test_finished_job_frees_work_for_a_later_desk_in_the_same_tick() -> void:
	var review := state.station("general_services/review")
	while review.desks < 2:
		review.add_desk()
	review.staff = 2
	var done := _case()
	review.jobs[0] = StationJob.new(done, 0.01)
	review.jobs[0].progress = 1.0
	review.inbox.append(_case())
	sim._work_stations(GameConfig.TICK)
	assert_has(review.outbox, done)
	assert_not_null(review.jobs[1])


func test_idle_runners_of_one_group_share_a_failed_search() -> void:
	for i in 3:
		state.add_runner(Runner.INTAKE)
	sim._update_runners(GameConfig.TICK)
	for runner in state.runners:
		assert_eq(runner.task, Runner.Task.IDLE)
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case("general_services", 0))
	sim._update_runners(GameConfig.TICK)
	var busy := 0
	for runner in state.runners:
		if runner.task != Runner.Task.IDLE:
			busy += 1
	assert_eq(busy, 1)


func test_reject_runners_stay_out_of_the_idle_group_search() -> void:
	var first := state.add_runner(Runner.INTAKE)
	var second := state.add_runner(Runner.INTAKE)
	var rejecter := state.add_runner(Runner.REJECT)
	state.station("general_services/review").rejects = 2
	sim._update_runners(GameConfig.TICK)
	assert_eq(first.task, Runner.Task.IDLE)
	assert_eq(second.task, Runner.Task.IDLE)
	assert_eq(rejecter.source, "general_services/review")
	assert_eq(rejecter.task, Runner.Task.IDLE)
	state.station(GameConfig.RECEPTION).outbox.append(_case("general_services", 0))
	sim._update_runners(GameConfig.TICK)
	assert_eq(first.task, Runner.Task.TO_SOURCE)
	assert_eq(rejecter.task, Runner.Task.IDLE)


func test_runner_arriving_at_source_lets_others_search_again() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	var first := state.add_runner(Runner.INTAKE)
	var second := state.add_runner(Runner.INTAKE)
	for i in 2:
		reception.outbox.append(_case("general_services", 0))
	first.task = Runner.Task.TO_SOURCE
	first.source = GameConfig.RECEPTION
	first.target = "general_services/review"
	first.reserved = 2
	first.position = layout.output_point(GameConfig.RECEPTION)
	second.position = layout.runner_home()
	Formulas.runner_load(state, first)
	sim._update_runners(GameConfig.TICK)
	assert_eq(first.task, Runner.Task.TO_TARGET)
	assert_true(second.task == Runner.Task.IDLE or second.task == Runner.Task.TO_SOURCE)


func test_launch_parcels_skips_cases_without_tubes() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	var reception := state.station(GameConfig.RECEPTION)
	var case_file := _case("general_services", 0)
	reception.outbox.append(case_file)
	sim._launch_parcels()
	assert_has(reception.outbox, case_file)
	assert_true(state.tube_parcels.is_empty())
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	state.set_upgrade("tube_station", 1, "general_services")
	sim._launch_parcels()
	assert_false(reception.outbox.has(case_file))
	assert_eq(state.tube_parcels.size(), 1)
	assert_eq(state.tube_parcels[0].tube_id(), RouteBuilder.tube_id(GameConfig.RECEPTION, "general_services/review"))


func test_wake_check_ignores_far_stations_but_wakes_close_ones() -> void:
	var review := state.station("general_services/review")
	review.staff = 1
	review.moods[0].rest(DeskMood.ASLEEP)
	state.player.position = Vector2(-5000, -5000)
	sim._wake_nearby(GameConfig.WAKE_TIME + 1.0)
	assert_true(review.moods[0].is_resting())
	assert_eq(review.moods[0].wake_progress, 0.0)
	state.player.position = layout.desk_position("general_services/review", 0)
	sim._wake_nearby(GameConfig.WAKE_TIME + 1.0)
	assert_false(review.moods[0].is_resting())
