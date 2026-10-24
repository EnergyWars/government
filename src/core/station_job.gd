class_name StationJob
extends RefCounted

var case_file: CaseFile
var progress := 0.0
var required := 1.0
var by_specialist := false


func _init(p_case_file: CaseFile = null, p_required: float = 1.0, p_by_specialist: bool = false) -> void:
	case_file = p_case_file
	required = maxf(p_required, 0.01)
	by_specialist = p_by_specialist


func is_done() -> bool:
	return progress >= required


func ratio() -> float:
	return clampf(progress / required, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"case": case_file.to_dict(), "progress": progress, "required": required, "specialist": by_specialist}


static func from_dict(data: Dictionary) -> StationJob:
	var job := StationJob.new(CaseFile.from_dict(data.get("case", {})), float(data.get("required", 1.0)), bool(data.get("specialist", false)))
	job.progress = float(data.get("progress", 0.0))
	return job
