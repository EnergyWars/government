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
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func test_sick_state_basics() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.SICK)
	assert_true(mood.is_sick())
	assert_true(mood.is_absent())
	assert_false(mood.is_away())
	assert_false(mood.needs_help())
	assert_eq(mood.slot, -1)
	assert_eq(DeskMood.from_dict(mood.to_dict()).state, DeskMood.SICK)


func test_sick_counts_as_resting_for_station() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	assert_eq(review.resting_count(), 1)
	assert_false(review.is_working(0))
	assert_eq(state.sick_count(), 1)


func test_nobody_reports_sick_with_too_few_staff() -> void:
	state.station(REVIEW).staff = GameConfig.SICK_MIN_STAFF - 1
	assert_false(sim.report_sick())
	assert_eq(state.sick_count(), 0)


func test_report_sick_picks_working_employee() -> void:
	watch_signals(sim)
	assert_true(sim.report_sick())
	assert_eq(state.sick_count(), 1)
	assert_signal_emitted(sim, "employee_dozed")


func test_report_sick_fails_when_everyone_rests() -> void:
	for mood in state.station(REVIEW).moods:
		mood.rest(DeskMood.ASLEEP)
	assert_false(sim.report_sick())


func test_sick_timer_triggers_report() -> void:
	state.sick_timer = 0.0
	_run(0.1)
	assert_eq(state.sick_count(), 1)
	assert_gte(state.sick_timer, GameConfig.SICK_MIN_INTERVAL)


func test_sick_returns_on_its_own_after_long_time() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	_run(GameConfig.SICK_SECONDS - 5.0, 1.0)
	assert_true(review.moods[0].is_sick())
	_run(7.0, 1.0)
	assert_false(review.moods[0].is_resting())


func test_player_calls_sick_employee_at_phone() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	state.player.position = layout.phone_point()
	watch_signals(sim)
	_run(GameConfig.CALL_TIME + 0.5, 0.1)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.calls_made, 1)
	assert_eq(state.wakes, 1)
	assert_signal_emitted_with_parameters(sim, "sick_called", [true, REVIEW, 0])


func test_call_needs_presence_and_resets_progress() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	state.player.position = layout.phone_point()
	_run(0.5, 0.1)
	assert_gt(state.player.call_progress, 0.0)
	state.player.position = Vector2(50, 50)
	_run(0.1)
	assert_eq(state.player.call_progress, 0.0)
	_run(5.0, 0.5)
	assert_true(review.moods[0].is_sick())


func test_call_picks_longest_sick_first() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	review.moods[1].rest(DeskMood.SICK)
	review.moods[1].resting = 50.0
	assert_true(sim.call_in_sick(false))
	assert_true(review.moods[0].is_sick())
	assert_false(review.moods[1].is_resting())
	assert_eq(state.wakes, 0)
	assert_false(sim.call_in_sick(false) and sim.call_in_sick(false))


func test_hr_clerks_call_automatically() -> void:
	state.hr = 2
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SICK)
	_run(GameConfig.HR_CALL_SECONDS / 2.0 + 1.0, 0.25)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.wakes, 0)


func test_hr_timer_resets_without_sick_people() -> void:
	state.hr = 1
	state.hr_timer = 5.0
	_run(0.1)
	assert_eq(state.hr_timer, 0.0)


func test_hire_hr_costs_money_and_has_limit() -> void:
	var actions := GameActions.new(state, sim)
	state.money = 1e9
	var first := Formulas.hr_cost(state)
	assert_true(actions.hire_hr())
	assert_eq(state.hr, 1)
	assert_gt(Formulas.hr_cost(state), first)
	assert_eq(state.staff_hired, 1)
	for i in GameConfig.MAX_HR:
		actions.hire_hr()
	assert_eq(state.hr, GameConfig.MAX_HR)
	assert_false(actions.can_hire_hr())
	state.hr = 0
	state.money = 0.0
	assert_false(actions.hire_hr())


