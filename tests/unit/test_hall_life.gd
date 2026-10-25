extends GutTest

const REVIEW := "general_services/review"

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.complaint_timer = 1e6
	state.dispute_timer = 1e6
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _staff_review(count: int) -> Station:
	var review := state.station(REVIEW)
	while review.desks < count:
		review.add_desk()
	review.staff = count
	return review


func _queue_work(review: Station, amount: int = 1) -> void:
	for i in amount:
		var case_file := sim.create_case(state.department("general_services"))
		case_file.step = 1
		review.inbox.append(case_file)


func _fill_lobby() -> void:
	var dept := state.department("general_services")
	for i in state.lobby_capacity():
		assert_not_null(sim.spawn_case(dept))


func _walk_seconds(from: Vector2, to: Vector2) -> float:
	return from.distance_to(to) / GameConfig.VISITOR_SPEED


func test_complaint_arrives_with_a_visitor() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.complaint_timer = 0.0
	sim.tick(0.05)
	assert_eq(state.visitors.size(), 1)
	var visitor := state.visitors[0]
	assert_true(visitor.files_complaint)
	assert_eq(state.complaints, 0)
	var desk := layout.visitor_spot(visitor.slot)
	_run(_walk_seconds(layout.door_in(), desk) + 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	assert_eq(state.complaints + state.complaints_fended, 0)
	_run(GameConfig.VISITOR_TALK_SECONDS + _walk_seconds(desk, layout.complaint_drop_spot()) + 1.0)
	assert_eq(state.complaints + state.complaints_fended, 1)
	assert_false(visitor.files_complaint)
	_run(maxf(_walk_seconds(desk, layout.door_out()), _walk_seconds(layout.complaint_drop_spot(), layout.door_out())) + 2.0)
	assert_true(state.visitors.is_empty())


func _visitor_past_the_clerk(angry: bool, files_complaint: bool) -> ComplaintVisitor:
	for attempt in 200:
		state.visitors.clear()
		var visitor := sim.spawn_visitor(angry, files_complaint)
		visitor.position = layout.visitor_spot(visitor.slot)
		sim.tick(0.05)
		visitor.timer = 0.0
		var fended := state.complaints_fended
		sim.tick(0.05)
		if state.complaints_fended == fended:
			return visitor
	return null


func test_unfended_visitor_complains_to_the_interns_then_uses_the_box() -> void:
	state.set_upgrade("shredder_service", 1)
	var visitor := _visitor_past_the_clerk(false, true)
	assert_not_null(visitor)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_INTERNS)
	assert_true(visitor.files_complaint)
	assert_eq(state.complaints, 0)
	visitor.position = layout.vent_spot(visitor.slot)
	sim.tick(0.05)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.VENTING)
	assert_almost_eq(visitor.duration, GameConfig.VISITOR_VENT_SECONDS, 0.001)
	assert_true(visitor.vent_speaks())
	_run(GameConfig.VISITOR_VENT_SECONDS - 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.VENTING)
	assert_false(visitor.vent_speaks())
	assert_gt(state.intern.stress, 0.0)
	assert_eq(state.complaints, 0)
	_run(1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_BOX)
	visitor.position = layout.complaint_drop_spot()
	watch_signals(sim)
	sim.tick(0.05)
	assert_eq(state.complaints, 1)
	assert_false(visitor.files_complaint)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [false])


func test_normal_venting_stresses_the_intern_less_than_shouting() -> void:
	state.set_upgrade("shredder_service", 1)
	var visitor := _visitor_past_the_clerk(false, true)
	visitor.position = layout.vent_spot(visitor.slot)
	sim.tick(0.05)
	_run(2.0)
	var calm := state.intern.stress
	assert_almost_eq(calm, (GameConfig.INTERN_VENT_RATE - GameConfig.INTERN_CALM_RATE) * 2.0, 0.001)
	assert_gt(calm, 0.0)
	state.intern.stress = 0.0
	visitor.angry = true
	_run(2.0)
	assert_gt(state.intern.stress, calm)


func test_fended_visitor_leaves_without_visiting_the_interns() -> void:
	state.set_upgrade("shredder_service", 1)
	var fended := 0
	for attempt in 200:
		state.visitors.clear()
		var visitor := sim.spawn_visitor(false, true)
		visitor.position = layout.visitor_spot(visitor.slot)
		sim.tick(0.05)
		visitor.timer = 0.0
		var before := state.complaints_fended
		sim.tick(0.05)
		if state.complaints_fended > before:
			fended += 1
			assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
			assert_false(visitor.files_complaint)
		else:
			assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_INTERNS)
	assert_between(fended, 10, 60)
	assert_eq(state.complaints, 0)


func test_without_interns_the_visitor_walks_straight_to_the_box() -> void:
	var visitor := _visitor_past_the_clerk(false, true)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_BOX)
	_run(_walk_seconds(visitor.position, layout.complaint_drop_spot()) + 1.0)
	assert_eq(state.complaints, 1)
	assert_eq(state.intern.stress, 0.0)


func test_angry_visitor_without_interns_just_leaves() -> void:
	var visitor := _visitor_past_the_clerk(true, false)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)


