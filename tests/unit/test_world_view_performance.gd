extends GutTest

var game: Game
var world: WorldView


func before_each() -> void:
	var state := GameState.create_new(9)
	state.money = 1e9
	game = Game.new(state)
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	world = WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)


func _spawn_citizens(count: int) -> void:
	var dept := game.state.department("general_services")
	for i in count:
		game.simulation.spawn_case(dept)


func _focus_lobby() -> void:
	game.state.player.position = world.layout.door_in()
	world.camera = world.layout.door_in()


func test_floaters_are_capped_and_drop_the_oldest() -> void:
	for i in WorldView.MAX_FLOATERS + 5:
		world._float(Vector2.ZERO, str(i), Color.WHITE)
	assert_eq(world._floaters.size(), WorldView.MAX_FLOATERS)
	assert_eq(str(world._floaters[0].text), "5")
	assert_eq(str(world._floaters[-1].text), str(WorldView.MAX_FLOATERS + 4))


func test_department_flow_is_cached_for_the_flow_interval() -> void:
	var dept := game.state.department("general_services")
	var first := world.department_flow(game.state, dept)
	assert_eq(str(first.bottleneck), Formulas.bottleneck(game.state, dept))
	assert_same(world.department_flow(game.state, dept), first)
	world._time += WorldView.FLOW_INTERVAL * 0.5
	assert_same(world.department_flow(game.state, dept), first)
	world._time += WorldView.FLOW_INTERVAL
	var refreshed := world.department_flow(game.state, dept)
	assert_not_same(refreshed, first)
	assert_eq(float(refreshed.time), world._time)


func test_furnishing_signature_follows_places_and_machines() -> void:
	var before := world.furnishing_signature(game.state)
	assert_eq(before, Vector3i(game.state.seat_capacity(GameConfig.HALL_INTAKE), game.state.seat_capacity(GameConfig.HALL_PICKUP), 1))
	game.state.set_upgrade("seating", game.state.upgrade_level("seating") + 1)
	var more_seats := world.furnishing_signature(game.state)
	assert_eq(more_seats.x, before.x + 1)
	game.state.set_upgrade("pickup_seating", game.state.upgrade_level("pickup_seating") + 1)
	assert_eq(world.furnishing_signature(game.state).y, before.y + 1)
	game.state.set_upgrade("ticket_machine_2", 1)
	assert_eq(world.furnishing_signature(game.state).z, 2)


func test_furnishing_pops_only_while_animating() -> void:
	assert_false(world._furnishing_popping())
	WorldView._born_list(world._seat_born, GameConfig.HALL_PICKUP).append(world._time)
	assert_true(world._furnishing_popping())
	world._time += OfficePainter.POP_SECONDS + 0.1
	assert_false(world._furnishing_popping())


func test_furnishing_change_invalidates_the_static_hall_layer() -> void:
	world._process(0.016)
	await wait_physics_frames(2)
	world._furnishing_signature = Vector3i(-1, -1, -1)
	for layer in world._layers:
		if layer.id == WorldView.HALL_STATIC_LAYER:
			layer.drawn = true
	world._refresh_layers()
	assert_eq(world._furnishing_signature, world.furnishing_signature(game.state))


