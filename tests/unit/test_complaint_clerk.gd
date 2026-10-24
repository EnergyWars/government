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


func test_fend_chance_rises_with_level_and_stays_below_certainty() -> void:
	assert_eq(GameConfig.COMPLAINT_CLERK_FEND_CHANCES.size(), GameConfig.COMPLAINT_CLERK_MAX_LEVEL + 1)
	assert_gt(Formulas.complaint_fend_chance(0), 0.0)
	for level in range(1, GameConfig.COMPLAINT_CLERK_MAX_LEVEL + 1):
		assert_gt(Formulas.complaint_fend_chance(level), Formulas.complaint_fend_chance(level - 1))
	assert_lt(Formulas.complaint_fend_chance(GameConfig.COMPLAINT_CLERK_MAX_LEVEL), 1.0)
	assert_eq(Formulas.complaint_fend_chance(-3), Formulas.complaint_fend_chance(0))
	assert_eq(Formulas.complaint_fend_chance(99), Formulas.complaint_fend_chance(GameConfig.COMPLAINT_CLERK_MAX_LEVEL))


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
	state.complaint_clerk_level = GameConfig.COMPLAINT_CLERK_MAX_LEVEL
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
	state.complaint_clerk_level = GameConfig.COMPLAINT_CLERK_MAX_LEVEL
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
	state.money = 0.0
	assert_false(actions.can_upgrade_complaint_clerk())
	assert_false(actions.upgrade_complaint_clerk())
	state.money = 1.0e9
	var first := Formulas.complaint_clerk_cost(state)
	assert_eq(first, GameConfig.COMPLAINT_CLERK_COST)
	assert_true(actions.upgrade_complaint_clerk())
	assert_eq(state.complaint_clerk_level, 1)
	assert_eq(state.money, 1.0e9 - first)
	assert_gt(Formulas.complaint_clerk_cost(state), first)
	while actions.can_upgrade_complaint_clerk():
		actions.upgrade_complaint_clerk()
	assert_eq(state.complaint_clerk_level, GameConfig.COMPLAINT_CLERK_MAX_LEVEL)
	assert_false(actions.upgrade_complaint_clerk())


func test_upgrading_the_box_adds_space_and_stops_at_max() -> void:
	assert_eq(Formulas.complaint_cap(state), 20)
	state.money = 0.0
	assert_false(actions.upgrade_complaint_box())
	state.money = 1.0e9
	var first := Formulas.complaint_box_cost(state)
	assert_eq(first, GameConfig.COMPLAINT_BOX_COST)
	assert_true(actions.upgrade_complaint_box())
	assert_eq(state.money, 1.0e9 - first)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + GameConfig.COMPLAINT_BOX_PER_LEVEL)
	assert_gt(Formulas.complaint_box_cost(state), first)
	while actions.can_upgrade_complaint_box():
		actions.upgrade_complaint_box()
	assert_eq(state.complaint_box_level, GameConfig.COMPLAINT_BOX_MAX_LEVEL)
	assert_false(actions.upgrade_complaint_box())


func test_levels_and_fended_counter_survive_saving() -> void:
	state.complaint_clerk_level = 2
	state.complaint_box_level = 3
	state.complaints_fended = 17
	state.complaints = 45
	var copy := GameState.from_dict(state.to_dict())
	assert_eq(copy.complaint_clerk_level, 2)
	assert_eq(copy.complaint_box_level, 3)
	assert_eq(copy.complaints_fended, 17)
	assert_eq(copy.complaints, 45)


func test_loading_sanitizes_levels() -> void:
	var data := state.to_dict()
	data["complaint_clerk_level"] = 99
	data["complaint_box_level"] = -4
	data["complaints_fended"] = -3
	var copy := GameState.from_dict(data)
	assert_eq(copy.complaint_clerk_level, GameConfig.COMPLAINT_CLERK_MAX_LEVEL)
	assert_eq(copy.complaint_box_level, 0)
	assert_eq(copy.complaints_fended, 0)
	data.erase("complaint_clerk_level")
	data.erase("complaint_box_level")
	data.erase("complaints_fended")
	copy = GameState.from_dict(data)
	assert_eq(copy.complaint_clerk_level, 0)
	assert_eq(copy.complaint_box_level, 0)
	assert_eq(copy.complaints_fended, 0)


