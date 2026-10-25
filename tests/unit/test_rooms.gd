extends GutTest

var game: Game
var layout: WorldLayout


func before_each() -> void:
	var state := GameState.create_new(4)
	state.money = 1e12
	state.reputation = 2000.0
	game = Game.new(state)
	layout = WorldLayout.get_default()
	UpgradeEntryCard.amount_index = 0


func _sheet(spot: String) -> SpotSheet:
	var sheet := SpotSheet.new()
	sheet.setup(game, spot)
	add_child_autofree(sheet)
	return sheet


func _world() -> WorldView:
	var joystick := JoystickView.new()
	add_child_autofree(joystick)
	var world := WorldView.new()
	add_child_autofree(world)
	world.setup(game, joystick)
	watch_signals(world)
	return world


func _room_spot(room_id: String) -> String:
	return GameConfig.ROOM_PLAYER if room_id == GameConfig.ROOM_PLAYER else UpgradeCatalog.room_spot(room_id)


func _buy(sheet: Sheet, entry_id: String) -> void:
	sheet.act(func() -> bool: return UpgradeEntryCard.buy(game, entry_id))


func _open_all_rooms() -> void:
	game.state.unlock_department("business_licences")
	game.state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	game.state.ensure_mailroom()


func _install_tubes() -> void:
	game.state.set_upgrade("pneumatic_tubes", 1)
	game.state.set_upgrade("large_capsules", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		game.state.set_upgrade("tube_station", 1, room_id)


func _has_label(node: Node, text: String) -> bool:
	if node is Label and (node as Label).text == text:
		return true
	for child in node.get_children():
		if _has_label(child, text):
			return true
	return false


func _count_labels(node: Node, text: String) -> int:
	var count := 1 if node is Label and (node as Label).text == text else 0
	for child in node.get_children():
		count += _count_labels(child, text)
	return count


func _label_set(node: Node) -> Dictionary:
	var result := {}
	_collect_labels(node, result)
	return result


func _collect_labels(node: Node, result: Dictionary) -> void:
	if node is Label:
		result[(node as Label).text] = true
	for child in node.get_children():
		_collect_labels(child, result)


func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null


func test_room_headers_are_registered_as_room_spots() -> void:
	for room_id in UpgradeCatalog.rooms():
		var spot := UpgradeCatalog.room_spot(room_id)
		var header := layout.room_header(room_id)
		if room_id == GameConfig.ROOM_PLAYER:
			assert_false(header.has_area())
			assert_true(layout.spot_rects(spot).is_empty())
			continue
		assert_has(layout.spot_rects(spot), header, room_id)
		assert_eq(layout.spot_at(header.get_center()), spot, room_id)
	assert_eq(layout.room_header("tax_services"), layout.header("tax_services"))
	assert_eq(layout.room_header(GameConfig.ROOM_INSPECTION), layout.header("inspection"))
	assert_eq(layout.room_header(GameConfig.ROOM_HALL), layout.hall_plate())
	assert_eq(layout.room_header(GameConfig.ROOM_KITCHEN), layout.kitchen_header())
	assert_eq(layout.room_header(GameConfig.ROOM_TOILETS), layout.toilets_header())
	assert_eq(layout.room_header(GameConfig.ROOM_PHONE), layout.phone_header())
	assert_eq(layout.room_header(GameConfig.ROOM_MAIL), layout.mail_header())
	assert_eq(layout.room_header("nope"), Rect2())


func test_room_spots_skip_room_bodies_and_gaps() -> void:
	for room_id in UpgradeCatalog.rooms():
		var body := layout.service_room(room_id)
		if not body.has_area():
			continue
		assert_ne(layout.spot_at(body.get_center()), UpgradeCatalog.room_spot(room_id), room_id)
		assert_eq(layout.room_at(body.get_center()), room_id, room_id)
	var world := _world()
	var gap := Vector2(layout.kitchen_header().end.x + WorldLayout.GAP * 0.5, layout.kitchen_header().get_center().y)
	for point: Vector2 in [Vector2(1.0, 1.0), gap]:
		assert_eq(layout.spot_at(point), "")
		assert_eq(layout.room_at(point), "")
		assert_eq(world.tap_spot(point), "")


func test_room_availability_follows_progress() -> void:
	var state := game.state
	for room_id: String in [GameConfig.ROOM_PLAYER, GameConfig.ROOM_HALL, GameConfig.ROOM_COMPLAINTS, GameConfig.ROOM_SHREDDER, GameConfig.ROOM_TECH, GameConfig.ROOM_KITCHEN, GameConfig.ROOM_TOILETS, GameConfig.ROOM_PHONE, "", "general_services"]:
		assert_true(Progression.room_available(state, room_id), room_id)
	for room_id: String in [GameConfig.ROOM_MAIL, GameConfig.ROOM_INSPECTION, "tax_services", "nope"]:
		assert_false(Progression.room_available(state, room_id), room_id)
	assert_eq(Progression.upgrade_block_reason(state, "mail_subscription"), "room")
	assert_eq(Progression.upgrade_block_reason(state, "tube_station", GameConfig.ROOM_MAIL), "room")
	_open_all_rooms()
	for room_id: String in [GameConfig.ROOM_MAIL, GameConfig.ROOM_INSPECTION, "business_licences"]:
		assert_true(Progression.room_available(state, room_id), room_id)
	assert_false(Progression.room_available(state, "tax_services"))
	assert_eq(Progression.upgrade_block_reason(state, "mail_subscription"), "")
	assert_eq(Progression.upgrade_block_reason(state, "tube_station", GameConfig.ROOM_MAIL), "requires")


func test_room_entries_skip_locked_rooms() -> void:
	var state := game.state
	var inspection := UpgradeCatalog.room_spot(GameConfig.ROOM_INSPECTION)
	assert_eq(inspection, UpgradeCatalog.ROOM_PREFIX + GameConfig.ROOM_INSPECTION)
	assert_true(UpgradeCatalog.entries_for_spot(state, inspection).is_empty())
	assert_false(UpgradeCatalog.entries_for_spot(state, UpgradeCatalog.room_spot(GameConfig.ROOM_PHONE)).is_empty())
	assert_false(UpgradeCatalog.entries_for_spot(state, UpgradeCatalog.room_spot(GameConfig.ROOM_TOILETS)).is_empty())
	assert_true(UpgradeCatalog.entries_for_spot(state, UpgradeCatalog.ROOM_PREFIX + "nope").is_empty())
	state.unlock_department("business_licences")
	var spots := UpgradeCatalog.spots_of(UpgradeCatalog.entries_for_spot(state, inspection))
	assert_has(spots, UpgradeCatalog.STATION_PREFIX + GameConfig.INSPECTION)
	assert_has(spots, UpgradeCatalog.TUBE_PREFIX + GameConfig.ROOM_INSPECTION)


func test_staff_entries_cover_every_board() -> void:
	game.state.set_upgrade("shredder_service", 1)
	var boards: Array[String] = []
	for staff_type: String in UpgradeCatalog.STAFF_SPOTS:
		var entry := UpgradeCatalog.find(game.state, "%s:%s" % [UpgradeCatalog.STAFF, staff_type])
		assert_not_null(entry, staff_type)
		assert_eq(entry.level, 0, staff_type)
		assert_gt(entry.cost, 0.0, staff_type)
		assert_true(entry.is_buyable(), staff_type)
		assert_has(GameConfig.BOARD_SPOTS, entry.spot)
		assert_false(SpotStatus.lines(game.state, entry.spot).is_empty(), entry.spot)
		boards.append(entry.spot)
	for spot in GameConfig.BOARD_SPOTS:
		assert_has(boards, spot)


func test_staff_status_texts_follow_upgrades() -> void:
	assert_eq(SpotStatus.runners(game.state), TranslationServer.translate("FMT_RUNNER_INFO") % [Formulas.runner_capacity(game.state), UiKit.decimal(Formulas.transport_throughput(game.state) * 60.0)])
	assert_eq(SpotStatus.interns(game.state), TranslationServer.translate("LABEL_NEEDS_SHREDDER_SERVICE"))
	_install_tubes()
	game.state.set_upgrade("shredder_service", 1)
	assert_eq(SpotStatus.runners(game.state), TranslationServer.translate("LABEL_TUBES_ACTIVE"))
	assert_eq(SpotStatus.interns(game.state), TranslationServer.translate("FMT_HELPER_INFO") % Formulas.intern_capacity(game.state))


func test_buy_button_text_reflects_block_reason() -> void:
	var state := game.state
	state.set_upgrade("coffee", int(GameConfig.upgrade("coffee").max))
	assert_eq(UpgradeTexts.button_text(state, UpgradeCatalog.track(state, "coffee"), 1), TranslationServer.translate("LABEL_MAX_LEVEL"))
	assert_eq(UpgradeTexts.button_text(state, UpgradeCatalog.track(state, "tube_capacity"), 1), TranslationServer.translate("FMT_REQ_UPGRADE") % TranslationServer.translate("TRACK_PNEUMATIC_TUBES"))
	var espresso := UpgradeCatalog.track(state, "espresso")
	assert_eq(UpgradeTexts.button_text(state, espresso, 1), TranslationServer.translate("FMT_ACTION_COST") % [TranslationServer.translate("ACTION_BUY"), UiKit.money(espresso.bulk_cost(1))])
	state.reputation = 0.0
	state.reputation_peak = 0.0
	assert_eq(UpgradeTexts.button_text(state, UpgradeCatalog.track(state, "espresso"), 1), TranslationServer.translate("FMT_REQ_REPUTATION") % int(GameConfig.upgrade("espresso").reputation))
	state.money = 0.0
	var seating := UpgradeCatalog.track(state, "seating")
	assert_eq(seating.reason, "money")
	assert_eq(UpgradeTexts.button_text(state, seating, 1), TranslationServer.translate("FMT_ACTION_COST") % [TranslationServer.translate("ACTION_BUY"), UiKit.money(seating.bulk_cost(1))])


func test_every_room_spot_shows_only_its_upgrades() -> void:
	_open_all_rooms()
	var entries := UpgradeCatalog.entries(game.state)
	for room_id in GameConfig.SERVICE_ROOMS:
		var spot := _room_spot(room_id)
		var sheet := _sheet(spot)
		var labels := _label_set(sheet.content)
		assert_eq(sheet.title(), UpgradeTexts.spot_title(spot))
		assert_false(sheet.title().begins_with("ROOM_") or sheet.title().begins_with("SPOT_"), spot)
		assert_true(labels.has(UpgradeTexts.spot_description(spot)), spot)
		var own := {}
		for entry in entries:
			if entry.room == room_id:
				own[UpgradeTexts.title(entry)] = true
		for entry in entries:
			var title := UpgradeTexts.title(entry)
			if entry.room == room_id:
				assert_true(labels.has(title), "%s/%s" % [room_id, entry.id])
			elif not own.has(title):
				assert_false(labels.has(title), "%s/%s" % [room_id, entry.id])
		for boost_id in GameConfig.BOOST_ORDER:
			assert_eq(labels.has(sheet.tr("BOOST_" + boost_id.to_upper())), GameConfig.room_boosts(room_id).has(boost_id), "%s/%s" % [room_id, boost_id])
		assert_eq(labels.has(sheet.tr("SECTION_ROOM_BOOSTS")), not GameConfig.room_boosts(room_id).is_empty(), room_id)
	await wait_physics_frames(2)


func test_locked_room_spots_explain_why_they_are_closed() -> void:
	var mail := _sheet(UpgradeCatalog.room_spot(GameConfig.ROOM_MAIL))
	var mail_labels := _label_set(mail.content)
	assert_true(mail_labels.has(mail.tr("ROOM_LOCKED_TITLE")))
	assert_true(mail_labels.has(mail.tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1)))
	assert_false(mail_labels.has(mail.tr("SPOT_EMPTY")))
	var shelf := _sheet("mail_shelf")
	assert_true(_has_label(shelf.content, shelf.tr("ROOM_LOCKED_TITLE")))
	var inspection := _sheet(UpgradeCatalog.room_spot(GameConfig.ROOM_INSPECTION))
	assert_true(_has_label(inspection.content, inspection.tr("ROOM_LOCKED_INSPECTION")))
	var tax := _sheet(UpgradeCatalog.room_spot("tax_services"))
	assert_false(_has_label(tax.content, tax.tr("ROOM_LOCKED_TITLE")))
	assert_true(_has_label(tax.content, UpgradeTexts.title(UpgradeCatalog.find(game.state, "%s:tax_services" % UpgradeCatalog.UNLOCK))))
	assert_eq(SpotSheet.locked_text(game.state, GameConfig.ROOM_KITCHEN), tax.tr("LABEL_ROOM_LOCKED"))
	_open_all_rooms()
	mail.rebuild()
	inspection.rebuild()
	assert_false(_has_label(mail.content, mail.tr("ROOM_LOCKED_TITLE")))
	assert_false(_has_label(inspection.content, inspection.tr("ROOM_LOCKED_INSPECTION")))
	await wait_physics_frames(2)


