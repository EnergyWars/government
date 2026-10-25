extends GutTest


func _legacy(extra: Dictionary = {}) -> Dictionary:
	var data := {
		"version": GameState.LEGACY_SAVE_VERSION,
		"money": 500.0,
		"departments": {"general_services": {"id": "general_services", "unlocked": true}},
		"tutorial_step": Tutorial.FINISHED,
	}
	data.merge(extra, true)
	return data


func _upgrades(extra: Dictionary) -> Dictionary:
	return SaveMigration.migrate_v2(_legacy(extra)).upgrades


func test_result_is_current_version_without_legacy_keys() -> void:
	var result := SaveMigration.migrate_v2(_legacy({"research": {"briefcase": 1}, "waiting_level": 1, "seating_level": 1, "ticket_machine_level": 1, "ticket_display_level": 1, "complaint_clerk_level": 1, "complaint_box_level": 1}))
	assert_eq(int(result.version), GameState.SAVE_VERSION)
	assert_true(result.has("upgrades"))
	for key in SaveMigration.REMOVED_KEYS:
		assert_false(result.has(key), key)
	assert_eq(float(result.money), 500.0)


func test_input_is_not_modified() -> void:
	var data := _legacy({"research": {"briefcase": 1}, "tube_levels": {"a>b": 2}})
	var copy := data.duplicate(true)
	SaveMigration.migrate_v2(data)
	assert_eq(data, copy)


func test_scaled_research_levels() -> void:
	var upgrades := _upgrades({"research": {"briefcase": 2, "coffee": 1, "quality_training": 3, "ai_classification": 1, "kitchen": 3}})
	assert_eq(int(upgrades.briefcase), 4)
	assert_eq(int(upgrades.coffee), 35)
	assert_eq(int(upgrades.quality_training), roundi(3 * 28.6))
	assert_eq(int(upgrades.ai_classification), 99)
	assert_eq(int(upgrades.kitchen), 180)


func test_migrated_kitchen_keeps_the_old_chat_shift() -> void:
	for old_level in [1, 2, 3]:
		var level := int(_upgrades({"research": {"kitchen": old_level}}).kitchen)
		assert_almost_eq(1.0 - Formulas.track_value("kitchen", level), 0.27 * old_level, 0.0001, str(old_level))
	assert_gt(Formulas.track_value("kitchen", int(GameConfig.upgrade("kitchen").max)), 0.0)


func test_stepped_research_levels_clamp_to_last_step() -> void:
	var upgrades := _upgrades({"research": {"shredder_service": 2, "climate_control": 9, "wake_service": 5, "mediation": 1, "complaint_tube": 3}})
	assert_eq(int(upgrades.shredder_service), 47)
	assert_eq(int(upgrades.climate_control), 60)
	assert_eq(int(upgrades.wake_service), 135)
	assert_eq(int(upgrades.mediation), 1)
	assert_eq(int(upgrades.complaint_tube), 55)


func test_split_and_derived_research() -> void:
	var upgrades := _upgrades({"research": {"trolleys": 3, "coffee_machine": 2, "intern_training": 1}})
	assert_eq(int(upgrades.runner_trolleys), 3)
	assert_eq(int(upgrades.collector_carts), 3)
	assert_eq(int(upgrades.coffee_machine), 44)
	assert_eq(int(upgrades.espresso), 100)
	assert_eq(int(upgrades.intern_training), 1)
	assert_eq(int(upgrades.intern_resilience), 19)
	assert_false(upgrades.has("trolleys"))


func test_unknown_and_empty_research_is_dropped() -> void:
	var upgrades := _upgrades({"research": {"nope": 5, "briefcase": 0, "coffee": -2}})
	assert_true(upgrades.is_empty())
	assert_true(_upgrades({"research": "broken"}).is_empty())


func test_hall_levels_become_tracks() -> void:
	var upgrades := _upgrades({"waiting_level": 2, "seating_level": 3, "ticket_machine_level": 2, "ticket_display_level": 1})
	assert_eq(int(upgrades.waiting_places), 2 * SaveMigration.WAITING_SCALE)
	assert_eq(int(upgrades.standing_places), 2 * SaveMigration.WAITING_SCALE)
	assert_eq(int(upgrades.seating), SaveMigration.seats_for_level(3))
	assert_eq(int(upgrades.ticket_speed), roundi(2 * SaveMigration.TICKET_SCALE))
	assert_eq(int(upgrades.ticket_call_speed), roundi(SaveMigration.TICKET_SCALE))


