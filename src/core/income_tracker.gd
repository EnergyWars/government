class_name IncomeTracker
extends RefCounted

const SAMPLE_SECONDS := 1.0
const WINDOW := 30

var samples: Array[float] = []
var _last_earned := -1.0
var _clock := 0.0


func advance(delta: float, earned: float) -> void:
	_clock += delta
	if _clock < SAMPLE_SECONDS:
		return
	_clock = 0.0
	if _last_earned >= 0.0:
		samples.append(maxf(0.0, earned - _last_earned))
		if samples.size() > WINDOW:
			samples.remove_at(0)
	_last_earned = earned


func per_minute() -> float:
	if samples.is_empty():
		return 0.0
	var total := 0.0
	for value in samples:
		total += value
	return total / samples.size() * 60.0 / SAMPLE_SECONDS
