extends GutTest

var game: Game


func before_each() -> void:
	var state := GameState.create_new(4)
	state.money = 1e12
	state.reputation = 2000.0
	state.building_stage = GameConfig.BUILDING_STAGES.size() - 1
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	game = Game.new(state)
	UpgradeEntryCard.amount_index = 0
	UpgradesSheet.mode_index = 0


func _sheet(sheet: Sheet, argument: String = "") -> Sheet:
	sheet.setup(game, argument)
	add_child_autofree(sheet)
	return sheet


func _buy(sheet: Sheet, entry_id: String) -> void:
	sheet.act(func() -> bool: return UpgradeEntryCard.buy(game, entry_id))


func _install_tubes() -> void:
	game.state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		game.state.set_upgrade("tube_station", 1, room_id)


func test_every_sheet_builds_content() -> void:
	var sheets: Array[Sheet] = [UpgradesSheet.new(), StatisticsSheet.new(), GoalsSheet.new(), BoostSheet.new()]
	for sheet in sheets:
		_sheet(sheet)
		assert_gt(sheet.content.get_child_count(), 1, sheet.get_class())
		assert_false(sheet.title().is_empty())
	for spot: String in ["entrance", "runners", UpgradeCatalog.DEPT_PREFIX + "customs", UpgradeCatalog.ROOM_PREFIX + GameConfig.ROOM_TECH]:
		var spot_sheet := _sheet(SpotSheet.new(), spot)
		assert_gt(spot_sheet.content.get_child_count(), 1, spot)
		assert_false(spot_sheet.title().is_empty(), spot)
	await wait_physics_frames(2)


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false


func test_department_spot_shows_the_route_through_shared_stations() -> void:
	var licences := _sheet(SpotSheet.new(), UpgradeCatalog.DEPT_PREFIX + "business_licences")
	var route := DepartmentSection.route_text("business_licences")
	assert_true(_has_label(licences.content, route))
	assert_true(route.contains(StationCard.label_for(GameConfig.INSPECTION)))
	assert_true(route.contains(StationCard.label_for(GameConfig.RECEPTION)))
	var housing_sheet := _sheet(SpotSheet.new(), UpgradeCatalog.DEPT_PREFIX + "housing")
	var housing_route := DepartmentSection.route_text("housing")
	assert_true(_has_label(housing_sheet.content, housing_route))
	assert_true(housing_route.contains(housing_sheet.tr("STATION_GENERAL_SERVICES_REVIEW")))
	await wait_physics_frames(2)


func test_world_view_draws_resting_employees_and_reacts_to_naps() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station("general_services/review")
	review.staff = 1
	review.moods[0].rest(DeskMood.ASLEEP)
	review.moods[0].wake_progress = 0.3
	review.add_desk()
	review.staff = 2
	review.moods[1].rest(DeskMood.COFFEE)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.ASLEEP)
	game.simulation.employee_dozed.emit("general_services/review", 1, DeskMood.COFFEE)
	game.simulation.employee_woke.emit("general_services/review", 0, true)
	game.simulation.employee_woke.emit("general_services/review", 0, false)
	assert_eq(world._floaters.size(), 3)
	for i in 8:
		game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.ASLEEP)
		game.simulation.employee_woke.emit("general_services/review", 0, true)
	assert_lt(world._floaters.size(), 10)
	await wait_physics_frames(2)


func test_world_view_draws_kitchen_guests() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station("general_services/review")
	review.staff = 1
	for i in 3:
		review.add_desk()
	review.staff = 4
	review.moods[0].rest(DeskMood.CHAT, 0)
	review.moods[1].rest(DeskMood.CHAT, 1)
	review.moods[1].wake_progress = 0.3
	review.moods[2].rest(DeskMood.FETCH, 2)
	review.moods[3].rest(DeskMood.CHAT, 3)
	game.state.set_upgrade("coffee", 3)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	for rest_state in [DeskMood.CHAT, DeskMood.FETCH, DeskMood.ASLEEP, DeskMood.COFFEE]:
		game.simulation.employee_dozed.emit("general_services/review", 0, rest_state)
	assert_gt(world._floaters.size(), 0)
	await wait_physics_frames(2)


func test_world_view_draws_kranz_and_slow_walkers() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station("general_services/review")
	for i in 3:
		review.add_desk()
	review.staff = 4
	review.moods[0].rest(DeskMood.SLOW, 0)
	review.moods[1].rest(DeskMood.SLOW, 1)
	review.moods[2].rest(DeskMood.CHAT, 2)
	game.state.kranz = true
	game.state.kranz_progress = 0.5
	game.state.set_upgrade("kitchen", 3)
	game.state.set_upgrade("coffee_machine", 4)
	game.state.player.position = game.simulation.layout.kitchen_slot(0)
	game.simulation.kranz_called.emit()
	game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.SLOW)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	assert_gt(world._floaters.size(), 0)


func test_world_view_draws_sick_phone_and_loo() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station("general_services/review")
	for i in 3:
		review.add_desk()
	review.staff = 4
	review.moods[0].rest(DeskMood.SICK)
	review.moods[1].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	review.moods[1].wake_progress = 0.5
	review.moods[2].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS + 1)
	game.state.hr = 3
	var incoming := PhoneCall.new(PhoneCall.INCOMING, "general_services/review", 0, 10.0)
	incoming.line = PhoneCall.PLAYER
	incoming.progress = 1.0
	var outgoing := PhoneCall.new(PhoneCall.OUTGOING, "general_services/review", 3)
	outgoing.line = 1
	outgoing.progress = 1.0
	game.state.calls.append(PhoneCall.new(PhoneCall.INCOMING, "general_services/review", 2, 10.0))
	game.state.calls.append(incoming)
	game.state.calls.append(outgoing)
	var floaters := world._floaters.size()
	game.simulation.sick_called.emit(true, "general_services/review", 0)
	game.simulation.sick_called.emit(false, "general_services/review", 0)
	game.simulation.sick_call_answered.emit(true, "general_services/review", 0, true)
	game.simulation.sick_call_answered.emit(false, "general_services/review", 0, false)
	game.simulation.sick_call_missed.emit("general_services/review", 0)
	assert_eq(world._floaters.size(), floaters + 5)
	game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.SICK)
	game.simulation.employee_dozed.emit("general_services/review", 1, DeskMood.LOO)
	var phone_layer := _layer_node(world, WorldView.PHONE_LAYER)
	for ratio in [0.2, 0.8]:
		incoming.progress = incoming.duration() * ratio
		outgoing.progress = outgoing.duration() * ratio
		phone_layer.queue_redraw()
		await wait_physics_frames(2)
	game.state.calls.erase(incoming)
	phone_layer.queue_redraw()
	await wait_physics_frames(2)
	game.state.calls.clear()
	phone_layer.queue_redraw()
	await wait_physics_frames(2)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func test_returning_employee_walks_back_and_desk_stays_empty() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station("general_services/review")
	review.staff = 1
	review.moods[0].rest(DeskMood.CHAT, 2)
	game.simulation.wake_up(review, 0, true)
	assert_true(review.moods[0].is_returning())
	assert_true(review.moods[0].is_absent())
	assert_false(review.is_working(0))
	var walkers := world._walkers.size()
	assert_gt(walkers, 0)
	assert_almost_eq(float(world._walkers.back().duration), review.moods[0].return_time, 0.0001)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	game.simulation.tick(review.moods[0].return_time + 0.1)
	assert_true(review.moods[0].is_on_duty())
	review.moods[0].rest(DeskMood.ASLEEP)
	var before := world._walkers.size()
	game.simulation.wake_up(review, 0, false)
	assert_eq(world._walkers.size(), before)


func _layer_node(world: WorldView, id: String) -> Node2D:
	for layer in world._layers:
		if layer.id == id:
			return layer.node
	return null


