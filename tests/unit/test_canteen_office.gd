extends GutTest

const REVIEW := "general_services/review"

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
	state.complaint_letter_timer = 1e6
	state.dispute_timer = 1e6
	state.gift_timer = 1e6
	state.player.position = Vector2(50, 50)


func _staff(count: int) -> Station:
	var review := state.station(REVIEW)
	while review.desks < count:
		review.add_desk()
	review.staff = count
	return review


func _lunch_guests() -> int:
	var count := 0
	for key in state.ordered_station_keys():
		for mood in state.station(key).moods:
			if mood.state == DeskMood.LUNCH:
				count += 1
	return count


func test_lunch_needs_enough_awake_staff() -> void:
	_staff(1)
	assert_eq(sim.call_lunch(), 0)
	assert_eq(state.lunches, 0)


func test_lunch_takes_staff_to_the_canteen_and_keeps_one_working() -> void:
	_staff(4)
	watch_signals(sim)
	var joined := sim.call_lunch()
	assert_eq(joined, _lunch_guests())
	assert_gt(joined, 0)
	assert_lte(joined, GameConfig.LUNCH_SIZE)
	assert_eq(state.lunches, joined)
	assert_signal_emitted_with_parameters(sim, "lunch_called", [joined])
	var working := 0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		for desk in station.moods.size():
			if station.is_staffed(desk) and not station.moods[desk].is_resting():
				working += 1
	assert_gte(working, GameConfig.LUNCH_KEEP_WORKING)
	for key in state.ordered_station_keys():
		for mood in state.station(key).moods:
			if mood.state == DeskMood.LUNCH:
				assert_between(mood.slot, GameConfig.LUNCH_SLOT, GameConfig.KITCHEN_SLOTS - 1)
				assert_true(layout.kitchen.has_point(layout.kitchen_slot(mood.slot)))
				assert_true(DeskMood.is_away_state(mood.state))


func test_lunch_never_takes_more_than_the_table_holds() -> void:
	var review := _staff(GameConfig.LUNCH_SIZE + 4)
	assert_gt(review.staff, GameConfig.LUNCH_SIZE)
	var joined := sim.call_lunch()
	assert_eq(joined, GameConfig.LUNCH_SIZE)


func test_lunch_timer_calls_lunch_and_retries_without_staff() -> void:
	state.lunch_timer = 0.01
	sim.tick(0.05)
	assert_eq(state.lunches, 0)
	assert_almost_eq(state.lunch_timer, GameConfig.LUNCH_RETRY_SECONDS, 0.001)
	_staff(4)
	state.lunch_timer = 0.01
	sim.tick(0.05)
	assert_gt(state.lunches, 0)
	assert_between(state.lunch_timer, GameConfig.LUNCH_MIN_INTERVAL - 0.1, GameConfig.LUNCH_MAX_INTERVAL)


func test_works_outing_pauses_lunch() -> void:
	_staff(4)
	state.seals = 50
	assert_true(Boosts.new(state, sim).use("works_outing", Boosts.SEALS))
	state.lunch_timer = 0.01
	sim.tick(0.05)
	assert_eq(state.lunches, 0)


func test_lunch_ends_after_the_canteen_break() -> void:
	_staff(4)
	sim.call_lunch()
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.LUNCH), GameConfig.LUNCH_SECONDS, 0.001)
	var elapsed := 0.0
	while _lunch_guests() > 0 and elapsed < GameConfig.LUNCH_SECONDS * 3.0:
		sim.tick(0.25)
		elapsed += 0.25
	assert_eq(_lunch_guests(), 0)
	assert_gte(elapsed, GameConfig.LUNCH_SECONDS - 1.0)


func test_canteen_upgrades_shorten_the_break_and_raise_alertness() -> void:
	var base_limit := Formulas.rest_limit(state, DeskMood.LUNCH)
	state.set_upgrade("canteen_speed", 50)
	assert_lt(Formulas.rest_limit(state, DeskMood.LUNCH), base_limit)
	assert_almost_eq(Formulas.upgrade_value(state, "canteen_menu"), 1.2, 0.0001)
	state.set_upgrade("canteen_menu", 100)
	assert_almost_eq(Formulas.upgrade_value(state, "canteen_menu"), 2.2, 0.0001)
	state.rng.seed = 5
	var fed := Formulas.wake_alert(state, DeskMood.LUNCH)
	state.rng.seed = 5
	var plain := Formulas.wake_alert(state, DeskMood.LOO)
	assert_almost_eq(fed, plain * 2.2, 0.001)


