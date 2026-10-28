class_name IncomeTracker
extends RefCounted

const SAMPLE_SECONDS := 1.0
const WINDOW := 600
const REFRESH_SECONDS := 30.0

var samples: Array[float] = []
var _last_earned := -1.0
var _clock := 0.0
var _sum := 0.0
var _since_refresh := 0.0
var _per_minute := 0.0
var _has_value := false


func advance(delta: float, earned: float) -> void:
	_clock += delta
	if _clock < SAMPLE_SECONDS:
		return
	_clock = 0.0
	if _last_earned >= 0.0:
		_add_sample(maxf(0.0, earned - _last_earned))
	_last_earned = earned


func exclude(amount: float) -> void:
	if _last_earned >= 0.0:
		_last_earned += maxf(amount, 0.0)


func per_minute() -> float:
	return _per_minute


func _add_sample(value: float) -> void:
	samples.append(value)
	_sum += value
	if samples.size() > WINDOW:
		_sum -= samples[0]
		samples.remove_at(0)
	_since_refresh += SAMPLE_SECONDS
	if not _has_value or _since_refresh >= REFRESH_SECONDS:
		_refresh()


func _refresh() -> void:
	_has_value = true
	_since_refresh = 0.0
	_per_minute = maxf(0.0, _sum) / samples.size() * 60.0 / SAMPLE_SECONDS
