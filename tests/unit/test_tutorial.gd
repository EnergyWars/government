extends GutTest

const TEST_SAVE := "user://test_tutorial_save.json"

var state: GameState
var tutorial: Tutorial
var _previous_locale := ""


func before_all() -> void:
	_previous_locale = TranslationServer.get_locale()


func before_each() -> void:
	state = GameState.create_new(5)
	tutorial = Tutorial.new(state)


func after_each() -> void:
	SaveService.new(TEST_SAVE).delete()
	TranslationServer.set_locale(_previous_locale)


func _step_index(step_id: String) -> int:
	for index in Tutorial.STEPS.size():
		if Tutorial.STEPS[index].id == step_id:
			return index
	return -1


func _go_to_step(step_id: String) -> void:
	state.tutorial_step = _step_index(step_id)
	tutorial.update()


func test_new_game_starts_tutorial_at_first_step() -> void:
	assert_true(tutorial.is_active())
	assert_eq(tutorial.index(), 0)
	assert_eq(tutorial.count(), Tutorial.STEPS.size())
	assert_eq(tutorial.current().id, "welcome")
	assert_true(tutorial.is_info())
	assert_false(tutorial.is_last())


func test_step_definitions_are_consistent() -> void:
	var ids := {}
	var kinds := [Tutorial.INFO, Tutorial.MOVE, Tutorial.SHEET, Tutorial.STAT]
	var sheets := ["departments", "department", "team", "research", "building", "goals", "settings"]
	var targets := ["", "goal", "settings", "departments", "team", "research", "building", "goals"]
	for step: Dictionary in Tutorial.STEPS:
		assert_false(ids.has(step.id), step.id)
		ids[step.id] = true
		assert_true(kinds.has(step.kind), step.id)
		assert_true(targets.has(step.target), step.id)
		if step.kind == Tutorial.SHEET:
			assert_true(sheets.has(step.sheet), step.id)
		if step.kind == Tutorial.STAT:
			assert_gt(step.amount, 0, step.id)
	assert_eq(Tutorial.STEPS[Tutorial.STEPS.size() - 1].kind, Tutorial.INFO)


func test_every_step_is_translated_in_both_languages() -> void:
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for step: Dictionary in Tutorial.STEPS:
			var key := str(step.id).to_upper()
			for suffix in ["TITLE", "TEXT"]:
				var full := "TUTORIAL_%s_%s" % [key, suffix]
				assert_ne(TranslationServer.translate(full), full, "%s in %s" % [full, locale])
		for key in ["TUTORIAL_SKIP", "TUTORIAL_SKIP_STEP", "TUTORIAL_NEXT", "TUTORIAL_FINISH", "TUTORIAL_WAITING", "FMT_TUTORIAL_STEP", "TUTORIAL_SKIP_TITLE", "TUTORIAL_SKIP_TEXT", "TUTORIAL_SKIP_CONFIRM", "TUTORIAL_REPLAY", "TUTORIAL_REPLAY_HINT"]:
			assert_ne(TranslationServer.translate(key), key, "%s in %s" % [key, locale])


func test_advance_moves_through_info_steps() -> void:
	watch_signals(tutorial)
	assert_true(tutorial.advance())
	assert_eq(tutorial.index(), 1)
	assert_signal_emitted(tutorial, "changed")


func test_advance_is_refused_for_action_steps() -> void:
	_go_to_step("move")
	assert_false(tutorial.is_info())
	assert_false(tutorial.advance())
	assert_eq(tutorial.index(), _step_index("move"))


func test_move_step_completes_after_walking_far_enough() -> void:
	_go_to_step("move")
	state.player.position += Vector2(Tutorial.MOVE_DISTANCE - 10.0, 0.0)
	tutorial.update()
	assert_eq(tutorial.current().id, "move")
	state.player.position += Vector2(20.0, 0.0)
	tutorial.update()
	assert_eq(tutorial.current().id, "resources")


func test_stat_steps_count_from_step_entry() -> void:
	state.cases_completed = 40
	_go_to_step("first_case")
	tutorial.update()
	assert_eq(tutorial.current().id, "first_case")
	state.cases_completed = 41
	tutorial.update()
	assert_eq(tutorial.current().id, "queue")


