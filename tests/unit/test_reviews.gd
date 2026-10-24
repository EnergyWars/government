extends GutTest

var state: GameState
var sim: Simulation
var game: Game


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.complaint_timer = 1e6
	state.player.position = Vector2(50, 50)
	state.money = 1.0e6
	game = Game.new(state)


func _completed_case(flawed: bool) -> CaseFile:
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.flawed = flawed
	return case_file


func test_review_clamps_stars_and_classifies() -> void:
	assert_eq(Review.new(0, 9).stars, 5)
	assert_eq(Review.new(0, -3).stars, 1)
	assert_true(Review.new(0, 1).is_negative())
	assert_true(Review.new(0, 2).is_negative())
	assert_false(Review.new(0, 3).is_negative())
	assert_false(Review.new(0, 5).is_negative())


func test_drain_weight_depends_on_stars() -> void:
	assert_eq(Review.new(0, 1).drain_weight(), 1.0)
	assert_eq(Review.new(0, 2).drain_weight(), 0.5)
	assert_eq(Review.new(0, 4).drain_weight(), 0.0)


func test_forced_praise_is_five_stars_without_drain() -> void:
	var review := Review.new(0, 1, 2, 3)
	review.force_praise(4)
	assert_eq(review.stars, 5)
	assert_true(review.forced)
	assert_false(review.is_negative())
	assert_eq(review.drain_weight(), 0.0)
	assert_eq(review.text_key(), "REVIEW_FORCED_5")


func test_keys_follow_indices() -> void:
	var review := Review.new(0, 3, 1, 6)
	assert_eq(review.text_key(), "REVIEW_TEXT_3_2")
	assert_eq(review.author_key(), "REVIEW_AUTHOR_7")


func test_review_round_trip() -> void:
	var review := Review.new(7, 2, 3, 5, 12.5)
	var copy := Review.from_dict(review.to_dict())
	assert_eq(copy.id, 7)
	assert_eq(copy.stars, 2)
	assert_eq(copy.text_index, 3)
	assert_eq(copy.author_index, 5)
	assert_eq(copy.posted_at, 12.5)
	assert_false(copy.forced)
	review.force_praise(2)
	var forced := Review.from_dict(review.to_dict())
	assert_true(forced.forced)
	assert_eq(forced.stars, 5)
	assert_eq(forced.text_index, 2)


func test_review_from_dict_sanitizes() -> void:
	assert_null(Review.from_dict("nope"))
	var wild := Review.from_dict({"id": -4, "stars": 99, "text": 99, "author": 99, "at": -5.0, "forced": true})
	assert_eq(wild.id, 0)
	assert_eq(wild.stars, 5)
	assert_eq(wild.text_index, GameConfig.REVIEW_FORCED_TEXTS - 1)
	assert_eq(wild.author_index, GameConfig.REVIEW_AUTHORS - 1)
	assert_eq(wild.posted_at, 0.0)
	var plain := Review.from_dict({"stars": 2, "text": 99})
	assert_eq(plain.text_index, GameConfig.review_texts(2) - 1)


func test_state_adds_reviews_with_sequence() -> void:
	var first := state.add_review(4)
	var second := state.add_review(1)
	assert_ne(first.id, second.id)
	assert_eq(state.reviews.size(), 2)
	assert_eq(state.find_review(second.id), second)
	assert_null(state.find_review(999))


func test_state_statistics() -> void:
	assert_eq(state.average_rating(), 0.0)
	state.add_review(5)
	state.add_review(5)
	state.add_review(2)
	state.add_review(1)
	assert_almost_eq(state.average_rating(), 3.25, 0.0001)
	assert_eq(state.star_counts(), [1, 1, 0, 0, 2] as Array[int])
	assert_eq(state.negative_review_count(), 2)
	assert_almost_eq(state.review_drain(), 1.5, 0.0001)


func test_trim_drops_oldest_non_negative_first() -> void:
	var negative := state.add_review(1)
	for i in GameConfig.MAX_STORED_REVIEWS + 5:
		state.add_review(5)
	assert_eq(state.reviews.size(), GameConfig.MAX_STORED_REVIEWS)
	assert_eq(state.find_review(negative.id), negative)


