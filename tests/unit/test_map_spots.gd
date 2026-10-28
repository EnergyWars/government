extends GutTest

var layout: WorldLayout
var game: Game


func before_each() -> void:
	layout = WorldLayout.get_default()
	game = Game.new(GameState.create_new(8))


func _world() -> WorldView:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	return world


func _slot_center(point: Vector2) -> Vector2:
	return layout.slot_rect(point).get_center()


func test_every_static_spot_except_the_player_has_an_area() -> void:
	for spot: String in GameConfig.SPOTS:
		assert_eq(layout.spot_rects(spot).is_empty(), spot == GameConfig.ROOM_PLAYER, spot)


func test_static_spots_sit_in_their_room() -> void:
	for spot: String in GameConfig.SPOTS:
		var room := layout.service_room(GameConfig.spot_room(spot))
		for rect: Rect2 in layout.spot_rects(spot):
			assert_true(room.has_point(rect.get_center()), spot)


func test_service_rooms_have_header_spots() -> void:
	for room_id in GameConfig.SERVICE_ROOMS:
		var rects := layout.spot_rects(WorldLayout.ROOM_PREFIX + room_id)
		if room_id == GameConfig.ROOM_PLAYER:
			assert_true(rects.is_empty())
		else:
			assert_eq(rects, [layout.room_header(room_id)], room_id)
	assert_eq(layout.room_header(GameConfig.ROOM_HALL), layout.hall_plate())


func test_department_station_and_tube_spots() -> void:
	for dept_id in GameConfig.department_ids():
		assert_eq(layout.spot_rects(WorldLayout.DEPT_PREFIX + dept_id), [layout.header(dept_id)], dept_id)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		assert_eq(layout.spot_rects(WorldLayout.TUBE_PREFIX + room_id), [layout.slot_rect(layout.tube_station_point(room_id))], room_id)
	for key: String in layout.areas:
		assert_eq(layout.spot_rects(WorldLayout.STATION_PREFIX + key), [layout.area(key)], key)


func test_department_slots_stay_inside_their_room() -> void:
	for dept_id in GameConfig.department_ids():
		var room := layout.room(dept_id)
		assert_true(room.encloses(layout.slot_rect(layout.tube_station_point(dept_id))), dept_id)


func test_spot_at_prefers_the_smallest_area() -> void:
	assert_eq(layout.spot_at(layout.header("tax_services").get_center()), "dept:tax_services")
	assert_eq(layout.spot_at(layout.area("general_services/review").get_center()), "station:general_services/review")
	assert_eq(layout.spot_at(_slot_center(layout.tube_station_point("general_services"))), "tube:general_services")
	assert_eq(layout.spot_at(_slot_center(layout.tube_station_point(GameConfig.ROOM_HALL))), "tube:hall")
	assert_eq(layout.spot_at(_slot_center(layout.tube_station_point(GameConfig.ROOM_MAIL))), "tube:mail")
	assert_eq(layout.spot_at(layout.ticket_machine_point()), "tickets")
	assert_eq(layout.spot_at(layout.hall_plate().get_center()), "room:hall")
	assert_eq(layout.spot_at(layout.server_rect().get_center()), "server")
	assert_eq(layout.spot_at(layout.runners_board().get_center()), "runners")
	assert_eq(layout.spot_at(Vector2(1.0, 1.0)), "")


func test_room_at_finds_departments_and_service_rooms() -> void:
	assert_eq(layout.room_at(layout.room("tax_services").get_center()), "tax_services")
	assert_eq(layout.room_at(layout.room("inspection").get_center()), GameConfig.ROOM_INSPECTION)
	assert_eq(layout.room_at(layout.hall.get_center()), GameConfig.ROOM_HALL)
	assert_eq(layout.room_at(layout.kitchen.get_center()), GameConfig.ROOM_KITCHEN)
	assert_eq(layout.room_at(layout.toilets.get_center()), GameConfig.ROOM_TOILETS)
	assert_eq(layout.room_at(layout.phone_office.get_center()), GameConfig.ROOM_PHONE)
	assert_eq(layout.room_at(layout.mail_room.get_center()), GameConfig.ROOM_MAIL)
	assert_eq(layout.room_at(layout.complaint_office.get_center()), GameConfig.ROOM_COMPLAINTS)
	assert_eq(layout.room_at(layout.shredder_room.get_center()), GameConfig.ROOM_SHREDDER)
	assert_eq(layout.room_at(layout.tech_room.get_center()), GameConfig.ROOM_TECH)
	assert_eq(layout.room_at(layout.staff_room.get_center()), GameConfig.ROOM_STAFF)
	assert_eq(layout.room_at(Vector2(1.0, 1.0)), "")
	assert_eq(layout.room_at(Vector2(layout.complaint_office.end.x + WorldLayout.GAP * 0.5, layout.complaint_office.get_center().y)), "")


