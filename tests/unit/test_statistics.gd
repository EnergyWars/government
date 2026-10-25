extends GutTest

const REVIEW := "general_services/review"

var state: GameState
var game: Game


func before_each() -> void:
	state = GameState.create_new(31)
	for dept_id in state.departments:
		state.departments[dept_id].arrival_timer = -1e9
	state.money = 1.0e9
	game = Game.new(state)


func test_rate_counter_counts_within_the_window() -> void:
	var counter := RateCounter.new()
	assert_eq(counter.recent(0.0), 0)
	counter.add(0.5)
	counter.add(10.2, 2)
	assert_eq(counter.total, 3)
	assert_eq(counter.recent(10.9), 3)
	assert_eq(counter.recent(60.4), 2)
	assert_eq(counter.recent(70.5), 0)
	assert_eq(counter.total, 3)


func test_rate_counter_reuses_buckets_after_a_lap() -> void:
	var counter := RateCounter.new()
	counter.add(3.0, 5)
	counter.add(3.0 + RateCounter.WINDOW, 1)
	assert_eq(counter.recent(3.0 + RateCounter.WINDOW), 1)
	assert_eq(counter.total, 6)


func test_rate_counter_ignores_future_and_negative_times() -> void:
	var counter := RateCounter.new()
	counter.add(-5.0)
	counter.add(20.0)
	assert_eq(counter.recent(10.0), 1)
	assert_eq(counter.recent(0.0), 1)


func test_rate_counter_scales_to_per_minute() -> void:
	var counter := RateCounter.new()
	for second in 30:
		counter.add(float(second))
	assert_almost_eq(counter.per_minute(30.0, 0.0), 60.0, 0.001)
	assert_almost_eq(counter.per_minute(30.0, 29.5), 30.0 * 60.0, 0.001)
	assert_almost_eq(counter.per_minute(59.5, -100.0), 30.0, 0.001)


func test_production_stats_track_scope_and_total() -> void:
	var stats := ProductionStats.new()
	stats.begin(0.0)
	stats.record(ProductionStats.COMPLETED, "tax_services", 1.0)
	stats.record(ProductionStats.COMPLETED, "housing", 2.0, 2)
	stats.record(ProductionStats.LOST, "", 2.0)
	assert_eq(stats.total(ProductionStats.COMPLETED), 3)
	assert_eq(stats.total(ProductionStats.COMPLETED, "housing"), 2)
	assert_eq(stats.total(ProductionStats.LOST), 1)
	assert_eq(stats.total(ProductionStats.SICK), 0)
	assert_eq(stats.per_minute(ProductionStats.SICK, "", 5.0), 0.0)
	assert_almost_eq(stats.per_minute(ProductionStats.COMPLETED, "", 30.0), 6.0, 0.001)
	assert_eq(stats.observed(30.0), 30.0)
	assert_eq(stats.observed(500.0), float(RateCounter.WINDOW))
	stats.begin(40.0)
	assert_eq(stats.total(ProductionStats.COMPLETED), 0)
	assert_eq(stats.started, 40.0)


func test_simulation_starts_measuring_at_its_creation() -> void:
	state.play_time = 123.0
	Simulation.new(state)
	assert_eq(state.production.started, 123.0)


func test_simulation_records_arrivals_and_losses() -> void:
	var dept := state.department("general_services")
	assert_not_null(game.simulation.spawn_case(dept))
	assert_eq(state.production.total(ProductionStats.ARRIVED, "general_services"), 1)
	var entry := state.station(GameConfig.RECEPTION)
	while entry.has_inbox_space(state.lobby_capacity()):
		entry.inbox.append(game.simulation.create_case(dept))
	assert_null(game.simulation.spawn_case(dept))
	assert_eq(state.production.total(ProductionStats.ARRIVED, "general_services"), 2)
	assert_eq(state.production.total(ProductionStats.LOST, "general_services"), 1)


