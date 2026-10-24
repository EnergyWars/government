class_name RateCounter
extends RefCounted

const WINDOW := 60

var total := 0
var _counts := PackedInt32Array()
var _stamps := PackedInt32Array()


func _init() -> void:
	_counts.resize(WINDOW)
	_stamps.resize(WINDOW)
	_stamps.fill(-1)


func add(now: float, amount: int = 1) -> void:
	var second := maxi(0, int(now))
	var index := second % WINDOW
	if _stamps[index] != second:
		_stamps[index] = second
		_counts[index] = 0
	_counts[index] += amount
	total += amount


func recent(now: float) -> int:
	var second := maxi(0, int(now))
	var count := 0
	for index in WINDOW:
		var stamp := _stamps[index]
		if stamp >= 0 and stamp <= second and second - stamp < WINDOW:
			count += _counts[index]
	return count


func per_minute(now: float, since: float) -> float:
	var observed := clampf(now - since, 1.0, float(WINDOW))
	return recent(now) * 60.0 / observed
