extends GutTest

const REVIEW := "general_services/review"
const SIGNATURE := "general_services/signature"

var state: GameState


func before_each() -> void:
	state = GameState.create_new(31)


func _gain(entry_upgrades: Array, id: String) -> float:
	for upgrade: Dictionary in entry_upgrades:
		if upgrade.id == id:
			return float(upgrade.gain)
	return -1.0


func _ids(upgrades: Array) -> Array[String]:
	var result: Array[String] = []
	for upgrade: Dictionary in upgrades:
		result.append(str(upgrade.id) + ":" + str(upgrade.research))
	result.sort()
	return result


func _assert_sorted(upgrades: Array) -> void:
	for index in range(1, upgrades.size()):
		assert_true(float(upgrades[index - 1].gain) >= float(upgrades[index].gain))


func test_load_handles_missing_and_unlimited_capacity() -> void:
	assert_eq(ThroughputReport.load_of(0.0, 0.0), 0.0)
	assert_eq(ThroughputReport.load_of(0.5, 0.0), 1.0)
	assert_eq(ThroughputReport.load_of(2.0, INF), 0.0)
	assert_almost_eq(ThroughputReport.load_of(1.0, 4.0), 0.25, 0.0001)


func test_area_sorts_upgrades_by_gain() -> void:
	var upgrades: Array[Dictionary] = [ThroughputReport.upgrade("a", 1.0), ThroughputReport.upgrade("b", 3.0), ThroughputReport.upgrade("c", 2.0)]
	var entry := ThroughputReport.area(ThroughputReport.STATION, "k", 2.0, 4.0, upgrades)
	assert_eq(entry.area, ThroughputReport.STATION)
	assert_eq(entry.key, "k")
	assert_almost_eq(float(entry.load), 0.5, 0.0001)
	assert_eq((entry.upgrades as Array).map(func(u: Dictionary) -> String: return u.id), ["b", "c", "a"])
	var plain := ThroughputReport.upgrade("x", 1.5)
	assert_eq(plain.effect, ThroughputReport.CAPACITY)
	assert_eq(plain.research, "")


func test_can_research_respects_requirements_and_max_level() -> void:
	assert_true(ThroughputReport.can_research(state, "trolleys"))
	assert_false(ThroughputReport.can_research(state, "complaint_tube"))
	state.research["shredder_service"] = 1
	assert_true(ThroughputReport.can_research(state, "complaint_tube"))
	state.research["trolleys"] = int(GameConfig.RESEARCH.trolleys.max_level)
	assert_false(ThroughputReport.can_research(state, "trolleys"))


func test_station_case_time_and_throughput() -> void:
	var review := state.station(REVIEW)
	var case_time := Formulas.station_case_time(state, review, false)
	assert_gt(case_time, 0.0)
	assert_almost_eq(Formulas.station_throughput(state, review), Formulas.availability(state, review) / case_time, 0.0001)
	review.staff = 0
	assert_eq(Formulas.station_throughput(state, review), 0.0)
	var unused := Station.new("tax_services/review")
	unused.staff = 1
	assert_eq(Formulas.station_case_time(state, unused, false), 0.0)
	assert_eq(Formulas.station_throughput(state, unused), 0.0)


func test_station_gains_match_the_real_upgrade() -> void:
	var review := state.station(REVIEW)
	var dept := state.department("general_services")
	var upgrades := ThroughputReport.station_upgrades(state, review)
	assert_eq(_ids(upgrades), ["desk:", "level:", "research:digital_records", "specialist:", "supervisor:"])
	var before := Formulas.station_throughput(state, review)
	review.level += 1
	assert_almost_eq(_gain(upgrades, ThroughputReport.LEVEL), Formulas.station_throughput(state, review) - before, 0.0001)
	review.level -= 1
	dept.supervisors += 1
	assert_almost_eq(_gain(upgrades, ThroughputReport.SUPERVISOR), Formulas.station_throughput(state, review) - before, 0.0001)
	dept.supervisors -= 1
	state.research["digital_records"] = 1
	assert_almost_eq(_gain(upgrades, ThroughputReport.RESEARCH), Formulas.station_throughput(state, review) - before, 0.0001)
	state.research.erase("digital_records")
	review.add_desk()
	review.staff = 2
	assert_almost_eq(_gain(upgrades, ThroughputReport.DESK), Formulas.station_throughput(state, review) - before, 0.0001)


