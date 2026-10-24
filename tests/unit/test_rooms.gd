extends GutTest

var game: Game
var layout: WorldLayout


func before_each() -> void:
	var state := GameState.create_new(4)
	state.money = 1e12
	state.reputation = 2000.0
	game = Game.new(state)
	layout = WorldLayout.get_default()


func _sheet(argument: String) -> RoomSheet:
	var sheet := RoomSheet.new()
	sheet.setup(game, argument)
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


func test_header_at_finds_every_room_header() -> void:
	assert_eq(layout.header_at(layout.header("tax_services").get_center()), "tax_services")
	assert_eq(layout.header_at(layout.header("inspection").get_center()), GameConfig.ROOM_INSPECTION)
	assert_eq(layout.header_at(layout.kitchen_header().get_center()), GameConfig.ROOM_KITCHEN)
	assert_eq(layout.header_at(layout.toilets_header().get_center()), GameConfig.ROOM_TOILETS)
	assert_eq(layout.header_at(layout.phone_header().get_center()), GameConfig.ROOM_PHONE)
	assert_eq(layout.header_at(layout.mail_header().get_center()), GameConfig.ROOM_MAIL)
	assert_eq(layout.header_at(Vector2(1.0, 1.0)), "")
	assert_eq(layout.header_at(Vector2(layout.kitchen_header().end.x + WorldLayout.GAP * 0.5, layout.kitchen_header().get_center().y)), "")


func test_header_at_ignores_room_bodies() -> void:
	assert_eq(layout.header_at(layout.room("tax_services").get_center()), "")
	assert_eq(layout.header_at(layout.room("inspection").get_center()), "")
	assert_eq(layout.header_at(layout.kitchen.get_center()), "")
	assert_eq(layout.header_at(layout.toilets.get_center()), "")
	assert_eq(layout.header_at(layout.phone_office.get_center()), "")
	assert_eq(layout.header_at(layout.mail_room.get_center()), "")
	assert_eq(layout.header_at(layout.hall.get_center()), "")


func test_available_stations_skip_locked_ones() -> void:
	assert_true(UpgradeCards.available_stations(game.state, GameConfig.ROOM_INSPECTION).is_empty())
	assert_false(UpgradeCards.has_upgrades(game.state, GameConfig.ROOM_INSPECTION))
	assert_true(UpgradeCards.has_upgrades(game.state, GameConfig.ROOM_PHONE))
	assert_true(UpgradeCards.has_upgrades(game.state, GameConfig.ROOM_TOILETS))
	assert_false(UpgradeCards.has_upgrades(game.state, "nope"))
	game.state.unlock_department("business_licences")
	assert_eq(UpgradeCards.available_stations(game.state, GameConfig.ROOM_INSPECTION), [GameConfig.INSPECTION] as Array[String])
	assert_true(UpgradeCards.has_upgrades(game.state, GameConfig.ROOM_INSPECTION))


func test_staff_specs_cover_every_room_staff() -> void:
	assert_true(UpgradeCards.staff_spec(game, "nope").is_empty())
	game.state.research["shredder_service"] = 1
	for room: Dictionary in GameConfig.ROOMS:
		for staff_id in GameConfig.room_items(room.id, "staff"):
			var spec := UpgradeCards.staff_spec(game, staff_id)
			assert_false(spec.is_empty(), staff_id)
			assert_eq(int(spec.count.call()), 0, staff_id)
			assert_gt(float(spec.cost.call()), 0.0, staff_id)
			assert_true(bool(spec.can.call()), staff_id)
			assert_false(str(spec.info.call()).is_empty(), staff_id)


func test_staff_info_texts_follow_research() -> void:
	assert_eq(UpgradeCards.runner_info(game.state), TranslationServer.translate("FMT_RUNNER_INFO") % [Formulas.runner_capacity(game.state), UiKit.decimal(Formulas.transport_throughput(game.state) * 60.0)])
	assert_eq(UpgradeCards.helper_info(game.state), TranslationServer.translate("LABEL_NEEDS_SHREDDER_SERVICE"))
	game.state.research["pneumatic_tubes"] = 1
	game.state.connect_all_tubes()
	game.state.research["shredder_service"] = 1
	assert_eq(UpgradeCards.runner_info(game.state), TranslationServer.translate("LABEL_TUBES_ACTIVE"))
	assert_eq(UpgradeCards.helper_info(game.state), TranslationServer.translate("FMT_HELPER_INFO") % Formulas.intern_capacity(game.state))


func test_research_button_text_reflects_block_reason() -> void:
	assert_eq(UpgradeCards.research_button_text("coffee", "max", 6), TranslationServer.translate("LABEL_RESEARCHED"))
	assert_eq(UpgradeCards.research_button_text("tube_capacity", "requires", 0), TranslationServer.translate("FMT_REQ_RESEARCH") % TranslationServer.translate("RESEARCH_PNEUMATIC_TUBES"))
	assert_eq(UpgradeCards.research_button_text("coffee", "reputation", 0), TranslationServer.translate("FMT_REQ_REPUTATION") % 5)
	assert_eq(UpgradeCards.research_button_text("coffee", "", 1), UiKit.cost_text("ACTION_RESEARCH", Formulas.research_cost("coffee", 1)))


