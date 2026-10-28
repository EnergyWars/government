extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
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
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func _staff(count: int) -> void:
	state.set_upgrade("complaint_interns", count)
	for unit in state.interns:
		unit.position = layout.intern_home(unit.slot)


func _run_until(condition: Callable, limit: float = 120.0, step: float = 0.05) -> bool:
	var elapsed := 0.0
	while elapsed < limit:
		if condition.call():
			return true
		sim.tick(step)
		elapsed += step
	return condition.call()


func test_new_game_starts_with_an_unstaffed_counter() -> void:
	assert_eq(state.interns.size(), 0)
	assert_eq(state.interns_at_desk(), 0)
	assert_null(sim.desk_intern())


func test_complaints_go_straight_into_the_box_without_interns() -> void:
	sim.submit_complaint()
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_absorbed, 0)


func test_buying_interns_staffs_the_counter_up_to_three() -> void:
	state.money = 1e9
	for i in GameConfig.MAX_DESK_INTERNS:
		assert_true(actions.buy_upgrade("complaint_interns"))
	assert_false(actions.buy_upgrade("complaint_interns"))
	assert_eq(state.interns.size(), GameConfig.MAX_DESK_INTERNS)
	assert_eq(state.staff_hired, GameConfig.MAX_DESK_INTERNS)
	for index in state.interns.size():
		assert_eq(state.interns[index].slot, index)
		assert_true(state.interns[index].is_at_desk())


func test_lowering_the_level_removes_interns_from_the_end() -> void:
	_staff(3)
	state.interns[0].handled = 1
	state.set_upgrade("complaint_interns", 1)
	assert_eq(state.interns.size(), 1)
	assert_eq(state.interns[0].handled, 1)


func test_intern_fends_off_a_complaint_instead_of_the_box() -> void:
	_staff(1)
	watch_signals(sim)
	sim.submit_complaint()
	assert_eq(state.complaints, 0)
	assert_eq(state.interns[0].handled, 1)
	assert_eq(state.complaints_absorbed, 1)
	assert_signal_emitted_with_parameters(sim, "complaint_absorbed", [0])


func test_untrained_intern_cries_after_two_complaints() -> void:
	_staff(1)
	watch_signals(sim)
	sim.submit_complaint()
	assert_true(state.interns[0].is_at_desk())
	sim.submit_complaint()
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.TO_LOO)
	assert_eq(state.breakdowns, 1)
	assert_signal_emitted_with_parameters(sim, "intern_broke_down", [0])
	sim.submit_complaint()
	assert_eq(state.complaints, 1)


func test_steadfast_interns_hold_out_for_up_to_eight_complaints() -> void:
	_staff(1)
	state.set_upgrade("intern_steadfast", int(GameConfig.upgrade("intern_steadfast").max))
	assert_eq(Formulas.intern_steadfast(state), GameConfig.INTERN_MAX_STEADFAST)
	for i in GameConfig.INTERN_MAX_STEADFAST - 1:
		sim.submit_complaint()
	assert_true(state.interns[0].is_at_desk())
	sim.submit_complaint()
	assert_true(state.interns[0].is_away())


func test_complaints_go_to_the_least_burdened_intern() -> void:
	_staff(3)
	state.set_upgrade("intern_steadfast", 6)
	for i in 3:
		sim.submit_complaint()
	for unit in state.interns:
		assert_eq(unit.handled, 1)
	state.interns[1].handled = 0
	assert_eq(sim.desk_intern(), state.interns[1])


func test_crying_interns_never_recover_on_their_own() -> void:
	_staff(1)
	sim.submit_complaint()
	sim.submit_complaint()
	_run(300.0, 0.25)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.CRYING)
	assert_eq(state.interns[0].position, layout.intern_cry_point(0))
	assert_eq(state.interns[0].handled, GameConfig.INTERN_BASE_STEADFAST)