func test_simulation_records_station_output_and_completion() -> void:
	var station := state.station(GameConfig.COUNTER)
	station.staff = 1
	var case_file := CaseFile.new("general_services")
	case_file.route = [GameConfig.COUNTER]
	var job := StationJob.new(case_file, 1.0, false)
	job.progress = 1.0
	station.jobs[0] = job
	assert_true(game.simulation.finish_job(station, 0))
	assert_eq(station.moods[0].output.total, 1)
	assert_eq(state.production.total(ProductionStats.STATION, GameConfig.COUNTER), 1)
	assert_eq(state.production.total(ProductionStats.COMPLETED, "general_services"), 1)


func test_simulation_records_rejections_and_naps() -> void:
	var station := state.station(REVIEW)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	case_file.invalid = true
	var job := StationJob.new(case_file, 1.0, false)
	job.progress = 1.0
	station.jobs[0] = job
	assert_true(game.simulation.finish_job(station, 0))
	assert_eq(state.production.total(ProductionStats.REJECTED, "general_services"), 1)
	assert_eq(station.moods[0].output.total, 1)
	assert_true(game.simulation.doze_off(station, 0))
	assert_eq(station.moods[0].doze_count, 1)
	assert_eq(state.production.total(ProductionStats.DOZED, REVIEW), 1)


func test_simulation_records_quarrels() -> void:
	var station := state.station(REVIEW)
	station.add_desk()
	station.staff = 2
	assert_not_null(game.simulation.start_dispute("radio", "general_services"))
	assert_eq(state.production.total(ProductionStats.DISPUTE, "general_services"), 1)


func test_every_upgrade_track_has_a_spot_in_a_known_room() -> void:
	var rooms := UpgradeCatalog.rooms()
	for upgrade_id in GameConfig.upgrade_ids():
		var targets: Array[String] = [""]
		if GameConfig.is_room_upgrade(upgrade_id):
			targets = GameConfig.upgrade_rooms(upgrade_id)
		assert_false(targets.is_empty(), upgrade_id)
		for room_id in targets:
			var spot := GameConfig.upgrade_spot(upgrade_id, room_id)
			assert_false(spot.is_empty(), upgrade_id)
			assert_has(rooms, GameConfig.spot_room(spot), GameConfig.upgrade_key(upgrade_id, room_id))


func _connect_all_tubes() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	state.set_upgrade("large_capsules", 1)


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node)
	for child in node.get_children():
		result.append_array(_buttons(child))
	return result


func _statistics() -> StatisticsSheet:
	var sheet := StatisticsSheet.new()
	sheet.setup(game)
	add_child_autofree(sheet)
	return sheet


func test_upgrades_sheet_lists_every_room_with_upgrades() -> void:
	UpgradesSheet.mode_index = 0
	UpgradesSheet.expanded.clear()
	var sheet := UpgradesSheet.new()
	sheet.setup(game)
	add_child_autofree(sheet)
	assert_eq(UpgradesSheet.mode(), "rooms")
	var groups := UpgradesSheet.grouped(UpgradeCatalog.entries(state), "rooms")
	assert_true(groups.has(GameConfig.ROOM_HALL))
	assert_true(groups.has("general_services"))
	for room_id in UpgradesSheet.group_order("rooms"):
		assert_eq(_has_label(sheet.content, UpgradeTexts.room_title(room_id)), groups.has(room_id), room_id)


func test_statistics_sheet_shows_all_sections() -> void:
	var sheet := _statistics()
	assert_eq(sheet.title(), sheet.tr("SHEET_STATISTICS"))
	for key in ["STATS_OVERVIEW", "SECTION_STATISTICS", "STATS_SECTION_DEPARTMENTS", "STATS_SECTION_STATIONS", "STATS_SECTION_ABSENCES", "STATS_SECTION_OFFICIALS", "SHEET_REVIEWS", "DEPT_GENERAL_SERVICES"]:
		assert_true(_has_label(sheet.content, sheet.tr(key)), key)
	for key in state.ordered_station_keys():
		assert_true(_has_label(sheet.content, StationCard.label_for(key)), key)
	assert_true(_has_label(sheet.content, sheet.tr("FMT_OFFICIAL_NAME") % 1))
	assert_true(_has_label(sheet.content, StatisticsSheet.lifetime_text(state)))
	assert_true(_has_label(sheet.content, SpotStatus.population(state)))


