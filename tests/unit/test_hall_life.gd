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
	state.complaint_letter_timer = 1e6
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
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_BOX)
	assert_eq(state.complaints, 0)
	_run(_walk_seconds(desk, layout.complaint_drop_spot()) + 1.0)
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_absorbed, 0)
	assert_false(visitor.files_complaint)
	_run(maxf(_walk_seconds(desk, layout.door_out()), _walk_seconds(layout.complaint_drop_spot(), layout.door_out())) + 2.0)
	assert_true(state.visitors.is_empty())


func _visitor_at_the_desk(angry: bool, files_complaint: bool) -> ComplaintVisitor:
	var visitor := sim.spawn_visitor(angry, files_complaint)
	visitor.position = layout.visitor_spot(visitor.slot)
	sim.tick(0.05)
	return visitor


func _finish_talk(visitor: ComplaintVisitor) -> void:
	visitor.timer = 0.0
	sim.tick(0.05)


func test_intern_at_the_desk_fends_off_the_complaint() -> void:
	state.set_upgrade("complaint_interns", 1)
	var visitor := _visitor_at_the_desk(false, true)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	assert_almost_eq(visitor.duration, GameConfig.VISITOR_TALK_SECONDS, 0.001)
	assert_true(visitor.files_complaint)
	assert_eq(state.interns[0].handled, 0)
	watch_signals(sim)
	_finish_talk(visitor)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_false(visitor.files_complaint)
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_absorbed, 1)
	assert_eq(state.interns[0].handled, 1)
	assert_signal_emitted_with_parameters(sim, "complaint_absorbed", [0])
	assert_signal_not_emitted(sim, "complaint_filed")


func test_visitor_uses_the_box_when_the_intern_cries_meanwhile() -> void:
	state.set_upgrade("complaint_interns", 1)
	var visitor := _visitor_at_the_desk(false, true)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	state.interns[0].mood = ComplaintIntern.Mood.CRYING
	_finish_talk(visitor)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_BOX)
	assert_eq(state.complaints_absorbed, 0)
	visitor.position = layout.complaint_drop_spot()
	watch_signals(sim)
	sim.tick(0.05)
	assert_eq(state.complaints, 1)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [false])


func test_security_stops_visitors_before_the_desk() -> void:
	state.set_upgrade("complaint_security", 1)
	state.set_upgrade("security_training", GameConfig.SECURITY_LEVELS)
	assert_almost_eq(Formulas.security_chance(state), GameConfig.SECURITY_MAX_CHANCE, 0.001)
	var stopped := 0
	for attempt in 200:
		state.visitors.clear()
		var visitor := sim.spawn_visitor(false, true)
		if visitor.is_stopped():
			stopped += 1
			assert_false(visitor.files_complaint)
			assert_false(visitor.is_at_clerk())
	assert_between(stopped, 130, 190)
	state.visitors.clear()
	var guarded: ComplaintVisitor = null
	while guarded == null:
		guarded = sim.spawn_visitor(true, true)
		if not guarded.is_stopped():
			state.visitors.clear()
			guarded = null
	watch_signals(sim)
	guarded.position = layout.security_stop_spot()
	sim.tick(0.05)
	assert_eq(guarded.phase, ComplaintVisitor.Phase.STOPPED)
	assert_eq(state.visitors_stopped, 1)
	assert_signal_emitted_with_parameters(sim, "visitor_stopped", [true])
	_run(GameConfig.SECURITY_STOP_SECONDS + 0.5)
	assert_eq(guarded.phase, ComplaintVisitor.Phase.LEAVING)
	assert_eq(state.complaints, 0)


func test_without_interns_the_visitor_walks_straight_to_the_box() -> void:
	var visitor := _visitor_at_the_desk(false, true)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TO_BOX)
	_run(_walk_seconds(visitor.position, layout.complaint_drop_spot()) + 1.0)
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_absorbed, 0)


func test_angry_visitor_without_interns_just_leaves() -> void:
	var visitor := _visitor_at_the_desk(true, false)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)


func test_angry_visitor_vents_but_files_nothing() -> void:
	state.set_upgrade("complaint_interns", 1)
	var visitor := _visitor_at_the_desk(true, false)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	assert_almost_eq(visitor.duration, GameConfig.VISITOR_ANGRY_TALK_SECONDS, 0.001)
	_run(GameConfig.VISITOR_ANGRY_TALK_SECONDS + 0.5)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_eq(state.complaints, 0)
	assert_eq(state.interns[0].handled, 1)


