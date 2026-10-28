extends GutTest

const REVIEW := "general_services/review"
const MACHINE := "tax_services/signature"

var state: GameState


func before_each() -> void:
	state = GameState.create_new(31)
	state.station(REVIEW).staff = 1


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
	var shared_track := ThroughputReport.track("runner_speed", 1.0)
	assert_eq(shared_track.id, ThroughputReport.TRACK)
	assert_eq(shared_track.effect, ThroughputReport.CAPACITY)
	assert_eq(shared_track.entry, "track:runner_speed")
	var room_track := ThroughputReport.track("room_speed", 2.0, ThroughputReport.PLACES, "general_services")
	assert_eq(room_track.effect, ThroughputReport.PLACES)
	assert_eq(room_track.entry, "track:room_speed@general_services")
	assert_eq(UpgradeCatalog.find(state, str(room_track.entry)).id, str(room_track.entry))
	assert_eq(ThroughputReport.staff_entry("runners"), "staff:runners")


func test_track_gain_compares_neighbouring_levels() -> void:
	assert_almost_eq(ThroughputReport.track_gain(state, "runner_speed"), Formulas.track_value("runner_speed", 1) / Formulas.track_value("runner_speed", 0) - 1.0, 0.0001)
	state.set_upgrade("room_speed", 3, "general_services")
	assert_almost_eq(ThroughputReport.track_gain(state, "room_speed", "general_services"), Formulas.track_value("room_speed", 4) / Formulas.track_value("room_speed", 3) - 1.0, 0.0001)
	assert_almost_eq(ThroughputReport.track_gain(state, "room_speed", "general_services"), Formulas.level_speed(5) / Formulas.level_speed(4) - 1.0, 0.0001)
	assert_eq(ThroughputReport.track_gain(state, "complaint_interns"), 0.0)
	assert_eq(ThroughputReport.track_gain(state, "pneumatic_tubes"), 0.0)


func test_can_upgrade_respects_requirements_and_max_level() -> void:
	assert_true(ThroughputReport.can_upgrade(state, "runner_trolleys"))
	assert_false(ThroughputReport.can_upgrade(state, "intern_steadfast"))
	state.set_upgrade("complaint_interns", 1)
	assert_true(ThroughputReport.can_upgrade(state, "intern_steadfast"))
	assert_false(ThroughputReport.can_upgrade(state, "intern_box_runs"))
	state.set_upgrade("complaint_interns", 2)
	assert_true(ThroughputReport.can_upgrade(state, "intern_box_runs"))
	state.set_upgrade("runner_trolleys", _max_level("runner_trolleys"))
	assert_false(ThroughputReport.can_upgrade(state, "runner_trolleys"))
	assert_true(ThroughputReport.can_upgrade(state, "ticket_speed"))
	assert_null(state.mailroom())
	assert_false(ThroughputReport.can_upgrade(state, "registered_mail"))
	assert_false(ThroughputReport.can_upgrade(state, "room_speed"))
	assert_true(ThroughputReport.can_upgrade(state, "room_speed", "general_services"))
	assert_true(ThroughputReport.can_upgrade(state, "room_speed", GameConfig.ROOM_HALL))
	assert_false(ThroughputReport.can_upgrade(state, "room_speed", "tax_services"))
	assert_false(ThroughputReport.can_upgrade(state, "lead_focus", "general_services"))
	state.set_upgrade("team_lead", 1, GameConfig.HALL_INTAKE)
	assert_false(ThroughputReport.can_upgrade(state, "lead_focus", "general_services"))
	assert_true(ThroughputReport.can_upgrade(state, "lead_focus", GameConfig.HALL_INTAKE))
	assert_false(ThroughputReport.can_upgrade(state, "team_lead", GameConfig.HALL_INTAKE))
	assert_true(ThroughputReport.can_upgrade(state, "team_lead", GameConfig.HALL_PICKUP))
	assert_false(ThroughputReport.can_upgrade(state, "team_lead", GameConfig.ROOM_HALL))


