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
	state.complaint_timer = 1e6
	state.player.position = Vector2(50, 50)


func _submit(times: int) -> void:
	for i in times:
		state.complaints = 0
		sim.submit_complaint()


func _clerk_max() -> int:
	return int(GameConfig.upgrade("complaint_clerk").max)


func _legacy_save() -> Dictionary:
	var data := state.to_dict()
	data.erase("upgrades")
	data["version"] = GameState.LEGACY_SAVE_VERSION
	data["research"] = {}
	return data


func _entry_ids(entries: Array[UpgradeEntry]) -> Array[String]:
	var ids: Array[String] = []
	for entry in entries:
		ids.append(entry.id)
	return ids


func test_fend_chance_rises_with_level_and_stays_below_certainty() -> void:
	var max_level := _clerk_max()
	assert_gte(max_level, 100)
	assert_gt(Formulas.complaint_fend_chance(0), 0.0)
	var rising := true
	for level in range(1, max_level + 1):
		rising = rising and Formulas.complaint_fend_chance(level) > Formulas.complaint_fend_chance(level - 1)
	assert_true(rising)
	assert_lt(Formulas.complaint_fend_chance(max_level), 1.0)
	state.set_upgrade("complaint_clerk", -3)
	assert_eq(state.upgrade_level("complaint_clerk"), 0)
	state.set_upgrade("complaint_clerk", max_level + 50)
	assert_eq(state.upgrade_level("complaint_clerk"), max_level)


func test_clerk_fends_off_some_complaints_and_the_rest_lands_in_the_box() -> void:
	watch_signals(sim)
	_submit(400)
	assert_gt(state.complaints_fended, 0)
	assert_lt(state.complaints_fended, 400)
	assert_eq(state.complaints_fended + state.complaints_filed, 400)
	assert_signal_emitted(sim, "complaint_fended")
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [false])


func test_trained_clerk_fends_off_more() -> void:
	_submit(600)
	var untrained := state.complaints_fended
	state.complaints_fended = 0
	state.set_upgrade("complaint_clerk", _clerk_max())
	_submit(600)
	assert_gt(state.complaints_fended, untrained)


func test_amnesty_blocks_submitted_complaints() -> void:
	state.seals = 10
	assert_true(Boosts.new(state, sim).use("complaint_amnesty", Boosts.SEALS))
	_submit(50)
	assert_eq(state.complaints_fended, 0)
	assert_eq(state.complaints_filed, 0)


func test_fended_complaint_never_posts_a_review() -> void:
	state.complaints = Formulas.complaint_cap(state)
	state.set_upgrade("complaint_clerk", _clerk_max())
	for i in 300:
		sim.submit_complaint()
	var overflows := 300 - state.complaints_fended
	assert_gt(overflows, 0)
	assert_eq(state.complaints, Formulas.complaint_cap(state))
	assert_eq(state.negative_review_count(), mini(overflows, GameConfig.MAX_NEGATIVE_REVIEWS))


func test_visitor_complaint_goes_through_the_clerk() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for i in 40:
		assert_not_null(sim.spawn_visitor(false, true))
		var elapsed := 0.0
		while not state.visitors.is_empty() and elapsed < 120.0:
			sim.tick(0.1)
			elapsed += 0.1
		state.complaints = 0
	assert_gt(state.complaints_fended, 0)
	assert_eq(state.complaints_fended + state.complaints_filed, 40)


func test_upgrading_the_clerk_costs_money_and_stops_at_max() -> void:
	var max_level := _clerk_max()
	state.money = 0.0
	assert_eq(Progression.upgrade_block_reason(state, "complaint_clerk"), "money")
	assert_false(actions.buy_upgrade("complaint_clerk"))
	state.money = 1.0e12
	var first := Formulas.track_cost("complaint_clerk", 0)
	assert_eq(first, float(GameConfig.upgrade("complaint_clerk").cost))
	assert_true(actions.buy_upgrade("complaint_clerk"))
	assert_eq(state.upgrade_level("complaint_clerk"), 1)
	assert_almost_eq(state.money, 1.0e12 - first, 0.01)
	assert_gt(Formulas.track_cost("complaint_clerk", 1), first)
	var rest := Formulas.track_bulk_cost("complaint_clerk", 1, max_level - 1)
	var money := state.money
	assert_true(actions.buy_upgrade("complaint_clerk", "", max_level))
	assert_eq(state.upgrade_level("complaint_clerk"), max_level)
	assert_almost_eq(state.money, money - rest, 0.01)
	assert_eq(Progression.upgrade_block_reason(state, "complaint_clerk"), "max")
	assert_false(actions.buy_upgrade("complaint_clerk"))