func test_room_spot_actions_buy_upgrades() -> void:
	var kitchen := _sheet(UpgradeCatalog.room_spot(GameConfig.ROOM_KITCHEN))
	_buy(kitchen, "%s:coffee_interns" % UpgradeCatalog.STAFF)
	_buy(kitchen, "%s:coffee" % UpgradeCatalog.TRACK)
	assert_eq(game.state.coffee_interns.size(), 1)
	assert_eq(game.state.upgrade_level("coffee"), 1)
	var hall := _sheet(UpgradeCatalog.room_spot(GameConfig.ROOM_HALL))
	_buy(hall, "%s:waiting_places" % UpgradeCatalog.TRACK)
	_buy(hall, "%s:seating" % UpgradeCatalog.TRACK)
	_buy(hall, "%s:guards" % UpgradeCatalog.STAFF)
	hall.refresh()
	assert_eq(game.state.upgrade_level("waiting_places"), 1)
	assert_eq(game.state.upgrade_level("seating"), 1)
	assert_eq(game.state.guards, 1)
	assert_true(_has_label(hall.content, UpgradeTexts.level_text(UpgradeCatalog.find(game.state, "%s:seating" % UpgradeCatalog.TRACK))))
	await wait_physics_frames(2)


func test_department_spot_lists_office_upgrades_once() -> void:
	var spot := UpgradeCatalog.room_spot("general_services")
	var sheet := _sheet(spot)
	var entries := UpgradeCatalog.entries_for_spot(game.state, spot)
	assert_false(entries.is_empty())
	for entry in entries:
		assert_eq(entry.room, "general_services", entry.id)
		assert_eq(_count_labels(sheet.content, UpgradeTexts.title(entry)), 1, entry.id)
	assert_eq(_count_labels(sheet.content, sheet.tr("TRACK_DESC_OFFICE_EQUIPMENT")), 1)
	assert_true(_has_label(sheet.content, sheet.tr("LEGEND_MARKERS")))
	assert_true(_has_label(sheet.content, DepartmentSection.route_text("general_services")))
	assert_false(_has_label(sheet.content, sheet.tr("TRACK_DESC_COFFEE")))
	assert_false(_has_label(sheet.content, sheet.tr("TRACK_DESC_BRIEFCASE")))
	await wait_physics_frames(2)


