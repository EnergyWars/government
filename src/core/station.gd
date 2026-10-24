class_name Station
extends RefCounted

var key: String
var kind: String
var dept_id: String
var machine: bool
var desks := 1
var staff := 0
var specialists := 0
var level := 1
var inbox: Array[CaseFile] = []
var outbox: Array[CaseFile] = []
var jobs: Array[StationJob] = [null]
var moods: Array[DeskMood] = [DeskMood.new()]
var rejects := 0


func _init(p_key: String = "") -> void:
	key = p_key
	kind = GameConfig.station_kind_of(p_key)
	dept_id = GameConfig.station_dept(p_key)
	machine = GameConfig.is_machine(p_key)
	if machine:
		staff = desks


func is_shared() -> bool:
	return dept_id.is_empty()


func is_entry() -> bool:
	return kind == "reception" or kind == "dock"


func is_final() -> bool:
	return kind == "counter" or kind == "clearance"


func supports_specialists() -> bool:
	return kind == "review"


func inbox_capacity(lobby: int) -> int:
	if is_entry():
		return lobby
	return GameConfig.INBOX_BASE + GameConfig.INBOX_PER_DESK * desks


func outbox_capacity() -> int:
	return GameConfig.OUTBOX_BASE + GameConfig.OUTBOX_PER_DESK * desks


func has_inbox_space(lobby: int) -> bool:
	return inbox.size() < inbox_capacity(lobby)


func has_outbox_space() -> bool:
	return outbox.size() < outbox_capacity()


func has_reject_pile() -> bool:
	return kind == "review" and not dept_id.is_empty() and not GameConfig.is_customs(dept_id)


func has_reject_space() -> bool:
	return rejects < GameConfig.REJECT_CAPACITY


func is_specialist_desk(desk: int) -> bool:
	return desk >= desks


func is_staffed(desk: int) -> bool:
	return desk < staff or is_specialist_desk(desk)


func is_working(desk: int) -> bool:
	return is_staffed(desk) and not moods[desk].is_resting()


func resting_count() -> int:
	var count := 0
	for desk in moods.size():
		if is_staffed(desk) and (moods[desk].needs_help() or moods[desk].is_sick()):
			count += 1
	return count


func workers() -> int:
	return staff + specialists


func add_desk() -> void:
	jobs.insert(desks, null)
	moods.insert(desks, DeskMood.new())
	desks += 1
	if machine:
		staff = desks


func add_specialist() -> void:
	specialists += 1
	jobs.append(null)
	moods.append(DeskMood.new())


func active_jobs() -> int:
	var count := 0
	for job in jobs:
		if job != null:
			count += 1
	return count


func unstaffed_desks_busy() -> bool:
	for desk in range(staff, desks):
		if jobs[desk] != null:
			return true
	return false


func needs_manual_work() -> bool:
	return staff < desks and (not inbox.is_empty() or unstaffed_desks_busy())


func take_next_case(prioritize_urgent: bool, for_specialist: bool) -> CaseFile:
	var index := _pick(prioritize_urgent, for_specialist)
	if index < 0:
		return null
	var case_file := inbox[index]
	inbox.remove_at(index)
	return case_file


func _pick(prioritize_urgent: bool, for_specialist: bool) -> int:
	var best := -1
	var best_score := -1
	for i in inbox.size():
		var case_file := inbox[i]
		if specialists > 0 and not for_specialist and case_file.complex:
			continue
		var score := 0
		if for_specialist and case_file.complex:
			score += 2
		if prioritize_urgent and case_file.urgent:
			score += 1
		if score > best_score:
			best = i
			best_score = score
	return best


func all_cases() -> Array[CaseFile]:
	var cases: Array[CaseFile] = []
	cases.append_array(inbox)
	cases.append_array(outbox)
	for job in jobs:
		if job != null:
			cases.append(job.case_file)
	return cases


func to_dict() -> Dictionary:
	var job_data: Array = []
	for job in jobs:
		job_data.append(null if job == null else job.to_dict())
	return {
		"key": key,
		"desks": desks,
		"staff": staff,
		"specialists": specialists,
		"level": level,
		"rejects": rejects,
		"inbox": inbox.map(func(c: CaseFile) -> Dictionary: return c.to_dict()),
		"outbox": outbox.map(func(c: CaseFile) -> Dictionary: return c.to_dict()),
		"jobs": job_data,
		"moods": moods.map(func(m: DeskMood) -> Dictionary: return m.to_dict()),
	}


static func from_dict(data: Dictionary) -> Station:
	var station := Station.new(str(data.get("key", "")))
	station.desks = clampi(int(data.get("desks", 1)), 1, 99)
	station.staff = station.desks if station.machine else clampi(int(data.get("staff", 0)), 0, station.desks)
	station.specialists = clampi(int(data.get("specialists", 0)), 0, GameConfig.MAX_SPECIALISTS) if station.supports_specialists() else 0
	station.level = clampi(int(data.get("level", 1)), 1, GameConfig.MAX_STATION_LEVEL)
	station.rejects = clampi(int(data.get("rejects", 0)), 0, GameConfig.REJECT_CAPACITY) if station.has_reject_pile() else 0
	for entry in data.get("inbox", []):
		station.inbox.append(CaseFile.from_dict(entry))
	for entry in data.get("outbox", []):
		station.outbox.append(CaseFile.from_dict(entry))
	station.jobs.clear()
	station.moods.clear()
	var job_data: Array = data.get("jobs", [])
	var mood_data: Array = data.get("moods", [])
	for i in station.desks + station.specialists:
		var entry: Variant = job_data[i] if i < job_data.size() else null
		station.jobs.append(StationJob.from_dict(entry) if entry is Dictionary else null)
		station.moods.append(DeskMood.from_dict(mood_data[i] if i < mood_data.size() else null))
	return station
