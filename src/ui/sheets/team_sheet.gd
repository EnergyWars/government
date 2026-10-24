class_name TeamSheet
extends Sheet


func title() -> String:
	return tr("SHEET_TEAM")


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("TEAM_INTRO"), "BodySmall", true))
	container.add_child(UiKit.label(tr("SECTION_TRANSPORT"), "TitleMedium"))
	container.add_child(_runner_card())
	container.add_child(UiKit.label(tr("SECTION_ABSENCE"), "TitleMedium"))
	container.add_child(_hr_card())
	container.add_child(UiKit.label(tr("SECTION_PUBLIC_AREA"), "TitleMedium"))
	for key in [GameConfig.RECEPTION, GameConfig.COUNTER, GameConfig.INSPECTION]:
		if game.state.station(key) != null:
			container.add_child(StationCard.build(self, key))


func _hr_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.hr, AppTheme.SPECIALIST))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("STAFF_DESC_HR"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(self, game.actions.hire_hr)
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_HR"), state.hr, GameConfig.MAX_HR]
		info.text = tr("FMT_HR_INFO") % [state.sick_count(), UiKit.decimal(state.hr * 60.0 / GameConfig.HR_CALL_SECONDS)]
		StationCard.update_button(button, "ACTION_HIRE", Formulas.hr_cost(state), game.actions.can_hire_hr(), state.hr >= GameConfig.MAX_HR, "LABEL_MAX_LEVEL")
	)
	return card


func _runner_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.runners, AppTheme.RUNNER))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("STAFF_DESC_RUNNERS"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(self, game.actions.hire_runner)
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_RUNNERS"), state.runners.size(), GameConfig.MAX_RUNNERS]
		if state.has_research("pneumatic_tubes"):
			info.text = tr("LABEL_TUBES_ACTIVE")
		else:
			info.text = tr("FMT_RUNNER_INFO") % [Formulas.runner_capacity(state), UiKit.decimal(Formulas.transport_throughput(state) * 60.0)]
		StationCard.update_button(button, "ACTION_HIRE", Formulas.runner_cost(state), game.actions.can_hire_runner(), state.runners.size() >= GameConfig.MAX_RUNNERS, "LABEL_MAX_LEVEL")
	)
	return card
