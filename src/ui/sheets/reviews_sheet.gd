class_name ReviewsSheet
extends Sheet

const FILTER_STARS: Array[int] = [0, 5, 4, 3, 2, 1]
const TAP_SLOP := 16.0
const PAINT_DISTANCE := 24.0

var _filter := 0
var _selected := -1
var _shown := GameConfig.REVIEW_PAGE_SIZE
var _outcome := ""
var _bulk_result := ""
var _select_mode := false
var _marked: Dictionary = {}
var _boxes: Dictionary = {}
var _cards: Dictionary = {}
var _press_id := -1
var _press_at := Vector2.ZERO
var _painting := false
var _paint_value := false
var pending_dialog: AppDialog


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


func marked_ids() -> Array:
	var result: Array = []
	for review in visible_reviews():
		if _marked.has(review.id):
			result.append(review.id)
	return result


func is_marked(review_id: int) -> bool:
	return _marked.has(review_id)


func toggle_select_mode() -> void:
	_select_mode = not _select_mode
	_marked.clear()
	_bulk_result = ""
	rebuild()


func toggle_mark(review_id: int) -> void:
	if _marked.has(review_id):
		_marked.erase(review_id)
	else:
		_marked[review_id] = true
	rebuild()


func is_painting() -> bool:
	return _painting


func press_card(review_id: int, position: Vector2) -> void:
	_press_id = review_id
	_press_at = position
	_painting = false


func drag_card(position: Vector2) -> bool:
	if _press_id < 0:
		return false
	if not _painting:
		var moved := position - _press_at
		if absf(moved.x) < PAINT_DISTANCE or absf(moved.x) < absf(moved.y):
			return false
		_painting = true
		_paint_value = not _marked.has(_press_id)
		paint_review(_press_id)
	for review_id: int in _cards:
		if (_cards[review_id] as Control).get_global_rect().has_point(position):
			paint_review(review_id)
	return true


func paint_review(review_id: int) -> void:
	if _paint_value:
		_marked[review_id] = true
	else:
		_marked.erase(review_id)
	if _boxes.has(review_id):
		(_boxes[review_id] as CheckBox).set_pressed_no_signal(_paint_value)


func release_card(position: Vector2) -> void:
	if _press_id < 0:
		return
	var review_id := _press_id
	var was_painting := _painting
	_press_id = -1
	_painting = false
	if was_painting:
		rebuild()
	elif position.distance_to(_press_at) < TAP_SLOP:
		toggle_mark(review_id)


func _on_card_input(event: InputEvent, card: Control, review_id: int) -> void:
	var to_global := card.get_global_transform()
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			press_card(review_id, button.global_position)
		else:
			release_card(button.global_position)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			press_card(review_id, to_global * touch.position)
		else:
			release_card(to_global * touch.position)
	elif event is InputEventMouseMotion:
		if drag_card((event as InputEventMouseMotion).global_position):
			card.accept_event()
	elif event is InputEventScreenDrag:
		if drag_card(to_global * (event as InputEventScreenDrag).position):
			card.accept_event()


func request_delete_marked() -> void:
	var ids := marked_ids()
	if ids.is_empty():
		return
	var cost := Formulas.bulk_delete_cost(game.state, ids)
	_confirm(tr("FMT_REVIEWS_CONFIRM_DELETE_TITLE") % ids.size(), tr("FMT_REVIEW_CONFIRM_COST") % UiKit.money(cost), tr("ACTION_REVIEW_CONFIRM_DELETE"), "primary", delete_marked)


func request_sue_marked() -> void:
	var ids := suable_marked_ids()
	if ids.is_empty():
		return
	var cost := Formulas.bulk_lawsuit_cost(game.state, ids)
	_confirm(tr("FMT_REVIEWS_CONFIRM_SUE_TITLE") % ids.size(), tr("FMT_REVIEW_CONFIRM_SUE_TEXT") % UiKit.money(cost), tr("ACTION_REVIEW_CONFIRM_SUE"), "error", sue_marked)


