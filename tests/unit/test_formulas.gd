extends GutTest

var state: GameState


func before_each() -> void:
	state = GameState.create_new(3)


func _case(dept_id: String = "general_services", complex: bool = false, urgent: bool = false) -> CaseFile:
	var case_file := CaseFile.new(dept_id, complex, urgent)
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func _gs() -> Department:
	return state.department("general_services")


func _staff_everything() -> void:
	for key in state.stations:
		var station := state.stations[key]
		if not station.machine:
			station.staff = station.desks


func _pipe_everything() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("large_capsules", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)


func test_station_costs_grow() -> void:
	var review := state.station("general_services/review")
	review.staff = 1
	assert_almost_eq(Formulas.desk_cost(review), 120.0 * Formulas.early_discount(0), 0.001)
	assert_almost_eq(Formulas.hire_cost(review), 240.0 * GameConfig.HIRE_GROWTH * Formulas.early_discount(1), 0.001)
	review.add_desk()
	review.staff = 2
	assert_almost_eq(Formulas.desk_cost(review), 120.0 * GameConfig.DESK_GROWTH * Formulas.early_discount(1), 0.001)
	assert_almost_eq(Formulas.hire_cost(review), 240.0 * pow(GameConfig.HIRE_GROWTH, 2) * Formulas.early_discount(2), 0.001)


func test_cost_multipliers_per_department_and_shared_station() -> void:
	state.unlock_department("tax_services")
	assert_almost_eq(Formulas.desk_cost(state.station("tax_services/review")), 360.0 * Formulas.early_discount(0), 0.001)
	assert_eq(Formulas.cost_multiplier_for(state.station(GameConfig.RECEPTION)), 1.0)
	state.unlock_department("business_licences")
	assert_eq(Formulas.cost_multiplier_for(state.station(GameConfig.INSPECTION)), 10.0)


func test_staff_costs_follow_the_department_staff_multiplier() -> void:
	state.unlock_department("customs")
	var review := state.station("customs/review")
	var multiplier := float(GameConfig.department("customs").staff_multiplier)
	assert_eq(Formulas.staff_multiplier_for(review), multiplier)
	assert_almost_eq(Formulas.hire_cost(review), 240.0 * multiplier * Formulas.early_discount(0), 0.01)
	assert_almost_eq(Formulas.desk_cost(review), 120.0 * float(GameConfig.department("customs").cost_multiplier) * Formulas.early_discount(0), 0.01)
	assert_almost_eq(Formulas.track_cost("team_lead", 0, "customs"), float(GameConfig.upgrade("team_lead").cost) * multiplier * Formulas.early_discount(0), 0.01)
	assert_almost_eq(Formulas.track_cost("lead_focus", 0, "customs"), float(GameConfig.upgrade("lead_focus").cost) * multiplier * Formulas.early_discount(0), 0.01)
	assert_eq(Formulas.staff_multiplier_for(state.station(GameConfig.INSPECTION)), 10.0)
	assert_eq(Formulas.department_staff_multiplier({"cost_multiplier": 7.0}), 7.0)
	assert_eq(Formulas.department_staff_multiplier({}), 1.0)


func test_staff_multiplier_outgrows_cost_multiplier_for_later_departments() -> void:
	var previous := 0.0
	for entry: Dictionary in GameConfig.DEPARTMENTS:
		var multiplier := Formulas.department_staff_multiplier(entry)
		assert_gt(multiplier, previous, entry.id)
		assert_true(multiplier >= float(entry.cost_multiplier), entry.id)
		previous = multiplier


func test_staff_and_track_costs() -> void:
	assert_almost_eq(Formulas.runner_cost(state), GameConfig.RUNNER_COST * Formulas.early_discount(0), 0.001)
	state.add_runner()
	assert_almost_eq(Formulas.runner_cost(state), GameConfig.RUNNER_COST * GameConfig.RUNNER_GROWTH * Formulas.early_discount(1), 0.001)
	var briefcase := GameConfig.upgrade("briefcase")
	assert_almost_eq(Formulas.track_cost("briefcase", 0), float(briefcase.cost) * Formulas.early_discount(0), 0.001)
	assert_almost_eq(Formulas.track_cost("briefcase", 1), float(briefcase.cost) * float(briefcase.growth) * Formulas.early_discount(1), 0.001)
	assert_almost_eq(Formulas.track_cost("briefcase", 3), float(briefcase.cost) * pow(float(briefcase.growth), 3) * Formulas.early_discount(3), 0.001)
	assert_almost_eq(Formulas.track_cost("briefcase", 20), float(briefcase.cost) * pow(float(briefcase.growth), 20), 0.001)


func test_track_values_follow_their_curves() -> void:
	var briefcase := GameConfig.upgrade("briefcase")
	assert_eq(Formulas.track_value("briefcase", 0), float(briefcase.base))
	assert_almost_eq(Formulas.track_value("briefcase", 4), float(briefcase.base) + 4.0 * float(briefcase.step), 0.0001)
	var blades := GameConfig.upgrade("shredder_blades")
	assert_almost_eq(Formulas.track_value("shredder_blades", 0), float(blades.base), 0.0001)
	assert_almost_eq(Formulas.track_value("shredder_blades", 3), float(blades.base) * pow(float(blades.rate), 3), 0.0001)
	assert_eq(Formulas.track_value("ticket_machine_2", 0), 0.0)
	assert_eq(Formulas.track_value("ticket_machine_2", 1), 1.0)
	var mediation := GameConfig.upgrade("mediation")
	assert_eq(Formulas.track_value("mediation", 0), -1.0)
	assert_almost_eq(Formulas.track_value("mediation", 1), float(mediation.base), 0.0001)
	assert_almost_eq(Formulas.track_value("mediation", 3), float(mediation.base) * pow(float(mediation.rate), 2), 0.0001)
	assert_almost_eq(Formulas.track_value("security_training", 0), GameConfig.SECURITY_BASE_CHANCE, 0.0001)
	assert_gt(Formulas.track_value("security_training", 10), Formulas.track_value("security_training", 9))
	assert_almost_eq(Formulas.track_value("security_training", GameConfig.SECURITY_LEVELS), GameConfig.SECURITY_MAX_CHANCE, 0.0001)
	assert_eq(Formulas.track_value("pneumatic_tubes", 0), 0.0)
	assert_eq(Formulas.track_value("pneumatic_tubes", 1), 1.0)
	assert_eq(Formulas.track_value("nope", 5), 0.0)
	assert_eq(Formulas.track_value("team_lead", 0), 0.0)
	assert_eq(Formulas.track_value("team_lead", 1), 1.0)
	var trays := GameConfig.upgrade("room_trays")
	assert_eq(Formulas.track_value("room_trays", 0), float(GameConfig.TRAY_BASE))
	assert_eq(Formulas.track_value("room_trays", 4), float(GameConfig.TRAY_BASE) + 4.0 * float(trays.step))
	assert_almost_eq(Formulas.track_value("lead_patrol", 0), 3.0, 0.0001)
	assert_almost_eq(Formulas.track_value("lead_patrol", 10), 3.0 + 10.0 * 0.01, 0.0001)
	assert_almost_eq(Formulas.track_value("lead_cooldown", 0), 180.0, 0.0001)
	assert_almost_eq(Formulas.track_value("lead_cooldown", 5), 180.0 * pow(0.995, 5), 0.0001)
	assert_almost_eq(Formulas.track_value("lead_breaks", 7), 0.75 * pow(0.995, 7), 0.0001)


