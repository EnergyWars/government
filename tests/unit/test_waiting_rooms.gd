extends GutTest

var state: GameState
var sim: Simulation
var layout: WorldLayout
var dept: Department


func before_each() -> void:
	state = GameState.create_new(21)
	sim = Simulation.new(state)
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


func _with_ticket() -> CaseFile:
	var citizen := sim.spawn_case(dept)
	citizen.walk = 0.0
	assert_true(sim.draw_ticket(citizen))
	citizen.walk = 0.0
	return citizen


func _served() -> CaseFile:
	var citizen := _with_ticket()
	_reception().staff = 1
	sim.call_citizens()
	citizen.walk = 0.0
	assert_true(sim.start_job(_reception(), 0))
	var job := _reception().jobs[0]
	job.progress = job.required
	assert_true(sim.finish_job(_reception(), 0))
	_reception().staff = 0
	citizen.walk = 0.0
	return citizen


func _fill_pickup() -> void:
	for index in GameConfig.WAITING_PLACES:
		var seated := index < GameConfig.BASE_SEATS
		_waiting_for_pickup(index if seated else index - GameConfig.BASE_SEATS, seated)


func _waiting_for_pickup(place: int, seated: bool) -> CaseFile:
	var citizen := sim.create_case(dept)
	citizen.phase = CaseFile.Phase.WAITING_DOC
	citizen.place = place
	citizen.seated = seated
	state.citizens.append(citizen)
	return citizen


func test_each_waiting_room_has_its_own_seating_track() -> void:
	assert_eq(GameConfig.WAITING_ROOMS, [GameConfig.HALL_INTAKE, GameConfig.HALL_PICKUP] as Array[String])
	for room in GameConfig.WAITING_ROOMS:
		var track_id := str(GameConfig.SEATING_TRACKS[room])
		assert_eq(int(GameConfig.upgrade(track_id).max), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS, track_id)
		assert_eq(GameConfig.spot_room(str(GameConfig.upgrade(track_id).spot)), GameConfig.ROOM_HALL, track_id)
		assert_eq(state.seat_capacity(room), GameConfig.BASE_SEATS, room)
		assert_eq(state.standing_capacity(room), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS, room)
	state.set_upgrade("pickup_seating", 7)
	assert_eq(state.seat_capacity(GameConfig.HALL_PICKUP), GameConfig.BASE_SEATS + 7)
	assert_eq(state.seat_capacity(GameConfig.HALL_INTAKE), GameConfig.BASE_SEATS)
	assert_eq(state.standing_capacity(GameConfig.HALL_PICKUP), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS - 7)


func test_case_file_knows_its_waiting_room() -> void:
	var citizen := CaseFile.new("general_services")
	for phase in [CaseFile.Phase.NONE, CaseFile.Phase.LINE, CaseFile.Phase.WAITING, CaseFile.Phase.CALLED, CaseFile.Phase.SERVED, CaseFile.Phase.CALLED_DOC, CaseFile.Phase.COLLECTING]:
		citizen.phase = phase
		assert_eq(citizen.waiting_room(), GameConfig.HALL_INTAKE, str(phase))
	citizen.phase = CaseFile.Phase.WAITING_DOC
	assert_eq(citizen.waiting_room(), GameConfig.HALL_PICKUP)
	assert_true(citizen.waits_for_pickup())
	citizen.phase = CaseFile.Phase.CALLED_DOC
	assert_true(citizen.waits_for_pickup())
	citizen.phase = CaseFile.Phase.WAITING
	assert_false(citizen.waits_for_pickup())


func test_ticket_holders_sit_in_the_intake_room() -> void:
	var citizen := _with_ticket()
	assert_eq(citizen.waiting_room(), GameConfig.HALL_INTAKE)
	assert_eq(citizen.spot, layout.waiting_seat(0, GameConfig.HALL_INTAKE))
	assert_true(layout.place_area(GameConfig.HALL_INTAKE).has_point(citizen.spot))
	assert_eq(state.seated_citizens(GameConfig.HALL_PICKUP), 0)


func test_standing_places_follow_the_chairs_in_one_column() -> void:
	for i in GameConfig.BASE_SEATS:
		_with_ticket()
	var standing := _with_ticket()
	assert_false(standing.seated)
	assert_eq(standing.spot, layout.waiting_seat(GameConfig.BASE_SEATS))
	assert_eq(sim.place_point(standing), layout.standing_point(0, GameConfig.BASE_SEATS))


