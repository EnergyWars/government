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


func test_station_costs_grow() -> void:
	var review := state.station("general_services/review")
	assert_almost_eq(Formulas.desk_cost(review), 120.0, 0.001)
	assert_almost_eq(Formulas.hire_cost(review), 240.0 * GameConfig.HIRE_GROWTH, 0.001)
	assert_almost_eq(Formulas.upgrade_cost(review), 90.0, 0.001)
	assert_almost_eq(Formulas.specialist_cost(review), 1200.0, 0.001)
	review.add_desk()
	review.level = 2
	review.add_specialist()
	assert_almost_eq(Formulas.desk_cost(review), 120.0 * GameConfig.DESK_GROWTH, 0.001)
	assert_almost_eq(Formulas.upgrade_cost(review), 90.0 * GameConfig.UPGRADE_GROWTH, 0.001)
	assert_almost_eq(Formulas.specialist_cost(review), 1200.0 * GameConfig.SPECIALIST_GROWTH, 0.001)


func test_cost_multipliers_per_department_and_shared_station() -> void:
	state.unlock_department("tax_services")
	assert_almost_eq(Formulas.desk_cost(state.station("tax_services/review")), 360.0, 0.001)
	assert_eq(Formulas.cost_multiplier_for(state.station(GameConfig.RECEPTION)), 1.0)
	state.unlock_department("business_licences")
	assert_eq(Formulas.cost_multiplier_for(state.station(GameConfig.INSPECTION)), 10.0)


func test_staff_costs_follow_the_department_staff_multiplier() -> void:
	state.unlock_department("customs")
	var review := state.station("customs/review")
	var multiplier := float(GameConfig.department("customs").staff_multiplier)
	assert_eq(Formulas.staff_multiplier_for(review), multiplier)
	assert_almost_eq(Formulas.hire_cost(review), 240.0 * multiplier, 0.01)
	assert_almost_eq(Formulas.desk_cost(review), 120.0 * float(GameConfig.department("customs").cost_multiplier), 0.01)
	assert_almost_eq(Formulas.supervisor_cost(state.department("customs")), GameConfig.SUPERVISOR_COST * multiplier, 0.01)
	assert_almost_eq(Formulas.training_cost(review, "skill", 0), 240.0 * multiplier * float(GameConfig.OFFICIAL_TRAININGS.skill.cost), 0.01)
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


func test_staff_and_research_costs() -> void:
	assert_almost_eq(Formulas.supervisor_cost(_gs()), GameConfig.SUPERVISOR_COST, 0.001)
	_gs().supervisors = 1
	assert_almost_eq(Formulas.supervisor_cost(_gs()), GameConfig.SUPERVISOR_COST * GameConfig.SUPERVISOR_GROWTH, 0.001)
	assert_almost_eq(Formulas.runner_cost(state), GameConfig.RUNNER_COST, 0.001)
	state.add_runner()
	assert_almost_eq(Formulas.runner_cost(state), GameConfig.RUNNER_COST * GameConfig.RUNNER_GROWTH, 0.001)
	assert_almost_eq(Formulas.research_cost("briefcase", 0), 150.0, 0.001)
	assert_almost_eq(Formulas.research_cost("briefcase", 1), 375.0, 0.001)


func test_station_speed_combines_level_research_and_supervisors() -> void:
	var review := state.station("general_services/review")
	assert_almost_eq(Formulas.station_speed(state, review), 1.0, 0.001)
	review.level = 3
	state.research["digital_records"] = 1
	_gs().supervisors = 1
	assert_almost_eq(Formulas.station_speed(state, review), Formulas.level_speed(3) * 1.2 * 1.2, 0.001)
	state.research["scanners"] = 2
	assert_almost_eq(Formulas.research_speed_multiplier(state, "reception"), 1.6, 0.001)
	assert_eq(Formulas.research_speed_multiplier(state, "inspection"), 1.0)
	assert_almost_eq(Formulas.station_speed(state, state.station(GameConfig.RECEPTION)), 1.6, 0.001)