func test_comforting_brings_the_intern_back_with_fresh_nerves() -> void:
	_staff(1)
	sim.submit_complaint()
	sim.submit_complaint()
	assert_true(_run_until(func() -> bool: return state.interns[0].mood == ComplaintIntern.Mood.CRYING))
	watch_signals(sim)
	state.player.position = layout.intern_cry_point(0)
	_run(GameConfig.INTERN_COMFORT_TIME + 0.1)
	assert_eq(state.interns[0].handled, 0)
	assert_signal_emitted_with_parameters(sim, "intern_recovered", [0, true])
	state.player.position = Vector2(50, 50)
	assert_true(_run_until(func() -> bool: return state.interns[0].is_at_desk()))
	assert_eq(state.interns[0].position, layout.intern_home(0))


func test_comfort_progress_resets_when_the_player_walks_away() -> void:
	_staff(1)
	state.interns[0].mood = ComplaintIntern.Mood.CRYING
	state.interns[0].position = layout.intern_cry_point(0)
	state.player.position = layout.intern_cry_point(0)
	_run(GameConfig.INTERN_COMFORT_TIME * 0.5)
	assert_gt(state.interns[0].comfort_progress, 0.0)
	state.player.position = Vector2(50, 50)
	_run(0.1)
	assert_eq(state.interns[0].comfort_progress, 0.0)
	assert_eq(state.interns[0].mood, ComplaintIntern.Mood.CRYING)


func test_visitor_without_interns_drops_the_complaint_into_the_box() -> void:
	var visitor := sim.spawn_visitor(false, true)
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.complaints, 1)


func test_visitor_at_a_staffed_counter_is_fended_off() -> void:
	_staff(1)
	var visitor := sim.spawn_visitor(false, true)
	assert_true(_run_until(func() -> bool: return visitor.phase == ComplaintVisitor.Phase.TALKING))
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.complaints, 0)
	assert_eq(state.interns[0].handled, 1)


func test_angry_shouter_wears_the_intern_down_without_filing() -> void:
	_staff(1)
	var visitor := sim.spawn_visitor(true, false)
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.interns[0].handled, 1)
	assert_eq(state.complaints, 0)


func test_visitor_goes_to_the_box_when_the_intern_breaks_down_meanwhile() -> void:
	_staff(1)
	var visitor := sim.spawn_visitor(false, true)
	assert_true(_run_until(func() -> bool: return visitor.phase == ComplaintVisitor.Phase.TALKING))
	state.interns[0].mood = ComplaintIntern.Mood.CRYING
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.complaints, 1)


func test_amnesty_sends_visitors_home_without_wearing_interns_down() -> void:
	_staff(1)
	state.boosts["complaint_amnesty"] = 100.0
	var visitor := sim.spawn_visitor(true, true)
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.interns[0].handled, 0)
	assert_eq(state.complaints, 0)
	sim.submit_complaint()
	assert_eq(state.complaints, 0)


func test_player_at_the_counter_earns_respect_instead_of_complaints() -> void:
	state.player.position = layout.complaint_player_point()
	assert_true(sim.player_at_complaint_counter())
	watch_signals(sim)
	var visitor := sim.spawn_visitor(false, true)
	assert_true(_run_until(func() -> bool: return visitor.phase == ComplaintVisitor.Phase.TALKING))
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.complaints, 0)
	assert_eq(state.visitors_respected, 1)
	assert_signal_emitted_with_parameters(sim, "visitor_respected", [visitor.slot])


func test_player_spot_is_inside_the_office_and_apart_from_the_interns() -> void:
	var spot := layout.complaint_player_point()
	assert_true(layout.complaint_office.has_point(spot))
	assert_true(layout.complaint_read_rect().grow(GameConfig.INTERACT_RADIUS).has_point(spot))
	for slot in GameConfig.MAX_DESK_INTERNS:
		assert_gt(spot.distance_to(layout.intern_home(slot)), 40.0, str(slot))
	state.player.position = spot
	assert_true(sim.player_at_complaint_counter())
	state.player.position = layout.intern_home(GameConfig.MAX_DESK_INTERNS - 1) + Vector2(GameConfig.INTERACT_RADIUS * 2.0, 0.0)
	assert_false(sim.player_at_complaint_counter())


