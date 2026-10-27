extends GutTest

var state: GameState
var game: Game
var boosts: Boosts


func before_each() -> void:
	state = GameState.create_new(23)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	game = Game.new(state)
	boosts = game.boosts


func _review() -> Station:
	return state.station("general_services/review")


func _team(count: int) -> Station:
	var review := _review()
	while review.desks < count:
		review.add_desk()
	review.staff = review.desks
	return review


func test_every_boost_is_configured_and_ordered() -> void:
	assert_eq(GameConfig.BOOST_ORDER.size(), GameConfig.BOOSTS.size())
	for boost_id in GameConfig.BOOST_ORDER:
		var config := GameConfig.boost(boost_id)
		assert_false(config.is_empty(), boost_id)
		assert_gt(int(config.seals), 0, boost_id)
		assert_gt(float(config.cooldown), 0.0, boost_id)
		assert_true(Icons.BOOSTS.has(boost_id), boost_id)
	assert_true(GameConfig.boost("nope").is_empty())
	assert_eq(Boosts.seal_cost("nope"), 0)


func test_new_games_start_with_seals() -> void:
	assert_eq(state.seals, GameConfig.START_SEALS)


func test_seal_purchase_spends_seals_and_starts_timer() -> void:
	watch_signals(boosts)
	assert_true(boosts.can_use("overtime", Boosts.SEALS))
	assert_true(boosts.use("overtime", Boosts.SEALS))
	assert_eq(state.seals, GameConfig.START_SEALS - Boosts.seal_cost("overtime"))
	assert_true(state.is_boost_active("overtime"))
	assert_eq(state.boost_left("overtime"), float(GameConfig.BOOSTS.overtime.duration))
	assert_eq(state.boost_cooldown("overtime"), 0.0)
	assert_eq(state.boosts_used, 1)
	assert_signal_emitted_with_parameters(boosts, "used", ["overtime", Boosts.SEALS])
	assert_false(boosts.is_available("overtime"))
	assert_false(boosts.use("overtime", Boosts.SEALS))


func test_ad_boost_needs_cooldown_instead_of_seals() -> void:
	state.seals = 0
	assert_false(boosts.can_use("overtime", Boosts.SEALS))
	assert_true(boosts.use("overtime", Boosts.AD))
	assert_eq(state.seals, 0)
	assert_eq(state.ads_watched, 1)
	assert_eq(state.boost_cooldown("overtime"), float(GameConfig.BOOSTS.overtime.cooldown))
	state.advance_boosts(float(GameConfig.BOOSTS.overtime.duration) + 1.0)
	assert_false(state.is_boost_active("overtime"))
	assert_false(boosts.can_use("overtime", Boosts.AD))
	state.advance_boosts(float(GameConfig.BOOSTS.overtime.cooldown))
	assert_true(boosts.can_use("overtime", Boosts.AD))


func test_unknown_boosts_and_sources_are_rejected() -> void:
	assert_false(boosts.use("nope", Boosts.SEALS))
	assert_false(boosts.can_use("overtime", "coupon"))
	assert_false(boosts.use("overtime", "coupon"))


func test_express_post_needs_the_mail_room() -> void:
	assert_false(boosts.is_available("express_post"))
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	assert_true(boosts.is_available("express_post"))


func test_timers_expire_and_are_saved() -> void:
	boosts.use("fee_increase", Boosts.AD)
	game.simulation.tick(10.0)
	assert_almost_eq(state.boost_left("fee_increase"), float(GameConfig.BOOSTS.fee_increase.duration) - 10.0, 0.001)
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_almost_eq(loaded.boost_left("fee_increase"), state.boost_left("fee_increase"), 0.001)
	assert_almost_eq(loaded.boost_cooldown("fee_increase"), state.boost_cooldown("fee_increase"), 0.001)
	assert_eq(loaded.ads_watched, 1)
	assert_eq(loaded.boosts_used, 1)
	assert_eq(loaded.seals, state.seals)


