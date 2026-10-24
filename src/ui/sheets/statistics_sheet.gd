class_name StatisticsSheet
extends Sheet

const BUSY_LOAD := 0.85

var _bottlenecks := {}


func title() -> String:
	return tr("SHEET_STATISTICS")


func build(container: VBoxContainer) -> void:
	track(_update_bottlenecks)
	container.add_child(UiKit.label(tr("STATS_INTRO"), "BodySmall", true))
	container.add_child(_overview_card())
	container.add_child(_reviews_card())
	container.add_child(UiKit.label(tr("STATS_SECTION_DEPARTMENTS"), "TitleMedium"))
	for dept in game.state.unlocked_departments():
		container.add_child(_department_card(dept))
	container.add_child(UiKit.label(tr("STATS_SECTION_STATIONS"), "TitleMedium"))
	container.add_child(UiKit.label(tr("STATS_STATIONS_HINT"), "BodySmall", true))
	for key in game.state.ordered_station_keys():
		container.add_child(_station_card(key))
	container.add_child(UiKit.label(tr("STATS_SECTION_ABSENCES"), "TitleMedium"))
	container.add_child(_absence_card())
	container.add_child(UiKit.label(tr("STATS_SECTION_OFFICIALS"), "TitleMedium"))
	container.add_child(UiKit.label(tr("STATS_OFFICIALS_HINT"), "BodySmall", true))
	for key in game.state.ordered_station_keys():
		var station := game.state.station(key)
		if not station.machine and station.workers() > 0:
			container.add_child(_officials_card(station))


func is_bottleneck(key: String) -> bool:
	return _bottlenecks.has(key)


static func load_of(state: GameState, station: Station) -> float:
	var capacity := Formulas.station_throughput(state, station)
	if capacity <= 0.0:
		return 1.0 if Formulas.station_demand(state, station.key) > 0.0 else 0.0
	return Formulas.station_demand(state, station.key) / capacity


static func load_role(value: float) -> String:
	if value > 1.0:
		return "error"
	if value >= BUSY_LOAD:
		return "warning"
	return "success"


static func set_fill(bar: ProgressBar, role: String) -> void:
	if str(bar.get_meta(&"fill_role", "")) == role:
		return
	bar.set_meta(&"fill_role", role)
	bar.add_theme_stylebox_override(&"fill", AppTheme.box(AppTheme.accent(role), AppTheme.RADIUS_PILL))


func _update_bottlenecks() -> void:
	_bottlenecks.clear()
	for dept in game.state.unlocked_departments():
		_bottlenecks[Formulas.bottleneck(game.state, dept)] = true


func _rate(kind: String, scope: String = "") -> String:
	var state := game.state
	return tr("FMT_PER_MINUTE") % UiKit.decimal(state.production.per_minute(kind, scope, state.play_time))


func _metric(column: VBoxContainer, label_key: String) -> Label:
	var row := UiKit.hbox(AppTheme.SPACING_SM)
	row.add_child(UiKit.label(tr(label_key), "BodySmall", true))
	var value := UiKit.label("", "TitleSmall")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	column.add_child(row)
	return value


func _overview_card() -> Control:
	var card := UiKit.card("CardPrimary")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	column.add_child(UiKit.label(tr("STATS_OVERVIEW"), "TitleMedium", true))
	var window := UiKit.label("", "BodySmall", true)
	column.add_child(window)
	var income := _metric(column, "STATS_INCOME")
	var arrived := _metric(column, "STATS_ARRIVED")
	var completed := _metric(column, "STATS_COMPLETED")
	var rejected := _metric(column, "STATS_REJECTED")
	var lost := _metric(column, "STATS_LOST")
	var capacity := _metric(column, "STATS_CAPACITY")
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		window.text = tr("FMT_STATS_WINDOW") % UiKit.duration(state.production.observed(state.play_time))
		income.text = tr("FMT_INCOME") % UiKit.money(state.income.per_minute())
		arrived.text = _rate(ProductionStats.ARRIVED)
		completed.text = _rate(ProductionStats.COMPLETED)
		rejected.text = _rate(ProductionStats.REJECTED)
		lost.text = _rate(ProductionStats.LOST)
		var total := 0.0
		for dept in state.unlocked_departments():
			total += Formulas.department_throughput(state, dept)
		capacity.text = tr("FMT_PER_MINUTE") % UiKit.decimal(total * 60.0)
	)
	return card