func test_tapping_phone_office_opens_phone_room() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	world._handle_tap(world.layout.phone_header().get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.room_spot(GameConfig.ROOM_PHONE)])


func test_spots_open_only_on_a_double_tap() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	var point := world.layout.phone_header().get_center() * world.world_scale + world.position
	assert_false(world.register_tap(point, 1000))
	assert_signal_not_emitted(world, "open_spot")
	assert_true(world.register_tap(point + Vector2(10, 5), 1000 + WorldView.DOUBLE_TAP_TIME))
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.room_spot(GameConfig.ROOM_PHONE)])


func test_slow_or_distant_second_taps_do_not_open_a_spot() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	var point := world.layout.phone_header().get_center() * world.world_scale + world.position
	assert_false(world.register_tap(point, 1000))
	assert_false(world.register_tap(point, 1000 + WorldView.DOUBLE_TAP_TIME + 1))
	assert_false(world.register_tap(point + Vector2(WorldView.DOUBLE_TAP_DISTANCE + 1.0, 0.0), 1000 + WorldView.DOUBLE_TAP_TIME + 2))
	assert_signal_not_emitted(world, "open_spot")
	assert_true(world.register_tap(point + Vector2(WorldView.DOUBLE_TAP_DISTANCE + 1.0, 0.0), 1000 + WorldView.DOUBLE_TAP_TIME + 3))
	assert_false(world.register_tap(point, 1000 + WorldView.DOUBLE_TAP_TIME + 4))


func test_phone_and_toilet_painters_draw() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		for ringing in [true, false]:
			OfficePainter.phone(canvas, Vector2(50, 50), ringing, 0.2)
		for ringing in [0, 3, OfficePainter.SWITCHBOARD_LAMPS + 2]:
			for time in [0.1, 0.3]:
				OfficePainter.switchboard(canvas, Vector2(80, 120), ringing, time)
		OfficePainter.toilet_stalls(canvas, Vector2(10, 10), [true, false, true, false])
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_tapping_inspection_room_opens_inspection_room() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.state.stations.erase(GameConfig.INSPECTION)
	game.state.department("business_licences").unlocked = false
	watch_signals(world)
	var inspection_spot := UpgradeCatalog.room_spot(GameConfig.ROOM_INSPECTION)
	var body := world.layout.room("inspection").get_center()
	world._handle_tap(world.layout.header("inspection").get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [inspection_spot])
	assert_eq(world.tap_spot(body), "station:" + GameConfig.INSPECTION)
	var locked := _sheet(SpotSheet.new(), inspection_spot)
	assert_true(_has_label(locked.content, locked.tr("ROOM_LOCKED_INSPECTION")))
	game.state.unlock_department("business_licences")
	assert_not_null(game.state.station(GameConfig.INSPECTION))
	assert_eq(world.tap_spot(body), "station:" + GameConfig.INSPECTION)
	var opened := _sheet(SpotSheet.new(), inspection_spot)
	assert_false(_has_label(opened.content, opened.tr("ROOM_LOCKED_INSPECTION")))
	assert_true(_has_label(opened.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "%s:%s" % [UpgradeCatalog.TRACK, GameConfig.upgrade_key("room_speed", GameConfig.ROOM_INSPECTION)]))))