func test_complaint_levels_become_tracks() -> void:
	var upgrades := _upgrades({"complaint_box_level": 1, "research": {"complaint_desk": 2}, "complaint_clerk_level": 3})
	assert_eq(int(upgrades.complaint_box), 2 * SaveMigration.BOX_SCALE)
	assert_eq(int(upgrades.complaint_clerk), SaveMigration.CLERK_STEPS[3])
	var capped := _upgrades({"complaint_clerk_level": 99})
	assert_eq(int(capped.complaint_clerk), SaveMigration.CLERK_STEPS[SaveMigration.CLERK_STEPS.size() - 1])


func test_seats_for_level() -> void:
	assert_eq(SaveMigration.seats_for_level(0), 0)
	assert_eq(SaveMigration.seats_for_level(-3), 0)
	assert_eq(SaveMigration.seats_for_level(1), 3)
	assert_eq(SaveMigration.seats_for_level(3), 12)


func test_legacy_tubes_connect_unlocked_departments() -> void:
	var data := _legacy({
		"research": {"pneumatic_tubes": 1},
		"departments": {
			"general_services": {"unlocked": true},
			"business_licences": {"unlocked": true},
			"tax_services": {"unlocked": false, "tube": true},
		},
	})
	var result := SaveMigration.migrate_v2(data)
	var upgrades: Dictionary = result.upgrades
	assert_eq(int(upgrades.pneumatic_tubes), 1)
	assert_eq(int(upgrades.large_capsules), 1)
	for room_id in ["general_services", "business_licences", GameConfig.ROOM_HALL, GameConfig.ROOM_MAIL, GameConfig.ROOM_INSPECTION]:
		assert_eq(int(upgrades.get(GameConfig.upgrade_key("tube_station", room_id), 0)), 1, room_id)
	assert_false(upgrades.has(GameConfig.upgrade_key("tube_station", "tax_services")))
	for dept_id in result.departments:
		assert_false(result.departments[dept_id].has("tube"), dept_id)


func test_department_tube_flag_overrides_legacy_research() -> void:
	var upgrades := _upgrades({"departments": {"general_services": {"unlocked": true, "tube": true}, "housing": {"unlocked": true, "tube": false}}})
	assert_eq(int(upgrades.pneumatic_tubes), 1)
	assert_true(upgrades.has(GameConfig.upgrade_key("tube_station", "general_services")))
	assert_false(upgrades.has(GameConfig.upgrade_key("tube_station", "housing")))
	assert_false(upgrades.has(GameConfig.upgrade_key("tube_station", GameConfig.ROOM_INSPECTION)))


func test_no_connected_department_means_no_tubes() -> void:
	var upgrades := _upgrades({"research": {"pneumatic_tubes": 0}, "departments": {"general_services": {"unlocked": true, "tube": false}, "nope": {"unlocked": true, "tube": true}}})
	assert_false(upgrades.has("pneumatic_tubes"))
	assert_false(upgrades.has("large_capsules"))


func test_station_storage_and_training_are_scaled() -> void:
	var data := _legacy({"stations": {
		GameConfig.MAILROOM: {"key": GameConfig.MAILROOM, "storage_level": 3},
		"general_services/review": {"key": "general_services/review", "moods": [{"training": {"skill": 2, "calm": 1}}, "broken"]},
		GameConfig.RECEPTION: {"key": GameConfig.RECEPTION, "moods": "broken"},
	}})
	var stations: Dictionary = SaveMigration.migrate_v2(data).stations
	assert_eq(int(stations[GameConfig.MAILROOM].storage_level), 3 * SaveMigration.STORAGE_SCALE)
	var training: Dictionary = stations["general_services/review"].moods[0].training
	assert_eq(int(training.skill), 2 * SaveMigration.TRAINING_SCALE)
	assert_eq(int(training.calm), SaveMigration.TRAINING_SCALE)
	assert_false(stations["general_services/review"].has("storage_level"))


func test_tube_levels_are_scaled() -> void:
	var result := SaveMigration.migrate_v2(_legacy({"tube_levels": {"a>b": 3, "c>d": 0}}))
	assert_eq(int(result.tube_levels["a>b"]), 3 * SaveMigration.TUBE_LEVEL_SCALE)
	assert_eq(int(result.tube_levels["c>d"]), 0)


