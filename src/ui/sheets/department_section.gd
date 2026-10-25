class_name DepartmentSection
extends RefCounted

const JAM_LIMIT := 3


static func build(sheet: Sheet, container: VBoxContainer, dept_id: String) -> void:
	var dept := sheet.game.state.department(dept_id)
	if dept == null or not dept.unlocked:
		return
	container.add_child(summary(sheet, dept_id))
	container.add_child(UiKit.label(sheet.tr("LEGEND_MARKERS"), "BodySmall", true))
	container.add_child(UiKit.label(sheet.tr("SECTION_WORK_MODE"), "TitleMedium"))
	container.add_child(work_mode(sheet, dept_id))
	container.add_child(UiKit.label(route_text(dept_id), "BodySmall", true))


static func route_text(dept_id: String) -> String:
	var names: Array[String] = []
	for key in RouteBuilder.build(CaseFile.new(dept_id)):
		names.append(StationCard.label_for(key))
	return TranslationServer.translate("FMT_ROUTE") % " → ".join(names)


static func summary(sheet: Sheet, dept_id: String) -> Control:
	var game := sheet.game
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var stats := UiKit.label("", "BodySmall", true)
	column.add_child(stats)
	var bottleneck := UiKit.label("", "TitleSmall", true)
	bottleneck.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	column.add_child(bottleneck)
	var jam := UiKit.label("", "BodySmall", true)
	jam.add_theme_color_override(&"font_color", AppTheme.accent("error"))
	column.add_child(jam)
	card.add_child(column)
	sheet.track(func() -> void:
		var state := game.state
		var dept := state.department(dept_id)
		stats.text = sheet.tr("FMT_DEPT_DETAIL") % [
			UiKit.decimal(Formulas.department_throughput(state, dept) * 60.0),
			UiKit.decimal(Formulas.demand(state, dept) * 60.0),
			UiKit.percent(Formulas.error_chance(state, dept)),
			UiKit.money(Formulas.expected_case_value(state, dept)),
		] + "\n" + sheet.tr("FMT_DEPT_WAITING") % Formulas.waiting_count(state, dept)
		bottleneck.text = bottleneck_text(Formulas.bottleneck(state, dept))
		jam.text = jam_text(Formulas.full_boxes(state, dept))
		jam.visible = not jam.text.is_empty()
	)
	return card


static func jam_text(boxes: Array[Dictionary]) -> String:
	if boxes.is_empty():
		return ""
	var names: Array[String] = []
	for box in boxes.slice(0, JAM_LIMIT):
		names.append("%s (%s)" % [StationCard.label_for(str(box.key)), TranslationServer.translate("JAM_SIDE_" + str(box.side).to_upper())])
	var text := ", ".join(names)
	return TranslationServer.translate("FMT_JAM") % (text + " …" if boxes.size() > JAM_LIMIT else text)


static func bottleneck_text(weakest: String) -> String:
	match weakest:
		"demand":
			return TranslationServer.translate("BOTTLENECK_DEMAND")
		"transport":
			return TranslationServer.translate("BOTTLENECK_TRANSPORT")
	return TranslationServer.translate("FMT_BOTTLENECK_STATION") % StationCard.label_for(weakest)


static func work_mode(sheet: Sheet, dept_id: String) -> Control:
	var game := sheet.game
	var dept := game.state.department(dept_id)
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var options: Array[String] = []
	for mode: Dictionary in GameConfig.THOROUGHNESS:
		options.append(sheet.tr("MODE_" + str(mode.id).to_upper()))
	column.add_child(UiKit.segmented(options, dept.thoroughness, func(index: int) -> void:
		game.perform(game.actions.set_thoroughness.bind(dept_id, index))
		sheet.refresh()
	))
	var explanation := UiKit.label("", "BodySmall", true)
	column.add_child(explanation)
	column.add_child(UiKit.label(sheet.tr("MODE_HINT"), "BodySmall", true))
	column.add_child(HSeparator.new())
	column.add_child(UiKit.switch(sheet.tr("SWITCH_URGENT_FIRST"), dept.prioritize_urgent, func(value: bool) -> void:
		game.actions.set_prioritize_urgent(dept_id, value)
	))
	if dept.is_customs():
		column.add_child(HSeparator.new())
		column.add_child(UiKit.switch(sheet.tr("SWITCH_SCAN_ALL"), dept.scan_all, func(value: bool) -> void:
			game.actions.set_scan_all(dept_id, value)
		))
		column.add_child(UiKit.label(sheet.tr("SCAN_ALL_HINT"), "BodySmall", true))
	card.add_child(column)
	sheet.track(func() -> void:
		var current := game.state.department(dept_id)
		var mode: Dictionary = GameConfig.THOROUGHNESS[current.thoroughness]
		explanation.text = sheet.tr("FMT_MODE_EFFECT") % [UiKit.percent(float(mode.time)), UiKit.percent(Formulas.error_chance(game.state, current))]
	)
	return card
