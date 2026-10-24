class_name GoalsSheet
extends Sheet


func title() -> String:
	return tr("SHEET_GOALS")


func build(container: VBoxContainer) -> void:
	var state := game.state
	container.add_child(UiKit.banner(Icons.INFO, tr("WISDOM_TITLE"), Flavor.wisdom(Time.get_unix_time_from_system())))
	if not game.goals.has_goal():
		container.add_child(UiKit.banner(Icons.TROPHY, tr("GOALS_ALL_DONE"), tr("GOALS_ALL_DONE_TEXT"), "success"))
	for index in GameConfig.GOALS.size():
		container.add_child(_goal_row(index, state.goal_index))


func _goal_row(index: int, current: int) -> Control:
	var goal: Dictionary = GameConfig.GOALS[index]
	var card := UiKit.card("CardPrimary" if index == current else "CardRow")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	var done := index < current
	var icon_code := Icons.CHECK if done else (Icons.FLAG if index == current else Icons.LOCK)
	var icon_role := "success" if done else ("primary" if index == current else "neutral")
	row.add_child(UiKit.icon_disc(icon_code, AppTheme.accent(icon_role)))
	var texts := UiKit.vbox(2)
	texts.add_child(UiKit.label(GoalText.describe(goal), "TitleSmall", true))
	texts.add_child(UiKit.label(GoalText.reward(goal), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	if index == current:
		var bar := UiKit.progress()
		column.add_child(bar)
		var claim := UiKit.button(tr("ACTION_CLAIM"))
		claim.pressed.connect(func() -> void: act(game.goals.claim))
		column.add_child(claim)
		track(func() -> void:
			bar.value = clampf(game.goals.current_progress() / float(goal.target), 0.0, 1.0)
			claim.disabled = not game.goals.is_complete()
		)
	card.add_child(column)
	return card
