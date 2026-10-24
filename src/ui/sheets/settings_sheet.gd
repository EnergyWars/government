class_name SettingsSheet
extends Sheet

var settings: AppSettings


func with_settings(p_settings: AppSettings) -> SettingsSheet:
	settings = p_settings
	return self


func title() -> String:
	return tr("SHEET_SETTINGS")


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("SECTION_LANGUAGE"), "TitleMedium"))
	var card := UiKit.card()
	var options: Array[String] = [tr("LANGUAGE_SYSTEM"), tr("LANGUAGE_DE"), tr("LANGUAGE_EN")]
	card.add_child(UiKit.segmented(options, AppSettings.LOCALES.find(settings.locale), func(index: int) -> void:
		settings.set_locale(AppSettings.LOCALES[index])
		rebuild()
	))
	container.add_child(card)
	container.add_child(UiKit.label(tr("SECTION_GAME"), "TitleMedium"))
	var game_card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	column.add_child(UiKit.label(tr("TUTORIAL_REPLAY_HINT"), "BodySmall", true))
	var replay := UiKit.button(tr("TUTORIAL_REPLAY"), "primary", "Outlined")
	replay.pressed.connect(func() -> void: navigate.emit("tutorial", ""))
	column.add_child(replay)
	column.add_child(HSeparator.new())
	column.add_child(UiKit.label(tr("RESET_HINT"), "BodySmall", true))
	var reset := UiKit.button(tr("ACTION_RESET"), "error", "Tonal")
	reset.pressed.connect(func() -> void: navigate.emit("reset", ""))
	column.add_child(reset)
	game_card.add_child(column)
	container.add_child(game_card)
	container.add_child(UiKit.label(tr("SECTION_ABOUT"), "TitleMedium"))
	var about := UiKit.card()
	about.add_child(UiKit.label(tr("ABOUT_TEXT"), "BodySmall", true))
	container.add_child(about)
