extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions
var layout: WorldLayout
var dept: Department


func before_each() -> void:
	state = GameState.create_new(21)
	state.building_stage = GameConfig.TICKET_UNLOCK_STAGE
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.dispute_timer = 1e6
	state.event_cooldown = 1e9
	state.player.position = Vector2(50, 50)
	dept = state.department("general_services")


func _reception() -> Station:
	return state.station(GameConfig.RECEPTION)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _waiting_case() -> CaseFile:
	var case_file := sim.create_case(dept)
	state.ticket_waiting.append(case_file)
	return case_file


func test_tickets_are_locked_before_their_stage() -> void:
	state.building_stage = GameConfig.TICKET_UNLOCK_STAGE - 1
	assert_false(state.tickets_unlocked())
	var case_file := sim.spawn_case(dept)
	assert_not_null(case_file)
	assert_false(sim.needs_ticket(case_file))
	assert_true(_reception().inbox.has(case_file))
	assert_true(state.ticket_line.is_empty())
	_run(1.0)
	assert_eq(state.ticket_progress, 0.0)


func test_new_citizen_queues_at_the_ticket_machine() -> void:
	var case_file := sim.spawn_case(dept)
	assert_true(sim.needs_ticket(case_file))
	assert_eq(state.ticket_line.size(), 1)
	assert_true(state.ticket_line.has(case_file))
	assert_true(_reception().inbox.is_empty())
	assert_eq(state.lobby_used(), 1)
	assert_eq(Formulas.waiting_count(state, dept), 1)


func test_only_citizens_for_the_reception_need_a_ticket() -> void:
	var letter := sim.create_mail_case(dept)
	assert_false(sim.needs_ticket(letter))
	var customs := state.department("customs")
	var cargo := sim.create_case(customs)
	assert_false(sim.needs_ticket(cargo))
	var empty := CaseFile.new("general_services")
	assert_false(sim.needs_ticket(empty))
	var follow_up := sim.spawn_case(dept, true)
	assert_true(state.ticket_line.has(follow_up))


func test_drawing_a_number_takes_time() -> void:
	watch_signals(sim)
	var case_file := sim.spawn_case(dept)
	var draw_time := Formulas.ticket_draw_time(0)
	_run(draw_time - 0.2)
	assert_true(state.ticket_line.has(case_file))
	assert_gt(state.ticket_progress, 0.0)
	_run(0.3)
	assert_true(state.ticket_waiting.has(case_file))
	assert_true(state.ticket_line.is_empty())
	assert_eq(state.tickets_drawn, 1)
	assert_signal_emitted_with_parameters(sim, "ticket_drawn", [1])


func test_player_at_the_machine_speeds_up_drawing() -> void:
	state.player.position = layout.ticket_machine_point()
	var case_file := sim.spawn_case(dept)
	_run(Formulas.ticket_draw_time(0) / GameConfig.TICKET_HAND_FACTOR + 0.1)
	assert_true(state.ticket_waiting.has(case_file))


func test_waiting_citizen_is_called_to_the_reception() -> void:
	watch_signals(sim)
	var case_file := _waiting_case()
	state.tickets_drawn = 1
	_run(Formulas.ticket_call_time(0) - 0.2)
	assert_true(state.ticket_waiting.has(case_file))
	_run(0.3)
	assert_true(_reception().inbox.has(case_file))
	assert_true(state.ticket_waiting.is_empty())
	assert_eq(state.tickets_called, 1)
	assert_signal_emitted_with_parameters(sim, "ticket_called", [1])
	assert_eq(state.ticket_call_progress, 0.0)


func test_player_at_the_display_speeds_up_calls() -> void:
	state.player.position = layout.ticket_display_point()
	var case_file := _waiting_case()
	_run(Formulas.ticket_call_time(0) / GameConfig.TICKET_HAND_FACTOR + 0.1)
	assert_true(_reception().inbox.has(case_file))