func test_service_rooms_stack_in_a_column_right_of_the_departments() -> void:
	var column: Array[Rect2] = [layout.tech_room, layout.toilets, layout.kitchen, layout.phone_office, layout.mail_room, layout.player_office, layout.staff_room, layout.shredder_room, layout.complaint_office]
	for i in column.size():
		assert_eq(column[i].position.x, WorldLayout.MAIN_WIDTH, str(i))
		assert_eq(column[i].size.x, WorldLayout.SIDE_WIDTH, str(i))
		if i > 0:
			assert_almost_eq(column[i].position.y, column[i - 1].end.y + WorldLayout.GAP, 0.01, str(i))
		for slot: String in layout.rooms:
			assert_lt(layout.rooms[slot].end.x, column[i].position.x, slot)
	assert_eq(layout.complaint_office.end.y, layout.hall.end.y)
	assert_lt(layout.hall.end.x, layout.complaint_office.position.x)
	assert_almost_eq(layout.size.x, WorldLayout.WIDTH, 0.01)
	assert_lt(layout.complaint_office.end.x, layout.size.x)
	assert_true(layout.complaint_office.has_point(layout.complaint_box_point()))
	assert_lt(layout.complaint_box_point().distance_to(layout.office_door()), layout.complaint_box_point().distance_to(layout.tech_door()))
	assert_true(layout.complaint_office.encloses(layout.security_rect()))
	assert_eq(layout.spot_rects("security"), [layout.security_rect()])
	assert_eq(layout.spot_at(layout.security_rect().get_center()), "security")
	assert_eq(GameConfig.spot_room("security"), GameConfig.ROOM_COMPLAINTS)
	assert_false(layout.complaint_office.has_point(layout.security_stop_spot()))
	assert_lt(layout.player_office.get_center().distance_to(layout.hall.get_center()), layout.tech_room.get_center().distance_to(layout.hall.get_center()))
	assert_gte(layout.tech_room.position.y, WorldLayout.MARGIN)


func test_staff_room_holds_every_staff_board_near_the_hall() -> void:
	var staff := layout.staff_room
	assert_eq(layout.service_room(GameConfig.ROOM_STAFF), staff)
	assert_lt(staff.get_center().distance_to(layout.hall.get_center()), layout.kitchen.get_center().distance_to(layout.hall.get_center()))
	assert_eq(layout.staff_door().x, staff.position.x)
	var boards: Array[Rect2] = []
	for board in GameConfig.STAFF_ROOM_BOARDS:
		var rect := layout.staff_board(board)
		assert_true(staff.encloses(rect), board)
		assert_gt(rect.position.y, layout.room_header(GameConfig.ROOM_STAFF).end.y, board)
		for other in boards:
			assert_false(rect.intersects(other), board)
		boards.append(rect)
		assert_eq(layout.spot_rects(board), [rect], board)
		assert_eq(layout.spot_at(rect.get_center()), board, board)
		assert_eq(GameConfig.spot_room(board), GameConfig.ROOM_STAFF, board)
	assert_eq(layout.staff_board("unknown"), layout.staff_board(GameConfig.STAFF_ROOM_BOARDS[0]))
	for rect in [layout.coffee_interns_board(), layout.sick_board(), layout.training_board(), layout.works_council_board()]:
		assert_true(staff.encloses(rect))
	assert_false(staff.intersects(layout.runners_board()))


