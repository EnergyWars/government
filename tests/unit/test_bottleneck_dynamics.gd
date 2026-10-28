extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions


func before_each() -> void:
	state = GameState.create_new(29)
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.money = 1e9


func _case(dept_id: String = "general_services", step: int = 0) -> CaseFile:
	var case_file := CaseFile.new(dept_id)
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = step
	return case_file


func _finish(station: Station, case_file: CaseFile, by_hand: bool = false) -> bool:
	station.jobs[0] = StationJob.new(case_file, 0.01)
	station.jobs[0].progress = 1.0
	station.jobs[0].by_hand = by_hand
	return sim.finish_job(station, 0)


func test_level_speed_has_milestones() -> void:
	assert_eq(Formulas.level_speed(1), 1.0)
	assert_almost_eq(Formulas.level_speed(2), 1.0 + GameConfig.LEVEL_SPEED_BONUS, 0.0001)
	var before := Formulas.level_speed(GameConfig.LEVEL_MILESTONE_STEP - 1)
	var after := Formulas.level_speed(GameConfig.LEVEL_MILESTONE_STEP)
	assert_gt(after / before, GameConfig.LEVEL_MILESTONE_BONUS)
	assert_eq(Formulas.levels_to_milestone(1), GameConfig.LEVEL_MILESTONE_STEP - 1)
	assert_eq(Formulas.levels_to_milestone(GameConfig.LEVEL_MILESTONE_STEP), GameConfig.LEVEL_MILESTONE_STEP)
	assert_eq(Formulas.levels_to_milestone(GameConfig.LEVEL_MILESTONE_STEP - 1), 1)