func test_every_room_sheet_shows_only_its_upgrades() -> void:
	game.state.unlock_department("business_licences")
	game.state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	game.state.ensure_mailroom()
	for room: Dictionary in GameConfig.ROOMS:
		var room_id: String = room.id
		var sheet := _sheet(room_id)
		assert_eq(sheet.title(), UpgradeCards.room_title(room_id))
		assert_ne(sheet.title(), "ROOM_" + room_id.to_upper())
		assert_true(_has_label(sheet.content, UpgradeCards.room_description(room_id)), room_id)
		for research_id in GameConfig.RESEARCH:
			var research_name := sheet.tr("FMT_RESEARCH_LEVEL") % [sheet.tr("RESEARCH_" + str(research_id).to_upper()), game.state.research_level(research_id), int(GameConfig.RESEARCH[research_id].max_level)]
			assert_eq(_has_label(sheet.content, research_name), GameConfig.room_items(room_id, "research").has(research_id), "%s/%s" % [room_id, research_id])
		for staff_id: String in Icons.STAFF:
			assert_eq(_has_label(sheet.content, sheet.tr("STAFF_DESC_" + staff_id.to_upper())), GameConfig.room_items(room_id, "staff").has(staff_id), "%s/%s" % [room_id, staff_id])
		assert_eq(_has_label(sheet.content, sheet.tr("SECTION_ROOM_AREAS")), not GameConfig.room_items(room_id, "areas").is_empty(), room_id)
		assert_eq(_has_label(sheet.content, sheet.tr("SECTION_ROOM_STATIONS")), not GameConfig.room_items(room_id, "stations").is_empty(), room_id)
	await wait_physics_frames(2)


func test_room_sheet_actions_buy_upgrades() -> void:
	var kitchen := _sheet(GameConfig.ROOM_KITCHEN)
	kitchen.act(game.actions.hire_coffee_intern)
	kitchen.act(game.actions.buy_research.bind("coffee"))
	assert_eq(game.state.coffee_interns.size(), 1)
	assert_eq(game.state.research_level("coffee"), 1)
	var hall := _sheet(GameConfig.ROOM_HALL)
	hall.act(game.actions.upgrade_waiting_area)
	hall.act(game.actions.upgrade_seating_area)
	hall.act(game.actions.hire_guard)
	hall.refresh()
	assert_eq(game.state.waiting_level, 1)
	assert_eq(game.state.seating_level, 1)
	assert_eq(game.state.guards, 1)
	await wait_physics_frames(2)


func test_department_sheet_lists_office_upgrades_once() -> void:
	var sheet := DepartmentSheet.new()
	sheet.setup(game, "general_services")
	add_child_autofree(sheet)
	assert_true(_has_label(sheet.content, sheet.tr("SECTION_ALL_OFFICES")))
	assert_true(_has_label(sheet.content, sheet.tr("STAFF_DESC_RUNNERS")))
	assert_true(_has_label(sheet.content, sheet.tr("RESEARCH_DESC_BRIEFCASE")))
	assert_false(_has_label(sheet.content, sheet.tr("RESEARCH_DESC_COFFEE")))
	assert_eq(_count_labels(sheet.content, sheet.tr("RESEARCH_DESC_TROLLEYS")), 1)
	await wait_physics_frames(2)


func test_team_sheet_groups_staff_by_room() -> void:
	var sheet := TeamSheet.new()
	sheet.setup(game)
	add_child_autofree(sheet)
	for room_id in [GameConfig.ROOM_OFFICE, GameConfig.ROOM_KITCHEN, GameConfig.ROOM_PHONE, GameConfig.ROOM_HALL]:
		assert_true(_has_label(sheet.content, UpgradeCards.room_title(room_id)), room_id)
	assert_false(_has_label(sheet.content, UpgradeCards.room_title(GameConfig.ROOM_TOILETS)))
	assert_false(_has_label(sheet.content, UpgradeCards.room_title(GameConfig.ROOM_INSPECTION)))
	await wait_physics_frames(2)


func test_tapping_kitchen_and_toilets_headers_opens_their_rooms() -> void:
	var world := _world()
	world._handle_tap(layout.kitchen_header().get_center())
	assert_signal_emitted_with_parameters(world, "open_room", [GameConfig.ROOM_KITCHEN])
	world._handle_tap(layout.toilets_header().get_center())
	assert_signal_emitted_with_parameters(world, "open_room", [GameConfig.ROOM_TOILETS])
	world._handle_tap(Vector2(1.0, 1.0))
	assert_signal_emit_count(world, "open_room", 2)


func test_tapping_room_body_opens_nothing() -> void:
	var world := _world()
	for point in [layout.kitchen.get_center(), layout.toilets.get_center(), layout.phone_office.get_center(), layout.mail_room.get_center(), layout.hall.get_center(), layout.room("tax_services").get_center(), layout.room("inspection").get_center()]:
		world._handle_tap(point)
	assert_signal_not_emitted(world, "open_room")
	assert_signal_not_emitted(world, "open_department")
	assert_signal_not_emitted(world, "open_departments")


func test_tapping_complaint_pile_still_opens_complaints() -> void:
	var world := _world()
	world._handle_tap(layout.complaint_read_rect().get_center())
	assert_signal_emitted(world, "open_complaints")
	assert_signal_not_emitted(world, "open_room")


func test_room_texts_exist_in_both_languages() -> void:
	var keys: Array[String] = ["SECTION_ROOM_STAFF", "SECTION_ROOM_STATIONS", "SECTION_ROOM_AREAS", "SECTION_ROOM_RESEARCH", "SECTION_ALL_OFFICES"]
	for room: Dictionary in GameConfig.ROOMS:
		keys.append("ROOM_" + str(room.id).to_upper())
		keys.append("ROOM_DESC_" + str(room.id).to_upper())
	var original := TranslationServer.get_locale()
	for locale in ["de", "en"]:
		TranslationServer.set_locale(locale)
		for key in keys:
			assert_ne(TranslationServer.translate(key), key, "%s/%s" % [locale, key])
	TranslationServer.set_locale(original)
