extends GutTest

var game: Game
var raw_key := RegEx.create_from_string("\\b[A-Z][A-Z0-9]*_[A-Z0-9_]*")


func before_each() -> void:
	var state := GameState.create_new(6)
	state.money = 1e12
	state.reputation = 1e6
	game = Game.new(state)
	_reset_static_state()


func after_each() -> void:
	_reset_static_state()


func _reset_static_state() -> void:
	UpgradeEntryCard.amount_index = 0
	UpgradesSheet.mode_index = 0
	UpgradesSheet.expanded.clear()


func _t(key: String) -> String:
	return TranslationServer.translate(key)


func _sheet(sheet: Sheet, argument: String = "") -> Sheet:
	sheet.setup(game, argument)
	add_child_autofree(sheet)
	return sheet


func _texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append((node as Label).text)
	elif node is Button:
		result.append((node as Button).text)
	for child in node.get_children():
		result.append_array(_texts(child))
	return result


func _has_text(node: Node, text: String) -> bool:
	return _texts(node).has(text)


func _button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _entry_button(root: Node, title: String, text: String) -> Button:
	for label in root.find_children("*", "Label", true, false):
		if (label as Label).text != title:
			continue
		var node := label.get_parent()
		while node != null and node != root:
			var found := _button(node, text)
			if found != null:
				return found
			node = node.get_parent()
	return null


func _open_spot_buttons(sheet: Sheet) -> Array[Button]:
	var result: Array[Button] = []
	for node in sheet.content.find_children("*", "Button", true, false):
		if (node as Button).tooltip_text == _t("ACTION_OPEN_SPOT"):
			result.append(node)
	return result


func _assert_translated(text: String, context: String) -> void:
	assert_false(text.is_empty(), context)
	assert_null(raw_key.search(text), "%s: %s" % [context, text])


func _full_state() -> GameState:
	var state := game.state
	state.building_stage = GameConfig.BUILDING_STAGES.size() - 2
	state.ensure_mailroom()
	state.unlock_department("tax_services")
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	state.add_runner()
	return state


func test_spot_titles() -> void:
	assert_eq(UpgradeTexts.spot_title("room:hall"), _t("ROOM_HALL"))
	assert_eq(UpgradeTexts.spot_title("dept:tax_services"), _t("DEPT_TAX_SERVICES"))
	assert_eq(UpgradeTexts.spot_title("station:shared/reception"), StationCard.label_for(GameConfig.RECEPTION))
	assert_eq(UpgradeTexts.spot_title("shredder:housing"), _t("FMT_SPOT_SHREDDER") % _t("DEPT_HOUSING"))
	assert_eq(UpgradeTexts.spot_title("tube:hall"), _t("FMT_SPOT_TUBE_STATION") % _t("ROOM_HALL"))
	assert_eq(UpgradeTexts.spot_title("entrance"), _t("SPOT_ENTRANCE"))


func test_spot_description_keys() -> void:
	assert_eq(UpgradeTexts.spot_description_key("room:kitchen"), "ROOM_DESC_KITCHEN")
	assert_eq(UpgradeTexts.spot_description_key("dept:housing"), "DEPT_DESC_HOUSING")
	assert_eq(UpgradeTexts.spot_description_key("station:shared/reception"), "SPOT_DESC_STATION")
	assert_eq(UpgradeTexts.spot_description_key("shredder:housing"), "SPOT_DESC_DEPT_SHREDDER")
	assert_eq(UpgradeTexts.spot_description_key("shredder"), "SPOT_DESC_SHREDDER")
	assert_eq(UpgradeTexts.spot_description_key("tube:hall"), "SPOT_DESC_TUBE_STATION")
	assert_eq(UpgradeTexts.spot_description_key("tube_hub"), "SPOT_DESC_TUBE_HUB")
	assert_eq(UpgradeTexts.spot_description_key("seating"), "SPOT_DESC_SEATING")
	assert_eq(UpgradeTexts.spot_description("seating"), _t("SPOT_DESC_SEATING"))


func test_static_shredder_spot_is_not_a_department_shredder() -> void:
	var state := game.state
	assert_eq(UpgradeTexts.spot_title("shredder"), _t("SPOT_SHREDDER"))
	assert_eq(UpgradeTexts.spot_icon("shredder"), Icons.SPOTS["shredder"])
	assert_ne(UpgradeTexts.spot_icon("shredder"), UpgradeTexts.spot_icon("shredder:housing"))
	assert_eq(SpotStatus.lines(state, "shredder"), [_t("FMT_STATUS_SHREDDER") % [state.rejects_waiting(), 0]] as Array[String])


func test_every_spot_has_translated_texts() -> void:
	var spots: Array[String] = []
	for spot: String in GameConfig.SPOTS:
		spots.append(spot)
	for room_id in GameConfig.SERVICE_ROOMS:
		if room_id != GameConfig.ROOM_PLAYER:
			spots.append("room:" + room_id)
	for dept_id in GameConfig.department_ids():
		spots.append("dept:" + dept_id)
		spots.append("tube:" + dept_id)
		if not GameConfig.is_customs(dept_id):
			spots.append("shredder:" + dept_id)
	spots.append("station:" + GameConfig.RECEPTION)
	for spot in spots:
		_assert_translated(UpgradeTexts.spot_title(spot), spot)
		_assert_translated(UpgradeTexts.spot_description(spot), spot)
		assert_false(UpgradeTexts.spot_icon(spot).is_empty(), spot)


func test_spot_icons() -> void:
	assert_eq(UpgradeTexts.spot_icon("room:hall"), Icons.room(GameConfig.ROOM_HALL))
	assert_eq(UpgradeTexts.spot_icon("dept:housing"), Icons.room("housing"))
	assert_eq(UpgradeTexts.spot_icon("station:shared/reception"), Icons.station_for(GameConfig.RECEPTION))
	assert_eq(UpgradeTexts.spot_icon("shredder:housing"), Icons.upgrade("shredder"))
	assert_eq(UpgradeTexts.spot_icon("tube:hall"), Icons.upgrade("tube_station"))
	assert_eq(UpgradeTexts.spot_icon("nope"), Icons.UPGRADE)