func test_tutorial_steps_are_renamed() -> void:
	assert_eq(SaveMigration.tutorial_step(0), Tutorial.index_of("welcome"))
	assert_eq(SaveMigration.tutorial_step(SaveMigration.LEGACY_TUTORIAL.find("team_open")), Tutorial.index_of("upgrades_open"))
	assert_eq(SaveMigration.tutorial_step(SaveMigration.LEGACY_TUTORIAL.find("department_open")), Tutorial.index_of("spot_open"))
	assert_eq(SaveMigration.tutorial_step(SaveMigration.LEGACY_TUTORIAL.find("research_info")), Tutorial.index_of("spots_info"))
	assert_eq(SaveMigration.tutorial_step(SaveMigration.LEGACY_TUTORIAL.find("departments_info")), Tutorial.index_of("expand_info"))
	assert_eq(SaveMigration.tutorial_step(SaveMigration.LEGACY_TUTORIAL.find("finish")), Tutorial.index_of("finish"))
	assert_eq(SaveMigration.tutorial_step(Tutorial.FINISHED), Tutorial.FINISHED)
	assert_eq(SaveMigration.tutorial_step(SaveMigration.LEGACY_TUTORIAL.size()), Tutorial.FINISHED)


func test_every_legacy_step_maps_to_a_current_step() -> void:
	for index in SaveMigration.LEGACY_TUTORIAL.size():
		assert_ne(SaveMigration.tutorial_step(index), Tutorial.FINISHED, SaveMigration.LEGACY_TUTORIAL[index])


func test_every_migrated_track_exists() -> void:
	var research := {}
	for research_id: String in SaveMigration.LEVEL_SCALES:
		research[research_id] = 3
	for research_id: String in SaveMigration.LEVEL_STEPS:
		research[research_id] = 3
	for research_id: String in SaveMigration.SPLITS:
		research[research_id] = 3
	var upgrades := _upgrades({"research": research, "waiting_level": 4, "seating_level": 4, "ticket_machine_level": 4, "ticket_display_level": 4, "complaint_clerk_level": 4, "complaint_box_level": 4, "departments": {"general_services": {"unlocked": true, "tube": true}}})
	for key: String in upgrades:
		assert_false(GameConfig.upgrade(key.get_slice("@", 0)).is_empty(), key)


func test_game_state_loads_legacy_saves() -> void:
	var state := GameState.from_dict(_legacy({"research": {"briefcase": 2, "pneumatic_tubes": 1}, "waiting_level": 1, "complaint_clerk_level": 1}))
	assert_eq(state.upgrade_level("briefcase"), 4)
	assert_eq(state.upgrade_level("waiting_places"), SaveMigration.WAITING_SCALE)
	assert_eq(state.upgrade_level("complaint_clerk"), SaveMigration.CLERK_STEPS[1])
	assert_true(state.has_tube_station("general_services"))
	assert_true(state.has_tube_station(GameConfig.ROOM_HALL))
	assert_true(state.department("general_services").unlocked)
	assert_eq(state.money, 500.0)


func test_migrated_levels_are_capped_on_load() -> void:
	var state := GameState.from_dict(_legacy({"research": {"ai_classification": 50}}))
	assert_eq(state.upgrade_level("ai_classification"), int(GameConfig.upgrade("ai_classification").max))


func test_current_save_round_trips_upgrades() -> void:
	var state := GameState.create_new(3)
	state.set_upgrade("briefcase", 7)
	state.set_upgrade("office_equipment", 4, "general_services")
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.upgrades, state.upgrades)


func test_invalid_upgrade_keys_are_dropped_on_load() -> void:
	var data := GameState.create_new(3).to_dict()
	data.upgrades = {"nope": 3, "briefcase@hall": 2, "office_equipment": 2, "office_equipment@hall": 2, "shredder@customs": 1, "coffee": 4}
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.upgrades, {"coffee": 4})


func test_unknown_versions_start_a_new_game() -> void:
	var loaded := GameState.from_dict({"version": 1, "money": 9999.0})
	assert_eq(loaded.money, GameConfig.START_MONEY)
	assert_true(loaded.upgrades.is_empty())
	assert_true(loaded.department("general_services").unlocked)
