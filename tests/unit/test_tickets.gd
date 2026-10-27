extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions
var layout: WorldLayout
var dept: Department


func before_each() -> void:
	state = GameState.create_new(21)
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
	state.event_cooldown = 1e9
	state.player.position = Vector2(50, 50)
	dept = state.department("general_services")


func _reception() -> Station:
	return state.station(GameConfig.RECEPTION)


func _counter() -> Station:
	return state.station(GameConfig.COUNTER)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds - 0.0001:
		sim.tick(step)
		elapsed += step


func _arrived(citizen: CaseFile) -> CaseFile:
	citizen.walk = 0.0
	return citizen


func _in_line() -> CaseFile:
	return _arrived(sim.spawn_case(dept))


func _with_ticket() -> CaseFile:
	var citizen := _in_line()
	assert_true(sim.draw_ticket(citizen))
	return _arrived(citizen)


func _staff_reception() -> void:
	_reception().staff = 1


func _staff_counter() -> void:
	_counter().staff = 1


func _unlock_all() -> void:
	for dept_id in state.departments:
		state.departments[dept_id].unlocked = true


func _review_average(stars: Array[int]) -> void:
	state.reviews.clear()
	for value in stars:
		state.add_review(value)


func _max_level(upgrade_id: String) -> int:
	return int(GameConfig.upgrade(upgrade_id).max)


func _complaints_raised() -> int:
	return state.visitors.size() + state.complaints + state.complaints_absorbed


func test_arrivals_grow_linearly_with_unlocked_departments() -> void:
	var per_department := GameConfig.MAX_ARRIVALS_PER_MINUTE / GameConfig.DEPARTMENTS.size()
	assert_eq(state.unlocked_count(), 1)
	assert_almost_eq(Formulas.arrivals_per_minute(state), per_department, 0.0001)
	assert_almost_eq(Formulas.arrival_interval(state), 60.0 / per_department, 0.0001)
	state.department("tax_services").unlocked = true
	assert_almost_eq(Formulas.arrivals_per_minute(state), per_department * 2.0, 0.0001)
	_unlock_all()
	assert_almost_eq(Formulas.arrivals_per_minute(state), GameConfig.MAX_ARRIVALS_PER_MINUTE, 0.0001)


func test_reputation_does_not_change_arrivals() -> void:
	var before := Formulas.arrivals_per_minute(state)
	state.reputation = 5000.0
	state.cases_completed = 100000
	assert_eq(Formulas.arrivals_per_minute(state), before)


func test_reviews_scale_arrivals_in_tiers() -> void:
	assert_eq(Formulas.review_arrival_factor(state), 1.0)
	_review_average([5, 5, 5, 5, 3])
	assert_almost_eq(state.average_rating(), 4.6, 0.0001)
	assert_eq(Formulas.review_arrival_factor(state), 1.0)
	_review_average([5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 4, 3, 3, 3, 3])
	assert_lt(state.average_rating(), 4.6)
	assert_eq(Formulas.review_arrival_factor(state), 0.8)
	_review_average([5, 5, 4, 4, 4, 4, 4, 4, 4, 5])
	assert_almost_eq(state.average_rating(), 4.3, 0.0001)
	assert_eq(Formulas.review_arrival_factor(state), 0.8)
	_review_average([4, 4, 4, 4, 5, 5, 4, 4, 4, 4])
	assert_almost_eq(state.average_rating(), 4.2, 0.0001)
	assert_eq(Formulas.review_arrival_factor(state), 0.65)
	_review_average([4, 3])
	assert_almost_eq(state.average_rating(), 3.5, 0.0001)
	assert_eq(Formulas.review_arrival_factor(state), 0.65)
	_review_average([4, 3, 3, 3])
	assert_eq(Formulas.review_arrival_factor(state), 0.4)
	_review_average([1])
	assert_eq(Formulas.review_arrival_factor(state), 0.4)


