extends GutTest

const MIN_LETTER_LENGTH := 150
const MAX_SUBJECT_WIDTH := 420.0

var state: GameState
var sim: Simulation
var layout: WorldLayout


func before_each() -> void:
	state = GameState.create_new(11)
	sim = Simulation.new(state)
	layout = WorldLayout.get_default()
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.player.position = Vector2(50, 50)


func _run(seconds: float, step: float = 0.05) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		sim.tick(step)
		elapsed += step


func test_no_complaints_before_minimum_cases() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES - 1
	_run(GameConfig.COMPLAINT_INTERVAL * 2.0, 1.0)
	assert_eq(state.complaints, 0)


func test_complaints_are_filed_after_minimum_cases() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	watch_signals(sim)
	_run(GameConfig.COMPLAINT_INTERVAL * 1.5, 1.0)
	assert_gt(state.complaints, 0)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [false])


func test_complaint_letters_arrive_without_a_reason() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.complaint_timer = 1e6
	state.complaint_letter_timer = 1.0
	watch_signals(sim)
	_run(1.5, 0.5)
	assert_eq(state.complaints, 1)
	assert_eq(state.complaints_filed, 1)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [false])
	assert_between(state.complaint_letter_timer, GameConfig.COMPLAINT_LETTER_MIN_INTERVAL - 1.0, GameConfig.COMPLAINT_LETTER_MAX_INTERVAL)


func test_no_complaint_letters_before_minimum_cases() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES - 1
	state.complaint_letter_timer = 0.5
	_run(2.0, 0.5)
	assert_eq(state.complaints, 0)
	assert_eq(state.complaint_letter_timer, 0.5)


func test_complaint_letters_respect_the_amnesty() -> void:
	state.cases_completed = GameConfig.COMPLAINT_MIN_CASES
	state.complaint_timer = 1e6
	state.boosts["complaint_amnesty"] = 60.0
	state.complaint_letter_timer = 0.5
	_run(1.0, 0.5)
	assert_eq(state.complaints, 0)
	assert_gt(state.complaint_letter_timer, GameConfig.COMPLAINT_LETTER_MIN_INTERVAL - 1.0)


func test_complaint_letters_come_now_and_then() -> void:
	assert_gte(GameConfig.COMPLAINT_LETTER_MIN_INTERVAL, 120.0)
	assert_lt(GameConfig.COMPLAINT_LETTER_MIN_INTERVAL, GameConfig.COMPLAINT_LETTER_MAX_INTERVAL)
	assert_eq(Formulas.complaint_letter_interval(0.0), GameConfig.COMPLAINT_LETTER_MIN_INTERVAL)
	assert_eq(Formulas.complaint_letter_interval(1.0), GameConfig.COMPLAINT_LETTER_MAX_INTERVAL)
	assert_eq(Formulas.complaint_letter_interval(-3.0), GameConfig.COMPLAINT_LETTER_MIN_INTERVAL)
	assert_eq(Formulas.complaint_letter_interval(7.0), GameConfig.COMPLAINT_LETTER_MAX_INTERVAL)
	assert_almost_eq(Formulas.complaint_letter_interval(0.5), (GameConfig.COMPLAINT_LETTER_MIN_INTERVAL + GameConfig.COMPLAINT_LETTER_MAX_INTERVAL) * 0.5, 0.001)
	assert_almost_eq(Formulas.complaint_letter_rate(), 1.0 / Formulas.complaint_letter_interval(0.5), 0.0001)


func test_full_box_costs_no_reputation() -> void:
	state.reputation = 5.0
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	watch_signals(sim)
	sim.file_complaint()
	assert_eq(state.complaints, GameConfig.COMPLAINT_BOX_CAPACITY)
	assert_eq(state.reputation, 5.0)
	assert_eq(state.complaints_filed, 0)
	assert_signal_emitted_with_parameters(sim, "complaint_filed", [true])


