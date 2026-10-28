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
	assert_almost_eq(state.money, 1e6 - 120.0 * Formulas.early_discount(0), 0.01)


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
	state.unlock_department("tax_services")
	assert_false(actions.can_hire("tax_services/signature"))
	assert_false(actions.hire("nope"))
	state.money = 0.0
	assert_false(actions.hire(GameConfig.COUNTER))


func test_room_speed_rushes_only_the_stations_of_its_room() -> void:
	state.money = 1e9
	var reception := state.station(GameConfig.RECEPTION)
	var counter := state.station(GameConfig.COUNTER)
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	var cost := Formulas.track_cost("room_speed", 0, GameConfig.ROOM_HALL)
	assert_true(actions.buy_upgrade("room_speed", GameConfig.ROOM_HALL))
	assert_eq(state.upgrade_level("room_speed", GameConfig.ROOM_HALL), 1)
	assert_almost_eq(state.money, 1e9 - cost, 0.01)
	assert_eq(reception.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(counter.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(review.rush, 0.0)
	assert_eq(signature.rush, 0.0)
	assert_eq(state.staff_hired, 0)
	assert_true(actions.buy_upgrade("room_speed", "general_services", 3))
	assert_eq(state.upgrade_level("room_speed", "general_services"), 3)
	assert_eq(review.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(signature.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	state.set_upgrade("room_speed", GameConfig.ROOM_SPEED_LEVELS, "general_services")
	review.rush = 0.0
	assert_false(actions.buy_upgrade("room_speed", "general_services"))
	assert_eq(review.rush, 0.0)
	assert_false(actions.buy_upgrade("room_speed"))
	assert_false(actions.buy_upgrade("room_speed", "tax_services"))


func test_team_lead_is_hired_once_per_room_and_counts_as_staff() -> void:
	state.money = 1e9
	assert_eq(Progression.upgrade_block_reason(state, "lead_focus", "general_services"), "requires")
	assert_false(actions.buy_upgrade("lead_focus", "general_services"))
	assert_true(actions.buy_upgrade("team_lead", "general_services"))
	assert_true(state.has_upgrade("team_lead", "general_services"))
	assert_eq(state.staff_hired, 1)
	assert_false(actions.buy_upgrade("team_lead", "general_services"))
	assert_eq(state.staff_hired, 1)
	assert_eq(Progression.upgrade_block_reason(state, "lead_focus", GameConfig.HALL_INTAKE), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "lead_focus", GameConfig.ROOM_HALL), "unknown")
	assert_true(actions.buy_upgrade("lead_focus", "general_services", 2))
	assert_eq(state.upgrade_level("lead_focus", "general_services"), 2)
	assert_eq(state.staff_hired, 1)
	assert_false(actions.buy_upgrade("team_lead", "tax_services"))
	assert_false(actions.buy_upgrade("team_lead"))
	assert_false(actions.buy_upgrade("team_lead", GameConfig.ROOM_HALL))
	assert_true(actions.buy_upgrade("team_lead", GameConfig.HALL_INTAKE))
	assert_true(actions.buy_upgrade("team_lead", GameConfig.HALL_PICKUP))
	assert_eq(state.staff_hired, 3)
	assert_eq(Formulas.team_lead_count(state), 3)


func test_patrol_actions_delegate_to_the_simulation() -> void:
	assert_false(actions.can_patrol("general_services"))
	assert_false(actions.start_patrol("general_services"))
	assert_eq(state.patrols, 0)
	state.set_upgrade("team_lead", 1, "general_services")
	assert_eq(actions.can_patrol("general_services"), sim.can_patrol("general_services"))
	assert_true(actions.can_patrol("general_services"))
	assert_true(actions.start_patrol("general_services"))
	assert_true(state.is_patrolling("general_services"))
	assert_eq(state.patrols, 1)
	assert_false(actions.can_patrol("general_services"))
	assert_false(actions.start_patrol("general_services"))
	assert_eq(state.patrols, 1)
	assert_false(actions.can_patrol(GameConfig.HALL_INTAKE))


func test_runners_up_to_limit() -> void:
	state.money = 1e30
	for i in GameConfig.MAX_RUNNERS:
		assert_true(actions.hire_runner())
	assert_false(actions.hire_runner())
	assert_eq(state.runners.size(), GameConfig.MAX_RUNNERS)
	state.runners.clear()
	state.money = 0.0
	assert_false(actions.can_hire_runner())


func test_signature_part_has_its_own_work_mode() -> void:
	var dept := state.department("general_services")
	assert_true(dept.has_signature_part())
	assert_eq(dept.signature_thoroughness, -1)
	assert_true(actions.set_thoroughness("general_services", 2))
	assert_eq(dept.signature_mode(), 2)
	assert_true(actions.set_signature_thoroughness("general_services", 0))
	assert_eq(dept.signature_mode(), 0)
	assert_eq(dept.thoroughness, 2)
	assert_false(actions.set_signature_thoroughness("general_services", 3))
	assert_false(actions.set_signature_thoroughness("general_services", -1))
	assert_false(actions.set_signature_thoroughness("nope", 1))
	state.unlock_department("tax_services")
	assert_false(state.department("tax_services").has_signature_part())
	assert_false(actions.set_signature_thoroughness("tax_services", 1))


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
	state.reputation = float(GameConfig.department("tax_services").unlock_reputation)
	state.money = 800.0
	assert_true(actions.unlock_department("tax_services"))
	assert_eq(state.money, 0.0)
	assert_eq(state.building_stage, 1)
	assert_not_null(state.station("tax_services/review"))
	assert_false(actions.unlock_department("tax_services"))


func test_upgrade_purchase() -> void:
	state.money = 1e6
	var cost := Formulas.track_cost("briefcase", 0)
	assert_true(actions.buy_upgrade("briefcase"))
	assert_eq(state.upgrade_level("briefcase"), 1)
	assert_almost_eq(state.money, 1e6 - cost, 0.01)
	assert_false(actions.buy_upgrade("nope"))
	assert_false(actions.buy_upgrade("runner_trolleys"))
	assert_eq(state.upgrade_level("runner_trolleys"), 0)
	assert_false(actions.buy_upgrade("work_ethic", "", 0))
	assert_eq(state.upgrade_level("work_ethic"), 0)


func test_upgrades_can_be_bought_in_bulk() -> void:
	state.money = 1e6
	var cost := Formulas.track_bulk_cost("briefcase", 0, 5)
	assert_true(actions.buy_upgrade("briefcase", "", 5))
	assert_eq(state.upgrade_level("briefcase"), 5)
	assert_almost_eq(state.money, 1e6 - cost, 0.01)
	var limit := int(GameConfig.upgrade("briefcase").max)
	var money := state.money
	assert_false(actions.buy_upgrade("briefcase", "", limit))
	assert_eq(state.upgrade_level("briefcase"), 5)
	assert_eq(state.money, money)
	state.money = 1e30
	assert_true(actions.buy_upgrade("briefcase", "", limit * 2))
	assert_eq(state.upgrade_level("briefcase"), limit)
	assert_false(actions.buy_upgrade("briefcase"))


func test_room_upgrades_need_an_open_room() -> void:
	state.money = 1e9
	assert_false(actions.buy_upgrade("room_speed"))
	assert_false(actions.buy_upgrade("briefcase", "general_services"))
	assert_false(actions.buy_upgrade("room_speed", "tax_services"))
	assert_false(actions.buy_upgrade("room_speed", GameConfig.ROOM_PLAYER))
	assert_false(actions.buy_upgrade("shredder", "general_services"))
	var cost := Formulas.track_cost("room_speed", 0, "general_services")
	assert_true(actions.buy_upgrade("room_speed", "general_services"))
	assert_eq(state.upgrade_level("room_speed", "general_services"), 1)
	assert_eq(state.upgrade_level("room_speed"), 0)
	assert_almost_eq(state.money, 1e9 - cost, 0.01)
	state.reputation = float(GameConfig.department("tax_services").unlock_reputation)
	assert_true(actions.unlock_department("tax_services"))
	assert_true(actions.buy_upgrade("room_speed", "tax_services"))
	assert_true(actions.buy_upgrade("room_trays", "tax_services"))
	assert_eq(state.upgrade_level("room_trays", "tax_services"), 1)


func test_upgrades_need_their_requirements() -> void:
	state.money = 1e12
	state.reputation = 1e6
	assert_false(actions.buy_upgrade("tube_capacity"))
	assert_false(actions.buy_upgrade("tube_station", GameConfig.ROOM_HALL))
	assert_true(actions.buy_upgrade("pneumatic_tubes"))
	assert_false(actions.buy_upgrade("pneumatic_tubes"))
	assert_true(actions.buy_upgrade("tube_station", GameConfig.ROOM_HALL))
	assert_true(actions.buy_upgrade("tube_capacity"))
	assert_true(state.has_tube_station(GameConfig.ROOM_HALL))
	assert_false(actions.buy_upgrade("tube_station", GameConfig.ROOM_MAIL))
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	assert_true(actions.buy_upgrade("tube_station", GameConfig.ROOM_MAIL))
	assert_true(state.has_tube_station(GameConfig.ROOM_MAIL))


func test_opening_departments_expands_the_building_implicitly() -> void:
	state.money = 1e12
	state.reputation = 1e6
	assert_eq(state.building_stage, 0)
	assert_null(state.mailroom())
	var expected := [0, 1, 1, 2, 2, 3, 3, 4]
	var ids := GameConfig.department_ids()
	for index in range(1, ids.size()):
		assert_true(actions.unlock_department(ids[index]), ids[index])
		assert_eq(state.building_stage, expected[index], ids[index])
	assert_not_null(state.mailroom())
	assert_eq(state.max_desks(), int(GameConfig.BUILDING_STAGES[-1].max_desks))


func test_opening_departments_never_lowers_a_bought_stage() -> void:
	state.building_stage = 3
	state.unlock_department("tax_services")
	assert_eq(state.building_stage, 3)


func test_player_input_is_limited() -> void:
	actions.set_player_input(Vector2(3, 4))
	assert_almost_eq(state.player.input.length(), 1.0, 0.0001)
	actions.set_player_input(Vector2(0.2, 0))
	assert_eq(state.player.input, Vector2(0.2, 0))


func test_unlock_block_reasons() -> void:
	assert_eq(Progression.unlock_block_reason(state, "nope"), "unknown")
	assert_eq(Progression.unlock_block_reason(state, "general_services"), "unlocked")
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "reputation")
	state.reputation = float(GameConfig.department("tax_services").unlock_reputation)
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "money")
	state.money = 800.0
	assert_eq(Progression.unlock_block_reason(state, "tax_services"), "")


func test_next_locked_department() -> void:
	assert_eq(Progression.next_locked_department(state), "tax_services")
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	assert_eq(Progression.next_locked_department(state), "")


func test_upgrade_block_reasons() -> void:
	assert_eq(Progression.upgrade_block_reason(state, "nope"), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "office_equipment", "general_services"), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "room_speed"), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "room_speed", GameConfig.ROOM_PLAYER), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "briefcase", "general_services"), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "shredder", "general_services"), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "lead_calm", GameConfig.ROOM_HALL), "unknown")
	assert_eq(Progression.upgrade_block_reason(state, "room_speed", "tax_services"), "room")
	assert_eq(Progression.upgrade_block_reason(state, "room_speed", GameConfig.ROOM_MAIL), "room")
	assert_eq(Progression.upgrade_block_reason(state, "registered_mail"), "room")
	assert_eq(Progression.upgrade_block_reason(state, "lead_breaks", "general_services"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "tube_station", GameConfig.ROOM_INSPECTION), "room")
	state.money = 0.0
	assert_eq(Progression.upgrade_block_reason(state, "ticket_speed"), "money")
	assert_eq(Progression.upgrade_block_reason(state, "tube_capacity"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "runner_trolleys"), "reputation")
	assert_eq(Progression.upgrade_block_reason(state, "briefcase"), "money")
	state.money = Formulas.track_cost("briefcase", 0)
	assert_eq(Progression.upgrade_block_reason(state, "briefcase"), "")
	assert_eq(Progression.upgrade_block_reason(state, "briefcase", "", 2), "money")
	state.money = Formulas.track_bulk_cost("briefcase", 0, 2)
	assert_eq(Progression.upgrade_block_reason(state, "briefcase", "", 2), "")
	assert_eq(Progression.upgrade_block_reason(state, "team_lead", "general_services"), "money")
	state.set_upgrade("briefcase", int(GameConfig.upgrade("briefcase").max))
	assert_eq(Progression.upgrade_block_reason(state, "briefcase"), "max")
	assert_eq(Progression.upgrade_block_reason(state, "briefcase", "", 5), "max")