func test_room_speed_follows_the_milestone_curve() -> void:
	assert_eq(str(GameConfig.upgrade("room_speed").curve), "milestone")
	assert_eq(Formulas.track_value("room_speed", 0), 1.0)
	for level in [1, 8, 9, 10, 19, 55, GameConfig.ROOM_SPEED_LEVELS]:
		assert_almost_eq(Formulas.track_value("room_speed", level), Formulas.level_speed(level + 1), 0.0001, str(level))
	var before := Formulas.track_value("room_speed", GameConfig.LEVEL_MILESTONE_STEP - 2)
	var after := Formulas.track_value("room_speed", GameConfig.LEVEL_MILESTONE_STEP - 1)
	assert_gt(after / before, GameConfig.LEVEL_MILESTONE_BONUS)
	assert_eq(Formulas.track_value("room_speed", -4), Formulas.track_value("room_speed", 0))
	assert_eq(Formulas.track_value("room_speed", GameConfig.ROOM_SPEED_LEVELS + 50), Formulas.level_speed(GameConfig.ROOM_SPEED_LEVELS + 1))


func test_track_values_clamp_the_level() -> void:
	var briefcase := GameConfig.upgrade("briefcase")
	var top := int(briefcase.max)
	assert_eq(Formulas.track_value("briefcase", -3), Formulas.track_value("briefcase", 0))
	assert_eq(Formulas.track_value("briefcase", top + 50), Formulas.track_value("briefcase", top))
	assert_eq(Formulas.track_value("security_training", -3), Formulas.track_value("security_training", 0))
	assert_eq(Formulas.track_value("security_training", 999), Formulas.track_value("security_training", GameConfig.SECURITY_LEVELS))
	assert_eq(Formulas.track_value("mediation", -1), -1.0)
	assert_eq(Formulas.track_value("pneumatic_tubes", 7), 1.0)


func test_upgrade_value_reads_global_and_room_levels() -> void:
	assert_eq(Formulas.upgrade_value(state, "briefcase"), Formulas.track_value("briefcase", 0))
	state.set_upgrade("briefcase", 7)
	assert_eq(Formulas.upgrade_value(state, "briefcase"), Formulas.track_value("briefcase", 7))
	state.set_upgrade("room_speed", 12, "general_services")
	assert_almost_eq(Formulas.upgrade_value(state, "room_speed", "general_services"), Formulas.track_value("room_speed", 12), 0.0001)
	assert_eq(Formulas.upgrade_value(state, "room_speed", "tax_services"), Formulas.track_value("room_speed", 0))
	assert_eq(Formulas.upgrade_value(state, "room_speed"), Formulas.track_value("room_speed", 0))


func test_track_costs_scale_with_level_and_room() -> void:
	var speed := GameConfig.upgrade("room_speed")
	var tax_multiplier := float(GameConfig.department("tax_services").cost_multiplier)
	assert_eq(Formulas.track_room_factor("briefcase", ""), 1.0)
	assert_eq(Formulas.track_room_factor("room_speed", "general_services"), 1.0)
	assert_eq(Formulas.track_room_factor("room_speed", "tax_services"), tax_multiplier)
	assert_eq(Formulas.track_room_factor("room_speed", GameConfig.ROOM_HALL), 1.0)
	assert_eq(Formulas.track_room_factor("room_speed", GameConfig.ROOM_MAIL), 1.0)
	assert_eq(Formulas.track_room_factor("room_speed", GameConfig.ROOM_INSPECTION), float(GameConfig.SHARED_STATIONS[GameConfig.INSPECTION].cost_multiplier))
	assert_eq(Formulas.track_room_factor("team_lead", "tax_services"), float(GameConfig.department("tax_services").staff_multiplier))
	assert_eq(Formulas.track_room_factor("team_lead", GameConfig.ROOM_HALL), 1.0)
	assert_almost_eq(Formulas.track_cost("room_speed", 2, "tax_services"), float(speed.cost) * tax_multiplier * pow(float(speed.growth), 2) * Formulas.early_discount(2), 0.01)
	assert_gt(Formulas.track_cost("room_speed", 0, "customs"), Formulas.track_cost("room_speed", 0, "tax_services"))
	var first := Formulas.early_discount(0)
	assert_eq(Formulas.track_cost("tube_station", 0, GameConfig.ROOM_HALL), GameConfig.TUBE_STATION_MIN_COST * first)
	assert_eq(Formulas.track_cost("tube_station", 0, GameConfig.ROOM_MAIL), GameConfig.TUBE_STATION_MIN_COST * first)
	assert_eq(Formulas.track_cost("tube_station", 0, "general_services"), GameConfig.TUBE_STATION_MIN_COST * first)
	assert_almost_eq(Formulas.track_cost("tube_station", 0, GameConfig.ROOM_INSPECTION), GameConfig.TUBE_STATION_MIN_COST * GameConfig.TUBE_STATION_INSPECTION_FACTOR * first, 0.01)
	assert_almost_eq(Formulas.track_cost("tube_station", 0, "customs"), float(GameConfig.department("customs").unlock_cost) * GameConfig.TUBE_STATION_FACTOR * first, 0.01)


func test_bulk_costs_add_up_consecutive_levels() -> void:
	assert_eq(Formulas.geometric_sum(100.0, 2.0, 3), 700.0)
	assert_eq(Formulas.geometric_sum(100.0, 1.0, 4), 400.0)
	assert_eq(Formulas.geometric_sum(100.0, 2.0, 0), 0.0)
	assert_eq(Formulas.geometric_sum(100.0, 2.0, -2), 0.0)
	var expected := 0.0
	for level in range(2, 7):
		expected += Formulas.track_cost("briefcase", level)
	assert_almost_eq(Formulas.track_bulk_cost("briefcase", 2, 5), expected, 0.01)
	var room_expected := 0.0
	for level in 3:
		room_expected += Formulas.track_cost("room_speed", level, "tax_services")
	assert_almost_eq(Formulas.track_bulk_cost("room_speed", 0, 3, "tax_services"), room_expected, 0.01)
	assert_almost_eq(Formulas.track_bulk_cost("briefcase", 0, 1), Formulas.track_cost("briefcase", 0), 0.001)


func test_affordable_levels_respect_money_and_remaining_levels() -> void:
	assert_eq(Formulas.geometric_affordable(100.0, 2.0, 10, 99.0), 0)
	assert_eq(Formulas.geometric_affordable(100.0, 2.0, 10, 100.0), 1)
	assert_eq(Formulas.geometric_affordable(100.0, 2.0, 10, 699.0), 2)
	assert_eq(Formulas.geometric_affordable(100.0, 2.0, 10, 700.0), 3)
	assert_eq(Formulas.geometric_affordable(100.0, 2.0, 2, 1e9), 2)
	assert_eq(Formulas.geometric_affordable(100.0, 2.0, 0, 1e9), 0)
	assert_eq(Formulas.geometric_affordable(100.0, 1.0, 10, 450.0), 4)
	assert_eq(Formulas.geometric_affordable(0.0, 2.0, 5, 0.0), 5)
	var limit := int(GameConfig.upgrade("briefcase").max)
	state.set_upgrade("briefcase", limit - 3)
	assert_eq(UpgradeCatalog.track(state, "briefcase").affordable(1e30), 3)
	state.set_upgrade("briefcase", limit)
	assert_eq(UpgradeCatalog.track(state, "briefcase").affordable(1e30), 0)
	state.set_upgrade("briefcase", 0)
	var money := Formulas.track_bulk_cost("briefcase", 0, 4)
	assert_eq(UpgradeCatalog.track(state, "briefcase").affordable(money), 4)
	assert_eq(UpgradeCatalog.track(state, "briefcase").affordable(money - 1.0), 3)
	var speed := UpgradeCatalog.track(state, "room_speed", "tax_services")
	assert_eq(speed.affordable(Formulas.track_cost("room_speed", 0, "tax_services")), 1)
	assert_eq(speed.affordable(Formulas.track_cost("room_speed", 0, "tax_services") - 1.0), 0)


