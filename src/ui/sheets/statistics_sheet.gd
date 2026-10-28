class_name StatisticsSheet
extends Sheet

const BUSY_LOAD := ThroughputReport.BUSY_LOAD
const RECOMMENDATIONS := 4
const UPGRADE_LINES := 2
const REFRESH_MSEC := 250

var _bottlenecks := {}
var _areas := {}
var _recommended: Array[Dictionary] = []


func title() -> String:
	return tr("SHEET_STATISTICS")


func refresh_interval() -> int:
	return REFRESH_MSEC


func build(container: VBoxContainer) -> void:
	track(_update_report)
	container.add_child(UiKit.label(tr("STATS_INTRO"), "BodySmall", true))
	container.add_child(UiKit.label(tr("STATS_SECTION_UPGRADES"), "TitleMedium"))
	container.add_child(UiKit.label(tr("STATS_UPGRADES_HINT"), "BodySmall", true))
	container.add_child(_recommendation_card())
	container.add_child(_overview_card())
	container.add_child(_reviews_card())
	container.add_child(UiKit.label(tr("SECTION_STATISTICS"), "TitleMedium"))
	container.add_child(_lifetime_card())
	container.add_child(UiKit.label(tr("STATS_SECTION_DEPARTMENTS"), "TitleMedium"))
	for dept in game.state.unlocked_departments():
		container.add_child(_department_card(dept))
	container.add_child(UiKit.label(tr("STATS_SECTION_STATIONS"), "TitleMedium"))
	container.add_child(UiKit.label(tr("STATS_STATIONS_HINT"), "BodySmall", true))
	for key in game.state.ordered_station_keys():
		container.add_child(_station_card(key))
	container.add_child(UiKit.label(tr("STATS_SECTION_AREAS"), "TitleMedium"))
	container.add_child(UiKit.label(tr("STATS_AREAS_HINT"), "BodySmall", true))
	container.add_child(_transport_card())
	container.add_child(_complaint_card())
	container.add_child(_reject_card())
	container.add_child(_phone_card())
	container.add_child(_hall_card(ThroughputReport.SEATING, Icons.SEAT))
	container.add_child(_hall_card(ThroughputReport.WAITING, Icons.HOURGLASS))
	container.add_child(_hall_card(ThroughputReport.PICKUP_SEATING, Icons.SEAT))
	container.add_child(_hall_card(ThroughputReport.PICKUP_WAITING, Icons.HOURGLASS))
	container.add_child(_ticket_card())
	container.add_child(UiKit.label(tr("STATS_SECTION_ABSENCES"), "TitleMedium"))
	container.add_child(_absence_card())
	container.add_child(UiKit.label(tr("STATS_SECTION_OFFICIALS"), "TitleMedium"))
	container.add_child(UiKit.label(tr("STATS_OFFICIALS_HINT"), "BodySmall", true))
	for key in game.state.ordered_station_keys():
		var station := game.state.station(key)
		if not station.machine and station.workers() > 0:
			container.add_child(_officials_card(station))


static func lifetime_text(state: GameState) -> String:
	var accuracy := 1.0
	if state.cases_completed > 0:
		accuracy = 1.0 - float(state.cases_flawed) / state.cases_completed
	return TranslationServer.translate("FMT_STATISTICS") % [
		UiKit.number(state.cases_completed),
		UiKit.percent(accuracy),
		UiKit.number(state.citizens_lost),
		UiKit.number(state.wakes),
		UiKit.number(state.total_staff()),
		UiKit.money(state.money_earned),
		UiKit.duration(state.play_time),
	]


func _lifetime_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var population := UiKit.label("", "TitleSmall", true)
	column.add_child(population)
	var label := UiKit.label("", "BodyMedium", true)
	column.add_child(label)
	card.add_child(column)
	track(func() -> void:
		population.text = SpotStatus.population(game.state)
		label.text = lifetime_text(game.state)
	)
	return card