func test_base_and_required_times() -> void:
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	assert_almost_eq(Formulas.base_time(review, _gs(), false, false, state), 5.0, 0.001)
	assert_almost_eq(Formulas.base_time(review, _gs(), true, false, state), 10.0, 0.001)
	assert_almost_eq(Formulas.base_time(review, _gs(), true, true, state), 5.0, 0.001)
	assert_almost_eq(Formulas.base_time(signature, _gs(), true, false, state), 4.0, 0.001)
	assert_almost_eq(Formulas.base_time(state.station(GameConfig.RECEPTION), _gs(), true, false, state), 2.0, 0.001)
	_gs().thoroughness = 2
	assert_almost_eq(Formulas.base_time(review, _gs(), false, false, state), 5.0 * 1.4, 0.001)
	review.level = 2
	assert_almost_eq(Formulas.required_time(state, review, _case()), 5.0 * 1.4 / Formulas.level_speed(2), 0.001)
	state.research["ai_classification"] = 1
	assert_almost_eq(Formulas.complex_time_factor(state, false), 1.5, 0.001)
	assert_eq(Formulas.complex_time_factor(state, true), 1.0)


func test_referral_uses_station_time_with_case_thoroughness() -> void:
	state.unlock_department("housing")
	var housing := state.department("housing")
	housing.thoroughness = 0
	var registry := state.station("general_services/review")
	assert_almost_eq(Formulas.base_time(registry, housing, false, false, state), 5.0 * 0.6, 0.001)
	state.unlock_department("business_licences")
	var inspection := state.station(GameConfig.INSPECTION)
	assert_almost_eq(Formulas.base_time(inspection, state.department("business_licences"), true, false, state), 14.0, 0.001)


func test_error_and_flag_chances() -> void:
	assert_almost_eq(Formulas.error_chance(state, _gs()), 0.12, 0.0001)
	assert_almost_eq(Formulas.error_chance(state, _gs(), true), 0.036, 0.0001)
	state.research["quality_training"] = 1
	assert_almost_eq(Formulas.error_chance(state, _gs()), 0.09, 0.0001)
	state.research["ai_classification"] = 1
	assert_almost_eq(Formulas.error_chance(state, _gs()), 0.045, 0.0001)
	state.unlock_department("customs")
	var review := state.station("customs/review")
	assert_almost_eq(Formulas.flag_chance(review), 0.6, 0.0001)
	review.specialists = 3
	assert_almost_eq(Formulas.flag_chance(review), 0.96, 0.0001)


func test_reputation_drives_rewards_and_arrivals() -> void:
	assert_eq(Formulas.reputation_multiplier(state), 1.0)
	state.reputation = 400.0
	assert_almost_eq(Formulas.reputation_multiplier(state), 2.0, 0.0001)
	state.reputation = 64.0
	assert_almost_eq(Formulas.popularity(state), 2.0, 0.0001)
	assert_almost_eq(Formulas.arrival_interval(state, _gs()), 3.5, 0.0001)
	state.reputation = 1e6
	assert_eq(Formulas.popularity(state), GameConfig.MAX_POPULARITY)
	state.reputation = 0.0
	state.research["online_portal"] = 1
	assert_almost_eq(Formulas.arrival_interval(state, _gs()), 7.0 / 1.25, 0.0001)


func test_events_change_arrivals() -> void:
	state.unlock_department("tax_services")
	var tax := state.department("tax_services")
	assert_eq(Formulas.event_arrival_multiplier(state, "tax_services"), 1.0)
	state.event_id = "rush_hour"
	assert_eq(Formulas.event_arrival_multiplier(state, "general_services"), 2.0)
	state.event_id = "tax_deadline"
	assert_eq(Formulas.event_arrival_multiplier(state, "general_services"), 1.0)
	assert_almost_eq(Formulas.arrival_interval(state, tax), 3.0, 0.0001)


