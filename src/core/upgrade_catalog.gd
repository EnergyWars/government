class_name UpgradeCatalog
extends RefCounted

const TRACK := "track"
const DESK := "desk"
const HIRE := "hire"
const STAFF := "staff"
const RUNNER_LEVEL := "runner_level"
const SEGMENT := "segment"
const STORAGE := "storage"
const REJECT_PILE := "reject_pile"
const UNLOCK := "unlock"
const RANK := "rank"
const SINGLE_KINDS: Array[String] = [UNLOCK]
const STAFF_SPOTS := {
	"runners": "runners",
	"coffee_interns": "coffee_interns",
	"hr": "phone_clerks",
}
const STAFF_LIMITS := {
	"runners": GameConfig.MAX_RUNNERS,
	"coffee_interns": GameConfig.MAX_COFFEE_INTERNS,
	"hr": GameConfig.MAX_HR,
}
const STAFF_GROWTH := {
	"runners": GameConfig.RUNNER_GROWTH,
	"coffee_interns": GameConfig.COFFEE_INTERN_GROWTH,
	"hr": GameConfig.HR_GROWTH,
}
const TUBE_HUB := "tube_hub"
const TUBE_PREFIX := "tube:"
const DEPT_PREFIX := "dept:"
const ROOM_PREFIX := "room:"
const STATION_PREFIX := "station:"
const TRAYS_PREFIX := "trays:"
const STATION_ROOM_TRACKS: Array[String] = ["room_speed"]
const TRAY_ROOM_TRACKS: Array[String] = ["room_trays"]
const LEAD_PREFIX := "lead:"


static func entries(state: GameState) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	for dept in state.unlocked_departments():
		result.append(rank(state, dept))
	for upgrade_id in GameConfig.upgrade_ids():
		if not GameConfig.is_room_upgrade(upgrade_id):
			result.append(track(state, upgrade_id))
			continue
		for room_id in GameConfig.upgrade_rooms(upgrade_id):
			if Progression.room_available(state, room_id):
				result.append(track(state, upgrade_id, room_id))
	for key in state.ordered_station_keys():
		result.append_array(station_entries(state, key))
	for staff_type: String in STAFF_SPOTS:
		result.append(staff(state, staff_type))
	for index in state.runners.size():
		result.append(runner_level(state, index))
	result.append_array(segments(state))
	if state.mailroom() != null:
		result.append(storage(state))
	for dept_id in GameConfig.department_ids():
		if not state.department(dept_id).unlocked:
			result.append(unlock(state, dept_id))
	return result


static func expansion_entries(state: GameState) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	for entry in entries(state):
		if is_expansion(entry):
			result.append(entry)
	var paybacks: Dictionary[String, float] = {}
	for entry in result:
		paybacks[entry.id] = payback(state, entry)
	result.sort_custom(func(a: UpgradeEntry, b: UpgradeEntry) -> bool: return paybacks[a.id] < paybacks[b.id])
	return result


static func is_expansion(entry: UpgradeEntry) -> bool:
	match entry.kind:
		RANK:
			return not entry.is_maxed()
		UNLOCK:
			return entry.reason != "later"
	return false


static func income_gain(state: GameState, entry: UpgradeEntry) -> float:
	var dept := state.department(entry.target)
	if dept == null:
		return 0.0
	match entry.kind:
		RANK:
			return DepartmentRank.gain_per_second(state, dept)
		UNLOCK:
			return Formulas.potential_income(state, dept)
	return 0.0


static func payback(state: GameState, entry: UpgradeEntry) -> float:
	var gain := income_gain(state, entry)
	return entry.cost / gain if gain > 0.0 else INF


static func entries_for_spot(state: GameState, spot: String) -> Array[UpgradeEntry]:
	if spot.begins_with(ROOM_PREFIX):
		return entries_for_room(state, spot.trim_prefix(ROOM_PREFIX))
	var result: Array[UpgradeEntry] = []
	for entry in entries(state):
		if shows_at(entry, spot):
			result.append(entry)
	return result