func test_station_speed_follows_the_room_speed_of_its_room() -> void:
	state.unlock_department("tax_services")
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	var tax_signature := state.station("tax_services/signature")
	var reception := state.station(GameConfig.RECEPTION)
	assert_eq(Formulas.station_speed(state, review), 1.0)
	assert_eq(Formulas.station_room(review), "general_services")
	assert_eq(Formulas.station_room(reception), GameConfig.ROOM_HALL)
	state.set_upgrade("room_speed", 9, "general_services")
	var expected := Formulas.level_speed(10)
	assert_gt(expected, 1.0)
	assert_almost_eq(Formulas.station_speed(state, review), expected, 0.0001)
	assert_almost_eq(Formulas.station_speed(state, signature), expected, 0.0001)
	assert_eq(Formulas.station_speed(state, tax_signature), 1.0)
	assert_eq(Formulas.station_speed(state, reception), 1.0)
	state.set_upgrade("room_speed", 4, "tax_services")
	assert_almost_eq(Formulas.station_speed(state, tax_signature), Formulas.level_speed(5), 0.0001)
	state.set_upgrade("room_speed", 3, GameConfig.ROOM_HALL)
	assert_almost_eq(Formulas.station_speed(state, reception), Formulas.level_speed(4), 0.0001)
	assert_almost_eq(Formulas.station_speed(state, state.station(GameConfig.COUNTER)), Formulas.level_speed(4), 0.0001)
	state.set_upgrade("room_speed", 2, GameConfig.ROOM_MAIL)
	assert_almost_eq(Formulas.station_speed(state, Station.new(GameConfig.MAILROOM)), Formulas.level_speed(3), 0.0001)
	state.set_upgrade("room_speed", 1, GameConfig.ROOM_INSPECTION)
	assert_almost_eq(Formulas.station_speed(state, Station.new(GameConfig.INSPECTION)), Formulas.level_speed(2), 0.0001)
	assert_eq(Formulas.station_speed(state, Station.new("")), 1.0)


func test_base_and_required_times() -> void:
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	assert_almost_eq(Formulas.base_time(review, _gs(), false, state), 5.0, 0.001)
	assert_almost_eq(Formulas.base_time(review, _gs(), true, state), 10.0, 0.001)
	assert_almost_eq(Formulas.base_time(signature, _gs(), true, state), 4.0, 0.001)
	assert_almost_eq(Formulas.base_time(state.station(GameConfig.RECEPTION), _gs(), true, state), 2.0, 0.001)
	_gs().thoroughness = 2
	assert_almost_eq(Formulas.base_time(review, _gs(), false, state), 5.0 * 2.0, 0.001)
	assert_almost_eq(Formulas.base_time(signature, _gs(), false, state), 4.0 * 2.0, 0.001)
	assert_almost_eq(Formulas.base_time(state.station(GameConfig.RECEPTION), _gs(), false, state), 2.0, 0.001)
	state.set_upgrade("room_speed", 1, "general_services")
	assert_almost_eq(Formulas.required_time(state, review, _case()), 5.0 * 2.0 / Formulas.level_speed(2), 0.001)
	assert_almost_eq(Formulas.complex_time_factor(state), 1.0 + GameConfig.COMPLEX_TIME_PENALTY, 0.001)
	state.set_upgrade("ai_classification", 50)
	var classification := Formulas.track_value("ai_classification", 50)
	assert_lt(classification, 1.0)
	assert_almost_eq(Formulas.complex_time_factor(state), 1.0 + GameConfig.COMPLEX_TIME_PENALTY * classification, 0.001)


func test_referral_ignores_case_thoroughness_at_foreign_stations() -> void:
	state.unlock_department("housing")
	var housing := state.department("housing")
	housing.thoroughness = 0
	var registry := state.station("general_services/review")
	assert_almost_eq(Formulas.base_time(registry, housing, false, state), 5.0, 0.001)
	assert_almost_eq(Formulas.base_time(state.station("housing/review"), housing, false, state), 7.0 * 0.45 * DepartmentRank.time_factor(housing.rank), 0.001)
	state.unlock_department("business_licences")
	var inspection := state.station(GameConfig.INSPECTION)
	assert_almost_eq(Formulas.base_time(inspection, state.department("business_licences"), true, state), 14.0, 0.001)


func test_thoroughness_reads_the_table_and_clamps() -> void:
	for index in GameConfig.THOROUGHNESS.size():
		_gs().thoroughness = index
		assert_eq(Formulas.thoroughness(_gs()), GameConfig.THOROUGHNESS[index])
	_gs().thoroughness = 99
	assert_eq(Formulas.thoroughness(_gs()), GameConfig.THOROUGHNESS[-1])
	_gs().thoroughness = -5
	assert_eq(Formulas.thoroughness(_gs()), GameConfig.THOROUGHNESS[0])


func test_thoroughness_time_only_applies_to_own_staffed_stations() -> void:
	state.unlock_department("tax_services")
	var tax := state.department("tax_services")
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	var expected_times := [0.45, 1.0, 2.0]
	for index in expected_times.size():
		_gs().thoroughness = index
		assert_almost_eq(Formulas.thoroughness_time(review, _gs()), float(expected_times[index]), 0.0001, str(index))
		assert_almost_eq(Formulas.thoroughness_time(signature, _gs()), float(expected_times[index]), 0.0001, str(index))
		assert_eq(Formulas.thoroughness_time(state.station(GameConfig.RECEPTION), _gs()), 1.0, str(index))
		assert_eq(Formulas.thoroughness_time(state.station(GameConfig.COUNTER), _gs()), 1.0, str(index))
	tax.thoroughness = 2
	var tax_signature := state.station("tax_services/signature")
	assert_true(tax_signature.machine)
	assert_eq(Formulas.thoroughness_time(tax_signature, tax), 1.0)
	assert_almost_eq(Formulas.thoroughness_time(state.station("tax_services/review"), tax), 2.0, 0.0001)
	assert_eq(Formulas.thoroughness_time(review, tax), 1.0)
	assert_almost_eq(Formulas.base_time(tax_signature, tax, false, state), float(tax.config().signature_time), 0.0001)


func test_thoroughness_reward_and_error() -> void:
	var expected_rewards := [1.0, 1.0, 2.6]
	var expected_errors := [0.3, 0.12, 0.02]
	for index in expected_rewards.size():
		_gs().thoroughness = index
		assert_almost_eq(Formulas.thoroughness_reward(_gs()), float(expected_rewards[index]), 0.0001, str(index))
		assert_almost_eq(Formulas.error_chance(state, _gs()), float(expected_errors[index]), 0.0001, str(index))


func test_thorough_work_raises_the_case_reward() -> void:
	var normal: float = Formulas.case_outcome(state, _case()).money
	var normal_expected := Formulas.expected_case_value(state, _gs())
	_gs().thoroughness = 0
	assert_almost_eq(Formulas.case_outcome(state, _case()).money, normal, 0.001)
	_gs().thoroughness = 2
	assert_almost_eq(Formulas.case_outcome(state, _case()).money, normal * 2.6, 0.001)
	assert_almost_eq(Formulas.case_outcome(state, _case()).money, 20.0 * 2.6, 0.001)
	var flawed := _case()
	flawed.flawed = true
	assert_almost_eq(Formulas.case_outcome(state, flawed).money, 20.0 * 2.6 * GameConfig.FLAWED_REWARD_FACTOR, 0.001)
	assert_almost_eq(Formulas.case_outcome(state, _case(), true).money, 0.0, 0.001)
	assert_almost_eq(Formulas.expected_case_value(state, _gs()), 22.0 * 2.6 * (1.0 - 0.02 + 0.02 * GameConfig.FLAWED_REWARD_FACTOR), 0.001)
	assert_gt(Formulas.expected_case_value(state, _gs()), normal_expected)


func test_error_and_flag_chances() -> void:
	assert_almost_eq(Formulas.error_chance(state, _gs()), 0.12, 0.0001)
	state.set_upgrade("quality_training", 30)
	var training := Formulas.track_value("quality_training", 30)
	assert_lt(training, 1.0)
	assert_almost_eq(Formulas.error_chance(state, _gs()), 0.12 * training, 0.0001)
	state.set_upgrade("ai_classification", 100)
	assert_almost_eq(Formulas.error_chance(state, _gs()), 0.12 * training * Formulas.track_value("ai_classification", 100), 0.0001)
	assert_almost_eq(Formulas.flag_chance(), GameConfig.FLAG_BASE_CHANCE, 0.0001)
	assert_almost_eq(Formulas.flag_chance(), 0.6, 0.0001)


