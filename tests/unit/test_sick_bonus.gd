extends GutTest

const REVIEW := "general_services/review"

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	var review := state.station(REVIEW)
	for i in 3:
		review.add_desk()
	review.staff = review.desks
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.complaint_letter_timer = 1e6
	state.dispute_timer = 1e6
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _case_at_review() -> CaseFile:
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = case_file.route.find(REVIEW)
	return case_file


func _stand_at(desk: int) -> void:
	state.player.position = layout.desk_position(REVIEW, desk)


func _fill_income(per_second: float, seconds: int) -> void:
	var tracker := state.income
	var earned := 0.0
	tracker.advance(IncomeTracker.SAMPLE_SECONDS, earned)
	for i in seconds:
		earned += per_second
		tracker.advance(IncomeTracker.SAMPLE_SECONDS, earned)


func test_income_tracker_starts_empty_and_averages_samples() -> void:
	var tracker := IncomeTracker.new()
	assert_eq(tracker.per_minute(), 0.0)
	tracker.advance(0.5, 10.0)
	assert_eq(tracker.per_minute(), 0.0)
	tracker.advance(0.5, 10.0)
	assert_eq(tracker.per_minute(), 0.0)
	tracker.advance(1.0, 12.0)
	assert_almost_eq(tracker.per_minute(), 120.0, 0.001)
	tracker.advance(1.0, 16.0)
	assert_almost_eq(tracker.per_minute(), 180.0, 0.001)


func test_income_tracker_keeps_window_and_ignores_spending() -> void:
	var tracker := IncomeTracker.new()
	tracker.advance(1.0, 0.0)
	for i in IncomeTracker.WINDOW + 10:
		tracker.advance(1.0, float(i + 1))
	assert_eq(tracker.samples.size(), IncomeTracker.WINDOW)
	assert_almost_eq(tracker.per_minute(), 60.0, 0.001)
	tracker.advance(1.0, 0.0)
	assert_eq(tracker.samples.back(), 0.0)


func test_income_tracker_excludes_windfalls() -> void:
	var tracker := IncomeTracker.new()
	tracker.exclude(500.0)
	tracker.advance(1.0, 0.0)
	tracker.advance(1.0, 2.0)
	tracker.exclude(1000.0)
	tracker.advance(1.0, 1004.0)
	assert_eq(tracker.samples.size(), 2)
	assert_eq(tracker.samples[0], 2.0)
	assert_eq(tracker.samples[1], 2.0)
	tracker.exclude(-50.0)
	tracker.advance(1.0, 1006.0)
	assert_eq(tracker.samples.back(), 2.0)
	assert_almost_eq(tracker.per_minute(), 120.0, 0.001)


func test_offline_earnings_do_not_inflate_the_income_per_minute() -> void:
	for key in state.stations:
		if not state.stations[key].machine:
			state.stations[key].staff = maxi(1, state.stations[key].staff)
	for role in Runner.ROLES:
		state.add_runner(role)
	assert_gt(OfflineCalculator.earnings_per_second(state), 0.0)
	_fill_income(2.0, 5)
	state.money_earned = 10.0
	var before := state.income.per_minute()
	state.saved_at = 1000
	var result := OfflineCalculator.apply(state, 1000 + 3600)
	assert_gt(float(result.money), 0.0)
	state.earn(2.0)
	state.income.advance(IncomeTracker.SAMPLE_SECONDS, state.money_earned)
	assert_almost_eq(state.income.per_minute(), before, 0.001)
	var bonus := OfflineCalculator.double_up(state, result)
	assert_gt(bonus, 0.0)
	state.earn(2.0)
	state.income.advance(IncomeTracker.SAMPLE_SECONDS, state.money_earned)
	assert_almost_eq(state.income.per_minute(), before, 0.001)


func test_windfall_counts_as_earned_money() -> void:
	var money := state.money
	var earned := state.money_earned
	state.earn_windfall(250.0)
	assert_eq(state.money, money + 250.0)
	assert_eq(state.money_earned, earned + 250.0)


func test_simulation_feeds_income_tracker() -> void:
	_run(1.2, 0.1)
	state.earn(50.0)
	_run(1.5, 0.1)
	assert_gt(state.income.per_minute(), 0.0)


