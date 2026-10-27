extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.complaint_letter_timer = 1e6
	state.dispute_timer = 1e6
	state.ruckus_timer = 1e6
	state.lunch_timer = 1e6
	state.gift_timer = 1e6
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _spawn_stopped(angry: bool = false, files_complaint: bool = true) -> ComplaintVisitor:
	for attempt in 200:
		var visitor := sim.spawn_visitor(angry, files_complaint)
		if visitor != null and visitor.is_stopped():
			return visitor
		if visitor != null:
			state.visitors.erase(visitor)
	return null


func _share_stopped(trials: int) -> int:
	var stopped := 0
	for i in trials:
		var visitor := sim.spawn_visitor(false, true)
		if visitor.is_stopped():
			stopped += 1
		state.visitors.clear()
	return stopped


func test_without_security_nobody_is_stopped() -> void:
	assert_eq(Formulas.security_chance(state), 0.0)
	assert_eq(_share_stopped(100), 0)


func test_training_without_security_does_nothing() -> void:
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	assert_eq(Formulas.security_chance(state), 0.0)


func test_security_starts_at_ten_percent_and_trains_up_to_eighty() -> void:
	state.money = 1e9
	assert_eq(Progression.upgrade_block_reason(state, "security_training"), "requires")
	assert_true(actions.buy_upgrade("complaint_security"))
	assert_false(actions.buy_upgrade("complaint_security"))
	assert_almost_eq(Formulas.security_chance(state), GameConfig.SECURITY_BASE_CHANCE, 0.0001)
	assert_eq(int(GameConfig.upgrade("security_training").max), GameConfig.SECURITY_LEVELS)
	assert_true(actions.buy_upgrade("security_training"))
	assert_almost_eq(Formulas.security_chance(state), 0.107, 0.0001)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	assert_almost_eq(Formulas.security_chance(state), GameConfig.SECURITY_MAX_CHANCE, 0.0001)


func test_security_stops_roughly_the_trained_share() -> void:
	state.set_upgrade("complaint_security", 1)
	assert_between(_share_stopped(1000), 60, 140)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	assert_between(_share_stopped(1000), 750, 850)


func test_stopped_visitor_never_enters_the_office() -> void:
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	state.set_upgrade("complaint_interns", 1)
	watch_signals(sim)
	var visitor := _spawn_stopped()
	assert_not_null(visitor)
	assert_false(visitor.files_complaint)
	assert_eq(visitor.slot, -1)
	assert_false(visitor.is_at_clerk())
	var entered := false
	var elapsed := 0.0
	while state.visitors.has(visitor) and elapsed < 60.0:
		sim.tick(0.05)
		elapsed += 0.05
		entered = entered or layout.complaint_office.has_point(visitor.position)
	assert_false(entered)
	assert_false(state.visitors.has(visitor))
	assert_eq(state.visitors_stopped, 1)
	assert_signal_emitted(sim, "visitor_stopped")
	assert_eq(state.complaints, 0)
	assert_eq(state.interns[0].handled, 0)


func test_stopped_visitor_waits_at_the_security_for_a_while() -> void:
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	var visitor := _spawn_stopped()
	visitor.position = layout.security_stop_spot()
	sim.tick(0.05)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.STOPPED)
	assert_almost_eq(visitor.duration, GameConfig.SECURITY_STOP_SECONDS, 0.001)
	_run(GameConfig.SECURITY_STOP_SECONDS - 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.STOPPED)
	_run(1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)


func test_stopped_visitors_keep_the_counter_free() -> void:
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	assert_not_null(_spawn_stopped())
	assert_eq(sim._free_visitor_slot(), 0)


func test_angry_shouters_can_be_stopped_too() -> void:
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	var visitor := _spawn_stopped(true, false)
	assert_not_null(visitor)
	assert_true(visitor.angry)


