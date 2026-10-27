class_name Progression
extends RefCounted


static func unlock_block_reason(state: GameState, dept_id: String) -> String:
	var dept := state.department(dept_id)
	if dept == null:
		return "unknown"
	if dept.unlocked:
		return "unlocked"
	var config := dept.config()
	if state.standing() < float(config.unlock_reputation):
		return "reputation"
	if not state.can_afford(float(config.unlock_cost)):
		return "money"
	return ""


static func next_locked_department(state: GameState) -> String:
	for dept_id in GameConfig.department_ids():
		if not state.department(dept_id).unlocked:
			return dept_id
	return ""


static func upgrade_block_reason(state: GameState, upgrade_id: String, room_id: String = "", count: int = 1) -> String:
	var config := GameConfig.upgrade(upgrade_id)
	if config.is_empty() or GameConfig.is_room_upgrade(upgrade_id) == room_id.is_empty():
		return "unknown"
	if not room_id.is_empty() and not GameConfig.upgrade_rooms(upgrade_id).has(room_id):
		return "unknown"
	var level := state.upgrade_level(upgrade_id, room_id)
	if level >= int(config.max):
		return "max"
	if not room_available(state, room_id) or not room_available(state, GameConfig.spot_room(GameConfig.upgrade_spot(upgrade_id, room_id))):
		return "room"
	var requires: Dictionary = config.get("requires", {})
	for required_id: String in requires:
		if state.upgrade_level(required_id) < int(requires[required_id]):
			return "requires"
	if state.standing() < float(config.get("reputation", 0.0)):
		return "reputation"
	var amount := clampi(count, 1, int(config.max) - level)
	if not state.can_afford(Formulas.track_bulk_cost(upgrade_id, level, amount, room_id)):
		return "money"
	return ""


static func room_available(state: GameState, room_id: String) -> bool:
	match room_id:
		GameConfig.ROOM_MAIL:
			return state.mailroom() != null
		GameConfig.ROOM_INSPECTION:
			return state.station(GameConfig.INSPECTION) != null
	if room_id.is_empty() or GameConfig.SERVICE_ROOMS.has(room_id):
		return true
	var dept := state.department(room_id)
	return dept != null and dept.unlocked