func test_angry_visitor_vents_but_files_nothing() -> void:
	state.set_upgrade("shredder_service", 1)
	var visitor := _visitor_past_the_clerk(true, false)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_INTERNS)
	visitor.position = layout.vent_spot(visitor.slot)
	_run(GameConfig.VISITOR_VENT_SECONDS + 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_eq(state.complaints, 0)


func test_amnesty_sends_the_visitor_home_after_the_clerk() -> void:
	state.set_upgrade("shredder_service", 1)
	state.seals = 10
	assert_true(Boosts.new(state, sim).use("complaint_amnesty", Boosts.SEALS))
	var visitor := sim.spawn_visitor(false, true)
	visitor.position = layout.visitor_spot(visitor.slot)
	sim.tick(0.05)
	visitor.timer = 0.0
	sim.tick(0.05)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_false(visitor.files_complaint)
	assert_eq(state.complaints_fended, 0)


func test_visitor_frees_the_clerk_slot_once_past_the_desk() -> void:
	var first := sim.spawn_visitor(false, false)
	for i in GameConfig.VISITOR_SLOTS - 1:
		sim.spawn_visitor(false, false)
	assert_true(first.is_at_clerk())
	first.phase = ComplaintVisitor.Phase.TO_INTERNS
	assert_false(first.is_at_clerk())
	var next := sim.spawn_visitor(false, false)
	assert_not_null(next)
	assert_eq(next.slot, first.slot)
	for phase in [ComplaintVisitor.Phase.VENTING, ComplaintVisitor.Phase.TO_BOX, ComplaintVisitor.Phase.LEAVING, ComplaintVisitor.Phase.STOPPED]:
		first.phase = phase
		assert_false(first.is_at_clerk(), str(phase))
	first.phase = ComplaintVisitor.Phase.ARRIVING
	first.guard = 0
	assert_false(first.is_at_clerk())


func test_complaint_is_filed_directly_without_free_slot() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for i in GameConfig.VISITOR_SLOTS:
		sim.spawn_visitor(false, false)
	state.complaint_timer = 0.0
	sim.tick(0.05)
	assert_eq(state.complaints, 1)
	assert_eq(state.visitors.size(), GameConfig.VISITOR_SLOTS)


func test_visitor_slots_are_limited_and_unique() -> void:
	var seen := {}
	for i in GameConfig.VISITOR_SLOTS:
		var visitor := sim.spawn_visitor(false, false)
		assert_not_null(visitor)
		assert_false(seen.has(visitor.slot))
		seen[visitor.slot] = true
	assert_null(sim.spawn_visitor(false, false))
	assert_eq(state.visitors.size(), GameConfig.VISITOR_SLOTS)


func test_leaving_visitor_frees_its_slot() -> void:
	var first := sim.spawn_visitor(false, false)
	for i in GameConfig.VISITOR_SLOTS - 1:
		sim.spawn_visitor(false, false)
	first.phase = ComplaintVisitor.Phase.LEAVING
	var next := sim.spawn_visitor(false, false)
	assert_not_null(next)
	assert_eq(next.slot, first.slot)


func test_visitor_signal_and_dialog_ranges() -> void:
	watch_signals(sim)
	for i in 40:
		state.visitors.clear()
		var angry := i % 2 == 0
		var visitor := sim.spawn_visitor(angry, false)
		var limit := GameConfig.YELL_DIALOGS if angry else GameConfig.VISITOR_DIALOGS
		assert_between(visitor.dialog, 0, limit - 1)
		assert_between(visitor.look, 0, 11)
	assert_signal_emitted_with_parameters(sim, "visitor_arrived", [true], 0)
	assert_signal_emitted_with_parameters(sim, "visitor_arrived", [false], 1)


func test_visitor_line_follows_progress() -> void:
	var visitor := ComplaintVisitor.new()
	assert_eq(visitor.progress(), 0.0)
	visitor.duration = 9.0
	visitor.timer = 9.0
	assert_eq(visitor.line(), 0)
	assert_true(visitor.visitor_speaks())
	visitor.timer = 5.0
	assert_eq(visitor.line(), 1)
	assert_false(visitor.visitor_speaks())
	visitor.timer = 0.5
	assert_eq(visitor.line(), 2)
	assert_true(visitor.visitor_speaks())
	visitor.timer = -1.0
	assert_eq(visitor.line(), GameConfig.VISITOR_LINES - 1)


func test_visitor_walks_in_talks_and_leaves() -> void:
	var visitor := sim.spawn_visitor(false, false)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.ARRIVING)
	var desk := layout.visitor_spot(visitor.slot)
	_run(_walk_seconds(layout.door_in(), desk) + 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	assert_eq(visitor.position, desk)
	assert_gt(visitor.timer, 0.0)
	_run(GameConfig.VISITOR_TALK_SECONDS + 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	_run(_walk_seconds(desk, layout.door_out()) + 1.0)
	assert_true(state.visitors.is_empty())


func test_walkout_costs_reputation_but_newcomers_do_not_complain() -> void:
	state.reputation = 5.0
	_fill_lobby()
	watch_signals(sim)
	assert_null(sim.spawn_case(state.department("general_services")))
	assert_eq(state.walkouts, 1)
	assert_eq(state.citizens_lost, 1)
	assert_almost_eq(state.reputation, 5.0 + GameConfig.REP_WALKED_OUT * GameConfig.REP_LOSS_FACTOR, 0.001)
	assert_true(state.visitors.is_empty())
	assert_eq(state.complaints, 0)
	assert_signal_emitted(sim, "citizen_left")


func test_some_walkouts_come_back_as_angry_complainers() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	_fill_lobby()
	var dept := state.department("general_services")
	var attempts := 400
	var complainers := 0
	for i in attempts:
		state.leave_complaint_cooldown = 0.0
		state.visitors.clear()
		assert_null(sim.spawn_case(dept))
		if not state.visitors.is_empty():
			complainers += 1
			assert_true(state.visitors[0].angry)
			assert_true(state.visitors[0].files_complaint)
	assert_eq(state.walkouts, attempts)
	assert_eq(state.complaints, 0)
	var expected := attempts * GameConfig.WALKOUT_COMPLAINT_CHANCE
	assert_between(complainers, int(expected * 0.5), int(expected * 1.8))


func test_complaint_after_leaving_respects_experience_and_cooldown() -> void:
	assert_false(sim.complain_after_leaving(1.0, true))
	assert_true(state.visitors.is_empty())
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	assert_false(sim.complain_after_leaving(0.0, true))
	assert_eq(state.leave_complaint_cooldown, 0.0)
	assert_true(sim.complain_after_leaving(1.0, true))
	assert_eq(state.visitors.size(), 1)
	assert_true(state.visitors[0].angry)
	assert_true(state.visitors[0].files_complaint)
	assert_eq(state.leave_complaint_cooldown, GameConfig.LEAVE_COMPLAINT_COOLDOWN)
	assert_false(sim.complain_after_leaving(1.0, true))
	assert_eq(state.visitors.size(), 1)
	_run(GameConfig.LEAVE_COMPLAINT_COOLDOWN + 0.5, 0.5)
	assert_eq(state.leave_complaint_cooldown, 0.0)
	assert_true(sim.complain_after_leaving(1.0, false))


func test_leaver_complaint_is_filed_directly_without_free_slot() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	for i in GameConfig.VISITOR_SLOTS:
		sim.spawn_visitor(false, false)
	assert_true(sim.complain_after_leaving(1.0, true))
	assert_eq(state.complaints + state.complaints_fended, 1)
	assert_eq(state.visitors.size(), GameConfig.VISITOR_SLOTS)


func test_angry_visitors_come_when_complaints_pile_up() -> void:
	state.complaints = GameConfig.YELL_COMPLAINTS
	state.yell_timer = 0.0
	sim.tick(0.05)
	assert_eq(state.visitors.size(), 1)
	assert_true(state.visitors[0].angry)
	assert_false(state.visitors[0].files_complaint)
	assert_gt(state.yell_timer, 0.0)


func test_no_angry_visitors_below_threshold() -> void:
	state.complaints = GameConfig.YELL_COMPLAINTS - 1
	state.yell_timer = 0.0
	sim.tick(0.05)
	assert_true(state.visitors.is_empty())
	assert_eq(state.yell_timer, GameConfig.YELL_INTERVAL)


func test_angry_visitor_stresses_the_intern() -> void:
	state.set_upgrade("shredder_service", 1)
	var visitor := sim.spawn_visitor(true, false)
	visitor.phase = ComplaintVisitor.Phase.TO_INTERNS
	visitor.position = layout.vent_spot(visitor.slot)
	_run(3.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.VENTING)
	assert_gt(state.intern.stress, 0.0)


func test_angry_visitor_at_the_clerk_does_not_stress_the_intern() -> void:
	state.set_upgrade("shredder_service", 1)
	var visitor := sim.spawn_visitor(true, false)
	visitor.position = layout.visitor_spot(visitor.slot)
	_run(3.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	assert_eq(state.intern.stress, 0.0)


func test_angry_visitor_does_not_stress_without_shredder_service() -> void:
	var visitor := sim.spawn_visitor(true, false)
	_run(_walk_seconds(layout.door_in(), layout.visitor_spot(visitor.slot)) + GameConfig.VISITOR_ANGRY_TALK_SECONDS + GameConfig.VISITOR_VENT_SECONDS + 1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_eq(state.intern.stress, 0.0)


func test_normal_visitor_without_complaint_does_not_stress_the_intern() -> void:
	state.set_upgrade("shredder_service", 1)
	var visitor := sim.spawn_visitor(false, false)
	_run(_walk_seconds(layout.door_in(), layout.visitor_spot(visitor.slot)) + GameConfig.VISITOR_TALK_SECONDS + GameConfig.VISITOR_VENT_SECONDS + 1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_eq(state.intern.stress, 0.0)


func test_intern_stress_builds_up_with_many_complaints() -> void:
	state.set_upgrade("shredder_service", 1)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	_run(10.0)
	var expected := (GameConfig.COMPLAINT_BOX_CAPACITY - GameConfig.INTERN_STRESS_FREE) * GameConfig.INTERN_STRESS_RATE * 10.0
	assert_almost_eq(state.intern.stress, expected, 0.01)


func test_intern_survives_several_shredder_trips_with_a_full_box() -> void:
	var full_box := float(GameConfig.COMPLAINT_BOX_CAPACITY - GameConfig.INTERN_STRESS_FREE) * GameConfig.INTERN_STRESS_RATE
	var shouting := GameConfig.INTERN_YELL_RATE * GameConfig.VISITOR_VENT_SECONDS / GameConfig.YELL_INTERVAL
	var seconds_until_breakdown := (1.0 - GameConfig.INTERN_RECOVERED_STRESS) / (full_box + shouting)
	var trip := Formulas.track_value("shredder_service", 1) + GameConfig.INTERN_TRIP_ESTIMATE
	assert_gt(seconds_until_breakdown / trip, 2.0)


func test_resilience_reduces_stress_from_a_full_box() -> void:
	state.set_upgrade("shredder_service", 1)
	state.set_upgrade("intern_resilience", 40)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	_run(10.0)
	var over := GameConfig.COMPLAINT_BOX_CAPACITY - Formulas.intern_stress_free(state)
	var expected := over * GameConfig.INTERN_STRESS_RATE * Formulas.intern_stress_factor(state) * 10.0
	assert_almost_eq(state.intern.stress, expected, 0.002)
	var untrained := (GameConfig.COMPLAINT_BOX_CAPACITY - GameConfig.INTERN_STRESS_FREE) * GameConfig.INTERN_STRESS_RATE * 10.0
	assert_lt(state.intern.stress, untrained * 0.6)


func test_resilience_softens_the_shouting() -> void:
	state.set_upgrade("shredder_service", 1)
	state.set_upgrade("intern_resilience", 40)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	var visitor := sim.spawn_visitor(true, false)
	visitor.phase = ComplaintVisitor.Phase.TO_INTERNS
	visitor.position = layout.vent_spot(visitor.slot)
	_run(4.0)
	var factor := Formulas.intern_stress_factor(state)
	var from_box := (GameConfig.COMPLAINT_BOX_CAPACITY - Formulas.intern_stress_free(state)) * GameConfig.INTERN_STRESS_RATE * 4.0
	var from_shouting := GameConfig.INTERN_YELL_RATE * (4.0 - 0.05)
	assert_lt(factor, 1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.VENTING)
	assert_almost_eq(state.intern.stress, factor * (from_box + from_shouting), 0.002)


func test_fully_resilient_intern_barely_notices_a_full_box() -> void:
	state.set_upgrade("shredder_service", 1)
	state.set_upgrade("intern_resilience", int(GameConfig.upgrade("intern_resilience").max))
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	_run(10.0)
	assert_lt(state.intern.stress, 0.01)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.DESK)


func test_trained_intern_shreds_more_complaints_per_trip() -> void:
	state.set_upgrade("shredder_service", 1)
	state.set_upgrade("intern_training", 2)
	state.complaints = 5
	state.intern.mood = ComplaintIntern.Mood.TO_SHREDDER
	state.intern.position = layout.intern_shred_point()
	sim.tick(0.05)
	assert_eq(Formulas.intern_capacity(state), int(Formulas.track_value("intern_training", 2)))
	assert_gt(Formulas.intern_capacity(state), 1)
	assert_eq(state.complaints, 5 - Formulas.intern_capacity(state))
	assert_eq(state.complaints_shredded, Formulas.intern_capacity(state))
	assert_eq(state.intern.mood, ComplaintIntern.Mood.FROM_SHREDDER)


func test_helper_breakdown_reports_its_slot() -> void:
	state.set_upgrade("shredder_service", 1)
	var helper := state.add_helper()
	helper.stress = 0.9999
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	watch_signals(sim)
	sim.tick(0.1)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [helper.slot])
	assert_eq(helper.mood, ComplaintIntern.Mood.TO_LOO)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.DESK)


func test_intern_calms_down_with_few_complaints() -> void:
	state.set_upgrade("shredder_service", 1)
	state.intern.stress = 0.5
	_run(10.0)
	assert_almost_eq(state.intern.stress, 0.5 - GameConfig.INTERN_CALM_RATE * 10.0, 0.01)
	state.intern.stress = 0.01
	_run(5.0)
	assert_eq(state.intern.stress, 0.0)


func test_intern_stays_calm_without_shredder_service() -> void:
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	_run(20.0)
	assert_eq(state.intern.stress, 0.0)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.DESK)


func test_intern_breaks_down_and_runs_to_the_toilet() -> void:
	state.set_upgrade("shredder_service", 1)
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	state.intern.stress = 0.9999
	watch_signals(sim)
	sim.tick(0.1)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.TO_LOO)
	assert_eq(state.breakdowns, 1)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [0])
	assert_true(state.intern.is_away())
	_run(layout.intern_home().distance_to(layout.intern_cry_point()) / GameConfig.INTERN_SPEED + 1.0)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.CRYING)
	assert_eq(state.intern.position, layout.intern_cry_point())


