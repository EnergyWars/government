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


func _sheet(sheet: Sheet, argument: String = "") -> Sheet:
	sheet.setup(game, argument)
	add_child_autofree(sheet)
	return sheet


func test_every_sheet_builds_content() -> void:
	var sheets: Array[Sheet] = [DepartmentsSheet.new(), TeamSheet.new(), ResearchSheet.new(), BuildingSheet.new(), GoalsSheet.new()]
	for sheet in sheets:
		_sheet(sheet)
		assert_gt(sheet.content.get_child_count(), 1, sheet.get_class())
		assert_false(sheet.title().is_empty())
	await wait_physics_frames(2)


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false


func test_department_sheet_offers_shared_stations_of_the_route() -> void:
	var licences := _sheet(DepartmentSheet.new(), "business_licences")
	assert_true(_has_label(licences.content, licences.tr("SECTION_SHARED_STATIONS")))
	assert_true(_has_label(licences.content, licences.tr("STATION_INSPECTION")))
	assert_true(_has_label(licences.content, licences.tr("STATION_RECEPTION")))
	var housing := _sheet(DepartmentSheet.new(), "housing")
	assert_true(_has_label(housing.content, housing.tr("STATION_GENERAL_SERVICES_REVIEW")))
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
	game.state.research["coffee"] = 3
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
	game.state.research["kitchen"] = 3
	game.state.research["coffee_machine"] = 4
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
	review.moods[0].rest(DeskMood.CHAT, 2)
	game.simulation.wake_up(review, 0, true)
	assert_true(world._returning.has("general_services/review#0"))
	var walkers := world._walkers.size()
	assert_gt(walkers, 0)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	world._process(10.0)
	assert_false(world._returning.has("general_services/review#0"))
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
	assert_signal_emitted_with_parameters(world, "open_room", [GameConfig.ROOM_PHONE])


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
	var point := world.layout.header("inspection").get_center()
	world._handle_tap(point)
	assert_signal_not_emitted(world, "open_room")
	game.state.unlock_department("business_licences")
	assert_not_null(game.state.station(GameConfig.INSPECTION))
	world._handle_tap(point)
	assert_signal_emitted_with_parameters(world, "open_room", [GameConfig.ROOM_INSPECTION])


func test_team_sheet_hires_hr() -> void:
	game.state.money = 1e9
	var sheet := TeamSheet.new().setup(game)
	add_child_autofree(sheet)
	await wait_physics_frames(2)
	assert_true(game.actions.hire_hr())
	sheet.refresh()
	assert_eq(game.state.hr, 1)


func test_world_view_layers_are_created_and_redrawn_selectively() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	assert_eq(world._layers.size(), 8 + world.layout.rooms.size())
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
	var sheet := BuildingSheet.new().setup(game)
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
	game.simulation.complaint_fended.emit()
	assert_eq(world._floaters.size(), floaters + 1)
	for outcome in ["expired", "lost", "deleted"]:
		game.simulation.review_removed.emit(outcome)
	assert_eq(world._floaters.size(), floaters + 4)
	game.state.complaint_clerk_level = GameConfig.COMPLAINT_CLERK_MAX_LEVEL
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
		var sheet := _sheet(DepartmentSheet.new(), dept_id)
		assert_gt(sheet.content.get_child_count(), 4, dept_id)
		sheet.refresh()
	await wait_physics_frames(2)


func test_sheet_actions_rebuild_and_close() -> void:
	var sheet := _sheet(TeamSheet.new())
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
	StationCard.update_button(button, "ACTION_HIRE", 10.0, false, true, "LABEL_MAX_LEVEL")
	assert_true(button.disabled)
	assert_eq(button.text, button.tr("LABEL_MAX_LEVEL"))


func test_task_panel_lists_unlocked_departments() -> void:
	var panel := TaskPanel.new().setup(game)
	add_child_autofree(panel)
	panel.refresh()
	assert_eq(panel._rows.get_child_count(), GameConfig.DEPARTMENTS.size())
	watch_signals(panel)
	panel._toggle.pressed.emit()
	assert_false(panel.expanded)


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