func test_station_case_time_and_throughput() -> void:
	var review := state.station(REVIEW)
	var case_time := Formulas.station_case_time(state, review)
	assert_gt(case_time, 0.0)
	assert_almost_eq(Formulas.station_throughput(state, review), Formulas.availability(state, review) / case_time, 0.0001)
	review.staff = 0
	assert_eq(Formulas.station_throughput(state, review), 0.0)
	var unused := Station.new("tax_services/review")
	unused.staff = 1
	assert_eq(Formulas.station_case_time(state, unused), 0.0)
	assert_eq(Formulas.station_throughput(state, unused), 0.0)


func test_station_gains_match_the_real_upgrade() -> void:
	var review := state.station(REVIEW)
	var upgrades := ThroughputReport.station_upgrades(state, review)
	assert_eq(_entries(upgrades), ["desk:general_services/review", "track:room_speed@general_services", "track:team_lead@general_services"])
	var before := Formulas.station_throughput(state, review)
	assert_gt(before, 0.0)
	state.set_upgrade("room_speed", 1, "general_services")
	assert_gt(_entry_gain(upgrades, "track:room_speed@general_services"), 0.0)
	assert_almost_eq(_entry_gain(upgrades, "track:room_speed@general_services"), Formulas.station_throughput(state, review) - before, 0.0001)
	state.set_upgrade("room_speed", 0, "general_services")
	review.add_desk()
	review.staff = 2
	assert_almost_eq(_gain(upgrades, ThroughputReport.DESK), Formulas.station_throughput(state, review) - before, 0.0001)


func test_room_speed_suggestion_follows_the_station_room() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	var upgrades := ThroughputReport.station_upgrades(state, reception)
	assert_true(_entries(upgrades).has("track:room_speed@hall"))
	assert_false(_entries(upgrades).has("track:room_speed@general_services"))
	var before := Formulas.station_throughput(state, reception)
	state.set_upgrade("room_speed", 4, "general_services")
	assert_almost_eq(Formulas.station_throughput(state, reception), before, 0.0001)
	state.set_upgrade("room_speed", 1, GameConfig.ROOM_HALL)
	assert_almost_eq(_entry_gain(upgrades, "track:room_speed@hall"), Formulas.station_throughput(state, reception) - before, 0.0001)
	state.set_upgrade("room_speed", GameConfig.ROOM_SPEED_LEVELS, GameConfig.ROOM_HALL)
	assert_false(_entries(ThroughputReport.station_upgrades(state, reception)).has("track:room_speed@hall"))


func test_team_lead_gain_matches_a_lead_with_focus() -> void:
	var review := state.station(REVIEW)
	var upgrades := ThroughputReport.station_upgrades(state, review)
	var gain := _entry_gain(upgrades, "track:team_lead@general_services")
	assert_gt(gain, 0.0)
	for upgrade: Dictionary in upgrades:
		assert_eq(upgrade.effect, ThroughputReport.CAPACITY)
	var before := Formulas.station_throughput(state, review)
	assert_eq(state.upgrade_level("team_lead", "general_services"), 0)
	assert_eq(state.upgrade_level("lead_focus", "general_services"), 0)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_focus", 1, "general_services")
	assert_almost_eq(gain, Formulas.station_throughput(state, review) - before, 0.0001)


func test_owned_team_lead_suggests_more_focus() -> void:
	var review := state.station(REVIEW)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_focus", 3, "general_services")
	var upgrades := ThroughputReport.station_upgrades(state, review)
	assert_false(_entries(upgrades).has("track:team_lead@general_services"))
	assert_true(_entries(upgrades).has("track:lead_focus@general_services"))
	assert_eq(state.upgrade_level("lead_focus", "general_services"), 3)
	var before := Formulas.station_throughput(state, review)
	state.set_upgrade("lead_focus", 4, "general_services")
	assert_almost_eq(_entry_gain(upgrades, "track:lead_focus@general_services"), Formulas.station_throughput(state, review) - before, 0.0001)
	state.set_upgrade("lead_focus", _max_level("lead_focus"), "general_services")
	var maxed := _entries(ThroughputReport.station_upgrades(state, review))
	assert_false(maxed.has("track:lead_focus@general_services"))
	assert_false(maxed.has("track:team_lead@general_services"))