func test_reputation_drives_rewards_but_not_arrivals() -> void:
	assert_eq(Formulas.reputation_multiplier(state), 1.0)
	var interval := Formulas.arrival_interval(state)
	state.reputation = 400.0
	assert_almost_eq(Formulas.reputation_multiplier(state), 2.0, 0.0001)
	assert_eq(Formulas.arrival_interval(state), interval)
	assert_almost_eq(interval, 60.0 * state.unlocked_count() / Formulas.base_arrivals_per_minute(state.unlocked_count()), 0.0001)


func test_events_no_longer_change_arrivals() -> void:
	var interval := Formulas.arrival_interval(state)
	for event_id in GameConfig.EVENTS:
		assert_false(GameConfig.EVENTS[event_id].has("arrival"), event_id)
		state.event_id = event_id
		assert_eq(Formulas.arrival_interval(state), interval, event_id)


func test_player_and_runner_stats() -> void:
	assert_eq(Formulas.carry_capacity(state), 6)
	assert_eq(Formulas.runner_capacity(state), 2)
	assert_eq(Formulas.work_power(state), 2.5)
	state.set_upgrade("briefcase", 4)
	state.set_upgrade("runner_trolleys", 1)
	state.set_upgrade("work_ethic", 40)
	assert_eq(Formulas.carry_capacity(state), 10)
	assert_eq(Formulas.runner_capacity(state), 3)
	assert_almost_eq(Formulas.work_power(state), GameConfig.PLAYER_WORK_POWER * Formulas.track_value("work_ethic", 40), 0.001)
	assert_gt(Formulas.work_power(state), GameConfig.PLAYER_WORK_POWER)
	assert_eq(Formulas.runner_load_limit(0), GameConfig.RUNNER_BASE_CAPACITY + int(GameConfig.upgrade("runner_trolleys").max))
	assert_eq(Formulas.runner_load_limit(4), Formulas.runner_load_limit(0) + 4 * GameConfig.RUNNER_LEVEL_CAPACITY)


func test_movement_speeds_follow_their_tracks_and_skates() -> void:
	assert_eq(Formulas.player_speed(state), GameConfig.PLAYER_SPEED)
	assert_eq(Formulas.runner_speed(state), GameConfig.RUNNER_SPEED)
	assert_eq(Formulas.coffee_intern_speed(state), GameConfig.COFFEE_INTERN_SPEED)
	state.set_upgrade("sneakers", 20)
	state.set_upgrade("runner_speed", 30)
	state.set_upgrade("coffee_intern_speed", 50)
	var sneakers := Formulas.track_value("sneakers", 20)
	var runners := Formulas.track_value("runner_speed", 30)
	var coffee := Formulas.track_value("coffee_intern_speed", 50)
	assert_almost_eq(Formulas.player_speed(state), GameConfig.PLAYER_SPEED * sneakers, 0.001)
	assert_almost_eq(Formulas.runner_speed(state), GameConfig.RUNNER_SPEED * runners, 0.001)
	assert_almost_eq(Formulas.coffee_intern_speed(state), GameConfig.COFFEE_INTERN_SPEED * coffee, 0.001)
	state.boosts["roller_skates"] = 10.0
	assert_almost_eq(Formulas.player_speed(state), GameConfig.PLAYER_SPEED * sneakers * GameConfig.BOOST_PLAYER_SPEED, 0.001)
	assert_almost_eq(Formulas.runner_speed(state), GameConfig.RUNNER_SPEED * runners * GameConfig.BOOST_RUNNER_SPEED, 0.001)
	assert_almost_eq(Formulas.coffee_intern_speed(state), GameConfig.COFFEE_INTERN_SPEED * coffee, 0.001)


func test_loo_slots_follow_the_stall_track() -> void:
	assert_eq(Formulas.loo_slots(state), GameConfig.LOO_SLOTS)
	state.set_upgrade("toilet_stalls", 3)
	assert_eq(Formulas.loo_slots(state), GameConfig.LOO_SLOTS + 3)
	assert_eq(state.loo_slots(), Formulas.loo_slots(state))
	state.set_upgrade("toilet_stalls", int(GameConfig.upgrade("toilet_stalls").max) + 4)
	assert_eq(Formulas.loo_slots(state), GameConfig.MAX_LOO_SLOTS)


