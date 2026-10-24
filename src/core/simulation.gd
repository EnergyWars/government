class_name Simulation
extends RefCounted

signal case_arrived(dept_id: String)
signal case_completed(dept_id: String, money: float, flawed: bool)
signal citizen_left(dept_id: String)
signal contraband_found(dept_id: String)
signal smuggling_missed(dept_id: String)
signal department_unlocked(dept_id: String)
signal event_started(event_id: String)
signal event_ended(event_id: String)
signal case_rejected(dept_id: String)
signal case_piped(from_key: String, to_key: String, dept_id: String)
signal employee_dozed(key: String, desk: int, rest_state: String)
signal kranz_called
signal sick_called(by_player: bool, key: String, desk: int)
signal kranz_ended(by_player: bool)
signal complaint_filed(overflow: bool)
signal complaint_shredded(by_player: bool)
signal employee_woke(key: String, desk: int, by_player: bool)

var state: GameState
var layout: WorldLayout
var _wake_clock := 0.0
var _pad_clock := 0.0


func _init(p_state: GameState) -> void:
	state = p_state
	layout = WorldLayout.get_default()


func tick(delta: float) -> void:
	state.play_time += delta
	_update_event(delta)
	_age_cases(delta)
	_spawn_citizens(delta)
	_update_moods(delta)
	_update_complaints(delta)
	_update_kranz(delta)
	_update_sickness(delta)
	_work_stations(delta)
	_update_player(delta)
	_update_runners(delta)
	_pneumatic_transport()


func _update_event(delta: float) -> void:
	if not state.event_id.is_empty():
		state.event_time_left -= delta
		if state.event_time_left <= 0.0:
			_end_event()
		return
	state.event_cooldown -= delta
	if state.event_cooldown > 0.0:
		return
	var candidates := eligible_events()
	start_event(candidates[state.rng.randi_range(0, candidates.size() - 1)])


func _end_event() -> void:
	var finished := state.event_id
	if finished == "authority_comparison" and state.event_choice == "prepare":
		state.add_reputation(GameConfig.EVENT_PREPARE_REPUTATION)
	state.event_id = ""
	state.event_scope = ""
	state.event_choice = ""
	state.event_time_left = 0.0
	state.event_cooldown = state.rng.randf_range(GameConfig.EVENT_MIN_COOLDOWN, GameConfig.EVENT_MAX_COOLDOWN)
	event_ended.emit(finished)


func resolve_event(choice: String) -> bool:
	if state.event_id.is_empty() or not state.event_choice.is_empty():
		return false
	var choices: Array = GameConfig.EVENTS[state.event_id].get("choices", [])
	if not choices.has(choice):
		return false
	match choice:
		"prepare":
			state.event_choice = choice
			state.event_time_left = GameConfig.EVENT_PREPARE_SECONDS
		"cancel":
			state.add_reputation(-GameConfig.EVENT_CANCEL_PENALTY)
			_end_event()
		_:
			state.event_choice = choice
			_end_event()
	return true


func eligible_events() -> Array[String]:
	var result: Array[String] = []
	for event_id in GameConfig.EVENTS:
		var event: Dictionary = GameConfig.EVENTS[event_id]
		if state.cases_completed < int(event.min_cases):
			continue
		if not event.department.is_empty() and not state.department(event.department).unlocked:
			continue
		if bool(event.get("requires_inspection", false)) and state.departments_using(GameConfig.INSPECTION).is_empty():
			continue
		result.append(event_id)
	return result


func start_event(event_id: String) -> void:
	var event: Dictionary = GameConfig.EVENTS[event_id]
	state.event_id = event_id
	state.event_choice = ""
	state.event_scope = str(event.get("scope", ""))
	if state.event_scope == "random":
		var unlocked := state.unlocked_departments()
		state.event_scope = unlocked[state.rng.randi_range(0, unlocked.size() - 1)].id
	state.event_time_left = Formulas.event_duration(state, event_id)
	if bool(event.get("backlog", false)):
		_add_backlog()
	if bool(event.get("big_case", false)):
		_add_big_case(str(event.department))
	event_started.emit(event_id)