func test_upgrading_the_box_adds_space_and_stops_at_max() -> void:
	var config := GameConfig.upgrade("complaint_box")
	var max_level := int(config.max)
	var step := int(config.step)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY)
	state.money = 0.0
	assert_false(actions.buy_upgrade("complaint_box"))
	state.money = 1.0e12
	var first := Formulas.track_cost("complaint_box", 0)
	assert_eq(first, float(config.cost))
	assert_true(actions.buy_upgrade("complaint_box"))
	assert_almost_eq(state.money, 1.0e12 - first, 0.01)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + step)
	assert_gt(Formulas.track_cost("complaint_box", 1), first)
	assert_true(actions.buy_upgrade("complaint_box", "", max_level))
	assert_eq(state.upgrade_level("complaint_box"), max_level)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + step * max_level)
	assert_eq(Progression.upgrade_block_reason(state, "complaint_box"), "max")
	assert_false(actions.buy_upgrade("complaint_box"))


func test_levels_and_fended_counter_survive_saving() -> void:
	state.set_upgrade("complaint_clerk", 2)
	state.set_upgrade("complaint_box", 30)
	state.complaints_fended = 17
	state.complaints = 45
	var copy := GameState.from_dict(state.to_dict())
	assert_eq(copy.upgrade_level("complaint_clerk"), 2)
	assert_eq(copy.upgrade_level("complaint_box"), 30)
	assert_eq(copy.complaints_fended, 17)
	assert_eq(copy.complaints, 45)


func test_loading_sanitizes_levels() -> void:
	var data := state.to_dict()
	data["upgrades"] = {"complaint_clerk": 99999, "complaint_box": -4, "complaint_clerk@hall": 5}
	data["complaints_fended"] = -3
	var copy := GameState.from_dict(data)
	assert_eq(copy.upgrade_level("complaint_clerk"), _clerk_max())
	assert_eq(copy.upgrade_level("complaint_box"), 0)
	assert_false(copy.upgrades.has("complaint_box"))
	assert_false(copy.upgrades.has("complaint_clerk@hall"))
	assert_eq(copy.complaints_fended, 0)
	data.erase("upgrades")
	data.erase("complaints_fended")
	copy = GameState.from_dict(data)
	assert_eq(copy.upgrade_level("complaint_clerk"), 0)
	assert_eq(copy.upgrade_level("complaint_box"), 0)
	assert_eq(copy.complaints_fended, 0)


func test_legacy_clerk_and_box_levels_become_tracks() -> void:
	var data := _legacy_save()
	data["complaint_clerk_level"] = 2
	data["complaint_box_level"] = 3
	data["complaints"] = 25
	var copy := GameState.from_dict(data)
	assert_eq(copy.upgrade_level("complaint_clerk"), SaveMigration.CLERK_STEPS[2])
	assert_eq(copy.upgrade_level("complaint_box"), 3 * SaveMigration.BOX_SCALE)
	assert_eq(copy.complaints, 25)
	assert_gt(Formulas.complaint_fend_chance(copy.upgrade_level("complaint_clerk")), Formulas.complaint_fend_chance(0))
	data["complaint_clerk_level"] = 99
	assert_eq(GameState.from_dict(data).upgrade_level("complaint_clerk"), SaveMigration.CLERK_STEPS[SaveMigration.CLERK_STEPS.size() - 1])


func test_old_complaint_desk_research_becomes_box_levels() -> void:
	var data := _legacy_save()
	data.erase("complaint_box_level")
	(data["research"] as Dictionary)["complaint_desk"] = 2
	data["complaints"] = 35
	var copy := GameState.from_dict(data)
	assert_eq(copy.upgrade_level("complaint_box"), 2 * SaveMigration.BOX_SCALE)
	assert_eq(copy.complaints, 35)
	assert_false(copy.upgrades.has("complaint_desk"))
	data["complaint_box_level"] = 3
	assert_eq(GameState.from_dict(data).upgrade_level("complaint_box"), 3 * SaveMigration.BOX_SCALE)
	(data["research"] as Dictionary)["complaint_desk"] = 50
	assert_eq(GameState.from_dict(data).upgrade_level("complaint_box"), int(GameConfig.upgrade("complaint_box").max))


func test_complaint_spots_offer_clerk_box_and_tube_upgrades() -> void:
	assert_eq(GameConfig.spot_room("complaint_desk"), GameConfig.ROOM_COMPLAINTS)
	assert_eq(GameConfig.spot_room("interns"), GameConfig.ROOM_COMPLAINTS)
	assert_eq(GameConfig.spot_room("complaint_box"), GameConfig.ROOM_HALL)
	var desk := _entry_ids(UpgradeCatalog.entries_for_spot(state, "complaint_desk"))
	assert_true(desk.has("%s:complaint_clerk" % UpgradeCatalog.TRACK))
	var box := _entry_ids(UpgradeCatalog.entries_for_spot(state, "complaint_box"))
	assert_true(box.has("%s:complaint_box" % UpgradeCatalog.TRACK))
	assert_true(box.has("%s:complaint_tube" % UpgradeCatalog.TRACK))
	var office := _entry_ids(UpgradeCatalog.entries_for_spot(state, UpgradeCatalog.ROOM_PREFIX + GameConfig.ROOM_COMPLAINTS))
	assert_true(office.has("%s:complaint_clerk" % UpgradeCatalog.TRACK))
	assert_true(office.has("%s:shredder_service" % UpgradeCatalog.TRACK))
	assert_true(office.has("%s:helpers" % UpgradeCatalog.STAFF))
	assert_false(office.has("%s:complaint_box" % UpgradeCatalog.TRACK))
	assert_eq(layout.spot_at(layout.complaint_desk_point()), "complaint_desk")
	assert_eq(layout.spot_at(layout.complaint_box_point()), "complaint_box")