func request_delete(review_id: int) -> void:
	var review := game.state.find_review(review_id)
	if review == null:
		return
	var cost := Formulas.review_delete_cost(game.state, review)
	_confirm(tr("REVIEW_CONFIRM_DELETE_TITLE"), tr("FMT_REVIEW_CONFIRM_COST") % UiKit.money(cost), tr("ACTION_REVIEW_CONFIRM_DELETE"), "primary", act.bind(game.simulation.delete_review.bind(review_id)))


func request_sue(review_id: int) -> void:
	var review := game.state.find_review(review_id)
	if review == null:
		return
	var cost := Formulas.review_lawsuit_cost(game.state, review)
	_confirm(tr("REVIEW_CONFIRM_SUE_TITLE"), tr("FMT_REVIEW_CONFIRM_SUE_TEXT") % UiKit.money(cost), tr("ACTION_REVIEW_CONFIRM_SUE"), "error", act.bind(game.simulation.sue_for_defamation.bind(review_id)))


func _confirm(title_text: String, body: String, confirm_label: String, role: String, action: Callable) -> void:
	var dialog := AppDialog.new().configure(Icons.WARNING, title_text, body, confirm_label, tr("ACTION_CANCEL"), role)
	dialog.confirmed.connect(action)
	pending_dialog = dialog
	get_parent().add_child(dialog)


func mark_all_visible() -> void:
	for review in visible_reviews():
		_marked[review.id] = true
	rebuild()


func clear_marks() -> void:
	_marked.clear()
	rebuild()


func suable_marked_ids() -> Array:
	var result: Array = []
	for review_id in marked_ids():
		if game.state.find_review(review_id).can_be_sued():
			result.append(review_id)
	return result


func delete_marked() -> void:
	var ids := marked_ids()
	act(func() -> bool:
		var deleted := game.simulation.delete_reviews(ids)
		_outcome = ""
		_bulk_result = tr("FMT_REVIEWS_BULK_DELETED") % deleted
		_marked.clear()
		return deleted > 0
	)


func sue_marked() -> void:
	var ids := suable_marked_ids()
	act(func() -> bool:
		var result := game.simulation.sue_reviews(ids)
		_outcome = ""
		_bulk_result = tr("FMT_REVIEWS_BULK_SUED") % [result.x, result.y]
		_marked.clear()
		return result.x + result.y > 0
	)


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
	_boxes.clear()
	_cards.clear()
	var state := game.state
	var banner := _outcome_banner()
	if banner != null:
		container.add_child(banner)
	if not _bulk_result.is_empty():
		container.add_child(UiKit.banner(Icons.CHECK, tr("REVIEWS_BULK_TITLE"), _bulk_result, "success"))
	container.add_child(_summary_card(state))
	container.add_child(_arrival_banner(state))
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
	container.add_child(_select_toggle())
	if _select_mode:
		container.add_child(_bulk_bar())
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


func _select_toggle() -> Control:
	var toggle := UiKit.button(tr("ACTION_REVIEWS_SELECT_DONE") if _select_mode else tr("ACTION_REVIEWS_SELECT"), "primary", "Outlined")
	toggle.pressed.connect(toggle_select_mode)
	return toggle