func _add_backlog() -> void:
	var candidates: Array[Department] = []
	for dept in state.unlocked_departments():
		if not dept.is_customs():
			candidates.append(dept)
	var dept := candidates[state.rng.randi_range(0, candidates.size() - 1)]
	state.event_scope = dept.id
	var entry := state.station(GameConfig.department_station_keys(dept.id)[0])
	if entry == null:
		return
	for i in GameConfig.BACKLOG_CASES:
		if not entry.has_inbox_space(state.lobby_capacity()):
			return
		var case_file := create_case(dept)
		case_file.step = 1
		entry.inbox.append(case_file)


func _add_big_case(dept_id: String) -> void:
	var dept := state.department(dept_id)
	var entry := state.station(GameConfig.department_station_keys(dept_id)[0])
	if dept == null or entry == null:
		return
	var case_file := create_case(dept)
	case_file.complex = true
	case_file.big = true
	case_file.urgent = false
	case_file.invalid = false
	case_file.step = 1
	entry.inbox.append(case_file)


func _age_cases(delta: float) -> void:
	var limit := Formulas.patience(state)
	for key in state.stations:
		var station := state.stations[key]
		for case_file in station.inbox:
			case_file.age += delta
		for case_file in station.outbox:
			case_file.age += delta
		for job in station.jobs:
			if job != null:
				job.case_file.age += delta
		if not station.is_entry():
			continue
		var index := station.inbox.size() - 1
		while index >= 0:
			var waiting := station.inbox[index]
			waiting.waited += delta
			if waiting.waited > limit:
				station.inbox.remove_at(index)
				_lose_citizen(waiting.dept_id, GameConfig.REP_CITIZEN_LEFT)
			index -= 1
	for case_file in state.carried_cases():
		case_file.age += delta


func _spawn_citizens(delta: float) -> void:
	for dept in state.unlocked_departments():
		var interval := Formulas.arrival_interval(state, dept)
		dept.arrival_timer += delta
		while dept.arrival_timer >= interval:
			dept.arrival_timer -= interval
			spawn_case(dept)
		var index := dept.follow_ups.size() - 1
		while index >= 0:
			dept.follow_ups[index] -= delta
			if dept.follow_ups[index] <= 0.0:
				dept.follow_ups.remove_at(index)
				spawn_case(dept, true)
			index -= 1


func create_case(dept: Department, follow_up: bool = false) -> CaseFile:
	var config := dept.config()
	var case_file := CaseFile.new(dept.id)
	case_file.follow_up = follow_up
	case_file.complex = not follow_up and state.rng.randf() < float(config.complex_chance)
	case_file.urgent = state.rng.randf() < float(config.urgent_chance)
	var suspicion := 1.0
	if dept.is_customs():
		case_file.variant = GameConfig.CUSTOMS_VARIANTS[state.rng.randi_range(0, GameConfig.CUSTOMS_VARIANTS.size() - 1)]
		suspicion = float(GameConfig.CUSTOMS_VARIANT_SUSPICION[case_file.variant])
	case_file.suspicious = state.rng.randf() < float(config.suspicious_chance) * suspicion
	case_file.route = RouteBuilder.build(case_file)
	state.cases_spawned += 1
	case_file.invalid = not follow_up and not dept.is_customs() and Formulas.is_invalid_case(state, state.cases_spawned)
	return case_file


func spawn_case(dept: Department, follow_up: bool = false) -> CaseFile:
	var case_file := create_case(dept, follow_up)
	var entry := state.station(case_file.route[0])
	if entry != null and entry.has_inbox_space(state.lobby_capacity()):
		entry.inbox.append(case_file)
		case_arrived.emit(dept.id)
		return case_file
	_lose_citizen(dept.id, GameConfig.REP_TURNED_AWAY)
	return null


func _lose_citizen(dept_id: String, reputation_change: float) -> void:
	state.citizens_lost += 1
	state.add_reputation(reputation_change)
	citizen_left.emit(dept_id)