func test_trim_drops_oldest_when_all_negative() -> void:
	var first := state.add_review(1)
	for i in GameConfig.MAX_STORED_REVIEWS:
		state.add_review(1)
	assert_eq(state.reviews.size(), GameConfig.MAX_STORED_REVIEWS)
	assert_null(state.find_review(first.id))


func test_complaint_can_post_a_negative_review() -> void:
	watch_signals(sim)
	for i in 80:
		sim.file_complaint()
	assert_gt(state.negative_review_count(), 0)
	assert_lte(state.negative_review_count(), GameConfig.MAX_NEGATIVE_REVIEWS)
	assert_signal_emitted(sim, "review_posted")
	for review in state.reviews:
		assert_true(review.is_negative())


func test_negative_reviews_use_one_or_two_stars() -> void:
	var seen := {}
	for i in 200:
		sim.file_complaint()
		for review in state.reviews:
			seen[review.stars] = true
		state.reviews.clear()
	assert_true(seen.has(1))
	assert_true(seen.has(2))


func test_completed_cases_bring_praise() -> void:
	watch_signals(sim)
	for i in 200:
		sim.complete_case(_completed_case(false))
	assert_signal_emitted(sim, "review_posted")
	var stars := state.star_counts()
	assert_gt(stars[4], 0)
	assert_gt(stars[3], 0)
	assert_eq(stars[0], 0)
	assert_eq(stars[1], 0)


func test_flawed_cases_bring_three_star_reviews_only() -> void:
	for i in 200:
		sim.complete_case(_completed_case(true))
	var stars := state.star_counts()
	assert_gt(stars[2], 0)
	assert_eq(stars[0] + stars[1] + stars[3] + stars[4], 0)


func test_negative_reviews_drain_reputation_by_weight() -> void:
	state.add_review(1)
	state.add_review(2)
	state.add_review(5)
	state.reputation = 100.0
	sim.tick(10.0)
	assert_almost_eq(state.reputation, 100.0 - 1.5 * GameConfig.REVIEW_DRAIN * 10.0, 0.01)


func test_positive_reviews_do_not_drain() -> void:
	state.add_review(5)
	state.add_review(3)
	state.reputation = 100.0
	sim.tick(10.0)
	assert_almost_eq(state.reputation, 100.0, 0.001)


func test_delete_review_costs_money_and_returns_reputation() -> void:
	state.cases_completed = 100
	var review := state.add_review(1)
	state.add_review(1)
	state.money = 1.0e6
	state.reputation = 10.0
	watch_signals(sim)
	var cost := Formulas.review_delete_cost(state, review)
	assert_almost_eq(cost, Formulas.review_base_cost(state) * GameConfig.REVIEW_DELETE_STAR_FACTORS[0], 0.001)
	assert_true(sim.delete_review(review.id))
	assert_null(state.find_review(review.id))
	assert_eq(state.reviews.size(), 1)
	assert_almost_eq(state.money, 1.0e6 - cost, 0.001)
	assert_almost_eq(state.reputation, 10.0 + GameConfig.REVIEW_DELETE_REPUTATION, 0.001)
	assert_signal_emitted_with_parameters(sim, "review_removed", ["deleted"])


func test_delete_cost_falls_with_more_stars_and_five_stars_are_free() -> void:
	var previous := INF
	for stars in range(1, 6):
		var cost := Formulas.review_delete_cost(state, Review.new(0, stars))
		assert_lt(cost, previous, "stars %d" % stars)
		previous = cost
	assert_eq(Formulas.review_delete_cost(state, Review.new(0, 5)), 0.0)
	var forced := Review.new(0, 1)
	forced.force_praise(0)
	assert_eq(Formulas.review_delete_cost(state, forced), 0.0)
	assert_gt(Formulas.review_delete_cost(state, Review.new(0, 1)), Formulas.review_base_cost(state) * 5.0)


