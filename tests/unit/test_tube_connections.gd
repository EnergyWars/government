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
	UpgradeEntryCard.amount_index = 0


func _case(dept_id: String = "general_services", key: String = "") -> CaseFile:
	var case_file := CaseFile.new(dept_id)
	case_file.route = RouteBuilder.build(case_file)
	if not key.is_empty():
		case_file.step = case_file.route.find(key)
	return case_file


func _station(room_id: String) -> void:
	state.set_upgrade("tube_station", 1, room_id)


func _connect_all() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		_station(room_id)
	state.set_upgrade("large_capsules", 1)


func _mixed() -> void:
	state.unlock_department("tax_services")
	state.set_upgrade("pneumatic_tubes", 1)
	_station(GameConfig.ROOM_HALL)
	_station("general_services")


func _transfers(dept: Department) -> float:
	return float(RouteBuilder.build(CaseFile.new(dept.id)).size() - 1)


func _old_save(pneumatic_tubes: int, departments: Array) -> Dictionary:
	var entries := {}
	for entry: Dictionary in departments:
		entries[entry.id] = entry
	return {"version": GameState.LEGACY_SAVE_VERSION, "research": {"pneumatic_tubes": pneumatic_tubes}, "departments": entries}


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


func _suggested_entries(entry: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for upgrade: Dictionary in entry.upgrades:
		result.append(str(upgrade.entry))
	return result


func test_a_transfer_needs_the_unlock_and_stations_in_both_rooms() -> void:
	var review := "general_services/review"
	assert_false(state.has_tube_station("general_services"))
	_station("general_services")
	assert_false(state.has_tube_station("general_services"))
	state.set_upgrade("pneumatic_tubes", 1)
	assert_true(state.has_tube_station("general_services"))
	assert_false(state.has_tube_station("nope"))
	assert_false(state.tube_link(GameConfig.RECEPTION, review))
	assert_true(state.tube_link(review, "general_services/signature"))
	assert_false(state.tube_link(review, ""))
	assert_false(state.is_piped(_case()))
	assert_true(state.is_piped(_case("general_services", review)))
	assert_true(state.any_piped())
	_station(GameConfig.ROOM_HALL)
	assert_true(state.tube_link(GameConfig.RECEPTION, review))
	assert_true(state.is_piped(_case()))
	assert_false(state.all_piped())


func test_only_files_that_fit_a_capsule_are_piped() -> void:
	_connect_all()
	state.set_upgrade("large_capsules", 0)
	var complex := _case()
	complex.complex = true
	var big := _case()
	big.big = true
	assert_true(state.is_piped(_case()))
	assert_false(state.is_piped(complex))
	assert_false(state.is_piped(big))
	assert_false(state.all_piped())
	state.set_upgrade("large_capsules", 1)
	assert_true(state.is_piped(complex))
	assert_false(state.is_piped(big))
	assert_true(state.all_piped())


func test_piping_state_with_mixed_offices() -> void:
	_mixed()
	assert_true(state.any_piped())
	assert_false(state.all_piped())
	assert_true(state.is_piped(_case()))
	assert_false(state.is_piped(_case("tax_services")))
	_connect_all()
	assert_true(state.is_piped(_case("tax_services")))
	assert_true(state.all_piped())


func test_all_piped_needs_an_open_office() -> void:
	_connect_all()
	state.department("general_services").unlocked = false
	assert_false(state.all_piped())
	assert_false(state.any_piped())


func test_tube_stations_are_installed_per_room() -> void:
	var actions := game.actions
	state.reputation = 1e4
	state.unlock_department("tax_services")
	assert_eq(Progression.upgrade_block_reason(state, "tube_station", "general_services"), "requires")
	assert_false(actions.buy_upgrade("tube_station", "general_services"))
	assert_true(actions.buy_upgrade("pneumatic_tubes"))
	assert_false(state.any_piped())
	assert_true(actions.buy_upgrade("tube_station", GameConfig.ROOM_HALL))
	assert_true(actions.buy_upgrade("tube_station", "general_services"))
	assert_true(state.is_piped(_case()))
	assert_false(state.is_piped(_case("tax_services")))
	state.unlock_department("vehicle_registration")
	assert_false(state.has_tube_station("vehicle_registration"))
	assert_false(state.is_piped(_case("vehicle_registration")))
	assert_eq(Progression.upgrade_block_reason(state, "tube_station", "housing"), "room")
	assert_false(actions.buy_upgrade("tube_station", "housing"))
	assert_false(actions.buy_upgrade("tube_station", "nope"))
	assert_false(actions.buy_upgrade("tube_station"))


func test_buying_a_tube_station_for_an_office() -> void:
	var actions := game.actions
	var entry_id := "track:tube_station@tax_services"
	state.unlock_department("tax_services")
	assert_false(actions.buy_entry(entry_id))
	state.set_upgrade("pneumatic_tubes", 1)
	assert_false(actions.buy_upgrade("tube_station", "customs"))
	state.money = 0.0
	assert_false(actions.buy_entry(entry_id))
	state.money = 1e6
	assert_true(actions.buy_entry(entry_id))
	assert_almost_eq(state.money, 1e6 - Formulas.track_cost("tube_station", 0, "tax_services"), 0.001)
	assert_true(state.has_tube_station("tax_services"))
	assert_eq(Progression.upgrade_block_reason(state, "tube_station", "tax_services"), "max")
	assert_false(actions.buy_entry(entry_id))


func test_station_cost_follows_the_room() -> void:
	assert_eq(Formulas.track_cost("tube_station", 0, "general_services"), GameConfig.TUBE_STATION_MIN_COST)
	assert_eq(Formulas.track_cost("tube_station", 0, "tax_services"), GameConfig.TUBE_STATION_MIN_COST)
	assert_eq(Formulas.track_cost("tube_station", 0, GameConfig.ROOM_HALL), GameConfig.TUBE_STATION_MIN_COST)
	assert_almost_eq(Formulas.track_cost("tube_station", 0, "customs"), float(GameConfig.department("customs").unlock_cost) * GameConfig.TUBE_STATION_FACTOR, 0.001)
	assert_almost_eq(Formulas.track_cost("tube_station", 0, GameConfig.ROOM_INSPECTION), GameConfig.TUBE_STATION_MIN_COST * GameConfig.TUBE_STATION_INSPECTION_FACTOR, 0.001)
	assert_gt(Formulas.track_cost("tube_station", 0, "housing"), Formulas.track_cost("tube_station", 0, "vehicle_registration"))


func test_tube_stations_are_saved() -> void:
	_mixed()
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_true(loaded.has_tube_station("general_services"))
	assert_true(loaded.has_tube_station(GameConfig.ROOM_HALL))
	assert_false(loaded.has_tube_station("tax_services"))
	assert_true(loaded.is_piped(_case()))
	assert_false(loaded.is_piped(_case("tax_services")))


func test_old_saves_with_tubes_keep_open_offices_piped() -> void:
	var loaded := GameState.from_dict(_old_save(1, [{"id": "general_services", "unlocked": true}, {"id": "tax_services", "unlocked": true}]))
	assert_true(loaded.is_piped(_case()))
	assert_true(loaded.is_piped(_case("tax_services")))
	assert_true(loaded.all_piped())
	assert_false(GameState.from_dict(_old_save(0, [{"id": "general_services", "unlocked": true}])).any_piped())


func test_old_saves_never_connect_locked_offices() -> void:
	var loaded := GameState.from_dict(_old_save(1, [{"id": "general_services", "unlocked": true}, {"id": "tax_services", "unlocked": false, "tube": true}]))
	assert_false(loaded.has_tube_station("tax_services"))
	loaded.unlock_department("tax_services")
	assert_false(loaded.is_piped(_case("tax_services")))
	assert_true(loaded.is_piped(_case()))


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


func test_runners_help_out_when_piped_files_back_up() -> void:
	_mixed()
	var reception := state.station(GameConfig.RECEPTION)
	var runner := state.add_runner(Runner.INTAKE)
	var threshold := ceili(reception.outbox_capacity() * GameConfig.TUBE_OVERFLOW_SHARE)
	for i in threshold - 1:
		reception.outbox.append(_case())
	assert_false(reception.is_backlogged())
	assert_false(sim.runner_takes(runner, reception.outbox[0], GameConfig.RECEPTION))
	assert_false(sim.assign_runner(runner))
	reception.outbox.append(_case())
	assert_true(reception.is_backlogged())
	assert_true(sim.runner_takes(runner, reception.outbox[0], GameConfig.RECEPTION))
	assert_true(sim.assign_runner(runner))
	assert_eq(runner.target, "general_services/review")
	assert_false(sim.runner_takes(state.add_runner(Runner.OUTPUT), reception.outbox[0], GameConfig.RECEPTION))
	assert_false(sim.runner_takes(runner, reception.outbox[0], GameConfig.MAILROOM))


func test_runner_drops_reservation_when_office_gets_connected() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.outbox.append(_case())
	state.player.position = layout.input_point("general_services/signature")
	var runner := state.add_runner(Runner.INTAKE)
	runner.position = layout.runner_home()
	assert_true(sim.assign_runner(runner))
	sim.tick(0.05)
	assert_eq(runner.task, Runner.Task.TO_SOURCE)
	_connect_all()
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
	var complex_share := float(gs.config().complex_chance)
	assert_almost_eq(Formulas.total_transfer_demand(state), Formulas.demand(state, tax) * _transfers(tax) + Formulas.demand(state, gs) * _transfers(gs) * complex_share, 0.0001)
	assert_eq(Formulas.department_transport(state, gs), 0.0)
	state.set_upgrade("large_capsules", 1)
	assert_almost_eq(Formulas.total_transfer_demand(state), Formulas.demand(state, tax) * _transfers(tax), 0.0001)
	assert_almost_eq(Formulas.role_demand(state, Runner.INTAKE), Formulas.demand(state, tax), 0.0001)
	assert_true(is_inf(Formulas.department_transport(state, gs)))
	assert_eq(Formulas.transport_throughput(state), 0.0)
	assert_eq(Formulas.department_transport(state, tax), 0.0)
	_connect_all()
	assert_true(is_inf(Formulas.transport_throughput(state)))
	assert_true(is_inf(Formulas.department_transport(state, tax)))


func test_report_offers_runners_and_tube_capacity_when_mixed() -> void:
	_mixed()
	var entry := ThroughputReport.transport_area(state)
	assert_false(is_inf(float(entry.capacity)))
	var entries := _suggested_entries(entry)
	assert_has(entries, "track:tube_capacity")
	assert_has(entries, ThroughputReport.staff_entry("runners"))


func test_world_redraws_tubes_per_station() -> void:
	var view: WorldView = autofree(WorldView.new())
	state.set_upgrade("pneumatic_tubes", 1)
	var before := view._tube_layout_signature(state)
	_station(GameConfig.ROOM_HALL)
	var hall := view._tube_layout_signature(state)
	assert_ne(hall, before)
	_connect_all()
	var connected := view._tube_layout_signature(state)
	assert_ne(connected, hall)
	state.unlock_department("tax_services")
	assert_ne(view._tube_layout_signature(state), connected)


func test_tube_station_spot_installs_the_station() -> void:
	var spot := UpgradeCatalog.TUBE_PREFIX + "tax_services"
	var entry_id := "track:tube_station@tax_services"
	state.unlock_department("tax_services")
	assert_eq(UpgradeCatalog.resolve_spot(state, spot), UpgradeCatalog.DEPT_PREFIX + "tax_services")
	var sheet := _sheet(SpotSheet.new(), spot)
	assert_has(_texts(sheet.content), sheet.tr("STATUS_TUBES_LOCKED"))
	assert_has(_texts(sheet.content), UpgradeTexts.title(UpgradeCatalog.find(state, entry_id)))
	assert_null(_button_starting_with(sheet.content, sheet.tr("ACTION_BUY")))
	state.set_upgrade("pneumatic_tubes", 1)
	assert_eq(UpgradeCatalog.resolve_spot(state, spot), spot)
	sheet.rebuild()
	assert_has(_texts(sheet.content), sheet.tr("STATUS_TUBE_MISSING"))
	var button := _button_starting_with(sheet.content, UpgradeTexts.button_text(state, UpgradeCatalog.find(state, entry_id), 1))
	assert_not_null(button)
	assert_false(button.disabled)
	button.pressed.emit()
	assert_true(state.has_tube_station("tax_services"))
	assert_has(_texts(sheet.content), sheet.tr("STATUS_TUBE_CONNECTED"))
	var maxed := _button_starting_with(sheet.content, sheet.tr("LABEL_MAX_LEVEL"))
	assert_not_null(maxed)
	assert_true(maxed.disabled)


func test_runner_board_and_status_with_mixed_offices() -> void:
	state.add_runner(Runner.INTAKE)
	var sheet := _sheet(SpotSheet.new(), "runners")
	assert_does_not_have(_texts(sheet.content), sheet.tr("RUNNERS_TUBES_PARTIAL_TEXT"))
	_mixed()
	sheet.rebuild()
	assert_has(_texts(sheet.content), sheet.tr("RUNNERS_TUBES_PARTIAL_TEXT"))
	assert_eq(SpotStatus.runners(state), TranslationServer.translate("FMT_RUNNER_INFO") % [Formulas.runner_capacity(state), UiKit.decimal(Formulas.transport_throughput(state) * 60.0)])
	_connect_all()
	assert_eq(SpotStatus.runners(state), TranslationServer.translate("LABEL_TUBES_ACTIVE"))


func test_tube_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["TRACK_PNEUMATIC_TUBES", "TRACK_DESC_PNEUMATIC_TUBES", "TRACK_TUBE_STATION", "TRACK_DESC_TUBE_STATION", "TRACK_LARGE_CAPSULES", "TRACK_DESC_LARGE_CAPSULES", "TRACK_TUBE_CAPACITY", "TRACK_DESC_TUBE_CAPACITY", "TRACK_TUBE_SPEED", "TRACK_DESC_TUBE_SPEED", "SPOT_TUBE_HUB", "SPOT_DESC_TUBE_HUB", "FMT_SPOT_TUBE_STATION", "SPOT_DESC_TUBE_STATION", "STATUS_TUBES_LOCKED", "STATUS_TUBE_MISSING", "STATUS_TUBE_CONNECTED", "FMT_STATUS_TUBE_HUB", "LABEL_NEEDS_TUBE_STATIONS", "LABEL_TUBES_ACTIVE", "RUNNERS_TUBES_PARTIAL_TEXT", "FMT_RUNNER_LEVEL", "FMT_TUBE_SEGMENT", "ENTRY_DESC_SEGMENT"]
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)