func _work_stations(delta: float) -> void:
	for key in state.ordered_station_keys():
		var station := state.station(key)
		for desk in station.jobs.size():
			if station.jobs[desk] == null and station.is_working(desk):
				start_job(station, desk)
			var job := station.jobs[desk]
			if job == null:
				continue
			if station.is_working(desk):
				job.progress += delta * Formulas.event_speed(state, station)
			if job.is_done():
				finish_job(station, desk)


func _update_moods(delta: float) -> void:
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		var rate := -1.0
		for desk in station.moods.size():
			if not station.is_staffed(desk):
				continue
			var mood := station.moods[desk]
			if mood.is_resting():
				mood.resting += delta
				if mood.resting >= Formulas.rest_limit(state, mood.state):
					wake_up(station, desk, false)
			elif station.jobs[desk] != null or not station.inbox.is_empty():
				if rate < 0.0:
					rate = Formulas.drowsiness_rate(state, station)
				mood.alert -= delta * rate
				if mood.alert <= 0.0:
					doze_off(station, desk)


func doze_off(station: Station, desk: int) -> bool:
	if station.machine or not station.is_staffed(desk) or station.moods[desk].is_resting():
		return false
	var rest_state := _roll_doze_state()
	var slot := -1
	if DeskMood.is_away_state(rest_state):
		slot = state.free_loo_slot() if rest_state == DeskMood.LOO else state.free_kitchen_slot()
		if slot < 0:
			rest_state = DeskMood.ASLEEP
	station.moods[desk].rest(rest_state, slot)
	employee_dozed.emit(station.key, desk, rest_state)
	return true


func _roll_doze_state() -> String:
	var roll := state.rng.randf()
	var total := 0.0
	var weights := Formulas.doze_weights(state)
	for rest_state: String in weights:
		total += float(weights[rest_state])
		if roll < total:
			return rest_state
	return DeskMood.ASLEEP


func wake_up(station: Station, desk: int, by_player: bool) -> bool:
	var mood := station.moods[desk]
	if not mood.is_resting():
		return false
	mood.wake(Formulas.wake_alert(state, mood.state))
	if by_player:
		state.wakes += 1
	employee_woke.emit(station.key, desk, by_player)
	return true


func _update_complaints(delta: float) -> void:
	if state.cases_completed >= GameConfig.COMPLAINT_MIN_CASES:
		state.complaint_timer -= delta
		if state.complaint_timer <= 0.0:
			state.complaint_timer = GameConfig.COMPLAINT_INTERVAL * state.rng.randf_range(0.7, 1.3)
			file_complaint()
	if state.complaints > 0:
		state.add_reputation(-state.complaints * GameConfig.COMPLAINT_DRAIN * delta)
	var delay: float = GameConfig.SHREDDER_DELAYS[state.research_level("shredder_service")]
	if delay > 0.0 and (state.complaints > 0 or state.rejects_waiting() > 0):
		state.shred_timer += delta
		if state.shred_timer >= delay:
			state.shred_timer = 0.0
			if state.complaints > 0:
				shred_complaints(1, false)
			else:
				shred_rejects(1, false)
	else:
		state.shred_timer = 0.0
	var player := state.player
	player.complaint_timer -= delta
	if player.complaint_timer <= 0.0 and move_complaints():
		player.complaint_timer = GameConfig.COMPLAINT_TRANSFER_INTERVAL


func file_complaint() -> void:
	if state.complaints >= GameConfig.COMPLAINT_CAP:
		state.add_reputation(-GameConfig.COMPLAINT_OVERFLOW_PENALTY)
		complaint_filed.emit(true)
		return
	state.complaints += 1
	complaint_filed.emit(false)


func shred_complaints(count: int, by_player: bool) -> int:
	var source := state.player.complaints if by_player else state.complaints
	var shredded := mini(count, source)
	if shredded <= 0:
		return 0
	if by_player:
		state.player.complaints -= shredded
	else:
		state.complaints -= shredded
	state.complaints_shredded += shredded
	state.earn(GameConfig.COMPLAINT_REWARD * shredded)
	state.add_reputation(GameConfig.COMPLAINT_REPUTATION * shredded)
	complaint_shredded.emit(by_player)
	return shredded