func test_upgrade_block_reasons_check_requirements_before_reputation() -> void:
	assert_eq(Progression.upgrade_block_reason(state, "large_capsules"), "requires")
	state.set_upgrade("pneumatic_tubes", 1)
	assert_eq(Progression.upgrade_block_reason(state, "large_capsules"), "reputation")
	state.reputation = float(GameConfig.upgrade("large_capsules").reputation)
	assert_eq(Progression.upgrade_block_reason(state, "large_capsules"), "money")
	state.reputation = 0.0
	state.reputation_peak = float(GameConfig.upgrade("large_capsules").reputation)
	assert_eq(Progression.upgrade_block_reason(state, "large_capsules"), "money")
	state.money = Formulas.track_cost("large_capsules", 0)
	assert_eq(Progression.upgrade_block_reason(state, "large_capsules"), "")


func test_room_availability() -> void:
	assert_true(Progression.room_available(state, ""))
	for room_id in GameConfig.SERVICE_ROOMS:
		if room_id != GameConfig.ROOM_MAIL and room_id != GameConfig.ROOM_INSPECTION:
			assert_true(Progression.room_available(state, room_id), room_id)
	assert_false(Progression.room_available(state, GameConfig.ROOM_MAIL))
	assert_false(Progression.room_available(state, GameConfig.ROOM_INSPECTION))
	assert_true(Progression.room_available(state, "general_services"))
	assert_false(Progression.room_available(state, "tax_services"))
	assert_false(Progression.room_available(state, "nope"))
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	assert_true(Progression.room_available(state, GameConfig.ROOM_MAIL))
	state.unlock_department("business_licences")
	assert_true(Progression.room_available(state, "business_licences"))
	assert_true(Progression.room_available(state, GameConfig.ROOM_INSPECTION))


func test_guidance_is_empty_without_work() -> void:
	assert_true(Guidance.next_task(state).is_empty())


func test_guidance_points_to_manual_work() -> void:
	state.station(GameConfig.RECEPTION).inbox.append(_case())
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.WORK)
	assert_eq(task.key, GameConfig.RECEPTION)
	assert_eq(task.point, WorldLayout.get_default().desk_work_point(GameConfig.RECEPTION, 0))


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
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	assert_eq(Guidance.next_task(state).action, Guidance.PICKUP)
	state.set_upgrade("tube_station", 1, "general_services")
	assert_true(Guidance.next_task(state).is_empty())
	state.set_upgrade("pneumatic_tubes", 0)
	assert_eq(Guidance.next_task(state).action, Guidance.PICKUP)
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
	state.reputation = float(GameConfig.department("tax_services").unlock_reputation)
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
	state.player.position = layout.desk_work_point(GameConfig.COUNTER, 0)
	assert_eq(Guidance.next_task(state).key, GameConfig.COUNTER)
	state.player.position = layout.desk_work_point(GameConfig.RECEPTION, 0)
	assert_eq(Guidance.next_task(state).key, GameConfig.RECEPTION)
