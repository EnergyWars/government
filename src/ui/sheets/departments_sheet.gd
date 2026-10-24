class_name DepartmentsSheet
extends Sheet


func title() -> String:
	return tr("SHEET_DEPARTMENTS")


func build(container: VBoxContainer) -> void:
	var state := game.state
	var stage := state.stage_config()
	container.add_child(UiKit.label(tr("FMT_DEPARTMENT_SLOTS") % [state.unlocked_count(), int(stage.max_departments)], "BodySmall"))
	container.add_child(UiKit.label(tr("LEGEND_MARKERS"), "BodySmall", true))
	for dept_id in GameConfig.department_ids():
		var dept := state.department(dept_id)
		container.add_child(_unlocked_card(dept) if dept.unlocked else _locked_card(dept))


func _unlocked_card(dept: Department) -> Control:
	var card := UiKit.card("CardRow")
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.department(dept.id), AppTheme.department_color(dept.id)))
	var column := UiKit.vbox(2)
	column.add_child(UiKit.label(tr("DEPT_" + dept.id.to_upper()), "TitleSmall", true))
	var stats := UiKit.label("", "BodySmall", true)
	column.add_child(stats)
	var jam := UiKit.label("", "BodySmall", true)
	jam.add_theme_color_override(&"font_color", AppTheme.accent("error"))
	column.add_child(jam)
	row.add_child(column)
	var bottleneck_pill := UiKit.pill(tr("LABEL_BOTTLENECK"), "warning")
	row.add_child(bottleneck_pill)
	var open := UiKit.icon_button(Icons.CHEVRON, "primary", "IconTonal")
	open.pressed.connect(func() -> void: navigate.emit("department", dept.id))
	row.add_child(open)
	card.add_child(row)
	track(func() -> void:
		var per_minute := Formulas.department_throughput(game.state, dept) * 60.0
		var waiting := Formulas.waiting_count(game.state, dept)
		stats.text = tr("FMT_DEPT_SUMMARY") % [UiKit.decimal(per_minute), waiting]
		var weakest := Formulas.bottleneck(game.state, dept)
		bottleneck_pill.visible = weakest != "demand"
		var boxes := Formulas.full_boxes(game.state, dept)
		jam.visible = not boxes.is_empty()
		if jam.visible:
			jam.text = tr("FMT_JAM") % _jam_names(boxes)
	)
	return card


func _jam_names(boxes: Array[Dictionary]) -> String:
	var names: Array[String] = []
	for box in boxes.slice(0, 3):
		names.append("%s (%s)" % [StationCard.label_for(str(box.key)), tr("JAM_SIDE_" + str(box.side).to_upper())])
	var text := ", ".join(names)
	return text + " …" if boxes.size() > 3 else text


func _locked_card(dept: Department) -> Control:
	var config := dept.config()
	var card := UiKit.card("CardRow")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.LOCK, AppTheme.ON_SURFACE_VARIANT))
	var text_column := UiKit.vbox(2)
	text_column.add_child(UiKit.label(tr("DEPT_" + dept.id.to_upper()), "TitleSmall", true))
	text_column.add_child(UiKit.label(tr("DEPT_DESC_" + dept.id.to_upper()), "BodySmall", true))
	row.add_child(text_column)
	column.add_child(row)
	var requirement := UiKit.label("", "BodySmall", true)
	column.add_child(requirement)
	var unlock := UiKit.button(UiKit.cost_text("ACTION_UNLOCK", float(config.unlock_cost)))
	unlock.pressed.connect(func() -> void: act(game.actions.unlock_department.bind(dept.id)))
	column.add_child(unlock)
	card.add_child(column)
	track(func() -> void:
		var reason := Progression.unlock_block_reason(game.state, dept.id)
		unlock.disabled = not reason.is_empty()
		if reason == "space":
			requirement.text = tr("REQ_MORE_SPACE")
		else:
			requirement.text = tr("FMT_REQ_REPUTATION") % int(config.unlock_reputation)
		if Progression.next_locked_department(game.state) == dept.id:
			requirement.text += "\n" + tr("HINT_UNLOCK_PAD")
	)
	return card
