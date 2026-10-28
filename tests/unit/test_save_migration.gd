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


func test_result_is_previous_version_without_legacy_keys() -> void:
	var result := SaveMigration.migrate_v2(_legacy({"research": {"briefcase": 1}, "waiting_level": 1, "seating_level": 1, "ticket_machine_level": 1, "ticket_display_level": 1, "complaint_clerk_level": 1, "complaint_box_level": 1}))
	assert_eq(int(result.version), GameState.PREVIOUS_SAVE_VERSION)
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
	assert_false(upgrades.has("waiting_places"))
	assert_false(upgrades.has("standing_places"))
	assert_eq(int(upgrades.seating), SaveMigration.seats_for_level(3))
	assert_eq(int(upgrades.ticket_speed), roundi(2 * SaveMigration.TICKET_SCALE))
	assert_false(upgrades.has("ticket_call_speed"))


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
	var legacy := _legacy({"research": research, "waiting_level": 4, "seating_level": 4, "ticket_machine_level": 4, "ticket_display_level": 4, "complaint_clerk_level": 4, "complaint_box_level": 4, "guards": 2, "helpers": [{}], "departments": {"general_services": {"unlocked": true, "tube": true}}})
	var upgrades: Dictionary = SaveMigration.migrate_v5(SaveMigration.migrate_v4(SaveMigration.migrate_v3(SaveMigration.migrate_v2(legacy)))).upgrades
	assert_false(upgrades.is_empty())
	for key: String in upgrades:
		assert_false(GameConfig.upgrade(key.get_slice("@", 0)).is_empty(), key)


func test_game_state_loads_legacy_saves() -> void:
	var state := GameState.from_dict(_legacy({"research": {"briefcase": 2, "pneumatic_tubes": 1, "shredder_service": 1}, "waiting_level": 1, "complaint_clerk_level": 1, "complaint_box_level": 1}))
	assert_eq(state.upgrade_level("briefcase"), 4)
	assert_false(state.upgrades.has("waiting_places"))
	assert_false(state.upgrades.has("complaint_clerk"))
	assert_false(state.upgrades.has("shredder_service"))
	assert_eq(state.upgrade_level("complaint_interns"), 1)
	assert_eq(state.interns.size(), 1)
	assert_eq(state.upgrade_level("complaint_box"), ceili(SaveMigration.BOX_SCALE / float(GameConfig.COMPLAINT_BOX_STEP)))
	assert_true(state.has_tube_station("general_services"))
	assert_true(state.has_tube_station(GameConfig.ROOM_HALL))
	assert_true(state.department("general_services").unlocked)
	assert_eq(state.money, 500.0)


func test_migrated_levels_are_capped_on_load() -> void:
	var state := GameState.from_dict(_legacy({"research": {"ai_classification": 50, "comfortable_lobby": 3, "online_portal": 2}, "seating_level": 9, "ticket_machine_level": 20}))
	assert_eq(state.upgrade_level("ai_classification"), int(GameConfig.upgrade("ai_classification").max))
	assert_eq(state.upgrade_level("seating"), int(GameConfig.upgrade("seating").max))
	assert_eq(state.upgrade_level("ticket_speed"), GameConfig.TICKET_MACHINE_LEVELS)
	assert_false(state.upgrades.has("comfortable_lobby"))
	assert_false(state.upgrades.has("online_portal"))


func test_current_save_round_trips_upgrades() -> void:
	var state := GameState.create_new(3)
	state.set_upgrade("briefcase", 7)
	state.set_upgrade("room_speed", 4, "general_services")
	state.set_upgrade("room_trays", 2, GameConfig.ROOM_HALL)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_patrol", 3, "general_services")
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.upgrades, state.upgrades)


func test_invalid_upgrade_keys_are_dropped_on_load() -> void:
	var data := GameState.create_new(3).to_dict()
	data.upgrades = {"nope": 3, "briefcase@hall": 2, "room_speed": 2, "room_speed@player": 2, "lead_calm@hall": 1, "office_equipment@hall": 2, "scanners": 5, "shredder@customs": 1, "coffee": 4}
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.upgrades, {"coffee": 4})