func test_shredding_pauses_while_the_intern_cries() -> void:
	state.set_upgrade("shredder_service", int(GameConfig.upgrade("shredder_service").max))
	state.complaints = 2
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	_run(Formulas.intern_cry_seconds(state) - 1.0, 0.5)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.CRYING)
	assert_eq(state.complaints, 2)
	assert_eq(state.shred_timer, 0.0)


func test_intern_returns_and_shreds_again() -> void:
	state.set_upgrade("shredder_service", int(GameConfig.upgrade("shredder_service").max))
	state.complaints = 2
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	watch_signals(sim)
	_run(Formulas.intern_cry_seconds(state) + 1.0, 0.5)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.RETURNING)
	assert_signal_emitted_with_parameters(sim, "intern_recovered", [0, false])
	_run(45.0, 0.5)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.DESK)
	assert_lte(state.intern.stress, GameConfig.INTERN_RECOVERED_STRESS)
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_shredded, 2)


func test_player_comforts_the_crying_intern() -> void:
	state.set_upgrade("shredder_service", 1)
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	state.player.position = layout.intern_cry_point()
	watch_signals(sim)
	_run(GameConfig.INTERN_COMFORT_TIME + 0.5)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.RETURNING)
	assert_almost_eq(state.intern.stress, GameConfig.INTERN_COMFORT_STRESS, 0.001)
	assert_signal_emitted_with_parameters(sim, "intern_recovered", [0, true])


func test_player_can_comfort_the_intern_while_running_away() -> void:
	state.set_upgrade("shredder_service", 1)
	state.intern.mood = ComplaintIntern.Mood.TO_LOO
	state.intern.position = layout.intern_cry_point() + Vector2(0, 30)
	state.player.position = layout.intern_cry_point()
	sim.tick(0.05)
	assert_gt(state.intern.comfort_progress, 0.0)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.TO_LOO)


func test_comfort_progress_resets_when_the_player_leaves() -> void:
	state.set_upgrade("shredder_service", 1)
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	state.player.position = layout.intern_cry_point()
	_run(1.0)
	assert_gt(state.intern.comfort_progress, 0.0)
	state.player.position = Vector2(50, 50)
	sim.tick(0.1)
	assert_eq(state.intern.comfort_progress, 0.0)
	assert_eq(state.intern.mood, ComplaintIntern.Mood.CRYING)


func test_intern_state_is_saved_and_sanitised() -> void:
	state.set_upgrade("shredder_service", 1)
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.stress = 0.7
	state.intern.timer = 12.0
	state.intern.position = layout.intern_cry_point()
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.intern.mood, ComplaintIntern.Mood.CRYING)
	assert_almost_eq(restored.intern.stress, 0.7, 0.001)
	assert_almost_eq(restored.intern.timer, 12.0, 0.001)
	assert_eq(restored.intern.position, layout.intern_cry_point())
	data.intern = {"mood": 99, "stress": 5.0, "timer": -4.0, "x": -9999.0, "y": 1e9}
	var broken := GameState.from_dict(data)
	assert_eq(broken.intern.mood, ComplaintIntern.Mood.DESK)
	assert_eq(broken.intern.stress, 1.0)
	assert_eq(broken.intern.timer, 0.0)
	assert_eq(broken.intern.position, layout.clamp_to_world(Vector2(-9999.0, 1e9)))
	data.intern = "junk"
	assert_eq(GameState.from_dict(data).intern.position, layout.intern_home())
	data.erase("intern")
	assert_eq(GameState.from_dict(data).intern.mood, ComplaintIntern.Mood.DESK)


func test_coffee_intern_hire_cost_and_limit() -> void:
	state.money = 1.0e9
	var actions := GameActions.new(state, sim)
	assert_eq(Formulas.coffee_intern_cost(state), GameConfig.COFFEE_INTERN_COST)
	assert_true(actions.hire_coffee_intern())
	assert_almost_eq(Formulas.coffee_intern_cost(state), GameConfig.COFFEE_INTERN_COST * GameConfig.COFFEE_INTERN_GROWTH, 0.001)
	assert_eq(state.staff_hired, 1)
	while state.coffee_interns.size() < GameConfig.MAX_COFFEE_INTERNS:
		assert_true(actions.hire_coffee_intern())
	assert_false(actions.can_hire_coffee_intern())
	assert_false(actions.hire_coffee_intern())
	assert_eq(state.total_staff(), GameConfig.MAX_COFFEE_INTERNS + 1)


func test_coffee_intern_cannot_be_hired_without_money() -> void:
	state.money = 0.0
	assert_false(GameActions.new(state, sim).hire_coffee_intern())
	assert_true(state.coffee_interns.is_empty())


func test_coffee_intern_serves_a_tired_clerk() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	review.moods[0].alert = Formulas.coffee_threshold(state) - 1.0
	state.add_coffee_intern()
	watch_signals(sim)
	_run(20.0, 0.1)
	assert_eq(state.coffees_served, 1)
	assert_signal_emitted_with_parameters(sim, "coffee_served", [REVIEW, 0])
	assert_gt(review.moods[0].alert, Formulas.coffee_threshold(state))
	assert_false(state.coffee_interns[0].carrying)
	assert_eq(state.coffee_interns[0].task, CoffeeIntern.Task.IDLE)


func test_coffee_intern_walks_to_the_machine_first() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	review.moods[0].alert = 10.0
	var coffee_intern := state.add_coffee_intern()
	sim.tick(0.1)
	assert_eq(coffee_intern.task, CoffeeIntern.Task.TO_MACHINE)
	assert_eq(coffee_intern.key, REVIEW)
	assert_eq(coffee_intern.desk, 0)
	_run(3.0, 0.1)
	assert_eq(coffee_intern.task, CoffeeIntern.Task.TO_DESK)
	assert_true(coffee_intern.carrying)


func test_coffee_intern_skips_resting_clerks() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	review.moods[0].alert = 10.0
	review.moods[0].rest(DeskMood.ASLEEP)
	var coffee_intern := state.add_coffee_intern()
	_run(5.0, 0.1)
	assert_eq(state.coffees_served, 0)
	assert_eq(coffee_intern.task, CoffeeIntern.Task.IDLE)


func test_coffee_intern_skips_alert_clerks() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	state.add_coffee_intern()
	_run(5.0, 0.1)
	assert_eq(state.coffees_served, 0)


func test_coffee_intern_skips_clerks_without_work() -> void:
	var review := _staff_review(2)
	review.moods[0].alert = 10.0
	state.add_coffee_intern()
	_run(5.0, 0.1)
	assert_eq(state.coffees_served, 0)


func test_coffee_intern_ignores_machines() -> void:
	var signature := state.station("general_services/signature")
	signature.moods[0].alert = 1.0
	_queue_work(state.station(REVIEW))
	state.add_coffee_intern()
	_run(5.0, 0.1)
	assert_eq(state.coffees_served, 0)