func test_player_at_the_counter_calms_angry_shouters_and_spares_interns() -> void:
	_staff(1)
	state.player.position = layout.complaint_player_point()
	var shouter := sim.spawn_visitor(true, false)
	var raging := sim.spawn_visitor(true, true)
	assert_true(_run_until(func() -> bool: return not state.visitors.has(shouter) and not state.visitors.has(raging)))
	assert_eq(state.interns[0].handled, 0)
	assert_eq(state.complaints, 0)
	assert_eq(state.visitors_respected, 2)


func test_player_at_the_counter_stops_complaints_without_a_free_spot() -> void:
	state.player.position = layout.complaint_player_point()
	sim.submit_complaint()
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_absorbed, 0)


func test_respect_ends_when_the_player_leaves_the_counter() -> void:
	state.player.position = layout.complaint_player_point()
	var visitor := sim.spawn_visitor(false, true)
	assert_true(_run_until(func() -> bool: return visitor.phase == ComplaintVisitor.Phase.TALKING))
	state.player.position = Vector2(50, 50)
	assert_false(sim.player_at_complaint_counter())
	assert_true(_run_until(func() -> bool: return not state.visitors.has(visitor)))
	assert_eq(state.complaints, 1)
	assert_eq(state.visitors_respected, 0)


func test_respect_counter_survives_saving() -> void:
	state.visitors_respected = 7
	assert_eq(GameState.from_dict(state.to_dict()).visitors_respected, 7)
	var data := state.to_dict()
	data.erase("visitors_respected")
	assert_eq(GameState.from_dict(data).visitors_respected, 0)
	data["visitors_respected"] = -3
	assert_eq(GameState.from_dict(data).visitors_respected, 0)


func test_box_runs_need_the_upgrade() -> void:
	_staff(2)
	state.complaints = 3
	_run(5.0)
	for unit in state.interns:
		assert_true(unit.is_at_desk())
	assert_eq(state.complaints, 3)


func test_one_intern_always_stays_at_the_counter() -> void:
	_staff(1)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 3
	_run(5.0)
	assert_true(state.interns[0].is_at_desk())
	assert_eq(state.complaints, 3)


func test_intern_empties_the_box_into_the_shredder() -> void:
	_staff(2)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 3
	var money := state.money
	watch_signals(sim)
	sim.tick(0.05)
	assert_true(state.interns[0].is_at_desk())
	assert_eq(state.interns[1].mood, ComplaintIntern.Mood.TO_BOX)
	assert_true(_run_until(func() -> bool: return state.interns[1].mood == ComplaintIntern.Mood.TO_SHREDDER))
	assert_eq(state.interns[1].carried, 1)
	assert_eq(state.complaints, 2)
	assert_true(_run_until(func() -> bool: return state.interns[1].mood == ComplaintIntern.Mood.FROM_SHREDDER))
	assert_eq(state.interns[1].carried, 0)
	assert_eq(state.complaints_shredded, 1)
	assert_almost_eq(state.money, money + GameConfig.COMPLAINT_REWARD, 0.001)
	assert_signal_emitted_with_parameters(sim, "complaint_shredded", [false])


func test_trained_runs_carry_up_to_six_complaints() -> void:
	_staff(2)
	state.set_upgrade("intern_box_runs", GameConfig.MAX_INTERN_RUN)
	assert_eq(Formulas.intern_run_size(state), GameConfig.MAX_INTERN_RUN)
	state.complaints = 10
	assert_true(_run_until(func() -> bool: return state.interns[1].mood == ComplaintIntern.Mood.TO_SHREDDER))
	assert_eq(state.interns[1].carried, GameConfig.MAX_INTERN_RUN)
	assert_eq(state.complaints, 10 - GameConfig.MAX_INTERN_RUN)