func test_any_review_can_be_deleted() -> void:
	var praise := state.add_review(5)
	var middle := state.add_review(3)
	state.money = 0.0
	state.reputation = 10.0
	assert_true(sim.can_delete_review(praise.id))
	assert_true(sim.delete_review(praise.id))
	assert_null(state.find_review(praise.id))
	assert_eq(state.money, 0.0)
	assert_eq(state.reputation, 10.0)
	assert_false(sim.delete_review(middle.id))
	state.money = 1.0e6
	assert_true(sim.delete_review(middle.id))
	assert_eq(state.reputation, 10.0)


func test_delete_review_stops_the_drain() -> void:
	var review := state.add_review(1)
	sim.delete_review(review.id)
	assert_eq(state.review_drain(), 0.0)


func test_delete_review_rejects_invalid_requests() -> void:
	var negative := state.add_review(1)
	assert_false(sim.delete_review(999))
	assert_false(sim.can_delete_review(999))
	state.money = 0.0
	assert_false(sim.can_delete_review(negative.id))
	assert_false(sim.delete_review(negative.id))
	assert_not_null(state.find_review(negative.id))


func test_lawsuit_cost_is_the_same_for_every_rating() -> void:
	var first := Formulas.review_lawsuit_cost(state, Review.new(0, 1))
	for stars in range(2, 6):
		assert_almost_eq(Formulas.review_lawsuit_cost(state, Review.new(0, stars)), first, 0.001)
	assert_almost_eq(first, Formulas.review_base_cost(state) * GameConfig.REVIEW_LAWSUIT_FACTOR, 0.001)


func test_lawsuit_gets_dearer_and_likelier_with_each_attempt() -> void:
	var review := Review.new(0, 2)
	var cost := Formulas.review_lawsuit_cost(state, review)
	var chance := Formulas.review_lawsuit_chance(review)
	assert_eq(chance, GameConfig.REVIEW_LAWSUIT_CHANCE)
	review.lawsuits = 1
	assert_almost_eq(Formulas.review_lawsuit_cost(state, review), cost * GameConfig.REVIEW_LAWSUIT_GROWTH, 0.001)
	assert_almost_eq(Formulas.review_lawsuit_chance(review), chance + GameConfig.REVIEW_LAWSUIT_CHANCE_STEP, 0.0001)
	review.lawsuits = GameConfig.MAX_REVIEW_LAWSUITS
	assert_eq(Formulas.review_lawsuit_chance(review), GameConfig.REVIEW_LAWSUIT_MAX_CHANCE)


func test_lawsuit_win_forces_praise_and_scares_authors() -> void:
	state.cases_completed = 4
	state.money = 5000.0
	state.reputation = 10.0
	var review := state.add_review(1)
	var original_author := review.author_index
	var outcome := ""
	var cost := 0.0
	sim.review_removed.connect(func(result: String) -> void: outcome = result)
	var tries := 0
	while outcome != "won" and tries < 200:
		tries += 1
		state.money = 5000.0
		state.reputation = 10.0
		outcome = ""
		review.stars = 1
		review.lawsuits = 0
		cost = Formulas.review_lawsuit_cost(state, review)
		sim.sue_for_defamation(review.id)
	assert_eq(outcome, "won")
	assert_true(review.forced)
	assert_eq(review.stars, 5)
	assert_eq(review.author_index, original_author)
	assert_eq(state.negative_review_count(), 0)
	assert_eq(state.review_fear, GameConfig.REVIEW_FEAR_SECONDS)
	assert_almost_eq(state.money - 5000.0, cost * GameConfig.REVIEW_LAWSUIT_PAYOUT_FACTOR - cost, 0.001)
	assert_almost_eq(state.reputation, 10.0 + GameConfig.REVIEW_LAWSUIT_REPUTATION, 0.001)
	assert_eq(state.review_drain(), 0.0)


func test_lawsuit_loss_removes_a_star_and_counts_the_attempt() -> void:
	var review := state.add_review(3)
	var outcome := ""
	sim.review_removed.connect(func(result: String) -> void: outcome = result)
	var tries := 0
	while outcome != "lost" and tries < 200:
		tries += 1
		state.money = 1.0e6
		state.reputation = 10.0
		outcome = ""
		review.stars = 3
		review.lawsuits = 0
		review.forced = false
		state.review_fear = 0.0
		sim.sue_for_defamation(review.id)
	assert_eq(outcome, "lost")
	assert_eq(review.stars, 2)
	assert_eq(review.lawsuits, 1)
	assert_lt(review.text_index, GameConfig.review_texts(2))
	assert_true(review.is_negative())
	assert_almost_eq(state.reputation, 10.0 - GameConfig.REVIEW_LAWSUIT_LOSS, 0.001)
	assert_eq(state.review_fear, 0.0)


