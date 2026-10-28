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
	state.station(REVIEW).staff = 1
	state.player.position = Vector2(50, 50)


func _case() -> CaseFile:
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func _busy_review() -> Station:
	var review := state.station(REVIEW)
	review.inbox.append(_case())
	return review


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func test_mood_defaults_and_transitions() -> void:
	var mood := DeskMood.new()
	assert_eq(mood.state, DeskMood.AWAKE)
	assert_false(mood.is_resting())
	mood.wake_progress = 0.4
	mood.rest(DeskMood.ASLEEP)
	assert_true(mood.is_resting())
	assert_eq(mood.wake_progress, 0.0)
	mood.resting = 5.0
	mood.wake(42.0)
	assert_false(mood.is_resting())
	assert_eq(mood.resting, 0.0)
	assert_eq(mood.alert, 42.0)


func test_mood_serialization_round_trip_and_validation() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.COFFEE)
	mood.resting = 12.0
	mood.alert = 33.0
	var loaded := DeskMood.from_dict(mood.to_dict())
	assert_eq(loaded.state, DeskMood.COFFEE)
	assert_eq(loaded.resting, 12.0)
	assert_eq(loaded.alert, 33.0)
	assert_eq(DeskMood.from_dict("garbage").state, DeskMood.AWAKE)
	assert_eq(DeskMood.from_dict(null).alert, GameConfig.BASE_ALERT_SECONDS)
	var broken := DeskMood.from_dict({"state": "dancing", "alert": 1e9, "resting": -5.0})
	assert_eq(broken.state, DeskMood.AWAKE)
	assert_eq(broken.alert, GameConfig.MAX_ALERT_SECONDS)
	assert_eq(broken.resting, 0.0)


func test_station_moods_follow_desks() -> void:
	var station := Station.new(REVIEW)
	assert_eq(station.moods.size(), 1)
	station.add_desk()
	station.add_desk()
	assert_eq(station.moods.size(), station.jobs.size())
	assert_eq(station.moods.size(), 3)


func test_station_working_and_resting_counts() -> void:
	var station := Station.new(REVIEW)
	assert_false(station.is_working(0))
	station.staff = 1
	assert_true(station.is_working(0))
	assert_eq(station.resting_count(), 0)
	station.moods[0].rest(DeskMood.ASLEEP)
	assert_false(station.is_working(0))
	assert_eq(station.resting_count(), 1)
	station.staff = 0
	assert_eq(station.resting_count(), 0)


func test_station_save_restores_moods_and_old_saves_default() -> void:
	var station := Station.new(REVIEW)
	station.add_desk()
	station.staff = 2
	station.moods[1].rest(DeskMood.ASLEEP)
	var loaded := Station.from_dict(station.to_dict())
	assert_eq(loaded.moods.size(), 2)
	assert_eq(loaded.moods[1].state, DeskMood.ASLEEP)
	var data := station.to_dict()
	data.erase("moods")
	var legacy := Station.from_dict(data)
	assert_eq(legacy.moods.size(), 2)
	assert_false(legacy.moods[1].is_resting())


func test_game_state_saves_wake_counter() -> void:
	state.wakes = 7
	assert_eq(GameState.from_dict(state.to_dict()).wakes, 7)
	var data := state.to_dict()
	data.erase("wakes")
	assert_eq(GameState.from_dict(data).wakes, 0)
	data["wakes"] = -4
	assert_eq(GameState.from_dict(data).wakes, 0)


func test_coffee_extends_alert_duration() -> void:
	var base := Formulas.alert_duration(state)
	assert_eq(base, GameConfig.BASE_ALERT_SECONDS)
	state.set_upgrade("coffee", 70)
	assert_almost_eq(Formulas.alert_duration(state), base * Formulas.track_value("coffee", 70), 0.001)
	assert_gt(Formulas.alert_duration(state), base)
	state.set_upgrade("coffee", int(GameConfig.upgrade("coffee").max))
	assert_gt(Formulas.alert_duration(state), base * 3.0)


