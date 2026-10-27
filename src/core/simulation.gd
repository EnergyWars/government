class_name Simulation
extends RefCounted

signal case_arrived(dept_id: String)
signal case_completed(dept_id: String, money: float, flawed: bool)
signal citizen_left(dept_id: String)
signal citizen_raged(dept_id: String, point: Vector2, line: int)
signal contraband_found(dept_id: String)
signal smuggling_missed(dept_id: String)
signal department_unlocked(dept_id: String)
signal department_ranked_up(dept_id: String, rank: int)
signal event_started(event_id: String)
signal event_ended(event_id: String)
signal case_rejected(dept_id: String)
signal case_shredded(dept_id: String)
signal case_piped(from_key: String, to_key: String, dept_id: String)
signal employee_dozed(key: String, desk: int, rest_state: String)
signal kranz_called
signal sick_called(by_player: bool, key: String, desk: int)
signal sick_call_ringing(key: String, desk: int)
signal sick_call_answered(by_player: bool, key: String, desk: int, persuaded: bool)
signal sick_call_missed(key: String, desk: int)
signal kranz_ended(by_player: bool)
signal complaint_filed(overflow: bool)
signal complaint_shredded(by_player: bool)
signal dept_shredded(dept_id: String)
signal review_posted(review: Review)
signal review_removed(outcome: String)
signal employee_woke(key: String, desk: int, by_player: bool)
signal employee_returned(key: String, desk: int)
signal employee_recalled(key: String, desk: int)
signal visitor_arrived(angry: bool)
signal visitor_stopped(angry: bool)
signal visitor_respected(slot: int)
signal outputs_jammed(key: String, count: int)
signal intern_broke_down(slot: int)
signal intern_recovered(slot: int, by_player: bool)
signal coffee_served(key: String, desk: int)
signal dispute_started(kind: String, dept_id: String)
signal dispute_ended(kind: String, dept_id: String, by_player: bool)
signal bonus_left(key: String, desk: int, tier: int)
signal sick_avoided(key: String, desk: int)
signal dispute_calmed(dept_id: String)
signal mail_delivered(count: int, dropped: int, returned: int)
signal mail_answered(dept_id: String, money: float)
signal mail_picked_up
signal applications_bundled(dept_id: String, extras: int)
signal form_missing(dept_id: String)
signal onboarding_completed(dept_id: String)
signal ticket_drawn(number: int)
signal ticket_called(number: int)
signal ruckus_started(desk: int)
signal ruckus_calmed(desk: int)
signal lunch_called(count: int)
signal complaint_absorbed(slot: int)
signal gift_arrived(kind: int)
signal gift_claimed(kind: int, money: float)

var state: GameState
var layout: WorldLayout
var _wake_clock := 0.0
var _seat_layout := Vector2i(-1, -1)
var _pad_clock := 0.0
var _shredder_rooms: Array[String] = []
var _shredder_points: Array[Vector2] = []
var _reject_detours: Dictionary = {}


func _init(p_state: GameState) -> void:
	state = p_state
	layout = WorldLayout.get_default()
	state.production.begin(state.play_time)


func tick(delta: float) -> void:
	state.play_time += delta
	state.refill_loss_budget(delta)
	state.advance_boosts(delta)
	_update_event(delta)
	_age_cases(delta)
	_spawn_citizens(delta)
	_update_tickets(delta)
	_update_mail(delta)
	_update_moods(delta)
	_update_complaints(delta)
	_update_visitors(delta)
	_update_intern(delta)
	_update_coffee_interns(delta)
	_update_disputes(delta)
	_update_ruckus(delta)
	_update_kranz(delta)
	_update_lunch(delta)
	_update_gift(delta)
	_update_sickness(delta)
	_work_stations(delta)
	_update_player(delta)
	_update_runners(delta)
	_update_collectors(delta)
	_update_dept_shredders(delta)
	_pneumatic_transport(delta)
	state.income.advance(delta, state.money_earned)


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
	if candidates.is_empty():
		state.event_cooldown = GameConfig.EVENT_MIN_COOLDOWN
		return
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


func _age_all(cases: Array[CaseFile], delta: float) -> void:
	for case_file in cases:
		case_file.age += delta


func _age_cases(delta: float) -> void:
	var frozen := state.is_boost_active("mayor_speech")
	for key in state.stations:
		var station := state.stations[key]
		for case_file in station.inbox:
			case_file.age += delta
		for case_file in station.outbox:
			case_file.age += delta
		for job in station.jobs:
			if job != null:
				job.case_file.age += delta
		if station.kind != "dock" or frozen:
			continue
		var index := station.inbox.size() - 1
		while index >= 0:
			var waiting := station.inbox[index]
			waiting.waited += delta
			if waiting.waited > GameConfig.BASE_PATIENCE:
				station.inbox.remove_at(index)
				_lose_citizen(waiting.dept_id, GameConfig.REP_CITIZEN_LEFT)
				complain_after_leaving(GameConfig.LEAVE_COMPLAINT_CHANCE, false)
			index -= 1
	_age_all(state.player.items, delta)
	for runner in state.runners:
		_age_all(runner.items, delta)
	for parcel in state.tube_parcels:
		parcel.case_file.age += delta


func complain_after_leaving(chance: float, angry: bool) -> bool:
	if state.cases_completed < GameConfig.COMPLAINT_MIN_CASES or state.leave_complaint_cooldown > 0.0:
		return false
	if state.life_rng.randf() >= chance:
		return false
	state.leave_complaint_cooldown = GameConfig.LEAVE_COMPLAINT_COOLDOWN
	citizen_complains(angry)
	return true


func citizen_complains(angry: bool) -> void:
	if spawn_visitor(angry, true) == null:
		submit_complaint()


func _spawn_citizens(delta: float) -> void:
	var interval := Formulas.arrival_interval(state)
	for dept in state.unlocked_departments():
		for index in dept.follow_ups.size():
			dept.follow_ups[index] = maxf(0.0, dept.follow_ups[index] - delta)
		dept.arrival_timer += delta
		while dept.arrival_timer >= interval:
			dept.arrival_timer -= interval
			spawn_case(dept, _take_follow_up(dept))


func _take_follow_up(dept: Department) -> bool:
	for index in dept.follow_ups.size():
		if dept.follow_ups[index] <= 0.0:
			dept.follow_ups.remove_at(index)
			return true
	return false


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
	state.production.record(ProductionStats.ARRIVED, dept.id, state.play_time)
	if not needs_ticket(case_file):
		var entry := state.station(case_file.route[0]) if not case_file.route.is_empty() else null
		if entry != null and entry.has_inbox_space(state.lobby_capacity()):
			entry.inbox.append(case_file)
			case_arrived.emit(dept.id)
			return case_file
		_walk_out(dept.id)
		return null
	var machine := state.shortest_line()
	if machine < 0:
		_walk_out(dept.id)
		return null
	if not follow_up:
		case_file.extras = roll_extras(dept)
	case_file.phase = CaseFile.Phase.LINE
	case_file.machine = machine
	case_file.line_slot = state.line_length(machine)
	case_file.spot = layout.door_in()
	_walk_to(case_file, layout.ticket_line_point(machine, case_file.line_slot))
	state.ticket_line.append(case_file)
	state.citizens.append(case_file)
	case_arrived.emit(dept.id)
	return case_file


func _walk_out(dept_id: String) -> void:
	_lose_citizen(dept_id, GameConfig.REP_WALKED_OUT)
	state.walkouts += 1
	citizen_complains(true)


func needs_ticket(case_file: CaseFile) -> bool:
	return case_file.takes_seat() and not case_file.route.is_empty() and case_file.route[0] == GameConfig.RECEPTION


func _walk_time(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to) / GameConfig.CITIZEN_SPEED


func _walk_to(citizen: CaseFile, point: Vector2) -> void:
	citizen.walk += _walk_time(citizen.spot, point)
	citizen.spot = point


func _update_citizens(delta: float) -> void:
	var frozen := state.is_boost_active("mayor_speech")
	var index := state.citizens.size() - 1
	while index >= 0:
		var citizen := state.citizens[index]
		if citizen.phase == CaseFile.Phase.LINE or citizen.phase == CaseFile.Phase.WAITING:
			citizen.age += delta
		var waiting := Formulas.is_citizen_waiting(citizen)
		citizen.walk = maxf(0.0, citizen.walk - delta)
		if waiting and not frozen:
			citizen.waited += delta
			if citizen.waited >= Formulas.citizen_patience(citizen):
				give_up(citizen)
		index -= 1


func give_up(citizen: CaseFile) -> void:
	var key := GameConfig.COUNTER if citizen.waits_for_pickup() else GameConfig.RECEPTION
	match citizen.phase:
		CaseFile.Phase.LINE:
			state.ticket_line.erase(citizen)
			_close_line(citizen.machine)
		CaseFile.Phase.CALLED:
			_station_inbox_erase(GameConfig.RECEPTION, citizen)
		CaseFile.Phase.CALLED_DOC:
			_station_inbox_erase(GameConfig.COUNTER, citizen)
		CaseFile.Phase.WAITING_DOC, CaseFile.Phase.SERVED, CaseFile.Phase.CALLED_PHOTO, CaseFile.Phase.PHOTO:
			_abandon_file(citizen)
	if citizen.ticket > 0:
		state.tickets_lapsed += 1
	var point := citizen.spot
	citizen.raged = true
	_release_citizen(citizen)
	_pile_reject(key)
	_record_loss(citizen.dept_id, GameConfig.REP_CITIZEN_LEFT)
	citizen_raged.emit(citizen.dept_id, point, state.life_rng.randi_range(0, GameConfig.RAGE_LINES - 1))
	if spawn_visitor(true, true, point, GameConfig.RAGE_SECONDS) == null:
		submit_complaint()


func _pile_reject(key: String) -> void:
	var station := state.station(key)
	if station != null and station.has_reject_pile() and station.has_reject_space():
		station.rejects += 1


func _station_inbox_erase(key: String, case_file: CaseFile) -> void:
	var station := state.station(key)
	if station != null:
		station.inbox.erase(case_file)


