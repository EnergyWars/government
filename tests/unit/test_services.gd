extends GutTest

const TEST_SAVE := "user://test_savegame.json"

var state: GameState


func before_each() -> void:
	state = GameState.create_new(11)


func after_each() -> void:
	SaveService.new(TEST_SAVE).delete()


func test_goal_progress_types() -> void:
	var goals := GoalTracker.new(state)
	state.cases_completed = 4
	state.staff_hired = 2
	state.building_stage = 1
	state.reputation = 7.9
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	state.add_runner()
	state.station("general_services/review").level = 3
	assert_eq(goals.progress_of({"type": "cases"}), 4.0)
	assert_eq(goals.progress_of({"type": "staff_hired"}), 2.0)
	assert_eq(goals.progress_of({"type": "runners"}), 1.0)
	assert_eq(goals.progress_of({"type": "station_level"}), 3.0)
	assert_eq(goals.progress_of({"type": "building_stage"}), 1.0)
	assert_eq(goals.progress_of({"type": "department", "param": "general_services"}), 1.0)
	assert_eq(goals.progress_of({"type": "department", "param": "tax_services"}), 0.0)
	assert_eq(goals.progress_of({"type": "department", "param": "nope"}), 0.0)
	assert_eq(goals.progress_of({"type": "upgrades"}), float(1 + GameConfig.upgrade_rooms("tube_station").size()))
	assert_eq(goals.progress_of({"type": "upgrade_level", "param": "pneumatic_tubes"}), 1.0)
	assert_eq(goals.progress_of({"type": "upgrade_level", "param": "kitchen"}), 0.0)
	assert_eq(goals.progress_of({"type": "reputation"}), 7.0)
	assert_eq(goals.progress_of({"type": "unknown"}), 0.0)


func test_goal_claim_flow() -> void:
	var goals := GoalTracker.new(state)
	assert_true(goals.has_goal())
	assert_false(goals.is_complete())
	assert_false(goals.claim())
	state.cases_completed = 3
	assert_true(goals.is_complete())
	var money := state.money
	assert_true(goals.claim())
	assert_eq(state.goal_index, 1)
	assert_almost_eq(state.money, money + float(GameConfig.GOALS[0].money), 0.001)
	assert_almost_eq(state.reputation, float(GameConfig.GOALS[0].reputation), 0.001)


func test_goals_end() -> void:
	var goals := GoalTracker.new(state)
	state.goal_index = GameConfig.GOALS.size()
	assert_false(goals.has_goal())
	assert_true(goals.current().is_empty())
	assert_eq(goals.current_progress(), 0.0)
	assert_false(goals.is_complete())
	assert_false(goals.claim())


func test_offline_effective_seconds() -> void:
	assert_eq(OfflineCalculator.effective_seconds(0, 1000), 0.0)
	assert_eq(OfflineCalculator.effective_seconds(1000, 900), 0.0)
	assert_eq(OfflineCalculator.effective_seconds(1000, 1030), 0.0)
	assert_eq(OfflineCalculator.effective_seconds(1000, 1600), 600.0)
	assert_eq(OfflineCalculator.effective_seconds(1000, 1000 + 999999), GameConfig.OFFLINE_CAP_SECONDS)


func test_offline_needs_automation() -> void:
	state.saved_at = 1000
	var result := OfflineCalculator.compute(state, 5000)
	assert_eq(result.money, 0.0)
	assert_eq(result.seconds, 4000.0)


func test_offline_earnings_follow_bottleneck() -> void:
	var dept := state.department("general_services")
	state.add_runner()
	state.add_runner()
	for key in state.stations:
		state.station(key).staff = 1
	state.saved_at = 1000
	var per_second := Formulas.department_throughput(state, dept) * Formulas.expected_case_value(state, dept) * GameConfig.OFFLINE_EFFICIENCY
	assert_almost_eq(OfflineCalculator.earnings_per_second(state), per_second, 0.0001)
	var money := state.money
	var result := OfflineCalculator.apply(state, 4600)
	assert_almost_eq(float(result.money), per_second * 3600.0, 0.01)
	assert_almost_eq(state.money, money + per_second * 3600.0, 0.01)
	assert_eq(state.saved_at, 4600)


func test_offline_apply_without_earnings_updates_timestamp() -> void:
	state.saved_at = 0
	var money := state.money
	OfflineCalculator.apply(state, 123)
	assert_eq(state.money, money)
	assert_eq(state.saved_at, 123)


func test_save_and_load_roundtrip() -> void:
	var service := SaveService.new(TEST_SAVE)
	assert_false(service.has_save())
	assert_null(service.load_state())
	state.money = 4321.0
	state.station("general_services/review").inbox.append(CaseFile.new("general_services", true))
	assert_true(service.save(state, 777))
	assert_true(service.has_save())
	var loaded := service.load_state()
	assert_almost_eq(loaded.money, 4321.0, 0.001)
	assert_eq(loaded.saved_at, 777)
	assert_eq(loaded.station("general_services/review").inbox.size(), 1)
	service.delete()
	assert_false(service.has_save())
	service.delete()


func test_load_rejects_corrupt_file() -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string("[not, json")
	file.close()
	assert_null(SaveService.new(TEST_SAVE).load_state())


func test_save_fails_for_invalid_path() -> void:
	assert_false(SaveService.new("user://missing_dir/sub/save.json").save(state, 1))


func test_default_save_path() -> void:
	assert_eq(SaveService.new().path, SaveService.DEFAULT_PATH)


func test_number_format_compact() -> void:
	assert_eq(NumberFormat.compact(0.0), "0")
	assert_eq(NumberFormat.compact(999.9), "999")
	assert_eq(NumberFormat.compact(1000.0), "1K")
	assert_eq(NumberFormat.compact(1550.0), "1.5K")
	assert_eq(NumberFormat.compact(99999.0), "99.9K")
	assert_eq(NumberFormat.compact(250000.0), "250K")
	assert_eq(NumberFormat.compact(3400000.0, ","), "3,4M")
	assert_eq(NumberFormat.compact(-1500.0), "-1.5K")
	assert_eq(NumberFormat.compact(1e21), "1000000Q")


func test_number_format_decimal_and_duration() -> void:
	assert_eq(NumberFormat.decimal(2.26, 1, ","), "2,3")
	assert_eq(NumberFormat.duration_parts(3725.0), {"hours": 1, "minutes": 2, "seconds": 5})
	assert_eq(NumberFormat.duration_parts(-5.0), {"hours": 0, "minutes": 0, "seconds": 0})


func test_game_advance_runs_fixed_steps() -> void:
	var game := Game.new(state)
	watch_signals(game)
	assert_eq(game.advance(GameConfig.TICK * 0.5), 0)
	assert_signal_not_emitted(game, "changed")
	assert_eq(game.advance(GameConfig.TICK * 0.6), 1)
	assert_signal_emitted(game, "changed")
	assert_eq(game.advance(GameConfig.TICK), 1)
	assert_signal_emit_count(game, "changed", 1)
	assert_eq(game.advance(100.0), GameConfig.MAX_STEPS_PER_FRAME)
	assert_eq(game.advance(0.0), 0)


func test_game_perform_emits_on_success_only() -> void:
	var game := Game.new(state)
	watch_signals(game)
	assert_false(game.perform(func() -> bool: return false))
	assert_signal_not_emitted(game, "changed")
	assert_true(game.perform(func() -> bool: return true))
	assert_signal_emitted(game, "changed")