func test_statistics_sheet_shows_measured_rates() -> void:
	state.play_time = 30.0
	state.production.begin(0.0)
	for index in 3:
		state.production.record(ProductionStats.COMPLETED, "general_services", 10.0 + index)
	var sheet := _statistics()
	var rate := sheet.tr("FMT_PER_MINUTE") % UiKit.decimal(6.0)
	assert_true(_has_label(sheet.content, rate))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_STATS_WINDOW") % UiKit.duration(30.0)))


func test_statistics_sheet_marks_bottlenecks() -> void:
	var sheet := _statistics()
	var weakest := Formulas.bottleneck(state, state.department("general_services"))
	assert_true(sheet.is_bottleneck(weakest))
	assert_false(sheet.is_bottleneck("nope"))


func test_statistics_sheet_shows_review_summary_and_links() -> void:
	state.add_review(5)
	state.add_review(1)
	var sheet := _statistics()
	assert_true(_has_label(sheet.content, sheet.tr("FMT_STATS_REVIEWS") % [UiKit.decimal(3.0), 2, 1]))
	watch_signals(sheet)
	for button in _buttons(sheet.content):
		if button.tooltip_text == sheet.tr("ACTION_REVIEWS_OPEN"):
			button.pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "navigate", ["reviews", ""])
	for button in _buttons(sheet.content):
		if button.text == sheet.tr("ACTION_OFFICIALS"):
			button.pressed.emit()
			break
	assert_signal_emitted_with_parameters(sheet, "navigate", ["officials", REVIEW])


func test_statistics_sheet_review_summary_without_reviews() -> void:
	var sheet := _statistics()
	assert_true(_has_label(sheet.content, sheet.tr("FMT_STATS_REVIEWS") % ["–", 0, 0]))


func test_statistics_sheet_shows_official_details() -> void:
	var mood := state.station(REVIEW).moods[0]
	mood.training = {"skill": 2}
	mood.sick_count = 3
	mood.doze_count = 4
	mood.output.add(state.play_time)
	var sheet := _statistics()
	var rate := UiKit.decimal(mood.output.per_minute(state.play_time, state.production.started))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_STATS_OFFICIAL") % [sheet.tr("OFFICIAL_STATE_AWAKE"), rate, 1, 3, 4]))
	assert_true(_has_label(sheet.content, "2"))


func test_statistics_sheet_shows_absences() -> void:
	state.trainings = 7
	var sheet := _statistics()
	assert_true(_has_label(sheet.content, "7"))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_STATS_DISPUTES") % [0, sheet.tr("FMT_PER_MINUTE") % UiKit.decimal(0.0)]))


func test_load_helpers() -> void:
	var station := state.station(REVIEW)
	var station_load := StatisticsSheet.load_of(state, station)
	assert_almost_eq(station_load, Formulas.station_demand(state, REVIEW) / Formulas.station_throughput(state, station), 0.0001)
	station.staff = 0
	assert_eq(StatisticsSheet.load_of(state, station), 1.0)
	var unused := Station.new("tax_services/review")
	assert_eq(StatisticsSheet.load_of(state, unused), 0.0)
	assert_eq(StatisticsSheet.load_role(1.2), "error")
	assert_eq(StatisticsSheet.load_role(StatisticsSheet.BUSY_LOAD), "warning")
	assert_eq(StatisticsSheet.load_role(0.2), "success")


func test_progress_fill_is_only_replaced_on_role_change() -> void:
	var bar := UiKit.progress()
	autofree(bar)
	StatisticsSheet.set_fill(bar, "error")
	var style := bar.get_theme_stylebox(&"fill")
	StatisticsSheet.set_fill(bar, "error")
	assert_same(bar.get_theme_stylebox(&"fill"), style)
	StatisticsSheet.set_fill(bar, "success")
	assert_ne(bar.get_theme_stylebox(&"fill"), style)


