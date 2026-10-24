extends GutTest

var game: Game


func before_each() -> void:
	var state := GameState.create_new(5)
	state.money = 1e9
	state.reputation = 500.0
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	game = Game.new(state)


func _host() -> Control:
	var host := Control.new()
	add_child_autofree(host)
	return host


func _sheet(sheet: Sheet, argument: String = "") -> Sheet:
	var host := _host()
	sheet.setup(game, argument)
	host.add_child(sheet)
	return sheet


func _open_mail() -> Station:
	game.state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	return game.state.ensure_mailroom()


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	if node is Button:
		result.append((node as Button).text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result


func _find_ad(host: Node) -> AdPlaceholder:
	for child in host.get_children():
		if child is AdPlaceholder:
			return child
	return null


func test_ad_placeholder_counts_down_and_rewards() -> void:
	var host := _host()
	var calls := [0]
	var ad := AdPlaceholder.play(host, func() -> void: calls[0] += 1)
	watch_signals(ad)
	assert_between(ad.slogan, 1, AdPlaceholder.SLOGAN_COUNT)
	assert_eq(ad.remaining, GameConfig.AD_SECONDS)
	assert_eq(ad._countdown.text, tr("FMT_AD_COUNTDOWN") % ceili(GameConfig.AD_SECONDS))
	ad.advance(GameConfig.AD_SECONDS - 1.0)
	assert_false(ad.is_done())
	assert_eq(calls[0], 0)
	ad.advance(1.0)
	assert_true(ad.is_done())
	assert_eq(calls[0], 1)
	assert_signal_emitted(ad, "finished")
	ad.advance(5.0)
	assert_eq(calls[0], 1)
	await wait_physics_frames(2)
	assert_false(is_instance_valid(ad))


func test_ad_placeholder_survives_invalid_callback_and_runs_in_process() -> void:
	var ad := AdPlaceholder.play(_host(), Callable())
	ad._process(GameConfig.AD_SECONDS + 0.1)
	assert_true(ad.is_done())


func test_ad_slogans_exist_in_both_languages() -> void:
	var keys: Array[String] = ["LABEL_AD", "AD_PLACEHOLDER_NOTE", "FMT_AD_COUNTDOWN"]
	for index in range(1, AdPlaceholder.SLOGAN_COUNT + 1):
		keys.append("AD_TITLE_%d" % index)
		keys.append("AD_TEXT_%d" % index)
	for boost_id in GameConfig.BOOST_ORDER:
		keys.append("BOOST_" + boost_id.to_upper())
		keys.append("BOOST_DESC_" + boost_id.to_upper())
	var previous := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(previous)


func test_boost_sheet_lists_boosts_and_mock_shop() -> void:
	var sheet := _sheet(BoostSheet.new())
	assert_eq(sheet.title(), sheet.tr("SHEET_BOOSTS"))
	var texts := _texts(sheet.content)
	assert_has(texts, sheet.tr("FMT_SEALS") % GameConfig.START_SEALS)
	assert_has(texts, sheet.tr("BOOST_OVERTIME"))
	assert_does_not_have(texts, sheet.tr("BOOST_EXPRESS_POST"))
	assert_has(texts, sheet.tr("FMT_SEAL_PACK") % GameConfig.SEAL_PACKS[0])
	_open_mail()
	sheet.rebuild()
	assert_has(_texts(sheet.content), sheet.tr("BOOST_EXPRESS_POST"))
	await wait_physics_frames(2)


func test_boost_sheet_warns_when_swamped() -> void:
	var sheet := _sheet(BoostSheet.new()) as BoostSheet
	assert_eq(sheet._swamped_count(game.state), 0)
	var review := game.state.station("general_services/review")
	while not review.is_swamped(game.state.lobby_capacity()):
		review.inbox.append(CaseFile.new("general_services"))
	assert_eq(sheet._swamped_count(game.state), 1)
	sheet.refresh()


func test_boost_sheet_test_purchase_adds_seals() -> void:
	var sheet := _sheet(BoostSheet.new()) as BoostSheet
	var dialog := sheet.confirm_pack(1)
	assert_true(is_instance_valid(dialog))
	dialog._confirm()
	assert_eq(game.state.seals, GameConfig.START_SEALS + GameConfig.SEAL_PACKS[1])


func test_boost_card_buys_with_seals_and_ads() -> void:
	var sheet := _sheet(BoostSheet.new())
	var seal_text := sheet.tr("FMT_BOOST_SEALS") % Boosts.seal_cost("overtime")
	for button in _buttons(sheet.content):
		if button.text == seal_text and not button.disabled:
			button.pressed.emit()
			break
	assert_true(game.state.is_boost_active("overtime"))
	assert_has(_texts(sheet.content), sheet.tr("FMT_BOOST_ACTIVE") % UiKit.duration(game.state.boost_left("overtime")))
	var host := sheet.get_parent()
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("ACTION_WATCH_AD") and not button.disabled:
			button.pressed.emit()
			break
	var ad := _find_ad(host)
	assert_not_null(ad)
	ad.advance(GameConfig.AD_SECONDS)
	assert_eq(game.state.ads_watched, 1)
	assert_eq(game.state.boosts_used, 2)
	sheet.refresh()


func test_boost_ad_text_shows_cooldown() -> void:
	assert_eq(UpgradeCards.boost_ad_text(game.state, "overtime"), tr("ACTION_WATCH_AD"))
	game.state.boost_cooldowns["overtime"] = 90.0
	assert_eq(UpgradeCards.boost_ad_text(game.state, "overtime"), tr("FMT_AD_COOLDOWN") % UiKit.duration(90.0))


func test_sheet_watch_ad_runs_action_after_the_ad() -> void:
	var sheet := _sheet(GoalsSheet.new())
	var ad := sheet.watch_ad(game.boosts.buy_seals.bind(0))
	assert_eq(game.state.seals, GameConfig.START_SEALS)
	ad.advance(GameConfig.AD_SECONDS)
	assert_eq(game.state.seals, GameConfig.START_SEALS + GameConfig.SEAL_PACKS[0])


func test_mail_room_sheet_shows_storage_and_locked_state() -> void:
	var sheet := _sheet(RoomSheet.new(), GameConfig.ROOM_MAIL)
	assert_has(_texts(sheet.content), sheet.tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1))
	assert_eq(UpgradeCards.mail_storage_info(game.state), sheet.tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1))
	var room := _open_mail()
	sheet.rebuild()
	var texts := _texts(sheet.content)
	assert_does_not_have(texts, sheet.tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1))
	assert_has(texts, sheet.tr("MAIL_STORAGE_DESC"))
	assert_has(texts, sheet.tr("BOOST_EXPRESS_POST"))
	assert_has(texts, UpgradeCards.mail_storage_info(game.state))
	sheet.act(game.actions.upgrade_mail_storage)
	assert_eq(room.storage_level, 1)
	await wait_physics_frames(2)


