class_name StationCard
extends RefCounted


static func label_for(key: String) -> String:
	var kind := GameConfig.station_kind_of(key)
	var dept_id := GameConfig.station_dept(key)
	if kind == "signature" or (kind == "review" and not dept_id.is_empty()):
		return TranslationServer.translate(("STATION_%s_%s" % [dept_id, kind]).to_upper())
	return TranslationServer.translate("STATION_" + kind.to_upper())


static func build(sheet: Sheet, key: String, step: int = -1) -> Control:
	var game := sheet.game
	var station := game.state.station(key)
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var header := UiKit.hbox(AppTheme.SPACING_MD)
	var color_id := station.dept_id if not station.dept_id.is_empty() else ("inspection" if key == GameConfig.INSPECTION else "shared")
	header.add_child(UiKit.icon_disc(Icons.station_for(key), AppTheme.department_color(color_id)))
	var names := UiKit.vbox(0)
	var title := label_for(key)
	if step >= 0:
		title = sheet.tr("FMT_STEP") % [step + 1, title]
	names.add_child(UiKit.label(title, "TitleSmall", true))
	var subtitle := "LABEL_MACHINE" if station.machine else ("LABEL_SHARED_STATION" if station.is_shared() else "")
	if not subtitle.is_empty():
		names.add_child(UiKit.label(sheet.tr(subtitle), "BodySmall", true))
	header.add_child(names)
	var bottleneck_pill := UiKit.pill(sheet.tr("LABEL_BOTTLENECK"), "warning")
	header.add_child(bottleneck_pill)
	column.add_child(header)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var buttons := UiKit.hbox(AppTheme.SPACING_SM)
	var desk := action_button(sheet, game.actions.add_desk.bind(key))
	var upgrade := action_button(sheet, game.actions.upgrade.bind(key))
	var hire: Button = null
	buttons.add_child(desk)
	if not station.machine:
		hire = action_button(sheet, game.actions.hire.bind(key))
		buttons.add_child(hire)
	buttons.add_child(upgrade)
	column.add_child(buttons)
	var specialist: Button = null
	if station.supports_specialists():
		specialist = action_button(sheet, game.actions.hire_specialist.bind(key))
		column.add_child(UiKit.label(sheet.tr("STAFF_DESC_SPECIALISTS"), "BodySmall", true))
		column.add_child(specialist)
	card.add_child(column)
	sheet.track(func() -> void:
		var state := game.state
		var lines: Array[String] = []
		if not station.is_entry():
			lines.append(sheet.tr("FMT_INBOX") % [station.inbox.size(), station.inbox_capacity(state.lobby_capacity())])
		else:
			lines.append(sheet.tr("FMT_QUEUE") % [station.inbox.size(), station.inbox_capacity(state.lobby_capacity())])
		if not station.is_final():
			lines.append(sheet.tr("FMT_OUTBOX") % [station.outbox.size(), station.outbox_capacity()])
		if station.machine:
			lines.append(sheet.tr("FMT_MACHINES") % [station.desks, state.max_desks(), station.level])
		else:
			lines.append(sheet.tr("FMT_STAFFING") % [station.staff, station.desks, state.max_desks(), station.level])
		if station.resting_count() > 0:
			lines.append(sheet.tr("FMT_RESTING") % station.resting_count())
		if station.specialists > 0:
			lines.append(sheet.tr("FMT_SPECIALISTS") % [station.specialists, GameConfig.MAX_SPECIALISTS])
		lines.append(sheet.tr("FMT_THROUGHPUT") % UiKit.decimal(Formulas.station_throughput(state, station) * 60.0))
		if station.needs_manual_work() or (not station.machine and station.staff < station.desks):
			lines.append(sheet.tr("HINT_UNSTAFFED"))
		info.text = "\n".join(lines)
		var weakest := false
		for dept in state.departments_using(key):
			if Formulas.bottleneck(state, dept) == key:
				weakest = true
		bottleneck_pill.visible = weakest
		update_button(desk, "ACTION_ADD_MACHINE" if station.machine else "ACTION_ADD_DESK", Formulas.desk_cost(station), game.actions.can_add_desk(key), station.desks >= state.max_desks(), "LABEL_DESKS_FULL")
		if hire != null:
			update_button(hire, "ACTION_HIRE", Formulas.hire_cost(station), game.actions.can_hire(key), station.staff >= station.desks, "LABEL_NEED_DESK")
		update_button(upgrade, "ACTION_UPGRADE", Formulas.upgrade_cost(station), game.actions.can_upgrade(key), station.level >= GameConfig.MAX_STATION_LEVEL, "LABEL_MAX_LEVEL")
		if specialist != null:
			update_button(specialist, "ACTION_HIRE_SPECIALIST", Formulas.specialist_cost(station), game.actions.can_hire_specialist(key), station.specialists >= GameConfig.MAX_SPECIALISTS, "LABEL_MAX_LEVEL")
	)
	return card


static func action_button(sheet: Sheet, action: Callable) -> Button:
	var button := UiKit.button("")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 56
	button.pressed.connect(func() -> void: sheet.act(action))
	return button


static func update_button(button: Button, action_key: String, cost: float, enabled: bool, blocked: bool, blocked_key: String) -> void:
	if blocked:
		button.text = button.tr(blocked_key)
	else:
		button.text = button.tr(action_key) + "\n" + UiKit.money(cost)
	button.disabled = not enabled