func test_hud_offers_statistics_and_always_the_rating() -> void:
	var hud := Hud.new().setup(game, 0.0)
	add_child_autofree(hud)
	assert_true(hud._nav_buttons.has("statistics"))
	assert_true(hud._rating_chip.visible)
	watch_signals(hud)
	(hud._nav_buttons["statistics"] as Button).pressed.emit()
	assert_signal_emitted_with_parameters(hud, "open_sheet", ["statistics", ""])


func test_new_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["NAV_STATISTICS", "SHEET_STATISTICS", "STATS_INTRO", "STATS_OVERVIEW", "FMT_STATS_WINDOW", "STATS_INCOME", "STATS_ARRIVED", "STATS_COMPLETED", "STATS_REJECTED", "STATS_LOST", "STATS_CAPACITY", "FMT_STATS_REVIEWS", "STATS_SECTION_DEPARTMENTS", "STATS_DEPT_ARRIVED", "FMT_STATS_MEASURED_EXPECTED", "STATS_DEPT_COMPLETED", "STATS_DEPT_CAPACITY", "STATS_DEPT_WAITING", "STATS_SECTION_STATIONS", "STATS_STATIONS_HINT", "STATS_STATION_MEASURED", "STATS_STATION_CAPACITY", "STATS_STATION_DEMAND", "FMT_STATS_LOAD", "FMT_STATS_BOXES", "FMT_STATS_WORKING", "STATS_SECTION_ABSENCES", "STATS_SICK_NOW", "STATS_SICK_RATE", "STATS_SICK_AVOIDED", "STATS_DOZED", "STATS_DISPUTES", "FMT_STATS_DISPUTES", "STATS_DISPUTES_CALMED", "STATS_TRAININGS", "STATS_SECTION_OFFICIALS", "STATS_OFFICIALS_HINT", "FMT_STATS_OFFICIAL", "ACTION_OFFICIALS", "SHEET_OFFICIALS", "FMT_OFFICIALS_TITLE", "OFFICIALS_INTRO", "OFFICIALS_MACHINE", "OFFICIALS_EMPTY", "FMT_OFFICIAL_NAME", "FMT_SPECIALIST_NAME", "FMT_OFFICIAL_STATS", "FMT_TRAINING_LEVEL", "ACTION_TRAIN"]
	for room_id in GameConfig.SERVICE_ROOMS:
		keys.append("ROOM_" + room_id.to_upper())
		if room_id != GameConfig.ROOM_PLAYER:
			keys.append("ROOM_DESC_" + room_id.to_upper())
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)


func test_simulation_records_transfers_by_carrier() -> void:
	var sim := game.simulation
	var reception := state.station(GameConfig.RECEPTION)
	var case_file := CaseFile.new("general_services")
	case_file.route = RouteBuilder.build(case_file)
	reception.outbox.append(case_file)
	assert_true(sim.move_case(reception, 0))
	sim.deliver(CaseFile.new("general_services"), state.station(REVIEW), ProductionStats.BY_RUNNER)
	sim.deliver(CaseFile.new("general_services"), state.station(REVIEW), ProductionStats.BY_TUBE)
	var production := state.production
	assert_eq(production.total(ProductionStats.TRANSFER, ProductionStats.BY_PLAYER), 1)
	assert_eq(production.total(ProductionStats.TRANSFER, ProductionStats.BY_RUNNER), 1)
	assert_eq(production.total(ProductionStats.TRANSFER, ProductionStats.BY_TUBE), 1)
	assert_eq(production.total(ProductionStats.TRANSFER), 3)


func test_simulation_records_complaints_and_their_shredding() -> void:
	var sim := game.simulation
	var production := state.production
	sim.file_complaint()
	sim.file_complaint()
	assert_eq(production.total(ProductionStats.COMPLAINT), 2)
	assert_eq(sim.shred_complaints(1, false), 1)
	state.player.complaints = 2
	assert_eq(sim.shred_complaints(2, true), 2)
	assert_eq(production.total(ProductionStats.COMPLAINT_SHREDDED, ProductionStats.BY_STAFF), 1)
	assert_eq(production.total(ProductionStats.COMPLAINT_SHREDDED, ProductionStats.BY_PLAYER), 2)
	assert_eq(production.total(ProductionStats.COMPLAINT_SHREDDED), 3)
	state.complaints = Formulas.complaint_cap(state)
	sim.file_complaint()
	assert_eq(production.total(ProductionStats.COMPLAINT), 2)
	assert_eq(sim.shred_complaints(1, true), 0)
	assert_eq(production.total(ProductionStats.COMPLAINT_SHREDDED), 3)