func test_job_bars_are_recorded_per_layer_and_drawn_live() -> void:
	var review := game.state.station("general_services/review")
	world._ring_layer = "general_services"
	world._bars["general_services"] = []
	world._job_bar(review, 0, Vector2(10, 10))
	world._ring_layer = ""
	assert_eq((world._bars["general_services"] as Array).size(), 1)
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	var drawn := [false]
	canvas.draw.connect(func() -> void:
		world._canvas = canvas
		world._draw_live_bars(Rect2(-100, -100, 400, 400))
		review.jobs[0] = StationJob.new(game.simulation.create_case(game.state.department("general_services")), 2.0)
		world._draw_live_bars(Rect2(-100, -100, 400, 400))
		world._draw_live_bars(Rect2(1000, 1000, 10, 10))
		world._draw_job_bar(review, review.jobs.size() + 3, Vector2.ZERO)
		world._job_bar(review, 0, Vector2(20, 20))
		world._canvas = world
		drawn[0] = true
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(drawn[0])


func test_citizens_only_get_new_placements_every_interval() -> void:
	_spawn_citizens(2)
	world._citizen_clock = 0.0
	world._placement_timer = 0.0
	world._update_citizens(game.state)
	assert_eq(world._citizens.entries.size(), 2)
	assert_almost_eq(world._placement_timer, WorldView.PLACEMENT_INTERVAL, 0.0001)
	_spawn_citizens(1)
	world._citizen_clock = WorldView.PLACEMENT_INTERVAL * 0.25
	world._update_citizens(game.state)
	assert_eq(world._citizens.entries.size(), 2)
	assert_eq(world._citizen_clock, 0.0)
	world._citizen_clock = WorldView.PLACEMENT_INTERVAL
	world._update_citizens(game.state)
	assert_eq(world._citizens.entries.size(), 3)


func test_standing_citizens_move_to_the_queue_layer() -> void:
	_focus_lobby()
	_spawn_citizens(3)
	world._sync_citizens(game.state)
	assert_eq(world._citizens.entries.size(), 3)
	world._queue.queue_redraw()
	await wait_process_frames(2)
	assert_eq(world._queued.size(), 3)
	for case_file in world._queued:
		assert_true(world._citizens.entries.has(case_file))


func test_walking_queued_citizen_marks_the_queue_dirty() -> void:
	_focus_lobby()
	_spawn_citizens(1)
	world._sync_citizens(game.state)
	var case_file: CaseFile = world._citizens.entries.keys()[0]
	world._queued[case_file] = true
	world._queue_dirty = false
	var entry: Dictionary = world._citizens.entries[case_file]
	entry.pos = (entry.target as Vector2) + Vector2(150, 0)
	world._placement_timer = 10.0
	world._citizen_clock = 0.0
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		world._canvas = canvas
		world._draw_citizens(game.state, world.view_rect().grow(WorldView.CULL_MARGIN))
		world._canvas = world
	)
	canvas.queue_redraw()
	await wait_process_frames(1)
	assert_true(world._queue_dirty or not world._queued.has(case_file))


func test_departing_citizens_mark_the_queue_dirty() -> void:
	_focus_lobby()
	_spawn_citizens(1)
	world._sync_citizens(game.state)
	world._queue_dirty = false
	game.state.ticket_line.clear()
	game.state.citizens.clear()
	world._sync_citizens(game.state)
	assert_true(world._queue_dirty)
	assert_true(world._citizens.entries.is_empty())


func test_queue_layer_without_game_draws_nothing() -> void:
	var empty := WorldView.new()
	add_child_autofree(empty)
	empty._queued[CaseFile.new("general_services")] = true
	empty._draw_queue()
	assert_true(empty._queued.is_empty())


func test_disc_textures_pick_a_fitting_resolution() -> void:
	var small := ItemPainter.disc_texture(1.0)
	assert_eq(small.get_width(), ItemPainter.DISC_SIZES[0])
	assert_same(ItemPainter.disc_texture(1.0), small)
	var medium := ItemPainter.disc_texture(9.0)
	assert_gte(float(medium.get_width()), 9.0 * ItemPainter.DISC_DETAIL)
	assert_eq(ItemPainter.disc_texture(10000.0).get_width(), ItemPainter.DISC_SIZES[-1])
	var image := ItemPainter.disc_texture(1000.0).get_image()
	var size := image.get_width()
	assert_almost_eq(image.get_pixel(size / 2, size / 2).a, 1.0, 0.01)
	assert_almost_eq(image.get_pixel(0, 0).a, 0.0, 0.01)
	assert_almost_eq(image.get_pixel(size - 1, size / 2).a, image.get_pixel(0, size / 2).a, 0.01)


func test_disc_draws_and_skips_empty_radius() -> void:
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	var drawn := [false]
	canvas.draw.connect(func() -> void:
		ItemPainter.disc(canvas, Vector2(20, 20), 8.0, Color.RED)
		ItemPainter.disc(canvas, Vector2(20, 20), 0.0, Color.RED)
		ItemPainter.disc(canvas, Vector2(20, 20), -3.0, Color.RED)
		drawn[0] = true
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(drawn[0])