func shred_rejects(count: int, by_player: bool) -> int:
	var shredded := 0
	if by_player:
		shredded = mini(count, state.player.rejects)
		state.player.rejects -= shredded
	else:
		for key in state.ordered_station_keys():
			var station := state.station(key)
			while shredded < count and station.rejects > 0:
				station.rejects -= 1
				shredded += 1
	if shredded <= 0:
		return 0
	state.earn(GameConfig.REJECT_SHRED_REWARD * shredded)
	complaint_shredded.emit(by_player)
	return shredded


func move_complaints() -> bool:
	var player := state.player
	if layout.near(player.position, layout.shredder_point()):
		if player.complaints > 0:
			return shred_complaints(1, true) > 0
		if player.rejects > 0:
			return shred_rejects(1, true) > 0
	var carried := player.complaints + player.rejects
	if carried >= Formulas.carry_capacity(state):
		return false
	if state.complaints > 0 and layout.near(player.position, layout.complaint_desk_point()):
		state.complaints -= 1
		player.complaints += 1
		return true
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.rejects > 0 and layout.near(player.position, layout.reject_point(key)):
			station.rejects -= 1
			player.rejects += 1
			return true
	return false


func _update_sickness(delta: float) -> void:
	state.sick_timer -= delta
	if state.sick_timer <= 0.0:
		state.sick_timer = state.rng.randf_range(GameConfig.SICK_MIN_INTERVAL, GameConfig.SICK_MAX_INTERVAL)
		report_sick()
	var near_phone := layout.near(state.player.position, layout.phone_point())
	var sick := state.sick_count() if state.hr > 0 or near_phone else 0
	if sick > 0 and state.hr > 0:
		state.hr_timer += delta * state.hr
		if state.hr_timer >= GameConfig.HR_CALL_SECONDS:
			state.hr_timer = 0.0
			call_in_sick(false)
	else:
		state.hr_timer = 0.0
	var player := state.player
	if sick > 0 and near_phone:
		player.call_progress += delta
		if player.call_progress >= GameConfig.CALL_TIME:
			player.call_progress = 0.0
			call_in_sick(true)
	else:
		player.call_progress = 0.0


func report_sick() -> bool:
	var candidates: Array = []
	var staffed := 0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			if not station.is_staffed(desk):
				continue
			staffed += 1
			if not station.moods[desk].is_resting():
				candidates.append([station, desk])
	if staffed < GameConfig.SICK_MIN_STAFF or candidates.is_empty():
		return false
	var pick: Array = candidates[state.rng.randi_range(0, candidates.size() - 1)]
	var station: Station = pick[0]
	station.moods[pick[1]].rest(DeskMood.SICK)
	employee_dozed.emit(station.key, pick[1], DeskMood.SICK)
	return true


func call_in_sick(by_player: bool) -> bool:
	var best_station: Station = null
	var best_desk := -1
	var longest := -1.0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if station.is_staffed(desk) and mood.is_sick() and mood.resting > longest:
				longest = mood.resting
				best_station = station
				best_desk = desk
	if best_station == null:
		return false
	wake_up(best_station, best_desk, by_player)
	state.calls_made += 1
	sick_called.emit(by_player, best_station.key, best_desk)
	return true


func _update_kranz(delta: float) -> void:
	if state.kranz:
		if _chatter_count() == 0:
			_finish_kranz(false)
		elif layout.near(state.player.position, layout.kranz_point()):
			state.kranz_progress += delta
			if state.kranz_progress >= GameConfig.KRANZ_END_TIME:
				end_kranz(true)
		else:
			state.kranz_progress = 0.0
		return
	state.kranz_timer -= delta
	if state.kranz_timer <= 0.0 and not call_kranz():
		state.kranz_timer = GameConfig.KRANZ_RETRY_SECONDS


func _chatter_count() -> int:
	var count := 0
	for key in state.ordered_station_keys():
		for mood in state.station(key).moods:
			if mood.state == DeskMood.CHAT:
				count += 1
	return count