func is_bottleneck(key: String) -> bool:
	return _bottlenecks.has(key)


func area_report(kind: String, key: String = "") -> Dictionary:
	return _areas.get(kind + "|" + key, {})


func recommended() -> Array[Dictionary]:
	return _recommended


static func load_of(state: GameState, station: Station) -> float:
	return ThroughputReport.load_of(Formulas.station_demand(state, station.key), Formulas.station_throughput(state, station))


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


static func set_highlight(label: Label, on: bool) -> void:
	if bool(label.get_meta(&"highlight", false)) == on:
		return
	label.set_meta(&"highlight", on)
	if on:
		label.add_theme_color_override(&"font_color", AppTheme.accent("warning"))
	else:
		label.remove_theme_color_override(&"font_color")


static func upgrade_target(state: GameState, entry: Dictionary, upgrade: Dictionary) -> Array[String]:
	var found := UpgradeCatalog.find(state, str(upgrade.get("entry", "")))
	if found != null:
		return ["spot", found.spot]
	var station := state.station(str(entry.get("key", "")))
	if station != null:
		return ["spot", WorldLayout.STATION_PREFIX + station.key]
	return ["upgrades", ""]


func _update_report() -> void:
	var state := game.state
	_bottlenecks.clear()
	for dept in state.unlocked_departments():
		_bottlenecks[Formulas.bottleneck(state, dept)] = true
	_areas.clear()
	var areas := ThroughputReport.all_areas(state)
	for entry in areas:
		_areas[str(entry.area) + "|" + str(entry.key)] = entry
	_recommended = ThroughputReport.pick_recommendations(areas, RECOMMENDATIONS)


func _rate(kind: String, scope: String = "") -> String:
	var state := game.state
	return _per_minute(state.production.per_minute(kind, scope, state.play_time) / 60.0)


func _per_minute(per_second: float) -> String:
	if is_inf(per_second):
		return tr("STATS_UNLIMITED")
	return tr("FMT_PER_MINUTE") % UiKit.decimal(per_second * 60.0)


func _area_name(entry: Dictionary) -> String:
	if str(entry.area) == ThroughputReport.STATION:
		return StationCard.label_for(str(entry.key))
	return tr("AREA_" + str(entry.area).to_upper())


func _upgrade_name(upgrade: Dictionary) -> String:
	var entry_id := str(upgrade.get("entry", ""))
	var found := UpgradeCatalog.find(game.state, entry_id)
	if found != null:
		return UpgradeTexts.title(found)
	if str(upgrade.id) == ThroughputReport.TRACK:
		return tr("TRACK_" + entry_id.get_slice(":", 1).get_slice("@", 0).to_upper())
	return tr("UPGRADE_" + str(upgrade.id).to_upper())


func _upgrade_gain(upgrade: Dictionary) -> String:
	var gain := float(upgrade.gain)
	match str(upgrade.effect):
		ThroughputReport.RELIEF:
			return tr("FMT_GAIN_RELIEF") % UiKit.decimal(gain * 60.0)
		ThroughputReport.PLACES:
			return tr("FMT_GAIN_PLACES") % UiKit.number(gain)
	return tr("FMT_GAIN_CAPACITY") % UiKit.decimal(gain * 60.0)


func _upgrade_lines(entry: Dictionary, limit: int = -1) -> String:
	var upgrades: Array = entry.get("upgrades", [])
	if upgrades.is_empty():
		return tr("STATS_UPGRADES_NONE")
	var lines: Array[String] = []
	for upgrade: Dictionary in upgrades:
		if limit >= 0 and lines.size() >= limit:
			break
		lines.append(tr("FMT_UPGRADE") % [_upgrade_name(upgrade), _upgrade_gain(upgrade)])
	return "\n".join(lines)


func _metric(column: VBoxContainer, label_key: String) -> Label:
	return _metric_text(column, tr(label_key))


