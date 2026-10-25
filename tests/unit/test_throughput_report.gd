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


func _entry_gain(entry_upgrades: Array, entry_id: String) -> float:
	for upgrade: Dictionary in entry_upgrades:
		if upgrade.entry == entry_id:
			return float(upgrade.gain)
	return -1.0


func _entries(upgrades: Array) -> Array[String]:
	var result: Array[String] = []
	for upgrade: Dictionary in upgrades:
		result.append(str(upgrade.entry))
	result.sort()
	return result


func _assert_sorted(upgrades: Array) -> void:
	for index in range(1, upgrades.size()):
		assert_true(float(upgrades[index - 1].gain) >= float(upgrades[index].gain))


func _max_level(upgrade_id: String) -> int:
	return int(GameConfig.upgrade(upgrade_id).max)


func _connect_all_tubes() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	state.set_upgrade("large_capsules", 1)


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
	assert_eq(plain.entry, "")


func test_track_suggestions_point_to_catalog_entries() -> void:
	var shared_track := ThroughputReport.track("digital_records", 1.0)
	assert_eq(shared_track.id, ThroughputReport.TRACK)
	assert_eq(shared_track.effect, ThroughputReport.CAPACITY)
	assert_eq(shared_track.entry, "track:digital_records")
	var room_track := ThroughputReport.track("office_equipment", 2.0, ThroughputReport.PLACES, "general_services")
	assert_eq(room_track.effect, ThroughputReport.PLACES)
	assert_eq(room_track.entry, "track:office_equipment@general_services")
	assert_eq(UpgradeCatalog.find(state, str(room_track.entry)).id, str(room_track.entry))
	assert_eq(ThroughputReport.staff_entry("runners"), "staff:runners")


func test_track_gain_compares_neighbouring_levels() -> void:
	assert_almost_eq(ThroughputReport.track_gain(state, "runner_speed"), Formulas.track_value("runner_speed", 1) / Formulas.track_value("runner_speed", 0) - 1.0, 0.0001)
	state.set_upgrade("office_equipment", 3, "general_services")
	assert_almost_eq(ThroughputReport.track_gain(state, "office_equipment", "general_services"), Formulas.track_value("office_equipment", 4) / Formulas.track_value("office_equipment", 3) - 1.0, 0.0001)
	assert_eq(ThroughputReport.track_gain(state, "shredder_service"), 0.0)
	assert_eq(ThroughputReport.track_gain(state, "pneumatic_tubes"), 0.0)


