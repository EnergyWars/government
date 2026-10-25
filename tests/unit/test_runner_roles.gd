extends GutTest

var state: GameState
var game: Game
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(37)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.money = 1e9
	game = Game.new(state)
	sim = game.simulation
	layout = WorldLayout.get_default()


func _case(dept_id: String = "general_services", key: String = "") -> CaseFile:
	var case_file := CaseFile.new(dept_id)
	case_file.route = RouteBuilder.build(case_file)
	if not key.is_empty():
		case_file.step = case_file.route.find(key)
	return case_file


func _run(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(0.05)
		elapsed += 0.05


func test_role_for_classifies_every_transfer() -> void:
	assert_eq(Runner.role_for(GameConfig.RECEPTION, "general_services/review"), Runner.INTAKE)
	assert_eq(Runner.role_for(GameConfig.MAILROOM, "general_services/review"), Runner.INTAKE)
	assert_eq(Runner.role_for("customs/dock", "customs/review"), Runner.INTAKE)
	assert_eq(Runner.role_for("general_services/review", "general_services/signature"), Runner.INTERNAL)
	assert_eq(Runner.role_for("business_licences/review", GameConfig.INSPECTION), Runner.INTERNAL)
	assert_eq(Runner.role_for("housing/review", "general_services/review"), Runner.INTERNAL)
	assert_eq(Runner.role_for("general_services/signature", GameConfig.COUNTER), Runner.OUTPUT)
	assert_eq(Runner.role_for(GameConfig.RECEPTION, GameConfig.COUNTER), Runner.OUTPUT)


func test_serves_checks_role_and_department() -> void:
	var runner := Runner.new(Vector2.ZERO)
	var citizen := _case()
	assert_true(runner.serves(citizen, GameConfig.RECEPTION))
	var done := _case("general_services", "general_services/signature")
	assert_false(runner.serves(done, "general_services/signature"))
	runner.role = Runner.OUTPUT
	assert_true(runner.serves(done, "general_services/signature"))
	runner.dept_id = "tax_services"
	assert_false(runner.serves(done, "general_services/signature"))
	assert_true(runner.serves(_case("tax_services", "tax_services/signature"), "tax_services/signature"))


func test_new_runners_fill_the_emptiest_role() -> void:
	assert_eq(state.least_staffed_role(), Runner.INTAKE)
	assert_eq(state.add_runner().role, Runner.INTAKE)
	assert_eq(state.add_runner().role, Runner.INTERNAL)
	assert_eq(state.add_runner().role, Runner.OUTPUT)
	assert_eq(state.add_runner(Runner.OUTPUT).role, Runner.OUTPUT)
	assert_eq(state.add_runner("nope").role, Runner.INTAKE)
	assert_eq(state.runners_in(Runner.OUTPUT), 2)
	assert_eq(state.runners_in("nope"), 0)


func test_transfer_backlog_counts_waiting_files_per_role() -> void:
	state.station(GameConfig.RECEPTION).outbox.append(_case())
	state.station("general_services/review").outbox.append(_case("general_services", "general_services/review"))
	state.station("general_services/signature").outbox.append(_case("general_services", "general_services/signature"))
	state.station("general_services/signature").outbox.append(_case("general_services", "general_services/signature"))
	assert_eq(state.transfer_backlog(Runner.INTAKE), 1)
	assert_eq(state.transfer_backlog(Runner.INTERNAL), 1)
	assert_eq(state.transfer_backlog(Runner.OUTPUT), 2)


func test_runners_only_take_files_for_their_role() -> void:
	var output := state.add_runner(Runner.OUTPUT)
	state.station(GameConfig.RECEPTION).outbox.append(_case())
	assert_false(sim.assign_runner(output))
	state.station("general_services/signature").outbox.append(_case("general_services", "general_services/signature"))
	assert_true(sim.assign_runner(output))
	assert_eq(output.source, "general_services/signature")
	assert_eq(output.target, GameConfig.COUNTER)


func test_department_runner_ignores_other_departments() -> void:
	state.unlock_department("tax_services")
	var runner := state.add_runner(Runner.INTERNAL)
	runner.dept_id = "tax_services"
	state.station("general_services/review").outbox.append(_case("general_services", "general_services/review"))
	assert_false(sim.assign_runner(runner))
	state.station("tax_services/review").outbox.append(_case("tax_services", "tax_services/review"))
	assert_true(sim.assign_runner(runner))
	assert_eq(runner.target, "tax_services/signature")


func test_pickup_skips_files_the_runner_does_not_serve() -> void:
	var runner := state.add_runner(Runner.INTAKE)
	runner.dept_id = "general_services"
	var reception := state.station(GameConfig.RECEPTION)
	state.unlock_department("tax_services")
	reception.outbox.append(_case("tax_services"))
	reception.outbox.append(_case())
	runner.task = Runner.Task.TO_SOURCE
	runner.source = GameConfig.RECEPTION
	runner.target = "general_services/review"
	runner.reserved = 2
	runner.position = layout.output_point(GameConfig.RECEPTION)
	sim.tick(0.05)
	assert_eq(runner.items.size(), 1)
	assert_eq(runner.items[0].dept_id, "general_services")
	assert_eq(reception.outbox.size(), 1)


func test_three_roles_run_the_whole_route() -> void:
	for key in state.stations:
		if not state.stations[key].machine:
			state.stations[key].staff = 1
	for role in Runner.ROLES:
		state.add_runner(role)
	state.department("general_services").arrival_timer = 0.0
	_run(180.0)
	assert_gt(state.cases_completed, 5)


func test_missing_output_runner_leaves_finished_files() -> void:
	for key in state.stations:
		if not state.stations[key].machine:
			state.stations[key].staff = 1
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	state.player.position = Vector2(-5000, -5000)
	state.department("general_services").arrival_timer = 0.0
	_run(120.0)
	assert_eq(state.cases_completed, 0)
	assert_gt(state.transfer_backlog(Runner.OUTPUT), 0)


func test_hire_runner_for_a_role_or_the_weakest_one() -> void:
	assert_true(game.actions.hire_runner(Runner.OUTPUT))
	assert_eq(state.runners[0].role, Runner.OUTPUT)
	assert_true(game.actions.hire_runner())
	assert_eq(state.runners[1].role, Runner.INTAKE)
	assert_eq(state.staff_hired, 2)


func test_weakest_role_follows_demand_and_capacity() -> void:
	assert_eq(Formulas.weakest_runner_role(state), Runner.INTAKE)
	state.add_runner(Runner.INTAKE)
	assert_eq(Formulas.weakest_runner_role(state), Runner.INTERNAL)
	state.add_runner(Runner.INTERNAL)
	assert_eq(Formulas.weakest_runner_role(state), Runner.OUTPUT)
	state.department("general_services").unlocked = false
	assert_eq(Formulas.weakest_runner_role(state), Runner.OUTPUT)


func test_role_transfers_and_demand() -> void:
	assert_eq(Formulas.runner_transfers(state, state.department("general_services")), {Runner.INTAKE: 1.0, Runner.INTERNAL: 1.0, Runner.OUTPUT: 1.0})
	assert_eq(Formulas.runner_transfers(state, state.department("housing")), {Runner.INTAKE: 1.0, Runner.INTERNAL: 2.0, Runner.OUTPUT: 1.0})
	assert_eq(Formulas.runner_transfers(state, state.department("business_licences")), {Runner.INTAKE: 1.0, Runner.INTERNAL: 2.0, Runner.OUTPUT: 1.0})
	assert_eq(float(Formulas.runner_transfers(state, state.department("customs"))[Runner.INTAKE]), 1.0)
	var gs := state.department("general_services")
	assert_almost_eq(Formulas.role_demand(state, Runner.OUTPUT), Formulas.demand(state, gs), 0.0001)
	assert_almost_eq(Formulas.role_capacity(state, Runner.OUTPUT, 2), 2.0 * Formulas.runner_capacity(state) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)


func test_transport_throughput_with_an_extra_runner() -> void:
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	assert_eq(Formulas.transport_throughput(state), 0.0)
	assert_eq(Formulas.transport_throughput(state, Runner.INTAKE), 0.0)
	assert_gt(Formulas.transport_throughput(state, Runner.OUTPUT), 0.0)
	state.department("general_services").unlocked = false
	assert_almost_eq(Formulas.transport_throughput(state, Runner.OUTPUT), 3.0 * Formulas.runner_capacity(state) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)


func test_reassigning_runners() -> void:
	var actions := game.actions
	assert_false(actions.set_runner_role(0, Runner.OUTPUT))
	var runner := state.add_runner(Runner.INTAKE)
	assert_false(actions.set_runner_role(0, "nope"))
	assert_false(actions.set_runner_role(-1, Runner.OUTPUT))
	assert_false(actions.set_runner_role(0, Runner.INTAKE))
	runner.task = Runner.Task.TO_SOURCE
	runner.reserved = 2
	assert_true(actions.set_runner_role(0, Runner.OUTPUT))
	assert_eq(runner.role, Runner.OUTPUT)
	assert_eq(runner.task, Runner.Task.IDLE)
	runner.items.append(_case())
	runner.task = Runner.Task.TO_TARGET
	assert_true(actions.set_runner_role(0, Runner.INTERNAL))
	assert_eq(runner.task, Runner.Task.TO_TARGET)


func test_cycling_the_responsible_department() -> void:
	var actions := game.actions
	assert_false(actions.cycle_runner_department(0))
	var runner := state.add_runner(Runner.INTERNAL)
	state.unlock_department("tax_services")
	assert_eq(actions.runner_department_options(), [Runner.ALL_DEPARTMENTS, "general_services", "tax_services"] as Array[String])
	assert_true(actions.cycle_runner_department(0))
	assert_eq(runner.dept_id, "general_services")
	runner.task = Runner.Task.TO_SOURCE
	assert_true(actions.cycle_runner_department(0))
	assert_eq(runner.dept_id, "tax_services")
	assert_eq(runner.task, Runner.Task.IDLE)
	assert_true(actions.cycle_runner_department(0))
	assert_eq(runner.dept_id, Runner.ALL_DEPARTMENTS)
	runner.dept_id = "customs"
	assert_true(actions.cycle_runner_department(0))
	assert_eq(runner.dept_id, Runner.ALL_DEPARTMENTS)


func test_roles_and_departments_are_saved() -> void:
	var runner := state.add_runner(Runner.OUTPUT)
	runner.dept_id = "general_services"
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.runners[0].role, Runner.OUTPUT)
	assert_eq(loaded.runners[0].dept_id, "general_services")
	var data := Runner.from_dict({"role": "boss", "dept": "nope"}, Vector2.ZERO)
	assert_eq(data.role, "")
	assert_eq(data.dept_id, Runner.ALL_DEPARTMENTS)


