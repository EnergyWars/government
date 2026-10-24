extends GutTest

const TEST_SETTINGS := "user://test_settings.cfg"

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
	var keys := ["DEPT_GENERAL_SERVICES", "STATION_REVIEW", "ACTION_HIRE", "FMT_MONEY"]
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
	for research_id in GameConfig.RESEARCH_ORDER:
		keys.append("RESEARCH_" + research_id.to_upper())
		keys.append("RESEARCH_DESC_" + research_id.to_upper())
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
	assert_eq(UiKit.cost_text("ACTION_HIRE", 80.0), "Hire · $80")


func test_goal_texts() -> void:
	TranslationServer.set_locale("de")
	assert_eq(GoalText.describe({"type": "cases", "target": 3.0}), "Erledige 3 Fälle")
	assert_eq(GoalText.describe({"type": "department", "target": 1.0, "param": "tax_services"}), "Eröffne: Finanzamt")
	assert_eq(GoalText.describe({"type": "research_level", "target": 1.0, "param": "pneumatic_tubes"}), "Führe ein: Rohrpost")
	assert_eq(GoalText.describe({"type": "building_stage", "target": 1.0}), "Erweitere zu: Bürgeramt")
	assert_eq(GoalText.describe({"type": "runners", "target": 1.0}), "Stelle 1 Boten ein")
	assert_eq(GoalText.describe({"type": "reputation", "target": 30.0}), "Erreiche 30 Ansehen")
	assert_eq(GoalText.reward({"money": 60.0, "reputation": 1.0}), "Belohnung: 60 € und 1 Ansehen")
	assert_eq(GoalText.reward({"money": 800.0, "reputation": 0.0}), "Belohnung: 800 €")
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
	for research_id in GameConfig.RESEARCH_ORDER:
		assert_true(Icons.RESEARCH.has(research_id), research_id)
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
		for i in Flavor.GO_LOO_COUNT:
			assert_ne(Flavor.go_loo(i), "GO_LOO_%d" % (i + 1), "%s loo %d" % [locale, i])
		for i in Flavor.LOO_VOICE_COUNT:
			assert_ne(Flavor.loo_voice(i), "LOO_VOICE_%d" % (i + 1), "%s voice %d" % [locale, i])
		for key in ["SIGN_SICK_PHONE", "FMT_SICK_COUNT", "FMT_COMPLAINT_MALUS", "SECTION_ABSENCE", "STAFF_HR", "STAFF_DESC_HR", "FMT_HR_INFO", "SIGN_LOO", "AREA_TOILETS"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for i in Flavor.SLOW_COUNT:
			assert_ne(Flavor.slow(i), "SLOW_%d" % (i + 1), "%s slow %d" % [locale, i])
		for i in Flavor.KRANZ_COUNT:
			assert_ne(Flavor.kranz(i), "KRANZ_%d" % (i + 1), "%s kranz %d" % [locale, i])
		for key in ["SIGN_KRANZ", "RESEARCH_COFFEE_MACHINE", "RESEARCH_KITCHEN", "RESEARCH_DESC_COFFEE_MACHINE", "RESEARCH_DESC_KITCHEN"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for i in Flavor.COMPLAINT_COUNT:
			assert_ne(Flavor.complaint(i), "COMPLAINT_%d" % (i + 1), "%s complaint %d" % [locale, i])
		for i in Flavor.SHRED_COUNT:
			assert_ne(Flavor.shred(i), "SHRED_%d" % (i + 1), "%s shred %d" % [locale, i])
		for key in ["SIGN_COMPLAINTS", "SIGN_SHREDDER", "FLOAT_COMPLAINT_OVERFLOW", "RESEARCH_SHREDDER_SERVICE", "RESEARCH_DESC_SHREDDER_SERVICE"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for key in ["AREA_KITCHEN", "SIGN_COFFEE_FUND", "SIGN_KITCHEN_RULES"]:
			assert_ne(TranslationServer.translate(key), key, "%s %s" % [locale, key])
		for key in ["SECTION_SHARED_STATIONS", "FMT_TASK_ROW_RESTING", "FMT_RESTING", "TUTORIAL_WAKE_TITLE", "TUTORIAL_WAKE_TEXT"]:
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
