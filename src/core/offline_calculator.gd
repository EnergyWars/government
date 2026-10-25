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
	return Formulas.income_per_second(state) * GameConfig.OFFLINE_EFFICIENCY


static func compute(state: GameState, now: int) -> Dictionary:
	var seconds := effective_seconds(state.saved_at, now)
	var money := earnings_per_second(state) * seconds
	return {"seconds": seconds, "money": money}


static func double_up(state: GameState, result: Dictionary) -> float:
	var bonus := float(result.get("money", 0.0)) * (GameConfig.AD_REWARD_FACTOR - 1.0)
	if bonus <= 0.0:
		return 0.0
	state.earn_windfall(bonus)
	state.ads_watched += 1
	return bonus


static func apply(state: GameState, now: int) -> Dictionary:
	var result := compute(state, now)
	if result.money > 0.0:
		state.earn_windfall(result.money)
	state.saved_at = now
	return result
