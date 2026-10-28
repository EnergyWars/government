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
	assert_null(state.department("nope"))
	assert_null(state.station("nope"))


func test_unlocking_creates_unstaffed_stations_once() -> void:
	state.unlock_department("business_licences")
	assert_eq(state.station("business_licences/review").staff, 0)
	assert_eq(state.station(GameConfig.INSPECTION).staff, 0)
	assert_true(state.station("business_licences/signature").machine)
	assert_eq(state.station("business_licences/signature").staff, 1)
	assert_eq(state.station(GameConfig.RECEPTION).staff, 0)
	var inspection := state.station(GameConfig.INSPECTION)
	inspection.staff = 1
	state.unlock_department("building_permits")
	assert_same(state.station(GameConfig.INSPECTION), inspection)
	assert_eq(state.station(GameConfig.INSPECTION).staff, 1)
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
	assert_eq(state.total_staff(), 2)
	state.unlock_department("tax_services")
	assert_true(state.station("tax_services/signature").machine)
	assert_eq(state.total_staff(), 2)
	assert_eq(state.upgrade_count(), 0)
	assert_eq(state.max_room_speed(), 0)
	state.set_upgrade("briefcase", 2)
	state.set_upgrade("runner_trolleys", 1)
	state.set_upgrade("room_speed", 3, "general_services")
	assert_eq(state.upgrade_count(), 6)
	assert_eq(state.max_room_speed(), 3)
	state.set_upgrade("room_speed", 5, GameConfig.ROOM_HALL)
	assert_eq(state.max_room_speed(), 5)
	assert_true(state.has_upgrade("runner_trolleys"))
	assert_false(state.has_upgrade("pneumatic_tubes"))
	assert_true(state.has_upgrade("room_speed", "general_services"))
	assert_false(state.has_upgrade("room_speed", "tax_services"))
	assert_false(state.has_upgrade("room_speed"))
	assert_eq(state.upgrade_level("room_speed", "general_services"), 3)
	assert_eq(state.upgrade_level("nope"), 0)


func test_team_leads_count_as_staff() -> void:
	state.station("general_services/review").staff = 1
	state.set_upgrade("team_lead", 1, "general_services")
	assert_eq(state.total_staff(), 2)
	state.set_upgrade("team_lead", 1, GameConfig.HALL_INTAKE)
	assert_eq(state.total_staff(), 3)
	state.set_upgrade("lead_focus", 4, GameConfig.HALL_INTAKE)
	assert_eq(state.total_staff(), 3)
	state.set_upgrade("team_lead", 0, "general_services")
	assert_eq(state.total_staff(), 2)


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
	assert_true(state.upgrades.is_empty())
	state.set_upgrade("room_speed", 2, "tax_services")
	assert_eq(state.upgrades.get(GameConfig.upgrade_key("room_speed", "tax_services"), 0), 2)
	assert_eq(state.upgrade_level("room_speed", "tax_services"), 2)
	assert_eq(state.upgrade_level("room_speed", "housing"), 0)
	state.set_upgrade("room_speed", 999, GameConfig.ROOM_HALL)
	assert_eq(state.upgrade_level("room_speed", GameConfig.ROOM_HALL), GameConfig.ROOM_SPEED_LEVELS)
	state.set_upgrade("team_lead", 5, "tax_services")
	assert_eq(state.upgrade_level("team_lead", "tax_services"), 1)


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
	state.set_upgrade("room_speed", 3, "tax_services")
	state.set_upgrade("room_trays", 2, "tax_services")
	state.set_upgrade("team_lead", 1, "tax_services")
	state.lead_patrols["tax_services"] = 12.5
	state.lead_cooldowns["tax_services"] = 90.0
	state.patrols = 4
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
	assert_almost_eq(copy.patrol_left("tax_services"), 12.5, 0.0001)
	assert_almost_eq(copy.patrol_cooldown("tax_services"), 90.0, 0.0001)
	assert_eq(copy.patrols, 4)
	assert_eq(copy.station("tax_services/review").tray_size, GameConfig.TRAY_BASE + 2)
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
	assert_eq(loaded.stations.size(), 4)
	for key in loaded.stations:
		var station := loaded.station(key)
		assert_eq(station.staff, station.desks if station.machine else 0, key)
	assert_eq(GameState.from_dict({}).unlocked_count(), 1)
	assert_eq(GameState.from_dict({"version": GameState.SAVE_VERSION + 1}).station("general_services/review").staff, 0)


func test_patrol_timers_are_restored_only_for_rooms_with_a_team_lead() -> void:
	state.set_upgrade("team_lead", 1, "general_services")
	var data := state.to_dict()
	data.lead_patrols = {"general_services": 999.0, GameConfig.ROOM_HALL: 10.0, "nope": 4.0}
	data.lead_cooldowns = {"general_services": 9999.0, GameConfig.ROOM_HALL: 20.0}
	data.patrols = -4
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.patrol_left("general_services"), GameConfig.LEAD_PATROL_SECONDS)
	assert_eq(loaded.patrol_cooldown("general_services"), float(GameConfig.upgrade("lead_cooldown").base))
	assert_eq(loaded.lead_patrols.size(), 1)
	assert_eq(loaded.lead_cooldowns.size(), 1)
	assert_false(loaded.is_patrolling(GameConfig.ROOM_HALL))
	assert_eq(loaded.patrols, 0)
	data.lead_patrols = "broken"
	data.lead_cooldowns = {"general_services": -3.0}
	data.patrols = 7
	loaded = GameState.from_dict(data)
	assert_true(loaded.lead_patrols.is_empty())
	assert_true(loaded.lead_cooldowns.is_empty())
	assert_eq(loaded.patrols, 7)
	data.erase("lead_patrols")
	data.erase("lead_cooldowns")
	data.erase("patrols")
	loaded = GameState.from_dict(data)
	assert_true(loaded.lead_patrols.is_empty())
	assert_eq(loaded.patrols, 0)