func test_player_picks_up_at_box_and_shreds() -> void:
	state.complaints = 3
	state.player.position = layout.complaint_box_point()
	_run(2.0)
	assert_eq(state.complaints, 0)
	assert_eq(state.player.complaints, 3)
	var money := state.money
	state.player.position = layout.shredder_point()
	watch_signals(sim)
	_run(2.0)
	assert_eq(state.player.complaints, 0)
	assert_eq(state.complaints_shredded, 3)
	assert_gt(state.money, money)
	assert_signal_emitted_with_parameters(sim, "complaint_shredded", [true])


func test_pickup_respects_carry_capacity() -> void:
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	state.player.position = layout.complaint_box_point()
	_run(10.0)
	assert_eq(state.player.complaints, Formulas.carry_capacity(state))
	assert_eq(state.complaints, GameConfig.COMPLAINT_BOX_CAPACITY - Formulas.carry_capacity(state))


func test_nothing_happens_away_from_desk_and_shredder() -> void:
	state.complaints = 2
	state.player.complaints = 2
	_run(3.0)
	assert_eq(state.complaints, 2)
	assert_eq(state.player.complaints, 2)
	assert_false(sim.move_complaints())


func test_player_shreds_at_a_bought_department_shredder() -> void:
	state.player.complaints = 1
	state.player.position = layout.dept_shredder_point("general_services")
	assert_false(sim.move_complaints())
	state.set_upgrade("shredder", 1, "general_services")
	assert_true(sim.move_complaints())
	assert_eq(state.player.complaints, 0)
	assert_eq(state.complaints_shredded, 1)


func test_shred_complaints_edge_cases() -> void:
	assert_eq(sim.shred_complaints(3, true), 0)
	assert_eq(sim.shred_complaints(3, false), 0)
	state.complaints = 2
	assert_eq(sim.shred_complaints(5, false), 2)
	assert_eq(state.complaints, 0)


func test_box_running_interns_shred_automatically() -> void:
	state.set_upgrade("complaint_interns", 2)
	state.set_upgrade("intern_box_runs", 3)
	state.complaints = 2
	watch_signals(sim)
	_run(Formulas.intern_trip_time(state) * 2.0 + 15.0, 0.5)
	assert_eq(state.complaints, 0)
	assert_eq(state.complaints_shredded, 2)
	assert_signal_emitted_with_parameters(sim, "complaint_shredded", [false])


func test_without_intern_nothing_is_shredded_automatically() -> void:
	state.complaints = 2
	_run(120.0, 1.0)
	assert_eq(state.complaints_shredded, 0)
	assert_true(state.interns.is_empty())


func test_intern_speed_is_a_long_track_that_keeps_speeding_up() -> void:
	var config := GameConfig.upgrade("intern_speed")
	var max_level := int(config.max)
	assert_eq(str(config.spot), "complaint_desk")
	assert_gte(max_level, 100)
	assert_eq(Formulas.track_value("intern_speed", 0), 1.0)
	var faster := true
	for level in range(1, max_level + 1):
		faster = faster and Formulas.track_value("intern_speed", level) > Formulas.track_value("intern_speed", level - 1)
	assert_true(faster)
	state.set_upgrade("complaint_interns", 1)
	var slow := Formulas.intern_trip_time(state)
	state.set_upgrade("intern_speed", max_level)
	assert_lt(Formulas.intern_trip_time(state), slow)


func test_complaint_layout_uses_office_hall_and_shredder_room() -> void:
	assert_true(layout.complaint_office.has_point(layout.complaint_desk_point()))
	assert_true(layout.complaint_office.has_point(layout.complaint_box_point()))
	assert_true(layout.shredder_room.has_point(layout.shredder_point()))
	assert_false(layout.near(layout.complaint_desk_point(), layout.shredder_point()))
	assert_false(layout.near(layout.complaint_box_point(), layout.shredder_point()))


