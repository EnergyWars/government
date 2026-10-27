extends GutTest

var state: GameState
var actions: GameActions


func before_each() -> void:
	state = GameState.create_new(21)
	actions = GameActions.new(state, Simulation.new(state))


func test_ladder_values_follow_mantissas_and_decades() -> void:
	var ladder := MilestoneLadder.new(10.0, [1.0, 2.5, 5.0] as Array[float])
	assert_eq(ladder.value_at(-1), 0.0)
	assert_almost_eq(ladder.value_at(0), 10.0, 0.001)
	assert_almost_eq(ladder.value_at(1), 25.0, 0.001)
	assert_almost_eq(ladder.value_at(2), 50.0, 0.001)
	assert_almost_eq(ladder.value_at(3), 100.0, 0.001)
	assert_almost_eq(ladder.value_at(7), 2500.0, 0.001)


func test_ladder_index_of_values() -> void:
	var ladder := MilestoneLadder.new(1000.0, [1.0, 5.0] as Array[float])
	assert_eq(ladder.index_of(0.0), -1)
	assert_eq(ladder.index_of(999.9), -1)
	assert_eq(ladder.index_of(1000.0), 0)
	assert_eq(ladder.index_of(4999.0), 0)
	assert_eq(ladder.index_of(5000.0), 1)
	assert_eq(ladder.index_of(1e6), 6)


func test_ladder_index_is_capped_for_huge_values() -> void:
	var ladder := MilestoneLadder.new(1.0, [1.0] as Array[float])
	assert_eq(ladder.index_of(INF), MilestoneLadder.MAX_STEPS - 1)


func test_ladder_reports_each_crossing_once() -> void:
	var ladder := MilestoneLadder.new(10.0, [1.0, 2.5, 5.0] as Array[float])
	ladder.start(5.0)
	assert_eq(ladder.update(9.0), 0.0)
	assert_almost_eq(ladder.update(12.0), 10.0, 0.001)
	assert_eq(ladder.update(20.0), 0.0)
	assert_almost_eq(ladder.update(60.0), 50.0, 0.001)
	assert_eq(ladder.update(40.0), 0.0)
	assert_eq(ladder.update(60.0), 0.0)


func test_ladder_start_skips_already_reached_milestones() -> void:
	var ladder := MilestoneLadder.new(10.0, [1.0, 2.5, 5.0] as Array[float])
	ladder.start(300.0)
	assert_eq(ladder.update(300.0), 0.0)
	assert_eq(ladder.update(499.0), 0.0)
	assert_almost_eq(ladder.update(500.0), 500.0, 0.001)


func test_ladder_guards_invalid_configuration() -> void:
	var ladder := MilestoneLadder.new(0.0, [] as Array[float])
	assert_gt(ladder.first, 0.0)
	assert_eq(ladder.mantissas.size(), 1)
	assert_gt(ladder.value_at(1), ladder.value_at(0))


func test_streak_counts_hits_inside_window() -> void:
	var streak := StreakCounter.new(1.0)
	assert_eq(streak.hit(), 1)
	streak.advance(0.5)
	assert_eq(streak.hit(), 2)
	streak.advance(0.9)
	assert_eq(streak.hit(), 3)
	assert_eq(streak.count, 3)


func test_streak_resets_after_window() -> void:
	var streak := StreakCounter.new(1.0)
	streak.hit()
	streak.hit()
	streak.advance(1.5)
	assert_eq(streak.count, 0)
	assert_eq(streak.hit(), 1)


func test_streak_hit_resets_when_window_passed_without_advance_reset() -> void:
	var streak := StreakCounter.new(1.0)
	streak.hit()
	streak.count = 4
	streak._clock = 5.0
	assert_eq(streak.hit(), 1)


func test_streak_reset_and_negative_values() -> void:
	var streak := StreakCounter.new(-3.0)
	assert_eq(streak.window, 0.0)
	streak.hit()
	streak.advance(-1.0)
	assert_eq(streak.count, 1)
	streak.reset()
	assert_eq(streak.count, 0)


func test_streak_milestones() -> void:
	for value in [3, 5, 10, 20, 30, 100]:
		assert_true(StreakCounter.is_milestone(value), str(value))
	for value in [0, 1, 2, 4, 6, 9, 11, 25]:
		assert_false(StreakCounter.is_milestone(value), str(value))


func test_buy_entry_emits_purchased() -> void:
	state.money = 1e9
	watch_signals(actions)
	assert_true(actions.buy_entry("track:briefcase", 3))
	assert_signal_emitted_with_parameters(actions, "purchased", ["track:briefcase", 3])
	assert_true(actions.buy_entry("level:shared/reception", 0))
	assert_signal_emitted_with_parameters(actions, "purchased", ["level:shared/reception", 1])


func test_failed_purchase_emits_nothing() -> void:
	state.money = 0.0
	watch_signals(actions)
	assert_false(actions.buy_entry("track:briefcase"))
	assert_false(actions.buy_entry("bogus:1"))
	assert_signal_not_emitted(actions, "purchased")


func test_building_stage_cannot_be_bought() -> void:
	state.money = 1e12
	state.reputation = 1e6
	watch_signals(actions)
	assert_false(actions.buy_entry("stage:building"))
	assert_signal_not_emitted(actions, "purchased")
	assert_eq(state.building_stage, 0)


func test_goal_claim_emits_reward() -> void:
	var goals := GoalTracker.new(state)
	watch_signals(goals)
	assert_false(goals.claim())
	assert_signal_not_emitted(goals, "claimed")
	var goal := goals.current()
	state.cases_completed = int(goal.target)
	assert_true(goals.claim())
	assert_signal_emitted_with_parameters(goals, "claimed", [float(goal.money), float(goal.reputation), GameConfig.GOAL_SEALS])


func test_doubled_goal_claim_emits_doubled_money() -> void:
	var goals := GoalTracker.new(state)
	watch_signals(goals)
	var goal := goals.current()
	state.cases_completed = int(goal.target)
	assert_true(goals.claim_doubled())
	assert_signal_emitted_with_parameters(goals, "claimed", [float(goal.money) * GameConfig.AD_REWARD_FACTOR, float(goal.reputation), GameConfig.GOAL_SEALS])