func test_calling_frees_the_intake_place_and_service_moves_to_pickup() -> void:
	var citizen := _with_ticket()
	_reception().staff = 1
	assert_true(sim.call_citizens())
	assert_eq(citizen.place, -1)
	assert_eq(state.places_left(GameConfig.HALL_INTAKE), GameConfig.WAITING_PLACES)
	citizen.walk = 0.0
	assert_true(sim.start_job(_reception(), 0))
	var job := _reception().jobs[0]
	job.progress = job.required
	assert_true(sim.finish_job(_reception(), 0))
	assert_eq(citizen.phase, CaseFile.Phase.WAITING_DOC)
	assert_true(layout.place_area(GameConfig.HALL_PICKUP).has_point(citizen.spot))
	assert_eq(state.places_left(GameConfig.HALL_PICKUP), GameConfig.WAITING_PLACES - 1)


func test_reception_stops_calling_while_the_pickup_room_is_full() -> void:
	_fill_pickup()
	var citizen := _with_ticket()
	_reception().staff = 1
	assert_eq(sim.pickup_space(), 0)
	assert_false(sim.call_citizens())
	assert_eq(citizen.phase, CaseFile.Phase.WAITING)
	state.citizens.erase(state.citizens[0])
	assert_eq(sim.pickup_space(), 1)
	assert_true(sim.call_citizens())
	assert_eq(sim.pickup_space(), 0)


func test_called_citizen_is_redirected_when_the_desk_clerk_leaves() -> void:
	var reception := _reception()
	reception.add_desk()
	reception.staff = 2
	var citizen := _with_ticket()
	assert_true(sim.call_citizens())
	var first := citizen.desk
	reception.moods[first].rest(DeskMood.COFFEE)
	assert_true(sim.call_citizens())
	assert_ne(citizen.desk, first)
	assert_eq(citizen.phase, CaseFile.Phase.CALLED)
	assert_gt(citizen.walk, 0.0)


func test_called_citizen_stays_when_no_other_desk_is_free() -> void:
	var reception := _reception()
	reception.staff = 1
	var citizen := _with_ticket()
	assert_true(sim.call_citizens())
	reception.moods[0].rest(DeskMood.COFFEE)
	assert_false(sim.call_citizens())
	assert_eq(citizen.desk, 0)


func test_next_citizen_is_called_in_the_same_tick_a_job_finishes() -> void:
	var reception := _reception()
	reception.staff = 1
	var first := _with_ticket()
	var second := _with_ticket()
	assert_true(sim.call_citizens())
	first.walk = 0.0
	assert_true(sim.start_job(reception, 0))
	reception.jobs[0].progress = reception.jobs[0].required
	sim._work_stations(0.0)
	assert_eq(second.phase, CaseFile.Phase.CALLED)
	assert_eq(second.desk, 0)


func test_served_citizen_without_pickup_place_storms_off() -> void:
	watch_signals(sim)
	var citizen := _with_ticket()
	_reception().staff = 1
	sim.call_citizens()
	citizen.walk = 0.0
	assert_true(sim.start_job(_reception(), 0))
	_fill_pickup()
	assert_eq(state.free_place(false, GameConfig.HALL_PICKUP), -1)
	var job := _reception().jobs[0]
	job.progress = job.required
	assert_true(sim.finish_job(_reception(), 0))
	assert_false(state.citizens.has(citizen))
	assert_true(citizen.abandoned)
	assert_false(_reception().outbox.has(citizen))
	assert_eq(_counter().rejects, 1)
	assert_signal_emitted(sim, "citizen_raged")


func test_more_seats_move_standing_citizens_onto_chairs() -> void:
	sim.tick(0.01)
	for i in GameConfig.BASE_SEATS + 2:
		_with_ticket()
	var first_standing := state.citizens[GameConfig.BASE_SEATS]
	var second_standing := state.citizens[GameConfig.BASE_SEATS + 1]
	assert_false(first_standing.seated)
	state.set_upgrade("seating", 1)
	sim.tick(0.01)
	assert_true(first_standing.seated)
	assert_eq(first_standing.place, GameConfig.BASE_SEATS)
	assert_false(second_standing.seated)
	assert_eq(second_standing.spot, layout.standing_point(second_standing.place, GameConfig.BASE_SEATS + 1))
	assert_eq(state.standing_citizens(), 1)