func test_bad_reviews_slow_down_arrivals() -> void:
	_unlock_all()
	_review_average([1, 1])
	assert_almost_eq(Formulas.arrivals_per_minute(state), GameConfig.MAX_ARRIVALS_PER_MINUTE * 0.4, 0.0001)
	assert_almost_eq(Formulas.arrival_interval(state), 60.0 / (GameConfig.MAX_ARRIVALS_PER_MINUTE / GameConfig.DEPARTMENTS.size() * 0.4), 0.0001)


func test_departments_spawn_at_the_fixed_interval() -> void:
	dept.arrival_timer = 0.0
	var interval := Formulas.arrival_interval(state)
	sim.tick(interval * 0.5)
	assert_eq(state.citizens.size(), 0)
	sim.tick(interval * 0.5 + 0.001)
	assert_eq(state.citizens.size(), 1)
	assert_eq(state.cases_spawned, 1)


func test_due_follow_up_replaces_a_regular_arrival() -> void:
	dept.follow_ups.append(0.5)
	dept.arrival_timer = 0.0
	sim.tick(0.6)
	assert_eq(dept.follow_ups, [0.0] as Array[float])
	assert_true(state.citizens.is_empty())
	sim.tick(Formulas.arrival_interval(state))
	assert_eq(state.citizens.size(), 1)
	assert_true(state.citizens[0].follow_up)
	assert_true(dept.follow_ups.is_empty())


func test_new_citizen_walks_to_the_shortest_line() -> void:
	var citizen := sim.spawn_case(dept)
	assert_eq(citizen.phase, CaseFile.Phase.LINE)
	assert_eq(citizen.machine, 0)
	assert_eq(citizen.line_slot, 0)
	assert_eq(citizen.spot, layout.ticket_line_point(0, 0))
	assert_almost_eq(citizen.walk, layout.door_in().distance_to(citizen.spot) / GameConfig.CITIZEN_SPEED, 0.001)
	assert_true(state.ticket_line.has(citizen))
	assert_true(state.citizens.has(citizen))
	state.set_upgrade("ticket_speed", _max_level("ticket_speed"))
	state.set_upgrade("ticket_machine_2", 1)
	var second := sim.spawn_case(dept)
	assert_eq(second.machine, 1)
	assert_eq(second.line_slot, 0)
	var third := sim.spawn_case(dept)
	assert_eq(third.machine, 0)
	assert_eq(third.line_slot, 1)


func test_customs_cargo_skips_the_ticket_machines() -> void:
	var customs := state.department("customs")
	customs.unlocked = true
	var cargo := sim.create_case(customs)
	assert_false(sim.needs_ticket(cargo))
	var letter := sim.create_mail_case(dept)
	assert_false(sim.needs_ticket(letter))
	assert_true(sim.needs_ticket(sim.create_case(dept)))