func test_team_lead_in_another_room_does_not_count() -> void:
	state.set_upgrade("team_lead", 1, GameConfig.HALL_INTAKE)
	var upgrades := ThroughputReport.station_upgrades(state, state.station(REVIEW))
	assert_true(_entries(upgrades).has("track:team_lead@general_services"))
	assert_false(_entries(upgrades).has("track:lead_focus@general_services"))


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
	state.unlock_department("tax_services")
	var signature := state.station(MACHINE)
	assert_true(signature.machine)
	var upgrades := ThroughputReport.station_upgrades(state, signature)
	assert_true(_gain(upgrades, ThroughputReport.MACHINE) > 0.0)
	assert_eq(_gain(upgrades, ThroughputReport.HIRE), -1.0)
	assert_true(_entries(upgrades).has("desk:" + MACHINE))
	assert_true(_entries(upgrades).has("track:room_speed@tax_services"))
	assert_false(_entries(upgrades).has("track:team_lead@tax_services"))
	assert_false(_entries(upgrades).has("track:lead_focus@tax_services"))
	while signature.desks < state.max_desks():
		signature.add_desk()
	assert_eq(_gain(ThroughputReport.station_upgrades(state, signature), ThroughputReport.MACHINE), -1.0)


func test_fully_upgraded_station_offers_nothing() -> void:
	var review := state.station(REVIEW)
	review.add_desk()
	review.staff = review.desks
	state.set_upgrade("room_speed", GameConfig.ROOM_SPEED_LEVELS, "general_services")
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_focus", _max_level("lead_focus"), "general_services")
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
	assert_true((entry.upgrades as Array).is_empty())


func test_complaint_demand_capacity_and_upgrades() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 1)
	var entry := ThroughputReport.complaint_area(state)
	var incoming := 1.0 / GameConfig.COMPLAINT_INTERVAL + Formulas.leave_complaint_rate(state)
	var letters := Formulas.complaint_letter_rate()
	assert_almost_eq(float(entry.demand), incoming + letters, 0.0001)
	var per_trip := GameConfig.INTERN_SPEED / WorldLayout.get_default().intern_trip_length()
	assert_almost_eq(float(entry.capacity), per_trip, 0.0001)
	assert_almost_eq(float(entry.capacity), 1.0 / Formulas.intern_trip_time(state), 0.0001)
	assert_eq(_entries(entry.upgrades), ["track:complaint_interns", "track:complaint_security", "track:intern_box_runs", "track:intern_speed"])
	assert_almost_eq(_entry_gain(entry.upgrades, "track:complaint_security"), GameConfig.SECURITY_BASE_CHANCE * incoming, 0.0001)
	for upgrade: Dictionary in entry.upgrades:
		var expected_effect := ThroughputReport.RELIEF if upgrade.entry == "track:complaint_security" else ThroughputReport.CAPACITY
		assert_eq(upgrade.effect, expected_effect, str(upgrade.entry))
	for upgrade_id: String in ["complaint_interns", "intern_box_runs", "intern_speed"]:
		var level := state.upgrade_level(upgrade_id)
		state.set_upgrade(upgrade_id, level + 1)
		assert_almost_eq(_entry_gain(entry.upgrades, "track:" + upgrade_id), ThroughputReport.complaint_capacity(state) - float(entry.capacity), 0.0001, upgrade_id)
		state.set_upgrade(upgrade_id, level)
	state.set_upgrade("complaint_security", 1)
	assert_almost_eq(_entry_gain(entry.upgrades, "track:complaint_security"), float(entry.demand) - ThroughputReport.complaint_demand(state), 0.0001)
	_assert_sorted(entry.upgrades)


