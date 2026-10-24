extends GutTest

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func test_no_complaints_before_minimum_cases() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES - 1
	_run(GameConfig.COMPLAINT_INTERVAL * 2.0, 1.0)
	assert_eq(state.complaints, 0)


func test_complaints_are_filed_after_minimum_cases() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	watch_signals(sim)
	_run(GameConfig.COMPLAINT_INTERVAL * 1.5, 1.0)
	assert_gt(state.complaints, 0)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [false])


func test_full_box_costs_reputation() -> void:
	state.reputation = 5.0
	state.complaints = GameConfig.COMPLAINT_CAP
	watch_signals(sim)
	sim.file_complaint()
	assert_eq(state.complaints, GameConfig.COMPLAINT_CAP)
	assert_almost_eq(state.reputation, 5.0 - GameConfig.COMPLAINT_OVERFLOW_PENALTY, 0.001)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [true])


func test_player_picks_up_at_desk_and_shreds() -> void:
	state.complaints = 3
	state.player.position = layout.complaint_desk_point()
	_run(2.0)
	assert_eq(state.complaints, 0)
	assert_eq(state.player.complaints, 3)
	var money := state.money
	state.player.position = layout.shredder_point()
	watch_signals(sim)
	_run(2.0)
	assert_eq(state.player.complaints, 0)
	assert_eq(state.complaints_shredded, 3)
	assert_gt(state.money, money)
	assert_signal_emitted_with_parameters(sim, "complaint_shredded", [true])


func test_pickup_respects_carry_capacity() -> void:
	state.complaints = GameConfig.COMPLAINT_CAP
	state.player.position = layout.complaint_desk_point()
	_run(10.0)
	assert_eq(state.player.complaints, Formulas.carry_capacity(state))
	assert_eq(state.complaints, GameConfig.COMPLAINT_CAP - Formulas.carry_capacity(state))


func test_nothing_happens_away_from_desk_and_shredder() -> void:
	state.complaints = 2
	state.player.complaints = 2
	_run(3.0)
	assert_eq(state.complaints, 2)
	assert_eq(state.player.complaints, 2)
	assert_false(sim.move_complaints())


func test_shred_complaints_edge_cases() -> void:
	assert_eq(sim.shred_complaints(3, true), 0)
	assert_eq(sim.shred_complaints(3, false), 0)
	state.complaints = 2
	assert_eq(sim.shred_complaints(5, false), 2)
	assert_eq(state.complaints, 0)


func test_shredder_intern_shreds_automatically() -> void:
	state.research["shredder_service"] = 3
	state.complaints = 2
	_run(GameConfig.SHREDDER_DELAYS[3] * 2.0 + 1.0, 0.5)
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_shredded, 2)


func test_without_intern_nothing_is_shredded_automatically() -> void:
	state.complaints = 2
	_run(120.0, 1.0)
	assert_eq(state.complaints_shredded, 0)
	assert_eq(state.shred_timer, 0.0)


func test_shredder_config_matches_research() -> void:
	assert_eq(GameConfig.SHREDDER_DELAYS.size(), int(GameConfig.RESEARCH.shredder_service.max_level) + 1)
	assert_true(GameConfig.RESEARCH_ORDER.has("shredder_service"))


func test_complaint_layout_lies_in_hall() -> void:
	assert_true(layout.hall.has_point(layout.complaint_desk_point()))
	assert_true(layout.hall.has_point(layout.shredder_point()))
	assert_false(layout.near(layout.complaint_desk_point(), layout.shredder_point()))


func test_complaint_state_is_saved() -> void:
	state.complaints = 4
	state.complaints_shredded = 9
	state.complaint_timer = 12.0
	state.player.complaints = 2
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.complaints, 4)
	assert_eq(loaded.complaints_shredded, 9)
	assert_almost_eq(loaded.complaint_timer, 12.0, 0.001)
	assert_eq(loaded.player.complaints, 2)


func test_old_saves_and_invalid_values_are_tolerated() -> void:
	var data := state.to_dict()
	data.erase("complaints")
	data.erase("complaints_shredded")
	data.erase("complaint_timer")
	data.player.erase("complaints")
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.complaints, 0)
	assert_eq(loaded.player.complaints, 0)
	data.complaints = 999
	data.complaints_shredded = -4
	data.complaint_timer = 1e9
	data.player.complaints = -3
	loaded = GameState.from_dict(data)
	assert_eq(loaded.complaints, GameConfig.COMPLAINT_CAP)
	assert_eq(loaded.complaints_shredded, 0)
	assert_eq(loaded.complaint_timer, GameConfig.COMPLAINT_INTERVAL)
	assert_eq(loaded.player.complaints, 0)


func test_guidance_leads_to_desk_then_shredder() -> void:
	state.complaints = 1
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.COMPLAINT)
	assert_eq(task.point, layout.complaint_desk_point())
	state.complaints = 0
	state.player.complaints = 1
	task = Guidance.next_task(state)
	assert_eq(task.action, Guidance.SHRED)
	assert_eq(task.point, layout.shredder_point())
