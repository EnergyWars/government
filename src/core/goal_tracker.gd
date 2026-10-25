class_name GoalTracker
extends RefCounted

var state: GameState


func _init(p_state: GameState) -> void:
	state = p_state


func has_goal() -> bool:
	return state.goal_index < GameConfig.GOALS.size()


func current() -> Dictionary:
	return GameConfig.GOALS[state.goal_index] if has_goal() else {}


func progress_of(goal: Dictionary) -> float:
	match str(goal.get("type", "")):
		"cases":
			return state.cases_completed
		"staff_hired":
			return state.staff_hired
		"runners":
			return state.runners.size()
		"station_level":
			return state.max_station_level()
		"building_stage":
			return state.building_stage
		"department":
			var dept := state.department(goal.param)
			return 1.0 if dept != null and dept.unlocked else 0.0
		"upgrades":
			return state.upgrade_count()
		"upgrade_level":
			return state.upgrade_level(goal.param)
		"reputation":
			return floorf(state.standing())
	return 0.0


func current_progress() -> float:
	return progress_of(current()) if has_goal() else 0.0


func is_complete() -> bool:
	return has_goal() and current_progress() >= float(current().target)


func claim() -> bool:
	return _claim(1.0)


func claim_doubled() -> bool:
	if not _claim(GameConfig.AD_REWARD_FACTOR):
		return false
	state.ads_watched += 1
	return true


func _claim(money_factor: float) -> bool:
	if not is_complete():
		return false
	var goal := current()
	state.grant(float(goal.money) * money_factor)
	state.add_reputation(float(goal.reputation))
	state.seals += GameConfig.GOAL_SEALS
	state.goal_index += 1
	return true
