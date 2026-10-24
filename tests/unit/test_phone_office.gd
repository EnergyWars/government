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


func _sick(desk: int, reported: bool, resting: float = 0.0) -> DeskMood:
	var mood := state.station(REVIEW).moods[desk]
	mood.rest(DeskMood.SICK)
	mood.reported = reported
	mood.resting = resting
	return mood


func _ring(desk: int) -> PhoneCall:
	_sick(desk, false)
	var phone_call := PhoneCall.new(PhoneCall.INCOMING, REVIEW, desk, GameConfig.SICK_RING_SECONDS)
	state.calls.append(phone_call)
	return phone_call


func _seed_for(persuade: bool) -> int:
	for candidate in 500:
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if (probe.randf() < GameConfig.SICK_TALK_CHANCE) == persuade:
			return candidate
	return -1


func _finish_player_answer(persuade: bool) -> PhoneCall:
	var phone_call := _ring(0)
	state.player.position = layout.phone_point()
	phone_call.line = PhoneCall.PLAYER
	phone_call.progress = GameConfig.CALL_TIME - 0.01
	state.life_rng.seed = _seed_for(persuade)
	sim._update_phones(0.05)
	return phone_call


func test_phone_call_basics() -> void:
	var phone_call := PhoneCall.new(PhoneCall.INCOMING, REVIEW, 2, 9.0)
	assert_true(phone_call.is_incoming())
	assert_true(phone_call.is_ringing())
	assert_false(phone_call.by_player())
	assert_eq(phone_call.ring, 9.0)
	assert_true(phone_call.targets(REVIEW, 2))
	assert_false(phone_call.targets(REVIEW, 1))
	assert_false(phone_call.targets("x", 2))
	assert_eq(phone_call.duration(), GameConfig.HR_ANSWER_SECONDS)
	phone_call.line = PhoneCall.PLAYER
	assert_true(phone_call.by_player())
	assert_false(phone_call.is_ringing())
	assert_eq(phone_call.duration(), GameConfig.CALL_TIME)
	phone_call.progress = GameConfig.CALL_TIME * 2.0
	assert_eq(phone_call.ratio(), 1.0)
	var outgoing := PhoneCall.new(PhoneCall.OUTGOING, REVIEW, 0)
	outgoing.line = 1
	assert_false(outgoing.is_incoming())
	assert_eq(outgoing.duration(), GameConfig.HR_CALL_SECONDS)
	outgoing.progress = GameConfig.HR_CALL_SECONDS * 0.5
	assert_almost_eq(outgoing.ratio(), 0.5, 0.0001)


func test_reported_flag_lifecycle() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.SICK)
	assert_false(mood.reported)
	assert_false(mood.can_be_called())
	mood.reported = true
	assert_true(mood.can_be_called())
	assert_true(DeskMood.from_dict(mood.to_dict()).reported)
	mood.reported = false
	assert_false(DeskMood.from_dict(mood.to_dict()).reported)
	mood.reported = true
	mood.wake(10.0)
	assert_false(mood.reported)
	assert_false(mood.can_be_called())
	mood.reported = true
	mood.rest(DeskMood.ASLEEP)
	assert_false(mood.reported)


func test_legacy_sick_mood_counts_as_reported() -> void:
	assert_true(DeskMood.from_dict({"state": DeskMood.SICK}).reported)
	assert_false(DeskMood.from_dict({"state": DeskMood.ASLEEP}).reported)
	assert_false(DeskMood.from_dict({"state": DeskMood.AWAKE, "reported": true}).reported)


func test_report_sick_rings_the_phone() -> void:
	watch_signals(sim)
	assert_true(sim.report_sick())
	assert_eq(state.calls.size(), 1)
	var phone_call := state.calls[0]
	assert_true(phone_call.is_incoming())
	assert_true(phone_call.is_ringing())
	assert_eq(phone_call.ring, GameConfig.SICK_RING_SECONDS)
	assert_true(state.station(phone_call.key).moods[phone_call.desk].is_sick())
	assert_false(state.station(phone_call.key).moods[phone_call.desk].reported)
	assert_eq(state.ringing_count(), 1)
	assert_signal_emitted_with_parameters(sim, "sick_call_ringing", [phone_call.key, phone_call.desk])


func test_unanswered_call_is_missed_and_stays_unexcused() -> void:
	var phone_call := _ring(0)
	watch_signals(sim)
	_run(GameConfig.SICK_RING_SECONDS - 1.0, 0.5)
	assert_eq(state.calls.size(), 1)
	_run(2.0, 0.5)
	assert_true(state.calls.is_empty())
	assert_eq(state.calls_missed, 1)
	assert_signal_emitted_with_parameters(sim, "sick_call_missed", [phone_call.key, phone_call.desk])
	assert_false(state.station(REVIEW).moods[0].reported)
	state.player.position = layout.phone_point()
	_run(GameConfig.CALL_TIME + 1.0, 0.1)
	assert_true(state.station(REVIEW).moods[0].is_sick())
	assert_eq(state.calls_made, 0)
	assert_null(state.line_call(PhoneCall.PLAYER))


