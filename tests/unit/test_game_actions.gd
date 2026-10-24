extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions


func before_each() -> void:
	state = GameState.create_new(9)
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)


func _case(dept_id: String = "general_services") -> CaseFile:
	var case_file := CaseFile.new(dept_id)
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func test_add_desk_until_stage_limit() -> void:
	state.money = 1e6
	assert_true(actions.add_desk("general_services/review"))
	assert_eq(state.station("general_services/review").desks, 2)
	assert_false(actions.can_add_desk("general_services/review"))
	assert_false(actions.add_desk("general_services/review"))
	assert_false(actions.add_desk("nope"))
	assert_almost_eq(state.money, 1e6 - 120.0, 0.01)


func test_add_desk_needs_money() -> void:
	state.money = 10.0
	assert_false(actions.add_desk(GameConfig.COUNTER))
	assert_eq(state.money, 10.0)


func test_hire_needs_free_desk_and_no_machine() -> void:
	state.money = 1e6
	assert_true(actions.hire(GameConfig.RECEPTION))
	assert_eq(state.station(GameConfig.RECEPTION).staff, 1)
	assert_eq(state.staff_hired, 1)
	assert_false(actions.hire(GameConfig.RECEPTION))
	assert_false(actions.can_hire("general_services/signature"))
	assert_false(actions.hire("nope"))
	state.money = 0.0
	assert_false(actions.hire(GameConfig.COUNTER))


func test_upgrade_until_max_level() -> void:
	state.money = 1e30
	var station := state.station(GameConfig.COUNTER)
	assert_true(actions.upgrade(GameConfig.COUNTER))
	assert_eq(station.level, 2)
	station.level = GameConfig.MAX_STATION_LEVEL
	assert_false(actions.upgrade(GameConfig.COUNTER))
	assert_false(actions.upgrade("nope"))


func test_specialists_only_at_review_stations() -> void:
	state.money = 1e9
	assert_false(actions.can_hire_specialist(GameConfig.RECEPTION))
	for i in GameConfig.MAX_SPECIALISTS:
		assert_true(actions.hire_specialist("general_services/review"))
	assert_false(actions.hire_specialist("general_services/review"))
	assert_eq(state.station("general_services/review").specialists, GameConfig.MAX_SPECIALISTS)
	assert_eq(state.staff_hired, GameConfig.MAX_SPECIALISTS)
	assert_false(actions.hire_specialist("nope"))


func test_supervisors_per_unlocked_department() -> void:
	state.money = 1e9
	assert_false(actions.hire_supervisor("tax_services"))
	assert_false(actions.hire_supervisor("nope"))
	for i in GameConfig.MAX_SUPERVISORS:
		assert_true(actions.hire_supervisor("general_services"))
	assert_false(actions.hire_supervisor("general_services"))
	assert_eq(state.department("general_services").supervisors, GameConfig.MAX_SUPERVISORS)


func test_runners_up_to_limit() -> void:
	state.money = 1e30
	for i in GameConfig.MAX_RUNNERS:
		assert_true(actions.hire_runner())
	assert_false(actions.hire_runner())
	assert_eq(state.runners.size(), GameConfig.MAX_RUNNERS)
	state.runners.clear()
	state.money = 0.0
	assert_false(actions.can_hire_runner())


func test_department_settings() -> void:
	assert_true(actions.set_thoroughness("general_services", 2))
	assert_eq(state.department("general_services").thoroughness, 2)
	assert_false(actions.set_thoroughness("general_services", 3))
	assert_false(actions.set_thoroughness("general_services", -1))
	assert_false(actions.set_thoroughness("nope", 1))
	assert_true(actions.set_prioritize_urgent("general_services", false))
	assert_false(state.department("general_services").prioritize_urgent)
	assert_false(actions.set_prioritize_urgent("nope", false))
	assert_false(actions.set_scan_all("general_services", true))
	assert_false(actions.set_scan_all("nope", true))
	assert_true(actions.set_scan_all("customs", true))
	assert_true(state.department("customs").scan_all)


func test_unlock_department_spends_money() -> void:
	state.building_stage = 1
	state.reputation = 15.0
	state.money = 800.0
	assert_true(actions.unlock_department("tax_services"))
	assert_eq(state.money, 0.0)
	assert_not_null(state.station("tax_services/review"))
	assert_false(actions.unlock_department("tax_services"))


func test_research_purchase() -> void:
	state.money = 1e6
	assert_true(actions.buy_research("briefcase"))
	assert_eq(state.research_level("briefcase"), 1)
	assert_almost_eq(state.money, 1e6 - 150.0, 0.01)
	assert_false(actions.buy_research("nope"))
	assert_false(actions.buy_research("trolleys"))


