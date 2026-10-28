extends GutTest

const GS := "general_services"
const REVIEW := "general_services/review"

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
	state.event_cooldown = 1e9
	state.player.position = Vector2(50, 50)
	state.money = 1e12


func _case() -> CaseFile:
	var case_file := CaseFile.new(GS)
	case_file.route = RouteBuilder.build(case_file)
	return case_file


func _citizen(phase: CaseFile.Phase, seated: bool) -> CaseFile:
	var citizen := _case()
	citizen.phase = phase
	citizen.seated = seated
	citizen.place = 0
	citizen.ticket = 1
	state.citizens.append(citizen)
	return citizen


func _wait(seconds: int) -> void:
	for i in seconds:
		sim._update_citizens(1.0)


func _tick(seconds: int) -> void:
	for i in seconds:
		sim.tick(1.0)


func _moods(seconds: int) -> void:
	for i in seconds:
		sim._update_moods(1.0)


func _probe() -> RandomNumberGenerator:
	var probe := RandomNumberGenerator.new()
	probe.seed = state.rng.seed
	probe.state = state.rng.state
	return probe


func _upcoming_rolls(count: int) -> Array[float]:
	var probe := _probe()
	var rolls: Array[float] = []
	for i in count:
		rolls.append(probe.randf())
	return rolls


func _state_after(count: int) -> int:
	var probe := _probe()
	for i in count:
		probe.randf()
	return probe.state


func _checkpoints() -> Array[float]:
	return Formulas.seat_leave_checks(0.0, GameConfig.SEAT_PATIENCE)


func _first_checkpoint() -> int:
	return int(_checkpoints()[0])


func _seed_where(accept: Callable) -> bool:
	var count := _checkpoints().size()
	for candidate in 10000:
		state.rng.seed = candidate
		if accept.call(_upcoming_rolls(count)):
			return true
	return false


func _leaves_first(rolls: Array) -> bool:
	return float(rolls[0]) < Formulas.seat_leave_chance(_checkpoints()[0])


func _stays_always(rolls: Array) -> bool:
	var checks := _checkpoints()
	for index in checks.size():
		if float(rolls[index]) < Formulas.seat_leave_chance(checks[index]):
			return false
	return true


func _lead(room_id: String = GS) -> void:
	state.set_upgrade("team_lead", 1, room_id)


func _staff(key: String, count: int = 1) -> Station:
	var station := state.station(key)
	while station.desks < count:
		station.add_desk()
	station.staff = count
	return station


func test_seat_leave_checkpoints_cover_the_waiting_window() -> void:
	var checks := _checkpoints()
	assert_eq(checks.size(), 9)
	assert_eq(checks[0], 120.0)
	assert_eq(checks[checks.size() - 1], 280.0)
	assert_almost_eq(Formulas.seat_leave_chance(120.0), 0.1, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(180.0), 0.15, 0.0001)
	assert_almost_eq(Formulas.seat_leave_chance(280.0), 0.2, 0.0001)


func _assert_stays_before_first_checkpoint(phase: CaseFile.Phase) -> void:
	assert_true(_seed_where(_leaves_first))
	var citizen := _citizen(phase, true)
	var rng_state := state.rng.state
	_wait(_first_checkpoint() - 1)
	assert_true(state.citizens.has(citizen))
	assert_almost_eq(citizen.waited, _first_checkpoint() - 1.0, 0.001)
	assert_eq(state.rng.state, rng_state)
	state.citizens.erase(citizen)


func test_seated_waiters_never_leave_before_the_first_checkpoint() -> void:
	_assert_stays_before_first_checkpoint(CaseFile.Phase.WAITING)
	_assert_stays_before_first_checkpoint(CaseFile.Phase.WAITING_DOC)