func test_canteen_upgrades_sit_at_the_canteen_spot() -> void:
	assert_eq(GameConfig.spot_room("canteen"), GameConfig.ROOM_KITCHEN)
	for upgrade_id: String in ["canteen_menu", "canteen_speed"]:
		assert_eq(GameConfig.upgrade_spot(upgrade_id), "canteen", upgrade_id)
	assert_true(layout.kitchen.encloses(layout.canteen_counter_rect()))
	assert_true(layout.kitchen.has_point(layout.cook_point()))
	assert_true(layout.kitchen.has_point(layout.lunch_table_point()))
	assert_eq(layout.spot_at(layout.canteen_counter_rect().get_center()), "canteen")


func test_lunch_lines_are_translated() -> void:
	var keys: Array[String] = ["SPOT_CANTEEN", "TRACK_CANTEEN_MENU", "TRACK_CANTEEN_SPEED", "TRACK_DESC_CANTEEN_MENU", "TRACK_DESC_CANTEEN_SPEED", "OFFICIAL_STATE_LUNCH", "FMT_STATUS_CANTEEN", "ROOM_PLAYER_OFFICE", "SIGN_EMPLOYEE_OF_MONTH", "DESK_LETTER_TITLE", "DESK_GIFT_TITLE", "FMT_DESK_GIFT"]
	for i in Flavor.LUNCH_COUNT:
		keys.append("LUNCH_%d" % (i + 1))
	for i in Flavor.LUNCH_TALK_COUNT:
		keys.append("LUNCH_TALK_%d" % (i + 1))
	for i in Flavor.INTERN_ENDURE_COUNT:
		keys.append("INTERN_ENDURE_%d" % (i + 1))
	for i in GameConfig.GIFT_KINDS:
		keys.append("GIFT_%d" % (i + 1))
	var previous := TranslationServer.get_locale()
	for locale: String in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(String(tr(key)), key, locale + "/" + key)
	TranslationServer.set_locale(previous)


func test_gift_appears_on_the_timer_and_waits_for_the_player() -> void:
	watch_signals(sim)
	state.gift_timer = 0.01
	sim.tick(0.05)
	assert_between(state.gift_kind, 0, GameConfig.GIFT_KINDS - 1)
	assert_gte(state.gift_money, float(GameConfig.GIFT_MIN_MONEY))
	assert_signal_emitted(sim, "gift_arrived")
	var kind := state.gift_kind
	state.gift_timer = 0.0
	sim.tick(0.05)
	assert_eq(state.gift_kind, kind)
	assert_false(sim.place_gift(0))


func test_gift_value_follows_income() -> void:
	assert_eq(Formulas.gift_value(state), float(GameConfig.GIFT_MIN_MONEY))
	assert_eq(Formulas.gift_interval(-1.0), GameConfig.GIFT_MIN_INTERVAL)
	assert_eq(Formulas.gift_interval(2.0), GameConfig.GIFT_MAX_INTERVAL)
	assert_eq(Formulas.lunch_interval(0.0), GameConfig.LUNCH_MIN_INTERVAL)
	assert_eq(Formulas.lunch_interval(1.0), GameConfig.LUNCH_MAX_INTERVAL)


func test_claiming_a_gift_pays_out_once() -> void:
	assert_false(sim.claim_gift())
	assert_true(sim.place_gift(99))
	assert_eq(state.gift_kind, GameConfig.GIFT_KINDS - 1)
	var value := state.gift_money
	var money := state.money
	watch_signals(sim)
	assert_true(sim.claim_gift())
	assert_almost_eq(state.money, money + value, 0.001)
	assert_eq(state.gift_kind, -1)
	assert_eq(state.gift_money, 0.0)
	assert_eq(state.gifts_opened, 1)
	assert_signal_emitted_with_parameters(sim, "gift_claimed", [GameConfig.GIFT_KINDS - 1, value])
	assert_false(sim.claim_gift())