func test_room_and_topic_titles() -> void:
	assert_eq(UpgradeTexts.room_title("housing"), _t("DEPT_HOUSING"))
	assert_eq(UpgradeTexts.room_title(GameConfig.ROOM_TECH), _t("ROOM_TECH_ROOM"))
	for room_id in UpgradeCatalog.rooms():
		_assert_translated(UpgradeTexts.room_title(room_id), room_id)
	for topic_id in GameConfig.TOPICS:
		_assert_translated(UpgradeTexts.topic_title(topic_id), topic_id)


func test_every_entry_text_is_translated() -> void:
	var state := _full_state()
	for entry in UpgradeCatalog.entries(state):
		_assert_translated(UpgradeTexts.title(entry), entry.id)
		_assert_translated(UpgradeTexts.description(entry), entry.id)
		_assert_translated(UpgradeTexts.place(entry), entry.id)
		_assert_translated(UpgradeTexts.level_text(entry), entry.id)
		_assert_translated(UpgradeTexts.button_text(state, entry, 1), entry.id)
		assert_false(UpgradeTexts.icon(entry).is_empty(), entry.id)
		var effect := UpgradeTexts.effect(state, entry)
		if not effect.is_empty():
			_assert_translated(effect, entry.id)


func test_entry_titles() -> void:
	var state := game.state
	assert_eq(UpgradeTexts.title(UpgradeCatalog.find(state, "track:briefcase")), _t("TRACK_BRIEFCASE"))
	assert_eq(UpgradeTexts.title(UpgradeCatalog.find(state, "track:office_equipment@general_services")), _t("FMT_ENTRY_IN_ROOM") % [_t("TRACK_OFFICE_EQUIPMENT"), _t("DEPT_GENERAL_SERVICES")])
	assert_eq(UpgradeTexts.title(UpgradeCatalog.find(state, "desk:shared/reception")), _t("FMT_ENTRY_DESK") % StationCard.label_for(GameConfig.RECEPTION))
	assert_eq(UpgradeTexts.title(UpgradeCatalog.find(state, "unlock:tax_services")), _t("FMT_ENTRY_UNLOCK") % _t("DEPT_TAX_SERVICES"))
	state.unlock_department("tax_services")
	assert_eq(UpgradeTexts.title(UpgradeCatalog.find(state, "desk:tax_services/signature")), _t("FMT_ENTRY_MACHINE") % StationCard.label_for("tax_services/signature"))
	var unknown := UpgradeEntry.new()
	unknown.id = "bogus:1"
	unknown.kind = "bogus"
	assert_eq(UpgradeTexts.title(unknown), "bogus:1")
	assert_eq(UpgradeTexts.icon(unknown), Icons.UPGRADE)


func test_entry_descriptions() -> void:
	var state := game.state
	assert_eq(UpgradeTexts.description(UpgradeCatalog.find(state, "track:briefcase")), _t("TRACK_DESC_BRIEFCASE"))
	assert_eq(UpgradeTexts.description(UpgradeCatalog.find(state, "staff:runners")), _t("STAFF_DESC_RUNNERS"))
	assert_eq(UpgradeTexts.description(UpgradeCatalog.find(state, "specialist:general_services/review")), _t("STAFF_DESC_SPECIALISTS"))
	assert_eq(UpgradeTexts.description(UpgradeCatalog.find(state, "supervisor:general_services")), _t("STAFF_DESC_SUPERVISORS"))
	assert_eq(UpgradeTexts.description(UpgradeCatalog.find(state, "level:shared/reception")), _t("ENTRY_DESC_LEVEL"))
	assert_eq(UpgradeTexts.description(UpgradeCatalog.find(state, "unlock:tax_services")), _t("ENTRY_DESC_UNLOCK"))


func test_level_texts() -> void:
	var state := game.state
	state.set_upgrade("briefcase", 3)
	var track := UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(UpgradeTexts.level_text(track), _t("FMT_LEVEL_OF") % [3, track.max_level])
	assert_eq(UpgradeTexts.level_text(UpgradeCatalog.find(state, "unlock:tax_services")), _t("LABEL_ONCE"))


func test_format_values() -> void:
	assert_eq(UpgradeTexts.format_value("count", 3.7), "3")
	assert_eq(UpgradeTexts.format_value("bonus", 1.25), "+%s %%" % UiKit.decimal((1.25 - 1.0) * 100.0))
	assert_eq(UpgradeTexts.format_value("reduction", 0.8), "−%s %%" % UiKit.decimal((1.0 - 0.8) * 100.0))
	assert_eq(UpgradeTexts.format_value("seconds", -1.0), _t("LABEL_OFF"))
	assert_eq(UpgradeTexts.format_value("seconds", 12.5), _t("FMT_EFFECT_SECONDS") % UiKit.decimal(12.5))
	assert_eq(UpgradeTexts.format_value("chance", 0.15), "%s %%" % UiKit.decimal(0.15 * 100.0))
	assert_eq(UpgradeTexts.format_value("percent", 1.05), "%s %%" % UiKit.decimal(1.05 * 100.0))
	assert_eq(UpgradeTexts.format_value("unlock", 1.0), _t("LABEL_YES"))
	assert_eq(UpgradeTexts.format_value("unlock", 0.0), _t("LABEL_NO"))
	assert_eq(UpgradeTexts.format_value("other", 2.5), UiKit.decimal(2.5))


func test_track_effect_shows_the_next_value() -> void:
	var state := game.state
	var entry := UpgradeCatalog.find(state, "track:briefcase")
	var now := UpgradeTexts.format_value("count", Formulas.track_value("briefcase", 0))
	var next := UpgradeTexts.format_value("count", Formulas.track_value("briefcase", 1))
	assert_eq(UpgradeTexts.effect(state, entry), _t("FMT_EFFECT") % [now, next])
	state.set_upgrade("briefcase", entry.max_level)
	entry = UpgradeCatalog.find(state, "track:briefcase")
	var top := UpgradeTexts.format_value("count", Formulas.track_value("briefcase", entry.max_level))
	assert_eq(UpgradeTexts.effect(state, entry), _t("FMT_EFFECT_MAX") % top)


