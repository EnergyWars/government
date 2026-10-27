class_name StreakCounter
extends RefCounted

var window: float
var count := 0
var _clock := 0.0
var _last := 0.0


func _init(p_window: float) -> void:
	window = maxf(p_window, 0.0)


func advance(delta: float) -> void:
	_clock += maxf(delta, 0.0)
	if count > 0 and _clock - _last > window:
		count = 0


func hit() -> int:
	if count > 0 and _clock - _last > window:
		count = 0
	count += 1
	_last = _clock
	return count


func reset() -> void:
	count = 0


static func is_milestone(value: int) -> bool:
	return value == 3 or value == 5 or (value >= 10 and value % 10 == 0)