func test_phone_clerk_board_hires_hr() -> void:
	game.state.money = 1e9
	var sheet := _sheet(SpotSheet.new(), "phone_clerks")
	assert_true(_has_label(sheet.content, sheet.tr("PHONE_CLERKS_EMPTY")))
	_buy(sheet, "%s:hr" % UpgradeCatalog.STAFF)
	assert_eq(game.state.hr, 1)
	assert_false(_has_label(sheet.content, sheet.tr("PHONE_CLERKS_EMPTY")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_PHONE_LINE") % 1))
	await wait_physics_frames(2)


func test_world_view_layers_are_created_and_redrawn_selectively() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	assert_eq(world._layers.size(), 13 + world.layout.rooms.size())
	var layer_ids: Array[String] = []
	for layer in world._layers:
		layer_ids.append(str(layer.id))
	for id: String in [WorldView.SHELL_LAYER, WorldView.KITCHEN_LAYER, WorldView.TOILETS_LAYER, WorldView.PHONE_LAYER, WorldView.MAIL_LAYER, WorldView.COMPLAINT_LAYER, WorldView.SHREDDER_LAYER, WorldView.TECH_LAYER, WorldView.OFFICE_LAYER, WorldView.STAFF_LAYER, WorldView.HALL_STATIC_LAYER, WorldView.HALL_LAYER, WorldView.TUBES_LAYER]:
		assert_has(layer_ids, id)
	world._process(0.016)
	await wait_physics_frames(2)
	var drawn := 0
	for layer in world._layers:
		if layer.drawn:
			drawn += 1
	assert_gt(drawn, 0)
	var static_layers := 0
	for layer in world._layers:
		if layer.once:
			static_layers += 1
	assert_eq(static_layers, 3)
	var stage_before: int = world._shell_stage
	game.state.building_stage = (stage_before + 1) % GameConfig.BUILDING_STAGES.size()
	world._process(0.016)
	assert_ne(world._shell_stage, stage_before)
	for step in 30:
		world._process(0.2)
	await wait_physics_frames(2)
	world._process(0.016)


func test_world_view_style_cache_is_keyed_exactly() -> void:
	var world := WorldView.new()
	add_child_autofree(world)
	var first := world._style(Color.RED, 8, Color.BLUE, 2, false, false)
	assert_same(first, world._style(Color.RED, 8, Color.BLUE, 2, false, false))
	assert_ne(first, world._style(Color.RED, 8, Color.BLUE, 2, true, false))
	assert_ne(first, world._style(Color.RED, 8, Color.BLUE, 2, false, true))
	assert_ne(first, world._style(Color.GREEN, 8, Color.BLUE, 2, false, false))
	assert_ne(first, world._style(Color.RED, 9, Color.BLUE, 2, false, false))


func test_lite_person_and_textures_draw() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		for look in 6:
			ItemPainter.draw_person_lite(canvas, Vector2(30 + look * 40, 40), AppTheme.STAFF_COLOR, 0.9, look)
		OfficePainter.tiles(canvas, Rect2(0, 60, 200, 100))
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_not_null(ItemPainter.shadow_texture())
	assert_not_null(OfficePainter.tile_texture())
	assert_same(ItemPainter.shadow_texture(), ItemPainter.shadow_texture())


func test_sheet_scroll_container_is_fling_scroll() -> void:
	var sheet := UpgradesSheet.new().setup(game)
	add_child_autofree(sheet)
	assert_true(sheet._scroll is FlingScroll)


func test_world_view_draws_complaint_corner() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.state.complaints = 5
	game.state.player.complaints = 2
	game.simulation.complaint_filed.emit(false)
	game.simulation.complaint_filed.emit(true)
	game.simulation.complaint_shredded.emit(true)
	var floaters := world._floaters.size()
	game.state.set_upgrade("complaint_interns", 1)
	game.simulation.complaint_absorbed.emit(0)
	assert_eq(world._floaters.size(), floaters + 1)
	for outcome in ["expired", "lost", "deleted"]:
		game.simulation.review_removed.emit(outcome)
	assert_eq(world._floaters.size(), floaters + 4)
	game.state.set_upgrade("complaint_interns", GameConfig.MAX_DESK_INTERNS)
	game.state.set_upgrade("complaint_security", 1)
	game.state.interns[0].mood = ComplaintIntern.Mood.CRYING
	game.state.interns[0].handled = Formulas.intern_steadfast(game.state)
	game.state.complaints = Formulas.complaint_cap(game.state)
	assert_gt(world._shred_time, 0.0)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	world._process(1.0)
	assert_eq(world._shred_time, 0.0)


func test_world_view_floats_complaint_subject_instead_of_letter() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.state.complaints_filed = 3
	game.simulation.complaint_filed.emit(false)
	var floater: Dictionary = world._floaters[world._floaters.size() - 1]
	assert_eq(floater["text"], Flavor.complaint_subject(2))
	assert_ne(floater["text"], Flavor.complaint(2))
	game.simulation.complaint_filed.emit(true)
	floater = world._floaters[world._floaters.size() - 1]
	assert_eq(floater["text"], world.tr("FLOAT_COMPLAINT_OVERFLOW"))


func test_complaint_painter_elements_draw() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		for count in [0, 3, 20]:
			OfficePainter.complaint_pile(canvas, Vector2(50, 50), count)
		for active in [true, false]:
			OfficePainter.shredder(canvas, Vector2(100, 100), active, 0.3)
		for fill in [0.0, 0.5, 1.0, 3.0]:
			OfficePainter.complaint_box(canvas, Vector2(150, 100), fill)
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_kitchen_painter_elements_draw() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		OfficePainter.kitchen_counter(canvas, Rect2(0, 0, 300, 40))
		OfficePainter.fridge(canvas, Rect2(0, 0, 58, 118))
		OfficePainter.sink(canvas, Vector2(50, 50))
		OfficePainter.microwave(canvas, Vector2(50, 50))
		OfficePainter.kitchen_table(canvas, Vector2(100, 100))
		for level in [0, 3, 6]:
			for active in [true, false]:
				OfficePainter.coffee_machine(canvas, Vector2(50, 80), level, active, 0.1)
		ItemPainter.draw_person(canvas, Vector2(20, 20), AppTheme.PLAYER, 1.0, Color.TRANSPARENT, 1, AppTheme.TIE, true)
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_task_panel_shows_resting_employees() -> void:
	game.state.station("general_services/review").moods[0].rest(DeskMood.ASLEEP)
	game.state.station("general_services/review").staff = 1
	var panel := TaskPanel.new().setup(game)
	add_child_autofree(panel)
	panel.refresh()
	assert_gt(panel._rows.get_child_count(), 0)
	await wait_physics_frames(2)


func test_goals_sheet_starts_with_wisdom_banner() -> void:
	var sheet := _sheet(GoalsSheet.new())
	assert_gt(sheet.content.get_child_count(), GameConfig.GOALS.size())
	var banner := sheet.content.get_child(0) as PanelContainer
	assert_not_null(banner)
	await wait_physics_frames(2)


func test_department_sheets_for_all_departments() -> void:
	for dept_id in GameConfig.department_ids():
		var sheet := _sheet(SpotSheet.new(), UpgradeCatalog.room_spot(dept_id))
		assert_gt(sheet.content.get_child_count(), 4, dept_id)
		assert_eq(sheet.title(), UpgradeTexts.room_title(dept_id))
		sheet.refresh()
	await wait_physics_frames(2)


func test_sheet_actions_rebuild_and_close() -> void:
	var sheet := _sheet(SpotSheet.new(), "runners")
	watch_signals(sheet)
	var runners := game.state.runners.size()
	sheet.act(game.actions.hire_runner)
	assert_eq(game.state.runners.size(), runners + 1)
	sheet.close_sheet()
	assert_signal_emitted(sheet, "closed")
	sheet.close_sheet()
	await wait_physics_frames(2)


func test_station_card_labels() -> void:
	assert_ne(StationCard.label_for("tax_services/signature"), StationCard.label_for(GameConfig.COUNTER))
	var button := autofree(UiKit.button("")) as Button
	StationCard.update_button(button, "ACTION_BUY", 10.0, false, true, "LABEL_MAX_LEVEL")
	assert_true(button.disabled)
	assert_eq(button.text, button.tr("LABEL_MAX_LEVEL"))
	StationCard.update_button(button, "ACTION_BUY", 10.0, true, false, "LABEL_MAX_LEVEL")
	assert_false(button.disabled)
	assert_eq(button.text, button.tr("ACTION_BUY") + "\n" + UiKit.money(10.0))


func test_task_panel_lists_unlocked_departments() -> void:
	var panel := TaskPanel.new().setup(game)
	add_child_autofree(panel)
	panel.refresh()
	assert_eq(panel._rows.get_child_count(), GameConfig.DEPARTMENTS.size())
	watch_signals(panel)
	panel._toggle.pressed.emit()
	assert_false(panel.expanded)


func test_hud_task_panel_opens_the_department_spot() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	watch_signals(hud)
	hud.task_panel.open_department.emit("tax_services")
	assert_signal_emitted_with_parameters(hud, "open_sheet", ["spot", UpgradeCatalog.DEPT_PREFIX + "tax_services"])
	hud.task_panel.focus_department.emit("customs")
	assert_signal_emitted_with_parameters(hud, "focus_department", ["customs"])


func test_world_view_renders_and_handles_input() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	for dept_id in GameConfig.department_ids():
		game.simulation.spawn_case(game.state.department(dept_id))
	game.state.add_runner()
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	world.focus("customs")
	world._process(0.1)
	assert_eq(world._highlight_dept, "customs")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = world.get_viewport_rect().size * 0.5
	world._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(60, 0)
	world._unhandled_input(motion)
	assert_gt(game.state.player.input.x, 0.0)
	assert_true(joystick.active)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	world._unhandled_input(release)
	assert_eq(game.state.player.input, Vector2.ZERO)
	assert_false(joystick.active)


func _tap_world(world: WorldView, point: Vector2, wiggle: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	world._unhandled_input(press)
	if wiggle != Vector2.ZERO:
		var motion := InputEventMouseMotion.new()
		motion.position = point + wiggle
		motion.relative = wiggle
		world._unhandled_input(motion)
		var back := InputEventMouseMotion.new()
		back.position = point
		back.relative = -wiggle
		world._unhandled_input(back)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	world._unhandled_input(release)


func test_world_view_tap_opens_only_without_any_drag() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	world.top_inset = 0.0
	world.bottom_inset = 0.0
	world.position = Vector2.ZERO
	var point := world.layout.header("tax_services").get_center() * world.world_scale
	world.position = world.get_viewport_rect().size * 0.5 - point
	var screen := world.position + point
	_tap_world(world, screen, Vector2(1, 0))
	assert_signal_not_emitted(world, "open_spot")
	_tap_world(world, screen, Vector2.ZERO)
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.DEPT_PREFIX + "tax_services"])


func test_world_view_small_drag_moves_the_player() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = world.get_viewport_rect().size * 0.5
	world._unhandled_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(WorldView.STICK_DEADZONE + 2.0, 0)
	world._unhandled_input(motion)
	assert_gt(game.state.player.input.x, 0.0)


func test_world_view_tap_opens_department() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	assert_eq(world.tap_spot(world.layout.room("tax_services").get_center()), "station:tax_services/review")
	world._handle_tap(world.layout.header("tax_services").get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.DEPT_PREFIX + "tax_services"])
	game.state.department("customs").unlocked = false
	for key in GameConfig.department_station_keys("customs"):
		game.state.stations.erase(key)
	assert_eq(world.tap_spot(world.layout.room("customs").get_center()), UpgradeCatalog.DEPT_PREFIX + "customs")
	assert_eq(world.tap_spot(world.layout.area("customs/dock").get_center()), UpgradeCatalog.DEPT_PREFIX + "customs")
	world._handle_tap(world.layout.header("customs").get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.DEPT_PREFIX + "customs"])
	assert_eq(world.tap_spot(world.layout.place_area(GameConfig.HALL_INTAKE).get_center()), "seating")
	assert_signal_emit_count(world, "open_spot", 2)