func test_specialist_gain_includes_faster_complex_cases() -> void:
	var review := state.station(REVIEW)
	var gain := _gain(ThroughputReport.station_upgrades(state, review), ThroughputReport.SPECIALIST)
	var before := Formulas.station_throughput(state, review)
	review.add_specialist()
	assert_almost_eq(gain, Formulas.station_throughput(state, review) - before, 0.0001)


func test_station_offers_hiring_for_a_free_desk() -> void:
	var review := state.station(REVIEW)
	review.add_desk()
	var upgrades := ThroughputReport.station_upgrades(state, review)
	assert_true(_gain(upgrades, ThroughputReport.HIRE) > 0.0)
	assert_eq(_gain(upgrades, ThroughputReport.DESK), -1.0)
	var before := Formulas.station_throughput(state, review)
	review.staff += 1
	assert_almost_eq(_gain(upgrades, ThroughputReport.HIRE), Formulas.station_throughput(state, review) - before, 0.0001)
	_assert_sorted(upgrades)


func test_machine_station_offers_machines() -> void:
	var signature := state.station(SIGNATURE)
	assert_true(signature.machine)
	var upgrades := ThroughputReport.station_upgrades(state, signature)
	assert_true(_gain(upgrades, ThroughputReport.MACHINE) > 0.0)
	assert_eq(_gain(upgrades, ThroughputReport.HIRE), -1.0)
	assert_eq(_gain(upgrades, ThroughputReport.SPECIALIST), -1.0)
	signature.add_desk()
	assert_eq(_gain(ThroughputReport.station_upgrades(state, signature), ThroughputReport.MACHINE), -1.0)


func test_fully_upgraded_station_offers_nothing() -> void:
	var review := state.station(REVIEW)
	review.add_desk()
	review.staff = review.desks
	review.level = GameConfig.MAX_STATION_LEVEL
	for index in GameConfig.MAX_SPECIALISTS:
		review.add_specialist()
	state.department("general_services").supervisors = GameConfig.MAX_SUPERVISORS
	state.research["digital_records"] = int(GameConfig.RESEARCH.digital_records.max_level)
	assert_true(ThroughputReport.station_upgrades(state, review).is_empty())
	assert_true(ThroughputReport.station_upgrades(state, Station.new("tax_services/review")).is_empty())


func test_station_area_reports_demand_and_capacity() -> void:
	var review := state.station(REVIEW)
	var entry := ThroughputReport.station_area(state, review)
	assert_eq(entry.area, ThroughputReport.STATION)
	assert_eq(entry.key, REVIEW)
	assert_almost_eq(float(entry.demand), Formulas.station_demand(state, REVIEW), 0.0001)
	assert_almost_eq(float(entry.capacity), Formulas.station_throughput(state, review), 0.0001)


func test_transport_with_runners() -> void:
	var entry := ThroughputReport.transport_area(state)
	assert_eq(float(entry.capacity), 0.0)
	assert_almost_eq(float(entry.demand), Formulas.total_transfer_demand(state), 0.0001)
	assert_eq(float(entry.load), 1.0)
	assert_eq(_ids(entry.upgrades), ["runner:"])
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	entry = ThroughputReport.transport_area(state)
	assert_eq(float(entry.capacity), 0.0)
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.RUNNER), 3.0 * Formulas.runner_capacity(state) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	assert_eq(_gain(entry.upgrades, ThroughputReport.RESEARCH), 0.0)
	state.add_runner(Runner.OUTPUT)
	entry = ThroughputReport.transport_area(state)
	assert_almost_eq(float(entry.capacity), Formulas.transport_throughput(state), 0.0001)
	assert_eq(_gain(entry.upgrades, ThroughputReport.RUNNER), 0.0)
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.RESEARCH), 3.0 * GameConfig.RUNNER_CAPACITY_PER_LEVEL / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	while state.runners.size() < GameConfig.MAX_RUNNERS:
		state.add_runner()
	state.research["trolleys"] = int(GameConfig.RESEARCH.trolleys.max_level)
	assert_true((ThroughputReport.transport_area(state).upgrades as Array).is_empty())


