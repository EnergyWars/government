class_name GameState
extends RefCounted

const SAVE_VERSION := 2

var money := GameConfig.START_MONEY
var reputation := 0.0
var building_stage := 0
var goal_index := 0
var tutorial_step := 0
var departments: Dictionary[String, Department] = {}
var stations: Dictionary[String, Station] = {}
var research: Dictionary[String, int] = {}
var player := Player.new()
var runners: Array[Runner] = []
var event_id := ""
var event_time_left := 0.0
var event_cooldown := GameConfig.EVENT_FIRST_COOLDOWN
var event_scope := ""
var event_choice := ""
var cases_spawned := 0
var cases_rejected := 0
var cases_completed := 0
var cases_flawed := 0
var citizens_lost := 0
var contraband_seized := 0
var staff_hired := 0
var wakes := 0
var complaints := 0
var complaints_shredded := 0
var complaint_timer := GameConfig.COMPLAINT_INTERVAL
var shred_timer := 0.0
var kranz := false
var hr := 0
var sick_timer := GameConfig.SICK_FIRST_SECONDS
var hr_timer := 0.0
var calls_made := 0
var kranz_timer := GameConfig.KRANZ_FIRST_SECONDS
var kranz_progress := 0.0
var money_earned := 0.0
var play_time := 0.0
var saved_at := 0
var rng := RandomNumberGenerator.new()
var _ordered_keys: Array[String] = []
var _ordered_signature := -1


func _init() -> void:
	for dept_id in GameConfig.department_ids():
		departments[dept_id] = Department.new(dept_id)
	for research_id in GameConfig.RESEARCH_ORDER:
		research[research_id] = 0
	player.position = WorldLayout.get_default().player_start()


static func create_new(seed_value: int = -1) -> GameState:
	var state := GameState.new()
	if seed_value >= 0:
		state.rng.seed = seed_value
	else:
		state.rng.randomize()
	state.unlock_department("general_services")
	state.station("general_services/review").staff = 1
	return state


func department(dept_id: String) -> Department:
	return departments.get(dept_id)


func station(key: String) -> Station:
	return stations.get(key)


func unlocked_departments() -> Array[Department]:
	var result: Array[Department] = []
	for dept_id in GameConfig.department_ids():
		if departments[dept_id].unlocked:
			result.append(departments[dept_id])
	return result


func unlocked_count() -> int:
	return unlocked_departments().size()


func stage_config() -> Dictionary:
	return GameConfig.building_stage(building_stage)


func lobby_capacity() -> int:
	return int(stage_config().lobby)


func max_desks() -> int:
	return int(stage_config().max_desks)


func research_level(research_id: String) -> int:
	return research.get(research_id, 0)


func has_research(research_id: String) -> bool:
	return research_level(research_id) > 0


func unlock_department(dept_id: String) -> void:
	var dept := department(dept_id)
	if dept == null or dept.unlocked:
		return
	dept.unlocked = true
	var first := dept_id == "general_services"
	for key in RouteBuilder.required_stations(dept_id):
		if stations.has(key):
			continue
		var created := Station.new(key)
		if not created.machine:
			created.staff = 0 if first else 1
		stations[key] = created


func departments_using(key: String) -> Array[Department]:
	var result: Array[Department] = []
	for dept in unlocked_departments():
		if RouteBuilder.required_stations(dept.id).has(key):
			result.append(dept)
	return result


func ordered_station_keys() -> Array[String]:
	var signature := stations.size()
	for dept_id in GameConfig.department_ids():
		signature = signature * 2 + (1 if departments[dept_id].unlocked else 0)
	if signature != _ordered_signature:
		_ordered_signature = signature
		_ordered_keys = _compute_ordered_keys()
	return _ordered_keys


func kitchen_slot_taken(slot: int) -> bool:
	for key in stations:
		for mood in stations[key].moods:
			if mood.is_away() and mood.slot == slot:
				return true
	return false


func free_kitchen_slot(start: int = 0) -> int:
	for offset in GameConfig.KITCHEN_SLOTS:
		var slot := (start + offset) % GameConfig.KITCHEN_SLOTS
		if not kitchen_slot_taken(slot):
			return slot
	return -1


func sick_count() -> int:
	var count := 0
	for key in ordered_station_keys():
		var station := stations[key]
		for desk in station.moods.size():
			if station.is_staffed(desk) and station.moods[desk].is_sick():
				count += 1
	return count


func free_loo_slot() -> int:
	for slot in range(GameConfig.KITCHEN_SLOTS, GameConfig.KITCHEN_SLOTS + GameConfig.LOO_SLOTS):
		if not kitchen_slot_taken(slot):
			return slot
	return -1


