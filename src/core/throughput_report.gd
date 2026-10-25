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
const TICKETS := "tickets"
const CALLS := "calls"

const HIRE := "hire"
const DESK := "desk"
const MACHINE := "machine"
const LEVEL := "level"
const SPECIALIST := "specialist"
const SUPERVISOR := "supervisor"
const TRACK := "track"
const RUNNER := "runner"
const HELPER := "helper"
const COLLECTOR := "collector"
const HR := "hr"
const GUARD := "guard"

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


static func upgrade(id: String, gain: float, effect: String = CAPACITY, entry: String = "") -> Dictionary:
	return {"id": id, "gain": gain, "effect": effect, "entry": entry}


static func track(upgrade_id: String, gain: float, effect: String = CAPACITY, room_id: String = "") -> Dictionary:
	return upgrade(TRACK, gain, effect, "%s:%s" % [UpgradeCatalog.TRACK, GameConfig.upgrade_key(upgrade_id, room_id)])


static func can_upgrade(state: GameState, upgrade_id: String, room_id: String = "") -> bool:
	return ["", "money", "reputation"].has(Progression.upgrade_block_reason(state, upgrade_id, room_id))


static func track_gain(state: GameState, upgrade_id: String, room_id: String = "") -> float:
	var level := state.upgrade_level(upgrade_id, room_id)
	var current := Formulas.track_value(upgrade_id, level)
	if current <= 0.0:
		return 0.0
	return Formulas.track_value(upgrade_id, level + 1) / current - 1.0


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
			result.append(upgrade(MACHINE, per_official, CAPACITY, "%s:%s" % [UpgradeCatalog.DESK, station.key]))
	elif station.staff < station.desks:
		result.append(upgrade(HIRE, per_official, CAPACITY, "%s:%s" % [UpgradeCatalog.HIRE, station.key]))
	elif station.desks < state.max_desks():
		result.append(upgrade(DESK, per_official, CAPACITY, "%s:%s" % [UpgradeCatalog.DESK, station.key]))
	if station.level < GameConfig.MAX_STATION_LEVEL:
		result.append(upgrade(LEVEL, capacity * (Formulas.level_speed(station.level + 1) / Formulas.level_speed(station.level) - 1.0), CAPACITY, "%s:%s" % [UpgradeCatalog.LEVEL, station.key]))
	if station.supports_specialists() and station.specialists < GameConfig.MAX_SPECIALISTS:
		var with_specialist := Formulas.station_case_time(state, station, true)
		result.append(upgrade(SPECIALIST, (Formulas.effective_workers(station) + 1.0) * availability / with_specialist - capacity, CAPACITY, "%s:%s" % [UpgradeCatalog.SPECIALIST, station.key]))
	var dept := state.department(station.dept_id)
	if dept != null and dept.supervisors < GameConfig.MAX_SUPERVISORS:
		dept.supervisors += 1
		var with_supervisor := Formulas.station_throughput(state, station)
		dept.supervisors -= 1
		result.append(upgrade(SUPERVISOR, with_supervisor - capacity, CAPACITY, "%s:%s" % [UpgradeCatalog.SUPERVISOR, dept.id]))
	if dept != null and can_upgrade(state, "office_equipment", dept.id):
		result.append(track("office_equipment", capacity * track_gain(state, "office_equipment", dept.id), CAPACITY, dept.id))
	if GameConfig.UPGRADE_SPEED.has(station.kind):
		var upgrade_id := str(GameConfig.UPGRADE_SPEED[station.kind])
		if can_upgrade(state, upgrade_id):
			result.append(track(upgrade_id, capacity * track_gain(state, upgrade_id)))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.gain) > float(b.gain))
	return result


static func staff_entry(staff_type: String) -> String:
	return "%s:%s" % [UpgradeCatalog.STAFF, staff_type]


static func transport_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var demand := Formulas.total_transfer_demand(state)
	if state.any_piped() and can_upgrade(state, "tube_capacity"):
		upgrades.append(track("tube_capacity", float(GameConfig.upgrade("tube_capacity").step), PLACES))
	if state.all_piped():
		return area(TRANSPORT, "", demand, INF, upgrades)
	var current := Formulas.transport_throughput(state)
	if state.runners.size() < GameConfig.MAX_RUNNERS:
		upgrades.append(upgrade(RUNNER, Formulas.transport_throughput(state, Formulas.weakest_runner_role(state)) - current, CAPACITY, staff_entry("runners")))
	if not state.runners.is_empty() and can_upgrade(state, "runner_trolleys"):
		upgrades.append(track("runner_trolleys", current / Formulas.runner_capacity(state)))
	if not state.runners.is_empty() and can_upgrade(state, "runner_speed"):
		upgrades.append(track("runner_speed", current * track_gain(state, "runner_speed")))
	return area(TRANSPORT, "", demand, current, upgrades)


