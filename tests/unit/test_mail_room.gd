extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions


func before_each() -> void:
	state = GameState.create_new(17)
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.money = 1e9


func _open_mail() -> Station:
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	return state.ensure_mailroom()


func _mail_case(dept_id: String = "general_services") -> CaseFile:
	var case_file := CaseFile.new(dept_id)
	case_file.mail = true
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func test_mail_room_opens_with_the_building_stage() -> void:
	assert_false(state.mail_unlocked())
	assert_null(state.ensure_mailroom())
	assert_null(state.mailroom())
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE - 1
	state.reputation = 1e6
	state.reputation_peak = 1e6
	assert_true(actions.expand_building())
	assert_not_null(state.mailroom())
	assert_true(state.mailroom().is_mailroom())
	assert_true(state.mailroom().is_entry())
	assert_eq(state.mailroom().staff, 0)
	assert_eq(state.ordered_station_keys()[0], GameConfig.MAILROOM)


func test_mail_route_skips_the_counter() -> void:
	var route := RouteBuilder.build(_mail_case())
	assert_eq(route[0], GameConfig.MAILROOM)
	assert_false(route.has(GameConfig.COUNTER))
	assert_false(route.has(GameConfig.RECEPTION))
	state.unlock_department("business_licences")
	var inspected := RouteBuilder.build(_mail_case("business_licences"))
	assert_true(inspected.has(GameConfig.INSPECTION))
	assert_eq(inspected[-1], GameConfig.department_station_keys("business_licences")[1])


func test_storage_capacity_and_upgrade() -> void:
	var room := _open_mail()
	assert_eq(room.storage_capacity(), GameConfig.MAIL_STORAGE_BASE)
	assert_eq(room.inbox_capacity(999), GameConfig.MAIL_STORAGE_BASE)
	var cost := Formulas.mail_storage_cost(room)
	assert_eq(cost, GameConfig.MAIL_STORAGE_COST)
	var money := state.money
	assert_true(actions.upgrade_mail_storage())
	assert_eq(room.storage_level, 1)
	assert_almost_eq(state.money, money - cost, 0.001)
	assert_eq(room.storage_capacity(), GameConfig.MAIL_STORAGE_BASE + GameConfig.MAIL_STORAGE_PER_LEVEL)
	assert_almost_eq(Formulas.mail_storage_cost(room), GameConfig.MAIL_STORAGE_COST * GameConfig.MAIL_STORAGE_GROWTH, 0.001)
	room.storage_level = GameConfig.MAIL_STORAGE_MAX_LEVEL
	assert_false(actions.can_upgrade_mail_storage())
	assert_false(actions.upgrade_mail_storage())


func test_storage_upgrade_needs_mail_room_and_money() -> void:
	assert_false(actions.can_upgrade_mail_storage())
	_open_mail()
	state.money = 0.0
	assert_false(actions.can_upgrade_mail_storage())


func test_deliveries_fill_storage_and_return_overflow() -> void:
	var room := _open_mail()
	watch_signals(sim)
	var accepted := sim.deliver_mail(GameConfig.MAIL_STORAGE_BASE + 5)
	assert_eq(accepted, GameConfig.MAIL_STORAGE_BASE)
	assert_eq(room.inbox.size(), GameConfig.MAIL_STORAGE_BASE)
	assert_eq(state.mail_received, GameConfig.MAIL_STORAGE_BASE)
	assert_eq(state.mail_returned, 5)
	assert_signal_emitted_with_parameters(sim, "mail_delivered", [GameConfig.MAIL_STORAGE_BASE, 5])
	for case_file in room.inbox:
		assert_true(case_file.mail)
		assert_false(case_file.urgent)


func test_returned_letters_cost_nothing() -> void:
	var room := _open_mail()
	state.reputation = 5.0
	sim.deliver_mail(room.storage_capacity() + 10)
	assert_eq(state.reputation, 5.0)
	assert_eq(state.citizens_lost, 0)


func test_delivery_needs_mail_room_and_departments() -> void:
	assert_eq(sim.deliver_mail(3), 0)
	_open_mail()
	state.department("general_services").unlocked = false
	assert_eq(sim.deliver_mail(3), 0)


