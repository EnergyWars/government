class_name BuildingSheet
extends Sheet


func title() -> String:
	return tr("SHEET_BUILDING")


func build(container: VBoxContainer) -> void:
	var state := game.state
	for index in GameConfig.BUILDING_STAGES.size():
		container.add_child(_stage_card(index, state.building_stage))
	container.add_child(UiKit.label(tr("SECTION_STATISTICS"), "TitleMedium"))
	container.add_child(_statistics())


func _stage_card(index: int, current: int) -> Control:
	var config := GameConfig.building_stage(index)
	var variation := "CardPrimary" if index == current else "CardRow"
	var card := UiKit.card(variation)
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	var done := index <= current
	var icon_color: Color = AppTheme.accent("success" if done else "neutral")
	row.add_child(UiKit.icon_disc(Icons.CHECK if done else Icons.DOMAIN, icon_color))
	var texts := UiKit.vbox(2)
	texts.add_child(UiKit.label(tr("FMT_STAGE_TITLE") % [index + 1, tr("STAGE_" + str(config.id).to_upper())], "TitleSmall", true))
	texts.add_child(UiKit.label(tr("FMT_STAGE_INFO") % [int(config.max_departments), int(config.max_desks), int(config.lobby)], "BodySmall", true))
	row.add_child(texts)
	if index == current:
		row.add_child(UiKit.pill(tr("LABEL_CURRENT"), "primary"))
	column.add_child(row)
	if index == current + 1:
		var requirement := UiKit.label("", "BodySmall", true)
		column.add_child(requirement)
		var button := UiKit.button(UiKit.cost_text("ACTION_EXPAND", float(config.cost)))
		button.pressed.connect(func() -> void: act(game.actions.expand_building))
		column.add_child(button)
		track(func() -> void:
			var reason := Progression.expansion_block_reason(game.state)
			button.disabled = not reason.is_empty()
			requirement.text = tr("FMT_REQ_REPUTATION") % int(config.reputation)
		)
	card.add_child(column)
	return card


func _statistics() -> Control:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var population := UiKit.label("", "TitleSmall", true)
	column.add_child(population)
	var label := UiKit.label("", "BodyMedium", true)
	column.add_child(label)
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		population.text = tr("FMT_POPULATION") % [UiKit.number(Formulas.population(state)), tr("SETTLEMENT_" + Formulas.settlement(state).to_upper())]
		var accuracy := 1.0
		if state.cases_completed > 0:
			accuracy = 1.0 - float(state.cases_flawed) / state.cases_completed
		label.text = tr("FMT_STATISTICS") % [
			UiKit.number(state.cases_completed),
			UiKit.percent(accuracy),
			UiKit.number(state.citizens_lost),
			UiKit.number(state.wakes),
			UiKit.number(state.total_staff()),
			UiKit.money(state.money_earned),
			UiKit.duration(state.play_time),
		]
	)
	return card