func _assert_leaves_at_first_checkpoint(phase: CaseFile.Phase) -> void:
	assert_true(_seed_where(_leaves_first))
	var lost := state.citizens_lost
	var citizen := _citizen(phase, true)
	_wait(_first_checkpoint() - 1)
	assert_true(state.citizens.has(citizen))
	_wait(1)
	assert_false(state.citizens.has(citizen))
	assert_true(citizen.raged)
	assert_eq(citizen.phase, CaseFile.Phase.NONE)
	assert_eq(state.citizens_lost, lost + 1)


func test_seated_waiters_leave_at_a_checkpoint_when_the_roll_hits() -> void:
	_assert_leaves_at_first_checkpoint(CaseFile.Phase.WAITING)
	_assert_leaves_at_first_checkpoint(CaseFile.Phase.WAITING_DOC)


func _assert_stays_until_patience_ends(phase: CaseFile.Phase) -> void:
	assert_true(_seed_where(_stays_always))
	var expected_state := _state_after(_checkpoints().size())
	var citizen := _citizen(phase, true)
	_wait(int(GameConfig.SEAT_PATIENCE) - 1)
	assert_true(state.citizens.has(citizen))
	assert_eq(state.rng.state, expected_state)
	_wait(1)
	assert_false(state.citizens.has(citizen))
	assert_true(citizen.raged)


func test_seated_waiters_stay_until_seat_patience_when_every_roll_misses() -> void:
	_assert_stays_until_patience_ends(CaseFile.Phase.WAITING)
	_assert_stays_until_patience_ends(CaseFile.Phase.WAITING_DOC)


func _assert_always_leaves(phase: CaseFile.Phase) -> void:
	for candidate in 6:
		state.rng.seed = candidate
		var citizen := _citizen(phase, true)
		_wait(int(GameConfig.SEAT_PATIENCE))
		assert_false(state.citizens.has(citizen), str(candidate))
		assert_true(citizen.raged, str(candidate))


func test_seated_waiters_always_leave_once_seat_patience_is_reached() -> void:
	_assert_always_leaves(CaseFile.Phase.WAITING)
	_assert_always_leaves(CaseFile.Phase.WAITING_DOC)
	var late := _citizen(CaseFile.Phase.WAITING, true)
	late.waited = GameConfig.SEAT_PATIENCE - 0.5
	sim._update_citizens(0.5)
	assert_false(state.citizens.has(late))


func test_standing_waiters_leave_after_stand_patience_without_rolling() -> void:
	assert_true(_seed_where(_leaves_first))
	var rng_state := state.rng.state
	var standing := _citizen(CaseFile.Phase.WAITING, false)
	assert_eq(Formulas.citizen_patience(standing), GameConfig.STAND_PATIENCE)
	_wait(int(GameConfig.STAND_PATIENCE) - 1)
	assert_true(state.citizens.has(standing))
	_wait(1)
	assert_false(state.citizens.has(standing))
	assert_eq(state.rng.state, rng_state)
	var probe := _citizen(CaseFile.Phase.WAITING_DOC, false)
	probe.waited = _first_checkpoint() + 1.0
	assert_false(sim._seat_leave_roll(probe, _first_checkpoint() - 1.0))
	assert_eq(state.rng.state, rng_state)


func _assert_no_seat_roll(phase: CaseFile.Phase, rng_state: int) -> void:
	var citizen := _citizen(phase, true)
	citizen.waited = _first_checkpoint() + 1.0
	assert_false(citizen.is_seat_waiting(), str(phase))
	assert_false(sim._seat_leave_roll(citizen, _first_checkpoint() - 1.0), str(phase))
	assert_eq(state.rng.state, rng_state, str(phase))


func test_line_and_called_citizens_never_roll_the_seat_chance() -> void:
	assert_true(_seed_where(_leaves_first))
	var rng_state := state.rng.state
	_assert_no_seat_roll(CaseFile.Phase.LINE, rng_state)
	_assert_no_seat_roll(CaseFile.Phase.CALLED, rng_state)
	_assert_no_seat_roll(CaseFile.Phase.CALLED_DOC, rng_state)
	var seated := _citizen(CaseFile.Phase.WAITING, true)
	seated.waited = _first_checkpoint() + 1.0
	assert_true(sim._seat_leave_roll(seated, _first_checkpoint() - 1.0))
	assert_ne(state.rng.state, rng_state)