func test_downgrade_stops_at_one_star() -> void:
	var review := Review.new(0, 1, 5)
	review.downgrade(99)
	assert_eq(review.stars, 1)
	assert_eq(review.lawsuits, 1)
	assert_eq(review.text_index, GameConfig.review_texts(1) - 1)
	review = Review.new(0, 4)
	review.downgrade(0)
	assert_eq(review.stars, 3)


func test_lawsuit_rejects_invalid_requests() -> void:
	var negative := state.add_review(1)
	assert_false(sim.sue_for_defamation(999))
	assert_false(sim.can_sue_for_defamation(999))
	state.money = 0.0
	assert_false(sim.sue_for_defamation(negative.id))
	negative.lawsuits = GameConfig.MAX_REVIEW_LAWSUITS
	state.money = 1.0e9
	assert_false(negative.can_be_sued())
	assert_false(sim.sue_for_defamation(negative.id))


func test_every_unforced_review_can_be_sued() -> void:
	var praise := state.add_review(4)
	assert_true(sim.can_sue_for_defamation(praise.id))
	assert_true(sim.sue_for_defamation(praise.id))


func test_forced_review_cannot_be_sued_again_but_deleted_for_free() -> void:
	var review := state.add_review(1)
	review.force_praise(0)
	state.money = 0.0
	assert_false(sim.sue_for_defamation(review.id))
	assert_true(sim.delete_review(review.id))
	assert_null(state.find_review(review.id))


func test_lawsuits_survive_saving() -> void:
	var review := Review.new(1, 2)
	review.lawsuits = 3
	assert_eq(Review.from_dict(review.to_dict()).lawsuits, 3)
	assert_eq(Review.from_dict({"stars": 2, "lawsuits": 999}).lawsuits, GameConfig.MAX_REVIEW_LAWSUITS)
	assert_eq(Review.from_dict({"stars": 2, "lawsuits": -4}).lawsuits, 0)
	assert_eq(Review.from_dict({"stars": 2}).lawsuits, 0)


func test_fear_makes_negative_reviews_rare_and_wears_off() -> void:
	var quiet := 0
	state.review_fear = GameConfig.REVIEW_FEAR_SECONDS
	for i in 400:
		sim.file_complaint()
		quiet += state.negative_review_count()
		state.reviews.clear()
	var loud := 0
	state.review_fear = 0.0
	for i in 400:
		sim.file_complaint()
		loud += state.negative_review_count()
		state.reviews.clear()
	assert_gt(loud, quiet * 2)
	state.review_fear = 5.0
	sim.tick(10.0)
	assert_eq(state.review_fear, 0.0)


func test_negative_reviews_are_capped() -> void:
	for i in 500:
		sim.file_complaint()
	assert_lte(state.negative_review_count(), GameConfig.MAX_NEGATIVE_REVIEWS)


func test_reviews_survive_saving() -> void:
	state.add_review(1)
	var praise := state.add_review(5)
	praise.force_praise(3)
	state.review_fear = 100.0
	var copy := GameState.from_dict(state.to_dict())
	assert_eq(copy.reviews.size(), 2)
	assert_eq(copy.reviews[0].stars, 1)
	assert_true(copy.reviews[1].forced)
	assert_eq(copy.reviews[1].text_index, 3)
	assert_eq(copy.review_fear, 100.0)
	assert_eq(copy.review_seq, state.review_seq)