func test_v3_saves_become_v4_and_load_through_the_v4_migration() -> void:
	var v3 := GameState.create_new(3).to_dict()
	v3["version"] = GameState.PREVIOUS_SAVE_VERSION
	v3["upgrades"] = {"briefcase": 2, "scanners": 4, "office_equipment@general_services": 3, "guard_training": 2}
	v3["trainings"] = 9
	var migrated := SaveMigration.migrate_v3(v3)
	assert_eq(int(migrated.version), GameState.V4_SAVE_VERSION)
	assert_true(migrated.upgrades.has("scanners"))
	assert_false(migrated.upgrades.has("guard_training"))
	var loaded := GameState.from_dict(v3)
	assert_eq(loaded.upgrades, {"briefcase": 2})
	var saved := loaded.to_dict()
	assert_eq(int(saved.version), GameState.SAVE_VERSION)
	assert_false(saved.has("trainings"))


func _v4(extra: Dictionary = {}) -> Dictionary:
	var data := {
		"version": GameState.V4_SAVE_VERSION,
		"money": 750.0,
		"departments": {"general_services": {"id": "general_services", "unlocked": true}},
		"tutorial_step": Tutorial.FINISHED,
	}
	data.merge(extra, true)
	return data


func _strip(station: Dictionary) -> Dictionary:
	return SaveMigration.migrate_v4(_v4({"stations": {"general_services/review": station}})).stations["general_services/review"]


func test_v4_result_is_current_version_and_input_is_kept() -> void:
	var data := _v4({
		"upgrades": {"scanners": 2, "briefcase": 1},
		"trainings": 3,
		"stations": {"general_services/review": {"desks": 1, "level": 4, "jobs": [{"case": {"ticket": 1}}, {"case": {"ticket": 2}}]}},
	})
	var copy := data.duplicate(true)
	var result := SaveMigration.migrate_v4(data)
	assert_eq(int(result.version), GameState.V5_SAVE_VERSION)
	assert_eq(data, copy)
	assert_eq(float(result.money), 750.0)
	assert_eq(int(result.tutorial_step), Tutorial.FINISHED)


func test_v4_drops_removed_upgrade_tracks() -> void:
	var upgrades: Dictionary = SaveMigration.migrate_v4(_v4({"upgrades": {
		"scanners": 3,
		"digital_records": 2,
		"digital_signatures": 1,
		"letter_opener": 4,
		"office_equipment": 1,
		"office_equipment@general_services": 5,
		"office_equipment@tax_services": 2,
		"briefcase": 2,
		"pneumatic_tubes": 1,
		"tube_station@hall": 1,
		"shredder@general_services": 1,
	}})).upgrades
	assert_eq(upgrades, {"briefcase": 2, "pneumatic_tubes": 1, "tube_station@hall": 1, "shredder@general_services": 1})
	for upgrade_id in SaveMigration.V4_REMOVED_UPGRADES:
		assert_false(upgrades.has(upgrade_id), upgrade_id)


func test_v4_handles_missing_and_broken_upgrades() -> void:
	assert_eq(SaveMigration.migrate_v4(_v4()).upgrades, {})
	assert_eq(SaveMigration.migrate_v4(_v4({"upgrades": "broken"})).upgrades, {})


func test_v4_keeps_tubes() -> void:
	var result := SaveMigration.migrate_v4(_v4({
		"upgrades": {"pneumatic_tubes": 1, "large_capsules": 1, "tube_capacity": 4, "tube_station@general_services": 1, "tube_station@mail": 1},
		"tube_levels": {"hall>general_services": 6},
		"tube_parcels": [{"from": "hall"}],
	}))
	assert_eq(result.upgrades, {"pneumatic_tubes": 1, "large_capsules": 1, "tube_capacity": 4, "tube_station@general_services": 1, "tube_station@mail": 1})
	assert_eq(result.tube_levels, {"hall>general_services": 6})
	assert_eq(result.tube_parcels, [{"from": "hall"}])


