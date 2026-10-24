class_name Formulas
extends RefCounted


static func cost_multiplier_for(station: Station) -> float:
	if station.is_shared():
		return float(GameConfig.SHARED_STATIONS.get(station.key, {}).get("cost_multiplier", 1.0))
	return float(GameConfig.department(station.dept_id).get("cost_multiplier", 1.0))


static func desk_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).desk_cost) * cost_multiplier_for(station) * pow(GameConfig.DESK_GROWTH, station.desks - 1)


static func hire_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).hire_cost) * cost_multiplier_for(station) * pow(GameConfig.HIRE_GROWTH, station.staff)


static func upgrade_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).upgrade_cost) * cost_multiplier_for(station) * pow(GameConfig.UPGRADE_GROWTH, station.level - 1)


static func specialist_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).hire_cost) * 5.0 * cost_multiplier_for(station) * pow(GameConfig.SPECIALIST_GROWTH, station.specialists)


static func supervisor_cost(dept: Department) -> float:
	return 1000.0 * float(dept.config().cost_multiplier) * pow(GameConfig.SUPERVISOR_GROWTH, dept.supervisors)


static func runner_cost(state: GameState) -> float:
	return GameConfig.RUNNER_COST * pow(GameConfig.RUNNER_GROWTH, state.runners.size())


static func research_cost(research_id: String, level: int) -> float:
	var config: Dictionary = GameConfig.RESEARCH[research_id]
	return float(config.cost) * pow(float(config.growth), level)


static func research_speed_multiplier(state: GameState, kind: String) -> float:
	if not GameConfig.RESEARCH_SPEED.has(kind):
		return 1.0
	var entry: Dictionary = GameConfig.RESEARCH_SPEED[kind]
	return 1.0 + float(entry.bonus) * state.research_level(entry.research)


static func station_speed(state: GameState, station: Station) -> float:
	var speed := 1.0 + GameConfig.LEVEL_SPEED_BONUS * (station.level - 1)
	speed *= research_speed_multiplier(state, station.kind)
	var dept := state.department(station.dept_id)
	if dept != null:
		speed *= 1.0 + GameConfig.SUPERVISOR_BONUS * dept.supervisors
	return speed


static func complex_time_factor(state: GameState, by_specialist: bool) -> float:
	if by_specialist:
		return 1.0
	var penalty := GameConfig.COMPLEX_TIME_PENALTY
	if state.has_research("ai_classification"):
		penalty *= GameConfig.AI_COMPLEX_FACTOR
	return 1.0 + penalty


static func base_time(station: Station, case_dept: Department, complex: bool, by_specialist: bool, state: GameState) -> float:
	var config := case_dept.config()
	var time := float(GameConfig.station_kind(station.kind).base_time)
	if station.kind == "review" and station.dept_id == case_dept.id:
		time = float(config.review_time)
	elif station.kind == "signature":
		time = float(config.signature_time)
	if station.kind == "review":
		time *= float(GameConfig.THOROUGHNESS[case_dept.thoroughness].time)
	if complex and (station.kind == "review" or station.kind == "inspection"):
		time *= complex_time_factor(state, by_specialist)
	return time


static func required_time(state: GameState, station: Station, case_file: CaseFile, by_specialist: bool = false) -> float:
	var dept := state.department(case_file.dept_id)
	var time := base_time(station, dept, case_file.complex, by_specialist, state) / station_speed(state, station)
	return time * GameConfig.BIG_CASE_TIME_FACTOR if case_file.big else time


static func error_chance(state: GameState, dept: Department, by_specialist: bool = false) -> float:
	var chance := float(GameConfig.THOROUGHNESS[dept.thoroughness].error)
	chance *= pow(GameConfig.QUALITY_TRAINING_FACTOR, state.research_level("quality_training"))
	if state.has_research("ai_classification"):
		chance *= GameConfig.AI_ERROR_FACTOR
	if by_specialist:
		chance *= GameConfig.SPECIALIST_ERROR_FACTOR
	return clampf(chance, 0.0, 1.0)


static func flag_chance(station: Station) -> float:
	return clampf(GameConfig.FLAG_BASE_CHANCE + GameConfig.FLAG_PER_SPECIALIST * station.specialists, 0.0, 1.0)


static func reputation_multiplier(state: GameState) -> float:
	return 1.0 + sqrt(state.reputation) / GameConfig.REPUTATION_REWARD_DIVISOR


static func popularity(state: GameState) -> float:
	return minf(1.0 + sqrt(state.reputation) / GameConfig.POPULARITY_DIVISOR, GameConfig.MAX_POPULARITY)