func test_two_coffee_interns_pick_different_clerks() -> void:
	var review := _staff_review(2)
	_queue_work(review, 2)
	review.moods[0].alert = 10.0
	review.moods[1].alert = 20.0
	var first := state.add_coffee_intern()
	var second := state.add_coffee_intern()
	sim.tick(0.1)
	assert_ne(first.desk, second.desk)
	assert_ne(first.desk, -1)
	assert_ne(second.desk, -1)


func test_coffee_intern_with_cup_waits_for_a_new_target() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	var coffee_intern := state.add_coffee_intern()
	coffee_intern.carrying = true
	_run(2.0, 0.1)
	assert_true(coffee_intern.carrying)
	assert_eq(coffee_intern.task, CoffeeIntern.Task.IDLE)
	review.moods[0].alert = 10.0
	_run(20.0, 0.1)
	assert_false(coffee_intern.carrying)
	assert_eq(state.coffees_served, 1)


func test_coffee_intern_drops_target_when_clerk_dozes_off() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	review.moods[0].alert = 10.0
	var coffee_intern := state.add_coffee_intern()
	sim.tick(0.1)
	_run(3.0, 0.1)
	assert_eq(coffee_intern.task, CoffeeIntern.Task.TO_DESK)
	review.moods[0].rest(DeskMood.ASLEEP)
	_run(20.0, 0.1)
	assert_eq(state.coffees_served, 0)
	assert_eq(coffee_intern.task, CoffeeIntern.Task.IDLE)
	assert_true(coffee_intern.carrying)


func test_idle_coffee_intern_returns_to_the_kitchen() -> void:
	var coffee_intern := state.add_coffee_intern()
	coffee_intern.position = layout.coffee_home() + Vector2(300, 100)
	_run(10.0, 0.1)
	assert_lt(coffee_intern.position.distance_to(layout.coffee_home()), 1.0)


func test_coffee_interns_are_saved() -> void:
	var first := state.add_coffee_intern()
	first.carrying = true
	first.position = Vector2(500, 600)
	state.add_coffee_intern()
	state.coffees_served = 7
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.coffee_interns.size(), 2)
	assert_true(restored.coffee_interns[0].carrying)
	assert_false(restored.coffee_interns[1].carrying)
	assert_eq(restored.coffee_interns[0].position, Vector2(500, 600))
	assert_eq(restored.coffees_served, 7)
	var crowd: Array = []
	for i in GameConfig.MAX_COFFEE_INTERNS + 3:
		crowd.append({"x": 1.0, "y": 2.0})
	crowd.append("junk")
	data.coffee_interns = crowd
	data.coffees_served = -5
	var clamped := GameState.from_dict(data)
	assert_eq(clamped.coffee_interns.size(), GameConfig.MAX_COFFEE_INTERNS)
	assert_eq(clamped.coffees_served, 0)


func _places(upgrade_id: String, level: int) -> int:
	return int(Formulas.track_value(upgrade_id, level))


func _max_level(upgrade_id: String) -> int:
	return int(GameConfig.upgrade(upgrade_id).max)


func _assert_track_costs_and_limit(upgrade_id: String) -> void:
	var actions := GameActions.new(state, sim)
	var config := GameConfig.upgrade(upgrade_id)
	state.money = 0.0
	assert_eq(Progression.upgrade_block_reason(state, upgrade_id), "money")
	assert_false(actions.buy_upgrade(upgrade_id))
	state.money = 1.0e12
	assert_eq(Formulas.track_cost(upgrade_id, 0), float(config.cost))
	assert_true(actions.buy_upgrade(upgrade_id))
	assert_eq(state.upgrade_level(upgrade_id), 1)
	assert_almost_eq(Formulas.track_cost(upgrade_id, 1), float(config.cost) * float(config.growth), 0.001)
	assert_true(actions.buy_upgrade(upgrade_id, "", _max_level(upgrade_id)))
	assert_eq(state.upgrade_level(upgrade_id), _max_level(upgrade_id))
	assert_eq(Progression.upgrade_block_reason(state, upgrade_id), "max")
	assert_false(actions.buy_upgrade(upgrade_id))


func test_waiting_places_extend_the_lobby() -> void:
	var base := state.lobby_capacity()
	state.set_upgrade("waiting_places", 2)
	assert_eq(state.lobby_capacity(), base + _places("waiting_places", 2))
	assert_gt(state.lobby_capacity(), base)


func test_extra_waiting_places_admit_more_citizens() -> void:
	state.set_upgrade("waiting_places", 1)
	_fill_lobby()
	assert_eq(state.station(GameConfig.RECEPTION).inbox.size(), int(GameConfig.BUILDING_STAGES[0].lobby) + _places("waiting_places", 1))
	assert_null(sim.spawn_case(state.department("general_services")))


func test_waiting_places_costs_and_limit() -> void:
	_assert_track_costs_and_limit("waiting_places")


func _seat_citizens(count: int) -> void:
	var station := state.station(REVIEW)
	while station.inbox_capacity(state.lobby_capacity()) <= count + 1:
		station.add_desk()
	for i in count:
		station.inbox.append(sim.create_case(state.department("general_services")))


func test_seat_capacity_grows_with_level() -> void:
	assert_eq(state.seat_capacity(), GameConfig.SEATING_BASE_SEATS)
	state.set_upgrade("seating", 2)
	assert_eq(state.seat_capacity(), _places("seating", 2))
	assert_gt(state.seat_capacity(), GameConfig.SEATING_BASE_SEATS)


func test_each_seating_level_adds_chairs() -> void:
	assert_eq(_places("seating", 0), GameConfig.SEATING_BASE_SEATS)
	for level in _max_level("seating"):
		assert_gt(_places("seating", level + 1), _places("seating", level), str(level))


func test_full_seating_serves_a_thousand_applications_per_minute() -> void:
	assert_gte(_places("seating", _max_level("seating")), 250)


func test_standing_places_grow_with_their_upgrade() -> void:
	assert_eq(state.standing_capacity(), 0)
	state.set_upgrade("standing_places", 3)
	assert_eq(state.standing_capacity(), _places("standing_places", 3))
	assert_gt(state.standing_capacity(), 0)


func test_standing_counts_only_citizens_beyond_the_seats() -> void:
	_seat_citizens(state.seat_capacity() - 2)
	assert_eq(state.standing_citizens(), 0)
	_seat_citizens(4)
	assert_eq(state.standing_citizens(), 2)


func test_reception_admits_into_standing_places_when_seats_are_full() -> void:
	_seat_citizens(state.seat_capacity())
	var reception := state.station(GameConfig.RECEPTION)
	reception.inbox.append(sim.create_case(state.department("general_services")))
	assert_false(state.reception_may_admit())
	state.set_upgrade("standing_places", 1)
	assert_true(state.reception_may_admit())
	assert_true(sim.start_job(reception, 0))
	_seat_citizens(state.standing_capacity())
	assert_false(state.reception_may_admit())


func test_standing_places_raise_the_number_served_at_once() -> void:
	_seat_citizens(state.seat_capacity())
	var before := ThroughputReport.seating_area(state)
	state.set_upgrade("standing_places", 2)
	var after := ThroughputReport.seating_area(state)
	assert_eq(float(after.capacity) - float(before.capacity), float(_places("standing_places", 2)))


func test_more_seats_raise_the_number_served_at_once() -> void:
	var before := ThroughputReport.seating_area(state)
	state.set_upgrade("seating", 5)
	var after := ThroughputReport.seating_area(state)
	assert_eq(float(after.capacity) - float(before.capacity), float(_places("seating", 5) - _places("seating", 0)))


func test_crowding_shortens_patience() -> void:
	assert_eq(Formulas.crowding_factor(state), 1.0)
	state.set_upgrade("standing_places", 1)
	assert_eq(Formulas.crowding_factor(state), 1.0)
	_seat_citizens(state.seat_capacity() + state.standing_capacity())
	assert_almost_eq(Formulas.crowding_factor(state), 1.0 - GameConfig.STANDING_PATIENCE_PENALTY, 0.0001)
	_seat_citizens(state.standing_capacity())
	assert_almost_eq(Formulas.crowding_factor(state), 1.0 - GameConfig.STANDING_PATIENCE_PENALTY, 0.0001)
	var waiting := sim.create_case(state.department("general_services"))
	assert_almost_eq(Formulas.citizen_patience(state, waiting, 0.5), Formulas.citizen_patience(state, waiting) * 0.5, 0.0001)


func test_crowded_queue_leaves_earlier() -> void:
	state.set_upgrade("standing_places", 1)
	_seat_citizens(state.seat_capacity() + state.standing_capacity())
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 0
	var waiting := sim.create_case(state.department("general_services"))
	waiting.waited = Formulas.patience(state) * Formulas.crowding_factor(state) + 0.01
	reception.inbox.append(waiting)
	sim.tick(0.01)
	assert_false(reception.inbox.has(waiting))


func test_full_seating_area_keeps_citizens_in_the_waiting_area() -> void:
	_seat_citizens(state.seat_capacity())
	assert_eq(state.seated_citizens(), state.seat_capacity())
	assert_false(state.has_free_seat())
	assert_not_null(sim.spawn_case(state.department("general_services")))
	assert_eq(state.walkouts, 0)
	assert_eq(state.station(GameConfig.RECEPTION).inbox.size(), 1)