func test_v4_removes_supervisors_from_departments() -> void:
	var departments: Dictionary = SaveMigration.migrate_v4(_v4({"departments": {
		"general_services": {"id": "general_services", "unlocked": true, "supervisors": 3, "rank_level": 2},
		"tax_services": {"id": "tax_services", "supervisors": 1},
		"housing": {"id": "housing"},
		"broken": "nope",
	}})).departments
	assert_eq(departments.general_services, {"id": "general_services", "unlocked": true, "rank_level": 2})
	assert_eq(departments.tax_services, {"id": "tax_services"})
	assert_eq(departments.housing, {"id": "housing"})
	assert_eq(departments.broken, "nope")


func test_v4_tolerates_missing_and_broken_sections() -> void:
	var bare := SaveMigration.migrate_v4({"version": GameState.V4_SAVE_VERSION})
	assert_eq(int(bare.version), GameState.V5_SAVE_VERSION)
	assert_false(bare.has("departments"))
	assert_false(bare.has("stations"))
	assert_eq(bare.upgrades, {})
	var broken := SaveMigration.migrate_v4(_v4({"departments": "broken", "stations": [1, 2]}))
	assert_eq(broken.departments, "broken")
	assert_eq(broken.stations, [1, 2])


func test_v4_removes_the_training_counter() -> void:
	var result := SaveMigration.migrate_v4(_v4({"trainings": 7, "wakes": 3}))
	for key in SaveMigration.V4_REMOVED_KEYS:
		assert_false(result.has(key), key)
	assert_eq(int(result.wakes), 3)


func test_v4_strips_removed_station_fields() -> void:
	var station := _strip({"key": "general_services/review", "desks": 2, "staff": 2, "level": 7, "specialists": 2, "tray_level": 5, "rejects": 1, "rush": 3.0})
	for key in SaveMigration.V4_REMOVED_STATION_KEYS:
		assert_false(station.has(key), key)
	assert_eq(int(station.desks), 2)
	assert_eq(int(station.staff), 2)
	assert_eq(int(station.rejects), 1)
	assert_eq(float(station.rush), 3.0)
	assert_eq(station.jobs, [])
	assert_eq(station.inbox, [])
	assert_eq(station.moods, [])


func test_v4_moves_extra_jobs_to_the_front_of_the_inbox() -> void:
	var station := _strip({"desks": 2, "jobs": [
		{"case": {"ticket": 1}, "specialist": true, "progress": 0.3},
		null,
		{"case": {"ticket": 3}, "specialist": true, "progress": 0.4},
		{"progress": 1.0, "specialist": true},
		null,
		"junk",
		{"case": {"ticket": 7}},
	], "inbox": [{"ticket": 8}, {"ticket": 9}]})
	assert_eq(station.jobs, [{"case": {"ticket": 1}, "progress": 0.3}, null])
	assert_eq(station.inbox, [{"ticket": 3}, {"ticket": 7}, {"ticket": 8}, {"ticket": 9}])


func test_v4_erases_the_specialist_flag_from_kept_jobs() -> void:
	var station := _strip({"desks": 3, "jobs": [
		{"case": {"ticket": 1}, "specialist": false, "required": 2.0},
		{"case": {"ticket": 2}, "specialist": true, "by_hand": true},
	]})
	assert_eq(station.jobs, [{"case": {"ticket": 1}, "required": 2.0}, {"case": {"ticket": 2}, "by_hand": true}])
	assert_eq(station.inbox, [])


func test_v4_trims_moods_and_drops_training() -> void:
	var station := _strip({"desks": 2, "moods": [
		{"state": "awake", "training": {"skill": 3}},
		"junk",
		{"state": "asleep", "training": {"calm": 1}},
	]})
	assert_eq(station.moods, [{"state": "awake"}, "junk"])
	var short := _strip({"desks": 3, "moods": [{"state": "asleep", "training": {}, "alert": 0.5}]})
	assert_eq(short.moods, [{"state": "asleep", "alert": 0.5}])


