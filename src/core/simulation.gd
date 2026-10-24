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
signal complaint_piped
signal review_posted(review: Review)
signal review_removed(outcome: String)
signal employee_woke(key: String, desk: int, by_player: bool)
signal visitor_arrived(angry: bool)
signal visitor_stopped(angry: bool)
signal intern_broke_down
signal intern_recovered(by_player: bool)
signal coffee_served(key: String, desk: int)
signal dispute_started(kind: String, dept_id: String)
signal dispute_ended(kind: String, dept_id: String, by_player: bool)
signal bonus_left(key: String, desk: int, tier: int)
signal sick_avoided(key: String, desk: int)
signal dispute_calmed(dept_id: String)

var state: GameState
var layout: WorldLayout
var _wake_clock := 0.0
var _pad_clock := 0.0


func _init(p_state: GameState) -> void:
	state = p_state
	layout = WorldLayout.get_default()
	state.production.begin(state.play_time)


func tick(delta: float) -> void:
	state.play_time += delta
	_update_event(delta)
	_age_cases(delta)
	_spawn_citizens(delta)
	_update_moods(delta)
	_update_complaints(delta)
	_update_visitors(delta)
	_update_intern(delta)
	_update_coffee_interns(delta)
	_update_disputes(delta)
	_update_kranz(delta)
	_update_sickness(delta)
	_work_stations(delta)
	_update_player(delta)
	_update_runners(delta)
	_update_collectors(delta)
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
				_complain_about_wait()
			index -= 1
	for case_file in state.carried_cases():
		case_file.age += delta


func _complain_about_wait() -> void:
	if state.cases_completed < GameConfig.COMPLAINT_MIN_CASES:
		return
	if spawn_visitor(false, true) == null:
		file_complaint()


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
		state.production.record(ProductionStats.ARRIVED, dept.id, state.play_time)
		case_arrived.emit(dept.id)
		return case_file
	state.production.record(ProductionStats.ARRIVED, dept.id, state.play_time)
	_lose_citizen(dept.id, GameConfig.REP_WALKED_OUT)
	state.walkouts += 1
	if spawn_visitor(true, true) == null:
		file_complaint()
	return null


func _lose_citizen(dept_id: String, reputation_change: float) -> void:
	state.citizens_lost += 1
	state.production.record(ProductionStats.LOST, dept_id, state.play_time)
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
				job.progress += delta * Formulas.event_speed(state, station) * Formulas.dispute_speed(state, station) * Formulas.official_speed(station.moods[desk])
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
				mood.resting += delta * (Formulas.sick_recovery_speed(mood.bonus) if mood.is_sick() else 1.0)
				if mood.resting >= Formulas.rest_limit(state, mood.state):
					wake_up(station, desk, false)
			elif station.jobs[desk] != null or not station.inbox.is_empty():
				if rate < 0.0:
					rate = Formulas.drowsiness_rate(state, station)
				mood.alert -= delta * rate * Formulas.official_drowsy_factor(mood)
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
	mood.wake(Formulas.wake_alert(state, mood.state))
	if by_player:
		state.wakes += 1
	employee_woke.emit(station.key, desk, by_player)
	return true


func _update_complaints(delta: float) -> void:
	if state.cases_completed >= GameConfig.COMPLAINT_MIN_CASES:
		state.complaint_timer -= delta
		if state.complaint_timer <= 0.0:
			state.complaint_timer = Formulas.complaint_interval(state, state.rng.randf())
			if spawn_visitor(false, true) == null:
				file_complaint()
	var review_drain := state.review_drain()
	if review_drain > 0.0:
		state.add_reputation(-review_drain * GameConfig.REVIEW_DRAIN * delta)
	state.review_fear = maxf(0.0, state.review_fear - delta)
	_update_complaint_tube(delta)
	var player := state.player
	player.complaint_timer -= delta
	if player.complaint_timer <= 0.0 and move_complaints():
		player.complaint_timer = GameConfig.COMPLAINT_TRANSFER_INTERVAL


func _free_visitor_slot() -> int:
	for slot in GameConfig.VISITOR_SLOTS:
		var taken := false
		for visitor in state.visitors:
			if visitor.slot == slot and visitor.phase != ComplaintVisitor.Phase.LEAVING:
				taken = true
				break
		if not taken:
			return slot
	return -1


func _free_guard() -> int:
	for guard in state.guards:
		var busy := false
		for visitor in state.visitors:
			if visitor.guard == guard and visitor.phase != ComplaintVisitor.Phase.LEAVING:
				busy = true
				break
		if not busy:
			return guard
	return -1