func test_seated_citizens_are_flagged_from_four_minutes() -> void:
	var citizen := _case()
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.phase = CaseFile.Phase.WAITING
	citizen.seated = true
	citizen.waited = 239.0
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = 240.0
	assert_true(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = GameConfig.SEAT_PATIENCE
	assert_true(Formulas.citizen_leaves_soon(citizen))
	citizen.walk = 2.0
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.walk = 0.0
	citizen.phase = CaseFile.Phase.SERVED
	assert_false(Formulas.citizen_leaves_soon(citizen))
	assert_eq(GameConfig.SEAT_PATIENCE - GameConfig.SEAT_LEAVE_WARNING_SECONDS, 240.0)


func test_standing_citizens_are_flagged_below_thirty_seconds() -> void:
	var citizen := _case()
	citizen.phase = CaseFile.Phase.WAITING
	citizen.seated = false
	citizen.waited = 0.0
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = 59.0
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = 60.0
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = 61.0
	assert_true(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = GameConfig.STAND_PATIENCE
	assert_true(Formulas.citizen_leaves_soon(citizen))
	assert_eq(GameConfig.STAND_LEAVE_WARNING_SECONDS, 30.0)


func test_seat_threshold_does_not_apply_outside_the_waiting_room() -> void:
	var citizen := _case()
	citizen.phase = CaseFile.Phase.CALLED
	citizen.seated = true
	citizen.waited = 0.0
	assert_false(Formulas.citizen_leaves_soon(citizen))
	citizen.waited = GameConfig.DESK_PATIENCE - 1.0
	assert_true(Formulas.citizen_leaves_soon(citizen))


func test_citizen_patience_follows_the_phase() -> void:
	var citizen := _case()
	assert_eq(Formulas.citizen_patience(citizen), 0.0)
	assert_eq(Formulas.citizen_time_left(citizen), 0.0)
	assert_false(Formulas.is_citizen_waiting(citizen))
	citizen.phase = CaseFile.Phase.LINE
	citizen.walk = 3.0
	assert_eq(Formulas.citizen_patience(citizen), GameConfig.LINE_PATIENCE)
	assert_true(Formulas.is_citizen_waiting(citizen))
	citizen.phase = CaseFile.Phase.WAITING
	assert_false(Formulas.is_citizen_waiting(citizen))
	citizen.walk = 0.0
	assert_true(Formulas.is_citizen_waiting(citizen))
	assert_eq(Formulas.citizen_patience(citizen), GameConfig.STAND_PATIENCE)
	assert_eq(Formulas.citizen_patience(citizen), 90.0)
	citizen.seated = true
	assert_eq(Formulas.citizen_patience(citizen), GameConfig.SEAT_PATIENCE)
	assert_eq(Formulas.citizen_patience(citizen), 300.0)
	citizen.phase = CaseFile.Phase.WAITING_DOC
	assert_eq(Formulas.citizen_patience(citizen), GameConfig.SEAT_PATIENCE)
	citizen.seated = false
	assert_eq(Formulas.citizen_patience(citizen), GameConfig.STAND_PATIENCE)
	citizen.seated = true
	citizen.waited = 15.0
	assert_eq(Formulas.citizen_time_left(citizen), GameConfig.SEAT_PATIENCE - 15.0)
	citizen.waited = 999.0
	assert_eq(Formulas.citizen_time_left(citizen), 0.0)
	for phase in [CaseFile.Phase.CALLED, CaseFile.Phase.CALLED_DOC]:
		citizen.phase = phase
		assert_eq(Formulas.citizen_patience(citizen), GameConfig.DESK_PATIENCE)
	for phase in [CaseFile.Phase.SERVED, CaseFile.Phase.COLLECTING, CaseFile.Phase.NONE]:
		citizen.phase = phase
		assert_eq(Formulas.citizen_patience(citizen), 0.0)
		assert_false(Formulas.is_citizen_waiting(citizen))


func test_seat_leave_chance_rises_in_tiers() -> void:
	assert_eq(Formulas.seat_leave_chance(0.0), 0.0)
	assert_eq(Formulas.seat_leave_chance(60.0), 0.0)
	assert_eq(Formulas.seat_leave_chance(119.9), 0.0)
	assert_almost_eq(Formulas.seat_leave_chance(120.0), 0.1, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(179.9), 0.1, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(180.0), 0.15, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(239.9), 0.15, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(240.0), 0.2, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(299.0), 0.2, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(1000.0), 0.2, 0.0001)


func test_seat_leave_checks_list_every_passed_checkpoint() -> void:
	assert_eq(Formulas.seat_leave_checks(0.0, 119.9), [] as Array[float])
	assert_eq(Formulas.seat_leave_checks(119.0, 121.0), [120.0] as Array[float])
	assert_eq(Formulas.seat_leave_checks(119.0, 120.0), [120.0] as Array[float])
	assert_eq(Formulas.seat_leave_checks(120.0, 139.9), [] as Array[float])
	assert_eq(Formulas.seat_leave_checks(120.0, 140.0), [140.0] as Array[float])
	assert_eq(Formulas.seat_leave_checks(130.0, 200.0), [140.0, 160.0, 180.0, 200.0] as Array[float])
	assert_eq(Formulas.seat_leave_checks(0.0, 160.0), [120.0, 140.0, 160.0] as Array[float])
	assert_eq(Formulas.seat_leave_checks(250.0, 400.0), [260.0, 280.0] as Array[float])
	assert_eq(Formulas.seat_leave_checks(280.0, 400.0), [] as Array[float])
	assert_eq(Formulas.seat_leave_checks(290.0, 310.0), [] as Array[float])
	assert_eq(Formulas.seat_leave_checks(300.0, 500.0), [] as Array[float])
	assert_eq(Formulas.seat_leave_checks(150.0, 150.0), [] as Array[float])
	for point in Formulas.seat_leave_checks(0.0, 1000.0):
		assert_lt(point, GameConfig.SEAT_PATIENCE)
		assert_gt(Formulas.seat_leave_chance(point), 0.0)
	assert_eq(Formulas.seat_leave_checks(0.0, 1000.0).size(), 9)


func test_leave_complaint_rate_counts_every_lost_citizen() -> void:
	assert_eq(Formulas.leave_complaint_rate(state), 0.0)
	state.play_time = 60.0
	state.production.record(ProductionStats.LOST, "general_services", 30.0, 2)
	assert_almost_eq(Formulas.leave_complaint_rate(state), 2.0 / 60.0, 0.0001)


func test_case_outcomes() -> void:
	var simple := Formulas.case_outcome(state, _case())
	assert_almost_eq(simple.money, 20.0, 0.001)
	assert_almost_eq(simple.reputation, GameConfig.REP_CORRECT, 0.001)
	assert_almost_eq(Formulas.case_outcome(state, _case("general_services", true)).money, 40.0, 0.001)
	var urgent := _case("general_services", false, true)
	var on_time := Formulas.case_outcome(state, urgent)
	assert_almost_eq(on_time.money, 30.0, 0.001)
	assert_almost_eq(on_time.reputation, GameConfig.REP_CORRECT + GameConfig.REP_URGENT_ON_TIME, 0.001)
	urgent.age = GameConfig.URGENT_DEADLINE + 1.0
	var late := Formulas.case_outcome(state, urgent)
	assert_almost_eq(late.money, 20.0, 0.001)
	assert_almost_eq(late.reputation, GameConfig.REP_CORRECT + GameConfig.REP_URGENT_LATE, 0.001)
	var flawed := _case()
	flawed.flawed = true
	var result := Formulas.case_outcome(state, flawed)
	assert_almost_eq(result.money, 20.0 * GameConfig.FLAWED_REWARD_FACTOR, 0.001)
	assert_almost_eq(result.reputation, GameConfig.REP_FLAWED, 0.001)
	state.event_id = "audit_visit"
	assert_almost_eq(Formulas.case_outcome(state, flawed).reputation, GameConfig.REP_FLAWED * GameConfig.AUDIT_FACTOR, 0.001)
	var follow_up := _case()
	follow_up.follow_up = true
	assert_almost_eq(Formulas.case_outcome(state, follow_up).money, 20.0 * GameConfig.FOLLOW_UP_REWARD_FACTOR, 0.001)
	assert_almost_eq(Formulas.thoroughness_reward(_gs()), 1.0, 0.0001)


func test_hand_bonus_scales_with_manual_share() -> void:
	var case_file := _case()
	case_file.route.assign(["shared/reception", "general_services/review", "tax_services/signature", "shared/counter"])
	assert_eq(Formulas.hand_slots(case_file), 6)
	assert_eq(Formulas.hand_share(case_file), 0.0)
	assert_almost_eq(Formulas.case_outcome(state, case_file).money, 20.0, 0.001)
	case_file.handled = 3
	assert_almost_eq(Formulas.hand_share(case_file), 0.5, 0.001)
	assert_almost_eq(Formulas.case_outcome(state, case_file).money, 20.0 * (1.0 + GameConfig.HAND_REWARD_BONUS * 0.5), 0.001)
	case_file.handled = 99
	assert_eq(Formulas.hand_share(case_file), 1.0)
	assert_almost_eq(Formulas.case_outcome(state, case_file).money, 20.0 * (1.0 + GameConfig.HAND_REWARD_BONUS), 0.001)
	case_file.flawed = true
	assert_almost_eq(Formulas.case_outcome(state, case_file).money, 20.0 * (1.0 + GameConfig.HAND_REWARD_BONUS) * GameConfig.FLAWED_REWARD_FACTOR, 0.001)


func test_hand_slots_never_drop_below_one() -> void:
	var empty := _case()
	empty.route.clear()
	empty.handled = 1
	assert_eq(Formulas.hand_slots(empty), 1)
	assert_eq(Formulas.hand_share(empty), 1.0)
	var smuggled := _case("customs")
	smuggled.handled = 5
	assert_eq(Formulas.case_outcome(state, smuggled, true).money, 0.0)


func test_customs_outcomes() -> void:
	var cargo := _case("customs")
	cargo.contraband = true
	var seized := Formulas.case_outcome(state, cargo)
	assert_almost_eq(seized.money, 14000.0 * GameConfig.CONTRABAND_REWARD_FACTOR, 0.01)
	assert_almost_eq(seized.reputation, GameConfig.REP_CONTRABAND + GameConfig.REP_CORRECT, 0.001)
	var smuggled := Formulas.case_outcome(state, _case("customs"), true)
	assert_eq(smuggled.money, 0.0)
	assert_almost_eq(smuggled.reputation, GameConfig.REP_SMUGGLED, 0.001)


func test_station_throughput() -> void:
	var review := state.station("general_services/review")
	review.staff = 1
	var available := Formulas.availability(state, review)
	assert_almost_eq(Formulas.station_throughput(state, review), available / 5.5, 0.0001)
	assert_almost_eq(Formulas.station_case_time(state, review), 5.5, 0.0001)
	review.add_desk()
	review.staff = 2
	assert_eq(review.workers(), 2)
	assert_almost_eq(Formulas.station_throughput(state, review), 2.0 * available / 5.5, 0.0001)
	state.set_upgrade("room_speed", 9, "general_services")
	assert_almost_eq(Formulas.station_case_time(state, review), 5.5 / Formulas.level_speed(10), 0.0001)
	assert_eq(Formulas.station_throughput(state, state.station(GameConfig.RECEPTION)), 0.0)
	assert_eq(Formulas.station_throughput(state, Station.new("tax_services/review")), 0.0)
	assert_almost_eq(Formulas.station_demand(state, GameConfig.RECEPTION), 1.0 / Formulas.arrival_interval(state), 0.0001)


func test_transport_capacity() -> void:
	assert_eq(Formulas.transport_throughput(state), 0.0)
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	assert_eq(Formulas.transport_throughput(state), 0.0)
	state.add_runner(Runner.OUTPUT)
	assert_almost_eq(Formulas.transport_throughput(state), 6.0 / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	assert_almost_eq(Formulas.department_runner_transfers(state, _gs()), 3.0, 0.0001)
	assert_almost_eq(Formulas.department_transport(state, _gs()), 6.0 / GameConfig.RUNNER_TRIP_ESTIMATE / 3.0, 0.0001)
	_pipe_everything()
	assert_eq(Formulas.department_runner_transfers(state, _gs()), 0.0)
	assert_true(is_inf(Formulas.transport_throughput(state)))
	assert_true(is_inf(Formulas.department_transport(state, _gs())))
	state.set_upgrade("large_capsules", 0)
	assert_almost_eq(Formulas.department_runner_transfers(state, _gs()), 3.0 * float(GameConfig.department("general_services").complex_chance), 0.0001)
	assert_false(is_inf(Formulas.transport_throughput(state)))
	state.set_upgrade("tube_station", 0, GameConfig.ROOM_HALL)
	var route := RouteBuilder.build(CaseFile.new("general_services"))
	assert_eq(Formulas.runner_share(state, _gs(), route[0], route[1]), 1.0)
	assert_almost_eq(Formulas.runner_share(state, _gs(), route[1], route[2]), float(GameConfig.department("general_services").complex_chance), 0.0001)


func test_reject_runners_do_not_count_as_transport() -> void:
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	state.add_runner(Runner.OUTPUT)
	var before := Formulas.transport_throughput(state)
	state.add_runner(Runner.REJECT)
	state.add_runner(Runner.REJECT)
	assert_eq(Formulas.transport_throughput(state), before)
	assert_eq(Formulas.transport_throughput(state, Runner.REJECT), before)
	assert_eq(Formulas.role_demand(state, Runner.INTAKE), Formulas.role_demand(state, Runner.INTAKE))
	assert_almost_eq(Formulas.total_transfer_demand(state), Formulas.role_demand(state, Runner.INTAKE) + Formulas.role_demand(state, Runner.INTERNAL) + Formulas.role_demand(state, Runner.OUTPUT), 0.0001)
	assert_false(Formulas.runner_transfers(state, _gs()).has(Runner.REJECT))


func test_idle_transport_ignores_reject_runners() -> void:
	state.department("general_services").unlocked = false
	state.add_runner(Runner.REJECT)
	assert_eq(Formulas.total_transfer_demand(state), 0.0)
	assert_eq(Formulas.transport_throughput(state), 0.0)
	state.add_runner(Runner.INTAKE)
	assert_almost_eq(Formulas.transport_throughput(state), 2.0 / Formulas.runner_trip_time(state), 0.0001)
	assert_almost_eq(Formulas.transport_throughput(state, Runner.INTAKE), 4.0 / Formulas.runner_trip_time(state), 0.0001)


func test_reject_role_capacity_uses_the_reject_trip() -> void:
	assert_eq(Formulas.role_capacity(state, Runner.REJECT), 0.0)
	var runner := state.add_runner(Runner.REJECT)
	var trip := Formulas.reject_trip_time(state)
	assert_almost_eq(Formulas.role_capacity(state, Runner.REJECT), float(Formulas.runner_load(state, runner)) / trip, 0.0001)
	assert_almost_eq(Formulas.role_capacity(state, Runner.REJECT, 1), float(Formulas.runner_load(state, runner) + Formulas.runner_capacity(state)) / trip, 0.0001)
	runner.level = 3
	assert_eq(Formulas.role_loads(state, Runner.REJECT), Formulas.runner_capacity(state) + 3)
	assert_eq(Formulas.role_loads(state, Runner.INTAKE), 0)
	assert_almost_eq(Formulas.role_capacity(state, Runner.INTAKE), 0.0, 0.0001)


func test_reject_trip_time_follows_the_distance_to_the_piles() -> void:
	var layout := WorldLayout.get_default()
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var pile := layout.reject_point("general_services/review")
	var expected := maxf(GameConfig.REJECT_RUNNER_TRIP_ESTIMATE, 2.0 * pile.distance_to(layout.shredder_point()) / Formulas.runner_speed(state))
	assert_almost_eq(Formulas.reject_trip_time(state), expected, 0.0001)
	state.boosts["roller_skates"] = 10.0
	assert_true(Formulas.reject_trip_time(state) <= expected)
	assert_almost_eq(Formulas.reject_trip_time(state, 2.0), maxf(GameConfig.REJECT_RUNNER_TRIP_ESTIMATE, 2.0 * pile.distance_to(layout.shredder_point()) / (Formulas.runner_speed(state) * 2.0)), 0.0001)


func test_reject_trip_time_without_piles_uses_the_estimate() -> void:
	state.department("general_services").unlocked = false
	assert_eq(Formulas.reject_trip_time(state), GameConfig.REJECT_RUNNER_TRIP_ESTIMATE)
	assert_eq(Formulas.reject_trip_time(state, 3.0), GameConfig.REJECT_RUNNER_TRIP_ESTIMATE)


func test_reject_demand_needs_completed_cases() -> void:
	assert_eq(Formulas.reject_demand(state), 0.0)
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	assert_almost_eq(Formulas.reject_demand(state), Formulas.demand(state, _gs()) * GameConfig.REJECT_CHANCE, 0.0001)
	assert_eq(Formulas.role_demand(state, Runner.REJECT), Formulas.reject_demand(state))
	assert_eq(Formulas.role_demand(state, Runner.INTAKE) > 0.0, true)
	state.cases_completed = GameConfig.REJECT_MIN_CASES - 1
	assert_eq(Formulas.role_demand(state, Runner.REJECT), 0.0)


func test_department_transport_without_demand() -> void:
	state.department("general_services").unlocked = false
	state.add_runner()
	assert_eq(Formulas.total_transfer_demand(state), 0.0)
	assert_eq(Formulas.department_transport(state, _gs()), 0.0)


func test_throughput_and_bottleneck() -> void:
	assert_eq(Formulas.department_throughput(state, _gs()), 0.0)
	assert_eq(Formulas.bottleneck(state, _gs()), "transport")
	_pipe_everything()
	assert_eq(Formulas.bottleneck(state, _gs()), GameConfig.RECEPTION)
	_staff_everything()
	var review := state.station("general_services/review")
	assert_almost_eq(Formulas.department_throughput(state, _gs()), Formulas.station_throughput(state, review), 0.0001)
	assert_eq(Formulas.bottleneck(state, _gs()), "general_services/review")
	for room_id in GameConfig.office_rooms():
		state.set_upgrade("room_speed", GameConfig.ROOM_SPEED_LEVELS, room_id)
	assert_almost_eq(Formulas.department_throughput(state, _gs()), Formulas.demand(state, _gs()), 0.0001)
	assert_eq(Formulas.bottleneck(state, _gs()), "demand")
	var full_demand := Formulas.demand(state, _gs())
	state.add_review(1)
	assert_almost_eq(Formulas.demand(state, _gs()), full_demand * 0.4, 0.0001)
	assert_almost_eq(Formulas.department_throughput(state, _gs()), full_demand * 0.4, 0.0001)
	assert_eq(Formulas.bottleneck(state, _gs()), "demand")
	state.stations.erase(GameConfig.COUNTER)
	assert_eq(Formulas.department_throughput(state, _gs()), 0.0)


func test_customs_throughput_ignores_optional_inspection() -> void:
	state.unlock_department("customs")
	_pipe_everything()
	var customs := state.department("customs")
	_staff_everything()
	state.station(GameConfig.INSPECTION).staff = 0
	assert_gt(Formulas.department_throughput(state, customs), 0.0)
	assert_ne(Formulas.bottleneck(state, customs), GameConfig.INSPECTION)


func test_expected_value_workload_and_waiting() -> void:
	assert_almost_eq(Formulas.expected_case_value(state, _gs()), 22.0 * (1.0 - 0.12 + 0.12 * GameConfig.FLAWED_REWARD_FACTOR), 0.001)
	assert_eq(Formulas.workload(state, _gs()), 0.0)
	for i in 4:
		state.station("general_services/review").inbox.append(_case())
		var citizen := _case()
		citizen.phase = CaseFile.Phase.WAITING
		state.citizens.append(citizen)
	var served := _case()
	served.phase = CaseFile.Phase.WAITING_DOC
	state.citizens.append(served)
	assert_almost_eq(Formulas.workload(state, _gs()), 4.0 / 24.0, 0.0001)
	assert_eq(Formulas.waiting_count(state, _gs()), 4)
	state.unlock_department("tax_services")
	assert_eq(Formulas.waiting_count(state, state.department("tax_services")), 0)
	state.unlock_department("customs")
	var customs := state.department("customs")
	state.station("customs/dock").inbox.append(_case("customs"))
	assert_eq(Formulas.waiting_count(state, customs), 1)
	state.stations.erase("customs/dock")
	assert_eq(Formulas.waiting_count(state, customs), 0)
	state.stations.erase("tax_services/review")
	state.stations.erase("tax_services/signature")
	assert_eq(Formulas.workload(state, state.department("tax_services")), 0.0)


func test_lead_values_are_neutral_without_levels_and_outside_offices() -> void:
	for upgrade_id in GameConfig.LEAD_TRACKS:
		assert_eq(Formulas.lead_value(state, upgrade_id, "general_services"), Formulas.lead_neutral(upgrade_id), upgrade_id)
		assert_eq(Formulas.lead_value(state, upgrade_id, GameConfig.ROOM_KITCHEN), Formulas.lead_neutral(upgrade_id), upgrade_id)
		assert_eq(Formulas.lead_value(state, upgrade_id, ""), Formulas.lead_neutral(upgrade_id), upgrade_id)
	assert_eq(Formulas.lead_value(state, "lead_breaks", "general_services"), 1.0)
	assert_eq(Formulas.lead_value(state, "lead_calm", GameConfig.ROOM_HALL), 0.0)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_breaks", 10, "general_services")
	assert_almost_eq(Formulas.lead_value(state, "lead_breaks", "general_services"), 0.75 * pow(0.995, 10), 0.0001)
	assert_eq(Formulas.lead_value(state, "lead_breaks", "tax_services"), 1.0)
	assert_eq(Formulas.lead_value(state, "lead_breaks", GameConfig.ROOM_TOILETS), 1.0)
	state.set_upgrade("lead_calm", 5, GameConfig.ROOM_HALL)
	assert_eq(state.upgrade_level("lead_calm", GameConfig.ROOM_HALL), 5)
	assert_eq(Formulas.lead_value(state, "lead_calm", GameConfig.ROOM_HALL), 0.0)


func test_team_leads_are_counted_per_office_room() -> void:
	assert_false(Formulas.has_lead(state, "general_services"))
	assert_eq(Formulas.team_lead_count(state), 0)
	var interval := Formulas.dispute_interval(state, 0.5)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("team_lead", 1, GameConfig.HALL_INTAKE)
	assert_true(Formulas.has_lead(state, "general_services"))
	assert_true(Formulas.has_lead(state, GameConfig.HALL_INTAKE))
	assert_false(Formulas.has_lead(state, GameConfig.HALL_PICKUP))
	assert_false(Formulas.has_lead(state, "tax_services"))
	assert_eq(Formulas.team_lead_count(state), 2)
	assert_almost_eq(Formulas.dispute_interval(state, 0.5), interval * (1.0 + GameConfig.LEAD_DISPUTE_RELIEF * 2.0), 0.001)


func test_patrol_speed_and_cooldown_follow_the_lead() -> void:
	assert_eq(Formulas.patrol_speed(state, "general_services"), 1.0)
	assert_almost_eq(Formulas.patrol_cooldown(state, "general_services"), 120.0, 0.0001)
	assert_almost_eq(Formulas.patrol_cooldown(state, GameConfig.ROOM_KITCHEN), 120.0, 0.0001)
	assert_eq(Formulas.patrol_speed(state, GameConfig.ROOM_KITCHEN), 1.0)
	state.set_upgrade("team_lead", 1, "general_services")
	assert_eq(Formulas.patrol_speed(state, "general_services"), 1.0)
	state.lead_patrols["general_services"] = 10.0
	assert_true(state.is_patrolling("general_services"))
	assert_almost_eq(Formulas.patrol_speed(state, "general_services"), 2.0, 0.0001)
	assert_eq(Formulas.patrol_speed(state, "tax_services"), 1.0)
	state.set_upgrade("lead_patrol", 10, "general_services")
	assert_almost_eq(Formulas.patrol_speed(state, "general_services"), 2.0 + 10.0 * 0.01, 0.0001)
	state.set_upgrade("lead_cooldown", 5, "general_services")
	assert_almost_eq(Formulas.patrol_cooldown(state, "general_services"), 120.0 * pow(0.995, 5), 0.0001)
	assert_almost_eq(Formulas.patrol_cooldown(state, "tax_services"), 120.0, 0.0001)
	var review := state.station("general_services/review")
	assert_almost_eq(Formulas.work_speed(state, review), 2.0 + 10.0 * 0.01, 0.0001)
	assert_eq(Formulas.work_speed(state, state.station(GameConfig.RECEPTION)), 1.0)
	state.lead_patrols.erase("general_services")
	assert_eq(Formulas.work_speed(state, review), 1.0)


func test_lead_breaks_shorten_rest_limits_except_sleep_and_chat() -> void:
	state.set_upgrade("wake_service", 5)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_breaks", 20, "general_services")
	var factor := 0.75 * pow(0.995, 20)
	for rest_state: String in [DeskMood.FETCH, DeskMood.SLOW, DeskMood.LUNCH, DeskMood.LOO, DeskMood.COFFEE]:
		var base := Formulas.base_rest_limit(state, rest_state)
		assert_eq(Formulas.rest_limit(state, rest_state), base, rest_state)
		assert_eq(Formulas.rest_limit(state, rest_state, "tax_services"), base, rest_state)
		assert_almost_eq(Formulas.rest_limit(state, rest_state, "general_services"), base * factor, 0.0001, rest_state)
	for rest_state: String in [DeskMood.ASLEEP, DeskMood.CHAT]:
		assert_eq(Formulas.rest_limit(state, rest_state, "general_services"), Formulas.base_rest_limit(state, rest_state), rest_state)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.SICK, "general_services"), GameConfig.SICK_SECONDS * 0.75, 0.0001)
	assert_eq(Formulas.rest_limit(state, DeskMood.SICK, "tax_services"), GameConfig.SICK_SECONDS)
	state.set_upgrade("wake_service", 0)
	assert_true(is_inf(Formulas.rest_limit(state, DeskMood.ASLEEP, "general_services")))


func test_lead_health_shortens_sickness() -> void:
	var mood := DeskMood.new()
	assert_eq(Formulas.sick_time_left(state, mood, "general_services"), 0.0)
	mood.rest(DeskMood.SICK)
	var plain := Formulas.sick_time_left(state, mood, "general_services")
	assert_almost_eq(plain, GameConfig.SICK_SECONDS / Formulas.sick_recovery_speed(0), 0.0001)
	var share := Formulas.sick_share(state, "general_services")
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_health", 10, "general_services")
	var factor := 0.75 * pow(0.995, 10)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.SICK, "general_services"), GameConfig.SICK_SECONDS * factor, 0.0001)
	assert_eq(Formulas.rest_limit(state, DeskMood.SICK), GameConfig.SICK_SECONDS)
	assert_almost_eq(Formulas.sick_time_left(state, mood, "general_services"), plain * factor, 0.0001)
	assert_almost_eq(Formulas.sick_time_left(state, mood), plain, 0.0001)
	assert_almost_eq(Formulas.sick_time_left_with(state, mood, 2, "general_services"), GameConfig.SICK_SECONDS * factor / Formulas.sick_recovery_speed(2), 0.0001)
	mood.resting = 40.0
	assert_almost_eq(Formulas.sick_time_left(state, mood, "general_services"), (GameConfig.SICK_SECONDS * factor - 40.0) / Formulas.sick_recovery_speed(0), 0.0001)
	assert_lt(Formulas.sick_share(state, "general_services"), share)
	assert_eq(Formulas.sick_share(state, "tax_services"), share)