func test_upgrade_overview_groups_only_open_rooms() -> void:
	UpgradesSheet.mode_index = 0
	UpgradesSheet.expanded.clear()
	var sheet := UpgradesSheet.new()
	sheet.setup(game)
	add_child_autofree(sheet)
	for room_id: String in [GameConfig.ROOM_PLAYER, GameConfig.ROOM_HALL, GameConfig.ROOM_TECH, GameConfig.ROOM_KITCHEN, GameConfig.ROOM_TOILETS, GameConfig.ROOM_PHONE, "general_services"]:
		assert_true(_has_label(sheet.content, UpgradeTexts.room_title(room_id)), room_id)
	assert_false(_has_label(sheet.content, UpgradeTexts.room_title(GameConfig.ROOM_INSPECTION)))
	game.state.unlock_department("business_licences")
	sheet.rebuild()
	assert_true(_has_label(sheet.content, UpgradeTexts.room_title(GameConfig.ROOM_INSPECTION)))
	await wait_physics_frames(2)


func test_room_boosts_cover_every_boost_once() -> void:
	var seen: Array[String] = []
	for room_id in GameConfig.SERVICE_ROOMS:
		for boost_id in GameConfig.room_boosts(room_id):
			assert_does_not_have(seen, boost_id)
			seen.append(boost_id)
	var expected: Array[String] = []
	expected.assign(GameConfig.BOOST_ORDER)
	seen.sort()
	expected.sort()
	assert_eq(seen, expected)
	assert_true(GameConfig.room_boosts("nope").is_empty())