func test_expand_building() -> void:
	state.money = 2500.0
	assert_false(actions.expand_building())
	state.reputation = 10.0
	assert_true(actions.expand_building())
	assert_eq(state.building_stage, 1)
	assert_eq(state.money, 0.0)


func test_player_input_is_limited() -> void:
	actions.set_player_input(Vector2(3, 4))
	assert_almost_eq(state.player.input.length(), 1.0, 0.0001)
	actions.set_player_input(Vector2(0.2, 0))
	assert_eq(state.player.input, Vector2(0.2, 0))


func test_unlock_block_reasons() -> void:
	assert_eq(Progression.unlock_block_reason(state, "nope"), "unknown")
	assert_eq(Progression.unlock_block_reason(state, "general_services"), "unlocked")
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "space")
	state.building_stage = 1
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "reputation")
	state.reputation = 15.0
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "money")
	state.money = 800.0
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "")


func test_next_locked_department() -> void:
	assert_eq(Progression.next_locked_department(state), "tax_services")
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	assert_eq(Progression.next_locked_department(state), "")


func test_research_block_reasons() -> void:
	assert_eq(Progression.research_block_reason(state, "nope"), "unknown")
	assert_eq(Progression.research_block_reason(state, "trolleys"), "reputation")
	assert_eq(Progression.research_block_reason(state, "briefcase"), "money")
	state.money = 150.0
	assert_eq(Progression.research_block_reason(state, "briefcase"), "")
	state.research["briefcase"] = int(GameConfig.RESEARCH.briefcase.max_level)
	assert_eq(Progression.research_block_reason(state, "briefcase"), "max")


func test_expansion_block_reasons() -> void:
	assert_eq(Progression.expansion_block_reason(state), "reputation")
	state.reputation = 10.0
	assert_eq(Progression.expansion_block_reason(state), "money")
	state.money = 2500.0
	assert_eq(Progression.expansion_block_reason(state), "")
	state.building_stage = GameConfig.BUILDING_STAGES.size() - 1
	assert_eq(Progression.expansion_block_reason(state), "max")


func test_guidance_is_empty_without_work() -> void:
	assert_true(Guidance.next_task(state).is_empty())


func test_guidance_points_to_manual_work() -> void:
	state.station(GameConfig.RECEPTION).inbox.append(_case())
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WORK)
	assert_eq(task.key, GameConfig.RECEPTION)
	assert_eq(task.point, WorldLayout.get_default().work_point(GameConfig.RECEPTION))


func test_guidance_prefers_delivering_carried_files() -> void:
	state.station(GameConfig.RECEPTION).inbox.append(_case())
	state.player.items.append(_case())
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.DROP)
	assert_eq(task.key, "general_services/review")


func test_guidance_skips_full_targets() -> void:
	var review := state.station("general_services/review")
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(_case())
	state.player.items.append(_case())
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.DROP)


func test_guidance_pickups_depend_on_automation() -> void:
	state.station(GameConfig.RECEPTION).outbox.append(_case())
	assert_eq(Guidance.next_task(state).action, Guidance.PICKUP)
	state.add_runner()
	assert_true(Guidance.next_task(state).is_empty())
	state.runners.clear()
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	assert_true(Guidance.next_task(state).is_empty())
	state.research["pneumatic_tubes"] = 0
	for i in Formulas.carry_capacity(state):
		state.player.items.append(_case())
	var review := state.station("general_services/review")
	for i in review.inbox_capacity(state.lobby_capacity()):
		review.inbox.append(_case())
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WORK)
	assert_eq(task.key, review.key)
	assert_ne(task.action, Guidance.PICKUP)


func test_guidance_points_to_unlock_pad() -> void:
	state.building_stage = 1
	state.reputation = 15.0
	state.money = 800.0
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.PAD)
	assert_eq(task.key, "tax_services")


func test_guidance_picks_nearest_option() -> void:
	var layout := WorldLayout.get_default()
	state.station(GameConfig.RECEPTION).inbox.append(_case())
	var counter := state.station(GameConfig.COUNTER)
	var finished := _case()
	finished.step = finished.route.size() - 1
	counter.inbox.append(finished)
	state.player.position = layout.work_point(GameConfig.COUNTER)
	assert_eq(Guidance.next_task(state).key, GameConfig.COUNTER)
	state.player.position = layout.work_point(GameConfig.RECEPTION)
	assert_eq(Guidance.next_task(state).key, GameConfig.RECEPTION)