static func shows_at(entry: UpgradeEntry, spot: String) -> bool:
	if entry.spot == spot:
		return true
	if spot == TUBE_HUB:
		return entry.spot.begins_with(TUBE_PREFIX)
	if spot.begins_with(DEPT_PREFIX):
		return entry.room == spot.trim_prefix(DEPT_PREFIX)
	if spot.begins_with(STATION_PREFIX):
		return _room_track_at(entry, STATION_ROOM_TRACKS, spot.trim_prefix(STATION_PREFIX))
	if spot.begins_with(TRAYS_PREFIX):
		return _room_track_at(entry, TRAY_ROOM_TRACKS, spot.trim_prefix(TRAYS_PREFIX))
	return false


static func _room_track_at(entry: UpgradeEntry, tracks: Array[String], key: String) -> bool:
	return entry.kind == TRACK and tracks.has(entry.target) and entry.room_id == GameConfig.station_room(key)


static func spots_of(entries_list: Array[UpgradeEntry]) -> Array[String]:
	var found: Array[String] = []
	for entry in entries_list:
		if not found.has(entry.spot):
			found.append(entry.spot)
	var result: Array[String] = []
	for spot: String in GameConfig.SPOTS:
		if found.has(spot):
			result.append(spot)
	for spot in found:
		if not GameConfig.SPOTS.has(spot):
			result.append(spot)
	return result


static func entries_for_room(state: GameState, room_id: String) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	for entry in entries(state):
		if entry.room == room_id:
			result.append(entry)
	return result


static func find(state: GameState, entry_id: String) -> UpgradeEntry:
	var kind := entry_id.get_slice(":", 0)
	var target := entry_id.substr(kind.length() + 1)
	match kind:
		TRACK:
			var upgrade_id := target.get_slice("@", 0)
			var room_id := target.get_slice("@", 1) if target.contains("@") else ""
			if GameConfig.upgrade(upgrade_id).is_empty() or GameConfig.is_room_upgrade(upgrade_id) == room_id.is_empty():
				return null
			if not room_id.is_empty() and not GameConfig.upgrade_rooms(upgrade_id).has(room_id):
				return null
			return track(state, upgrade_id, room_id)
		DESK, HIRE, REJECT_PILE:
			for entry in station_entries(state, target):
				if entry.kind == kind:
					return entry
		STAFF:
			return staff(state, target) if STAFF_SPOTS.has(target) else null
		RUNNER_LEVEL:
			return runner_level(state, target.to_int()) if target.is_valid_int() and target.to_int() >= 0 and target.to_int() < state.runners.size() else null
		SEGMENT:
			return segment(state, target)
		STORAGE:
			return storage(state) if state.mailroom() != null else null
		UNLOCK:
			var locked := state.department(target)
			return unlock(state, target) if locked != null and not locked.unlocked else null
		RANK:
			var ranked := state.department(target)
			return rank(state, ranked) if ranked != null and ranked.unlocked else null
	return null


static func room_spot(room_id: String) -> String:
	return GameConfig.room_spot(room_id)


static func rooms() -> Array[String]:
	var result: Array[String] = GameConfig.SERVICE_ROOMS.duplicate()
	result.append_array(GameConfig.department_ids())
	return result


static func track(state: GameState, upgrade_id: String, room_id: String = "") -> UpgradeEntry:
	var config := GameConfig.upgrade(upgrade_id)
	var entry := _entry(TRACK, GameConfig.upgrade_key(upgrade_id, room_id), GameConfig.upgrade_spot(upgrade_id, room_id), str(config.topic))
	entry.target = upgrade_id
	entry.room_id = room_id
	entry.level = state.upgrade_level(upgrade_id, room_id)
	entry.max_level = int(config.max)
	entry.cost = Formulas.track_cost(upgrade_id, entry.level, room_id)
	entry.growth = float(config.growth)
	entry.price_level = Formulas.track_price_level(upgrade_id, entry.level)
	entry.reason = Progression.upgrade_block_reason(state, upgrade_id, room_id)
	return entry