func test_security_training_is_suggested_after_security() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("security_training", 5)
	var entry := ThroughputReport.complaint_area(state)
	var demand := float(entry.demand)
	assert_almost_eq(demand, ThroughputReport.complaint_demand(state, Formulas.security_chance(state)), 0.0001)
	assert_eq(_entries(entry.upgrades), ["track:security_training"])
	assert_eq((entry.upgrades as Array)[0].effect, ThroughputReport.RELIEF)
	state.set_upgrade("security_training", 6)
	assert_almost_eq(_entry_gain(entry.upgrades, "track:security_training"), demand - ThroughputReport.complaint_demand(state), 0.0001)


func test_interns_need_box_runs_before_more_interns_are_suggested() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.set_upgrade("complaint_interns", 1)
	var entry := ThroughputReport.complaint_area(state)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_entries(entry.upgrades), ["track:complaint_security"])
	state.set_upgrade("complaint_interns", 2)
	entry = ThroughputReport.complaint_area(state)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_entries(entry.upgrades), ["track:complaint_security", "track:intern_box_runs"])
	assert_almost_eq(_entry_gain(entry.upgrades, "track:intern_box_runs"), GameConfig.INTERN_SPEED / WorldLayout.get_default().intern_trip_length(), 0.0001)


func test_complaint_capacity_counts_box_runners() -> void:
	state.set_upgrade("complaint_interns", 3)
	state.set_upgrade("intern_box_runs", 4)
	state.set_upgrade("intern_speed", 10)
	var trip := WorldLayout.get_default().intern_trip_length() / (GameConfig.INTERN_SPEED * Formulas.track_value("intern_speed", 10))
	assert_almost_eq(ThroughputReport.complaint_capacity(state), 2.0 * 4.0 / trip, 0.0001)
	assert_almost_eq(ThroughputReport.intern_rate(state, 1, 1, 0), GameConfig.INTERN_SPEED / WorldLayout.get_default().intern_trip_length(), 0.0001)
	assert_eq(ThroughputReport.box_runners(0), 0)
	assert_eq(ThroughputReport.box_runners(1), 0)
	assert_eq(ThroughputReport.box_runners(3), 2)
	assert_eq(ThroughputReport.intern_rate(state, 0, 3), 0.0)
	assert_eq(ThroughputReport.intern_rate(state, 2, 0), 0.0)


func test_fully_staffed_complaints_offer_nothing() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for upgrade_id: String in ["complaint_interns", "intern_steadfast", "intern_speed", "complaint_box", "intern_box_runs", "complaint_security", "security_training"]:
		state.set_upgrade(upgrade_id, _max_level(upgrade_id))
	assert_true((ThroughputReport.complaint_area(state).upgrades as Array).is_empty())
	var incoming := 1.0 / GameConfig.COMPLAINT_INTERVAL + Formulas.leave_complaint_rate(state)
	assert_almost_eq(ThroughputReport.complaint_demand(state), (1.0 - GameConfig.SECURITY_MAX_CHANCE) * incoming + Formulas.complaint_letter_rate(), 0.0001)
	assert_almost_eq(ThroughputReport.complaint_demand(state, 0.0), incoming + Formulas.complaint_letter_rate(), 0.0001)


func test_lost_citizens_add_bundled_complaint_demand() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	var calm := ThroughputReport.complaint_demand(state, 0)
	assert_almost_eq(calm, 1.0 / GameConfig.COMPLAINT_INTERVAL + Formulas.complaint_letter_rate(), 0.0001)
	state.play_time = 60.0
	state.production.record(ProductionStats.LOST, "general_services", 30.0, 3)
	assert_almost_eq(ThroughputReport.complaint_demand(state, 0), calm + 3.0 / 60.0, 0.0001)
	var guarded := ThroughputReport.complaint_demand(state, GameConfig.SECURITY_BASE_CHANCE)
	assert_almost_eq(guarded, (1.0 - GameConfig.SECURITY_BASE_CHANCE) * (1.0 / GameConfig.COMPLAINT_INTERVAL + 3.0 / 60.0) + Formulas.complaint_letter_rate(), 0.0001)


