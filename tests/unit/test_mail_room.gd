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
	var entry_id := "storage:" + GameConfig.MAILROOM
	assert_eq(UpgradeCatalog.find(state, entry_id).level, 1)
	assert_true(actions.buy_entry(entry_id))
	assert_eq(room.storage_level, 2)
	room.storage_level = GameConfig.MAIL_STORAGE_MAX_LEVEL
	assert_false(actions.can_upgrade_mail_storage())
	assert_false(actions.upgrade_mail_storage())
	assert_false(actions.buy_entry(entry_id))


func test_storage_upgrade_needs_mail_room_and_money() -> void:
	assert_false(actions.can_upgrade_mail_storage())
	_open_mail()
	state.money = 0.0
	assert_false(actions.can_upgrade_mail_storage())


func test_deliveries_fill_storage_and_drop_overflow_on_the_floor() -> void:
	var room := _open_mail()
	watch_signals(sim)
	var accepted := sim.deliver_mail(GameConfig.MAIL_STORAGE_BASE + 5)
	assert_eq(accepted, GameConfig.MAIL_STORAGE_BASE)
	assert_eq(room.inbox.size(), GameConfig.MAIL_STORAGE_BASE)
	assert_eq(state.mail_received, GameConfig.MAIL_STORAGE_BASE)
	assert_eq(state.mail_floor.size(), 5)
	assert_eq(state.mail_dropped, 5)
	assert_eq(state.mail_returned, 0)
	assert_signal_emitted_with_parameters(sim, "mail_delivered", [GameConfig.MAIL_STORAGE_BASE, 5, 0])
	for case_file in room.inbox:
		assert_true(case_file.mail)
		assert_false(case_file.urgent)
	for letter in state.mail_floor:
		assert_true(letter.mail)
		assert_eq(letter.next_key(), GameConfig.MAILROOM)


func test_full_floor_sends_letters_back() -> void:
	var room := _open_mail()
	watch_signals(sim)
	sim.deliver_mail(room.storage_capacity() + GameConfig.MAIL_FLOOR_MAX + 4)
	assert_eq(state.mail_floor.size(), GameConfig.MAIL_FLOOR_MAX)
	assert_eq(state.mail_returned, 4)
	assert_signal_emitted_with_parameters(sim, "mail_delivered", [room.storage_capacity(), GameConfig.MAIL_FLOOR_MAX, 4])


func test_floor_letters_wait_for_the_player() -> void:
	var room := _open_mail()
	sim.deliver_mail(room.storage_capacity() + 3)
	room.inbox.clear()
	state.player.position = Vector2(-500, -500)
	state.player.transfer_timer = 0.0
	sim.player_transfer()
	assert_eq(state.mail_floor.size(), 3)
	assert_true(room.inbox.is_empty())


func test_player_picks_up_floor_letters_into_the_shelf() -> void:
	var room := _open_mail()
	sim.deliver_mail(room.storage_capacity() + 3)
	room.inbox.pop_back()
	room.inbox.pop_back()
	state.player.position = WorldLayout.get_default().mail_floor_point()
	watch_signals(sim)
	assert_true(sim.player_transfer())
	assert_true(sim.player_transfer())
	assert_false(sim.player_transfer())
	assert_eq(state.mail_floor.size(), 1)
	assert_eq(room.inbox.size(), room.storage_capacity())
	assert_signal_emit_count(sim, "mail_picked_up", 2)


func test_pick_up_needs_letters_space_and_mail_room() -> void:
	assert_false(sim.pick_up_mail())
	var room := _open_mail()
	assert_false(sim.pick_up_mail())
	sim.deliver_mail(room.storage_capacity() + 1)
	assert_false(sim.pick_up_mail())
	room.inbox.pop_back()
	assert_true(sim.pick_up_mail())
	assert_true(state.mail_floor.is_empty())


func test_player_pick_up_works_with_full_hands() -> void:
	var room := _open_mail()
	sim.deliver_mail(room.storage_capacity() + 1)
	room.inbox.pop_back()
	for i in Formulas.carry_capacity(state):
		state.player.items.append(_mail_case())
	state.player.position = WorldLayout.get_default().mail_floor_point()
	assert_true(sim.player_transfer())
	assert_true(state.mail_floor.is_empty())


func test_guidance_points_to_floor_letters_when_the_shelf_has_space() -> void:
	var room := _open_mail()
	sim.deliver_mail(room.storage_capacity() + 2)
	state.player.position = WorldLayout.get_default().mail_floor_point()
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.MAIL_FLOOR)
	room.inbox.clear()
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.MAIL_FLOOR)
	assert_eq(task.point, WorldLayout.get_default().mail_floor_point())