func test_transport_with_pneumatic_tubes() -> void:
	state.research["pneumatic_tubes"] = 1
	state.connect_all_tubes()
	var entry := ThroughputReport.transport_area(state)
	assert_true(is_inf(float(entry.capacity)))
	assert_eq(float(entry.load), 0.0)
	assert_eq(_ids(entry.upgrades), ["research:tube_capacity"])
	assert_eq((entry.upgrades as Array)[0].effect, ThroughputReport.PLACES)
	assert_eq(_gain(entry.upgrades, ThroughputReport.RESEARCH), float(GameConfig.TUBE_CAPACITY_PER_LEVEL))
	state.research["tube_capacity"] = int(GameConfig.RESEARCH.tube_capacity.max_level)
	assert_true((ThroughputReport.transport_area(state).upgrades as Array).is_empty())


func test_complaints_before_they_start() -> void:
	var entry := ThroughputReport.complaint_area(state)
	assert_eq(float(entry.demand), 0.0)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(float(entry.load), 0.0)
	assert_eq(_ids(entry.upgrades), ["research:shredder_service"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.RESEARCH), 1.0 / (GameConfig.SHREDDER_DELAYS[1] + GameConfig.INTERN_TRIP_ESTIMATE), 0.0001)


func test_complaint_demand_capacity_and_upgrades() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.research["shredder_service"] = 1
	var entry := ThroughputReport.complaint_area(state)
	var passed := 1.0 - Formulas.complaint_fend_chance(0)
	assert_almost_eq(float(entry.demand), passed / GameConfig.COMPLAINT_INTERVAL, 0.0001)
	var per_intern := 1.0 / (GameConfig.SHREDDER_DELAYS[1] + GameConfig.INTERN_TRIP_ESTIMATE)
	assert_almost_eq(float(entry.capacity), per_intern, 0.0001)
	assert_eq(_ids(entry.upgrades), ["clerk:", "guard:", "helper:", "research:complaint_tube", "research:intern_training", "research:shredder_service"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.HELPER), per_intern, 0.0001)
	var relieved := (1.0 - GameConfig.GUARD_BLOCK_CHANCE) * passed / (GameConfig.COMPLAINT_INTERVAL * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF))
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.GUARD), float(entry.demand) - relieved, 0.0001)
	var trained := (1.0 - Formulas.complaint_fend_chance(1)) / GameConfig.COMPLAINT_INTERVAL
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.CLERK), float(entry.demand) - trained, 0.0001)
	_assert_sorted(entry.upgrades)


func test_complaint_capacity_adds_interns_and_tube() -> void:
	state.research["shredder_service"] = 2
	state.research["intern_training"] = 1
	state.research["complaint_tube"] = 3
	state.add_helper()
	var per_trip := Formulas.intern_capacity(state)
	var expected := 2.0 * per_trip / (GameConfig.SHREDDER_DELAYS[2] + GameConfig.INTERN_TRIP_ESTIMATE) + 1.0 / GameConfig.COMPLAINT_TUBE_DELAYS[3]
	assert_almost_eq(ThroughputReport.complaint_capacity(state), expected, 0.0001)
	assert_eq(ThroughputReport.tube_rate(0), 0.0)
	assert_eq(ThroughputReport.intern_rate(0, 3), 0.0)


func test_fully_staffed_complaints_offer_nothing() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for research_id in ["shredder_service", "intern_training", "complaint_tube"]:
		state.research[research_id] = int(GameConfig.RESEARCH[research_id].max_level)
	while state.helpers.size() < GameConfig.MAX_HELPERS:
		state.add_helper()
	state.guards = GameConfig.MAX_GUARDS
	state.complaint_clerk_level = GameConfig.COMPLAINT_CLERK_MAX_LEVEL
	assert_true((ThroughputReport.complaint_area(state).upgrades as Array).is_empty())
	var blocked := pow(1.0 - GameConfig.GUARD_BLOCK_CHANCE, GameConfig.MAX_GUARDS) * (1.0 - Formulas.complaint_fend_chance(GameConfig.COMPLAINT_CLERK_MAX_LEVEL))
	var interval := GameConfig.COMPLAINT_INTERVAL * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF * (GameConfig.MAX_GUARDS + GameConfig.MAX_HELPERS))
	assert_almost_eq(ThroughputReport.complaint_demand(state, state.guards), blocked / interval, 0.0001)