func test_old_saves_split_runners_evenly() -> void:
	for i in 4:
		state.add_runner()
	var data := state.to_dict()
	for entry: Dictionary in data.runners:
		entry.erase("role")
		entry.erase("dept")
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.runners_in(Runner.INTAKE), 2)
	assert_eq(loaded.runners_in(Runner.INTERNAL), 1)
	assert_eq(loaded.runners_in(Runner.OUTPUT), 1)
	for runner in loaded.runners:
		assert_eq(runner.dept_id, Runner.ALL_DEPARTMENTS)


func test_guidance_only_counts_matching_runners() -> void:
	var signature := state.station("general_services/signature")
	assert_false(Guidance._automated(state, signature))
	state.add_runner(Runner.INTAKE)
	assert_true(Guidance._automated(state, signature))
	signature.outbox.append(_case("general_services", "general_services/signature"))
	assert_false(Guidance._automated(state, signature))
	state.add_runner(Runner.OUTPUT)
	assert_true(Guidance._automated(state, signature))
	state.runners.clear()
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, "general_services")
	assert_false(Guidance._automated(state, signature))
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	assert_true(Guidance._automated(state, signature))


func test_runner_level_raises_load_and_cost() -> void:
	var runner := state.add_runner(Runner.INTAKE)
	assert_eq(Formulas.runner_load(state, runner), Formulas.runner_capacity(state))
	assert_eq(Formulas.runner_level_cost(runner), GameConfig.RUNNER_LEVEL_COST)
	runner.level = 2
	assert_eq(Formulas.runner_load(state, runner), Formulas.runner_capacity(state) + 2 * GameConfig.RUNNER_LEVEL_CAPACITY)
	assert_almost_eq(Formulas.runner_level_cost(runner), GameConfig.RUNNER_LEVEL_COST * pow(GameConfig.RUNNER_LEVEL_GROWTH, 2), 0.001)
	var base_load := Formulas.runner_load(state, runner)
	state.set_upgrade("runner_trolleys", 1)
	assert_eq(Formulas.runner_capacity(state), int(Formulas.track_value("runner_trolleys", 1)))
	assert_eq(Formulas.runner_load(state, runner), Formulas.runner_capacity(state) + 2 * GameConfig.RUNNER_LEVEL_CAPACITY)
	assert_gt(Formulas.runner_load(state, runner), base_load)