func test_v4_replaces_broken_station_lists() -> void:
	var station := _strip({"desks": 1, "jobs": "broken", "inbox": 5, "moods": {"a": 1}})
	assert_eq(station.jobs, [])
	assert_eq(station.inbox, [])
	assert_eq(station.moods, [])
	var queued := _strip({"inbox": [{"ticket": 4}]})
	assert_eq(queued.jobs, [])
	assert_eq(queued.inbox, [{"ticket": 4}])
	var untouched := SaveMigration.migrate_v4(_v4({"stations": {"general_services/review": "broken"}}))
	assert_eq(untouched.stations["general_services/review"], "broken")


func test_v4_clamps_the_desk_count() -> void:
	var jobs := [{"case": {"ticket": 1}}, {"case": {"ticket": 2}}]
	var none := _strip({"desks": 0, "jobs": jobs.duplicate(true), "moods": [{}, {}]})
	assert_eq(none.jobs, [{"case": {"ticket": 1}}])
	assert_eq(none.inbox, [{"ticket": 2}])
	assert_eq(none.moods.size(), 1)
	var negative := _strip({"desks": -5, "jobs": jobs.duplicate(true)})
	assert_eq(negative.jobs.size(), 1)
	var missing := _strip({"jobs": jobs.duplicate(true)})
	assert_eq(missing.jobs.size(), 1)
	assert_eq(missing.inbox, [{"ticket": 2}])
	var crowd: Array = []
	var moods: Array = []
	for index in 101:
		crowd.append({"case": {"ticket": index}})
		moods.append({"slot": index})
	var many := _strip({"desks": 500, "jobs": crowd, "moods": moods})
	assert_eq(many.jobs.size(), 99)
	assert_eq(many.moods.size(), 99)
	assert_eq(many.inbox, [{"ticket": 99}, {"ticket": 100}])


func _case_at_review(ticket: int) -> CaseFile:
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = case_file.route.find("general_services/review")
	case_file.ticket = ticket
	return case_file


func test_v4_save_loads_and_round_trips() -> void:
	var state := GameState.create_new(3)
	state.unlock_department("tax_services")
	state.money = 4321.0
	var review := state.station("general_services/review")
	review.staff = 1
	review.inbox.append(_case_at_review(33))
	var data := state.to_dict()
	data["version"] = GameState.V4_SAVE_VERSION
	data["trainings"] = 5
	data["upgrades"] = {"briefcase": 3, "pneumatic_tubes": 1, "tube_station@hall": 1, "scanners": 10, "digital_records": 2, "office_equipment@general_services": 4, "letter_opener": 2}
	data["departments"]["general_services"]["supervisors"] = 2
	var entry: Dictionary = data["stations"]["general_services/review"]
	entry["level"] = 9
	entry["specialists"] = 1
	entry["tray_level"] = 3
	var kept_job := StationJob.new(_case_at_review(11), 3.0).to_dict()
	kept_job["specialist"] = false
	var extra_job := StationJob.new(_case_at_review(22), 3.0).to_dict()
	extra_job["specialist"] = true
	entry["jobs"] = [kept_job, extra_job]
	var mood := DeskMood.new().to_dict()
	mood["training"] = {"skill": 4}
	entry["moods"] = [mood, mood.duplicate(true)]
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded.upgrades, {"briefcase": 3, "pneumatic_tubes": 1, "tube_station@hall": 1})
	assert_almost_eq(loaded.money, 4321.0, 0.001)
	assert_true(loaded.department("tax_services").unlocked)
	var restored := loaded.station("general_services/review")
	assert_eq(restored.staff, 1)
	assert_eq(restored.tray_size, GameConfig.TRAY_BASE)
	assert_eq(restored.jobs.size(), 1)
	assert_eq(restored.moods.size(), 1)
	assert_eq(restored.jobs[0].case_file.ticket, 11)
	assert_eq(restored.inbox.size(), 2)
	assert_eq(restored.inbox[0].ticket, 22)
	assert_eq(restored.inbox[1].ticket, 33)
	var saved := loaded.to_dict()
	assert_eq(int(saved.version), GameState.SAVE_VERSION)
	assert_false(saved.has("trainings"))
	assert_false(saved.departments.general_services.has("supervisors"))
	assert_false(saved.stations["general_services/review"].has("level"))
	assert_false(saved.stations["general_services/review"].moods[0].has("training"))
	var again := GameState.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(JSON.stringify(again.to_dict()), JSON.stringify(saved))