func test_spot_boosts_follow_the_room_and_the_mail_room() -> void:
	assert_eq(SpotSheet.room_boosts(game, GameConfig.ROOM_PLAYER), GameConfig.room_boosts(GameConfig.ROOM_PLAYER))
	assert_eq(SpotSheet.room_boosts(game, UpgradeCatalog.room_spot(GameConfig.ROOM_KITCHEN)), GameConfig.room_boosts(GameConfig.ROOM_KITCHEN))
	assert_true(SpotSheet.room_boosts(game, "coffee_machine").is_empty())
	assert_true(SpotSheet.room_boosts(game, UpgradeCatalog.room_spot("general_services")).is_empty())
	var mail := UpgradeCatalog.room_spot(GameConfig.ROOM_MAIL)
	assert_true(SpotSheet.room_boosts(game, mail).is_empty())
	game.state.boosts["express_post"] = 30.0
	assert_eq(SpotSheet.room_boosts(game, mail), GameConfig.room_boosts(GameConfig.ROOM_MAIL))
	game.state.boosts.erase("express_post")
	_open_all_rooms()
	assert_eq(SpotSheet.room_boosts(game, mail), GameConfig.room_boosts(GameConfig.ROOM_MAIL))


func test_tapping_room_headers_opens_their_room_spots() -> void:
	var world := _world()
	world._handle_tap(layout.kitchen_header().get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.room_spot(GameConfig.ROOM_KITCHEN)])
	world._handle_tap(layout.toilets_header().get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.room_spot(GameConfig.ROOM_TOILETS)])
	for room_id: String in [GameConfig.ROOM_COMPLAINTS, GameConfig.ROOM_SHREDDER, GameConfig.ROOM_TECH]:
		world._handle_tap(layout.room_header(room_id).get_center())
		assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.room_spot(room_id)])
	world._handle_tap(Vector2(1.0, 1.0))
	assert_signal_emit_count(world, "open_spot", 5)


