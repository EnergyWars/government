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
	container.add_child(UiKit.label(tr("SECTION_FEEDBACK"), "TitleMedium"))
	var feedback_card := UiKit.card()
	var feedback := UiKit.vbox(AppTheme.SPACING_SM)
	feedback.add_child(UiKit.switch(tr("SETTING_SOUND"), settings.sound, settings.set_sound))
	feedback.add_child(UiKit.switch(tr("SETTING_HAPTICS"), settings.haptics, settings.set_haptics))
	feedback_card.add_child(feedback)
	container.add_child(feedback_card)
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
	var about_column := UiKit.vbox(AppTheme.SPACING_SM)
	about_column.add_child(UiKit.label(tr("ABOUT_TEXT"), "BodySmall", true))
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	about_column.add_child(UiKit.label(version_text(BuildInfo.load_from(), bias), "BodySmall", true))
	about.add_child(about_column)
	container.add_child(about)


func version_text(info: BuildInfo, bias_minutes: int) -> String:
	if not info.has_timestamp():
		return tr("ABOUT_VERSION") % info.version
	var date := info.local_datetime(bias_minutes)
	var stamp := tr("ABOUT_BUILD_DATE").format({
		"year": "%04d" % date.year,
		"month": "%02d" % date.month,
		"day": "%02d" % date.day,
		"hour": "%02d" % date.hour,
		"minute": "%02d" % date.minute,
	})
	return tr("ABOUT_VERSION_BUILT") % [info.version, stamp]