func test_rolled_alert_stays_within_variance() -> void:
	var duration := Formulas.alert_duration(state)
	for i in 50:
		var rolled := Formulas.roll_alert(state)
		assert_gte(rolled, duration * (1.0 - GameConfig.ALERT_VARIANCE) - 0.001)
		assert_lte(rolled, duration * (1.0 + GameConfig.ALERT_VARIANCE) + 0.001)


func test_lead_focus_slows_drowsiness() -> void:
	var station := state.station(REVIEW)
	assert_eq(Formulas.drowsiness_rate(state, station), 1.0)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_focus", 2, "general_services")
	assert_almost_eq(Formulas.drowsiness_rate(state, station), Formulas.track_value("lead_focus", 2), 0.0001)


func test_shared_stations_use_the_lead_of_their_room() -> void:
	state.unlock_department("tax_services")
	var reception := state.station(GameConfig.RECEPTION)
	state.set_upgrade("team_lead", 1, "tax_services")
	state.set_upgrade("lead_focus", 5, "tax_services")
	assert_eq(Formulas.drowsiness_rate(state, reception), 1.0)
	state.set_upgrade("team_lead", 1, GameConfig.HALL_INTAKE)
	state.set_upgrade("lead_focus", 1, GameConfig.HALL_INTAKE)
	assert_almost_eq(Formulas.drowsiness_rate(state, reception), Formulas.track_value("lead_focus", 1), 0.0001)
	assert_eq(Formulas.drowsiness_rate(state, state.station(GameConfig.COUNTER)), 1.0)
	state.set_upgrade("team_lead", 1, GameConfig.HALL_PICKUP)
	state.set_upgrade("lead_focus", 3, GameConfig.HALL_PICKUP)
	assert_almost_eq(Formulas.drowsiness_rate(state, state.station(GameConfig.COUNTER)), Formulas.track_value("lead_focus", 3), 0.0001)


func test_rest_limits_follow_wake_service() -> void:
	assert_eq(Formulas.rest_limit(state, DeskMood.ASLEEP), INF)
	assert_eq(Formulas.rest_limit(state, DeskMood.COFFEE), GameConfig.COFFEE_BREAK_SECONDS)
	for level in range(1, int(GameConfig.upgrade("wake_service").max) + 1):
		state.set_upgrade("wake_service", level)
		var delay := Formulas.track_value("wake_service", level)
		assert_eq(Formulas.rest_limit(state, DeskMood.ASLEEP), delay, str(level))
		assert_eq(Formulas.rest_limit(state, DeskMood.COFFEE), minf(GameConfig.COFFEE_BREAK_SECONDS, delay), str(level))


func test_wake_service_track_matches_upgrades() -> void:
	assert_eq(GameConfig.spot_room(GameConfig.upgrade_spot("coffee")), GameConfig.ROOM_KITCHEN)
	assert_eq(GameConfig.spot_room(GameConfig.upgrade_spot("wake_service")), GameConfig.ROOM_TOILETS)
	assert_lt(Formulas.track_value("wake_service", 0), 0.0)
	assert_gt(Formulas.track_value("wake_service", 1), 0.0)
	for level in range(2, int(GameConfig.upgrade("wake_service").max) + 1):
		assert_lt(Formulas.track_value("wake_service", level), Formulas.track_value("wake_service", level - 1), str(level))


func test_employee_dozes_off_while_working() -> void:
	var review := _busy_review()
	review.moods[0].alert = 1.0
	watch_signals(sim)
	_run(1.5)
	assert_true(review.moods[0].is_resting())
	assert_signal_emitted(sim, "employee_dozed")


func test_idle_employee_does_not_tire() -> void:
	var review := state.station(REVIEW)
	review.moods[0].alert = 5.0
	_run(10.0)
	assert_eq(review.moods[0].alert, 5.0)
	assert_false(review.moods[0].is_resting())