func test_upgrading_a_runner() -> void:
	var actions := game.actions
	assert_false(actions.upgrade_runner(0))
	assert_false(actions.can_upgrade_runner(-1))
	var runner := state.add_runner(Runner.INTAKE)
	state.money = 0.0
	assert_false(actions.upgrade_runner(0))
	state.money = 1e9
	assert_true(actions.upgrade_runner(0))
	assert_eq(runner.level, 1)
	assert_almost_eq(state.money, 1e9 - GameConfig.RUNNER_LEVEL_COST, 0.001)
	while actions.upgrade_runner(0):
		pass
	assert_eq(runner.level, GameConfig.MAX_RUNNER_LEVEL)
	assert_false(actions.can_upgrade_runner(0))


func test_runner_levels_count_in_capacity() -> void:
	var runner := state.add_runner(Runner.OUTPUT)
	runner.level = 3
	var base := Formulas.runner_capacity(state)
	assert_almost_eq(Formulas.role_capacity(state, Runner.OUTPUT), (base + 3.0) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	assert_almost_eq(Formulas.role_capacity(state, Runner.OUTPUT, 1), (2.0 * base + 3.0) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	state.department("general_services").unlocked = false
	assert_almost_eq(Formulas.transport_throughput(state), (base + 3.0) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	assert_almost_eq(Formulas.transport_throughput(state, Runner.INTAKE), (2.0 * base + 3.0) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)


func test_runner_speed_shortens_the_trip_estimate() -> void:
	assert_eq(Formulas.runner_trip_time(state), GameConfig.RUNNER_TRIP_ESTIMATE)
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	state.add_runner(Runner.OUTPUT)
	var before := Formulas.role_capacity(state, Runner.OUTPUT)
	var transport := Formulas.transport_throughput(state)
	state.set_upgrade("runner_speed", 50)
	var speed := Formulas.track_value("runner_speed", 50)
	assert_gt(speed, 1.0)
	assert_almost_eq(Formulas.runner_trip_time(state), GameConfig.RUNNER_TRIP_ESTIMATE / speed, 0.0001)
	assert_almost_eq(Formulas.role_capacity(state, Runner.OUTPUT), before * speed, 0.0001)
	assert_almost_eq(Formulas.transport_throughput(state), transport * speed, 0.0001)
	state.department("general_services").unlocked = false
	assert_almost_eq(Formulas.transport_throughput(state), 3.0 * Formulas.runner_capacity(state) / Formulas.runner_trip_time(state), 0.0001)


func test_upgraded_runner_reserves_more_files() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	for i in 6:
		reception.outbox.append(_case())
	var runner := state.add_runner(Runner.INTAKE)
	runner.level = 2
	assert_true(sim.assign_runner(runner))
	assert_eq(runner.reserved, Formulas.runner_capacity(state) + 2)


func test_guidance_counts_runner_levels() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	for i in Formulas.runner_capacity(state) + 1:
		reception.outbox.append(_case())
	var runner := state.add_runner(Runner.INTAKE)
	assert_false(Guidance._automated(state, reception))
	runner.level = 1
	assert_true(Guidance._automated(state, reception))


func test_runner_levels_are_saved_and_clamped() -> void:
	var runner := state.add_runner(Runner.INTAKE)
	runner.level = 3
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.runners[0].level, 3)
	assert_eq(Runner.from_dict({"level": 99}, Vector2.ZERO).level, GameConfig.MAX_RUNNER_LEVEL)
	assert_eq(Runner.from_dict({"level": -2}, Vector2.ZERO).level, 0)
	assert_eq(Runner.from_dict({}, Vector2.ZERO).level, 0)


func test_runner_fills_up_with_files_that_arrived_on_the_way() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	var runner := state.add_runner(Runner.INTAKE)
	assert_true(sim.assign_runner(runner))
	assert_eq(runner.reserved, 1)
	for i in 4:
		reception.outbox.append(_case())
	runner.position = layout.output_point(GameConfig.RECEPTION)
	sim.tick(0.05)
	assert_eq(runner.items.size(), Formulas.runner_load(state, runner))
	assert_eq(runner.task, Runner.Task.TO_TARGET)


func test_runner_leaves_files_reserved_by_others() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	var first := state.add_runner(Runner.INTAKE)
	var second := state.add_runner(Runner.INTAKE)
	assert_true(sim.assign_runner(first))
	reception.outbox.append(_case())
	assert_true(sim.assign_runner(second))
	assert_eq(second.reserved, 1)
	first.position = layout.output_point(GameConfig.RECEPTION)
	sim.tick(0.05)
	assert_eq(first.items.size(), 1)
	assert_eq(reception.outbox.size(), 1)


func test_runner_takes_files_for_several_targets_and_delivers_all() -> void:
	state.unlock_department("tax_services")
	var general := state.station("general_services/review")
	var tax := state.station("tax_services/review")
	general.staff = 0
	tax.staff = 0
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	reception.outbox.append(_case("tax_services"))
	var runner := state.add_runner(Runner.INTAKE)
	assert_true(sim.assign_runner(runner))
	runner.position = layout.output_point(GameConfig.RECEPTION)
	sim.tick(0.05)
	assert_eq(runner.items.size(), 2)
	assert_true(reception.outbox.is_empty())
	_run(60.0)
	assert_eq(general.inbox.size(), 1)
	assert_eq(tax.inbox.size(), 1)
	assert_eq(runner.task, Runner.Task.IDLE)


func test_runner_skips_extra_targets_without_inbox_space() -> void:
	state.unlock_department("tax_services")
	var tax := state.station("tax_services/review")
	tax.staff = 0
	for i in tax.inbox_capacity(state.lobby_capacity()):
		tax.inbox.append(_case("tax_services", "tax_services/review"))
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	reception.outbox.append(_case("tax_services"))
	var runner := state.add_runner(Runner.INTAKE)
	runner.task = Runner.Task.TO_SOURCE
	runner.source = GameConfig.RECEPTION
	runner.target = "general_services/review"
	runner.reserved = 1
	runner.position = layout.output_point(GameConfig.RECEPTION)
	sim.tick(0.05)
	assert_eq(runner.items.size(), 1)
	assert_eq(runner.items[0].dept_id, "general_services")


func test_runner_switches_to_the_next_target_after_a_delivery() -> void:
	state.unlock_department("tax_services")
	state.station("general_services/review").staff = 0
	var runner := state.add_runner(Runner.INTAKE)
	runner.items.append_array([_case(), _case("tax_services")])
	runner.task = Runner.Task.TO_TARGET
	runner.target = "general_services/review"
	runner.position = layout.input_point("general_services/review")
	sim.tick(0.05)
	assert_eq(runner.items.size(), 1)
	assert_eq(runner.target, "tax_services/review")
	assert_eq(runner.task, Runner.Task.TO_TARGET)


func test_runner_picks_another_target_when_the_reserved_one_is_gone() -> void:
	state.unlock_department("tax_services")
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case("tax_services"))
	var runner := state.add_runner(Runner.INTAKE)
	runner.task = Runner.Task.TO_SOURCE
	runner.source = GameConfig.RECEPTION
	runner.target = "general_services/review"
	runner.reserved = 1
	runner.position = layout.output_point(GameConfig.RECEPTION)
	sim._runner_to_source(runner, 0.05)
	assert_eq(runner.items.size(), 1)
	assert_eq(runner.target, "tax_services/review")
