class_name ReviewsSheet
extends Sheet

const FILTER_STARS: Array[int] = [0, 5, 4, 3, 2, 1]

var _filter := 0
var _selected := -1
var _shown := GameConfig.REVIEW_PAGE_SIZE
var _outcome := ""


func setup(p_game: Game, p_argument: String = "") -> Sheet:
	super.setup(p_game, p_argument)
	if p_argument.is_valid_int():
		_selected = p_argument.to_int()
	return self


func _ready() -> void:
	super._ready()
	game.simulation.review_removed.connect(_on_review_removed)


func _exit_tree() -> void:
	if game != null and game.simulation.review_removed.is_connected(_on_review_removed):
		game.simulation.review_removed.disconnect(_on_review_removed)


func title() -> String:
	return tr("SHEET_REVIEW_DETAIL") if _selected_review() != null else tr("SHEET_REVIEWS")


func build(container: VBoxContainer) -> void:
	var review := _selected_review()
	if review == null:
		_selected = -1
		_build_list(container)
	else:
		_build_detail(container, review)


func visible_reviews() -> Array[Review]:
	var result: Array[Review] = []
	for index in range(game.state.reviews.size() - 1, -1, -1):
		var review := game.state.reviews[index]
		if _filter == 0 or review.stars == _filter:
			result.append(review)
	return result


func select(review_id: int) -> void:
	_selected = review_id
	_outcome = ""
	rebuild()


func set_filter(index: int) -> void:
	_filter = FILTER_STARS[clampi(index, 0, FILTER_STARS.size() - 1)]
	_shown = GameConfig.REVIEW_PAGE_SIZE
	rebuild()


func step(direction: int) -> void:
	var list := visible_reviews()
	var at_index := _position_in(list, _selected)
	if at_index < 0:
		return
	select(list[clampi(at_index + direction, 0, list.size() - 1)].id)


func _selected_review() -> Review:
	return game.state.find_review(_selected) if _selected >= 0 else null


func _position_in(list: Array[Review], review_id: int) -> int:
	for index in list.size():
		if list[index].id == review_id:
			return index
	return -1


func _on_review_removed(outcome: String) -> void:
	_outcome = outcome


func _outcome_banner() -> Control:
	if _outcome.is_empty():
		return null
	var role := "error" if _outcome == "lost" else "success"
	var icon_code := Icons.WARNING if _outcome == "lost" else Icons.CHECK
	return UiKit.banner(icon_code, tr("FLOAT_REVIEW_" + _outcome.to_upper()), tr("REVIEW_OUTCOME_" + _outcome.to_upper()), role)


func _build_list(container: VBoxContainer) -> void:
	var state := game.state
	var banner := _outcome_banner()
	if banner != null:
		container.add_child(banner)
	container.add_child(_summary_card(state))
	if state.review_fear > 0.0:
		container.add_child(UiKit.banner(Icons.GAVEL, tr("REVIEW_FEAR_TITLE"), tr("FMT_REVIEW_FEAR") % UiKit.duration(state.review_fear), "success"))
	var drain := state.review_drain() * GameConfig.REVIEW_DRAIN * 60.0
	if drain > 0.0:
		container.add_child(UiKit.banner(Icons.WARNING, tr("FMT_REVIEWS_TITLE") % state.negative_review_count(), tr("FMT_REVIEW_DRAIN") % UiKit.decimal(drain, 2), "error"))
	if state.reviews.is_empty():
		container.add_child(UiKit.label(tr("REVIEWS_EMPTY"), "BodyMedium", true))
		return
	var options: Array[String] = []
	for stars in FILTER_STARS:
		options.append(tr("REVIEW_FILTER_ALL") if stars == 0 else str(stars))
	container.add_child(UiKit.segmented(options, FILTER_STARS.find(_filter), set_filter))
	var list := visible_reviews()
	if list.is_empty():
		container.add_child(UiKit.label(tr("REVIEWS_FILTER_EMPTY"), "BodyMedium", true))
		return
	for index in mini(list.size(), _shown):
		container.add_child(_review_card(list[index]))
	if list.size() > _shown:
		var more := UiKit.button(tr("ACTION_REVIEWS_MORE") % (list.size() - _shown), "neutral", "Text")
		more.pressed.connect(func() -> void:
			_shown += GameConfig.REVIEW_PAGE_SIZE
			rebuild()
		)
		container.add_child(more)


func _summary_card(state: GameState) -> Control:
	var card := UiKit.card("CardPrimary")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_LG)
	var average := UiKit.label(UiKit.decimal(state.average_rating()) if not state.reviews.is_empty() else "–", "DisplaySmall")
	head.add_child(average)
	var details := UiKit.vbox(2)
	details.add_child(UiKit.stars(roundi(state.average_rating()), AppTheme.SIZE_ICON))
	details.add_child(UiKit.label(tr("FMT_REVIEW_COUNT") % state.reviews.size(), "BodySmall"))
	head.add_child(details)
	column.add_child(head)
	var counts := state.star_counts()
	var total := maxi(1, state.reviews.size())
	for stars in range(5, 0, -1):
		var row := UiKit.hbox(AppTheme.SPACING_SM)
		var star_label := UiKit.label(str(stars), "TitleSmall")
		star_label.custom_minimum_size.x = 16
		row.add_child(star_label)
		row.add_child(UiKit.icon(Icons.STAR, AppTheme.accent("warning"), AppTheme.SIZE_ICON_SMALL))
		var role := "success" if stars >= 4 else ("neutral" if stars == 3 else "error")
		row.add_child(UiKit.progress(float(counts[stars - 1]) / float(total), role))
		var count := UiKit.label(str(counts[stars - 1]), "BodySmall")
		count.custom_minimum_size.x = 32
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count)
		column.add_child(row)
	card.add_child(column)
	return card