func _stopping_guard() -> int:
	var guard := _free_guard()
	if guard < 0 or state.life_rng.randf() >= Formulas.guard_block_chance(state):
		return -1
	return guard


func spawn_visitor(angry: bool, files_complaint: bool) -> ComplaintVisitor:
	var guard := _stopping_guard()
	var slot := -1 if guard >= 0 else _free_visitor_slot()
	if guard < 0 and slot < 0:
		return null
	var visitor := ComplaintVisitor.new(layout.door_in())
	visitor.angry = angry
	visitor.files_complaint = files_complaint and guard < 0
	visitor.slot = slot
	visitor.guard = guard
	var dialogs := GameConfig.GUARD_DIALOGS if guard >= 0 else (GameConfig.YELL_DIALOGS if angry else GameConfig.VISITOR_DIALOGS)
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
		match visitor.phase:
			ComplaintVisitor.Phase.ARRIVING:
				if visitor.is_stopped():
					if visitor.move_towards(layout.guard_stop_spot(visitor.guard), GameConfig.VISITOR_SPEED, delta):
						_start_stop(visitor)
				elif visitor.move_towards(layout.visitor_spot(visitor.slot), GameConfig.VISITOR_SPEED, delta):
					_start_talking(visitor)
			ComplaintVisitor.Phase.STOPPED:
				visitor.timer -= delta
				if visitor.timer <= 0.0:
					visitor.phase = ComplaintVisitor.Phase.LEAVING
			ComplaintVisitor.Phase.TALKING:
				visitor.timer -= delta
				if visitor.angry and state.has_research("shredder_service"):
					var target := _calmest_intern_at_desk()
					if target != null:
						target.stress = minf(1.0, target.stress + GameConfig.INTERN_YELL_RATE * delta)
				if visitor.timer <= 0.0:
					visitor.phase = ComplaintVisitor.Phase.LEAVING
			ComplaintVisitor.Phase.LEAVING:
				if visitor.move_towards(layout.door_out(), GameConfig.VISITOR_SPEED, delta):
					state.visitors.remove_at(index)
		index -= 1


func _calmest_intern_at_desk() -> ComplaintIntern:
	var best: ComplaintIntern = null
	for unit in state.all_interns():
		if unit.is_at_desk() and (best == null or unit.stress < best.stress):
			best = unit
	return best


func _start_stop(visitor: ComplaintVisitor) -> void:
	visitor.phase = ComplaintVisitor.Phase.STOPPED
	visitor.duration = GameConfig.GUARD_STOP_SECONDS
	visitor.timer = visitor.duration
	state.visitors_stopped += 1
	visitor_stopped.emit(visitor.angry)


func _start_talking(visitor: ComplaintVisitor) -> void:
	visitor.phase = ComplaintVisitor.Phase.TALKING
	visitor.duration = GameConfig.VISITOR_ANGRY_TALK_SECONDS if visitor.angry else GameConfig.VISITOR_TALK_SECONDS
	visitor.timer = visitor.duration
	if visitor.files_complaint:
		visitor.files_complaint = false
		file_complaint()


func _update_intern(delta: float) -> void:
	if not state.has_research("shredder_service"):
		return
	var units := state.all_interns()
	for unit in units:
		_update_intern_unit(unit, units.size(), delta)


func _update_intern_unit(intern: ComplaintIntern, team_size: int, delta: float) -> void:
	match intern.mood:
		ComplaintIntern.Mood.DESK:
			intern.move_towards(layout.intern_home(intern.slot), GameConfig.INTERN_SPEED, delta)
			var over := float(state.complaints) / team_size - Formulas.intern_stress_free(state)
			if over > 0.0:
				intern.stress += over * GameConfig.INTERN_STRESS_RATE * delta
			else:
				intern.stress -= GameConfig.INTERN_CALM_RATE * delta
			intern.stress = clampf(intern.stress, 0.0, 1.0)
			if intern.stress >= 1.0:
				intern.mood = ComplaintIntern.Mood.TO_LOO
				intern.comfort_progress = 0.0
				state.breakdowns += 1
				intern_broke_down.emit()
				return
			_tick_shred_clock(intern, delta)
		ComplaintIntern.Mood.TO_SHREDDER:
			if intern.move_towards(layout.intern_shred_point(intern.slot), GameConfig.INTERN_SPEED, delta):
				var left := Formulas.intern_capacity(state)
				left -= shred_complaints(left, false)
				if left > 0:
					shred_rejects(left, false)
				intern.mood = ComplaintIntern.Mood.FROM_SHREDDER
		ComplaintIntern.Mood.FROM_SHREDDER:
			if intern.move_towards(layout.intern_home(intern.slot), GameConfig.INTERN_SPEED, delta):
				intern.mood = ComplaintIntern.Mood.DESK
		ComplaintIntern.Mood.TO_LOO:
			if intern.move_towards(layout.intern_cry_point(intern.slot), GameConfig.INTERN_SPEED, delta):
				intern.mood = ComplaintIntern.Mood.CRYING
				intern.timer = 0.0
			_comfort_intern(intern, delta)
		ComplaintIntern.Mood.CRYING:
			intern.timer += delta
			if intern.timer >= Formulas.intern_cry_seconds(state):
				_recover_intern(intern, GameConfig.INTERN_RECOVERED_STRESS, false)
			else:
				_comfort_intern(intern, delta)
		ComplaintIntern.Mood.RETURNING:
			if intern.move_towards(layout.intern_home(intern.slot), GameConfig.INTERN_SPEED, delta):
				intern.mood = ComplaintIntern.Mood.DESK