func test_layout_puts_the_office_above_the_hall_with_the_box_beside_it() -> void:
	var office := layout.complaint_office
	var desk := layout.complaint_desk_point()
	var box := layout.complaint_box_point()
	assert_eq(office.end.y + WorldLayout.GAP, layout.hall.position.y)
	assert_eq(layout.shredder_room.end.y + WorldLayout.GAP, layout.hall.position.y)
	assert_true(office.has_point(desk))
	assert_true(layout.hall.has_point(box))
	assert_between(box.x, office.position.x, office.end.x)
	assert_between(layout.office_door().x, office.position.x, office.end.x)
	assert_false(layout.near(desk, box))
	assert_false(layout.near(box, layout.shredder_point()))
	assert_true(office.encloses(layout.complaint_read_rect()))
	assert_true(layout.complaint_read_rect().has_point(desk))
	assert_false(layout.complaint_read_rect().has_point(box))
	assert_false(layout.complaint_read_rect().has_point(layout.shredder_point()))
	assert_lt(layout.complaint_clerk_point().y, desk.y)
	assert_true(office.encloses(layout.interns_board()))
	for slot in GameConfig.MAX_HELPERS + 1:
		var home := layout.intern_home(slot)
		assert_true(office.has_point(home), str(slot))
		assert_gt(home.x, desk.x + 60.0, str(slot))
		assert_true(layout.shredder_room.has_point(layout.intern_shred_point(slot)), str(slot))
		assert_lt(layout.intern_shred_point(slot).x, layout.shredder_point().x)
	for slot in GameConfig.VISITOR_SLOTS:
		var spot := layout.vent_spot(slot)
		assert_true(office.has_point(spot), str(slot))
		assert_gt(spot.x, desk.x + 40.0)
		assert_true(office.has_point(layout.visitor_spot(slot)), str(slot))
	assert_eq(layout.vent_spot(99), layout.vent_spot(GameConfig.VISITOR_SLOTS - 1))
	assert_true(layout.hall.has_point(layout.complaint_drop_spot()))
	assert_true(layout.near(layout.complaint_drop_spot(), box))
	var tube := layout.complaint_tube_path()
	assert_eq(tube[0].x, box.x)
	assert_eq(tube[tube.size() - 1].x, layout.shredder_point().x)
	assert_true(layout.shredder_room.has_point(tube[tube.size() - 1]))


func test_closed_sign_stands_in_the_hall_away_from_the_complaint_spots() -> void:
	var sign := layout.closed_sign_rect()
	assert_true(layout.hall.encloses(sign))
	assert_false(sign.has_point(layout.complaint_box_point()))
	assert_false(sign.has_point(layout.shredder_point()))
	assert_false(sign.has_point(layout.complaint_desk_point()))
	assert_false(sign.has_point(layout.complaint_drop_spot()))
	for slot in GameConfig.MAX_HELPERS + 1:
		assert_false(sign.has_point(layout.intern_shred_point(slot)), str(slot))
		assert_false(sign.has_point(layout.intern_home(slot)), str(slot))


func test_clerk_and_box_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["FLOAT_REVIEW_EXPIRED", "FMT_REVIEW_EXPIRES", "SIGN_CLOSED", "ROOM_COMPLAINT_OFFICE", "ROOM_DESC_COMPLAINT_OFFICE", "FMT_STATUS_COMPLAINT_DESK", "FMT_STATUS_COMPLAINT_BOX", "ACTION_READ_COMPLAINTS"]
	for upgrade_id: String in ["complaint_clerk", "complaint_box", "complaint_tube"]:
		keys.append("TRACK_" + upgrade_id.to_upper())
		keys.append("TRACK_DESC_" + upgrade_id.to_upper())
	for spot: String in ["complaint_desk", "complaint_box", "interns"]:
		keys.append("SPOT_" + spot.to_upper())
		keys.append(UpgradeTexts.spot_description_key(spot))
	for i in Flavor.FEND_COUNT:
		keys.append("CLERK_FEND_%d" % (i + 1))
	var previous := TranslationServer.get_locale()
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
	TranslationServer.set_locale(previous)
	assert_eq(Flavor.fend(Flavor.FEND_COUNT), Flavor.fend(0))
	assert_ne(Flavor.fend(0), Flavor.fend(1))