func test_unstaffed_desks_and_machines_never_doze() -> void:
	var review := _busy_review()
	review.staff = 0
	review.moods[0].alert = 0.1
	var signature := state.station("general_services/signature")
	signature.inbox.append(_case())
	signature.moods[0].alert = 0.1
	_run(2.0)
	assert_false(review.moods[0].is_resting())
	assert_false(signature.moods[0].is_resting())
	assert_false(sim.doze_off(signature, 0))
	assert_false(sim.doze_off(review, 0))


func test_dozing_chooses_both_kinds() -> void:
	var kinds := {}
	for i in 40:
		var review := state.station(REVIEW)
		review.moods[0].wake(10.0)
		sim.doze_off(review, 0)
		kinds[review.moods[0].state] = true
	assert_true(kinds.has(DeskMood.ASLEEP))
	assert_true(kinds.has(DeskMood.COFFEE))


func test_resting_desk_pauses_its_job() -> void:
	var review := _busy_review()
	_run(0.2)
	var job := review.jobs[0]
	assert_not_null(job)
	review.moods[0].rest(DeskMood.ASLEEP)
	var before := job.progress
	_run(2.0)
	assert_eq(job.progress, before)
	review.moods[0].wake(50.0)
	_run(0.5)
	assert_gt(job.progress, before)


func test_resting_desk_does_not_start_new_jobs() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.ASLEEP)
	review.inbox.append(_case())
	_run(1.0)
	assert_null(review.jobs[0])
	assert_eq(review.inbox.size(), 1)


func test_sleepers_stay_asleep_without_wake_service() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.ASLEEP)
	_run(120.0, 1.0)
	assert_eq(review.moods[0].state, DeskMood.ASLEEP)


func test_coffee_break_ends_on_its_own() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.COFFEE)
	_run(GameConfig.COFFEE_BREAK_SECONDS - 5.0, 1.0)
	assert_true(review.moods[0].is_resting())
	_run(10.0, 1.0)
	assert_false(review.moods[0].is_resting())


func test_wake_service_wakes_sleepers_by_themselves() -> void:
	state.set_upgrade("wake_service", 25)
	var review := _busy_review()
	review.moods[0].rest(DeskMood.ASLEEP)
	watch_signals(sim)
	_run(Formulas.rest_limit(state, DeskMood.ASLEEP) + 2.0, 0.5)
	assert_false(review.moods[0].is_resting())
	assert_signal_emitted_with_parameters(sim, "employee_woke", [REVIEW, 0, false])
	assert_eq(state.wakes, 0)


func test_player_wakes_sleeper_by_standing_close() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.ASLEEP)
	state.player.position = layout.desk_position(REVIEW, 0)
	watch_signals(sim)
	_run(GameConfig.WAKE_TIME / 2.0)
	assert_true(review.moods[0].is_resting())
	assert_gt(review.moods[0].wake_progress, 0.0)
	_run(GameConfig.WAKE_TIME)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.wakes, 1)
	assert_signal_emitted_with_parameters(sim, "employee_woke", [REVIEW, 0, true])
	assert_gt(review.moods[0].alert, 0.0)


func test_wake_progress_resets_when_player_leaves() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.COFFEE)
	state.player.position = layout.desk_position(REVIEW, 0)
	_run(GameConfig.WAKE_TIME / 2.0)
	assert_gt(review.moods[0].wake_progress, 0.0)
	state.player.position = Vector2(50, 50)
	_run(0.2)
	assert_eq(review.moods[0].wake_progress, 0.0)
	assert_true(review.moods[0].is_resting())


func test_wake_up_guards() -> void:
	var review := state.station(REVIEW)
	assert_false(sim.wake_up(review, 0, true))
	assert_eq(state.wakes, 0)
	assert_true(sim.doze_off(review, 0))
	assert_false(sim.doze_off(review, 0))
	assert_true(sim.wake_up(review, 0, false))
	assert_eq(state.wakes, 0)


func test_guidance_points_to_resting_desk() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.ASLEEP)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WAKE)
	assert_eq(task.key, REVIEW)
	assert_eq(task.point, layout.desk_position(REVIEW, 0))