func _reviews_card() -> Control:
	var card := UiKit.card("CardRow")
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.REVIEWS, AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	texts.add_child(UiKit.label(tr("SHEET_REVIEWS"), "TitleSmall", true))
	var summary := UiKit.label("", "BodySmall", true)
	texts.add_child(summary)
	row.add_child(texts)
	var open := UiKit.icon_button(Icons.CHEVRON, "primary", "IconTonal")
	open.tooltip_text = tr("ACTION_REVIEWS_OPEN")
	open.pressed.connect(func() -> void: navigate.emit("reviews", ""))
	row.add_child(open)
	card.add_child(row)
	track(func() -> void:
		var state := game.state
		var average := UiKit.decimal(state.average_rating()) if not state.reviews.is_empty() else "–"
		summary.text = tr("FMT_STATS_REVIEWS") % [average, state.reviews.size(), state.negative_review_count()]
	)
	return card


func _department_card(dept: Department) -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.icon_disc(Icons.department(dept.id), AppTheme.department_color(dept.id)))
	head.add_child(UiKit.label(tr("DEPT_" + dept.id.to_upper()), "TitleSmall", true))
	column.add_child(head)
	var arrived := _metric(column, "STATS_DEPT_ARRIVED")
	var completed := _metric(column, "STATS_DEPT_COMPLETED")
	var capacity := _metric(column, "STATS_DEPT_CAPACITY")
	var waiting := _metric(column, "STATS_DEPT_WAITING")
	var coverage := UiKit.progress()
	column.add_child(coverage)
	var bottleneck := UiKit.label("", "BodySmall", true)
	column.add_child(bottleneck)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		var demand := Formulas.demand(state, dept)
		var throughput := Formulas.department_throughput(state, dept)
		arrived.text = tr("FMT_STATS_MEASURED_EXPECTED") % [_rate(ProductionStats.ARRIVED, dept.id), UiKit.decimal(demand * 60.0)]
		completed.text = _rate(ProductionStats.COMPLETED, dept.id)
		capacity.text = tr("FMT_PER_MINUTE") % UiKit.decimal(throughput * 60.0)
		waiting.text = str(Formulas.waiting_count(state, dept))
		var ratio := throughput / demand if demand > 0.0 else 1.0
		coverage.value = clampf(ratio, 0.0, 1.0)
		set_fill(coverage, "success" if throughput >= demand else "warning")
		bottleneck.text = _bottleneck_text(Formulas.bottleneck(state, dept))
	)
	return card


func _bottleneck_text(weakest: String) -> String:
	match weakest:
		"demand":
			return tr("BOTTLENECK_DEMAND")
		"transport":
			return tr("BOTTLENECK_TRANSPORT")
	return tr("FMT_BOTTLENECK_STATION") % StationCard.label_for(weakest)


