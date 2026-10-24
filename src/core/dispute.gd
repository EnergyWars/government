class_name Dispute
extends RefCounted

var kind := ""
var dept_id := ""
var elapsed := 0.0
var progress := 0.0


func _init(p_kind: String = "", p_dept_id: String = "") -> void:
	kind = p_kind
	dept_id = p_dept_id


func speed() -> float:
	return float(GameConfig.DISPUTES[kind].speed)


func to_dict() -> Dictionary:
	return {"kind": kind, "dept": dept_id, "elapsed": elapsed}


static func from_dict(data: Variant) -> Dispute:
	if not data is Dictionary:
		return null
	var saved_kind := str(data.get("kind", ""))
	var saved_dept := str(data.get("dept", ""))
	if not GameConfig.DISPUTES.has(saved_kind) or GameConfig.department(saved_dept).is_empty():
		return null
	var dispute := Dispute.new(saved_kind, saved_dept)
	dispute.elapsed = clampf(float(data.get("elapsed", 0.0)), 0.0, GameConfig.DISPUTE_MAX_SECONDS)
	return dispute
