extends GutTest

var state: GameState
var game: Game
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(41)
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


func _mixed() -> void:
	state.unlock_department("tax_services")
	state.research["pneumatic_tubes"] = 1
	state.department("general_services").tube = true


func _host() -> Control:
	var host := Control.new()
	add_child_autofree(host)
	return host


func _sheet(sheet: Sheet, argument: String = "") -> Sheet:
	sheet.setup(game, argument)
	_host().add_child(sheet)
	return sheet


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	if node is Button:
		result.append((node as Button).text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _button_starting_with(node: Node, prefix: String) -> Button:
	if node is Button and (node as Button).text.begins_with(prefix):
		return node
	for child in node.get_children():
		var found := _button_starting_with(child, prefix)
		if found != null:
			return found
	return null


func _upgrade_ids(entry: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for upgrade: Dictionary in entry.upgrades:
		ids.append(str(upgrade.id) + (":" + str(upgrade.research) if upgrade.has("research") and not str(upgrade.research).is_empty() else ""))
	return ids


func test_tube_needs_research_and_connection() -> void:
	var gs := state.department("general_services")
	assert_false(state.has_tube("general_services"))
	gs.tube = true
	assert_false(state.has_tube("general_services"))
	state.research["pneumatic_tubes"] = 1
	assert_true(state.has_tube("general_services"))
	assert_true(state.is_piped(_case()))
	assert_false(state.has_tube("nope"))
	assert_true(state.any_piped())
	assert_true(state.all_piped())


func test_piping_state_with_mixed_offices() -> void:
	_mixed()
	assert_true(state.any_piped())
	assert_false(state.all_piped())
	assert_false(state.is_piped(_case("tax_services")))
	state.connect_all_tubes()
	assert_true(state.all_piped())
	assert_false(state.department("customs").tube)


func test_all_piped_needs_an_open_office() -> void:
	state.research["pneumatic_tubes"] = 1
	state.department("general_services").unlocked = false
	assert_false(state.all_piped())
	assert_false(state.any_piped())


func test_research_connects_only_the_offices_opened_so_far() -> void:
	state.reputation = 1e4
	state.unlock_department("tax_services")
	assert_true(game.actions.buy_research("pneumatic_tubes"))
	assert_true(state.has_tube("general_services"))
	assert_true(state.has_tube("tax_services"))
	state.unlock_department("vehicle_registration")
	assert_false(state.has_tube("vehicle_registration"))
	assert_false(state.all_piped())


func test_connecting_an_office() -> void:
	var actions := game.actions
	state.unlock_department("tax_services")
	assert_false(actions.can_connect_tube("tax_services"))
	state.research["pneumatic_tubes"] = 1
	assert_false(actions.connect_tube("customs"))
	assert_false(actions.connect_tube("nope"))
	state.money = 0.0
	assert_false(actions.connect_tube("tax_services"))
	state.money = 1e6
	assert_true(actions.connect_tube("tax_services"))
	assert_almost_eq(state.money, 1e6 - Formulas.tube_connection_cost("tax_services"), 0.001)
	assert_true(state.has_tube("tax_services"))
	assert_false(actions.can_connect_tube("tax_services"))
	assert_false(actions.connect_tube("tax_services"))


func test_connection_cost_follows_the_office() -> void:
	assert_eq(Formulas.tube_connection_cost("general_services"), GameConfig.TUBE_CONNECTION_MIN_COST)
	assert_eq(Formulas.tube_connection_cost("tax_services"), GameConfig.TUBE_CONNECTION_MIN_COST)
	assert_almost_eq(Formulas.tube_connection_cost("customs"), float(GameConfig.department("customs").unlock_cost) * GameConfig.TUBE_CONNECTION_FACTOR, 0.001)
	assert_gt(Formulas.tube_connection_cost("housing"), Formulas.tube_connection_cost("vehicle_registration"))


func test_connections_are_saved() -> void:
	_mixed()
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_true(loaded.has_tube("general_services"))
	assert_false(loaded.has_tube("tax_services"))


func test_old_saves_with_tubes_connect_open_offices() -> void:
	state.unlock_department("tax_services")
	state.research["pneumatic_tubes"] = 1
	var data := state.to_dict()
	for dept_id: String in data.departments:
		(data.departments[dept_id] as Dictionary).erase("tube")
	var loaded := GameState.from_dict(data)
	assert_true(loaded.has_tube("general_services"))
	assert_true(loaded.has_tube("tax_services"))
	assert_false(loaded.department("customs").tube)
	data.research["pneumatic_tubes"] = 0
	assert_false(GameState.from_dict(data).department("general_services").tube)


func test_locked_offices_never_load_a_connection() -> void:
	assert_false(Department.from_dict({"id": "tax_services", "unlocked": false, "tube": true}).tube)
	assert_true(Department.from_dict({"id": "tax_services", "unlocked": true, "tube": true}).tube)
	assert_true(Department.from_dict({"id": "tax_services", "unlocked": true}, true).tube)
	assert_false(Department.from_dict({"id": "tax_services", "unlocked": true}).tube)


func test_only_connected_offices_use_the_tube() -> void:
	_mixed()
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	reception.outbox.append(_case("tax_services"))
	sim.tick(0.05)
	assert_eq(state.tube_parcels.size(), 1)
	assert_eq(state.tube_parcels[0].case_file.dept_id, "general_services")
	assert_eq(reception.outbox.size(), 1)
	assert_eq(reception.outbox[0].dept_id, "tax_services")


func test_runners_carry_only_unconnected_offices() -> void:
	_mixed()
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	reception.outbox.append(_case("tax_services"))
	var runner := state.add_runner(Runner.INTAKE)
	assert_true(sim.assign_runner(runner))
	assert_eq(runner.target, "tax_services/review")
	assert_eq(runner.reserved, 1)
	assert_false(sim.runner_takes(runner, _case(), GameConfig.RECEPTION))
	assert_true(sim.runner_takes(runner, _case("tax_services"), GameConfig.RECEPTION))


func test_runner_drops_reservation_when_office_gets_connected() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	state.player.position = layout.input_point("general_services/signature")
	var runner := state.add_runner(Runner.INTAKE)
	runner.position = layout.runner_home()
	assert_true(sim.assign_runner(runner))
	sim.tick(0.05)
	assert_eq(runner.task, Runner.Task.TO_SOURCE)
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	sim.tick(0.05)
	assert_eq(runner.task, Runner.Task.IDLE)
	runner.task = Runner.Task.TO_SOURCE
	runner.source = "nope"
	sim.tick(0.05)
	assert_eq(runner.task, Runner.Task.IDLE)


func test_backlog_ignores_piped_files() -> void:
	_mixed()
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	reception.outbox.append(_case("tax_services"))
	assert_eq(state.transfer_backlog(Runner.INTAKE), 1)


func test_guidance_with_mixed_offices() -> void:
	_mixed()
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	assert_true(Guidance._automated(state, reception))
	reception.outbox.append(_case("tax_services"))
	assert_false(Guidance._automated(state, reception))
	state.add_runner(Runner.INTAKE)
	assert_true(Guidance._automated(state, reception))


func test_transport_formulas_with_mixed_offices() -> void:
	_mixed()
	var gs := state.department("general_services")
	var tax := state.department("tax_services")
	assert_almost_eq(Formulas.total_transfer_demand(state), Formulas.demand(state, tax) * Formulas.transfers_per_case(tax), 0.0001)
	assert_almost_eq(Formulas.role_demand(state, Runner.INTAKE), Formulas.demand(state, tax), 0.0001)
	assert_true(is_inf(Formulas.department_transport(state, gs)))
	assert_eq(Formulas.transport_throughput(state), 0.0)
	assert_eq(Formulas.department_transport(state, tax), 0.0)
	state.connect_all_tubes()
	assert_true(is_inf(Formulas.transport_throughput(state)))
	assert_true(is_inf(Formulas.department_transport(state, tax)))


func test_report_offers_runners_and_tube_capacity_when_mixed() -> void:
	_mixed()
	var entry := ThroughputReport.transport_area(state)
	assert_false(is_inf(float(entry.capacity)))
	var ids := _upgrade_ids(entry)
	assert_has(ids, ThroughputReport.RESEARCH + ":tube_capacity")
	assert_has(ids, ThroughputReport.RUNNER)


func test_world_redraws_tubes_per_connection() -> void:
	var view: WorldView = autofree(WorldView.new())
	state.research["pneumatic_tubes"] = 1
	var before := view._tube_layout_signature(state)
	state.connect_all_tubes()
	assert_ne(view._tube_layout_signature(state), before)
	var connected := view._tube_layout_signature(state)
	state.unlock_department("tax_services")
	assert_ne(view._tube_layout_signature(state), connected)


func test_department_sheet_connects_the_tube() -> void:
	state.unlock_department("tax_services")
	var sheet := _sheet(DepartmentSheet.new(), "tax_services")
	assert_does_not_have(_texts(sheet.content), sheet.tr("LABEL_TUBE_CONNECTION"))
	state.research["pneumatic_tubes"] = 1
	sheet.rebuild()
	assert_has(_texts(sheet.content), sheet.tr("LABEL_TUBE_CONNECTION"))
	assert_has(_texts(sheet.content), sheet.tr("TUBE_CONNECTION_TEXT"))
	var button := _button_starting_with(sheet.content, sheet.tr("ACTION_CONNECT_TUBE"))
	assert_not_null(button)
	assert_false(button.disabled)
	button.pressed.emit()
	assert_true(state.has_tube("tax_services"))
	assert_has(_texts(sheet.content), sheet.tr("TUBE_CONNECTED_TEXT"))
	var connected := _button_starting_with(sheet.content, sheet.tr("LABEL_TUBE_CONNECTED"))
	assert_not_null(connected)
	assert_true(connected.disabled)


func test_runner_sheet_and_card_texts_with_mixed_offices() -> void:
	state.add_runner(Runner.INTAKE)
	_mixed()
	var sheet := _sheet(RunnerSheet.new())
	assert_has(_texts(sheet.content), sheet.tr("RUNNERS_TUBES_PARTIAL_TEXT"))
	assert_eq(UpgradeCards.runner_info(state), TranslationServer.translate("FMT_RUNNER_INFO") % [Formulas.runner_capacity(state), UiKit.decimal(Formulas.transport_throughput(state) * 60.0)])
	state.connect_all_tubes()
	assert_eq(UpgradeCards.runner_info(state), TranslationServer.translate("LABEL_TUBES_ACTIVE"))


func test_connection_and_level_texts_exist() -> void:
	for key in ["LABEL_TUBE_CONNECTION", "TUBE_CONNECTION_TEXT", "TUBE_CONNECTED_TEXT", "ACTION_CONNECT_TUBE", "LABEL_TUBE_CONNECTED", "ACTION_UPGRADE_RUNNER", "FMT_RUNNER_LEVEL", "RUNNERS_TUBES_PARTIAL_TEXT"]:
		assert_ne(TranslationServer.translate(key), key, key)