func test_segments_cover_every_route_section_once() -> void:
	var segments := RouteBuilder.segments("general_services")
	var route := RouteBuilder.build(CaseFile.new("general_services"))
	for i in route.size() - 1:
		assert_has(segments, RouteBuilder.tube_id(route[i], route[i + 1]))
	assert_has(segments, RouteBuilder.tube_id(GameConfig.MAILROOM, route[1]))
	var unique := {}
	for id in segments:
		assert_false(unique.has(id), id)
		unique[id] = true
	assert_same(RouteBuilder.segments("general_services"), segments)
	assert_eq(RouteBuilder.segment_ends(segments[0]), PackedStringArray([route[0], route[1]]))
	var customs := RouteBuilder.segments("customs")
	for id in customs:
		assert_false(id.begins_with(GameConfig.MAILROOM), id)


func test_parcel_tube_id_matches_the_route_builder() -> void:
	var parcel := TubeParcel.new(_case(), GameConfig.RECEPTION, "general_services/review")
	assert_eq(parcel.tube_id(), RouteBuilder.tube_id(GameConfig.RECEPTION, "general_services/review"))


func test_tube_segment_formulas() -> void:
	var id := RouteBuilder.segments("general_services")[0]
	assert_eq(state.tube_level(id), 0)
	assert_eq(Formulas.tube_capacity(state), GameConfig.TUBE_BASE_CAPACITY)
	assert_eq(Formulas.tube_segment_capacity(state, id), Formulas.tube_capacity(state))
	assert_eq(Formulas.tube_segment_factor(0), 1.0)
	assert_eq(Formulas.tube_segment_speed(state, id), GameConfig.TUBE_SPEED)
	assert_eq(Formulas.tube_segment_cost(0), GameConfig.TUBE_SEGMENT_COST)
	assert_almost_eq(Formulas.tube_segment_cost(2), GameConfig.TUBE_SEGMENT_COST * pow(GameConfig.TUBE_SEGMENT_GROWTH, 2), 0.01)
	state.tube_levels[id] = 2
	assert_eq(Formulas.tube_segment_capacity(state, id), Formulas.tube_capacity(state) + 2 * GameConfig.TUBE_SEGMENT_CAPACITY_PER_LEVEL)
	assert_almost_eq(Formulas.tube_segment_speed(state, id), GameConfig.TUBE_SPEED * (1.0 + 2.0 * GameConfig.TUBE_SEGMENT_SPEED_PER_LEVEL), 0.001)
	assert_eq(Formulas.tube_segment_capacity(state, RouteBuilder.segments("general_services")[1]), Formulas.tube_capacity(state))
	state.set_upgrade("tube_capacity", 3)
	state.set_upgrade("tube_speed", 10)
	assert_eq(Formulas.tube_capacity(state), int(Formulas.track_value("tube_capacity", 3)))
	assert_eq(Formulas.tube_segment_capacity(state, id), Formulas.tube_capacity(state) + 2 * GameConfig.TUBE_SEGMENT_CAPACITY_PER_LEVEL)
	assert_almost_eq(Formulas.tube_segment_speed(state, id), GameConfig.TUBE_SPEED * Formulas.tube_segment_factor(2) * Formulas.track_value("tube_speed", 10), 0.001)


