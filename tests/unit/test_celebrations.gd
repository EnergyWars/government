extends GutTest

const TEST_SETTINGS := "user://test_celebration_settings.cfg"

var game: Game
var _previous_locale := ""


func before_all() -> void:
	_previous_locale = TranslationServer.get_locale()


func before_each() -> void:
	TranslationServer.set_locale("de")
	var state := GameState.create_new(31)
	state.money = 1e12
	state.reputation = 1e6
	game = Game.new(state)


func after_each() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS)
	TranslationServer.set_locale(_previous_locale)


func _layer() -> CelebrationLayer:
	var layer := CelebrationLayer.new()
	layer.size = Vector2(720, 1280)
	add_child_autofree(layer)
	return layer


func _director(with_world: bool = false) -> Dictionary:
	var settings := AppSettings.new(TEST_SETTINGS)
	var sfx := SfxPlayer.new().setup(settings)
	add_child_autofree(sfx)
	var layer := _layer()
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	var world: WorldView = null
	if with_world:
		var joystick := JoystickView.new()
		add_child_autofree(joystick)
		world = WorldView.new()
		add_child_autofree(world)
		world.setup(game, joystick)
	var director := RewardDirector.new().setup(game, sfx, layer, hud, world)
	add_child_autofree(director)
	return {"director": director, "sfx": sfx, "layer": layer, "hud": hud, "world": world}


func _labels(node: Node) -> Array[String]:
	var texts: Array[String] = []
	if node is Label:
		texts.append((node as Label).text)
	for child in node.get_children():
		texts.append_array(_labels(child))
	return texts


func test_float_scale_pops_then_settles() -> void:
	assert_eq(Juice.float_scale(-1.0), Juice.FLOAT_POP_START)
	assert_eq(Juice.float_scale(0.0), Juice.FLOAT_POP_START)
	assert_almost_eq(Juice.float_scale(Juice.FLOAT_POP_TIME * 0.5), Juice.FLOAT_POP_PEAK, 0.001)
	assert_gt(Juice.float_scale(Juice.FLOAT_POP_TIME * 0.25), Juice.FLOAT_POP_START)
	assert_gt(Juice.float_scale(Juice.FLOAT_POP_TIME * 0.75), 1.0)
	assert_eq(Juice.float_scale(Juice.FLOAT_POP_TIME), 1.0)
	assert_eq(Juice.float_scale(5.0), 1.0)


func test_juice_needs_tree_and_returns_tweens() -> void:
	var control := Control.new()
	assert_null(Juice.pop(control))
	assert_null(Juice.pop_in(control))
	assert_null(Juice.breathe(control))
	control.size = Vector2(40, 20)
	add_child_autofree(control)
	assert_not_null(Juice.pop(control))
	assert_eq(control.pivot_offset, Vector2(20, 10))
	var tween := Juice.pop_in(control)
	assert_not_null(tween)
	assert_eq(control.modulate.a, 0.0)
	assert_almost_eq(control.scale.x, Juice.POP_IN_FROM, 0.001)
	tween.kill()
	var loop := Juice.breathe(control)
	assert_not_null(loop)
	loop.kill()
	Juice.center_pivot(null)


func test_juice_pop_settles_back() -> void:
	var control := Control.new()
	control.size = Vector2(10, 10)
	add_child_autofree(control)
	Juice.pop(control)
	await wait_seconds(Juice.POP_TIME + 0.2)
	assert_almost_eq(control.scale.x, 1.0, 0.01)


func test_rolling_number_snaps_first_value_and_drops() -> void:
	var roll := RollingNumber.new()
	roll.set_target(100.0)
	assert_eq(roll.value, 100.0)
	assert_false(roll.is_rolling())
	assert_false(roll.advance(0.1))
	roll.set_target(40.0)
	assert_eq(roll.value, 40.0)


