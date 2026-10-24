class_name AppDialog
extends Control

signal confirmed
signal dismissed

var icon_code := Icons.INFO
var icon_role := "primary"
var title_text := ""
var body_text := ""
var confirm_text := ""
var confirm_role := "primary"
var cancel_text := ""


func configure(p_icon: String, p_title: String, p_body: String, p_confirm: String, p_cancel: String = "", p_confirm_role: String = "primary") -> AppDialog:
	icon_code = p_icon
	title_text = p_title
	body_text = p_body
	confirm_text = p_confirm
	cancel_text = p_cancel
	confirm_role = p_confirm_role
	icon_role = p_confirm_role
	return self


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
	column.add_child(UiKit.icon(icon_code, AppTheme.accent(icon_role), 36))
	var heading := UiKit.label(title_text, "TitleLarge", true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	var body := UiKit.label(body_text, "BodyMedium", true)
	body.add_theme_color_override(&"font_color", AppTheme.ON_SURFACE_VARIANT)
	column.add_child(body)
	var buttons := UiKit.hbox(AppTheme.SPACING_SM)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	if not cancel_text.is_empty():
		var cancel := UiKit.button(cancel_text, "neutral", "Text")
		cancel.pressed.connect(_dismiss)
		buttons.add_child(cancel)
	var confirm := UiKit.button(confirm_text, confirm_role, "Tonal")
	confirm.pressed.connect(_confirm)
	buttons.add_child(confirm)
	column.add_child(buttons)


func _confirm() -> void:
	confirmed.emit()
	queue_free()


func _dismiss() -> void:
	dismissed.emit()
	queue_free()