func test_world_view_reacts_to_simulation_signals() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var sim := game.simulation
	sim.case_arrived.emit("general_services")
	sim.case_completed.emit("vehicle_registration", 10.0, false)
	sim.case_completed.emit("customs", 10.0, true)
	sim.citizen_left.emit("general_services")
	sim.contraband_found.emit("customs")
	sim.smuggling_missed.emit("customs")
	sim.ticket_called.emit(7)
	assert_gt(world._walkers.size(), 0)
	for walker in world._walkers:
		assert_true(["car", "truck"].has(walker.kind), str(walker.kind))
	assert_gt(world._floaters.size(), 3)
	world._advance_effects(10.0)
	assert_true(world._walkers.is_empty())
	assert_true(world._floaters.is_empty())


func test_item_painter_draws_every_product() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		for dept_id in GameConfig.department_ids():
			var case_file := CaseFile.new(dept_id, false, true)
			case_file.route = RouteBuilder.build(case_file)
			ItemPainter.draw_item(canvas, Vector2.ZERO, case_file)
			case_file.produced = true
			ItemPainter.draw_item(canvas, Vector2.ZERO, case_file)
		for variant in GameConfig.CUSTOMS_VARIANTS:
			var cargo := CaseFile.new("customs")
			cargo.variant = variant
			cargo.route = RouteBuilder.build(cargo)
			cargo.flagged = variant == "electronics"
			cargo.contraband = variant == "vehicles"
			ItemPainter.draw_stack(canvas, Vector2.ZERO, [cargo] as Array[CaseFile])
		ItemPainter.draw_output(canvas, Vector2.ZERO, "inspection")
		ItemPainter.draw_person(canvas, Vector2.ZERO, AppTheme.PLAYER, 1.0, AppTheme.PLAYER_HAT)
		ItemPainter.draw_truck(canvas, Vector2.ZERO)
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_office_painter_draws_every_element() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		OfficePainter.tiles(canvas, Rect2(0, 0, 100, 90))
		OfficePainter.plant(canvas, Vector2(50, 50))
		OfficePainter.cabinet(canvas, Rect2(0, 0, 60, 108))
		OfficePainter.clock(canvas, Vector2(30, 30), 20.0)
		OfficePainter.flag(canvas, Vector2(30, 100), 100.0, 1.0)
		OfficePainter.waiting_chair(canvas, Vector2(30, 30), 1.0)
		OfficePainter.queue_mark(canvas, Vector2(60, 30), 0.5)
		OfficePainter.ticket_dispenser(canvas, Vector2(30, 30))
		for occupied in [true, false]:
			OfficePainter.desk(canvas, Vector2(50, 50), occupied, occupied, 0.1)
			OfficePainter.desk(canvas, Vector2(50, 50), occupied, occupied, 0.1, true)
		for time in [0.1, 0.45]:
			OfficePainter.photo_booth(canvas, Vector2(80, 80), Color.WHITE, true, time)
		OfficePainter.photo_booth(canvas, Vector2(80, 80), Color.WHITE, false, 0.0)
		OfficePainter.lead_office(canvas, Rect2(0, 0, 160, 120), AppTheme.accent("primary"))
		OfficePainter.runner_lounge(canvas, Rect2(0, 0, 176, 140))
		ItemPainter.leave_warning(canvas, Vector2(20, 20))
		for dept_id in GameConfig.department_ids() + ["unknown"]:
			for time in [0.1, 0.45]:
				OfficePainter.machine(canvas, dept_id, Vector2(50, 50), Color.WHITE, true, time)
			OfficePainter.machine(canvas, dept_id, Vector2(50, 50), Color.WHITE, false, 0.0)
		for look in 12:
			ItemPainter.draw_person(canvas, Vector2(20, 20), AppTheme.PLAYER, 1.0, AppTheme.PLAYER_HAT, look, AppTheme.TIE)
		ItemPainter.draw_car(canvas, Vector2(20, 20), AppTheme.CAR)
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_world_view_adds_flavor_floaters_for_completed_cases() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.simulation.case_completed.emit("general_services", 10.0, false)
	game.simulation.case_completed.emit("general_services", 10.0, true)
	assert_eq(world._floaters.size(), 4)
	for i in 10:
		game.simulation.case_completed.emit("customs", 10.0, false)
	assert_lt(world._floaters.size(), 20)
	await wait_physics_frames(2)


func _tutorial_card() -> TutorialCard:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	var card := TutorialCard.new().setup(game, hud, 0.0)
	add_child_autofree(card)
	return card


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func test_tutorial_card_shows_info_step_with_next_button() -> void:
	var card := _tutorial_card()
	assert_true(card.visible)
	assert_true(card._next.visible)
	assert_false(card._waiting.visible)
	assert_eq(card._title.text, card.tr("TUTORIAL_WELCOME_TITLE"))
	watch_signals(card)
	card._next.pressed.emit()
	assert_eq(game.tutorial.current().id, "move")
	assert_eq(card._title.text, card.tr("TUTORIAL_MOVE_TITLE"))
	assert_false(card._next.visible)
	assert_true(card._waiting.visible)
	assert_signal_emitted(card, "highlight_changed")


func test_tutorial_card_reports_highlight_target() -> void:
	var card := _tutorial_card()
	watch_signals(card)
	game.tutorial.state.tutorial_step = Tutorial.index_of("upgrades_open")
	game.tutorial.changed.emit()
	assert_signal_emitted_with_parameters(card, "highlight_changed", ["upgrades"])
	game.tutorial.state.tutorial_step = Tutorial.index_of("goals_open")
	game.tutorial.changed.emit()
	assert_signal_emitted_with_parameters(card, "highlight_changed", ["goals"])


func test_tutorial_card_finish_label_on_last_step() -> void:
	var card := _tutorial_card()
	game.tutorial.state.tutorial_step = Tutorial.STEPS.size() - 1
	game.tutorial.changed.emit()
	assert_eq(card._next.text, card.tr("TUTORIAL_FINISH"))
	card._next.pressed.emit()
	assert_false(card.visible)


func test_tutorial_card_offers_step_skip_after_delay() -> void:
	var card := _tutorial_card()
	card._next.pressed.emit()
	assert_eq(game.tutorial.current().id, "move")
	game.tutorial.update(Tutorial.STEP_SKIP_DELAY)
	assert_true(card._next.visible)
	assert_false(card._waiting.visible)
	assert_eq(card._next.text, card.tr("TUTORIAL_SKIP_STEP"))
	card._next.pressed.emit()
	assert_eq(game.tutorial.current().id, "resources")
	assert_eq(card._next.text, card.tr("TUTORIAL_NEXT"))


func test_tutorial_card_skip_asks_for_confirmation() -> void:
	var card := _tutorial_card()
	watch_signals(card)
	var before := card.get_child_count()
	card._confirm_skip()
	assert_eq(card.get_child_count(), before + 1)
	assert_true(game.tutorial.is_active())
	var dialog := card.get_child(card.get_child_count() - 1) as AppDialog
	dialog.confirmed.emit()
	assert_false(game.tutorial.is_active())
	assert_false(card.visible)
	assert_signal_emitted_with_parameters(card, "highlight_changed", [""])
	card._process(0.0)


func test_tutorial_card_moves_to_top_while_a_sheet_is_open() -> void:
	var card := _tutorial_card()
	card._process(0.0)
	assert_eq(card.panel.anchor_top, 1.0)
	assert_lt(card.panel.offset_top, 0.0)
	game.tutorial.set_open_sheet("upgrades")
	card._process(0.0)
	assert_eq(card.panel.anchor_top, 0.0)
	assert_eq(card.panel.offset_top, float(AppTheme.SPACING_SM))


