extends GutTest

const TEST_SETTINGS := "user://test_settings.cfg"
const MAX_SINGLE_LINE_WIDTH := 500.0

var _previous_locale := ""


func before_all() -> void:
	_previous_locale = TranslationServer.get_locale()


func after_each() -> void:
	DirAccess.remove_absolute(TEST_SETTINGS)
	TranslationServer.set_locale(_previous_locale)


func test_settings_validate_and_persist_locale() -> void:
	var settings := AppSettings.new(TEST_SETTINGS)
	settings.set_locale("de")
	assert_eq(TranslationServer.get_locale(), "de")
	var loaded := AppSettings.new(TEST_SETTINGS).load_settings()
	assert_eq(loaded.locale, "de")
	settings.set_locale("klingon")
	assert_eq(settings.locale, "")
	assert_true(AppSettings.LOCALES.has(settings.resolved_locale()))


func test_settings_ignore_invalid_stored_locale() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", "xx")
	config.save(TEST_SETTINGS)
	assert_eq(AppSettings.new(TEST_SETTINGS).load_settings().locale, "")
	assert_eq(AppSettings.new("user://missing_settings.cfg").load_settings().locale, "")


func test_settings_resolve_explicit_locale() -> void:
	var settings := AppSettings.new(TEST_SETTINGS)
	settings.locale = "en"
	assert_eq(settings.resolved_locale(), "en")


func test_translations_exist_for_both_languages() -> void:
	var keys := ["DEPT_GENERAL_SERVICES", "STATION_REVIEW", "ACTION_BUY", "FMT_MONEY"]
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s missing in %s" % [key, locale])
	TranslationServer.set_locale("de")
	assert_eq(TranslationServer.translate("DEPT_TAX_SERVICES"), "Finanzamt")
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate("DEPT_TAX_SERVICES"), "Tax office")


func test_every_content_id_is_translated() -> void:
	TranslationServer.set_locale("de")
	var keys: Array[String] = []
	for dept_id in GameConfig.department_ids():
		keys.append("DEPT_" + dept_id.to_upper())
		keys.append("DEPT_DESC_" + dept_id.to_upper())
	for kind in GameConfig.STATION_KINDS:
		keys.append("STATION_" + kind.to_upper())
		keys.append("STATION_SHORT_" + kind.to_upper())
	for upgrade_id in GameConfig.upgrade_ids():
		keys.append("TRACK_" + upgrade_id.to_upper())
		keys.append("TRACK_DESC_" + upgrade_id.to_upper())
	for spot: String in GameConfig.SPOTS:
		keys.append("SPOT_" + spot.to_upper())
		keys.append(UpgradeTexts.spot_description_key(spot))
	for topic_id in GameConfig.TOPICS:
		keys.append("TOPIC_" + topic_id.to_upper())
	for mode_id in UpgradesSheet.MODES:
		keys.append("UPGRADE_MODE_" + mode_id.to_upper())
		keys.append("UPGRADE_MODE_HINT_" + mode_id.to_upper())
	for kind: String in [UpgradeCatalog.LEVEL, UpgradeCatalog.DESK, UpgradeCatalog.HIRE, UpgradeCatalog.RUNNER_LEVEL, UpgradeCatalog.SEGMENT, UpgradeCatalog.STORAGE, UpgradeCatalog.UNLOCK, UpgradeCatalog.RANK, UpgradeCatalog.STAGE]:
		keys.append("ENTRY_DESC_" + kind.to_upper())
	for reason: String in UpgradeTexts.BLOCK_KEYS:
		keys.append(str(UpgradeTexts.BLOCK_KEYS[reason]))
	for stage: Dictionary in GameConfig.BUILDING_STAGES:
		keys.append("STAGE_" + str(stage.id).to_upper())
	for event_id in GameConfig.EVENTS:
		keys.append("EVENT_" + event_id.to_upper())
		keys.append("EVENT_DESC_" + event_id.to_upper())
	for role in Icons.STAFF:
		keys.append("STAFF_" + role.to_upper())
		keys.append("STAFF_DESC_" + role.to_upper())
	for dept_id in GameConfig.department_ids():
		for key in GameConfig.department_station_keys(dept_id):
			if GameConfig.station_kind_of(key) in ["review", "signature"]:
				keys.append(("STATION_%s_%s" % [dept_id, GameConfig.station_kind_of(key)]).to_upper())
	for mode: Dictionary in GameConfig.THOROUGHNESS:
		keys.append("MODE_" + str(mode.id).to_upper())
	for slot: String in WorldLayout.get_default().rooms:
		keys.append("DEPT_" + slot.to_upper())
	for key in keys:
		assert_ne(TranslationServer.translate(key), key, key)