func _metric_text(column: VBoxContainer, text: String) -> Label:
	var row := UiKit.hbox(AppTheme.SPACING_SM)
	row.add_child(UiKit.label(text, "BodySmall", true))
	var value := UiKit.label("", "TitleSmall")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	column.add_child(row)
	return value


func _upgrade_block(column: VBoxContainer) -> Label:
	column.add_child(UiKit.label(tr("STATS_UPGRADES"), "LabelSmall", true))
	var lines := UiKit.label("", "BodySmall", true)
	column.add_child(lines)
	return lines


func _recommendation_card() -> Control:
	var card := UiKit.card("CardPrimary")
	var column := UiKit.vbox(AppTheme.SPACING_MD)
	var empty := UiKit.label(tr("STATS_UPGRADES_EMPTY"), "BodySmall", true)
	column.add_child(empty)
	var rows: Array[Dictionary] = []
	for index in RECOMMENDATIONS:
		rows.append(_recommendation_row(column))
	card.add_child(column)
	track(func() -> void:
		empty.visible = _recommended.is_empty()
		for index in rows.size():
			var row: Dictionary = rows[index]
			var box: Control = row.box
			box.visible = index < _recommended.size()
			if not box.visible:
				continue
			var entry := _recommended[index]
			(row.title as Label).text = tr("FMT_STATS_AREA_LOAD") % [_area_name(entry), UiKit.percent(float(entry.load))]
			(row.lines as Label).text = _upgrade_lines(entry, UPGRADE_LINES)
			var first: Dictionary = (entry.upgrades as Array)[0]
			box.set_meta(&"target", upgrade_target(game.state, entry, first))
	)
	return card


func _recommendation_row(column: VBoxContainer) -> Dictionary:
	var box := UiKit.hbox(AppTheme.SPACING_MD)
	var texts := UiKit.vbox(2)
	var heading := UiKit.label("", "TitleSmall", true)
	texts.add_child(heading)
	var lines := UiKit.label("", "BodySmall", true)
	texts.add_child(lines)
	box.add_child(texts)
	var open := UiKit.icon_button(Icons.CHEVRON, "primary", "IconTonal")
	open.tooltip_text = tr("ACTION_STATS_OPEN")
	open.pressed.connect(func() -> void:
		var target: Array = box.get_meta(&"target", [])
		if target.size() == 2:
			navigate.emit(str(target[0]), str(target[1]))
	)
	box.add_child(open)
	column.add_child(box)
	return {"box": box, "title": heading, "lines": lines}


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
		capacity.text = _per_minute(total)
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
	var rank := _metric(column, "STATS_DEPT_RANK")
	var arrived := _metric(column, "STATS_DEPT_ARRIVED")
	var completed := _metric(column, "STATS_DEPT_COMPLETED")
	var capacity := _metric(column, "STATS_DEPT_CAPACITY")
	var waiting := _metric(column, "STATS_DEPT_WAITING")
	var coverage := UiKit.progress()
	column.add_child(coverage)
	column.add_child(UiKit.label(tr("STATS_DEPT_STEPS"), "LabelSmall", true))
	var steps: Array[Dictionary] = []
	for step in ThroughputReport.department_steps(game.state, dept):
		var key := str(step.key)
		var step_name := tr("STATS_STEP_TRANSPORT") if key == ThroughputReport.TRANSPORT else StationCard.label_for(key)
		steps.append({"key": key, "value": _metric_text(column, step_name)})
	var bottleneck := UiKit.label("", "BodySmall", true)
	column.add_child(bottleneck)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		var demand := Formulas.demand(state, dept)
		var throughput := Formulas.department_throughput(state, dept)
		rank.text = tr("FMT_STATS_RANK") % [UpgradeTexts.rank_title(dept.rank), UpgradeTexts.fee_factor_text(dept.rank)]
		arrived.text = tr("FMT_STATS_MEASURED_EXPECTED") % [_rate(ProductionStats.ARRIVED, dept.id), UiKit.decimal(demand * 60.0)]
		completed.text = _rate(ProductionStats.COMPLETED, dept.id)
		capacity.text = _per_minute(throughput)
		waiting.text = str(Formulas.waiting_count(state, dept))
		var ratio := throughput / demand if demand > 0.0 else 1.0
		coverage.value = clampf(ratio, 0.0, 1.0)
		set_fill(coverage, "success" if throughput >= demand else "warning")
		var weakest := Formulas.bottleneck(state, dept)
		var rates := ThroughputReport.department_steps(state, dept)
		for index in mini(steps.size(), rates.size()):
			var value: Label = steps[index].value
			value.text = _per_minute(float(rates[index].rate))
			set_highlight(value, str(steps[index].key) == weakest)
		bottleneck.text = _bottleneck_text(weakest)
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
	var upgrades := _upgrade_block(column)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		var entry := area_report(ThroughputReport.STATION, key)
		if entry.is_empty():
			entry = ThroughputReport.station_area(state, station)
		measured.text = _rate(ProductionStats.STATION, key)
		capacity.text = _per_minute(float(entry.capacity))
		demand.text = _per_minute(float(entry.demand))
		var value := float(entry.load)
		load_bar.value = clampf(value, 0.0, 1.0)
		set_fill(load_bar, load_role(value))
		var working := 0
		for desk in station.moods.size():
			if station.is_working(desk):
				working += 1
		var lines: Array[String] = [tr("FMT_STATS_LOAD") % UiKit.percent(value)]
		var case_time := Formulas.station_case_time(state, station)
		if case_time > 0.0:
			lines.append(tr("FMT_STATS_CASE_TIME") % [UiKit.decimal(case_time), _per_minute(1.0 / case_time)])
		lines.append(tr("FMT_STATS_BOXES") % [station.inbox.size(), station.inbox_capacity(state.lobby_capacity()), station.outbox.size(), station.outbox_capacity()])
		lines.append(tr("FMT_STATS_WORKING") % [working, station.workers(), station.active_jobs()])
		details.text = "\n".join(lines)
		upgrades.text = _upgrade_lines(entry)
		pill.visible = is_bottleneck(key)
	)
	return card


