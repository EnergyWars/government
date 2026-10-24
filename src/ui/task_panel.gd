class_name TaskPanel
extends PanelContainer

signal focus_department(dept_id: String)
signal open_department(dept_id: String)

const ROW_WIDTH := 244

var game: Game
var _rows: VBoxContainer
var _toggle: Button
var _count := -1
var _updaters: Array[Callable] = []
var expanded := true
var _fills := {}


func setup(p_game: Game) -> TaskPanel:
	game = p_game
	return self


func _ready() -> void:
	var style := AppTheme.box(Color(AppTheme.SURFACE, 0.92), AppTheme.RADIUS_CARD, AppTheme.outline_soft(), AppTheme.SPACING_SM)
	add_theme_stylebox_override(&"panel", style)
	for role in ["success", "warning", "error"]:
		_fills[role] = AppTheme.box(AppTheme.accent(role), AppTheme.RADIUS_PILL)
	var column := UiKit.vbox(AppTheme.SPACING_XS)
	add_child(column)
	_toggle = UiKit.button(tr("TASKS_TITLE"), "neutral", "Text")
	_toggle.custom_minimum_size = Vector2(ROW_WIDTH, 32)
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.pressed.connect(func() -> void:
		expanded = not expanded
		_rows.visible = expanded
	)
	column.add_child(_toggle)
	_rows = UiKit.vbox(AppTheme.SPACING_XS)
	column.add_child(_rows)


func refresh() -> void:
	if game == null:
		return
	if game.state.unlocked_count() != _count:
		_rebuild()
	for updater in _updaters:
		updater.call()


func _rebuild() -> void:
	_count = game.state.unlocked_count()
	_toggle.text = tr("TASKS_TITLE")
	_updaters.clear()
	for child in _rows.get_children():
		child.queue_free()
	for dept in game.state.unlocked_departments():
		_rows.add_child(_row(dept))


func _row(dept: Department) -> Control:
	var row := UiKit.hbox(AppTheme.SPACING_XS)
	var focus := Button.new()
	focus.theme_type_variation = "NeutralText"
	focus.focus_mode = Control.FOCUS_NONE
	focus.custom_minimum_size = Vector2(ROW_WIDTH - 40, 36)
	focus.pressed.connect(func() -> void: focus_department.emit(dept.id))
	var content := UiKit.hbox(AppTheme.SPACING_SM)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = AppTheme.SPACING_XS
	content.offset_right = -AppTheme.SPACING_XS
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(UiKit.icon_disc(Icons.department(dept.id), AppTheme.department_color(dept.id), 28))
	var texts := UiKit.vbox(2)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	var waiting := UiKit.label("", "LabelSmall")
	waiting.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(waiting)
	var bar := UiKit.progress()
	bar.custom_minimum_size.y = 5
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(bar)
	content.add_child(texts)
	focus.add_child(content)
	row.add_child(focus)
	var open := UiKit.icon_button(Icons.CHEVRON, "primary", "IconStandard")
	open.custom_minimum_size = Vector2(36, 36)
	open.pressed.connect(func() -> void: open_department.emit(dept.id))
	row.add_child(open)
	_updaters.append(func() -> void:
		var load := Formulas.workload(game.state, dept)
		var resting := Formulas.resting_count(game.state, dept)
		if resting > 0:
			waiting.text = tr("FMT_TASK_ROW_RESTING") % [Formulas.waiting_count(game.state, dept), UiKit.percent(load), resting]
		else:
			waiting.text = tr("FMT_TASK_ROW") % [Formulas.waiting_count(game.state, dept), UiKit.percent(load)]
		bar.value = load
		var fill_role := "error" if load > 0.8 else ("warning" if load > 0.5 else "success")
		if str(bar.get_meta(&"fill_role", "")) != fill_role:
			bar.set_meta(&"fill_role", fill_role)
			bar.add_theme_stylebox_override(&"fill", _fills[fill_role])
	)
	return row