func test_patient_end_in_the_intake_room_piles_a_reception_reject() -> void:
	watch_signals(sim)
	var citizen := _with_ticket()
	var point := citizen.spot
	citizen.waited = GameConfig.SEAT_PATIENCE
	sim.tick(0.05)
	assert_false(state.citizens.has(citizen))
	assert_true(citizen.raged)
	assert_eq(_reception().rejects, 1)
	assert_eq(_counter().rejects, 0)
	assert_eq(state.citizens_lost, 1)
	assert_signal_not_emitted(sim, "citizen_left")
	assert_signal_emitted(sim, "citizen_raged")
	var params: Array = get_signal_parameters(sim, "citizen_raged")
	assert_eq(params[0], "general_services")
	assert_eq(params[1], point)
	assert_between(int(params[2]), 0, GameConfig.RAGE_LINES - 1)
	assert_eq(state.visitors.size(), 1)
	var visitor := state.visitors[0]
	assert_true(visitor.angry)
	assert_true(visitor.files_complaint)
	assert_eq(visitor.position, point)
	assert_gt(visitor.rage_timer, 0.0)


func test_patient_end_in_the_pickup_room_piles_a_counter_reject() -> void:
	var citizen := _served()
	citizen.waited = GameConfig.SEAT_PATIENCE
	sim.tick(0.05)
	assert_false(state.citizens.has(citizen))
	assert_true(citizen.abandoned)
	assert_eq(_counter().rejects, 1)
	assert_eq(_reception().rejects, 0)


func test_patient_end_at_the_counter_desk_piles_a_counter_reject() -> void:
	var citizen := _served()
	_reception().outbox.erase(citizen)
	citizen.step = citizen.route.find(GameConfig.COUNTER)
	_counter().inbox.append(citizen)
	_counter().staff = 1
	assert_true(sim.call_citizens())
	citizen.walk = 0.0
	_counter().staff = 0
	citizen.waited = GameConfig.DESK_PATIENCE
	sim.tick(0.05)
	assert_false(_counter().inbox.has(citizen))
	assert_eq(_counter().rejects, 1)


func test_full_reject_pile_drops_further_rejects() -> void:
	_reception().rejects = GameConfig.REJECT_CAPACITY
	var citizen := _with_ticket()
	citizen.waited = GameConfig.SEAT_PATIENCE
	sim.tick(0.05)
	assert_false(state.citizens.has(citizen))
	assert_eq(_reception().rejects, GameConfig.REJECT_CAPACITY)


func test_raging_citizen_without_a_free_clerk_slot_still_complains() -> void:
	for slot in GameConfig.VISITOR_SLOTS:
		sim.spawn_visitor(false, false)
	var before := state.visitors.size()
	var complaints := state.complaints + state.complaints_absorbed
	var citizen := _with_ticket()
	citizen.waited = GameConfig.SEAT_PATIENCE
	sim.tick(0.05)
	assert_eq(state.visitors.size(), before)
	assert_eq(state.complaints + state.complaints_absorbed, complaints + 1)
	assert_eq(_reception().rejects, 1)


func test_raging_visitor_stands_still_before_walking_to_the_complaint_office() -> void:
	var visitor := sim.spawn_visitor(true, true, Vector2(500, 500), GameConfig.RAGE_SECONDS)
	assert_eq(visitor.position, Vector2(500, 500))
	sim.tick(GameConfig.RAGE_SECONDS * 0.5)
	assert_eq(visitor.position, Vector2(500, 500))
	assert_almost_eq(visitor.rage_timer, GameConfig.RAGE_SECONDS * 0.5, 0.0001)
	sim.tick(GameConfig.RAGE_SECONDS)
	assert_eq(visitor.rage_timer, 0.0)
	var before := visitor.position.distance_to(layout.visitor_spot(visitor.slot))
	sim.tick(0.5)
	assert_lt(visitor.position.distance_to(layout.visitor_spot(visitor.slot)), before)


func test_visitors_without_origin_still_enter_through_the_door() -> void:
	var visitor := sim.spawn_visitor(false, true)
	assert_eq(visitor.position, layout.door_in())
	assert_eq(visitor.rage_timer, 0.0)