func test_unlock_track_effect() -> void:
	var entry := UpgradeCatalog.find(game.state, "track:mediation")
	assert_eq(UpgradeTexts.effect(game.state, entry), _t("FMT_EFFECT") % [_t("LABEL_OFF"), UpgradeTexts.format_value("seconds", Formulas.track_value("mediation", 1))])


func test_station_and_unlock_effects() -> void:
	var state := game.state
	var level := UpgradeCatalog.find(state, "level:shared/reception")
	var speed_now := "×%s" % UiKit.decimal(Formulas.level_speed(level.level), 2)
	var speed_next := "×%s" % UiKit.decimal(Formulas.level_speed(level.level + 1), 2)
	assert_eq(UpgradeTexts.effect(state, level), _t("FMT_EFFECT_SPEED") % [speed_now, speed_next])
	state.station(GameConfig.RECEPTION).level = GameConfig.MAX_STATION_LEVEL
	level = UpgradeCatalog.find(state, "level:shared/reception")
	assert_eq(UpgradeTexts.effect(state, level), _t("FMT_EFFECT_SPEED_MAX") % ("×%s" % UiKit.decimal(Formulas.level_speed(level.level), 2)))
	var unlock := UpgradeCatalog.find(state, "unlock:tax_services")
	assert_eq(UpgradeTexts.effect(state, unlock), UpgradeTexts.gain_text("FMT_EFFECT_UNLOCK_GAIN", Formulas.potential_income(state, state.department("tax_services")), unlock.cost))
	assert_false(UpgradeTexts.effect(state, unlock).is_empty())
	assert_eq(UpgradeTexts.effect(state, UpgradeCatalog.find(state, "staff:coffee_interns")), _t("FMT_EFFECT_COUNT") % ["0", "1"])


func test_runner_effect_needs_an_existing_runner() -> void:
	var state := game.state
	var runner := state.add_runner()
	var entry := UpgradeCatalog.find(state, "runner_level:0")
	var carried := Formulas.runner_load(state, runner)
	assert_eq(UpgradeTexts.effect(state, entry), _t("FMT_EFFECT_CAPACITY") % [str(carried), str(carried + GameConfig.RUNNER_LEVEL_CAPACITY)])
	state.runners.clear()
	assert_eq(UpgradeTexts.effect(state, entry), "")


func test_block_texts() -> void:
	var state := game.state
	assert_eq(UpgradeTexts.block_text(state, UpgradeCatalog.find(state, "track:tube_capacity")), _t("FMT_REQ_UPGRADE") % _t("TRACK_PNEUMATIC_TUBES"))
	assert_eq(UpgradeTexts.block_text(state, UpgradeCatalog.find(state, "track:intern_steadfast")), _t("FMT_REQ_UPGRADE") % _t("TRACK_COMPLAINT_INTERNS"))
	assert_eq(UpgradeTexts.block_text(state, UpgradeCatalog.find(state, "track:intern_box_runs")), _t("FMT_REQ_UPGRADE") % (_t("FMT_REQ_TRACK_LEVEL") % [_t("TRACK_COMPLAINT_INTERNS"), 2]))
	state.unlock_department("tax_services")
	var hire := UpgradeCatalog.find(state, "hire:tax_services/review")
	assert_eq(hire.reason, "onboarding")
	assert_eq(UpgradeTexts.block_text(state, hire), StationCard.onboarding_text(state.department("tax_services")))
	state.reputation = 0.0
	state.reputation_peak = 0.0
	var gated := UpgradeCatalog.find(state, "track:digital_records")
	assert_eq(gated.reason, "reputation")
	assert_eq(UpgradeTexts.block_text(state, gated), _t("FMT_REQ_REPUTATION") % int(GameConfig.upgrade("digital_records").reputation))
	var unknown := UpgradeEntry.new()
	unknown.reason = "whatever"
	assert_eq(UpgradeTexts.block_text(state, unknown), _t("LABEL_UNAVAILABLE"))
	unknown.reason = "max"
	assert_eq(UpgradeTexts.block_text(state, unknown), _t("LABEL_MAX_LEVEL"))
	state.money = 1e9
	for i in state.max_desks():
		UpgradeCatalog.buy(game.actions, "desk:shared/reception")
	var desk := UpgradeCatalog.find(state, "desk:shared/reception")
	assert_eq(desk.reason, "stage")
	assert_eq(UpgradeTexts.block_text(state, desk), _t("LABEL_NEEDS_STAGE"))


func test_required_reputation() -> void:
	var state := game.state
	assert_eq(UpgradeTexts.required_reputation(UpgradeCatalog.find(state, "track:digital_records")), float(GameConfig.upgrade("digital_records").reputation))
	assert_eq(UpgradeTexts.required_reputation(UpgradeCatalog.find(state, "unlock:tax_services")), float(GameConfig.department("tax_services").unlock_reputation))
	assert_eq(UpgradeTexts.required_reputation(UpgradeCatalog.find(state, "staff:runners")), 0.0)


func test_button_texts() -> void:
	var state := game.state
	var entry := UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(UpgradeTexts.button_text(state, entry, 1), _t("FMT_ACTION_COST") % [_t("ACTION_BUY"), UiKit.money(entry.bulk_cost(1))])
	assert_eq(UpgradeTexts.button_text(state, entry, 10), _t("FMT_ACTION_COST") % [_t("FMT_ACTION_BUY_MANY") % 10, UiKit.money(entry.bulk_cost(10))])
	assert_eq(UpgradeTexts.button_text(state, entry, 0), UpgradeTexts.button_text(state, entry, 1))
	state.money = 0.0
	entry = UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(entry.reason, "money")
	assert_eq(UpgradeTexts.button_text(state, entry, 1), _t("FMT_ACTION_COST") % [_t("ACTION_BUY"), UiKit.money(entry.bulk_cost(1))])
	var blocked := UpgradeCatalog.find(state, "track:tube_capacity")
	assert_eq(UpgradeTexts.button_text(state, blocked, 1), UpgradeTexts.block_text(state, blocked))