func test_player_answers_and_logs_sick_note() -> void:
	watch_signals(sim)
	var phone_call := _finish_player_answer(false)
	var mood := state.station(REVIEW).moods[0]
	assert_false(state.calls.has(phone_call))
	assert_true(mood.is_sick())
	assert_true(mood.reported)
	assert_eq(state.calls_answered, 1)
	assert_signal_emitted_with_parameters(sim, "sick_call_answered", [true, REVIEW, 0, false])


func test_player_can_talk_caller_into_coming() -> void:
	watch_signals(sim)
	_finish_player_answer(true)
	var mood := state.station(REVIEW).moods[0]
	assert_false(mood.is_resting())
	assert_eq(state.wakes, 1)
	assert_eq(state.calls_answered, 1)
	assert_signal_emitted_with_parameters(sim, "sick_call_answered", [true, REVIEW, 0, true])


func test_player_picks_up_ringing_call_at_phone() -> void:
	var phone_call := _ring(0)
	state.player.position = layout.phone_point()
	_run(0.5, 0.1)
	assert_eq(phone_call.line, PhoneCall.PLAYER)
	assert_gt(phone_call.progress, 0.0)
	assert_almost_eq(phone_call.ring, GameConfig.SICK_RING_SECONDS - 0.1, 0.001)
	assert_eq(state.ringing_count(), 0)
	_run(GameConfig.CALL_TIME, 0.1)
	assert_false(state.calls.has(phone_call))
	assert_eq(state.calls_answered, 1)


func test_walking_away_puts_incoming_call_back_on_hold() -> void:
	var phone_call := _ring(0)
	state.player.position = layout.phone_point()
	_run(0.5, 0.1)
	state.player.position = Vector2(50, 50)
	_run(0.1)
	assert_true(phone_call.is_ringing())
	assert_eq(phone_call.progress, 0.0)
	assert_lt(phone_call.ring, GameConfig.SICK_RING_SECONDS)
	assert_true(state.calls.has(phone_call))


func test_player_calls_reported_colleague_back() -> void:
	_sick(0, true)
	state.player.position = layout.phone_point()
	watch_signals(sim)
	_run(GameConfig.CALL_TIME + 0.5, 0.1)
	assert_false(state.station(REVIEW).moods[0].is_resting())
	assert_eq(state.calls_made, 1)
	assert_eq(state.wakes, 1)
	assert_true(state.calls.is_empty())
	assert_signal_emitted_with_parameters(sim, "sick_called", [true, REVIEW, 0])


func test_walking_away_cancels_outgoing_call() -> void:
	_sick(0, true)
	state.player.position = layout.phone_point()
	_run(0.5, 0.1)
	assert_eq(state.calls.size(), 1)
	assert_false(state.calls[0].is_incoming())
	state.player.position = Vector2(50, 50)
	_run(0.1)
	assert_true(state.calls.is_empty())
	_run(5.0, 0.5)
	assert_true(state.station(REVIEW).moods[0].is_sick())


func test_incoming_calls_take_priority_over_callbacks() -> void:
	_sick(1, true, 50.0)
	var phone_call := _ring(0)
	state.player.position = layout.phone_point()
	_run(0.1)
	assert_eq(state.line_call(PhoneCall.PLAYER), phone_call)


func test_longest_sick_is_called_first_and_never_twice() -> void:
	_sick(0, true, 10.0)
	_sick(1, true, 50.0)
	_sick(2, false, 90.0)
	state.hr = 3
	_run(0.1)
	assert_eq(state.line_call(0).desk, 1)
	assert_eq(state.line_call(1).desk, 0)
	assert_null(state.line_call(2))
	assert_eq(state.calls.size(), 2)
	assert_not_null(state.call_for(REVIEW, 1))
	assert_null(state.call_for(REVIEW, 2))


func test_clerks_answer_and_call_back_automatically() -> void:
	state.hr = 1
	_ring(0)
	_sick(1, true, 5.0)
	watch_signals(sim)
	_run(GameConfig.HR_ANSWER_SECONDS + 0.2, 0.1)
	assert_eq(state.calls_answered, 1)
	assert_signal_emitted(sim, "sick_call_answered")
	_run(GameConfig.HR_CALL_SECONDS + 0.5, 0.1)
	assert_false(state.station(REVIEW).moods[1].is_resting())
	assert_gte(state.calls_made, 1)
	assert_eq(state.wakes, 0)
	assert_signal_emitted(sim, "sick_called")