func test_amnesty_sends_the_visitor_home_after_the_clerk() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.seals = 10
	assert_true(Boosts.new(state, sim).use("complaint_amnesty", Boosts.SEALS))
	var visitor := _visitor_at_the_desk(false, true)
	_finish_talk(visitor)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_false(visitor.files_complaint)
	assert_eq(state.complaints_absorbed, 0)
	assert_eq(state.interns[0].handled, 0)


func test_visitor_frees_the_clerk_slot_once_past_the_desk() -> void:
	var first := sim.spawn_visitor(false, false)
	for i in GameConfig.VISITOR_SLOTS - 1:
		sim.spawn_visitor(false, false)
	assert_true(first.is_at_clerk())
	first.phase = ComplaintVisitor.Phase.TO_BOX
	assert_false(first.is_at_clerk())
	var next := sim.spawn_visitor(false, false)
	assert_not_null(next)
	assert_eq(next.slot, first.slot)
	for phase in [ComplaintVisitor.Phase.TO_BOX, ComplaintVisitor.Phase.LEAVING, ComplaintVisitor.Phase.STOPPED]:
		first.phase = phase
		assert_false(first.is_at_clerk(), str(phase))
	first.phase = ComplaintVisitor.Phase.ARRIVING
	first.stopped = true
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
	state.set_upgrade("complaint_interns", 1)
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
	assert_eq(state.complaints, 1)
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


func test_intern_counts_the_complaint_only_after_the_talk() -> void:
	state.set_upgrade("complaint_interns", 1)
	var visitor := sim.spawn_visitor(true, false)
	visitor.position = layout.visitor_spot(visitor.slot)
	_run(3.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.TALKING)
	assert_eq(state.interns[0].handled, 0)
	assert_eq(state.complaints_absorbed, 0)


func test_normal_visitor_without_complaint_does_not_wear_the_intern_down() -> void:
	state.set_upgrade("complaint_interns", 1)
	var visitor := sim.spawn_visitor(false, false)
	_run(_walk_seconds(layout.door_in(), layout.visitor_spot(visitor.slot)) + GameConfig.VISITOR_TALK_SECONDS + 1.0)
	assert_eq(visitor.phase, ComplaintVisitor.Phase.LEAVING)
	assert_eq(state.interns[0].handled, 0)
	assert_eq(state.complaints_absorbed, 0)


func test_a_full_box_does_not_wear_the_intern_down() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.complaints = Formulas.complaint_cap(state)
	_run(10.0)
	assert_eq(state.interns[0].handled, 0)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)
	assert_eq(state.complaints, Formulas.complaint_cap(state))


func test_every_submitted_complaint_counts_for_the_desk_intern() -> void:
	state.set_upgrade("complaint_interns", 1)
	sim.submit_complaint()
	assert_eq(state.complaints_absorbed, 1)
	assert_eq(state.interns[0].handled, 1)
	assert_eq(state.complaints, 0)


func test_intern_endures_a_few_complaints_before_crying() -> void:
	state.set_upgrade("complaint_interns", 1)
	var steadfast := Formulas.intern_steadfast(state)
	assert_eq(steadfast, GameConfig.INTERN_BASE_STEADFAST)
	assert_gte(steadfast, 2)
	assert_lte(GameConfig.INTERN_MAX_STEADFAST, 8)
	for i in steadfast - 1:
		sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)
	assert_eq(state.interns[0].handled, steadfast - 1)
	sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.TO_LOO)
	assert_eq(state.breakdowns, 1)


func test_steadfast_upgrade_raises_the_breaking_point() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.set_upgrade("intern_steadfast", 3)
	assert_eq(Formulas.intern_steadfast(state), GameConfig.INTERN_BASE_STEADFAST + 3)
	for i in Formulas.intern_steadfast(state) - 1:
		sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)
	sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.TO_LOO)