func test_upgrading_a_single_tube_segment() -> void:
	var actions := game.actions
	var segments := RouteBuilder.segments("general_services")
	var id := segments[0]
	assert_false(actions.can_upgrade_tube(id))
	assert_null(UpgradeCatalog.find(state, "segment:" + id))
	state.set_upgrade("pneumatic_tubes", 1)
	assert_false(actions.tube_segment_ready(id))
	assert_false(actions.can_upgrade_tube(id))
	assert_eq(UpgradeCatalog.find(state, "segment:" + id).reason, "tubes")
	_connect_all()
	assert_true(actions.tube_segment_ready(id))
	assert_false(actions.can_upgrade_tube("nope>nowhere"))
	assert_false(actions.tube_segment_ready(RouteBuilder.segments("tax_services")[0]))
	var money := state.money
	assert_true(actions.upgrade_tube(id))
	assert_eq(state.tube_level(id), 1)
	assert_eq(state.tube_level(segments[1]), 0)
	assert_almost_eq(state.money, money - GameConfig.TUBE_SEGMENT_COST, 0.01)
	assert_true(actions.buy_entry("segment:" + id))
	assert_eq(state.tube_level(id), 2)
	while state.tube_level(id) < GameConfig.TUBE_SEGMENT_MAX_LEVEL:
		assert_true(actions.upgrade_tube(id))
	assert_false(actions.can_upgrade_tube(id))
	assert_false(actions.upgrade_tube(id))
	assert_eq(UpgradeCatalog.find(state, "segment:" + id).reason, "max")
	state.money = 0.0
	assert_false(actions.can_upgrade_tube(segments[1]))