func test_can_upgrade_respects_requirements_and_max_level() -> void:
	assert_true(ThroughputReport.can_upgrade(state, "runner_trolleys"))
	assert_false(ThroughputReport.can_upgrade(state, "complaint_tube"))
	state.set_upgrade("shredder_service", 1)
	assert_true(ThroughputReport.can_upgrade(state, "complaint_tube"))
	state.set_upgrade("runner_trolleys", _max_level("runner_trolleys"))
	assert_false(ThroughputReport.can_upgrade(state, "runner_trolleys"))
	assert_false(ThroughputReport.can_upgrade(state, "ticket_speed"))
	assert_null(state.mailroom())
	assert_false(ThroughputReport.can_upgrade(state, "letter_opener"))
	assert_false(ThroughputReport.can_upgrade(state, "office_equipment"))
	assert_true(ThroughputReport.can_upgrade(state, "office_equipment", "general_services"))
	assert_false(ThroughputReport.can_upgrade(state, "office_equipment", "tax_services"))


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
	assert_eq(_entries(upgrades), ["desk:general_services/review", "level:general_services/review", "specialist:general_services/review", "supervisor:general_services", "track:digital_records", "track:office_equipment@general_services"])
	var before := Formulas.station_throughput(state, review)
	review.level += 1
	assert_almost_eq(_gain(upgrades, ThroughputReport.LEVEL), Formulas.station_throughput(state, review) - before, 0.0001)
	review.level -= 1
	dept.supervisors += 1
	assert_almost_eq(_gain(upgrades, ThroughputReport.SUPERVISOR), Formulas.station_throughput(state, review) - before, 0.0001)
	dept.supervisors -= 1
	state.set_upgrade("digital_records", 1)
	assert_almost_eq(_entry_gain(upgrades, "track:digital_records"), Formulas.station_throughput(state, review) - before, 0.0001)
	state.set_upgrade("digital_records", 0)
	state.set_upgrade("office_equipment", 1, "general_services")
	assert_almost_eq(_entry_gain(upgrades, "track:office_equipment@general_services"), Formulas.station_throughput(state, review) - before, 0.0001)
	state.set_upgrade("office_equipment", 0, "general_services")
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
	assert_true(_entries(upgrades).has("hire:" + REVIEW))
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
	assert_true(_entries(upgrades).has("desk:" + SIGNATURE))
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
	state.set_upgrade("digital_records", _max_level("digital_records"))
	state.set_upgrade("office_equipment", _max_level("office_equipment"), "general_services")
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
	assert_eq(_entries(entry.upgrades), ["staff:runners"])
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	entry = ThroughputReport.transport_area(state)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_entries(entry.upgrades), ["staff:runners", "track:runner_speed", "track:runner_trolleys"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.RUNNER), 3.0 * Formulas.runner_capacity(state) / GameConfig.RUNNER_TRIP_ESTIMATE, 0.0001)
	assert_eq(_entry_gain(entry.upgrades, "track:runner_trolleys"), 0.0)
	assert_eq(_entry_gain(entry.upgrades, "track:runner_speed"), 0.0)
	state.add_runner(Runner.OUTPUT)
	entry = ThroughputReport.transport_area(state)
	var current := Formulas.transport_throughput(state)
	assert_almost_eq(float(entry.capacity), current, 0.0001)
	assert_eq(_gain(entry.upgrades, ThroughputReport.RUNNER), 0.0)
	assert_almost_eq(_entry_gain(entry.upgrades, "track:runner_speed"), current * (Formulas.track_value("runner_speed", 1) / Formulas.track_value("runner_speed", 0) - 1.0), 0.0001)
	state.set_upgrade("runner_trolleys", 1)
	assert_almost_eq(_entry_gain(entry.upgrades, "track:runner_trolleys"), Formulas.transport_throughput(state) - current, 0.0001)
	while state.runners.size() < GameConfig.MAX_RUNNERS:
		state.add_runner()
	state.set_upgrade("runner_trolleys", _max_level("runner_trolleys"))
	state.set_upgrade("runner_speed", _max_level("runner_speed"))
	assert_true((ThroughputReport.transport_area(state).upgrades as Array).is_empty())


func test_transport_with_pneumatic_tubes() -> void:
	_connect_all_tubes()
	var entry := ThroughputReport.transport_area(state)
	assert_true(is_inf(float(entry.capacity)))
	assert_eq(float(entry.load), 0.0)
	assert_eq(_entries(entry.upgrades), ["track:tube_capacity"])
	assert_eq((entry.upgrades as Array)[0].effect, ThroughputReport.PLACES)
	assert_eq(_entry_gain(entry.upgrades, "track:tube_capacity"), float(GameConfig.upgrade("tube_capacity").step))
	state.set_upgrade("tube_capacity", _max_level("tube_capacity"))
	assert_true((ThroughputReport.transport_area(state).upgrades as Array).is_empty())


func test_transport_pipes_only_between_rooms_with_stations() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	assert_false(state.any_piped())
	assert_eq(_entries(ThroughputReport.transport_area(state).upgrades), ["staff:runners"])
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	assert_false(state.any_piped())
	state.set_upgrade("tube_station", 1, "general_services")
	assert_true(state.any_piped())
	assert_false(state.all_piped())
	var dept := state.department("general_services")
	var transfers := RouteBuilder.build(CaseFile.new(dept.id)).size() - 1
	var entry := ThroughputReport.transport_area(state)
	assert_almost_eq(float(entry.demand), Formulas.demand(state, dept) * transfers * float(dept.config().complex_chance), 0.0001)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_entries(entry.upgrades), ["staff:runners", "track:tube_capacity"])
	state.set_upgrade("large_capsules", 1)
	assert_true(state.all_piped())
	assert_true(is_inf(float(ThroughputReport.transport_area(state).capacity)))


