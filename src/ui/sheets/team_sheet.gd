class_name TeamSheet
extends Sheet


func title() -> String:
	return tr("SHEET_TEAM")


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("TEAM_INTRO"), "BodySmall", true))
	container.add_child(UiKit.label(tr("SECTION_TRANSPORT"), "TitleMedium"))
	container.add_child(_runner_card())
	container.add_child(_collector_card())
	container.add_child(_helper_card())
	container.add_child(_coffee_intern_card())
	container.add_child(UiKit.label(tr("SECTION_ABSENCE"), "TitleMedium"))
	container.add_child(_hr_card())
	container.add_child(UiKit.label(tr("SECTION_PUBLIC_AREA"), "TitleMedium"))
	container.add_child(_guard_card())
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
		info.text = tr("FMT_HR_INFO") % [state.sick_count(), state.reported_sick_count(), state.ringing_count()]
		StationCard.update_button(button, "ACTION_HIRE", Formulas.hr_cost(state), game.actions.can_hire_hr(), state.hr >= GameConfig.MAX_HR, "LABEL_MAX_LEVEL")
	)
	return card


func _guard_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.guards, AppTheme.GUARD))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("STAFF_DESC_GUARDS"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(self, game.actions.hire_guard)
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_GUARDS"), state.guards, GameConfig.MAX_GUARDS]
		info.text = tr("FMT_GUARD_INFO") % [roundi(Formulas.guard_block_chance(state) * 100.0), state.visitors_stopped]
		StationCard.update_button(button, "ACTION_HIRE", Formulas.guard_cost(state), game.actions.can_hire_guard(), state.guards >= GameConfig.MAX_GUARDS, "LABEL_MAX_LEVEL")
	)
	return card


func _helper_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.helpers, AppTheme.accent("tertiary")))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("STAFF_DESC_HELPERS"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(self, game.actions.hire_helper)
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_HELPERS"), state.helpers.size(), GameConfig.MAX_HELPERS]
		info.text = tr("FMT_HELPER_INFO") % Formulas.intern_capacity(state) if state.has_research("shredder_service") else tr("LABEL_NEEDS_SHREDDER_SERVICE")
		StationCard.update_button(button, "ACTION_HIRE", Formulas.helper_cost(state), game.actions.can_hire_helper(), state.helpers.size() >= GameConfig.MAX_HELPERS, "LABEL_MAX_LEVEL")
	)
	return card


func _collector_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.collectors, AppTheme.accent("neutral")))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("STAFF_DESC_COLLECTORS"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(self, game.actions.hire_collector)
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_COLLECTORS"), state.collectors.size(), GameConfig.MAX_COLLECTORS]
		info.text = tr("FMT_COLLECTOR_INFO") % [GameConfig.COLLECTOR_CAPACITY, state.rejects_waiting()]
		StationCard.update_button(button, "ACTION_HIRE", Formulas.collector_cost(state), game.actions.can_hire_collector(), state.collectors.size() >= GameConfig.MAX_COLLECTORS, "LABEL_MAX_LEVEL")
	)
	return card


func _coffee_intern_card() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.coffee_interns, AppTheme.COFFEE_LIQUID))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("STAFF_DESC_COFFEE_INTERNS"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(self, game.actions.hire_coffee_intern)
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		name_label.text = tr("FMT_STAFF_COUNT") % [tr("STAFF_COFFEE_INTERNS"), state.coffee_interns.size(), GameConfig.MAX_COFFEE_INTERNS]
		info.text = tr("FMT_COFFEE_INTERN_INFO") % state.coffees_served
		StationCard.update_button(button, "ACTION_HIRE", Formulas.coffee_intern_cost(state), game.actions.can_hire_coffee_intern(), state.coffee_interns.size() >= GameConfig.MAX_COFFEE_INTERNS, "LABEL_MAX_LEVEL")
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