func test_only_needed_runners_leave_the_counter() -> void:
	_staff(3)
	state.set_upgrade("intern_box_runs", 2)
	state.complaints = 2
	_run(0.2)
	var running := state.interns.filter(func(unit: ComplaintIntern) -> bool: return unit.mood == ComplaintIntern.Mood.TO_BOX)
	assert_eq(running.size(), 1)
	assert_eq(state.interns[2].mood, ComplaintIntern.Mood.TO_BOX)


func test_two_runners_when_the_box_needs_it() -> void:
	_staff(3)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 5
	_run(0.2)
	assert_true(state.interns[0].is_at_desk())
	assert_eq(state.interns[1].mood, ComplaintIntern.Mood.TO_BOX)
	assert_eq(state.interns[2].mood, ComplaintIntern.Mood.TO_BOX)


func test_runner_returns_empty_handed_when_the_box_was_emptied() -> void:
	_staff(2)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 1
	sim.tick(0.05)
	state.complaints = 0
	assert_true(_run_until(func() -> bool: return state.interns[1].mood != ComplaintIntern.Mood.TO_BOX))
	assert_eq(state.interns[1].mood, ComplaintIntern.Mood.RETURNING)
	assert_eq(state.complaints_shredded, 0)


func test_intern_speed_spans_one_hundred_levels() -> void:
	_staff(1)
	assert_almost_eq(Formulas.intern_speed(state), GameConfig.INTERN_SPEED, 0.001)
	assert_eq(int(GameConfig.upgrade("intern_speed").max), GameConfig.INTERN_SPEED_LEVELS)
	var slow := Formulas.intern_trip_time(state)
	state.set_upgrade("intern_speed", GameConfig.INTERN_SPEED_LEVELS)
	assert_almost_eq(Formulas.intern_speed(state), GameConfig.INTERN_SPEED * (1.0 + GameConfig.INTERN_SPEED_STEP * GameConfig.INTERN_SPEED_LEVELS), 0.001)
	assert_lt(Formulas.intern_trip_time(state), slow)


func test_faster_interns_finish_runs_sooner() -> void:
	_staff(2)
	state.set_upgrade("intern_box_runs", 1)
	state.complaints = 1
	var slow := 0.0
	while state.complaints_shredded == 0 and slow < 60.0:
		sim.tick(0.05)
		slow += 0.05
	before_each()
	_staff(2)
	state.set_upgrade("intern_box_runs", 1)
	state.set_upgrade("intern_speed", GameConfig.INTERN_SPEED_LEVELS)
	state.complaints = 1
	var fast := 0.0
	while state.complaints_shredded == 0 and fast < 60.0:
		sim.tick(0.05)
		fast += 0.05
	assert_lt(fast, slow)


func test_track_ranges_match_the_design() -> void:
	assert_eq(int(GameConfig.upgrade("complaint_interns").max), 3)
	assert_eq(Formulas.track_value("intern_steadfast", 0), 2.0)
	assert_eq(Formulas.track_value("intern_steadfast", int(GameConfig.upgrade("intern_steadfast").max)), 8.0)
	assert_eq(Formulas.track_value("intern_box_runs", 0), 0.0)
	assert_eq(Formulas.track_value("intern_box_runs", 1), 1.0)
	assert_eq(Formulas.track_value("intern_box_runs", GameConfig.MAX_INTERN_RUN), 6.0)
	assert_eq(Formulas.track_value("complaint_box", 0), float(GameConfig.COMPLAINT_BOX_CAPACITY))
	assert_eq(Formulas.track_value("complaint_box", GameConfig.COMPLAINT_BOX_LEVELS), float(GameConfig.COMPLAINT_BOX_CAPACITY + GameConfig.COMPLAINT_BOX_STEP * GameConfig.COMPLAINT_BOX_LEVELS))