func test_floor_letters_survive_saving_and_are_repaired() -> void:
	var room := _open_mail()
	sim.deliver_mail(room.storage_capacity() + 2)
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.mail_floor.size(), 2)
	assert_true(loaded.mail_floor[0].mail)
	assert_eq(loaded.mail_dropped, 2)
	var data := state.to_dict()
	var crowd: Array = []
	for i in GameConfig.MAIL_FLOOR_MAX + 5:
		crowd.append(_mail_case().to_dict())
	crowd.append("junk")
	crowd.append(CaseFile.new("general_services").to_dict())
	data.mail_floor = crowd
	data.mail_dropped = -4
	var repaired := GameState.from_dict(data)
	assert_eq(repaired.mail_floor.size(), GameConfig.MAIL_FLOOR_MAX)
	assert_eq(repaired.mail_dropped, 0)
	data.erase("mail_floor")
	data.erase("mail_dropped")
	var legacy := GameState.from_dict(data)
	assert_true(legacy.mail_floor.is_empty())
	assert_eq(legacy.mail_dropped, 0)


func test_mail_floor_texts_exist() -> void:
	for key in ["FMT_FLOAT_MAIL_DROPPED", "FMT_MAIL_FLOOR", "MAIL_STORAGE_TITLE", "ENTRY_DESC_STORAGE", "FMT_MAIL_STORAGE_INFO"]:
		assert_ne(TranslationServer.translate(key), key, key)
	for upgrade_id in ["mail_subscription", "mail_frequency", "registered_mail", "letter_opener"]:
		assert_ne(TranslationServer.translate("TRACK_" + upgrade_id.to_upper()), "TRACK_" + upgrade_id.to_upper(), upgrade_id)
		assert_ne(TranslationServer.translate("TRACK_DESC_" + upgrade_id.to_upper()), "TRACK_DESC_" + upgrade_id.to_upper(), upgrade_id)


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
	state.set_upgrade("mail_frequency", 10)
	state.mail_timer = 0.05
	sim.tick(0.1)
	assert_almost_eq(state.mail_timer, Formulas.track_value("mail_frequency", 10), 0.001)
	assert_lt(state.mail_timer, GameConfig.MAIL_INTERVAL)
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
	state.set_upgrade("mail_subscription", 2)
	assert_eq(Formulas.mail_batch(state), base + GameConfig.MAIL_BATCH_PER_DEPT + int(Formulas.track_value("mail_subscription", 2)))
	assert_gt(Formulas.mail_batch(state), base + GameConfig.MAIL_BATCH_PER_DEPT)
	assert_almost_eq(Formulas.mail_interval(state), GameConfig.MAIL_INTERVAL, 0.0001)
	assert_almost_eq(Formulas.mail_rate(state), Formulas.mail_batch(state) / GameConfig.MAIL_INTERVAL, 0.0001)
	state.set_upgrade("mail_frequency", 5)
	assert_almost_eq(Formulas.mail_interval(state), Formulas.track_value("mail_frequency", 5), 0.0001)
	assert_lt(Formulas.mail_interval(state), GameConfig.MAIL_INTERVAL)
	assert_almost_eq(Formulas.mail_rate(state), Formulas.mail_batch(state) / Formulas.mail_interval(state), 0.0001)


func test_mail_rate_is_zero_without_mail_room() -> void:
	assert_eq(Formulas.mail_rate(state), 0.0)
	assert_eq(Formulas.station_demand(state, GameConfig.MAILROOM), 0.0)


func test_mail_pays_less_and_registered_mail_raises_it() -> void:
	var citizen := CaseFile.new("general_services")
	citizen.route = RouteBuilder.build(citizen)
	var full: float = Formulas.case_outcome(state, citizen).money
	assert_almost_eq(Formulas.case_outcome(state, _mail_case()).money, full * GameConfig.MAIL_REWARD_FACTOR, 0.001)
	state.set_upgrade("registered_mail", 3)
	assert_almost_eq(Formulas.mail_reward_factor(state), Formulas.track_value("registered_mail", 3), 0.0001)
	assert_gt(Formulas.mail_reward_factor(state), GameConfig.MAIL_REWARD_FACTOR)
	assert_almost_eq(Formulas.case_outcome(state, _mail_case()).money, full * Formulas.mail_reward_factor(state), 0.001)


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
	state.set_upgrade("letter_opener", 1)
	assert_lt(Formulas.station_case_time(state, room, false), float(GameConfig.station_kind("mailroom").base_time))
	assert_almost_eq(Formulas.station_case_time(state, room, false), float(GameConfig.station_kind("mailroom").base_time) / Formulas.track_value("letter_opener", 1), 0.0001)
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