func _area_card(kind: String, icon_code: String) -> Dictionary:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.icon(icon_code, AppTheme.accent("primary")))
	head.add_child(UiKit.label(tr("AREA_" + kind.to_upper()), "TitleSmall", true))
	column.add_child(head)
	card.add_child(column)
	return {"card": card, "column": column}


func _area_footer(column: VBoxContainer, kind: String) -> Callable:
	var capacity := _metric(column, "STATS_STATION_CAPACITY")
	var demand := _metric(column, "STATS_STATION_DEMAND")
	var load_bar := UiKit.progress()
	column.add_child(load_bar)
	var details := UiKit.label("", "BodySmall", true)
	column.add_child(details)
	var upgrades := _upgrade_block(column)
	return func(extra: Array[String]) -> void:
		var entry := area_report(kind)
		capacity.text = _per_minute(float(entry.capacity))
		demand.text = _per_minute(float(entry.demand))
		var value := float(entry.load)
		load_bar.value = clampf(value, 0.0, 1.0)
		set_fill(load_bar, load_role(value))
		var lines: Array[String] = [tr("FMT_STATS_LOAD") % UiKit.percent(value)]
		lines.append_array(extra)
		details.text = "\n".join(lines)
		upgrades.text = _upgrade_lines(entry)


func _transport_card() -> Control:
	var parts := _area_card(ThroughputReport.TRANSPORT, Icons.STAFF.runners)
	var column: VBoxContainer = parts.column
	var measured := _metric(column, "STATS_AREA_MEASURED")
	var footer := _area_footer(column, ThroughputReport.TRANSPORT)
	track(func() -> void:
		var state := game.state
		measured.text = _rate(ProductionStats.TRANSFER)
		var extra: Array[String] = [tr("FMT_STATS_TRANSFERS") % [_rate(ProductionStats.TRANSFER, ProductionStats.BY_PLAYER), _rate(ProductionStats.TRANSFER, ProductionStats.BY_RUNNER), _rate(ProductionStats.TRANSFER, ProductionStats.BY_TUBE)]]
		if state.any_piped():
			extra.append(tr("FMT_STATS_TUBES") % [Formulas.tube_capacity(state), state.tube_parcels.size()])
		if not state.all_piped():
			extra.append(tr("FMT_STATS_RUNNERS") % [state.runners.size(), Formulas.runner_capacity(state)])
			for role in Runner.ROLES:
				extra.append(BoardSection.role_info(state, role))
		footer.call(extra)
	)
	return parts.card