func test_security_sits_at_the_office_entrance() -> void:
	var office := layout.complaint_office
	assert_true(office.has_point(layout.security_post()))
	assert_false(office.has_point(layout.security_stop_spot()))
	assert_lt(layout.security_post().distance_to(layout.office_door()), 90.0)
	assert_lt(layout.security_stop_spot().distance_to(layout.office_door()), 90.0)
	assert_true(layout.security_rect().has_point(layout.security_post()))
	assert_eq(layout.spot_at(layout.security_post()), "security")


func test_security_makes_ruckus_rarer() -> void:
	var before := Formulas.ruckus_interval(state, 0.5)
	state.set_upgrade("complaint_security", 1)
	assert_almost_eq(Formulas.ruckus_interval(state, 0.5), before * (1.0 + GameConfig.RUCKUS_SECURITY_RELIEF), 0.001)


func test_security_lowers_complaint_demand() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	var open := ThroughputReport.complaint_demand(state)
	state.set_upgrade("complaint_security", 1)
	var guarded := ThroughputReport.complaint_demand(state)
	var letters := Formulas.complaint_letter_rate()
	assert_almost_eq(guarded - letters, (open - letters) * (1.0 - GameConfig.SECURITY_BASE_CHANCE), 0.00001)
	var area := ThroughputReport.complaint_area(state)
	var ids: Array = (area.upgrades as Array).map(func(upgrade: Dictionary) -> String: return str(upgrade.entry))
	assert_has(ids, "track:security_training")
	assert_does_not_have(ids, "track:complaint_security")


func test_security_status_line() -> void:
	assert_eq(SpotStatus.security(state), tr("STATUS_NO_SECURITY"))
	state.set_upgrade("complaint_security", 1)
	state.visitors_stopped = 4
	assert_eq(SpotStatus.security(state), tr("FMT_SECURITY_INFO") % [10, 4])


func test_complaint_interval_no_longer_depends_on_staff() -> void:
	assert_almost_eq(Formulas.complaint_interval(0.0), GameConfig.COMPLAINT_INTERVAL * 0.7, 0.001)
	assert_almost_eq(Formulas.complaint_interval(1.0), GameConfig.COMPLAINT_INTERVAL * 1.3, 0.001)
	assert_almost_eq(Formulas.complaint_interval(5.0), GameConfig.COMPLAINT_INTERVAL * 1.3, 0.001)


func test_guard_lines_are_translated_and_clamped() -> void:
	for dialog in GameConfig.GUARD_DIALOGS:
		for line in GameConfig.GUARD_LINES:
			assert_ne(Flavor.guard_line(dialog, line), "GUARD_%d_%d" % [dialog + 1, line + 1])
	assert_eq(Flavor.guard_line(GameConfig.GUARD_DIALOGS, 0), Flavor.guard_line(0, 0))
	assert_eq(Flavor.guard_line(0, 9), Flavor.guard_line(0, GameConfig.GUARD_LINES - 1))


func test_security_spot_offers_the_security_upgrades() -> void:
	var ids: Array[String] = []
	for entry in UpgradeCatalog.entries_for_spot(state, "security"):
		ids.append(entry.id)
	assert_eq(ids, ["%s:complaint_security" % UpgradeCatalog.TRACK, "%s:security_training" % UpgradeCatalog.TRACK])
	assert_eq(GameConfig.spot_room("security"), GameConfig.ROOM_COMPLAINTS)
	assert_false(GameConfig.BOARD_SPOTS.has("security"))


func test_world_view_draws_security_and_stopped_visitors() -> void:
	var game := Game.new(GameState.create_new(4))
	game.state.set_upgrade("complaint_security", 1)
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var visitor := ComplaintVisitor.new(layout.security_stop_spot())
	visitor.stopped = true
	visitor.slot = -1
	visitor.phase = ComplaintVisitor.Phase.STOPPED
	visitor.duration = GameConfig.SECURITY_STOP_SECONDS
	game.state.visitors.append(visitor)
	for timer in [GameConfig.SECURITY_STOP_SECONDS, 0.5]:
		visitor.timer = timer
		game.state.player.position = layout.security_post()
		world.camera = layout.security_post()
		world._process(0.1)
		world.queue_redraw()
		await wait_physics_frames(2)
	assert_true(is_instance_valid(world))