func test_rolling_number_counts_up_over_roll_time() -> void:
	var roll := RollingNumber.new()
	roll.set_target(0.0)
	roll.set_target(600.0)
	assert_true(roll.is_rolling())
	assert_true(roll.advance(RollingNumber.ROLL_TIME * 0.5))
	assert_almost_eq(roll.value, 300.0, 0.01)
	roll.advance(RollingNumber.ROLL_TIME)
	assert_eq(roll.value, 600.0)
	assert_false(roll.is_rolling())
	assert_false(roll.advance(0.1))


func test_rolling_number_snaps_when_almost_there() -> void:
	var roll := RollingNumber.new()
	roll.set_target(1000.0)
	roll.set_target(1000.5)
	roll.advance(0.001)
	assert_eq(roll.value, 1000.5)
	roll.set_target(2000.0)
	roll.advance(-1.0)
	assert_eq(roll.value, 1000.5)


func test_confetti_bursts_fall_and_expire() -> void:
	var confetti := ConfettiView.new()
	add_child_autofree(confetti)
	assert_eq(confetti.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(confetti.burst(Vector2(100, 400), 20), 20)
	assert_eq(confetti.pieces.size(), 20)
	var start: Vector2 = confetti.pieces[0].vel
	confetti.advance(0.1)
	assert_gt((confetti.pieces[0].vel as Vector2).y, start.y * (1.0 - ConfettiView.DRAG * 0.1) - 0.01)
	confetti.advance(ConfettiView.LIFETIME + 0.1)
	assert_true(confetti.pieces.is_empty())


func test_confetti_respects_piece_limit() -> void:
	var confetti := ConfettiView.new()
	add_child_autofree(confetti)
	assert_eq(confetti.burst(Vector2.ZERO, ConfettiView.MAX_PIECES + 50), ConfettiView.MAX_PIECES)
	assert_eq(confetti.sparkle(Vector2.ZERO, 5, Color.WHITE), 0)


func test_sparkles_spread_evenly_without_gravity() -> void:
	var confetti := ConfettiView.new()
	add_child_autofree(confetti)
	assert_eq(confetti.sparkle(Vector2(50, 50), 4, AppTheme.MONEY), 4)
	confetti.advance(0.1)
	for piece in confetti.pieces:
		assert_true(piece.spark)
		assert_eq(piece.color, AppTheme.MONEY)
	assert_almost_eq((confetti.pieces[0].vel as Vector2).y, 0.0, 0.001)
	confetti.advance(ConfettiView.SPARK_LIFETIME)
	assert_true(confetti.pieces.is_empty())


func test_confetti_draws_without_errors() -> void:
	var confetti := ConfettiView.new()
	add_child_autofree(confetti)
	confetti.burst(Vector2(100, 100), 5)
	confetti.sparkle(Vector2(100, 100), 3, AppTheme.MONEY)
	await wait_physics_frames(2)
	assert_false(confetti.pieces.is_empty())


func test_confetti_colors_come_from_theme() -> void:
	var colors := AppTheme.confetti_colors()
	assert_true(colors.has(AppTheme.accent("primary")))
	assert_true(colors.has(AppTheme.FLAG_GOLD))


func test_toasts_stack_and_trim() -> void:
	var layer := _layer()
	for index in CelebrationLayer.MAX_TOASTS + 2:
		layer.toast(Icons.CART, "Titel %d" % index, "Text", "tertiary")
	assert_eq(layer.toasts.get_child_count(), CelebrationLayer.MAX_TOASTS)
	var texts := _labels(layer.toasts)
	assert_false(texts.has("Titel 0"))
	assert_true(texts.has("Titel %d" % (CelebrationLayer.MAX_TOASTS + 1)))
	assert_eq((layer.toasts.get_child(0) as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_toasts_follow_top_inset() -> void:
	var layer := _layer()
	layer.top_inset = 120.0
	layer._process(0.016)
	assert_eq(layer.toasts.offset_top, 120.0 + AppTheme.SPACING_SM)
	assert_eq(layer.toasts.offset_left, float(AppTheme.SPACING_LG))


func test_toasts_disappear_after_their_time() -> void:
	var layer := _layer()
	var card := layer.toast(Icons.CART, "Titel", "", "primary")
	await wait_seconds(CelebrationLayer.TOAST_TIME + CelebrationLayer.FADE_TIME + 0.3)
	assert_false(is_instance_valid(card))


func test_big_celebrations_queue_and_show_in_order() -> void:
	var layer := _layer()
	watch_signals(layer)
	assert_true(layer.celebrate(Icons.FLAG, "Erste", "Text"))
	assert_true(is_instance_valid(layer.big_card))
	assert_signal_emitted_with_parameters(layer, "celebration_shown", ["Erste"])
	assert_gt(layer.confetti.pieces.size(), 0)
	assert_true(_labels(layer.big_card).has("Erste"))
	assert_true(layer.celebrate(Icons.FLAG, "Zweite", ""))
	assert_eq(layer.big_queue.size(), 1)
	var first := layer.big_card
	layer._finish_big(first)
	assert_ne(layer.big_card, first)
	assert_true(_labels(layer.big_card).has("Zweite"))
	assert_true(layer.big_queue.is_empty())
	layer._finish_big(layer.big_card)
	assert_null(layer.big_card)
	assert_null(layer.show_next())


func test_big_celebration_queue_is_limited() -> void:
	var layer := _layer()
	layer.celebrate(Icons.FLAG, "Aktiv", "")
	for index in CelebrationLayer.MAX_QUEUE:
		assert_true(layer.celebrate(Icons.FLAG, "Wartet %d" % index, ""))
	assert_false(layer.celebrate(Icons.FLAG, "Zu viel", ""))
	assert_eq(layer.big_queue.size(), CelebrationLayer.MAX_QUEUE)


func test_big_card_ignores_input_and_uses_role() -> void:
	var layer := _layer()
	layer.celebrate(Icons.TROPHY, "Titel", "Text", "warning")
	var card := layer.big_card.get_child(0) as PanelContainer
	assert_eq(card.theme_type_variation, "BannerWarning")
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(layer.big_card.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_coins_fly_to_target_and_land() -> void:
	var layer := _layer()
	watch_signals(layer)
	assert_eq(layer.fly_coins(Vector2(300, 600), Vector2(80, 40), 3), 3)
	assert_eq(layer.fly_coins(Vector2.ZERO, Vector2.ZERO, -2), 0)
	assert_eq(layer.fly_coins(Vector2.ZERO, Vector2.ZERO, CelebrationLayer.MAX_COINS + 5), CelebrationLayer.MAX_COINS)
	await wait_seconds(CelebrationLayer.COIN_TIME + CelebrationLayer.COIN_STAGGER * CelebrationLayer.MAX_COINS + 0.4)
	assert_signal_emit_count(layer, "coin_landed", 3 + CelebrationLayer.MAX_COINS)


func test_coin_curve_hits_start_and_end() -> void:
	var start := Vector2(0, 100)
	var control := Vector2(50, -100)
	var end := Vector2(100, 0)
	assert_eq(CelebrationLayer.curve_point(start, control, end, 0.0), start)
	assert_eq(CelebrationLayer.curve_point(start, control, end, 1.0), end)
	assert_lt(CelebrationLayer.curve_point(start, control, end, 0.5).y, 50.0)


func test_burst_shows_rising_label_with_sparkles() -> void:
	var layer := _layer()
	var label := layer.burst(Vector2(200, 300), "Gekauft", AppTheme.MONEY)
	assert_not_null(label)
	assert_eq(label.text, "Gekauft")
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(layer.confetti.pieces.size(), CelebrationLayer.SPARK_COUNT)
	assert_null(layer.burst(Vector2.ZERO, "", AppTheme.MONEY))


func test_layer_never_blocks_input() -> void:
	var layer := _layer()
	assert_eq(layer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(layer.toasts.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_scale_pitch_climbs_and_wraps() -> void:
	assert_eq(RewardDirector.scale_pitch(0), 1.0)
	assert_eq(RewardDirector.scale_pitch(-3), 1.0)
	assert_almost_eq(RewardDirector.scale_pitch(5), 2.0, 0.0001)
	assert_gt(RewardDirector.scale_pitch(3), RewardDirector.scale_pitch(2))
	assert_eq(RewardDirector.scale_pitch(RewardDirector.SCALE_STEPS.size()), 1.0)


func test_streak_texts_are_translated() -> void:
	assert_eq(RewardDirector.streak_text(2), "Doppelt!")
	assert_eq(RewardDirector.streak_text(3), "Dreifach!")
	assert_eq(RewardDirector.streak_text(7), "Dienstserie ×7!")
	TranslationServer.set_locale("en")
	assert_eq(RewardDirector.streak_text(2), "Double!")


func test_director_starts_ladders_at_current_progress() -> void:
	game.state.money_earned = 25000.0
	game.state.cases_completed = 120
	var parts := _director()
	var director: RewardDirector = parts.director
	assert_eq(director.money_ladder.reached, director.money_ladder.index_of(25000.0))
	assert_eq(director.case_ladder.reached, director.case_ladder.index_of(120.0))
	director.check_progress()
	assert_null((parts.layer as CelebrationLayer).big_card)


func test_money_milestone_celebrates_once() -> void:
	var parts := _director()
	var layer: CelebrationLayer = parts.layer
	game.state.money_earned = 1500.0
	(parts.director as RewardDirector).check_progress()
	assert_true(is_instance_valid(layer.big_card))
	assert_true(_labels(layer.big_card).has(tr("FMT_CELEBRATE_MONEY_TITLE") % UiKit.money(1000.0)))
	(parts.director as RewardDirector).check_progress()
	assert_true(layer.big_queue.is_empty())
	assert_true((parts.sfx as SfxPlayer)._last_played.has(SoundBank.FANFARE))


func test_case_milestone_celebrates() -> void:
	var parts := _director()
	game.state.cases_completed = 25
	(parts.director as RewardDirector).check_progress()
	assert_true(_labels((parts.layer as CelebrationLayer).big_card).has(tr("FMT_CELEBRATE_CASES_TITLE") % UiKit.number(25.0)))


func test_goal_ready_chimes_once() -> void:
	var parts := _director()
	var sfx: SfxPlayer = parts.sfx
	var director: RewardDirector = parts.director
	game.state.cases_completed = int(game.goals.current().target)
	director.check_progress()
	assert_true(sfx._last_played.has(SoundBank.CHIME))
	sfx._last_played.clear()
	director.check_progress()
	assert_false(sfx._last_played.has(SoundBank.CHIME))


func test_goal_claim_showers_coins_and_celebrates() -> void:
	var parts := _director()
	var layer: CelebrationLayer = parts.layer
	game.state.cases_completed = int(game.goals.current().target)
	var goal := game.goals.current()
	assert_true(game.perform(game.goals.claim))
	var expected := tr("FMT_CELEBRATE_GOAL") % [UiKit.money(float(goal.money)), int(goal.reputation), GameConfig.GOAL_SEALS]
	assert_true(_labels(layer.big_card).has(expected))
	var coins := 0
	for child in layer.get_children():
		if child is Label and (child as Label).text == Icons.PAID:
			coins += 1
	assert_eq(coins, RewardDirector.COINS_PER_CLAIM)
	assert_true((parts.sfx as SfxPlayer)._last_played.has(SoundBank.CLAIM))


func test_coin_landing_pulses_money_chip() -> void:
	var parts := _director()
	var hud: Hud = parts.hud
	(parts.layer as CelebrationLayer).coin_landed.emit(2)
	assert_true((parts.sfx as SfxPlayer)._last_played.has(SoundBank.COIN))
	assert_not_null(hud._money_pop)
	hud.pulse_money()
	assert_true(hud._money_pop.is_valid())


func test_purchase_rings_register_and_bursts() -> void:
	var parts := _director()
	var layer: CelebrationLayer = parts.layer
	assert_true(game.actions.buy_entry("track:briefcase", 10))
	assert_true((parts.sfx as SfxPlayer)._last_played.has(SoundBank.CASH))
	assert_true(_labels(layer).has(tr("FMT_FLOAT_BOUGHT_MANY") % 10))
	game.actions.buy_entry("track:briefcase")
	assert_true(_labels(layer).has(tr("FLOAT_BOUGHT")))


func test_purchase_spree_shows_toast() -> void:
	var parts := _director()
	var layer: CelebrationLayer = parts.layer
	for index in 3:
		game.actions.buy_entry("track:briefcase")
	assert_eq(layer.toasts.get_child_count(), 1)
	assert_true(_labels(layer.toasts).has(tr("FMT_CELEBRATE_SPREE") % 3))


func test_unlock_celebrates_without_an_extra_stage_celebration() -> void:
	var parts := _director()
	var layer: CelebrationLayer = parts.layer
	watch_signals(layer)
	assert_true(game.actions.buy_entry("unlock:tax_services"))
	assert_true(game.actions.buy_entry("unlock:business_licences"))
	assert_eq(game.state.building_stage, 1)
	assert_signal_emitted_with_parameters(layer, "celebration_shown", [tr("CELEBRATE_UNLOCK_TITLE")])
	assert_eq(layer.big_queue.size(), 1)
	assert_eq(layer.big_queue[0].title, tr("CELEBRATE_UNLOCK_TITLE"))
	assert_eq(layer.big_queue[0].text, tr("FMT_CELEBRATE_UNLOCK") % tr("DEPT_BUSINESS_LICENCES"))


func test_rank_up_plays_level_up_and_celebrates_milestones() -> void:
	var parts := _director()
	var director: RewardDirector = parts.director
	var layer: CelebrationLayer = parts.layer
	var milestone := DepartmentRank.next_milestone(1)
	director._on_department_ranked_up("general_services", 2 if milestone != 2 else 3)
	assert_true((parts.sfx as SfxPlayer)._last_played.has(SoundBank.LEVEL_UP))
	assert_null(layer.big_card)
	director._on_department_ranked_up("general_services", milestone)
	assert_true(is_instance_valid(layer.big_card))
	assert_true(_labels(layer.big_card).has(tr("FMT_CELEBRATE_RANK_TITLE") % UpgradeTexts.rank_title(milestone)))


func test_player_deeds_build_a_streak_with_cheers() -> void:
	var parts := _director(true)
	var director: RewardDirector = parts.director
	var world: WorldView = parts.world
	var floaters := world._floaters.size()
	assert_eq(director.deed(), 1)
	assert_eq(world._floaters.size(), floaters)
	(parts.sfx as SfxPlayer).clock += 1.0
	assert_eq(director.deed(), 2)
	assert_eq(world._floaters.size(), floaters + 1)
	assert_eq(world._floaters[-1].text, "Doppelt!")
	director._process(RewardDirector.DEED_STREAK_WINDOW + 0.1)
	assert_eq(director.deed(), 1)


func test_only_player_driven_events_count_as_deeds() -> void:
	var parts := _director()
	var director: RewardDirector = parts.director
	var sim := game.simulation
	sim.employee_woke.emit("general_services/review", 0, false)
	sim.complaint_shredded.emit(false)
	sim.sick_call_answered.emit(true, "general_services/review", 0, false)
	assert_eq(director.deed_streak.count, 0)
	sim.employee_woke.emit("general_services/review", 0, true)
	sim.dispute_ended.emit("chat", "general_services", true)
	sim.intern_recovered.emit(0, true)
	sim.complaint_shredded.emit(true)
	sim.sick_called.emit(true, "general_services/review", 0)
	sim.sick_call_answered.emit(true, "general_services/review", 0, true)
	sim.ruckus_calmed.emit(0)
	sim.mail_picked_up.emit()
	sim.bonus_left.emit("general_services/review", 0, 1)
	assert_eq(director.deed_streak.count, 9)


func test_completed_cases_ring_coins_and_cheer_streaks() -> void:
	var parts := _director(true)
	var director: RewardDirector = parts.director
	var world: WorldView = parts.world
	game.simulation.case_completed.emit("general_services", 10.0, true)
	assert_eq(director.case_streak.count, 0)
	for index in 9:
		game.simulation.case_completed.emit("general_services", 10.0, false)
	assert_ne(world._floaters[-1].text, tr("FMT_FLOAT_CASE_STREAK") % 9)
	game.simulation.case_completed.emit("general_services", 10.0, false)
	assert_eq(director.case_streak.count, 10)
	assert_eq(world._floaters[-1].text, tr("FMT_FLOAT_CASE_STREAK") % 10)
	game.simulation.mail_answered.emit("general_services", 5.0)
	assert_eq(director.case_streak.count, 11)


func test_small_events_play_sounds() -> void:
	var parts := _director()
	var sfx: SfxPlayer = parts.sfx
	var sim := game.simulation
	sim.onboarding_completed.emit("general_services")
	sim.gift_arrived.emit(0)
	game.boosts.used.emit("rush", "ad")
	sim.review_removed.emit("lost")
	assert_true(sfx._last_played.has(SoundBank.CHIME))
	assert_true(sfx._last_played.has(SoundBank.SPARKLE))
	assert_true(sfx._last_played.has(SoundBank.WHOOSH))
	sfx._last_played.clear()
	sim.review_removed.emit("expired")
	assert_false(sfx._last_played.has(SoundBank.CHIME))
	sim.review_removed.emit("won")
	assert_true(sfx._last_played.has(SoundBank.CHIME))


func test_gift_claim_and_windfall_shower_coins() -> void:
	var parts := _director()
	var director: RewardDirector = parts.director
	var layer: CelebrationLayer = parts.layer
	var before := layer.get_child_count()
	game.simulation.gift_claimed.emit(0, 50.0)
	assert_eq(layer.get_child_count(), before + RewardDirector.COINS_PER_GIFT)
	assert_eq(director.windfall(), RewardDirector.COINS_PER_CLAIM)


func test_director_without_ui_still_counts() -> void:
	var director := RewardDirector.new().setup(game, null, null, null, null)
	add_child_autofree(director)
	assert_eq(director.shower_coins(Vector2.ZERO, 3), 0)
	assert_eq(director.deed(), 1)
	game.simulation.case_completed.emit("general_services", 1.0, false)
	assert_eq(director.case_streak.count, 1)
	game.state.money_earned = 1e9
	director.check_progress()
	director._on_purchased("track:briefcase", 1)
	director._on_goal_claimed(1.0, 0.0, 1)
	assert_eq(director.purchase_streak.count, 1)


func test_tutorial_progress_chimes() -> void:
	game.state.tutorial_step = 0
	var parts := _director()
	var sfx: SfxPlayer = parts.sfx
	game.tutorial.restart()
	assert_false(sfx._last_played.has(SoundBank.CHIME))
	game.state.tutorial_step = 1
	game.tutorial.changed.emit()
	assert_true(sfx._last_played.has(SoundBank.CHIME))


func test_ruckus_vibration_respects_setting() -> void:
	var parts := _director()
	var director: RewardDirector = parts.director
	var sfx: SfxPlayer = parts.sfx
	game.simulation.ruckus_started.emit(0)
	assert_true(director._vibrate(RewardDirector.RUCKUS_VIBRATION_MS))
	sfx.settings.haptics = false
	assert_false(director._vibrate(RewardDirector.RUCKUS_VIBRATION_MS))


func test_hud_money_rolls_up() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	var start := game.state.money
	assert_eq(hud._money_label.text, UiKit.money(start))
	game.state.money = start * 2.0
	hud.refresh()
	assert_eq(hud._money_label.text, UiKit.money(start))
	hud._process(RollingNumber.ROLL_TIME + 0.1)
	assert_eq(hud._money_label.text, UiKit.money(start * 2.0))
	game.state.money = 5.0
	hud.refresh()
	assert_eq(hud._money_label.text, UiKit.money(5.0))


func test_hud_anchors_and_goal_glow() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	await wait_physics_frames(2)
	assert_true(hud.top_bar.get_global_rect().has_point(hud.money_anchor()))
	assert_eq(hud.goal_anchor(), hud._goal_card.get_global_rect().get_center())
	assert_null(hud._claim_glow)
	game.state.cases_completed = int(game.goals.current().target)
	hud.refresh()
	assert_not_null(hud._claim_glow)
	assert_not_null(hud.pulse_goal())
	game.state.goal_index = GameConfig.GOALS.size()
	hud.refresh()
	assert_null(hud._claim_glow)
	assert_eq(hud._goal_claim.scale, Vector2.ONE)
	assert_eq(hud.goal_anchor(), hud.get_viewport_rect().size * 0.5)


func test_settings_sheet_toggles_sound_and_haptics() -> void:
	var settings := AppSettings.new(TEST_SETTINGS)
	var sheet := SettingsSheet.new().with_settings(settings)
	sheet.setup(game)
	add_child_autofree(sheet)
	var switches: Array[CheckButton] = []
	var stack: Array[Node] = [sheet.content]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is CheckButton:
			switches.append(node)
		stack.append_array(node.get_children())
	var sound: CheckButton = null
	var haptics: CheckButton = null
	for item in switches:
		if item.text == tr("SETTING_SOUND"):
			sound = item
		elif item.text == tr("SETTING_HAPTICS"):
			haptics = item
	assert_not_null(sound)
	assert_not_null(haptics)
	assert_true(sound.button_pressed)
	sound.button_pressed = false
	haptics.button_pressed = false
	assert_false(settings.sound)
	assert_false(settings.haptics)
	assert_false(AppSettings.new(TEST_SETTINGS).load_settings().sound)
	assert_true(_labels(sheet.content).has(tr("SECTION_FEEDBACK")))
	await wait_physics_frames(2)


func test_world_cheers_float_with_pop() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	world.cheer("Doppelt!", AppTheme.accent("success"))
	var floater: Dictionary = world._floaters[-1]
	assert_eq(floater.pos, game.state.player.position + WorldView.CHEER_OFFSET)
	assert_eq(floater.size, AppTheme.SIZE_TITLE_LARGE)
	world.cheer_at(world.counter_point(), "Fließband ×10!", AppTheme.MONEY)
	assert_eq(world._floaters[-1].pos, world.counter_point())
	await wait_physics_frames(2)
	assert_eq(world._floaters.size(), 2)


func test_new_texts_exist_in_both_languages() -> void:
	var keys := ["SECTION_FEEDBACK", "SETTING_SOUND", "SETTING_HAPTICS", "CELEBRATE_UNLOCK_TITLE", "FMT_CELEBRATE_UNLOCK", "FMT_CELEBRATE_RANK_TITLE", "FMT_CELEBRATE_RANK", "CELEBRATE_GOAL_TITLE", "FMT_CELEBRATE_GOAL", "FMT_CELEBRATE_MONEY_TITLE", "CELEBRATE_MONEY_TEXT", "FMT_CELEBRATE_CASES_TITLE", "CELEBRATE_CASES_TEXT", "CELEBRATE_SPREE_TITLE", "FMT_CELEBRATE_SPREE", "FLOAT_BOUGHT", "FMT_FLOAT_BOUGHT_MANY", "STREAK_2", "STREAK_3", "STREAK_4", "FMT_STREAK_MANY", "FMT_FLOAT_CASE_STREAK"]
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s missing in %s" % [key, locale])
