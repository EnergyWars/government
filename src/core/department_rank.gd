class_name DepartmentRank
extends RefCounted


static func fee_factor(rank: int) -> float:
	return pow(GameConfig.RANK_FEE_FACTOR, clampi(rank, 1, GameConfig.MAX_DEPARTMENT_RANK) - 1)


static func tier(dept_id: String, rank: int) -> int:
	return maxi(0, GameConfig.department_ids().find(dept_id)) + clampi(rank, 1, GameConfig.MAX_DEPARTMENT_RANK) - 1


static func ladder_cost(tier_index: int) -> float:
	var ids := GameConfig.department_ids()
	var last := ids.size() - 1
	var index := maxi(0, tier_index)
	if index <= last:
		return float(GameConfig.department(ids[index]).unlock_cost)
	return float(GameConfig.department(ids[last]).unlock_cost) * pow(GameConfig.RANK_COST_GROWTH, index - last)


static func ladder_reputation(tier_index: int) -> float:
	var ids := GameConfig.department_ids()
	return float(GameConfig.department(ids[clampi(tier_index, 0, ids.size() - 1)]).unlock_reputation)


static func is_max(dept: Department) -> bool:
	return dept.rank >= GameConfig.MAX_DEPARTMENT_RANK


static func next_cost(dept: Department) -> float:
	return ladder_cost(tier(dept.id, dept.rank) + 1)


static func next_reputation(dept: Department) -> float:
	return ladder_reputation(tier(dept.id, dept.rank) + 1)


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
	return Formulas.potential_income(state, dept) * (GameConfig.RANK_FEE_FACTOR - 1.0)
