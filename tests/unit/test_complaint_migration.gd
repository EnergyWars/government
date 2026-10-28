extends GutTest


func _v3(upgrades: Dictionary, extra: Dictionary = {}) -> Dictionary:
	var data := GameState.create_new(5).to_dict()
	data["version"] = GameState.PREVIOUS_SAVE_VERSION
	data.erase("interns")
	data["upgrades"] = upgrades
	data.merge(extra, true)
	return data


func _migrated(upgrades: Dictionary, extra: Dictionary = {}) -> Dictionary:
	return SaveMigration.migrate_v3(_v3(upgrades, extra)).upgrades


func test_result_is_current_version_without_old_keys() -> void:
	var result := SaveMigration.migrate_v3(_v3({"shredder_service": 3, "intern_training": 2, "intern_resilience": 10, "complaint_tube": 4, "complaint_clerk": 7, "guard_training": 9}, {"intern": {}, "helpers": [{}], "guards": 1, "complaints_fended": 3}))
	assert_eq(int(result.version), GameState.V4_SAVE_VERSION)
	for key in SaveMigration.V3_REMOVED_KEYS:
		assert_false(result.has(key), key)
	for upgrade_id in SaveMigration.V3_REMOVED_UPGRADES:
		assert_false((result.upgrades as Dictionary).has(upgrade_id), upgrade_id)


func test_input_is_not_modified() -> void:
	var data := _v3({"shredder_service": 1, "complaint_box": 20}, {"helpers": [{}], "guards": 2})
	var copy := data.duplicate(true)
	SaveMigration.migrate_v3(data)
	assert_eq(data, copy)


func test_desk_intern_and_helpers_become_counter_interns() -> void:
	assert_eq(int(_migrated({"shredder_service": 5}).complaint_interns), 1)
	assert_eq(int(_migrated({"shredder_service": 5}, {"helpers": [{}]}).complaint_interns), 2)
	assert_eq(int(_migrated({"shredder_service": 5}, {"helpers": [{}, {}, {}]}).complaint_interns), GameConfig.MAX_DESK_INTERNS)
	assert_false(_migrated({}, {"helpers": [{}, {}]}).has("complaint_interns"))
	assert_eq(int(_migrated({"shredder_service": 1}, {"helpers": "junk"}).complaint_interns), 1)


func test_resilience_becomes_steadfastness() -> void:
	assert_false(_migrated({"intern_resilience": 24}).has("intern_steadfast"))
	assert_eq(int(_migrated({"intern_resilience": 50}).intern_steadfast), 2)
	assert_eq(int(_migrated({"intern_resilience": 150}).intern_steadfast), int(GameConfig.upgrade("intern_steadfast").max))


func test_intern_training_becomes_box_runs_only_with_two_interns() -> void:
	assert_false(_migrated({"shredder_service": 1, "intern_training": 3}).has("intern_box_runs"))
	assert_eq(int(_migrated({"shredder_service": 1, "intern_training": 0}, {"helpers": [{}]}).intern_box_runs), 1)
	assert_eq(int(_migrated({"shredder_service": 1, "intern_training": 2}, {"helpers": [{}]}).intern_box_runs), 3)
	assert_eq(int(_migrated({"shredder_service": 1, "intern_training": 50}, {"helpers": [{}]}).intern_box_runs), GameConfig.MAX_INTERN_RUN)


func test_box_levels_are_rescaled() -> void:
	assert_false(_migrated({}).has("complaint_box"))
	assert_eq(int(_migrated({"complaint_box": 1}).complaint_box), 1)
	assert_eq(int(_migrated({"complaint_box": 4}).complaint_box), 1)
	assert_eq(int(_migrated({"complaint_box": 5}).complaint_box), 2)
	assert_eq(int(_migrated({"complaint_box": 200}).complaint_box), GameConfig.COMPLAINT_BOX_LEVELS)


func test_guards_become_security() -> void:
	assert_false(_migrated({"guard_training": 50}).has("complaint_security"))
	var single := _migrated({}, {"guards": 1})
	assert_eq(int(single.complaint_security), 1)
	assert_eq(int(single.security_training), SaveMigration.security_level(1, 0))
	assert_eq(SaveMigration.security_level(1, 0), 36)
	assert_eq(SaveMigration.security_level(2, 0), 68)
	assert_eq(SaveMigration.security_level(6, 150), GameConfig.SECURITY_LEVELS)
	assert_eq(SaveMigration.security_level(0, 0), 0)
	assert_eq(int(_migrated({"guard_training": 150}, {"guards": 6}).security_training), GameConfig.SECURITY_LEVELS)


func test_other_upgrades_are_kept() -> void:
	var upgrades := _migrated({"briefcase": 7, "seating": 3})
	assert_eq(int(upgrades.briefcase), 7)
	assert_eq(int(upgrades.seating), 3)


func test_game_state_loads_version_three_saves() -> void:
	var data := _v3({"shredder_service": 2, "complaint_box": 9, "intern_training": 1}, {"helpers": [{"mood": 0}], "guards": 1, "intern": {"mood": 2}})
	data["complaints"] = 9
	var state := GameState.from_dict(data)
	assert_eq(state.interns.size(), 2)
	assert_eq(state.upgrade_level("complaint_box"), 3)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + 3 * GameConfig.COMPLAINT_BOX_STEP)
	assert_eq(state.complaints, 9)
	assert_eq(state.upgrade_level("intern_box_runs"), 2)
	assert_true(state.has_upgrade("complaint_security"))
	for unit in state.interns:
		assert_true(unit.is_at_desk())


func test_legacy_saves_run_through_both_migrations() -> void:
	var legacy := {"version": GameState.LEGACY_SAVE_VERSION, "research": {"shredder_service": 1, "intern_training": 1}, "complaint_clerk_level": 2, "complaint_box_level": 1}
	var state := GameState.from_dict(legacy)
	assert_eq(state.upgrade_level("complaint_interns"), 1)
	assert_eq(state.upgrade_level("complaint_box"), ceili(SaveMigration.BOX_SCALE / float(GameConfig.COMPLAINT_BOX_STEP)))
	assert_eq(state.upgrade_level("intern_steadfast"), 0)
	assert_eq(state.to_dict().version, GameState.SAVE_VERSION)