func test_fully_steadfast_intern_endures_the_maximum() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.set_upgrade("intern_steadfast", int(GameConfig.upgrade("intern_steadfast").max))
	assert_eq(Formulas.intern_steadfast(state), GameConfig.INTERN_MAX_STEADFAST)
	for i in GameConfig.INTERN_MAX_STEADFAST - 1:
		sim.submit_complaint()
	assert_eq(state.interns[0].handled, GameConfig.INTERN_MAX_STEADFAST - 1)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)


func test_trained_interns_empty_more_complaints_per_run() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 2)
	assert_eq(Formulas.intern_run_size(state), 2)
	state.complaints = 5
	sim.tick(0.05)
	var runner := state.interns[1]
	assert_eq(runner.mood, ComplaintIntern.Mood.TO_BOX)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)
	runner.position = layout.intern_box_point(runner.slot)
	sim.tick(0.05)
	assert_eq(runner.mood, ComplaintIntern.Mood.TO_SHREDDER)
	assert_eq(runner.carried, 2)
	assert_eq(state.complaints, 3)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)
	runner.position = layout.intern_shred_point(runner.slot)
	sim.tick(0.05)
	assert_eq(state.complaints_shredded, 2)
	assert_eq(runner.carried, 0)
	assert_eq(runner.mood, ComplaintIntern.Mood.FROM_SHREDDER)


func test_complaints_go_to_the_least_worn_intern() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.interns[0].handled = 1
	watch_signals(sim)
	sim.submit_complaint()
	assert_eq(state.interns[1].handled, 1)
	assert_eq(state.interns[0].handled, 1)
	sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.TO_LOO)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [0])
	sim.submit_complaint()
	assert_eq(state.interns[1].mood, ComplaintIntern.Mood.TO_LOO)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [1])
	assert_null(sim.desk_intern())
	sim.submit_complaint()
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_absorbed, 3)
	assert_eq(state.breakdowns, 2)


func test_intern_does_not_recover_on_its_own() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.interns[0].handled = 1
	_run(30.0, 0.5)
	assert_eq(state.interns[0].handled, 1)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.DESK)


func test_complaints_stay_in_the_box_without_interns() -> void:
	state.complaints = Formulas.complaint_cap(state)
	_run(20.0)
	assert_true(state.interns.is_empty())
	assert_eq(state.complaints, Formulas.complaint_cap(state))
	assert_eq(state.complaints_shredded, 0)


func test_intern_breaks_down_and_runs_to_the_toilet() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.interns[0].handled = Formulas.intern_steadfast(state) - 1
	watch_signals(sim)
	sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.TO_LOO)
	assert_eq(state.breakdowns, 1)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [0])
	assert_true(state.interns[0].is_away())
	_run(layout.intern_home().distance_to(layout.intern_cry_point()) / Formulas.intern_speed(state) + 1.0)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.CRYING)
	assert_lt(state.interns[0].position.distance_to(layout.intern_cry_point()), 1.0)


func test_crying_intern_never_recovers_on_its_own() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 2
	var crying := state.interns[1]
	crying.mood = ComplaintIntern.Mood.CRYING
	crying.handled = Formulas.intern_steadfast(state)
	crying.position = layout.intern_cry_point(crying.slot)
	watch_signals(sim)
	_run(120.0, 0.5)
	assert_eq(crying.mood, ComplaintIntern.Mood.CRYING)
	assert_eq(crying.handled, Formulas.intern_steadfast(state))
	assert_eq(state.complaints, 2)
	assert_signal_not_emitted(sim, "intern_recovered")


func test_comforted_intern_returns_and_empties_the_box_again() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 2
	var crying := state.interns[1]
	crying.mood = ComplaintIntern.Mood.CRYING
	crying.handled = Formulas.intern_steadfast(state)
	crying.position = layout.intern_cry_point(crying.slot)
	state.player.position = crying.position
	watch_signals(sim)
	_run(GameConfig.INTERN_COMFORT_TIME + 0.5)
	assert_eq(crying.mood, ComplaintIntern.Mood.RETURNING)
	assert_eq(crying.handled, 0)
	assert_signal_emitted_with_parameters(sim, "intern_recovered", [1, true])
	state.player.position = Vector2(50, 50)
	_run(90.0, 0.1)
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_shredded, 2)
	for unit in state.interns:
		assert_eq(unit.mood, ComplaintIntern.Mood.DESK)


