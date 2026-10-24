class_name AdPlaceholder
extends Control

signal finished

const SLOGAN_COUNT := 6

var remaining := GameConfig.AD_SECONDS
var slogan := 1
var _on_done: Callable
var _countdown: Label
var _bar: ProgressBar
var _done := false


static func play(host: Node, on_done: Callable) -> AdPlaceholder:
	var ad := AdPlaceholder.new()
	ad._on_done = on_done
	ad.slogan = randi_range(1, SLOGAN_COUNT)
	host.add_child(ad)
	return ad


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = AppTheme.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := UiKit.card("Dialog")
	panel.custom_minimum_size.x = 560
	center.add_child(panel)
	var column := UiKit.vbox(AppTheme.SPACING_LG)
	panel.add_child(column)
	var header := UiKit.hbox(AppTheme.SPACING_SM)
	header.add_child(UiKit.pill(tr("LABEL_AD"), "warning"))
	header.add_child(UiKit.spacer())
	_countdown = UiKit.label("", "TitleSmall")
	header.add_child(_countdown)
	column.add_child(header)
	column.add_child(UiKit.icon(Icons.AD, AppTheme.accent("primary"), 64))
	var heading := UiKit.label(tr("AD_TITLE_%d" % slogan), "TitleLarge", true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := UiKit.label(tr("AD_TEXT_%d" % slogan), "BodyMedium", true)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override(&"font_color", AppTheme.ON_SURFACE_VARIANT)
	column.add_child(body)
	_bar = UiKit.progress()
	column.add_child(_bar)
	var note := UiKit.label(tr("AD_PLACEHOLDER_NOTE"), "BodySmall", true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override(&"font_color", AppTheme.ON_SURFACE_VARIANT)
	column.add_child(note)
	_update_view()


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _done:
		return
	remaining = maxf(0.0, remaining - delta)
	_update_view()
	if remaining > 0.0:
		return
	_done = true
	if _on_done.is_valid():
		_on_done.call()
	finished.emit()
	queue_free()


func is_done() -> bool:
	return _done


func _update_view() -> void:
	if _countdown == null:
		return
	_countdown.text = tr("FMT_AD_COUNTDOWN") % ceili(remaining)
	_bar.value = 1.0 - remaining / GameConfig.AD_SECONDS