func test_postman_comes_on_a_timer() -> void:
	var room := _open_mail()
	state.mail_timer = 0.05
	sim.tick(0.1)
	assert_eq(room.inbox.size(), Formulas.mail_batch(state))
	assert_almost_eq(state.mail_timer, GameConfig.MAIL_INTERVAL, 0.001)
	state.stations.erase(GameConfig.MAILROOM)
	state.mail_timer = 0.05
	sim.tick(0.1)
	assert_almost_eq(state.mail_timer, 0.05, 0.001)


func test_batch_grows_with_departments_and_subscription() -> void:
	_open_mail()
	var base := Formulas.mail_batch(state)
	assert_eq(base, GameConfig.MAIL_BATCH_BASE + GameConfig.MAIL_BATCH_PER_DEPT)
	state.unlock_department("tax_services")
	state.unlock_department("customs")
	assert_eq(Formulas.mail_batch(state), base + GameConfig.MAIL_BATCH_PER_DEPT)
	state.research["mail_subscription"] = 2
	assert_eq(Formulas.mail_batch(state), base + GameConfig.MAIL_BATCH_PER_DEPT + 2 * GameConfig.MAIL_SUBSCRIPTION_BATCH)
	assert_almost_eq(Formulas.mail_rate(state), Formulas.mail_batch(state) / GameConfig.MAIL_INTERVAL, 0.0001)


func test_mail_rate_is_zero_without_mail_room() -> void:
	assert_eq(Formulas.mail_rate(state), 0.0)
	assert_eq(Formulas.station_demand(state, GameConfig.MAILROOM), 0.0)


func test_mail_pays_less_and_research_raises_it() -> void:
	var citizen := CaseFile.new("general_services")
	citizen.route = RouteBuilder.build(citizen)
	var full: float = Formulas.case_outcome(state, citizen).money
	assert_almost_eq(Formulas.case_outcome(state, _mail_case()).money, full * GameConfig.MAIL_REWARD_FACTOR, 0.001)
	state.research["registered_mail"] = 3
	assert_almost_eq(Formulas.mail_reward_factor(state), GameConfig.MAIL_REWARD_FACTOR + 3 * GameConfig.MAIL_REWARD_PER_LEVEL, 0.0001)


func test_mail_completes_without_counter_and_without_praise() -> void:
	_open_mail()
	var signature := state.station("general_services/signature")
	var letter := _mail_case()
	letter.step = letter.route.size() - 1
	signature.jobs[0] = StationJob.new(letter, 0.01)
	signature.jobs[0].progress = 1.0
	watch_signals(sim)
	var money := state.money
	assert_true(sim.finish_job(signature, 0))
	assert_gt(state.money, money)
	assert_signal_emitted(sim, "mail_answered")
	assert_signal_not_emitted(sim, "case_completed")


func test_mail_has_no_patience() -> void:
	var room := _open_mail()
	var letter := _mail_case()
	letter.waited = 1e6
	room.inbox.append(letter)
	sim.tick(0.1)
	assert_true(room.inbox.has(letter))
	assert_eq(state.citizens_lost, 0)


func test_mail_does_not_take_seats() -> void:
	_open_mail()
	var review := state.station("general_services/review")
	var before := state.seated_citizens()
	review.inbox.append(_mail_case())
	assert_eq(state.seated_citizens(), before)
	var companion := CaseFile.new("general_services")
	companion.companion = true
	review.inbox.append(companion)
	assert_eq(state.seated_citizens(), before)
	review.inbox.append(CaseFile.new("general_services"))
	assert_eq(state.seated_citizens(), before + 1)


func test_citizens_go_before_mail() -> void:
	var review := state.station("general_services/review")
	var letter := _mail_case()
	letter.step = 1
	var citizen := CaseFile.new("general_services")
	citizen.route = RouteBuilder.build(citizen)
	citizen.step = 1
	review.inbox.append_array([letter, citizen])
	assert_eq(review.take_next_case(true, false), citizen)
	assert_eq(review.take_next_case(true, false), letter)


func test_mail_room_has_its_own_case_time_and_demand() -> void:
	var room := _open_mail()
	assert_almost_eq(Formulas.station_case_time(state, room, false), float(GameConfig.station_kind("mailroom").base_time), 0.0001)
	state.research["letter_opener"] = 1
	assert_lt(Formulas.station_case_time(state, room, false), float(GameConfig.station_kind("mailroom").base_time))
	assert_almost_eq(Formulas.station_demand(state, GameConfig.MAILROOM), Formulas.mail_rate(state), 0.0001)