func test_goal_hire_runner_and_upgrade_steps() -> void:
	_go_to_step("goal")
	state.goal_index += 1
	tutorial.update()
	assert_eq(tutorial.current().id, "tasks")
	_go_to_step("hire")
	state.staff_hired += 1
	tutorial.update()
	assert_eq(tutorial.current().id, "runner")
	tutorial.update()
	state.add_runner()
	tutorial.update()
	assert_eq(tutorial.current().id, "upgrade")
	tutorial.update()
	state.station(GameConfig.RECEPTION).level += 1
	tutorial.update()
	assert_eq(tutorial.current().id, "department_open")


func test_sheet_steps_complete_when_sheet_opens() -> void:
	_go_to_step("team_open")
	tutorial.set_open_sheet("research")
	tutorial.update()
	assert_eq(tutorial.current().id, "team_open")
	tutorial.set_open_sheet("team")
	tutorial.update()
	assert_eq(tutorial.current().id, "hire")


func test_sheet_step_completes_if_sheet_is_already_open() -> void:
	tutorial.set_open_sheet("research")
	_go_to_step("research_open")
	assert_eq(tutorial.current().id, "research_info")


func test_open_sheet_tracking_emits_only_on_change() -> void:
	watch_signals(tutorial)
	tutorial.set_open_sheet("team")
	assert_eq(tutorial.open_sheet(), "team")
	assert_signal_emit_count(tutorial, "changed", 1)
	tutorial.set_open_sheet("team")
	assert_signal_emit_count(tutorial, "changed", 1)
	tutorial.set_open_sheet("")
	assert_eq(tutorial.open_sheet(), "")
	assert_signal_emit_count(tutorial, "changed", 2)


func test_finishing_last_step_ends_tutorial() -> void:
	_go_to_step("finish")
	assert_true(tutorial.is_last())
	assert_true(tutorial.advance())
	assert_false(tutorial.is_active())
	assert_eq(state.tutorial_step, Tutorial.FINISHED)
	assert_eq(tutorial.current(), {})
	assert_false(tutorial.is_info())
	assert_false(tutorial.advance())


func test_skip_ends_tutorial_once() -> void:
	watch_signals(tutorial)
	tutorial.skip()
	assert_false(tutorial.is_active())
	assert_signal_emit_count(tutorial, "changed", 1)
	tutorial.skip()
	assert_signal_emit_count(tutorial, "changed", 1)
	tutorial.update()
	assert_false(tutorial.is_active())


func test_restart_begins_again() -> void:
	tutorial.skip()
	tutorial.restart()
	assert_true(tutorial.is_active())
	assert_eq(tutorial.index(), 0)


func test_unknown_stat_never_completes() -> void:
	assert_eq(tutorial._stat("nope"), 0.0)
	assert_false(tutorial._is_complete())


func test_index_helpers() -> void:
	assert_true(Tutorial.is_valid_index(0))
	assert_true(Tutorial.is_valid_index(Tutorial.STEPS.size() - 1))
	assert_false(Tutorial.is_valid_index(Tutorial.STEPS.size()))
	assert_false(Tutorial.is_valid_index(-1))
	assert_eq(Tutorial.clamp_saved(3), 3)
	assert_eq(Tutorial.clamp_saved(999), Tutorial.FINISHED)
	assert_eq(Tutorial.clamp_saved(-5), Tutorial.FINISHED)


func test_progress_is_saved_and_restored() -> void:
	state.tutorial_step = 9
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(copy.tutorial_step, 9)
	var service := SaveService.new(TEST_SAVE)
	assert_true(service.save(state, 1))
	assert_eq(service.load_state().tutorial_step, 9)


func test_saves_without_progress_count_as_finished() -> void:
	var data := state.to_dict()
	data.erase("tutorial_step")
	assert_eq(GameState.from_dict(data).tutorial_step, Tutorial.FINISHED)


func test_invalid_saved_progress_counts_as_finished() -> void:
	var data := state.to_dict()
	data.tutorial_step = 9999
	assert_eq(GameState.from_dict(data).tutorial_step, Tutorial.FINISHED)
	data.tutorial_step = -7
	assert_eq(GameState.from_dict(data).tutorial_step, Tutorial.FINISHED)


func test_outdated_save_version_restarts_tutorial() -> void:
	assert_eq(GameState.from_dict({"version": 1}).tutorial_step, 0)


func test_game_advances_tutorial_every_frame() -> void:
	var game := Game.new(state)
	game.advance(0.0)
	var origin := state.player.position
	game.tutorial.advance()
	state.player.position = origin
	game.advance(0.0)
	state.player.position = origin + Vector2(Tutorial.MOVE_DISTANCE + 1.0, 0.0)
	game.advance(0.0)
	assert_eq(game.tutorial.current().id, "resources")


