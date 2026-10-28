extends GutTest

var state: GameState
var sim: Simulation


func before_each() -> void:
	state = GameState.create_new(21)
	sim = Simulation.new(state)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9


func test_gains_count_fully_and_raise_the_peak() -> void:
	state.add_reputation(5.0)
	assert_eq(state.reputation, 5.0)
	assert_eq(state.reputation_peak, 5.0)
	state.add_reputation(0.0)
	assert_eq(state.reputation_peak, 5.0)


func test_losses_are_damped() -> void:
	state.reputation = 10.0
	state.add_reputation(-1.0)
	assert_almost_eq(state.reputation, 10.0 - GameConfig.REP_LOSS_FACTOR, 0.0001)
	assert_almost_eq(state.reputation_loss_budget, GameConfig.REP_MAX_LOSS_PER_MINUTE - GameConfig.REP_LOSS_FACTOR, 0.0001)


func test_losses_stop_at_the_minute_budget() -> void:
	state.reputation = 10.0
	for i in 100:
		state.add_reputation(-50.0)
	assert_almost_eq(state.reputation, 10.0 - GameConfig.REP_MAX_LOSS_PER_MINUTE, 0.0001)
	assert_eq(state.reputation_loss_budget, 0.0)


func test_reputation_never_goes_negative() -> void:
	state.reputation = 0.01
	state.add_reputation(-10.0)
	assert_eq(state.reputation, 0.0)


func test_budget_refills_over_a_minute() -> void:
	state.reputation_loss_budget = 0.0
	state.refill_loss_budget(30.0)
	assert_almost_eq(state.reputation_loss_budget, GameConfig.REP_MAX_LOSS_PER_MINUTE * 0.5, 0.0001)
	state.refill_loss_budget(600.0)
	assert_eq(state.reputation_loss_budget, GameConfig.REP_MAX_LOSS_PER_MINUTE)


func test_tick_refills_the_budget() -> void:
	state.reputation_loss_budget = 0.0
	sim.tick(6.0)
	assert_almost_eq(state.reputation_loss_budget, GameConfig.REP_MAX_LOSS_PER_MINUTE * 0.1, 0.0001)


func test_long_failure_streak_only_stagnates() -> void:
	state.reputation = 50.0
	for minute in 10:
		for i in 200:
			state.add_reputation(GameConfig.REP_CITIZEN_LEFT)
		state.refill_loss_budget(60.0)
	assert_gte(state.reputation, 50.0 - 10.0 * GameConfig.REP_MAX_LOSS_PER_MINUTE - 0.001)


func test_standing_uses_the_peak_for_progress() -> void:
	state.add_reputation(200.0)
	state.reputation = 10.0
	assert_eq(state.standing(), 200.0)
	assert_eq(Progression.unlock_block_reason(state, "tax_services") != "reputation", true)
	state.reputation_peak = 0.0
	assert_eq(state.standing(), 10.0)


func test_reputation_goal_uses_standing() -> void:
	var goals := GoalTracker.new(state)
	state.reputation_peak = 999.0
	state.reputation = 1.0
	assert_eq(goals.progress_of({"type": "reputation", "target": 1.0, "param": ""}), 999.0)


func test_peak_and_budget_are_saved_and_validated() -> void:
	state.add_reputation(30.0)
	state.reputation = 12.0
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.reputation_peak, 30.0)
	var data := state.to_dict()
	data.erase("reputation_peak")
	loaded = GameState.from_dict(data)
	assert_eq(loaded.reputation_peak, 12.0)
	data.reputation_peak = -5.0
	loaded = GameState.from_dict(data)
	assert_eq(loaded.reputation_peak, 12.0)


func test_review_factor_drives_arrivals() -> void:
	assert_eq(Formulas.review_arrival_factor(state), 1.0)
	var base := Formulas.arrival_interval(state)
	state.add_review(5)
	assert_almost_eq(Formulas.arrival_interval(state), base / 1.25, 0.0001)
	state.reviews.clear()
	state.add_review(4)
	assert_eq(Formulas.arrival_interval(state), base)
	state.reviews.clear()
	state.add_review(1)
	assert_almost_eq(Formulas.arrival_interval(state), base / 0.4, 0.0001)


func test_reputation_no_longer_brings_more_citizens() -> void:
	var base := Formulas.arrival_interval(state)
	state.add_reputation(100.0)
	assert_eq(Formulas.arrival_interval(state), base)


func test_kranz_ends_on_its_own_and_rewards_the_player() -> void:
	var review := state.station("general_services/review")
	while review.desks < GameConfig.KRANZ_SIZE + GameConfig.KRANZ_MIN_PARTICIPANTS:
		review.add_desk()
	review.staff = review.desks
	assert_true(sim.call_kranz())
	state.kranz_elapsed = GameConfig.KRANZ_MAX_SECONDS
	sim.tick(0.05)
	assert_false(state.kranz)
	assert_eq(state.kranz_elapsed, 0.0)
	assert_true(sim.call_kranz())
	var before := state.reputation
	sim.end_kranz(true)
	assert_almost_eq(state.reputation, before + GameConfig.KRANZ_END_REPUTATION, 0.0001)