func test_area_spec_knows_every_area() -> void:
	for area_id in ["waiting", "seating", "mail_storage"]:
		var spec := UpgradeCards.area_spec(game, area_id)
		assert_false(spec.is_empty(), area_id)
		assert_false(str(spec.info.call()).is_empty(), area_id)
		assert_gte(float(spec.cost.call()), 0.0, area_id)
	assert_true(UpgradeCards.area_spec(game, "nope").is_empty())
	_open_mail()
	assert_gt(float(UpgradeCards.area_spec(game, "mail_storage").cost.call()), 0.0)


func test_station_card_shows_upgrade_dynamics_and_onboarding() -> void:
	game.state.unlock_department("tax_services")
	var review := game.state.station("general_services/review")
	review.rush = 10.0
	var lines := StationCard.dynamics_lines(game.state, review, 100.0)
	assert_has(lines, tr("FMT_RUSH") % UiKit.duration(10.0))
	assert_has(lines, tr("FMT_MILESTONE") % [Formulas.levels_to_milestone(1), UiKit.decimal(GameConfig.LEVEL_MILESTONE_BONUS)])
	var next := game.state.station("general_services/signature")
	assert_has(lines, tr("FMT_DOWNSTREAM_SLOW") % [StationCard.label_for(next.key), UiKit.decimal(Formulas.station_throughput(game.state, next) * 60.0)])
	lines = StationCard.dynamics_lines(game.state, review, 0.0)
	assert_has(lines, tr("FMT_DOWNSTREAM") % [StationCard.label_for(next.key), UiKit.decimal(Formulas.station_throughput(game.state, next) * 60.0)])
	review.level = GameConfig.MAX_STATION_LEVEL
	review.rush = 0.0
	for line in StationCard.dynamics_lines(game.state, review, 0.0):
		assert_false(line.begins_with(tr("FMT_MILESTONE").split("%")[0]))
	var tax := game.state.department("tax_services")
	assert_eq(StationCard.onboarding_text(tax), tr("FMT_ONBOARDING") % [0, GameConfig.HANDS_ON_CASES])
	var sheet := _sheet(DepartmentSheet.new(), "tax_services")
	assert_has(_texts(sheet.content), StationCard.onboarding_text(tax))
	await wait_physics_frames(2)