func test_lead_focus_slows_drowsiness_in_its_room() -> void:
	state.unlock_department("tax_services")
	var review := state.station("general_services/review")
	var tax := state.station("tax_services/review")
	var reception := state.station(GameConfig.RECEPTION)
	var available := Formulas.availability(state, review)
	assert_eq(Formulas.drowsiness_rate(state, review), 1.0)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_focus", 10, "general_services")
	assert_almost_eq(Formulas.drowsiness_rate(state, review), 0.7 * pow(0.995, 10), 0.0001)
	assert_eq(Formulas.drowsiness_rate(state, tax), 1.0)
	assert_eq(Formulas.drowsiness_rate(state, reception), 1.0)
	assert_gt(Formulas.availability(state, review), available)
	state.set_upgrade("lead_focus", 4, GameConfig.HALL_INTAKE)
	assert_eq(Formulas.drowsiness_rate(state, reception), 1.0)
	state.set_upgrade("team_lead", 1, GameConfig.HALL_INTAKE)
	assert_almost_eq(Formulas.drowsiness_rate(state, reception), 0.7 * pow(0.995, 4), 0.0001)
	assert_eq(Formulas.drowsiness_rate(state, state.station(GameConfig.COUNTER)), 1.0)
	assert_eq(Formulas.lead_room(reception), GameConfig.HALL_INTAKE)
	state.event_id = "coffee_escalation"
	assert_almost_eq(Formulas.drowsiness_rate(state, review), 0.7 * pow(0.995, 10) * Formulas.event_drowsy(state), 0.0001)