func test_bonus_cost_uses_minimum_income_and_scales_with_income() -> void:
	assert_eq(Formulas.sick_bonus_cost(state, 0), 0.0)
	for tier in range(1, GameConfig.sick_bonus_tiers() + 1):
		assert_eq(Formulas.sick_bonus_cost(state, tier), ceilf(GameConfig.SICK_BONUS_MIN_INCOME * GameConfig.SICK_BONUS_MINUTES[tier]))
	_fill_income(10.0, 5)
	assert_almost_eq(state.income.per_minute(), 600.0, 0.001)
	assert_eq(Formulas.sick_bonus_cost(state, 1), ceilf(600.0 * GameConfig.SICK_BONUS_MINUTES[1]))
	assert_eq(Formulas.sick_bonus_cost(state, 3), ceilf(600.0 * GameConfig.SICK_BONUS_MINUTES[3]))
	assert_eq(Formulas.sick_bonus_cost(state, 99), Formulas.sick_bonus_cost(state, GameConfig.sick_bonus_tiers()))
	assert_lt(Formulas.sick_bonus_cost(state, 1), Formulas.sick_bonus_cost(state, 2))
	assert_lt(Formulas.sick_bonus_cost(state, 2), Formulas.sick_bonus_cost(state, 3))


func test_recovery_speed_grows_with_tier_and_is_clamped() -> void:
	assert_eq(Formulas.sick_recovery_speed(0), 1.0)
	assert_eq(Formulas.sick_recovery_speed(-3), 1.0)
	for tier in range(1, GameConfig.sick_bonus_tiers() + 1):
		assert_gt(Formulas.sick_recovery_speed(tier), Formulas.sick_recovery_speed(tier - 1))
	assert_eq(Formulas.sick_recovery_speed(99), GameConfig.SICK_BONUS_SPEED[GameConfig.sick_bonus_tiers()])
	assert_eq(GameConfig.SICK_BONUS_SPEED.size(), GameConfig.SICK_BONUS_MINUTES.size())


func test_sick_time_left_counts_down_and_shrinks_with_bonus() -> void:
	var mood := DeskMood.new()
	assert_eq(Formulas.sick_time_left(state, mood), 0.0)
	mood.rest(DeskMood.SICK)
	assert_eq(Formulas.sick_time_left(state, mood), GameConfig.SICK_SECONDS)
	mood.resting = 40.0
	assert_eq(Formulas.sick_time_left(state, mood), GameConfig.SICK_SECONDS - 40.0)
	mood.bonus = 2
	assert_almost_eq(Formulas.sick_time_left(state, mood), (GameConfig.SICK_SECONDS - 40.0) / GameConfig.SICK_BONUS_SPEED[2], 0.001)
	mood.resting = GameConfig.SICK_SECONDS + 5.0
	assert_eq(Formulas.sick_time_left(state, mood), 0.0)


func test_bonus_is_saved_clamped_and_reset() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.SICK)
	mood.bonus = 2
	assert_eq(DeskMood.from_dict(mood.to_dict()).bonus, 2)
	var data := mood.to_dict()
	data.bonus = 99
	assert_eq(DeskMood.from_dict(data).bonus, GameConfig.sick_bonus_tiers())
	data.bonus = -4
	assert_eq(DeskMood.from_dict(data).bonus, 0)
	data.erase("bonus")
	assert_eq(DeskMood.from_dict(data).bonus, 0)
	data.bonus = 2
	data.state = DeskMood.ASLEEP
	assert_eq(DeskMood.from_dict(data).bonus, 0)
	mood.wake(10.0)
	assert_eq(mood.bonus, 0)
	mood.bonus = 1
	mood.rest(DeskMood.SICK)
	assert_eq(mood.bonus, 0)


func test_sick_desk_near_finds_only_sick_desks_close_by() -> void:
	var review := state.station(REVIEW)
	assert_true(sim.sick_desk_near(layout.desk_position(REVIEW, 1)).is_empty())
	review.moods[1].rest(DeskMood.SICK)
	assert_eq(sim.sick_desk_near(layout.desk_position(REVIEW, 1)), [REVIEW, 1])
	assert_true(sim.sick_desk_near(Vector2(50, 50)).is_empty())
	review.staff = 1
	assert_true(sim.sick_desk_near(layout.desk_position(REVIEW, 1)).is_empty())