func test_citizens_leave_only_when_seating_and_waiting_area_are_full() -> void:
	_seat_citizens(state.seat_capacity())
	_fill_lobby()
	assert_null(sim.spawn_case(state.department("general_services")))
	assert_eq(state.walkouts, 1)


func test_reception_waits_for_a_free_seat() -> void:
	_seat_citizens(state.seat_capacity())
	var reception := state.station(GameConfig.RECEPTION)
	reception.inbox.append(sim.create_case(state.department("general_services")))
	assert_false(state.reception_may_admit())
	assert_false(sim.start_job(reception, 0))
	state.set_upgrade("seating", 1)
	assert_true(state.reception_may_admit())
	assert_true(sim.start_job(reception, 0))


func test_reception_counts_pending_jobs_and_outbox_as_seats() -> void:
	_seat_citizens(state.seat_capacity() - 1)
	var reception := state.station(GameConfig.RECEPTION)
	assert_true(state.reception_may_admit())
	reception.outbox.append(sim.create_case(state.department("general_services")))
	assert_false(state.reception_may_admit())
	reception.outbox.clear()
	reception.jobs[0] = StationJob.new(sim.create_case(state.department("general_services")), 1.0, false)
	assert_false(state.reception_may_admit())


func test_free_seat_admits_citizens() -> void:
	_seat_citizens(state.seat_capacity() - 1)
	assert_true(state.has_free_seat())
	assert_not_null(sim.spawn_case(state.department("general_services")))


func test_extra_seating_admits_more_citizens() -> void:
	_seat_citizens(state.seat_capacity())
	state.set_upgrade("seating", 1)
	assert_true(state.has_free_seat())
	assert_not_null(sim.spawn_case(state.department("general_services")))


func test_follow_up_ignores_full_seating_area() -> void:
	_seat_citizens(state.seat_capacity())
	assert_not_null(sim.spawn_case(state.department("general_services"), true))


func test_carried_cases_occupy_seats() -> void:
	var case_file := sim.create_case(state.department("general_services"))
	state.player.items.append(case_file)
	assert_eq(state.seated_citizens(), 1)


func test_seating_costs_and_limit() -> void:
	_assert_track_costs_and_limit("seating")


func test_standing_places_costs_and_limit() -> void:
	_assert_track_costs_and_limit("standing_places")


func test_seating_upgrade_is_saved_and_clamped() -> void:
	state.set_upgrade("seating", 3)
	var data := state.to_dict()
	assert_eq(GameState.from_dict(data).upgrade_level("seating"), 3)
	data.upgrades = {"seating": 99999}
	assert_eq(GameState.from_dict(data).upgrade_level("seating"), _max_level("seating"))
	data.upgrades = {"seating": -2}
	assert_eq(GameState.from_dict(data).upgrade_level("seating"), 0)
	data.erase("upgrades")
	assert_eq(GameState.from_dict(data).upgrade_level("seating"), 0)


func test_waiting_limits_allow_far_more_than_twenty_places() -> void:
	assert_gte(_places("seating", _max_level("seating")), 60)
	var top_lobby := int(GameConfig.BUILDING_STAGES[GameConfig.BUILDING_STAGES.size() - 1].lobby) + _places("waiting_places", _max_level("waiting_places"))
	assert_eq(top_lobby, GameConfig.MAX_LOBBY_SLOTS)


func test_queue_slots_fit_inside_the_hall() -> void:
	for i in GameConfig.MAX_LOBBY_SLOTS:
		assert_true(layout.hall.has_point(layout.queue_point(i)), str(i))


func test_chair_pop_animation_overshoots_and_settles() -> void:
	assert_eq(OfficePainter.pop_scale(-1.0), 0.0)
	assert_eq(OfficePainter.pop_scale(0.0), 0.0)
	assert_eq(OfficePainter.pop_scale(OfficePainter.POP_SECONDS), 1.0)
	assert_eq(OfficePainter.pop_scale(10.0), 1.0)
	var peak := 0.0
	for step in 20:
		peak = maxf(peak, OfficePainter.pop_scale(OfficePainter.POP_SECONDS * step / 20.0))
	assert_gt(peak, 1.0)


func test_reputation_losses_are_mild() -> void:
	assert_gte(GameConfig.REP_WALKED_OUT, -0.3)
	assert_lte(GameConfig.REVIEW_DRAIN * GameConfig.MAX_NEGATIVE_REVIEWS * 60.0, 0.25)


func test_seat_grid_fits_inside_the_hall() -> void:
	var total := mini(_places("seating", _max_level("seating")), WorldLayout.MAX_VISIBLE_SEATS)
	assert_gt(total, GameConfig.SEATING_BASE_SEATS)
	for i in total:
		assert_true(layout.waiting_area.has_point(layout.waiting_seat(i)))
	assert_true(layout.hall.encloses(layout.seating_sign_rect()))
	for key in [GameConfig.RECEPTION, GameConfig.COUNTER]:
		for i in total:
			assert_false(layout.area(key).has_point(layout.waiting_seat(i)), key)
	for i in total:
		for j in range(i + 1, total):
			assert_gt(layout.waiting_seat(i).distance_to(layout.waiting_seat(j)), 24.0)


func test_waiting_places_are_saved_and_clamped() -> void:
	state.set_upgrade("waiting_places", 3)
	state.walkouts = 4
	state.breakdowns = 2
	state.disputes_solved = 5
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.upgrade_level("waiting_places"), 3)
	assert_eq(restored.walkouts, 4)
	assert_eq(restored.breakdowns, 2)
	assert_eq(restored.disputes_solved, 5)
	data.upgrades = {"waiting_places": 99999}
	data.walkouts = -1
	assert_eq(GameState.from_dict(data).upgrade_level("waiting_places"), _max_level("waiting_places"))
	assert_eq(GameState.from_dict(data).walkouts, 0)
	data.upgrades = {"waiting_places": -3}
	assert_eq(GameState.from_dict(data).upgrade_level("waiting_places"), 0)


func test_no_dispute_before_minimum_cases() -> void:
	_staff_review(2)
	state.dispute_timer = 0.0
	_run(5.0)
	assert_true(state.disputes.is_empty())


func test_dispute_starts_when_ready() -> void:
	_staff_review(2)
	state.cases_completed = GameConfig.DISPUTE_MIN_CASES
	state.dispute_timer = 0.0
	watch_signals(sim)
	sim.tick(0.1)
	assert_eq(state.disputes.size(), 1)
	assert_eq(state.disputes[0].dept_id, "general_services")
	assert_true(GameConfig.DISPUTES.has(state.disputes[0].kind))
	assert_gt(state.dispute_timer, 0.0)
	assert_signal_emitted(sim, "dispute_started")


func test_dispute_needs_two_workers() -> void:
	state.cases_completed = GameConfig.DISPUTE_MIN_CASES
	state.dispute_timer = 0.0
	sim.tick(0.1)
	assert_true(state.disputes.is_empty())
	assert_eq(state.dispute_timer, GameConfig.DISPUTE_RETRY_SECONDS)
	assert_null(sim.start_dispute("window", "general_services"))


func test_dispute_rejects_unknown_kind_and_locked_department() -> void:
	_staff_review(2)
	assert_null(sim.start_dispute("nope", "general_services"))
	assert_null(sim.start_dispute("window", "tax_services"))
	assert_null(sim.start_dispute("window", "nope"))


func test_one_dispute_per_department() -> void:
	_staff_review(2)
	assert_not_null(sim.start_dispute("radio", "general_services"))
	assert_null(sim.start_dispute("window", "general_services"))
	assert_true(sim.dispute_candidates().is_empty())


func test_dispute_cap_limits_the_timer() -> void:
	state.unlock_department("tax_services")
	state.unlock_department("business_licences")
	for dept_id in ["general_services", "tax_services", "business_licences"]:
		var station := state.station(dept_id + "/review")
		station.add_desk()
		station.staff = 2
	assert_not_null(sim.start_dispute("radio", "general_services"))
	assert_not_null(sim.start_dispute("window", "tax_services"))
	assert_eq(state.disputes.size(), GameConfig.MAX_DISPUTES)
	state.cases_completed = GameConfig.DISPUTE_MIN_CASES
	state.dispute_timer = 0.0
	sim.tick(0.1)
	assert_eq(state.disputes.size(), GameConfig.MAX_DISPUTES)
	assert_gt(state.dispute_timer, GameConfig.DISPUTE_RETRY_SECONDS)


func test_random_dispute_picks_candidate_and_allowed_kind() -> void:
	_staff_review(2)
	var dispute := sim.start_dispute()
	assert_not_null(dispute)
	assert_eq(dispute.dept_id, "general_services")
	assert_true(Formulas.dispute_allowed(state, dispute.kind))


