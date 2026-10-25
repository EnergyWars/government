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


func _track_entry(upgrade_id: String) -> String:
	return "%s:%s" % [UpgradeCatalog.TRACK, upgrade_id]


func _max_level(upgrade_id: String) -> int:
	return int(GameConfig.upgrade(upgrade_id).max)


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
	var draw_time := Formulas.ticket_draw_time(state)
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
	_run(Formulas.ticket_draw_time(state) / GameConfig.TICKET_HAND_FACTOR + 0.1)
	assert_true(state.ticket_waiting.has(case_file))


func test_extra_ticket_machines_draw_numbers_faster() -> void:
	state.set_upgrade("ticket_machines", 2)
	assert_eq(Formulas.ticket_machines(state), 3)
	assert_almost_eq(Formulas.ticket_draw_time(state), GameConfig.TICKET_DRAW_SECONDS / 3.0, 0.0001)
	var case_file := sim.spawn_case(dept)
	_run(Formulas.ticket_draw_time(state) + 0.1)
	assert_true(state.ticket_waiting.has(case_file))


func test_waiting_citizen_is_called_to_the_reception() -> void:
	watch_signals(sim)
	var case_file := _waiting_case()
	state.tickets_drawn = 1
	_run(Formulas.ticket_call_time(state) - 0.2)
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
	_run(Formulas.ticket_call_time(state) / GameConfig.TICKET_HAND_FACTOR + 0.1)
	assert_true(_reception().inbox.has(case_file))


func test_calls_wait_while_the_reception_queue_is_full() -> void:
	_reception().staff = 0
	for i in GameConfig.TICKET_CALL_SLOTS:
		_reception().inbox.append(sim.create_case(dept))
	var case_file := _waiting_case()
	state.ticket_call_progress = 1.0
	_run(Formulas.ticket_call_time(state) * 2.0)
	assert_true(state.ticket_waiting.has(case_file))
	assert_eq(state.ticket_call_progress, 0.0)
	_reception().inbox.pop_front()
	_run(Formulas.ticket_call_time(state) + 0.1)
	assert_true(_reception().inbox.has(case_file))


func test_draw_and_call_reject_empty_queues() -> void:
	assert_false(sim.draw_ticket())
	assert_false(sim.call_ticket())
	state.stations.erase(GameConfig.RECEPTION)
	_waiting_case()
	assert_false(sim.call_ticket())
	_run(Formulas.ticket_call_time(state) + 0.1)
	assert_eq(state.ticket_waiting.size(), 1)
	assert_eq(state.ticket_call_progress, 0.0)


func test_full_ticket_line_turns_citizens_away() -> void:
	assert_eq(state.ticket_line_capacity(), GameConfig.TICKET_LINE_SLOTS)
	for i in state.ticket_line_capacity():
		assert_not_null(sim.spawn_case(dept))
	var lost := state.citizens_lost
	var walkouts := state.walkouts
	assert_null(sim.spawn_case(dept))
	assert_eq(state.citizens_lost, lost + 1)
	assert_eq(state.walkouts, walkouts + 1)


func test_longer_ticket_line_admits_more_citizens() -> void:
	state.set_upgrade("ticket_line", 5)
	assert_eq(state.ticket_line_capacity(), GameConfig.TICKET_LINE_SLOTS + 5)
	for i in state.ticket_line_capacity():
		assert_not_null(sim.spawn_case(dept))
	assert_null(sim.spawn_case(dept))
	state.set_upgrade("ticket_line", _max_level("ticket_line") + 10)
	assert_eq(state.ticket_line_capacity(), GameConfig.MAX_TICKET_LINE_SLOTS)


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
	assert_eq(Formulas.ticket_machines(state), 1)
	assert_almost_eq(Formulas.ticket_draw_time(state), GameConfig.TICKET_DRAW_SECONDS, 0.0001)
	assert_almost_eq(Formulas.ticket_call_time(state), GameConfig.TICKET_CALL_SECONDS, 0.0001)
	var draw_rate := float(GameConfig.upgrade("ticket_speed").rate)
	var call_rate := float(GameConfig.upgrade("ticket_call_speed").rate)
	state.set_upgrade("ticket_speed", 1)
	state.set_upgrade("ticket_call_speed", 2)
	assert_almost_eq(Formulas.ticket_draw_time(state), GameConfig.TICKET_DRAW_SECONDS * draw_rate, 0.0001)
	assert_almost_eq(Formulas.ticket_call_time(state), GameConfig.TICKET_CALL_SECONDS * pow(call_rate, 2), 0.0001)
	assert_eq(Formulas.ticket_speed(false), 1.0)
	assert_eq(Formulas.ticket_speed(true), GameConfig.TICKET_HAND_FACTOR)
	assert_almost_eq(Formulas.ticket_draw_rate(state), 1.0 / Formulas.ticket_draw_time(state), 0.0001)
	assert_almost_eq(Formulas.ticket_call_rate(state), 1.0 / Formulas.ticket_call_time(state), 0.0001)
	state.set_upgrade("ticket_speed", _max_level("ticket_speed") + 5)
	assert_eq(state.upgrade_level("ticket_speed"), _max_level("ticket_speed"))
	assert_almost_eq(Formulas.ticket_draw_time(state), GameConfig.TICKET_DRAW_SECONDS * pow(draw_rate, _max_level("ticket_speed")), 0.0001)
	assert_gt(Formulas.ticket_draw_time(state), 0.0)
	state.set_upgrade("ticket_machines", _max_level("ticket_machines") + 5)
	assert_eq(Formulas.ticket_machines(state), GameConfig.MAX_TICKET_MACHINES)
	assert_almost_eq(Formulas.ticket_draw_time(state), Formulas.upgrade_value(state, "ticket_speed") / GameConfig.MAX_TICKET_MACHINES, 0.0001)