func test_leave_bonus_requires_presence_money_and_sickness() -> void:
	var review := state.station(REVIEW)
	state.money = 1e6
	assert_false(sim.can_leave_bonus(REVIEW, 0, 1))
	review.moods[0].rest(DeskMood.SICK)
	assert_false(sim.can_leave_bonus(REVIEW, 0, 1))
	_stand_at(0)
	assert_true(sim.can_leave_bonus(REVIEW, 0, 1))
	assert_false(sim.can_leave_bonus(REVIEW, 0, 0))
	assert_false(sim.can_leave_bonus(REVIEW, 0, GameConfig.sick_bonus_tiers() + 1))
	assert_false(sim.can_leave_bonus("nope/none", 0, 1))
	assert_false(sim.can_leave_bonus(REVIEW, -1, 1))
	assert_false(sim.can_leave_bonus(REVIEW, 99, 1))
	assert_false(sim.can_leave_bonus("general_services/signature", 0, 1))
	state.money = 0.0
	assert_false(sim.can_leave_bonus(REVIEW, 0, 1))
	assert_false(sim.leave_bonus(REVIEW, 0, 1))
	assert_eq(review.moods[0].bonus, 0)


func test_leave_bonus_spends_money_and_allows_only_upgrades() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	_stand_at(0)
	state.money = 1e6
	watch_signals(sim)
	var cost := Formulas.sick_bonus_cost(state, 2)
	assert_eq(Formulas.sick_bonus_price(state, review.moods[0], 2), cost)
	assert_true(sim.leave_bonus(REVIEW, 0, 2))
	assert_almost_eq(state.money, 1e6 - cost, 0.01)
	assert_eq(review.moods[0].bonus, 2)
	assert_eq(state.bonuses_paid, 1)
	assert_signal_emitted_with_parameters(sim, "bonus_left", [REVIEW, 0, 2])
	assert_false(sim.leave_bonus(REVIEW, 0, 1))
	assert_false(sim.leave_bonus(REVIEW, 0, 2))
	var upgrade := Formulas.sick_bonus_cost(state, 3) - Formulas.sick_bonus_cost(state, 2)
	var before := state.money
	assert_true(sim.leave_bonus(REVIEW, 0, 3))
	assert_almost_eq(state.money, before - upgrade, 0.01)
	assert_eq(review.moods[0].bonus, 3)
	assert_eq(state.bonuses_paid, 2)


func test_upgrade_needs_only_the_difference() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	review.moods[0].bonus = 2
	_stand_at(0)
	var upgrade := Formulas.sick_bonus_cost(state, 3) - Formulas.sick_bonus_cost(state, 2)
	state.money = upgrade
	assert_lt(state.money, Formulas.sick_bonus_cost(state, 3))
	assert_true(sim.can_leave_bonus(REVIEW, 0, 3))
	assert_true(sim.leave_bonus(REVIEW, 0, 3))
	assert_almost_eq(state.money, 0.0, 0.01)


func test_bonus_price_is_difference_to_paid_tier_and_never_negative() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.SICK)
	for tier in range(0, GameConfig.sick_bonus_tiers() + 1):
		assert_eq(Formulas.sick_bonus_price(state, mood, tier), Formulas.sick_bonus_cost(state, tier))
	mood.bonus = 2
	assert_eq(Formulas.sick_bonus_price(state, mood, 3), Formulas.sick_bonus_cost(state, 3) - Formulas.sick_bonus_cost(state, 2))
	assert_eq(Formulas.sick_bonus_price(state, mood, 2), 0.0)
	assert_eq(Formulas.sick_bonus_price(state, mood, 1), 0.0)


func test_bonus_stays_cheap_compared_to_income() -> void:
	for tier in range(1, GameConfig.sick_bonus_tiers() + 1):
		assert_lte(GameConfig.SICK_BONUS_MINUTES[tier], 1.0, "tier %d" % tier)


func test_time_left_with_tier_previews_each_option() -> void:
	var mood := DeskMood.new()
	assert_eq(Formulas.sick_time_left_with(state, mood, 3), 0.0)
	mood.rest(DeskMood.SICK)
	mood.resting = 20.0
	var remaining := GameConfig.SICK_SECONDS - 20.0
	assert_eq(Formulas.sick_time_left_with(state, mood, 0), remaining)
	for tier in range(1, GameConfig.sick_bonus_tiers() + 1):
		assert_almost_eq(Formulas.sick_time_left_with(state, mood, tier), remaining / GameConfig.SICK_BONUS_SPEED[tier], 0.001)
		assert_lt(Formulas.sick_time_left_with(state, mood, tier), Formulas.sick_time_left_with(state, mood, tier - 1))
	mood.bonus = 2
	assert_almost_eq(Formulas.sick_time_left_with(state, mood, 1), remaining / GameConfig.SICK_BONUS_SPEED[2], 0.001)
	assert_eq(Formulas.sick_time_left_with(state, mood, 2), Formulas.sick_time_left(state, mood))


