class_name TubeParcel
extends RefCounted

var case_file: CaseFile
var from_key := ""
var to_key := ""
var left := 0.0


func _init(p_case: CaseFile = null, p_from: String = "", p_to: String = "", p_left: float = 0.0) -> void:
	case_file = p_case
	from_key = p_from
	to_key = p_to
	left = p_left


func tube_id() -> String:
	return RouteBuilder.tube_id(from_key, to_key)


func to_dict() -> Dictionary:
	return {"from": from_key, "to": to_key, "left": left, "case": case_file.to_dict()}


static func from_dict(data: Variant) -> TubeParcel:
	if not data is Dictionary or not data.get("case") is Dictionary:
		return null
	var from_key := str(data.get("from", ""))
	var to_key := str(data.get("to", ""))
	if from_key.is_empty() or to_key.is_empty():
		return null
	return TubeParcel.new(CaseFile.from_dict(data.case), from_key, to_key, maxf(0.0, float(data.get("left", 0.0))))