func test_place_names_room_and_spot() -> void:
	var entry := UpgradeCatalog.find(game.state, "track:seating")
	assert_eq(UpgradeTexts.place(entry), _t("FMT_ENTRY_PLACE") % [_t("ROOM_HALL"), _t("SPOT_SEATING")])


func test_amount_selection() -> void:
	assert_eq(UpgradeEntryCard.amount(), 1)
	UpgradeEntryCard.amount_index = 1
	assert_eq(UpgradeEntryCard.amount(), 10)
	UpgradeEntryCard.amount_index = 2
	assert_eq(UpgradeEntryCard.amount(), 0)
	UpgradeEntryCard.amount_index = 9
	assert_eq(UpgradeEntryCard.amount(), 0)
	UpgradeEntryCard.amount_index = -4
	assert_eq(UpgradeEntryCard.amount(), 1)


func test_purchase_count() -> void:
	var state := game.state
	var track := UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(UpgradeEntryCard.purchase_count(state, track, 1), 1)
	assert_eq(UpgradeEntryCard.purchase_count(state, track, 10), 10)
	assert_eq(UpgradeEntryCard.purchase_count(state, track, 0), track.affordable(state.money))
	state.set_upgrade("briefcase", track.max_level - 3)
	track = UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(UpgradeEntryCard.purchase_count(state, track, 10), 3)
	assert_eq(UpgradeEntryCard.purchase_count(state, UpgradeCatalog.find(state, "unlock:tax_services"), 10), 1)
	state.money = 0.0
	assert_eq(UpgradeEntryCard.purchase_count(state, UpgradeCatalog.find(state, "track:briefcase"), 0), 1)


func test_can_buy() -> void:
	var state := game.state
	var track := UpgradeCatalog.find(state, "track:briefcase")
	assert_true(UpgradeEntryCard.can_buy(state, track, 1))
	assert_false(UpgradeEntryCard.can_buy(state, track, 0))
	assert_false(UpgradeEntryCard.can_buy(state, track, track.remaining() + 1))
	assert_false(UpgradeEntryCard.can_buy(state, UpgradeCatalog.find(state, "track:tube_capacity"), 1))
	state.money = track.cost - 1.0
	assert_false(UpgradeEntryCard.can_buy(state, UpgradeCatalog.find(state, "track:briefcase"), 1))


func test_buy_uses_the_selected_amount() -> void:
	var state := game.state
	assert_true(UpgradeEntryCard.buy(game, "track:briefcase"))
	assert_eq(state.upgrade_level("briefcase"), 1)
	UpgradeEntryCard.amount_index = 1
	assert_true(UpgradeEntryCard.buy(game, "track:briefcase"))
	assert_eq(state.upgrade_level("briefcase"), 11)
	UpgradeEntryCard.amount_index = 2
	state.money = Formulas.track_bulk_cost("sneakers", 0, 3) + 0.5
	assert_true(UpgradeEntryCard.buy(game, "track:sneakers"))
	assert_eq(state.upgrade_level("sneakers"), 3)
	assert_false(UpgradeEntryCard.buy(game, "track:nope"))
	assert_false(UpgradeEntryCard.buy(game, "track:tube_capacity"))


func test_entry_card_hides_missing_entries() -> void:
	var sheet := _sheet(SpotSheet.new(), "player")
	var card := UpgradeEntryCard.build(sheet, "unlock:nope")
	assert_false(card.visible)
	card.free()


func test_entry_card_buy_button_buys_and_refreshes() -> void:
	var sheet := _sheet(SpotSheet.new(), "player")
	var entry := UpgradeCatalog.find(game.state, "track:briefcase")
	var button := _entry_button(sheet.content, UpgradeTexts.title(entry), UpgradeTexts.button_text(game.state, entry, 1))
	assert_not_null(button)
	button.pressed.emit()
	assert_eq(game.state.upgrade_level("briefcase"), 1)
	assert_true(_has_text(sheet.content, UpgradeTexts.level_text(UpgradeCatalog.find(game.state, "track:briefcase"))))


func test_spot_sheet_basics() -> void:
	var sheet: SpotSheet = _sheet(SpotSheet.new(), "entrance")
	assert_eq(sheet.title(), _t("SPOT_ENTRANCE"))
	assert_eq(sheet.room_id(), GameConfig.ROOM_HALL)
	assert_eq(sheet.refresh_interval(), SpotSheet.REFRESH_MSEC)
	assert_true(_has_text(sheet.content, _t("SPOT_DESC_ENTRANCE")))
	assert_true(_has_text(sheet.content, _t("ROOM_HALL")))
	assert_true(_has_text(sheet.content, "\n".join(SpotStatus.lines(game.state, "entrance"))))
	assert_null(UpgradeCatalog.find(game.state, "stage:building"))
	assert_false(_has_text(sheet.content, _t("SPOT_EMPTY")))


func test_spot_sheet_shows_locked_rooms() -> void:
	var sheet := _sheet(SpotSheet.new(), "mail_shelf")
	assert_true(_has_text(sheet.content, _t("ROOM_LOCKED_TITLE")))
	assert_true(_has_text(sheet.content, SpotSheet.locked_text(game.state, GameConfig.ROOM_MAIL)))
	assert_false(_has_text(sheet.content, _t("AMOUNT_ONE")))
	assert_eq(SpotSheet.locked_text(game.state, GameConfig.ROOM_MAIL), _t("FMT_MAIL_LOCKED") % 2)
	assert_eq(SpotSheet.locked_text(game.state, GameConfig.ROOM_INSPECTION), _t("ROOM_LOCKED_INSPECTION"))
	assert_eq(SpotSheet.locked_text(game.state, GameConfig.ROOM_KITCHEN), _t("LABEL_ROOM_LOCKED"))
	assert_true(SpotSheet.is_room_open(game.state, "tax_services"))
	assert_true(SpotSheet.is_room_open(game.state, GameConfig.ROOM_KITCHEN))
	assert_false(SpotSheet.is_room_open(game.state, GameConfig.ROOM_MAIL))
	assert_false(SpotSheet.is_room_open(game.state, GameConfig.ROOM_INSPECTION))