func _abandon_file(case_file: CaseFile) -> void:
	case_file.abandoned = true
	var station := state.station(case_file.current_key())
	if station == null:
		return
	if station.inbox.has(case_file):
		station.inbox.erase(case_file)
	elif station.outbox.has(case_file):
		station.outbox.erase(case_file)


func _release_citizen(citizen: CaseFile) -> void:
	state.citizens.erase(citizen)
	citizen.phase = CaseFile.Phase.NONE
	citizen.place = -1
	citizen.desk = -1
	citizen.walk = 0.0


func dismiss_citizen(case_file: CaseFile) -> void:
	if case_file.has_citizen():
		_release_citizen(case_file)


func _close_line(machine: int) -> void:
	var slot := 0
	for citizen in state.ticket_line:
		if citizen.machine != machine:
			continue
		if citizen.line_slot != slot:
			citizen.line_slot = slot
			_walk_to(citizen, layout.ticket_line_point(machine, slot))
		slot += 1


func line_front(machine: int) -> CaseFile:
	for citizen in state.ticket_line:
		if citizen.machine == machine:
			return citizen
	return null


func front_at_ticket_machine() -> bool:
	for machine in Formulas.ticket_machines(state):
		var front := line_front(machine)
		if front != null and is_drawing(front):
			return true
	return false


func is_drawing(case_file: CaseFile) -> bool:
	return case_file.phase == CaseFile.Phase.LINE and case_file.line_slot == 0 and case_file.walk <= 0.0


func _update_tickets(delta: float) -> void:
	_sync_places()
	_update_citizens(delta)
	for machine in Formulas.ticket_machines(state):
		var front := line_front(machine)
		if front == null or not is_drawing(front):
			continue
		front.draw_progress += delta * Formulas.ticket_speed(layout.near(state.player.position, layout.ticket_machine_point(machine)))
		if front.draw_progress >= Formulas.ticket_draw_time(state, machine):
			draw_ticket(front)
	call_citizens()


func draw_ticket(case_file: CaseFile = null) -> bool:
	if case_file == null:
		case_file = line_front(0)
	if case_file == null or not state.ticket_line.has(case_file):
		return false
	state.ticket_line.erase(case_file)
	_close_line(case_file.machine)
	case_file.draw_progress = 0.0
	case_file.line_slot = -1
	state.tickets_drawn += 1
	case_file.ticket = state.tickets_drawn
	ticket_drawn.emit(state.tickets_drawn)
	if not _take_place(case_file, CaseFile.Phase.WAITING):
		give_up(case_file)
	return true


func _take_place(citizen: CaseFile, phase: CaseFile.Phase) -> bool:
	citizen.phase = phase
	citizen.place = -1
	var room := citizen.waiting_room()
	var seat := state.free_place(true, room)
	citizen.seated = seat >= 0
	citizen.place = seat if seat >= 0 else state.free_place(false, room)
	citizen.waited = 0.0
	if citizen.place < 0:
		return false
	_walk_to(citizen, place_point(citizen))
	return true


func place_point(citizen: CaseFile) -> Vector2:
	var room := citizen.waiting_room()
	if citizen.seated:
		return layout.waiting_seat(citizen.place, room)
	return layout.standing_point(citizen.place, state.seat_capacity(room), room)


func _sync_places() -> void:
	var seats := Vector2i(state.seat_capacity(GameConfig.HALL_INTAKE), state.seat_capacity(GameConfig.HALL_PICKUP))
	if seats == _seat_layout:
		return
	var initial := _seat_layout.x < 0
	_seat_layout = seats
	if initial:
		return
	for citizen in state.citizens:
		if not citizen.is_in_hall() or citizen.seated:
			continue
		var seat := state.free_place(true, citizen.waiting_room())
		if seat >= 0:
			citizen.seated = true
			citizen.place = seat
		_walk_to(citizen, place_point(citizen))


func pickup_space() -> int:
	var heading := 0
	for citizen in state.citizens:
		if citizen.phase == CaseFile.Phase.CALLED or citizen.phase == CaseFile.Phase.SERVED:
			heading += 1
	return state.places_left(GameConfig.HALL_PICKUP) - heading


func call_citizens() -> bool:
	var player_spot := []
	var checked := false
	var called := false
	for key in GameConfig.CALL_STATIONS:
		var station := state.station(key)
		if station == null or is_halted(station):
			continue
		for desk in station.desks:
			if station.jobs[desk] != null or desk_call(station, desk) != null:
				continue
			if not _desk_manned(station, desk):
				if not checked:
					player_spot = player_desk()
					checked = true
				if player_spot != [key, desk]:
					continue
			var citizen := _next_caller(station)
			if citizen == null:
				break
			_call(citizen, station, desk)
			called = true
	return called


func _desk_manned(station: Station, desk: int) -> bool:
	return station.is_working(desk) or (state.is_boost_active("temp_workers") and _is_temp_desk(station, desk))


func desk_call(station: Station, desk: int) -> CaseFile:
	for case_file in station.inbox:
		if case_file.desk == desk and _is_called(case_file):
			return case_file
	return null


func _is_called(case_file: CaseFile) -> bool:
	return case_file.phase == CaseFile.Phase.CALLED or case_file.phase == CaseFile.Phase.CALLED_DOC or case_file.phase == CaseFile.Phase.CALLED_PHOTO


func _next_caller(station: Station) -> CaseFile:
	if station.kind == "counter" or station.key == GameConfig.PHOTO_STATION:
		for case_file in station.inbox:
			if case_file.phase == CaseFile.Phase.WAITING_DOC:
				return case_file
		return null
	if pickup_space() <= 0:
		return null
	var waiting: Array[CaseFile] = []
	for citizen in state.citizens:
		if citizen.phase == CaseFile.Phase.WAITING:
			waiting.append(citizen)
	if waiting.is_empty():
		return null
	var blocked := _saturated_targets(station, waiting)
	var best: CaseFile = null
	for citizen in waiting:
		if not blocked.has(citizen.next_key()) and (best == null or citizen.ticket < best.ticket):
			best = citizen
	return best


func _call(citizen: CaseFile, station: Station, desk: int) -> void:
	citizen.desk = desk
	if station.key == GameConfig.PHOTO_STATION:
		citizen.phase = CaseFile.Phase.CALLED_PHOTO
		_walk_to(citizen, layout.desk_front(station.key, desk))
		ticket_called.emit(citizen.ticket)
		return
	citizen.waited = 0.0
	citizen.place = -1
	if station.kind == "counter":
		citizen.phase = CaseFile.Phase.CALLED_DOC
	else:
		citizen.phase = CaseFile.Phase.CALLED
		station.inbox.append(citizen)
		state.tickets_called = mini(state.tickets_called + 1, state.tickets_drawn)
	_walk_to(citizen, layout.desk_front(station.key, desk))
	ticket_called.emit(citizen.ticket)


func _take_called(station: Station, desk: int) -> CaseFile:
	var fallback := -1
	for index in station.inbox.size():
		var case_file := station.inbox[index]
		if case_file.desk == desk and _is_called(case_file):
			if case_file.walk > 0.0:
				return null
			station.inbox.remove_at(index)
			if case_file.phase == CaseFile.Phase.CALLED_PHOTO:
				case_file.phase = CaseFile.Phase.PHOTO
				return case_file
			case_file.phase = CaseFile.Phase.SERVED if case_file.phase == CaseFile.Phase.CALLED else CaseFile.Phase.COLLECTING
			case_file.waited = 0.0
			return case_file
		if fallback < 0 and not case_file.has_citizen():
			fallback = index
	if fallback < 0:
		return null
	var taken := station.inbox[fallback]
	if _saturated_targets(station).has(taken.next_key()):
		return null
	station.inbox.remove_at(fallback)
	return taken


func _after_service(case_file: CaseFile) -> void:
	if case_file.phase == CaseFile.Phase.PHOTO:
		case_file.phase = CaseFile.Phase.WAITING_DOC
		case_file.desk = -1
		_walk_to(case_file, place_point(case_file))
		return
	if case_file.phase != CaseFile.Phase.SERVED:
		return
	case_file.desk = -1
	if not _take_place(case_file, CaseFile.Phase.WAITING_DOC):
		give_up(case_file)


func roll_extras(dept: Department) -> Array[String]:
	var extras: Array[String] = []
	if dept.is_customs():
		return extras
	var others: Array[String] = []
	for other in state.mail_departments():
		if other.id != dept.id:
			others.append(other.id)
	var chance := Formulas.multi_application_chance(others.size())
	while extras.size() < GameConfig.MULTI_MAX_EXTRAS and not others.is_empty() and state.life_rng.randf() < chance:
		extras.append(others.pop_at(state.life_rng.randi_range(0, others.size() - 1)))
		chance *= GameConfig.MULTI_SECOND_FACTOR
	return extras


func _update_mail(delta: float) -> void:
	if state.mailroom() == null:
		return
	state.mail_timer -= delta
	if state.mail_timer <= 0.0:
		state.mail_timer = Formulas.mail_interval(state)
		deliver_mail(Formulas.mail_batch(state))


func create_mail_case(dept: Department) -> CaseFile:
	var case_file := CaseFile.new(dept.id)
	case_file.mail = true
	case_file.complex = state.life_rng.randf() < float(dept.config().complex_chance)
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func deliver_mail(count: int) -> int:
	var room := state.mailroom()
	var depts := state.mail_departments()
	if room == null or depts.is_empty():
		return 0
	var accepted := 0
	var dropped := 0
	var returned := 0
	var letters: Array[String] = state.mail_promised.duplicate()
	state.mail_promised.clear()
	for i in count:
		letters.append(depts[state.life_rng.randi_range(0, depts.size() - 1)].id)
	for dept_id in letters:
		var dept := state.department(dept_id)
		if dept == null or not dept.unlocked:
			continue
		if room.has_inbox_space(state.lobby_capacity()):
			room.inbox.append(create_mail_case(dept))
			accepted += 1
		elif state.mail_floor.size() < GameConfig.MAIL_FLOOR_MAX:
			state.mail_floor.append(create_mail_case(dept))
			dropped += 1
		else:
			returned += 1
	state.mail_received += accepted
	state.mail_dropped += dropped
	state.mail_returned += returned
	mail_delivered.emit(accepted, dropped, returned)
	return accepted


