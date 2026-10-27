class_name Juice
extends RefCounted

const POP_SCALE := 1.18
const POP_TIME := 0.36
const POP_IN_FROM := 0.4
const BREATHE_SCALE := 1.07
const BREATHE_TIME := 0.55
const FLOAT_POP_TIME := 0.24
const FLOAT_POP_PEAK := 1.25
const FLOAT_POP_START := 0.45


static func center_pivot(control: Control) -> void:
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5


static func pop(control: Control, strength: float = POP_SCALE) -> Tween:
	if not control.is_inside_tree():
		return null
	center_pivot(control)
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * strength, POP_TIME * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, POP_TIME * 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween


static func pop_in(control: Control) -> Tween:
	if not control.is_inside_tree():
		return null
	center_pivot(control)
	control.scale = Vector2.ONE * POP_IN_FROM
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel()
	tween.tween_callback(center_pivot.bind(control))
	tween.tween_property(control, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, POP_TIME * 0.5)
	return tween


static func breathe(control: Control) -> Tween:
	if not control.is_inside_tree():
		return null
	center_pivot(control)
	var tween := control.create_tween().set_loops()
	tween.tween_callback(center_pivot.bind(control))
	tween.tween_property(control, "scale", Vector2.ONE * BREATHE_SCALE, BREATHE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, BREATHE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


static func float_scale(elapsed: float) -> float:
	if elapsed <= 0.0:
		return FLOAT_POP_START
	var rise := FLOAT_POP_TIME * 0.5
	if elapsed < rise:
		return lerpf(FLOAT_POP_START, FLOAT_POP_PEAK, elapsed / rise)
	if elapsed < FLOAT_POP_TIME:
		return lerpf(FLOAT_POP_PEAK, 1.0, (elapsed - rise) / (FLOAT_POP_TIME - rise))
	return 1.0