func test_department_calm_needs_a_lead() -> void:
	assert_eq(Formulas.department_calm(state, "general_services"), 0.0)
	state.set_upgrade("lead_calm", 10, "general_services")
	assert_eq(Formulas.department_calm(state, "general_services"), 0.0)
	state.set_upgrade("team_lead", 1, "general_services")
	assert_almost_eq(Formulas.department_calm(state, "general_services"), 0.25 + 10.0 * 0.005, 0.0001)
	assert_eq(Formulas.department_calm(state, "tax_services"), 0.0)
	state.set_upgrade("team_lead", 1, GameConfig.ROOM_HALL)
	assert_eq(Formulas.department_calm(state, GameConfig.ROOM_HALL), 0.0)


func test_tray_size_follows_the_room_trays_track() -> void:
	assert_eq(Formulas.tray_size(state, "general_services"), GameConfig.TRAY_BASE)
	assert_eq(Formulas.tray_size(state, GameConfig.ROOM_KITCHEN), GameConfig.TRAY_BASE)
	state.set_upgrade("room_trays", 5, "general_services")
	assert_eq(Formulas.tray_size(state, "general_services"), GameConfig.TRAY_BASE + 5)
	assert_eq(Formulas.tray_size(state, "tax_services"), GameConfig.TRAY_BASE)
	state.set_upgrade("room_trays", 999, "general_services")
	assert_eq(Formulas.tray_size(state, "general_services"), GameConfig.TRAY_MAX)
	assert_eq(GameConfig.TRAY_MAX, 25)
	state.set_upgrade("room_trays", 3, GameConfig.ROOM_HALL)
	assert_eq(Formulas.tray_size(state, GameConfig.ROOM_HALL), GameConfig.TRAY_BASE + 3)


