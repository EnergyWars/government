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


func test_department_station_shredder_and_tube_spots() -> void:
	for dept_id in GameConfig.department_ids():
		assert_eq(layout.spot_rects(WorldLayout.DEPT_PREFIX + dept_id), [layout.header(dept_id)], dept_id)
		assert_eq(layout.spot_rects(WorldLayout.SHREDDER_PREFIX + dept_id).is_empty(), GameConfig.is_customs(dept_id), dept_id)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		assert_eq(layout.spot_rects(WorldLayout.TUBE_PREFIX + room_id), [layout.slot_rect(layout.tube_station_point(room_id))], room_id)
	for key: String in layout.areas:
		assert_eq(layout.spot_rects(WorldLayout.STATION_PREFIX + key), [layout.area(key)], key)


func test_department_slots_stay_inside_their_room() -> void:
	for dept_id in GameConfig.department_ids():
		var room := layout.room(dept_id)
		assert_true(room.encloses(layout.slot_rect(layout.tube_station_point(dept_id))), dept_id)
		if not GameConfig.is_customs(dept_id):
			assert_true(room.encloses(layout.slot_rect(layout.dept_shredder_point(dept_id))), dept_id)
			assert_false(layout.slot_rect(layout.dept_shredder_point(dept_id)).intersects(layout.slot_rect(layout.tube_station_point(dept_id))), dept_id)


func test_spot_at_prefers_the_smallest_area() -> void:
	assert_eq(layout.spot_at(layout.header("tax_services").get_center()), "dept:tax_services")
	assert_eq(layout.spot_at(layout.area("general_services/review").get_center()), "station:general_services/review")
	assert_eq(layout.spot_at(_slot_center(layout.dept_shredder_point("tax_services"))), "shredder:tax_services")
	assert_eq(layout.spot_at(_slot_center(layout.tube_station_point("general_services"))), "tube:general_services")
	assert_eq(layout.spot_at(_slot_center(layout.tube_station_point(GameConfig.ROOM_HALL))), "tube:hall")
	assert_eq(layout.spot_at(_slot_center(layout.tube_station_point(GameConfig.ROOM_MAIL))), "tube:mail")
	assert_eq(layout.spot_at(layout.ticket_display_rect().get_center()), "ticket_display")
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
	assert_eq(layout.room_at(Vector2(1.0, 1.0)), "")
	assert_eq(layout.room_at(Vector2(layout.complaint_office.end.x + WorldLayout.GAP * 0.5, layout.complaint_office.get_center().y)), "")


func test_service_rooms_sit_next_to_each_other_above_the_hall() -> void:
	assert_eq(layout.complaint_office.position.y, layout.shredder_room.position.y)
	assert_eq(layout.shredder_room.position.y, layout.tech_room.position.y)
	assert_almost_eq(layout.shredder_room.position.x, layout.complaint_office.end.x + WorldLayout.GAP, 0.01)
	assert_almost_eq(layout.tech_room.position.x, layout.shredder_room.end.x + WorldLayout.GAP, 0.01)
	assert_almost_eq(layout.tech_room.end.x, WorldLayout.WIDTH - WorldLayout.MARGIN, 0.01)
	assert_almost_eq(layout.hall.position.y, layout.complaint_office.end.y + WorldLayout.GAP, 0.01)
	assert_true(layout.hall.has_point(layout.complaint_box_point()))
	assert_lt(layout.complaint_box_point().distance_to(layout.office_door()), layout.complaint_box_point().distance_to(layout.tech_door()))


func test_tap_on_the_player_opens_the_player_spot() -> void:
	var world := _world()
	var player := game.state.player.position
	assert_eq(world.tap_spot(player), GameConfig.ROOM_PLAYER)
	assert_eq(world.tap_spot(player + Vector2(WorldView.PLAYER_TAP_RADIUS - 1.0, 0.0)), GameConfig.ROOM_PLAYER)
	assert_ne(world.tap_spot(player + Vector2(WorldView.PLAYER_TAP_RADIUS + 1.0, 0.0)), GameConfig.ROOM_PLAYER)


func test_tap_resolves_locked_and_missing_spots_to_their_room() -> void:
	var world := _world()
	assert_eq(world.tap_spot(layout.area("tax_services/review").get_center()), "dept:tax_services")
	assert_eq(world.tap_spot(_slot_center(layout.dept_shredder_point("tax_services"))), "dept:tax_services")
	assert_eq(world.tap_spot(_slot_center(layout.tube_station_point("general_services"))), "dept:general_services")
	assert_eq(world.tap_spot(layout.area(GameConfig.MAILROOM).get_center()), "room:mail")
	assert_eq(world.tap_spot(_slot_center(layout.dept_shredder_point("general_services"))), "shredder:general_services")
	game.state.set_upgrade("pneumatic_tubes", 1)
	assert_eq(world.tap_spot(_slot_center(layout.tube_station_point("general_services"))), "tube:general_services")


func test_tap_on_free_floor_opens_the_room() -> void:
	var world := _world()
	var room := layout.room("general_services")
	assert_eq(world.tap_spot(room.position + Vector2(5.0, 300.0)), "dept:general_services")
	assert_eq(world.tap_spot(Vector2(1.0, 1.0)), "")


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
	for spot in ["entrance", "interns", GameConfig.ROOM_PLAYER]:
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


func test_nearest_shredder_picks_the_closest_point() -> void:
	var central := layout.shredder_point()
	var housing := layout.dept_shredder_point("housing")
	var none: Array[String] = []
	var depts: Array[String] = ["general_services", "housing"]
	assert_eq(layout.shredder_points(none), [central] as Array[Vector2])
	assert_eq(layout.shredder_points(depts), [central, layout.dept_shredder_point("general_services"), housing] as Array[Vector2])
	assert_true(layout.room("housing").has_point(housing))
	assert_eq(layout.nearest_shredder(housing, none), central)
	assert_eq(layout.nearest_shredder(housing, depts), housing)
	assert_eq(layout.nearest_shredder(central + Vector2(4.0, 4.0), depts), central)


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


func test_map_draws_slots_stations_and_shredders() -> void:
	var world := _world()
	var state := game.state
	state.unlock_department("tax_services")
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("complaint_tube", 1)
	state.set_upgrade("shredder_service", 1)
	state.set_upgrade("climate_control", 50)
	state.set_upgrade("it_support", 30)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	for room_id in GameConfig.upgrade_rooms("shredder"):
		state.set_upgrade("shredder", 1, room_id)
	game.simulation.dept_shredded.emit("general_services")
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