func test_rejects_need_collectors() -> void:
	assert_eq(ThroughputReport.reject_demand(state), 0.0)
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var expected := Formulas.demand(state, state.department("general_services")) * GameConfig.REJECT_CHANCE
	var entry := ThroughputReport.reject_area(state)
	assert_almost_eq(float(entry.demand), expected, 0.0001)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_ids(entry.upgrades), ["collector:"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.COLLECTOR), ThroughputReport.collector_rate(state), 0.0001)
	while state.collectors.size() < GameConfig.MAX_COLLECTORS:
		state.collectors.append(RejectCollector.new())
	entry = ThroughputReport.reject_area(state)
	assert_almost_eq(float(entry.capacity), GameConfig.MAX_COLLECTORS * ThroughputReport.collector_rate(state), 0.0001)
	assert_eq(_ids(entry.upgrades), ["research:trolleys"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.RESEARCH), GameConfig.MAX_COLLECTORS * GameConfig.COLLECTOR_CAPACITY_PER_LEVEL / ThroughputReport.collector_trip(state), 0.0001)
	state.research["trolleys"] = int(GameConfig.RESEARCH.trolleys.max_level)
	entry = ThroughputReport.reject_area(state)
	assert_true((entry.upgrades as Array).is_empty())
	assert_almost_eq(float(entry.capacity), GameConfig.MAX_COLLECTORS * float(Formulas.collector_capacity_limit()) / ThroughputReport.collector_trip(state), 0.0001)


func test_collector_trip_follows_the_distance_to_the_piles() -> void:
	var layout := WorldLayout.get_default()
	var distance := layout.shredder_point().distance_to(layout.reject_point(REVIEW))
	var expected := maxf(GameConfig.COLLECTOR_TRIP_ESTIMATE, 2.0 * distance / GameConfig.COLLECTOR_SPEED)
	assert_almost_eq(ThroughputReport.collector_trip(state), expected, 0.0001)
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	assert_true(ThroughputReport.collector_trip(state) >= expected)
	assert_almost_eq(ThroughputReport.collector_rate(state), Formulas.collector_capacity(state) / ThroughputReport.collector_trip(state), 0.0001)


func test_collector_trip_without_demand_uses_the_estimate() -> void:
	state.department("general_services").unlocked = false
	assert_eq(ThroughputReport.collector_trip(state), GameConfig.COLLECTOR_TRIP_ESTIMATE)


func test_rejects_ignore_customs() -> void:
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var before := ThroughputReport.reject_demand(state)
	state.unlock_department("customs")
	assert_almost_eq(ThroughputReport.reject_demand(state), before, 0.0001)


func test_phones_need_enough_staff() -> void:
	var entry := ThroughputReport.phone_area(state)
	assert_eq(ThroughputReport.staffed_officials(state), 1)
	assert_eq(float(entry.demand), 0.0)
	assert_true((entry.upgrades as Array).is_empty())
	state.station(GameConfig.RECEPTION).staff = 1
	state.station(GameConfig.COUNTER).staff = 1
	var interval := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, 0.5) / ThroughputReport.staffed_officials(state)
	entry = ThroughputReport.phone_area(state)
	assert_almost_eq(float(entry.demand), 1.0 / interval, 0.0001)
	assert_eq(float(entry.load), 1.0)
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.HR), 1.0 / interval - 1.0 / (interval * (1.0 + GameConfig.SICK_HR_RELIEF)), 0.0001)
	assert_eq((entry.upgrades as Array)[0].effect, ThroughputReport.RELIEF)
	state.hr = GameConfig.MAX_HR
	entry = ThroughputReport.phone_area(state)
	assert_almost_eq(float(entry.capacity), GameConfig.MAX_HR / GameConfig.HR_ANSWER_SECONDS, 0.0001)
	assert_true((entry.upgrades as Array).is_empty())