func test_phone_office_and_mail_room_are_small() -> void:
	assert_lt(layout.phone_office.get_area(), layout.hall.get_area() * 0.25)
	assert_lt(layout.mail_room.get_area(), layout.hall.get_area() * 0.35)
	assert_true(layout.phone_office.has_point(layout.operator_point()))
	assert_eq(layout.operator_point(0), layout.operator_point(5))
	assert_eq(GameConfig.MAX_HR, 1)
	assert_true(layout.mail_room.encloses(layout.area(GameConfig.MAILROOM)))
	assert_true(layout.mail_room.encloses(layout.mail_storage_rect()))
	assert_false(layout.mail_storage_rect().intersects(layout.area(GameConfig.MAILROOM)))
	assert_true(layout.mail_room.has_point(layout.mail_door()))
	assert_gt(layout.mail_street().x, layout.size.x)


func test_player_office_holds_desk_phone_and_trophies() -> void:
	var office := layout.player_office
	assert_eq(layout.service_room(GameConfig.ROOM_OFFICE), office)
	assert_eq(layout.room_at(office.get_center()), GameConfig.ROOM_OFFICE)
	for point in [layout.office_desk_point(), layout.phone_point(), layout.office_gift_point(), layout.office_letter_point(), layout.player_office_door()]:
		assert_true(office.has_point(point) or point.x == office.position.x)
	assert_true(layout.near(layout.phone_point(), layout.office_desk_point()))
	assert_true(layout.near(layout.office_gift_point(), layout.office_desk_point()))
	for rect in [layout.employee_of_month_rect(), layout.certificate_rect(), layout.trophy_shelf_rect()]:
		assert_true(office.encloses(rect))
		assert_false(rect.has_point(layout.office_desk_point()))
	assert_false(layout.employee_of_month_rect().intersects(layout.certificate_rect()))
	assert_false(layout.phone_office.has_point(layout.phone_point()))
	assert_eq(layout.line_point(PhoneCall.PLAYER), layout.phone_point())


func test_tap_on_the_player_opens_the_player_spot() -> void:
	var world := _world()
	var player := game.state.player.position
	assert_eq(world.tap_spot(player), GameConfig.ROOM_PLAYER)
	assert_eq(world.tap_spot(player + Vector2(WorldView.PLAYER_TAP_RADIUS - 1.0, 0.0)), GameConfig.ROOM_PLAYER)
	assert_ne(world.tap_spot(player + Vector2(WorldView.PLAYER_TAP_RADIUS + 1.0, 0.0)), GameConfig.ROOM_PLAYER)


func test_taps_open_the_smallest_spot() -> void:
	var world := _world()
	game.state.set_upgrade("pneumatic_tubes", 1)
	assert_eq(world.tap_spot(layout.area("general_services/review").get_center()), "station:general_services/review")
	assert_eq(world.tap_spot(layout.area(GameConfig.RECEPTION).position + Vector2(60.0, 18.0)), "station:" + GameConfig.RECEPTION)
	assert_eq(world.tap_spot(layout.area(GameConfig.COUNTER).position + Vector2(60.0, 18.0)), "station:" + GameConfig.COUNTER)
	assert_eq(world.tap_spot(layout.place_area(GameConfig.HALL_INTAKE).get_center()), "seating")
	assert_eq(world.tap_spot(layout.seating_sign_rect(GameConfig.HALL_INTAKE).get_center()), "seating")
	assert_eq(world.tap_spot(layout.place_area(GameConfig.HALL_PICKUP).get_center()), "pickup_seating")
	assert_eq(world.tap_spot(layout.standing_sign_rect(GameConfig.HALL_PICKUP).get_center()), "pickup_seating")
	assert_eq(world.tap_spot(layout.ticket_area.get_center()), "tickets")
	assert_eq(world.tap_spot(_slot_center(layout.tube_station_point("general_services"))), "tube:general_services")
	assert_eq(world.tap_spot(layout.runners_board().get_center()), "runners")
	assert_eq(world.tap_spot(layout.complaint_read_rect().get_center()), "complaint_desk")
	assert_eq(world.tap_spot(layout.server_rect().get_center()), "server")


func test_taps_outside_spots_open_the_room() -> void:
	var world := _world()
	assert_eq(world.tap_spot(layout.room("general_services").position + Vector2(5.0, 300.0)), "dept:general_services")
	assert_eq(world.tap_spot(layout.hall.position + Vector2(20.0, 700.0)), UpgradeCatalog.room_spot(GameConfig.ROOM_HALL))
	assert_eq(world.tap_spot(Vector2(1.0, 1.0)), "")