func test_missing_forms_come_back_by_post() -> void:
	_open_mail()
	state.cases_completed = GameConfig.MISSING_FORM_MIN_CASES
	var review := state.station("general_services/review")
	var missed := 0
	for i in 400:
		var case_file := CaseFile.new("general_services")
		case_file.route = RouteBuilder.build(case_file)
		case_file.step = 1
		review.jobs[0] = StationJob.new(case_file, 0.01)
		review.jobs[0].progress = 1.0
		review.outbox.clear()
		sim.finish_job(review, 0)
		if review.outbox.is_empty():
			missed += 1
	assert_gt(missed, 0)
	assert_lt(missed, 80)
	assert_eq(state.mail_promised.size(), missed)
	var room := state.mailroom()
	sim.deliver_mail(0)
	assert_eq(room.inbox.size(), mini(missed, room.storage_capacity()))
	assert_true(state.mail_promised.is_empty())


func test_missing_forms_need_mail_room_and_experience() -> void:
	var review := state.station("general_services/review")
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	for i in 200:
		assert_false(sim._misses_form(review, case_file))
	_open_mail()
	state.cases_completed = 0
	for i in 200:
		assert_false(sim._misses_form(review, case_file))
	state.cases_completed = GameConfig.MISSING_FORM_MIN_CASES
	case_file.follow_up = true
	for i in 200:
		assert_false(sim._misses_form(review, case_file))
	assert_false(sim._misses_form(state.station(GameConfig.RECEPTION), _mail_case()))


func test_mail_state_survives_saving() -> void:
	var room := _open_mail()
	room.storage_level = 3
	room.inbox.append(_mail_case())
	state.mail_timer = 12.0
	state.mail_received = 7
	state.mail_returned = 2
	state.mail_promised.append("general_services")
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.mailroom().storage_level, 3)
	assert_true(loaded.mailroom().inbox[0].mail)
	assert_eq(loaded.mail_timer, 12.0)
	assert_eq(loaded.mail_received, 7)
	assert_eq(loaded.mail_returned, 2)
	assert_eq(loaded.mail_promised, ["general_services"] as Array[String])


func test_invalid_mail_values_are_repaired() -> void:
	var room := _open_mail()
	var data := state.to_dict()
	data.mail_timer = 1e9
	data.mail_received = -3
	data.mail_returned = -1
	data.mail_promised = ["nope", "customs", "general_services"]
	data.stations[GameConfig.MAILROOM].storage_level = 999
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.mail_timer, GameConfig.MAIL_INTERVAL)
	assert_eq(loaded.mail_received, 0)
	assert_eq(loaded.mail_returned, 0)
	assert_eq(loaded.mail_promised, ["general_services"] as Array[String])
	assert_eq(loaded.mailroom().storage_level, GameConfig.MAIL_STORAGE_MAX_LEVEL)
	var other := Station.from_dict({"key": "general_services/review", "storage_level": 5})
	assert_eq(other.storage_level, 0)
	assert_not_null(room)


func test_old_saves_get_a_mail_room_when_the_stage_allows() -> void:
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	var data := state.to_dict()
	data.erase("mail_timer")
	data.erase("mail_promised")
	var loaded := GameState.from_dict(data)
	assert_not_null(loaded.mailroom())
	assert_eq(loaded.mail_timer, GameConfig.MAIL_FIRST_SECONDS)


func test_mail_leaves_room_for_citizens_downstream() -> void:
	var room := _open_mail()
	room.staff = 1
	var review := state.station("general_services/review")
	var reserve := ceili(review.inbox_capacity(state.lobby_capacity()) * GameConfig.MAIL_TARGET_SHARE)
	for i in reserve:
		review.inbox.append(_case_at_review())
	room.inbox.append(_mail_case())
	assert_false(sim.start_job(room, 0))
	review.inbox.pop_back()
	assert_true(sim.start_job(room, 0))
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	reception.inbox.append(_citizen())
	assert_true(sim.start_job(reception, 0))


func _case_at_review() -> CaseFile:
	var case_file := _citizen()
	case_file.step = 1
	return case_file


func _citizen() -> CaseFile:
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	return case_file