func test_unknown_versions_start_a_new_game() -> void:
	var loaded := GameState.from_dict({"version": 1, "money": 9999.0})
	assert_eq(loaded.money, GameConfig.START_MONEY)
	assert_true(loaded.upgrades.is_empty())
	assert_true(loaded.department("general_services").unlocked)


func test_hall_team_lead_moves_to_intake_and_pickup() -> void:
	var upgrades := {"team_lead@hall": 1, "lead_focus@hall": 12, "lead_breaks@pickup": 20, "lead_breaks@hall": 5, "room_speed@hall": 3, "team_lead@general_services": 1}
	var copy := upgrades.duplicate(true)
	var result := SaveMigration.split_hall_leads(upgrades)
	assert_eq(upgrades, copy)
	assert_eq_deep(result, {
		"team_lead@intake": 1, "team_lead@pickup": 1,
		"lead_focus@intake": 12, "lead_focus@pickup": 12,
		"lead_breaks@intake": 5, "lead_breaks@pickup": 20,
		"room_speed@hall": 3, "team_lead@general_services": 1,
	})
	assert_eq_deep(SaveMigration.split_hall_leads({}), {})
	assert_eq_deep(SaveMigration.split_hall_leads({"briefcase": 2}), {"briefcase": 2})


func test_saved_hall_team_lead_loads_into_both_hall_offices() -> void:
	var state := GameState.create_new(3)
	var data := state.to_dict()
	data["upgrades"] = {"team_lead@hall": 1, "lead_patrol@hall": 7, "room_speed@hall": 2}
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(data)))
	for room_id in GameConfig.WAITING_ROOMS:
		assert_true(loaded.has_upgrade("team_lead", room_id), room_id)
		assert_eq(loaded.upgrade_level("lead_patrol", room_id), 7, room_id)
	assert_eq(loaded.upgrade_level("team_lead", GameConfig.ROOM_HALL), 0)
	assert_eq(loaded.upgrade_level("room_speed", GameConfig.ROOM_HALL), 2)
	assert_eq(Formulas.team_lead_count(loaded), 2)
	var again := GameState.from_dict(JSON.parse_string(JSON.stringify(loaded.to_dict())))
	assert_eq(again.upgrades, loaded.upgrades)


func _v5(extra: Dictionary = {}) -> Dictionary:
	var data := {
		"version": GameState.V5_SAVE_VERSION,
		"money": 900.0,
		"departments": {"general_services": {"id": "general_services", "unlocked": true}},
		"tutorial_step": Tutorial.FINISHED,
	}
	data.merge(extra, true)
	return data


func test_save_version_is_six_and_follows_v5() -> void:
	assert_eq(GameState.SAVE_VERSION, 6)
	assert_eq(GameState.V5_SAVE_VERSION, 5)
	assert_eq(GameState.V4_SAVE_VERSION, 4)


func test_v5_result_is_current_version_and_input_is_kept() -> void:
	var data := _v5({"upgrades": {"collector_carts": 2, "briefcase": 1}, "collectors": [{"x": 1.0, "y": 2.0, "loaded": 1, "dept": ""}], "shredder_timers": {"general_services": 3.0}})
	var copy := data.duplicate(true)
	var result := SaveMigration.migrate_v5(data)
	assert_eq(int(result.version), GameState.SAVE_VERSION)
	assert_eq(data, copy)
	assert_eq(float(result.money), 900.0)
	assert_eq(int(result.tutorial_step), Tutorial.FINISHED)
	assert_false(result.has("collectors"))
	assert_false(result.has("shredder_timers"))
	for key in SaveMigration.V5_REMOVED_KEYS:
		assert_false(result.has(key), key)