func _reject_runners(count: int) -> void:
	for index in count:
		state.add_runner(Runner.REJECT)


func test_rejects_need_reject_runners() -> void:
	assert_eq(Formulas.reject_demand(state), 0.0)
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	var expected := Formulas.demand(state, state.department("general_services")) * GameConfig.REJECT_CHANCE
	var entry := ThroughputReport.reject_area(state)
	assert_almost_eq(float(entry.demand), expected, 0.0001)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(float(entry.load), 1.0)
	assert_eq(_entries(entry.upgrades), ["staff:runners"])
	assert_almost_eq(_gain(entry.upgrades, ThroughputReport.RUNNER), Formulas.runner_capacity(state) / Formulas.reject_trip_time(state), 0.0001)
	_reject_runners(1)
	entry = ThroughputReport.reject_area(state)
	assert_almost_eq(float(entry.capacity), Formulas.runner_capacity(state) / Formulas.reject_trip_time(state), 0.0001)
	assert_eq(_entries(entry.upgrades), ["staff:runners", "track:runner_speed", "track:runner_trolleys"])


func test_reject_runner_upgrade_gains_match_the_real_capacity_change() -> void:
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	_reject_runners(4)
	state.add_runner(Runner.INTAKE)
	var entry := ThroughputReport.reject_area(state)
	var capacity := float(entry.capacity)
	assert_almost_eq(capacity, Formulas.role_capacity(state, Runner.REJECT), 0.0001)
	var hire := _gain(entry.upgrades, ThroughputReport.RUNNER)
	state.add_runner(Runner.REJECT)
	assert_almost_eq(hire, float(ThroughputReport.reject_area(state).capacity) - capacity, 0.0001)
	state.runners.pop_back()
	for upgrade_id: String in ["runner_trolleys", "runner_speed"]:
		for level: int in [0, _max_level(upgrade_id) - 1]:
			state.set_upgrade(upgrade_id, level)
			entry = ThroughputReport.reject_area(state)
			capacity = float(entry.capacity)
			var gain := _entry_gain(entry.upgrades, "track:" + upgrade_id)
			state.set_upgrade(upgrade_id, level + 1)
			assert_almost_eq(gain, float(ThroughputReport.reject_area(state).capacity) - capacity, 0.0001, "%s %d" % [upgrade_id, level])
		state.set_upgrade(upgrade_id, 0)


func test_full_reject_crew_offers_nothing_more_at_maximum() -> void:
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	_reject_runners(GameConfig.MAX_RUNNERS)
	var entry := ThroughputReport.reject_area(state)
	assert_eq(_entries(entry.upgrades), ["track:runner_speed", "track:runner_trolleys"])
	state.set_upgrade("runner_trolleys", _max_level("runner_trolleys"))
	state.set_upgrade("runner_speed", _max_level("runner_speed"))
	entry = ThroughputReport.reject_area(state)
	assert_true((entry.upgrades as Array).is_empty())
	var loads := GameConfig.MAX_RUNNERS * Formulas.runner_load_limit(0)
	assert_almost_eq(float(entry.capacity), loads / Formulas.reject_trip_time(state), 0.0001)


func test_reject_runners_are_not_part_of_the_transport_area() -> void:
	state.add_runner(Runner.INTAKE)
	state.add_runner(Runner.INTERNAL)
	state.add_runner(Runner.OUTPUT)
	var before := ThroughputReport.transport_area(state)
	_reject_runners(3)
	var after := ThroughputReport.transport_area(state)
	assert_eq(float(after.capacity), float(before.capacity))
	assert_eq(_entries(after.upgrades), _entries(before.upgrades))
	assert_almost_eq(_entry_gain(after.upgrades, "track:runner_trolleys"), _entry_gain(before.upgrades, "track:runner_trolleys"), 0.0001)