func test_taps_in_locked_departments_open_the_opening() -> void:
	var world := _world()
	assert_false(game.state.department("tax_services").unlocked)
	assert_eq(world.tap_spot(layout.area("tax_services/review").get_center()), "dept:tax_services")
	assert_eq(world.tap_spot(_slot_center(layout.tube_station_point("tax_services"))), "dept:tax_services")
	game.state.unlock_department("tax_services")
	assert_eq(world.tap_spot(layout.area("tax_services/review").get_center()), "station:tax_services/review")


func test_taps_on_headers_open_their_room() -> void:
	var world := _world()
	for dept_id in GameConfig.department_ids():
		assert_eq(world.tap_spot(layout.header(dept_id).get_center()), UpgradeCatalog.DEPT_PREFIX + dept_id, dept_id)
	for room_id in GameConfig.SERVICE_ROOMS:
		var header := layout.room_header(room_id)
		if header.has_area():
			assert_eq(world.tap_spot(header.get_center()), UpgradeCatalog.ROOM_PREFIX + room_id, room_id)


func test_tap_emits_open_spot_only_for_hits() -> void:
	var world := _world()
	watch_signals(world)
	world._handle_tap(layout.header("general_services").get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", ["dept:general_services"])
	world._handle_tap(Vector2(1.0, 1.0))
	assert_signal_emit_count(world, "open_spot", 1)


func test_focus_spot_highlights_until_the_focus_ends() -> void:
	var world := _world()
	world.focus_spot("entrance")
	assert_eq(world.highlighted_spot(), "entrance")
	assert_eq(world.focus_point(), layout.spot_center("entrance"))
	world.focus_spot("nope")
	assert_eq(world.highlighted_spot(), "entrance")
	world._process(WorldView.FOCUS_TIME + 0.1)
	assert_eq(world.highlighted_spot(), "")


func test_focus_spot_on_the_player() -> void:
	var world := _world()
	world.focus_spot(GameConfig.ROOM_PLAYER)
	assert_eq(world.highlighted_spot(), GameConfig.ROOM_PLAYER)
	assert_eq(world.focus_point(), game.state.player.position)


func test_focusing_a_room_clears_the_spot_highlight() -> void:
	var world := _world()
	world.focus_spot("entrance")
	world.focus("tax_services")
	assert_eq(world.highlighted_spot(), "")
	assert_eq(world.focus_point(), layout.room("tax_services").get_center())


func test_highlights_are_drawn() -> void:
	var world := _world()
	for spot in ["entrance", "security", GameConfig.ROOM_PLAYER]:
		world.focus_spot(spot)
		world._process(0.1)
		world.queue_redraw()
		await wait_physics_frames(2)
	assert_eq(world.highlighted_spot(), GameConfig.ROOM_PLAYER)


func test_tube_pairs_need_stations_at_both_ends() -> void:
	var state := game.state
	assert_true(WorldView.tube_pairs(state).is_empty())
	state.set_upgrade("pneumatic_tubes", 1)
	assert_true(WorldView.tube_pairs(state).is_empty())
	state.set_upgrade("tube_station", 1, "general_services")
	assert_eq(WorldView.tube_pairs(state), ["general_services/review>general_services/signature"] as Array[String])
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	assert_eq(WorldView.tube_pairs(state), ["shared/reception>general_services/review", "general_services/review>general_services/signature", "general_services/signature>shared/counter"] as Array[String])


func test_tube_pairs_are_unique_across_departments() -> void:
	var state := game.state
	state.unlock_department("tax_services")
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	var pairs := WorldView.tube_pairs(state)
	for pair in pairs:
		assert_eq(pairs.count(pair), 1, pair)
		assert_true(state.tube_link(pair.get_slice(">", 0), pair.get_slice(">", 1)), pair)
	assert_true(pairs.has("shared/reception>tax_services/review"))


func test_only_the_central_shredder_exists() -> void:
	assert_true(layout.shredder_room.has_point(layout.shredder_point()))
	assert_eq(layout.spot_at(layout.shredder_point()), "shredder")
	for method in ["dept_shredder_point", "shredder_points", "nearest_shredder", "collector_home", "collectors_board"]:
		assert_false(layout.has_method(method), method)
	for dept_id in GameConfig.department_ids():
		assert_true(layout.spot_rects("shredder:" + dept_id).is_empty(), dept_id)


func test_tier_maps_levels_to_visual_steps() -> void:
	assert_eq(WorldView.tier(0, 100, 4), 0)
	assert_eq(WorldView.tier(-3, 100, 4), 0)
	assert_eq(WorldView.tier(5, 0, 4), 0)
	assert_eq(WorldView.tier(1, 100, 4), 1)
	assert_eq(WorldView.tier(25, 100, 4), 1)
	assert_eq(WorldView.tier(26, 100, 4), 2)
	assert_eq(WorldView.tier(100, 100, 4), 4)
	assert_eq(WorldView.tier(500, 100, 4), 4)


func test_new_rooms_have_their_own_layers() -> void:
	var world := _world()
	var ids: Array[String] = []
	for layer in world._layers:
		ids.append(layer.id)
	for layer_id in [WorldView.COMPLAINT_LAYER, WorldView.SHREDDER_LAYER, WorldView.TECH_LAYER]:
		assert_true(ids.has(layer_id), layer_id)


func test_map_draws_slots_stations_and_reject_runners() -> void:
	var world := _world()
	var state := game.state
	state.unlock_department("tax_services")
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("climate_control", 50)
	state.set_upgrade("it_support", 30)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	var reject_runner := state.add_runner(Runner.REJECT)
	reject_runner.position = layout.shredder_point() + Vector2(-40, 20)
	reject_runner.loaded = 3
	state.add_runner(Runner.INTAKE)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func test_new_painters_draw() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		for units in [0, 3, OfficePainter.SERVER_UNITS + 2]:
			OfficePainter.server_rack(canvas, Rect2(10, 10, 90, 150), units, 0.4)
		for level in [0, 30, 100]:
			OfficePainter.climate_unit(canvas, Rect2(120, 10, 100, 60), level, 0.4)
		for active in [true, false]:
			OfficePainter.tube_hub(canvas, Vector2(300, 80), active, 0.7)
		OfficePainter.tube_station(canvas, Vector2(400, 80), 0.2)
		OfficePainter.tube_station(canvas, Vector2(400, 80), 0.9)
		OfficePainter.empty_slot(canvas, Rect2(450, 50, 88, 52))
		OfficePainter.empty_slot(canvas, Rect2(450, 50, 0, 0))
		OfficePainter.toilet_stalls(canvas, Vector2(10, 200), [])
		OfficePainter.toilet_stalls(canvas, Vector2(10, 300), [true, false], WorldLayout.LOO_PITCH)
		OfficePainter.mail_shelf(canvas, Rect2(10, 400, 280, 270), 500, OfficePainter.SHELF_LETTERS * 4)
		OfficePainter.mail_shelf(canvas, Rect2(300, 400, 280, 270), 0, 0)
		for active in [true, false]:
			OfficePainter.shredder(canvas, Vector2(600, 300), active, 0.3)
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func _ids(spot: String) -> Array[String]:
	var ids: Array[String] = []
	for entry in UpgradeCatalog.entries_for_spot(game.state, spot):
		ids.append(entry.id)
	return ids


func test_tray_spots_cover_the_trays_of_every_station() -> void:
	for key: String in layout.areas:
		var spot := UpgradeCatalog.TRAYS_PREFIX + key
		var points := layout.tray_points(key)
		assert_eq(layout.spot_rects(spot).size(), points.size(), key)
		for point in points:
			assert_has(layout.spot_rects(spot), layout.tray_rect(point), key)
			assert_true(layout.tray_rect(point).has_point(point), key)
		assert_eq(GameConfig.spot_room(spot), GameConfig.station_room(key), key)
	assert_eq(layout.tray_points(GameConfig.RECEPTION), [layout.output_point(GameConfig.RECEPTION), layout.reject_point(GameConfig.RECEPTION)] as Array[Vector2])
	assert_eq(layout.tray_points(GameConfig.COUNTER), [layout.input_point(GameConfig.COUNTER), layout.reject_point(GameConfig.COUNTER)] as Array[Vector2])
	var review := "general_services/review"
	assert_eq(layout.tray_points(review), [layout.input_point(review), layout.output_point(review), layout.reject_point(review)] as Array[Vector2])
	assert_eq(layout.spot_at(layout.output_point(review)), UpgradeCatalog.TRAYS_PREFIX + review)


func test_station_and_tray_spots_split_the_station_upgrades() -> void:
	var review := "general_services/review"
	var station := _ids(UpgradeCatalog.STATION_PREFIX + review)
	var trays := _ids(UpgradeCatalog.TRAYS_PREFIX + review)
	station.sort()
	trays.sort()
	assert_eq(station, ["desk:" + review, "hire:" + review, "track:room_speed@general_services"] as Array[String])
	assert_eq(trays, ["reject_pile:" + review, "track:room_trays@general_services"] as Array[String])
	var header := _ids(UpgradeCatalog.DEPT_PREFIX + "general_services")
	for entry_id in station + trays:
		assert_true(header.has(entry_id), entry_id)
	var reception := _ids(UpgradeCatalog.TRAYS_PREFIX + GameConfig.RECEPTION)
	reception.sort()
	assert_eq(reception, ["reject_pile:" + GameConfig.RECEPTION, "track:room_trays@hall"] as Array[String])
	assert_true(_ids(UpgradeCatalog.STATION_PREFIX + GameConfig.RECEPTION).has("track:room_speed@hall"))
	assert_false(_ids(UpgradeCatalog.STATION_PREFIX + GameConfig.RECEPTION).has("track:room_trays@hall"))


func test_every_upgrade_is_reachable_without_a_room_header() -> void:
	var state := game.state
	state.money = 1e15
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	state.add_runner()
	var reachable := {}
	for spot: String in layout.spots:
		if spot.begins_with(UpgradeCatalog.DEPT_PREFIX) or spot.begins_with(UpgradeCatalog.ROOM_PREFIX):
			continue
		for entry_id in _ids(spot):
			reachable[entry_id] = true
	for entry_id in _ids(GameConfig.ROOM_PLAYER):
		reachable[entry_id] = true
	for entry in UpgradeCatalog.entries(state):
		if entry.kind == UpgradeCatalog.UNLOCK or entry.kind == UpgradeCatalog.RANK:
			continue
		assert_true(reachable.has(entry.id), entry.id)


func test_spot_sheet_groups_only_header_spots() -> void:
	var two: Array[String] = ["a", "b"]
	var one: Array[String] = ["a"]
	assert_true(SpotSheet.is_grouped(UpgradeCatalog.DEPT_PREFIX + "general_services", two))
	assert_true(SpotSheet.is_grouped(UpgradeCatalog.ROOM_PREFIX + GameConfig.ROOM_HALL, two))
	assert_false(SpotSheet.is_grouped(UpgradeCatalog.DEPT_PREFIX + "general_services", one))
	assert_false(SpotSheet.is_grouped(UpgradeCatalog.STATION_PREFIX + "general_services/review", two))
	assert_false(SpotSheet.is_grouped(UpgradeCatalog.TRAYS_PREFIX + "general_services/review", two))


func test_tray_spot_texts_and_status() -> void:
	var state := game.state
	var review := "general_services/review"
	var spot := UpgradeCatalog.TRAYS_PREFIX + review
	assert_eq(UpgradeTexts.spot_title(spot), TranslationServer.translate("FMT_SPOT_TRAYS") % StationCard.label_for(review))
	assert_eq(UpgradeTexts.spot_icon(spot), Icons.INBOX)
	assert_ne(UpgradeTexts.spot_description(spot), "SPOT_DESC_TRAYS")
	assert_eq(SpotStatus.trays(state, review).size(), 3)
	assert_eq(SpotStatus.trays(state, GameConfig.RECEPTION).size(), 2)
	assert_eq(SpotStatus.trays(state, GameConfig.COUNTER).size(), 2)
	var station := state.station(review)
	for i in station.outbox_capacity():
		station.outbox.append(CaseFile.new("general_services"))
	assert_true(station.is_output_jammed())
	assert_has(SpotStatus.trays(state, review), TranslationServer.translate("STATUS_OUTPUTS_JAMMED"))
	assert_true(SpotStatus.trays(state, "nope/review").is_empty())
	assert_eq(SpotStatus.lines(state, spot), SpotStatus.trays(state, review))