func test_player_comforts_the_crying_intern() -> void:
	state.set_upgrade("complaint_interns", 1)
	var intern := state.interns[0]
	intern.mood = ComplaintIntern.Mood.CRYING
	intern.handled = Formulas.intern_steadfast(state)
	intern.position = layout.intern_cry_point()
	state.player.position = layout.intern_cry_point()
	watch_signals(sim)
	_run(GameConfig.INTERN_COMFORT_TIME + 0.5)
	assert_eq(intern.mood, ComplaintIntern.Mood.RETURNING)
	assert_eq(intern.handled, 0)
	assert_eq(intern.comfort_progress, 0.0)
	assert_signal_emitted_with_parameters(sim, "intern_recovered", [0, true])


func test_player_can_comfort_the_intern_while_running_away() -> void:
	state.set_upgrade("complaint_interns", 1)
	var intern := state.interns[0]
	intern.mood = ComplaintIntern.Mood.TO_LOO
	intern.position = layout.intern_cry_point() + Vector2(0, 30)
	state.player.position = layout.intern_cry_point()
	sim.tick(0.05)
	assert_gt(intern.comfort_progress, 0.0)
	assert_eq(intern.mood, ComplaintIntern.Mood.TO_LOO)


func test_comfort_progress_resets_when_the_player_leaves() -> void:
	state.set_upgrade("complaint_interns", 1)
	var intern := state.interns[0]
	intern.mood = ComplaintIntern.Mood.CRYING
	intern.position = layout.intern_cry_point()
	state.player.position = layout.intern_cry_point()
	_run(1.0)
	assert_gt(intern.comfort_progress, 0.0)
	state.player.position = Vector2(50, 50)
	sim.tick(0.1)
	assert_eq(intern.comfort_progress, 0.0)
	assert_eq(intern.mood, ComplaintIntern.Mood.CRYING)


func test_intern_state_is_saved_and_sanitised() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.interns[0].mood = ComplaintIntern.Mood.TO_SHREDDER
	state.interns[1].mood = ComplaintIntern.Mood.CRYING
	state.interns[1].handled = 1
	state.interns[1].position = layout.intern_cry_point(1)
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.interns.size(), 2)
	assert_eq(restored.interns[0].mood, ComplaintIntern.Mood.RETURNING)
	assert_eq(restored.interns[1].mood, ComplaintIntern.Mood.CRYING)
	assert_eq(restored.interns[1].handled, 1)
	assert_eq(restored.interns[1].slot, 1)
	assert_eq(restored.interns[1].position, layout.intern_cry_point(1))
	data.interns = [{"mood": 99, "handled": 50, "x": -9999.0, "y": 1e9}, "junk"]
	var broken := GameState.from_dict(data)
	assert_eq(broken.interns[0].mood, ComplaintIntern.Mood.DESK)
	assert_eq(broken.interns[0].handled, GameConfig.INTERN_MAX_STEADFAST)
	assert_eq(broken.interns[0].position, layout.clamp_to_world(Vector2(-9999.0, 1e9)))
	assert_eq(broken.interns[1].position, layout.intern_home(1))
	data.interns = "junk"
	assert_eq(GameState.from_dict(data).interns[0].position, layout.intern_home(0))
	data.erase("interns")
	var fresh := GameState.from_dict(data)
	assert_eq(fresh.interns.size(), 2)
	assert_eq(fresh.interns[1].mood, ComplaintIntern.Mood.DESK)


func test_coffee_intern_hire_cost_and_limit() -> void:
	state.money = 1.0e9
	var actions := GameActions.new(state, sim)
	assert_eq(Formulas.coffee_intern_cost(state), GameConfig.COFFEE_INTERN_COST)
	_staff_review(1)
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


func test_seat_capacity_grows_with_level() -> void:
	assert_eq(state.seat_capacity(), GameConfig.BASE_SEATS)
	state.set_upgrade("seating", 2)
	assert_eq(state.seat_capacity(), _places("seating", 2))
	assert_eq(state.seat_capacity() + state.standing_capacity(), GameConfig.WAITING_PLACES)


func test_each_seating_level_turns_a_standing_place_into_a_seat() -> void:
	assert_eq(_places("seating", 0), GameConfig.BASE_SEATS)
	for level in _max_level("seating"):
		assert_eq(_places("seating", level + 1), _places("seating", level) + 1, str(level))
	assert_eq(_places("seating", _max_level("seating")), GameConfig.WAITING_PLACES)