func test_ticket_machine_and_display_can_be_upgraded() -> void:
	state.money = 1e12
	var speed_cost := Formulas.track_cost("ticket_speed", 0)
	assert_eq(speed_cost, float(GameConfig.upgrade("ticket_speed").cost))
	assert_true(actions.buy_upgrade("ticket_speed"))
	assert_eq(state.upgrade_level("ticket_speed"), 1)
	assert_almost_eq(state.money, 1e12 - speed_cost, 0.01)
	assert_almost_eq(Formulas.track_cost("ticket_speed", 1), speed_cost * float(GameConfig.upgrade("ticket_speed").growth), 0.01)
	var call_cost := Formulas.track_cost("ticket_call_speed", 0)
	assert_eq(call_cost, float(GameConfig.upgrade("ticket_call_speed").cost))
	assert_true(actions.buy_upgrade("ticket_call_speed"))
	assert_eq(state.upgrade_level("ticket_call_speed"), 1)
	assert_almost_eq(Formulas.track_cost("ticket_call_speed", 1), call_cost * float(GameConfig.upgrade("ticket_call_speed").growth), 0.01)
	assert_true(actions.buy_upgrade("ticket_machines"))
	assert_eq(Formulas.ticket_machines(state), 2)
	assert_true(actions.buy_upgrade("ticket_line", "", 5))
	assert_eq(state.ticket_line_capacity(), GameConfig.TICKET_LINE_SLOTS + 5)


func test_ticket_upgrades_respect_lock_money_and_maximum() -> void:
	var tracks: Array[String] = ["ticket_speed", "ticket_call_speed", "ticket_machines", "ticket_line"]
	state.money = 0.0
	for upgrade_id in tracks:
		assert_eq(Progression.upgrade_block_reason(state, upgrade_id), "money", upgrade_id)
		assert_false(actions.buy_upgrade(upgrade_id), upgrade_id)
	state.money = 1e15
	for upgrade_id in tracks:
		state.set_upgrade(upgrade_id, _max_level(upgrade_id))
		assert_eq(Progression.upgrade_block_reason(state, upgrade_id), "max", upgrade_id)
		assert_false(actions.buy_upgrade(upgrade_id), upgrade_id)
		state.set_upgrade(upgrade_id, 0)
	state.building_stage = 0
	for upgrade_id in tracks:
		assert_eq(Progression.upgrade_block_reason(state, upgrade_id), "stage", upgrade_id)
		assert_false(actions.buy_upgrade(upgrade_id), upgrade_id)
	assert_eq(state.money, 1e15)
	assert_true(state.upgrades.is_empty())