func test_calls_wait_while_the_reception_queue_is_full() -> void:
	_reception().staff = 0
	for i in GameConfig.TICKET_CALL_SLOTS:
		_reception().inbox.append(sim.create_case(dept))
	var case_file := _waiting_case()
	state.ticket_call_progress = 1.0
	_run(Formulas.ticket_call_time(0) * 2.0)
	assert_true(state.ticket_waiting.has(case_file))
	assert_eq(state.ticket_call_progress, 0.0)
	_reception().inbox.pop_front()
	_run(Formulas.ticket_call_time(0) + 0.1)
	assert_true(_reception().inbox.has(case_file))


func test_draw_and_call_reject_empty_queues() -> void:
	assert_false(sim.draw_ticket())
	assert_false(sim.call_ticket())
	state.stations.erase(GameConfig.RECEPTION)
	_waiting_case()
	assert_false(sim.call_ticket())
	_run(Formulas.ticket_call_time(0) + 0.1)
	assert_eq(state.ticket_waiting.size(), 1)
	assert_eq(state.ticket_call_progress, 0.0)


func test_full_ticket_line_turns_citizens_away() -> void:
	for i in GameConfig.TICKET_LINE_SLOTS:
		assert_not_null(sim.spawn_case(dept))
	var lost := state.citizens_lost
	var walkouts := state.walkouts
	assert_null(sim.spawn_case(dept))
	assert_eq(state.citizens_lost, lost + 1)
	assert_eq(state.walkouts, walkouts + 1)


func test_ticket_holders_count_towards_the_waiting_area() -> void:
	while state.lobby_used() < state.lobby_capacity() - 1:
		_waiting_case()
	assert_true(state.lobby_has_space())
	_reception().inbox.append(sim.create_case(dept))
	assert_false(state.lobby_has_space())
	assert_false(state.ticket_line_has_space())
	assert_null(sim.spawn_case(dept))
	assert_eq(ThroughputReport.waiting_area(state).demand, float(state.lobby_capacity()))


func test_impatient_ticket_holders_leave() -> void:
	watch_signals(sim)
	var in_line := sim.spawn_case(dept)
	var waiting := _waiting_case()
	var limit := Formulas.patience(state)
	in_line.waited = limit * in_line.patience_factor
	waiting.waited = limit * waiting.patience_factor
	var lost := state.citizens_lost
	sim.tick(0.05)
	assert_false(state.ticket_line.has(in_line))
	assert_false(state.ticket_waiting.has(waiting))
	assert_eq(state.citizens_lost, lost + 2)
	assert_signal_emit_count(sim, "citizen_left", 2)


func test_mayor_speech_keeps_ticket_holders_patient() -> void:
	state.boosts["mayor_speech"] = 10.0
	var waiting := _waiting_case()
	waiting.waited = Formulas.patience(state) * 10.0
	var before := waiting.waited
	sim.tick(0.05)
	assert_true(state.ticket_waiting.has(waiting))
	assert_eq(waiting.waited, before)


func test_ticket_times_shrink_with_each_level() -> void:
	assert_eq(Formulas.ticket_draw_time(0), GameConfig.TICKET_DRAW_SECONDS)
	assert_eq(Formulas.ticket_call_time(0), GameConfig.TICKET_CALL_SECONDS)
	assert_almost_eq(Formulas.ticket_draw_time(1), GameConfig.TICKET_DRAW_SECONDS * GameConfig.TICKET_LEVEL_FACTOR, 0.0001)
	assert_almost_eq(Formulas.ticket_call_time(2), GameConfig.TICKET_CALL_SECONDS * pow(GameConfig.TICKET_LEVEL_FACTOR, 2), 0.0001)
	assert_eq(Formulas.ticket_draw_time(GameConfig.TICKET_MAX_LEVEL + 5), Formulas.ticket_draw_time(GameConfig.TICKET_MAX_LEVEL))
	assert_eq(Formulas.ticket_speed(false), 1.0)
	assert_eq(Formulas.ticket_speed(true), GameConfig.TICKET_HAND_FACTOR)
	state.ticket_machine_level = 3
	state.ticket_display_level = 2
	assert_almost_eq(Formulas.ticket_draw_rate(state), 1.0 / Formulas.ticket_draw_time(3), 0.0001)
	assert_almost_eq(Formulas.ticket_call_rate(state), 1.0 / Formulas.ticket_call_time(2), 0.0001)