func test_tapping_a_room_body_opens_a_spot_of_that_room() -> void:
	var world := _world()
	for room_id in GameConfig.SERVICE_ROOMS:
		if room_id == GameConfig.ROOM_PLAYER:
			continue
		var spot := world.tap_spot(layout.service_room(room_id).get_center())
		assert_false(spot.is_empty(), room_id)
		assert_eq(GameConfig.spot_room(spot), room_id, spot)
	for dept_id: String in ["general_services", "tax_services"]:
		assert_eq(GameConfig.spot_room(world.tap_spot(layout.room(dept_id).get_center())), dept_id)
	world._handle_tap(layout.kitchen.get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", [UpgradeCatalog.room_spot(GameConfig.ROOM_KITCHEN)])


func test_tapping_complaint_pile_opens_the_complaint_desk() -> void:
	var world := _world()
	world._handle_tap(layout.complaint_read_rect().get_center())
	assert_signal_emitted_with_parameters(world, "open_spot", ["complaint_desk"])
	var sheet := _sheet("complaint_desk")
	watch_signals(sheet)
	var read := _find_button(sheet.content, sheet.tr("ACTION_READ_COMPLAINTS"))
	assert_not_null(read)
	read.pressed.emit()
	assert_signal_emitted_with_parameters(sheet, "navigate", ["complaints", ""])
	await wait_physics_frames(2)


func test_room_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["SECTION_ROOM_BOOSTS", "SECTION_SHIFT_PLAN", "ROOM_LOCKED_TITLE", "ROOM_LOCKED_INSPECTION", "LABEL_ROOM_LOCKED", "SPOT_EMPTY", "ACTION_OPEN_SPOT", "ACTION_LOCATE", "ACTION_READ_COMPLAINTS"]
	for room_id in GameConfig.SERVICE_ROOMS:
		keys.append("ROOM_" + room_id.to_upper())
		keys.append(UpgradeTexts.spot_description_key(_room_spot(room_id)))
		keys.append(UpgradeTexts.spot_description_key(UpgradeCatalog.room_spot(room_id)))
	for dept_id in GameConfig.department_ids():
		keys.append(UpgradeTexts.spot_description_key(UpgradeCatalog.room_spot(dept_id)))
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)