func test_early_levels_are_much_cheaper() -> void:
	assert_almost_eq(Formulas.early_discount(0), GameConfig.EARLY_DISCOUNT_START, 0.0001)
	assert_almost_eq(Formulas.early_discount(-3), GameConfig.EARLY_DISCOUNT_START, 0.0001)
	assert_eq(Formulas.early_discount(GameConfig.EARLY_DISCOUNT_LEVELS), 1.0)
	assert_eq(Formulas.early_discount(500), 1.0)
	for level in GameConfig.EARLY_DISCOUNT_LEVELS:
		assert_lt(Formulas.early_discount(level), Formulas.early_discount(level + 1))
	var config := GameConfig.upgrade("room_speed")
	assert_almost_eq(Formulas.track_cost("room_speed", 0, "general_services"), float(config.cost) * GameConfig.EARLY_DISCOUNT_START, 0.0001)
	for level in 30:
		assert_lt(Formulas.track_cost("room_speed", level, "general_services"), Formulas.track_cost("room_speed", level + 1, "general_services"))


func test_ramped_sum_adds_every_discounted_level() -> void:
	for start in [0, 4, 9, 10, 25]:
		for count in [0, 1, 3, 12, 40]:
			var expected := 0.0
			for index in count:
				expected += Formulas.track_cost("work_ethic", start + index)
			assert_almost_eq(Formulas.track_bulk_cost("work_ethic", start, count), expected, maxf(0.001, expected * 0.000001), "%d/%d" % [start, count])


func test_ramped_affordable_finds_the_largest_amount() -> void:
	var cost := Formulas.track_cost("work_ethic", 2)
	var growth := float(GameConfig.upgrade("work_ethic").growth)
	assert_eq(Formulas.ramped_affordable(cost, growth, 2, 50, cost - 1.0), 0)
	assert_eq(Formulas.ramped_affordable(cost, growth, 2, 0, 1e12), 0)
	assert_eq(Formulas.ramped_affordable(cost, growth, 2, 50, 1e30), 50)
	assert_eq(Formulas.ramped_affordable(0.0, growth, 2, 7, 1.0), 7)
	var money := Formulas.track_bulk_cost("work_ethic", 2, 17)
	assert_eq(Formulas.ramped_affordable(cost, growth, 2, 50, money), 17)
	assert_eq(Formulas.ramped_affordable(cost, growth, 2, 50, money - 0.01), 16)


func test_staff_and_station_prices_use_the_early_discount() -> void:
	assert_almost_eq(Formulas.runner_cost(state), GameConfig.RUNNER_COST * GameConfig.EARLY_DISCOUNT_START, 0.0001)
	assert_almost_eq(Formulas.hr_cost(state), GameConfig.HR_COST * GameConfig.EARLY_DISCOUNT_START, 0.0001)
	assert_almost_eq(Formulas.coffee_intern_cost(state), GameConfig.COFFEE_INTERN_COST * GameConfig.EARLY_DISCOUNT_START, 0.0001)
	assert_almost_eq(Formulas.tube_segment_cost(0), GameConfig.TUBE_SEGMENT_COST * GameConfig.EARLY_DISCOUNT_START, 0.0001)
	var station := state.station("general_services/review")
	assert_almost_eq(Formulas.desk_cost(station), float(GameConfig.station_kind("review").desk_cost) * GameConfig.EARLY_DISCOUNT_START, 0.0001)


func test_later_ticket_tracks_skip_the_early_discount() -> void:
	assert_eq(Formulas.track_price_level("ticket_speed_2", 0), GameConfig.TICKET_UNLOCK_LEVEL)
	assert_eq(Formulas.track_price_level("ticket_speed", 3), 3)
	assert_almost_eq(Formulas.track_cost("ticket_machine_2", 0), GameConfig.TICKET_SECOND_COST, 0.001)
