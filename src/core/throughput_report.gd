class_name ThroughputReport
extends RefCounted

const BUSY_LOAD := 0.85

const STATION := "station"
const TRANSPORT := "transport"
const COMPLAINTS := "complaints"
const REJECTS := "rejects"
const PHONES := "phones"
const SEATING := "seating"
const WAITING := "waiting"

const HIRE := "hire"
const DESK := "desk"
const MACHINE := "machine"
const LEVEL := "level"
const SPECIALIST := "specialist"
const SUPERVISOR := "supervisor"
const RESEARCH := "research"
const RUNNER := "runner"
const HELPER := "helper"
const COLLECTOR := "collector"
const HR := "hr"
const GUARD := "guard"
const CLERK := "clerk"
const SEATS := "seats"
const WAITING_SEATS := "waiting_seats"

const CAPACITY := "capacity"
const RELIEF := "relief"
const PLACES := "places"


static func load_of(demand: float, capacity: float) -> float:
	if capacity <= 0.0:
		return 1.0 if demand > 0.0 else 0.0
	if is_inf(capacity):
		return 0.0
	return demand / capacity


static func area(kind: String, key: String, demand: float, capacity: float, upgrades: Array[Dictionary]) -> Dictionary:
	upgrades.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.gain) > float(b.gain))
	return {"area": kind, "key": key, "demand": demand, "capacity": capacity, "load": load_of(demand, capacity), "upgrades": upgrades}


static func upgrade(id: String, gain: float, effect: String = CAPACITY, research_id: String = "") -> Dictionary:
	return {"id": id, "gain": gain, "effect": effect, "research": research_id}


static func can_research(state: GameState, research_id: String) -> bool:
	var config: Dictionary = GameConfig.RESEARCH[research_id]
	if config.has("requires") and not state.has_research(str(config.requires)):
		return false
	return state.research_level(research_id) < int(config.max_level)


static func station_area(state: GameState, station: Station) -> Dictionary:
	var demand := Formulas.station_demand(state, station.key)
	return area(STATION, station.key, demand, Formulas.station_throughput(state, station), station_upgrades(state, station))


static func station_upgrades(state: GameState, station: Station) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var case_time := Formulas.station_case_time(state, station, station.specialists > 0)
	if case_time <= 0.0:
		return result
	var capacity := Formulas.station_throughput(state, station)
	var availability := Formulas.availability(state, station)
	var per_official := availability / case_time
	if station.machine:
		if station.desks < state.max_desks():
			result.append(upgrade(MACHINE, per_official))
	elif station.staff < station.desks:
		result.append(upgrade(HIRE, per_official))
	elif station.desks < state.max_desks():
		result.append(upgrade(DESK, per_official))
	if station.level < GameConfig.MAX_STATION_LEVEL:
		result.append(upgrade(LEVEL, capacity * (Formulas.level_speed(station.level + 1) / Formulas.level_speed(station.level) - 1.0)))
	if station.supports_specialists() and station.specialists < GameConfig.MAX_SPECIALISTS:
		var with_specialist := Formulas.station_case_time(state, station, true)
		result.append(upgrade(SPECIALIST, (Formulas.effective_workers(station) + 1.0) * availability / with_specialist - capacity))
	var dept := state.department(station.dept_id)
	if dept != null and dept.supervisors < GameConfig.MAX_SUPERVISORS:
		dept.supervisors += 1
		var with_supervisor := Formulas.station_throughput(state, station)
		dept.supervisors -= 1
		result.append(upgrade(SUPERVISOR, with_supervisor - capacity))
	if GameConfig.RESEARCH_SPEED.has(station.kind):
		var entry: Dictionary = GameConfig.RESEARCH_SPEED[station.kind]
		var research_id := str(entry.research)
		if can_research(state, research_id):
			var research_speed := Formulas.research_speed_multiplier(state, station.kind)
			result.append(upgrade(RESEARCH, capacity * float(entry.bonus) / research_speed, CAPACITY, research_id))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.gain) > float(b.gain))
	return result


