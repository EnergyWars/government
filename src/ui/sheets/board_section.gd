class_name BoardSection
extends RefCounted


static func build(sheet: Sheet, container: VBoxContainer, spot: String) -> void:
	container.add_child(UiKit.label(sheet.tr("SECTION_SHIFT_PLAN"), "TitleMedium"))
	match spot:
		"runners":
			_runners(sheet, container)
		"coffee_interns":
			_coffee_interns(sheet, container)
		"phone_clerks":
			_phone_clerks(sheet, container)


static func department_text(dept_id: String) -> String:
	if dept_id == Runner.ALL_DEPARTMENTS:
		return TranslationServer.translate("RUNNER_ALL_DEPARTMENTS")
	return TranslationServer.translate("DEPT_" + dept_id.to_upper())


static func empty_hint(sheet: Sheet, container: VBoxContainer, key: String) -> void:
	container.add_child(UiKit.label(sheet.tr(key), "BodyMedium", true))


static func _runners(sheet: Sheet, container: VBoxContainer) -> void:
	var state := sheet.game.state
	container.add_child(UiKit.label(sheet.tr("RUNNERS_INTRO"), "BodySmall", true))
	if state.any_piped():
		container.add_child(UiKit.banner(Icons.upgrade("pneumatic_tubes"), sheet.tr("LABEL_TUBES_ACTIVE"), sheet.tr("RUNNERS_TUBES_PARTIAL_TEXT")))
	if state.runners.is_empty():
		empty_hint(sheet, container, "RUNNERS_EMPTY")
		return
	for role in Runner.ROLES:
		container.add_child(UiKit.label(sheet.tr("RUNNER_ROLE_" + role.to_upper()), "TitleSmall"))
		var summary := UiKit.label("", "BodySmall", true)
		container.add_child(summary)
		sheet.track(func() -> void: summary.text = role_summary(state, role))
		for index in state.runners.size():
			if state.runners[index].role == role:
				container.add_child(runner_row(sheet, index))


static func role_summary(state: GameState, role: String) -> String:
	return TranslationServer.translate("FMT_RUNNER_ROLE_SUMMARY") % [TranslationServer.translate("RUNNER_ROLE_DESC_" + role.to_upper()), state.transfer_backlog(role), UiKit.decimal(Formulas.role_capacity(state, role) * 60.0), UiKit.decimal(Formulas.role_demand(state, role) * 60.0)]


static func runner_row(sheet: Sheet, index: int) -> Control:
	var game := sheet.game
	var runner := game.state.runners[index]
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.icon(Icons.STAFF.runners, AppTheme.RUNNER))
	head.add_child(UiKit.label(sheet.tr("FMT_RUNNER_NAME") % (index + 1), "TitleSmall", true))
	var status := UiKit.label("", "BodySmall", true)
	head.add_child(status)
	column.add_child(head)
	var roles: Array[String] = []
	for role in Runner.ROLES:
		roles.append(sheet.tr("RUNNER_ROLE_SHORT_" + role.to_upper()))
	column.add_child(UiKit.segmented(roles, Runner.ROLES.find(runner.role), func(choice: int) -> void: sheet.act(game.actions.set_runner_role.bind(index, Runner.ROLES[choice]))))
	var dept := UiKit.button(sheet.tr("FMT_RUNNER_DEPARTMENT") % department_text(runner.dept_id))
	dept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dept.pressed.connect(func() -> void: sheet.act(game.actions.cycle_runner_department.bind(index)))
	column.add_child(dept)
	var load_label := UiKit.label("", "BodySmall", true)
	column.add_child(load_label)
	column.add_child(UpgradeEntryCard.buy_button(sheet, "%s:%d" % [UpgradeCatalog.RUNNER_LEVEL, index]))
	card.add_child(column)
	sheet.track(func() -> void:
		status.text = sheet.tr("RUNNER_BUSY") if is_busy(runner) else sheet.tr("RUNNER_IDLE")
		load_label.text = level_text(game.state, runner)
	)
	return card


static func is_busy(runner: Runner) -> bool:
	return not runner.items.is_empty() or runner.task != Runner.Task.IDLE or runner.loaded > 0 or not runner.source.is_empty()


static func level_text(state: GameState, runner: Runner) -> String:
	return TranslationServer.translate("FMT_RUNNER_LEVEL") % [runner.level, GameConfig.MAX_RUNNER_LEVEL, Formulas.runner_load(state, runner)]


static func role_info(state: GameState, role: String) -> String:
	return TranslationServer.translate("FMT_RUNNER_ROLE_INFO") % [TranslationServer.translate("RUNNER_ROLE_" + role.to_upper()), state.runners_in(role), state.transfer_backlog(role)]


static func _coffee_interns(sheet: Sheet, container: VBoxContainer) -> void:
	var game := sheet.game
	var state := game.state
	container.add_child(UiKit.label(sheet.tr("COFFEE_INTERNS_INTRO"), "BodySmall", true))
	if state.coffee_interns.is_empty():
		empty_hint(sheet, container, "COFFEE_INTERNS_EMPTY")
		return
	for index in state.coffee_interns.size():
		var coffee_intern := state.coffee_interns[index]
		var row := _member_row(sheet, Icons.STAFF.coffee_interns, sheet.tr("FMT_COFFEE_INTERN_NAME") % (index + 1))
		var status: Label = row.get_meta(&"status")
		var focus := UiKit.button(sheet.tr("FMT_FOCUS") % department_text(coffee_intern.dept_id), "primary", "Outlined")
		focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus.pressed.connect(func() -> void: sheet.act(game.actions.cycle_coffee_intern_department.bind(index)))
		(row.get_meta(&"column") as VBoxContainer).add_child(focus)
		container.add_child(row)
		sheet.track(func() -> void: status.text = sheet.tr("COFFEE_TASK_" + str(CoffeeIntern.Task.keys()[coffee_intern.task])))


static func _phone_clerks(sheet: Sheet, container: VBoxContainer) -> void:
	var state := sheet.game.state
	container.add_child(UiKit.label(sheet.tr("PHONE_CLERKS_INTRO"), "BodySmall", true))
	if state.hr <= 0:
		empty_hint(sheet, container, "PHONE_CLERKS_EMPTY")
		return
	for line in state.hr:
		var row := _member_row(sheet, Icons.STAFF.hr, sheet.tr("FMT_PHONE_LINE") % (line + 1))
		var status: Label = row.get_meta(&"status")
		container.add_child(row)
		sheet.track(func() -> void: status.text = sheet.tr("PHONE_LINE_BUSY") if state.line_call(line) != null else sheet.tr("PHONE_LINE_FREE"))


static func _member_row(sheet: Sheet, icon_code: String, name: String) -> PanelContainer:
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.icon(icon_code, AppTheme.accent("primary")))
	head.add_child(UiKit.label(name, "TitleSmall", true))
	var status := UiKit.label("", "BodySmall", true)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(status)
	column.add_child(head)
	card.add_child(column)
	card.set_meta(&"status", status)
	card.set_meta(&"column", column)
	return card