func test_resting_count_per_department() -> void:
	var dept := state.department("general_services")
	assert_eq(Formulas.resting_count(state, dept), 0)
	state.station(REVIEW).moods[0].rest(DeskMood.ASLEEP)
	assert_eq(Formulas.resting_count(state, dept), 1)


func test_player_wake_only_counts_staffed_resting_desks() -> void:
	var review := state.station(REVIEW)
	review.add_desk()
	review.moods[1].rest(DeskMood.ASLEEP)
	state.player.position = layout.desk_position(REVIEW, 1)
	_run(2.0)
	assert_true(review.moods[1].is_resting())
	assert_eq(state.wakes, 0)


func test_mood_kitchen_states() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.CHAT, 3)
	assert_true(mood.is_away())
	assert_true(mood.needs_help())
	assert_eq(mood.slot, 3)
	mood.rest(DeskMood.FETCH, 4)
	assert_true(mood.is_away())
	assert_false(mood.needs_help())
	assert_eq(mood.slot, 4)
	mood.rest(DeskMood.ASLEEP, 5)
	assert_false(mood.is_away())
	assert_true(mood.needs_help())
	assert_eq(mood.slot, -1)
	mood.rest(DeskMood.COFFEE)
	assert_true(mood.needs_help())
	mood.rest(DeskMood.CHAT, 2)
	mood.wake(10.0)
	assert_eq(mood.slot, -1)
	assert_false(mood.needs_help())


func test_mood_slot_is_saved_and_validated() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.CHAT, 7)
	assert_eq(DeskMood.from_dict(mood.to_dict()).slot, 7)
	assert_eq(DeskMood.from_dict({"state": "chat", "slot": 999}).slot, GameConfig.KITCHEN_SLOTS - 1)
	assert_eq(DeskMood.from_dict({"state": "asleep", "slot": 4}).slot, -1)
	assert_eq(DeskMood.from_dict({"state": "fetch"}).slot, -1)


func test_fetching_employees_do_not_count_as_needing_help() -> void:
	var station := state.station(REVIEW)
	station.moods[0].rest(DeskMood.FETCH, 0)
	assert_eq(station.resting_count(), 0)
	assert_false(station.is_working(0))
	station.moods[0].rest(DeskMood.CHAT, 0)
	assert_eq(station.resting_count(), 1)


func test_kitchen_slots_are_allocated_and_freed() -> void:
	assert_eq(state.free_kitchen_slot(), 0)
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.CHAT, 0)
	assert_true(state.kitchen_slot_taken(0))
	assert_eq(state.free_kitchen_slot(), 1)
	review.moods[0].wake(10.0)
	assert_false(state.kitchen_slot_taken(0))


func test_saved_kitchen_slots_are_repaired_on_load() -> void:
	var review := state.station(REVIEW)
	review.add_desk()
	review.add_desk()
	review.staff = 3
	review.moods[0].rest(DeskMood.CHAT, 2)
	review.moods[1].rest(DeskMood.CHAT, 2)
	review.moods[2].rest(DeskMood.FETCH, 2)
	var loaded := GameState.from_dict(state.to_dict())
	var slots := {}
	for mood in loaded.station(REVIEW).moods:
		assert_true(mood.is_away())
		assert_false(slots.has(mood.slot))
		assert_gte(mood.slot, 0)
		slots[mood.slot] = true


func test_overflowing_kitchen_sends_extra_guests_to_sleep() -> void:
	var review := state.station(REVIEW)
	for i in GameConfig.KITCHEN_SLOTS:
		review.add_desk()
	review.staff = review.desks
	for i in GameConfig.KITCHEN_SLOTS:
		review.moods[i + 1].rest(DeskMood.CHAT, i)
	var data := state.to_dict()
	data.stations[REVIEW].moods[0] = {"state": "fetch", "slot": 0, "alert": 5.0, "resting": 0.0}
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.station(REVIEW).moods[0].state, DeskMood.ASLEEP)
	assert_eq(loaded.free_kitchen_slot(), -1)


