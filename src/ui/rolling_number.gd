class_name RollingNumber
extends RefCounted

const ROLL_TIME := 0.6
const SNAP_SHARE := 0.001

var value := 0.0
var target := 0.0
var _started := false
var _speed := 0.0


func set_target(next: float) -> void:
	if not _started or next < value:
		_started = true
		value = next
		target = next
		_speed = 0.0
		return
	target = next
	_speed = maxf(_speed, (target - value) / ROLL_TIME)


func advance(delta: float) -> bool:
	if is_equal_approx(value, target):
		return false
	value = minf(target, value + _speed * maxf(delta, 0.0))
	if target - value <= absf(target) * SNAP_SHARE:
		value = target
	if is_equal_approx(value, target):
		_speed = 0.0
	return true


func is_rolling() -> bool:
	return not is_equal_approx(value, target)