func test_locked_department_offers_its_unlock() -> void:
	var sheet := _sheet(SpotSheet.new(), "dept:tax_services")
	assert_true(_has_text(sheet.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "unlock:tax_services"))))
	assert_false(_has_text(sheet.content, _t("SECTION_WORK_MODE")))


func test_open_department_shows_its_section() -> void:
	var sheet := _sheet(SpotSheet.new(), "dept:general_services")
	assert_true(_has_text(sheet.content, _t("LEGEND_MARKERS")))
	assert_true(_has_text(sheet.content, _t("SECTION_WORK_MODE")))
	assert_true(_has_text(sheet.content, DepartmentSection.route_text("general_services")))
	assert_true(_has_text(sheet.content, UpgradeTexts.spot_title("station:general_services/review")))


func test_spot_sheet_groups_entries_by_spot() -> void:
	var kitchen := _sheet(SpotSheet.new(), "room:kitchen")
	var spots := UpgradeCatalog.spots_of(SpotSheet.visible_entries(game.state, "room:kitchen"))
	assert_eq(spots, ["coffee_machine", "kitchen", "canteen"] as Array[String])
	for spot in spots:
		assert_true(_has_text(kitchen.content, UpgradeTexts.spot_title(spot)), spot)
	assert_eq(_open_spot_buttons(kitchen).size(), spots.size())
	var toilets := _sheet(SpotSheet.new(), "toilets")
	assert_true(_open_spot_buttons(toilets).is_empty())
	assert_true(_has_text(toilets.content, _t("TRACK_TOILET_STALLS")))


func test_group_header_opens_the_spot() -> void:
	var sheet := _sheet(SpotSheet.new(), "room:kitchen")
	watch_signals(sheet)
	var buttons := _open_spot_buttons(sheet)
	assert_false(buttons.is_empty())
	buttons[0].pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "navigate", ["spot", "coffee_machine"])


func test_complaint_desk_links_to_the_complaints() -> void:
	var sheet := _sheet(SpotSheet.new(), "complaint_desk")
	watch_signals(sheet)
	var read := _button(sheet.content, _t("ACTION_READ_COMPLAINTS"))
	assert_not_null(read)
	read.pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "navigate", ["complaints", ""])


func test_station_spot_shows_the_station_card() -> void:
	var sheet := _sheet(SpotSheet.new(), "station:" + GameConfig.RECEPTION)
	assert_true(_has_text(sheet.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "level:shared/reception"))))
	assert_true(_has_text(sheet.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "hire:shared/reception"))))


func test_spot_without_content_says_so() -> void:
	var sheet := _sheet(SpotSheet.new(), "nope")
	assert_true(_has_text(sheet.content, _t("SPOT_EMPTY")))


func test_every_spot_sheet_builds_translated() -> void:
	_full_state()
	var spots: Array[String] = []
	for spot: String in GameConfig.SPOTS:
		spots.append(spot)
	for room_id in GameConfig.SERVICE_ROOMS:
		if room_id != GameConfig.ROOM_PLAYER:
			spots.append("room:" + room_id)
	for dept_id in ["general_services", "tax_services", "housing", "customs"]:
		spots.append("dept:" + dept_id)
	spots.append_array(["shredder:general_services", "tube:hall", "tube:general_services", "station:" + GameConfig.MAILROOM])
	for spot in spots:
		var sheet := _sheet(SpotSheet.new(), spot)
		assert_gt(sheet.content.get_child_count(), 1, spot)
		for text in _texts(sheet.content):
			if not text.is_empty():
				assert_null(raw_key.search(text), "%s: %s" % [spot, text])
		sheet.free()


func test_visible_entries_hide_runner_levels_on_the_board() -> void:
	var state := game.state
	state.add_runner()
	var all := UpgradeCatalog.entries_for_spot(state, "runners")
	var visible := SpotSheet.visible_entries(state, "runners")
	assert_true(all.any(func(entry: UpgradeEntry) -> bool: return entry.kind == UpgradeCatalog.RUNNER_LEVEL))
	assert_false(visible.any(func(entry: UpgradeEntry) -> bool: return entry.kind == UpgradeCatalog.RUNNER_LEVEL))
	assert_eq(visible.size(), all.size() - state.runners.size())
	assert_eq(SpotSheet.visible_entries(state, "toilets").size(), UpgradeCatalog.entries_for_spot(state, "toilets").size())


func test_room_boosts() -> void:
	assert_eq(SpotSheet.room_boosts(game, GameConfig.ROOM_PLAYER), GameConfig.room_boosts(GameConfig.ROOM_PLAYER))
	assert_true(SpotSheet.room_boosts(game, "entrance").is_empty())
	assert_false(SpotSheet.room_boosts(game, "room:mail").has("express_post"))
	for boost_id in GameConfig.room_boosts(GameConfig.ROOM_HALL):
		if not bool(GameConfig.boost(boost_id).get("requires_mail", false)):
			assert_true(SpotSheet.room_boosts(game, "room:hall").has(boost_id), boost_id)


func test_room_sheet_lists_its_boosts() -> void:
	var sheet := _sheet(SpotSheet.new(), GameConfig.ROOM_PLAYER)
	assert_true(_has_text(sheet.content, _t("SECTION_ROOM_BOOSTS")))


func test_board_sections_show_their_staff() -> void:
	var state := game.state
	var empty := _sheet(SpotSheet.new(), "runners")
	assert_true(_has_text(empty.content, _t("SECTION_SHIFT_PLAN")))
	assert_true(_has_text(empty.content, _t("RUNNERS_EMPTY")))
	state.add_runner()
	state.add_collector()
	state.add_coffee_intern()
	state.hr = 1
	var expected := {
		"runners": _t("FMT_RUNNER_NAME") % 1,
		"collectors": _t("FMT_COLLECTOR_NAME") % 1,
		"coffee_interns": _t("FMT_COFFEE_INTERN_NAME") % 1,
		"phone_clerks": _t("FMT_PHONE_LINE") % 1,
	}
	for spot: String in expected:
		var sheet := _sheet(SpotSheet.new(), spot)
		assert_true(_has_text(sheet.content, expected[spot]), spot)
		sheet.free()