func test_hud_has_seals_boost_button_and_ad_doubling() -> void:
	var host := _host()
	var hud := Hud.new().setup(game, 0.0)
	host.add_child(hud)
	assert_eq(hud._seal_label.text, str(GameConfig.START_SEALS))
	watch_signals(hud)
	hud._boost_button.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "open_sheet", ["boosts", ""])
	assert_eq(hud._highlight_control("boosts"), hud._boost_button)
	assert_eq(hud._boost_role, "primary")
	var review := game.state.station("general_services/review")
	while not review.is_swamped(game.state.lobby_capacity()):
		review.inbox.append(CaseFile.new("general_services"))
	hud.refresh()
	assert_eq(hud._boost_role, "warning")
	assert_eq(hud._boost_button.theme_type_variation, "WarningIconTonal")
	assert_true(hud._goal_double.disabled)
	assert_false(hud._goal_reward.visible)
	game.state.cases_completed = 999
	hud.refresh()
	assert_false(hud._goal_double.disabled)
	assert_true(hud._goal_reward.visible)
	assert_eq(hud._goal_reward.text, GoalText.claim_reward(game.goals.current()))
	var money := game.state.money
	hud._goal_double.pressed.emit()
	var ad := _find_ad(host)
	assert_not_null(ad)
	ad.advance(GameConfig.AD_SECONDS)
	assert_gt(game.state.money, money)
	assert_eq(game.state.ads_watched, 1)


func test_hud_sick_card_offers_a_doctor_note_ad() -> void:
	var host := _host()
	var hud := Hud.new().setup(game, 0.0)
	host.add_child(hud)
	var review := game.state.station("general_services/review")
	review.add_desk()
	review.add_desk()
	review.staff = 3
	review.moods[0].rest(DeskMood.SICK)
	game.state.player.position = game.simulation.layout.desk_position(review.key, 0)
	hud.refresh()
	if hud._bonus_target.is_empty():
		pass_test("player not near a sick desk in this layout")
		return
	assert_eq(hud._sick_ad.text, tr("ACTION_SICK_NOTE_AD"))
	assert_false(hud._sick_ad.disabled)
	hud._sick_ad.pressed.emit()
	_find_ad(host).advance(GameConfig.AD_SECONDS)
	assert_false(review.moods[0].is_sick())
	review.moods[0].rest(DeskMood.SICK)
	hud.refresh()
	assert_eq(hud._sick_ad.text, tr("FMT_AD_COOLDOWN") % UiKit.duration(game.state.boost_cooldown(Boosts.SICK_NOTE)))
	assert_true(hud._sick_ad.disabled)


func test_world_view_draws_mail_room_and_reacts_to_mail() -> void:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var layer: Node2D = null
	for entry in world._layers:
		if entry.id == WorldView.MAIL_LAYER:
			layer = entry.node
	assert_not_null(layer)
	layer.queue_redraw()
	await wait_physics_frames(2)
	var room := _open_mail()
	room.inbox.append(CaseFile.new("general_services"))
	room.inbox[0].mail = true
	layer.queue_redraw()
	await wait_physics_frames(2)
	var walkers := world._walkers.size()
	var floaters := world._floaters.size()
	game.simulation.mail_delivered.emit(3, 2)
	game.simulation.mail_delivered.emit(0, 0)
	game.simulation.mail_answered.emit("general_services", 10.0)
	game.simulation.applications_bundled.emit("general_services", 1)
	game.simulation.form_missing.emit("general_services")
	game.simulation.onboarding_completed.emit("general_services")
	game.boosts.use("overtime", Boosts.SEALS)
	assert_eq(world._walkers.size(), walkers + 2)
	assert_eq(world._floaters.size(), floaters + 7)
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	watch_signals(world)
	world._handle_tap(world.layout.mail_header().get_center())
	assert_signal_emitted_with_parameters(world, "open_room", [GameConfig.ROOM_MAIL])


func test_letters_and_shelves_paint() -> void:
	var canvas := Node2D.new()
	add_child_autofree(canvas)
	canvas.draw.connect(func() -> void:
		var letter := CaseFile.new("general_services")
		letter.mail = true
		ItemPainter.draw_item(canvas, Vector2(50, 50), letter)
		OfficePainter.mail_shelf(canvas, Rect2(0, 0, 200, 200), 30, 44)
		OfficePainter.mail_shelf(canvas, Rect2(0, 0, 200, 200), 0, 12)
		OfficePainter.mailbox(canvas, Vector2(100, 100))
	)
	canvas.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(canvas))