func test_complaint_state_is_saved() -> void:
	state.complaints = 4
	state.complaints_shredded = 9
	state.complaint_timer = 12.0
	state.complaint_letter_timer = 33.0
	state.player.complaints = 2
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.complaints, 4)
	assert_eq(loaded.complaints_shredded, 9)
	assert_almost_eq(loaded.complaint_timer, 12.0, 0.001)
	assert_almost_eq(loaded.complaint_letter_timer, 33.0, 0.001)
	assert_eq(loaded.player.complaints, 2)


func test_old_saves_and_invalid_values_are_tolerated() -> void:
	var data := state.to_dict()
	data.erase("complaints")
	data.erase("complaints_shredded")
	data.erase("complaint_timer")
	data.erase("complaint_letter_timer")
	data.player.erase("complaints")
	var loaded := GameState.from_dict(data)
	assert_eq(loaded.complaints, 0)
	assert_eq(loaded.complaint_letter_timer, GameConfig.COMPLAINT_LETTER_MAX_INTERVAL)
	assert_eq(loaded.player.complaints, 0)
	data.complaints = 999
	data.complaints_shredded = -4
	data.complaint_timer = 1e9
	data.complaint_letter_timer = -5.0
	data.complaints_filed = -7
	data.player.complaints = -3
	loaded = GameState.from_dict(data)
	assert_eq(loaded.complaints, GameConfig.COMPLAINT_BOX_CAPACITY)
	assert_eq(loaded.complaints_shredded, 0)
	assert_eq(loaded.complaints_filed, GameConfig.COMPLAINT_BOX_CAPACITY)
	assert_eq(loaded.complaint_timer, GameConfig.COMPLAINT_INTERVAL)
	assert_eq(loaded.complaint_letter_timer, 0.0)
	assert_eq(loaded.player.complaints, 0)


func test_guidance_leads_to_box_then_shredder() -> void:
	state.complaints = 1
	var task := Guidance.next_task(state)
	assert_eq(task.action, Guidance.COMPLAINT)
	assert_eq(task.point, layout.complaint_box_point())
	state.complaints = 0
	state.player.complaints = 1
	task = Guidance.next_task(state)
	assert_eq(task.action, Guidance.SHRED)
	assert_eq(task.point, layout.shredder_point())


func test_guidance_leads_to_the_nearest_shredder() -> void:
	var dept_shredder := layout.dept_shredder_point("general_services")
	state.player.complaints = 1
	state.player.position = dept_shredder
	assert_eq(Guidance.next_task(state).point, layout.shredder_point())
	state.set_upgrade("shredder", 1, "general_services")
	assert_eq(Guidance.next_task(state).point, dept_shredder)
	state.player.position = layout.shredder_point()
	assert_eq(Guidance.next_task(state).point, layout.shredder_point())


func test_complaints_are_rare_and_harmless() -> void:
	assert_gte(GameConfig.COMPLAINT_INTERVAL, 120.0)
	assert_gt(GameConfig.COMPLAINT_REWARD, 0.0)
	assert_lte(GameConfig.COMPLAINT_REWARD, 5.0)
	state.reputation = 10.0
	state.complaints = GameConfig.COMPLAINT_BOX_CAPACITY
	_run(120.0, 0.5)
	assert_gte(state.reputation, 10.0)


func test_leaving_citizens_complain_only_occasionally() -> void:
	assert_lte(GameConfig.LEAVE_COMPLAINT_CHANCE, 0.6)
	assert_gte(GameConfig.LEAVE_COMPLAINT_COOLDOWN, 30.0)
	assert_lte(GameConfig.LEAVE_COMPLAINT_COOLDOWN, GameConfig.COMPLAINT_INTERVAL)


func test_overcrowded_office_does_not_flood_the_box() -> void:
	state.cases_completed = 50
	state.complaint_timer = 1e6
	state.complaint_letter_timer = 1e6
	state.event_cooldown = 1e6
	state.sick_timer = 1e6
	state.kranz_timer = 1e6
	state.dispute_timer = 1e6
	state.department("general_services").arrival_timer = 0.0
	var seconds := 600.0
	_run(seconds, 0.1)
	var received := state.complaints_filed + state.complaints_absorbed
	for visitor in state.visitors:
		if visitor.files_complaint:
			received += 1
	assert_gte(state.citizens_lost, 50)
	assert_gte(received, 3)
	assert_lte(received, int(seconds / GameConfig.LEAVE_COMPLAINT_COOLDOWN) + 1)