func test_doze_reaches_every_state() -> void:
	var seen := {}
	var review := state.station(REVIEW)
	for i in 300:
		review.moods[0].wake(10.0)
		sim.doze_off(review, 0)
		seen[review.moods[0].state] = true
	for rest_state in [DeskMood.ASLEEP, DeskMood.COFFEE, DeskMood.CHAT, DeskMood.FETCH, DeskMood.SLOW]:
		assert_true(seen.has(rest_state), rest_state)


func test_chatting_and_fetching_employees_get_kitchen_slots() -> void:
	var review := state.station(REVIEW)
	for i in 100:
		review.moods[0].wake(10.0)
		sim.doze_off(review, 0)
		if review.moods[0].state == DeskMood.LOO:
			assert_gte(review.moods[0].slot, GameConfig.KITCHEN_SLOTS)
		elif review.moods[0].is_away():
			assert_gte(review.moods[0].slot, 0)
			assert_lt(review.moods[0].slot, GameConfig.KITCHEN_SLOTS)
		else:
			assert_eq(review.moods[0].slot, -1)


func test_full_kitchen_never_accepts_more_guests() -> void:
	var review := state.station(REVIEW)
	for i in GameConfig.KITCHEN_SLOTS:
		review.add_desk()
	review.staff = review.desks
	for i in GameConfig.KITCHEN_SLOTS:
		review.moods[i + 1].rest(DeskMood.CHAT, i)
	for i in 80:
		review.moods[0].wake(10.0)
		sim.doze_off(review, 0)
		assert_true(review.moods[0].state == DeskMood.LOO or not review.moods[0].is_away())


func test_fetching_employee_returns_refreshed() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.FETCH, 0)
	watch_signals(sim)
	_run(GameConfig.FETCH_SECONDS - 1.0, 0.5)
	assert_true(review.moods[0].is_resting())
	_run(2.0, 0.5)
	assert_false(review.moods[0].is_resting())
	assert_gte(review.moods[0].alert, GameConfig.BASE_ALERT_SECONDS * (1.0 - GameConfig.ALERT_VARIANCE) * GameConfig.FETCH_ALERT_FACTOR - 0.01)
	assert_signal_emitted_with_parameters(sim, "employee_woke", [REVIEW, 0, false])
	assert_eq(state.wakes, 0)


func test_fetch_time_ignores_wake_service() -> void:
	var top := int(GameConfig.upgrade("wake_service").max)
	state.set_upgrade("wake_service", top)
	assert_eq(Formulas.rest_limit(state, DeskMood.FETCH), GameConfig.FETCH_SECONDS)
	assert_eq(Formulas.rest_limit(state, DeskMood.CHAT), Formulas.track_value("wake_service", top))


func test_wake_alert_bonus_only_after_fetching() -> void:
	var plain := 0.0
	var fetched := 0.0
	for i in 40:
		plain += Formulas.wake_alert(state, DeskMood.ASLEEP)
		fetched += Formulas.wake_alert(state, DeskMood.FETCH)
	assert_gt(fetched, plain * 1.2)


func test_chatterer_stays_in_kitchen_until_fetched_by_player() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.CHAT, 2)
	_run(60.0, 1.0)
	assert_eq(review.moods[0].state, DeskMood.CHAT)
	state.player.position = layout.kitchen_slot(2)
	watch_signals(sim)
	_run(GameConfig.WAKE_TIME + 0.5)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.wakes, 1)
	assert_signal_emitted_with_parameters(sim, "employee_woke", [REVIEW, 0, true])


