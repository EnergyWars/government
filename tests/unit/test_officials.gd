extends GutTest

const REVIEW := "general_services/review"
const SIGNATURE := "general_services/signature"

var state: GameState
var game: Game


func before_each() -> void:
	state = GameState.create_new(21)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.money = 1.0e9
	game = Game.new(state)


func _review() -> Station:
	return state.station(REVIEW)


func _staff_two() -> Station:
	var station := _review()
	station.add_desk()
	station.staff = 2
	return station


func _staff_sick_team() -> Station:
	var station := _review()
	while station.desks < GameConfig.SICK_MIN_STAFF:
		station.add_desk()
	station.staff = station.desks
	return station


func test_training_raises_level_and_costs_money() -> void:
	var station := _review()
	var cost := Formulas.training_cost(station, "skill", 0)
	assert_almost_eq(cost, float(GameConfig.station_kind("review").hire_cost) * float(GameConfig.OFFICIAL_TRAININGS.skill.cost), 0.001)
	assert_true(game.actions.train_official(REVIEW, 0, "skill"))
	assert_eq(station.moods[0].training_level("skill"), 1)
	assert_almost_eq(state.money, 1.0e9 - cost, 0.01)
	assert_eq(state.trainings, 1)
	assert_gt(Formulas.training_cost(station, "skill", 1), cost)


func test_training_is_capped_per_track() -> void:
	for level in GameConfig.MAX_OFFICIAL_TRAINING:
		assert_true(game.actions.train_official(REVIEW, 0, "health"))
	assert_false(game.actions.can_train_official(REVIEW, 0, "health"))
	assert_false(game.actions.train_official(REVIEW, 0, "health"))
	assert_eq(_review().moods[0].training_level("health"), GameConfig.MAX_OFFICIAL_TRAINING)
	assert_true(game.actions.can_train_official(REVIEW, 0, "calm"))


func test_training_rejects_invalid_targets() -> void:
	assert_false(game.actions.train_official("nope/review", 0, "skill"))
	assert_false(game.actions.train_official(REVIEW, 5, "skill"))
	assert_false(game.actions.train_official(REVIEW, -1, "skill"))
	assert_false(game.actions.train_official(REVIEW, 0, "flying"))
	assert_false(game.actions.train_official(SIGNATURE, 0, "skill"))
	_review().add_desk()
	assert_false(game.actions.is_trainable(REVIEW, 1))
	state.money = 0.0
	assert_false(game.actions.train_official(REVIEW, 0, "skill"))
	assert_eq(state.trainings, 0)


func test_specialists_can_be_trained() -> void:
	var station := _review()
	station.add_specialist()
	var desk := station.moods.size() - 1
	assert_true(game.actions.train_official(REVIEW, desk, "stamina"))
	assert_eq(station.moods[desk].training_level("stamina"), 1)


func test_training_moves_with_the_official_when_desks_are_added() -> void:
	var station := _review()
	station.add_specialist()
	var specialist := station.moods.size() - 1
	game.actions.train_official(REVIEW, specialist, "skill")
	station.add_desk()
	assert_eq(station.moods[station.moods.size() - 1].training_level("skill"), 1)


func test_training_effects() -> void:
	var mood := DeskMood.new()
	assert_eq(Formulas.official_speed(mood), 1.0)
	assert_eq(Formulas.official_sick_resist(mood), 0.0)
	assert_eq(Formulas.official_drowsy_factor(mood), 1.0)
	assert_eq(Formulas.official_calm(mood), 0.0)
	mood.training = {"skill": 2, "health": 3, "stamina": 1, "calm": 2}
	assert_almost_eq(Formulas.official_speed(mood), 1.0 + 2.0 * float(GameConfig.OFFICIAL_TRAININGS.skill.effect), 0.0001)
	assert_almost_eq(Formulas.official_sick_resist(mood), 3.0 * float(GameConfig.OFFICIAL_TRAININGS.health.effect), 0.0001)
	assert_almost_eq(Formulas.official_drowsy_factor(mood), float(GameConfig.OFFICIAL_TRAININGS.stamina.effect), 0.0001)
	assert_almost_eq(Formulas.official_calm(mood), 2.0 * float(GameConfig.OFFICIAL_TRAININGS.calm.effect), 0.0001)
	assert_eq(mood.training_total(), 8)
	assert_eq(Formulas.training_effect("stamina", 0), 0.0)
	assert_lt(Formulas.official_sick_resist(mood), 1.0)