func test_complaints_before_they_start() -> void:
	var entry := ThroughputReport.complaint_area(state)
	assert_eq(float(entry.demand), 0.0)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(float(entry.load), 0.0)
	assert_eq(_entries(entry.upgrades), ["track:shredder_service"])
	assert_almost_eq(_entry_gain(entry.upgrades, "track:shredder_service"), 1.0 / (Formulas.track_value("shredder_service", 1) + GameConfig.INTERN_TRIP_ESTIMATE), 0.0001)


func test_complaint_demand_capacity_and_upgrades() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.set_upgrade("shredder_service", 1)
	var entry := ThroughputReport.complaint_area(state)
	var passed := 1.0 - Formulas.complaint_fend_chance(0)
	assert_almost_eq(float(entry.demand), passed / GameConfig.COMPLAINT_INTERVAL, 0.0001)
	var per_intern := 1.0 / (Formulas.track_value("shredder_service", 1) + GameConfig.INTERN_TRIP_ESTIMATE)
	assert_almost_eq(float(entry.capacity), per_intern, 0.0001)
	assert_eq(_entries(entry.upgrades), ["staff:guards", "staff:helpers", "track:complaint_clerk", "track:complaint_tube", "track:intern_training", "track:shredder_service"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.HELPER), per_intern, 0.0001)
	var relieved := (1.0 - Formulas.guard_chance(state)) * passed / (GameConfig.COMPLAINT_INTERVAL * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF))
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.GUARD), float(entry.demand) - relieved, 0.0001)
	var trained := (1.0 - Formulas.complaint_fend_chance(1)) / GameConfig.COMPLAINT_INTERVAL
	assert_almost_eq(_entry_gain(entry.upgrades, "track:complaint_clerk"), float(entry.demand) - trained, 0.0001)
	for upgrade_id: String in ["shredder_service", "intern_training", "complaint_tube"]:
		var level := state.upgrade_level(upgrade_id)
		state.set_upgrade(upgrade_id, level + 1)
		assert_almost_eq(_entry_gain(entry.upgrades, "track:" + upgrade_id), ThroughputReport.complaint_capacity(state) - float(entry.capacity), 0.0001, upgrade_id)
		state.set_upgrade(upgrade_id, level)
	_assert_sorted(entry.upgrades)


func test_complaint_capacity_adds_interns_and_tube() -> void:
	state.set_upgrade("shredder_service", 2)
	state.set_upgrade("intern_training", 1)
	state.set_upgrade("complaint_tube", 3)
	state.add_helper()
	var per_trip := Formulas.intern_capacity(state)
	var expected := 2.0 * per_trip / (Formulas.track_value("shredder_service", 2) + GameConfig.INTERN_TRIP_ESTIMATE) + 1.0 / Formulas.track_value("complaint_tube", 3)
	assert_almost_eq(ThroughputReport.complaint_capacity(state), expected, 0.0001)
	assert_eq(ThroughputReport.tube_rate(0), 0.0)
	assert_eq(ThroughputReport.intern_rate(0, 3), 0.0)


func test_fully_staffed_complaints_offer_nothing() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for upgrade_id: String in ["shredder_service", "intern_training", "complaint_tube", "complaint_clerk"]:
		state.set_upgrade(upgrade_id, _max_level(upgrade_id))
	while state.helpers.size() < GameConfig.MAX_HELPERS:
		state.add_helper()
	state.guards = GameConfig.MAX_GUARDS
	assert_true((ThroughputReport.complaint_area(state).upgrades as Array).is_empty())
	var blocked := pow(1.0 - Formulas.guard_chance(state), GameConfig.MAX_GUARDS) * (1.0 - Formulas.complaint_fend_chance(_max_level("complaint_clerk")))
	var interval := GameConfig.COMPLAINT_INTERVAL * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF * (GameConfig.MAX_GUARDS + GameConfig.MAX_HELPERS))
	assert_almost_eq(ThroughputReport.complaint_demand(state, state.guards), blocked / interval, 0.0001)


