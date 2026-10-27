extends GutTest

var state: GameState


func before_each() -> void:
	state = GameState.create_new(7)


func test_new_game_starts_with_citizen_services() -> void:
	assert_eq(state.money, GameConfig.START_MONEY)
	assert_eq(state.unlocked_count(), 1)
	assert_true(state.department("general_services").unlocked)
	assert_eq(state.stations.size(), 4)
	assert_eq(state.station("general_services/review").staff, 0)
	assert_eq(state.station(GameConfig.RECEPTION).staff, 0)
	assert_eq(state.station(GameConfig.COUNTER).staff, 0)
	assert_false(state.station("general_services/signature").machine)
	assert_eq(state.station("general_services/signature").staff, 0)
	assert_eq(state.player.position, WorldLayout.get_default().player_start())
	assert_true(state.runners.is_empty())
	assert_true(state.upgrades.is_empty())
	assert_true(state.shredder_rooms().is_empty())
	assert_null(state.department("nope"))
	assert_null(state.station("nope"))


func test_unlocking_creates_unstaffed_stations_once() -> void:
	state.unlock_department("business_licences")
	assert_eq(state.station("business_licences/review").staff, 0)
	assert_eq(state.station(GameConfig.INSPECTION).staff, 0)
	assert_true(state.station("business_licences/signature").machine)
	assert_eq(state.station("business_licences/signature").staff, 1)
	assert_eq(state.station(GameConfig.RECEPTION).staff, 0)
	state.station(GameConfig.INSPECTION).level = 3
	state.unlock_department("building_permits")
	assert_eq(state.station(GameConfig.INSPECTION).level, 3)
	var count := state.stations.size()
	state.unlock_department("building_permits")
	state.unlock_department("nope")
	assert_eq(state.stations.size(), count)


func test_departments_using_shared_stations() -> void:
	assert_eq(state.departments_using(GameConfig.RECEPTION).size(), 1)
	state.unlock_department("housing")
	assert_eq(state.departments_using("general_services/review").size(), 2)
	state.unlock_department("customs")
	assert_eq(state.departments_using(GameConfig.RECEPTION).size(), 2)
	assert_eq(state.departments_using(GameConfig.INSPECTION).size(), 1)


func test_ordered_station_keys_are_unique() -> void:
	var first := state.ordered_station_keys()
	assert_eq(first[0], GameConfig.RECEPTION)
	state.unlock_department("housing")
	var keys := state.ordered_station_keys()
	assert_eq(keys[0], GameConfig.MAILROOM)
	assert_eq(keys[1], GameConfig.RECEPTION)
	for key in keys:
		assert_eq(keys.count(key), 1, key)
	assert_eq(keys.size(), state.stations.size())


func test_stage_helpers() -> void:
	assert_eq(state.lobby_capacity(), int(GameConfig.BUILDING_STAGES[0].lobby))
	assert_eq(state.max_desks(), int(GameConfig.BUILDING_STAGES[0].max_desks))
	state.building_stage = 2
	assert_eq(state.stage_config().id, GameConfig.BUILDING_STAGES[2].id)
	assert_eq(state.lobby_capacity(), int(GameConfig.BUILDING_STAGES[2].lobby))


func test_counting_helpers() -> void:
	state.station("general_services/review").staff = 1
	assert_eq(state.total_staff(), 1)
	state.add_runner()
	state.station("general_services/review").add_specialist()
	state.department("general_services").supervisors = 1
	assert_eq(state.total_staff(), 4)
	state.station(GameConfig.COUNTER).level = 5
	assert_eq(state.max_station_level(), 5)
	assert_eq(state.upgrade_count(), 0)
	state.set_upgrade("briefcase", 2)
	state.set_upgrade("runner_trolleys", 1)
	state.set_upgrade("office_equipment", 3, "general_services")
	assert_eq(state.upgrade_count(), 6)
	assert_true(state.has_upgrade("runner_trolleys"))
	assert_false(state.has_upgrade("pneumatic_tubes"))
	assert_true(state.has_upgrade("office_equipment", "general_services"))
	assert_false(state.has_upgrade("office_equipment", "tax_services"))
	assert_false(state.has_upgrade("office_equipment"))
	assert_eq(state.upgrade_level("office_equipment", "general_services"), 3)
	assert_eq(state.upgrade_level("nope"), 0)


func test_set_upgrade_clamps_and_removes_levels() -> void:
	var limit := int(GameConfig.upgrade("briefcase").max)
	state.set_upgrade("briefcase", limit + 50)
	assert_eq(state.upgrade_level("briefcase"), limit)
	state.set_upgrade("briefcase", 0)
	assert_false(state.upgrades.has("briefcase"))
	assert_eq(state.upgrade_level("briefcase"), 0)
	state.set_upgrade("briefcase", -3)
	assert_false(state.upgrades.has("briefcase"))
	state.set_upgrade("nope", 5)
	assert_false(state.upgrades.has("nope"))
	state.set_upgrade("office_equipment", 2, "tax_services")
	assert_eq(state.upgrades.get(GameConfig.upgrade_key("office_equipment", "tax_services"), 0), 2)
	assert_eq(state.upgrade_level("office_equipment", "tax_services"), 2)
	assert_eq(state.upgrade_level("office_equipment", "housing"), 0)