func test_skill_raises_capacity_and_work_speed() -> void:
	var station := _review()
	var before := Formulas.station_throughput(state, station)
	assert_eq(Formulas.effective_workers(station), 1.0)
	station.moods[0].training = {"skill": 2}
	assert_almost_eq(Formulas.effective_workers(station), Formulas.official_speed(station.moods[0]), 0.0001)
	assert_almost_eq(Formulas.station_throughput(state, station), before * Formulas.official_speed(station.moods[0]), 0.0001)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	station.jobs[0] = StationJob.new(case_file, 100.0, false)
	game.simulation._work_stations(1.0)
	assert_almost_eq(station.jobs[0].progress, Formulas.official_speed(station.moods[0]), 0.0001)


func test_stamina_slows_down_tiredness() -> void:
	var station := _staff_two()
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	station.inbox.append(case_file)
	station.moods[0].alert = 100.0
	station.moods[1].alert = 100.0
	station.moods[1].training = {"stamina": 3}
	game.simulation._update_moods(1.0)
	var untrained := 100.0 - station.moods[0].alert
	var trained := 100.0 - station.moods[1].alert
	assert_gt(untrained, 0.0)
	assert_almost_eq(trained, untrained * Formulas.official_drowsy_factor(station.moods[1]), 0.0001)


func test_health_training_avoids_sick_notes() -> void:
	var station := _staff_sick_team()
	for mood in station.moods:
		mood.training = {"health": GameConfig.MAX_OFFICIAL_TRAINING}
	watch_signals(game.simulation)
	var sick := 0
	for i in 200:
		for mood in station.moods:
			mood.wake(10.0)
		if game.simulation.report_sick():
			sick += 1
		state.calls.clear()
	var avoided := state.production.total(ProductionStats.SICK_AVOIDED)
	assert_eq(sick + avoided, 200)
	assert_gt(avoided, 60)
	assert_gt(sick, 30)
	assert_signal_emitted(game.simulation, "sick_avoided")
	assert_eq(state.production.total(ProductionStats.SICK), sick)


func test_sick_notes_are_counted_per_official() -> void:
	var station := _staff_sick_team()
	assert_true(game.simulation.report_sick())
	var total := 0
	for mood in station.moods:
		total += mood.sick_count
	assert_eq(total, 1)
	assert_eq(state.production.total(ProductionStats.SICK, REVIEW), 1)


func test_calm_training_avoids_quarrels() -> void:
	var station := _staff_two()
	assert_eq(Formulas.department_calm(state, "general_services"), 0.0)
	for mood in station.moods:
		mood.training = {"calm": GameConfig.MAX_OFFICIAL_TRAINING}
	assert_almost_eq(Formulas.department_calm(state, "general_services"), Formulas.training_effect("calm", GameConfig.MAX_OFFICIAL_TRAINING), 0.0001)
	watch_signals(game.simulation)
	var started := 0
	for i in 200:
		state.disputes.clear()
		if game.simulation._try_auto_dispute():
			started += state.disputes.size()
	var calmed := state.production.total(ProductionStats.DISPUTE_CALMED)
	assert_eq(started + calmed, 200)
	assert_gt(calmed, 60)
	assert_gt(started, 30)
	assert_signal_emitted_with_parameters(game.simulation, "dispute_calmed", ["general_services"])
	assert_eq(state.production.total(ProductionStats.DISPUTE, "general_services"), started)


func test_auto_quarrel_needs_candidates() -> void:
	assert_false(game.simulation._try_auto_dispute())
	assert_eq(Formulas.department_calm(state, "tax_services"), 0.0)


func test_untrained_quarrels_always_start() -> void:
	_staff_two()
	assert_true(game.simulation._try_auto_dispute())
	assert_eq(state.disputes.size(), 1)


func test_training_survives_saving() -> void:
	var station := _review()
	game.actions.train_official(REVIEW, 0, "skill")
	game.actions.train_official(REVIEW, 0, "calm")
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	var mood := copy.station(REVIEW).moods[0]
	assert_eq(mood.training_level("skill"), 1)
	assert_eq(mood.training_level("calm"), 1)
	assert_eq(mood.training_level("health"), 0)
	assert_eq(copy.trainings, 2)
	assert_eq(station.moods[0].to_dict().training, {"skill": 1, "calm": 1})


func test_loading_sanitizes_training() -> void:
	var mood := DeskMood.from_dict({"training": {"skill": 99, "health": -3, "flying": 2, "calm": 1}})
	assert_eq(mood.training_level("skill"), GameConfig.MAX_OFFICIAL_TRAINING)
	assert_eq(mood.training_level("health"), 0)
	assert_false(mood.training.has("flying"))
	assert_false(mood.training.has("health"))
	assert_eq(mood.training_level("calm"), 1)
	assert_true(DeskMood.from_dict({"training": "junk"}).training.is_empty())
	assert_true(DeskMood.from_dict({}).training.is_empty())


