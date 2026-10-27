extends GutTest

const PHOTO := GameConfig.PHOTO_STATION

var state: GameState
var sim: Simulation
var actions: GameActions
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(31)
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.complaint_letter_timer = 1e6
	state.dispute_timer = 1e6
	state.ruckus_timer = 1e6
	state.lunch_timer = 1e6
	state.gift_timer = 1e6
	state.praise_timer = 1e6
	state.player.position = Vector2(50, 50)


func _photo() -> Station:
	return state.station(PHOTO)


func _run_until(condition: Callable, limit: float = 60.0, step: float = 0.05) -> bool:
	var elapsed := 0.0
	while elapsed < limit:
		if condition.call():
			return true
		sim.tick(step)
		elapsed += step
	return condition.call()


func _waiting_citizen(ticket: int = 5) -> CaseFile:
	var citizen := CaseFile.new("general_services")
	citizen.route = RouteBuilder.build(citizen)
	citizen.step = citizen.route.find(PHOTO)
	citizen.ticket = ticket
	citizen.phase = CaseFile.Phase.WAITING_DOC
	citizen.place = state.free_place(true, GameConfig.HALL_PICKUP)
	citizen.seated = true
	citizen.spot = layout.waiting_seat(citizen.place, GameConfig.HALL_PICKUP)
	citizen.waited = 12.0
	state.citizens.append(citizen)
	_photo().inbox.append(citizen)
	return citizen


func test_new_game_starts_with_empty_desks_in_citizen_services() -> void:
	assert_eq(state.station("general_services/review").staff, 0)
	assert_eq(state.station("general_services/review").desks, 1)
	assert_false(_photo().machine)
	assert_eq(_photo().staff, 0)
	assert_true(_photo().calls_citizens())
	assert_false(state.station("general_services/review").calls_citizens())


func test_photographers_can_be_hired_right_away() -> void:
	state.money = 1e9
	assert_true(actions.can_hire(PHOTO))
	assert_true(actions.hire(PHOTO))
	assert_eq(_photo().staff, 1)
	assert_true(UpgradeCatalog.find(state, "hire:" + PHOTO) != null)


func test_unstaffed_photo_desk_calls_nobody() -> void:
	var citizen := _waiting_citizen()
	sim.tick(0.1)
	assert_eq(citizen.phase, CaseFile.Phase.WAITING_DOC)
	assert_null(sim.desk_call(_photo(), 0))


func test_photographer_calls_the_citizen_and_keeps_the_place() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	var place := citizen.place
	watch_signals(sim)
	sim.tick(0.05)
	assert_eq(citizen.phase, CaseFile.Phase.CALLED_PHOTO)
	assert_eq(citizen.desk, 0)
	assert_eq(citizen.place, place)
	assert_eq(citizen.spot, layout.desk_front(PHOTO, 0))
	assert_gt(citizen.walk, 0.0)
	assert_eq(sim.desk_call(_photo(), 0), citizen)
	assert_signal_emitted_with_parameters(sim, "ticket_called", [citizen.ticket])
	assert_eq(state.tickets_called, 0)


func test_reserved_place_stays_free_of_other_citizens() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	var left := state.places_left(GameConfig.HALL_PICKUP)
	sim.tick(0.05)
	assert_true(citizen.is_at_photo())
	assert_eq(citizen.waiting_room(), GameConfig.HALL_PICKUP)
	assert_eq(state.places_left(GameConfig.HALL_PICKUP), left)
	assert_ne(state.free_place(true, GameConfig.HALL_PICKUP), citizen.place)
	assert_eq(state.seated_citizens(GameConfig.HALL_PICKUP), 1)


func test_patience_neither_resets_nor_runs_during_the_photo() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	sim.tick(0.05)
	var waited := citizen.waited
	assert_gte(waited, 12.0)
	assert_eq(Formulas.citizen_patience(citizen), 0.0)
	assert_false(Formulas.is_citizen_waiting(citizen))
	assert_true(_run_until(func() -> bool: return citizen.phase == CaseFile.Phase.PHOTO))
	assert_eq(citizen.waited, waited)
	assert_true(_run_until(func() -> bool: return citizen.phase == CaseFile.Phase.WAITING_DOC))
	assert_eq(citizen.waited, waited)
	assert_gt(Formulas.citizen_patience(citizen), 0.0)