func test_patrol_needs_a_team_lead() -> void:
	_staff(REVIEW)
	assert_false(sim.can_patrol(GS))
	assert_false(actions.can_patrol(GS))
	assert_false(sim.start_patrol(GS))
	assert_false(state.is_patrolling(GS))
	assert_eq(state.patrol_cooldown(GS), 0.0)
	assert_eq(state.patrols, 0)


func test_patrol_needs_stations_in_the_room() -> void:
	_lead(GameConfig.ROOM_INSPECTION)
	assert_true(Formulas.has_lead(state, GameConfig.ROOM_INSPECTION))
	assert_true(state.room_stations(GameConfig.ROOM_INSPECTION).is_empty())
	assert_false(sim.can_patrol(GameConfig.ROOM_INSPECTION))
	assert_false(actions.start_patrol(GameConfig.ROOM_INSPECTION))
	assert_eq(state.patrols, 0)


func test_patrol_is_blocked_while_active_and_while_cooling_down() -> void:
	_lead()
	_staff(REVIEW)
	assert_true(sim.can_patrol(GS))
	assert_true(actions.can_patrol(GS))
	assert_true(actions.start_patrol(GS))
	assert_true(state.is_patrolling(GS))
	assert_false(sim.can_patrol(GS))
	assert_false(sim.start_patrol(GS))
	assert_eq(state.patrols, 1)
	state.lead_patrols.erase(GS)
	assert_false(state.is_patrolling(GS))
	assert_gt(state.patrol_cooldown(GS), 0.0)
	assert_false(sim.can_patrol(GS))
	assert_false(actions.start_patrol(GS))
	assert_eq(state.patrols, 1)
	state.lead_cooldowns.erase(GS)
	assert_true(sim.can_patrol(GS))


func test_patrol_sets_timers_and_wakes_resting_desks_of_its_room_only() -> void:
	_lead()
	var review := _staff(REVIEW, 2)
	var photo := _staff(GameConfig.PHOTO_STATION)
	var reception := _staff(GameConfig.RECEPTION)
	photo.add_desk()
	review.moods[0].rest(DeskMood.ASLEEP)
	review.moods[1].rest(DeskMood.SICK)
	photo.moods[0].rest(DeskMood.COFFEE)
	photo.moods[1].rest(DeskMood.ASLEEP)
	reception.moods[0].rest(DeskMood.ASLEEP)
	watch_signals(sim)
	assert_true(sim.start_patrol(GS))
	assert_eq(state.lead_patrols[GS], GameConfig.LEAD_PATROL_SECONDS)
	assert_eq(state.patrol_left(GS), GameConfig.LEAD_PATROL_SECONDS)
	assert_almost_eq(state.lead_cooldowns[GS], Formulas.patrol_cooldown(state, GS), 0.0001)
	assert_almost_eq(state.patrol_cooldown(GS), float(GameConfig.upgrade("lead_cooldown").base), 0.0001)
	assert_eq(state.patrols, 1)
	assert_true(review.moods[0].is_on_duty())
	assert_true(review.moods[1].is_sick())
	assert_true(photo.moods[0].is_on_duty())
	assert_eq(photo.moods[1].state, DeskMood.ASLEEP)
	assert_eq(reception.moods[0].state, DeskMood.ASLEEP)
	assert_eq(state.production.total(ProductionStats.LEAD_WOKEN), 2)
	assert_eq(state.production.total(ProductionStats.LEAD_WOKEN, REVIEW), 1)
	assert_eq(state.production.total(ProductionStats.LEAD_WOKEN, GameConfig.PHOTO_STATION), 1)
	assert_eq(state.production.total(ProductionStats.LEAD_WOKEN, GameConfig.RECEPTION), 0)
	assert_signal_emitted_with_parameters(sim, "patrol_started", [GS, 2])


