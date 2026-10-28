class_name Department
extends RefCounted

var id: String
var unlocked := false
var rank := 1
var thoroughness := 1
var signature_thoroughness := -1
var prioritize_urgent := true
var scan_all := false
var arrival_timer := 0.0
var follow_ups: Array[float] = []
var hands_on := 0


func _init(p_id: String = "") -> void:
	id = p_id


func config() -> Dictionary:
	return GameConfig.department(id)


func station_keys() -> Array[String]:
	return GameConfig.department_station_keys(id)


func has_signature_part() -> bool:
	return not bool(config().get("signature_machine", true))


func signature_mode() -> int:
	return thoroughness if signature_thoroughness < 0 else signature_thoroughness


func is_customs() -> bool:
	return GameConfig.is_customs(id)


func is_onboarded() -> bool:
	return not GameConfig.needs_onboarding(id) or hands_on >= GameConfig.HANDS_ON_CASES


func to_dict() -> Dictionary:
	return {
		"id": id,
		"unlocked": unlocked,
		"rank_level": rank,
		"thoroughness": thoroughness,
		"signature_thoroughness": signature_thoroughness,
		"prioritize_urgent": prioritize_urgent,
		"scan_all": scan_all,
		"arrival_timer": arrival_timer,
		"follow_ups": follow_ups.duplicate(),
		"hands_on": hands_on,
	}


static func from_dict(data: Dictionary) -> Department:
	var dept := Department.new(str(data.get("id", "")))
	dept.unlocked = bool(data.get("unlocked", false))
	dept.rank = _restore_rank(data) if dept.unlocked else 1
	dept.thoroughness = clampi(int(data.get("thoroughness", 1)), 0, GameConfig.THOROUGHNESS.size() - 1)
	dept.signature_thoroughness = clampi(int(data.get("signature_thoroughness", -1)), -1, GameConfig.THOROUGHNESS.size() - 1)
	dept.prioritize_urgent = bool(data.get("prioritize_urgent", true))
	dept.scan_all = bool(data.get("scan_all", false))
	dept.arrival_timer = float(data.get("arrival_timer", 0.0))
	for value in data.get("follow_ups", []):
		dept.follow_ups.append(float(value))
	dept.hands_on = clampi(int(data.get("hands_on", GameConfig.HANDS_ON_CASES if dept.unlocked else 0)), 0, GameConfig.HANDS_ON_CASES)
	return dept


static func _restore_rank(data: Dictionary) -> int:
	if data.has("rank_level"):
		return DepartmentRank.clamp_level(int(data.rank_level))
	if data.has("rank"):
		return SaveMigration.legacy_rank_level(int(data.rank))
	return 1