func test_formatting_helpers_follow_locale() -> void:
	TranslationServer.set_locale("de")
	assert_eq(UiKit.money(1500.0), "1,5K €")
	assert_eq(UiKit.decimal(2.26), "2,3")
	assert_eq(UiKit.percent(0.125), "13 %")
	assert_eq(UiKit.duration(3700.0), "1 Std. 1 Min.")
	assert_eq(UiKit.duration(125.0), "2 Min.")
	assert_eq(UiKit.duration(5.0), "5 Sek.")
	assert_eq(UiKit.number(2000.0), "2K")
	TranslationServer.set_locale("en")
	assert_eq(UiKit.money(1500.0), "$1.5K")
	assert_eq(UiKit.cost_text("ACTION_BUY", 80.0), "Buy · $80")


func test_goal_texts() -> void:
	TranslationServer.set_locale("de")
	assert_eq(GoalText.describe({"type": "cases", "target": 3.0}), "Erledige 3 Fälle")
	assert_eq(GoalText.describe({"type": "department", "target": 1.0, "param": "tax_services"}), "Eröffne: Finanzamt")
	assert_eq(GoalText.describe({"type": "upgrade_level", "target": 1.0, "param": "pneumatic_tubes"}), "Führe ein: Rohrpost")
	assert_eq(GoalText.describe({"type": "upgrade_level", "target": 5.0, "param": "coffee"}), "Kaffeequalität auf Stufe 5")
	assert_eq(GoalText.describe({"type": "upgrades", "target": 1.0}), "Kaufe 1 Upgrade-Stufe")
	assert_eq(GoalText.describe({"type": "building_stage", "target": 1.0}), "Erweitere zu: Bürgeramt")
	assert_eq(GoalText.describe({"type": "runners", "target": 1.0}), "Stelle 1 Boten ein")
	assert_eq(GoalText.describe({"type": "reputation", "target": 30.0}), "Erreiche 30 Ansehen")
	assert_eq(GoalText.reward({"money": 60.0, "reputation": 1.0}), "Belohnung: 60 € und 1 Ansehen")
	assert_eq(GoalText.reward({"money": 800.0, "reputation": 0.0}), "Belohnung: 800 €")
	assert_eq(GoalText.claim_reward({"money": 60.0, "reputation": 1.0}), "Belohnung: 60 € und 1 Ansehen · Siegel +%d" % GameConfig.GOAL_SEALS)
	TranslationServer.set_locale("en")
	assert_eq(GoalText.claim_reward({"money": 800.0, "reputation": 0.0}), "Reward: $800 · seals +%d" % GameConfig.GOAL_SEALS)
	TranslationServer.set_locale("de")
	for goal: Dictionary in GameConfig.GOALS:
		assert_false(GoalText.describe(goal).contains("FMT_"), str(goal))


func test_theme_provides_variations() -> void:
	var theme := AppTheme.build()
	for variation in ["PrimaryTonal", "PrimaryFilled", "ErrorTonal", "NeutralText", "PrimaryOutlined", "NeutralIconStandard", "PrimaryIconTonal", "Segment", "NavItem"]:
		assert_eq(theme.get_type_variation_base(variation), &"Button", variation)
	for variation in ["CardOutlined", "CardPrimary", "Sheet", "Dialog", "BannerWarning", "PillPrimary"]:
		assert_eq(theme.get_type_variation_base(variation), &"PanelContainer", variation)
	for variation in ["TitleLarge", "BodySmall", "Icon"]:
		assert_eq(theme.get_type_variation_base(variation), &"Label", variation)
	var card := theme.get_stylebox(&"panel", "CardOutlined") as StyleBoxFlat
	assert_eq(card.corner_radius_top_left, AppTheme.RADIUS_CARD)
	assert_true(theme.has_icon(&"checked", "CheckButton"))