func test_hud_highlights_and_clears_targets() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	for item: Dictionary in Hud.NAV_ITEMS:
		hud.highlight(str(item.id))
		assert_eq(hud._highlighted, hud._nav_buttons[item.id])
	hud.highlight("upgrades")
	assert_eq(hud._highlighted, hud._nav_buttons["upgrades"])
	assert_not_null(hud._highlight_tween)
	hud.highlight("goal")
	assert_eq(hud._highlighted, hud._goal_card)
	assert_eq(hud._nav_buttons["upgrades"].modulate, Color.WHITE)
	hud.highlight("settings")
	assert_eq(hud._highlighted, hud._settings_button)
	hud.highlight("")
	assert_null(hud._highlighted)
	assert_null(hud._highlight_tween)
	assert_eq(hud._settings_button.modulate, Color.WHITE)
	hud.highlight("unknown")
	assert_null(hud._highlighted)


func test_settings_sheet_offers_tutorial_replay() -> void:
	var sheet := SettingsSheet.new().with_settings(AppSettings.new("user://test_settings_scene.cfg"))
	_sheet(sheet)
	watch_signals(sheet)
	var replay := _find_button(sheet.content, sheet.tr("TUTORIAL_REPLAY"))
	assert_not_null(replay)
	replay.pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "navigate", ["tutorial", ""])
	await wait_physics_frames(2)


func test_event_banner_offers_choices_and_resolves_them() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	game.state.cases_completed = 500
	game.simulation.start_event("authority_comparison")
	hud.refresh()
	assert_eq(hud._event_actions.get_child_count(), 2)
	assert_true(hud._event_actions.visible)
	var prepare := _find_button(hud._event_actions, hud.tr("EVENT_CHOICE_PREPARE"))
	assert_not_null(prepare)
	prepare.pressed.emit()
	assert_eq(game.state.event_choice, "prepare")
	hud.refresh()
	assert_false(hud._event_actions.visible)
	await wait_physics_frames(2)


func test_event_banner_without_choices_hides_actions() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	game.simulation.start_event("printer_jam")
	hud.refresh()
	assert_false(hud._event_actions.visible)
	game.simulation.start_event("staff_meeting")
	hud.refresh()
	assert_eq(hud._event_actions.get_child_count(), 1)
	await wait_physics_frames(2)


func test_department_spot_shows_jam_and_legend() -> void:
	var review := game.state.station("general_services/review")
	for i in review.outbox_capacity():
		review.outbox.append(CaseFile.new("general_services"))
	var sheet := _sheet(SpotSheet.new(), UpgradeCatalog.DEPT_PREFIX + "general_services")
	sheet.refresh()
	assert_true(_has_label(sheet.content, sheet.tr("LEGEND_MARKERS")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_JAM") % ("%s (%s)" % [StationCard.label_for("general_services/review"), sheet.tr("JAM_SIDE_OUT")])))
	await wait_physics_frames(2)


func test_complaint_spots_offer_intern_and_box_upgrades() -> void:
	game.state.money = 1.0e9
	var clerk_id := "%s:complaint_interns" % UpgradeCatalog.TRACK
	var sheet := _sheet(SpotSheet.new(), "complaint_desk")
	var clerk := UpgradeCatalog.find(game.state, clerk_id)
	assert_eq(clerk.level, 0)
	assert_true(_has_label(sheet.content, UpgradeTexts.title(clerk)))
	assert_true(_has_label(sheet.content, UpgradeTexts.level_text(clerk)))
	assert_true(_has_label(sheet.content, UpgradeTexts.effect(game.state, clerk)))
	assert_true(_has_label(sheet.content, "\n".join(SpotStatus.lines(game.state, "complaint_desk"))))
	_buy(sheet, clerk_id)
	clerk = UpgradeCatalog.find(game.state, clerk_id)
	assert_eq(clerk.level, 1)
	assert_eq(game.state.upgrade_level("complaint_interns"), 1)
	assert_eq(game.state.interns.size(), 1)
	assert_true(_has_label(sheet.content, UpgradeTexts.level_text(clerk)))
	assert_true(_has_label(sheet.content, UpgradeTexts.effect(game.state, clerk)))
	assert_true(_has_label(sheet.content, "\n".join(SpotStatus.lines(game.state, "complaint_desk"))))
	game.state.set_upgrade("complaint_interns", clerk.max_level)
	sheet.refresh()
	var maxed := UpgradeCatalog.find(game.state, clerk_id)
	assert_true(maxed.is_maxed())
	assert_false(UpgradeTexts.effect(game.state, maxed).contains("→"))
	assert_true(_has_label(sheet.content, UpgradeTexts.effect(game.state, maxed)))
	assert_not_null(_find_button(sheet.content, sheet.tr("LABEL_MAX_LEVEL")))
	var box_sheet := _sheet(SpotSheet.new(), "complaint_box")
	assert_true(_has_label(box_sheet.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "%s:complaint_box" % UpgradeCatalog.TRACK))))
	assert_true(_has_label(box_sheet.content, "\n".join(SpotStatus.lines(game.state, "complaint_box"))))
	var security_sheet := _sheet(SpotSheet.new(), "security")
	assert_true(_has_label(security_sheet.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "%s:complaint_security" % UpgradeCatalog.TRACK))))
	assert_true(_has_label(security_sheet.content, SpotStatus.security(game.state)))
	await wait_physics_frames(2)


func test_entrance_spot_and_statistics_show_population() -> void:
	var expected := TranslationServer.translate("FMT_POPULATION") % [UiKit.number(Formulas.population(game.state)), TranslationServer.translate("SETTLEMENT_VILLAGE")]
	assert_eq(SpotStatus.population(game.state), expected)
	var lines := SpotStatus.lines(game.state, "entrance")
	assert_has(lines, expected)
	var entrance := _sheet(SpotSheet.new(), "entrance")
	assert_true(_has_label(entrance.content, "\n".join(lines)))
	var statistics := _sheet(StatisticsSheet.new())
	statistics.refresh()
	assert_true(_has_label(statistics.content, expected))
	await wait_physics_frames(2)