func test_dispute_slows_only_the_affected_human_stations() -> void:
	var review := _staff_review(2)
	state.unlock_department("tax_services")
	sim.start_dispute("thermostat", "general_services")
	assert_almost_eq(Formulas.dispute_speed(state, review), 0.8, 0.001)
	assert_eq(Formulas.dispute_speed(state, state.station("general_services/signature")), 1.0)
	assert_eq(Formulas.dispute_speed(state, state.station(GameConfig.RECEPTION)), 1.0)
	assert_eq(Formulas.dispute_speed(state, state.station("tax_services/review")), 1.0)


func test_dispute_reduces_work_progress() -> void:
	var review := _staff_review(2)
	_queue_work(review)
	sim.start_dispute("window", "general_services")
	sim.tick(0.5)
	assert_almost_eq(review.jobs[0].progress, 0.5 * 0.85, 0.001)


func test_dispute_speed_is_neutral_without_disputes() -> void:
	var review := _staff_review(2)
	assert_eq(Formulas.dispute_speed(state, review), 1.0)
	_queue_work(review)
	sim.tick(0.5)
	assert_almost_eq(review.jobs[0].progress, 0.5, 0.001)


func test_player_mediates_a_dispute() -> void:
	_staff_review(2)
	sim.start_dispute("radio", "general_services")
	state.player.position = layout.dispute_point("general_services")
	state.reputation = 1.0
	watch_signals(sim)
	_run(GameConfig.MEDIATE_TIME + 0.5)
	assert_true(state.disputes.is_empty())
	assert_eq(state.disputes_solved, 1)
	assert_almost_eq(state.reputation, 1.0 + GameConfig.MEDIATE_REPUTATION, 0.001)
	assert_signal_emitted_with_parameters(sim, "dispute_ended", ["radio", "general_services", true])


func test_mediation_progress_resets_when_the_player_walks_away() -> void:
	_staff_review(2)
	var dispute := sim.start_dispute("radio", "general_services")
	state.player.position = layout.dispute_point("general_services")
	_run(1.0)
	assert_gt(dispute.progress, 0.0)
	state.player.position = Vector2(50, 50)
	sim.tick(0.1)
	assert_eq(dispute.progress, 0.0)
	assert_eq(state.disputes.size(), 1)


func test_dispute_fizzles_out_without_mediation() -> void:
	_staff_review(2)
	var dispute := sim.start_dispute("yoghurt", "general_services")
	state.reputation = 1.0
	dispute.elapsed = GameConfig.DISPUTE_MAX_SECONDS - 0.05
	watch_signals(sim)
	sim.tick(0.1)
	assert_true(state.disputes.is_empty())
	assert_eq(state.reputation, 1.0)
	assert_signal_emitted_with_parameters(sim, "dispute_ended", ["yoghurt", "general_services", false])


func test_mediation_board_ends_quarrels_early() -> void:
	_staff_review(2)
	state.set_upgrade("mediation", 100)
	var limit := Formulas.dispute_limit(state)
	assert_eq(limit, Formulas.track_value("mediation", 100))
	assert_lt(limit, GameConfig.DISPUTE_MAX_SECONDS)
	var dispute := sim.start_dispute("stapler", "general_services")
	dispute.elapsed = limit - 0.15
	sim.tick(0.1)
	assert_eq(state.disputes.size(), 1)
	sim.tick(0.1)
	assert_true(state.disputes.is_empty())


func test_dispute_limit_shrinks_with_every_mediation_level() -> void:
	assert_eq(Formulas.dispute_limit(state), GameConfig.DISPUTE_MAX_SECONDS)
	var previous := GameConfig.DISPUTE_MAX_SECONDS
	for level in range(1, _max_level("mediation") + 1):
		state.set_upgrade("mediation", level)
		var limit := Formulas.dispute_limit(state)
		assert_eq(limit, minf(GameConfig.DISPUTE_MAX_SECONDS, Formulas.track_value("mediation", level)), str(level))
		assert_lt(limit, previous, str(level))
		previous = limit


func test_dispute_interval_scales_with_climate_control() -> void:
	assert_eq(Formulas.dispute_interval(state, 0.0), GameConfig.DISPUTE_MIN_INTERVAL)
	assert_eq(Formulas.dispute_interval(state, 1.0), GameConfig.DISPUTE_MAX_INTERVAL)
	assert_eq(Formulas.dispute_interval(state, 5.0), GameConfig.DISPUTE_MAX_INTERVAL)
	state.set_upgrade("climate_control", 75)
	assert_almost_eq(Formulas.dispute_interval(state, 0.0), GameConfig.DISPUTE_MIN_INTERVAL * Formulas.track_value("climate_control", 75), 0.001)
	assert_gt(Formulas.dispute_interval(state, 0.0), GameConfig.DISPUTE_MIN_INTERVAL)


func test_climate_control_blocks_window_and_thermostat_disputes() -> void:
	for kind in GameConfig.DISPUTES:
		assert_true(Formulas.dispute_allowed(state, kind), kind)
	var window := int(GameConfig.DISPUTES.window.climate)
	var thermostat := int(GameConfig.DISPUTES.thermostat.climate)
	assert_lt(window, thermostat)
	assert_lte(thermostat, _max_level("climate_control"))
	state.set_upgrade("climate_control", window - 1)
	assert_true(Formulas.dispute_allowed(state, "window"))
	state.set_upgrade("climate_control", window)
	assert_false(Formulas.dispute_allowed(state, "window"))
	assert_true(Formulas.dispute_allowed(state, "thermostat"))
	state.set_upgrade("climate_control", thermostat)
	assert_false(Formulas.dispute_allowed(state, "thermostat"))
	assert_true(Formulas.dispute_allowed(state, "fish_roll"))
	_staff_review(2)
	for i in 30:
		var dispute := sim.start_dispute("", "general_services")
		assert_not_null(dispute)
		assert_false(["window", "thermostat"].has(dispute.kind))
		sim.end_dispute(dispute, false)


func test_dispute_state_is_saved_and_sanitised() -> void:
	_staff_review(2)
	var dispute := sim.start_dispute("stapler", "general_services")
	dispute.elapsed = 33.0
	state.dispute_timer = 99.0
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.disputes.size(), 1)
	assert_eq(restored.disputes[0].kind, "stapler")
	assert_almost_eq(restored.disputes[0].elapsed, 33.0, 0.001)
	assert_almost_eq(restored.dispute_timer, 99.0, 0.001)
	data.disputes = [
		{"kind": "nope", "dept": "general_services"},
		{"kind": "window", "dept": "customs", "elapsed": 1.0},
		"junk",
		{"kind": "radio", "dept": "general_services", "elapsed": 1e9},
		{"kind": "window", "dept": "general_services"},
	]
	data.dispute_timer = 1e9
	var sanitised := GameState.from_dict(data)
	assert_eq(sanitised.disputes.size(), 1)
	assert_eq(sanitised.disputes[0].kind, "radio")
	assert_eq(sanitised.disputes[0].elapsed, GameConfig.DISPUTE_MAX_SECONDS)
	assert_eq(sanitised.dispute_timer, GameConfig.DISPUTE_MAX_INTERVAL * 2.0)
	data.disputes = "junk"
	assert_true(GameState.from_dict(data).disputes.is_empty())


func test_saved_disputes_respect_the_cap() -> void:
	state.unlock_department("tax_services")
	state.unlock_department("business_licences")
	var data := state.to_dict()
	data.disputes = [
		{"kind": "radio", "dept": "general_services"},
		{"kind": "window", "dept": "tax_services"},
		{"kind": "stapler", "dept": "business_licences"},
	]
	assert_eq(GameState.from_dict(data).disputes.size(), GameConfig.MAX_DISPUTES)


func test_dispute_model_basics() -> void:
	var dispute := Dispute.new("fish_roll", "tax_services")
	assert_eq(dispute.speed(), float(GameConfig.DISPUTES.fish_roll.speed))
	assert_null(Dispute.from_dict(null))
	assert_null(Dispute.from_dict({"kind": "window", "dept": "nope"}))
	assert_eq(Dispute.from_dict(dispute.to_dict()).kind, "fish_roll")


func test_guidance_leads_to_a_dispute() -> void:
	_staff_review(2)
	sim.start_dispute("window", "general_services")
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.DISPUTE)
	assert_eq(task.point, layout.dispute_point("general_services"))


func test_guidance_leads_to_the_crying_intern() -> void:
	state.set_upgrade("shredder_service", 1)
	state.intern.mood = ComplaintIntern.Mood.CRYING
	state.intern.position = layout.intern_cry_point()
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.COMFORT)
	assert_eq(task.point, layout.intern_cry_point())


func test_guidance_ignores_intern_without_shredder_service() -> void:
	state.intern.mood = ComplaintIntern.Mood.CRYING
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.COMFORT)