func test_simulation_records_shredded_rejects() -> void:
	var sim := game.simulation
	var production := state.production
	state.station(REVIEW).rejects = 2
	assert_eq(sim.shred_rejects(5, false), 2)
	state.player.rejects = 1
	assert_eq(sim.shred_rejects(1, true), 1)
	assert_eq(sim.shred_rejects(1, true), 0)
	assert_eq(production.total(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF), 2)
	assert_eq(production.total(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_PLAYER), 1)
	var collector := RejectCollector.new(sim.layout.shredder_point())
	collector.loaded = 3
	state.collectors.append(collector)
	sim._update_collectors(0.1)
	assert_eq(collector.loaded, 0)
	assert_eq(production.total(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF), 5)


func test_simulation_records_answered_and_missed_calls() -> void:
	var sim := game.simulation
	var production := state.production
	state.station(REVIEW).moods[0].rest(DeskMood.SICK)
	state.calls.append(PhoneCall.new(PhoneCall.INCOMING, REVIEW, 0, 0.5))
	sim._ring_calls(1.0)
	assert_eq(production.total(ProductionStats.CALL_MISSED), 1)
	var by_staff := PhoneCall.new(PhoneCall.INCOMING, REVIEW, 0)
	by_staff.line = 0
	sim._finish_call(by_staff)
	var by_player := PhoneCall.new(PhoneCall.INCOMING, REVIEW, 0)
	by_player.line = PhoneCall.PLAYER
	sim._finish_call(by_player)
	assert_eq(production.total(ProductionStats.CALL_ANSWERED, ProductionStats.BY_STAFF), 1)
	assert_eq(production.total(ProductionStats.CALL_ANSWERED, ProductionStats.BY_PLAYER), 1)
	var outgoing := PhoneCall.new(PhoneCall.OUTGOING, REVIEW, 0)
	outgoing.line = 0
	sim._finish_call(outgoing)
	assert_eq(production.total(ProductionStats.CALL_ANSWERED), 2)


func test_statistics_sheet_shows_throughput_sections() -> void:
	var sheet := _statistics()
	for key in ["STATS_SECTION_UPGRADES", "STATS_UPGRADES_HINT", "STATS_SECTION_AREAS", "STATS_AREAS_HINT", "STATS_DEPT_STEPS", "STATS_STEP_TRANSPORT", "AREA_TRANSPORT", "AREA_COMPLAINTS", "AREA_REJECTS", "AREA_PHONES", "AREA_SEATING", "AREA_WAITING", "STATS_UPGRADES", "STATS_CALLS_ANSWERED", "STATS_CALLS_MISSED", "STATS_OCCUPANCY"]:
		assert_true(_has_label(sheet.content, sheet.tr(key)), key)
	assert_true(_has_text_part(sheet.content, UpgradeTexts.title(UpgradeCatalog.find(state, "level:" + REVIEW))))
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_RUNNERS") % [0, Formulas.runner_capacity(state)]))
	assert_true(_has_label(sheet.content, sheet.tr("FMT_STATS_OCCUPANCY") % [0, state.seat_capacity() + state.standing_capacity()]))
	var review := state.station(REVIEW)
	var case_time := Formulas.station_case_time(state, review, false)
	var per_official := sheet.tr("FMT_PER_MINUTE") % UiKit.decimal(60.0 / case_time)
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_CASE_TIME") % [UiKit.decimal(case_time), per_official]))
	assert_true(_has_highlight(sheet.content))


