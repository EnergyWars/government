extends GutTest

const REVIEW := "general_services/review"

var state: GameState
var sim: Simulation
var actions: GameActions
var layout: WorldLayout


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
	state.praise_timer = 1e6
	state.player.position = Vector2(50, 50)


func _review() -> Station:
	return state.station(REVIEW)


func _staff_review(count: int) -> Station:
	var review := _review()
	while review.desks < count:
		review.add_desk()
	review.staff = count
	return review


func _case() -> CaseFile:
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.step = case_file.route.find(REVIEW)
	return case_file


func _fill_outbox(station: Station) -> void:
	while station.outbox.size() < station.outbox_capacity():
		station.outbox.append(_case())


func test_only_department_reviews_can_jam() -> void:
	assert_true(_review().produces_rejects())
	assert_false(state.station(GameConfig.RECEPTION).produces_rejects())
	assert_false(state.station(GameConfig.COUNTER).produces_rejects())
	assert_false(state.station(GameConfig.PHOTO_STATION).produces_rejects())
	var counter := state.station(GameConfig.COUNTER)
	counter.rejects = counter.reject_capacity()
	assert_false(counter.is_output_jammed())


func test_full_outbox_or_full_reject_pile_jams_the_review() -> void:
	var review := _review()
	assert_false(review.is_output_jammed())
	_fill_outbox(review)
	assert_true(review.is_output_jammed())
	review.outbox.pop_back()
	assert_false(review.is_output_jammed())
	review.rejects = review.reject_capacity()
	assert_true(review.is_output_jammed())
	review.rejects -= 1
	assert_false(review.is_output_jammed())


func test_jam_sends_the_whole_team_to_lunch_or_coffee_talk() -> void:
	var review := _staff_review(3)
	watch_signals(sim)
	_fill_outbox(review)
	sim.tick(GameConfig.TICK)
	for desk in review.staff:
		var mood := review.moods[desk]
		assert_true(mood.state == DeskMood.LUNCH or mood.state == DeskMood.CHAT, mood.state)
		assert_gte(mood.slot, 0)
	assert_signal_emitted_with_parameters(sim, "outputs_jammed", [REVIEW, 3])
	assert_signal_emit_count(sim, "employee_dozed", 3)
	assert_true(review.jammed)


func test_breaks_use_lunch_and_kitchen_table_slots() -> void:
	var seen := {}
	for attempt in 30:
		var review := _staff_review(2)
		for desk in review.moods.size():
			review.moods[desk].wake(GameConfig.BASE_ALERT_SECONDS)
		assert_eq(sim.send_on_break(review), 2)
		for desk in review.staff:
			seen[review.moods[desk].state] = true
	assert_true(seen.has(DeskMood.LUNCH))
	assert_true(seen.has(DeskMood.CHAT))


func test_full_kitchen_falls_back_to_a_coffee_break_at_the_desk() -> void:
	var review := _staff_review(GameConfig.KITCHEN_SLOTS + 1)
	for slot in GameConfig.KITCHEN_SLOTS:
		review.moods[slot].rest(DeskMood.FETCH, slot)
	assert_eq(state.free_kitchen_slot(), -1)
	assert_eq(sim.send_on_break(review), 1)
	var last := review.moods[GameConfig.KITCHEN_SLOTS]
	assert_eq(last.state, DeskMood.COFFEE)
	assert_eq(last.slot, -1)


func test_jam_triggers_only_once_and_skips_absent_staff() -> void:
	var review := _staff_review(2)
	review.moods[1].rest(DeskMood.SICK)
	watch_signals(sim)
	_fill_outbox(review)
	sim.tick(GameConfig.TICK)
	assert_signal_emitted_with_parameters(sim, "outputs_jammed", [REVIEW, 1])
	assert_true(review.moods[1].is_sick())
	sim.recall(review, 0)
	review.moods[0].arrive()
	sim.tick(GameConfig.TICK)
	assert_signal_emit_count(sim, "outputs_jammed", 1)
	assert_true(review.moods[0].is_on_duty())


func test_recalled_staff_cannot_work_while_jammed() -> void:
	var review := _staff_review(1)
	var job := StationJob.new(_case(), 10.0)
	review.jobs[0] = job
	_fill_outbox(review)
	sim.tick(GameConfig.TICK)
	review.moods[0].wake(GameConfig.BASE_ALERT_SECONDS)
	var progress := job.progress
	for i in 30:
		sim.tick(GameConfig.TICK)
	assert_eq(job.progress, progress)
	assert_true(review.moods[0].is_on_duty())


