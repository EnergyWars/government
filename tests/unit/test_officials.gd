extends GutTest

const REVIEW := "general_services/review"
const SIGNATURE := "tax_services/signature"
const ROOM := "general_services"

var state: GameState
var game: Game


func before_each() -> void:
	state = GameState.create_new(21)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.money = 1.0e9
	state.unlock_department("tax_services")
	state.station(REVIEW).staff = 1
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


func _hire_lead(room_id: String = ROOM) -> void:
	state.set_upgrade("team_lead", 1, room_id)


func test_lead_breaks_shorten_rest_limits_in_their_room() -> void:
	var fetch := Formulas.rest_limit(state, DeskMood.FETCH, ROOM)
	var slow := Formulas.rest_limit(state, DeskMood.SLOW, ROOM)
	assert_almost_eq(fetch, Formulas.base_rest_limit(state, DeskMood.FETCH), 0.0001)
	_hire_lead()
	state.set_upgrade("lead_breaks", 10, ROOM)
	var factor := Formulas.lead_value(state, "lead_breaks", ROOM)
	assert_lt(factor, 1.0)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.FETCH, ROOM), fetch * factor, 0.0001)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.SLOW, ROOM), slow * factor, 0.0001)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.FETCH, "tax_services"), fetch, 0.0001)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.FETCH), fetch, 0.0001)


func test_lead_breaks_leave_sleep_and_chat_untouched() -> void:
	var asleep := Formulas.rest_limit(state, DeskMood.ASLEEP, ROOM)
	var chat := Formulas.rest_limit(state, DeskMood.CHAT, ROOM)
	_hire_lead()
	state.set_upgrade("lead_breaks", 20, ROOM)
	assert_eq(Formulas.rest_limit(state, DeskMood.ASLEEP, ROOM), asleep)
	assert_eq(Formulas.rest_limit(state, DeskMood.CHAT, ROOM), chat)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.SICK, ROOM), GameConfig.SICK_SECONDS * Formulas.track_value("lead_health", 0), 0.0001)


func test_lead_health_shortens_sick_leave_in_their_room() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.SICK)
	var before := Formulas.sick_time_left(state, mood, ROOM)
	assert_almost_eq(before, GameConfig.SICK_SECONDS, 0.0001)
	_hire_lead()
	state.set_upgrade("lead_health", 10, ROOM)
	var factor := Formulas.lead_value(state, "lead_health", ROOM)
	assert_lt(factor, 1.0)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.SICK, ROOM), GameConfig.SICK_SECONDS * factor, 0.0001)
	assert_almost_eq(Formulas.sick_time_left(state, mood, ROOM), before * factor, 0.0001)
	assert_almost_eq(Formulas.sick_time_left_with(state, mood, 0, ROOM), before * factor, 0.0001)
	assert_almost_eq(Formulas.sick_time_left(state, mood, "tax_services"), before, 0.0001)
	assert_lt(Formulas.sick_share(state, ROOM), Formulas.sick_share(state, "tax_services"))


func test_lead_health_makes_officials_return_sooner() -> void:
	var station := _review()
	_hire_lead()
	state.set_upgrade("lead_health", 50, ROOM)
	var limit := Formulas.rest_limit(state, DeskMood.SICK, ROOM)
	station.moods[0].rest(DeskMood.SICK)
	station.moods[0].resting = limit - 0.5
	game.simulation._update_moods(1.0)
	assert_false(station.moods[0].is_sick())


func test_lead_focus_slows_down_tiredness() -> void:
	var station := _review()
	var base := Formulas.drowsiness_rate(state, station)
	_hire_lead()
	state.set_upgrade("lead_focus", 10, ROOM)
	var factor := Formulas.lead_value(state, "lead_focus", ROOM)
	assert_lt(factor, 1.0)
	assert_almost_eq(Formulas.drowsiness_rate(state, station), base * factor, 0.0001)
	assert_almost_eq(Formulas.drowsiness_rate(state, state.station(SIGNATURE)), base, 0.0001)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	station.inbox.append(case_file)
	station.moods[0].alert = 100.0
	game.simulation._update_moods(1.0)
	assert_almost_eq(100.0 - station.moods[0].alert, Formulas.drowsiness_rate(state, station), 0.0001)


func test_lead_values_fall_back_outside_office_rooms() -> void:
	assert_eq(Formulas.lead_value(state, "lead_focus", "kitchen"), 1.0)
	assert_eq(Formulas.lead_value(state, "lead_calm", GameConfig.ROOM_HALL), 0.0)


func test_sick_notes_are_counted_per_official() -> void:
	var station := _staff_sick_team()
	assert_true(game.simulation.report_sick())
	var total := 0
	for mood in station.moods:
		total += mood.sick_count
	assert_eq(total, 1)
	assert_eq(state.production.total(ProductionStats.SICK, REVIEW), 1)


func test_lead_calm_avoids_quarrels() -> void:
	_staff_two()
	assert_eq(Formulas.department_calm(state, ROOM), 0.0)
	state.set_upgrade("lead_calm", 30, ROOM)
	assert_eq(Formulas.department_calm(state, ROOM), 0.0)
	_hire_lead()
	assert_almost_eq(Formulas.department_calm(state, ROOM), Formulas.track_value("lead_calm", 30), 0.0001)
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
	assert_signal_emitted_with_parameters(game.simulation, "dispute_calmed", [ROOM])
	assert_eq(state.production.total(ProductionStats.DISPUTE, ROOM), started)


func test_auto_quarrel_needs_candidates() -> void:
	assert_false(game.simulation._try_auto_dispute())
	assert_eq(Formulas.department_calm(state, "tax_services"), 0.0)


func test_quarrels_without_lead_always_start() -> void:
	_staff_two()
	assert_true(game.simulation._try_auto_dispute())
	assert_eq(state.disputes.size(), 1)


func test_team_lead_counts_as_staff() -> void:
	var before := state.total_staff()
	_hire_lead()
	assert_eq(Formulas.team_lead_count(state), 1)
	assert_eq(state.total_staff(), before + 1)


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result


func test_statistics_lists_only_staffed_desks() -> void:
	var station := _staff_two()
	station.add_desk()
	assert_eq(StatisticsSheet.staffed_desks(station), [0, 1] as Array[int])


func test_official_state_texts_exist_for_every_state() -> void:
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for mood_state in DeskMood.STATES:
			var key := "OFFICIAL_STATE_" + mood_state.to_upper()
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
		for track_id in GameConfig.LEAD_TRACKS:
			for prefix in ["TRACK_", "TRACK_DESC_"]:
				var key: String = prefix + track_id.to_upper()
				assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)


func test_lead_tracks_have_icons_and_lead_spots() -> void:
	for track_id in GameConfig.LEAD_TRACKS:
		assert_true(Icons.UPGRADES.has(track_id), track_id)
		assert_true(GameConfig.is_lead_track(track_id))
		assert_eq(GameConfig.upgrade_spot(track_id, ROOM), GameConfig.lead_spot(ROOM))


func test_station_card_has_no_officials_menu() -> void:
	for key in [REVIEW, SIGNATURE]:
		var sheet := SpotSheet.new()
		sheet.setup(game, UpgradeCatalog.STATION_PREFIX + key)
		add_child_autofree(sheet)
		for button in _buttons(sheet.content):
			assert_ne(button.text, "ACTION_OFFICIALS")
		assert_eq(TranslationServer.translate("ACTION_OFFICIALS"), "ACTION_OFFICIALS")
