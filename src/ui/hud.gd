class_name Hud
extends Control

signal open_sheet(sheet_id: String, argument: String)
signal focus_department(dept_id: String)

const NAV_ITEMS := [
	{"id": "upgrades", "icon": Icons.UPGRADE, "label": "NAV_UPGRADES"},
	{"id": "statistics", "icon": Icons.STATS, "label": "NAV_STATISTICS"},
	{"id": "goals", "icon": Icons.FLAG, "label": "NAV_GOALS"},
]

var game: Game
var top_bar: PanelContainer
var bottom_bar: PanelContainer
var _money_label: Label
var _reputation_label: Label
var _income_label: Label
var _goal_label: Label
var _goal_bar: ProgressBar
var _goal_reward: Label
var _goal_claim: Button
var _goal_card: PanelContainer
var _event_banner: PanelContainer
var _event_title: Label
var _event_text: Label
var _event_actions: HBoxContainer
var _event_actions_key := ""
var _ruckus_banner: PanelContainer
var _review_banner: PanelContainer
var _review_title: Label
var _review_text: Label
var _review_open: Button
var _bonus_card: PanelContainer
var _bonus_title: Label
var _bonus_text: Label
var _bonus_buttons: Array[Button] = []
var _bonus_target: Array = []
var _desk_card: PanelContainer
var _letter_box: VBoxContainer
var _letter_text: Label
var _gift_box: VBoxContainer
var _gift_text: Label
var _rating_label: Label
var _rating_chip: Control
var _safe_top := 0.0
var task_panel: TaskPanel
var _nav_buttons := {}
var _settings_button: Button
var _seal_label: Label
var _boost_button: Button
var _boost_role := ""
var _goal_double: Button
var _sick_ad: Button
var _highlighted: Control
var _highlight_tween: Tween
var _money_chip: Control
var _money_roll := RollingNumber.new()
var _money_pop: Tween
var _claim_glow: Tween


func setup(p_game: Game, safe_top: float) -> Hud:
	game = p_game
	_safe_top = safe_top
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_bottom()
	task_panel = TaskPanel.new().setup(game)
	task_panel.focus_department.connect(func(dept_id: String) -> void: focus_department.emit(dept_id))
	task_panel.open_department.connect(func(dept_id: String) -> void: open_sheet.emit("spot", WorldLayout.DEPT_PREFIX + dept_id))
	add_child(task_panel)
	refresh()


