class_name DepartmentRank
extends RefCounted


static func clamp_level(level: int) -> int:
	return clampi(level, 1, GameConfig.MAX_DEPARTMENT_RANK)


static func milestones(level: int) -> int:
	return mini(floori(clamp_level(level) / float(GameConfig.RANK_MILESTONE_STEP)), GameConfig.RANK_MILESTONE_FACTORS.size())


static func is_milestone(level: int) -> bool:
	return level >= GameConfig.RANK_MILESTONE_STEP and level <= GameConfig.MAX_DEPARTMENT_RANK and level % GameConfig.RANK_MILESTONE_STEP == 0


static func milestone_factor(level: int) -> float:
	if not is_milestone(level):
		return 1.0
	return GameConfig.RANK_MILESTONE_FACTORS[milestones(level) - 1]


static func next_milestone(level: int) -> int:
	return mini((milestones(level) + 1) * GameConfig.RANK_MILESTONE_STEP, GameConfig.MAX_DEPARTMENT_RANK)


static func title_index(level: int) -> int:
	return mini(milestones(level) + 1, GameConfig.RANK_TITLES)


static func fee_factor(level: int) -> float:
	var capped := clamp_level(level)
	var factor := pow(GameConfig.RANK_LEVEL_FEE_FACTOR, capped - 1)
	for index in milestones(capped):
		factor *= GameConfig.RANK_MILESTONE_FACTORS[index]
	return factor


static func department_index(dept_id: String) -> int:
	return maxi(0, GameConfig.department_ids().find(dept_id))


static func ladder_cost(tier_index: int) -> float:
	var ids := GameConfig.department_ids()
	var last := ids.size() - 1
	var index := maxi(0, tier_index)
	if index <= last:
		return float(GameConfig.department(ids[index]).unlock_cost)
	return float(GameConfig.department(ids[last]).unlock_cost) * pow(GameConfig.RANK_LADDER_GROWTH, index - last)


static func ladder_reputation(tier_index: int) -> float:
	var ids := GameConfig.department_ids()
	return float(GameConfig.department(ids[clampi(tier_index, 0, ids.size() - 1)]).unlock_reputation)


static func base_cost(dept_id: String) -> float:
	var first_block := Formulas.geometric_sum(1.0, GameConfig.RANK_LEVEL_COST_GROWTH, GameConfig.RANK_MILESTONE_STEP - 1)
	return ladder_cost(department_index(dept_id) + 1) / first_block


static func level_cost(dept_id: String, level: int) -> float:
	return base_cost(dept_id) * pow(GameConfig.RANK_LEVEL_COST_GROWTH, clamp_level(level) - 1)


static func level_reputation(dept_id: String, level: int) -> float:
	return ladder_reputation(department_index(dept_id) + 1 + milestones(level))


static func is_max(dept: Department) -> bool:
	return dept.rank >= GameConfig.MAX_DEPARTMENT_RANK


static func next_cost(dept: Department) -> float:
	return level_cost(dept.id, dept.rank)


static func next_reputation(dept: Department) -> float:
	return level_reputation(dept.id, dept.rank)


static func reachable_level(state: GameState, dept: Department) -> int:
	var level := clamp_level(dept.rank)
	var standing := state.standing()
	while level < GameConfig.MAX_DEPARTMENT_RANK and standing >= level_reputation(dept.id, level):
		level = next_milestone(level)
	return level


static func block_reason(state: GameState, dept_id: String) -> String:
	var dept := state.department(dept_id)
	if dept == null:
		return "unknown"
	if not dept.unlocked:
		return "room"
	if is_max(dept):
		return "max"
	if state.standing() < next_reputation(dept):
		return "reputation"
	if not state.can_afford(next_cost(dept)):
		return "money"
	return ""


static func gain_per_second(state: GameState, dept: Department) -> float:
	if is_max(dept):
		return 0.0
	return Formulas.potential_income(state, dept) * (fee_factor(dept.rank + 1) / fee_factor(dept.rank) - 1.0)
