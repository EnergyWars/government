class_name CitizenTracker
extends RefCounted

const SPEED := GameConfig.CITIZEN_SPEED
const ARRIVED := 0.5

var entries: Dictionary = {}
var _next_look := 0
var _started := false


func sync(placements: Array[Dictionary], delta: float, spawn: Vector2) -> Array[Dictionary]:
	var seen := {}
	for placement in placements:
		seen[placement.case] = true
	var gone: Array[Dictionary] = []
	for case_file in entries.keys():
		if not seen.has(case_file):
			gone.append(entries[case_file])
			entries.erase(case_file)
	for placement in placements:
		var case_file: CaseFile = placement.case
		var entry: Dictionary = entries.get(case_file, {})
		if entry.is_empty():
			entry = {"pos": spawn, "look": _next_look, "dept": case_file.dept_id, "stage": "", "case": case_file}
			_next_look += 1
			entries[case_file] = entry
		entry.stage = str(placement.get("stage", ""))
		var target: Vector2 = placement.get("target", Vector2.ZERO)
		if not _started:
			entry.pos = target
		entry.target = target
		entry.pos = (entry.pos as Vector2).move_toward(target, SPEED * delta)
	_started = true
	return gone


func advance(delta: float) -> void:
	var step := SPEED * delta
	for case_file in entries:
		var entry: Dictionary = entries[case_file]
		entry.pos = (entry.pos as Vector2).move_toward(entry.target, step)


func entry_for(case_file: CaseFile) -> Dictionary:
	return entries.get(case_file, {})


static func is_walking(entry: Dictionary) -> bool:
	return (entry.pos as Vector2).distance_to(entry.target) > ARRIVED