func test_rest_and_wake_keep_training() -> void:
	var mood := DeskMood.new()
	mood.train("skill")
	mood.rest(DeskMood.SICK)
	mood.wake(10.0)
	assert_eq(mood.training_level("skill"), 1)
	mood.train("flying")
	assert_false(mood.training.has("flying"))


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result


func _sheet(argument: String) -> OfficialsSheet:
	var sheet := OfficialsSheet.new()
	sheet.setup(game, argument)
	add_child_autofree(sheet)
	return sheet


func test_officials_sheet_lists_staffed_officials() -> void:
	var station := _staff_two()
	station.add_specialist()
	var sheet := _sheet(REVIEW)
	assert_eq(sheet.title(), sheet.tr("FMT_OFFICIALS_TITLE") % StationCard.label_for(REVIEW))
	assert_eq(OfficialsSheet.staffed_desks(station), [0, 1, 2] as Array[int])
	assert_true(_has_label(sheet.content, sheet.tr("FMT_OFFICIAL_NAME") % 1))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_OFFICIAL_NAME") % 2))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_SPECIALIST_NAME") % 1))
	assert_true(_has_label(sheet.content, sheet.tr("OFFICIAL_STATE_AWAKE")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_TRAINING_LEVEL") % [sheet.tr("TRAINING_SKILL"), 0, GameConfig.MAX_OFFICIAL_TRAINING]))


func test_officials_sheet_trains_on_button_press() -> void:
	var sheet := _sheet(REVIEW)
	var pressed := false
	for button in _buttons(sheet.content):
		if button.text.begins_with(sheet.tr("ACTION_TRAIN")) and not pressed:
			button.pressed.emit()
			pressed = true
	assert_true(pressed)
	assert_eq(_review().moods[0].training_level(GameConfig.OFFICIAL_TRAINING_ORDER[0]), 1)
	assert_true(_has_label(sheet.content, OfficialsSheet.effect_text(GameConfig.OFFICIAL_TRAINING_ORDER[0], 1)))


func test_officials_sheet_shows_maxed_and_unaffordable_training() -> void:
	_review().moods[0].training = {"skill": GameConfig.MAX_OFFICIAL_TRAINING}
	state.money = 0.0
	var sheet := _sheet(REVIEW)
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("LABEL_MAX_LEVEL") or button.text.begins_with(sheet.tr("ACTION_TRAIN")):
			assert_true(button.disabled)
	var labels := 0
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("LABEL_MAX_LEVEL"):
			labels += 1
	assert_eq(labels, 1)


func test_officials_sheet_handles_machines_empty_and_unknown_stations() -> void:
	var machine := _sheet(SIGNATURE)
	assert_true(_has_label(machine.content, machine.tr("OFFICIALS_MACHINE")))
	var unknown := _sheet("nope")
	assert_eq(unknown.title(), unknown.tr("SHEET_OFFICIALS"))
	assert_true(_has_label(unknown.content, unknown.tr("OFFICIALS_MACHINE")))
	state.station(GameConfig.RECEPTION).staff = 0
	var empty := _sheet(GameConfig.RECEPTION)
	assert_true(_has_label(empty.content, empty.tr("OFFICIALS_EMPTY")))


func test_official_state_texts_exist_for_every_state() -> void:
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for mood_state in DeskMood.STATES:
			var key := "OFFICIAL_STATE_" + mood_state.to_upper()
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
		for track_id in GameConfig.OFFICIAL_TRAINING_ORDER:
			for prefix in ["TRAINING_", "TRAINING_DESC_", "FMT_TRAINING_EFFECT_"]:
				var key: String = prefix + track_id.to_upper()
				assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)


func test_training_config_is_consistent() -> void:
	assert_eq(GameConfig.OFFICIAL_TRAINING_ORDER.size(), GameConfig.OFFICIAL_TRAININGS.size())
	for track_id in GameConfig.OFFICIAL_TRAINING_ORDER:
		assert_true(GameConfig.OFFICIAL_TRAININGS.has(track_id))
		assert_true(Icons.TRAININGS.has(track_id))


func test_station_card_opens_officials() -> void:
	var sheet := DepartmentSheet.new()
	sheet.setup(game, "general_services")
	add_child_autofree(sheet)
	watch_signals(sheet)
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("ACTION_OFFICIALS"):
			button.pressed.emit()
			break
	assert_signal_emitted_with_parameters(sheet, "navigate", ["officials", REVIEW])