func test_full_lines_turn_newcomers_away_angrily() -> void:
	for i in GameConfig.TICKET_LINE_SLOTS:
		assert_not_null(sim.spawn_case(dept))
	state.cases_completed = 0
	var before := _complaints_raised()
	var reputation := state.reputation
	assert_null(sim.spawn_case(dept))
	assert_eq(state.walkouts, 1)
	assert_eq(state.citizens_lost, 1)
	assert_eq(state.ticket_line.size(), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(_complaints_raised(), before + 1)
	assert_true(state.visitors.back().angry)
	assert_lte(state.reputation, reputation)


func test_more_machines_add_twelve_places_each() -> void:
	assert_eq(Formulas.ticket_line_capacity(state), GameConfig.TICKET_LINE_SLOTS)
	state.set_upgrade("ticket_speed", _max_level("ticket_speed"))
	state.set_upgrade("ticket_machine_2", 1)
	assert_eq(Formulas.ticket_line_capacity(state), GameConfig.TICKET_LINE_SLOTS * 2)
	for i in GameConfig.TICKET_LINE_SLOTS * 2:
		assert_not_null(sim.spawn_case(dept))
	assert_eq(state.line_length(0), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(state.line_length(1), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(state.shortest_line(), -1)
	assert_null(sim.spawn_case(dept))


func test_drawing_starts_only_at_the_machine() -> void:
	var citizen := sim.spawn_case(dept)
	assert_false(sim.is_drawing(citizen))
	_run(0.5)
	assert_eq(citizen.draw_progress, 0.0)
	_arrived(citizen)
	assert_true(sim.is_drawing(citizen))
	assert_true(sim.front_at_ticket_machine())
	_run(0.5)
	assert_almost_eq(citizen.draw_progress, 0.5, 0.01)


func test_drawing_takes_the_machine_time() -> void:
	var citizen := _in_line()
	var draw_time := Formulas.ticket_draw_time(state, 0)
	assert_almost_eq(draw_time, 1.0 / GameConfig.TICKET_BASE_RATE, 0.0001)
	_run(draw_time - 0.1)
	assert_eq(citizen.phase, CaseFile.Phase.LINE)
	_run(0.15)
	assert_eq(citizen.phase, CaseFile.Phase.WAITING)
	assert_eq(citizen.ticket, 1)
	assert_eq(state.tickets_drawn, 1)


func test_player_at_the_machine_speeds_up_drawing() -> void:
	var citizen := _in_line()
	state.player.position = layout.ticket_machine_point(0)
	_run(0.4)
	assert_almost_eq(citizen.draw_progress, 0.4 * GameConfig.TICKET_HAND_FACTOR, 0.02)


func test_every_ticket_gets_the_next_number_and_the_line_moves_up() -> void:
	watch_signals(sim)
	var first := _in_line()
	var second := _in_line()
	assert_eq(second.line_slot, 1)
	assert_true(sim.draw_ticket())
	assert_eq(first.ticket, 1)
	assert_eq(second.line_slot, 0)
	assert_eq(second.spot, layout.ticket_line_point(0, 0))
	assert_gt(second.walk, 0.0)
	assert_signal_emitted_with_parameters(sim, "ticket_drawn", [1])
	assert_true(sim.draw_ticket(_arrived(second)))
	assert_eq(second.ticket, 2)
	assert_false(sim.draw_ticket())
	assert_false(sim.draw_ticket(first))


func test_ticket_holders_prefer_seats_then_standing_places() -> void:
	assert_eq(state.seat_capacity(), GameConfig.BASE_SEATS)
	assert_eq(state.standing_capacity(), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS)
	var seated := _with_ticket()
	assert_true(seated.seated)
	assert_eq(seated.place, 0)
	assert_eq(seated.spot, layout.waiting_seat(0))
	for i in GameConfig.BASE_SEATS - 1:
		_with_ticket()
	assert_eq(state.seated_citizens(), GameConfig.BASE_SEATS)
	var standing := _with_ticket()
	assert_false(standing.seated)
	assert_eq(standing.place, 0)
	assert_eq(standing.spot, layout.standing_point(0, GameConfig.BASE_SEATS))
	assert_eq(state.standing_citizens(), 1)


func test_without_a_free_place_the_ticket_holder_leaves() -> void:
	for i in GameConfig.WAITING_PLACES:
		_with_ticket()
	assert_eq(state.seated_citizens() + state.standing_citizens(), GameConfig.WAITING_PLACES)
	var before := _complaints_raised()
	var last := _in_line()
	assert_true(sim.draw_ticket(last))
	assert_false(state.citizens.has(last))
	assert_eq(state.tickets_lapsed, 1)
	assert_eq(_complaints_raised(), before + 1)


func test_line_patience_is_thirty_seconds() -> void:
	state.set_upgrade("ticket_speed", 0)
	var front := _in_line()
	var waiting := _in_line()
	front.draw_progress = -1e9
	assert_eq(Formulas.citizen_patience(waiting), GameConfig.LINE_PATIENCE)
	_run(GameConfig.LINE_PATIENCE - 0.5)
	assert_true(state.citizens.has(waiting))
	assert_almost_eq(Formulas.citizen_time_left(waiting), 0.5, 0.06)
	var before := _complaints_raised()
	_run(1.0)
	assert_false(state.citizens.has(waiting))
	assert_false(state.ticket_line.has(waiting))
	assert_eq(state.tickets_lapsed, 0)
	assert_eq(state.citizens_lost, 2)
	assert_eq(_complaints_raised(), before + 2)


func test_seated_citizens_wait_sixty_seconds_and_standing_twenty() -> void:
	var seated := _with_ticket()
	for i in GameConfig.BASE_SEATS - 1:
		_with_ticket()
	var standing := _with_ticket()
	assert_eq(seated.waited, 0.0)
	assert_eq(Formulas.citizen_patience(seated), GameConfig.SEAT_PATIENCE)
	assert_eq(Formulas.citizen_patience(standing), GameConfig.STAND_PATIENCE)
	_run(GameConfig.STAND_PATIENCE + 0.1)
	assert_false(state.citizens.has(standing))
	assert_true(state.citizens.has(seated))
	_run(GameConfig.SEAT_PATIENCE - GameConfig.STAND_PATIENCE)
	assert_false(state.citizens.has(seated))
	assert_eq(state.tickets_lapsed, GameConfig.BASE_SEATS + 1)


func test_drawing_a_ticket_resets_the_timer() -> void:
	var citizen := _in_line()
	citizen.waited = 25.0
	assert_true(sim.draw_ticket(citizen))
	assert_eq(citizen.waited, 0.0)
	assert_almost_eq(Formulas.citizen_time_left(citizen), GameConfig.SEAT_PATIENCE, 0.0001)


func test_walking_to_a_place_pauses_the_seat_timer() -> void:
	var citizen := _in_line()
	assert_true(sim.draw_ticket(citizen))
	assert_gt(citizen.walk, 0.0)
	assert_false(Formulas.is_citizen_waiting(citizen))
	sim.tick(0.05)
	assert_eq(citizen.waited, 0.0)


func test_mayor_speech_freezes_every_timer() -> void:
	var citizen := _with_ticket()
	state.boosts["mayor_speech"] = 100.0
	_run(GameConfig.SEAT_PATIENCE + 5.0)
	assert_true(state.citizens.has(citizen))
	assert_eq(citizen.waited, 0.0)


func test_unstaffed_reception_does_not_call_numbers() -> void:
	var citizen := _with_ticket()
	assert_false(sim.call_citizens())
	assert_eq(citizen.phase, CaseFile.Phase.WAITING)


func test_player_at_an_empty_reception_desk_calls_numbers() -> void:
	var citizen := _with_ticket()
	state.player.position = layout.desk_work_point(GameConfig.RECEPTION, 0)
	assert_true(sim.call_citizens())
	assert_eq(citizen.phase, CaseFile.Phase.CALLED)
	assert_eq(citizen.desk, 0)


func test_staffed_reception_calls_the_lowest_number() -> void:
	watch_signals(sim)
	var first := _with_ticket()
	var second := _with_ticket()
	_staff_reception()
	assert_true(sim.call_citizens())
	assert_eq(first.phase, CaseFile.Phase.CALLED)
	assert_eq(second.phase, CaseFile.Phase.WAITING)
	assert_eq(first.spot, layout.desk_front(GameConfig.RECEPTION, 0))
	assert_eq(sim.desk_call(_reception(), 0), first)
	assert_eq(state.tickets_called, 1)
	assert_signal_emitted_with_parameters(sim, "ticket_called", [first.ticket])
	assert_false(sim.call_citizens())
	assert_eq(first.place, -1)
	assert_eq(state.seated_citizens(), 1)


func test_each_reception_desk_calls_its_own_number() -> void:
	_with_ticket()
	_with_ticket()
	_with_ticket()
	var reception := _reception()
	reception.add_desk()
	reception.staff = 2
	assert_true(sim.call_citizens())
	assert_eq(reception.inbox.size(), 2)
	assert_eq(sim.desk_call(reception, 0).ticket, 1)
	assert_eq(sim.desk_call(reception, 1).ticket, 2)


func test_sleeping_clerk_does_not_call() -> void:
	_with_ticket()
	_staff_reception()
	_reception().moods[0].state = DeskMood.ASLEEP
	assert_false(sim.call_citizens())


func test_called_citizen_waits_twenty_seconds_at_the_desk() -> void:
	var citizen := _with_ticket()
	_staff_reception()
	sim.call_citizens()
	assert_false(Formulas.is_citizen_waiting(citizen))
	_arrived(citizen)
	_reception().staff = 0
	assert_eq(Formulas.citizen_patience(citizen), GameConfig.DESK_PATIENCE)
	_run(GameConfig.DESK_PATIENCE - 0.5)
	assert_true(state.citizens.has(citizen))
	_run(1.0)
	assert_false(state.citizens.has(citizen))
	assert_false(_reception().inbox.has(citizen))
	assert_eq(state.tickets_lapsed, 1)


func test_processing_starts_once_the_citizen_reaches_the_desk() -> void:
	var citizen := _with_ticket()
	_staff_reception()
	sim.call_citizens()
	assert_false(sim.start_job(_reception(), 0))
	_arrived(citizen)
	assert_true(sim.start_job(_reception(), 0))
	assert_eq(citizen.phase, CaseFile.Phase.SERVED)
	assert_eq(Formulas.citizen_patience(citizen), 0.0)
	assert_true(_reception().outbox.is_empty())


func test_file_reaches_the_tray_only_after_processing() -> void:
	var citizen := _with_ticket()
	_staff_reception()
	sim.call_citizens()
	_arrived(citizen)
	_run(0.1)
	assert_eq(citizen.phase, CaseFile.Phase.SERVED)
	assert_true(_reception().outbox.is_empty())
	var job := _reception().jobs[0]
	job.progress = job.required
	assert_true(sim.finish_job(_reception(), 0))
	assert_true(_reception().outbox.has(citizen))
	assert_eq(citizen.phase, CaseFile.Phase.WAITING_DOC)
	assert_eq(citizen.waited, 0.0)
	assert_eq(citizen.spot, layout.waiting_seat(citizen.place, GameConfig.HALL_PICKUP))
	assert_eq(citizen.waiting_room(), GameConfig.HALL_PICKUP)
	assert_eq(state.seated_citizens(GameConfig.HALL_PICKUP), 1)
	assert_eq(state.seated_citizens(), 0)
	assert_eq(citizen.desk, -1)


func _served() -> CaseFile:
	var citizen := _with_ticket()
	_staff_reception()
	sim.call_citizens()
	_arrived(citizen)
	assert_true(sim.start_job(_reception(), 0))
	var job := _reception().jobs[0]
	job.progress = job.required
	assert_true(sim.finish_job(_reception(), 0))
	_reception().staff = 0
	return _arrived(citizen)


func _at_counter(citizen: CaseFile) -> void:
	_reception().outbox.erase(citizen)
	citizen.step = citizen.route.find(GameConfig.COUNTER)
	_counter().inbox.append(citizen)


func test_document_waiters_give_up_and_abandon_their_file() -> void:
	var citizen := _served()
	assert_true(_reception().outbox.has(citizen))
	_run(GameConfig.SEAT_PATIENCE + 0.1)
	assert_false(state.citizens.has(citizen))
	assert_true(citizen.abandoned)
	assert_false(_reception().outbox.has(citizen))


func test_abandoned_files_are_dropped_on_delivery_and_after_work() -> void:
	var file := sim.create_case(dept)
	file.abandoned = true
	var review := state.station("general_services/review")
	sim.deliver(file, review, ProductionStats.BY_PLAYER)
	assert_false(review.inbox.has(file))
	review.staff = 1
	review.jobs[0] = StationJob.new(file, 0.01)
	review.jobs[0].progress = 1.0
	assert_true(sim.finish_job(review, 0))
	assert_null(review.jobs[0])
	assert_true(review.outbox.is_empty())


func test_counter_calls_the_citizen_whose_document_is_ready() -> void:
	var citizen := _served()
	_at_counter(citizen)
	_staff_counter()
	assert_true(sim.call_citizens())
	assert_eq(citizen.phase, CaseFile.Phase.CALLED_DOC)
	assert_eq(citizen.desk, 0)
	assert_eq(citizen.place, -1)
	assert_eq(citizen.spot, layout.desk_front(GameConfig.COUNTER, 0))
	assert_eq(sim.desk_call(_counter(), 0), citizen)
	assert_false(sim.start_job(_counter(), 0))
	_arrived(citizen)
	assert_true(sim.start_job(_counter(), 0))
	assert_eq(citizen.phase, CaseFile.Phase.COLLECTING)


func test_collecting_the_document_sends_the_citizen_home() -> void:
	watch_signals(sim)
	var citizen := _served()
	_at_counter(citizen)
	_staff_counter()
	sim.call_citizens()
	_arrived(citizen)
	sim.start_job(_counter(), 0)
	var job := _counter().jobs[0]
	job.progress = job.required
	assert_true(sim.finish_job(_counter(), 0))
	assert_false(state.citizens.has(citizen))
	assert_eq(citizen.phase, CaseFile.Phase.NONE)
	assert_eq(state.cases_completed, 1)
	assert_signal_emitted(sim, "case_completed")


func test_citizen_at_the_counter_waits_twenty_seconds() -> void:
	var citizen := _served()
	_at_counter(citizen)
	_staff_counter()
	sim.call_citizens()
	_arrived(citizen)
	_counter().staff = 0
	_run(GameConfig.DESK_PATIENCE + 0.1)
	assert_false(state.citizens.has(citizen))
	assert_false(_counter().inbox.has(citizen))


func test_counter_handles_files_without_citizen_directly() -> void:
	var companion := sim.create_case(dept)
	companion.companion = true
	companion.step = companion.route.find(GameConfig.COUNTER)
	_counter().inbox.append(companion)
	assert_true(sim.start_job(_counter(), 0))
	assert_eq(_counter().jobs[0].case_file, companion)


func test_counter_does_not_take_files_whose_citizen_waits() -> void:
	var citizen := _served()
	_at_counter(citizen)
	assert_false(sim.start_job(_counter(), 0))


func test_rejected_or_incomplete_applications_dismiss_the_citizen() -> void:
	var citizen := _served()
	sim.dismiss_citizen(citizen)
	assert_false(state.citizens.has(citizen))
	assert_eq(citizen.place, -1)
	var other := _served()
	sim.shred_case(other)
	assert_false(state.citizens.has(other))


func test_ticket_machines_follow_the_upgrade_chain() -> void:
	assert_eq(Formulas.ticket_machines(state), 1)
	assert_eq(Progression.upgrade_block_reason(state, "ticket_machine_2"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "ticket_speed_2"), "requires")
	state.set_upgrade("ticket_speed", GameConfig.TICKET_MACHINE_LEVELS - 1)
	assert_eq(Progression.upgrade_block_reason(state, "ticket_machine_2"), "requires")
	state.set_upgrade("ticket_speed", GameConfig.TICKET_MACHINE_LEVELS)
	state.money = 1e15
	assert_eq(Progression.upgrade_block_reason(state, "ticket_machine_2"), "")
	assert_true(actions.buy_upgrade("ticket_machine_2"))
	assert_eq(Formulas.ticket_machines(state), 2)
	assert_eq(Progression.upgrade_block_reason(state, "ticket_machine_3"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "ticket_speed_2"), "")
	state.set_upgrade("ticket_speed_2", GameConfig.TICKET_MACHINE_LEVELS)
	assert_true(actions.buy_upgrade("ticket_machine_3"))
	assert_eq(Formulas.ticket_machines(state), GameConfig.MAX_TICKET_MACHINES)
	assert_eq(Progression.upgrade_block_reason(state, "ticket_machine_3"), "max")


func test_fully_upgraded_machine_serves_one_citizen_per_second() -> void:
	for upgrade_id in GameConfig.TICKET_SPEED_TRACKS:
		assert_eq(_max_level(upgrade_id), 100)
		assert_almost_eq(Formulas.track_value(upgrade_id, 0), GameConfig.TICKET_BASE_RATE, 0.0001)
		assert_almost_eq(Formulas.track_value(upgrade_id, 100), 1.0, 0.0001)
	state.set_upgrade("ticket_speed", 100)
	assert_almost_eq(Formulas.ticket_draw_time(state, 0), 1.0, 0.0001)
	assert_eq(Formulas.ticket_draw_time(state, 1), INF)
	assert_eq(Formulas.ticket_machine_rate(state, -1), 0.0)
	state.set_upgrade("ticket_machine_2", 1)
	state.set_upgrade("ticket_speed_2", 100)
	state.set_upgrade("ticket_machine_3", 1)
	state.set_upgrade("ticket_speed_3", 100)
	assert_almost_eq(Formulas.ticket_draw_rate(state) * 60.0, GameConfig.MAX_ARRIVALS_PER_MINUTE, 0.0001)


func test_machines_draw_in_parallel() -> void:
	state.set_upgrade("ticket_speed", 100)
	state.set_upgrade("ticket_machine_2", 1)
	var first := _in_line()
	var second := _in_line()
	assert_ne(first.machine, second.machine)
	_run(1.0 / GameConfig.TICKET_BASE_RATE + 0.1)
	assert_eq(first.phase, CaseFile.Phase.WAITING)
	assert_eq(second.phase, CaseFile.Phase.WAITING)


func test_seats_replace_standing_places_step_by_step() -> void:
	assert_eq(_max_level("seating"), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS)
	state.set_upgrade("seating", 10)
	assert_eq(state.seat_capacity(), GameConfig.BASE_SEATS + 10)
	assert_eq(state.standing_capacity(), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS - 10)
	state.set_upgrade("seating", _max_level("seating"))
	assert_eq(state.seat_capacity(), GameConfig.WAITING_PLACES)
	assert_eq(state.standing_capacity(), 0)
	assert_eq(state.free_place(false), -1)


func test_citizens_are_not_saved() -> void:
	_in_line()
	_with_ticket()
	state.tickets_drawn = 12
	state.tickets_called = 9
	state.tickets_lapsed = 2
	var data := state.to_dict()
	assert_false(data.has("ticket_line"))
	assert_false(data.has("ticket_waiting"))
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_true(loaded.ticket_line.is_empty())
	assert_true(loaded.citizens.is_empty())
	assert_eq(loaded.tickets_drawn, 12)
	assert_eq(loaded.tickets_called, 9)
	assert_eq(loaded.tickets_lapsed, 2)


func test_loading_ignores_old_ticket_queues_and_clamps_counters() -> void:
	var data := state.to_dict()
	var valid := sim.create_case(dept).to_dict()
	data.ticket_line = [valid, "junk"]
	data.ticket_waiting = [valid]
	data.upgrades = {"ticket_speed": 9999, "ticket_machines": 3, "ticket_line": 4, "standing_places": 5, "comfortable_lobby": 2, "online_portal": 1, "waiting_places": 3}
	data.tickets_drawn = 5
	data.tickets_called = 50
	data.tickets_lapsed = 9
	var loaded := GameState.from_dict(data)
	assert_true(loaded.ticket_line.is_empty())
	assert_true(loaded.citizens.is_empty())
	assert_eq(loaded.upgrade_level("ticket_speed"), _max_level("ticket_speed"))
	assert_eq(loaded.upgrades.size(), 1)
	assert_eq(loaded.tickets_called, 5)
	assert_eq(loaded.tickets_lapsed, 5)


func test_loaded_files_in_the_pipeline_finish_without_citizen() -> void:
	var citizen := _served()
	var data := state.to_dict()
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(data)))
	var file: CaseFile = loaded.station(GameConfig.RECEPTION).outbox[0]
	assert_eq(file.dept_id, citizen.dept_id)
	assert_false(file.has_citizen())


func test_throughput_report_offers_the_next_ticket_step() -> void:
	var machine := ThroughputReport.ticket_machine_area(state)
	assert_almost_eq(float(machine.capacity), Formulas.ticket_draw_rate(state), 0.0001)
	var entries: Array[String] = []
	for suggestion: Dictionary in machine.upgrades:
		assert_gt(float(suggestion.gain), 0.0)
		entries.append(str(suggestion.entry))
	assert_eq(entries, ["%s:ticket_speed" % UpgradeCatalog.TRACK] as Array[String])
	state.set_upgrade("ticket_speed", 100)
	entries.clear()
	for suggestion: Dictionary in ThroughputReport.ticket_machine_area(state).upgrades:
		entries.append(str(suggestion.entry))
	assert_eq(entries, ["%s:ticket_machine_2" % UpgradeCatalog.TRACK] as Array[String])
	for upgrade_id in ["ticket_machine_2", "ticket_speed_2", "ticket_machine_3", "ticket_speed_3"]:
		state.set_upgrade(upgrade_id, _max_level(upgrade_id))
	assert_true(ThroughputReport.ticket_machine_area(state).upgrades.is_empty())


func test_hall_areas_report_seats_and_standing_places() -> void:
	_with_ticket()
	var seating := ThroughputReport.seating_area(state)
	assert_eq(float(seating.demand), 1.0)
	assert_eq(float(seating.capacity), float(GameConfig.BASE_SEATS))
	var standing := ThroughputReport.standing_area(state)
	assert_eq(float(standing.demand), 0.0)
	assert_eq(float(standing.capacity), float(GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS))
	assert_true(standing.upgrades.is_empty())


func test_guidance_points_to_the_busiest_line() -> void:
	state.player.position = layout.ticket_machine_point(0)
	for i in GameConfig.TICKET_RUSH - 1:
		sim.spawn_case(dept)
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.TICKET)
	sim.spawn_case(dept)
	var task := Guidance.next_task(state)
	assert_eq(task.get("action", ""), Guidance.TICKET)
	assert_eq(task.get("point"), layout.ticket_machine_point(0))