func test_transport_ignores_tracks_when_only_reject_runners_exist() -> void:
	_reject_runners(2)
	var entry := ThroughputReport.transport_area(state)
	assert_eq(float(entry.capacity), 0.0)
	assert_eq(_entries(entry.upgrades), ["staff:runners"])


func test_rejects_ignore_customs() -> void:
	state.cases_completed = GameConfig.REJECT_MIN_CASES
	state.unlock_department("customs")
	var expected := Formulas.demand(state, state.department("general_services")) * GameConfig.REJECT_CHANCE
	assert_almost_eq(Formulas.reject_demand(state), expected, 0.0001)


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


func _hall_citizen(seated: bool, place: int) -> CaseFile:
	var citizen := CaseFile.new("general_services")
	citizen.phase = CaseFile.Phase.WAITING
	citizen.seated = seated
	citizen.place = place
	state.citizens.append(citizen)
	return citizen


func test_hall_areas_report_occupancy() -> void:
	var seating := ThroughputReport.seating_area(state)
	assert_eq(float(seating.capacity), float(GameConfig.BASE_SEATS))
	assert_eq(float(seating.demand), 0.0)
	assert_eq(_entries(seating.upgrades), ["track:seating"])
	assert_eq(_entry_gain(seating.upgrades, "track:seating"), float(GameConfig.upgrade("seating").step))
	for upgrade: Dictionary in seating.upgrades:
		assert_eq(upgrade.effect, ThroughputReport.PLACES)
	_hall_citizen(true, 0)
	_hall_citizen(true, 1)
	_hall_citizen(false, 0)
	assert_eq(float(ThroughputReport.seating_area(state).demand), 2.0)
	var standing := ThroughputReport.standing_area(state)
	assert_eq(float(standing.demand), 1.0)
	assert_eq(float(standing.capacity), float(GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS))
	assert_true((standing.upgrades as Array).is_empty())
	state.set_upgrade("seating", 4)
	assert_eq(float(ThroughputReport.seating_area(state).capacity), float(GameConfig.BASE_SEATS + 4))
	assert_eq(float(ThroughputReport.standing_area(state).capacity), float(GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS - 4))
	state.set_upgrade("seating", _max_level("seating"))
	assert_true((ThroughputReport.seating_area(state).upgrades as Array).is_empty())
	assert_eq(float(ThroughputReport.standing_area(state).capacity), 0.0)


func test_all_areas_cover_used_stations_and_support() -> void:
	var areas := ThroughputReport.all_areas(state)
	var kinds: Array[String] = []
	var keys: Array[String] = []
	for entry in areas:
		kinds.append(str(entry.area))
		if entry.area == ThroughputReport.STATION:
			keys.append(str(entry.key))
	assert_eq(keys, state.ordered_station_keys())
	for kind in [ThroughputReport.TRANSPORT, ThroughputReport.COMPLAINTS, ThroughputReport.REJECTS, ThroughputReport.PHONES, ThroughputReport.SEATING, ThroughputReport.WAITING, ThroughputReport.PICKUP_SEATING, ThroughputReport.PICKUP_WAITING]:
		assert_true(kinds.has(kind), kind)
	assert_true(kinds.has(ThroughputReport.TICKETS))
	var support := ThroughputReport.support_areas(state)
	assert_eq(support.size(), 9)
	var support_kinds := support.map(func(entry: Dictionary) -> String: return entry.area)
	assert_true(support_kinds.has(ThroughputReport.TICKETS))


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
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 1)
	state.station(GameConfig.RECEPTION).staff = 1
	state.station(GameConfig.COUNTER).staff = 1
	state.add_runner()
	state.add_runner(Runner.REJECT)
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
