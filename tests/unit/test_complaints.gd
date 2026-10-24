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


func test_full_box_costs_no_reputation() -> void:
	state.reputation = 5.0
	state.complaints = GameConfig.COMPLAINT_CAP
	watch_signals(sim)
	sim.file_complaint()
	assert_eq(state.complaints, GameConfig.COMPLAINT_CAP)
	assert_eq(state.reputation, 5.0)
	assert_eq(state.complaints_filed, 0)
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
	_run(GameConfig.SHREDDER_DELAYS[3] * 2.0 + 15.0, 0.5)
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
	data.complaints_filed = -7
	data.player.complaints = -3
	loaded = GameState.from_dict(data)
	assert_eq(loaded.complaints, GameConfig.COMPLAINT_CAP)
	assert_eq(loaded.complaints_shredded, 0)
	assert_eq(loaded.complaints_filed, GameConfig.COMPLAINT_CAP)
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


func test_complaints_are_rare_and_harmless() -> void:
	assert_gte(GameConfig.COMPLAINT_INTERVAL, 120.0)
	assert_gt(GameConfig.COMPLAINT_REWARD, 0.0)
	assert_lte(GameConfig.COMPLAINT_REWARD, 5.0)
	state.reputation = 10.0
	state.complaints = GameConfig.COMPLAINT_CAP
	_run(120.0, 0.5)
	assert_gte(state.reputation, 10.0)


func test_filing_counts_serials_and_pile_texts_are_newest_first() -> void:
	sim.file_complaint()
	sim.file_complaint()
	sim.file_complaint()
	assert_eq(state.complaints_filed, 3)
	assert_eq(state.pile_complaint_serials(2), [2, 1])
	assert_eq(state.pile_complaint_serials(10), [2, 1, 0])
	state.complaints = 0
	assert_true(state.pile_complaint_serials(5).is_empty())


func test_complaint_texts_cycle_through_all_variants() -> void:
	var seen := {}
	for serial in GameConfig.COMPLAINT_TEXTS:
		seen[Formulas.complaint_text_index(serial)] = true
	assert_eq(seen.size(), GameConfig.COMPLAINT_TEXTS)
	assert_eq(Formulas.complaint_text_index(0), Formulas.complaint_text_index(GameConfig.COMPLAINT_TEXTS))
	assert_eq(Flavor.COMPLAINT_COUNT, GameConfig.COMPLAINT_TEXTS)
	assert_between(Formulas.complaint_text_index(-5), 0, GameConfig.COMPLAINT_TEXTS - 1)


func test_filed_counter_survives_saving() -> void:
	sim.file_complaint()
	sim.file_complaint()
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.complaints_filed, 2)
	var data := state.to_dict()
	data.erase("complaints_filed")
	assert_eq(GameState.from_dict(data).complaints_filed, state.complaints)


func test_layout_exposes_read_area_around_the_desk() -> void:
	assert_true(layout.complaint_read_rect().has_point(layout.complaint_desk_point()))
	assert_false(layout.complaint_read_rect().has_point(layout.shredder_point()))


func test_sheet_shows_empty_box_and_pile_texts() -> void:
	var game := Game.new(state)
	var sheet := ComplaintsSheet.new()
	sheet.setup(game, "")
	add_child_autofree(sheet)
	assert_eq(sheet.title(), sheet.tr("SHEET_COMPLAINTS"))
	assert_true(_has_label(sheet.content, sheet.tr("COMPLAINTS_EMPTY")))
	for i in GameConfig.COMPLAINT_READ_MAX + 2:
		sim.file_complaint()
	sheet.rebuild()
	assert_true(_has_label(sheet.content, Flavor.complaint(state.complaints_filed - 1)))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_COMPLAINTS_MORE") % 2))


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false
