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
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func test_doze_weights_sum_to_one_and_shift_with_kitchen_level() -> void:
	var base := Formulas.doze_weights(state)
	var total := 0.0
	for key in base:
		total += float(base[key])
	assert_almost_eq(total, 1.0, 0.0001)
	state.research["kitchen"] = 3
	var upgraded := Formulas.doze_weights(state)
	total = 0.0
	for key in upgraded:
		total += float(upgraded[key])
	assert_almost_eq(total, 1.0, 0.0001)
	assert_lt(float(upgraded["chat"]), float(base["chat"]))
	assert_gt(float(upgraded["fetch"]), float(base["fetch"]))
	assert_eq(float(upgraded["asleep"]), float(base["asleep"]))


func test_kitchen_config_matches_research() -> void:
	assert_true(GameConfig.RESEARCH_ORDER.has("coffee_machine"))
	assert_true(GameConfig.RESEARCH_ORDER.has("kitchen"))
	assert_lt(GameConfig.KITCHEN_CHAT_SHIFT * int(GameConfig.RESEARCH.kitchen.max_level), float(GameConfig.DOZE_WEIGHTS["chat"]))


func test_coffee_machine_shortens_fetch_and_boosts_alert() -> void:
	var base_time := Formulas.rest_limit(state, DeskMood.FETCH)
	state.research["coffee_machine"] = 4
	assert_lt(Formulas.rest_limit(state, DeskMood.FETCH), base_time)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.FETCH), GameConfig.FETCH_SECONDS * pow(GameConfig.COFFEE_MACHINE_FETCH_FACTOR, 4), 0.001)
	var plain := 0.0
	var upgraded := 0.0
	for i in 40:
		plain += Formulas.wake_alert(state, DeskMood.SLOW)
		upgraded += Formulas.wake_alert(state, DeskMood.FETCH)
	assert_gt(upgraded, plain)


func test_slow_state_basics() -> void:
	var mood := DeskMood.new()
	mood.rest(DeskMood.SLOW, 2)
	assert_true(mood.is_away())
	assert_true(mood.needs_help())
	assert_eq(mood.slot, 2)
	assert_eq(DeskMood.from_dict(mood.to_dict()).state, DeskMood.SLOW)
	assert_eq(Formulas.rest_limit(state, DeskMood.SLOW), GameConfig.SLOW_SECONDS)
	state.research["wake_service"] = 5
	assert_eq(Formulas.rest_limit(state, DeskMood.SLOW), GameConfig.SLOW_SECONDS)


func test_slow_walker_returns_slowly_on_his_own() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SLOW, 0)
	_run(GameConfig.SLOW_SECONDS - 5.0, 0.5)
	assert_true(review.moods[0].is_resting())
	_run(6.0, 0.5)
	assert_false(review.moods[0].is_resting())
	assert_eq(state.wakes, 0)


func test_player_drives_slow_walker_on() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SLOW, 3)
	state.player.position = layout.kitchen_slot(3)
	_run(GameConfig.SLOW_SECONDS / GameConfig.DRIVE_FACTOR + 1.0, 0.1)
	assert_false(review.moods[0].is_resting())


func test_driving_requires_being_close() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SLOW, 3)
	state.player.position = layout.desk_position(REVIEW, 0)
	_run(GameConfig.SLOW_SECONDS / GameConfig.DRIVE_FACTOR + 1.0, 0.1)
	assert_true(review.moods[0].is_resting())


func test_guidance_leads_to_slow_walker() -> void:
	var review := state.station(REVIEW)
	review.moods[0].rest(DeskMood.SLOW, 5)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WAKE)
	assert_eq(task.point, layout.kitchen_slot(5))


func test_kranz_not_called_with_too_few_staff() -> void:
	var review := state.station(REVIEW)
	review.staff = 1
	state.kranz_timer = 0.0
	_run(0.1)
	assert_false(state.kranz)
	assert_eq(state.kranz_timer, GameConfig.KRANZ_RETRY_SECONDS)


func test_kranz_is_called_and_sends_staff_to_kitchen() -> void:
	state.kranz_timer = 0.0
	watch_signals(sim)
	_run(0.1)
	assert_true(state.kranz)
	assert_signal_emitted(sim, "kranz_called")
	var chatting := 0
	for mood in state.station(REVIEW).moods:
		if mood.state == DeskMood.CHAT:
			chatting += 1
			assert_gte(mood.slot, 0)
	assert_gte(chatting, GameConfig.KRANZ_MIN_PARTICIPANTS)
	assert_lte(chatting, GameConfig.KRANZ_SIZE)


func test_player_ends_kranz_at_table() -> void:
	state.kranz_timer = 0.0
	_run(0.1)
	watch_signals(sim)
	state.player.position = layout.kranz_point()
	_run(GameConfig.KRANZ_END_TIME + 0.5, 0.1)
	assert_false(state.kranz)
	assert_gt(state.wakes, 0)
	assert_signal_emitted_with_parameters(sim, "kranz_ended", [true])
	for mood in state.station(REVIEW).moods:
		assert_ne(mood.state, DeskMood.CHAT)
	assert_gte(state.kranz_timer, GameConfig.KRANZ_MIN_INTERVAL - 1.0)


func test_kranz_progress_resets_when_player_leaves() -> void:
	state.kranz_timer = 0.0
	_run(0.1)
	state.player.position = layout.kranz_point()
	_run(0.5, 0.1)
	assert_gt(state.kranz_progress, 0.0)
	state.player.position = Vector2(50, 50)
	_run(0.1)
	assert_eq(state.kranz_progress, 0.0)
	assert_true(state.kranz)


func test_kranz_ends_by_itself_when_everyone_returned() -> void:
	state.research["wake_service"] = 5
	state.kranz_timer = 0.0
	_run(0.1)
	watch_signals(sim)
	_run(GameConfig.WAKE_SERVICE_DELAYS[5] + 2.0, 0.25)
	assert_false(state.kranz)
	assert_signal_emitted_with_parameters(sim, "kranz_ended", [false])


func test_kranz_limited_by_free_kitchen_slots() -> void:
	var review := state.station(REVIEW)
	for i in GameConfig.KITCHEN_SLOTS:
		review.add_desk()
	review.staff = review.desks
	for i in GameConfig.KITCHEN_SLOTS:
		review.moods[i + 1].rest(DeskMood.CHAT, i)
	assert_false(sim.call_kranz())


func test_guidance_prefers_kranz_table() -> void:
	state.kranz_timer = 0.0
	_run(0.1)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.KRANZ)
	assert_eq(task.point, layout.kranz_point())


func test_kranz_state_is_saved_and_clamped() -> void:
	state.kranz = true
	state.kranz_timer = 33.0
	var loaded := GameState.from_dict(state.to_dict())
	assert_true(loaded.kranz)
	assert_almost_eq(loaded.kranz_timer, 33.0, 0.001)
	var data := state.to_dict()
	data.erase("kranz")
	data.kranz_timer = 1e9
	loaded = GameState.from_dict(data)
	assert_false(loaded.kranz)
	assert_eq(loaded.kranz_timer, GameConfig.KRANZ_MAX_INTERVAL)


func test_kranz_point_is_in_kitchen() -> void:
	assert_true(layout.kitchen.has_point(layout.kranz_point()))