static func transport_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var demand := Formulas.total_transfer_demand(state)
	if state.any_piped() and can_research(state, "tube_capacity"):
		upgrades.append(upgrade(RESEARCH, float(GameConfig.TUBE_CAPACITY_PER_LEVEL), PLACES, "tube_capacity"))
	if state.all_piped():
		return area(TRANSPORT, "", demand, INF, upgrades)
	if state.runners.size() < GameConfig.MAX_RUNNERS:
		var current := Formulas.transport_throughput(state)
		upgrades.append(upgrade(RUNNER, Formulas.transport_throughput(state, Formulas.weakest_runner_role(state)) - current))
	if not state.runners.is_empty() and can_research(state, "trolleys"):
		var capacity := Formulas.transport_throughput(state)
		upgrades.append(upgrade(RESEARCH, capacity * GameConfig.RUNNER_CAPACITY_PER_LEVEL / Formulas.runner_capacity(state), CAPACITY, "trolleys"))
	return area(TRANSPORT, "", demand, Formulas.transport_throughput(state), upgrades)


static func complaint_demand(state: GameState, guards: int, clerk_level: int = -1) -> float:
	if state.cases_completed < GameConfig.COMPLAINT_MIN_CASES:
		return 0.0
	var level := state.complaint_clerk_level if clerk_level < 0 else clerk_level
	var interval := GameConfig.COMPLAINT_INTERVAL * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF * (guards + state.helpers.size()))
	return pow(1.0 - GameConfig.GUARD_BLOCK_CHANCE, guards) * (1.0 - Formulas.complaint_fend_chance(level)) / interval


static func intern_rate(level: int, per_trip: int) -> float:
	var delay: float = GameConfig.SHREDDER_DELAYS[level]
	if delay <= 0.0:
		return 0.0
	return per_trip / (delay + GameConfig.INTERN_TRIP_ESTIMATE)


static func tube_rate(level: int) -> float:
	var delay: float = GameConfig.COMPLAINT_TUBE_DELAYS[level]
	return 1.0 / delay if delay > 0.0 else 0.0


static func complaint_capacity(state: GameState) -> float:
	var units := state.all_interns().size()
	var interns := units * intern_rate(state.research_level("shredder_service"), Formulas.intern_capacity(state))
	return interns + tube_rate(state.research_level("complaint_tube"))


static func complaint_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var level := state.research_level("shredder_service")
	var units := state.all_interns().size()
	var per_trip := Formulas.intern_capacity(state)
	if can_research(state, "shredder_service"):
		upgrades.append(upgrade(RESEARCH, units * (intern_rate(level + 1, per_trip) - intern_rate(level, per_trip)), CAPACITY, "shredder_service"))
	if level > 0 and state.helpers.size() < GameConfig.MAX_HELPERS:
		upgrades.append(upgrade(HELPER, intern_rate(level, per_trip)))
	if level > 0 and can_research(state, "intern_training"):
		upgrades.append(upgrade(RESEARCH, units * intern_rate(level, 1), CAPACITY, "intern_training"))
	if can_research(state, "complaint_tube"):
		var tube := state.research_level("complaint_tube")
		upgrades.append(upgrade(RESEARCH, tube_rate(tube + 1) - tube_rate(tube), CAPACITY, "complaint_tube"))
	var demand := complaint_demand(state, state.guards)
	if state.guards < GameConfig.MAX_GUARDS and demand > 0.0:
		upgrades.append(upgrade(GUARD, demand - complaint_demand(state, state.guards + 1), RELIEF))
	if state.complaint_clerk_level < GameConfig.COMPLAINT_CLERK_MAX_LEVEL and demand > 0.0:
		upgrades.append(upgrade(CLERK, demand - complaint_demand(state, state.guards, state.complaint_clerk_level + 1), RELIEF))
	return area(COMPLAINTS, "", demand, complaint_capacity(state), upgrades)


static func reject_demand(state: GameState) -> float:
	if state.cases_completed < GameConfig.REJECT_MIN_CASES:
		return 0.0
	var total := 0.0
	for dept in state.unlocked_departments():
		if not dept.is_customs():
			total += Formulas.demand(state, dept) * GameConfig.REJECT_CHANCE
	return total