func test_upgraded_segment_carries_more_and_faster() -> void:
	_connect_all()
	var reception := state.station(GameConfig.RECEPTION)
	for i in 10:
		reception.outbox.append(_case())
	var target := reception.outbox[0].next_key()
	var id := RouteBuilder.tube_id(GameConfig.RECEPTION, target)
	state.tube_levels[id] = 2
	state.player.position = Vector2(-500, -500)
	sim.tick(0.05)
	assert_eq(state.tube_parcels.size(), Formulas.tube_segment_capacity(state, id))
	var length := WorldLayout.path_length(layout.tube_path(GameConfig.RECEPTION, target))
	assert_almost_eq(state.tube_parcels[0].left, maxf(0.2, length / Formulas.tube_segment_speed(state, id)), 0.06)


func test_tube_levels_are_saved_and_repaired() -> void:
	var id := RouteBuilder.segments("general_services")[0]
	state.tube_levels[id] = 3
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.tube_level(id), 3)
	var data := state.to_dict()
	data.tube_levels = {id: 99, "broken": 2, "a>b": -1}
	var repaired := GameState.from_dict(data)
	assert_eq(repaired.tube_level(id), GameConfig.TUBE_SEGMENT_MAX_LEVEL)
	assert_false(repaired.tube_levels.has("broken"))
	assert_false(repaired.tube_levels.has("a>b"))
	data.tube_levels = "junk"
	assert_true(GameState.from_dict(data).tube_levels.is_empty())
	data.erase("tube_levels")
	assert_true(GameState.from_dict(data).tube_levels.is_empty())


