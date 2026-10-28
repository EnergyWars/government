extends GutTest

var game: Game
var state: GameState


func before_each() -> void:
	state = GameState.create_new(11)
	game = Game.new(state)


func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _world() -> WorldView:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	return world


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	elif node is Button:
		result.append((node as Button).text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _start_ruckus() -> void:
	state.cases_completed = GameConfig.RUCKUS_MIN_CASES
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	reception.inbox.append(game.simulation.create_case(state.department("general_services")))
	assert_true(game.simulation.start_job(reception, 0))
	assert_true(game.simulation.start_ruckus())


func test_first_event_shows_at_once_and_repeats_are_counted() -> void:
	var batch := FloatBatcher.new()
	assert_eq(batch.window, FloatBatcher.WINDOW)
	assert_false(batch.is_cooling("left"))
	assert_true(batch.add("left", {"text": "A"}))
	assert_true(batch.is_cooling("left"))
	assert_false(batch.add("left", {"text": "B"}))
	assert_false(batch.add("left", {"text": "C"}))
	assert_eq(batch.pending_count("left"), 2)
	assert_true(batch.advance(0.5).is_empty())
	var flushed := batch.advance(0.6)
	assert_eq(flushed.size(), 1)
	assert_eq(int(flushed[0].count), 2)
	assert_eq(str(flushed[0].text), "C")
	assert_eq(batch.pending_count("left"), 0)
	assert_true(batch.is_cooling("left"))
	assert_false(batch.add("left", {"text": "D"}))
	assert_eq(batch.advance(1.0).size(), 1)


func test_quiet_keys_cool_down_and_show_at_once_again() -> void:
	var batch := FloatBatcher.new()
	assert_true(batch.add("left", {}))
	assert_true(batch.advance(1.0).is_empty())
	assert_false(batch.is_cooling("left"))
	assert_true(batch.add("left", {}))


func test_keys_are_batched_independently() -> void:
	var batch := FloatBatcher.new()
	assert_true(batch.add("bundle:2", {}))
	assert_true(batch.add("bundle:3", {}))
	assert_false(batch.add("bundle:2", {}))
	assert_eq(batch.pending_count("bundle:2"), 1)
	assert_eq(batch.pending_count("bundle:3"), 0)
	var flushed := batch.advance(1.0)
	assert_eq(flushed.size(), 1)
	assert_eq(int(flushed[0].count), 1)


func test_window_is_never_negative() -> void:
	var batch := FloatBatcher.new(-3.0)
	assert_eq(batch.window, 0.0)
	assert_true(batch.add("left", {}))
	assert_false(batch.add("left", {"text": "again"}))
	assert_eq(batch.advance(0.0).size(), 1)


func test_repeat_text_appends_the_count() -> void:
	assert_eq(WorldView.repeat_text("Reicht mir!", 1), "Reicht mir!")
	assert_eq(WorldView.repeat_text("Reicht mir!", 0), "Reicht mir!")
	assert_eq(WorldView.repeat_text("Reicht mir!", 5), _t("FMT_FLOAT_REPEAT") % ["Reicht mir!", 5])


func test_world_bundles_citizens_leaving_into_one_floater_per_second() -> void:
	var world := _world()
	var before := world._floaters.size()
	for i in 6:
		game.simulation.citizen_left.emit("general_services")
	assert_eq(world._floaters.size(), before + 1)
	assert_eq(str(world._floaters.back().text), _t("FLOAT_CITIZEN_LEFT"))
	world._advance_effects(FloatBatcher.WINDOW + 0.01)
	assert_eq(str(world._floaters.back().text), WorldView.repeat_text(_t("FLOAT_CITIZEN_LEFT"), 5))
	game.simulation.citizen_left.emit("customs")
	world._advance_effects(FloatBatcher.WINDOW + 0.01)
	assert_false(world._float_batch.is_cooling(WorldView.FLOAT_LEFT))


func test_world_bundles_multi_applications_per_size() -> void:
	var world := _world()
	var before := world._floaters.size()
	for i in 4:
		game.simulation.applications_bundled.emit("general_services", 1)
	game.simulation.applications_bundled.emit("general_services", 2)
	assert_eq(world._floaters.size(), before + 2)
	world._advance_effects(FloatBatcher.WINDOW + 0.01)
	var bundle := _t("FMT_FLOAT_BUNDLE") % 2
	var texts: Array[String] = []
	for floater in world._floaters:
		texts.append(str(floater.text))
	assert_true(texts.has(WorldView.repeat_text(bundle, 3)))
	assert_true(texts.has(_t("FMT_FLOAT_BUNDLE") % 3))


func test_ticket_calls_do_not_add_floaters() -> void:
	var world := _world()
	var before := world._floaters.size()
	game.simulation.ticket_called.emit(9)
	assert_eq(world._floaters.size(), before)


func test_world_draws_the_ticket_corner() -> void:
	var world := _world()
	var drawn := [false]
	world._actors.draw.connect(func() -> void:
		world._canvas = world._actors
		world._draw_ticket_corner(state)
		world._canvas = world
		drawn[0] = true
	)
	world._actors.queue_redraw()
	await wait_physics_frames(2)
	assert_true(drawn[0])


func test_world_floats_the_ruckus_alarm() -> void:
	var world := _world()
	var before := world._floaters.size()
	_start_ruckus()
	assert_eq(world._floaters.size(), before + 1)
	assert_eq(str(world._floaters.back().text), _t("FLOAT_RUCKUS_START"))


func test_hud_warns_while_a_ruckus_halts_the_reception() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	hud.refresh()
	assert_false(hud._ruckus_banner.visible)
	_start_ruckus()
	hud.refresh()
	assert_true(hud._ruckus_banner.visible)
	assert_true(_texts(hud._ruckus_banner).has(_t("RUCKUS_ALERT_TITLE")))
	assert_true(_texts(hud._ruckus_banner).has(_t("RUCKUS_ALERT_TEXT")))
	assert_null(_button(hud._ruckus_banner, _t("ACTION_LOCATE")))
	game.simulation.calm_ruckus()
	hud.refresh()
	assert_false(hud._ruckus_banner.visible)


func test_world_inset_ignores_transient_banners() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	hud.refresh()
	await wait_physics_frames(2)
	var before := hud.world_inset()
	assert_gt(before, 0.0)
	_start_ruckus()
	game.state.gift_kind = 0
	game.state.gift_money = 10.0
	game.state.player.position = game.simulation.layout.office_desk_point()
	hud.refresh()
	await wait_physics_frames(2)
	assert_gt(hud.top_height(), hud.world_inset())
	assert_eq(hud.world_inset(), before)


func test_guidance_puts_the_ruckus_before_everything_else() -> void:
	_start_ruckus()
	state.player.position = WorldLayout.get_default().phone_point()
	state.calls.append(PhoneCall.new(PhoneCall.INCOMING, "general_services/review", 0, 10.0))
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.RUCKUS)
	assert_eq(task.key, GameConfig.RECEPTION)
	assert_eq(task.point, WorldLayout.get_default().ruckus_point(state.ruckus_desk))


func test_ruckus_texts_exist_in_both_languages() -> void:
	var previous := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in ["RUCKUS_ALERT_TITLE", "RUCKUS_ALERT_TEXT", "FMT_FLOAT_REPEAT"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
	TranslationServer.set_locale(previous)
