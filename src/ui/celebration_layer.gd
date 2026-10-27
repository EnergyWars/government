class_name CelebrationLayer
extends Control

signal coin_landed(index: int)
signal celebration_shown(title: String)

const TOAST_TIME := 2.4
const FADE_TIME := 0.3
const MAX_TOASTS := 3
const BIG_TIME := 2.6
const MAX_QUEUE := 3
const BIG_ICON := 72
const BIG_MAX_WIDTH := 520.0
const BIG_HEIGHT_SHARE := 0.38
const CONFETTI_COUNT := 110
const COIN_TIME := 0.75
const COIN_STAGGER := 0.07
const COIN_SPREAD := 70.0
const COIN_LIFT := 160.0
const COIN_SIZE := 30
const MAX_COINS := 12
const BURST_TIME := 0.9
const BURST_RISE := 70.0
const SPARK_COUNT := 10
const TEXT_OUTLINE := 6

var top_inset := 0.0
var confetti: ConfettiView
var toasts: VBoxContainer
var big_queue: Array[Dictionary] = []
var big_card: Control
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts = UiKit.vbox(AppTheme.SPACING_SM)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(toasts)
	confetti = ConfettiView.new()
	add_child(confetti)


func _process(_delta: float) -> void:
	toasts.offset_left = AppTheme.SPACING_LG
	toasts.offset_right = -AppTheme.SPACING_LG
	toasts.offset_top = top_inset + AppTheme.SPACING_SM


static func ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		ignore_mouse(child)


func toast(icon_code: String, title: String, text: String, role: String = "primary") -> Control:
	var card := UiKit.banner(icon_code, title, text, role)
	ignore_mouse(card)
	toasts.add_child(card)
	while toasts.get_child_count() > MAX_TOASTS:
		var oldest := toasts.get_child(0)
		toasts.remove_child(oldest)
		oldest.queue_free()
	Juice.pop_in(card)
	var tween := card.create_tween()
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(card, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(card.queue_free)
	return card


func celebrate(icon_code: String, title: String, text: String, role: String = "success") -> bool:
	if big_queue.size() >= MAX_QUEUE:
		return false
	big_queue.append({"icon": icon_code, "title": title, "text": text, "role": role})
	if not is_instance_valid(big_card):
		show_next()
	return true


func show_next() -> Control:
	if big_queue.is_empty():
		big_card = null
		return null
	var data: Dictionary = big_queue.pop_front()
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.offset_bottom = -size.y * (1.0 - 2.0 * BIG_HEIGHT_SHARE) if size.y > 0.0 else 0.0
	var card := _big_card(data)
	holder.add_child(card)
	add_child(holder)
	move_child(confetti, get_child_count() - 1)
	big_card = holder
	Juice.pop_in(card)
	confetti.burst(Vector2(size.x * 0.5, size.y * BIG_HEIGHT_SHARE), CONFETTI_COUNT)
	celebration_shown.emit(str(data.title))
	var tween := holder.create_tween()
	tween.tween_interval(BIG_TIME)
	tween.tween_property(holder, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_finish_big.bind(holder))
	return card


func _finish_big(holder: Control) -> void:
	holder.queue_free()
	if big_card == holder:
		big_card = null
	show_next()


func _big_card(data: Dictionary) -> Control:
	var role := str(data.role)
	var card := UiKit.card("Banner" + role.capitalize())
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size.x = minf(BIG_MAX_WIDTH, maxf(0.0, size.x - AppTheme.SPACING_LG * 2.0))
	var column := UiKit.vbox(AppTheme.SPACING_MD)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var disc := UiKit.icon_disc(str(data.icon), AppTheme.accent(role), BIG_ICON)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(disc)
	var title := UiKit.label(str(data.title), "HeadlineSmall", true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override(&"font_color", AppTheme.accent(role))
	column.add_child(title)
	if not str(data.text).is_empty():
		var body := UiKit.label(str(data.text), "BodyMedium", true)
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_theme_color_override(&"font_color", AppTheme.on_container(role))
		column.add_child(body)
	card.add_child(column)
	ignore_mouse(card)
	return card


func fly_coins(from: Vector2, to: Vector2, count: int) -> int:
	var total := clampi(count, 0, MAX_COINS)
	for index in total:
		var coin := UiKit.icon(Icons.PAID, AppTheme.MONEY, COIN_SIZE)
		coin.add_theme_constant_override(&"outline_size", TEXT_OUTLINE)
		coin.add_theme_color_override(&"font_outline_color", AppTheme.SURFACE)
		add_child(coin)
		coin.reset_size()
		var start := from + Vector2(rng.randf_range(-COIN_SPREAD, COIN_SPREAD), rng.randf_range(-COIN_SPREAD, COIN_SPREAD) * 0.5)
		var control := start.lerp(to, 0.5) + Vector2(rng.randf_range(-COIN_SPREAD, COIN_SPREAD), -COIN_LIFT)
		coin.position = start - coin.size * 0.5
		coin.modulate.a = 0.0
		var tween := coin.create_tween()
		tween.tween_interval(index * COIN_STAGGER)
		tween.tween_property(coin, "modulate:a", 1.0, 0.08)
		tween.tween_method(_move_coin.bind(coin, start, control, to), 0.0, 1.0, COIN_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tween.tween_callback(_land_coin.bind(coin, index))
	return total


static func curve_point(start: Vector2, control: Vector2, end: Vector2, t: float) -> Vector2:
	return start.lerp(control, t).lerp(control.lerp(end, t), t)


func _move_coin(t: float, coin: Control, start: Vector2, control: Vector2, end: Vector2) -> void:
	coin.position = curve_point(start, control, end, t) - coin.size * 0.5
	coin.scale = Vector2.ONE * lerpf(1.2, 0.7, t)


func _land_coin(coin: Control, index: int) -> void:
	coin.queue_free()
	coin_landed.emit(index)


func burst(at: Vector2, text: String, color: Color) -> Label:
	confetti.sparkle(at, SPARK_COUNT, color)
	if text.is_empty():
		return null
	var label := UiKit.label(text, "TitleMedium")
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", TEXT_OUTLINE)
	label.add_theme_color_override(&"font_outline_color", AppTheme.SURFACE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	label.position = at - label.size * 0.5
	Juice.pop_in(label)
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - BURST_RISE, BURST_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, BURST_TIME * 0.4).set_delay(BURST_TIME * 0.6)
	tween.chain().tween_callback(label.queue_free)
	return label
