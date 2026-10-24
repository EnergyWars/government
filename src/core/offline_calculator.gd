class_name OfflineCalculator
extends RefCounted


static func effective_seconds(saved_at: int, now: int) -> float:
	if saved_at <= 0 or now <= saved_at:
		return 0.0
	var elapsed := float(now - saved_at)
	if elapsed < GameConfig.OFFLINE_MIN_SECONDS:
		return 0.0
	return minf(elapsed, GameConfig.OFFLINE_CAP_SECONDS)


static func earnings_per_second(state: GameState) -> float:
	var total := 0.0
	for dept in state.unlocked_departments():
		total += Formulas.department_throughput(state, dept) * Formulas.expected_case_value(state, dept)
	return total * GameConfig.OFFLINE_EFFICIENCY


static func compute(state: GameState, now: int) -> Dictionary:
	var seconds := effective_seconds(state.saved_at, now)
	var money := earnings_per_second(state) * seconds
	return {"seconds": seconds, "money": money}


static func apply(state: GameState, now: int) -> Dictionary:
	var result := compute(state, now)
	if result.money > 0.0:
		state.earn(result.money)
	state.saved_at = now
	return result
