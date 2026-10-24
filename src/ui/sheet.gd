class_name Sheet
extends Control

signal closed
signal navigate(sheet_id: String, argument: String)

var game: Game
var argument := ""
var content: VBoxContainer
var _title_label: Label
var _panel: PanelContainer
var _scroll: FlingScroll
var _updaters: Array[Callable] = []


func setup(p_game: Game, p_argument: String = "") -> Sheet:
	game = p_game
	argument = p_argument
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = AppTheme.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)
	_panel = UiKit.card("Sheet")
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0 - sheet_height_ratio()
	_panel.anchor_bottom = 1.0
	add_child(_panel)
	var layout := UiKit.vbox(AppTheme.SPACING_MD)
	_panel.add_child(layout)
	var header := UiKit.hbox(AppTheme.SPACING_SM)
	_title_label = UiKit.label(title(), "TitleLarge", true)
	header.add_child(_title_label)
	var close := UiKit.icon_button(Icons.CLOSE)
	close.tooltip_text = tr("ACTION_CLOSE")
	close.pressed.connect(close_sheet)
	header.add_child(close)
	layout.add_child(header)
	_scroll = FlingScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 4
	_scroll.follow_focus = false
	layout.add_child(_scroll)
	content = UiKit.vbox(AppTheme.SPACING_MD)
	_scroll.add_child(content)
	rebuild()
	if game != null:
		game.changed.connect(_on_game_changed)


func sheet_height_ratio() -> float:
	return 0.72


func title() -> String:
	return ""


func build(_container: VBoxContainer) -> void:
	pass


func rebuild() -> void:
	var scroll_position := _scroll.scroll_vertical if _scroll != null else 0
	_updaters.clear()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	build(content)
	_scroll.scroll_vertical = scroll_position
	FlingScroll.pass_touches(content)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = AppTheme.SPACING_XL
	content.add_child(spacer)
	_title_label.text = title()
	refresh()
	_restore_scroll.call_deferred(scroll_position)


func _restore_scroll(value: int) -> void:
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = value


func track(updater: Callable) -> void:
	_updaters.append(updater)


func refresh() -> void:
	for updater in _updaters:
		updater.call()


func act(action: Callable) -> void:
	if game.perform(action):
		rebuild()


func close_sheet() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()


func _on_game_changed() -> void:
	if is_inside_tree():
		refresh()


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not is_queued_for_deletion():
		close_sheet()
