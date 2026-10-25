class_name FloatBatcher
extends RefCounted

const WINDOW := 1.0

var window: float
var _cooldowns: Dictionary[String, float] = {}
var _pending: Dictionary[String, Dictionary] = {}


func _init(p_window: float = WINDOW) -> void:
	window = maxf(0.0, p_window)


func add(key: String, payload: Dictionary) -> bool:
	if not _cooldowns.has(key):
		_cooldowns[key] = window
		return true
	var pending: Dictionary = _pending.get(key, {"count": 0})
	var count := int(pending.count) + 1
	pending = payload.duplicate()
	pending.count = count
	_pending[key] = pending
	return false


func advance(delta: float) -> Array[Dictionary]:
	var flushed: Array[Dictionary] = []
	for key in _cooldowns.keys():
		_cooldowns[key] -= delta
		if _cooldowns[key] > 0.0:
			continue
		if _pending.has(key):
			flushed.append(_pending[key])
			_pending.erase(key)
			_cooldowns[key] = window
		else:
			_cooldowns.erase(key)
	return flushed


func pending_count(key: String) -> int:
	return int(_pending.get(key, {}).get("count", 0))


func is_cooling(key: String) -> bool:
	return _cooldowns.has(key)