func pick_up_mail() -> bool:
	var room := state.mailroom()
	if room == null or state.mail_floor.is_empty() or not room.has_inbox_space(state.lobby_capacity()):
		return false
	room.inbox.append(state.mail_floor.pop_front())
	return true


func _lose_citizen(dept_id: String, reputation_change: float) -> void:
	_record_loss(dept_id, reputation_change)
	citizen_left.emit(dept_id)


func _record_loss(dept_id: String, reputation_change: float) -> void:
	state.citizens_lost += 1
	state.production.record(ProductionStats.LOST, dept_id, state.play_time)
	state.add_reputation(reputation_change)


func _work_stations(delta: float) -> void:
	var temps := state.is_boost_active("temp_workers")
	for key in state.ordered_station_keys():
		var station := state.station(key)
		station.rush = maxf(0.0, station.rush - delta)
		if is_halted(station) or _update_jam(station):
			continue
		var step := delta * Formulas.work_speed(state, station)
		var idle_failed := false
		var specialist_failed := false
		var jobs := station.jobs
		for desk in jobs.size():
			var working := station.is_working(desk) or (temps and _is_temp_desk(station, desk))
			var job := jobs[desk]
			if job == null:
				if not working:
					continue
				var specialist := station.is_specialist_desk(desk)
				if (specialist_failed if specialist else idle_failed) or not start_job(station, desk):
					if specialist:
						specialist_failed = true
					else:
						idle_failed = true
					continue
				job = jobs[desk]
			if working:
				job.progress += step * Formulas.official_speed(station.moods[desk])
			if job.progress >= job.required and finish_job(station, desk):
				idle_failed = false
				specialist_failed = false


func _update_jam(station: Station) -> bool:
	var jammed := station.is_output_jammed()
	if jammed and not station.jammed:
		outputs_jammed.emit(station.key, send_on_break(station))
	station.jammed = jammed
	return jammed


func send_on_break(station: Station) -> int:
	if station.machine:
		return 0
	var sent := 0
	for desk in station.moods.size():
		if not station.is_staffed(desk) or not station.moods[desk].is_on_duty():
			continue
		var lunch := state.rng.randf() < GameConfig.JAM_LUNCH_CHANCE
		var rest_state := DeskMood.LUNCH if lunch else DeskMood.CHAT
		var slot := state.free_kitchen_slot(GameConfig.LUNCH_SLOT if lunch else GameConfig.KITCHEN_TABLE_SLOT)
		if slot < 0:
			rest_state = DeskMood.COFFEE
		station.moods[desk].rest(rest_state, slot)
		employee_dozed.emit(station.key, desk, rest_state)
		sent += 1
	return sent


func _is_temp_desk(station: Station, desk: int) -> bool:
	return not station.machine and desk >= station.staff and desk < station.desks


func _update_moods(delta: float) -> void:
	var caffeinated := state.is_boost_active("coffee_round")
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		var rate := -1.0
		for desk in station.moods.size():
			if not station.is_staffed(desk):
				continue
			var mood := station.moods[desk]
			if mood.is_returning():
				mood.resting += delta
				if mood.resting >= mood.return_time:
					mood.arrive()
					employee_returned.emit(station.key, desk)
			elif mood.is_disputing():
				continue
			elif mood.is_resting():
				mood.resting += delta * (Formulas.sick_recovery_speed(mood.bonus) if mood.is_sick() else 1.0)
				if mood.resting >= Formulas.rest_limit(state, mood.state):
					wake_up(station, desk, false)
			elif not caffeinated and (station.jobs[desk] != null or not station.inbox.is_empty()):
				if rate < 0.0:
					rate = Formulas.drowsiness_rate(state, station)
					if station.is_swamped(state.lobby_capacity()):
						rate *= GameConfig.SWAMPED_DROWSY_FACTOR
				mood.alert -= delta * rate * Formulas.official_drowsy_factor(mood)
				if mood.alert <= 0.0:
					doze_off(station, desk)


func doze_off(station: Station, desk: int) -> bool:
	if station.machine or not station.is_staffed(desk) or not station.moods[desk].is_on_duty():
		return false
	var rest_state := _roll_doze_state()
	var slot := -1
	if DeskMood.is_away_state(rest_state):
		slot = state.free_loo_slot() if rest_state == DeskMood.LOO else state.free_kitchen_slot()
		if slot < 0:
			rest_state = DeskMood.ASLEEP
	station.moods[desk].rest(rest_state, slot)
	station.moods[desk].doze_count += 1
	state.production.record(ProductionStats.DOZED, station.key, state.play_time)
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
	var away_slot := mood.slot if mood.is_away() else -1
	mood.wake(Formulas.wake_alert(state, mood.state))
	if away_slot >= 0:
		mood.start_return(Formulas.staff_walk_time(layout.slot_point(away_slot), layout.desk_position(station.key, desk)))
	if by_player:
		state.wakes += 1
	employee_woke.emit(station.key, desk, by_player)
	return true


func _update_complaints(delta: float) -> void:
	state.leave_complaint_cooldown = maxf(0.0, state.leave_complaint_cooldown - delta)
	if state.cases_completed >= GameConfig.COMPLAINT_MIN_CASES:
		state.complaint_timer -= delta
		if state.complaint_timer <= 0.0:
			state.complaint_timer = Formulas.complaint_interval(state.rng.randf())
			if spawn_visitor(false, true) == null:
				submit_complaint()
		state.complaint_letter_timer -= delta
		if state.complaint_letter_timer <= 0.0:
			state.complaint_letter_timer = Formulas.complaint_letter_interval(state.rng.randf())
			file_complaint()
	var review_drain := state.review_drain()
	if review_drain > 0.0:
		state.add_reputation(-review_drain * GameConfig.REVIEW_DRAIN * delta)
	_update_praise(delta)
	if state.expire_reviews() > 0:
		review_removed.emit("expired")
	var player := state.player
	player.complaint_timer -= delta
	if player.complaint_timer <= 0.0 and move_complaints():
		player.complaint_timer = Formulas.complaint_transfer_interval(state)


func _free_visitor_slot() -> int:
	for slot in GameConfig.VISITOR_SLOTS:
		var taken := false
		for visitor in state.visitors:
			if visitor.slot == slot and visitor.is_at_clerk():
				taken = true
				break
		if not taken:
			return slot
	return -1


func _security_stops() -> bool:
	var chance := Formulas.security_chance(state)
	return chance > 0.0 and state.life_rng.randf() < chance


func spawn_visitor(angry: bool, files_complaint: bool, from: Vector2 = Vector2.INF, rage: float = 0.0) -> ComplaintVisitor:
	var stopped := _security_stops()
	var slot := -1 if stopped else _free_visitor_slot()
	if not stopped and slot < 0:
		return null
	var visitor := ComplaintVisitor.new(layout.door_in() if from == Vector2.INF else from)
	visitor.rage_timer = maxf(0.0, rage)
	visitor.angry = angry
	visitor.files_complaint = files_complaint and not stopped
	visitor.slot = slot
	visitor.stopped = stopped
	var dialogs := GameConfig.GUARD_DIALOGS if stopped else (GameConfig.YELL_DIALOGS if angry else GameConfig.VISITOR_DIALOGS)
	visitor.dialog = state.life_rng.randi_range(0, dialogs - 1)
	visitor.look = state.life_rng.randi_range(0, 11)
	state.visitors.append(visitor)
	visitor_arrived.emit(angry)
	return visitor


func _update_visitors(delta: float) -> void:
	if state.complaints >= GameConfig.YELL_COMPLAINTS:
		state.yell_timer -= delta
		if state.yell_timer <= 0.0:
			state.yell_timer = GameConfig.YELL_INTERVAL * state.life_rng.randf_range(0.8, 1.2)
			spawn_visitor(true, false)
	else:
		state.yell_timer = GameConfig.YELL_INTERVAL
	var index := state.visitors.size() - 1
	while index >= 0:
		var visitor := state.visitors[index]
		if visitor.rage_timer > 0.0:
			visitor.rage_timer = maxf(0.0, visitor.rage_timer - delta)
			index -= 1
			continue
		match visitor.phase:
			ComplaintVisitor.Phase.ARRIVING:
				if visitor.is_stopped():
					if visitor.move_towards(layout.security_stop_spot(), GameConfig.VISITOR_SPEED, delta):
						_start_stop(visitor)
				elif visitor.move_towards(layout.visitor_spot(visitor.slot), GameConfig.VISITOR_SPEED, delta):
					_start_talking(visitor)
			ComplaintVisitor.Phase.STOPPED:
				visitor.timer -= delta
				if visitor.timer <= 0.0:
					visitor.phase = ComplaintVisitor.Phase.LEAVING
			ComplaintVisitor.Phase.TALKING:
				visitor.timer -= delta
				if visitor.timer <= 0.0:
					_finish_talking(visitor)
			ComplaintVisitor.Phase.TO_BOX:
				if visitor.move_towards(layout.complaint_drop_spot(), GameConfig.VISITOR_SPEED, delta):
					visitor.files_complaint = false
					file_complaint()
					visitor.phase = ComplaintVisitor.Phase.LEAVING
			ComplaintVisitor.Phase.LEAVING:
				if visitor.move_towards(layout.door_out(), GameConfig.VISITOR_SPEED, delta):
					state.visitors.remove_at(index)
		index -= 1


func desk_intern() -> ComplaintIntern:
	var best: ComplaintIntern = null
	for unit in state.interns:
		if unit.is_at_desk() and (best == null or unit.handled < best.handled):
			best = unit
	return best


func _start_stop(visitor: ComplaintVisitor) -> void:
	visitor.phase = ComplaintVisitor.Phase.STOPPED
	visitor.duration = GameConfig.SECURITY_STOP_SECONDS
	visitor.timer = visitor.duration
	state.visitors_stopped += 1
	visitor_stopped.emit(visitor.angry)


func player_at_complaint_counter() -> bool:
	return layout.near(state.player.position, layout.complaint_player_point())