func test_room_speed_purchase_starts_inauguration_rush() -> void:
	var review := state.station("general_services/review")
	var signature := state.station("general_services/signature")
	var reception := state.station(GameConfig.RECEPTION)
	assert_eq(Formulas.work_speed(state, review), 1.0)
	assert_true(actions.buy_upgrade("room_speed", "general_services"))
	assert_eq(state.upgrade_level("room_speed", "general_services"), 1)
	assert_eq(review.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(signature.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(reception.rush, 0.0)
	assert_eq(Formulas.work_speed(state, review), GameConfig.UPGRADE_RUSH_SPEED)
	assert_almost_eq(Formulas.station_speed(state, review), Formulas.level_speed(2), 0.0001)
	sim.tick(1.0)
	assert_almost_eq(review.rush, GameConfig.UPGRADE_RUSH_SECONDS - 1.0, 0.001)
	var loaded := Station.from_dict(review.to_dict())
	assert_almost_eq(loaded.rush, review.rush, 0.001)
	assert_eq(Station.from_dict({"key": review.key, "rush": 1e9}).rush, GameConfig.UPGRADE_RUSH_SECONDS)
	sim.tick(GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(review.rush, 0.0)


func test_other_room_tracks_do_not_start_a_rush() -> void:
	var review := state.station("general_services/review")
	assert_true(actions.buy_upgrade("room_trays", "general_services"))
	assert_eq(review.rush, 0.0)
	assert_eq(review.tray_size, GameConfig.TRAY_BASE + 1)
	assert_true(actions.buy_upgrade("room_speed", GameConfig.ROOM_HALL))
	assert_eq(review.rush, 0.0)
	assert_eq(state.station(GameConfig.RECEPTION).rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(state.station(GameConfig.COUNTER).rush, GameConfig.UPGRADE_RUSH_SECONDS)


func test_swamped_threshold_follows_the_tray_size() -> void:
	var review := state.station("general_services/review")
	var lobby := state.lobby_capacity()
	var before := ceili(review.inbox_capacity(lobby) * GameConfig.SWAMPED_SHARE)
	state.set_upgrade("room_trays", int(GameConfig.upgrade("room_trays").max), "general_services")
	assert_eq(review.inbox_capacity(lobby), GameConfig.TRAY_MAX)
	assert_gt(ceili(review.inbox_capacity(lobby) * GameConfig.SWAMPED_SHARE), before)
	for i in before:
		review.inbox.append(_case("general_services", 1))
	assert_false(review.is_swamped(lobby))


func test_swamped_stations() -> void:
	var review := state.station("general_services/review")
	var lobby := state.lobby_capacity()
	assert_false(review.is_swamped(lobby))
	var threshold := ceili(review.inbox_capacity(lobby) * GameConfig.SWAMPED_SHARE)
	for i in threshold:
		review.inbox.append(_case("general_services", 1))
	assert_true(review.is_swamped(lobby))
	var reception := state.station(GameConfig.RECEPTION)
	for i in 50:
		reception.inbox.append(_case())
	assert_false(reception.is_swamped(lobby))


func test_swamped_stations_tire_faster() -> void:
	var review := state.station("general_services/review")
	review.inbox.append(_case("general_services", 1))
	var alert := review.moods[0].alert
	sim._update_moods(1.0)
	var calm_loss := alert - review.moods[0].alert
	while not review.is_swamped(state.lobby_capacity()):
		review.inbox.append(_case("general_services", 1))
	alert = review.moods[0].alert
	sim._update_moods(1.0)
	assert_almost_eq(alert - review.moods[0].alert, calm_loss * GameConfig.SWAMPED_DROWSY_FACTOR, 0.0001)


func test_sickness_prefers_swamped_stations() -> void:
	state.unlock_department("tax_services")
	var review := state.station("general_services/review")
	var tax := state.station("tax_services/review")
	review.staff = 1
	tax.staff = 1
	state.station(GameConfig.RECEPTION).staff = 1
	while not review.is_swamped(state.lobby_capacity()):
		review.inbox.append(_case("general_services", 1))
	var hits := 0
	for i in 300:
		review.moods[0].wake(10.0)
		tax.moods[0].wake(10.0)
		state.station(GameConfig.RECEPTION).moods[0].wake(10.0)
		sim.report_sick()
		state.calls.clear()
		if review.moods[0].is_sick():
			hits += 1
	assert_gt(hits, 150)


func test_downstream_keys_follow_the_route() -> void:
	assert_eq(Formulas.downstream_keys(state, GameConfig.RECEPTION), ["general_services/review"] as Array[String])
	assert_eq(Formulas.downstream_keys(state, "general_services/review"), ["general_services/signature"] as Array[String])
	assert_eq(Formulas.downstream_keys(state, GameConfig.COUNTER), [] as Array[String])
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	assert_eq(Formulas.downstream_keys(state, GameConfig.MAILROOM), ["general_services/review"] as Array[String])


func test_availability_reflects_rests_and_sickness() -> void:
	var review := state.station("general_services/review")
	var available := Formulas.availability(state, review)
	assert_gt(available, 0.0)
	assert_lt(available, 1.0)
	assert_eq(Formulas.availability(state, Station.new("tax_services/signature")), 1.0)
	state.set_upgrade("wake_service", int(GameConfig.upgrade("wake_service").max))
	assert_gt(Formulas.availability(state, review), available)
	assert_gt(Formulas.sick_share(state), 0.0)
	state.hr = 2
	assert_lt(Formulas.sick_share(state), Formulas.sick_share(GameState.create_new(1)))
	var with_hr := Formulas.availability(state, review)
	state.set_upgrade("team_lead", 1, "general_services")
	state.set_upgrade("lead_breaks", 30, "general_services")
	state.set_upgrade("lead_health", 30, "general_services")
	assert_gt(Formulas.availability(state, review), with_hr)
	assert_lt(Formulas.sick_share(state, "general_services"), Formulas.sick_share(state))


func test_sick_interval_scales_with_staff() -> void:
	var one := Formulas.sick_interval(state, 0.5)
	var review := state.station("general_services/review")
	review.add_desk()
	review.staff = 2
	assert_almost_eq(Formulas.sick_interval(state, 0.5), one / 2.0, 0.001)


func test_multi_application_chance() -> void:
	assert_eq(Formulas.multi_application_chance(0), 0.0)
	assert_almost_eq(Formulas.multi_application_chance(1), GameConfig.MULTI_BASE_CHANCE + GameConfig.MULTI_PER_DEPT, 0.0001)
	assert_eq(Formulas.multi_application_chance(100), GameConfig.MULTI_MAX_CHANCE)


func test_extras_only_for_other_unlocked_civil_departments() -> void:
	var gs := state.department("general_services")
	for i in 50:
		assert_true(sim.roll_extras(gs).is_empty())
	state.unlock_department("tax_services")
	state.unlock_department("customs")
	var seen := 0
	for i in 300:
		var extras := sim.roll_extras(gs)
		assert_lte(extras.size(), GameConfig.MULTI_MAX_EXTRAS)
		for extra in extras:
			assert_eq(extra, "tax_services")
		seen += extras.size()
	assert_gt(seen, 20)
	assert_true(sim.roll_extras(state.department("customs")).is_empty())


func test_spawned_citizens_may_bring_extras() -> void:
	state.unlock_department("tax_services")
	var bundles := 0
	for i in 200:
		state.station(GameConfig.RECEPTION).inbox.clear()
		state.ticket_line.clear()
		var case_file := sim.spawn_case(state.department("general_services"))
		if not case_file.extras.is_empty():
			bundles += 1
	assert_gt(bundles, 10)
	state.station(GameConfig.RECEPTION).inbox.clear()
	state.ticket_line.clear()
	assert_true(sim.spawn_case(state.department("general_services"), true).extras.is_empty())


func test_bundles_take_longer_at_reception() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	var single := _case()
	var bundle := _case()
	bundle.extras.append("tax_services")
	assert_almost_eq(Formulas.required_time(state, reception, bundle), Formulas.required_time(state, reception, single) * (1.0 + GameConfig.MULTI_TIME_PER_EXTRA), 0.0001)
	var review := state.station("general_services/review")
	assert_eq(Formulas.required_time(state, review, bundle), Formulas.required_time(state, review, single))


func test_reception_splits_bundles_into_companion_cases() -> void:
	state.unlock_department("tax_services")
	var reception := state.station(GameConfig.RECEPTION)
	var bundle := _case()
	bundle.extras.append("tax_services")
	watch_signals(sim)
	assert_true(_finish(reception, bundle))
	assert_eq(reception.outbox.size(), 2)
	var companion := reception.outbox[1]
	assert_true(companion.companion)
	assert_eq(companion.dept_id, "tax_services")
	assert_eq(companion.step, bundle.step)
	assert_eq(companion.next_key(), "tax_services/review")
	assert_true(bundle.extras.is_empty())
	assert_eq(state.bundles, 1)
	assert_signal_emitted_with_parameters(sim, "applications_bundled", ["general_services", 1])


func test_bundles_wait_for_outbox_space() -> void:
	state.unlock_department("tax_services")
	var reception := state.station(GameConfig.RECEPTION)
	while reception.outbox.size() < reception.outbox_capacity() - 1:
		reception.outbox.append(_case("general_services", 1))
	var bundle := _case()
	bundle.extras.append("tax_services")
	assert_false(_finish(reception, bundle))
	reception.outbox.pop_back()
	assert_true(_finish(reception, bundle))


func test_locked_extras_are_dropped() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	var bundle := _case()
	bundle.extras.append("tax_services")
	assert_true(_finish(reception, bundle))
	assert_eq(reception.outbox.size(), 1)
	assert_eq(state.bundles, 1)


func test_case_file_saves_and_validates_bundle_fields() -> void:
	var bundle := _case()
	bundle.mail = true
	bundle.companion = true
	bundle.extras.append("tax_services")
	var loaded := CaseFile.from_dict(bundle.to_dict())
	assert_true(loaded.mail)
	assert_true(loaded.companion)
	assert_eq(loaded.extras, ["tax_services"] as Array[String])
	var data := bundle.to_dict()
	data.extras = ["nope", "customs", "tax_services", "housing", "business_licences"]
	loaded = CaseFile.from_dict(data)
	assert_eq(loaded.extras, ["tax_services", "housing"] as Array[String])
	assert_false(CaseFile.from_dict({"dept": "general_services"}).mail)


func test_new_departments_need_hands_on_onboarding() -> void:
	state.unlock_department("tax_services")
	var key := "tax_services/review"
	var tax := state.department("tax_services")
	assert_false(tax.is_onboarded())
	assert_true(actions.needs_onboarding(key))
	assert_false(actions.can_hire(key))
	assert_false(actions.hire(key))
	assert_false(actions.needs_onboarding("general_services/review"))
	assert_false(actions.needs_onboarding(GameConfig.RECEPTION))
	assert_false(actions.needs_onboarding("nope"))
	assert_true(state.department("general_services").is_onboarded())


func test_hand_work_onboards_with_a_reward() -> void:
	state.unlock_department("tax_services")
	var review := state.station("tax_services/review")
	var tax := state.department("tax_services")
	watch_signals(sim)
	var money := state.money
	var reputation := state.reputation
	for i in GameConfig.HANDS_ON_CASES:
		review.outbox.clear()
		assert_true(_finish(review, _case("tax_services", 1), true))
	assert_eq(tax.hands_on, GameConfig.HANDS_ON_CASES)
	assert_true(tax.is_onboarded())
	assert_gte(state.money, money + Formulas.hands_on_reward(tax))
	assert_almost_eq(state.reputation, reputation + GameConfig.HANDS_ON_REPUTATION, 0.5)
	assert_signal_emit_count(sim, "onboarding_completed", 1)
	review.outbox.clear()
	_finish(review, _case("tax_services", 1), true)
	assert_eq(tax.hands_on, GameConfig.HANDS_ON_CASES)
	assert_true(actions.can_hire("tax_services/review"))


func test_staff_work_does_not_onboard() -> void:
	state.unlock_department("tax_services")
	var review := state.station("tax_services/review")
	_finish(review, _case("tax_services", 1), false)
	assert_eq(state.department("tax_services").hands_on, 0)
	state.unlock_department("housing")
	var registry := state.station("general_services/review")
	_finish(registry, _case("housing", 2), true)
	assert_eq(state.department("housing").hands_on, 0)


func test_hands_on_is_saved_and_old_saves_count_as_onboarded() -> void:
	state.unlock_department("tax_services")
	state.department("tax_services").hands_on = 2
	var data := state.to_dict()
	assert_eq(GameState.from_dict(data).department("tax_services").hands_on, 2)
	data.departments.tax_services.erase("hands_on")
	assert_eq(GameState.from_dict(data).department("tax_services").hands_on, GameConfig.HANDS_ON_CASES)
	data.departments.tax_services.hands_on = 99
	assert_eq(GameState.from_dict(data).department("tax_services").hands_on, GameConfig.HANDS_ON_CASES)
	assert_eq(Department.from_dict({"id": "housing"}).hands_on, 0)


func test_player_works_only_one_unstaffed_desk() -> void:
	var review := state.station("general_services/review")
	review.add_desk()
	review.add_desk()
	review.staff = 0
	for i in 3:
		review.inbox.append(_case("general_services", 1))
	state.player.position = WorldLayout.get_default().desk_work_point("general_services/review", 1)
	assert_true(sim.work_at_desk(0.01))
	var busy := 0
	for job in review.jobs:
		if job != null:
			busy += 1
	assert_eq(busy, 1)


func test_positive_events_raise_fees() -> void:
	var case_file := _case()
	var money: float = Formulas.case_outcome(state, case_file).money
	assert_eq(Formulas.event_fee(state), 1.0)
	state.event_id = "mayor_visit"
	state.event_time_left = 30.0
	assert_eq(Formulas.event_fee(state), float(GameConfig.EVENTS.mayor_visit.fee))
	assert_almost_eq(Formulas.case_outcome(state, case_file).money, money * float(GameConfig.EVENTS.mayor_visit.fee), 0.001)
	assert_false(GameConfig.EVENTS.mayor_visit.has("arrival"))


func test_guidance_points_to_cover_sick_desks() -> void:
	var review := state.station("general_services/review")
	review.moods[0].rest(DeskMood.SICK)
	review.inbox.append(_case("general_services", 1))
	var found := false
	state.player.position = Vector2(-500, -500)
	var task := Guidance.next_task(state)
	if review.can_cover(0):
		found = task.action == Guidance.COVER or task.action == Guidance.WORK
	else:
		found = true
	assert_true(found)