func test_patrol_ends_after_its_duration_and_cooldown_runs_out() -> void:
	_lead()
	_staff(REVIEW)
	watch_signals(sim)
	assert_true(sim.start_patrol(GS))
	var duration := int(GameConfig.LEAD_PATROL_SECONDS)
	_tick(duration - 1)
	assert_true(state.is_patrolling(GS))
	assert_signal_not_emitted(sim, "patrol_ended")
	_tick(1)
	assert_false(state.is_patrolling(GS))
	assert_signal_emitted_with_parameters(sim, "patrol_ended", [GS])
	assert_eq(get_signal_emit_count(sim, "patrol_ended"), 1)
	assert_almost_eq(state.patrol_cooldown(GS), Formulas.patrol_cooldown(state, GS) - GameConfig.LEAD_PATROL_SECONDS, 0.001)
	assert_false(sim.can_patrol(GS))
	var remaining := ceili(state.patrol_cooldown(GS))
	_tick(remaining - 1)
	assert_gt(state.patrol_cooldown(GS), 0.0)
	assert_false(sim.can_patrol(GS))
	_tick(1)
	assert_eq(state.patrol_cooldown(GS), 0.0)
	assert_true(sim.can_patrol(GS))
	assert_true(actions.can_patrol(GS))
	assert_eq(get_signal_emit_count(sim, "patrol_ended"), 1)


func test_patrol_speeds_up_the_room_and_keeps_its_desks_awake() -> void:
	_lead()
	state.set_upgrade("lead_patrol", 10, GS)
	var review := _staff(REVIEW)
	var reception := _staff(GameConfig.RECEPTION)
	var normal := Formulas.work_speed(state, review)
	var hall := Formulas.work_speed(state, reception)
	assert_eq(Formulas.patrol_speed(state, GS), 1.0)
	assert_true(sim.start_patrol(GS))
	var config := GameConfig.upgrade("lead_patrol")
	var bonus := Formulas.lead_value(state, "lead_patrol", GS)
	assert_almost_eq(bonus, float(config.base) + float(config.step) * 10.0, 0.0001)
	assert_almost_eq(Formulas.patrol_speed(state, GS), bonus, 0.0001)
	assert_eq(Formulas.patrol_speed(state, GameConfig.ROOM_HALL), 1.0)
	assert_almost_eq(Formulas.work_speed(state, review), normal * bonus, 0.0001)
	assert_almost_eq(Formulas.work_speed(state, reception), hall, 0.0001)
	review.inbox.append(_case())
	reception.inbox.append(_case())
	review.moods[0].alert = 0.5
	reception.moods[0].alert = 0.5
	sim._update_moods(1.0)
	assert_true(review.moods[0].is_on_duty())
	assert_eq(review.moods[0].alert, 0.5)
	assert_false(reception.moods[0].is_on_duty())


func test_lead_upgrades_require_a_team_lead_in_the_same_room() -> void:
	var staff := state.total_staff()
	assert_false(actions.buy_upgrade("lead_breaks", GS))
	assert_true(actions.buy_upgrade("team_lead", GameConfig.HALL_INTAKE))
	assert_eq(Progression.upgrade_block_reason(state, "lead_breaks", GS), "requires")
	assert_false(actions.buy_upgrade("lead_breaks", GS))
	assert_true(actions.buy_upgrade("team_lead", GS))
	assert_true(actions.buy_upgrade("lead_breaks", GS))
	assert_eq(state.upgrade_level("lead_breaks", GS), 1)
	assert_eq(state.upgrade_level("lead_breaks", GameConfig.HALL_INTAKE), 0)
	assert_eq(Formulas.team_lead_count(state), 2)
	assert_eq(state.total_staff(), staff + 2)


