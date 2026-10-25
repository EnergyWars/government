extends GutTest

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.dispute_timer = 1e6
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _spawn_stopped(angry: bool = false, files_complaint: bool = true) -> ComplaintVisitor:
	for attempt in 100:
		var visitor := sim.spawn_visitor(angry, files_complaint)
		if visitor != null and visitor.is_stopped():
			return visitor
		if visitor != null:
			state.visitors.erase(visitor)
	return null


func test_without_guards_nobody_is_stopped() -> void:
	for i in 50:
		var visitor := sim.spawn_visitor(false, true)
		assert_false(visitor.is_stopped())
		assert_true(visitor.files_complaint)
		state.visitors.clear()


func test_guard_stops_roughly_the_configured_share() -> void:
	state.guards = 1
	var stopped := 0
	for i in 400:
		var visitor := sim.spawn_visitor(false, true)
		if visitor.is_stopped():
			stopped += 1
		state.visitors.clear()
	assert_between(stopped, 100, 180)


func test_stopped_visitor_files_no_complaint_and_leaves() -> void:
	state.guards = 1
	watch_signals(sim)
	var visitor := _spawn_stopped()
	assert_not_null(visitor)
	assert_false(visitor.files_complaint)
	assert_eq(visitor.slot, -1)
	assert_eq(visitor.guard, 0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.ARRIVING)
	_run(15.0)
	assert_eq(state.visitors_stopped, 1)
	assert_signal_emitted_with_parameters(sim, "visitor_stopped", [false])
	assert_eq(state.complaints, 0)
	_run(20.0)
	assert_false(state.visitors.has(visitor))
	assert_eq(state.complaints, 0)


func test_stopped_visitor_waits_at_the_guard() -> void:
	state.guards = 1
	var visitor := _spawn_stopped()
	visitor.position = layout.guard_stop_spot(0)
	sim.tick(0.05)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.STOPPED)
	assert_almost_eq(visitor.duration, GameConfig.GUARD_STOP_SECONDS, 0.001)
	_run(GameConfig.GUARD_STOP_SECONDS - 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.STOPPED)
	_run(1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)


func test_busy_guard_cannot_stop_another_visitor() -> void:
	state.guards = 1
	assert_not_null(_spawn_stopped())
	for i in 30:
		var visitor := sim.spawn_visitor(false, true)
		if visitor == null:
			break
		assert_false(visitor.is_stopped())
		state.visitors.erase(visitor)


func test_second_guard_works_in_parallel() -> void:
	state.guards = 2
	var first := _spawn_stopped()
	var second := _spawn_stopped()
	assert_not_null(first)
	assert_not_null(second)
	assert_ne(first.guard, second.guard)


func test_guard_is_free_again_once_the_visitor_leaves() -> void:
	state.guards = 1
	var visitor := _spawn_stopped()
	visitor.phase = ComplaintVisitor.Phase.LEAVING
	assert_not_null(_spawn_stopped())


func test_stopped_visitor_needs_no_free_slot() -> void:
	for i in GameConfig.VISITOR_SLOTS:
		assert_not_null(sim.spawn_visitor(false, false))
	assert_null(sim.spawn_visitor(false, true))
	state.guards = 1
	var stopped: ComplaintVisitor = null
	for attempt in 100:
		stopped = sim.spawn_visitor(false, true)
		if stopped != null:
			break
	assert_not_null(stopped)
	assert_true(stopped.is_stopped())


func test_stopped_visitor_prevents_the_direct_complaint() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.guards = 2
	var filed := 0
	for i in 60:
		state.visitors.clear()
		state.complaints = 0
		state.complaint_timer = 0.0
		sim.tick(0.05)
		_run(10.0, 0.25)
		filed += state.complaints
	assert_gt(state.visitors_stopped, 0)
	assert_lt(filed, 60)


func test_stopped_angry_visitor_does_not_stress_the_intern() -> void:
	state.set_upgrade("shredder_service", 1)
	state.guards = 1
	var visitor := _spawn_stopped(true, false)
	visitor.position = layout.guard_stop_spot(0)
	var stress := state.intern.stress
	_run(2.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.STOPPED)
	assert_lte(state.intern.stress, stress)


func test_stopped_visitor_uses_guard_dialogs() -> void:
	state.guards = 1
	for i in 40:
		var visitor := _spawn_stopped()
		assert_between(visitor.dialog, 0, GameConfig.GUARD_DIALOGS - 1)
		state.visitors.clear()


func test_guard_cost_and_chance_grow_with_guards() -> void:
	assert_almost_eq(Formulas.guard_cost(state), GameConfig.GUARD_COST, 0.001)
	assert_almost_eq(Formulas.guard_block_chance(state), 0.0, 0.0001)
	state.guards = 1
	assert_almost_eq(Formulas.guard_cost(state), GameConfig.GUARD_COST * GameConfig.GUARD_GROWTH, 0.001)
	assert_almost_eq(Formulas.guard_block_chance(state), GameConfig.GUARD_BLOCK_CHANCE, 0.0001)
	state.guards = 2
	assert_gt(Formulas.guard_block_chance(state), GameConfig.GUARD_BLOCK_CHANCE)
	assert_lt(Formulas.guard_block_chance(state), 1.0)