func _start_talking(visitor: ComplaintVisitor) -> void:
	if desk_intern() == null and not player_at_complaint_counter():
		visitor.phase = ComplaintVisitor.Phase.TO_BOX if visitor.files_complaint else ComplaintVisitor.Phase.LEAVING
		return
	visitor.phase = ComplaintVisitor.Phase.TALKING
	visitor.duration = GameConfig.VISITOR_ANGRY_TALK_SECONDS if visitor.angry else GameConfig.VISITOR_TALK_SECONDS
	visitor.timer = visitor.duration


func _finish_talking(visitor: ComplaintVisitor) -> void:
	if state.is_boost_active("complaint_amnesty") or (not visitor.files_complaint and not visitor.angry):
		_send_away(visitor)
		return
	if player_at_complaint_counter():
		_send_away(visitor)
		state.visitors_respected += 1
		visitor_respected.emit(visitor.slot)
		return
	if _fend_off():
		_send_away(visitor)
		return
	visitor.phase = ComplaintVisitor.Phase.TO_BOX if visitor.files_complaint else ComplaintVisitor.Phase.LEAVING


func _send_away(visitor: ComplaintVisitor) -> void:
	visitor.files_complaint = false
	visitor.phase = ComplaintVisitor.Phase.LEAVING


func _fend_off() -> bool:
	var intern := desk_intern()
	if intern == null:
		return false
	intern.handled += 1
	state.complaints_absorbed += 1
	complaint_absorbed.emit(intern.slot)
	if intern.handled >= Formulas.intern_steadfast(state):
		intern.mood = ComplaintIntern.Mood.TO_LOO
		intern.comfort_progress = 0.0
		state.breakdowns += 1
		intern_broke_down.emit(intern.slot)
	return true


func _update_intern(delta: float) -> void:
	for unit in state.interns:
		_update_intern_unit(unit, delta)
	_dispatch_box_run()


func _dispatch_box_run() -> void:
	var size := Formulas.intern_run_size(state)
	if size <= 0 or state.interns_at_desk() < 2:
		return
	var reserved := 0
	for unit in state.interns:
		if unit.mood == ComplaintIntern.Mood.TO_BOX:
			reserved += size
	if state.complaints <= reserved:
		return
	for index in range(state.interns.size() - 1, -1, -1):
		var unit := state.interns[index]
		if unit.is_at_desk():
			unit.mood = ComplaintIntern.Mood.TO_BOX
			return


func _update_intern_unit(intern: ComplaintIntern, delta: float) -> void:
	var speed := Formulas.intern_speed(state)
	match intern.mood:
		ComplaintIntern.Mood.DESK:
			intern.move_towards(layout.intern_home(intern.slot), speed, delta)
		ComplaintIntern.Mood.TO_BOX:
			if intern.move_towards(layout.intern_box_point(intern.slot), speed, delta):
				intern.carried = mini(Formulas.intern_run_size(state), state.complaints)
				state.complaints -= intern.carried
				intern.mood = ComplaintIntern.Mood.TO_SHREDDER if intern.carried > 0 else ComplaintIntern.Mood.RETURNING
		ComplaintIntern.Mood.TO_SHREDDER:
			if intern.move_towards(layout.intern_shred_point(intern.slot), speed, delta):
				_book_complaints(intern.carried, false)
				intern.carried = 0
				intern.mood = ComplaintIntern.Mood.FROM_SHREDDER
		ComplaintIntern.Mood.FROM_SHREDDER, ComplaintIntern.Mood.RETURNING:
			if intern.move_towards(layout.intern_home(intern.slot), speed, delta):
				intern.mood = ComplaintIntern.Mood.DESK
		ComplaintIntern.Mood.TO_LOO:
			if intern.move_towards(layout.intern_cry_point(intern.slot), speed, delta):
				intern.mood = ComplaintIntern.Mood.CRYING
			_comfort_intern(intern, delta)
		ComplaintIntern.Mood.CRYING:
			_comfort_intern(intern, delta)


func _comfort_intern(intern: ComplaintIntern, delta: float) -> void:
	if not layout.near(state.player.position, intern.position):
		intern.comfort_progress = 0.0
		return
	intern.comfort_progress += delta
	if intern.comfort_progress >= GameConfig.INTERN_COMFORT_TIME:
		intern.mood = ComplaintIntern.Mood.RETURNING
		intern.handled = 0
		intern.comfort_progress = 0.0
		intern_recovered.emit(intern.slot, true)


func _update_coffee_interns(delta: float) -> void:
	for intern in state.coffee_interns:
		match intern.task:
			CoffeeIntern.Task.IDLE:
				_idle_coffee_intern(intern, delta)
			CoffeeIntern.Task.TO_MACHINE:
				if intern.move_towards(layout.coffee_brew_point(), Formulas.coffee_intern_speed(state), delta):
					intern.task = CoffeeIntern.Task.BREWING
					intern.brew = 0.0
			CoffeeIntern.Task.BREWING:
				intern.brew += delta
				if intern.brew >= GameConfig.COFFEE_BREW_SECONDS:
					intern.carrying = true
					intern.task = CoffeeIntern.Task.TO_DESK
			CoffeeIntern.Task.TO_DESK:
				_coffee_to_desk(intern, delta)


func _idle_coffee_intern(intern: CoffeeIntern, delta: float) -> void:
	intern.search_timer -= delta
	if intern.search_timer <= 0.0:
		intern.search_timer = GameConfig.WAKE_CHECK_INTERVAL * 5.0
		if _assign_coffee_target(intern):
			intern.task = CoffeeIntern.Task.TO_DESK if intern.carrying else CoffeeIntern.Task.TO_MACHINE
			return
	intern.move_towards(layout.coffee_home(), Formulas.coffee_intern_speed(state) * 0.5, delta)


func _coffee_to_desk(intern: CoffeeIntern, delta: float) -> void:
	if not _coffee_target_valid(intern.key, intern.desk):
		intern.clear_task()
		return
	if not intern.move_towards(layout.desk_position(intern.key, intern.desk) + Vector2(0.0, 26.0), Formulas.coffee_intern_speed(state), delta):
		return
	var mood := state.station(intern.key).moods[intern.desk]
	mood.alert = maxf(mood.alert, Formulas.coffee_alert(state))
	state.coffees_served += 1
	coffee_served.emit(intern.key, intern.desk)
	intern.carrying = false
	intern.clear_task()


func _coffee_target_valid(key: String, desk: int) -> bool:
	var station := state.station(key)
	if station == null or station.machine or desk < 0 or desk >= station.moods.size():
		return false
	var mood := station.moods[desk]
	return station.is_staffed(desk) and mood.is_on_duty() and mood.alert < Formulas.coffee_threshold(state)


func _assign_coffee_target(intern: CoffeeIntern) -> bool:
	var best_alert := INF
	var best_key := ""
	var best_desk := -1
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine or not intern.serves(station.dept_id) or (station.inbox.is_empty() and station.active_jobs() == 0):
			continue
		for desk in station.moods.size():
			if not _coffee_target_valid(key, desk) or _coffee_claimed(key, desk, intern):
				continue
			var alert := station.moods[desk].alert
			if alert < best_alert:
				best_alert = alert
				best_key = key
				best_desk = desk
	if best_key.is_empty():
		return false
	intern.key = best_key
	intern.desk = best_desk
	return true


func _coffee_claimed(key: String, desk: int, except: CoffeeIntern) -> bool:
	for other in state.coffee_interns:
		if other != except and other.targets(key, desk):
			return true
	return false


func _update_disputes(delta: float) -> void:
	if state.cases_completed >= GameConfig.DISPUTE_MIN_CASES and not state.is_boost_active("works_outing"):
		state.dispute_timer -= delta
		if state.dispute_timer <= 0.0:
			state.dispute_timer = Formulas.dispute_interval(state, state.life_rng.randf())
			if state.disputes.size() < GameConfig.MAX_DISPUTES and not _try_auto_dispute():
				state.dispute_timer = GameConfig.DISPUTE_RETRY_SECONDS
	var limit := Formulas.dispute_limit(state)
	var index := state.disputes.size() - 1
	while index >= 0:
		var dispute := state.disputes[index]
		dispute.elapsed += delta
		if layout.near(state.player.position, layout.dispute_point(dispute.dept_id)):
			dispute.progress += delta
			if dispute.progress >= GameConfig.MEDIATE_TIME:
				end_dispute(dispute, true)
				index -= 1
				continue
		else:
			dispute.progress = 0.0
		if dispute.elapsed >= limit:
			end_dispute(dispute, false)
		index -= 1


func is_halted(station: Station) -> bool:
	return station.kind == "reception" and state.has_ruckus()


func _update_ruckus(delta: float) -> void:
	if state.has_ruckus():
		if layout.near(state.player.position, layout.ruckus_point(state.ruckus_desk)):
			state.ruckus_progress += delta
			if state.ruckus_progress >= GameConfig.RUCKUS_CALM_TIME:
				calm_ruckus()
		else:
			state.ruckus_progress = 0.0
		return
	if state.cases_completed < GameConfig.RUCKUS_MIN_CASES:
		return
	state.ruckus_timer -= delta
	if state.ruckus_timer <= 0.0:
		state.ruckus_timer = Formulas.ruckus_interval(state, state.life_rng.randf()) if start_ruckus() else GameConfig.RUCKUS_RETRY_SECONDS


func start_ruckus() -> bool:
	var reception := state.station(GameConfig.RECEPTION)
	if reception == null or state.has_ruckus():
		return false
	for desk in reception.jobs.size():
		var job := reception.jobs[desk]
		if job != null and job.case_file.takes_seat():
			state.ruckus_desk = desk
			state.ruckus_progress = 0.0
			ruckus_started.emit(desk)
			return true
	return false


func calm_ruckus() -> bool:
	if not state.has_ruckus():
		return false
	var desk := state.ruckus_desk
	state.ruckus_desk = -1
	state.ruckus_progress = 0.0
	state.ruckus_calmed += 1
	ruckus_calmed.emit(desk)
	return true