func test_stale_calls_are_dropped() -> void:
	var phone_call := _ring(0)
	state.station(REVIEW).moods[0].wake(10.0)
	_run(0.1)
	assert_false(state.calls.has(phone_call))
	phone_call = _ring(1)
	state.station(REVIEW).staff = 1
	_run(0.1)
	assert_false(state.calls.has(phone_call))
	state.station(REVIEW).staff = 4
	state.calls.append(PhoneCall.new(PhoneCall.INCOMING, "missing/station", 0, 5.0))
	state.calls.append(PhoneCall.new(PhoneCall.INCOMING, REVIEW, 99, 5.0))
	_run(0.1)
	assert_true(state.calls.is_empty())


func test_calls_on_lost_lines_are_dropped() -> void:
	_sick(0, true)
	state.hr = 2
	_run(0.1)
	assert_not_null(state.line_call(0))
	state.hr = 0
	_run(0.1)
	assert_true(state.calls.is_empty())


func test_sick_employee_returning_alone_ends_call() -> void:
	_sick(0, true, GameConfig.SICK_SECONDS - 1.0)
	state.hr = 1
	_run(0.1)
	assert_eq(state.calls.size(), 1)
	_run(1.5, 0.1)
	assert_false(state.station(REVIEW).moods[0].is_resting())
	assert_true(state.calls.is_empty())
	assert_eq(state.calls_made, 0)


func test_state_helpers() -> void:
	assert_eq(state.ringing_count(), 0)
	assert_eq(state.reported_sick_count(), 0)
	assert_null(state.line_call(0))
	assert_null(state.call_for(REVIEW, 0))
	var phone_call := _ring(0)
	_sick(1, true)
	_sick(2, false)
	assert_eq(state.ringing_count(), 1)
	assert_eq(state.reported_sick_count(), 1)
	assert_eq(state.sick_count(), 3)
	assert_eq(state.call_for(REVIEW, 0), phone_call)
	phone_call.line = 0
	assert_eq(state.ringing_count(), 0)
	assert_eq(state.line_call(0), phone_call)


func test_guidance_leads_to_phone_only_with_something_to_do() -> void:
	state.player.position = layout.phone_point()
	_sick(0, false)
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.CALL)
	state.station(REVIEW).moods[0].reported = true
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.CALL)
	assert_eq(task.point, layout.phone_point())
	state.station(REVIEW).moods[0].reported = false
	state.calls.append(PhoneCall.new(PhoneCall.INCOMING, REVIEW, 0, 5.0))
	assert_eq(Guidance.next_task(state).action, Guidance.CALL)


func test_call_counters_are_saved_and_clamped() -> void:
	state.calls_answered = 4
	state.calls_missed = 2
	_sick(0, true)
	_ring(1)
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.calls_answered, 4)
	assert_eq(loaded.calls_missed, 2)
	assert_true(loaded.station(REVIEW).moods[0].reported)
	assert_false(loaded.station(REVIEW).moods[1].reported)
	assert_true(loaded.calls.is_empty())
	var data := state.to_dict()
	data.calls_answered = -1
	data.calls_missed = -5
	loaded = GameState.from_dict(data)
	assert_eq(loaded.calls_answered, 0)
	assert_eq(loaded.calls_missed, 0)
	data.erase("calls_answered")
	data.erase("calls_missed")
	loaded = GameState.from_dict(data)
	assert_eq(loaded.calls_answered, 0)
	assert_eq(loaded.calls_missed, 0)


func test_phone_office_is_own_room() -> void:
	var office := layout.phone_office
	assert_gt(office.size.y, WorldLayout.HEADER)
	assert_false(office.intersects(layout.kitchen))
	assert_false(office.intersects(layout.toilets))
	assert_false(office.intersects(layout.hall))
	for slot in layout.rooms:
		assert_false(office.intersects(layout.rooms[slot]), slot)
	assert_true(Rect2(Vector2.ZERO, layout.size).encloses(office))
	assert_gt(office.position.y, layout.kitchen.end.y)
	assert_gt(layout.hall.position.y, office.end.y)
	assert_eq(layout.phone_header().size.y, WorldLayout.HEADER)
	assert_eq(layout.phone_header().position, office.position)
	assert_true(office.has_point(layout.phone_point()))
	assert_true(office.has_point(layout.switchboard_point()))
	assert_true(office.encloses(layout.sick_board()))
	for line in GameConfig.MAX_HR:
		var point := layout.operator_point(line)
		assert_true(office.has_point(point), str(line))
		assert_false(layout.sick_board().grow(40).has_point(point), str(line))
		assert_eq(layout.line_point(line), point)
	assert_eq(layout.line_point(PhoneCall.PLAYER), layout.phone_point())
	assert_eq(layout.operator_point(99), layout.operator_point(GameConfig.MAX_HR - 1))
	assert_false(layout.near(layout.phone_point(), layout.operator_point(0)))