func test_hall_areas_report_occupancy() -> void:
	var seating := ThroughputReport.seating_area(state)
	assert_eq(float(seating.capacity), float(state.seat_capacity()))
	assert_eq(float(seating.demand), float(state.seated_citizens()))
	assert_eq(_gain(seating.upgrades, ThroughputReport.SEATS), float(GameConfig.SEATING_SEATS_PER_LEVEL))
	var reception := state.station(GameConfig.RECEPTION)
	for index in 4:
		reception.inbox.append(CaseFile.new("general_services"))
	var waiting := ThroughputReport.waiting_area(state)
	assert_eq(float(waiting.demand), 4.0)
	assert_almost_eq(float(waiting.load), 4.0 / state.lobby_capacity(), 0.0001)
	assert_eq(_gain(waiting.upgrades, ThroughputReport.WAITING_SEATS), float(GameConfig.WAITING_SEATS_PER_LEVEL))
	state.seating_level = GameConfig.SEATING_MAX_LEVEL
	state.waiting_level = GameConfig.WAITING_MAX_LEVEL
	assert_true((ThroughputReport.seating_area(state).upgrades as Array).is_empty())
	assert_true((ThroughputReport.waiting_area(state).upgrades as Array).is_empty())


func test_waiting_area_without_reception() -> void:
	state.stations.erase(GameConfig.RECEPTION)
	assert_eq(float(ThroughputReport.waiting_area(state).demand), 0.0)


func test_all_areas_cover_used_stations_and_support() -> void:
	var areas := ThroughputReport.all_areas(state)
	var kinds: Array[String] = []
	var keys: Array[String] = []
	for entry in areas:
		kinds.append(str(entry.area))
		if entry.area == ThroughputReport.STATION:
			keys.append(str(entry.key))
	assert_eq(keys, state.ordered_station_keys())
	for kind in [ThroughputReport.TRANSPORT, ThroughputReport.COMPLAINTS, ThroughputReport.REJECTS, ThroughputReport.PHONES, ThroughputReport.SEATING, ThroughputReport.WAITING]:
		assert_true(kinds.has(kind), kind)
	assert_eq(ThroughputReport.support_areas(state).size(), 6)


func test_recommendations_pick_the_busiest_upgradable_areas() -> void:
	var some: Array[Dictionary] = [ThroughputReport.upgrade(ThroughputReport.HIRE, 1.0)]
	var none: Array[Dictionary] = []
	var areas: Array[Dictionary] = [
		ThroughputReport.area(ThroughputReport.STATION, "calm", 0.1, 1.0, some.duplicate()),
		ThroughputReport.area(ThroughputReport.STATION, "busy", 0.9, 1.0, some.duplicate()),
		ThroughputReport.area(ThroughputReport.STATION, "jammed", 2.0, 1.0, some.duplicate()),
		ThroughputReport.area(ThroughputReport.STATION, "maxed", 3.0, 1.0, none),
	]
	var picked := ThroughputReport.pick_recommendations(areas, 5)
	assert_eq(picked.map(func(e: Dictionary) -> String: return e.key), ["jammed", "busy"])
	assert_eq(ThroughputReport.pick_recommendations(areas, 1).size(), 1)
	assert_true(ThroughputReport.pick_recommendations(areas, -1).is_empty())
	var live := ThroughputReport.recommendations(state, 10)
	for entry in live:
		assert_true(float(entry.load) >= ThroughputReport.BUSY_LOAD)


func test_department_steps_list_every_step_and_transport() -> void:
	var dept := state.department("general_services")
	var steps := ThroughputReport.department_steps(state, dept)
	var required := RouteBuilder.required_stations(dept.id)
	assert_eq(steps.size(), required.size() + 1)
	for index in required.size():
		assert_eq(steps[index].key, required[index])
		assert_almost_eq(float(steps[index].rate), Formulas.station_share(state, state.station(required[index]), dept), 0.0001)
	assert_eq(steps[-1].key, ThroughputReport.TRANSPORT)
	assert_almost_eq(float(steps[-1].rate), Formulas.department_transport(state, dept), 0.0001)


func test_department_steps_skip_inspection_for_customs() -> void:
	state.unlock_department("customs")
	var customs := state.department("customs")
	for step in ThroughputReport.department_steps(state, customs):
		assert_ne(step.key, GameConfig.INSPECTION)