func _try_auto_dispute() -> bool:
	var candidates := dispute_candidates()
	if candidates.is_empty():
		return start_dispute() != null
	var dept_id := candidates[state.life_rng.randi_range(0, candidates.size() - 1)]
	var calm := Formulas.department_calm(state, dept_id)
	if calm > 0.0 and state.life_rng.randf() < calm:
		state.production.record(ProductionStats.DISPUTE_CALMED, dept_id, state.play_time)
		dispute_calmed.emit(dept_id)
		return true
	return start_dispute("", dept_id) != null


func dispute_candidates() -> Array[String]:
	var result: Array[String] = []
	for dept in state.unlocked_departments():
		if state.dispute_in(dept.id) == null and _staffed_workers(dept.id) >= GameConfig.DISPUTE_MIN_STAFF:
			result.append(dept.id)
	return result


func _staffed_workers(dept_id: String) -> int:
	var count := 0
	for key in GameConfig.department_station_keys(dept_id):
		var station := state.station(key)
		if station != null and not station.machine:
			count += station.workers()
	return count


func start_dispute(kind: String = "", dept_id: String = "") -> Dispute:
	var candidates := dispute_candidates()
	if dept_id.is_empty() and not candidates.is_empty():
		dept_id = candidates[state.life_rng.randi_range(0, candidates.size() - 1)]
	if kind.is_empty():
		var kinds: Array[String] = []
		for option: String in GameConfig.DISPUTES:
			if Formulas.dispute_allowed(state, option):
				kinds.append(option)
		if not kinds.is_empty():
			kind = kinds[state.life_rng.randi_range(0, kinds.size() - 1)]
	if kind.is_empty() or not GameConfig.DISPUTES.has(kind) or not candidates.has(dept_id):
		return null
	var dispute := Dispute.new(kind, dept_id)
	state.disputes.append(dispute)
	_gather_dispute_crew(dept_id)
	state.production.record(ProductionStats.DISPUTE, dept_id, state.play_time)
	dispute_started.emit(kind, dept_id)
	return dispute


func _gather_dispute_crew(dept_id: String) -> int:
	var joined := 0
	for key in GameConfig.department_station_keys(dept_id):
		var station := state.station(key)
		if station == null or station.machine:
			continue
		for desk in station.moods.size():
			if joined >= GameConfig.DISPUTE_CREW:
				return joined
			if station.is_staffed(desk) and station.moods[desk].join_dispute():
				joined += 1
	return joined


func dispute_crew(dept_id: String) -> Array[Dictionary]:
	var crew: Array[Dictionary] = []
	for key in GameConfig.department_station_keys(dept_id):
		var station := state.station(key)
		if station == null or station.machine:
			continue
		for desk in station.moods.size():
			if station.is_staffed(desk) and station.moods[desk].is_disputing():
				crew.append({"key": key, "desk": desk})
	return crew


func _release_dispute_crew(dept_id: String) -> void:
	var crew := dispute_crew(dept_id)
	for index in crew.size():
		var key := str(crew[index].key)
		var desk := int(crew[index].desk)
		var mood := state.station(key).moods[desk]
		mood.arrive()
		mood.start_return(Formulas.staff_walk_time(layout.dispute_spot(dept_id, index), layout.desk_position(key, desk)))


func end_dispute(dispute: Dispute, by_player: bool) -> void:
	state.disputes.erase(dispute)
	_release_dispute_crew(dispute.dept_id)
	state.disputes_solved += 1
	if by_player:
		state.add_reputation(GameConfig.MEDIATE_REPUTATION)
	dispute_ended.emit(dispute.kind, dispute.dept_id, by_player)


func submit_complaint() -> void:
	if state.is_boost_active("complaint_amnesty") or player_at_complaint_counter():
		return
	if not _fend_off():
		file_complaint()


func file_complaint() -> void:
	if state.is_boost_active("complaint_amnesty"):
		return
	if state.complaints >= Formulas.complaint_cap(state):
		complaint_filed.emit(true)
		_post_negative_review()
		return
	state.complaints += 1
	state.complaints_filed += 1
	state.production.record(ProductionStats.COMPLAINT, "", state.play_time)
	complaint_filed.emit(false)


func _post_negative_review() -> void:
	var stars := 1 if state.review_rng.randf() < GameConfig.REVIEW_ONE_STAR_SHARE else 2
	review_posted.emit(state.add_review(stars))


func _update_praise(delta: float) -> void:
	state.praise_timer -= delta
	if state.praise_timer > 0.0:
		return
	state.praise_timer = Formulas.praise_interval(state.review_rng.randf())
	post_praise()


func post_praise() -> Review:
	var review := state.add_review(Formulas.praise_stars(state.review_rng.randf()))
	review_posted.emit(review)
	return review


func can_delete_review(review_id: int) -> bool:
	var review := state.find_review(review_id)
	return review != null and state.can_afford(Formulas.review_delete_cost(state, review))


func delete_review(review_id: int) -> bool:
	if not can_delete_review(review_id):
		return false
	var review := state.find_review(review_id)
	state.spend(Formulas.review_delete_cost(state, review))
	state.reviews.erase(review)
	if review.is_negative():
		state.add_reputation(GameConfig.REVIEW_DELETE_REPUTATION)
	review_removed.emit("deleted")
	return true


func can_sue_for_defamation(review_id: int) -> bool:
	var review := state.find_review(review_id)
	return review != null and review.can_be_sued() and state.can_afford(Formulas.review_lawsuit_cost(state, review))


func sue_for_defamation(review_id: int) -> bool:
	if not can_sue_for_defamation(review_id):
		return false
	var review := state.find_review(review_id)
	var cost := Formulas.review_lawsuit_cost(state, review)
	state.spend(cost)
	if state.review_rng.randf() < Formulas.review_lawsuit_chance(review):
		win_lawsuit(review, cost * GameConfig.REVIEW_LAWSUIT_REFUND_FACTOR)
	else:
		review.downgrade(state.review_rng.randi_range(0, GameConfig.review_texts(maxi(1, review.stars - 1)) - 1))
		state.add_reputation(-GameConfig.REVIEW_LAWSUIT_LOSS)
		review_removed.emit("lost")
	return true


func win_lawsuit(review: Review, refund: float) -> void:
	review.force_praise(state.review_rng.randi_range(0, GameConfig.REVIEW_FORCED_TEXTS - 1))
	state.earn(refund)
	state.add_reputation(GameConfig.REVIEW_LAWSUIT_REPUTATION)
	review_removed.emit("won")


func shred_complaints(count: int, by_player: bool) -> int:
	var source := state.player.complaints if by_player else state.complaints
	var shredded := mini(count, source)
	if shredded <= 0:
		return 0
	if by_player:
		state.player.complaints -= shredded
	else:
		state.complaints -= shredded
	_book_complaints(shredded, by_player)
	return shredded


func _book_complaints(shredded: int, by_player: bool) -> void:
	if shredded <= 0:
		return
	state.complaints_shredded += shredded
	state.production.record(ProductionStats.COMPLAINT_SHREDDED, ProductionStats.BY_PLAYER if by_player else ProductionStats.BY_STAFF, state.play_time, shredded)
	state.earn(GameConfig.COMPLAINT_REWARD * shredded)
	state.add_reputation(GameConfig.COMPLAINT_REPUTATION * shredded)
	complaint_shredded.emit(by_player)


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
	state.production.record(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_PLAYER if by_player else ProductionStats.BY_STAFF, state.play_time, shredded)
	state.earn(GameConfig.REJECT_SHRED_REWARD * shredded)
	complaint_shredded.emit(by_player)
	return shredded


func shred_case(case_file: CaseFile) -> bool:
	dismiss_citizen(case_file)
	state.cases_shredded += 1
	_lose_citizen(case_file.dept_id, -GameConfig.SHRED_CASE_PENALTY)
	case_shredded.emit(case_file.dept_id)
	return true


func _update_collectors(delta: float) -> void:
	var capacity := Formulas.collector_capacity(state)
	var speed := Formulas.collector_speed(state)
	for collector in state.collectors:
		if collector.source.is_empty() and collector.loaded < capacity:
			collector.source = collector_target(collector, capacity)
		if not collector.source.is_empty():
			if collector.move_towards(layout.reject_point(collector.source), speed, delta):
				_collect_rejects(collector, capacity)
		elif collector.loaded > 0:
			if collector.move_towards(nearest_shredder(collector.position), speed, delta):
				_unload_collector(collector)
		else:
			collector.move_towards(layout.collector_home(), speed * 0.5, delta)


func shredder_points() -> Array[Vector2]:
	var rooms := state.shredder_rooms()
	if not is_same(rooms, _shredder_rooms):
		_shredder_rooms = rooms
		_shredder_points = layout.shredder_points(rooms)
		_reject_detours.clear()
	return _shredder_points


func _reject_to_shredder(key: String) -> float:
	var points := shredder_points()
	var cached: Variant = _reject_detours.get(key)
	if cached == null:
		var point := layout.reject_point(key)
		cached = point.distance_to(WorldLayout.nearest_of(point, layout.shredder_point(), points))
		_reject_detours[key] = cached
	return cached


func nearest_shredder(from: Vector2) -> Vector2:
	return WorldLayout.nearest_of(from, layout.shredder_point(), shredder_points())


func near_shredder(position: Vector2) -> bool:
	for point in shredder_points():
		if layout.near(position, point):
			return true
	return false


func _update_dept_shredders(delta: float) -> void:
	var rooms := state.shredder_rooms()
	if rooms.is_empty():
		return
	var reject_stations := _reject_stations()
	for dept_id in rooms:
		var station: Station = reject_stations.get(dept_id)
		if station == null:
			state.shredder_timers[dept_id] = 0.0
			continue
		var timer := float(state.shredder_timers.get(dept_id, 0.0)) + delta
		var interval := Formulas.shredder_interval(state, dept_id)
		if timer >= interval:
			timer = 0.0
			var shredded := mini(GameConfig.SHREDDER_BATCH, station.rejects)
			station.rejects -= shredded
			state.production.record(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF, state.play_time, shredded)
			state.earn(GameConfig.REJECT_SHRED_REWARD * shredded)
			dept_shredded.emit(dept_id)
		state.shredder_timers[dept_id] = timer