func test_player_at_the_desk_recalls_an_absent_official() -> void:
	watch_signals(sim)
	for rest_state in [DeskMood.CHAT, DeskMood.FETCH, DeskMood.SLOW, DeskMood.LOO, DeskMood.LUNCH]:
		var review := _busy_review()
		review.moods[0].wake(GameConfig.BASE_ALERT_SECONDS)
		review.moods[0].arrive()
		review.moods[0].rest(rest_state, GameConfig.KITCHEN_SLOTS if rest_state == DeskMood.LOO else 2)
		state.player.position = layout.desk_position(REVIEW, 0)
		_run(GameConfig.RECALL_TIME - 0.3, 0.1)
		assert_eq(review.moods[0].state, rest_state, rest_state)
		assert_gt(review.moods[0].recall_progress, 0.0, rest_state)
		_run(0.5, 0.1)
		assert_true(review.moods[0].is_returning(), rest_state)
		assert_false(review.is_working(0), rest_state)
		assert_signal_emitted_with_parameters(sim, "employee_recalled", [REVIEW, 0])
		state.player.position = Vector2(50, 50)
		_run(review.moods[0].return_time + 0.2, 0.1)
		assert_true(review.moods[0].is_on_duty(), rest_state)
		assert_signal_emitted_with_parameters(sim, "employee_returned", [REVIEW, 0])
	assert_eq(state.recalls, 5)


func test_recall_progress_resets_when_leaving_the_desk() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.CHAT, 2)
	state.player.position = layout.desk_position(REVIEW, 0)
	_run(0.5, 0.1)
	assert_gt(review.moods[0].recall_progress, 0.0)
	state.player.position = Vector2(50, 50)
	sim.tick(0.1)
	assert_eq(review.moods[0].recall_progress, 0.0)
	assert_eq(review.moods[0].state, DeskMood.CHAT)


func test_recall_guards() -> void:
	var review := state.station(REVIEW)
	assert_false(sim.recall(review, 0))
	review.moods[0].rest(DeskMood.ASLEEP)
	assert_false(sim.recall(review, 0))
	review.moods[0].rest(DeskMood.SICK)
	assert_false(sim.recall(review, 0))
	review.moods[0].rest(DeskMood.CHAT, 1)
	assert_false(sim.recall(review, -1))
	assert_false(sim.recall(review, 9))
	review.staff = 0
	assert_false(sim.recall(review, 0))
	review.staff = 1
	assert_true(sim.recall(review, 0))
	assert_eq(state.recalls, 1)
	assert_eq(state.wakes, 1)


func test_returning_official_works_only_after_the_walk() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.LOO, GameConfig.KITCHEN_SLOTS)
	assert_true(sim.wake_up(review, 0, true))
	var mood := review.moods[0]
	var walk := Formulas.staff_walk_time(layout.slot_point(GameConfig.KITCHEN_SLOTS), layout.desk_position(REVIEW, 0))
	assert_almost_eq(mood.return_time, walk, 0.0001)
	assert_true(mood.is_returning())
	assert_false(mood.is_resting())
	assert_true(mood.is_absent())
	assert_false(mood.needs_help())
	assert_false(sim.wake_up(review, 0, true))
	assert_false(sim.doze_off(review, 0))
	_run(walk - 0.2, 0.1)
	assert_true(mood.is_returning())
	assert_true(review.jobs[0] == null or review.jobs[0].progress == 0.0)
	_run(0.4, 0.1)
	assert_true(mood.is_on_duty())
	assert_true(review.is_working(0))


func test_waking_a_sleeper_needs_no_walk() -> void:
	var review := _busy_review()
	review.moods[0].rest(DeskMood.ASLEEP)
	assert_true(sim.wake_up(review, 0, true))
	assert_true(review.moods[0].is_on_duty())


func test_staff_walk_time_is_clamped() -> void:
	assert_eq(Formulas.staff_walk_time(Vector2.ZERO, Vector2.ZERO), GameConfig.STAFF_WALK_MIN_SECONDS)
	assert_eq(Formulas.staff_walk_time(Vector2.ZERO, Vector2(1e6, 0)), GameConfig.STAFF_WALK_MAX_SECONDS)
	assert_almost_eq(Formulas.staff_walk_time(Vector2.ZERO, Vector2(GameConfig.STAFF_WALK_SPEED, 0)), 1.0, 0.0001)