static func event_arrival_multiplier(state: GameState, dept_id: String) -> float:
	if state.event_id.is_empty():
		return 1.0
	var event: Dictionary = GameConfig.EVENTS[state.event_id]
	var target := str(event.department) if not str(event.department).is_empty() else state.event_scope
	if target.is_empty() or target == dept_id:
		return float(event.arrival)
	return 1.0


static func event_effective(state: GameState) -> bool:
	if state.event_id.is_empty():
		return false
	return not (bool(GameConfig.EVENTS[state.event_id].get("pending", false)) and state.event_choice.is_empty())


static func event_speed(state: GameState, station: Station) -> float:
	if not event_effective(state):
		return 1.0
	var event: Dictionary = GameConfig.EVENTS[state.event_id]
	var speed := float(event.get("speed", 1.0))
	if is_equal_approx(speed, 1.0):
		return 1.0
	var scope := state.event_scope
	if scope.is_empty() or station.key == scope or station.dept_id == scope:
		return speed
	return 1.0


static func event_drowsy(state: GameState) -> float:
	if not event_effective(state):
		return 1.0
	return float(GameConfig.EVENTS[state.event_id].get("drowsy", 1.0))


static func event_patience(state: GameState) -> float:
	if not event_effective(state):
		return 1.0
	return float(GameConfig.EVENTS[state.event_id].get("patience", 1.0))


static func event_duration(state: GameState, event_id: String) -> float:
	var event: Dictionary = GameConfig.EVENTS[event_id]
	var duration := float(event.get("duration", GameConfig.EVENT_DURATION))
	if bool(event.get("pending", false)):
		return GameConfig.EVENT_CHOICE_SECONDS
	var research := str(event.get("mitigation", ""))
	if not research.is_empty():
		duration *= maxf(GameConfig.EVENT_MIN_DURATION_FACTOR, 1.0 - GameConfig.EVENT_MITIGATION * state.research_level(research))
	return duration


static func population(state: GameState) -> int:
	return maxi(GameConfig.POPULATION_BASE, GameConfig.POPULATION_BASE + state.cases_completed * GameConfig.POPULATION_PER_CASE - state.citizens_lost * GameConfig.POPULATION_PER_LOST)


static func settlement(state: GameState) -> String:
	var inhabitants := population(state)
	var result := "village"
	for rank in GameConfig.SETTLEMENT_RANKS:
		if inhabitants >= int(rank.population):
			result = str(rank.id)
	return result


static func demand_growth(state: GameState) -> float:
	return 1.0 + GameConfig.DEMAND_GROWTH_SCALE * log(1.0 + state.cases_completed / GameConfig.DEMAND_GROWTH_DIVISOR) / log(10.0)


static func is_invalid_case(state: GameState, serial: int) -> bool:
	if state.cases_completed < GameConfig.REJECT_MIN_CASES:
		return false
	return float(posmod(hash([state.rng.seed, serial]), 1000)) / 1000.0 < GameConfig.REJECT_CHANCE


static func full_boxes(state: GameState, dept: Department) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null:
			continue
		if not station.is_final() and not station.has_outbox_space():
			result.append({"key": key, "side": "out"})
		if not station.has_inbox_space(state.lobby_capacity()):
			result.append({"key": key, "side": "in"})
		if station.has_reject_pile() and not station.has_reject_space():
			result.append({"key": key, "side": "rejects"})
	return result


static func arrival_interval(state: GameState, dept: Department) -> float:
	var rate := popularity(state)
	rate *= 1.0 + GameConfig.PORTAL_ARRIVAL_BONUS * state.research_level("online_portal")
	rate *= event_arrival_multiplier(state, dept.id)
	rate *= demand_growth(state)
	return float(dept.config().arrival_interval) / rate


static func patience(state: GameState) -> float:
	return GameConfig.BASE_PATIENCE * (1.0 + GameConfig.PATIENCE_PER_LOBBY_LEVEL * state.research_level("comfortable_lobby")) * event_patience(state)


static func carry_capacity(state: GameState) -> int:
	return GameConfig.PLAYER_BASE_CAPACITY + GameConfig.PLAYER_CAPACITY_PER_LEVEL * state.research_level("briefcase")


static func wake_time(rest_state: String) -> float:
	return GameConfig.ENCOURAGE_TIME if rest_state == DeskMood.LOO else GameConfig.WAKE_TIME


static func hr_cost(state: GameState) -> float:
	return GameConfig.HR_COST * pow(GameConfig.HR_GROWTH, state.hr)