func test_lost_citizens_add_bundled_complaint_demand() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	var calm := ThroughputReport.complaint_demand(state, 0)
	var passed := 1.0 - Formulas.complaint_fend_chance(0)
	assert_almost_eq(calm, passed / GameConfig.COMPLAINT_INTERVAL, 0.0001)
	state.play_time = 60.0
	state.production.record(ProductionStats.LOST, "general_services", 30.0, 3)
	assert_almost_eq(ThroughputReport.complaint_demand(state, 0), calm + passed * 3.0 / 60.0 * GameConfig.LEAVE_COMPLAINT_CHANCE, 0.0001)
	state.production.record(ProductionStats.LOST, "general_services", 40.0, 1000)
	assert_almost_eq(ThroughputReport.complaint_demand(state, 0), calm + passed / GameConfig.LEAVE_COMPLAINT_COOLDOWN, 0.0001)


func test_rejects_need_collectors() -> void:
	assert_eq(ThroughputReport.reject_demand(state), 0.0)
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var expected := Formulas.demand(state, state.department("general_services")) * GameConfig.REJECT_CHANCE
	var entry := ThroughputReport.reject_area(state)
	assert_almost_eq(float(entry.demand), expected, 0.0001)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_entries(entry.upgrades), ["staff:collectors", "track:shredder@general_services"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.COLLECTOR), ThroughputReport.collector_rate(state), 0.0001)
	while state.collectors.size() < GameConfig.MAX_COLLECTORS:
		state.collectors.append(RejectCollector.new())
	entry = ThroughputReport.reject_area(state)
	var capacity := float(entry.capacity)
	assert_almost_eq(capacity, GameConfig.MAX_COLLECTORS * ThroughputReport.collector_rate(state), 0.0001)
	assert_eq(_entries(entry.upgrades), ["track:collector_carts", "track:collector_speed", "track:shredder@general_services"])
	for upgrade_id: String in ["collector_carts", "collector_speed"]:
		state.set_upgrade(upgrade_id, 1)
		assert_almost_eq(_entry_gain(entry.upgrades, "track:" + upgrade_id), float(ThroughputReport.reject_area(state).capacity) - capacity, 0.0001, upgrade_id)
		state.set_upgrade(upgrade_id, 0)
	state.set_upgrade("collector_carts", _max_level("collector_carts"))
	state.set_upgrade("collector_speed", _max_level("collector_speed"))
	state.set_upgrade("shredder", 1, "general_services")
	entry = ThroughputReport.reject_area(state)
	assert_true((entry.upgrades as Array).is_empty())
	assert_almost_eq(float(entry.capacity), GameConfig.MAX_COLLECTORS * float(Formulas.collector_capacity_limit()) / ThroughputReport.collector_trip(state) + ThroughputReport.shredder_capacity(state), 0.0001)