func test_lead_breaks_shorten_coffee_and_lunch_in_its_room_only() -> void:
	_lead()
	state.set_upgrade("lead_breaks", 50, GS)
	var review := _staff(REVIEW)
	var reception := _staff(GameConfig.RECEPTION)
	var factor := Formulas.lead_value(state, "lead_breaks", GS)
	assert_almost_eq(factor, Formulas.track_value("lead_breaks", 50), 0.0001)
	assert_lt(Formulas.track_value("lead_breaks", 0), 1.0)
	for rest_state: String in [DeskMood.COFFEE, DeskMood.LUNCH]:
		var full := Formulas.rest_limit(state, rest_state, GameConfig.ROOM_HALL)
		var short := Formulas.rest_limit(state, rest_state, GS)
		assert_almost_eq(full, Formulas.base_rest_limit(state, rest_state), 0.0001, rest_state)
		assert_almost_eq(short, full * factor, 0.0001, rest_state)
		review.moods[0].rest(rest_state)
		reception.moods[0].rest(rest_state)
		_moods(ceili(short) + 1)
		assert_false(review.moods[0].is_resting(), rest_state)
		assert_true(reception.moods[0].is_resting(), rest_state)
		reception.moods[0].wake(GameConfig.BASE_ALERT_SECONDS)
	assert_eq(Formulas.rest_limit(state, DeskMood.ASLEEP, GS), Formulas.rest_limit(state, DeskMood.ASLEEP, GameConfig.ROOM_HALL))
	assert_eq(Formulas.rest_limit(state, DeskMood.CHAT, GS), Formulas.rest_limit(state, DeskMood.CHAT, GameConfig.ROOM_HALL))


func test_lead_health_shortens_sick_leave_in_its_room_only() -> void:
	_lead()
	state.set_upgrade("lead_health", 50, GS)
	var review := _staff(REVIEW)
	var reception := _staff(GameConfig.RECEPTION)
	review.moods[0].rest(DeskMood.SICK)
	reception.moods[0].rest(DeskMood.SICK)
	var short := Formulas.sick_time_left(state, review.moods[0], GS)
	var full := Formulas.sick_time_left(state, reception.moods[0], GameConfig.ROOM_HALL)
	assert_almost_eq(full, GameConfig.SICK_SECONDS, 0.001)
	assert_almost_eq(short, GameConfig.SICK_SECONDS * Formulas.track_value("lead_health", 50), 0.001)
	assert_almost_eq(Formulas.rest_limit(state, DeskMood.SICK, GS), short, 0.001)
	assert_lt(Formulas.sick_share(state, GS), Formulas.sick_share(state, GameConfig.ROOM_HALL))
	_moods(ceili(short) + 1)
	assert_false(review.moods[0].is_sick())
	assert_true(reception.moods[0].is_sick())


func test_team_lead_gives_strong_buffs_right_away() -> void:
	for upgrade_id in ["lead_breaks", "lead_health", "lead_focus", "lead_calm", "lead_patrol"]:
		assert_eq(Formulas.lead_value(state, upgrade_id, GS), Formulas.lead_neutral(upgrade_id), upgrade_id)
	assert_eq(Formulas.lead_value(state, "lead_breaks", GS), 1.0)
	assert_eq(Formulas.department_calm(state, GS), 0.0)
	_lead()
	assert_lte(Formulas.lead_value(state, "lead_breaks", GS), 0.75)
	assert_lte(Formulas.lead_value(state, "lead_health", GS), 0.75)
	assert_lte(Formulas.lead_value(state, "lead_focus", GS), 0.7)
	assert_gte(Formulas.department_calm(state, GS), 0.25)
	assert_gte(Formulas.lead_value(state, "lead_patrol", GS), 3.0)
	assert_eq(Formulas.lead_value(state, "lead_breaks", GameConfig.ROOM_HALL), 1.0)
	assert_eq(Formulas.lead_value(state, "lead_breaks", ""), 1.0)
	assert_eq(Formulas.lead_neutral("lead_cooldown"), Formulas.track_value("lead_cooldown", 0))