func _complaint_card() -> Control:
	var parts := _area_card(ThroughputReport.COMPLAINTS, Icons.SPOTS.complaint_desk)
	var column: VBoxContainer = parts.column
	var incoming := _metric(column, "STATS_AREA_INCOMING")
	var measured := _metric(column, "STATS_AREA_MEASURED")
	var footer := _area_footer(column, ThroughputReport.COMPLAINTS)
	track(func() -> void:
		var state := game.state
		incoming.text = _rate(ProductionStats.COMPLAINT)
		measured.text = _rate(ProductionStats.COMPLAINT_SHREDDED)
		var extra: Array[String] = [tr("FMT_STATS_HANDLED_BY") % [_rate(ProductionStats.COMPLAINT_SHREDDED, ProductionStats.BY_PLAYER), _rate(ProductionStats.COMPLAINT_SHREDDED, ProductionStats.BY_STAFF)]]
		extra.append(tr("FMT_STATS_COMPLAINT_STATE") % [state.complaints, Formulas.complaint_cap(state), state.interns.size(), UiKit.percent(Formulas.security_chance(state)) if state.has_upgrade("complaint_security") else tr("STATS_SECURITY_NONE")])
		footer.call(extra)
	)
	return parts.card


func _reject_card() -> Control:
	var parts := _area_card(ThroughputReport.REJECTS, Icons.STAFF.runners)
	var column: VBoxContainer = parts.column
	var incoming := _metric(column, "STATS_AREA_INCOMING")
	var measured := _metric(column, "STATS_AREA_MEASURED")
	var footer := _area_footer(column, ThroughputReport.REJECTS)
	track(func() -> void:
		var state := game.state
		incoming.text = _rate(ProductionStats.REJECTED)
		measured.text = _rate(ProductionStats.REJECT_SHREDDED)
		var extra: Array[String] = [tr("FMT_STATS_HANDLED_BY") % [_rate(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_PLAYER), _rate(ProductionStats.REJECT_SHREDDED, ProductionStats.BY_STAFF)]]
		extra.append(tr("FMT_STATS_REJECT_STATE") % [state.rejects_waiting(), state.runners_in(Runner.REJECT)])
		footer.call(extra)
	)
	return parts.card


func _ticket_card() -> Control:
	var parts := _area_card(ThroughputReport.TICKETS, Icons.TICKET)
	var footer := _area_footer(parts.column, ThroughputReport.TICKETS)
	track(func() -> void:
		var state := game.state
		var extra: Array[String] = [tr("FMT_STATS_TICKETS") % [state.ticket_line.size(), state.citizens.size() - state.ticket_line.size(), state.tickets_called, state.tickets_lapsed]]
		footer.call(extra)
	)
	return parts.card