func test_player_and_runner_stats() -> void:
	assert_eq(Formulas.patience(state), GameConfig.BASE_PATIENCE)
	assert_eq(Formulas.carry_capacity(state), 6)
	assert_eq(Formulas.runner_capacity(state), 2)
	assert_eq(Formulas.work_power(state), 2.5)
	state.research["comfortable_lobby"] = 1
	state.research["briefcase"] = 2
	state.research["trolleys"] = 1
	state.research["work_ethic"] = 2
	assert_almost_eq(Formulas.patience(state), GameConfig.BASE_PATIENCE * 1.4, 0.001)
	assert_eq(Formulas.carry_capacity(state), 10)
	assert_eq(Formulas.runner_capacity(state), 3)
	assert_almost_eq(Formulas.work_power(state), 5.0, 0.001)


func test_citizens_bring_their_own_patience() -> void:
	assert_eq(Formulas.patience_factor(state, 7), 1.0)
	state.cases_completed = GameConfig.PATIENCE_SPREAD_MIN_CASES
	var samples := 2000
	var lowest := INF
	var highest := -INF
	var total := 0.0
	for serial in samples:
		var factor := Formulas.patience_factor(state, serial)
		assert_between(factor, GameConfig.PATIENCE_MIN_FACTOR, GameConfig.PATIENCE_MAX_FACTOR)
		lowest = minf(lowest, factor)
		highest = maxf(highest, factor)
		total += factor
	assert_lt(lowest, GameConfig.PATIENCE_MIN_FACTOR + 0.05)
	assert_gt(highest, GameConfig.PATIENCE_MAX_FACTOR - 0.05)
	assert_almost_eq(total / samples, (GameConfig.PATIENCE_MIN_FACTOR + GameConfig.PATIENCE_MAX_FACTOR) / 2.0, 0.05)
	assert_eq(Formulas.patience_factor(state, 42), Formulas.patience_factor(state, 42))


func test_patience_spread_averages_the_base_patience() -> void:
	assert_lt(GameConfig.PATIENCE_MIN_FACTOR, 1.0)
	assert_gt(GameConfig.PATIENCE_MAX_FACTOR, 1.0)
	assert_almost_eq((GameConfig.PATIENCE_MIN_FACTOR + GameConfig.PATIENCE_MAX_FACTOR) / 2.0, 1.0, 0.0001)
	assert_gte(GameConfig.BASE_PATIENCE * GameConfig.PATIENCE_MIN_FACTOR, 20.0)


func test_citizen_patience_and_complaint_chance_follow_the_factor() -> void:
	var calm := _case()
	calm.patience_factor = GameConfig.PATIENCE_MAX_FACTOR
	var hurried := _case()
	hurried.patience_factor = GameConfig.PATIENCE_MIN_FACTOR
	assert_almost_eq(Formulas.citizen_patience(state, calm), GameConfig.BASE_PATIENCE * GameConfig.PATIENCE_MAX_FACTOR, 0.001)
	assert_almost_eq(Formulas.citizen_patience(state, hurried), GameConfig.BASE_PATIENCE * GameConfig.PATIENCE_MIN_FACTOR, 0.001)
	state.research["comfortable_lobby"] = 1
	assert_almost_eq(Formulas.citizen_patience(state, hurried), GameConfig.BASE_PATIENCE * 1.4 * GameConfig.PATIENCE_MIN_FACTOR, 0.001)
	assert_almost_eq(Formulas.leave_complaint_chance(calm), GameConfig.LEAVE_COMPLAINT_CHANCE * GameConfig.PATIENCE_MAX_FACTOR, 0.0001)
	assert_almost_eq(Formulas.leave_complaint_chance(hurried), GameConfig.LEAVE_COMPLAINT_CHANCE * GameConfig.PATIENCE_MIN_FACTOR, 0.0001)
	assert_almost_eq(Formulas.leave_complaint_chance(_case()), GameConfig.LEAVE_COMPLAINT_CHANCE, 0.0001)
	calm.patience_factor = 10.0
	assert_eq(Formulas.leave_complaint_chance(calm), 1.0)
	calm.patience_factor = -1.0
	assert_eq(Formulas.leave_complaint_chance(calm), 0.0)