func test_invalid_boost_save_data_is_repaired() -> void:
	var data := state.to_dict()
	data.seals = -4
	data.ads_watched = -1
	data.boosts_used = -2
	data.boosts = {"overtime": 1e9, "nope": 10.0, "fee_increase": -3.0}
	data.boost_cooldowns = {"overtime": 1e9, Boosts.SICK_NOTE: 1e9, "budget_injection": 0.0}
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.seals, 0)
	assert_eq(loaded.ads_watched, 0)
	assert_eq(loaded.boosts_used, 0)
	assert_eq(loaded.boosts.keys(), ["overtime"])
	assert_eq(loaded.boost_left("overtime"), float(GameConfig.BOOSTS.overtime.duration))
	assert_eq(loaded.boost_cooldown("overtime"), float(GameConfig.BOOSTS.overtime.cooldown))
	assert_eq(loaded.boost_cooldown(Boosts.SICK_NOTE), GameConfig.AD_SICK_COOLDOWN)
	assert_false(loaded.boost_cooldowns.has("budget_injection"))
	data.boosts = "junk"
	data.erase("seals")
	loaded = GameState.from_dict(data)
	assert_true(loaded.boosts.is_empty())
	assert_eq(loaded.seals, GameConfig.START_SEALS)


func test_overtime_stamp_and_express_speed_up_work() -> void:
	var review := _review()
	var signature := Station.new("tax_services/signature")
	assert_true(signature.machine)
	assert_eq(Formulas.work_speed(state, review), 1.0)
	state.boosts["overtime"] = 10.0
	assert_eq(Formulas.work_speed(state, review), GameConfig.BOOST_OVERTIME_SPEED)
	state.boosts["stamp_turbo"] = 10.0
	assert_eq(Formulas.work_speed(state, review), GameConfig.BOOST_OVERTIME_SPEED)
	assert_eq(Formulas.work_speed(state, signature), GameConfig.BOOST_OVERTIME_SPEED * GameConfig.BOOST_STAMP_SPEED)
	state.boosts.clear()
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	var room := state.ensure_mailroom()
	state.boosts["express_post"] = 10.0
	assert_eq(Formulas.work_speed(state, room), GameConfig.BOOST_POST_SPEED)
	assert_eq(Formulas.work_speed(state, review), 1.0)


func test_temp_workers_staff_empty_desks() -> void:
	var review := _review()
	review.add_desk()
	review.staff = 0
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = 1
	review.inbox.append(case_file)
	game.simulation.tick(0.05)
	assert_null(review.jobs[0])
	assert_true(boosts.use("temp_workers", Boosts.SEALS))
	game.simulation.tick(0.05)
	assert_not_null(review.jobs[0])
	assert_gt(review.jobs[0].progress, 0.0)


func test_coffee_round_wakes_everyone_and_stops_drowsiness() -> void:
	var review := _team(3)
	review.moods[0].rest(DeskMood.ASLEEP)
	review.moods[1].rest(DeskMood.SICK)
	assert_true(boosts.use("coffee_round", Boosts.SEALS))
	assert_false(review.moods[0].is_resting())
	assert_true(review.moods[1].is_sick())
	var alert := review.moods[2].alert
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = 1
	review.inbox.append(case_file)
	game.simulation.tick(1.0)
	assert_gte(review.moods[2].alert, alert)


func test_doctor_cures_only_the_sick() -> void:
	var review := _team(2)
	review.moods[0].rest(DeskMood.ASLEEP)
	review.moods[1].rest(DeskMood.SICK)
	assert_true(boosts.use("doctor_visit", Boosts.SEALS))
	assert_true(review.moods[0].is_resting())
	assert_false(review.moods[1].is_sick())
	assert_false(state.is_boost_active("doctor_visit"))
	assert_eq(state.seals, GameConfig.START_SEALS - Boosts.seal_cost("doctor_visit"))


func test_works_outing_calms_the_office_and_blocks_trouble() -> void:
	var review := _team(4)
	assert_true(game.simulation.call_kranz())
	assert_true(boosts.use("works_outing", Boosts.SEALS))
	assert_false(state.kranz)
	assert_true(state.disputes.is_empty())
	state.kranz_timer = 0.0
	state.sick_timer = 0.0
	state.cases_completed = 999
	state.dispute_timer = 0.0
	game.simulation.tick(0.05)
	assert_false(state.kranz)
	assert_eq(state.sick_count(), 0)
	assert_true(state.disputes.is_empty())
	assert_not_null(review)


func test_complaint_amnesty_clears_and_blocks_complaints() -> void:
	state.complaints = 5
	assert_true(boosts.use("complaint_amnesty", Boosts.SEALS))
	assert_eq(state.complaints, 0)
	game.simulation.file_complaint()
	assert_eq(state.complaints, 0)


func test_mayor_speech_keeps_citizens_waiting() -> void:
	var waiting := CaseFile.new("general_services")
	waiting.route = RouteBuilder.build(waiting)
	waiting.phase = CaseFile.Phase.WAITING
	waiting.place = 0
	waiting.waited = 1e6
	state.citizens.append(waiting)
	state.boosts["mayor_speech"] = 10.0
	game.simulation.tick(0.1)
	assert_true(state.citizens.has(waiting))
	state.boosts.clear()
	game.simulation.tick(0.1)
	assert_false(state.citizens.has(waiting))