func _station_card(key: String) -> Control:
	var station := game.state.station(key)
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.icon(Icons.station_for(key), AppTheme.accent("primary")))
	head.add_child(UiKit.label(StationCard.label_for(key), "TitleSmall", true))
	var pill := UiKit.pill(tr("LABEL_BOTTLENECK"), "warning")
	head.add_child(pill)
	column.add_child(head)
	var measured := _metric(column, "STATS_STATION_MEASURED")
	var capacity := _metric(column, "STATS_STATION_CAPACITY")
	var demand := _metric(column, "STATS_STATION_DEMAND")
	var load_bar := UiKit.progress()
	column.add_child(load_bar)
	var details := UiKit.label("", "BodySmall", true)
	column.add_child(details)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		measured.text = _rate(ProductionStats.STATION, key)
		capacity.text = tr("FMT_PER_MINUTE") % UiKit.decimal(Formulas.station_throughput(state, station) * 60.0)
		demand.text = tr("FMT_PER_MINUTE") % UiKit.decimal(Formulas.station_demand(state, key) * 60.0)
		var value := load_of(state, station)
		load_bar.value = clampf(value, 0.0, 1.0)
		set_fill(load_bar, load_role(value))
		var working := 0
		for desk in station.moods.size():
			if station.is_working(desk):
				working += 1
		var lines: Array[String] = [tr("FMT_STATS_LOAD") % UiKit.percent(value)]
		lines.append(tr("FMT_STATS_BOXES") % [station.inbox.size(), station.inbox_capacity(state.lobby_capacity()), station.outbox.size(), station.outbox_capacity()])
		lines.append(tr("FMT_STATS_WORKING") % [working, station.workers(), station.active_jobs()])
		details.text = "\n".join(lines)
		pill.visible = is_bottleneck(key)
	)
	return card


func _absence_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var sick_now := _metric(column, "STATS_SICK_NOW")
	var sick := _metric(column, "STATS_SICK_RATE")
	var avoided := _metric(column, "STATS_SICK_AVOIDED")
	var dozed := _metric(column, "STATS_DOZED")
	var disputes := _metric(column, "STATS_DISPUTES")
	var calmed := _metric(column, "STATS_DISPUTES_CALMED")
	var trainings := _metric(column, "STATS_TRAININGS")
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		var production := state.production
		sick_now.text = str(state.sick_count())
		sick.text = _rate(ProductionStats.SICK)
		avoided.text = str(production.total(ProductionStats.SICK_AVOIDED))
		dozed.text = _rate(ProductionStats.DOZED)
		disputes.text = tr("FMT_STATS_DISPUTES") % [state.disputes.size(), _rate(ProductionStats.DISPUTE)]
		calmed.text = str(production.total(ProductionStats.DISPUTE_CALMED))
		trainings.text = str(state.trainings)
	)
	return card


func _officials_card(station: Station) -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.label(StationCard.label_for(station.key), "TitleSmall", true))
	var train := UiKit.button(tr("ACTION_OFFICIALS"))
	train.pressed.connect(func() -> void: navigate.emit("officials", station.key))
	head.add_child(train)
	column.add_child(head)
	var rows: Array[Dictionary] = []
	for desk in OfficialsSheet.staffed_desks(station):
		rows.append(_official_row(column, station, desk))
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		for row in rows:
			var mood: DeskMood = row.mood
			(row.info as Label).text = tr("FMT_STATS_OFFICIAL") % [OfficialsSheet.state_text(mood), UiKit.decimal(mood.output.per_minute(state.play_time, state.production.started)), mood.output.total, mood.sick_count, mood.doze_count]
			var levels: Array = row.levels
			for index in levels.size():
				(levels[index] as Label).text = str(mood.training_level(GameConfig.OFFICIAL_TRAINING_ORDER[index]))
	)
	return card


func _official_row(column: VBoxContainer, station: Station, desk: int) -> Dictionary:
	var row := UiKit.vbox(2)
	var head := UiKit.hbox(AppTheme.SPACING_SM)
	head.add_child(UiKit.label(OfficialsSheet.official_name(station, desk), "BodyMedium", true))
	var levels: Array[Label] = []
	for track_id in GameConfig.OFFICIAL_TRAINING_ORDER:
		head.add_child(UiKit.icon(Icons.TRAININGS[track_id], AppTheme.accent("primary"), AppTheme.SIZE_ICON_SMALL))
		var level := UiKit.label("", "LabelSmall")
		head.add_child(level)
		levels.append(level)
	row.add_child(head)
	var info := UiKit.label("", "BodySmall", true)
	row.add_child(info)
	column.add_child(row)
	return {"mood": station.moods[desk], "info": info, "levels": levels}