func test_doubled_gift_counts_the_ad() -> void:
	assert_false(sim.claim_gift_doubled())
	assert_eq(state.ads_watched, 0)
	sim.place_gift(0)
	var value := state.gift_money
	var money := state.money
	assert_true(sim.claim_gift_doubled())
	assert_almost_eq(state.money, money + value * GameConfig.AD_REWARD_FACTOR, 0.001)
	assert_eq(state.ads_watched, 1)


func test_player_must_stand_at_the_office_desk() -> void:
	assert_false(sim.at_office_desk())
	state.player.position = layout.office_desk_point()
	assert_true(sim.at_office_desk())


func test_lunch_and_gift_state_survive_saving_and_are_clamped() -> void:
	state.lunch_timer = 77.0
	state.lunches = 12
	state.gift_timer = 33.0
	state.complaints_absorbed = 5
	sim.place_gift(2)
	state.gift_money = 140.0
	state.gifts_opened = 4
	var copy := GameState.from_dict(state.to_dict())
	assert_almost_eq(copy.lunch_timer, 77.0, 0.001)
	assert_eq(copy.lunches, 12)
	assert_almost_eq(copy.gift_timer, 33.0, 0.001)
	assert_eq(copy.gift_kind, 2)
	assert_almost_eq(copy.gift_money, 140.0, 0.001)
	assert_eq(copy.gifts_opened, 4)
	assert_eq(copy.complaints_absorbed, 5)
	var data := state.to_dict()
	data.lunch_timer = 1e9
	data.lunches = -3
	data.gift_timer = -5.0
	data.gift_kind = 99
	data.gift_money = -10.0
	data.gifts_opened = -1
	data.complaints_absorbed = -4
	var clamped := GameState.from_dict(data)
	assert_eq(clamped.lunch_timer, GameConfig.LUNCH_MAX_INTERVAL)
	assert_eq(clamped.lunches, 0)
	assert_eq(clamped.gift_timer, 0.0)
	assert_eq(clamped.gift_kind, GameConfig.GIFT_KINDS - 1)
	assert_eq(clamped.gift_money, 0.0)
	assert_eq(clamped.gifts_opened, 0)
	assert_eq(clamped.complaints_absorbed, 0)
	data.gift_kind = -7
	data.gift_money = 500.0
	var empty := GameState.from_dict(data)
	assert_eq(empty.gift_kind, -1)
	assert_eq(empty.gift_money, 0.0)
	var fresh := {}
	var defaults := GameState.from_dict(fresh)
	assert_eq(defaults.lunch_timer, GameConfig.LUNCH_FIRST_SECONDS)
	assert_eq(defaults.gift_kind, -1)


func test_hud_desk_card_offers_letter_and_gift_only_at_the_desk() -> void:
	var game := Game.new(state)
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	hud.refresh()
	assert_false(hud._desk_card.visible)
	game.simulation.place_gift(1)
	hud.refresh()
	assert_false(hud._desk_card.visible)
	state.player.position = layout.office_desk_point()
	hud.refresh()
	assert_true(hud._desk_card.visible)
	assert_true(hud._gift_box.visible)
	assert_false(hud._letter_box.visible)
	assert_eq(hud._gift_text.text, hud.tr("FMT_DESK_GIFT") % [Flavor.gift(1), UiKit.money(state.gift_money)])
	var take := _button(hud._gift_box, hud.tr("ACTION_CLAIM"))
	assert_not_null(take)
	assert_not_null(_button(hud._gift_box, hud.tr("ACTION_CLAIM_DOUBLE")))
	var money := state.money
	take.pressed.emit()
	assert_gt(state.money, money)
	assert_eq(state.gift_kind, -1)
	state.cases_completed = 1000
	hud.refresh()
	assert_true(game.goals.is_complete())
	assert_true(hud._letter_box.visible)
	assert_false(hud._gift_box.visible)
	var goal_index := state.goal_index
	_button(hud._letter_box, hud.tr("ACTION_CLAIM")).pressed.emit()
	assert_eq(state.goal_index, goal_index + 1)


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null