func test_bonus_brings_colleague_back_sooner() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	review.moods[1].rest(DeskMood.SICK)
	review.moods[0].bonus = GameConfig.sick_bonus_tiers()
	var fast := GameConfig.SICK_SECONDS / Formulas.sick_recovery_speed(GameConfig.sick_bonus_tiers())
	_run(fast - 2.0, 0.5)
	assert_true(review.moods[0].is_sick())
	_run(3.0, 0.5)
	assert_false(review.moods[0].is_resting())
	assert_eq(review.moods[0].bonus, 0)
	assert_true(review.moods[1].is_sick())


func test_bonuses_paid_is_saved_and_clamped() -> void:
	state.bonuses_paid = 6
	assert_eq(GameState.from_dict(state.to_dict()).bonuses_paid, 6)
	var data := state.to_dict()
	data.bonuses_paid = -3
	assert_eq(GameState.from_dict(data).bonuses_paid, 0)
	data.erase("bonuses_paid")
	assert_eq(GameState.from_dict(data).bonuses_paid, 0)


func test_can_cover_needs_absent_staffed_desk_with_work() -> void:
	var review := state.station(REVIEW)
	assert_false(review.can_cover(0))
	review.moods[0].rest(DeskMood.SICK)
	assert_false(review.can_cover(0))
	review.inbox.append(_case_at_review())
	assert_true(review.can_cover(0))
	review.inbox.clear()
	review.jobs[0] = StationJob.new(_case_at_review(), 10.0)
	assert_true(review.can_cover(0))
	review.moods[0].rest(DeskMood.ASLEEP)
	assert_false(review.can_cover(0))
	review.moods[0].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	assert_true(review.can_cover(0))
	review.moods[0].rest(DeskMood.CHAT, 1)
	assert_true(review.can_cover(0))
	review.staff = 0
	assert_false(review.can_cover(0))
	var machine := state.station("general_services/signature")
	if machine != null and machine.machine:
		assert_false(machine.can_cover(0))


func test_player_works_at_desk_of_sick_colleague() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	review.jobs[0] = StationJob.new(_case_at_review(), 3.0)
	_run(1.0, 0.1)
	assert_eq(review.jobs[0].progress, 0.0)
	_stand_at(0)
	_run(1.0, 0.1)
	assert_gt(review.jobs[0].progress, 0.5)
	_run(3.0, 0.1)
	assert_null(review.jobs[0])
	assert_eq(review.outbox.size() + state.player.items.size(), 1)


func test_player_starts_new_job_at_empty_desk_of_absent_colleague() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.FETCH, 0)
	review.moods[0].resting = -1e6
	for desk in range(1, review.moods.size()):
		review.moods[desk].rest(DeskMood.SICK)
	review.inbox.append(_case_at_review())
	_stand_at(0)
	_run(0.3, 0.1)
	assert_not_null(review.jobs[0])
	assert_true(review.inbox.is_empty())


func test_work_desk_reports_progress() -> void:
	var review := state.station(REVIEW)
	assert_false(sim.work_desk(review, 0, 1.0))
	review.jobs[0] = StationJob.new(_case_at_review(), 2.0)
	assert_true(sim.work_desk(review, 0, 1.0))
	assert_true(sim.work_desk(review, 0, 1.5))
	assert_false(sim.work_desk(review, 0, 1.0))


func test_player_helps_an_awake_colleague_over_the_shoulder() -> void:
	var review := state.station(REVIEW)
	review.jobs[0] = StationJob.new(_case_at_review(), 100.0)
	_stand_at(0)
	_run(1.0, 0.1)
	assert_gt(review.jobs[0].progress, 1.0 + Formulas.work_power(state) * 0.5)


func test_any_toilet_guest_can_be_chased_out() -> void:
	var review := state.station(REVIEW)
	for desk in review.moods.size():
		review.moods[desk].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS + desk)
		review.moods[desk].resting = -1e6
	for desk in review.moods.size():
		state.player.position = layout.slot_point(GameConfig.KITCHEN_SLOTS + desk)
		_run(GameConfig.ENCOURAGE_TIME + 0.3, 0.1)
		assert_false(review.moods[desk].is_resting(), str(desk))
	assert_eq(state.wakes, review.moods.size())


func test_guidance_points_to_toilet_guest() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	state.player.position = layout.slot_point(GameConfig.KITCHEN_SLOTS) + Vector2(10, 0)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WAKE)
	assert_eq(task.point, layout.slot_point(GameConfig.KITCHEN_SLOTS))