func test_layout_points_lie_in_their_rooms() -> void:
	assert_true(layout.complaint_office.has_point(layout.intern_home()))
	assert_true(layout.toilets.has_point(layout.intern_cry_point()))
	assert_true(layout.shredder_room.has_point(layout.intern_shred_point()))
	assert_true(layout.hall.has_point(layout.complaint_drop_spot()))
	assert_true(layout.kitchen.has_point(layout.coffee_home()))
	assert_true(layout.kitchen.has_point(layout.coffee_brew_point()))
	for slot in GameConfig.VISITOR_SLOTS:
		assert_true(layout.complaint_office.has_point(layout.visitor_spot(slot)), str(slot))
		assert_true(layout.complaint_office.has_point(layout.vent_spot(slot)), str(slot))
		assert_false(layout.near(layout.visitor_spot(slot), layout.shredder_point()))
	assert_eq(layout.visitor_spot(99), layout.visitor_spot(GameConfig.VISITOR_SLOTS - 1))
	for dept_id in GameConfig.department_ids():
		assert_true(layout.room(dept_id).has_point(layout.dispute_point(dept_id)), dept_id)


func test_new_content_is_translated_and_has_icons() -> void:
	var keys: Array[String] = [
		"STAFF_COFFEE_INTERNS", "STAFF_DESC_COFFEE_INTERNS", "FMT_COFFEE_INTERN_INFO",
		"TRACK_CLIMATE_CONTROL", "TRACK_DESC_CLIMATE_CONTROL", "TRACK_MEDIATION", "TRACK_DESC_MEDIATION",
		"SPOT_WAITING", "SPOT_DESC_WAITING", "SPOT_SEATING", "SPOT_DESC_SEATING",
		"TRACK_WAITING_PLACES", "TRACK_DESC_WAITING_PLACES", "TRACK_SEATING", "TRACK_DESC_SEATING",
		"TRACK_STANDING_PLACES", "TRACK_DESC_STANDING_PLACES", "FMT_WAITING_SIGN", "FMT_STANDING_SIGN",
		"SIGN_INTERN_AWAY", "FLOAT_INTERN_BREAKDOWN", "FLOAT_INTERN_COMFORTED", "FLOAT_INTERN_BACK",
		"FLOAT_DISPUTE_START", "FLOAT_DISPUTE_PEACE", "FLOAT_DISPUTE_OVER", "FMT_DISPUTE",
	]
	for kind in GameConfig.DISPUTES:
		assert_true(Icons.DISPUTES.has(kind), kind)
		keys.append("DISPUTE_" + kind.to_upper())
		for line in Flavor.DISPUTE_LINES:
			keys.append("DISPUTE_%s_%d" % [kind.to_upper(), line + 1])
	for dialog in GameConfig.VISITOR_DIALOGS:
		for line in GameConfig.VISITOR_LINES:
			keys.append("VISIT_%d_%d" % [dialog + 1, line + 1])
	for dialog in GameConfig.YELL_DIALOGS:
		for line in GameConfig.VISITOR_LINES:
			keys.append("YELL_%d_%d" % [dialog + 1, line + 1])
	for i in Flavor.INTERN_CRY_COUNT:
		keys.append("INTERN_CRY_%d" % (i + 1))
	for i in Flavor.INTERN_NERVOUS_COUNT:
		keys.append("INTERN_NERVOUS_%d" % (i + 1))
	for i in GameConfig.VENT_DIALOGS:
		keys.append("VENT_%d" % (i + 1))
	for i in Flavor.COFFEE_SERVED_COUNT:
		keys.append("COFFEE_SERVED_%d" % (i + 1))
	var previous := TranslationServer.get_locale()
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(previous)
	for upgrade_id in ["climate_control", "mediation", "waiting_places", "seating", "standing_places"]:
		assert_true(Icons.UPGRADES.has(upgrade_id), upgrade_id)
	assert_true(Icons.SPOTS.has("waiting"))
	assert_true(Icons.SPOTS.has("seating"))
	assert_true(Icons.STAFF.has("coffee_interns"))


func test_flavor_helpers_wrap_around() -> void:
	assert_eq(Flavor.intern_cry(0), Flavor.intern_cry(Flavor.INTERN_CRY_COUNT))
	assert_eq(Flavor.intern_nervous(-1), Flavor.intern_nervous(Flavor.INTERN_NERVOUS_COUNT - 1))
	assert_eq(Flavor.coffee_served(1), Flavor.coffee_served(1 + Flavor.COFFEE_SERVED_COUNT))
	assert_eq(Flavor.dispute_line("window", 0), Flavor.dispute_line("window", Flavor.DISPUTE_LINES))
	assert_ne(Flavor.visit_line(true, 0, 0), Flavor.visit_line(false, 0, 0))


func _hall_world(game: Game) -> WorldView:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	return world


func _look_at(game: Game, world: WorldView, point: Vector2) -> void:
	game.state.player.position = point
	world.camera = point
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)


func test_world_view_draws_the_hall_life() -> void:
	var game := Game.new(GameState.create_new(4))
	var hall_state := game.state
	hall_state.set_upgrade("shredder_service", 1)
	var world := _hall_world(game)
	game.simulation.spawn_visitor(true, false)
	game.simulation.spawn_visitor(false, false)
	for visitor in hall_state.visitors:
		visitor.phase = ComplaintVisitor.Phase.TALKING
		visitor.position = layout.visitor_spot(visitor.slot)
		visitor.duration = 9.0
		visitor.timer = 7.0
	hall_state.intern.stress = 0.8
	hall_state.complaints = 3
	hall_state.cases_completed = 1
	var coffee_intern := hall_state.add_coffee_intern()
	coffee_intern.carrying = true
	coffee_intern.position = layout.complaint_desk_point() + Vector2(-200, 0)
	await _look_at(game, world, layout.complaint_desk_point())
	for visitor in hall_state.visitors:
		visitor.phase = ComplaintVisitor.Phase.VENTING
		visitor.position = layout.vent_spot(visitor.slot)
		visitor.duration = GameConfig.VISITOR_VENT_SECONDS
		visitor.timer = GameConfig.VISITOR_VENT_SECONDS
	await _look_at(game, world, layout.complaint_desk_point())
	for visitor in hall_state.visitors:
		visitor.timer = 0.5
	await _look_at(game, world, layout.complaint_desk_point())
	assert_true(world._visitor_speaking(hall_state))
	for visitor in hall_state.visitors:
		visitor.timer = 3.0
		visitor.phase = ComplaintVisitor.Phase.LEAVING
	await _look_at(game, world, layout.complaint_desk_point())
	hall_state.intern.mood = ComplaintIntern.Mood.TO_LOO
	hall_state.intern.comfort_progress = 1.0
	await _look_at(game, world, layout.complaint_desk_point())
	hall_state.intern.mood = ComplaintIntern.Mood.CRYING
	hall_state.intern.position = layout.intern_cry_point()
	await _look_at(game, world, layout.intern_cry_point())
	coffee_intern.carrying = false
	coffee_intern.position = layout.coffee_home()
	await _look_at(game, world, layout.coffee_home())
	hall_state.intern.mood = ComplaintIntern.Mood.RETURNING
	await _look_at(game, world, layout.intern_home())
	assert_true(is_instance_valid(world))


func test_world_view_draws_disputes_and_waiting_sign() -> void:
	var game := Game.new(GameState.create_new(4))
	var dispute_state := game.state
	var review := dispute_state.station(REVIEW)
	review.add_desk()
	review.staff = 2
	var world := _hall_world(game)
	for kind in GameConfig.DISPUTES:
		dispute_state.disputes.clear()
		var dispute := Dispute.new(kind, "general_services")
		dispute.progress = 1.0
		dispute_state.disputes.append(dispute)
		await _look_at(game, world, layout.dispute_point("general_services"))
	var reception := dispute_state.station(GameConfig.RECEPTION)
	for i in dispute_state.lobby_capacity():
		reception.inbox.append(CaseFile.new("general_services"))
	await _look_at(game, world, layout.waiting_area.get_center())
	assert_true(is_instance_valid(world))


func test_world_view_reacts_to_hall_life_signals() -> void:
	var game := Game.new(GameState.create_new(4))
	var world := _hall_world(game)
	var sim_signals := game.simulation
	sim_signals.intern_broke_down.emit(0)
	sim_signals.intern_recovered.emit(0, true)
	sim_signals.intern_recovered.emit(0, false)
	sim_signals.coffee_served.emit(REVIEW, 0)
	sim_signals.dispute_started.emit("window", "general_services")
	sim_signals.dispute_ended.emit("window", "general_services", true)
	sim_signals.dispute_ended.emit("window", "general_services", false)
	assert_gt(world._floaters.size(), 4)
	world._advance_effects(10.0)
	assert_true(world._floaters.is_empty())
	for i in 12:
		sim_signals.coffee_served.emit(REVIEW, 0)
	assert_lte(world._floaters.size(), WorldView.MAX_FLAVOR_FLOATERS + 1)