func _phone_card() -> Control:
	var parts := _area_card(ThroughputReport.PHONES, Icons.STAFF.hr)
	var column: VBoxContainer = parts.column
	var incoming := _metric(column, "STATS_SICK_RATE")
	var answered := _metric(column, "STATS_CALLS_ANSWERED")
	var missed := _metric(column, "STATS_CALLS_MISSED")
	var footer := _area_footer(column, ThroughputReport.PHONES)
	track(func() -> void:
		var state := game.state
		incoming.text = _rate(ProductionStats.SICK)
		answered.text = _rate(ProductionStats.CALL_ANSWERED)
		missed.text = _rate(ProductionStats.CALL_MISSED)
		var calls := state.calls_answered + state.calls_missed
		var quota := UiKit.percent(float(state.calls_answered) / calls) if calls > 0 else "–"
		var extra: Array[String] = [tr("FMT_STATS_HANDLED_BY") % [_rate(ProductionStats.CALL_ANSWERED, ProductionStats.BY_PLAYER), _rate(ProductionStats.CALL_ANSWERED, ProductionStats.BY_STAFF)]]
		extra.append(tr("FMT_STATS_PHONE_STATE") % [state.ringing_count(), state.hr, quota])
		footer.call(extra)
	)
	return parts.card


func _hall_card(kind: String, icon_code: String) -> Control:
	var parts := _area_card(kind, icon_code)
	var column: VBoxContainer = parts.column
	var occupied := _metric(column, "STATS_OCCUPANCY")
	var load_bar := UiKit.progress()
	column.add_child(load_bar)
	var upgrades := _upgrade_block(column)
	track(func() -> void:
		var entry := area_report(kind)
		occupied.text = tr("FMT_STATS_OCCUPANCY") % [int(entry.demand), int(entry.capacity)]
		var value := float(entry.load)
		load_bar.value = clampf(value, 0.0, 1.0)
		set_fill(load_bar, load_role(value))
		upgrades.text = _upgrade_lines(entry)
	)
	return parts.card


func _absence_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var sick_now := _metric(column, "STATS_SICK_NOW")
	var sick := _metric(column, "STATS_SICK_RATE")
	var woken := _metric(column, "STATS_LEAD_WOKEN")
	var dozed := _metric(column, "STATS_DOZED")
	var disputes := _metric(column, "STATS_DISPUTES")
	var calmed := _metric(column, "STATS_DISPUTES_CALMED")
	var patrols := _metric(column, "STATS_PATROLS")
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		var production := state.production
		sick_now.text = str(state.sick_count())
		sick.text = _rate(ProductionStats.SICK)
		woken.text = str(production.total(ProductionStats.LEAD_WOKEN))
		dozed.text = _rate(ProductionStats.DOZED)
		disputes.text = tr("FMT_STATS_DISPUTES") % [state.disputes.size(), _rate(ProductionStats.DISPUTE)]
		calmed.text = str(production.total(ProductionStats.DISPUTE_CALMED))
		patrols.text = str(state.patrols)
	)
	return card


func _officials_card(station: Station) -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	column.add_child(UiKit.label(StationCard.label_for(station.key), "TitleSmall", true))
	var rows: Array[Dictionary] = []
	for desk in staffed_desks(station):
		rows.append(_official_row(column, station, desk))
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		for row in rows:
			var mood: DeskMood = row.mood
			(row.info as Label).text = tr("FMT_STATS_OFFICIAL") % [official_state(mood), UiKit.decimal(mood.output.per_minute(state.play_time, state.production.started)), mood.output.total, mood.sick_count, mood.doze_count]
	)
	return card


func _official_row(column: VBoxContainer, station: Station, desk: int) -> Dictionary:
	var row := UiKit.vbox(2)
	var head := UiKit.hbox(AppTheme.SPACING_SM)
	head.add_child(UiKit.label(official_name(desk), "BodyMedium", true))
	row.add_child(head)
	var info := UiKit.label("", "BodySmall", true)
	row.add_child(info)
	column.add_child(row)
	return {"mood": station.moods[desk], "info": info}


static func staffed_desks(target: Station) -> Array[int]:
	var result: Array[int] = []
	for desk in target.moods.size():
		if target.is_staffed(desk):
			result.append(desk)
	return result


static func official_name(desk: int) -> String:
	return TranslationServer.translate("FMT_OFFICIAL_NAME") % (desk + 1)


static func official_state(mood: DeskMood) -> String:
	return TranslationServer.translate("OFFICIAL_STATE_" + mood.state.to_upper())
