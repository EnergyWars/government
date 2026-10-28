class_name ProductionStats
extends RefCounted

const ARRIVED := "arrived"
const COMPLETED := "completed"
const REJECTED := "rejected"
const LOST := "lost"
const STATION := "station"
const SICK := "sick"
const LEAD_WOKEN := "lead_woken"
const DOZED := "dozed"
const DISPUTE := "dispute"
const DISPUTE_CALMED := "dispute_calmed"
const TRANSFER := "transfer"
const COMPLAINT := "complaint"
const COMPLAINT_SHREDDED := "complaint_shredded"
const REJECT_SHREDDED := "reject_shredded"
const CALL_ANSWERED := "call_answered"
const CALL_MISSED := "call_missed"
const BY_PLAYER := "player"
const BY_RUNNER := "runner"
const BY_TUBE := "tube"
const BY_STAFF := "staff"

var started := 0.0
var _counters := {}


func begin(now: float) -> void:
	started = now
	_counters.clear()


func record(kind: String, scope: String, now: float, amount: int = 1) -> void:
	_counter(kind, scope).add(now, amount)
	if not scope.is_empty():
		_counter(kind, "").add(now, amount)


func per_minute(kind: String, scope: String, now: float) -> float:
	var counter: RateCounter = _counters.get(_key(kind, scope))
	return counter.per_minute(now, started) if counter != null else 0.0


func total(kind: String, scope: String = "") -> int:
	var counter: RateCounter = _counters.get(_key(kind, scope))
	return counter.total if counter != null else 0


func observed(now: float) -> float:
	return clampf(now - started, 0.0, float(RateCounter.WINDOW))


func _counter(kind: String, scope: String) -> RateCounter:
	var key := _key(kind, scope)
	if not _counters.has(key):
		_counters[key] = RateCounter.new()
	return _counters[key]


static func _key(kind: String, scope: String) -> String:
	return kind + "|" + scope