func test_world_view_tap_opens_department() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	world._handle_tap(world.layout.room("tax_services").get_center())
	assert_signal_not_emitted(world, "open_department")
	world._handle_tap(world.layout.header("tax_services").get_center())
	assert_signal_emitted_with_parameters(world, "open_department", ["tax_services"])
	game.state.department("customs").unlocked = false
	world._handle_tap(world.layout.room("customs").get_center())
	assert_signal_not_emitted(world, "open_departments")
	world._handle_tap(world.layout.header("customs").get_center())
	assert_signal_emitted(world, "open_departments")
	world._handle_tap(world.layout.hall.get_center())
	assert_signal_not_emitted(world, "open_room")


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
	assert_gt(world._walkers.size(), 2)
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
	game.tutorial.state.tutorial_step = 8
	game.tutorial.changed.emit()
	assert_signal_emitted_with_parameters(card, "highlight_changed", ["team"])


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
	game.tutorial.set_open_sheet("team")
	card._process(0.0)
	assert_eq(card.panel.anchor_top, 0.0)
	assert_eq(card.panel.offset_top, float(AppTheme.SPACING_SM))


func test_hud_highlights_and_clears_targets() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	hud.highlight("team")
	assert_eq(hud._highlighted, hud._nav_buttons["team"])
	assert_not_null(hud._highlight_tween)
	hud.highlight("goal")
	assert_eq(hud._highlighted, hud._goal_card)
	assert_eq(hud._nav_buttons["team"].modulate, Color.WHITE)
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


func test_departments_sheet_shows_jam_and_legend() -> void:
	var review := game.state.station("general_services/review")
	for i in review.outbox_capacity():
		review.outbox.append(CaseFile.new("general_services"))
	var sheet := _sheet(DepartmentsSheet.new())
	sheet.refresh()
	assert_true(_has_label(sheet.content, sheet.tr("LEGEND_MARKERS")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_JAM") % ("%s (%s)" % [StationCard.label_for("general_services/review"), sheet.tr("JAM_SIDE_OUT")])))
	await wait_physics_frames(2)


func test_building_sheet_offers_clerk_and_box_upgrades() -> void:
	game.state.money = 1.0e9
	var sheet := _sheet(BuildingSheet.new())
	sheet.refresh()
	var clerk: String = sheet.tr("FMT_WAITING_LEVEL") % [sheet.tr("COMPLAINT_CLERK_TITLE"), 0, GameConfig.COMPLAINT_CLERK_MAX_LEVEL]
	var box: String = sheet.tr("FMT_WAITING_LEVEL") % [sheet.tr("COMPLAINT_BOX_TITLE"), 0, GameConfig.COMPLAINT_BOX_MAX_LEVEL]
	assert_true(_has_label(sheet.content, clerk))
	assert_true(_has_label(sheet.content, box))
	assert_true(_has_label(sheet.content, UpgradeCards.complaint_clerk_info(game.state)))
	assert_true(game.actions.upgrade_complaint_clerk())
	sheet.refresh()
	assert_true(_has_label(sheet.content, UpgradeCards.complaint_clerk_info(game.state)))
	game.state.complaint_clerk_level = GameConfig.COMPLAINT_CLERK_MAX_LEVEL
	assert_false(UpgradeCards.complaint_clerk_info(game.state).contains("\n"))
	await wait_physics_frames(2)


func test_building_sheet_shows_population() -> void:
	var sheet := _sheet(BuildingSheet.new())
	sheet.refresh()
	var expected: String = sheet.tr("FMT_POPULATION") % [UiKit.number(Formulas.population(game.state)), sheet.tr("SETTLEMENT_VILLAGE")]
	assert_true(_has_label(sheet.content, expected))
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
	game.state.research["pneumatic_tubes"] = 1
	game.state.connect_all_tubes()
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
	for step in 30:
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
	assert_eq(world._walkers.size(), 1)
	assert_eq(world._walkers[0].to, world.layout.door_out())
	await wait_physics_frames(2)


func test_citizens_enter_left_and_leave_right() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	game.simulation.case_arrived.emit("general_services")
	assert_eq(world._walkers[0].from, world.layout.door_in())
	game.simulation.case_completed.emit("general_services", 10.0, false)
	var leaver: Dictionary = world._walkers[world._walkers.size() - 1]
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
	panel.toggle()
	assert_false(panel.expanded)
	panel.toggle()
	assert_true(panel.expanded)


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


func test_team_sheet_shows_helper_card() -> void:
	game.state.research["shredder_service"] = 1
	var sheet := _sheet(TeamSheet.new())
	sheet.refresh()
	assert_gt(sheet.get_child_count(), 0)


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
	_layer_node(world, WorldView.PHONE_LAYER).queue_redraw()
	await wait_physics_frames(2)
	outgoing.progress = outgoing.duration() * 0.6
	assert_almost_eq(_ring_ratios(world, WorldView.PHONE_LAYER).max(), 0.6, 0.001)
	game.state.calls.clear()
	assert_eq(_ring_ratios(world, WorldView.PHONE_LAYER).max(), 0.0)


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
