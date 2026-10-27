class_name IntroScreen
extends Control

signal finished

const PARAGRAPHS: Array[String] = ["INTRO_TEXT_HIRED", "INTRO_TEXT_REALITY", "INTRO_TEXT_TASK"]
const ICON_DIAMETER := 88
const MAX_WIDTH := 640

var state: GameState
var start_button: Button
var _safe_top := 0.0


static func should_show(p_state: GameState) -> bool:
	return not p_state.intro_seen


func setup(p_state: GameState, safe_top: float) -> IntroScreen:
	state = p_state
	_safe_top = safe_top
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var background := ColorRect.new()
	background.color = AppTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(&"margin_left", AppTheme.SPACING_LG)
	margin.add_theme_constant_override(&"margin_right", AppTheme.SPACING_LG)
	margin.add_theme_constant_override(&"margin_top", int(_safe_top) + AppTheme.SPACING_XXL)
	margin.add_theme_constant_override(&"margin_bottom", AppTheme.SPACING_XXL)
	scroll.add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	center.add_child(_build_content())


func _build_content() -> Control:
	var column := UiKit.vbox(AppTheme.SPACING_LG)
	column.custom_minimum_size.x = MAX_WIDTH
	var disc := UiKit.icon_disc(Icons.SEAL, AppTheme.accent("primary"), ICON_DIAMETER)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(disc)
	var kicker := UiKit.label(tr("INTRO_KICKER"), "LabelSmall")
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	column.add_child(kicker)
	var title := UiKit.label(tr("INTRO_TITLE"), "HeadlineSmall", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	column.add_child(_build_letter())
	start_button = UiKit.button(tr("INTRO_START"))
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(start)
	column.add_child(start_button)
	return column


func _build_letter() -> Control:
	var letter := UiKit.card()
	var body := UiKit.vbox(AppTheme.SPACING_MD)
	letter.add_child(body)
	for key in PARAGRAPHS:
		body.add_child(UiKit.label(tr(key), "BodyMedium", true))
	var signature := UiKit.vbox(0)
	for key: String in ["INTRO_SIGNOFF", "INTRO_SENDER"]:
		var line := UiKit.label(tr(key), "BodySmall", true)
		line.add_theme_color_override(&"font_color", AppTheme.ON_SURFACE_VARIANT)
		signature.add_child(line)
	body.add_child(signature)
	return letter


func start() -> void:
	if state.intro_seen:
		return
	state.intro_seen = true
	finished.emit()
	queue_free()
