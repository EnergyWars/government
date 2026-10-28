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
const PICKUP_SEATING := "pickup_seating"
const PICKUP_WAITING := "pickup_waiting"
const TICKETS := "tickets"

const HIRE := "hire"
const DESK := "desk"
const MACHINE := "machine"
const TRACK := "track"
const RUNNER := "runner"
const HR := "hr"

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
	var case_time := Formulas.station_case_time(state, station)
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
	var room_id := GameConfig.station_room(station.key)
	if can_upgrade(state, "room_speed", room_id):
		result.append(track("room_speed", capacity * track_gain(state, "room_speed", room_id), CAPACITY, room_id))
	room_id = GameConfig.lead_room(station.key)
	if not station.machine and can_upgrade(state, "team_lead", room_id):
		state.set_upgrade("team_lead", 1, room_id)
		state.set_upgrade("lead_focus", 1, room_id)
		var with_lead := Formulas.station_throughput(state, station)
		state.set_upgrade("lead_focus", 0, room_id)
		state.set_upgrade("team_lead", 0, room_id)
		result.append(track("team_lead", with_lead - capacity, CAPACITY, room_id))
	elif not station.machine and can_upgrade(state, "lead_focus", room_id):
		var level := state.upgrade_level("lead_focus", room_id)
		state.set_upgrade("lead_focus", level + 1, room_id)
		var focused := Formulas.station_throughput(state, station)
		state.set_upgrade("lead_focus", level, room_id)
		result.append(track("lead_focus", focused - capacity, CAPACITY, room_id))
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
	if state.case_runner_count() > 0 and can_upgrade(state, "runner_trolleys"):
		upgrades.append(track("runner_trolleys", current / Formulas.runner_capacity(state)))
	if state.case_runner_count() > 0 and can_upgrade(state, "runner_speed"):
		upgrades.append(track("runner_speed", current * track_gain(state, "runner_speed")))
	return area(TRANSPORT, "", demand, current, upgrades)


static func complaint_demand(state: GameState, blocked: float = -1.0) -> float:
	if state.cases_completed < GameConfig.COMPLAINT_MIN_CASES:
		return 0.0
	var chance := Formulas.security_chance(state) if blocked < 0.0 else blocked
	var incoming := 1.0 / GameConfig.COMPLAINT_INTERVAL + Formulas.leave_complaint_rate(state)
	return (1.0 - chance) * incoming + Formulas.complaint_letter_rate()


static func box_runners(interns: int) -> int:
	return maxi(0, interns - 1)


static func intern_rate(state: GameState, runners: int, per_run: int, speed_level: int = -1) -> float:
	if runners <= 0 or per_run <= 0:
		return 0.0
	var level := state.upgrade_level("intern_speed") if speed_level < 0 else speed_level
	var trip := WorldLayout.get_default().intern_trip_length() / (GameConfig.INTERN_SPEED * Formulas.track_value("intern_speed", level))
	return runners * per_run / trip


static func complaint_capacity(state: GameState) -> float:
	return intern_rate(state, box_runners(state.interns.size()), Formulas.intern_run_size(state))


static func complaint_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var runners := box_runners(state.interns.size())
	var per_run := Formulas.intern_run_size(state)
	var current := complaint_capacity(state)
	if per_run > 0 and can_upgrade(state, "complaint_interns"):
		upgrades.append(track("complaint_interns", intern_rate(state, runners + 1, per_run) - current))
	if can_upgrade(state, "intern_box_runs"):
		upgrades.append(track("intern_box_runs", intern_rate(state, runners, per_run + 1) - current))
	if current > 0.0 and can_upgrade(state, "intern_speed"):
		upgrades.append(track("intern_speed", intern_rate(state, runners, per_run, state.upgrade_level("intern_speed") + 1) - current))
	var demand := complaint_demand(state)
	if demand > 0.0 and can_upgrade(state, "complaint_security"):
		upgrades.append(track("complaint_security", demand - complaint_demand(state, GameConfig.SECURITY_BASE_CHANCE), RELIEF))
	elif demand > 0.0 and can_upgrade(state, "security_training"):
		var next := Formulas.track_value("security_training", state.upgrade_level("security_training") + 1)
		upgrades.append(track("security_training", demand - complaint_demand(state, next), RELIEF))
	return area(COMPLAINTS, "", demand, current, upgrades)


static func reject_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var current := Formulas.role_capacity(state, Runner.REJECT)
	var staffed := state.runners_in(Runner.REJECT)
	if state.runners.size() < GameConfig.MAX_RUNNERS:
		upgrades.append(upgrade(RUNNER, Formulas.role_capacity(state, Runner.REJECT, 1) - current, CAPACITY, staff_entry("runners")))
	if staffed > 0 and can_upgrade(state, "runner_trolleys"):
		upgrades.append(track("runner_trolleys", staffed / Formulas.reject_trip_time(state)))
	if staffed > 0 and can_upgrade(state, "runner_speed"):
		var faster := Formulas.role_loads(state, Runner.REJECT) / Formulas.reject_trip_time(state, 1.0 + track_gain(state, "runner_speed"))
		upgrades.append(track("runner_speed", faster - current))
	return area(REJECTS, "", Formulas.reject_demand(state), current, upgrades)


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


static func seating_area(state: GameState, room: String = GameConfig.HALL_INTAKE) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var track_id := str(GameConfig.SEATING_TRACKS[room])
	if can_upgrade(state, track_id):
		upgrades.append(track(track_id, float(GameConfig.upgrade(track_id).step), PLACES))
	var kind := PICKUP_SEATING if room == GameConfig.HALL_PICKUP else SEATING
	return area(kind, "", float(state.seated_citizens(room)), float(state.seat_capacity(room)), upgrades)


static func standing_area(state: GameState, room: String = GameConfig.HALL_INTAKE) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	var kind := PICKUP_WAITING if room == GameConfig.HALL_PICKUP else WAITING
	return area(kind, "", float(state.standing_citizens(room)), float(state.standing_capacity(room)), upgrades)


static func ticket_demand(state: GameState) -> float:
	return Formulas.station_demand(state, GameConfig.RECEPTION)


static func ticket_machine_area(state: GameState) -> Dictionary:
	var upgrades: Array[Dictionary] = []
	for machine in GameConfig.MAX_TICKET_MACHINES:
		var speed_id := GameConfig.TICKET_SPEED_TRACKS[machine]
		var machine_id := GameConfig.TICKET_MACHINE_TRACKS[machine]
		if not machine_id.is_empty() and can_upgrade(state, machine_id):
			upgrades.append(track(machine_id, Formulas.track_value(speed_id, 0)))
		if can_upgrade(state, speed_id):
			var level := state.upgrade_level(speed_id)
			upgrades.append(track(speed_id, Formulas.track_value(speed_id, level + 1) - Formulas.track_value(speed_id, level)))
	return area(TICKETS, "", ticket_demand(state), Formulas.ticket_draw_rate(state), upgrades)


static func support_areas(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	result.append(transport_area(state))
	result.append(complaint_area(state))
	result.append(reject_area(state))
	result.append(phone_area(state))
	for room in GameConfig.WAITING_ROOMS:
		result.append(seating_area(state, room))
		result.append(standing_area(state, room))
	result.append(ticket_machine_area(state))
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
