class_name FlingScroll
extends ScrollContainer

const FRICTION := 4.5
const MIN_SPEED := 25.0
const MAX_SPEED := 6000.0

var _speed := 0.0
var _offset := 0.0
var _touching := false


func _ready() -> void:
	set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_touching = touch.pressed
		if touch.pressed:
			stop_fling()
		elif absf(_speed) >= MIN_SPEED:
			_offset = float(scroll_vertical)
			set_process(true)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_speed = clampf(-drag.velocity.y, -MAX_SPEED, MAX_SPEED)


func stop_fling() -> void:
	_speed = 0.0
	set_process(false)


func is_flinging() -> bool:
	return is_processing()


func _process(delta: float) -> void:
	if _touching:
		return
	_offset += _speed * delta
	scroll_vertical = int(_offset)
	_speed *= exp(-FRICTION * delta)
	if absf(_speed) < MIN_SPEED or scroll_vertical != int(_offset):
		stop_fling()


static func pass_touches(root: Node) -> void:
	for child in root.get_children():
		if child is Control and (child as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		pass_touches(child)