func _bulk_bar() -> Control:
	var state := game.state
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var ids := marked_ids()
	column.add_child(UiKit.label(tr("FMT_REVIEWS_SELECTED") % ids.size(), "TitleSmall"))
	var pick := UiKit.hbox(AppTheme.SPACING_SM)
	var all := UiKit.button(tr("ACTION_REVIEWS_SELECT_ALL"), "neutral", "Text")
	all.pressed.connect(mark_all_visible)
	pick.add_child(all)
	var none := UiKit.button(tr("ACTION_REVIEWS_SELECT_NONE"), "neutral", "Text")
	none.pressed.connect(clear_marks)
	pick.add_child(none)
	column.add_child(pick)
	var delete_cost := Formulas.bulk_delete_cost(state, ids)
	var delete := UiKit.button(tr("FMT_ACTION_COST") % [tr("FMT_REVIEWS_BULK_DELETE") % ids.size(), UiKit.money(delete_cost)], "primary")
	delete.disabled = ids.is_empty() or not state.can_afford(delete_cost)
	delete.pressed.connect(request_delete_marked)
	column.add_child(delete)
	var suable := suable_marked_ids()
	var sue_cost := Formulas.bulk_lawsuit_cost(state, suable)
	var sue := UiKit.button(tr("FMT_ACTION_COST") % [tr("FMT_REVIEWS_BULK_SUE") % suable.size(), UiKit.money(sue_cost)], "error")
	sue.disabled = suable.is_empty() or not state.can_afford(sue_cost)
	sue.pressed.connect(request_sue_marked)
	column.add_child(sue)
	return column


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


func _arrival_banner(state: GameState) -> Control:
	var factor := Formulas.review_arrival_factor(state)
	var role := "success" if factor > 1.0 else ("primary" if is_equal_approx(factor, 1.0) else ("warning" if factor >= 0.65 else "error"))
	var title := tr("REVIEW_ARRIVAL_NEUTRAL") if is_equal_approx(factor, 1.0) else tr("FMT_REVIEW_ARRIVAL_TITLE") % _signed_percent(factor - 1.0)
	return UiKit.banner(Icons.REVIEWS, title, tr("REVIEW_ARRIVAL_INFO"), role)


func _signed_percent(value: float) -> String:
	var rounded := roundi(value * 100.0)
	return ("+" if rounded > 0 else ("−" if rounded < 0 else "±")) + UiKit.percent(absf(value))


func _review_card(review: Review) -> Control:
	var card := UiKit.card("CardOutlined")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_SM)
	if _select_mode:
		var box := CheckBox.new()
		box.button_pressed = _marked.has(review.id)
		box.focus_mode = Control.FOCUS_NONE
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boxes[review.id] = box
		_cards[review.id] = card
		card.gui_input.connect(_on_card_input.bind(card, review.id))
		head.add_child(box)
	head.add_child(UiKit.stars(review.stars))
	head.add_child(UiKit.spacer())
	head.add_child(_tag(review))
	column.add_child(head)
	column.add_child(UiKit.label(tr(review.author_key()), "TitleSmall", true))
	var text := UiKit.label(tr(review.text_key()), "BodySmall", true)
	text.max_lines_visible = 2
	text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(text)
	if not _select_mode:
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
	delete.pressed.connect(request_delete.bind(review.id))
	container.add_child(delete)
	container.add_child(UiKit.label(tr("REVIEW_DELETE_HINT"), "BodySmall", true))
	var sue: Button = null
	if review.can_be_sued():
		sue = UiKit.button(UiKit.cost_text("ACTION_REVIEW_SUE", Formulas.review_lawsuit_cost(game.state, review)), "error")
		sue.pressed.connect(request_sue.bind(review.id))
		container.add_child(sue)
		container.add_child(UiKit.label(tr("FMT_REVIEW_LAWSUIT_INFO") % [UiKit.percent(Formulas.review_lawsuit_chance(review)), review.lawsuits_left()], "TitleSmall", true))
		container.add_child(UiKit.label(tr("REVIEW_SUE_HINT"), "BodySmall", true))
	if review.can_win_by_ad():
		var ad := UiKit.button(tr("ACTION_REVIEW_SUE_AD"), "primary", "Outlined")
		ad.pressed.connect(func() -> void: watch_ad(game.boosts.sue_by_ad.bind(review.id)))
		container.add_child(ad)
		container.add_child(UiKit.label(tr("REVIEW_SUE_AD_HINT"), "BodySmall", true))
	track(func() -> void:
		delete.disabled = not game.simulation.can_delete_review(review.id)
		if sue != null:
			sue.disabled = not game.simulation.can_sue_for_defamation(review.id)
	)