func test_patrol_timers_count_down_and_expire() -> void:
	assert_false(state.is_patrolling("general_services"))
	assert_eq(state.patrol_left("general_services"), 0.0)
	assert_eq(state.patrol_cooldown("general_services"), 0.0)
	state.lead_patrols["general_services"] = 2.0
	state.lead_cooldowns["general_services"] = 5.0
	assert_true(state.is_patrolling("general_services"))
	assert_false(state.is_patrolling(GameConfig.ROOM_HALL))
	state.advance_patrols(1.5)
	assert_almost_eq(state.patrol_left("general_services"), 0.5, 0.0001)
	assert_almost_eq(state.patrol_cooldown("general_services"), 3.5, 0.0001)
	state.advance_patrols(0.5)
	assert_false(state.is_patrolling("general_services"))
	assert_false(state.lead_patrols.has("general_services"))
	assert_almost_eq(state.patrol_cooldown("general_services"), 3.0, 0.0001)
	state.advance_patrols(3.0)
	assert_true(state.lead_cooldowns.is_empty())
	assert_eq(state.patrol_cooldown("general_services"), 0.0)
	state.advance_patrols(1.0)
	assert_true(state.lead_patrols.is_empty())


func test_lead_stations_split_the_hall_counters() -> void:
	assert_eq(state.lead_stations(GameConfig.HALL_INTAKE), [state.station(GameConfig.RECEPTION)] as Array[Station])
	assert_eq(state.lead_stations(GameConfig.HALL_PICKUP), [state.station(GameConfig.COUNTER)] as Array[Station])
	assert_true(state.lead_stations(GameConfig.ROOM_HALL).is_empty())
	assert_eq(state.lead_stations("general_services"), state.room_stations("general_services"))
	assert_true(state.lead_stations("nope").is_empty())


func test_room_stations_follow_the_station_rooms() -> void:
	var hall := state.room_stations(GameConfig.ROOM_HALL)
	assert_eq(hall.size(), 2)
	assert_true(hall.has(state.station(GameConfig.RECEPTION)))
	assert_true(hall.has(state.station(GameConfig.COUNTER)))
	var general := state.room_stations("general_services")
	assert_eq(general.size(), 2)
	assert_true(general.has(state.station("general_services/review")))
	assert_true(general.has(state.station("general_services/signature")))
	assert_true(state.room_stations(GameConfig.ROOM_MAIL).is_empty())
	assert_true(state.room_stations(GameConfig.ROOM_INSPECTION).is_empty())
	assert_true(state.room_stations("nope").is_empty())
	state.unlock_department("business_licences")
	assert_eq(state.room_stations(GameConfig.ROOM_INSPECTION), [state.station(GameConfig.INSPECTION)] as Array[Station])
	assert_eq(state.room_stations(GameConfig.ROOM_MAIL), [state.mailroom()] as Array[Station])
	assert_eq(state.room_stations("business_licences").size(), 2)


func test_room_trays_resize_the_trays_of_their_room() -> void:
	var review := state.station("general_services/review")
	var reception := state.station(GameConfig.RECEPTION)
	assert_eq(review.tray_size, GameConfig.TRAY_BASE)
	assert_eq(review.inbox_capacity(state.lobby_capacity()), GameConfig.TRAY_BASE)
	assert_eq(review.outbox_capacity(), GameConfig.TRAY_BASE)
	state.set_upgrade("room_trays", 4, "general_services")
	assert_eq(review.tray_size, GameConfig.TRAY_BASE + 4)
	assert_eq(review.inbox_capacity(state.lobby_capacity()), GameConfig.TRAY_BASE + 4)
	assert_eq(review.outbox_capacity(), GameConfig.TRAY_BASE + 4)
	assert_eq(state.station("general_services/signature").tray_size, GameConfig.TRAY_BASE + 4)
	assert_eq(reception.tray_size, GameConfig.TRAY_BASE)
	review.add_desk()
	assert_eq(review.outbox_capacity(), GameConfig.TRAY_BASE + 4)
	state.set_upgrade("room_trays", 999, "general_services")
	assert_eq(review.tray_size, GameConfig.TRAY_MAX)
	state.set_upgrade("room_trays", 0, "general_services")
	assert_eq(review.tray_size, GameConfig.TRAY_BASE)


func test_new_and_loaded_stations_get_their_room_trays() -> void:
	state.set_upgrade("room_trays", 3, "tax_services")
	state.set_upgrade("room_trays", 2, GameConfig.ROOM_MAIL)
	state.set_upgrade("room_trays", 5, GameConfig.ROOM_HALL)
	state.unlock_department("tax_services")
	assert_eq(state.station("tax_services/review").tray_size, GameConfig.TRAY_BASE + 3)
	assert_eq(state.station("tax_services/signature").tray_size, GameConfig.TRAY_BASE + 3)
	assert_eq(state.mailroom().tray_size, GameConfig.TRAY_BASE + 2)
	assert_eq(state.mailroom().outbox_capacity(), GameConfig.TRAY_BASE + 2)
	assert_eq(state.station("general_services/review").tray_size, GameConfig.TRAY_BASE)
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.station(GameConfig.COUNTER).tray_size, GameConfig.TRAY_BASE + 5)
	assert_eq(loaded.station("tax_services/review").tray_size, GameConfig.TRAY_BASE + 3)
	assert_eq(loaded.mailroom().tray_size, GameConfig.TRAY_BASE + 2)