static func complaint_demand(state: GameState, guards: int, clerk_level: int = -1) -> float:
	if state.cases_completed < GameConfig.COMPLAINT_MIN_CASES:
		return 0.0
	var level := state.upgrade_level("complaint_clerk") if clerk_level < 0 else clerk_level
	var interval := GameConfig.COMPLAINT_INTERVAL * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF * (guards + state.helpers.size()))
	var incoming := 1.0 / interval + Formulas.leave_complaint_rate(state)
	return pow(1.0 - Formulas.guard_chance(state), guards) * (1.0 - Formulas.complaint_fend_chance(level)) * incoming


static func intern_rate(level: int, per_trip: int) -> float:
	var delay := Formulas.track_value("shredder_service", level)
	if delay <= 0.0:
		return 0.0
	return per_trip / (delay + GameConfig.INTERN_TRIP_ESTIMATE)


static func tube_rate(level: int) -> float:
	var delay := Formulas.track_value("complaint_tube", level)
	return 1.0 / delay if delay > 0.0 else 0.0


static func complaint_capacity(state: GameState) -> float:
	var units := state.all_interns().size()
	var interns := units * intern_rate(state.upgrade_level("shredder_service"), Formulas.intern_capacity(state))
	return interns + tube_rate(state.upgrade_level("complaint_tube"))


static func complaint_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var level := state.upgrade_level("shredder_service")
	var units := state.all_interns().size()
	var per_trip := Formulas.intern_capacity(state)
	if can_upgrade(state, "shredder_service"):
		upgrades.append(track("shredder_service", units * (intern_rate(level + 1, per_trip) - intern_rate(level, per_trip))))
	if level > 0 and state.helpers.size() < GameConfig.MAX_HELPERS:
		upgrades.append(upgrade(HELPER, intern_rate(level, per_trip), CAPACITY, staff_entry("helpers")))
	if level > 0 and can_upgrade(state, "intern_training"):
		upgrades.append(track("intern_training", units * intern_rate(level, 1)))
	if can_upgrade(state, "complaint_tube"):
		var tube := state.upgrade_level("complaint_tube")
		upgrades.append(track("complaint_tube", tube_rate(tube + 1) - tube_rate(tube)))
	var demand := complaint_demand(state, state.guards)
	if state.guards < GameConfig.MAX_GUARDS and demand > 0.0:
		upgrades.append(upgrade(GUARD, demand - complaint_demand(state, state.guards + 1), RELIEF, staff_entry("guards")))
	var clerk := state.upgrade_level("complaint_clerk")
	if can_upgrade(state, "complaint_clerk") and demand > 0.0:
		upgrades.append(track("complaint_clerk", demand - complaint_demand(state, state.guards, clerk + 1), RELIEF))
	return area(COMPLAINTS, "", demand, complaint_capacity(state), upgrades)


static func reject_demand(state: GameState) -> float:
	if state.cases_completed < GameConfig.REJECT_MIN_CASES:
		return 0.0
	var total := 0.0
	for dept in state.unlocked_departments():
		if not dept.is_customs():
			total += Formulas.demand(state, dept) * GameConfig.REJECT_CHANCE
	return total


static func collector_trip(state: GameState, speed_factor: float = 1.0) -> float:
	var layout := WorldLayout.get_default()
	var speed := Formulas.collector_speed(state) * speed_factor
	var weighted := 0.0
	var total := 0.0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if not station.has_reject_pile():
			continue
		var point := layout.reject_point(key)
		var distance := point.distance_to(layout.shredder_point())
		if state.has_upgrade("shredder", station.dept_id):
			distance = minf(distance, point.distance_to(layout.dept_shredder_point(station.dept_id)))
		var demand := Formulas.demand(state, state.department(station.dept_id))
		weighted += demand * 2.0 * distance / speed
		total += demand
	if total <= 0.0:
		return GameConfig.COLLECTOR_TRIP_ESTIMATE
	return maxf(GameConfig.COLLECTOR_TRIP_ESTIMATE, weighted / total)


static func collector_rate(state: GameState) -> float:
	return Formulas.collector_capacity(state) / collector_trip(state)


static func shredder_capacity(state: GameState) -> float:
	var total := 0.0
	for dept_id in state.shredder_rooms():
		total += GameConfig.SHREDDER_BATCH / Formulas.shredder_interval(state, dept_id)
	return total


static func missing_shredder(state: GameState) -> String:
	for dept in state.unlocked_departments():
		if not dept.is_customs() and can_upgrade(state, "shredder", dept.id) and not state.has_upgrade("shredder", dept.id):
			return dept.id
	return ""