func _tick_shred_clock(intern: ComplaintIntern, delta: float) -> void:
	var delay: float = GameConfig.SHREDDER_DELAYS[state.research_level("shredder_service")]
	if delay > 0.0 and (state.complaints > 0 or state.rejects_waiting() > 0):
		intern.work_timer += delta
		if intern.work_timer >= delay:
			intern.work_timer = 0.0
			intern.mood = ComplaintIntern.Mood.TO_SHREDDER
	else:
		intern.work_timer = 0.0


func _comfort_intern(intern: ComplaintIntern, delta: float) -> void:
	if not layout.near(state.player.position, intern.position):
		intern.comfort_progress = 0.0
		return
	intern.comfort_progress += delta
	if intern.comfort_progress >= GameConfig.INTERN_COMFORT_TIME:
		_recover_intern(intern, GameConfig.INTERN_COMFORT_STRESS, true)


func _recover_intern(intern: ComplaintIntern, stress: float, by_player: bool) -> void:
	intern.mood = ComplaintIntern.Mood.RETURNING
	intern.stress = stress
	intern.timer = 0.0
	intern.comfort_progress = 0.0
	intern_recovered.emit(by_player)


func _update_coffee_interns(delta: float) -> void:
	for intern in state.coffee_interns:
		match intern.task:
			CoffeeIntern.Task.IDLE:
				_idle_coffee_intern(intern, delta)
			CoffeeIntern.Task.TO_MACHINE:
				if intern.move_towards(layout.coffee_brew_point(), GameConfig.COFFEE_INTERN_SPEED, delta):
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
	intern.move_towards(layout.coffee_home(), GameConfig.COFFEE_INTERN_SPEED * 0.5, delta)


func _coffee_to_desk(intern: CoffeeIntern, delta: float) -> void:
	if not _coffee_target_valid(intern.key, intern.desk):
		intern.clear_task()
		return
	if not intern.move_towards(layout.desk_position(intern.key, intern.desk) + Vector2(0.0, 26.0), GameConfig.COFFEE_INTERN_SPEED, delta):
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
	return station.is_staffed(desk) and not mood.is_resting() and mood.alert < Formulas.coffee_threshold(state)


func _assign_coffee_target(intern: CoffeeIntern) -> bool:
	var best_alert := INF
	var best_key := ""
	var best_desk := -1
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine or (station.inbox.is_empty() and station.active_jobs() == 0):
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
	if state.cases_completed >= GameConfig.DISPUTE_MIN_CASES:
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
	state.production.record(ProductionStats.DISPUTE, dept_id, state.play_time)
	dispute_started.emit(kind, dept_id)
	return dispute


func end_dispute(dispute: Dispute, by_player: bool) -> void:
	state.disputes.erase(dispute)
	state.disputes_solved += 1
	if by_player:
		state.add_reputation(GameConfig.MEDIATE_REPUTATION)
	dispute_ended.emit(dispute.kind, dispute.dept_id, by_player)


func file_complaint() -> void:
	if state.complaints >= Formulas.complaint_cap(state):
		complaint_filed.emit(true)
		_maybe_post_review()
		return
	state.complaints += 1
	state.complaints_filed += 1
	complaint_filed.emit(false)
	_maybe_post_review()