func _slot_valid(mood: DeskMood) -> bool:
	if mood.state == DeskMood.LOO:
		return mood.slot >= GameConfig.KITCHEN_SLOTS
	return mood.slot >= 0 and mood.slot < GameConfig.KITCHEN_SLOTS


func _repair_kitchen_slots() -> void:
	var used := {}
	var broken: Array[DeskMood] = []
	for key in stations:
		for mood in stations[key].moods:
			if not mood.is_away():
				continue
			if _slot_valid(mood) and not used.has(mood.slot):
				used[mood.slot] = true
			else:
				broken.append(mood)
	for mood in broken:
		var free := -1
		var first := GameConfig.KITCHEN_SLOTS if mood.state == DeskMood.LOO else 0
		var last := GameConfig.KITCHEN_SLOTS + GameConfig.LOO_SLOTS if mood.state == DeskMood.LOO else GameConfig.KITCHEN_SLOTS
		for slot in range(first, last):
			if not used.has(slot):
				free = slot
				break
		if free < 0:
			mood.rest(DeskMood.ASLEEP)
		else:
			mood.slot = free
			used[free] = true


func _compute_ordered_keys() -> Array[String]:
	var keys: Array[String] = []
	for dept in unlocked_departments():
		for key in RouteBuilder.required_stations(dept.id):
			if not keys.has(key) and stations.has(key):
				keys.append(key)
	return keys


func total_staff() -> int:
	var count := runners.size()
	for key in stations:
		var item := stations[key]
		count += item.specialists + (0 if item.machine else item.staff)
	for dept in unlocked_departments():
		count += dept.supervisors
	return count


func max_station_level() -> int:
	var best := 0
	for key in stations:
		best = maxi(best, stations[key].level)
	return best


func research_count() -> int:
	var count := 0
	for research_id in research:
		count += research[research_id]
	return count


func add_reputation(amount: float) -> void:
	reputation = maxf(0.0, reputation + amount)


func earn(amount: float) -> void:
	money += amount
	money_earned += maxf(amount, 0.0)


func grant(amount: float) -> void:
	money += amount


func rejects_waiting() -> int:
	var total := 0
	for key in stations:
		total += stations[key].rejects
	return total


func can_afford(cost: float) -> bool:
	return money + 0.0001 >= cost


func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	money = maxf(0.0, money - cost)
	return true


func add_runner() -> Runner:
	var runner := Runner.new(WorldLayout.get_default().runner_home() + Vector2(runners.size() * 18.0, 0))
	runners.append(runner)
	return runner


func carried_cases() -> Array[CaseFile]:
	var cases: Array[CaseFile] = []
	cases.append_array(player.items)
	for runner in runners:
		cases.append_array(runner.items)
	return cases


func to_dict() -> Dictionary:
	var dept_data := {}
	for dept_id in departments:
		dept_data[dept_id] = departments[dept_id].to_dict()
	var station_data := {}
	for key in stations:
		station_data[key] = stations[key].to_dict()
	return {
		"version": SAVE_VERSION,
		"money": money,
		"reputation": reputation,
		"building_stage": building_stage,
		"goal_index": goal_index,
		"tutorial_step": tutorial_step,
		"departments": dept_data,
		"stations": station_data,
		"research": research.duplicate(),
		"player": player.to_dict(),
		"runners": runners.map(func(r: Runner) -> Dictionary: return r.to_dict()),
		"event_id": event_id,
		"event_time_left": event_time_left,
		"event_cooldown": event_cooldown,
		"event_scope": event_scope,
		"event_choice": event_choice,
		"cases_spawned": cases_spawned,
		"cases_rejected": cases_rejected,
		"cases_completed": cases_completed,
		"cases_flawed": cases_flawed,
		"citizens_lost": citizens_lost,
		"contraband_seized": contraband_seized,
		"staff_hired": staff_hired,
		"wakes": wakes,
		"complaints": complaints,
		"complaints_shredded": complaints_shredded,
		"complaint_timer": complaint_timer,
		"kranz": kranz,
		"hr": hr,
		"sick_timer": sick_timer,
		"calls_made": calls_made,
		"kranz_timer": kranz_timer,
		"money_earned": money_earned,
		"play_time": play_time,
		"saved_at": saved_at,
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
	}