static func reject_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var rate := collector_rate(state)
	if state.collectors.size() < GameConfig.MAX_COLLECTORS:
		upgrades.append(upgrade(COLLECTOR, rate, CAPACITY, staff_entry("collectors")))
	if not state.collectors.is_empty() and can_upgrade(state, "collector_carts"):
		upgrades.append(track("collector_carts", state.collectors.size() / collector_trip(state)))
	if not state.collectors.is_empty() and can_upgrade(state, "collector_speed"):
		var faster := Formulas.collector_capacity(state) / collector_trip(state, 1.0 + track_gain(state, "collector_speed"))
		upgrades.append(track("collector_speed", state.collectors.size() * (faster - rate)))
	var dept_id := missing_shredder(state)
	if not dept_id.is_empty():
		upgrades.append(track("shredder", GameConfig.SHREDDER_BATCH / Formulas.track_value("shredder", 1), CAPACITY, dept_id))
	return area(REJECTS, "", reject_demand(state), state.collectors.size() * rate + shredder_capacity(state), upgrades)


static func sick_demand(state: GameState, hr: int) -> float:
	var officials := staffed_officials(state)
	if officials < GameConfig.SICK_MIN_STAFF:
		return 0.0
	var interval := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, 0.5) / officials * (1.0 + GameConfig.SICK_HR_RELIEF * hr)
	return 1.0 / interval


static func staffed_officials(state: GameState) -> int:
	return state.staffed_officials()


static func phone_capacity(state: GameState) -> float:
	return state.hr * Formulas.phone_speed(state) / GameConfig.HR_ANSWER_SECONDS


static func phone_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var demand := sick_demand(state, state.hr)
	if state.hr < GameConfig.MAX_HR and demand > 0.0:
		upgrades.append(upgrade(HR, demand - sick_demand(state, state.hr + 1), RELIEF, staff_entry("hr")))
	if state.hr > 0 and can_upgrade(state, "phone_training"):
		var level := state.upgrade_level("phone_training")
		upgrades.append(track("phone_training", phone_capacity(state) * (Formulas.track_value("phone_training", level) / Formulas.track_value("phone_training", level + 1) - 1.0)))
	return area(PHONES, "", demand, phone_capacity(state), upgrades)


static func seating_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	if can_upgrade(state, "seating"):
		upgrades.append(track("seating", float(GameConfig.upgrade("seating").step), PLACES))
	if can_upgrade(state, "standing_places"):
		upgrades.append(track("standing_places", float(GameConfig.upgrade("standing_places").step), PLACES))
	return area(SEATING, "", float(state.seated_citizens()), float(state.seat_capacity() + state.standing_capacity()), upgrades)


static func waiting_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	if can_upgrade(state, "waiting_places"):
		upgrades.append(track("waiting_places", float(GameConfig.upgrade("waiting_places").step), PLACES))
	return area(WAITING, "", float(state.lobby_used()), float(state.lobby_capacity()), upgrades)


static func ticket_demand(state: GameState) -> float:
	return Formulas.station_demand(state, GameConfig.RECEPTION)


static func ticket_machine_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var rate := Formulas.ticket_draw_rate(state)
	var machines := Formulas.ticket_machines(state)
	if can_upgrade(state, "ticket_speed"):
		upgrades.append(track("ticket_speed", machines / Formulas.track_value("ticket_speed", state.upgrade_level("ticket_speed") + 1) - rate))
	if can_upgrade(state, "ticket_machines"):
		upgrades.append(track("ticket_machines", rate / machines))
	return area(TICKETS, "", ticket_demand(state), rate, upgrades)


static func ticket_call_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var rate := Formulas.ticket_call_rate(state)
	var displays := Formulas.ticket_displays(state)
	if can_upgrade(state, "ticket_call_speed"):
		upgrades.append(track("ticket_call_speed", displays / Formulas.track_value("ticket_call_speed", state.upgrade_level("ticket_call_speed") + 1) - rate))
	if can_upgrade(state, "ticket_displays"):
		upgrades.append(track("ticket_displays", rate / displays))
	return area(CALLS, "", ticket_demand(state), rate, upgrades)


static func support_areas(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(transport_area(state))
	result.append(complaint_area(state))
	result.append(reject_area(state))
	result.append(phone_area(state))
	result.append(seating_area(state))
	result.append(waiting_area(state))
	if state.tickets_unlocked():
		result.append(ticket_machine_area(state))
		result.append(ticket_call_area(state))
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


static func recommended_entries(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for entry in recommendations(state, 1 << 16):
		for suggestion: Dictionary in entry.upgrades:
			var entry_id := str(suggestion.get("entry", ""))
			if not entry_id.is_empty() and not result.has(entry_id):
				result.append(entry_id)
	return result


static func department_steps(state: GameState, dept: Department) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null or (key == GameConfig.INSPECTION and dept.is_customs()):
			continue
		result.append({"key": key, "rate": Formulas.station_share(state, station, dept)})
	result.append({"key": TRANSPORT, "rate": Formulas.department_transport(state, dept)})
	return result