func test_loading_sanitizes_reviews() -> void:
	var data := state.to_dict()
	data["reviews"] = [{"id": 3, "stars": 2}, {"id": 3, "stars": 5}, "junk", {"id": 8, "stars": 1}]
	data["review_seq"] = 0
	data["review_fear"] = 1.0e9
	var copy := GameState.from_dict(data)
	assert_eq(copy.reviews.size(), 2)
	assert_eq(copy.review_seq, 9)
	assert_eq(copy.review_fear, GameConfig.REVIEW_FEAR_SECONDS)
	data["reviews"] = "broken"
	assert_true(GameState.from_dict(data).reviews.is_empty())
	var many: Array = []
	for i in GameConfig.MAX_STORED_REVIEWS + 10:
		many.append({"id": i, "stars": 4})
	data["reviews"] = many
	assert_eq(GameState.from_dict(data).reviews.size(), GameConfig.MAX_STORED_REVIEWS)


func test_legacy_counter_save_becomes_negative_reviews() -> void:
	var data := state.to_dict()
	data["reviews"] = 3
	data.erase("review_seq")
	data.erase("review_fear")
	var copy := GameState.from_dict(data)
	assert_eq(copy.reviews.size(), 3)
	assert_eq(copy.negative_review_count(), 3)
	assert_eq(copy.review_seq, 3)
	assert_eq(copy.review_fear, 0.0)
	data["reviews"] = 99
	assert_eq(GameState.from_dict(data).reviews.size(), GameConfig.MAX_NEGATIVE_REVIEWS)
	data["reviews"] = 0
	assert_true(GameState.from_dict(data).reviews.is_empty())


func test_review_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["SHEET_REVIEWS", "SHEET_REVIEW_DETAIL", "ACTION_BACK", "ACTION_REVIEW_READ", "ACTION_REVIEWS_OPEN", "ACTION_REVIEWS_MORE", "REVIEW_FILTER_ALL", "REVIEWS_EMPTY", "REVIEWS_FILTER_EMPTY", "FMT_REVIEW_COUNT", "FMT_REVIEW_AGE", "FMT_REVIEW_POSITION", "FMT_REVIEW_DRAIN", "REVIEW_COSTS_TITLE", "REVIEW_TAG_CORRECTED", "REVIEW_CORRECTED_TITLE", "REVIEW_CORRECTED_TEXT", "REVIEW_FEAR_TITLE", "FMT_REVIEW_FEAR", "REVIEW_DELETE_HINT", "REVIEW_SUE_HINT", "REVIEW_OUTCOME_DELETED", "REVIEW_OUTCOME_WON", "REVIEW_OUTCOME_LOST", "FMT_REVIEW_BANNER", "FMT_RATING_CHIP", "ACTION_REVIEW_DELETE_FREE", "FMT_REVIEW_LAWSUIT_INFO"]
	for stars in range(1, 6):
		for index in GameConfig.review_texts(stars):
			keys.append("REVIEW_TEXT_%d_%d" % [stars, index + 1])
	for index in GameConfig.REVIEW_FORCED_TEXTS:
		keys.append("REVIEW_FORCED_%d" % (index + 1))
	for index in GameConfig.REVIEW_AUTHORS:
		keys.append("REVIEW_AUTHOR_%d" % (index + 1))
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)


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


func _sheet(argument: String = "") -> ReviewsSheet:
	var sheet := ReviewsSheet.new()
	sheet.setup(game, argument)
	add_child_autofree(sheet)
	return sheet


func _fill_reviews() -> void:
	state.add_review(5)
	state.add_review(4)
	state.add_review(1)
	state.add_review(3)
	state.add_review(2)


func test_sheet_shows_empty_state() -> void:
	var sheet := _sheet()
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEWS"))
	assert_true(_has_label(sheet.content, sheet.tr("REVIEWS_EMPTY")))


func test_sheet_lists_newest_first_and_filters() -> void:
	_fill_reviews()
	var sheet := _sheet()
	var list := sheet.visible_reviews()
	assert_eq(list.size(), 5)
	assert_eq(list[0].stars, 2)
	assert_eq(list[4].stars, 5)
	sheet.set_filter(1)
	assert_eq(sheet.visible_reviews().size(), 1)
	assert_eq(sheet.visible_reviews()[0].stars, 5)
	sheet.set_filter(0)
	assert_eq(sheet.visible_reviews().size(), 5)
	sheet.set_filter(99)
	assert_eq(sheet.visible_reviews().size(), 1)