func test_staff_reduces_sickness_disputes_kranz_and_complaints() -> void:
	var officials := maxi(1, state.staffed_officials())
	assert_almost_eq(Formulas.sick_interval(state, 0.0), GameConfig.SICK_MIN_PER_OFFICIAL / officials, 0.001)
	assert_almost_eq(Formulas.sick_interval(state, 1.0), GameConfig.SICK_MAX_PER_OFFICIAL / officials, 0.001)
	assert_almost_eq(Formulas.sick_interval(state, 7.0), GameConfig.SICK_MAX_PER_OFFICIAL / officials, 0.001)
	state.hr = 2
	assert_almost_eq(Formulas.sick_interval(state, 0.0), GameConfig.SICK_MIN_PER_OFFICIAL / officials * (1.0 + 2.0 * GameConfig.SICK_HR_RELIEF), 0.001)
	assert_eq(Formulas.kranz_interval(state, 0.0), GameConfig.KRANZ_MIN_INTERVAL)
	assert_eq(Formulas.kranz_interval(state, 1.0), GameConfig.KRANZ_MAX_INTERVAL)
	state.coffee_interns.append(CoffeeIntern.new())
	assert_almost_eq(Formulas.kranz_interval(state, 0.0), GameConfig.KRANZ_MIN_INTERVAL * (1.0 + GameConfig.KRANZ_COFFEE_RELIEF), 0.001)
	assert_almost_eq(Formulas.complaint_interval(0.0), GameConfig.COMPLAINT_INTERVAL * 0.7, 0.001)
	assert_almost_eq(Formulas.complaint_interval(1.0), GameConfig.COMPLAINT_INTERVAL * 1.3, 0.001)
	assert_almost_eq(Formulas.complaint_interval(0.5), GameConfig.COMPLAINT_INTERVAL, 0.001)
	assert_eq(Formulas.total_supervisors(state), 0)
	state.department("general_services").supervisors = 2
	assert_eq(Formulas.total_supervisors(state), 2)
	assert_almost_eq(Formulas.dispute_interval(state, 0.0), GameConfig.DISPUTE_MIN_INTERVAL * (1.0 + 2.0 * GameConfig.DISPUTE_SUPERVISOR_RELIEF), 0.001)


func test_early_game_trouble_without_sickness_spiral() -> void:
	assert_lte(GameConfig.SICK_MIN_STAFF, 3)
	assert_lte(GameConfig.SICK_SECONDS, 150.0)
	assert_gte(GameConfig.SICK_MIN_PER_OFFICIAL / GameConfig.SICK_MIN_STAFF, 300.0)
	assert_lt(GameConfig.DISPUTE_MIN_CASES, 40)
	assert_lt(GameConfig.DISPUTE_FIRST_SECONDS, 240.0)
	assert_lt(GameConfig.KRANZ_FIRST_SECONDS, 120.0)


func test_sick_timer_respects_phone_clerks() -> void:
	state.hr = 2
	state.sick_timer = 0.0
	sim.tick(0.05)
	assert_gte(state.sick_timer, GameConfig.SICK_MIN_PER_OFFICIAL / maxi(1, state.staffed_officials()) * (1.0 + 2.0 * GameConfig.SICK_HR_RELIEF) - 0.1)


func test_kranz_and_complaint_timers_use_relief() -> void:
	for i in GameConfig.MAX_COFFEE_INTERNS:
		state.coffee_interns.append(CoffeeIntern.new())
	sim.end_kranz(false)
	assert_gte(state.kranz_timer, GameConfig.KRANZ_MIN_INTERVAL * (1.0 + GameConfig.MAX_COFFEE_INTERNS * GameConfig.KRANZ_COFFEE_RELIEF) - 0.01)
	state.set_upgrade("complaint_security", 1)
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.complaint_timer = 0.0
	sim.tick(0.05)
	assert_between(state.complaint_timer, GameConfig.COMPLAINT_INTERVAL * 0.7 - 0.1, GameConfig.COMPLAINT_INTERVAL * 1.3)


func test_clock_format() -> void:
	assert_eq(NumberFormat.clock(0.0), "0:00")
	assert_eq(NumberFormat.clock(-5.0), "0:00")
	assert_eq(NumberFormat.clock(9.2), "0:10")
	assert_eq(NumberFormat.clock(65.0), "1:05")
	assert_eq(NumberFormat.clock(600.0), "10:00")


func test_bonus_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["FMT_SICK_RETURN", "FMT_SICK_BONUS_TITLE", "SICK_BONUS_TEXT", "FMT_SICK_BONUS_BUTTON", "FLOAT_SICK_BONUS"]
	for tier in range(1, GameConfig.sick_bonus_tiers() + 1):
		keys.append("SICK_BONUS_TIER_%d" % tier)
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)
