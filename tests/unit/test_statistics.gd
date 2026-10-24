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


func test_research_groups_cover_every_research_once() -> void:
	var seen: Array[String] = []
	for group: Dictionary in GameConfig.RESEARCH_GROUPS:
		for research_id: String in group.items:
			assert_false(seen.has(research_id), research_id)
			assert_true(GameConfig.RESEARCH.has(research_id), research_id)
			seen.append(research_id)
	assert_eq(seen.size(), GameConfig.RESEARCH.size())


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


func test_research_sheet_shows_groups() -> void:
	var sheet := ResearchSheet.new()
	sheet.setup(game)
	add_child_autofree(sheet)
	for group: Dictionary in GameConfig.RESEARCH_GROUPS:
		assert_true(_has_label(sheet.content, sheet.tr("RESEARCH_GROUP_" + str(group.id).to_upper())))
		assert_true(_has_label(sheet.content, sheet.tr("RESEARCH_GROUP_DESC_" + str(group.id).to_upper())))


func test_statistics_sheet_shows_all_sections() -> void:
	var sheet := _statistics()
	assert_eq(sheet.title(), sheet.tr("SHEET_STATISTICS"))
	for key in ["STATS_OVERVIEW", "STATS_SECTION_DEPARTMENTS", "STATS_SECTION_STATIONS", "STATS_SECTION_ABSENCES", "STATS_SECTION_OFFICIALS", "SHEET_REVIEWS", "DEPT_GENERAL_SERVICES"]:
		assert_true(_has_label(sheet.content, sheet.tr(key)), key)
	for key in state.ordered_station_keys():
		assert_true(_has_label(sheet.content, StationCard.label_for(key)), key)
	assert_true(_has_label(sheet.content, sheet.tr("FMT_OFFICIAL_NAME") % 1))


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
	for group: Dictionary in GameConfig.RESEARCH_GROUPS:
		keys.append("RESEARCH_GROUP_" + str(group.id).to_upper())
		keys.append("RESEARCH_GROUP_DESC_" + str(group.id).to_upper())
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)
