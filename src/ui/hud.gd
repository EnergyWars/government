class_name Hud
extends Control

signal open_sheet(sheet_id: String, argument: String)
signal focus_department(dept_id: String)

const NAV_ITEMS := [
	{"id": "departments", "icon": Icons.APARTMENT, "label": "NAV_DEPARTMENTS"},
	{"id": "team", "icon": Icons.TEAM, "label": "NAV_TEAM"},
	{"id": "research", "icon": Icons.SCIENCE, "label": "NAV_RESEARCH"},
	{"id": "building", "icon": Icons.DOMAIN, "label": "NAV_BUILDING"},
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
var _goal_claim: Button
var _goal_card: PanelContainer
var _event_banner: PanelContainer
var _event_title: Label
var _event_text: Label
var _event_actions: HBoxContainer
var _event_actions_key := ""
var _safe_top := 0.0
var task_panel: TaskPanel
var _nav_buttons := {}
var _settings_button: Button
var _highlighted: Control
var _highlight_tween: Tween
var _income_window: Array[float] = []
var _income_last_money := -1.0
var _income_timer := 0.0


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
	task_panel.open_department.connect(func(dept_id: String) -> void: open_sheet.emit("department", dept_id))
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
	_reputation_label = _resource_chip(row, Icons.STAR, AppTheme.accent("warning"))
	_income_label = UiKit.label("", "BodySmall")
	row.add_child(_income_label)
	row.add_child(UiKit.spacer())
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
	goal_row.add_child(goal_column)
	_goal_claim = UiKit.button(tr("ACTION_CLAIM"))
	_goal_claim.pressed.connect(func() -> void: game.perform(game.goals.claim))
	goal_row.add_child(_goal_claim)
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
	return _nav_buttons.get(target)


func top_height() -> float:
	return top_bar.size.y


func bottom_height() -> float:
	return bottom_bar.size.y


func _process(delta: float) -> void:
	if task_panel != null:
		task_panel.position = Vector2(AppTheme.SPACING_SM, top_bar.size.y + AppTheme.SPACING_SM)
	_income_timer += delta
	if _income_timer >= 1.0:
		_income_timer = 0.0
		_sample_income()


func _sample_income() -> void:
	if game == null:
		return
	var earned := game.state.money_earned
	if _income_last_money >= 0.0:
		_income_window.append(earned - _income_last_money)
		if _income_window.size() > 30:
			_income_window.remove_at(0)
	_income_last_money = earned


func income_per_minute() -> float:
	if _income_window.is_empty():
		return 0.0
	var total := 0.0
	for value in _income_window:
		total += value
	return total / _income_window.size() * 60.0


func refresh() -> void:
	if game == null:
		return
	var state := game.state
	_money_label.text = UiKit.money(state.money)
	_reputation_label.text = str(int(state.reputation))
	_income_label.text = tr("FMT_INCOME") % UiKit.money(income_per_minute())
	task_panel.refresh()
	_goal_card.visible = game.goals.has_goal()
	if game.goals.has_goal():
		var goal := game.goals.current()
		var target := float(goal.target)
		_goal_label.text = tr("FMT_GOAL_PROGRESS") % [GoalText.describe(goal), UiKit.number(minf(game.goals.current_progress(), target)), UiKit.number(target)]
		_goal_bar.value = clampf(game.goals.current_progress() / target, 0.0, 1.0)
		_goal_claim.disabled = not game.goals.is_complete()
	_event_banner.visible = not state.event_id.is_empty()
	if _event_banner.visible:
		_event_title.text = tr("FMT_EVENT_TITLE") % [tr("EVENT_" + state.event_id.to_upper()), int(ceilf(state.event_time_left))]
		_event_text.text = tr("EVENT_DESC_" + state.event_id.to_upper())
		_refresh_event_actions(state)


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