func test_theme_color_helpers() -> void:
	assert_eq(AppTheme.accent("error"), AppTheme.ROLES.error.accent)
	assert_eq(AppTheme.on_accent("primary"), AppTheme.ROLES.primary.on_accent)
	assert_eq(AppTheme.container("success"), AppTheme.ROLES.success.container)
	assert_eq(AppTheme.on_container("warning"), AppTheme.ROLES.warning.on_container)
	assert_eq(AppTheme.role("unknown"), AppTheme.ROLES.primary)
	assert_eq(AppTheme.department_color("unknown"), AppTheme.DEPARTMENT_COLORS.shared)
	for dept_id in GameConfig.department_ids():
		assert_true(AppTheme.DEPARTMENT_COLORS.has(dept_id), dept_id)
	assert_true(AppTheme.DEPARTMENT_COLORS.has("inspection"))
	var box := AppTheme.box(AppTheme.SURFACE, 10, AppTheme.OUTLINE, 4)
	assert_eq(box.border_width_left, 1)
	assert_eq(box.content_margin_left, 4.0)


func test_icons_cover_content() -> void:
	for dept_id in GameConfig.department_ids():
		assert_true(Icons.DEPARTMENTS.has(dept_id), dept_id)
	for kind in GameConfig.STATION_KINDS:
		assert_true(Icons.STATIONS.has(kind), kind)
	for upgrade_id in GameConfig.upgrade_ids():
		assert_true(Icons.UPGRADES.has(upgrade_id), upgrade_id)
	for spot: String in GameConfig.SPOTS:
		assert_true(Icons.SPOTS.has(spot), spot)
	for room_id in GameConfig.SERVICE_ROOMS:
		assert_true(Icons.ROOMS.has(room_id), room_id)
	for topic_id in GameConfig.TOPICS:
		assert_true(Icons.TOPICS.has(topic_id), topic_id)
	for boost_id in GameConfig.BOOST_ORDER:
		assert_true(Icons.BOOSTS.has(boost_id), boost_id)
	assert_eq(Icons.upgrade("nope"), Icons.UPGRADE)
	assert_eq(Icons.topic("nope"), Icons.UPGRADE)
	assert_eq(Icons.room(GameConfig.ROOM_KITCHEN), Icons.ROOMS.kitchen)
	assert_eq(Icons.room("general_services"), Icons.DEPARTMENTS.general_services)
	for dept_id in GameConfig.department_ids():
		assert_true(Icons.SIGNATURES.has(dept_id), dept_id)
	for event_id in GameConfig.EVENTS:
		assert_true(Icons.EVENTS.has(event_id), event_id)
	assert_eq(Icons.department("nope"), Icons.DEPARTMENTS.inspection)
	assert_eq(Icons.station("nope"), Icons.DESCRIPTION)
	assert_eq(Icons.signature("nope"), Icons.STATIONS.signature)
	assert_eq(Icons.station_for("tax_services/signature"), Icons.SIGNATURES.tax_services)
	assert_eq(Icons.station_for(GameConfig.COUNTER), Icons.STATIONS.counter)