func _build_top() -> void:
	top_bar = UiKit.card("Bar")
	var style := AppTheme.box(AppTheme.SURFACE, 0, Color.TRANSPARENT, AppTheme.SPACING_MD)
	style.content_margin_top = AppTheme.SPACING_MD + _safe_top
	style.corner_radius_bottom_left = AppTheme.RADIUS_CARD
	style.corner_radius_bottom_right = AppTheme.RADIUS_CARD
	style.shadow_color = Color(AppTheme.ON_SURFACE, 0.08)
	style.shadow_size = 3
	top_bar.add_theme_stylebox_override(&"panel", style)
	add_child(top_bar)
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	top_bar.add_child(column)
	var row := UiKit.hbox(AppTheme.SPACING_SM)
	_money_label = _resource_chip(row, Icons.PAID, AppTheme.MONEY)
	_money_chip = _money_label.get_parent().get_parent()
	_reputation_label = _resource_chip(row, Icons.STAR, AppTheme.accent("warning"))
	_rating_label = _resource_chip(row, Icons.REVIEWS, AppTheme.accent("primary"))
	_rating_chip = _rating_label.get_parent().get_parent()
	_rating_chip.tooltip_text = tr("FMT_RATING_CHIP")
	_rating_chip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			open_sheet.emit("reviews", "")
	)
	_income_label = UiKit.label("", "BodySmall")
	row.add_child(_income_label)
	row.add_child(UiKit.spacer())
	_seal_label = _resource_chip(row, Icons.SEAL, AppTheme.accent("tertiary"))
	_boost_button = UiKit.icon_button(Icons.BOLT, "primary", "IconTonal")
	_boost_button.tooltip_text = tr("SHEET_BOOSTS")
	_boost_button.pressed.connect(func() -> void: open_sheet.emit("boosts", ""))
	row.add_child(_boost_button)
	_settings_button = UiKit.icon_button(Icons.SETTINGS)
	_settings_button.pressed.connect(func() -> void: open_sheet.emit("settings", ""))
	row.add_child(_settings_button)
	column.add_child(row)
	_goal_card = UiKit.card("CardRow")
	var goal_row := UiKit.hbox(AppTheme.SPACING_MD)
	goal_row.add_child(UiKit.icon(Icons.FLAG, AppTheme.accent("primary")))
	var goal_column := UiKit.vbox(AppTheme.SPACING_XS)
	_goal_label = UiKit.label("", "TitleSmall", true)
	goal_column.add_child(_goal_label)
	_goal_bar = UiKit.progress()
	goal_column.add_child(_goal_bar)
	_goal_reward = UiKit.label("", "BodySmall", true)
	_goal_reward.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	_goal_reward.visible = false
	goal_column.add_child(_goal_reward)
	goal_row.add_child(goal_column)
	_goal_claim = UiKit.button(tr("ACTION_CLAIM"))
	_goal_claim.pressed.connect(func() -> void: game.perform(game.goals.claim))
	goal_row.add_child(_goal_claim)
	_goal_double = UiKit.button(tr("ACTION_CLAIM_DOUBLE"), "primary", "Outlined")
	_goal_double.pressed.connect(func() -> void: watch_ad(game.goals.claim_doubled))
	goal_row.add_child(_goal_double)
	_goal_card.add_child(goal_row)
	_goal_card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			open_sheet.emit("goals", "")
	)
	column.add_child(_goal_card)
	_event_banner = UiKit.card("BannerWarning")
	var event_row := UiKit.hbox(AppTheme.SPACING_MD)
	event_row.add_child(UiKit.icon(Icons.BOLT, AppTheme.accent("warning")))
	var event_column := UiKit.vbox(0)
	_event_title = UiKit.label("", "TitleSmall", true)
	_event_title.add_theme_color_override(&"font_color", AppTheme.accent("warning"))
	event_column.add_child(_event_title)
	_event_text = UiKit.label("", "BodySmall", true)
	_event_text.add_theme_color_override(&"font_color", AppTheme.on_container("warning"))
	event_column.add_child(_event_text)
	_event_actions = UiKit.hbox(AppTheme.SPACING_SM)
	event_column.add_child(_event_actions)
	event_row.add_child(event_column)
	_event_banner.add_child(event_row)
	column.add_child(_event_banner)
	_build_ruckus_banner(column)
	_review_banner = UiKit.card("BannerError")
	var review_column := UiKit.vbox(AppTheme.SPACING_XS)
	_review_title = UiKit.label("", "TitleSmall", true)
	_review_title.add_theme_color_override(&"font_color", AppTheme.accent("error"))
	review_column.add_child(_review_title)
	_review_text = UiKit.label("", "BodySmall", true)
	_review_text.add_theme_color_override(&"font_color", AppTheme.on_container("error"))
	review_column.add_child(_review_text)
	_review_open = UiKit.button(tr("ACTION_REVIEWS_OPEN"), "error")
	_review_open.pressed.connect(func() -> void: open_sheet.emit("reviews", ""))
	review_column.add_child(_review_open)
	_review_banner.add_child(review_column)
	column.add_child(_review_banner)
	_build_bonus_card(column)
	_build_desk_card(column)


func _build_desk_card(column: VBoxContainer) -> void:
	_desk_card = UiKit.card("BannerPrimary")
	var desk_column := UiKit.vbox(AppTheme.SPACING_MD)
	var letter := _desk_offer(tr("DESK_LETTER_TITLE"), func() -> void: game.perform(game.goals.claim), func() -> void: watch_ad(game.goals.claim_doubled))
	_letter_box = letter[0]
	_letter_text = letter[1]
	desk_column.add_child(_letter_box)
	var gift := _desk_offer(tr("DESK_GIFT_TITLE"), func() -> void: game.perform(game.simulation.claim_gift), func() -> void: watch_ad(game.simulation.claim_gift_doubled))
	_gift_box = gift[0]
	_gift_text = gift[1]
	desk_column.add_child(_gift_box)
	_desk_card.add_child(desk_column)
	_desk_card.visible = false
	column.add_child(_desk_card)