func test_v5_drops_collector_and_department_shredder_tracks() -> void:
	var upgrades: Dictionary = SaveMigration.migrate_v5(_v5({"upgrades": {
		"collector_carts": 5,
		"collector_speed": 12,
		"shredder@general_services": 3,
		"shredder@tax_services": 1,
		"shredder": 2,
		"shredder_blades": 7,
		"runner_trolleys": 4,
		"runner_speed": 9,
		"tube_station@hall": 1,
		"briefcase": 2,
	}})).upgrades
	assert_eq(upgrades, {"shredder_blades": 7, "runner_trolleys": 4, "runner_speed": 9, "tube_station@hall": 1, "briefcase": 2})
	for upgrade_id in SaveMigration.V5_REMOVED_UPGRADES:
		for key: String in upgrades:
			assert_ne(key.get_slice("@", 0), upgrade_id)


func test_v5_handles_missing_and_broken_upgrades() -> void:
	assert_eq(SaveMigration.migrate_v5(_v5()).upgrades, {})
	assert_eq(SaveMigration.migrate_v5(_v5({"upgrades": "broken"})).upgrades, {})
	assert_eq(SaveMigration.migrate_v5(_v5({"upgrades": []})).upgrades, {})


func test_v5_turns_collectors_into_reject_runners() -> void:
	var result := SaveMigration.migrate_v5(_v5({"collectors": [
		{"x": 100.0, "y": 200.0, "loaded": 2, "dept": "tax_services"},
		{"x": 300.0, "y": 400.0, "loaded": 0, "dept": ""},
	]}))
	assert_eq(result.runners.size(), 2)
	assert_eq(result.runners[0].role, Runner.REJECT)
	assert_eq(result.runners[0].dept, "tax_services")
	assert_eq(int(result.runners[0].level), 0)
	assert_eq(int(result.runners[0].loaded), 2)
	assert_eq(float(result.runners[0].x), 100.0)
	assert_eq(float(result.runners[0].y), 200.0)
	assert_eq(result.runners[0].items, [])
	assert_eq(result.runners[1].role, Runner.REJECT)
	assert_eq(result.runners[1].dept, "")
	assert_eq(int(result.runners[1].loaded), 0)


func test_v5_appends_reject_runners_after_existing_runners() -> void:
	var existing := {"x": 5.0, "y": 6.0, "items": [], "target": "", "role": "output", "dept": "", "level": 3}
	var result := SaveMigration.migrate_v5(_v5({"runners": [existing], "collectors": [{"loaded": 1}]}))
	assert_eq(result.runners.size(), 2)
	assert_eq(result.runners[0], existing)
	assert_eq(result.runners[1].role, Runner.REJECT)
	assert_eq(int(result.runners[1].loaded), 1)


func test_v5_keeps_runners_without_collectors() -> void:
	var existing := {"role": "intake"}
	assert_eq(SaveMigration.migrate_v5(_v5({"runners": [existing]})).runners, [existing])
	assert_eq(SaveMigration.migrate_v5(_v5()).runners, [])


func test_v5_limits_reject_runners_to_the_runner_cap() -> void:
	var collectors: Array = []
	for index in GameConfig.MAX_RUNNERS + 5:
		collectors.append({"loaded": 1})
	var result := SaveMigration.migrate_v5(_v5({"collectors": collectors}))
	assert_eq(result.runners.size(), GameConfig.MAX_RUNNERS)
	var existing: Array = []
	for index in GameConfig.MAX_RUNNERS - 1:
		existing.append({"role": "intake"})
	var partly := SaveMigration.migrate_v5(_v5({"runners": existing, "collectors": [{"loaded": 2}, {"loaded": 3}]}))
	assert_eq(partly.runners.size(), GameConfig.MAX_RUNNERS)
	assert_eq(int(partly.runners[GameConfig.MAX_RUNNERS - 1].loaded), 2)
	var full: Array = []
	for index in GameConfig.MAX_RUNNERS:
		full.append({"role": "intake"})
	assert_eq(SaveMigration.migrate_v5(_v5({"runners": full, "collectors": [{"loaded": 2}]})).runners.size(), GameConfig.MAX_RUNNERS)


func test_v5_tolerates_broken_collectors() -> void:
	assert_eq(SaveMigration.migrate_v5(_v5({"collectors": "broken"})).runners, [])
	assert_eq(SaveMigration.migrate_v5(_v5({"collectors": [1, "x", null]})).runners, [])
	assert_eq(SaveMigration.migrate_v5(_v5({"runners": "broken", "collectors": [{"loaded": 1}]})).runners.size(), 1)
	var result := SaveMigration.migrate_v5(_v5({"collectors": [{"loaded": -4}, {}]}))
	assert_eq(int(result.runners[0].loaded), 0)
	assert_false(result.runners[1].has("x"))
	assert_eq(result.runners[1].dept, "")
	assert_eq(int(result.runners[1].loaded), 0)