func test_weekend_shift_finishes_running_jobs() -> void:
	var review := _review()
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = 1
	review.jobs[0] = StationJob.new(case_file, 100.0)
	assert_true(boosts.use("weekend_shift", Boosts.SEALS))
	assert_true(review.jobs[0] == null or review.jobs[0].is_done())
	assert_eq(game.simulation.finish_all_jobs(), 0)


func test_fee_increase_raises_fees_but_not_arrivals() -> void:
	var interval := Formulas.arrival_interval(state)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	var money: float = Formulas.case_outcome(state, case_file).money
	state.boosts["fee_increase"] = 10.0
	assert_eq(Formulas.arrival_interval(state), interval)
	assert_false(GameConfig.BOOSTS.has("gazette_ad"))
	assert_almost_eq(Formulas.case_outcome(state, case_file).money, money * GameConfig.BOOST_FEE_FACTOR, 0.001)


func test_budget_injection_grants_minutes_of_income() -> void:
	var money := state.money
	var grant := Formulas.budget_injection(state)
	assert_eq(grant, ceilf(GameConfig.BOOST_MIN_INCOME * GameConfig.BOOST_BUDGET_MINUTES))
	assert_true(boosts.use("budget_injection", Boosts.SEALS))
	assert_almost_eq(state.money, money + grant, 0.001)


func test_roller_skates_speed_up_player_and_runners() -> void:
	state.player.input = Vector2.RIGHT
	var start := state.player.position
	game.simulation.tick(0.1)
	var normal := state.player.position.distance_to(start)
	state.boosts["roller_skates"] = 10.0
	start = state.player.position
	game.simulation.tick(0.1)
	assert_almost_eq(state.player.position.distance_to(start), normal * GameConfig.BOOST_PLAYER_SPEED, 0.5)
	assert_eq(game.simulation._runner_speed(), GameConfig.RUNNER_SPEED * GameConfig.BOOST_RUNNER_SPEED)


func test_seal_packs_are_mock_purchases() -> void:
	assert_true(boosts.buy_seals(0))
	assert_eq(state.seals, GameConfig.START_SEALS + GameConfig.SEAL_PACKS[0])
	assert_false(boosts.buy_seals(-1))
	assert_false(boosts.buy_seals(GameConfig.SEAL_PACKS.size()))


func test_sick_note_by_ad() -> void:
	var review := _team(3)
	assert_false(boosts.can_cure_by_ad("general_services/review", 0))
	assert_false(boosts.can_cure_by_ad("nope", 0))
	assert_false(boosts.can_cure_by_ad("general_services/review", 99))
	assert_false(boosts.can_cure_by_ad("general_services/signature", 0))
	review.moods[0].rest(DeskMood.SICK)
	assert_true(boosts.cure_by_ad("general_services/review", 0))
	assert_false(review.moods[0].is_sick())
	assert_eq(state.ads_watched, 1)
	review.moods[1].rest(DeskMood.SICK)
	assert_false(boosts.cure_by_ad("general_services/review", 1))
	state.advance_boosts(GameConfig.AD_SICK_COOLDOWN)
	assert_true(boosts.cure_by_ad("general_services/review", 1))


func test_goals_give_seals_and_can_be_doubled_by_ad() -> void:
	state.cases_completed = 999
	var goal: Dictionary = game.goals.current()
	var money := state.money
	assert_true(game.goals.claim_doubled())
	assert_almost_eq(state.money, money + float(goal.money) * GameConfig.AD_REWARD_FACTOR, 0.001)
	assert_eq(state.seals, GameConfig.START_SEALS + GameConfig.GOAL_SEALS)
	assert_eq(state.ads_watched, 1)
	state.cases_completed = 0
	assert_false(game.goals.claim_doubled())
	assert_eq(state.ads_watched, 1)


func test_offline_earnings_can_be_doubled_once() -> void:
	var money := state.money
	assert_eq(OfflineCalculator.double_up(state, {"money": 0.0}), 0.0)
	assert_eq(OfflineCalculator.double_up(state, {}), 0.0)
	assert_eq(OfflineCalculator.double_up(state, {"money": 100.0}), 100.0 * (GameConfig.AD_REWARD_FACTOR - 1.0))
	assert_almost_eq(state.money, money + 100.0, 0.001)
	assert_eq(state.ads_watched, 1)