func test_shredder_rooms_need_an_open_department() -> void:
	state.set_upgrade("shredder", 1, "general_services")
	state.set_upgrade("shredder", 4, "tax_services")
	assert_eq(state.shredder_rooms(), ["general_services"] as Array[String])
	state.unlock_department("tax_services")
	assert_eq(state.shredder_rooms(), ["general_services", "tax_services"] as Array[String])
	state.set_upgrade("shredder", 0, "general_services")
	assert_eq(state.shredder_rooms(), ["tax_services"] as Array[String])


func test_money_and_reputation() -> void:
	state.add_reputation(-10.0)
	assert_eq(state.reputation, 0.0)
	state.add_reputation(2.5)
	assert_eq(state.reputation, 2.5)
	state.earn(100.0)
	state.earn(-20.0)
	assert_eq(state.money_earned, 100.0)
	assert_true(state.spend(state.money))
	assert_eq(state.money, 0.0)
	assert_false(state.spend(1.0))
	assert_false(state.can_afford(1.0))


func test_runners_and_carried_cases() -> void:
	var first := state.add_runner()
	var second := state.add_runner()
	assert_ne(first.position, second.position)
	first.items.append(CaseFile.new("general_services"))
	state.player.items.append(CaseFile.new("general_services"))
	assert_eq(state.carried_cases().size(), 2)


func test_roundtrip_keeps_everything() -> void:
	state.money = 999.0
	state.reputation = 12.0
	state.building_stage = 1
	state.ensure_mailroom()
	state.goal_index = 4
	state.unlock_department("tax_services")
	state.set_upgrade("briefcase", 2)
	state.set_upgrade("office_equipment", 3, "tax_services")
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_MAIL)
	state.player.position = Vector2(300, 2000)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	state.player.items.append(case_file)
	state.station(GameConfig.RECEPTION).inbox.append(case_file)
	state.add_runner()
	state.event_id = "printer_jam"
	state.event_time_left = 10.0
	state.cases_completed = 50
	state.contraband_seized = 2
	state.rng.randf()
	var data := state.to_dict()
	var copy := GameState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(data))
	assert_eq(copy.upgrades, state.upgrades)
	assert_eq(copy.rng.randf(), state.rng.randf())


func test_load_raises_the_stage_to_the_opened_departments() -> void:
	for dept_id in GameConfig.department_ids().slice(0, 4):
		state.departments[dept_id].unlocked = true
	var data := state.to_dict()
	data.building_stage = 0
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.building_stage, GameConfig.stage_for_departments(4))
	assert_not_null(loaded.mailroom())


func test_load_keeps_a_bought_stage_above_the_departments() -> void:
	var data := state.to_dict()
	data.building_stage = 3
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.building_stage, 3)
	assert_eq(loaded.max_desks(), int(GameConfig.BUILDING_STAGES[3].max_desks))


func test_load_validates_input() -> void:
	var data := state.to_dict()
	data.money = -5.0
	data.reputation = -1.0
	data.building_stage = 99
	data.goal_index = 999
	data.event_id = "nope"
	data.upgrades = {"briefcase": 999, "nope": 1, "work_ethic": -2}
	data.departments = {"general_services": {"id": "general_services", "unlocked": false}, "nope": {}}
	data.stations = {"bad/kind": {"key": "bad/kind"}, "x": {"key": GameConfig.COUNTER}}
	data.player = {"x": -999.0, "y": -999.0}
	var runners: Array = []
	for i in GameConfig.MAX_RUNNERS + 3:
		runners.append({})
	runners.append("junk")
	data.runners = runners
	data.erase("rng_seed")
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.money, 0.0)
	assert_eq(loaded.reputation, 0.0)
	assert_eq(loaded.building_stage, GameConfig.BUILDING_STAGES.size() - 1)
	assert_eq(loaded.goal_index, GameConfig.GOALS.size())
	assert_eq(loaded.event_id, "")
	assert_eq(loaded.upgrade_level("briefcase"), int(GameConfig.upgrade("briefcase").max))
	assert_eq(loaded.upgrades.size(), 1)
	assert_true(loaded.department("general_services").unlocked)
	assert_eq(loaded.stations.size(), 5)
	assert_not_null(loaded.mailroom())
	assert_eq(loaded.station(GameConfig.COUNTER).staff, 0)
	assert_eq(loaded.player.position, Vector2(WorldLayout.MARGIN, WorldLayout.MARGIN))
	assert_eq(loaded.runners.size(), GameConfig.MAX_RUNNERS)


func test_old_save_version_starts_fresh_game() -> void:
	var loaded := GameState.from_dict({"version": 1, "money": 1e9})
	assert_eq(loaded.money, GameConfig.START_MONEY)
	assert_eq(loaded.station("general_services/review").staff, 1)
	assert_eq(GameState.from_dict({}).unlocked_count(), 1)