func call_kranz() -> bool:
	var candidates: Array = []
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			if station.is_staffed(desk) and not station.moods[desk].is_resting():
				candidates.append([station, desk])
	if candidates.size() < GameConfig.KRANZ_MIN_PARTICIPANTS:
		return false
	var joined := 0
	while joined < GameConfig.KRANZ_SIZE and not candidates.is_empty():
		var slot := state.free_kitchen_slot(GameConfig.KITCHEN_TABLE_SLOT)
		if slot < 0:
			break
		var pick: Array = candidates.pop_at(state.rng.randi_range(0, candidates.size() - 1))
		var station: Station = pick[0]
		station.moods[pick[1]].rest(DeskMood.CHAT, slot)
		employee_dozed.emit(station.key, pick[1], DeskMood.CHAT)
		joined += 1
	if joined < GameConfig.KRANZ_MIN_PARTICIPANTS:
		return false
	state.kranz = true
	state.kranz_progress = 0.0
	kranz_called.emit()
	return true


func end_kranz(by_player: bool) -> void:
	for key in state.ordered_station_keys():
		var station := state.station(key)
		for desk in station.moods.size():
			if station.moods[desk].state == DeskMood.CHAT and station.is_staffed(desk):
				wake_up(station, desk, by_player)
	_finish_kranz(by_player)


func _finish_kranz(by_player: bool) -> void:
	state.kranz = false
	state.kranz_progress = 0.0
	state.kranz_timer = state.rng.randf_range(GameConfig.KRANZ_MIN_INTERVAL, GameConfig.KRANZ_MAX_INTERVAL)
	kranz_ended.emit(by_player)


func _wake_nearby(delta: float) -> void:
	var position := state.player.position
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if not mood.needs_help() or not station.is_staffed(desk):
				continue
			var spot := layout.slot_point(mood.slot) if mood.is_away() else layout.desk_position(key, desk)
			if mood.state == DeskMood.SLOW:
				if layout.near(position, spot):
					mood.resting += delta * (GameConfig.DRIVE_FACTOR - 1.0)
			elif layout.near(position, spot):
				mood.wake_progress += delta
				if mood.wake_progress >= Formulas.wake_time(mood.state):
					wake_up(station, desk, true)
			else:
				mood.wake_progress = 0.0


func start_job(station: Station, desk: int) -> bool:
	if station.jobs[desk] != null:
		return false
	var for_specialist := station.is_specialist_desk(desk)
	var case_file := station.take_next_case(_prioritize_for(station), for_specialist)
	if case_file == null:
		return false
	station.jobs[desk] = StationJob.new(case_file, Formulas.required_time(state, station, case_file, for_specialist), for_specialist)
	return true


func _prioritize_for(station: Station) -> bool:
	var dept := state.department(station.dept_id)
	if dept == null and not station.inbox.is_empty():
		dept = state.department(station.inbox[0].dept_id)
	return dept == null or dept.prioritize_urgent


func finish_job(station: Station, desk: int) -> bool:
	var job := station.jobs[desk]
	if job == null or not job.is_done():
		return false
	var case_file := job.case_file
	if case_file.invalid and station.has_reject_pile() and station.dept_id == case_file.dept_id:
		if not station.has_reject_space():
			return false
		station.jobs[desk] = null
		station.rejects += 1
		_reject_case(case_file)
		return true
	if not case_file.is_final_step() and not station.has_outbox_space():
		return false
	station.jobs[desk] = null
	apply_station_effect(station, case_file, job.by_specialist)
	if case_file.is_final_step():
		complete_case(case_file)
	else:
		station.outbox.append(case_file)
	return true


func apply_station_effect(station: Station, case_file: CaseFile, by_specialist: bool) -> void:
	var dept := state.department(case_file.dept_id)
	match station.kind:
		"review":
			if station.dept_id != case_file.dept_id:
				return
			case_file.flawed = state.rng.randf() < Formulas.error_chance(state, dept, by_specialist)
			if dept.is_customs():
				case_file.flagged = case_file.suspicious and state.rng.randf() < Formulas.flag_chance(station)
				if not dept.scan_all and not case_file.flagged:
					case_file.remove_from_route("customs/signature")
		"signature":
			case_file.produced = true
			if dept.is_customs():
				case_file.scanned = true
				if case_file.suspicious and state.rng.randf() < GameConfig.CONTRABAND_CHANCE:
					case_file.contraband = true
					case_file.insert_before(GameConfig.INSPECTION, "customs/clearance")
					contraband_found.emit(dept.id)


