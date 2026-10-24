class_name ResearchSheet
extends Sheet


func title() -> String:
	return tr("SHEET_RESEARCH")


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("RESEARCH_INTRO"), "BodySmall", true))
	for group: Dictionary in GameConfig.RESEARCH_GROUPS:
		var group_id := str(group.id).to_upper()
		container.add_child(UiKit.label(tr("RESEARCH_GROUP_" + group_id), "TitleMedium"))
		container.add_child(UiKit.label(tr("RESEARCH_GROUP_DESC_" + group_id), "BodySmall", true))
		for research_id: String in group.items:
			container.add_child(_research_card(research_id))


func _research_card(research_id: String) -> Control:
	var config: Dictionary = GameConfig.RESEARCH[research_id]
	var card := UiKit.card("CardRow")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.RESEARCH[research_id], AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("RESEARCH_DESC_" + research_id.to_upper()), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info: Label = null
	if research_id == "tube_capacity":
		info = UiKit.label("", "BodySmall", true)
		column.add_child(info)
	var level_bar := UiKit.progress(0.0, "success")
	column.add_child(level_bar)
	var button := UiKit.button("")
	button.pressed.connect(func() -> void: act(game.actions.buy_research.bind(research_id)))
	column.add_child(button)
	card.add_child(column)
	track(func() -> void:
		var level := game.state.research_level(research_id)
		var maximum := int(config.max_level)
		name_label.text = tr("FMT_RESEARCH_LEVEL") % [tr("RESEARCH_" + research_id.to_upper()), level, maximum]
		level_bar.value = float(level) / maximum
		if info != null:
			info.text = tr("FMT_TUBE_CAPACITY") % Formulas.tube_capacity(game.state)
		var reason := Progression.research_block_reason(game.state, research_id)
		button.disabled = not reason.is_empty()
		match reason:
			"max":
				button.text = tr("LABEL_RESEARCHED")
			"requires":
				button.text = tr("FMT_REQ_RESEARCH") % tr("RESEARCH_" + str(config.requires).to_upper())
			"reputation":
				button.text = tr("FMT_REQ_REPUTATION") % int(config.reputation)
			_:
				button.text = UiKit.cost_text("ACTION_RESEARCH", Formulas.research_cost(research_id, level))
	)
	return card