func test_player_cannot_work_a_jammed_desk() -> void:
	var review := _review()
	review.inbox.append(_case())
	review.rejects = review.reject_capacity()
	assert_false(sim.work_desk(review, 0, 5.0))
	assert_null(review.jobs[0])
	review.rejects = 0
	assert_true(sim.work_desk(review, 0, 0.1))


func test_work_resumes_once_every_output_has_room() -> void:
	var review := _staff_review(1)
	var job := StationJob.new(_case(), 0.5)
	review.jobs[0] = job
	_fill_outbox(review)
	review.rejects = review.reject_capacity()
	sim.tick(GameConfig.TICK)
	review.moods[0].wake(GameConfig.BASE_ALERT_SECONDS)
	review.outbox.pop_back()
	sim.tick(GameConfig.TICK)
	assert_eq(job.progress, 0.0)
	assert_true(review.jammed)
	review.rejects -= 1
	sim.tick(GameConfig.TICK)
	assert_false(review.jammed)
	assert_gt(job.progress, 0.0)


func test_new_jam_after_recovery_sends_staff_away_again() -> void:
	var review := _staff_review(1)
	watch_signals(sim)
	_fill_outbox(review)
	sim.tick(GameConfig.TICK)
	review.moods[0].wake(GameConfig.BASE_ALERT_SECONDS)
	review.outbox.pop_back()
	sim.tick(GameConfig.TICK)
	review.outbox.append(_case())
	sim.tick(GameConfig.TICK)
	assert_signal_emit_count(sim, "outputs_jammed", 2)
	assert_false(review.moods[0].is_on_duty())


func test_machines_never_take_a_break() -> void:
	state.unlock_department("tax_services")
	var machine := state.station("tax_services/signature")
	assert_true(machine.machine)
	assert_eq(sim.send_on_break(machine), 0)


func test_reject_pile_grows_with_its_level() -> void:
	var review := _review()
	assert_eq(review.reject_capacity(), GameConfig.REJECT_CAPACITY)
	review.reject_level = 3
	assert_eq(review.reject_capacity(), GameConfig.REJECT_CAPACITY + 3 * GameConfig.REJECT_CAPACITY_PER_LEVEL)
	review.rejects = GameConfig.REJECT_CAPACITY
	assert_true(review.has_reject_space())


func test_reject_pile_entry_exists_only_where_files_are_rejected() -> void:
	for key in state.ordered_station_keys():
		var ids: Array[String] = []
		for entry in UpgradeCatalog.station_entries(state, key):
			ids.append(entry.id)
		assert_eq(ids.has("reject_pile:" + key), state.station(key).has_reject_pile(), key)
	assert_null(UpgradeCatalog.find(state, "reject_pile:" + GameConfig.PHOTO_STATION))
	assert_null(UpgradeCatalog.find(state, "reject_pile:nope/review"))


func test_reject_pile_entry_fields_and_purchase() -> void:
	var review := _review()
	var entry := UpgradeCatalog.find(state, "reject_pile:" + REVIEW)
	assert_eq(entry.kind, UpgradeCatalog.REJECT_PILE)
	assert_eq(entry.topic, "building")
	assert_eq(entry.room, "general_services")
	assert_eq(entry.spot, UpgradeCatalog.STATION_PREFIX + REVIEW)
	assert_eq(entry.max_level, GameConfig.MAX_REJECT_LEVEL)
	assert_eq(entry.growth, GameConfig.REJECT_PILE_GROWTH)
	assert_almost_eq(entry.cost, Formulas.reject_pile_cost(review), 0.001)
	state.money = 0.0
	assert_eq(UpgradeCatalog.find(state, entry.id).reason, "money")
	assert_false(actions.upgrade_reject_pile(REVIEW))
	state.money = 1e12
	assert_true(UpgradeCatalog.buy(actions, entry.id, 3))
	assert_eq(review.reject_level, 3)
	assert_gt(Formulas.reject_pile_cost(review), entry.cost)
	assert_almost_eq(Formulas.reject_pile_cost(review), entry.cost * pow(GameConfig.REJECT_PILE_GROWTH, 3), 0.01)