func _reject_stations() -> Dictionary:
	var best := {}
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.rejects <= 0:
			continue
		var current: Station = best.get(station.dept_id)
		if current == null or station.rejects > current.rejects:
			best[station.dept_id] = station
	return best


func _collect_rejects(collector: RejectCollector, capacity: int) -> void:
	var station := state.station(collector.source)
	collector.source = ""
	if station == null:
		return
	var taken := mini(capacity - collector.loaded, station.rejects)
	collector.loaded += taken
	station.rejects -= taken


func _unload_collector(collector: RejectCollector) -> void:
	state.production.record(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF, state.play_time, collector.loaded)
	state.earn(GameConfig.REJECT_SHRED_REWARD * collector.loaded)
	collector.loaded = 0
	complaint_shredded.emit(false)


func collector_target(collector: RejectCollector, capacity: int) -> String:
	var free := capacity - collector.loaded
	if free <= 0:
		return ""
	var straight := collector.position.distance_to(nearest_shredder(collector.position)) if collector.loaded > 0 else 0.0
	var best := ""
	var best_urgent := false
	var best_score := 0.0
	var claimed := _claimed_sources(collector)
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.rejects <= 0 or claimed.has(key) or not collector.serves(station.dept_id):
			continue
		var point := layout.reject_point(key)
		var detour := collector.position.distance_to(point) + _reject_to_shredder(key) - straight
		var urgent := station.rejects >= GameConfig.REJECT_CAPACITY - GameConfig.COLLECTOR_URGENT_MARGIN
		if collector.loaded > 0 and not urgent and detour > GameConfig.COLLECTOR_MAX_DETOUR:
			continue
		var score := float(mini(station.rejects, free)) / (maxf(0.0, detour) + GameConfig.COLLECTOR_DISTANCE_BIAS)
		if (urgent and not best_urgent) or (urgent == best_urgent and score > best_score):
			best = key
			best_urgent = urgent
			best_score = score
	return best


func _claimed_sources(collector: RejectCollector) -> Dictionary:
	var claimed := {}
	for other in state.collectors:
		if other != collector and not other.source.is_empty():
			claimed[other.source] = true
	return claimed


func move_complaints() -> bool:
	var player := state.player
	if near_shredder(player.position):
		if player.complaints > 0:
			return shred_complaints(1, true) > 0
		if player.rejects > 0:
			return shred_rejects(1, true) > 0
		if not player.items.is_empty():
			return shred_case(player.items.pop_back())
	var carried := player.complaints + player.rejects
	if carried >= Formulas.carry_capacity(state):
		return false
	if state.complaints > 0 and layout.near(player.position, layout.complaint_box_point()):
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
		state.sick_timer = Formulas.sick_interval(state, state.rng.randf())
		if not state.is_boost_active("works_outing"):
			report_sick()
	_update_phones(delta)


func report_sick() -> bool:
	var candidates: Array = []
	var swamped: Array = []
	var staffed := 0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		var overloaded := station.is_swamped(state.lobby_capacity())
		for desk in station.moods.size():
			if not station.is_staffed(desk):
				continue
			staffed += 1
			if station.moods[desk].is_on_duty():
				candidates.append([station, desk])
				if overloaded:
					swamped.append([station, desk])
	if staffed < GameConfig.SICK_MIN_STAFF or candidates.is_empty():
		return false
	if not swamped.is_empty() and state.life_rng.randf() < GameConfig.SWAMPED_SICK_SHARE:
		candidates = swamped
	var pick: Array = candidates[state.rng.randi_range(0, candidates.size() - 1)]
	var station: Station = pick[0]
	var resist := Formulas.official_sick_resist(station.moods[pick[1]])
	if resist > 0.0 and state.life_rng.randf() < resist:
		state.production.record(ProductionStats.SICK_AVOIDED, station.key, state.play_time)
		sick_avoided.emit(station.key, pick[1])
		return false
	station.moods[pick[1]].rest(DeskMood.SICK)
	station.moods[pick[1]].sick_count += 1
	state.production.record(ProductionStats.SICK, station.key, state.play_time)
	state.calls.append(PhoneCall.new(PhoneCall.INCOMING, station.key, pick[1], GameConfig.SICK_RING_SECONDS))
	employee_dozed.emit(station.key, pick[1], DeskMood.SICK)
	sick_call_ringing.emit(station.key, pick[1])
	return true


func _update_phones(delta: float) -> void:
	_drop_stale_calls()
	_ring_calls(delta)
	var player_call := state.line_call(PhoneCall.PLAYER)
	var at_phone := layout.near(state.player.position, layout.phone_point())
	if player_call != null and not at_phone:
		_hang_up(player_call)
	elif player_call == null and at_phone:
		_take_call(PhoneCall.PLAYER)
	for line in state.hr:
		if state.line_call(line) == null:
			_take_call(line)
	var index := state.calls.size() - 1
	while index >= 0:
		var phone_call := state.calls[index]
		if not phone_call.is_ringing():
			phone_call.progress += delta if phone_call.line == PhoneCall.PLAYER else delta * Formulas.phone_speed(state)
			if phone_call.progress >= phone_call.duration():
				state.calls.remove_at(index)
				_finish_call(phone_call)
		index -= 1


func _drop_stale_calls() -> void:
	var index := state.calls.size() - 1
	while index >= 0:
		var phone_call := state.calls[index]
		var station := state.station(phone_call.key)
		var valid := station != null and phone_call.desk < station.moods.size() and station.is_staffed(phone_call.desk) and station.moods[phone_call.desk].is_sick()
		if not valid or phone_call.line >= state.hr:
			state.calls.remove_at(index)
		index -= 1


func _ring_calls(delta: float) -> void:
	var index := state.calls.size() - 1
	while index >= 0:
		var phone_call := state.calls[index]
		if phone_call.is_incoming() and phone_call.is_ringing():
			phone_call.ring -= delta
			if phone_call.ring <= 0.0:
				state.calls.remove_at(index)
				state.calls_missed += 1
				state.production.record(ProductionStats.CALL_MISSED, "", state.play_time)
				sick_call_missed.emit(phone_call.key, phone_call.desk)
		index -= 1


func _hang_up(phone_call: PhoneCall) -> void:
	if phone_call.is_incoming():
		phone_call.line = PhoneCall.NONE
		phone_call.progress = 0.0
	else:
		state.calls.erase(phone_call)


func _take_call(line: int) -> PhoneCall:
	for phone_call in state.calls:
		if phone_call.is_incoming() and phone_call.is_ringing():
			phone_call.line = line
			phone_call.progress = 0.0
			return phone_call
	var target := _longest_callable()
	if target.is_empty():
		return null
	var phone_call := PhoneCall.new(PhoneCall.OUTGOING, target[0], target[1])
	phone_call.line = line
	state.calls.append(phone_call)
	return phone_call


func _longest_callable() -> Array:
	var best: Array = []
	var longest := -1.0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if mood.state == DeskMood.SICK and mood.reported and mood.resting > longest and station.is_staffed(desk) and state.call_for(key, desk) == null:
				longest = mood.resting
				best = [key, desk]
	return best


func _finish_call(phone_call: PhoneCall) -> void:
	var station := state.station(phone_call.key)
	var by_player := phone_call.by_player()
	if phone_call.is_incoming():
		station.moods[phone_call.desk].reported = true
		state.calls_answered += 1
		state.production.record(ProductionStats.CALL_ANSWERED, ProductionStats.BY_PLAYER if by_player else ProductionStats.BY_STAFF, state.play_time)
		var persuaded := state.life_rng.randf() < GameConfig.SICK_TALK_CHANCE
		if persuaded:
			wake_up(station, phone_call.desk, by_player)
		sick_call_answered.emit(by_player, phone_call.key, phone_call.desk, persuaded)
		return
	wake_up(station, phone_call.desk, by_player)
	state.calls_made += 1
	sick_called.emit(by_player, phone_call.key, phone_call.desk)


func _update_kranz(delta: float) -> void:
	if state.kranz:
		state.kranz_elapsed += delta
		if _chatter_count() == 0:
			_finish_kranz(false)
		elif state.kranz_elapsed >= GameConfig.KRANZ_MAX_SECONDS:
			end_kranz(false)
		elif layout.near(state.player.position, layout.kranz_point()):
			state.kranz_progress += delta
			if state.kranz_progress >= GameConfig.KRANZ_END_TIME:
				end_kranz(true)
		else:
			state.kranz_progress = 0.0
		return
	if state.is_boost_active("works_outing"):
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
			if station.is_staffed(desk) and station.moods[desk].is_on_duty():
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
	state.kranz_elapsed = 0.0
	kranz_called.emit()
	return true


func end_kranz(by_player: bool) -> void:
	for key in state.ordered_station_keys():
		var station := state.station(key)
		for desk in station.moods.size():
			if station.moods[desk].state == DeskMood.CHAT and station.is_staffed(desk):
				wake_up(station, desk, by_player)
	if by_player:
		state.add_reputation(GameConfig.KRANZ_END_REPUTATION)
	_finish_kranz(by_player)


func _finish_kranz(by_player: bool) -> void:
	state.kranz = false
	state.kranz_progress = 0.0
	state.kranz_elapsed = 0.0
	state.kranz_timer = Formulas.kranz_interval(state, state.rng.randf())
	kranz_ended.emit(by_player)


func _update_lunch(delta: float) -> void:
	if state.is_boost_active("works_outing"):
		return
	state.lunch_timer -= delta
	if state.lunch_timer <= 0.0:
		state.lunch_timer = Formulas.lunch_interval(state.rng.randf()) if call_lunch() > 0 else GameConfig.LUNCH_RETRY_SECONDS