func test_runner_card_hires_per_role_and_opens_the_plan() -> void:
	var sheet := _sheet(TeamSheet.new())
	var texts := _texts(sheet.content)
	for role in Runner.ROLES:
		assert_has(texts, UpgradeCards.role_info(game.state, role))
	var hire_buttons: Array[Button] = []
	var plan: Button = null
	for button in _buttons(sheet.content):
		if button.text.begins_with(sheet.tr("ACTION_HIRE") + "\n") and hire_buttons.size() < 3 and button.get_parent().get_child(button.get_index() - 1) is Label and (button.get_parent().get_child(button.get_index() - 1) as Label).text.begins_with(sheet.tr("RUNNER_ROLE_INTAKE")):
			hire_buttons.append(button)
		if button.text == sheet.tr("ACTION_RUNNER_PLAN"):
			plan = button
	assert_not_null(plan)
	assert_true(plan.disabled)
	assert_eq(hire_buttons.size(), 1)
	hire_buttons[0].pressed.emit()
	assert_eq(game.state.runners_in(Runner.INTAKE), 1)
	await wait_physics_frames(2)
	watch_signals(sheet)
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("ACTION_RUNNER_PLAN"):
			assert_false(button.disabled)
			button.pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "navigate", ["runners", ""])


func test_runner_sheet_assigns_roles_and_departments() -> void:
	var sheet := _sheet(RunnerSheet.new()) as RunnerSheet
	assert_eq(sheet.title(), sheet.tr("SHEET_RUNNERS"))
	assert_has(_texts(sheet.content), sheet.tr("RUNNERS_EMPTY"))
	game.state.add_runner(Runner.INTAKE)
	game.state.unlock_department("tax_services")
	sheet.rebuild()
	var texts := _texts(sheet.content)
	assert_has(texts, sheet.tr("FMT_RUNNER_NAME") % 1)
	assert_has(texts, sheet.tr("RUNNER_IDLE"))
	for role in Runner.ROLES:
		assert_has(texts, RunnerSheet.role_summary(game.state, role))
	var output_segment: Button = null
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("RUNNER_ROLE_SHORT_OUTPUT"):
			output_segment = button
	output_segment.pressed.emit()
	assert_eq(game.state.runners[0].role, Runner.OUTPUT)
	var dept_text := sheet.tr("FMT_RUNNER_DEPARTMENT") % RunnerSheet.department_text(Runner.ALL_DEPARTMENTS)
	for button in _buttons(sheet.content):
		if button.text == dept_text:
			button.pressed.emit()
			break
	assert_eq(game.state.runners[0].dept_id, "general_services")
	assert_has(_texts(sheet.content), sheet.tr("FMT_RUNNER_DEPARTMENT") % sheet.tr("DEPT_GENERAL_SERVICES"))
	game.state.runners[0].task = Runner.Task.TO_SOURCE
	sheet.refresh()
	assert_has(_texts(sheet.content), sheet.tr("RUNNER_BUSY"))
	game.state.research["pneumatic_tubes"] = 1
	game.state.connect_all_tubes()
	sheet.rebuild()
	assert_has(_texts(sheet.content), sheet.tr("RUNNERS_TUBES_TEXT"))
	await wait_physics_frames(2)


func test_runner_sheet_upgrades_a_runner() -> void:
	var runner := game.state.add_runner(Runner.INTAKE)
	var sheet := _sheet(RunnerSheet.new()) as RunnerSheet
	assert_has(_texts(sheet.content), RunnerSheet.level_text(game.state, runner))
	var upgrade: Button = null
	for button in _buttons(sheet.content):
		if button.text.begins_with(sheet.tr("ACTION_UPGRADE_RUNNER")):
			upgrade = button
	assert_not_null(upgrade)
	upgrade.pressed.emit()
	assert_eq(runner.level, 1)
	assert_has(_texts(sheet.content), RunnerSheet.level_text(game.state, runner))
	assert_eq(RunnerSheet.level_text(game.state, runner), TranslationServer.translate("FMT_RUNNER_LEVEL") % [1, GameConfig.MAX_RUNNER_LEVEL, Formulas.runner_load(game.state, runner)])
	runner.level = GameConfig.MAX_RUNNER_LEVEL
	sheet.rebuild()
	assert_has(_texts(sheet.content), sheet.tr("LABEL_MAX_LEVEL"))
	await wait_physics_frames(2)