func test_leave_complaint_rate_follows_losses_up_to_the_cooldown() -> void:
	assert_eq(Formulas.leave_complaint_rate(state), 0.0)
	state.play_time = 60.0
	state.production.record(ProductionStats.LOST, "general_services", 30.0, 2)
	assert_almost_eq(Formulas.leave_complaint_rate(state), 2.0 / 60.0 * GameConfig.LEAVE_COMPLAINT_CHANCE, 0.0001)
	state.production.record(ProductionStats.LOST, "general_services", 40.0, 500)
	assert_almost_eq(Formulas.leave_complaint_rate(state), 1.0 / GameConfig.LEAVE_COMPLAINT_COOLDOWN, 0.0001)


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


func test_hand_bonus_scales_with_manual_share() -> void:
	var case_file := _case()
	case_file.route.assign(["shared/reception", "general_services/review", "general_services/signature", "shared/counter"])
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
	var available := Formulas.availability(state, review)
	assert_almost_eq(Formulas.station_throughput(state, review), available / 5.5, 0.0001)
	review.add_specialist()
	assert_almost_eq(Formulas.station_throughput(state, review), 2.0 * available / 5.0, 0.0001)
	assert_eq(Formulas.station_throughput(state, state.station(GameConfig.RECEPTION)), 0.0)
	assert_eq(Formulas.station_throughput(state, Station.new("tax_services/review")), 0.0)
	assert_almost_eq(Formulas.station_demand(state, GameConfig.RECEPTION), 1.0 / 7.0, 0.0001)


func test_transport_capacity() -> void:
	assert_eq(Formulas.transport_throughput(state), 0.0)
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	assert_eq(Formulas.transport_throughput(state), 0.0)
	state.add_runner(Runner.OUTPUT)
	assert_almost_eq(Formulas.transport_throughput(state), 6.0 / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	assert_eq(Formulas.transfers_per_case(_gs()), 3)
	assert_almost_eq(Formulas.department_transport(state, _gs()), 6.0 / GameConfig.RUNNER_TRIP_ESTIMATE / 3.0, 0.0001)
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	assert_true(is_inf(Formulas.transport_throughput(state)))
	assert_true(is_inf(Formulas.department_transport(state, _gs())))


func test_department_transport_without_demand() -> void:
	state.department("general_services").unlocked = false
	state.add_runner()
	assert_eq(Formulas.total_transfer_demand(state), 0.0)
	assert_eq(Formulas.department_transport(state, _gs()), 0.0)


func test_throughput_and_bottleneck() -> void:
	assert_eq(Formulas.department_throughput(state, _gs()), 0.0)
	assert_eq(Formulas.bottleneck(state, _gs()), "transport")
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	assert_eq(Formulas.bottleneck(state, _gs()), GameConfig.RECEPTION)
	_staff_everything()
	var review := state.station("general_services/review")
	assert_almost_eq(Formulas.department_throughput(state, _gs()), Formulas.station_throughput(state, review), 0.0001)
	assert_eq(Formulas.bottleneck(state, _gs()), "general_services/review")
	for key in state.stations:
		state.stations[key].level = 20
	assert_almost_eq(Formulas.department_throughput(state, _gs()), 1.0 / 7.0, 0.0001)
	assert_eq(Formulas.bottleneck(state, _gs()), "demand")
	state.reputation = 1e6
	assert_ne(Formulas.bottleneck(state, _gs()), "demand")
	state.stations.erase(GameConfig.COUNTER)
	assert_eq(Formulas.department_throughput(state, _gs()), 0.0)


func test_customs_throughput_ignores_optional_inspection() -> void:
	state.unlock_department("customs")
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
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
		state.station(GameConfig.RECEPTION).inbox.append(_case())
	assert_almost_eq(Formulas.workload(state, _gs()), 4.0 / 32.0, 0.0001)
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