func call_lunch() -> int:
	var candidates: Array = []
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			if station.is_staffed(desk) and station.moods[desk].is_on_duty():
				candidates.append([station, desk])
	if candidates.size() < GameConfig.LUNCH_MIN_STAFF:
		return 0
	var joined := 0
	while joined < GameConfig.LUNCH_SIZE and candidates.size() > GameConfig.LUNCH_KEEP_WORKING:
		var slot := state.free_kitchen_slot(GameConfig.LUNCH_SLOT)
		if slot < 0:
			break
		var pick: Array = candidates.pop_at(state.rng.randi_range(0, candidates.size() - 1))
		var station: Station = pick[0]
		station.moods[pick[1]].rest(DeskMood.LUNCH, slot)
		employee_dozed.emit(station.key, pick[1], DeskMood.LUNCH)
		joined += 1
	if joined > 0:
		state.lunches += joined
		lunch_called.emit(joined)
	return joined


func _update_gift(delta: float) -> void:
	if state.gift_kind >= 0:
		return
	state.gift_timer -= delta
	if state.gift_timer <= 0.0:
		state.gift_timer = Formulas.gift_interval(state.life_rng.randf())
		place_gift(state.life_rng.randi_range(0, GameConfig.GIFT_KINDS - 1))


func place_gift(kind: int) -> bool:
	if state.gift_kind >= 0:
		return false
	state.gift_kind = clampi(kind, 0, GameConfig.GIFT_KINDS - 1)
	state.gift_money = Formulas.gift_value(state)
	gift_arrived.emit(state.gift_kind)
	return true


func at_office_desk() -> bool:
	return layout.near(state.player.position, layout.office_desk_point())


func claim_gift(money_factor: float = 1.0) -> bool:
	if state.gift_kind < 0:
		return false
	var kind := state.gift_kind
	var money := state.gift_money * money_factor
	state.gift_kind = -1
	state.gift_money = 0.0
	state.gifts_opened += 1
	state.grant(money)
	gift_claimed.emit(kind, money)
	return true


func claim_gift_doubled() -> bool:
	if not claim_gift(GameConfig.AD_REWARD_FACTOR):
		return false
	state.ads_watched += 1
	return true


func _wake_nearby(delta: float) -> void:
	var position := state.player.position
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		var near_area := layout.desk_reach(key, station.moods.size()).has_point(position)
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if not station.is_staffed(desk):
				continue
			if mood.can_be_recalled() and near_area and layout.near(position, layout.desk_position(key, desk)):
				mood.recall_progress += delta
				if mood.recall_progress >= GameConfig.RECALL_TIME:
					recall(station, desk)
				continue
			mood.recall_progress = 0.0
			if not mood.needs_help():
				continue
			var close := layout.near(position, layout.slot_point(mood.slot)) if mood.is_away() else near_area and layout.near(position, layout.desk_position(key, desk))
			if mood.state == DeskMood.SLOW:
				if close:
					mood.resting += delta * (GameConfig.DRIVE_FACTOR - 1.0)
			elif close:
				mood.wake_progress += delta
				if mood.wake_progress >= Formulas.wake_time(mood.state):
					wake_up(station, desk, true)
			else:
				mood.wake_progress = 0.0


func recall(station: Station, desk: int) -> bool:
	if station.machine or desk < 0 or desk >= station.moods.size() or not station.is_staffed(desk) or not station.moods[desk].can_be_recalled():
		return false
	state.recalls += 1
	wake_up(station, desk, true)
	employee_recalled.emit(station.key, desk)
	return true


func start_job(station: Station, desk: int) -> bool:
	if station.jobs[desk] != null or station.inbox.is_empty():
		return false
	var for_specialist := station.is_specialist_desk(desk)
	var case_file: CaseFile = null
	if station.calls_citizens():
		case_file = _take_called(station, desk)
	else:
		case_file = station.take_next_case(_prioritize_for(station), for_specialist, _saturated_targets(station))
	if case_file == null:
		return false
	station.jobs[desk] = StationJob.new(case_file, Formulas.required_time(state, station, case_file, for_specialist), for_specialist)
	return true


func _saturated_targets(station: Station, candidates: Array[CaseFile] = []) -> Array[String]:
	var blocked: Array[String] = []
	if not station.is_entry():
		return blocked
	var pending := {}
	for case_file in station.outbox:
		pending[case_file.next_key()] = int(pending.get(case_file.next_key(), 0)) + 1
	for job in station.jobs:
		if job != null:
			pending[job.case_file.next_key()] = int(pending.get(job.case_file.next_key(), 0)) + 1
	for case_file in station.inbox:
		pending[case_file.next_key()] = int(pending.get(case_file.next_key(), 0)) + (1 if case_file.has_citizen() else 0)
	for case_file in candidates:
		if not pending.has(case_file.next_key()):
			pending[case_file.next_key()] = 0
	var lobby := state.lobby_capacity()
	var share := GameConfig.MAIL_TARGET_SHARE if station.is_mailroom() else 1.0
	for target_key: String in pending:
		var target := state.station(target_key)
		if target != null and target.inbox.size() + int(pending[target_key]) >= ceili(target.inbox_capacity(lobby) * share):
			blocked.append(target_key)
	return blocked


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
	if case_file.abandoned:
		station.jobs[desk] = null
		_record_output(station, desk)
		return true
	if case_file.invalid and station.has_reject_pile() and station.dept_id == case_file.dept_id:
		if not station.has_reject_space():
			return false
		station.jobs[desk] = null
		_record_output(station, desk)
		station.rejects += 1
		_reject_case(case_file)
		return true
	if not case_file.is_final_step() and station.outbox.size() + 1 + case_file.extras.size() > station.outbox_capacity():
		return false
	station.jobs[desk] = null
	_record_output(station, desk)
	if job.by_hand:
		_count_hands_on(station, case_file)
	apply_station_effect(station, case_file, job.by_specialist)
	if _misses_form(station, case_file):
		state.mail_promised.append(case_file.dept_id)
		dismiss_citizen(case_file)
		form_missing.emit(case_file.dept_id)
		return true
	if case_file.is_final_step():
		complete_case(case_file)
	else:
		station.outbox.append(case_file)
		_split_bundle(station, case_file)
		_after_service(case_file)
	return true


func _split_bundle(station: Station, case_file: CaseFile) -> void:
	if case_file.extras.is_empty():
		return
	var count := 0
	for dept_id in case_file.extras:
		var dept := state.department(dept_id)
		if dept == null or not dept.unlocked:
			continue
		var companion := create_case(dept)
		companion.companion = true
		companion.step = case_file.step
		station.outbox.append(companion)
		state.production.record(ProductionStats.ARRIVED, dept_id, state.play_time)
		count += 1
	case_file.extras.clear()
	state.bundles += 1
	applications_bundled.emit(case_file.dept_id, count)


func _misses_form(station: Station, case_file: CaseFile) -> bool:
	if station.kind != "review" or station.dept_id != case_file.dept_id or state.mailroom() == null:
		return false
	if case_file.mail or case_file.follow_up or case_file.big or case_file.invalid or GameConfig.is_customs(case_file.dept_id):
		return false
	if state.cases_completed < GameConfig.MISSING_FORM_MIN_CASES:
		return false
	return state.life_rng.randf() < GameConfig.MISSING_FORM_CHANCE


func _count_hands_on(station: Station, case_file: CaseFile) -> void:
	if station.dept_id.is_empty() or station.dept_id != case_file.dept_id:
		return
	var dept := state.department(station.dept_id)
	if dept == null or dept.is_onboarded():
		return
	dept.hands_on += 1
	if dept.is_onboarded():
		state.earn(Formulas.hands_on_reward(dept))
		state.add_reputation(GameConfig.HANDS_ON_REPUTATION)
		onboarding_completed.emit(dept.id)


func _record_output(station: Station, desk: int) -> void:
	station.moods[desk].output.add(state.play_time)
	state.production.record(ProductionStats.STATION, station.key, state.play_time)


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
	dismiss_citizen(case_file)
	state.cases_rejected += 1
	state.production.record(ProductionStats.REJECTED, dept.id, state.play_time)
	state.earn(Formulas.reject_fee(state, dept))
	case_rejected.emit(dept.id)


func complete_case(case_file: CaseFile) -> void:
	var dept := state.department(case_file.dept_id)
	dismiss_citizen(case_file)
	var smuggled := dept.is_customs() and case_file.suspicious and not case_file.scanned and state.rng.randf() < GameConfig.CONTRABAND_CHANCE
	var outcome := Formulas.case_outcome(state, case_file, smuggled)
	state.earn(outcome.money)
	state.add_reputation(outcome.reputation)
	state.cases_completed += 1
	state.production.record(ProductionStats.COMPLETED, dept.id, state.play_time)
	if case_file.flawed:
		state.cases_flawed += 1
	if case_file.contraband:
		state.contraband_seized += 1
	if smuggled:
		smuggling_missed.emit(dept.id)
	if bool(dept.config().follow_up) and not case_file.follow_up:
		dept.follow_ups.append(state.rng.randf_range(GameConfig.FOLLOW_UP_DELAY_MIN, GameConfig.FOLLOW_UP_DELAY_MAX))
	if case_file.mail:
		mail_answered.emit(case_file.dept_id, outcome.money)
		return
	case_completed.emit(case_file.dept_id, outcome.money, case_file.flawed)


func move_case(from: Station, case_index: int) -> bool:
	var case_file := from.outbox[case_index]
	var target := state.station(case_file.next_key())
	if target == null or not target.has_inbox_space(state.lobby_capacity()):
		return false
	from.outbox.remove_at(case_index)
	deliver(case_file, target, ProductionStats.BY_PLAYER)
	return true


func deliver(case_file: CaseFile, target: Station, carrier: String) -> void:
	if case_file.abandoned:
		return
	case_file.step += 1
	if carrier == ProductionStats.BY_PLAYER:
		case_file.handled += 1
	target.inbox.append(case_file)
	state.production.record(ProductionStats.TRANSFER, carrier, state.play_time)


func _update_player(delta: float) -> void:
	var player := state.player
	if player.input.length_squared() > 0.0:
		var speed := Formulas.player_speed(state)
		player.position = layout.clamp_to_world(player.position + player.input.limit_length(1.0) * speed * delta)
	player.transfer_timer -= delta
	if player.transfer_timer <= 0.0 and player_transfer():
		player.transfer_timer = GameConfig.TRANSFER_INTERVAL
	work_at_desk(Formulas.work_power(state) * delta)
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
			deliver(matching[0], station, ProductionStats.BY_PLAYER)
			return true
	if layout.near(player.position, layout.mail_floor_point()) and pick_up_mail():
		mail_picked_up.emit()
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