func test_statistics_sheet_shows_area_states() -> void:
	state.complaints = 3
	state.guards = 1
	state.station(REVIEW).rejects = 2
	state.collectors.append(RejectCollector.new())
	state.hr = 2
	state.calls_answered = 3
	state.calls_missed = 1
	var sheet := _statistics()
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_COMPLAINT_STATE") % [3, Formulas.complaint_cap(state), 1, 1]))
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_REJECT_STATE") % [2, 1]))
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_PHONE_STATE") % [0, 2, UiKit.percent(0.75)]))
	var zero := sheet.tr("FMT_PER_MINUTE") % UiKit.decimal(0.0)
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_HANDLED_BY") % [zero, zero]))


func test_statistics_sheet_phone_quota_without_calls() -> void:
	var sheet := _statistics()
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_PHONE_STATE") % [0, 0, "–"]))


func test_statistics_sheet_shows_unlimited_tubes() -> void:
	_connect_all_tubes()
	var sheet := _statistics()
	assert_true(_has_label(sheet.content, sheet.tr("STATS_UNLIMITED")))
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_TUBES") % [Formulas.tube_capacity(state), 0]))
	assert_false(_has_text_part(sheet.content, sheet.tr("FMT_STATS_RUNNERS") % [0, Formulas.runner_capacity(state)]))


func test_statistics_sheet_shows_tubes_and_runners_when_mixed() -> void:
	state.unlock_department("tax_services")
	state.set_upgrade("pneumatic_tubes", 1)
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	state.set_upgrade("tube_station", 1, "general_services")
	var sheet := _statistics()
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_TUBES") % [Formulas.tube_capacity(state), 0]))
	assert_true(_has_text_part(sheet.content, sheet.tr("FMT_STATS_RUNNERS") % [0, Formulas.runner_capacity(state)]))
	for role in Runner.ROLES:
		assert_true(_has_text_part(sheet.content, BoardSection.role_info(state, role)), role)


func test_statistics_sheet_recommends_upgrades_and_links_them() -> void:
	var sheet := _statistics()
	var picked := sheet.recommended()
	assert_false(picked.is_empty())
	var keys: Array[String] = []
	for entry in picked:
		keys.append(str(entry.key))
	assert_true(keys.has(GameConfig.RECEPTION))
	var reception_title := sheet.tr("FMT_STATS_AREA_LOAD") % [StationCard.label_for(GameConfig.RECEPTION), UiKit.percent(1.0)]
	assert_true(_has_label(sheet.content, reception_title))
	assert_false(_visible_label(sheet.content, sheet.tr("STATS_UPGRADES_EMPTY")))
	var first: Dictionary = picked[0]
	var target := StatisticsSheet.upgrade_target(state, first, (first.upgrades as Array)[0])
	watch_signals(sheet)
	for button in _buttons(sheet.content):
		if button.tooltip_text == sheet.tr("ACTION_STATS_OPEN"):
			button.pressed.emit()
			break
	assert_signal_emitted_with_parameters(sheet, "navigate", [target[0], target[1]])


func test_statistics_sheet_without_busy_areas() -> void:
	_connect_all_tubes()
	state.station(GameConfig.RECEPTION).staff = 1
	state.station(GameConfig.COUNTER).staff = 1
	state.station(REVIEW).level = 10
	state.station("general_services/signature").level = 10
	state.hr = 1
	var sheet := _statistics()
	assert_true(sheet.recommended().is_empty())
	assert_true(_visible_label(sheet.content, sheet.tr("STATS_UPGRADES_EMPTY")))
	assert_eq(sheet.area_report(ThroughputReport.TRANSPORT).area, ThroughputReport.TRANSPORT)
	assert_true(sheet.area_report("nope").is_empty())


