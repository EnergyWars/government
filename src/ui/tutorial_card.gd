class_name TutorialCard
extends Control

signal highlight_changed(target: String)

var game: Game
var hud: Hud
var panel: PanelContainer
var _safe_top := 0.0
var _counter: Label
var _title: Label
var _text: Label
var _progress: ProgressBar
var _next: Button
var _waiting: HBoxContainer


func setup(p_game: Game, p_hud: Hud, safe_top: float) -> TutorialCard:
	game = p_game
	hud = p_hud
	_safe_top = safe_top
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	game.tutorial.changed.connect(refresh)
	refresh()


func _build() -> void:
	panel = UiKit.card("CardPrimary")
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.offset_left = AppTheme.SPACING_SM
	panel.offset_right = -AppTheme.SPACING_SM
	add_child(panel)
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	panel.add_child(column)
	var header := UiKit.hbox(AppTheme.SPACING_MD)
	header.add_child(UiKit.icon_disc(Icons.SCHOOL, AppTheme.accent("primary"), 44))
	var titles := UiKit.vbox(0)
	_counter = UiKit.label("", "LabelSmall")
	_counter.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	titles.add_child(_counter)
	_title = UiKit.label("", "TitleMedium", true)
	titles.add_child(_title)
	header.add_child(titles)
	column.add_child(header)
	_text = UiKit.label("", "BodySmall", true)
	_text.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	column.add_child(_text)
	_progress = UiKit.progress()
	column.add_child(_progress)
	var buttons := UiKit.hbox(AppTheme.SPACING_SM)
	var skip := UiKit.button(tr("TUTORIAL_SKIP"), "neutral", "Text")
	skip.pressed.connect(_confirm_skip)
	buttons.add_child(skip)
	buttons.add_child(UiKit.spacer())
	_waiting = UiKit.hbox(AppTheme.SPACING_XS)
	_waiting.add_child(UiKit.icon(Icons.HOURGLASS, AppTheme.accent("primary"), AppTheme.SIZE_ICON_SMALL))
	_waiting.add_child(UiKit.label(tr("TUTORIAL_WAITING"), "LabelSmall"))
	buttons.add_child(_waiting)
	_next = UiKit.button(tr("TUTORIAL_NEXT"))
	_next.pressed.connect(game.tutorial.advance)
	buttons.add_child(_next)
	column.add_child(buttons)


func refresh() -> void:
	var tutorial := game.tutorial
	visible = tutorial.is_active()
	if not visible:
		highlight_changed.emit("")
		return
	var step := tutorial.current()
	var key := str(step.id).to_upper()
	_counter.text = tr("FMT_TUTORIAL_STEP") % [tutorial.index() + 1, tutorial.count()]
	_title.text = tr("TUTORIAL_%s_TITLE" % key)
	_text.text = tr("TUTORIAL_%s_TEXT" % key)
	_progress.value = float(tutorial.index()) / float(tutorial.count())
	_next.visible = tutorial.can_advance()
	_next.text = _next_label(tutorial)
	_waiting.visible = not tutorial.can_advance()
	highlight_changed.emit(str(step.target))


func _next_label(tutorial: Tutorial) -> String:
	if not tutorial.is_info():
		return tr("TUTORIAL_SKIP_STEP")
	return tr("TUTORIAL_FINISH") if tutorial.is_last() else tr("TUTORIAL_NEXT")


func _process(_delta: float) -> void:
	if not visible:
		return
	var margin := AppTheme.SPACING_SM
	var on_top := not game.tutorial.open_sheet().is_empty()
	var anchor := 0.0 if on_top else 1.0
	panel.anchor_top = anchor
	panel.anchor_bottom = anchor
	var offset := _safe_top + margin if on_top else -(hud.bottom_height() + margin)
	panel.offset_top = offset
	panel.offset_bottom = offset
	panel.grow_vertical = Control.GROW_DIRECTION_END if on_top else Control.GROW_DIRECTION_BEGIN


func _confirm_skip() -> void:
	var dialog := AppDialog.new().configure(Icons.SCHOOL, tr("TUTORIAL_SKIP_TITLE"), tr("TUTORIAL_SKIP_TEXT"), tr("TUTORIAL_SKIP_CONFIRM"), tr("ACTION_CANCEL"))
	dialog.confirmed.connect(game.tutorial.skip)
	add_child(dialog)