func test_reception_and_counter_have_reject_piles() -> void:
	assert_true(_reception().has_reject_pile())
	assert_true(_counter().has_reject_pile())
	_reception().rejects = 3
	var data := _reception().to_dict()
	assert_eq(Station.from_dict(data).rejects, 3)
	assert_true(Formulas.full_boxes(state, dept).filter(func(box: Dictionary) -> bool: return box.side == "rejects").is_empty())
	_reception().rejects = GameConfig.REJECT_CAPACITY
	assert_true(Formulas.full_boxes(state, dept).filter(func(box: Dictionary) -> bool: return box.side == "rejects").is_empty())
	assert_gt(Formulas.reject_trip_time(state), 0.0)


func test_reject_runners_and_player_clear_hall_reject_piles() -> void:
	_counter().rejects = 2
	state.player.position = layout.reject_point(GameConfig.COUNTER)
	assert_true(sim.move_complaints())
	assert_eq(state.player.rejects, 1)
	assert_eq(_counter().rejects, 1)
	var runner := state.add_runner(Runner.REJECT)
	runner.position = layout.shredder_point()
	assert_eq(sim.reject_target(runner, Formulas.runner_load(state, runner)), GameConfig.COUNTER)


func test_hall_report_lists_both_waiting_rooms() -> void:
	_served()
	_with_ticket()
	var pickup := ThroughputReport.seating_area(state, GameConfig.HALL_PICKUP)
	assert_eq(pickup.area, ThroughputReport.PICKUP_SEATING)
	assert_eq(float(pickup.demand), 1.0)
	assert_eq(float(pickup.capacity), float(GameConfig.BASE_SEATS))
	assert_eq(pickup.upgrades[0].entry, "track:pickup_seating")
	var standing := ThroughputReport.standing_area(state, GameConfig.HALL_PICKUP)
	assert_eq(standing.area, ThroughputReport.PICKUP_WAITING)
	assert_eq(float(standing.capacity), float(GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS))
	assert_eq(float(ThroughputReport.seating_area(state).demand), 1.0)
	var kinds: Array[String] = []
	for entry in ThroughputReport.support_areas(state):
		kinds.append(str(entry.area))
	for kind in [ThroughputReport.SEATING, ThroughputReport.WAITING, ThroughputReport.PICKUP_SEATING, ThroughputReport.PICKUP_WAITING]:
		assert_true(kinds.has(kind), kind)


func test_seating_beyond_the_new_limit_moves_to_the_pickup_room() -> void:
	var limit := int(GameConfig.upgrade("seating").max)
	assert_eq_deep(SaveMigration.split_seating({"seating": 10}), {"seating": 10})
	assert_eq_deep(SaveMigration.split_seating({"seating": limit + 7}), {"seating": limit, "pickup_seating": 7})
	assert_eq_deep(SaveMigration.split_seating({"seating": limit + 3, "pickup_seating": 5}), {"seating": limit, "pickup_seating": 5})
	assert_eq_deep(SaveMigration.split_seating({"seating": limit * 3}), {"seating": limit, "pickup_seating": limit})
	assert_eq_deep(SaveMigration.split_seating({}), {})
	var original := {"seating": limit + 1}
	SaveMigration.split_seating(original)
	assert_eq(int(original.seating), limit + 1)
	var data := state.to_dict()
	data.upgrades = {"seating": limit + 12}
	var restored := GameState.from_dict(data)
	assert_eq(restored.upgrade_level("seating"), limit)
	assert_eq(restored.upgrade_level("pickup_seating"), 12)


func test_waiting_rooms_sit_inside_the_hall_side_by_side() -> void:
	var intake := layout.waiting_room(GameConfig.HALL_INTAKE)
	var pickup := layout.waiting_room(GameConfig.HALL_PICKUP)
	assert_true(layout.hall.encloses(intake))
	assert_true(layout.hall.encloses(pickup))
	assert_false(intake.intersects(pickup))
	assert_lt(intake.end.x, pickup.position.x)
	assert_gt(intake.position.x, layout.hall.position.x)
	assert_lt(pickup.end.x, layout.hall.end.x)
	assert_gt(intake.position.y, layout.hall.position.y)
	assert_lt(intake.end.y, layout.hall.end.y)
	assert_true(intake.encloses(layout.area(GameConfig.RECEPTION)))
	assert_true(pickup.encloses(layout.area(GameConfig.COUNTER)))
	assert_gt(layout.place_area(GameConfig.HALL_INTAKE).get_center().x, intake.get_center().x)
	assert_lt(layout.place_area(GameConfig.HALL_PICKUP).get_center().x, pickup.get_center().x)
	assert_eq(layout.waiting_room("unknown"), Rect2())
	assert_eq(layout.place_area("unknown"), Rect2())