func test_sick_and_hr_are_saved_and_clamped() -> void:
	state.hr = 3
	state.calls_made = 7
	state.sick_timer = 55.0
	state.station(REVIEW).moods[0].rest(DeskMood.SICK)
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.hr, 3)
	assert_eq(loaded.calls_made, 7)
	assert_almost_eq(loaded.sick_timer, 55.0, 0.001)
	assert_true(loaded.station(REVIEW).moods[0].is_sick())
	var data := state.to_dict()
	data.hr = 99
	data.sick_timer = 1e9
	data.calls_made = -2
	loaded = GameState.from_dict(data)
	assert_eq(loaded.hr, GameConfig.MAX_HR)
	assert_eq(loaded.sick_timer, GameConfig.SICK_MAX_INTERVAL)
	assert_eq(loaded.calls_made, 0)


func test_guidance_leads_to_phone() -> void:
	state.station(REVIEW).moods[0].rest(DeskMood.SICK)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.CALL)
	assert_eq(task.point, layout.phone_point())


func test_complaints_drain_reputation() -> void:
	state.reputation = 10.0
	state.complaints = 4
	_run(10.0, 0.5)
	assert_almost_eq(state.reputation, 10.0 - 4 * GameConfig.COMPLAINT_DRAIN * 10.0, 0.01)
	assert_almost_eq(Formulas.complaint_malus_per_minute(state), 4 * GameConfig.COMPLAINT_DRAIN * 60.0, 0.0001)
	state.complaints = 0
	var before := state.reputation
	_run(5.0, 0.5)
	assert_eq(state.reputation, before)


func test_loo_state_uses_separate_slot_range() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS + 1)
	assert_true(mood.is_away())
	assert_true(mood.needs_help())
	assert_eq(mood.slot, GameConfig.KITCHEN_SLOTS + 1)
	assert_eq(state.free_loo_slot(), GameConfig.KITCHEN_SLOTS)
	state.station(REVIEW).moods[0].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	assert_eq(state.free_loo_slot(), GameConfig.KITCHEN_SLOTS + 1)
	assert_eq(state.free_kitchen_slot(), 0)


func test_loo_slot_points() -> void:
	for i in GameConfig.LOO_SLOTS:
		assert_true(layout.toilets.has_point(layout.slot_point(GameConfig.KITCHEN_SLOTS + i)))
	assert_eq(layout.slot_point(3), layout.kitchen_slot(3))
	assert_eq(layout.slot_point(999), layout.slot_point(GameConfig.KITCHEN_SLOTS + GameConfig.LOO_SLOTS - 1))
	assert_true(layout.toilets.has_point(layout.phone_point()))
	assert_true(layout.toilets.has_point(layout.loo_origin() + Vector2(256, 98)))


func test_toilets_are_separate_from_kitchen() -> void:
	assert_false(layout.toilets.intersects(layout.kitchen))
	assert_false(layout.toilets.intersects(layout.hall))
	assert_eq(layout.toilets.position.y, layout.kitchen.position.y)
	assert_eq(layout.toilets.end.x, layout.kitchen.end.x + layout.toilets.size.x + WorldLayout.GAP)
	assert_eq(layout.toilets_header().size.y, WorldLayout.HEADER)
	for slot in layout.rooms:
		assert_false(layout.toilets.intersects(layout.rooms[slot]), slot)
	assert_true(Rect2(Vector2.ZERO, layout.size).encloses(layout.toilets))


func test_wake_remembers_slot_left() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.CHAT, 4)
	mood.wake(10.0)
	assert_eq(mood.left_slot, 4)
	assert_eq(mood.slot, -1)
	mood.rest(DeskMood.ASLEEP)
	mood.wake(10.0)
	assert_eq(mood.left_slot, -1)