func work_at_desk(power: float) -> bool:
	var spot := player_desk()
	if spot.is_empty():
		return false
	return work_desk(state.station(spot[0]), spot[1], power)


func player_desk() -> Array:
	var position := state.player.position
	var best: Array = []
	var best_distance := GameConfig.INTERACT_RADIUS * GameConfig.INTERACT_RADIUS
	for key in state.ordered_station_keys():
		if not layout.area(key).grow(GameConfig.INTERACT_RADIUS).has_point(position):
			continue
		var station := state.station(key)
		for desk in station.desks:
			if not can_work_desk(station, desk):
				continue
			var distance := position.distance_squared_to(layout.desk_work_point(key, desk))
			if distance <= best_distance:
				best_distance = distance
				best = [key, desk]
	return best


func can_work_desk(station: Station, desk: int) -> bool:
	if desk < 0 or desk >= station.desks:
		return false
	if not station.is_staffed(desk):
		return true
	return not station.machine and (station.is_working(desk) or station.can_cover(desk))


func work_desk(station: Station, desk: int, power: float) -> bool:
	if is_halted(station) or station.is_output_jammed():
		return false
	if station.jobs[desk] == null:
		start_job(station, desk)
	var job := station.jobs[desk]
	if job == null or job.is_done():
		return false
	job.work_by_hand(power)
	return true


func sick_desk_near(position: Vector2) -> Array:
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			if station.is_staffed(desk) and station.moods[desk].is_sick() and layout.near(position, layout.desk_position(key, desk)):
				return [key, desk]
	return []


func can_leave_bonus(key: String, desk: int, tier: int) -> bool:
	var station := state.station(key)
	if station == null or station.machine or desk < 0 or desk >= station.moods.size() or not station.is_staffed(desk):
		return false
	var mood := station.moods[desk]
	if not mood.is_sick() or tier <= mood.bonus or tier > GameConfig.sick_bonus_tiers():
		return false
	return layout.near(state.player.position, layout.desk_position(key, desk)) and state.can_afford(Formulas.sick_bonus_price(state, mood, tier))


func leave_bonus(key: String, desk: int, tier: int) -> bool:
	if not can_leave_bonus(key, desk, tier):
		return false
	var mood := state.station(key).moods[desk]
	state.spend(Formulas.sick_bonus_price(state, mood, tier))
	mood.bonus = tier
	state.bonuses_paid += 1
	bonus_left.emit(key, desk, tier)
	return true


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


func rank_up(dept_id: String) -> bool:
	if not DepartmentRank.block_reason(state, dept_id).is_empty():
		return false
	var dept := state.department(dept_id)
	state.spend(DepartmentRank.next_cost(dept))
	dept.rank += 1
	department_ranked_up.emit(dept_id, dept.rank)
	return true


func _update_runners(delta: float) -> void:
	var unassignable := {}
	var speed := _runner_speed()
	for runner in state.runners:
		match runner.task:
			Runner.Task.IDLE:
				var group := "%s|%s" % [runner.role, runner.dept_id]
				if unassignable.has(group) or not assign_runner(runner):
					unassignable[group] = true
					runner.move_towards(layout.runner_home(), speed, delta)
			Runner.Task.TO_SOURCE:
				if _reservation_lost(runner):
					runner.clear_task()
					unassignable.clear()
					runner.move_towards(layout.runner_home(), speed, delta)
				elif _runner_to_source(runner, delta):
					unassignable.clear()
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
	var capacity := Formulas.runner_load(state, runner)
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.outbox.is_empty():
			continue
		var counts := {}
		for case_file in station.outbox:
			if runner_takes(runner, case_file, key):
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


func _reservation_lost(runner: Runner) -> bool:
	var station := state.station(runner.source)
	if station == null:
		return true
	for case_file in station.outbox:
		if case_file.next_key() == runner.target and runner_takes(runner, case_file, runner.source):
			return false
	return true


func runner_takes(runner: Runner, case_file: CaseFile, source_key: String) -> bool:
	if not runner.serves(case_file, source_key):
		return false
	if not state.is_piped(case_file):
		return true
	var source := state.station(source_key)
	return source != null and source.is_backlogged()


func _runner_to_source(runner: Runner, delta: float) -> bool:
	if not runner.move_towards(layout.output_point(runner.source), _runner_speed(), delta):
		return false
	var station := state.station(runner.source)
	var capacity := Formulas.runner_load(state, runner)
	var others := reserved_for(runner.source, runner.target) - runner.reserved
	_load_runner(runner, station, runner.target, mini(capacity, maxi(runner.reserved, _waiting_for(runner, station, runner.target) - others)))
	for target_key in _extra_targets(runner, station):
		if runner.items.size() >= capacity:
			break
		var free := _waiting_for(runner, station, target_key) - reserved_for(runner.source, target_key)
		_load_runner(runner, station, target_key, mini(capacity, runner.items.size() + free))
	if runner.items.is_empty():
		runner.clear_task()
		return true
	runner.task = Runner.Task.TO_TARGET
	runner.reserved = 0
	if runner.items_for(runner.target).is_empty():
		runner.target = _next_runner_target(runner)
	return true


func _waiting_for(runner: Runner, station: Station, target_key: String) -> int:
	var count := 0
	for case_file in station.outbox:
		if case_file.next_key() == target_key and runner_takes(runner, case_file, runner.source):
			count += 1
	return count


func _load_runner(runner: Runner, station: Station, target_key: String, limit: int) -> void:
	var index := 0
	while index < station.outbox.size() and runner.items.size() < limit:
		if station.outbox[index].next_key() == target_key and runner_takes(runner, station.outbox[index], runner.source):
			runner.items.append(station.outbox[index])
			station.outbox.remove_at(index)
		else:
			index += 1


func _extra_targets(runner: Runner, station: Station) -> Array[String]:
	var result: Array[String] = []
	var origin := layout.output_point(runner.source)
	for case_file in station.outbox:
		var target_key := case_file.next_key()
		if target_key == runner.target or result.has(target_key) or not runner_takes(runner, case_file, runner.source):
			continue
		var target := state.station(target_key)
		if target != null and target.has_inbox_space(state.lobby_capacity()):
			result.append(target_key)
	result.sort_custom(func(a: String, b: String) -> bool: return origin.distance_to(layout.input_point(a)) < origin.distance_to(layout.input_point(b)))
	return result


func _next_runner_target(runner: Runner) -> String:
	var best := ""
	var best_distance := INF
	for case_file in runner.items:
		var target_key := case_file.next_key()
		var distance := runner.position.distance_to(layout.input_point(target_key))
		if distance < best_distance:
			best_distance = distance
			best = target_key
	return best


func _runner_to_target(runner: Runner, delta: float) -> void:
	if not runner.move_towards(layout.input_point(runner.target), _runner_speed(), delta):
		return
	var target := state.station(runner.target)
	if target == null:
		return
	var index := 0
	while index < runner.items.size() and target.has_inbox_space(state.lobby_capacity()):
		if runner.items[index].next_key() == runner.target:
			deliver(runner.items[index], target, ProductionStats.BY_RUNNER)
			runner.items.remove_at(index)
		else:
			index += 1
	if runner.items.is_empty():
		runner.clear_task()
	elif runner.items_for(runner.target).is_empty():
		runner.target = _next_runner_target(runner)


func _pneumatic_transport(delta: float) -> void:
	if not state.has_upgrade("pneumatic_tubes"):
		return
	_advance_parcels(delta)
	_launch_parcels()


func _advance_parcels(delta: float) -> void:
	var index := state.tube_parcels.size() - 1
	while index >= 0:
		var parcel := state.tube_parcels[index]
		parcel.left = maxf(0.0, parcel.left - delta)
		if parcel.left <= 0.0:
			var target := state.station(parcel.to_key)
			if target == null:
				state.tube_parcels.remove_at(index)
				state.station(GameConfig.RECEPTION).outbox.append(parcel.case_file)
			elif target.has_inbox_space(state.lobby_capacity()):
				state.tube_parcels.remove_at(index)
				deliver(parcel.case_file, target, ProductionStats.BY_TUBE)
		index -= 1


func _launch_parcels() -> void:
	var load := {}
	for parcel in state.tube_parcels:
		load[parcel.tube_id()] = int(load.get(parcel.tube_id(), 0)) + 1
	for key in state.ordered_station_keys():
		var station := state.station(key)
		var index := 0
		while index < station.outbox.size():
			var case_file := station.outbox[index]
			var target_key := case_file.next_key()
			if target_key.is_empty() or not state.is_piped(case_file) or state.station(target_key) == null:
				index += 1
				continue
			var tube_id := RouteBuilder.tube_id(key, target_key)
			if int(load.get(tube_id, 0)) >= Formulas.tube_segment_capacity(state, tube_id):
				index += 1
				continue
			var parcel := TubeParcel.new(case_file, key, target_key)
			station.outbox.remove_at(index)
			parcel.left = maxf(0.2, WorldLayout.path_length(layout.tube_path(key, target_key)) / Formulas.tube_segment_speed(state, tube_id))
			load[tube_id] = int(load.get(tube_id, 0)) + 1
			state.tube_parcels.append(parcel)
			case_piped.emit(key, target_key, case_file.dept_id)


func _runner_speed() -> float:
	return Formulas.runner_speed(state)


func wake_everyone(include_sick: bool) -> int:
	var woken := 0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if station.is_staffed(desk) and mood.is_resting() and mood.is_sick() == include_sick and wake_up(station, desk, false):
				woken += 1
	return woken


func calm_office() -> void:
	for dispute in state.disputes.duplicate():
		end_dispute(dispute, false)
	if state.kranz:
		end_kranz(false)


func finish_all_jobs() -> int:
	var count := 0
	for key in state.ordered_station_keys():
		for job in state.station(key).jobs:
			if job != null and not job.is_done():
				job.progress = job.required
				count += 1
	return count