func test_filing_counts_serials_and_pile_texts_are_newest_first() -> void:
	sim.file_complaint()
	sim.file_complaint()
	sim.file_complaint()
	assert_eq(state.complaints_filed, 3)
	assert_eq(state.pile_complaint_serials(2), [2, 1])
	assert_eq(state.pile_complaint_serials(10), [2, 1, 0])
	state.complaints = 0
	assert_true(state.pile_complaint_serials(5).is_empty())


func test_complaint_texts_cycle_through_all_variants() -> void:
	var seen := {}
	for serial in GameConfig.COMPLAINT_TEXTS:
		seen[Formulas.complaint_text_index(serial)] = true
	assert_eq(seen.size(), GameConfig.COMPLAINT_TEXTS)
	assert_eq(Formulas.complaint_text_index(0), Formulas.complaint_text_index(GameConfig.COMPLAINT_TEXTS))
	assert_eq(Flavor.COMPLAINT_COUNT, GameConfig.COMPLAINT_TEXTS)
	assert_between(Formulas.complaint_text_index(-5), 0, GameConfig.COMPLAINT_TEXTS - 1)


func test_complaint_letters_are_long_and_float_a_short_subject() -> void:
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		var letters := {}
		var subjects := {}
		for serial in GameConfig.COMPLAINT_TEXTS:
			var letter := Flavor.complaint(serial)
			var subject := Flavor.complaint_subject(serial)
			var width := AppTheme.FONT_SEMIBOLD.get_string_size(subject, HORIZONTAL_ALIGNMENT_LEFT, -1, AppTheme.SIZE_TITLE_SMALL).x
			assert_gte(letter.length(), MIN_LETTER_LENGTH, "%s letter %d" % [locale, serial])
			assert_lt(subject.length(), letter.length(), "%s subject %d" % [locale, serial])
			assert_false(subject.contains("\n"), "%s subject %d" % [locale, serial])
			assert_lte(width, MAX_SUBJECT_WIDTH, "%s subject %d" % [locale, serial])
			letters[letter] = true
			subjects[subject] = true
		assert_eq(letters.size(), GameConfig.COMPLAINT_TEXTS, locale)
		assert_eq(subjects.size(), GameConfig.COMPLAINT_TEXTS, locale)
	TranslationServer.set_locale(original)


func test_filed_counter_survives_saving() -> void:
	sim.file_complaint()
	sim.file_complaint()
	var loaded := GameState.from_dict(state.to_dict())
	assert_eq(loaded.complaints_filed, 2)
	var data := state.to_dict()
	data.erase("complaints_filed")
	assert_eq(GameState.from_dict(data).complaints_filed, state.complaints)


func test_layout_exposes_read_area_around_the_desk() -> void:
	assert_true(layout.complaint_read_rect().has_point(layout.complaint_desk_point()))
	assert_false(layout.complaint_read_rect().has_point(layout.shredder_point()))


func test_sheet_shows_empty_box_and_pile_texts() -> void:
	var game := Game.new(state)
	var sheet := ComplaintsSheet.new()
	sheet.setup(game, "")
	add_child_autofree(sheet)
	assert_eq(sheet.title(), sheet.tr("SHEET_COMPLAINTS"))
	assert_true(_has_label(sheet.content, sheet.tr("COMPLAINTS_EMPTY")))
	state.set_upgrade("complaint_box", 2)
	for i in GameConfig.COMPLAINT_READ_MAX + 2:
		sim.file_complaint()
	sheet.rebuild()
	assert_true(_has_label(sheet.content, Flavor.complaint(state.complaints_filed - 1)))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_COMPLAINTS_MORE") % 2))


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false