func test_finished_notices_use_their_own_output_tube() -> void:
	var signature := "general_services/signature"
	var output := layout.tube_path(signature, GameConfig.COUNTER)
	assert_true(WorldLayout.is_output_tube(GameConfig.COUNTER))
	assert_false(WorldLayout.is_output_tube("general_services/review"))
	assert_eq(output[0], layout.output_point(signature))
	assert_eq(output[output.size() - 1], layout.input_point(GameConfig.COUNTER))
	assert_eq(output[2].x, WorldLayout.OUTPUT_SHAFT_X)
	assert_eq(output[3].x, WorldLayout.OUTPUT_SHAFT_X)
	assert_eq(output[1].y, layout.tube_gap(signature) + WorldLayout.OUTPUT_LANE)
	var inbound := layout.tube_path(GameConfig.RECEPTION, "general_services/review")
	assert_eq(inbound[2].x, WorldLayout.SHAFT_X)
	for point in inbound:
		assert_ne(point.x, WorldLayout.OUTPUT_SHAFT_X)
	for point in output:
		assert_ne(point.x, WorldLayout.SHAFT_X)


func test_tube_spot_lists_and_upgrades_segments() -> void:
	var id := RouteBuilder.segments("general_services")[0]
	state.set_upgrade("pneumatic_tubes", 1)
	var sheet := _sheet(SpotSheet.new(), UpgradeCatalog.TUBE_PREFIX + "general_services")
	var title := sheet.tr("FMT_TUBE_SEGMENT") % [StationCard.label_for(GameConfig.RECEPTION), StationCard.label_for("general_services/review")]
	assert_has(_texts(sheet.content), title)
	assert_has(_texts(sheet.content), sheet.tr("LABEL_NEEDS_TUBE_STATIONS"))
	_connect_all()
	sheet.refresh()
	var button := _button_starting_with(sheet.content, UpgradeTexts.button_text(state, UpgradeCatalog.find(state, "segment:" + id), 1))
	assert_not_null(button)
	assert_false(button.disabled)
	button.pressed.emit()
	assert_eq(state.tube_level(id), 1)
	assert_does_not_have(_texts(sheet.content), sheet.tr("LABEL_NEEDS_TUBE_STATIONS"))