func test_action_step_can_be_skipped_after_delay() -> void:
	_go_to_step("move")
	watch_signals(tutorial)
	tutorial.update(Tutorial.STEP_SKIP_DELAY - 1.0)
	assert_false(tutorial.can_skip_step())
	assert_false(tutorial.can_advance())
	assert_signal_emit_count(tutorial, "changed", 0)
	tutorial.update(1.0)
	assert_true(tutorial.can_skip_step())
	assert_true(tutorial.can_advance())
	assert_signal_emit_count(tutorial, "changed", 1)
	tutorial.update(5.0)
	assert_signal_emit_count(tutorial, "changed", 1)
	assert_true(tutorial.advance())
	assert_eq(tutorial.current().id, "resources")


func test_skip_delay_restarts_with_each_step() -> void:
	_go_to_step("move")
	tutorial.update(Tutorial.STEP_SKIP_DELAY)
	assert_true(tutorial.advance())
	_go_to_step("first_case")
	assert_false(tutorial.can_skip_step())
	tutorial.update(Tutorial.STEP_SKIP_DELAY)
	assert_true(tutorial.can_skip_step())


func test_info_steps_are_never_step_skippable() -> void:
	tutorial.update(Tutorial.STEP_SKIP_DELAY * 2.0)
	assert_true(tutorial.is_info())
	assert_false(tutorial.can_skip_step())
	assert_true(tutorial.can_advance())


func test_skip_step_unavailable_when_finished() -> void:
	tutorial.skip()
	tutorial.update(Tutorial.STEP_SKIP_DELAY)
	assert_false(tutorial.can_skip_step())
	assert_false(tutorial.can_advance())


func test_goal_step_is_skipped_when_all_goals_are_done() -> void:
	state.goal_index = GameConfig.GOALS.size()
	_go_to_step("goal")
	assert_eq(tutorial.current().id, "tasks")


func test_runner_step_is_skipped_at_runner_limit() -> void:
	while state.runners.size() < GameConfig.MAX_RUNNERS:
		state.add_runner()
	_go_to_step("runner")
	assert_eq(tutorial.current().id, "upgrade")


func test_upgrade_step_is_skipped_when_every_station_is_maxed() -> void:
	for key in state.stations:
		state.stations[key].level = GameConfig.MAX_STATION_LEVEL
	_go_to_step("upgrade")
	assert_eq(tutorial.current().id, "department_open")


func test_upgrade_step_waits_while_one_station_can_grow() -> void:
	for key in state.stations:
		state.stations[key].level = GameConfig.MAX_STATION_LEVEL
	state.station(GameConfig.RECEPTION).level = 1
	_go_to_step("upgrade")
	assert_eq(tutorial.current().id, "upgrade")


func test_hire_step_is_skipped_when_no_one_can_be_hired() -> void:
	while state.runners.size() < GameConfig.MAX_RUNNERS:
		state.add_runner()
	for key in state.stations:
		var station: Station = state.stations[key]
		station.desks = state.max_desks()
		station.staff = station.desks
	_go_to_step("hire")
	assert_eq(tutorial.current().id, "upgrade")


func test_hire_step_waits_while_runners_can_be_hired() -> void:
	for key in state.stations:
		var station: Station = state.stations[key]
		station.desks = state.max_desks()
		station.staff = station.desks
	_go_to_step("hire")
	assert_eq(tutorial.current().id, "hire")


func test_hire_step_waits_while_a_desk_is_free() -> void:
	while state.runners.size() < GameConfig.MAX_RUNNERS:
		state.add_runner()
	for key in state.stations:
		var station: Station = state.stations[key]
		station.desks = state.max_desks()
		station.staff = station.desks
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = reception.desks - 1
	_go_to_step("hire")
	assert_eq(tutorial.current().id, "hire")


func test_room_for_staff_ignores_machines() -> void:
	var machine := Station.new()
	machine.machine = true
	machine.desks = 1
	machine.staff = 0
	assert_false(tutorial._has_room_for_staff(machine))


func test_unknown_stat_is_never_blocked() -> void:
	assert_true(tutorial._can_progress("nope"))
	assert_true(tutorial._can_progress("cases"))


func test_game_passes_time_to_tutorial() -> void:
	var game := Game.new(state)
	game.tutorial.advance()
	game.advance(0.0)
	game.advance(Tutorial.STEP_SKIP_DELAY)
	assert_true(game.tutorial.can_skip_step())