func test_item_painter_draws_markers_and_experts() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	var licence := CaseFile.new("business_licences")
	licence.route = RouteBuilder.build(licence)
	licence.invalid = true
	licence.big = true
	var housing := CaseFile.new("housing")
	housing.route = RouteBuilder.build(housing)
	canvas.draw.connect(func() -> void:
		ItemPainter.draw_item(canvas, Vector2(40, 40), licence)
		ItemPainter.draw_item(canvas, Vector2(90, 40), housing)
		ItemPainter.draw_person(canvas, Vector2(40, 100), AppTheme.SPECIALIST_COAT, 1.0, Color.TRANSPARENT, 3, AppTheme.SPECIALIST, false, true)
		OfficePainter.desk(canvas, Vector2(120, 100), true, true, 0.2, true)
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_world_view_draws_tubes_capsules_and_reject_piles() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	_install_tubes()
	assert_true(game.state.tube_link("general_services/review", GameConfig.COUNTER))
	game.state.station("general_services/review").rejects = 3
	game.state.player.rejects = 2
	game.simulation.case_piped.emit("general_services/review", "shared/counter", "general_services")
	game.simulation.case_piped.emit("shared/reception", "general_services/review", "general_services")
	assert_eq(world._capsules.size(), 2)
	for i in 40:
		game.simulation.case_piped.emit("general_services/review", "shared/counter", "general_services")
	assert_lte(world._capsules.size(), WorldView.MAX_CAPSULES)
	game.simulation.case_piped.emit("general_services/review", "", "general_services")
	assert_eq(world._capsules.size(), WorldView.MAX_CAPSULES)
	var longest := 0.0
	for capsule in world._capsules:
		longest = maxf(longest, float(capsule.duration))
	for step in ceili(longest / 0.2) + 1:
		world._process(0.2)
	await wait_physics_frames(2)
	assert_eq(world._capsules.size(), 0)


func test_world_view_reacts_to_rejections() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.simulation.case_rejected.emit("general_services")
	assert_eq(world._floaters.size(), 1)
	assert_true(world._walkers.is_empty())
	await wait_physics_frames(2)


func test_citizens_enter_left_and_leave_right() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	world._sync_citizens(game.state)
	var citizen := game.simulation.spawn_case(game.state.department("general_services"))
	world._sync_citizens(game.state)
	assert_eq(world._citizens.entry_for(citizen).pos, world.layout.door_in())
	game.state.citizens.clear()
	world._sync_citizens(game.state)
	var leaver: Dictionary = world._walkers[world._walkers.size() - 1]
	assert_eq(leaver.from, world.layout.door_in())
	assert_eq(leaver.to, world.layout.door_out())
	assert_lt(world.layout.door_in().x, world.layout.door_out().x)
	await wait_physics_frames(2)


func test_world_view_marks_stations_affected_by_an_event() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.state.event_id = "system_crash"
	game.state.event_scope = "general_services"
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	assert_lt(Formulas.event_speed(game.state, game.state.station("general_services/review")), 1.0)


func test_task_panel_can_be_minimized() -> void:
	var panel := TaskPanel.new().setup(game)
	add_child_autofree(panel)
	panel.refresh()
	assert_true(panel.expanded)
	var full_width := panel.get_combined_minimum_size().x
	panel.toggle()
	assert_false(panel.expanded)
	assert_false(panel._rows.visible)
	assert_false(panel._toggle.visible)
	assert_true(panel._chevron.visible)
	assert_eq(panel._chevron.text, Icons.EXPAND_MORE)
	assert_eq(panel._chevron.theme_type_variation, "PrimaryIconTonal")
	assert_true(panel.get_theme_stylebox(&"panel") is StyleBoxEmpty)
	assert_lt(panel.get_combined_minimum_size().x, full_width * 0.5)
	panel.toggle()
	assert_true(panel.expanded)
	assert_true(panel._rows.visible)
	assert_true(panel._toggle.visible)
	assert_eq(panel._chevron.theme_type_variation, "NeutralIconStandard")


func test_hud_shows_review_banner_and_rating_chip() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	hud.refresh()
	assert_false(hud._review_banner.visible)
	assert_true(hud._rating_chip.visible)
	assert_eq(hud._rating_label.text, "–")
	game.state.add_review(5)
	game.state.add_review(1)
	hud.refresh()
	assert_true(hud._review_banner.visible)
	assert_true(hud._rating_chip.visible)
	assert_eq(hud._rating_label.text, UiKit.decimal(3.0))
	watch_signals(hud)
	hud._review_open.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "open_sheet", ["reviews", ""])
	var click := InputEventMouseButton.new()
	click.pressed = true
	hud._rating_chip.gui_input.emit(click)
	assert_signal_emit_count(hud, "open_sheet", 2)
	game.state.reviews.clear()
	hud.refresh()
	assert_false(hud._review_banner.visible)


func test_world_view_draws_sick_timer_bonus_and_cover_hint() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station("general_services/review")
	for i in 2:
		review.add_desk()
	review.staff = review.desks
	review.moods[0].rest(DeskMood.SICK)
	review.moods[0].bonus = 2
	review.moods[1].rest(DeskMood.SICK)
	review.moods[2].rest(DeskMood.FETCH, 0)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	review.jobs[2] = StationJob.new(case_file, 5.0)
	assert_true(review.can_cover(2))
	var floaters := world._floaters.size()
	game.simulation.bonus_left.emit("general_services/review", 0, 2)
	assert_eq(world._floaters.size(), floaters + 1)
	for layer in world._layers:
		layer.node.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func test_hud_bonus_card_appears_at_sick_desk_and_pays_bonus() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	var layout := WorldLayout.get_default()
	var review := game.state.station("general_services/review")
	review.add_desk()
	review.staff = review.desks
	game.state.player.position = Vector2(50, 50)
	hud.refresh()
	assert_false(hud._bonus_card.visible)
	assert_false(hud.leave_bonus(1))
	review.moods[1].rest(DeskMood.SICK)
	game.state.player.position = layout.desk_position("general_services/review", 1)
	hud.refresh()
	assert_true(hud._bonus_card.visible)
	assert_eq(hud._bonus_buttons.size(), GameConfig.sick_bonus_tiers())
	assert_true(hud._bonus_title.text.contains(NumberFormat.clock(GameConfig.SICK_SECONDS)))
	var fast := NumberFormat.clock(GameConfig.SICK_SECONDS / GameConfig.SICK_BONUS_SPEED[1])
	var expected := hud.tr("FMT_SICK_BONUS_BUTTON") % [hud.tr("SICK_BONUS_TIER_1"), UiKit.money(Formulas.sick_bonus_cost(game.state, 1)), fast]
	assert_eq(hud._bonus_buttons[0].text, expected)
	assert_eq(hud._bonus_text.text, hud.tr("SICK_BONUS_TEXT"))
	assert_false(hud._bonus_buttons[0].disabled)
	var money := game.state.money
	hud._bonus_buttons[1].pressed.emit()
	assert_eq(review.moods[1].bonus, 2)
	assert_lt(game.state.money, money)
	hud.refresh()
	assert_true(hud._bonus_buttons[0].disabled)
	assert_true(hud._bonus_buttons[1].disabled)
	assert_false(hud._bonus_buttons[2].disabled)
	var mood := review.moods[1]
	assert_true(hud._bonus_buttons[2].text.contains(UiKit.money(Formulas.sick_bonus_price(game.state, mood, 3))))
	assert_true(hud._bonus_buttons[2].text.contains(NumberFormat.clock(Formulas.sick_time_left_with(game.state, mood, 3))))
	game.state.money = 0.0
	hud.refresh()
	assert_true(hud._bonus_buttons[2].disabled)
	review.moods[1].wake(10.0)
	hud.refresh()
	assert_false(hud._bonus_card.visible)


func test_hud_income_comes_from_core_tracker() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	assert_eq(hud.income_per_minute(), 0.0)
	game.state.income.advance(1.0, 0.0)
	game.state.income.advance(1.0, 5.0)
	assert_almost_eq(hud.income_per_minute(), 300.0, 0.001)


func _ring_world() -> WorldView:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	return world


func _ring_ratios(world: WorldView, id: String) -> Array[float]:
	var ratios: Array[float] = []
	for entry: Dictionary in world._rings.get(id, []):
		ratios.append(float((entry.ratio as Callable).call()))
	return ratios


func test_progress_rings_follow_live_state_between_layer_redraws() -> void:
	var world := _ring_world()
	game.state.kranz = true
	game.state.kranz_progress = 0.0
	_layer_node(world, WorldView.KITCHEN_LAYER).queue_redraw()
	await wait_physics_frames(2)
	assert_eq(_ring_ratios(world, WorldView.KITCHEN_LAYER).max(), 0.0)
	game.state.kranz_progress = GameConfig.KRANZ_END_TIME * 0.5
	assert_almost_eq(_ring_ratios(world, WorldView.KITCHEN_LAYER).max(), 0.5, 0.001)
	game.state.kranz = false
	assert_eq(_ring_ratios(world, WorldView.KITCHEN_LAYER).max(), 0.0)
	world._actors.queue_redraw()
	await wait_physics_frames(2)
	assert_eq(world._ring_layer, "")


func test_progress_ring_of_mood_stops_when_state_changes() -> void:
	var world := _ring_world()
	var review := game.state.station("general_services/review")
	review.staff = 1
	review.moods[0].rest(DeskMood.CHAT, 0)
	_layer_node(world, WorldView.KITCHEN_LAYER).queue_redraw()
	await wait_physics_frames(2)
	review.moods[0].wake_progress = GameConfig.WAKE_TIME * 0.25
	assert_almost_eq(_ring_ratios(world, WorldView.KITCHEN_LAYER).max(), 0.25, 0.001)
	review.moods[0].state = DeskMood.AWAKE
	assert_eq(_ring_ratios(world, WorldView.KITCHEN_LAYER).max(), 0.0)