func test_lead_tracks_are_fine_grained_and_cheap() -> void:
	for upgrade_id: String in GameConfig.LEAD_TRACKS:
		var config := GameConfig.upgrade(upgrade_id)
		if upgrade_id == "team_lead":
			assert_lte(float(config.cost), 400.0)
			continue
		assert_eq(int(config.max), GameConfig.LEAD_TRACK_LEVELS, upgrade_id)
		assert_lte(float(config.cost), 100.0, upgrade_id)
		assert_lte(float(config.growth), 1.05, upgrade_id)


func test_lead_focus_slows_dozing_in_its_room_only() -> void:
	_lead()
	state.set_upgrade("lead_focus", 50, GS)
	var review := _staff(REVIEW)
	var reception := _staff(GameConfig.RECEPTION)
	review.inbox.append(_case())
	reception.inbox.append(_case())
	var focused := Formulas.drowsiness_rate(state, review)
	var normal := Formulas.drowsiness_rate(state, reception)
	assert_almost_eq(focused, normal * Formulas.track_value("lead_focus", 50), 0.0001)
	review.moods[0].alert = 50.0
	reception.moods[0].alert = 50.0
	sim._update_moods(10.0)
	assert_almost_eq(review.moods[0].alert, 50.0 - 10.0 * focused, 0.001)
	assert_almost_eq(reception.moods[0].alert, 50.0 - 10.0 * normal, 0.001)
	assert_gt(review.moods[0].alert, reception.moods[0].alert)


func test_room_trays_raise_every_tray_of_the_room_up_to_the_cap() -> void:
	var lobby := state.lobby_capacity()
	var room := state.room_stations(GS)
	var counter := state.station(GameConfig.COUNTER)
	assert_eq(room.size(), 2)
	for station in room:
		assert_eq(station.inbox_capacity(lobby), GameConfig.TRAY_BASE, station.key)
		assert_eq(station.outbox_capacity(), GameConfig.TRAY_BASE, station.key)
	assert_true(actions.buy_upgrade("room_trays", GS, 4))
	for station in room:
		assert_eq(station.inbox_capacity(lobby), GameConfig.TRAY_BASE + 4, station.key)
		assert_eq(station.outbox_capacity(), GameConfig.TRAY_BASE + 4, station.key)
	assert_eq(counter.inbox_capacity(lobby), GameConfig.TRAY_BASE)
	room[0].add_desk()
	room[0].staff = 2
	assert_eq(room[0].inbox_capacity(lobby), GameConfig.TRAY_BASE + 4)
	assert_eq(room[0].outbox_capacity(), GameConfig.TRAY_BASE + 4)
	assert_true(actions.buy_upgrade("room_trays", GS, 1000))
	for station in room:
		assert_eq(station.inbox_capacity(lobby), GameConfig.TRAY_MAX, station.key)
		assert_eq(station.outbox_capacity(), GameConfig.TRAY_MAX, station.key)
	assert_false(actions.buy_upgrade("room_trays", GS))
	state.set_upgrade("room_trays", 1000, GS)
	assert_eq(Formulas.tray_size(state, GS), GameConfig.TRAY_MAX)
	for station in room:
		assert_eq(station.inbox_capacity(lobby), GameConfig.TRAY_MAX, station.key)
	assert_eq(counter.inbox_capacity(lobby), GameConfig.TRAY_BASE)


func test_hall_trays_raise_the_counter_but_not_the_reception_lobby() -> void:
	var lobby := state.lobby_capacity()
	var reception := state.station(GameConfig.RECEPTION)
	var counter := state.station(GameConfig.COUNTER)
	assert_true(actions.buy_upgrade("room_trays", GameConfig.ROOM_HALL, 3))
	assert_eq(counter.inbox_capacity(lobby), GameConfig.TRAY_BASE + 3)
	assert_eq(counter.outbox_capacity(), GameConfig.TRAY_BASE + 3)
	assert_eq(reception.inbox_capacity(lobby), lobby)
	assert_eq(reception.outbox_capacity(), GameConfig.TRAY_BASE + 3)
	assert_eq(state.station(REVIEW).inbox_capacity(lobby), GameConfig.TRAY_BASE)