func test_sheet_filter_without_matches_shows_hint() -> void:
	state.add_review(5)
	var sheet := _sheet()
	sheet.set_filter(5)
	assert_true(_has_label(sheet.content, sheet.tr("REVIEWS_FILTER_EMPTY")))


func test_sheet_pages_long_lists() -> void:
	for i in GameConfig.REVIEW_PAGE_SIZE + 3:
		state.add_review(5)
	var sheet := _sheet()
	assert_true(_has_label(sheet.content, sheet.tr("ACTION_REVIEWS_MORE") % 3))


func test_sheet_opens_detail_from_argument_and_steps_through() -> void:
	_fill_reviews()
	var newest := state.reviews[4]
	var sheet := _sheet(str(newest.id))
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEW_DETAIL"))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEW_POSITION") % [1, 5]))
	sheet.step(1)
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEW_POSITION") % [2, 5]))
	sheet.step(-1)
	sheet.step(-1)
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEW_POSITION") % [1, 5]))
	for i in 10:
		sheet.step(1)
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEW_POSITION") % [5, 5]))
	sheet.select(-1)
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEWS"))


func test_sheet_ignores_step_for_unknown_selection() -> void:
	_fill_reviews()
	var sheet := _sheet()
	sheet.step(1)
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEWS"))


func test_sheet_unknown_argument_falls_back_to_list() -> void:
	_fill_reviews()
	var sheet := _sheet("9999")
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEWS"))
	var other := _sheet("text")
	assert_eq(other.title(), other.tr("SHEET_REVIEWS"))


func test_sheet_deleting_returns_to_list_with_outcome() -> void:
	var review := state.add_review(1)
	state.add_review(5)
	var sheet := _sheet(str(review.id))
	var buttons := _buttons(sheet.content)
	var delete: Button
	for button in buttons:
		if button.text.begins_with(sheet.tr("ACTION_REVIEW_DELETE")):
			delete = button
	assert_not_null(delete)
	delete.pressed.emit()
	assert_null(state.find_review(review.id))
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEWS"))
	assert_true(_has_label(sheet.content, sheet.tr("FLOAT_REVIEW_DELETED")))


func test_sheet_suing_shows_outcome_and_corrected_note() -> void:
	var review := state.add_review(1)
	var sheet := _sheet(str(review.id))
	var tries := 0
	while review.is_negative() and tries < 100:
		tries += 1
		state.money = 1.0e9
		review.lawsuits = 0
		sheet.select(review.id)
		for button in _buttons(sheet.content):
			if button.text.begins_with(sheet.tr("ACTION_REVIEW_SUE")):
				button.pressed.emit()
				break
	assert_true(review.forced)
	assert_true(_has_label(sheet.content, sheet.tr("FLOAT_REVIEW_WON")))
	sheet.select(review.id)
	assert_true(_has_label(sheet.content, sheet.tr("REVIEW_CORRECTED_TITLE")))
	for button in _buttons(sheet.content):
		assert_false(button.text.begins_with(sheet.tr("ACTION_REVIEW_SUE")))