func test_loo_guest_is_encouraged_by_player_standing_nearby() -> void:
	var review := state.station(REVIEW)
	var slot := GameConfig.KITCHEN_SLOTS + 2
	review.moods[0].rest(DeskMood.LOO, slot)
	state.player.position = layout.slot_point(slot)
	_run(GameConfig.WAKE_TIME + 0.3, 0.1)
	assert_true(review.moods[0].is_resting())
	_run(GameConfig.ENCOURAGE_TIME, 0.1)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.wakes, 1)
	assert_eq(Formulas.wake_time(DeskMood.LOO), GameConfig.ENCOURAGE_TIME)
	assert_eq(Formulas.wake_time(DeskMood.CHAT), GameConfig.WAKE_TIME)


func test_loo_guest_stays_without_help_and_wake_service_shortens_it() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	assert_eq(Formulas.rest_limit(state, DeskMood.LOO), GameConfig.LOO_SECONDS)
	_run(60.0, 1.0)
	assert_true(review.moods[0].is_resting())
	state.research["wake_service"] = 5
	assert_eq(Formulas.rest_limit(state, DeskMood.LOO), GameConfig.WAKE_SERVICE_DELAYS[5])


func test_doze_weights_still_sum_to_one_with_loo() -> void:
	state.research["kitchen"] = 3
	var total := 0.0
	var weights := Formulas.doze_weights(state)
	for key in weights:
		total += float(weights[key])
	assert_almost_eq(total, 1.0, 0.0001)
	assert_true(weights.has("loo"))


func test_doze_can_send_employees_to_loo_and_falls_back_when_full() -> void:
	var review := state.station(REVIEW)
	var seen := false
	for i in 400:
		review.moods[0].wake(10.0)
		sim.doze_off(review, 0)
		if review.moods[0].state == DeskMood.LOO:
			seen = true
			assert_gte(review.moods[0].slot, GameConfig.KITCHEN_SLOTS)
	assert_true(seen)
	for i in GameConfig.LOO_SLOTS:
		review.add_desk()
	review.staff = review.desks
	var base := review.moods.size() - GameConfig.LOO_SLOTS
	for i in GameConfig.LOO_SLOTS:
		review.moods[base + i].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS + i)
	for i in 100:
		review.moods[0].wake(10.0)
		sim.doze_off(review, 0)
		assert_ne(review.moods[0].state, DeskMood.LOO)


func test_loo_slots_are_repaired_on_load() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	review.moods[1].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	review.moods[2].rest(DeskMood.CHAT, 2)
	var data := state.to_dict()
	data.stations[REVIEW].moods[2].slot = GameConfig.KITCHEN_SLOTS + 1
	var loaded := GameState.from_dict(data)
	var moods := loaded.station(REVIEW).moods
	assert_ne(moods[0].slot, moods[1].slot)
	assert_gte(moods[0].slot, GameConfig.KITCHEN_SLOTS)
	assert_gte(moods[1].slot, GameConfig.KITCHEN_SLOTS)
	assert_lt(moods[2].slot, GameConfig.KITCHEN_SLOTS)
	assert_true(moods[2].is_away())


func test_kranz_participants_sit_at_table_slots() -> void:
	state.kranz_timer = 0.0
	_run(0.1)
	assert_true(state.kranz)
	for mood in state.station(REVIEW).moods:
		if mood.state == DeskMood.CHAT:
			assert_gte(mood.slot, GameConfig.KITCHEN_TABLE_SLOT)


func test_slow_and_chat_guests_gather_at_coffee_machine_cluster() -> void:
	var machine := layout.coffee_machine_point()
	for slot in GameConfig.KITCHEN_TABLE_SLOT:
		assert_lt(layout.kitchen_slot(slot).distance_to(machine), 200.0, str(slot))
	var table := layout.kranz_point()
	for slot in range(GameConfig.KITCHEN_TABLE_SLOT, GameConfig.KITCHEN_SLOTS):
		assert_lt(layout.kitchen_slot(slot).distance_to(table), 200.0, str(slot))
