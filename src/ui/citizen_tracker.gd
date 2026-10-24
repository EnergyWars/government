class_name CitizenTracker
extends RefCounted

const SPEED := 200.0
const ARRIVED := 0.5

var entries: Dictionary = {}
var _seats: Dictionary = {}
var _next_look := 0
var _started := false


func sync(placements: Array[Dictionary], delta: float, spawn: Vector2, seat_point: Callable, seat_limit: int) -> Array[Dictionary]:
	var seen := {}
	for placement in placements:
		seen[placement.case] = true
	var gone: Array[Dictionary] = []
	for case_file in entries.keys():
		if not seen.has(case_file):
			var entry: Dictionary = entries[case_file]
			_release_seat(entry)
			gone.append(entry)
			entries.erase(case_file)
	for placement in placements:
		var case_file: CaseFile = placement.case
		var entry: Dictionary = entries.get(case_file, {})
		if entry.is_empty():
			entry = {"pos": spawn, "look": _next_look, "seat": -1, "dept": case_file.dept_id, "stage": ""}
			_next_look += 1
			entries[case_file] = entry
		entry.stage = str(placement.get("stage", ""))
		var target: Vector2 = placement.get("target", Vector2.ZERO)
		if bool(placement.get("seat", false)):
			if int(entry.seat) < 0:
				entry.seat = _claim_seat(seat_limit)
			if int(entry.seat) >= 0:
				target = seat_point.call(int(entry.seat))
		else:
			_release_seat(entry)
		if not _started:
			entry.pos = target
		entry.target = target
		entry.pos = (entry.pos as Vector2).move_toward(target, SPEED * delta)
	_started = true
	return gone


func entry_for(case_file: CaseFile) -> Dictionary:
	return entries.get(case_file, {})


static func is_walking(entry: Dictionary) -> bool:
	return (entry.pos as Vector2).distance_to(entry.target) > ARRIVED


func _claim_seat(limit: int) -> int:
	for index in limit:
		if not _seats.has(index):
			_seats[index] = true
			return index
	return -1


func _release_seat(entry: Dictionary) -> void:
	if int(entry.seat) >= 0:
		_seats.erase(int(entry.seat))
		entry.seat = -1