func _desk_offer(title_text: String, take: Callable, double: Callable) -> Array:
	var box := UiKit.vbox(AppTheme.SPACING_XS)
	var title := UiKit.label(title_text, "TitleSmall", true)
	title.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	box.add_child(title)
	var text := UiKit.label("", "BodySmall", true)
	text.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	box.add_child(text)
	var row := UiKit.hbox(AppTheme.SPACING_SM)
	var take_button := UiKit.button(tr("ACTION_CLAIM"))
	take_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	take_button.pressed.connect(take)
	row.add_child(take_button)
	var double_button := UiKit.button(tr("ACTION_CLAIM_DOUBLE"), "primary", "Outlined")
	double_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	double_button.pressed.connect(double)
	row.add_child(double_button)
	box.add_child(row)
	return [box, text]


func _refresh_desk_card(state: GameState) -> void:
	var at_desk := game.simulation.at_office_desk()
	var letter := at_desk and game.goals.is_complete()
	var gift := at_desk and state.gift_kind >= 0
	_desk_card.visible = letter or gift
	_letter_box.visible = letter
	_gift_box.visible = gift
	if letter:
		_letter_text.text = GoalText.claim_reward(game.goals.current())
	if gift:
		_gift_text.text = tr("FMT_DESK_GIFT") % [Flavor.gift(state.gift_kind), UiKit.money(state.gift_money)]


func _build_ruckus_banner(column: VBoxContainer) -> void:
	_ruckus_banner = UiKit.card("BannerError")
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon(Icons.ALARM, AppTheme.accent("error")))
	var text_column := UiKit.vbox(AppTheme.SPACING_XS)
	var title := UiKit.label(tr("RUCKUS_ALERT_TITLE"), "TitleSmall", true)
	title.add_theme_color_override(&"font_color", AppTheme.accent("error"))
	text_column.add_child(title)
	var text := UiKit.label(tr("RUCKUS_ALERT_TEXT"), "BodySmall", true)
	text.add_theme_color_override(&"font_color", AppTheme.on_container("error"))
	text_column.add_child(text)
	row.add_child(text_column)
	_ruckus_banner.add_child(row)
	_ruckus_banner.visible = false
	column.add_child(_ruckus_banner)


func _build_bonus_card(column: VBoxContainer) -> void:
	_bonus_card = UiKit.card("BannerPrimary")
	var bonus_column := UiKit.vbox(AppTheme.SPACING_XS)
	_bonus_title = UiKit.label("", "TitleSmall", true)
	_bonus_title.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	bonus_column.add_child(_bonus_title)
	_bonus_text = UiKit.label("", "BodySmall", true)
	_bonus_text.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	bonus_column.add_child(_bonus_text)
	var bonus_row := UiKit.hbox(AppTheme.SPACING_SM)
	for tier in range(1, GameConfig.sick_bonus_tiers() + 1):
		var button := UiKit.button("")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(leave_bonus.bind(tier))
		bonus_row.add_child(button)
		_bonus_buttons.append(button)
	bonus_column.add_child(bonus_row)
	_sick_ad = UiKit.button("", "primary", "Outlined")
	_sick_ad.pressed.connect(func() -> void:
		if not _bonus_target.is_empty():
			watch_ad(game.boosts.cure_by_ad.bind(str(_bonus_target[0]), int(_bonus_target[1])))
	)
	bonus_column.add_child(_sick_ad)
	_bonus_card.add_child(bonus_column)
	_bonus_card.visible = false
	column.add_child(_bonus_card)


func leave_bonus(tier: int) -> bool:
	if _bonus_target.is_empty():
		return false
	return game.perform(game.simulation.leave_bonus.bind(str(_bonus_target[0]), int(_bonus_target[1]), tier))


func _refresh_bonus_card(state: GameState) -> void:
	_bonus_target = game.simulation.sick_desk_near(state.player.position)
	_bonus_card.visible = not _bonus_target.is_empty()
	if not _bonus_card.visible:
		return
	var key := str(_bonus_target[0])
	var desk := int(_bonus_target[1])
	var mood := state.station(key).moods[desk]
	_bonus_title.text = tr("FMT_SICK_BONUS_TITLE") % NumberFormat.clock(Formulas.sick_time_left(state, mood))
	_bonus_text.text = tr("SICK_BONUS_TEXT")
	for index in _bonus_buttons.size():
		var tier := index + 1
		var button := _bonus_buttons[index]
		button.text = tr("FMT_SICK_BONUS_BUTTON") % [tr("SICK_BONUS_TIER_%d" % tier), UiKit.money(Formulas.sick_bonus_price(state, mood, tier)), NumberFormat.clock(Formulas.sick_time_left_with(state, mood, tier))]
		button.disabled = not game.simulation.can_leave_bonus(key, desk, tier)
	var cooldown := state.boost_cooldown(Boosts.SICK_NOTE)
	_sick_ad.text = tr("FMT_AD_COOLDOWN") % UiKit.duration(cooldown) if cooldown > 0.0 else tr("ACTION_SICK_NOTE_AD")
	_sick_ad.disabled = not game.boosts.can_cure_by_ad(key, desk)