func test_photo_starts_only_after_the_citizen_arrived() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	sim.tick(0.05)
	assert_gt(citizen.walk, 0.1)
	assert_null(_photo().jobs[0])
	assert_true(_run_until(func() -> bool: return _photo().jobs[0] != null))
	assert_eq(citizen.walk, 0.0)
	assert_eq(citizen.phase, CaseFile.Phase.PHOTO)
	assert_eq(_photo().jobs[0].case_file, citizen)
	assert_false(_photo().inbox.has(citizen))


func test_citizen_returns_to_the_same_place_after_the_photo() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	var place := citizen.place
	var seat := citizen.spot
	assert_true(_run_until(func() -> bool: return citizen.phase == CaseFile.Phase.WAITING_DOC and _photo().jobs[0] == null and _photo().outbox.has(citizen)))
	assert_eq(citizen.place, place)
	assert_true(citizen.seated)
	assert_eq(citizen.spot, seat)
	assert_eq(citizen.desk, -1)
	assert_true(citizen.produced)


func test_seat_sync_leaves_citizens_at_the_photo_alone() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	citizen.seated = false
	citizen.place = state.free_place(false, GameConfig.HALL_PICKUP)
	sim.tick(0.05)
	var place := citizen.place
	state.set_upgrade("pickup_seating", state.upgrade_level("pickup_seating") + 5)
	sim.tick(0.05)
	assert_eq(citizen.place, place)
	assert_false(citizen.seated)
	assert_eq(citizen.spot, layout.desk_front(PHOTO, 0))


func test_player_at_the_empty_photo_desk_calls_and_shoots() -> void:
	var citizen := _waiting_citizen()
	state.player.position = layout.desk_work_point(PHOTO, 0)
	sim.tick(0.05)
	assert_eq(citizen.phase, CaseFile.Phase.CALLED_PHOTO)
	assert_true(_run_until(func() -> bool: return _photo().outbox.has(citizen)))
	assert_eq(citizen.phase, CaseFile.Phase.WAITING_DOC)


func test_files_without_citizen_are_photographed_without_a_call() -> void:
	_photo().staff = 1
	var mail := CaseFile.new("general_services")
	mail.route = RouteBuilder.build(mail)
	mail.step = mail.route.find(PHOTO)
	mail.mail = true
	_photo().inbox.append(mail)
	assert_true(_run_until(func() -> bool: return _photo().outbox.has(mail)))
	assert_false(mail.has_citizen())


func test_calls_follow_the_inbox_order() -> void:
	_photo().staff = 1
	var first := _waiting_citizen(3)
	var second := _waiting_citizen(4)
	sim.tick(0.05)
	assert_eq(first.phase, CaseFile.Phase.CALLED_PHOTO)
	assert_eq(second.phase, CaseFile.Phase.WAITING_DOC)


func test_giving_up_at_the_photo_drops_the_file() -> void:
	_photo().staff = 1
	var citizen := _waiting_citizen()
	sim.tick(0.05)
	assert_true(citizen.waits_for_pickup())
	sim.give_up(citizen)
	assert_false(_photo().inbox.has(citizen))
	assert_true(citizen.abandoned)
	assert_false(state.citizens.has(citizen))
	assert_eq(state.station(GameConfig.COUNTER).rejects, 1)


func test_photo_phases_map_to_hall_stages() -> void:
	var citizen := CaseFile.new("general_services")
	citizen.phase = CaseFile.Phase.CALLED_PHOTO
	assert_eq(WorldView.citizen_stage(citizen), WorldView.STAGE_CALLED)
	assert_false(citizen.is_in_hall())
	citizen.phase = CaseFile.Phase.PHOTO
	assert_eq(WorldView.citizen_stage(citizen), WorldView.STAGE_DESK)
	assert_true(citizen.is_at_photo())
	citizen.phase = CaseFile.Phase.WAITING_DOC
	assert_false(citizen.is_at_photo())


func test_photo_desk_is_a_call_station() -> void:
	assert_eq(GameConfig.CALL_STATIONS, [GameConfig.RECEPTION, GameConfig.COUNTER, PHOTO] as Array[String])
	assert_false(GameConfig.is_machine(PHOTO))
	state.unlock_department("tax_services")
	assert_true(GameConfig.is_machine("tax_services/signature"))
	assert_false(state.station("tax_services/signature").calls_citizens())


func test_ticket_machine_falls_slightly_behind_at_the_start() -> void:
	var draws := Formulas.ticket_draw_rate(state) * 60.0
	var arrivals := Formulas.arrivals_per_minute(state)
	assert_lt(draws, arrivals)
	assert_gt(draws, arrivals * 0.75)
	state.set_upgrade("ticket_speed", 10)
	assert_gt(Formulas.ticket_draw_rate(state) * 60.0, arrivals)