func test_ui_kit_builds_components() -> void:
	var button := autofree(UiKit.button("Go", "error", "Text")) as Button
	assert_eq(button.theme_type_variation, &"ErrorText")
	var icon_button := autofree(UiKit.icon_button(Icons.CLOSE)) as Button
	assert_eq(icon_button.theme_type_variation, &"NeutralIconStandard")
	var chosen := []
	var segmented := autofree(UiKit.segmented(["A", "B"] as Array[String], 1, func(index: int) -> void: chosen.append(index))) as HBoxContainer
	assert_eq(segmented.get_child_count(), 2)
	assert_true((segmented.get_child(1) as Button).button_pressed)
	(segmented.get_child(0) as Button).pressed.emit()
	assert_eq(chosen, [0])
	var toggled := []
	var switch := autofree(UiKit.switch("x", true, func(value: bool) -> void: toggled.append(value))) as CheckButton
	switch.toggled.emit(false)
	assert_eq(toggled, [false])
	var bar := autofree(UiKit.progress(0.5, "error")) as ProgressBar
	assert_almost_eq(bar.value, 0.5, 0.001)
	assert_true(bar.has_theme_stylebox_override(&"fill"))
	assert_eq((autofree(UiKit.pill("p", "warning")) as PanelContainer).theme_type_variation, &"PillWarning")
	var banner := autofree(UiKit.banner(Icons.INFO, "T", "", "success")) as PanelContainer
	assert_eq(banner.theme_type_variation, &"BannerSuccess")
	var wrapped := autofree(UiKit.label("x", "BodySmall", true)) as Label
	assert_eq(wrapped.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_not_null(autofree(UiKit.icon_disc(Icons.STAR, AppTheme.MONEY)))
	assert_not_null(autofree(UiKit.spacer()))
	assert_not_null(autofree(UiKit.card()))
	assert_not_null(autofree(UiKit.vbox()))
	assert_not_null(autofree(UiKit.hbox()))


func test_flavor_texts_exist_in_both_languages() -> void:
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for i in Flavor.QUIP_COUNT:
			assert_ne(Flavor.quip(i), "QUIP_%d" % (i + 1), "%s quip %d" % [locale, i])
		for i in Flavor.DONE_COUNT:
			assert_ne(Flavor.done(i), "FLOAT_DONE_%d" % (i + 1), "%s done %d" % [locale, i])
		for i in Flavor.FLAWED_COUNT:
			assert_ne(Flavor.flawed(i), "FLOAT_FLAWED_%d" % (i + 1), "%s flawed %d" % [locale, i])
		for i in Flavor.NAP_COUNT:
			assert_ne(Flavor.nap(i), "NAP_%d" % (i + 1), "%s nap %d" % [locale, i])
		for i in Flavor.COFFEE_BREAK_COUNT:
			assert_ne(Flavor.coffee_break(i), "COFFEE_BREAK_%d" % (i + 1), "%s coffee %d" % [locale, i])
		for i in Flavor.WOKE_COUNT:
			assert_ne(Flavor.woke(i), "WOKE_%d" % (i + 1), "%s woke %d" % [locale, i])
		for i in Flavor.CHAT_COUNT:
			assert_ne(Flavor.chat(i), "CHAT_%d" % (i + 1), "%s chat %d" % [locale, i])
		for i in Flavor.GO_KITCHEN_COUNT:
			assert_ne(Flavor.go_kitchen(i), "GO_KITCHEN_%d" % (i + 1), "%s go %d" % [locale, i])
		for i in Flavor.FETCH_COUNT:
			assert_ne(Flavor.fetch(i), "FETCH_%d" % (i + 1), "%s fetch %d" % [locale, i])
		for i in Flavor.SICK_NOTE_COUNT:
			assert_ne(Flavor.sick_note(i), "SICK_NOTE_%d" % (i + 1), "%s note %d" % [locale, i])
		for i in Flavor.SICK_CALL_COUNT:
			assert_ne(Flavor.sick_excuse(i), "SICK_EXCUSE_%d" % (i + 1), "%s excuse %d" % [locale, i])
			assert_ne(Flavor.sick_reply(i), "SICK_REPLY_%d" % (i + 1), "%s reply %d" % [locale, i])
		for i in Flavor.SICK_ANSWER_COUNT:
			assert_ne(Flavor.sick_answer(i), "SICK_ANSWER_%d" % (i + 1), "%s answer %d" % [locale, i])
		for i in Flavor.GO_LOO_COUNT:
			assert_ne(Flavor.go_loo(i), "GO_LOO_%d" % (i + 1), "%s loo %d" % [locale, i])
		for i in Flavor.LOO_VOICE_COUNT:
			assert_ne(Flavor.loo_voice(i), "LOO_VOICE_%d" % (i + 1), "%s voice %d" % [locale, i])
		for key in ["SIGN_SICK_PHONE", "AREA_PHONE_OFFICE", "SIGN_SICK_BOARD", "FMT_RINGING", "FMT_BOARD_SICK", "FMT_BOARD_REPORTED", "FMT_BOARD_UNEXCUSED", "FMT_BOARD_CALLS", "FLOAT_SICK_BACK", "FLOAT_SICK_NOTED", "FLOAT_SICK_PERSUADED", "FLOAT_SICK_MISSED", "STAFF_HR", "STAFF_DESC_HR", "FMT_HR_INFO", "SIGN_LOO", "AREA_TOILETS"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for i in Flavor.SLOW_COUNT:
			assert_ne(Flavor.slow(i), "SLOW_%d" % (i + 1), "%s slow %d" % [locale, i])
		for i in Flavor.KRANZ_COUNT:
			assert_ne(Flavor.kranz(i), "KRANZ_%d" % (i + 1), "%s kranz %d" % [locale, i])
		for key in ["SIGN_KRANZ", "TRACK_COFFEE_MACHINE", "TRACK_KITCHEN", "TRACK_DESC_COFFEE_MACHINE", "TRACK_DESC_KITCHEN"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for i in Flavor.COMPLAINT_COUNT:
			assert_ne(Flavor.complaint(i), "COMPLAINT_%d" % (i + 1), "%s complaint %d" % [locale, i])
			assert_false(Flavor.complaint_subject(i).begins_with("COMPLAINT_SUBJECT_"), "%s subject %d" % [locale, i])
		for i in Flavor.SHRED_COUNT:
			assert_ne(Flavor.shred(i), "SHRED_%d" % (i + 1), "%s shred %d" % [locale, i])
		for key in ["SIGN_COMPLAINTS", "SIGN_SHREDDER", "FLOAT_COMPLAINT_OVERFLOW", "TRACK_SHREDDER_SERVICE", "TRACK_DESC_SHREDDER_SERVICE"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for key in ["AREA_KITCHEN", "SIGN_COFFEE_FUND", "SIGN_KITCHEN_RULES"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for key in ["FMT_ROUTE", "FMT_TASK_ROW_RESTING", "FMT_RESTING", "TUTORIAL_WAKE_TITLE", "TUTORIAL_WAKE_TEXT"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for day in Flavor.WISDOM_COUNT:
			var wisdom := Flavor.wisdom(day * float(Flavor.SECONDS_PER_DAY))
			assert_false(wisdom.begins_with("WISDOM_"), "%s wisdom %d" % [locale, day])
		for key in ["AREA_PUBLIC", "SIGN_BUILDING", "SIGN_HOURS_TITLE", "SIGN_HOURS_TEXT", "SIGN_LUNCH", "SIGN_TICKET", "SIGN_CLOSED", "FLOAT_STAMPED", "WISDOM_TITLE"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
	TranslationServer.set_locale("de")


func test_flavor_selection_wraps_and_changes_daily() -> void:
	TranslationServer.set_locale("de")
	assert_eq(Flavor.quip(0), Flavor.quip(Flavor.QUIP_COUNT))
	assert_eq(Flavor.quip(-1), Flavor.quip(Flavor.QUIP_COUNT - 1))
	assert_eq(Flavor.done(Flavor.DONE_COUNT), Flavor.done(0))
	assert_eq(Flavor.flawed(Flavor.FLAWED_COUNT), Flavor.flawed(0))
	assert_eq(Flavor.nap(Flavor.NAP_COUNT), Flavor.nap(0))
	assert_eq(Flavor.coffee_break(-1), Flavor.coffee_break(Flavor.COFFEE_BREAK_COUNT - 1))
	assert_eq(Flavor.woke(Flavor.WOKE_COUNT), Flavor.woke(0))
	assert_eq(Flavor.chat(Flavor.CHAT_COUNT), Flavor.chat(0))
	assert_eq(Flavor.complaint(Flavor.COMPLAINT_COUNT), Flavor.complaint(0))
	assert_eq(Flavor.complaint_subject(Flavor.COMPLAINT_COUNT), Flavor.complaint_subject(0))
	assert_eq(Flavor.slow(Flavor.SLOW_COUNT), Flavor.slow(0))
	assert_eq(Flavor.sick_note(Flavor.SICK_NOTE_COUNT), Flavor.sick_note(0))
	assert_eq(Flavor.sick_excuse(-1), Flavor.sick_excuse(Flavor.SICK_CALL_COUNT - 1))
	assert_eq(Flavor.sick_reply(Flavor.SICK_CALL_COUNT), Flavor.sick_reply(0))
	assert_eq(Flavor.go_loo(Flavor.GO_LOO_COUNT), Flavor.go_loo(0))
	assert_eq(Flavor.loo_voice(-1), Flavor.loo_voice(Flavor.LOO_VOICE_COUNT - 1))
	assert_eq(Flavor.kranz(-1), Flavor.kranz(Flavor.KRANZ_COUNT - 1))
	assert_eq(Flavor.shred(-1), Flavor.shred(Flavor.SHRED_COUNT - 1))
	assert_eq(Flavor.go_kitchen(-1), Flavor.go_kitchen(Flavor.GO_KITCHEN_COUNT - 1))
	assert_eq(Flavor.fetch(Flavor.FETCH_COUNT), Flavor.fetch(0))
	assert_ne(Flavor.wisdom(0.0), Flavor.wisdom(float(Flavor.SECONDS_PER_DAY)))
	assert_eq(Flavor.wisdom(0.0), Flavor.wisdom(float(Flavor.SECONDS_PER_DAY * Flavor.WISDOM_COUNT)))


func test_speech_and_floater_flavor_fits_on_one_line() -> void:
	var speech: Array[String] = []
	var floaters: Array[String] = []
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for i in Flavor.QUIP_COUNT:
			speech.append(Flavor.quip(i))
		for i in Flavor.SICK_CALL_COUNT:
			speech.append(Flavor.sick_excuse(i))
			speech.append(Flavor.sick_reply(i))
		for i in Flavor.SICK_ANSWER_COUNT:
			speech.append(Flavor.sick_answer(i))
		for i in Flavor.LOO_VOICE_COUNT:
			speech.append(Flavor.loo_voice(i))
		for i in Flavor.INTERN_CRY_COUNT:
			speech.append(Flavor.intern_cry(i))
		for i in Flavor.INTERN_NERVOUS_COUNT:
			speech.append(Flavor.intern_nervous(i))
		for i in GameConfig.VENT_DIALOGS:
			speech.append(Flavor.vent(i))
		for i in Flavor.CHAT_COUNT:
			speech.append(Flavor.chat(i))
		for i in Flavor.SLOW_COUNT:
			speech.append(Flavor.slow(i))
			floaters.append(Flavor.slow(i))
		for kind in GameConfig.DISPUTES:
			for line in Flavor.DISPUTE_LINES:
				speech.append(Flavor.dispute_line(kind, line))
		for angry in [false, true]:
			var dialogs := GameConfig.YELL_DIALOGS if angry else GameConfig.VISITOR_DIALOGS
			for dialog in dialogs:
				for line in GameConfig.VISITOR_LINES:
					speech.append(Flavor.visit_line(angry, dialog, line))
		for dialog in GameConfig.GUARD_DIALOGS:
			for line in GameConfig.GUARD_LINES:
				speech.append(Flavor.guard_line(dialog, line))
		for i in Flavor.NAP_COUNT:
			floaters.append(Flavor.nap(i))
		for i in Flavor.COFFEE_BREAK_COUNT:
			floaters.append(Flavor.coffee_break(i))
		for i in Flavor.WOKE_COUNT:
			floaters.append(Flavor.woke(i))
		for i in Flavor.GO_KITCHEN_COUNT:
			floaters.append(Flavor.go_kitchen(i))
		for i in Flavor.FETCH_COUNT:
			floaters.append(Flavor.fetch(i))
		for i in Flavor.SICK_NOTE_COUNT:
			floaters.append(Flavor.sick_note(i))
		for i in Flavor.GO_LOO_COUNT:
			floaters.append(Flavor.go_loo(i))
		for i in Flavor.KRANZ_COUNT:
			floaters.append(Flavor.kranz(i))
		for i in Flavor.COFFEE_SERVED_COUNT:
			floaters.append(Flavor.coffee_served(i))
	for text in speech:
		assert_false(text.contains("\n"), text)
		assert_lte(_line_width(text, AppTheme.SIZE_BODY_SMALL), MAX_SINGLE_LINE_WIDTH, text)
	for text in floaters:
		assert_false(text.contains("\n"), text)
		assert_lte(_line_width(text, AppTheme.SIZE_TITLE_SMALL), MAX_SINGLE_LINE_WIDTH, text)


func _line_width(text: String, size: int) -> float:
	return AppTheme.FONT_SEMIBOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