func test_board_sections_show_empty_hints() -> void:
	var expected := {
		"collectors": "COLLECTORS_EMPTY",
		"coffee_interns": "COFFEE_INTERNS_EMPTY",
		"phone_clerks": "PHONE_CLERKS_EMPTY",
	}
	for spot: String in expected:
		var sheet := _sheet(SpotSheet.new(), spot)
		assert_true(_has_text(sheet.content, _t(expected[spot])), spot)
		sheet.free()


func test_collector_focus_button_cycles_the_department() -> void:
	var state := game.state
	state.add_collector()
	var before := state.collectors[0].dept_id
	var sheet := _sheet(SpotSheet.new(), "collectors")
	var focus := _button(sheet.content, _t("FMT_FOCUS") % BoardSection.department_text(before))
	assert_not_null(focus)
	focus.pressed.emit()
	assert_ne(state.collectors[0].dept_id, before)


func test_board_helpers() -> void:
	var state := game.state
	assert_eq(BoardSection.department_text(Runner.ALL_DEPARTMENTS), _t("RUNNER_ALL_DEPARTMENTS"))
	assert_eq(BoardSection.department_text("tax_services"), _t("DEPT_TAX_SERVICES"))
	var runner := state.add_runner()
	assert_eq(BoardSection.level_text(state, runner), _t("FMT_RUNNER_LEVEL") % [runner.level, GameConfig.MAX_RUNNER_LEVEL, Formulas.runner_load(state, runner)])


func test_upgrades_sheet_modes() -> void:
	assert_eq(UpgradesSheet.mode(), "rooms")
	UpgradesSheet.mode_index = 1
	assert_eq(UpgradesSheet.mode(), "topics")
	UpgradesSheet.mode_index = 3
	assert_eq(UpgradesSheet.mode(), "recommended")
	UpgradesSheet.mode_index = 99
	assert_eq(UpgradesSheet.mode(), "expansion")
	UpgradesSheet.mode_index = -1
	assert_eq(UpgradesSheet.mode(), "rooms")
	assert_eq(UpgradesSheet.group_order("topics"), GameConfig.TOPICS)
	assert_eq(UpgradesSheet.group_order("rooms"), UpgradeCatalog.rooms())
	var entry := UpgradeCatalog.find(game.state, "track:seating")
	assert_eq(UpgradesSheet.group_key(entry, "topics"), "citizens")
	assert_eq(UpgradesSheet.group_key(entry, "rooms"), GameConfig.ROOM_HALL)


func test_buyable_is_sorted_by_cost() -> void:
	var list := UpgradesSheet.buyable(UpgradeCatalog.entries(game.state))
	assert_false(list.is_empty())
	for index in list.size():
		assert_true(list[index].is_buyable(), list[index].id)
		if index > 0:
			assert_true(list[index - 1].cost <= list[index].cost, list[index].id)


func test_group_detail_and_grouping() -> void:
	var a := UpgradeEntry.new()
	a.level = 2
	a.max_level = 10
	var b := UpgradeEntry.new()
	b.level = 1
	b.max_level = 5
	b.reason = "money"
	assert_eq(UpgradesSheet.group_detail([a, b] as Array[UpgradeEntry]), _t("FMT_GROUP_DETAIL") % [1, 3, 15])
	var entries := UpgradeCatalog.entries(game.state)
	var groups := UpgradesSheet.grouped(entries, "rooms")
	var total := 0
	for key: String in groups:
		assert_true(UpgradeCatalog.rooms().has(key), key)
		for entry: UpgradeEntry in groups[key]:
			assert_eq(entry.room, key, entry.id)
		total += groups[key].size()
	assert_eq(total, entries.size())


func test_rooms_mode_starts_collapsed_and_expands() -> void:
	var sheet: UpgradesSheet = _sheet(UpgradesSheet.new())
	assert_eq(sheet.title(), _t("SHEET_UPGRADES"))
	assert_eq(sheet.refresh_interval(), UpgradesSheet.REFRESH_MSEC)
	var waiting := UpgradeTexts.title(UpgradeCatalog.find(game.state, "track:seating"))
	assert_true(_has_text(sheet.content, UpgradeTexts.room_title(GameConfig.ROOM_HALL)))
	assert_false(_has_text(sheet.content, waiting))
	UpgradesSheet.expanded["rooms:hall"] = true
	sheet.rebuild()
	assert_true(_has_text(sheet.content, waiting))
	assert_true(_has_text(sheet.content, UpgradeTexts.spot_title("seating")))


func test_group_header_button_toggles() -> void:
	var sheet: UpgradesSheet = _sheet(UpgradesSheet.new())
	var buttons := sheet.content.find_children("*", "Button", true, false)
	var header: Button = null
	for node in buttons:
		if _has_text(node, UpgradeTexts.room_title(GameConfig.ROOM_PLAYER)):
			header = node
			break
	assert_not_null(header)
	header.pressed.emit()
	assert_true(UpgradesSheet.expanded.get("rooms:player", false))
	assert_true(_has_text(sheet.content, _t("TRACK_BRIEFCASE")))


func test_topics_mode_lists_entries_with_their_place() -> void:
	UpgradesSheet.mode_index = 1
	UpgradesSheet.expanded["topics:citizens"] = true
	var sheet := _sheet(UpgradesSheet.new())
	var entry := UpgradeCatalog.find(game.state, "track:seating")
	assert_true(_has_text(sheet.content, UpgradeTexts.topic_title("citizens")))
	assert_true(_has_text(sheet.content, UpgradeTexts.title(entry)))
	assert_true(_has_text(sheet.content, UpgradeTexts.place(entry)))


func test_buyable_mode_limits_the_list() -> void:
	UpgradesSheet.mode_index = 2
	var state := _full_state()
	var list := UpgradesSheet.buyable(UpgradeCatalog.entries(state))
	assert_gt(list.size(), UpgradesSheet.LIST_LIMIT)
	var sheet := _sheet(UpgradesSheet.new())
	assert_true(_has_text(sheet.content, _t("FMT_MORE_ENTRIES") % (list.size() - UpgradesSheet.LIST_LIMIT)))
	assert_true(_has_text(sheet.content, UpgradeTexts.title(list[0])))
	assert_true(_has_text(sheet.content, UpgradeTexts.place(list[0])))
	assert_false(_has_text(sheet.content, _t("UPGRADES_NONE_BUYABLE")))
	state.money = 0.0
	sheet.rebuild()
	assert_true(_has_text(sheet.content, _t("UPGRADES_NONE_BUYABLE")))


