class_name RunnerSheet
extends Sheet


func title() -> String:
	return tr("SHEET_RUNNERS")


func build(container: VBoxContainer) -> void:
	var state := game.state
	container.add_child(UiKit.label(tr("RUNNERS_INTRO"), "BodySmall", true))
	if state.any_piped():
		container.add_child(UiKit.banner(Icons.STAFF.runners, tr("LABEL_TUBES_ACTIVE") if state.all_piped() else tr("RESEARCH_PNEUMATIC_TUBES"), tr("RUNNERS_TUBES_TEXT") if state.all_piped() else tr("RUNNERS_TUBES_PARTIAL_TEXT")))
	if state.runners.is_empty():
		container.add_child(UiKit.label(tr("RUNNERS_EMPTY"), "BodyMedium", true))
		return
	for role in Runner.ROLES:
		container.add_child(UiKit.label(tr("RUNNER_ROLE_" + role.to_upper()), "TitleMedium"))
		var summary := UiKit.label("", "BodySmall", true)
		container.add_child(summary)
		track(func() -> void: summary.text = role_summary(state, role))
		for index in state.runners.size():
			if state.runners[index].role == role:
				container.add_child(runner_row(index))


static func role_summary(state: GameState, role: String) -> String:
	return TranslationServer.translate("FMT_RUNNER_ROLE_SUMMARY") % [TranslationServer.translate("RUNNER_ROLE_DESC_" + role.to_upper()), state.transfer_backlog(role), UiKit.decimal(Formulas.role_capacity(state, role) * 60.0), UiKit.decimal(Formulas.role_demand(state, role) * 60.0)]


static func department_text(dept_id: String) -> String:
	if dept_id == Runner.ALL_DEPARTMENTS:
		return TranslationServer.translate("RUNNER_ALL_DEPARTMENTS")
	return TranslationServer.translate("DEPT_" + dept_id.to_upper())


func runner_row(index: int) -> Control:
	var runner := game.state.runners[index]
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	head.add_child(UiKit.icon(Icons.STAFF.runners, AppTheme.RUNNER))
	head.add_child(UiKit.label(tr("FMT_RUNNER_NAME") % (index + 1), "TitleSmall", true))
	var status := UiKit.label("", "BodySmall", true)
	head.add_child(status)
	column.add_child(head)
	var roles: Array[String] = []
	for role in Runner.ROLES:
		roles.append(tr("RUNNER_ROLE_SHORT_" + role.to_upper()))
	column.add_child(UiKit.segmented(roles, Runner.ROLES.find(runner.role), func(choice: int) -> void: act(game.actions.set_runner_role.bind(index, Runner.ROLES[choice]))))
	var dept := UiKit.button(tr("FMT_RUNNER_DEPARTMENT") % department_text(runner.dept_id))
	dept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dept.pressed.connect(func() -> void: act(game.actions.cycle_runner_department.bind(index)))
	column.add_child(dept)
	var load_label := UiKit.label("", "BodySmall", true)
	column.add_child(load_label)
	var upgrade_button := StationCard.action_button(self, game.actions.upgrade_runner.bind(index))
	column.add_child(upgrade_button)
	card.add_child(column)
	track(func() -> void:
		status.text = tr("RUNNER_BUSY") if not runner.items.is_empty() or runner.task != Runner.Task.IDLE else tr("RUNNER_IDLE")
		load_label.text = level_text(game.state, runner)
		StationCard.update_button(upgrade_button, "ACTION_UPGRADE_RUNNER", Formulas.runner_level_cost(runner), game.actions.can_upgrade_runner(index), runner.level >= GameConfig.MAX_RUNNER_LEVEL, "LABEL_MAX_LEVEL")
	)
	return card


static func level_text(state: GameState, runner: Runner) -> String:
	return TranslationServer.translate("FMT_RUNNER_LEVEL") % [runner.level, GameConfig.MAX_RUNNER_LEVEL, Formulas.runner_load(state, runner)]