func _reject_case(case_file: CaseFile) -> void:
	var dept := state.department(case_file.dept_id)
	state.cases_rejected += 1
	state.earn(float(dept.config().reward) * Formulas.reputation_multiplier(state) * GameConfig.REJECT_FEE_FACTOR)
	case_rejected.emit(dept.id)


func complete_case(case_file: CaseFile) -> void:
	var dept := state.department(case_file.dept_id)
	var smuggled := dept.is_customs() and case_file.suspicious and not case_file.scanned and state.rng.randf() < GameConfig.CONTRABAND_CHANCE
	var outcome := Formulas.case_outcome(state, case_file, smuggled)
	state.earn(outcome.money)
	state.add_reputation(outcome.reputation)
	state.cases_completed += 1
	if case_file.flawed:
		state.cases_flawed += 1
	if case_file.contraband:
		state.contraband_seized += 1
	if smuggled:
		smuggling_missed.emit(dept.id)
	if bool(dept.config().follow_up) and not case_file.follow_up:
		dept.follow_ups.append(state.rng.randf_range(GameConfig.FOLLOW_UP_DELAY_MIN, GameConfig.FOLLOW_UP_DELAY_MAX))
	case_completed.emit(case_file.dept_id, outcome.money, case_file.flawed)


func move_case(from: Station, case_index: int) -> bool:
	var case_file := from.outbox[case_index]
	var target := state.station(case_file.next_key())
	if target == null or not target.has_inbox_space(state.lobby_capacity()):
		return false
	from.outbox.remove_at(case_index)
	deliver(case_file, target)
	return true


func deliver(case_file: CaseFile, target: Station) -> void:
	case_file.step += 1
	target.inbox.append(case_file)


func _update_player(delta: float) -> void:
	var player := state.player
	if player.input.length_squared() > 0.0:
		player.position = layout.clamp_to_world(player.position + player.input.limit_length(1.0) * GameConfig.PLAYER_SPEED * delta)
	player.transfer_timer -= delta
	if player.transfer_timer <= 0.0 and player_transfer():
		player.transfer_timer = GameConfig.TRANSFER_INTERVAL
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.needs_manual_work() and layout.near(player.position, layout.work_point(key)):
			work(station, Formulas.work_power(state) * delta)
	_wake_clock += delta
	if _wake_clock >= GameConfig.WAKE_CHECK_INTERVAL:
		_wake_nearby(_wake_clock)
		_wake_clock = 0.0
	_pad_clock += delta
	if _pad_clock >= GameConfig.WAKE_CHECK_INTERVAL:
		_update_pad(_pad_clock)
		_pad_clock = 0.0


func player_transfer() -> bool:
	var player := state.player
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.is_entry() or not layout.near(player.position, layout.input_point(key)):
			continue
		if not station.has_inbox_space(state.lobby_capacity()):
			continue
		var matching := player.items_for(key)
		if not matching.is_empty():
			player.items.erase(matching[0])
			deliver(matching[0], station)
			return true
	if player.items.size() >= Formulas.carry_capacity(state):
		return false
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.outbox.is_empty() or not layout.near(player.position, layout.output_point(key)):
			continue
		player.items.append(station.outbox.pop_front())
		return true
	return false


func work(station: Station, power: float) -> bool:
	var worked := false
	for desk in range(station.staff, station.desks):
		if station.jobs[desk] == null:
			start_job(station, desk)
		var job := station.jobs[desk]
		if job != null and not job.is_done():
			job.progress += power
			worked = true
	return worked


func _update_pad(delta: float) -> void:
	var player := state.player
	var target := Progression.next_locked_department(state)
	if target.is_empty() or not layout.near(player.position, layout.pad_point(target)) or not Progression.unlock_block_reason(state, target).is_empty():
		player.pad_dept = ""
		player.pad_progress = 0.0
		return
	player.pad_dept = target
	player.pad_progress += delta
	if player.pad_progress >= GameConfig.PAD_TIME:
		player.pad_progress = 0.0
		player.pad_dept = ""
		unlock(target)