func watch_ad(action: Callable) -> AdPlaceholder:
	return AdPlaceholder.play(get_parent(), game.perform.bind(action))


func _refresh_boost_button(state: GameState) -> void:
	_seal_label.text = str(state.seals)
	var role := "warning" if _any_swamped(state) else "primary"
	if role != _boost_role:
		_boost_role = role
		_boost_button.theme_type_variation = role.capitalize() + "IconTonal"


func _any_swamped(state: GameState) -> bool:
	var lobby := state.lobby_capacity()
	for key in state.ordered_station_keys():
		if state.station(key).is_swamped(lobby):
			return true
	return false


func _resource_chip(parent: HBoxContainer, icon_code: String, color: Color) -> Label:
	var chip := PanelContainer.new()
	var style := AppTheme.box(AppTheme.SURFACE_VARIANT, AppTheme.RADIUS_PILL)
	style.content_margin_left = AppTheme.SPACING_SM
	style.content_margin_right = AppTheme.SPACING_MD
	style.content_margin_top = AppTheme.SPACING_XS
	style.content_margin_bottom = AppTheme.SPACING_XS
	chip.add_theme_stylebox_override(&"panel", style)
	var row := UiKit.hbox(AppTheme.SPACING_XS)
	row.add_child(UiKit.icon(icon_code, color, AppTheme.SIZE_ICON_SMALL + 2))
	var value := UiKit.label("", "TitleMedium")
	row.add_child(value)
	chip.add_child(row)
	parent.add_child(chip)
	return value


func _build_bottom() -> void:
	bottom_bar = UiKit.card("Bar")
	var style := AppTheme.box(AppTheme.SURFACE, 0, Color.TRANSPARENT, AppTheme.SPACING_SM)
	style.corner_radius_top_left = AppTheme.RADIUS_CARD
	style.corner_radius_top_right = AppTheme.RADIUS_CARD
	style.content_margin_bottom = AppTheme.SPACING_LG
	style.shadow_color = Color(AppTheme.ON_SURFACE, 0.08)
	style.shadow_size = 3
	bottom_bar.add_theme_stylebox_override(&"panel", style)
	add_child(bottom_bar)
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var row := UiKit.hbox(AppTheme.SPACING_XS)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.add_child(row)
	for item: Dictionary in NAV_ITEMS:
		var nav_button := _nav_button(item)
		_nav_buttons[item.id] = nav_button
		row.add_child(nav_button)