func test_progress_ring_of_phone_call_ends_with_the_call() -> void:
	var world := _ring_world()
	var outgoing := PhoneCall.new(PhoneCall.OUTGOING, "general_services/review", 0)
	outgoing.line = PhoneCall.PLAYER
	game.state.calls.append(outgoing)
	_layer_node(world, WorldView.OFFICE_LAYER).queue_redraw()
	await wait_physics_frames(2)
	outgoing.progress = outgoing.duration() * 0.6
	assert_almost_eq(_ring_ratios(world, WorldView.OFFICE_LAYER).max(), 0.6, 0.001)
	game.state.calls.clear()
	assert_eq(_ring_ratios(world, WorldView.OFFICE_LAYER).max(), 0.0)


func test_progress_ring_draws_directly_outside_layers() -> void:
	var world := _ring_world()
	var drawn := [0]
	var full := func() -> float:
		drawn[0] += 1
		return 2.0
	var empty := func() -> float:
		drawn[0] += 1
		return 0.0
	world._actors.draw.connect(func() -> void:
		world._canvas = world._actors
		world._progress_ring(Vector2.ZERO, 10.0, 2.0, func() -> Color: return AppTheme.accent("success"), full)
		world._progress_ring(Vector2.ZERO, 10.0, 2.0, AppTheme.MONEY, empty)
		world._canvas = world
	)
	world._actors.queue_redraw()
	await wait_physics_frames(2)
	assert_gt(drawn[0], 1)
	assert_false(world._rings.has(""))


func _world() -> WorldView:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	return world


func _citizen() -> CaseFile:
	return game.simulation.create_case(game.state.department("general_services"))


func _stage_of(placements: Array[Dictionary], case_file: CaseFile) -> String:
	for placement in placements:
		if placement.case == case_file:
			return str(placement.stage)
	return ""


func _in_phase(phase: CaseFile.Phase, seated: bool = false) -> CaseFile:
	var citizen := _citizen()
	citizen.phase = phase
	citizen.seated = seated
	citizen.spot = Vector2(100 + game.state.citizens.size() * 30, 400)
	game.state.citizens.append(citizen)
	return citizen


func test_world_view_places_every_citizen_by_phase() -> void:
	var world := _world()
	var state := game.state
	var in_line := _in_phase(CaseFile.Phase.LINE)
	var standing := _in_phase(CaseFile.Phase.WAITING)
	var seated := _in_phase(CaseFile.Phase.WAITING, true)
	var called := _in_phase(CaseFile.Phase.CALLED)
	var at_desk := _in_phase(CaseFile.Phase.SERVED)
	var waiting_doc := _in_phase(CaseFile.Phase.WAITING_DOC, true)
	var called_doc := _in_phase(CaseFile.Phase.CALLED_DOC)
	var collecting := _in_phase(CaseFile.Phase.COLLECTING)
	state.player.items.append(_citizen())
	var placements := world.citizen_placements(state)
	assert_eq(placements.size(), 8)
	assert_eq(_stage_of(placements, in_line), WorldView.STAGE_TICKET)
	assert_eq(_stage_of(placements, standing), WorldView.STAGE_WAITING)
	assert_eq(_stage_of(placements, seated), WorldView.STAGE_SEATED)
	assert_eq(_stage_of(placements, called), WorldView.STAGE_CALLED)
	assert_eq(_stage_of(placements, at_desk), WorldView.STAGE_DESK)
	assert_eq(_stage_of(placements, waiting_doc), WorldView.STAGE_SEATED)
	assert_eq(_stage_of(placements, called_doc), WorldView.STAGE_CALLED)
	assert_eq(_stage_of(placements, collecting), WorldView.STAGE_COUNTER)
	for placement in placements:
		assert_eq(placement.target, (placement.case as CaseFile).spot)


func test_desks_show_the_called_number() -> void:
	var world := _world()
	var state := game.state
	var reception := state.station(GameConfig.RECEPTION)
	assert_eq(world.called_number(reception, 0), 0)
	var citizen := game.simulation.spawn_case(state.department("general_services"))
	citizen.walk = 0.0
	assert_true(game.simulation.draw_ticket(citizen))
	citizen.walk = 0.0
	reception.staff = 1
	assert_true(game.simulation.call_citizens())
	assert_eq(world.called_number(reception, 0), citizen.ticket)
	citizen.walk = 0.0
	assert_true(game.simulation.start_job(reception, 0))
	assert_eq(world.called_number(reception, 0), citizen.ticket)
	reception.jobs[0] = StationJob.new(_citizen())
	assert_eq(world.called_number(reception, 0), 0)
	world._draw_queue()
	await wait_physics_frames(1)


func test_world_view_citizens_walk_out_in_their_own_colour() -> void:
	var world := _world()
	var state := game.state
	var leaving := _in_phase(CaseFile.Phase.COLLECTING)
	var angry := _in_phase(CaseFile.Phase.WAITING)
	world._sync_citizens(state)
	var look := int(world._citizens.entry_for(leaving).look)
	var angry_look := int(world._citizens.entry_for(angry).look)
	state.citizens.clear()
	var before := world._walkers.size()
	world._sync_citizens(state)
	assert_eq(world._walkers.size(), before + 2)
	var kinds := {}
	for walker in world._walkers.slice(before):
		kinds[walker.kind] = walker
	assert_eq(kinds.leave.color, WorldView.citizen_color(look))
	assert_eq(kinds.exit.color, WorldView.citizen_color(angry_look))
	assert_eq(kinds.exit.to, world.layout.door_out())
	world.queue_redraw()
	await wait_physics_frames(2)


func test_world_view_draws_the_ticket_corner_and_moving_citizens() -> void:
	var world := _world()
	var state := game.state
	var dept := state.department("general_services")
	for i in 3:
		game.simulation.spawn_case(dept)
	for i in 3:
		var citizen := game.simulation.spawn_case(dept)
		citizen.walk = 0.0
		game.simulation.draw_ticket(citizen)
	state.set_upgrade("ticket_speed", 100)
	state.set_upgrade("ticket_machine_2", 1)
	state.ticket_line[0].walk = 0.0
	state.ticket_line[0].draw_progress = 0.5
	assert_gt(world.ticket_ratio(state, 0), 0.0)
	assert_eq(world.ticket_ratio(state, 1), 0.0)
	assert_eq(world.ticket_ratio(state, 2), 0.0)
	assert_eq(world.furnishing_signature(state), Vector3i(GameConfig.BASE_SEATS, GameConfig.BASE_SEATS, 2))
	world._process(0.1)
	world._sync_citizens(state)
	game.simulation.spawn_case(dept)
	for step in 5:
		world._process(0.1)
		world.queue_redraw()
		await wait_physics_frames(1)
	var walking := 0
	for entry in world._citizens.entries.values():
		if CitizenTracker.is_walking(entry):
			walking += 1
	assert_gt(walking, 0)
	assert_eq(world._citizens.entries.size(), state.citizens.size())


func test_away_walk_hides_the_kitchen_guest_until_arrival() -> void:
	var world := _world()
	var review := game.state.station("general_services/review")
	review.staff = 1
	review.moods[0].rest(DeskMood.CHAT, 2)
	game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.CHAT)
	assert_true(world.is_guest_arriving("general_services/review", 0))
	var walker: Dictionary = world._walkers.back()
	assert_eq(walker.kind, "staff")
	assert_eq(walker.to, world.layout.slot_point(2))
	assert_eq(int(walker.look), WorldView.staff_look(review, 0))
	world._advance_effects(20.0)
	assert_false(world.is_guest_arriving("general_services/review", 0))
	review.moods[0].wake(1.0)
	review.moods[0].rest(DeskMood.ASLEEP)
	var before := world._walkers.size()
	game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.ASLEEP)
	assert_eq(world._walkers.size(), before)