func test_ticket_machine_and_display_can_be_upgraded() -> void:
	state.money = 1e12
	var machine_cost := Formulas.ticket_machine_cost(state)
	assert_eq(machine_cost, GameConfig.TICKET_MACHINE_COST)
	assert_true(actions.upgrade_ticket_machine())
	assert_eq(state.ticket_machine_level, 1)
	assert_eq(state.money, 1e12 - machine_cost)
	assert_almost_eq(Formulas.ticket_machine_cost(state), machine_cost * GameConfig.TICKET_MACHINE_GROWTH, 0.01)
	var display_cost := Formulas.ticket_display_cost(state)
	assert_eq(display_cost, GameConfig.TICKET_DISPLAY_COST)
	assert_true(actions.upgrade_ticket_display())
	assert_eq(state.ticket_display_level, 1)
	assert_almost_eq(Formulas.ticket_display_cost(state), display_cost * GameConfig.TICKET_DISPLAY_GROWTH, 0.01)


func test_ticket_upgrades_respect_lock_money_and_maximum() -> void:
	state.money = 0.0
	assert_false(actions.upgrade_ticket_machine())
	assert_false(actions.upgrade_ticket_display())
	state.money = 1e15
	state.ticket_machine_level = GameConfig.TICKET_MAX_LEVEL
	state.ticket_display_level = GameConfig.TICKET_MAX_LEVEL
	assert_false(actions.can_upgrade_ticket_machine())
	assert_false(actions.can_upgrade_ticket_display())
	state.ticket_machine_level = 0
	state.ticket_display_level = 0
	state.building_stage = 0
	assert_false(actions.upgrade_ticket_machine())
	assert_false(actions.upgrade_ticket_display())
	assert_eq(state.money, 1e15)


func test_tickets_survive_saving_and_loading() -> void:
	var in_line := sim.spawn_case(dept)
	var waiting := _waiting_case()
	waiting.waited = 4.0
	state.ticket_machine_level = 2
	state.ticket_display_level = 3
	state.ticket_progress = 1.5
	state.ticket_call_progress = 2.0
	state.tickets_drawn = 12
	state.tickets_called = 9
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.ticket_line.size(), 1)
	assert_eq(loaded.ticket_line[0].dept_id, in_line.dept_id)
	assert_eq(loaded.ticket_waiting.size(), 1)
	assert_eq(loaded.ticket_waiting[0].waited, 4.0)
	assert_eq(loaded.ticket_machine_level, 2)
	assert_eq(loaded.ticket_display_level, 3)
	assert_eq(loaded.ticket_progress, 1.5)
	assert_eq(loaded.ticket_call_progress, 2.0)
	assert_eq(loaded.tickets_drawn, 12)
	assert_eq(loaded.tickets_called, 9)
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(GameState.from_dict(loaded.to_dict()).to_dict()))


func test_loading_sanitizes_ticket_data() -> void:
	var data := state.to_dict()
	var valid := sim.create_case(dept).to_dict()
	var foreign := sim.create_case(state.department("customs")).to_dict()
	var locked := sim.create_case(state.department("housing")).to_dict()
	var lines: Array = ["junk", foreign, locked]
	for i in GameConfig.TICKET_LINE_SLOTS + 3:
		lines.append(valid)
	data.ticket_line = lines
	data.ticket_waiting = "junk"
	data.ticket_machine_level = 99
	data.ticket_display_level = -4
	data.ticket_progress = 999.0
	data.ticket_call_progress = -3.0
	data.tickets_drawn = 5
	data.tickets_called = 50
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.ticket_line.size(), GameConfig.TICKET_LINE_SLOTS)
	assert_true(loaded.ticket_waiting.is_empty())
	assert_eq(loaded.ticket_machine_level, GameConfig.TICKET_MAX_LEVEL)
	assert_eq(loaded.ticket_display_level, 0)
	assert_eq(loaded.ticket_progress, GameConfig.TICKET_DRAW_SECONDS)
	assert_eq(loaded.ticket_call_progress, 0.0)
	assert_eq(loaded.tickets_called, 5)