func test_waiting_count_includes_citizens_before_the_reception() -> void:
	_served()
	_in_line()
	_with_ticket()
	assert_eq(Formulas.waiting_count(state, dept), 2)


func test_hall_layout_points_are_inside_the_hall() -> void:
	assert_true(layout.hall.encloses(layout.ticket_area))
	for room in GameConfig.WAITING_ROOMS:
		assert_true(layout.hall.encloses(layout.waiting_room(room)), room)
		assert_true(layout.waiting_room(room).encloses(layout.place_area(room)), room)
	for machine in GameConfig.MAX_TICKET_MACHINES:
		assert_true(layout.ticket_area.has_point(layout.ticket_machine_point(machine)), "machine %d" % machine)
		for slot in GameConfig.TICKET_LINE_SLOTS:
			assert_true(layout.ticket_area.has_point(layout.ticket_line_point(machine, slot)), "slot %d/%d" % [machine, slot])
	assert_eq(layout.ticket_machine_point(), layout.ticket_machine_point(0))
	assert_eq(layout.ticket_machine_point(9), layout.ticket_machine_point(GameConfig.MAX_TICKET_MACHINES - 1))
	assert_eq(layout.ticket_line_point(0, 99), layout.ticket_line_point(0, GameConfig.TICKET_LINE_SLOTS - 1))
	var points := {}
	for slot in GameConfig.TICKET_LINE_SLOTS:
		points[layout.ticket_line_point(0, slot)] = true
	assert_eq(points.size(), GameConfig.TICKET_LINE_SLOTS)
	for room in GameConfig.WAITING_ROOMS:
		for index in GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS:
			assert_true(layout.place_area(room).has_point(layout.standing_point(index, GameConfig.BASE_SEATS, room)), "standing %d" % index)
		for index in GameConfig.WAITING_PLACES:
			assert_true(layout.place_area(room).has_point(layout.waiting_seat(index, room)), "seat %d" % index)
	assert_eq(layout.desk_front(GameConfig.RECEPTION, 0), layout.desk_position(GameConfig.RECEPTION, 0) + WorldLayout.DESK_FRONT)