func test_department_shredders_add_capacity_and_shorten_trips() -> void:
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var layout := WorldLayout.get_default()
	assert_eq(ThroughputReport.missing_shredder(state), "general_services")
	assert_eq(ThroughputReport.shredder_capacity(state), 0.0)
	var gain := _entry_gain(ThroughputReport.reject_area(state).upgrades, "track:shredder@general_services")
	assert_almost_eq(gain, GameConfig.SHREDDER_BATCH / Formulas.track_value("shredder", 1), 0.0001)
	var before := ThroughputReport.collector_trip(state)
	state.set_upgrade("shredder", 1, "general_services")
	assert_eq(ThroughputReport.missing_shredder(state), "")
	assert_almost_eq(ThroughputReport.shredder_capacity(state), gain, 0.0001)
	assert_almost_eq(ThroughputReport.shredder_capacity(state), GameConfig.SHREDDER_BATCH / Formulas.shredder_interval(state, "general_services"), 0.0001)
	assert_almost_eq(float(ThroughputReport.reject_area(state).capacity), ThroughputReport.shredder_capacity(state), 0.0001)
	var pile := layout.reject_point(REVIEW)
	var distance := minf(pile.distance_to(layout.shredder_point()), pile.distance_to(layout.dept_shredder_point("general_services")))
	assert_almost_eq(ThroughputReport.collector_trip(state), maxf(GameConfig.COLLECTOR_TRIP_ESTIMATE, 2.0 * distance / Formulas.collector_speed(state)), 0.0001)
	assert_true(ThroughputReport.collector_trip(state) <= before)
	state.unlock_department("customs")
	assert_eq(ThroughputReport.missing_shredder(state), "")
	state.unlock_department("tax_services")
	assert_eq(ThroughputReport.missing_shredder(state), "tax_services")


func test_collector_trip_follows_the_distance_to_the_piles() -> void:
	var layout := WorldLayout.get_default()
	var distance := layout.shredder_point().distance_to(layout.reject_point(REVIEW))
	var expected := maxf(GameConfig.COLLECTOR_TRIP_ESTIMATE, 2.0 * distance / Formulas.collector_speed(state))
	assert_almost_eq(ThroughputReport.collector_trip(state), expected, 0.0001)
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	assert_true(ThroughputReport.collector_trip(state) >= expected)
	assert_almost_eq(ThroughputReport.collector_rate(state), Formulas.collector_capacity(state) / ThroughputReport.collector_trip(state), 0.0001)


func test_collector_trip_without_demand_uses_the_estimate() -> void:
	state.department("general_services").unlocked = false
	assert_eq(ThroughputReport.collector_trip(state), GameConfig.COLLECTOR_TRIP_ESTIMATE)
	assert_eq(ThroughputReport.collector_trip(state, 3.0), GameConfig.COLLECTOR_TRIP_ESTIMATE)


func test_collector_speed_gain_matches_the_real_capacity_change() -> void:
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	state.collectors.append(RejectCollector.new())
	var slow := ThroughputReport.collector_trip(state)
	assert_gt(slow, GameConfig.COLLECTOR_TRIP_ESTIMATE)
	assert_almost_eq(ThroughputReport.collector_trip(state, 2.0), maxf(GameConfig.COLLECTOR_TRIP_ESTIMATE, slow / 2.0), 0.0001)
	for level: int in [0, _max_level("collector_speed") - 1]:
		state.set_upgrade("collector_speed", level)
		var entry := ThroughputReport.reject_area(state)
		var capacity := float(entry.capacity)
		var gain := _entry_gain(entry.upgrades, "track:collector_speed")
		state.set_upgrade("collector_speed", level + 1)
		assert_almost_eq(gain, float(ThroughputReport.reject_area(state).capacity) - capacity, 0.0001)
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
	assert_eq(_entries(entry.upgrades), ["staff:hr"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.HR), 1.0 / interval - 1.0 / (interval * (1.0 + GameConfig.SICK_HR_RELIEF)), 0.0001)
	assert_eq((entry.upgrades as Array)[0].effect, ThroughputReport.RELIEF)
	state.hr = GameConfig.MAX_HR
	entry = ThroughputReport.phone_area(state)
	var capacity := float(entry.capacity)
	assert_almost_eq(capacity, GameConfig.MAX_HR * Formulas.phone_speed(state) / GameConfig.HR_ANSWER_SECONDS, 0.0001)
	assert_eq(_entries(entry.upgrades), ["track:phone_training"])
	state.set_upgrade("phone_training", 1)
	assert_almost_eq(_entry_gain(entry.upgrades, "track:phone_training"), float(ThroughputReport.phone_area(state).capacity) - capacity, 0.0001)
	state.set_upgrade("phone_training", _max_level("phone_training"))
	assert_true((ThroughputReport.phone_area(state).upgrades as Array).is_empty())