func test_more_seats_raise_the_seated_capacity() -> void:
	var before := ThroughputReport.seating_area(state)
	state.set_upgrade("seating", 5)
	var after := ThroughputReport.seating_area(state)
	assert_eq(float(after.capacity) - float(before.capacity), 5.0)
	assert_eq(float(ThroughputReport.standing_area(state).capacity), float(GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS - 5))


func test_seating_costs_and_limit() -> void:
	_assert_track_costs_and_limit("seating")


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


func test_seat_grid_fits_inside_the_waiting_rooms() -> void:
	var total := _places("seating", _max_level("seating"))
	assert_eq(total, GameConfig.WAITING_PLACES)
	for room in GameConfig.WAITING_ROOMS:
		var rect := layout.waiting_room(room)
		for i in total:
			assert_true(layout.place_area(room).has_point(layout.waiting_seat(i, room)), room)
		assert_true(rect.encloses(layout.seating_sign_rect(room)), room)
		assert_true(rect.encloses(layout.standing_sign_rect(room)), room)
		assert_false(layout.place_area(room).intersects(layout.seating_sign_rect(room)), room)
		for key in [GameConfig.RECEPTION, GameConfig.COUNTER]:
			assert_false(layout.area(key).intersects(layout.place_area(room)), key)
		for i in total:
			for j in range(i + 1, total):
				assert_gt(layout.waiting_seat(i, room).distance_to(layout.waiting_seat(j, room)), 24.0)
	assert_eq(layout.standing_point(0, 10), layout.waiting_seat(10))
	assert_eq(layout.standing_point(3, 10, GameConfig.HALL_PICKUP), layout.waiting_seat(13, GameConfig.HALL_PICKUP))


func test_seating_and_hall_counters_are_saved_and_clamped() -> void:
	state.set_upgrade("seating", 3)
	state.walkouts = 4
	state.breakdowns = 2
	state.disputes_solved = 5
	var data := state.to_dict()
	var restored := GameState.from_dict(data)
	assert_eq(restored.upgrade_level("seating"), 3)
	assert_eq(restored.walkouts, 4)
	assert_eq(restored.breakdowns, 2)
	assert_eq(restored.disputes_solved, 5)
	data.upgrades = {"seating": 99999}
	data.walkouts = -1
	assert_eq(GameState.from_dict(data).upgrade_level("seating"), _max_level("seating"))
	assert_eq(GameState.from_dict(data).walkouts, 0)
	data.upgrades = {"seating": -3}
	assert_eq(GameState.from_dict(data).upgrade_level("seating"), 0)


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
	assert_almost_eq(Formulas.dispute_speed(state, state.station("general_services/signature")), 0.8, 0.001)
	assert_eq(Formulas.dispute_speed(state, state.station(GameConfig.RECEPTION)), 1.0)
	assert_eq(Formulas.dispute_speed(state, state.station("tax_services/review")), 1.0)
	var tax_review := state.station("tax_services/review")
	tax_review.add_desk()
	tax_review.staff = 2
	assert_not_null(sim.start_dispute("thermostat", "tax_services"))
	assert_almost_eq(Formulas.dispute_speed(state, tax_review), 0.8, 0.001)
	assert_true(state.station("tax_services/signature").machine)
	assert_eq(Formulas.dispute_speed(state, state.station("tax_services/signature")), 1.0)


func test_dispute_reduces_work_progress() -> void:
	var review := _staff_review(GameConfig.DISPUTE_CREW + 1)
	_queue_work(review)
	sim.start_dispute("window", "general_services")
	var worker := GameConfig.DISPUTE_CREW
	assert_true(review.moods[worker].is_on_duty())
	sim.tick(0.5)
	assert_almost_eq(review.jobs[worker].progress, 0.5 * 0.85, 0.001)


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
	state.set_upgrade("complaint_interns", 1)
	state.interns[0].mood = ComplaintIntern.Mood.CRYING
	state.interns[0].position = layout.intern_cry_point()
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.COMFORT)
	assert_eq(task.point, layout.intern_cry_point())