func test_waking_during_the_walk_turns_the_employee_around() -> void:
	var world := _world()
	var review := game.state.station("general_services/review")
	review.staff = 1
	review.moods[0].rest(DeskMood.CHAT, 2)
	game.simulation.employee_dozed.emit("general_services/review", 0, DeskMood.CHAT)
	game.simulation.wake_up(review, 0, true)
	assert_false(world.is_guest_arriving("general_services/review", 0))
	assert_true(review.moods[0].is_absent())
	assert_eq(world._walkers.back().to, world.layout.desk_position("general_services/review", 0) + Vector2(0, -24))


func test_dispute_crew_walks_over_and_back() -> void:
	var world := _world()
	var review := game.state.station("general_services/review")
	while review.desks < 2:
		review.add_desk()
	review.staff = 2
	var dispute := game.simulation.start_dispute("radio", "general_services")
	assert_not_null(dispute)
	var crew := world.dispute_crew("general_services")
	assert_eq(crew.size(), 2)
	for member in crew:
		var station := game.state.station(str(member.key))
		assert_true(station.moods[int(member.desk)].is_disputing())
		assert_false(station.is_working(int(member.desk)))
	assert_true(world._leaving.has("dispute#general_services"))
	var walkers := world._walkers.size()
	world.queue_redraw()
	await wait_physics_frames(2)
	world._advance_effects(20.0)
	assert_false(world._leaving.has("dispute#general_services"))
	game.simulation.end_dispute(dispute, true)
	assert_eq(world._walkers.size(), 2)
	for walker in world._walkers:
		assert_eq(walker.kind, "staff")
		assert_almost_eq(float(walker.from.distance_to(world.layout.dispute_point("general_services"))), GameConfig.DISPUTE_CREW_OFFSET, 0.001)
	for member in crew:
		assert_true(game.state.station(str(member.key)).moods[int(member.desk)].is_returning())
	assert_false(world._dispute_crews.has("general_services"))
	assert_gt(walkers, 0)


func test_absent_desks_say_where_the_official_is() -> void:
	var mood := DeskMood.new()
	for rest_state in [DeskMood.LOO, DeskMood.CHAT, DeskMood.FETCH, DeskMood.SLOW, DeskMood.LUNCH]:
		mood.rest(rest_state, 1)
		assert_eq(WorldView.absence_text(mood), TranslationServer.translate("OFFICIAL_STATE_" + rest_state.to_upper()))
	mood.wake(1.0)
	assert_true(mood.join_dispute())
	assert_eq(WorldView.absence_text(mood), TranslationServer.translate("OFFICIAL_STATE_DISPUTE"))
	mood.arrive()
	mood.start_return(2.0)
	assert_eq(WorldView.absence_text(mood), TranslationServer.translate("OFFICIAL_STATE_RETURNING"))
	assert_ne(WorldView.absence_text(mood), "OFFICIAL_STATE_RETURNING")


func test_world_view_draws_every_absence_state() -> void:
	var world := _world()
	var review := game.state.station("general_services/review")
	while review.desks < 3:
		review.add_desk()
	review.staff = 3
	for rest_state in [DeskMood.LUNCH, DeskMood.ASLEEP, DeskMood.COFFEE]:
		review.moods[0].wake(1.0)
		review.moods[0].rest(rest_state, GameConfig.LUNCH_SLOT if rest_state == DeskMood.LUNCH else -1)
		review.moods[1].wake(1.0)
		review.moods[1].join_dispute()
		review.moods[2].start_return(3.0)
		world.queue_redraw()
		await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func test_world_view_draws_the_photo_booth_with_its_photographer() -> void:
	var world := _world()
	var photo := game.state.station(GameConfig.PHOTO_STATION)
	assert_not_null(photo)
	photo.staff = 1
	for layer in world._layers:
		layer.node.queue_redraw()
	world.queue_redraw()
	await wait_physics_frames(2)
	photo.moods[0].rest(DeskMood.ASLEEP)
	for layer in world._layers:
		layer.node.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func test_lead_sits_in_the_office_until_patrolling() -> void:
	var state := game.state
	var layout := WorldLayout.get_default()
	var room_id := "general_services"
	var review := state.station("general_services/review")
	review.staff = 1
	assert_eq(WorldView.lead_position(state, layout, room_id), layout.lead_seat(room_id))
	state.set_upgrade("team_lead", 1, room_id)
	assert_true(game.simulation.start_patrol(room_id))
	assert_eq(WorldView.lead_position(state, layout, room_id), layout.lead_seat(room_id))
	state.advance_patrols(GameConfig.LEAD_PATROL_SECONDS * 0.5)
	assert_ne(WorldView.lead_position(state, layout, room_id), layout.lead_seat(room_id))


func test_world_view_draws_lead_offices_and_patrols() -> void:
	var world := _world()
	var state := game.state
	state.station("general_services/review").staff = 1
	for layer in world._layers:
		layer.node.queue_redraw()
	world.queue_redraw()
	await wait_physics_frames(2)
	for room_id in [GameConfig.HALL_INTAKE, GameConfig.HALL_PICKUP, "general_services"]:
		state.set_upgrade("team_lead", 1, room_id)
	assert_true(game.simulation.start_patrol("general_services"))
	assert_true(game.simulation.start_patrol(GameConfig.HALL_PICKUP))
	state.lead_cooldowns[GameConfig.HALL_INTAKE] = 20.0
	world._process(0.1)
	for layer in world._layers:
		layer.node.queue_redraw()
	world.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func _patrol_button(sheet: Sheet) -> Button:
	for button in _all_buttons(sheet.content):
		if button.text == sheet.tr("ACTION_PATROL"):
			return button
	return null


func _all_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_all_buttons(child))
	return result


func test_lead_spot_sheet_starts_a_patrol() -> void:
	var room_id := "general_services"
	game.state.station("general_services/review").staff = 1
	var sheet := _sheet(SpotSheet.new(), GameConfig.lead_spot(room_id))
	assert_eq(sheet.title(), sheet.tr("FMT_SPOT_LEAD") % UpgradeTexts.room_title(room_id))
	assert_true(_has_label(sheet.content, sheet.tr("STATUS_NO_LEAD")))
	assert_true(_has_label(sheet.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "%s:%s" % [UpgradeCatalog.TRACK, GameConfig.upgrade_key("team_lead", room_id)]))))
	var patrol := _patrol_button(sheet)
	assert_not_null(patrol)
	assert_true(patrol.disabled)
	game.state.set_upgrade("team_lead", 1, room_id)
	sheet.rebuild()
	patrol = _patrol_button(sheet)
	assert_false(patrol.disabled)
	patrol.pressed.emit()
	assert_true(game.state.is_patrolling(room_id))
	sheet.refresh()
	assert_true(patrol.disabled)
	assert_eq(patrol.text, SpotSheet.patrol_label(game.state, room_id))
	assert_eq(SpotSheet.patrol_label(game.state, room_id), TranslationServer.translate("FMT_PATROL_ACTIVE") % UiKit.duration(game.state.patrol_left(room_id)))
	game.state.advance_patrols(GameConfig.LEAD_PATROL_SECONDS + 0.1)
	assert_eq(SpotSheet.patrol_label(game.state, room_id), TranslationServer.translate("FMT_PATROL_COOLDOWN") % UiKit.duration(game.state.patrol_cooldown(room_id)))
	await wait_physics_frames(2)