func test_dispute_takes_two_officials_away_and_sends_them_back() -> void:
	var review := state.station(REVIEW)
	while review.desks < 3:
		review.add_desk()
	review.staff = 3
	var dispute := sim.start_dispute("radio", "general_services")
	assert_not_null(dispute)
	var crew := sim.dispute_crew("general_services")
	assert_eq(crew.size(), GameConfig.DISPUTE_CREW)
	assert_true(review.moods[0].is_disputing())
	assert_true(review.moods[1].is_disputing())
	assert_true(review.moods[2].is_on_duty())
	assert_false(review.is_working(0))
	assert_true(review.is_working(2))
	_run(5.0, 0.5)
	assert_true(review.moods[0].is_disputing())
	assert_false(sim.wake_up(review, 0, true))
	sim.end_dispute(dispute, true)
	assert_true(review.moods[0].is_returning())
	assert_true(review.moods[1].is_returning())
	assert_almost_eq(review.moods[1].return_time, Formulas.staff_walk_time(layout.dispute_spot("general_services", 1), layout.desk_position(REVIEW, 1)), 0.0001)
	assert_true(sim.dispute_crew("general_services").is_empty())
	_run(GameConfig.STAFF_WALK_MAX_SECONDS + 0.5, 0.5)
	assert_true(review.moods[0].is_on_duty())
	assert_true(review.moods[1].is_on_duty())


func test_dispute_moods_survive_saving_and_orphans_are_released() -> void:
	var review := state.station(REVIEW)
	while review.desks < 2:
		review.add_desk()
	review.staff = 2
	sim.start_dispute("radio", "general_services")
	var data: Dictionary = JSON.parse_string(JSON.stringify(state.to_dict()))
	var loaded := GameState.from_dict(data)
	assert_true(loaded.station(REVIEW).moods[0].is_disputing())
	data.disputes = []
	var orphaned := GameState.from_dict(data)
	assert_true(orphaned.station(REVIEW).moods[0].is_on_duty())
	review.moods[0].arrive()
	review.moods[0].start_return(3.0)
	assert_eq(DeskMood.from_dict(review.moods[0].to_dict()).state, DeskMood.AWAKE)
	state.recalls = 4
	assert_eq(GameState.from_dict(state.to_dict()).recalls, 4)


func test_join_dispute_needs_an_official_on_duty() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.ASLEEP)
	assert_false(mood.join_dispute())
	mood.wake(1.0)
	assert_true(mood.join_dispute())
	assert_false(mood.join_dispute())
	assert_true(mood.is_absent())
	assert_false(mood.is_resting())
	assert_false(mood.can_be_recalled())


func test_wake_service_calls_chatterers_back() -> void:
	state.set_upgrade("wake_service", 52)
	var review := _busy_review()
	review.moods[0].rest(DeskMood.CHAT, 0)
	_run(Formulas.rest_limit(state, DeskMood.CHAT) + 2.0, 0.5)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.wakes, 0)


func test_guidance_leads_to_chatterer_in_kitchen_but_not_to_fetchers() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.FETCH, 1)
	assert_true(Guidance.next_task(state).is_empty())
	review.moods[0].rest(DeskMood.CHAT, 1)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WAKE)
	assert_eq(task.point, layout.kitchen_slot(1))


func test_kitchen_layout() -> void:
	var kitchen := layout.kitchen
	assert_false(kitchen.intersects(layout.hall))
	for slot in layout.rooms:
		assert_false(kitchen.intersects(layout.rooms[slot]), slot)
	assert_true(Rect2(Vector2.ZERO, layout.size).encloses(kitchen))
	assert_eq(layout.kitchen_header().size.y, WorldLayout.HEADER)
	assert_true(kitchen.has_point(layout.coffee_machine_point()))
	var seen := {}
	for slot in GameConfig.KITCHEN_SLOTS:
		var point := layout.kitchen_slot(slot)
		assert_true(kitchen.has_point(point), str(slot))
		assert_false(seen.has(point))
		seen[point] = true
	assert_eq(layout.kitchen_slot(-5), layout.kitchen_slot(0))
	assert_eq(layout.kitchen_slot(999), layout.kitchen_slot(GameConfig.KITCHEN_SLOTS - 1))
	assert_eq(layout.slot_at(kitchen.get_center()), "")