func test_upgrades_need_interns_first() -> void:
	state.money = 1e9
	assert_eq(Progression.upgrade_block_reason(state, "intern_steadfast"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "intern_speed"), "requires")
	assert_eq(Progression.upgrade_block_reason(state, "intern_box_runs"), "requires")
	state.set_upgrade("complaint_interns", 1)
	assert_eq(Progression.upgrade_block_reason(state, "intern_steadfast"), "")
	assert_eq(Progression.upgrade_block_reason(state, "intern_box_runs"), "requires")
	state.set_upgrade("complaint_interns", 2)
	assert_eq(Progression.upgrade_block_reason(state, "intern_box_runs"), "")


func test_all_complaint_upgrades_are_listed_in_the_office() -> void:
	var ids: Array[String] = []
	for entry in UpgradeCatalog.entries_for_spot(state, UpgradeCatalog.ROOM_PREFIX + GameConfig.ROOM_COMPLAINTS):
		ids.append(entry.target)
	for upgrade_id in ["complaint_interns", "intern_steadfast", "intern_speed", "complaint_box", "intern_box_runs", "complaint_security", "security_training"]:
		assert_has(ids, upgrade_id)
		assert_eq(GameConfig.spot_room(str(GameConfig.upgrade(upgrade_id).spot)), GameConfig.ROOM_COMPLAINTS, upgrade_id)


func test_counter_and_box_sit_side_by_side_in_the_office() -> void:
	var office := layout.complaint_office
	var counter := layout.complaint_counter_rect()
	assert_true(office.encloses(counter))
	var box := layout.complaint_box_point()
	assert_true(office.has_point(box))
	assert_gt(box.x, counter.end.x)
	assert_between(box.y, counter.position.y - 40.0, counter.end.y + 40.0)
	for slot in GameConfig.MAX_DESK_INTERNS:
		assert_lt(layout.intern_home(slot).y, counter.position.y)
		assert_gt(layout.visitor_spot(slot).y, counter.end.y)
		assert_true(office.has_point(layout.intern_box_point(slot)))
	assert_gt(layout.intern_trip_length(), 0.0)


func test_intern_state_survives_saving() -> void:
	_staff(2)
	state.interns[0].handled = 1
	state.interns[1].mood = ComplaintIntern.Mood.CRYING
	state.interns[1].handled = 2
	state.interns[1].position = layout.intern_cry_point(1)
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.interns.size(), 2)
	assert_eq(restored.interns[0].handled, 1)
	assert_eq(restored.interns[1].mood, ComplaintIntern.Mood.CRYING)
	assert_eq(restored.interns[1].slot, 1)
	assert_eq(restored.interns[1].position, layout.intern_cry_point(1))


func test_running_interns_return_after_loading() -> void:
	_staff(2)
	state.interns[1].mood = ComplaintIntern.Mood.TO_SHREDDER
	state.interns[1].carried = 3
	var restored := GameState.from_dict(state.to_dict())
	assert_eq(restored.interns[1].mood, ComplaintIntern.Mood.RETURNING)
	assert_eq(restored.interns[1].carried, 0)


func test_broken_intern_data_is_sanitised() -> void:
	_staff(2)
	var data := state.to_dict()
	data.interns = [{"mood": 99, "handled": 99, "x": -9999.0, "y": 1e9}, "junk", {}]
	var restored := GameState.from_dict(data)
	assert_eq(restored.interns.size(), 2)
	assert_eq(restored.interns[0].mood, ComplaintIntern.Mood.DESK)
	assert_eq(restored.interns[0].handled, GameConfig.INTERN_MAX_STEADFAST)
	assert_eq(restored.interns[0].position, layout.clamp_to_world(Vector2(-9999.0, 1e9)))
	assert_eq(restored.interns[1].position, layout.intern_home(1))
	data.interns = "junk"
	assert_eq(GameState.from_dict(data).interns.size(), 2)


func test_interns_count_as_staff() -> void:
	var before := state.total_staff()
	_staff(3)
	assert_eq(state.total_staff(), before + 3)