func test_reject_pile_upgrade_respects_maximum_and_missing_piles() -> void:
	state.money = 1e15
	var review := _review()
	review.reject_level = GameConfig.MAX_REJECT_LEVEL
	assert_false(actions.can_upgrade_reject_pile(REVIEW))
	assert_eq(UpgradeCatalog.find(state, "reject_pile:" + REVIEW).reason, "max")
	assert_false(actions.upgrade_reject_pile(GameConfig.PHOTO_STATION))
	assert_false(actions.upgrade_reject_pile("nope/review"))


func test_reject_pile_level_survives_saving_and_is_sanitised() -> void:
	var review := _review()
	review.reject_level = 4
	review.rejects = review.reject_capacity()
	var copy := Station.from_dict(review.to_dict())
	assert_eq(copy.reject_level, 4)
	assert_eq(copy.rejects, review.reject_capacity())
	var data := review.to_dict()
	data.reject_level = 999
	assert_eq(Station.from_dict(data).reject_level, GameConfig.MAX_REJECT_LEVEL)
	data.erase("reject_level")
	var legacy := Station.from_dict(data)
	assert_eq(legacy.reject_level, 0)
	assert_eq(legacy.rejects, GameConfig.REJECT_CAPACITY)
	var photo := state.station(GameConfig.PHOTO_STATION).to_dict()
	photo.reject_level = 5
	assert_eq(Station.from_dict(photo).reject_level, 0)
	assert_false(Station.from_dict(review.to_dict()).jammed)


func test_reject_pile_texts() -> void:
	var entry := UpgradeCatalog.find(state, "reject_pile:" + REVIEW)
	assert_eq(UpgradeTexts.title(entry), TranslationServer.translate("FMT_ENTRY_REJECT_PILE") % StationCard.label_for(REVIEW))
	assert_eq(UpgradeTexts.icon(entry), Icons.CLOSE)
	assert_eq(UpgradeTexts.description(entry), TranslationServer.translate("ENTRY_DESC_REJECT_PILE"))
	assert_eq(UpgradeTexts.effect(state, entry), TranslationServer.translate("FMT_EFFECT_CAPACITY") % [str(GameConfig.REJECT_CAPACITY), str(GameConfig.REJECT_CAPACITY + GameConfig.REJECT_CAPACITY_PER_LEVEL)])
	_review().reject_level = GameConfig.MAX_REJECT_LEVEL
	entry = UpgradeCatalog.find(state, entry.id)
	assert_eq(UpgradeTexts.effect(state, entry), TranslationServer.translate("FMT_EFFECT_CAPACITY_MAX") % str(GameConfig.REJECT_CAPACITY + GameConfig.MAX_REJECT_LEVEL * GameConfig.REJECT_CAPACITY_PER_LEVEL))


func test_jam_texts_exist_in_both_languages() -> void:
	for locale in ["en", "de"]:
		TranslationServer.set_locale(locale)
		for key in ["FMT_ENTRY_REJECT_PILE", "ENTRY_DESC_REJECT_PILE", "FLOAT_OUTPUTS_JAMMED", "FLOAT_RESPECT", "STATUS_OUTPUTS_JAMMED"]:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale("en")


func test_station_status_reports_the_jam() -> void:
	var spot := UpgradeCatalog.STATION_PREFIX + REVIEW
	assert_true(SpotStatus.lines(state, spot).is_empty())
	_fill_outbox(_review())
	assert_eq(SpotStatus.lines(state, spot), [TranslationServer.translate("STATUS_OUTPUTS_JAMMED")] as Array[String])
	assert_true(SpotStatus.lines(state, UpgradeCatalog.STATION_PREFIX + "nope/review").is_empty())


func test_world_view_floats_jam_and_respect_and_draws_bigger_piles() -> void:
	var game := Game.new(GameState.create_new(4))
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	var review := game.state.station(REVIEW)
	review.reject_level = 2
	review.rejects = review.reject_capacity()
	game.simulation.outputs_jammed.emit(REVIEW, 2)
	game.simulation.visitor_respected.emit(1)
	assert_eq(world._floaters.size(), 2)
	game.state.player.position = layout.area(REVIEW).get_center()
	world.camera = game.state.player.position
	world._process(0.1)
	world.queue_redraw()
	await wait_physics_frames(2)
	assert_true(is_instance_valid(world))