func _nav_button(item: Dictionary) -> Button:
	var button := Button.new()
	button.theme_type_variation = "NavItem"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 64)
	var column := UiKit.vbox(0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(UiKit.icon(item.icon, AppTheme.accent("primary")))
	var text := UiKit.label(tr(item.label), "LabelSmall")
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	button.add_child(column)
	button.pressed.connect(func() -> void: open_sheet.emit(item.id, ""))
	return button


func highlight(target: String) -> void:
	if _highlight_tween != null:
		_highlight_tween.kill()
		_highlight_tween = null
	if is_instance_valid(_highlighted):
		_highlighted.modulate = Color.WHITE
	_highlighted = _highlight_control(target)
	if _highlighted == null:
		return
	_highlight_tween = create_tween().set_loops()
	_highlight_tween.tween_property(_highlighted, "modulate:a", 0.35, 0.5)
	_highlight_tween.tween_property(_highlighted, "modulate:a", 1.0, 0.5)


func _highlight_control(target: String) -> Control:
	match target:
		"goal":
			return _goal_card
		"settings":
			return _settings_button
		"boosts":
			return _boost_button
	return _nav_buttons.get(target)


func top_height() -> float:
	return top_bar.size.y


func bottom_height() -> float:
	return bottom_bar.size.y


func _process(delta: float) -> void:
	if task_panel != null:
		task_panel.position = Vector2(AppTheme.SPACING_SM, top_bar.size.y + AppTheme.SPACING_SM)
	if _money_roll.advance(delta):
		_money_label.text = UiKit.money(_money_roll.value)


func money_anchor() -> Vector2:
	return _money_chip.get_global_rect().get_center()


func goal_anchor() -> Vector2:
	var source: Control = _goal_card if _goal_card.is_visible_in_tree() else _desk_card
	if source.is_visible_in_tree():
		return source.get_global_rect().get_center()
	return get_viewport_rect().size * 0.5


func pulse_money() -> void:
	if _money_pop != null and _money_pop.is_valid():
		_money_pop.kill()
	_money_chip.scale = Vector2.ONE
	_money_pop = Juice.pop(_money_chip)


func pulse_goal() -> Tween:
	return Juice.pop(_goal_card, Juice.BREATHE_SCALE)


func _set_claim_glow(active: bool) -> void:
	if active == (_claim_glow != null):
		return
	if _claim_glow != null:
		_claim_glow.kill()
		_claim_glow = null
		_goal_claim.scale = Vector2.ONE
		return
	_claim_glow = Juice.breathe(_goal_claim)


func income_per_minute() -> float:
	return game.state.income.per_minute() if game != null else 0.0


func refresh() -> void:
	if game == null:
		return
	var state := game.state
	_money_roll.set_target(state.money)
	_money_label.text = UiKit.money(_money_roll.value)
	_reputation_label.text = str(int(state.reputation))
	_income_label.text = tr("FMT_INCOME") % UiKit.money(income_per_minute())
	_refresh_boost_button(state)
	task_panel.refresh()
	_goal_card.visible = game.goals.has_goal()
	if not game.goals.has_goal():
		_set_claim_glow(false)
	else:
		var goal := game.goals.current()
		var target := float(goal.target)
		_goal_label.text = tr("FMT_GOAL_PROGRESS") % [GoalText.describe(goal), UiKit.number(minf(game.goals.current_progress(), target)), UiKit.number(target)]
		_goal_bar.value = clampf(game.goals.current_progress() / target, 0.0, 1.0)
		var complete := game.goals.is_complete()
		_goal_claim.disabled = not complete
		_goal_double.disabled = not complete
		_set_claim_glow(complete and is_inside_tree())
		_goal_reward.visible = complete
		if complete:
			_goal_reward.text = GoalText.claim_reward(goal)
	_event_banner.visible = not state.event_id.is_empty()
	if _event_banner.visible:
		_event_title.text = tr("FMT_EVENT_TITLE") % [tr("EVENT_" + state.event_id.to_upper()), int(ceilf(state.event_time_left))]
		_event_text.text = tr("EVENT_DESC_" + state.event_id.to_upper())
		_refresh_event_actions(state)
	_ruckus_banner.visible = state.has_ruckus()
	_rating_label.text = UiKit.decimal(state.average_rating()) if not state.reviews.is_empty() else "–"
	var negative := state.negative_review_count()
	_refresh_bonus_card(state)
	_refresh_desk_card(state)
	_review_banner.visible = negative > 0
	if _review_banner.visible:
		var newest := _newest_negative(state)
		_review_title.text = tr("FMT_REVIEWS_TITLE") % negative
		_review_text.text = tr("FMT_REVIEW_BANNER") % tr(newest.text_key())


func _newest_negative(state: GameState) -> Review:
	for index in range(state.reviews.size() - 1, -1, -1):
		if state.reviews[index].is_negative():
			return state.reviews[index]
	return null


func _refresh_event_actions(state: GameState) -> void:
	var key := state.event_id + "/" + state.event_choice
	if key == _event_actions_key:
		return
	_event_actions_key = key
	for child in _event_actions.get_children():
		child.queue_free()
	if not state.event_choice.is_empty():
		_event_actions.visible = false
		return
	var choices: Array = GameConfig.EVENTS[state.event_id].get("choices", [])
	for choice in choices:
		var button := UiKit.button(tr("EVENT_CHOICE_" + str(choice).to_upper()), "primary" if choice == "prepare" else "neutral")
		button.pressed.connect(func() -> void: game.perform(game.simulation.resolve_event.bind(str(choice))))
		_event_actions.add_child(button)
	_event_actions.visible = not choices.is_empty()