func test_v5_save_loads_collectors_as_reject_runners() -> void:
	var state := GameState.create_new(3)
	state.unlock_department("tax_services")
	var data := state.to_dict()
	data["version"] = GameState.V5_SAVE_VERSION
	data["collectors"] = [{"x": 120.0, "y": 80.0, "loaded": 2, "dept": "tax_services"}, {"x": 10.0, "y": 20.0, "loaded": 999, "dept": "nope"}]
	data["shredder_timers"] = {"general_services": 4.0}
	data["upgrades"] = {"briefcase": 3, "collector_carts": 6, "collector_speed": 20, "shredder@general_services": 2, "shredder@tax_services": 1}
	data["runners"] = [{"x": 1.0, "y": 1.0, "items": [], "target": "", "role": "intake", "dept": "", "level": 2}]
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(loaded.upgrades, {"briefcase": 3})
	assert_eq(loaded.runners.size(), 3)
	assert_eq(loaded.runners[0].role, Runner.INTAKE)
	assert_eq(loaded.runners[0].level, 2)
	assert_eq(loaded.runners[1].role, Runner.REJECT)
	assert_eq(loaded.runners[1].loaded, 2)
	assert_eq(loaded.runners[1].dept_id, "tax_services")
	assert_eq(loaded.runners[1].position, Vector2(120.0, 80.0))
	assert_eq(loaded.runners[2].role, Runner.REJECT)
	assert_eq(loaded.runners[2].dept_id, Runner.ALL_DEPARTMENTS)
	assert_eq(loaded.runners[2].loaded, Formulas.runner_load_limit(0))
	assert_eq(loaded.runners_in(Runner.REJECT), 2)
	var saved := loaded.to_dict()
	assert_eq(int(saved.version), GameState.SAVE_VERSION)
	assert_false(saved.has("collectors"))
	assert_false(saved.has("shredder_timers"))
	var again := GameState.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(JSON.stringify(again.to_dict()), JSON.stringify(saved))


func test_reject_runner_without_position_uses_the_runner_home() -> void:
	var data := GameState.create_new(3).to_dict()
	data["version"] = GameState.V5_SAVE_VERSION
	data["collectors"] = [{"loaded": 1}]
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.runners[0].position, WorldLayout.get_default().runner_home())
	assert_eq(loaded.runners[0].loaded, 1)


func test_saves_run_through_every_migration_up_to_the_current_version() -> void:
	var legacy := _legacy({"research": {"trolleys": 3, "briefcase": 1}, "departments": {"general_services": {"unlocked": true}}})
	var loaded := GameState.from_dict(legacy)
	assert_eq(loaded.upgrade_level("runner_trolleys"), 3)
	assert_false(loaded.upgrades.has("collector_carts"))
	assert_eq(int(loaded.to_dict().version), GameState.SAVE_VERSION)
	var v3 := GameState.create_new(3).to_dict()
	v3["version"] = GameState.PREVIOUS_SAVE_VERSION
	v3["collectors"] = [{"loaded": 1}]
	assert_eq(GameState.from_dict(v3).runners_in(Runner.REJECT), 1)
	var v4 := GameState.create_new(3).to_dict()
	v4["version"] = GameState.V4_SAVE_VERSION
	v4["collectors"] = [{"loaded": 1, "dept": "tax_services"}]
	v4["upgrades"] = {"scanners": 2, "collector_speed": 5, "shredder@general_services": 1}
	var from_v4 := GameState.from_dict(v4)
	assert_eq(from_v4.upgrades, {})
	assert_eq(from_v4.runners_in(Runner.REJECT), 1)
	assert_eq(from_v4.runners[0].dept_id, "tax_services")
	assert_eq(int(from_v4.to_dict().version), GameState.SAVE_VERSION)