static func station_entries(state: GameState, key: String) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	var station := state.station(key)
	if station == null:
		return result
	var spot := STATION_PREFIX + key
	var desk := _entry(DESK, key, spot, "building")
	desk.level = station.desks
	desk.max_level = maxi(station.desks, state.max_desks())
	desk.cost = Formulas.desk_cost(station)
	desk.growth = GameConfig.DESK_GROWTH
	desk.price_level = station.desks - 1
	desk.reason = "stage" if desk.is_maxed() and state.max_desks() < final_desks() else _money_reason(state, desk)
	result.append(desk)
	if not station.machine:
		var hire := _entry(HIRE, key, spot, "staff")
		hire.level = station.staff
		hire.max_level = station.desks
		hire.cost = Formulas.hire_cost(station)
		hire.growth = GameConfig.HIRE_GROWTH
		hire.price_level = station.staff
		hire.reason = _hire_reason(state, station, hire)
		result.append(hire)
	if station.has_reject_pile():
		var pile := _entry(REJECT_PILE, key, TRAYS_PREFIX + key, "building")
		pile.level = station.reject_level
		pile.max_level = GameConfig.MAX_REJECT_LEVEL
		pile.cost = Formulas.reject_pile_cost(station)
		pile.growth = GameConfig.REJECT_PILE_GROWTH
		pile.price_level = station.reject_level
		pile.reason = _money_reason(state, pile)
		result.append(pile)
	return result


static func final_desks() -> int:
	return int(GameConfig.building_stage(GameConfig.BUILDING_STAGES.size() - 1).max_desks)


static func staff(state: GameState, staff_type: String) -> UpgradeEntry:
	var entry := _entry(STAFF, staff_type, str(STAFF_SPOTS[staff_type]), "staff")
	entry.level = staff_count(state, staff_type)
	entry.max_level = int(STAFF_LIMITS[staff_type])
	entry.cost = staff_cost(state, staff_type)
	entry.growth = float(STAFF_GROWTH[staff_type])
	entry.price_level = entry.level
	entry.reason = _money_reason(state, entry)
	return entry


static func staff_count(state: GameState, staff_type: String) -> int:
	match staff_type:
		"runners":
			return state.runners.size()
		"coffee_interns":
			return state.coffee_interns.size()
		"hr":
			return state.hr
	return 0


static func staff_cost(state: GameState, staff_type: String) -> float:
	match staff_type:
		"runners":
			return Formulas.runner_cost(state)
		"coffee_interns":
			return Formulas.coffee_intern_cost(state)
		"hr":
			return Formulas.hr_cost(state)
	return 0.0


static func runner_level(state: GameState, index: int) -> UpgradeEntry:
	var runner := state.runners[index]
	var entry := _entry(RUNNER_LEVEL, str(index), "runners", "transport")
	entry.index = index
	entry.level = runner.level
	entry.max_level = GameConfig.MAX_RUNNER_LEVEL
	entry.cost = Formulas.runner_level_cost(runner)
	entry.growth = GameConfig.RUNNER_LEVEL_GROWTH
	entry.price_level = entry.level
	entry.reason = _money_reason(state, entry)
	return entry


static func segments(state: GameState) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	if not state.has_upgrade("pneumatic_tubes"):
		return result
	for dept in state.unlocked_departments():
		for tube_id in RouteBuilder.segments(dept.id):
			var entry := segment(state, tube_id)
			if entry != null:
				result.append(entry)
	return result


static func segment(state: GameState, tube_id: String) -> UpgradeEntry:
	var dept := state.department(RouteBuilder.segment_department(tube_id))
	if not state.has_upgrade("pneumatic_tubes") or dept == null or not dept.unlocked or not RouteBuilder.segments(dept.id).has(tube_id):
		return null
	var ends := RouteBuilder.segment_ends(tube_id)
	if state.station(ends[0]) == null or state.station(ends[1]) == null:
		return null
	var entry := _entry(SEGMENT, tube_id, TUBE_PREFIX + dept.id, "transport")
	entry.level = state.tube_level(tube_id)
	entry.max_level = GameConfig.TUBE_SEGMENT_MAX_LEVEL
	entry.cost = Formulas.tube_segment_cost(entry.level)
	entry.growth = GameConfig.TUBE_SEGMENT_GROWTH
	entry.price_level = entry.level
	entry.reason = "tubes" if not entry.is_maxed() and not state.tube_link(ends[0], ends[1]) else _money_reason(state, entry)
	return entry