static func collector_trip(state: GameState) -> float:
	var layout := WorldLayout.get_default()
	var shredder := layout.shredder_point()
	var weighted := 0.0
	var total := 0.0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if not station.has_reject_pile():
			continue
		var demand := Formulas.demand(state, state.department(station.dept_id))
		weighted += demand * 2.0 * shredder.distance_to(layout.reject_point(key)) / GameConfig.COLLECTOR_SPEED
		total += demand
	if total <= 0.0:
		return GameConfig.COLLECTOR_TRIP_ESTIMATE
	return maxf(GameConfig.COLLECTOR_TRIP_ESTIMATE, weighted / total)


static func collector_rate(state: GameState) -> float:
	return Formulas.collector_capacity(state) / collector_trip(state)


static func reject_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var rate := collector_rate(state)
	if state.collectors.size() < GameConfig.MAX_COLLECTORS:
		upgrades.append(upgrade(COLLECTOR, rate))
	if not state.collectors.is_empty() and can_research(state, "trolleys"):
		upgrades.append(upgrade(RESEARCH, state.collectors.size() * GameConfig.COLLECTOR_CAPACITY_PER_LEVEL / collector_trip(state), CAPACITY, "trolleys"))
	return area(REJECTS, "", reject_demand(state), state.collectors.size() * rate, upgrades)


static func sick_demand(state: GameState, hr: int) -> float:
	var officials := staffed_officials(state)
	if officials < GameConfig.SICK_MIN_STAFF:
		return 0.0
	var interval := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, 0.5) / officials * (1.0 + GameConfig.SICK_HR_RELIEF * hr)
	return 1.0 / interval


static func staffed_officials(state: GameState) -> int:
	return state.staffed_officials()


static func phone_capacity(state: GameState) -> float:
	return state.hr / GameConfig.HR_ANSWER_SECONDS


static func phone_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var demand := sick_demand(state, state.hr)
	if state.hr < GameConfig.MAX_HR and demand > 0.0:
		upgrades.append(upgrade(HR, demand - sick_demand(state, state.hr + 1), RELIEF))
	return area(PHONES, "", demand, phone_capacity(state), upgrades)


static func seating_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	if state.seating_level < GameConfig.SEATING_MAX_LEVEL:
		upgrades.append(upgrade(SEATS, float(GameConfig.SEATING_SEATS_PER_LEVEL), PLACES))
	return area(SEATING, "", float(state.seated_citizens()), float(state.seat_capacity()), upgrades)


static func waiting_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	if state.waiting_level < GameConfig.WAITING_MAX_LEVEL:
		upgrades.append(upgrade(WAITING_SEATS, float(GameConfig.WAITING_SEATS_PER_LEVEL), PLACES))
	var reception := state.station(GameConfig.RECEPTION)
	var waiting := reception.inbox.size() if reception != null else 0
	return area(WAITING, "", float(waiting), float(state.lobby_capacity()), upgrades)


static func support_areas(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(transport_area(state))
	result.append(complaint_area(state))
	result.append(reject_area(state))
	result.append(phone_area(state))
	result.append(seating_area(state))
	result.append(waiting_area(state))
	return result


static func all_areas(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in state.ordered_station_keys():
		result.append(station_area(state, state.station(key)))
	result.append_array(support_areas(state))
	return result


static func recommendations(state: GameState, limit: int) -> Array[Dictionary]:
	return pick_recommendations(all_areas(state), limit)


static func pick_recommendations(areas: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var busy: Array[Dictionary] = []
	for entry in areas:
		if float(entry.load) >= BUSY_LOAD and not (entry.upgrades as Array).is_empty():
			busy.append(entry)
	busy.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.load) > float(b.load))
	return busy.slice(0, maxi(0, limit))


static func department_steps(state: GameState, dept: Department) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null or (key == GameConfig.INSPECTION and dept.is_customs()):
			continue
		result.append({"key": key, "rate": Formulas.station_share(state, station, dept)})
	result.append({"key": TRANSPORT, "rate": Formulas.department_transport(state, dept)})
	return result