func _review_card(review: Review) -> Control:
	var card := UiKit.card("CardOutlined")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_SM)
	head.add_child(UiKit.stars(review.stars))
	head.add_child(UiKit.spacer())
	head.add_child(_tag(review))
	column.add_child(head)
	column.add_child(UiKit.label(tr(review.author_key()), "TitleSmall", true))
	var text := UiKit.label(tr(review.text_key()), "BodySmall", true)
	text.max_lines_visible = 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(text)
	var read := UiKit.button(tr("ACTION_REVIEW_READ"), "neutral", "Text")
	read.pressed.connect(select.bind(review.id))
	column.add_child(read)
	card.add_child(column)
	return card


func _tag(review: Review) -> Control:
	var age := UiKit.duration(maxf(0.0, game.state.play_time - review.posted_at))
	if review.forced:
		return UiKit.pill(tr("REVIEW_TAG_CORRECTED"), "warning")
	if review.is_negative():
		return UiKit.pill(tr("FMT_REVIEW_AGE") % age, "error")
	return UiKit.pill(tr("FMT_REVIEW_AGE") % age, "neutral")


func _build_detail(container: VBoxContainer, review: Review) -> void:
	var list := visible_reviews()
	var at_index := _position_in(list, review.id)
	var bar := UiKit.hbox(AppTheme.SPACING_SM)
	var back := UiKit.icon_button(Icons.ARROW_BACK)
	back.tooltip_text = tr("ACTION_BACK")
	back.pressed.connect(func() -> void: select(-1))
	bar.add_child(back)
	bar.add_child(UiKit.label(tr("FMT_REVIEW_POSITION") % [maxi(at_index, 0) + 1, list.size()], "TitleSmall"))
	bar.add_child(UiKit.spacer())
	var previous := UiKit.icon_button(Icons.CHEVRON_LEFT)
	previous.disabled = at_index <= 0
	previous.pressed.connect(step.bind(-1))
	bar.add_child(previous)
	var next := UiKit.icon_button(Icons.CHEVRON)
	next.disabled = at_index < 0 or at_index >= list.size() - 1
	next.pressed.connect(step.bind(1))
	bar.add_child(next)
	container.add_child(bar)
	var banner := _outcome_banner()
	if banner != null:
		container.add_child(banner)
	var card := UiKit.card("CardOutlined")
	var column := UiKit.vbox(AppTheme.SPACING_MD)
	var head := UiKit.hbox(AppTheme.SPACING_SM)
	head.add_child(UiKit.stars(review.stars, AppTheme.SIZE_TITLE_LARGE))
	head.add_child(UiKit.spacer())
	head.add_child(_tag(review))
	column.add_child(head)
	column.add_child(UiKit.label(tr(review.author_key()), "TitleMedium", true))
	column.add_child(UiKit.label(tr(review.text_key()), "BodyMedium", true))
	column.add_child(UiKit.label(tr("FMT_REVIEW_EXPIRES") % UiKit.duration(game.state.review_time_left(review)), "BodySmall", true))
	card.add_child(column)
	container.add_child(card)
	if review.forced:
		container.add_child(UiKit.banner(Icons.GAVEL, tr("REVIEW_CORRECTED_TITLE"), tr("REVIEW_CORRECTED_TEXT"), "warning"))
	if review.is_negative():
		var drain := review.drain_weight() * GameConfig.REVIEW_DRAIN * 60.0
		container.add_child(UiKit.banner(Icons.WARNING, tr("REVIEW_COSTS_TITLE"), tr("FMT_REVIEW_DRAIN") % UiKit.decimal(drain, 2), "error"))
	_build_actions(container, review)


func _build_actions(container: VBoxContainer, review: Review) -> void:
	var delete_cost := Formulas.review_delete_cost(game.state, review)
	var delete_text := tr("ACTION_REVIEW_DELETE_FREE") if delete_cost <= 0.0 else UiKit.cost_text("ACTION_REVIEW_DELETE", delete_cost)
	var delete := UiKit.button(delete_text, "primary")
	delete.pressed.connect(func() -> void: act(game.simulation.delete_review.bind(review.id)))
	container.add_child(delete)
	container.add_child(UiKit.label(tr("REVIEW_DELETE_HINT"), "BodySmall", true))
	var sue: Button = null
	if review.can_be_sued():
		sue = UiKit.button(UiKit.cost_text("ACTION_REVIEW_SUE", Formulas.review_lawsuit_cost(game.state, review)), "error")
		sue.pressed.connect(func() -> void: act(game.simulation.sue_for_defamation.bind(review.id)))
		container.add_child(sue)
		container.add_child(UiKit.label(tr("FMT_REVIEW_LAWSUIT_INFO") % [UiKit.percent(Formulas.review_lawsuit_chance(review)), review.lawsuits_left()], "TitleSmall", true))
		container.add_child(UiKit.label(tr("REVIEW_SUE_HINT"), "BodySmall", true))
	elif review.needs_ad_lawsuit():
		var ad := UiKit.button(tr("ACTION_REVIEW_SUE_AD"), "primary", "Outlined")
		ad.pressed.connect(func() -> void: watch_ad(game.boosts.sue_by_ad.bind(review.id)))
		container.add_child(ad)
		container.add_child(UiKit.label(tr("REVIEW_SUE_AD_HINT"), "BodySmall", true))
	track(func() -> void:
		delete.disabled = not game.simulation.can_delete_review(review.id)
		if sue != null:
			sue.disabled = not game.simulation.can_sue_for_defamation(review.id)
	)
