class_name Progression
extends RefCounted


static func unlock_block_reason(state: GameState, dept_id: String) -> String:
	var dept := state.department(dept_id)
	if dept == null:
		return "unknown"
	if dept.unlocked:
		return "unlocked"
	var config := dept.config()
	if state.unlocked_count() >= int(state.stage_config().max_departments):
		return "space"
	if state.reputation < float(config.unlock_reputation):
		return "reputation"
	if not state.can_afford(float(config.unlock_cost)):
		return "money"
	return ""


static func next_locked_department(state: GameState) -> String:
	for dept_id in GameConfig.department_ids():
		if not state.department(dept_id).unlocked:
			return dept_id
	return ""


static func research_block_reason(state: GameState, research_id: String) -> String:
	if not GameConfig.RESEARCH.has(research_id):
		return "unknown"
	var config: Dictionary = GameConfig.RESEARCH[research_id]
	var level := state.research_level(research_id)
	if level >= int(config.max_level):
		return "max"
	if state.reputation < float(config.reputation):
		return "reputation"
	if not state.can_afford(Formulas.research_cost(research_id, level)):
		return "money"
	return ""


static func expansion_block_reason(state: GameState) -> String:
	var next := state.building_stage + 1
	if next >= GameConfig.BUILDING_STAGES.size():
		return "max"
	var config := GameConfig.building_stage(next)
	if state.reputation < float(config.reputation):
		return "reputation"
	if not state.can_afford(float(config.cost)):
		return "money"
	return ""