func unlock(dept_id: String) -> bool:
	if not Progression.unlock_block_reason(state, dept_id).is_empty():
		return false
	state.spend(float(GameConfig.department(dept_id).unlock_cost))
	state.unlock_department(dept_id)
	department_unlocked.emit(dept_id)
	return true


func _update_runners(delta: float) -> void:
	if state.has_research("pneumatic_tubes"):
		for runner in state.runners:
			if runner.items.is_empty():
				runner.clear_task()
				runner.move_towards(layout.runner_home(), GameConfig.RUNNER_SPEED, delta)
			else:
				_runner_to_target(runner, delta)
		return
	for runner in state.runners:
		match runner.task:
			Runner.Task.IDLE:
				if not assign_runner(runner):
					runner.move_towards(layout.runner_home(), GameConfig.RUNNER_SPEED * 0.5, delta)
			Runner.Task.TO_SOURCE:
				_runner_to_source(runner, delta)
			Runner.Task.TO_TARGET:
				_runner_to_target(runner, delta)


func reserved_for(source: String, target: String) -> int:
	var count := 0
	for runner in state.runners:
		if runner.task == Runner.Task.TO_SOURCE and runner.source == source and runner.target == target:
			count += runner.reserved
	return count


func assign_runner(runner: Runner) -> bool:
	var best_score := 0.0
	var best_source := ""
	var best_target := ""
	var best_amount := 0
	var capacity := Formulas.runner_capacity(state)
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.outbox.is_empty():
			continue
		var counts := {}
		for case_file in station.outbox:
			counts[case_file.next_key()] = int(counts.get(case_file.next_key(), 0)) + 1
		for target_key: String in counts:
			var target := state.station(target_key)
			if target == null or not target.has_inbox_space(state.lobby_capacity()):
				continue
			var available: int = counts[target_key] - reserved_for(key, target_key)
			if available <= 0:
				continue
			var amount := mini(available, capacity)
			var source_point := layout.output_point(key)
			var distance := runner.position.distance_to(source_point) + source_point.distance_to(layout.input_point(target_key)) + 100.0
			var score := amount / distance
			if score > best_score:
				best_score = score
				best_source = key
				best_target = target_key
				best_amount = amount
	if best_source.is_empty():
		return false
	runner.task = Runner.Task.TO_SOURCE
	runner.source = best_source
	runner.target = best_target
	runner.reserved = best_amount
	return true


func _runner_to_source(runner: Runner, delta: float) -> void:
	if not runner.move_towards(layout.output_point(runner.source), GameConfig.RUNNER_SPEED, delta):
		return
	var station := state.station(runner.source)
	var index := 0
	while index < station.outbox.size() and runner.items.size() < runner.reserved:
		if station.outbox[index].next_key() == runner.target:
			runner.items.append(station.outbox[index])
			station.outbox.remove_at(index)
		else:
			index += 1
	if runner.items.is_empty():
		runner.clear_task()
		return
	runner.task = Runner.Task.TO_TARGET
	runner.reserved = 0


func _runner_to_target(runner: Runner, delta: float) -> void:
	if not runner.move_towards(layout.input_point(runner.target), GameConfig.RUNNER_SPEED, delta):
		return
	var target := state.station(runner.target)
	if target == null:
		return
	while not runner.items.is_empty() and target.has_inbox_space(state.lobby_capacity()):
		deliver(runner.items.pop_front(), target)
	if runner.items.is_empty():
		runner.clear_task()


func _pneumatic_transport() -> void:
	if not state.has_research("pneumatic_tubes"):
		return
	for key in state.ordered_station_keys():
		var station := state.station(key)
		var index := 0
		while index < station.outbox.size():
			var case_file := station.outbox[index]
			var target_key := case_file.next_key()
			if move_case(station, index):
				case_piped.emit(key, target_key, case_file.dept_id)
			else:
				index += 1