static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	if int(data.get("version", 0)) != SAVE_VERSION:
		state.rng.randomize()
		state.unlock_department("general_services")
		state.station("general_services/review").staff = 1
		return state
	state.money = maxf(0.0, float(data.get("money", GameConfig.START_MONEY)))
	state.reputation = maxf(0.0, float(data.get("reputation", 0.0)))
	state.building_stage = clampi(int(data.get("building_stage", 0)), 0, GameConfig.BUILDING_STAGES.size() - 1)
	state.goal_index = clampi(int(data.get("goal_index", 0)), 0, GameConfig.GOALS.size())
	state.tutorial_step = Tutorial.clamp_saved(int(data.get("tutorial_step", Tutorial.FINISHED)))
	var dept_data: Dictionary = data.get("departments", {})
	for dept_id in dept_data:
		if state.departments.has(dept_id):
			state.departments[dept_id] = Department.from_dict(dept_data[dept_id])
	var station_data: Dictionary = data.get("stations", {})
	for key in station_data:
		var restored := Station.from_dict(station_data[key])
		if GameConfig.station_kind(restored.kind).is_empty() or restored.key != str(key):
			continue
		state.stations[restored.key] = restored
	var research_data: Dictionary = data.get("research", {})
	for research_id in research_data:
		if state.research.has(research_id):
			state.research[research_id] = clampi(int(research_data[research_id]), 0, GameConfig.RESEARCH[research_id].max_level)
	var layout := WorldLayout.get_default()
	state.player = Player.from_dict(data.get("player", {}), layout.player_start())
	state.player.position = layout.clamp_to_world(state.player.position)
	for entry in data.get("runners", []):
		if entry is Dictionary and state.runners.size() < GameConfig.MAX_RUNNERS:
			state.runners.append(Runner.from_dict(entry, layout.runner_home()))
	state.event_id = str(data.get("event_id", ""))
	if not GameConfig.EVENTS.has(state.event_id):
		state.event_id = ""
	state.event_time_left = float(data.get("event_time_left", 0.0))
	state.event_cooldown = float(data.get("event_cooldown", GameConfig.EVENT_FIRST_COOLDOWN))
	state.event_scope = str(data.get("event_scope", "")) if state.event_id != "" else ""
	state.event_choice = str(data.get("event_choice", "")) if state.event_id != "" else ""
	state.cases_spawned = maxi(0, int(data.get("cases_spawned", 0)))
	state.cases_rejected = maxi(0, int(data.get("cases_rejected", 0)))
	state.cases_completed = int(data.get("cases_completed", 0))
	state.cases_flawed = int(data.get("cases_flawed", 0))
	state.citizens_lost = int(data.get("citizens_lost", 0))
	state.contraband_seized = int(data.get("contraband_seized", 0))
	state.staff_hired = int(data.get("staff_hired", 0))
	state.wakes = maxi(0, int(data.get("wakes", 0)))
	state.complaints = clampi(int(data.get("complaints", 0)), 0, GameConfig.COMPLAINT_CAP)
	state.hr = clampi(int(data.get("hr", 0)), 0, GameConfig.MAX_HR)
	state.sick_timer = clampf(float(data.get("sick_timer", GameConfig.SICK_FIRST_SECONDS)), 0.0, GameConfig.SICK_MAX_INTERVAL)
	state.calls_made = maxi(0, int(data.get("calls_made", 0)))
	state.kranz = bool(data.get("kranz", false))
	state.kranz_timer = clampf(float(data.get("kranz_timer", GameConfig.KRANZ_FIRST_SECONDS)), 0.0, GameConfig.KRANZ_MAX_INTERVAL)
	state.complaints_shredded = maxi(0, int(data.get("complaints_shredded", 0)))
	state.complaint_timer = clampf(float(data.get("complaint_timer", GameConfig.COMPLAINT_INTERVAL)), 0.0, GameConfig.COMPLAINT_INTERVAL)
	state.money_earned = float(data.get("money_earned", 0.0))
	state.play_time = float(data.get("play_time", 0.0))
	state.saved_at = int(data.get("saved_at", 0))
	if data.has("rng_seed"):
		state.rng.seed = str(data.rng_seed).to_int()
		state.rng.state = str(data.get("rng_state", "0")).to_int()
	else:
		state.rng.randomize()
	if state.unlocked_count() == 0:
		state.unlock_department("general_services")
	state._ensure_stations()
	state._repair_kitchen_slots()
	return state


func _ensure_stations() -> void:
	for dept in unlocked_departments():
		for key in RouteBuilder.required_stations(dept.id):
			if not stations.has(key):
				var created := Station.new(key)
				if not created.machine:
					created.staff = 1
				stations[key] = created