func test_old_complaint_desk_research_becomes_box_levels() -> void:
	var data := state.to_dict()
	data.erase("complaint_box_level")
	(data["research"] as Dictionary)["complaint_desk"] = 2
	data["complaints"] = 35
	var copy := GameState.from_dict(data)
	assert_eq(copy.complaint_box_level, 2)
	assert_eq(copy.complaints, 35)
	assert_false(copy.research.has("complaint_desk"))
	data["complaint_box_level"] = 3
	assert_eq(GameState.from_dict(data).complaint_box_level, 3)
	(data["research"] as Dictionary)["complaint_desk"] = 50
	assert_eq(GameState.from_dict(data).complaint_box_level, GameConfig.COMPLAINT_BOX_MAX_LEVEL)


func test_hall_offers_clerk_and_box_upgrades() -> void:
	var areas := GameConfig.room_items(GameConfig.ROOM_HALL, "areas")
	assert_true(areas.has("complaint_clerk"))
	assert_true(areas.has("complaint_box"))
	assert_false(GameConfig.RESEARCH.has("complaint_desk"))
	assert_false(GameConfig.RESEARCH_ORDER.has("complaint_desk"))


func test_layout_places_box_apart_from_the_desk_with_the_interns_beside_it() -> void:
	var desk := layout.complaint_desk_point()
	var box := layout.complaint_box_point()
	assert_true(layout.hall.has_point(box))
	assert_false(layout.near(desk, box))
	assert_false(layout.near(box, layout.shredder_point()))
	assert_true(layout.complaint_read_rect().has_point(box))
	assert_true(layout.complaint_read_rect().has_point(desk))
	assert_false(layout.complaint_read_rect().has_point(layout.shredder_point()))
	assert_lt(layout.complaint_clerk_point().y, desk.y)
	for slot in GameConfig.MAX_HELPERS + 1:
		var home := layout.intern_home(slot)
		assert_between(home.x, desk.x + 60.0, box.x - 30.0, str(slot))
		assert_lt(layout.intern_shred_point(slot).x, layout.shredder_point().x)
		assert_gt(layout.intern_shred_point(slot).x - box.x, 30.0)
	assert_true(layout.near(layout.intern_home(GameConfig.MAX_HELPERS), box))
	for slot in GameConfig.VISITOR_SLOTS:
		var spot := layout.vent_spot(slot)
		assert_true(layout.hall.has_point(spot), str(slot))
		assert_gt(spot.x, desk.x + 40.0)
		assert_lt(spot.x, box.x)
	assert_eq(layout.vent_spot(99), layout.vent_spot(GameConfig.VISITOR_SLOTS - 1))
	assert_true(layout.hall.has_point(layout.complaint_drop_spot()))
	assert_true(layout.near(layout.complaint_drop_spot(), box))
	var tube := layout.complaint_tube_path()
	assert_eq(tube[0].x, box.x)
	assert_eq(tube[tube.size() - 1].x, layout.shredder_point().x)


func test_closed_sign_replaces_the_desk_inside_the_hall() -> void:
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
	var keys: Array[String] = ["COMPLAINT_CLERK_TITLE", "COMPLAINT_CLERK_DESC", "ACTION_TRAIN_CLERK", "FMT_COMPLAINT_CLERK_INFO", "FMT_COMPLAINT_CLERK_NEXT", "COMPLAINT_BOX_TITLE", "COMPLAINT_BOX_DESC", "ACTION_ENLARGE_BOX", "FMT_COMPLAINT_BOX_INFO", "UPGRADE_CLERK", "FLOAT_REVIEW_EXPIRED", "FMT_REVIEW_EXPIRES", "SIGN_CLOSED"]
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
