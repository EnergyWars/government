class_name JoystickView
extends Control

const BASE_RADIUS := 70.0
const KNOB_RADIUS := 30.0

var origin := Vector2.ZERO
var knob := Vector2.ZERO
var active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_at(p_origin: Vector2, p_knob: Vector2) -> void:
	origin = p_origin
	knob = p_knob
	active = true
	queue_redraw()


func hide_stick() -> void:
	active = false
	queue_redraw()


func _draw() -> void:
	if not active:
		return
	draw_circle(origin, BASE_RADIUS, Color(AppTheme.SURFACE, 0.35))
	draw_arc(origin, BASE_RADIUS, 0.0, TAU, 48, Color(AppTheme.accent("primary"), 0.5), 3.0, true)
	draw_circle(knob, KNOB_RADIUS, Color(AppTheme.accent("primary"), 0.75))
