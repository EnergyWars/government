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
var storage_level := 0
var rush := 0.0


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
	return kind == "reception" or kind == "dock" or kind == "mailroom"


func is_mailroom() -> bool:
	return kind == "mailroom"


func is_final() -> bool:
	return kind == "counter" or kind == "clearance"


func supports_specialists() -> bool:
	return kind == "review"


func storage_capacity() -> int:
	return GameConfig.MAIL_STORAGE_BASE + GameConfig.MAIL_STORAGE_PER_LEVEL * storage_level


func inbox_capacity(lobby: int) -> int:
	if is_mailroom():
		return storage_capacity()
	if is_entry():
		return lobby
	return GameConfig.INBOX_BASE + GameConfig.INBOX_PER_DESK * desks


func is_swamped(lobby: int) -> bool:
	if is_entry():
		return false
	return inbox.size() >= ceili(inbox_capacity(lobby) * GameConfig.SWAMPED_SHARE)


func outbox_capacity() -> int:
	return GameConfig.OUTBOX_BASE + GameConfig.OUTBOX_PER_DESK * desks


func is_backlogged() -> bool:
	return outbox.size() >= ceili(outbox_capacity() * GameConfig.TUBE_OVERFLOW_SHARE)


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


func can_cover(desk: int) -> bool:
	return not machine and is_staffed(desk) and moods[desk].is_absent() and (jobs[desk] != null or not inbox.is_empty())


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


func can_be_helped() -> bool:
	if machine:
		return false
	var has_job := false
	var has_worker := false
	for desk in mini(staff, desks):
		if is_working(desk):
			has_worker = true
			has_job = has_job or jobs[desk] != null
	return has_worker and (has_job or not inbox.is_empty())


func needs_help() -> bool:
	return can_be_helped() and inbox.size() >= GameConfig.HELP_BACKLOG


func take_next_case(prioritize_urgent: bool, for_specialist: bool, blocked_targets: Array[String] = []) -> CaseFile:
	var index := _pick(prioritize_urgent, for_specialist, blocked_targets)
	if index < 0:
		return null
	var case_file := inbox[index]
	inbox.remove_at(index)
	return case_file


func _pick(prioritize_urgent: bool, for_specialist: bool, blocked_targets: Array[String]) -> int:
	var best := -1
	var best_score := -1
	for i in inbox.size():
		var case_file := inbox[i]
		if specialists > 0 and not for_specialist and case_file.complex:
			continue
		if blocked_targets.has(case_file.next_key()):
			continue
		var score := 0
		if not case_file.mail:
			score += GameConfig.MAIL_CITIZEN_PRIORITY
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
		"storage_level": storage_level,
		"rush": rush,
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
	station.storage_level = clampi(int(data.get("storage_level", 0)), 0, GameConfig.MAIL_STORAGE_MAX_LEVEL) if station.is_mailroom() else 0
	station.rush = clampf(float(data.get("rush", 0.0)), 0.0, GameConfig.UPGRADE_RUSH_SECONDS)
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