func test_guidance_ignores_interns_at_the_desk() -> void:
	state.set_upgrade("complaint_interns", 1)
	state.interns[0].handled = 1
	assert_ne(Guidance.next_task(state).get("action", ""), Guidance.COMFORT)


func test_layout_points_lie_in_their_rooms() -> void:
	assert_true(layout.complaint_office.has_point(layout.intern_home()))
	assert_true(layout.toilets.has_point(layout.intern_cry_point()))
	assert_true(layout.shredder_room.has_point(layout.intern_shred_point()))
	assert_true(layout.complaint_office.has_point(layout.complaint_drop_spot()))
	assert_true(layout.kitchen.has_point(layout.coffee_home()))
	assert_true(layout.kitchen.has_point(layout.coffee_brew_point()))
	for slot in GameConfig.VISITOR_SLOTS:
		assert_true(layout.complaint_office.has_point(layout.visitor_spot(slot)), str(slot))
		assert_false(layout.near(layout.visitor_spot(slot), layout.shredder_point()))
	assert_eq(layout.visitor_spot(99), layout.visitor_spot(GameConfig.VISITOR_SLOTS - 1))
	for dept_id in GameConfig.department_ids():
		assert_true(layout.room(dept_id).has_point(layout.dispute_point(dept_id)), dept_id)