func test_world_view_floats_above_the_intern_concerned() -> void:
	var game := Game.new(GameState.create_new(4))
	var world := _hall_world(game)
	var helper := game.state.add_helper()
	helper.position = layout.intern_cry_point(helper.slot)
	var above := Vector2(0, -60)
	game.simulation.intern_broke_down.emit(helper.slot)
	assert_eq(world._floaters[-1].pos, helper.position + above)
	game.simulation.intern_recovered.emit(helper.slot, true)
	assert_eq(world._floaters[-1].pos, helper.position + above)
	game.simulation.intern_recovered.emit(helper.slot, false)
	assert_eq(world._floaters[-1].pos, layout.intern_home(helper.slot) + above)
	game.simulation.intern_broke_down.emit(GameConfig.MAX_HELPERS + 1)
	assert_eq(world._floaters[-1].pos, layout.intern_home(GameConfig.MAX_HELPERS + 1) + above)


func test_spot_sheets_offer_the_new_upgrades() -> void:
	var game := Game.new(GameState.create_new(4))
	game.state.money = 1.0e9
	var previous_amount := UpgradeEntryCard.amount_index
	UpgradeEntryCard.amount_index = 0
	var sheets: Array[Sheet] = []
	for spot in ["coffee_interns", "waiting", "seating"]:
		var sheet := SpotSheet.new().setup(game, spot)
		add_child_autofree(sheet)
		sheets.append(sheet)
	await wait_physics_frames(2)
	assert_true(UpgradeEntryCard.buy(game, "staff:coffee_interns"))
	assert_true(UpgradeEntryCard.buy(game, "track:waiting_places"))
	assert_true(UpgradeEntryCard.buy(game, "track:seating"))
	assert_true(UpgradeEntryCard.buy(game, "track:standing_places"))
	for sheet in sheets:
		sheet.refresh()
	UpgradeEntryCard.amount_index = previous_amount
	assert_eq(game.state.coffee_interns.size(), 1)
	assert_eq(game.state.upgrade_level("waiting_places"), 1)
	assert_eq(game.state.upgrade_level("seating"), 1)
	assert_eq(game.state.upgrade_level("standing_places"), 1)


func test_complaint_visitors_have_at_least_thirty_distinct_dialogs() -> void:
	assert_gte(GameConfig.VISITOR_DIALOGS + GameConfig.YELL_DIALOGS, 30)
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		var openers := {}
		for angry in [false, true]:
			var count := GameConfig.YELL_DIALOGS if angry else GameConfig.VISITOR_DIALOGS
			for dialog in count:
				var opener := Flavor.visit_line(angry, dialog, 0)
				assert_false(openers.has(opener), "%s: %s" % [locale, opener])
				openers[opener] = true
		assert_eq(openers.size(), GameConfig.VISITOR_DIALOGS + GameConfig.YELL_DIALOGS)
	TranslationServer.set_locale(original)


func test_spawned_visitors_use_every_dialog_range() -> void:
	var seen := {}
	for i in 600:
		var visitor := sim.spawn_visitor(false, false)
		if visitor != null:
			seen[visitor.dialog] = true
			state.visitors.clear()
	assert_gt(seen.size(), GameConfig.VISITOR_DIALOGS * 0.5)
	for dialog: int in seen:
		assert_between(dialog, 0, GameConfig.VISITOR_DIALOGS - 1)


func _ruckus_ready() -> Station:
	state.cases_completed = GameConfig.RUCKUS_MIN_CASES
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	reception.inbox.append(sim.create_case(state.department("general_services")))
	assert_true(sim.start_job(reception, 0))
	return reception


func test_ruckus_starts_on_a_reception_job_and_halts_the_reception() -> void:
	var reception := _ruckus_ready()
	watch_signals(sim)
	assert_true(sim.start_ruckus())
	assert_true(state.has_ruckus())
	assert_eq(state.ruckus_desk, 0)
	assert_signal_emitted_with_parameters(sim, "ruckus_started", [0])
	assert_false(sim.start_ruckus())
	assert_true(sim.is_halted(reception))
	assert_false(sim.is_halted(state.station(REVIEW)))
	var progress := reception.jobs[0].progress
	state.player.position = Vector2(-500, -500)
	_run(5.0)
	assert_eq(reception.jobs[0].progress, progress)
	assert_false(sim.work_desk(reception, 0, 10.0))
	assert_true(state.has_ruckus())


func test_ruckus_needs_a_citizen_at_the_reception() -> void:
	assert_false(sim.start_ruckus())
	var reception := state.station(GameConfig.RECEPTION)
	var follow_up := sim.create_case(state.department("general_services"), true)
	follow_up.mail = true
	reception.jobs[0] = StationJob.new(follow_up, 1.0, false)
	assert_false(follow_up.takes_seat())
	assert_false(sim.start_ruckus())
	state.stations.erase(GameConfig.RECEPTION)
	assert_false(sim.start_ruckus())


func test_player_calms_the_ruckus_by_standing_there() -> void:
	_ruckus_ready()
	sim.start_ruckus()
	watch_signals(sim)
	state.player.position = layout.ruckus_point(0)
	_run(GameConfig.RUCKUS_CALM_TIME * 0.5)
	assert_true(state.has_ruckus())
	assert_gt(state.ruckus_progress, 0.0)
	state.player.position = Vector2(-500, -500)
	sim.tick(0.05)
	assert_eq(state.ruckus_progress, 0.0)
	state.player.position = layout.ruckus_point(0)
	_run(GameConfig.RUCKUS_CALM_TIME + 0.2)
	assert_false(state.has_ruckus())
	assert_eq(state.ruckus_calmed, 1)
	assert_signal_emitted_with_parameters(sim, "ruckus_calmed", [0])
	assert_false(sim.calm_ruckus())


func test_ruckus_timer_starts_ruckus_only_after_enough_cases() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	reception.staff = 1
	state.player.position = Vector2(-500, -500)
	state.ruckus_timer = 0.0
	reception.jobs[0] = StationJob.new(sim.create_case(state.department("general_services")), 1.0e6, false)
	sim.tick(0.05)
	assert_false(state.has_ruckus())
	assert_eq(state.ruckus_timer, 0.0)
	state.cases_completed = GameConfig.RUCKUS_MIN_CASES
	sim.tick(0.05)
	assert_true(state.has_ruckus())
	assert_gte(state.ruckus_timer, GameConfig.RUCKUS_MIN_INTERVAL - 0.1)


func test_ruckus_timer_retries_without_a_reception_job() -> void:
	state.cases_completed = GameConfig.RUCKUS_MIN_CASES
	state.station(GameConfig.RECEPTION).staff = 0
	state.ruckus_timer = 0.0
	sim.tick(0.05)
	assert_false(state.has_ruckus())
	assert_eq(state.ruckus_timer, GameConfig.RUCKUS_RETRY_SECONDS)


func test_guards_make_ruckus_rarer() -> void:
	var base := Formulas.ruckus_interval(state, 0.0)
	assert_eq(base, GameConfig.RUCKUS_MIN_INTERVAL)
	assert_eq(Formulas.ruckus_interval(state, 1.0), GameConfig.RUCKUS_MAX_INTERVAL)
	assert_eq(Formulas.ruckus_interval(state, 5.0), GameConfig.RUCKUS_MAX_INTERVAL)
	state.guards = 2
	assert_almost_eq(Formulas.ruckus_interval(state, 0.0), base * (1.0 + 2.0 * GameConfig.RUCKUS_GUARD_RELIEF), 0.001)


func test_guidance_points_to_the_ruckus() -> void:
	_ruckus_ready()
	sim.start_ruckus()
	state.player.position = layout.ruckus_point(0) + Vector2(5, 0)
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.RUCKUS)
	assert_eq(task.point, layout.ruckus_point(0))


func test_ruckus_is_saved_and_repaired() -> void:
	_ruckus_ready()
	sim.start_ruckus()
	state.ruckus_calmed = 3
	state.ruckus_timer = 42.0
	var loaded := GameState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(loaded.ruckus_desk, 0)
	assert_eq(loaded.ruckus_calmed, 3)
	assert_eq(loaded.ruckus_timer, 42.0)
	assert_eq(loaded.ruckus_progress, 0.0)
	var data := state.to_dict()
	data.ruckus_desk = 99
	data.ruckus_calmed = -1
	data.ruckus_timer = -5.0
	var repaired := GameState.from_dict(data)
	assert_eq(repaired.ruckus_desk, -1)
	assert_eq(repaired.ruckus_calmed, 0)
	assert_eq(repaired.ruckus_timer, 0.0)
	data.erase("ruckus_desk")
	data.erase("ruckus_calmed")
	data.erase("ruckus_timer")
	var legacy := GameState.from_dict(data)
	assert_false(legacy.has_ruckus())
	assert_eq(legacy.ruckus_timer, GameConfig.RUCKUS_FIRST_SECONDS)


func test_ruckus_and_standing_texts_exist() -> void:
	assert_eq(Flavor.ruckus_line(0), TranslationServer.translate("RUCKUS_1"))
	assert_eq(Flavor.ruckus_line(Flavor.RUCKUS_COUNT), TranslationServer.translate("RUCKUS_1"))
	var keys: Array[String] = ["FLOAT_RUCKUS_START", "FLOAT_RUCKUS_CALMED", "LABEL_RUCKUS", "FMT_STANDING_SIGN"]
	for index in Flavor.RUCKUS_COUNT:
		keys.append("RUCKUS_%d" % (index + 1))
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)