func test_tickets_survive_saving_and_loading() -> void:
	var in_line := sim.spawn_case(dept)
	var waiting := _waiting_case()
	waiting.waited = 4.0
	state.set_upgrade("ticket_speed", 2)
	state.set_upgrade("ticket_call_speed", 3)
	state.set_upgrade("ticket_machines", 1)
	state.set_upgrade("ticket_line", 4)
	state.ticket_progress = 1.5
	state.ticket_call_progress = 2.0
	state.tickets_drawn = 12
	state.tickets_called = 9
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.ticket_line.size(), 1)
	assert_eq(loaded.ticket_line[0].dept_id, in_line.dept_id)
	assert_eq(loaded.ticket_waiting.size(), 1)
	assert_eq(loaded.ticket_waiting[0].waited, 4.0)
	assert_eq(loaded.upgrade_level("ticket_speed"), 2)
	assert_eq(loaded.upgrade_level("ticket_call_speed"), 3)
	assert_eq(Formulas.ticket_machines(loaded), 2)
	assert_eq(loaded.ticket_line_capacity(), GameConfig.TICKET_LINE_SLOTS + 4)
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
	data.upgrades = {"ticket_speed": 9999, "ticket_call_speed": -4}
	data.ticket_progress = 999.0
	data.ticket_call_progress = -3.0
	data.tickets_drawn = 5
	data.tickets_called = 50
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.ticket_line_capacity(), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(loaded.ticket_line.size(), GameConfig.TICKET_LINE_SLOTS)
	assert_true(loaded.ticket_waiting.is_empty())
	assert_eq(loaded.upgrade_level("ticket_speed"), _max_level("ticket_speed"))
	assert_eq(loaded.upgrade_level("ticket_call_speed"), 0)
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
	for key in ["ticket_line", "ticket_waiting", "upgrades", "ticket_progress", "ticket_call_progress", "tickets_drawn", "tickets_called"]:
		data.erase(key)
	data.building_stage = GameConfig.TICKET_UNLOCK_STAGE
	var legacy := GameState.from_dict(data)
	assert_true(legacy.ticket_line.is_empty())
	assert_eq(legacy.upgrade_level("ticket_speed"), 0)
	assert_eq(legacy.ticket_line_capacity(), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(legacy.tickets_called, 0)


func test_throughput_report_lists_ticket_bottlenecks_once_unlocked() -> void:
	var kinds: Array[String] = []
	for entry in ThroughputReport.support_areas(state):
		kinds.append(str(entry.area))
	assert_true(kinds.has(ThroughputReport.TICKETS))
	assert_true(kinds.has(ThroughputReport.CALLS))
	var machine := ThroughputReport.ticket_machine_area(state)
	assert_almost_eq(float(machine.capacity), Formulas.ticket_draw_rate(state), 0.0001)
	var machine_entries: Array[String] = []
	for suggestion: Dictionary in machine.upgrades:
		assert_eq(suggestion.id, ThroughputReport.TRACK)
		assert_gt(float(suggestion.gain), 0.0)
		machine_entries.append(str(suggestion.entry))
	assert_true(machine_entries.has(_track_entry("ticket_speed")))
	assert_true(machine_entries.has(_track_entry("ticket_machines")))
	var calls := ThroughputReport.ticket_call_area(state)
	assert_eq(calls.upgrades.size(), 1)
	assert_eq(calls.upgrades[0].id, ThroughputReport.TRACK)
	assert_eq(calls.upgrades[0].entry, _track_entry("ticket_call_speed"))
	assert_gt(float(calls.upgrades[0].gain), 0.0)
	for upgrade_id: String in ["ticket_speed", "ticket_call_speed", "ticket_machines"]:
		state.set_upgrade(upgrade_id, _max_level(upgrade_id))
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
	assert_true(layout.hall.has_point(layout.ticket_display_point()))
	assert_true(layout.hall.encloses(layout.ticket_display_rect()))
	assert_true(layout.hall.encloses(layout.ticket_area))
	for i in GameConfig.MAX_TICKET_MACHINES:
		assert_true(layout.ticket_area.has_point(layout.ticket_machine_point(i)), "machine %d" % i)
	assert_eq(layout.ticket_machine_point(), layout.ticket_machine_point(0))
	assert_ne(layout.ticket_machine_point(0), layout.ticket_machine_point(1))
	assert_eq(layout.ticket_machine_point(GameConfig.MAX_TICKET_MACHINES + 2), layout.ticket_machine_point(GameConfig.MAX_TICKET_MACHINES - 1))
	for i in GameConfig.MAX_TICKET_LINE_SLOTS + 2:
		assert_true(layout.ticket_area.has_point(layout.ticket_line_point(i)), "slot %d" % i)
	assert_eq(layout.ticket_line_point(GameConfig.MAX_TICKET_LINE_SLOTS + 2), layout.ticket_line_point(GameConfig.MAX_TICKET_LINE_SLOTS - 1))
	assert_ne(layout.ticket_line_point(0), layout.ticket_line_point(1))
	assert_ne(layout.ticket_line_point(WorldLayout.TICKET_LINE_PER_ROW - 1), layout.ticket_line_point(WorldLayout.TICKET_LINE_PER_ROW))