func test_statistics_sheet_formats_upgrades() -> void:
	var sheet := _statistics()
	var relief := ThroughputReport.upgrade(ThroughputReport.HR, 0.5, ThroughputReport.RELIEF)
	var places := ThroughputReport.track("seating", 3.0, ThroughputReport.PLACES)
	var capacity := ThroughputReport.track("runner_trolleys", 0.1)
	assert_eq(sheet._upgrade_gain(relief), sheet.tr("FMT_GAIN_RELIEF") % UiKit.decimal(30.0))
	assert_eq(sheet._upgrade_gain(places), sheet.tr("FMT_GAIN_PLACES") % UiKit.number(3.0))
	assert_eq(sheet._upgrade_gain(capacity), sheet.tr("FMT_GAIN_CAPACITY") % UiKit.decimal(6.0))
	assert_eq(sheet._upgrade_name(capacity), UpgradeTexts.title(UpgradeCatalog.find(state, "track:runner_trolleys")))
	assert_eq(sheet._upgrade_name(capacity), sheet.tr("TRACK_RUNNER_TROLLEYS"))
	var unresolved := ThroughputReport.track("tube_station", 1.0, ThroughputReport.CAPACITY, "nope")
	assert_null(UpgradeCatalog.find(state, str(unresolved.entry)))
	assert_eq(sheet._upgrade_name(unresolved), sheet.tr("TRACK_TUBE_STATION"))
	assert_eq(sheet._upgrade_name(relief), sheet.tr("UPGRADE_HR"))
	var staffed := ThroughputReport.upgrade(ThroughputReport.HR, 0.5, ThroughputReport.RELIEF, ThroughputReport.staff_entry("hr"))
	assert_eq(sheet._upgrade_name(staffed), sheet.tr("STAFF_HR"))
	var entry := {"upgrades": [relief, places]}
	assert_eq(sheet._upgrade_lines(entry, 1), sheet.tr("FMT_UPGRADE") % [sheet.tr("UPGRADE_HR"), sheet._upgrade_gain(relief)])
	assert_eq(sheet._upgrade_lines(entry).split("\n").size(), 2)
	assert_eq(sheet._upgrade_lines({}), sheet.tr("STATS_UPGRADES_NONE"))
	assert_eq(sheet._per_minute(INF), sheet.tr("STATS_UNLIMITED"))
	assert_eq(sheet._area_name({"area": ThroughputReport.PHONES, "key": ""}), sheet.tr("AREA_PHONES"))


func test_upgrade_targets_open_the_right_spot() -> void:
	var none := {"key": ""}
	var plain := ThroughputReport.upgrade(ThroughputReport.HIRE, 1.0)
	assert_eq(StatisticsSheet.upgrade_target(state, none, plain), ["upgrades", ""])
	assert_eq(StatisticsSheet.upgrade_target(state, none, ThroughputReport.track("runner_trolleys", 1.0)), ["spot", "runners"])
	for staff_type: String in UpgradeCatalog.STAFF_SPOTS:
		var staff := ThroughputReport.upgrade(ThroughputReport.RUNNER, 1.0, ThroughputReport.CAPACITY, ThroughputReport.staff_entry(staff_type))
		assert_eq(StatisticsSheet.upgrade_target(state, none, staff), ["spot", str(UpgradeCatalog.STAFF_SPOTS[staff_type])], staff_type)
	assert_eq(StatisticsSheet.upgrade_target(state, none, ThroughputReport.track("seating", 1.0, ThroughputReport.PLACES)), ["spot", "seating"])
	assert_eq(StatisticsSheet.upgrade_target(state, none, ThroughputReport.track("waiting_places", 1.0, ThroughputReport.PLACES)), ["spot", "waiting"])
	assert_eq(StatisticsSheet.upgrade_target(state, none, ThroughputReport.track("office_equipment", 1.0, ThroughputReport.CAPACITY, "general_services")), ["spot", "dept:general_services"])
	var hire := ThroughputReport.upgrade(ThroughputReport.HIRE, 1.0, ThroughputReport.CAPACITY, "%s:%s" % [UpgradeCatalog.HIRE, REVIEW])
	assert_eq(StatisticsSheet.upgrade_target(state, none, hire), ["spot", UpgradeCatalog.STATION_PREFIX + REVIEW])
	assert_eq(StatisticsSheet.upgrade_target(state, {"key": REVIEW}, plain), ["spot", WorldLayout.STATION_PREFIX + REVIEW])
	var tax_key := GameConfig.department_station_keys("tax_services")[0]
	var locked := ThroughputReport.upgrade(ThroughputReport.HIRE, 1.0, ThroughputReport.CAPACITY, "%s:%s" % [UpgradeCatalog.HIRE, tax_key])
	assert_eq(StatisticsSheet.upgrade_target(state, {"key": tax_key}, locked), ["upgrades", ""])
	assert_eq(StatisticsSheet.upgrade_target(state, {"key": GameConfig.INSPECTION}, plain), ["upgrades", ""])
	state.stations[GameConfig.INSPECTION] = Station.new(GameConfig.INSPECTION)
	assert_eq(StatisticsSheet.upgrade_target(state, {"key": GameConfig.INSPECTION}, plain), ["spot", WorldLayout.STATION_PREFIX + GameConfig.INSPECTION])