func test_loading_trims_tickets_to_the_waiting_area() -> void:
	var data := state.to_dict()
	var valid := sim.create_case(dept).to_dict()
	var waiting: Array = []
	for i in state.lobby_capacity() + 5:
		waiting.append(valid)
	var line: Array = []
	for i in GameConfig.TICKET_LINE_SLOTS:
		line.append(valid)
	data.ticket_waiting = waiting
	data.ticket_line = line
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.lobby_used(), loaded.lobby_capacity())
	assert_eq(loaded.ticket_line.size(), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(loaded.ticket_waiting.size(), loaded.lobby_capacity() - GameConfig.TICKET_LINE_SLOTS)


func test_old_saves_and_locked_stages_drop_tickets() -> void:
	sim.spawn_case(dept)
	_waiting_case()
	var data := state.to_dict()
	data.building_stage = 0
	var loaded := GameState.from_dict(data)
	assert_true(loaded.ticket_line.is_empty())
	assert_true(loaded.ticket_waiting.is_empty())
	for key in ["ticket_line", "ticket_waiting", "ticket_machine_level", "ticket_display_level", "ticket_progress", "ticket_call_progress", "tickets_drawn", "tickets_called"]:
		data.erase(key)
	data.building_stage = GameConfig.TICKET_UNLOCK_STAGE
	var legacy := GameState.from_dict(data)
	assert_true(legacy.ticket_line.is_empty())
	assert_eq(legacy.ticket_machine_level, 0)
	assert_eq(legacy.tickets_called, 0)


func test_throughput_report_lists_ticket_bottlenecks_once_unlocked() -> void:
	var kinds: Array[String] = []
	for entry in ThroughputReport.support_areas(state):
		kinds.append(str(entry.area))
	assert_true(kinds.has(ThroughputReport.TICKETS))
	assert_true(kinds.has(ThroughputReport.CALLS))
	var machine := ThroughputReport.ticket_machine_area(state)
	assert_almost_eq(float(machine.capacity), Formulas.ticket_draw_rate(state), 0.0001)
	assert_eq(machine.upgrades[0].id, ThroughputReport.TICKET_MACHINE)
	assert_gt(float(machine.upgrades[0].gain), 0.0)
	var calls := ThroughputReport.ticket_call_area(state)
	assert_eq(calls.upgrades[0].id, ThroughputReport.TICKET_DISPLAY)
	assert_gt(float(calls.upgrades[0].gain), 0.0)
	state.ticket_machine_level = GameConfig.TICKET_MAX_LEVEL
	state.ticket_display_level = GameConfig.TICKET_MAX_LEVEL
	assert_true(ThroughputReport.ticket_machine_area(state).upgrades.is_empty())
	assert_true(ThroughputReport.ticket_call_area(state).upgrades.is_empty())
	state.building_stage = 0
	for entry in ThroughputReport.support_areas(state):
		assert_ne(str(entry.area), ThroughputReport.TICKETS)


func test_guidance_points_to_long_ticket_queues() -> void:
	for i in GameConfig.TICKET_RUSH:
		sim.spawn_case(dept)
	state.player.position = layout.ticket_machine_point()
	assert_eq(Guidance.next_task(state).get("action", ""), Guidance.TICKET)
	state.ticket_line.clear()
	for i in GameConfig.TICKET_RUSH:
		_waiting_case()
	state.player.position = layout.ticket_display_point()
	assert_eq(Guidance.next_task(state).get("action", ""), Guidance.TICKET_CALL)
	for i in GameConfig.TICKET_CALL_SLOTS:
		_reception().inbox.append(sim.create_case(dept))
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.TICKET_CALL)


func test_ticket_layout_points_are_inside_the_hall() -> void:
	assert_true(layout.hall.has_point(layout.ticket_machine_point()))
	assert_true(layout.hall.has_point(layout.ticket_display_point()))
	assert_true(layout.hall.encloses(layout.ticket_display_rect()))
	for i in GameConfig.TICKET_LINE_SLOTS + 2:
		assert_true(layout.hall.has_point(layout.ticket_line_point(i)), "slot %d" % i)
	assert_eq(layout.ticket_line_point(GameConfig.TICKET_LINE_SLOTS + 2), layout.ticket_line_point(GameConfig.TICKET_LINE_SLOTS - 1))
	assert_ne(layout.ticket_line_point(0), layout.ticket_line_point(1))