func test_sheet_offers_free_deletion_and_lawsuit_for_praise() -> void:
	var review := state.add_review(5)
	var sheet := _sheet(str(review.id))
	var labels: Array[String] = []
	for button in _buttons(sheet.content):
		labels.append(button.text)
	assert_true(labels.has(sheet.tr("ACTION_REVIEW_DELETE_FREE")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEW_LAWSUIT_INFO") % [UiKit.percent(GameConfig.REVIEW_LAWSUIT_CHANCE), 0]))
	assert_false(_has_label(sheet.content, sheet.tr("REVIEW_COSTS_TITLE")))
	state.money = 0.0
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("ACTION_REVIEW_DELETE_FREE"):
			button.pressed.emit()
	assert_null(state.find_review(review.id))


func test_sheet_lost_lawsuit_stays_on_detail_with_fewer_stars() -> void:
	var review := state.add_review(3)
	var sheet := _sheet(str(review.id))
	var outcome := ""
	game.simulation.review_removed.connect(func(result: String) -> void: outcome = result)
	var tries := 0
	while outcome != "lost" and tries < 200:
		tries += 1
		state.money = 1.0e9
		review.stars = 3
		review.lawsuits = 0
		review.forced = false
		outcome = ""
		sheet.select(review.id)
		for button in _buttons(sheet.content):
			if button.text.begins_with(sheet.tr("ACTION_REVIEW_SUE")):
				button.pressed.emit()
				break
	assert_eq(outcome, "lost")
	assert_eq(review.stars, 2)
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEW_DETAIL"))
	assert_true(_has_label(sheet.content, sheet.tr("FLOAT_REVIEW_LOST")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEW_LAWSUIT_INFO") % [UiKit.percent(Formulas.review_lawsuit_chance(review)), 1]))


func test_sheet_list_shows_fear_and_drain_banners() -> void:
	state.add_review(1)
	state.review_fear = 120.0
	var sheet := _sheet()
	assert_true(_has_label(sheet.content, sheet.tr("REVIEW_FEAR_TITLE")))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_REVIEWS_TITLE") % 1))


func test_sheet_disables_actions_without_money() -> void:
	var review := state.add_review(1)
	var sheet := _sheet(str(review.id))
	state.money = 0.0
	sheet.refresh()
	for button in _buttons(sheet.content):
		if button.text.begins_with(sheet.tr("ACTION_REVIEW_DELETE")) or button.text.begins_with(sheet.tr("ACTION_REVIEW_SUE")):
			assert_true(button.disabled)


func test_sheet_read_button_opens_detail() -> void:
	var review := state.add_review(4)
	var sheet := _sheet()
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("ACTION_REVIEW_READ"):
			button.pressed.emit()
	assert_eq(sheet.title(), sheet.tr("SHEET_REVIEW_DETAIL"))
	assert_eq(sheet._selected, review.id)


func test_stars_widget_has_five_icons() -> void:
	var row := UiKit.stars(3)
	autofree(row)
	assert_eq(row.get_child_count(), 5)
	assert_eq((row.get_child(0) as Label).text, Icons.STAR)
	assert_eq((row.get_child(4) as Label).text, Icons.STAR_BORDER)


func test_delete_cost_scales_with_income() -> void:
	var review := Review.new(0, 1)
	var low := Formulas.review_delete_cost(state, review)
	state.unlock_department("tax_services")
	assert_gte(Formulas.review_delete_cost(state, review), low)
	assert_almost_eq(Formulas.review_base_cost(state), maxf(GameConfig.REVIEW_DELETE_BASE, Formulas.income_per_second(state) * GameConfig.REVIEW_DELETE_INCOME_SECONDS), 0.001)
	assert_gt(Formulas.income_per_second(state), 0.0)


func test_review_text_pool_is_large_enough() -> void:
	var bad := 0
	for stars in range(1, 4):
		bad += GameConfig.review_texts(stars)
	var good := GameConfig.review_texts(4) + GameConfig.review_texts(5)
	assert_gte(bad, 100)
	assert_gte(good, 50)
	assert_eq(GameConfig.review_texts(0), GameConfig.review_texts(1))
	assert_eq(GameConfig.review_texts(9), GameConfig.review_texts(5))


func test_review_texts_are_distinct_per_language() -> void:
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		var seen := {}
		for stars in range(1, 6):
			for index in GameConfig.review_texts(stars):
				var text := TranslationServer.translate("REVIEW_TEXT_%d_%d" % [stars, index + 1])
				assert_false(seen.has(text), "%s: %s" % [locale, text])
				seen[text] = true
	TranslationServer.set_locale(original)


func test_new_reviews_pick_texts_within_their_star_pool() -> void:
	for i in 300:
		var stars := 1 + i % 5
		var review := state.add_review(stars)
		assert_between(review.text_index, 0, GameConfig.review_texts(stars) - 1)
	var high := Review.from_dict({"stars": 1, "text": 39})
	assert_eq(high.text_index, 39)
	var clamped := Review.from_dict({"stars": 4, "text": 39})
	assert_eq(clamped.text_index, GameConfig.review_texts(4) - 1)
