class_name Department
extends RefCounted

var id: String
var unlocked := false
var supervisors := 0
var thoroughness := 1
var prioritize_urgent := true
var scan_all := false
var arrival_timer := 0.0
var follow_ups: Array[float] = []
var hands_on := 0
var tube := false


func _init(p_id: String = "") -> void:
	id = p_id


func config() -> Dictionary:
	return GameConfig.department(id)


func station_keys() -> Array[String]:
	return GameConfig.department_station_keys(id)


func is_customs() -> bool:
	return GameConfig.is_customs(id)


func is_onboarded() -> bool:
	return not GameConfig.needs_onboarding(id) or hands_on >= GameConfig.HANDS_ON_CASES


func to_dict() -> Dictionary:
	return {
		"id": id,
		"unlocked": unlocked,
		"supervisors": supervisors,
		"thoroughness": thoroughness,
		"prioritize_urgent": prioritize_urgent,
		"scan_all": scan_all,
		"arrival_timer": arrival_timer,
		"follow_ups": follow_ups.duplicate(),
		"hands_on": hands_on,
		"tube": tube,
	}


static func from_dict(data: Dictionary, legacy_tube: bool = false) -> Department:
	var dept := Department.new(str(data.get("id", "")))
	dept.unlocked = bool(data.get("unlocked", false))
	dept.supervisors = clampi(int(data.get("supervisors", 0)), 0, GameConfig.MAX_SUPERVISORS)
	dept.thoroughness = clampi(int(data.get("thoroughness", 1)), 0, GameConfig.THOROUGHNESS.size() - 1)
	dept.prioritize_urgent = bool(data.get("prioritize_urgent", true))
	dept.scan_all = bool(data.get("scan_all", false))
	dept.arrival_timer = float(data.get("arrival_timer", 0.0))
	for value in data.get("follow_ups", []):
		dept.follow_ups.append(float(value))
	dept.hands_on = clampi(int(data.get("hands_on", GameConfig.HANDS_ON_CASES if dept.unlocked else 0)), 0, GameConfig.HANDS_ON_CASES)
	dept.tube = dept.unlocked and bool(data.get("tube", legacy_tube))
	return dept