func test_hire_guard_costs_money_and_has_limit() -> void:
	var actions := GameActions.new(state, sim)
	state.money = 1e9
	var money := state.money
	assert_true(actions.hire_guard())
	assert_eq(state.guards, 1)
	assert_almost_eq(state.money, money - GameConfig.GUARD_COST, 0.001)
	assert_eq(state.staff_hired, 1)
	for i in GameConfig.MAX_GUARDS + 1:
		actions.hire_guard()
	assert_eq(state.guards, GameConfig.MAX_GUARDS)
	assert_false(actions.can_hire_guard())
	assert_false(actions.hire_guard())
	state.guards = 0
	state.money = 0.0
	assert_false(actions.can_hire_guard())
	assert_false(actions.hire_guard())


func test_guards_are_saved_and_clamped() -> void:
	state.guards = 2
	state.visitors_stopped = 9
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.guards, 2)
	assert_eq(loaded.visitors_stopped, 9)
	var data := state.to_dict()
	data.guards = 99
	data.visitors_stopped = -3
	loaded = GameState.from_dict(data)
	assert_eq(loaded.guards, GameConfig.MAX_GUARDS)
	assert_eq(loaded.visitors_stopped, 0)
	data.erase("guards")
	data.erase("visitors_stopped")
	loaded = GameState.from_dict(data)
	assert_eq(loaded.guards, 0)
	assert_eq(loaded.visitors_stopped, 0)


func test_guard_posts_are_in_the_hall_and_distinct() -> void:
	assert_ne(layout.guard_post(0), layout.guard_post(1))
	for index in GameConfig.MAX_GUARDS:
		assert_true(layout.hall.has_point(layout.guard_post(index)))
		assert_true(layout.hall.has_point(layout.guard_stop_spot(index)))
		for slot in GameConfig.VISITOR_SLOTS:
			assert_gt(layout.guard_post(index).distance_to(layout.visitor_spot(slot)), 30.0)


func test_guard_lines_are_translated_and_clamped() -> void:
	for dialog in GameConfig.GUARD_DIALOGS:
		for line in GameConfig.GUARD_LINES:
			assert_ne(Flavor.guard_line(dialog, line), "GUARD_%d_%d" % [dialog + 1, line + 1])
	assert_eq(Flavor.guard_line(GameConfig.GUARD_DIALOGS, 0), Flavor.guard_line(0, 0))
	assert_eq(Flavor.guard_line(0, 9), Flavor.guard_line(0, GameConfig.GUARD_LINES - 1))
	assert_true(Icons.STAFF.has("guards"))


func test_guard_board_hires_and_lists_guards() -> void:
	var game := Game.new(GameState.create_new(4))
	game.state.money = 1e9
	UpgradeEntryCard.amount_index = 0
	var sheet := SpotSheet.new()
	sheet.setup(game, "guards")
	add_child_autofree(sheet)
	await wait_physics_frames(2)
	assert_eq(sheet.title(), UpgradeTexts.spot_title("guards"))
	assert_true(_has_label(sheet.content, sheet.tr("GUARDS_EMPTY")))
	assert_true(UpgradeEntryCard.buy(game, "%s:guards" % UpgradeCatalog.STAFF))
	sheet.rebuild()
	assert_eq(game.state.guards, 1)
	assert_false(_has_label(sheet.content, sheet.tr("GUARDS_EMPTY")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_GUARD_NAME") % 1))


func test_guard_spot_offers_hiring_and_training() -> void:
	var ids: Array[String] = []
	for entry in UpgradeCatalog.entries_for_spot(state, "guards"):
		ids.append(entry.id)
	assert_true(ids.has("%s:guards" % UpgradeCatalog.STAFF))
	assert_true(ids.has("%s:guard_training" % UpgradeCatalog.TRACK))
	assert_eq(GameConfig.spot_room("guards"), GameConfig.ROOM_HALL)
	assert_true(GameConfig.BOARD_SPOTS.has("guards"))
	assert_true(layout.hall.encloses(layout.guards_board()))


func test_guard_training_raises_the_block_chance() -> void:
	state.guards = 1
	var untrained := Formulas.guard_block_chance(state)
	state.set_upgrade("guard_training", int(GameConfig.upgrade("guard_training").max))
	assert_gt(Formulas.guard_block_chance(state), untrained)
	assert_lte(Formulas.guard_block_chance(state), 1.0)


func test_world_view_draws_guards_and_stopped_visitors() -> void:
	var game := Game.new(GameState.create_new(4))
	game.state.guards = 2
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var visitor := ComplaintVisitor.new(layout.guard_stop_spot(0))
	visitor.guard = 0
	visitor.slot = -1
	visitor.phase = ComplaintVisitor.Phase.STOPPED
	visitor.duration = GameConfig.GUARD_STOP_SECONDS
	visitor.timer = GameConfig.GUARD_STOP_SECONDS
	game.state.visitors.append(visitor)
	for timer in [GameConfig.GUARD_STOP_SECONDS, 0.5]:
		visitor.timer = timer
		game.state.player.position = layout.guard_post(0)
		world.camera = layout.guard_post(0)
		world._process(0.1)
		world.queue_redraw()
		await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false