func test_recommended_mode_lists_open_suggestions() -> void:
	UpgradesSheet.mode_index = 3
	var state := game.state
	var open: Array[UpgradeEntry] = []
	for entry_id in ThroughputReport.recommended_entries(state):
		var entry := UpgradeCatalog.find(state, entry_id)
		if entry != null and not entry.is_maxed():
			open.append(entry)
	var sheet := _sheet(UpgradesSheet.new())
	assert_eq(_has_text(sheet.content, _t("UPGRADES_NONE_RECOMMENDED")), open.is_empty())
	for entry in open.slice(0, UpgradesSheet.LIST_LIMIT):
		assert_true(_has_text(sheet.content, UpgradeTexts.title(entry)), entry.id)


func test_upgrades_summary_counts_levels() -> void:
	game.state.set_upgrade("briefcase", 4)
	var sheet := _sheet(UpgradesSheet.new())
	var entries := UpgradeCatalog.entries(game.state)
	var ready := entries.filter(func(entry: UpgradeEntry) -> bool: return entry.is_buyable()).size()
	assert_true(_has_text(sheet.content, _t("FMT_UPGRADES_SUMMARY") % [game.state.upgrade_count(), entries.size(), ready]))


func test_mode_switch_rebuilds_the_list() -> void:
	var sheet := _sheet(UpgradesSheet.new())
	var topics := _button(sheet.content, _t("UPGRADE_MODE_TOPICS"))
	assert_not_null(topics)
	topics.pressed.emit()
	assert_eq(UpgradesSheet.mode(), "topics")
	assert_true(_has_text(sheet.content, _t("UPGRADE_MODE_HINT_TOPICS")))


func test_jam_text() -> void:
	var label := StationCard.label_for(GameConfig.RECEPTION)
	assert_eq(DepartmentSection.jam_text([] as Array[Dictionary]), "")
	var one: Array[Dictionary] = [{"key": GameConfig.RECEPTION, "side": "in"}]
	assert_eq(DepartmentSection.jam_text(one), _t("FMT_JAM") % ("%s (%s)" % [label, _t("JAM_SIDE_IN")]))
	var three: Array[Dictionary] = []
	var names: Array[String] = []
	for side in ["in", "out", "rejects"]:
		three.append({"key": GameConfig.RECEPTION, "side": side})
		names.append("%s (%s)" % [label, _t("JAM_SIDE_" + side.to_upper())])
	assert_eq(DepartmentSection.jam_text(three), _t("FMT_JAM") % ", ".join(names))
	var four: Array[Dictionary] = []
	four.append_array(three)
	four.append({"key": GameConfig.COUNTER, "side": "in"})
	assert_eq(DepartmentSection.jam_text(four), _t("FMT_JAM") % (", ".join(names) + " …"))


func test_department_texts() -> void:
	assert_eq(DepartmentSection.bottleneck_text("demand"), _t("BOTTLENECK_DEMAND"))
	assert_eq(DepartmentSection.bottleneck_text("transport"), _t("BOTTLENECK_TRANSPORT"))
	assert_eq(DepartmentSection.bottleneck_text(GameConfig.RECEPTION), _t("FMT_BOTTLENECK_STATION") % StationCard.label_for(GameConfig.RECEPTION))
	var names: Array[String] = []
	for key in RouteBuilder.build(CaseFile.new("general_services")):
		names.append(StationCard.label_for(key))
	assert_eq(DepartmentSection.route_text("general_services"), _t("FMT_ROUTE") % " → ".join(names))


func test_spot_status_lines() -> void:
	var state := game.state
	var silent: Array[String] = ["archive", "training", "server", "coffee_machine", "kitchen", "room:hall", "dept:general_services", "station:" + GameConfig.RECEPTION]
	for spot: String in GameConfig.SPOTS:
		var lines := SpotStatus.lines(state, spot)
		assert_eq(lines.is_empty(), silent.has(spot), spot)
		for line in lines:
			_assert_translated(line, spot)
	for spot in silent:
		assert_true(SpotStatus.lines(state, spot).is_empty(), spot)


func test_spot_status_population() -> void:
	var state := game.state
	var expected := _t("FMT_POPULATION") % [UiKit.number(Formulas.population(state)), _t("SETTLEMENT_" + Formulas.settlement(state).to_upper())]
	assert_eq(SpotStatus.population(state), expected)
	assert_true(SpotStatus.lines(state, "entrance").has(expected))
	var building := _t("FMT_STATUS_STAGE") % [_t("STAGE_SERVICE_COUNTER"), 1, GameConfig.DEPARTMENTS.size()]
	assert_true(SpotStatus.lines(state, "entrance").has(building))


func test_spot_status_tickets_are_active_from_the_start() -> void:
	var state := game.state
	assert_eq(state.building_stage, 0)
	assert_eq(SpotStatus.tickets(state), _t("FMT_STATUS_TICKETS") % [1, UiKit.decimal(GameConfig.TICKET_BASE_RATE * 60.0, 0), 0, GameConfig.TICKET_LINE_SLOTS])
	state.set_upgrade("ticket_speed", 100)
	state.set_upgrade("ticket_machine_2", 1)
	game.simulation.spawn_case(state.department("general_services"))
	assert_eq(SpotStatus.tickets(state), _t("FMT_STATUS_TICKETS") % [2, UiKit.decimal((1.0 + GameConfig.TICKET_BASE_RATE) * 60.0, 0), 1, GameConfig.TICKET_LINE_SLOTS * 2])
	assert_true(SpotStatus.lines(state, "tickets").has(SpotStatus.tickets(state)))