func test_highlight_is_only_changed_when_needed() -> void:
	var label := Label.new()
	autofree(label)
	StatisticsSheet.set_highlight(label, false)
	assert_false(label.has_theme_color_override(&"font_color"))
	StatisticsSheet.set_highlight(label, true)
	assert_true(label.has_theme_color_override(&"font_color"))
	StatisticsSheet.set_highlight(label, true)
	assert_true(label.has_theme_color_override(&"font_color"))
	StatisticsSheet.set_highlight(label, false)
	assert_false(label.has_theme_color_override(&"font_color"))


func test_throughput_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["STATS_SECTION_UPGRADES", "STATS_UPGRADES_HINT", "STATS_UPGRADES_EMPTY", "FMT_STATS_AREA_LOAD", "ACTION_STATS_OPEN", "STATS_UPGRADES", "STATS_UPGRADES_NONE", "FMT_UPGRADE", "FMT_GAIN_CAPACITY", "FMT_GAIN_RELIEF", "FMT_GAIN_PLACES", "STATS_UNLIMITED", "FMT_STATS_CASE_TIME", "STATS_DEPT_STEPS", "STATS_STEP_TRANSPORT", "STATS_SECTION_AREAS", "STATS_AREAS_HINT", "STATS_AREA_MEASURED", "STATS_AREA_INCOMING", "FMT_STATS_TRANSFERS", "FMT_STATS_RUNNERS", "FMT_STATS_TUBES", "FMT_STATS_HANDLED_BY", "FMT_STATS_COMPLAINT_STATE", "FMT_STATS_REJECT_STATE", "STATS_CALLS_ANSWERED", "STATS_CALLS_MISSED", "FMT_STATS_PHONE_STATE", "STATS_OCCUPANCY", "FMT_STATS_OCCUPANCY", "FMT_STATS_TICKETS", "SECTION_STATISTICS", "FMT_STATISTICS", "FMT_POPULATION"]
	for id in [ThroughputReport.HIRE, ThroughputReport.DESK, ThroughputReport.MACHINE, ThroughputReport.LEVEL, ThroughputReport.SPECIALIST, ThroughputReport.SUPERVISOR, ThroughputReport.RUNNER, ThroughputReport.HELPER, ThroughputReport.COLLECTOR, ThroughputReport.HR, ThroughputReport.GUARD]:
		keys.append("UPGRADE_" + id.to_upper())
	for kind in [ThroughputReport.TRANSPORT, ThroughputReport.COMPLAINTS, ThroughputReport.REJECTS, ThroughputReport.PHONES, ThroughputReport.SEATING, ThroughputReport.WAITING, ThroughputReport.TICKETS, ThroughputReport.CALLS]:
		keys.append("AREA_" + kind.to_upper())
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)


func _has_text_part(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text.contains(text):
		return true
	for child in node.get_children():
		if _has_text_part(child, text):
			return true
	return false


func _visible_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return (node as Label).visible
	for child in node.get_children():
		if _visible_label(child, text):
			return true
	return false


func _has_highlight(node: Node) -> bool:
	if node is Label and bool(node.get_meta(&"highlight", false)):
		return true
	for child in node.get_children():
		if _has_highlight(child):
			return true
	return false