func _maybe_post_review() -> void:
	if state.negative_review_count() >= GameConfig.MAX_NEGATIVE_REVIEWS:
		return
	var chance := GameConfig.REVIEW_CHANCE
	if state.review_fear > 0.0:
		chance *= GameConfig.REVIEW_FEAR_FACTOR
	if state.review_rng.randf() >= chance:
		return
	var stars := 1 if state.review_rng.randf() < GameConfig.REVIEW_ONE_STAR_SHARE else 2
	review_posted.emit(state.add_review(stars))


func _maybe_praise(case_file: CaseFile) -> void:
	if case_file.flawed:
		if state.review_rng.randf() < GameConfig.REVIEW_FLAWED_CHANCE:
			review_posted.emit(state.add_review(3))
		return
	if state.review_rng.randf() >= GameConfig.REVIEW_PRAISE_CHANCE:
		return
	var roll := state.review_rng.randf()
	var stars := 5 if roll < 0.6 else (4 if roll < 0.9 else 3)
	review_posted.emit(state.add_review(stars))


func _update_complaint_tube(delta: float) -> void:
	var level := state.research_level("complaint_tube")
	var delay: float = GameConfig.COMPLAINT_TUBE_DELAYS[level]
	if delay > 0.0 and state.complaints > 0:
		state.complaint_tube_timer += delta
		if state.complaint_tube_timer >= delay:
			state.complaint_tube_timer = 0.0
			complaint_piped.emit()
			shred_complaints(1, false)
	else:
		state.complaint_tube_timer = 0.0


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
		review.force_praise(state.review_rng.randi_range(0, GameConfig.REVIEW_FORCED_TEXTS - 1))
		state.review_fear = GameConfig.REVIEW_FEAR_SECONDS
		state.earn(cost * GameConfig.REVIEW_LAWSUIT_PAYOUT_FACTOR)
		state.add_reputation(GameConfig.REVIEW_LAWSUIT_REPUTATION)
		review_removed.emit("won")
	else:
		review.downgrade(state.review_rng.randi_range(0, GameConfig.review_texts(maxi(1, review.stars - 1)) - 1))
		state.add_reputation(-GameConfig.REVIEW_LAWSUIT_LOSS)
		review_removed.emit("lost")
	return true


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


func shred_case(case_file: CaseFile) -> bool:
	state.cases_shredded += 1
	_lose_citizen(case_file.dept_id, -GameConfig.SHRED_CASE_PENALTY)
	case_shredded.emit(case_file.dept_id)
	return true


func _update_collectors(delta: float) -> void:
	for collector in state.collectors:
		if collector.loaded > 0:
			if collector.move_towards(layout.shredder_point(), GameConfig.COLLECTOR_SPEED, delta):
				state.earn(GameConfig.REJECT_SHRED_REWARD * collector.loaded)
				collector.loaded = 0
				complaint_shredded.emit(false)
			continue
		if collector.source.is_empty():
			collector.source = _collector_target(collector)
		if collector.source.is_empty():
			collector.move_towards(layout.collector_home(), GameConfig.COLLECTOR_SPEED * 0.5, delta)
			continue
		if collector.move_towards(layout.reject_point(collector.source), GameConfig.COLLECTOR_SPEED, delta):
			var station := state.station(collector.source)
			collector.loaded = mini(GameConfig.COLLECTOR_CAPACITY, station.rejects)
			station.rejects -= collector.loaded
			collector.source = ""


func _collector_target(collector: RejectCollector) -> String:
	var best := ""
	var best_distance := INF
	for key in state.ordered_station_keys():
		var station := state.station(key)
		var claimed := 0
		for other in state.collectors:
			if other != collector and other.source == key:
				claimed += GameConfig.COLLECTOR_CAPACITY
		if station.rejects - claimed <= 0:
			continue
		var distance := collector.position.distance_to(layout.reject_point(key))
		if distance < best_distance:
			best_distance = distance
			best = key
	return best


func move_complaints() -> bool:
	var player := state.player
	if layout.near(player.position, layout.shredder_point()):
		if player.complaints > 0:
			return shred_complaints(1, true) > 0
		if player.rejects > 0:
			return shred_rejects(1, true) > 0
		if not player.items.is_empty():
			return shred_case(player.items.pop_back())
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
		state.sick_timer = Formulas.sick_interval(state, state.rng.randf())
		report_sick()
	_update_phones(delta)


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
			phone_call.progress += delta
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
			if station.is_staffed(desk) and mood.can_be_called() and mood.resting > longest and state.call_for(key, desk) == null:
				longest = mood.resting
				best = [key, desk]
	return best