func test_spot_status_seating_counts_seats_and_standing_places() -> void:
	var lines := SpotStatus.lines(game.state, "seating")
	assert_false(lines.is_empty())
	assert_true(lines[0].contains(str(GameConfig.BASE_SEATS)))
	assert_true(lines[0].contains(str(GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS)))
	assert_eq(lines[1], _t("FMT_STATUS_WALKOUTS") % game.state.walkouts)
	game.state.set_upgrade("pickup_seating", 4)
	var pickup := SpotStatus.lines(game.state, "pickup_seating")
	assert_eq(pickup, [SpotStatus.waiting_room(game.state, GameConfig.HALL_PICKUP)] as Array[String])
	assert_true(pickup[0].contains(str(GameConfig.BASE_SEATS + 4)))
	assert_eq(UpgradeTexts.spot_description("pickup_seating"), _t("SPOT_DESC_PICKUP_SEATING"))


func test_spot_status_tubes() -> void:
	var state := game.state
	assert_eq(SpotStatus.tube_hub(state), _t("STATUS_TUBES_LOCKED"))
	assert_eq(SpotStatus.lines(state, "tube:hall"), [_t("STATUS_TUBES_LOCKED")] as Array[String])
	state.set_upgrade("pneumatic_tubes", 1)
	assert_eq(SpotStatus.tube_station(state, GameConfig.ROOM_HALL), _t("STATUS_TUBE_MISSING"))
	state.set_upgrade("tube_station", 1, GameConfig.ROOM_HALL)
	assert_eq(SpotStatus.tube_station(state, GameConfig.ROOM_HALL), _t("STATUS_TUBE_CONNECTED"))
	assert_eq(SpotStatus.tube_hub(state), _t("FMT_STATUS_TUBE_HUB") % [Formulas.tube_capacity(state), 0, 1, 2])


func test_spot_status_shredders_and_interns() -> void:
	var state := game.state
	assert_eq(SpotStatus.lines(state, "shredder:general_services"), [_t("STATUS_NO_SHREDDER")] as Array[String])
	state.set_upgrade("shredder", 5, "general_services")
	assert_eq(SpotStatus.dept_shredder(state, "general_services"), _t("FMT_STATUS_DEPT_SHREDDER") % UiKit.decimal(Formulas.shredder_interval(state, "general_services")))
	assert_eq(SpotStatus.lines(state, "complaint_desk"), [_t("FMT_STATUS_COMPLAINT_DESK") % [0, 0, Formulas.intern_steadfast(state), 0]] as Array[String])
	state.set_upgrade("complaint_interns", 2)
	state.interns[1].mood = ComplaintIntern.Mood.CRYING
	state.interns[1].handled = 2
	var desk := SpotStatus.lines(state, "complaint_desk")
	assert_eq(desk.size(), 3)
	assert_eq(desk[0], _t("FMT_STATUS_COMPLAINT_DESK") % [1, 2, Formulas.intern_steadfast(state), 0])
	assert_eq(desk[2], _t("FMT_INTERN_STATUS") % [_t("FMT_INTERN_NAME") % 2, _t("INTERN_MOOD_CRYING"), 2, Formulas.intern_steadfast(state)])
	assert_eq(SpotStatus.lines(state, "security"), [_t("STATUS_NO_SECURITY")] as Array[String])
	state.set_upgrade("complaint_security", 1)
	assert_eq(SpotStatus.lines(state, "security"), [_t("FMT_SECURITY_INFO") % [roundi(GameConfig.SECURITY_BASE_CHANCE * 100.0), 0]] as Array[String])
	assert_eq(SpotStatus.lines(state, "shredder"), [_t("FMT_STATUS_SHREDDER") % [state.rejects_waiting(), 1]] as Array[String])


func test_spot_status_mail() -> void:
	var state := game.state
	assert_eq(SpotStatus.mail(state), _t("FMT_MAIL_LOCKED") % 2)
	state.unlock_department("tax_services")
	assert_not_null(state.mailroom())
	_assert_translated(SpotStatus.mail(state), "mail")
	assert_ne(SpotStatus.mail(state), _t("FMT_MAIL_LOCKED") % 2)


func test_goal_texts_for_upgrades() -> void:
	var name := _t("TRACK_PNEUMATIC_TUBES")
	assert_eq(GoalText.describe({"type": "upgrade_level", "target": 1.0, "param": "pneumatic_tubes"}), _t("FMT_GOAL_UPGRADE_UNLOCK") % name)
	assert_eq(GoalText.describe({"type": "upgrade_level", "target": 25.0, "param": "pneumatic_tubes"}), _t("FMT_GOAL_UPGRADE_LEVEL") % [name, 25])
	assert_eq(GoalText.describe({"type": "upgrades", "target": 3.0, "param": ""}), _t("FMT_GOAL_UPGRADES") % 3)
	for goal: Dictionary in GameConfig.GOALS:
		_assert_translated(GoalText.describe(goal), str(goal.type))


func test_lifetime_statistics_text() -> void:
	var state := game.state
	state.cases_completed = 10
	state.cases_flawed = 2
	var expected := _t("FMT_STATISTICS") % [UiKit.number(10), UiKit.percent(0.8), UiKit.number(state.citizens_lost), UiKit.number(state.wakes), UiKit.number(state.total_staff()), UiKit.money(state.money_earned), UiKit.duration(state.play_time)]
	assert_eq(StatisticsSheet.lifetime_text(state), expected)
	state.cases_completed = 0
	assert_true(StatisticsSheet.lifetime_text(state).contains(UiKit.percent(1.0)))


func test_sheets_throttle_refreshes() -> void:
	var sheet := _sheet(SpotSheet.new(), "player")
	var calls: Array[int] = [0]
	sheet.track(func() -> void: calls[0] += 1)
	game.changed.emit()
	assert_eq(calls[0], 0)
	sheet._last_refresh -= SpotSheet.REFRESH_MSEC * 2
	game.changed.emit()
	assert_eq(calls[0], 1)


func test_plain_sheets_refresh_on_every_change() -> void:
	var sheet := _sheet(Sheet.new())
	assert_eq(sheet.refresh_interval(), 0)
	var calls: Array[int] = [0]
	sheet.track(func() -> void: calls[0] += 1)
	game.changed.emit()
	game.changed.emit()
	assert_eq(calls[0], 2)
