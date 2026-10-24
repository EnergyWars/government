class_name DepartmentSheet
extends Sheet


func dept() -> Department:
	return game.state.department(argument)


func title() -> String:
	return tr("DEPT_" + argument.to_upper())


func build(container: VBoxContainer) -> void:
	container.add_child(_summary())
	container.add_child(UiKit.label(tr("SECTION_WORK_MODE"), "TitleMedium"))
	container.add_child(_work_mode())
	container.add_child(UiKit.label(tr("SECTION_STATIONS"), "TitleMedium"))
	container.add_child(UiKit.label(_route_text(), "BodySmall", true))
	var keys := dept().station_keys()
	for index in keys.size():
		container.add_child(StationCard.build(self, keys[index], index))
	var shared := _shared_route_keys(keys)
	if not shared.is_empty():
		container.add_child(UiKit.label(tr("SECTION_SHARED_STATIONS"), "TitleMedium"))
		for key in shared:
			container.add_child(StationCard.build(self, key))
	container.add_child(UiKit.label(tr("SECTION_TEAM"), "TitleMedium"))
	container.add_child(_supervisor_row())


func _shared_route_keys(own_keys: Array[String]) -> Array[String]:
	var shared: Array[String] = []
	for key in RouteBuilder.required_stations(argument):
		if not own_keys.has(key) and game.state.station(key) != null:
			shared.append(key)
	return shared


func _route_text() -> String:
	var names: Array[String] = []
	for key in RouteBuilder.build(CaseFile.new(argument)):
		names.append(StationCard.label_for(key))
	return tr("FMT_ROUTE") % " → ".join(names)


func _summary() -> Control:
	var card := UiKit.card("CardPrimary")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.department(argument), AppTheme.department_color(argument), 48))
	var description := UiKit.label(tr("DEPT_DESC_" + argument.to_upper()), "BodyMedium", true)
	description.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	row.add_child(description)
	column.add_child(row)
	var stats := UiKit.label("", "BodySmall", true)
	stats.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	column.add_child(stats)
	var bottleneck := UiKit.label("", "TitleSmall", true)
	bottleneck.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	column.add_child(bottleneck)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		stats.text = tr("FMT_DEPT_DETAIL") % [
			UiKit.decimal(Formulas.department_throughput(state, dept()) * 60.0),
			UiKit.decimal(Formulas.demand(state, dept()) * 60.0),
			UiKit.percent(Formulas.error_chance(state, dept())),
			UiKit.money(Formulas.expected_case_value(state, dept())),
		]
		bottleneck.text = _bottleneck_text(Formulas.bottleneck(state, dept()))
	)
	return card


func _bottleneck_text(weakest: String) -> String:
	match weakest:
		"demand":
			return tr("BOTTLENECK_DEMAND")
		"transport":
			return tr("BOTTLENECK_TRANSPORT")
	return tr("FMT_BOTTLENECK_STATION") % StationCard.label_for(weakest)


func _work_mode() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var options: Array[String] = []
	for mode: Dictionary in GameConfig.THOROUGHNESS:
		options.append(tr("MODE_" + str(mode.id).to_upper()))
	column.add_child(UiKit.segmented(options, dept().thoroughness, func(index: int) -> void:
		game.perform(game.actions.set_thoroughness.bind(argument, index))
		refresh()
	))
	var explanation := UiKit.label("", "BodySmall", true)
	column.add_child(explanation)
	column.add_child(UiKit.label(tr("MODE_HINT"), "BodySmall", true))
	column.add_child(HSeparator.new())
	column.add_child(UiKit.switch(tr("SWITCH_URGENT_FIRST"), dept().prioritize_urgent, func(value: bool) -> void:
		game.actions.set_prioritize_urgent(argument, value)
	))
	if dept().is_customs():
		column.add_child(HSeparator.new())
		column.add_child(UiKit.switch(tr("SWITCH_SCAN_ALL"), dept().scan_all, func(value: bool) -> void:
			game.actions.set_scan_all(argument, value)
		))
		column.add_child(UiKit.label(tr("SCAN_ALL_HINT"), "BodySmall", true))
	card.add_child(column)
	track(func() -> void:
		var mode: Dictionary = GameConfig.THOROUGHNESS[dept().thoroughness]
		explanation.text = tr("FMT_MODE_EFFECT") % [UiKit.percent(float(mode.time)), UiKit.percent(Formulas.error_chance(game.state, dept()))]
	)
	return card


func _supervisor_row() -> Control:
	var card := UiKit.card("CardRow")
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.supervisors, AppTheme.accent("primary")))
	var column := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	column.add_child(name_label)
	column.add_child(UiKit.label(tr("STAFF_DESC_SUPERVISORS"), "BodySmall", true))
	row.add_child(column)
	var button := UiKit.button("")
	button.custom_minimum_size.x = 120
	button.pressed.connect(func() -> void: act(game.actions.hire_supervisor.bind(argument)))
	row.add_child(button)
	card.add_child(row)
	track(func() -> void:
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_SUPERVISORS"), dept().supervisors, GameConfig.MAX_SUPERVISORS]
		StationCard.update_button(button, "ACTION_HIRE", Formulas.supervisor_cost(dept()), game.actions.can_hire_supervisor(argument), dept().supervisors >= GameConfig.MAX_SUPERVISORS, "LABEL_MAX_LEVEL")
	)
	return card