func test_room_speed_upgrade_speeds_up_and_rushes_its_room() -> void:
	var review := state.station(REVIEW)
	var photo := state.station(GameConfig.PHOTO_STATION)
	var reception := state.station(GameConfig.RECEPTION)
	var case_file := _case()
	var before := Formulas.required_time(state, review, case_file)
	assert_eq(Formulas.station_speed(state, review), 1.0)
	assert_true(actions.buy_upgrade("room_speed", GS))
	assert_eq(state.upgrade_level("room_speed", GS), 1)
	assert_eq(state.max_room_speed(), 1)
	var faster := Formulas.level_speed(2)
	assert_gt(faster, 1.0)
	assert_almost_eq(Formulas.station_speed(state, review), faster, 0.0001)
	assert_almost_eq(Formulas.station_speed(state, photo), faster, 0.0001)
	assert_almost_eq(Formulas.required_time(state, review, case_file), before / faster, 0.0001)
	assert_eq(review.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_eq(photo.rush, GameConfig.UPGRADE_RUSH_SECONDS)
	assert_almost_eq(Formulas.work_speed(state, review), GameConfig.UPGRADE_RUSH_SPEED, 0.0001)
	assert_eq(reception.rush, 0.0)
	assert_eq(Formulas.station_speed(state, reception), 1.0)


func test_thoroughness_scales_department_work_time() -> void:
	var review := _staff(REVIEW)
	var reception := state.station(GameConfig.RECEPTION)
	var case_file := _case()
	var normal := Formulas.required_time(state, review, case_file)
	var shared := Formulas.required_time(state, reception, case_file)
	assert_true(actions.set_thoroughness(GS, 0))
	assert_almost_eq(Formulas.required_time(state, review, case_file), normal * 0.45, 0.0001)
	assert_almost_eq(Formulas.required_time(state, reception, case_file), shared, 0.0001)
	assert_true(actions.set_thoroughness(GS, 2))
	assert_almost_eq(Formulas.required_time(state, review, case_file), normal * 2.0, 0.0001)
	assert_almost_eq(Formulas.required_time(state, reception, case_file), shared, 0.0001)
	review.inbox.append(case_file)
	assert_true(sim.start_job(review, 0))
	assert_almost_eq(review.jobs[0].required, normal * 2.0, 0.0001)


func test_thorough_cases_pay_more() -> void:
	var dept := state.department(GS)
	var case_file := _case()
	var normal := float(Formulas.case_outcome(state, case_file).money)
	var normal_expected := Formulas.expected_case_value(state, dept)
	assert_true(actions.set_thoroughness(GS, 0))
	assert_almost_eq(float(Formulas.case_outcome(state, case_file).money), normal, 0.0001)
	assert_true(actions.set_thoroughness(GS, 2))
	assert_almost_eq(Formulas.thoroughness_reward(dept), 2.6, 0.0001)
	assert_almost_eq(float(Formulas.case_outcome(state, case_file).money), normal * 2.6, 0.0001)
	assert_gt(Formulas.expected_case_value(state, dept), normal_expected * 2.6)
	watch_signals(sim)
	sim.complete_case(case_file)
	assert_signal_emitted(sim, "case_completed")
	var params: Array = get_signal_parameters(sim, "case_completed")
	assert_eq(params[0], GS)
	assert_almost_eq(float(params[1]), normal * 2.6, 0.0001)
	assert_false(bool(params[2]))


func test_new_game_offices_start_with_one_empty_desk() -> void:
	var fresh := GameState.create_new(9)
	var keys: Array[String] = []
	keys.append_array(GameConfig.department_station_keys(GS))
	keys.append(GameConfig.RECEPTION)
	keys.append(GameConfig.COUNTER)
	for key in keys:
		var station := fresh.station(key)
		assert_not_null(station, key)
		if station == null:
			continue
		assert_false(station.machine, key)
		assert_eq(station.desks, 1, key)
		assert_eq(station.staff, 0, key)
		assert_eq(station.tray_size, GameConfig.TRAY_BASE, key)
	for key in fresh.stations:
		var station := fresh.station(key)
		if not station.machine:
			assert_eq(station.staff, 0, key)
	assert_eq(Formulas.team_lead_count(fresh), 0)


func test_lead_position_follows_the_patrol_path() -> void:
	_lead()
	_staff(REVIEW)
	var seat := layout.lead_seat(GS)
	assert_eq(WorldView.lead_position(state, layout, GS), seat)
	assert_true(sim.start_patrol(GS))
	assert_lt(WorldView.lead_position(state, layout, GS).distance_to(seat), 0.01)
	state.lead_patrols[GS] = GameConfig.LEAD_PATROL_SECONDS * 0.5
	var middle := WorldView.lead_position(state, layout, GS)
	assert_gt(middle.distance_to(seat), 1.0)
	assert_lt(middle.distance_to(layout.desk_front(REVIEW, 0)), 0.01)
	state.lead_patrols[GS] = GameConfig.LEAD_PATROL_SECONDS * (1.0 - 1.0 / GameConfig.LEAD_PATROL_LAPS)
	assert_lt(WorldView.lead_position(state, layout, GS).distance_to(seat), 0.01)
	state.lead_patrols.erase(GS)
	assert_eq(WorldView.lead_position(state, layout, GS), seat)


func test_patrol_label_shows_ready_active_and_cooldown() -> void:
	_lead()
	_staff(REVIEW)
	assert_eq(SpotSheet.patrol_label(state, GS), TranslationServer.translate("ACTION_PATROL"))
	assert_true(sim.start_patrol(GS))
	assert_eq(SpotSheet.patrol_label(state, GS), TranslationServer.translate("FMT_PATROL_ACTIVE") % UiKit.duration(GameConfig.LEAD_PATROL_SECONDS))
	state.lead_patrols.erase(GS)
	assert_eq(SpotSheet.patrol_label(state, GS), TranslationServer.translate("FMT_PATROL_COOLDOWN") % UiKit.duration(state.patrol_cooldown(GS)))
	state.lead_cooldowns.erase(GS)
	assert_eq(SpotSheet.patrol_label(state, GS), TranslationServer.translate("ACTION_PATROL"))


func test_spot_status_describes_the_team_lead() -> void:
	var spot := GameConfig.lead_spot(GS)
	assert_eq(spot, "lead:" + GS)
	var empty := SpotStatus.lines(state, spot)
	assert_eq(empty.size(), 1)
	assert_eq(empty[0], TranslationServer.translate("STATUS_NO_LEAD"))
	_lead()
	state.set_upgrade("lead_breaks", 10, GS)
	state.set_upgrade("lead_patrol", 5, GS)
	var lines := SpotStatus.lines(state, spot)
	assert_eq(lines.size(), 2)
	var lead := TranslationServer.translate("FMT_STATUS_LEAD") % [UiKit.percent(1.0 - Formulas.track_value("lead_breaks", 10)), UiKit.percent(1.0 - Formulas.track_value("lead_health", 0)), UiKit.percent(1.0 - Formulas.track_value("lead_focus", 0))]
	assert_eq(lines[0], lead)
	var config := GameConfig.upgrade("lead_patrol")
	var patrol := TranslationServer.translate("FMT_STATUS_PATROL") % [UiKit.decimal(float(config.base) + float(config.step) * 5.0, 2), UiKit.duration(GameConfig.LEAD_PATROL_SECONDS), UiKit.duration(float(GameConfig.upgrade("lead_cooldown").base))]
	assert_eq(lines[1], patrol)
	assert_ne(lines[0], empty[0])