func test_desk_status_lists_every_intern() -> void:
	_staff(2)
	state.interns[1].handled = 1
	var lines := SpotStatus.lines(state, "complaint_desk")
	assert_eq(lines.size(), 3)
	assert_true(lines[2].contains("1/%d" % Formulas.intern_steadfast(state)))


func test_intern_strain_follows_steadfastness() -> void:
	var unit := ComplaintIntern.new(Vector2.ZERO)
	assert_eq(WorldView.intern_strain(unit, 2), 0.0)
	unit.handled = 1
	assert_almost_eq(WorldView.intern_strain(unit, 2), 0.5, 0.001)
	unit.handled = 9
	assert_eq(WorldView.intern_strain(unit, 2), 1.0)
	assert_eq(WorldView.intern_strain(unit, 0), 1.0)


func test_report_counts_box_runners() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	_staff(1)
	state.set_upgrade("intern_box_runs", 3)
	assert_eq(ThroughputReport.complaint_capacity(state), 0.0)
	_staff(3)
	var trip := layout.intern_trip_length() / Formulas.intern_speed(state)
	assert_almost_eq(ThroughputReport.complaint_capacity(state), 2.0 * 3.0 / trip, 0.0001)
	var area := ThroughputReport.complaint_area(state)
	var ids: Array = (area.upgrades as Array).map(func(upgrade: Dictionary) -> String: return str(upgrade.entry))
	assert_has(ids, "track:intern_box_runs")
	assert_has(ids, "track:intern_speed")
	assert_has(ids, "track:complaint_security")
	assert_does_not_have(ids, "track:complaint_interns")


func test_upgrading_the_box_adds_space_and_stops_at_max() -> void:
	var config := GameConfig.upgrade("complaint_box")
	var max_level := int(config.max)
	var step := int(config.step)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY)
	state.money = 0.0
	assert_false(actions.buy_upgrade("complaint_box"))
	state.money = 1.0e12
	var first := Formulas.track_cost("complaint_box", 0)
	assert_eq(first, float(config.cost) * Formulas.early_discount(0))
	assert_true(actions.buy_upgrade("complaint_box"))
	assert_almost_eq(state.money, 1.0e12 - first, 0.01)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + step)
	assert_true(actions.buy_upgrade("complaint_box", "", max_level))
	assert_eq(state.upgrade_level("complaint_box"), max_level)
	assert_eq(Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_CAPACITY + step * max_level)
	assert_eq(Progression.upgrade_block_reason(state, "complaint_box"), "max")


func test_full_box_turns_complaints_into_reviews() -> void:
	state.complaints = Formulas.complaint_cap(state)
	watch_signals(sim)
	sim.submit_complaint()
	assert_eq(state.complaints, Formulas.complaint_cap(state))
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [true])
	assert_eq(state.negative_review_count(), 1)


func test_office_lies_beside_the_hall_with_a_door_to_it() -> void:
	var office := layout.complaint_office
	assert_eq(office.end.y, layout.hall.end.y)
	assert_gt(office.position.x, layout.hall.end.x)
	assert_eq(layout.office_door().x, office.position.x)
	assert_true(office.encloses(layout.complaint_read_rect()))
	assert_true(layout.complaint_read_rect().has_point(layout.complaint_desk_point()))
	assert_false(layout.complaint_read_rect().has_point(layout.complaint_box_point()))
	assert_eq(layout.spot_at(layout.complaint_desk_point()), "complaint_desk")
	assert_eq(layout.spot_at(layout.complaint_box_point()), "complaint_box")
	assert_true(office.has_point(layout.complaint_drop_spot()))
	assert_true(layout.near(layout.complaint_drop_spot(), layout.complaint_box_point()))
	var homes := {}
	for slot in GameConfig.MAX_DESK_INTERNS:
		assert_false(homes.has(layout.intern_home(slot)))
		homes[layout.intern_home(slot)] = true
		assert_true(layout.complaint_counter_rect().grow(20.0).has_point(Vector2(layout.intern_home(slot).x, layout.complaint_counter_rect().position.y)))
		assert_true(layout.shredder_room.has_point(layout.intern_shred_point(slot)))
	assert_eq(layout.intern_home(99), layout.intern_home(GameConfig.MAX_DESK_INTERNS - 1))
	assert_eq(layout.intern_box_point(99), layout.intern_box_point(GameConfig.MAX_DESK_INTERNS - 1))