func test_every_desk_gets_its_own_office() -> void:
	for key in [GameConfig.RECEPTION, GameConfig.COUNTER]:
		assert_true(WorldLayout.has_offices(key))
		var area := layout.area(key)
		var previous := Rect2()
		for index in WorldLayout.OFFICE_COUNT:
			var office := layout.office_rect(key, index)
			assert_true(area.encloses(office), "%s %d" % [key, index])
			assert_true(office.has_point(layout.desk_position(key, index)), "%s %d" % [key, index])
			assert_true(office.has_point(layout.desk_front(key, index)), "%s %d" % [key, index])
			assert_true(office.has_point(layout.desk_work_point(key, index)), "%s %d" % [key, index])
			if index > 0:
				assert_false(office.intersects(previous.grow(-1.0)), "%s %d" % [key, index])
			previous = office
		assert_eq(layout.office_rect(key, 99), layout.office_rect(key, WorldLayout.OFFICE_COUNT - 1))
	assert_false(WorldLayout.has_offices("general_services/review"))


func test_hall_trays_sit_below_the_offices() -> void:
	var trays := [layout.output_point(GameConfig.RECEPTION), layout.reject_point(GameConfig.RECEPTION), layout.input_point(GameConfig.COUNTER), layout.reject_point(GameConfig.COUNTER)]
	for point: Vector2 in trays:
		var key := GameConfig.RECEPTION if layout.area(GameConfig.RECEPTION).has_point(point) else GameConfig.COUNTER
		assert_true(layout.area(key).has_point(point), str(point))
		for index in WorldLayout.OFFICE_COUNT:
			assert_false(layout.office_rect(key, index).has_point(point), str(point))
	assert_lt(layout.output_point(GameConfig.RECEPTION).x, layout.reject_point(GameConfig.RECEPTION).x)
	assert_lt(layout.input_point(GameConfig.COUNTER).x, layout.reject_point(GameConfig.COUNTER).x)
	assert_gt(layout.output_point(GameConfig.RECEPTION).distance_to(layout.reject_point(GameConfig.RECEPTION)), 100.0)


func test_walls_leave_doors_towards_the_aisle_and_the_entrance() -> void:
	for room in GameConfig.WAITING_ROOMS:
		var rect := layout.waiting_room(room)
		var walls := layout.room_walls(room)
		assert_eq(walls.size(), 5, room)
		for point in walls:
			assert_true(rect.grow(0.5).has_point(point), room)
		assert_almost_eq(absf(walls[0].x - walls[1].x), rect.size.x - WorldLayout.DOOR_WIDTH, 0.01)
		assert_lt(walls[4].y, layout.place_area(room).position.y)
		assert_lt(walls[0].distance_to(layout.entrance), walls[1].distance_to(layout.entrance), room)


func test_clocks_hours_and_archive_have_their_own_places() -> void:
	for room in GameConfig.WAITING_ROOMS:
		var band := layout.room_band(room)
		assert_true(band.has_point(layout.room_clock_point(room)), room)
		assert_eq(band.size.y, WorldLayout.ROOM_BAND)
	assert_ne(layout.room_clock_point(GameConfig.HALL_INTAKE), layout.room_clock_point(GameConfig.HALL_PICKUP))
	var board := layout.hours_board()
	assert_true(layout.hall.encloses(board))
	for room in GameConfig.WAITING_ROOMS:
		assert_false(layout.waiting_room(room).intersects(board), room)
	assert_false(board.intersects(layout.ticket_area))
	assert_false(board.intersects(layout.closed_sign_rect()))
	assert_true(layout.waiting_room(GameConfig.HALL_INTAKE).encloses(layout.archive_rect()))
	assert_false(layout.place_area(GameConfig.HALL_INTAKE).intersects(layout.archive_rect()))
	assert_true(layout.waiting_room(GameConfig.HALL_PICKUP).has_point(layout.tube_station_point(GameConfig.ROOM_HALL)))
	assert_eq(layout.spot_at(layout.place_area(GameConfig.HALL_PICKUP).get_center()), "pickup_seating")
	assert_eq(layout.spot_at(layout.hall_plate().get_center()), "room:hall")


func test_side_column_still_matches_the_hall_bottom() -> void:
	assert_eq(layout.complaint_office.end.y, layout.hall.end.y)
	assert_gte(layout.tech_room.position.y, WorldLayout.MARGIN)