static func complaint_malus_per_minute(state: GameState) -> float:
	return state.complaints * GameConfig.COMPLAINT_DRAIN * 60.0


static func runner_capacity(state: GameState) -> int:
	return GameConfig.RUNNER_BASE_CAPACITY + GameConfig.RUNNER_CAPACITY_PER_LEVEL * state.research_level("trolleys")


static func alert_duration(state: GameState) -> float:
	return GameConfig.BASE_ALERT_SECONDS * (1.0 + GameConfig.COFFEE_ALERT_BONUS * state.research_level("coffee"))


static func roll_alert(state: GameState) -> float:
	return alert_duration(state) * state.rng.randf_range(1.0 - GameConfig.ALERT_VARIANCE, 1.0 + GameConfig.ALERT_VARIANCE)


static func wake_alert(state: GameState, previous_state: String) -> float:
	var factor := 1.0
	if previous_state == DeskMood.FETCH:
		factor = GameConfig.FETCH_ALERT_FACTOR + GameConfig.COFFEE_MACHINE_ALERT_BONUS * state.research_level("coffee_machine")
	elif previous_state == DeskMood.SLOW:
		factor = GameConfig.FETCH_ALERT_FACTOR
	return roll_alert(state) * factor


static func doze_weights(state: GameState) -> Dictionary:
	var weights: Dictionary = GameConfig.DOZE_WEIGHTS.duplicate()
	var shift := minf(float(weights["chat"]), GameConfig.KITCHEN_CHAT_SHIFT * state.research_level("kitchen"))
	weights["chat"] = float(weights["chat"]) - shift
	weights["fetch"] = float(weights["fetch"]) + shift
	return weights


static func drowsiness_rate(state: GameState, station: Station) -> float:
	var supervisors := 0
	var dept := state.department(station.dept_id)
	if dept != null:
		supervisors = dept.supervisors
	else:
		for user in state.departments_using(station.key):
			supervisors = maxi(supervisors, user.supervisors)
	return pow(GameConfig.SUPERVISOR_DROWSY_FACTOR, supervisors) * event_drowsy(state)


static func rest_limit(state: GameState, rest_state: String) -> float:
	if rest_state == DeskMood.FETCH:
		return GameConfig.FETCH_SECONDS * pow(GameConfig.COFFEE_MACHINE_FETCH_FACTOR, state.research_level("coffee_machine"))
	if rest_state == DeskMood.SLOW:
		return GameConfig.SLOW_SECONDS
	if rest_state == DeskMood.SICK:
		return GameConfig.SICK_SECONDS
	if rest_state == DeskMood.LOO:
		var loo_delay: float = GameConfig.WAKE_SERVICE_DELAYS[state.research_level("wake_service")]
		return GameConfig.LOO_SECONDS if loo_delay < 0.0 else minf(GameConfig.LOO_SECONDS, loo_delay)
	var delay: float = GameConfig.WAKE_SERVICE_DELAYS[state.research_level("wake_service")]
	if rest_state == DeskMood.COFFEE:
		return GameConfig.COFFEE_BREAK_SECONDS if delay < 0.0 else minf(GameConfig.COFFEE_BREAK_SECONDS, delay)
	return INF if delay < 0.0 else delay


static func work_power(state: GameState) -> float:
	return GameConfig.PLAYER_WORK_POWER * (1.0 + GameConfig.PLAYER_WORK_PER_LEVEL * state.research_level("work_ethic"))


static func audit_factor(state: GameState) -> float:
	return GameConfig.AUDIT_FACTOR if state.event_id == "audit_visit" else 1.0


static func case_outcome(state: GameState, case_file: CaseFile, smuggled: bool = false) -> Dictionary:
	var config := GameConfig.department(case_file.dept_id)
	var money := float(config.reward) * reputation_multiplier(state)
	var rep := 0.0
	if case_file.follow_up:
		money *= GameConfig.FOLLOW_UP_REWARD_FACTOR
	if case_file.complex:
		money *= GameConfig.COMPLEX_REWARD_FACTOR
	if case_file.big:
		money *= GameConfig.BIG_CASE_REWARD_FACTOR
	if case_file.urgent:
		if case_file.is_overdue():
			rep += GameConfig.REP_URGENT_LATE
		else:
			money *= GameConfig.URGENT_REWARD_FACTOR
			rep += GameConfig.REP_URGENT_ON_TIME
	if case_file.contraband:
		money *= GameConfig.CONTRABAND_REWARD_FACTOR
		rep += GameConfig.REP_CONTRABAND
	if smuggled:
		return {"money": 0.0, "reputation": rep + GameConfig.REP_SMUGGLED * audit_factor(state)}
	if case_file.flawed:
		money *= GameConfig.FLAWED_REWARD_FACTOR
		rep += GameConfig.REP_FLAWED * audit_factor(state)
	else:
		rep += GameConfig.REP_CORRECT * audit_factor(state)
	return {"money": money, "reputation": rep}