func test_hall_areas_report_occupancy() -> void:
	var seating := ThroughputReport.seating_area(state)
	var capacity := float(state.seat_capacity() + state.standing_capacity())
	assert_eq(float(seating.capacity), capacity)
	assert_eq(float(seating.demand), float(state.seated_citizens()))
	assert_eq(_entries(seating.upgrades), ["track:seating", "track:standing_places"])
	assert_eq(_entry_gain(seating.upgrades, "track:seating"), float(GameConfig.upgrade("seating").step))
	assert_eq(_entry_gain(seating.upgrades, "track:standing_places"), float(GameConfig.upgrade("standing_places").step))
	for upgrade: Dictionary in seating.upgrades:
		assert_eq(upgrade.effect, ThroughputReport.PLACES)
	state.set_upgrade("seating", 4)
	state.set_upgrade("standing_places", 1)
	var grown := ThroughputReport.seating_area(state)
	assert_eq(float(grown.capacity), float(state.seat_capacity() + state.standing_capacity()))
	assert_almost_eq(float(grown.capacity), capacity + 4.0 * float(GameConfig.upgrade("seating").step) + float(GameConfig.upgrade("standing_places").step), 0.0001)
	state.set_upgrade("seating", 0)
	state.set_upgrade("standing_places", 0)
	var reception := state.station(GameConfig.RECEPTION)
	for index in 4:
		reception.inbox.append(CaseFile.new("general_services"))
	var waiting := ThroughputReport.waiting_area(state)
	assert_eq(float(waiting.demand), 4.0)
	assert_almost_eq(float(waiting.load), 4.0 / state.lobby_capacity(), 0.0001)
	assert_eq(_entries(waiting.upgrades), ["track:waiting_places"])
	assert_eq(_entry_gain(waiting.upgrades, "track:waiting_places"), float(GameConfig.upgrade("waiting_places").step))
	for upgrade_id: String in ["seating", "standing_places", "waiting_places"]:
		state.set_upgrade(upgrade_id, _max_level(upgrade_id))
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
	assert_false(kinds.has(ThroughputReport.TICKETS))
	assert_eq(ThroughputReport.support_areas(state).size(), 6)
	state.building_stage = GameConfig.TICKET_UNLOCK_STAGE
	var support := ThroughputReport.support_areas(state)
	assert_eq(support.size(), 8)
	var support_kinds := support.map(func(entry: Dictionary) -> String: return entry.area)
	assert_true(support_kinds.has(ThroughputReport.TICKETS))
	assert_true(support_kinds.has(ThroughputReport.CALLS))


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


func test_recommended_entries_are_unique_catalog_entries() -> void:
	var recommended := ThroughputReport.recommended_entries(state)
	assert_true(recommended.has("staff:runners"))
	for entry_id in recommended:
		assert_eq(recommended.count(entry_id), 1, entry_id)
		var found := UpgradeCatalog.find(state, entry_id)
		assert_not_null(found, entry_id)
		if found != null:
			assert_eq(found.id, entry_id)


func test_every_suggestion_links_to_a_catalog_entry() -> void:
	state.cases_completed = maxi(GameConfig.COMPLAINT_MIN_CASES, GameConfig.REJECT_MIN_CASES)
	state.building_stage = GameConfig.TICKET_UNLOCK_STAGE
	state.set_upgrade("shredder_service", 1)
	state.station(GameConfig.RECEPTION).staff = 1
	state.station(GameConfig.COUNTER).staff = 1
	state.add_runner()
	state.collectors.append(RejectCollector.new())
	state.hr = 1
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	state.set_upgrade("tube_station", 1, "general_services")
	var count := 0
	for report_area in ThroughputReport.all_areas(state):
		for suggestion: Dictionary in report_area.upgrades:
			count += 1
			var entry_id := str(suggestion.entry)
			var found := UpgradeCatalog.find(state, entry_id)
			assert_not_null(found, "%s %s" % [report_area.area, entry_id])
			if found != null:
				assert_eq(found.id, entry_id)
	assert_gt(count, 10)


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