func test_new_content_is_translated_and_has_icons() -> void:
	var keys: Array[String] = [
		"STAFF_COFFEE_INTERNS", "STAFF_DESC_COFFEE_INTERNS", "FMT_COFFEE_INTERN_INFO",
		"TRACK_CLIMATE_CONTROL", "TRACK_DESC_CLIMATE_CONTROL", "TRACK_MEDIATION", "TRACK_DESC_MEDIATION",
		"SPOT_SEATING", "SPOT_DESC_SEATING", "TRACK_SEATING", "TRACK_DESC_SEATING", "FMT_SEATING_SIGN", "FMT_STANDING_SIGN",
		"TRACK_TICKET_SPEED", "TRACK_DESC_TICKET_SPEED", "TRACK_TICKET_SPEED_2", "TRACK_DESC_TICKET_SPEED_2",
		"TRACK_TICKET_SPEED_3", "TRACK_DESC_TICKET_SPEED_3", "TRACK_TICKET_MACHINE_2", "TRACK_DESC_TICKET_MACHINE_2",
		"TRACK_TICKET_MACHINE_3", "TRACK_DESC_TICKET_MACHINE_3", "FMT_EFFECT_PER_SECOND", "FMT_REQ_TRACK_LEVEL",
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
	for i in Flavor.COFFEE_SERVED_COUNT:
		keys.append("COFFEE_SERVED_%d" % (i + 1))
	var previous := TranslationServer.get_locale()
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(previous)
	for upgrade_id in ["climate_control", "mediation", "seating", "ticket_speed", "ticket_machine_2", "ticket_speed_2", "ticket_machine_3", "ticket_speed_3"]:
		assert_true(Icons.UPGRADES.has(upgrade_id), upgrade_id)
	assert_false(Icons.SPOTS.has("waiting"))
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
	hall_state.set_upgrade("complaint_interns", 2)
	var world := _hall_world(game)
	game.simulation.spawn_visitor(true, false)
	game.simulation.spawn_visitor(false, false)
	for visitor in hall_state.visitors:
		visitor.phase = ComplaintVisitor.Phase.TALKING
		visitor.position = layout.visitor_spot(visitor.slot)
		visitor.duration = 9.0
		visitor.timer = 7.0
	hall_state.interns[0].handled = 1
	hall_state.interns[1].mood = ComplaintIntern.Mood.TO_SHREDDER
	hall_state.interns[1].carried = 2
	hall_state.complaints = 3
	hall_state.cases_completed = 1
	var coffee_intern := hall_state.add_coffee_intern()
	coffee_intern.carrying = true
	coffee_intern.position = layout.complaint_desk_point() + Vector2(-200, 0)
	await _look_at(game, world, layout.complaint_desk_point())
	for visitor in hall_state.visitors:
		visitor.timer = 0.5
	await _look_at(game, world, layout.complaint_desk_point())
	assert_true(world._visitor_speaking(hall_state))
	var guarded := hall_state.visitors[0]
	guarded.stopped = true
	guarded.phase = ComplaintVisitor.Phase.STOPPED
	guarded.position = layout.security_stop_spot()
	guarded.duration = GameConfig.SECURITY_STOP_SECONDS
	guarded.timer = 2.0
	var filer := hall_state.visitors[1]
	filer.phase = ComplaintVisitor.Phase.TO_BOX
	filer.position = layout.complaint_drop_spot()
	await _look_at(game, world, layout.complaint_desk_point())
	await _look_at(game, world, layout.security_stop_spot())
	for visitor in hall_state.visitors:
		visitor.timer = 3.0
		visitor.phase = ComplaintVisitor.Phase.LEAVING
	await _look_at(game, world, layout.complaint_desk_point())
	hall_state.interns[0].mood = ComplaintIntern.Mood.TO_LOO
	hall_state.interns[0].comfort_progress = 1.0
	await _look_at(game, world, layout.complaint_desk_point())
	hall_state.interns[0].mood = ComplaintIntern.Mood.CRYING
	hall_state.interns[0].position = layout.intern_cry_point()
	await _look_at(game, world, layout.intern_cry_point())
	coffee_intern.carrying = false
	coffee_intern.position = layout.coffee_home()
	await _look_at(game, world, layout.coffee_home())
	hall_state.interns[0].mood = ComplaintIntern.Mood.RETURNING
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
	await _look_at(game, world, layout.place_area(GameConfig.HALL_INTAKE).get_center())
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
	game.state.set_upgrade("complaint_interns", 2)
	var unit := game.state.interns[1]
	unit.position = layout.intern_cry_point(unit.slot)
	var above := Vector2(0, -60)
	game.simulation.intern_broke_down.emit(unit.slot)
	assert_eq(world._floaters[-1].pos, unit.position + above)
	game.simulation.intern_recovered.emit(unit.slot, true)
	assert_eq(world._floaters[-1].pos, unit.position + above)
	game.simulation.intern_recovered.emit(unit.slot, false)
	assert_eq(world._floaters[-1].pos, layout.intern_home(unit.slot) + above)
	game.simulation.intern_broke_down.emit(GameConfig.MAX_DESK_INTERNS + 1)
	assert_eq(world._floaters[-1].pos, layout.intern_home(GameConfig.MAX_DESK_INTERNS + 1) + above)


func test_spot_sheets_offer_the_new_upgrades() -> void:
	var game := Game.new(GameState.create_new(4))
	game.state.money = 1.0e9
	var previous_amount := UpgradeEntryCard.amount_index
	UpgradeEntryCard.amount_index = 0
	var sheets: Array[Sheet] = []
	for spot in ["coffee_interns", "seating", "tickets"]:
		var sheet := SpotSheet.new().setup(game, spot)
		add_child_autofree(sheet)
		sheets.append(sheet)
	await wait_physics_frames(2)
	assert_true(UpgradeEntryCard.buy(game, "staff:coffee_interns"))
	assert_true(UpgradeEntryCard.buy(game, "track:seating"))
	assert_true(UpgradeEntryCard.buy(game, "track:ticket_speed"))
	assert_false(UpgradeEntryCard.buy(game, "track:ticket_machine_2"))
	for sheet in sheets:
		sheet.refresh()
	UpgradeEntryCard.amount_index = previous_amount
	assert_eq(game.state.coffee_interns.size(), 1)
	assert_eq(game.state.upgrade_level("seating"), 1)
	assert_eq(game.state.upgrade_level("ticket_speed"), 1)
	assert_eq(game.state.upgrade_level("ticket_machine_2"), 0)


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


func test_security_makes_ruckus_rarer() -> void:
	var base := Formulas.ruckus_interval(state, 0.0)
	assert_eq(base, GameConfig.RUCKUS_MIN_INTERVAL)
	assert_eq(Formulas.ruckus_interval(state, 1.0), GameConfig.RUCKUS_MAX_INTERVAL)
	assert_eq(Formulas.ruckus_interval(state, 5.0), GameConfig.RUCKUS_MAX_INTERVAL)
	state.set_upgrade("complaint_security", 1)
	assert_almost_eq(Formulas.ruckus_interval(state, 0.0), base * (1.0 + GameConfig.RUCKUS_SECURITY_RELIEF), 0.001)


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