func test_closed_sign_stays_clear_of_the_complaint_spots() -> void:
	var sign := layout.closed_sign_rect()
	for point in [layout.complaint_box_point(), layout.complaint_desk_point(), layout.complaint_drop_spot(), layout.security_post(), layout.security_stop_spot()]:
		assert_false(sign.has_point(point))


func test_complaint_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["ROOM_COMPLAINT_OFFICE", "ROOM_DESC_COMPLAINT_OFFICE", "FMT_STATUS_COMPLAINT_DESK", "FMT_STATUS_COMPLAINT_BOX", "FMT_INTERN_STATUS", "FMT_INTERN_NAME", "FMT_SECURITY_INFO", "STATUS_NO_SECURITY", "SIGN_DESK_EMPTY", "STATS_SECURITY_NONE", "ACTION_READ_COMPLAINTS"]
	for upgrade_id: String in ["complaint_interns", "intern_steadfast", "intern_speed", "complaint_box", "intern_box_runs", "complaint_security", "security_training"]:
		keys.append("TRACK_" + upgrade_id.to_upper())
		keys.append("TRACK_DESC_" + upgrade_id.to_upper())
	for spot: String in ["complaint_desk", "complaint_box", "security"]:
		keys.append("SPOT_" + spot.to_upper())
		keys.append(UpgradeTexts.spot_description_key(spot))
	for mood: String in ComplaintIntern.Mood.keys():
		keys.append("INTERN_MOOD_" + mood)
	var previous := TranslationServer.get_locale()
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
	TranslationServer.set_locale(previous)


func test_office_header_sheet_lists_every_complaint_upgrade() -> void:
	var game := Game.new(GameState.create_new(4))
	var sheet := SpotSheet.new()
	sheet.setup(game, UpgradeCatalog.ROOM_PREFIX + GameConfig.ROOM_COMPLAINTS)
	add_child_autofree(sheet)
	await wait_physics_frames(2)
	for spot in ["complaint_desk", "complaint_box", "security"]:
		assert_true(_has_label(sheet.content, UpgradeTexts.spot_title(spot)), spot)
	for upgrade_id in ["complaint_interns", "intern_steadfast", "intern_speed", "complaint_box", "intern_box_runs", "complaint_security", "security_training"]:
		assert_true(_has_label(sheet.content, sheet.tr("TRACK_" + upgrade_id.to_upper())), upgrade_id)


func test_upgrades_sheet_nests_the_office_upgrades_by_spot() -> void:
	var entries := UpgradeCatalog.entries(state)
	var grouped := UpgradesSheet.grouped(entries, "rooms")
	var office: Array[UpgradeEntry] = []
	office.assign(grouped.get(GameConfig.ROOM_COMPLAINTS, []))
	var spots := UpgradeCatalog.spots_of(office)
	assert_eq(spots, ["complaint_desk", "complaint_box", "security"])


func test_world_view_draws_the_counter_with_working_and_crying_interns() -> void:
	var game := Game.new(GameState.create_new(4))
	game.state.set_upgrade("complaint_interns", 3)
	game.state.interns[0].handled = 1
	game.state.interns[1].mood = ComplaintIntern.Mood.CRYING
	game.state.interns[2].mood = ComplaintIntern.Mood.TO_SHREDDER
	game.state.interns[2].carried = 2
	game.state.complaints = 4
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	for point in [layout.complaint_desk_point(), layout.intern_cry_point(1)]:
		game.state.player.position = point
		world.camera = point
		world._process(0.1)
		world.queue_redraw()
		await wait_physics_frames(2)
	assert_true(is_instance_valid(world))


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false