static func storage(state: GameState) -> UpgradeEntry:
	var room := state.mailroom()
	var entry := _entry(STORAGE, GameConfig.MAILROOM, "mail_shelf", "mail")
	entry.level = room.storage_level
	entry.max_level = GameConfig.MAIL_STORAGE_MAX_LEVEL
	entry.cost = Formulas.mail_storage_cost(room)
	entry.growth = GameConfig.MAIL_STORAGE_GROWTH
	entry.price_level = entry.level
	entry.reason = _money_reason(state, entry)
	return entry


static func unlock(state: GameState, dept_id: String) -> UpgradeEntry:
	var entry := _entry(UNLOCK, dept_id, DEPT_PREFIX + dept_id, "building")
	entry.level = 1 if state.department(dept_id).unlocked else 0
	entry.cost = float(GameConfig.department(dept_id).unlock_cost)
	entry.single = true
	entry.reason = "later" if Progression.next_locked_department(state) != dept_id else Progression.unlock_block_reason(state, dept_id)
	return entry


static func rank(state: GameState, dept: Department) -> UpgradeEntry:
	var entry := _entry(RANK, dept.id, DEPT_PREFIX + dept.id, "building")
	entry.level = dept.rank
	entry.max_level = GameConfig.MAX_DEPARTMENT_RANK
	entry.cost = DepartmentRank.next_cost(dept)
	entry.growth = GameConfig.RANK_LEVEL_COST_GROWTH
	entry.cap = DepartmentRank.reachable_level(state, dept)
	entry.reason = DepartmentRank.block_reason(state, dept.id)
	return entry


static func buy(actions: GameActions, entry_id: String, count: int = 1) -> bool:
	var kind := entry_id.get_slice(":", 0)
	var target := entry_id.substr(kind.length() + 1)
	if kind == TRACK:
		var upgrade_id := target.get_slice("@", 0)
		var room_id := target.get_slice("@", 1) if target.contains("@") else ""
		return actions.buy_upgrade(upgrade_id, room_id, maxi(1, count))
	var repeats := 1 if SINGLE_KINDS.has(kind) else maxi(1, count)
	var bought := 0
	for i in repeats:
		if not _buy_once(actions, kind, target):
			break
		bought += 1
	return bought > 0


static func _buy_once(actions: GameActions, kind: String, target: String) -> bool:
	match kind:
		DESK:
			return actions.add_desk(target)
		HIRE:
			return actions.hire(target)
		REJECT_PILE:
			return actions.upgrade_reject_pile(target)
		STAFF:
			return hire_staff(actions, target)
		RUNNER_LEVEL:
			return target.is_valid_int() and actions.upgrade_runner(target.to_int())
		SEGMENT:
			return actions.upgrade_tube(target)
		STORAGE:
			return actions.upgrade_mail_storage()
		UNLOCK:
			return actions.unlock_department(target)
		RANK:
			return actions.rank_up_department(target)
	return false


static func hire_staff(actions: GameActions, staff_type: String) -> bool:
	match staff_type:
		"runners":
			return actions.hire_runner()
		"coffee_interns":
			return actions.hire_coffee_intern()
		"hr":
			return actions.hire_hr()
	return false


static func _entry(kind: String, target: String, spot: String, topic: String) -> UpgradeEntry:
	var entry := UpgradeEntry.new()
	entry.id = "%s:%s" % [kind, target]
	entry.kind = kind
	entry.target = target
	entry.spot = spot
	entry.room = GameConfig.spot_room(spot)
	entry.topic = topic
	return entry


static func _money_reason(state: GameState, entry: UpgradeEntry) -> String:
	if entry.is_maxed():
		return "max"
	return "" if state.can_afford(entry.cost) else "money"


static func _hire_reason(state: GameState, station: Station, entry: UpgradeEntry) -> String:
	if station.staff >= station.desks:
		return "desks"
	var dept := state.department(station.dept_id)
	if not station.is_shared() and dept != null and not dept.is_onboarded():
		return "onboarding"
	return _money_reason(state, entry)