func _finish_call(phone_call: PhoneCall) -> void:
	var station := state.station(phone_call.key)
	var by_player := phone_call.by_player()
	if phone_call.is_incoming():
		station.moods[phone_call.desk].reported = true
		state.calls_answered += 1
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
	state.kranz_timer = Formulas.kranz_interval(state, state.rng.randf())
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
	if station.kind == "reception" and not state.reception_may_admit():
		return false
	var for_specialist := station.is_specialist_desk(desk)
	var case_file := station.take_next_case(_prioritize_for(station), for_specialist, _saturated_targets(station))
	if case_file == null:
		return false
	station.jobs[desk] = StationJob.new(case_file, Formulas.required_time(state, station, case_file, for_specialist), for_specialist)
	return true


func _saturated_targets(station: Station) -> Array[String]:
	var blocked: Array[String] = []
	if not station.is_entry():
		return blocked
	var pending := {}
	for case_file in station.outbox:
		pending[case_file.next_key()] = int(pending.get(case_file.next_key(), 0)) + 1
	for job in station.jobs:
		if job != null:
			pending[job.case_file.next_key()] = int(pending.get(job.case_file.next_key(), 0)) + 1
	for target_key: String in pending:
		var target := state.station(target_key)
		if target != null and target.inbox.size() + int(pending[target_key]) >= target.inbox_capacity(state.lobby_capacity()):
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
	if case_file.invalid and station.has_reject_pile() and station.dept_id == case_file.dept_id:
		if not station.has_reject_space():
			return false
		station.jobs[desk] = null
		_record_output(station, desk)
		station.rejects += 1
		_reject_case(case_file)
		return true
	if not case_file.is_final_step() and not station.has_outbox_space():
		return false
	station.jobs[desk] = null
	_record_output(station, desk)
	apply_station_effect(station, case_file, job.by_specialist)
	if case_file.is_final_step():
		complete_case(case_file)
	else:
		station.outbox.append(case_file)
	return true


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
	state.cases_rejected += 1
	state.production.record(ProductionStats.REJECTED, dept.id, state.play_time)
	state.earn(float(dept.config().reward) * Formulas.reputation_multiplier(state) * GameConfig.REJECT_FEE_FACTOR)
	case_rejected.emit(dept.id)


func complete_case(case_file: CaseFile) -> void:
	var dept := state.department(case_file.dept_id)
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
	_maybe_praise(case_file)
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
		_cover_absent_desks(_wake_clock)
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
		worked = work_desk(station, desk, power) or worked
	return worked


func work_desk(station: Station, desk: int, power: float) -> bool:
	if station.jobs[desk] == null:
		start_job(station, desk)
	var job := station.jobs[desk]
	if job == null or job.is_done():
		return false
	job.progress += power
	return true


func _cover_absent_desks(delta: float) -> void:
	var position := state.player.position
	var power := Formulas.work_power(state) * delta
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if station.machine:
			continue
		for desk in station.moods.size():
			if station.can_cover(desk) and layout.near(position, layout.desk_position(key, desk)):
				work_desk(station, desk, power)


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
	return layout.near(state.player.position, layout.desk_position(key, desk)) and state.can_afford(Formulas.sick_bonus_cost(state, tier))


func leave_bonus(key: String, desk: int, tier: int) -> bool:
	if not can_leave_bonus(key, desk, tier):
		return false
	state.spend(Formulas.sick_bonus_cost(state, tier))
	state.station(key).moods[desk].bonus = tier
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


func _pneumatic_transport(delta: float) -> void:
	if not state.has_research("pneumatic_tubes"):
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
				deliver(parcel.case_file, target)
		index -= 1


func _launch_parcels() -> void:
	var capacity := Formulas.tube_capacity(state)
	var load := {}
	for parcel in state.tube_parcels:
		load[parcel.tube_id()] = int(load.get(parcel.tube_id(), 0)) + 1
	for key in state.ordered_station_keys():
		var station := state.station(key)
		var index := 0
		while index < station.outbox.size():
			var case_file := station.outbox[index]
			var target_key := case_file.next_key()
			var parcel := TubeParcel.new(case_file, key, target_key)
			if target_key.is_empty() or state.station(target_key) == null or int(load.get(parcel.tube_id(), 0)) >= capacity:
				index += 1
				continue
			station.outbox.remove_at(index)
			parcel.left = maxf(0.2, WorldLayout.path_length(layout.tube_path(key, target_key)) / GameConfig.TUBE_SPEED)
			load[parcel.tube_id()] = int(load.get(parcel.tube_id(), 0)) + 1
			state.tube_parcels.append(parcel)
			case_piped.emit(key, target_key, case_file.dept_id)