static func demand(state: GameState, dept: Department) -> float:
	return 1.0 / arrival_interval(state, dept)


static func station_demand(state: GameState, key: String) -> float:
	var total := 0.0
	for dept in state.departments_using(key):
		total += demand(state, dept)
	return total


static func station_throughput(state: GameState, station: Station) -> float:
	var users := state.departments_using(station.key)
	if users.is_empty() or station.workers() <= 0:
		return 0.0
	var total_time := 0.0
	var total_weight := 0.0
	for dept in users:
		var weight := demand(state, dept)
		var complex_chance := float(dept.config().complex_chance)
		var simple_time := base_time(station, dept, false, false, state)
		var complex_time := base_time(station, dept, true, station.specialists > 0, state)
		total_time += weight * lerpf(simple_time, complex_time, complex_chance)
		total_weight += weight
	var average_time := total_time / total_weight / station_speed(state, station)
	return station.workers() / average_time


static func transport_throughput(state: GameState) -> float:
	if state.has_research("pneumatic_tubes"):
		return INF
	return state.runners.size() * runner_capacity(state) / GameConfig.RUNNER_TRIP_ESTIMATE


static func transfers_per_case(dept: Department) -> int:
	return maxi(1, RouteBuilder.build(CaseFile.new(dept.id)).size() - 1)


static func total_transfer_demand(state: GameState) -> float:
	var total := 0.0
	for dept in state.unlocked_departments():
		total += demand(state, dept) * transfers_per_case(dept)
	return total


static func department_transport(state: GameState, dept: Department) -> float:
	var capacity := transport_throughput(state)
	if is_inf(capacity):
		return INF
	var total := total_transfer_demand(state)
	var share := demand(state, dept) * transfers_per_case(dept) / total if total > 0.0 else 0.0
	return capacity * share / transfers_per_case(dept)


static func station_share(state: GameState, station: Station, dept: Department) -> float:
	var total := station_demand(state, station.key)
	if total <= 0.0:
		return 0.0
	return station_throughput(state, station) * demand(state, dept) / total


static func department_throughput(state: GameState, dept: Department) -> float:
	var result := minf(demand(state, dept), department_transport(state, dept))
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null:
			return 0.0
		if key == GameConfig.INSPECTION and dept.is_customs():
			continue
		result = minf(result, station_share(state, station, dept))
	return result


static func bottleneck(state: GameState, dept: Department) -> String:
	var weakest := "demand"
	var weakest_value := demand(state, dept)
	var transport := department_transport(state, dept)
	if transport < weakest_value:
		weakest = "transport"
		weakest_value = transport
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null or (key == GameConfig.INSPECTION and dept.is_customs()):
			continue
		var value := station_share(state, station, dept)
		if value < weakest_value:
			weakest = key
			weakest_value = value
	return weakest


static func expected_case_value(state: GameState, dept: Department) -> float:
	var config := dept.config()
	var money := float(config.reward) * reputation_multiplier(state)
	money *= 1.0 + float(config.complex_chance) * (GameConfig.COMPLEX_REWARD_FACTOR - 1.0)
	var error := error_chance(state, dept)
	return money * (1.0 - error + error * GameConfig.FLAWED_REWARD_FACTOR)


static func workload(state: GameState, dept: Department) -> float:
	var used := 0
	var capacity := 0
	for key in dept.station_keys():
		var station := state.station(key)
		if station == null:
			continue
		used += station.inbox.size() + station.outbox.size()
		capacity += station.inbox_capacity(state.lobby_capacity()) + station.outbox_capacity()
	return clampf(float(used) / capacity, 0.0, 1.0) if capacity > 0 else 0.0


static func resting_count(state: GameState, dept: Department) -> int:
	var count := 0
	for key in dept.station_keys():
		var station := state.station(key)
		if station != null:
			count += station.resting_count()
	return count


static func waiting_count(state: GameState, dept: Department) -> int:
	var count := 0
	var entry := state.station(GameConfig.RECEPTION if not dept.is_customs() else "customs/dock")
	if entry == null:
		return 0
	for case_file in entry.inbox:
		if case_file.dept_id == dept.id:
			count += 1
	return count
