class_name UpgradeCards
extends RefCounted


static func room_title(room_id: String) -> String:
	return TranslationServer.translate("ROOM_" + room_id.to_upper())


static func room_description(room_id: String) -> String:
	return TranslationServer.translate("ROOM_DESC_" + room_id.to_upper())


static func add_room(sheet: Sheet, container: VBoxContainer, room_id: String) -> void:
	var staff := GameConfig.room_items(room_id, "staff")
	if not staff.is_empty():
		container.add_child(UiKit.label(sheet.tr("SECTION_ROOM_STAFF"), "TitleMedium"))
		for staff_id in staff:
			container.add_child(staff_card(sheet, staff_id))
	var stations := available_stations(sheet.game.state, room_id)
	if not stations.is_empty():
		container.add_child(UiKit.label(sheet.tr("SECTION_ROOM_STATIONS"), "TitleMedium"))
		for key in stations:
			container.add_child(StationCard.build(sheet, key))
	var areas := GameConfig.room_items(room_id, "areas")
	if not areas.is_empty():
		container.add_child(UiKit.label(sheet.tr("SECTION_ROOM_AREAS"), "TitleMedium"))
		for area_id in areas:
			container.add_child(area_card(sheet, area_id))
	var research := GameConfig.room_items(room_id, "research")
	if not research.is_empty():
		container.add_child(UiKit.label(sheet.tr("SECTION_ROOM_RESEARCH"), "TitleMedium"))
		for research_id in research:
			container.add_child(research_card(sheet, research_id))
	var boosts := GameConfig.room_items(room_id, "boosts")
	if not boosts.is_empty():
		container.add_child(UiKit.label(sheet.tr("SECTION_ROOM_BOOSTS"), "TitleMedium"))
		for boost_id in boosts:
			container.add_child(boost_card(sheet, boost_id))


static func available_stations(state: GameState, room_id: String) -> Array[String]:
	var keys: Array[String] = []
	for key in GameConfig.room_items(room_id, "stations"):
		if state.station(key) != null:
			keys.append(key)
	return keys


static func has_upgrades(state: GameState, room_id: String) -> bool:
	for kind in ["staff", "areas", "research", "boosts"]:
		if not GameConfig.room_items(room_id, kind).is_empty():
			return true
	return not available_stations(state, room_id).is_empty()


static func staff_spec(game: Game, staff_id: String) -> Dictionary:
	var state := game.state
	var actions := game.actions
	match staff_id:
		"runners":
			return {"icon": Icons.STAFF.runners, "color": AppTheme.RUNNER, "max": GameConfig.MAX_RUNNERS,
				"count": func() -> int: return state.runners.size(),
				"cost": func() -> float: return Formulas.runner_cost(state),
				"can": actions.can_hire_runner, "hire": actions.hire_runner,
				"info": UpgradeCards.runner_info.bind(state)}
		"collectors":
			return {"icon": Icons.STAFF.collectors, "color": AppTheme.accent("neutral"), "max": GameConfig.MAX_COLLECTORS,
				"count": func() -> int: return state.collectors.size(),
				"cost": func() -> float: return Formulas.collector_cost(state),
				"can": actions.can_hire_collector, "hire": actions.hire_collector,
				"info": func() -> String: return TranslationServer.translate("FMT_COLLECTOR_INFO") % [Formulas.collector_capacity(state), state.rejects_waiting()]}
		"helpers":
			return {"icon": Icons.STAFF.helpers, "color": AppTheme.accent("tertiary"), "max": GameConfig.MAX_HELPERS,
				"count": func() -> int: return state.helpers.size(),
				"cost": func() -> float: return Formulas.helper_cost(state),
				"can": actions.can_hire_helper, "hire": actions.hire_helper,
				"info": UpgradeCards.helper_info.bind(state)}
		"coffee_interns":
			return {"icon": Icons.STAFF.coffee_interns, "color": AppTheme.COFFEE_LIQUID, "max": GameConfig.MAX_COFFEE_INTERNS,
				"count": func() -> int: return state.coffee_interns.size(),
				"cost": func() -> float: return Formulas.coffee_intern_cost(state),
				"can": actions.can_hire_coffee_intern, "hire": actions.hire_coffee_intern,
				"info": func() -> String: return TranslationServer.translate("FMT_COFFEE_INTERN_INFO") % state.coffees_served}
		"hr":
			return {"icon": Icons.STAFF.hr, "color": AppTheme.SPECIALIST, "max": GameConfig.MAX_HR,
				"count": func() -> int: return state.hr,
				"cost": func() -> float: return Formulas.hr_cost(state),
				"can": actions.can_hire_hr, "hire": actions.hire_hr,
				"info": func() -> String: return TranslationServer.translate("FMT_HR_INFO") % [state.sick_count(), state.reported_sick_count(), state.ringing_count()]}
		"guards":
			return {"icon": Icons.STAFF.guards, "color": AppTheme.GUARD, "max": GameConfig.MAX_GUARDS,
				"count": func() -> int: return state.guards,
				"cost": func() -> float: return Formulas.guard_cost(state),
				"can": actions.can_hire_guard, "hire": actions.hire_guard,
				"info": func() -> String: return TranslationServer.translate("FMT_GUARD_INFO") % [roundi(Formulas.guard_block_chance(state) * 100.0), state.visitors_stopped]}
	return {}


static func runner_info(state: GameState) -> String:
	if state.all_piped():
		return TranslationServer.translate("LABEL_TUBES_ACTIVE")
	return TranslationServer.translate("FMT_RUNNER_INFO") % [Formulas.runner_capacity(state), UiKit.decimal(Formulas.transport_throughput(state) * 60.0)]


static func role_info(state: GameState, role: String) -> String:
	return TranslationServer.translate("FMT_RUNNER_ROLE_INFO") % [TranslationServer.translate("RUNNER_ROLE_" + role.to_upper()), state.runners_in(role), state.transfer_backlog(role)]


static func runner_card(sheet: Sheet) -> Control:
	var game := sheet.game
	var state := game.state
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.STAFF.runners, AppTheme.RUNNER))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(sheet.tr("STAFF_DESC_RUNNERS"), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var updaters: Array[Callable] = []
	for role in Runner.ROLES:
		var role_label := UiKit.label("", "BodyMedium", true)
		column.add_child(role_label)
		var button := StationCard.action_button(sheet, game.actions.hire_runner.bind(role))
		column.add_child(button)
		updaters.append(func() -> void:
			role_label.text = role_info(state, role)
			StationCard.update_button(button, "ACTION_HIRE", Formulas.runner_cost(state), game.actions.can_hire_runner(), state.runners.size() >= GameConfig.MAX_RUNNERS, "LABEL_MAX_LEVEL")
		)
	var plan := UiKit.button(sheet.tr("ACTION_RUNNER_PLAN"), "primary", "Outlined")
	plan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan.disabled = state.runners.is_empty()
	plan.pressed.connect(func() -> void: sheet.navigate.emit("runners", ""))
	column.add_child(plan)
	card.add_child(column)
	sheet.track(func() -> void:
		name_label.text = sheet.tr("FMT_STAFF_COUNT") % [sheet.tr("STAFF_RUNNERS"), state.runners.size(), GameConfig.MAX_RUNNERS]
		info.text = runner_info(state)
		for updater in updaters:
			updater.call()
	)
	return card


static func helper_info(state: GameState) -> String:
	if state.has_research("shredder_service"):
		return TranslationServer.translate("FMT_HELPER_INFO") % Formulas.intern_capacity(state)
	return TranslationServer.translate("LABEL_NEEDS_SHREDDER_SERVICE")


static func staff_card(sheet: Sheet, staff_id: String) -> Control:
	if staff_id == "runners":
		return runner_card(sheet)
	var spec := staff_spec(sheet.game, staff_id)
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(spec.icon, spec.color))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(sheet.tr("STAFF_DESC_" + staff_id.to_upper()), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(sheet, spec.hire)
	column.add_child(button)
	card.add_child(column)
	var maximum: int = spec.max
	sheet.track(func() -> void:
		var count: int = spec.count.call()
		name_label.text = sheet.tr("FMT_STAFF_COUNT") % [sheet.tr("STAFF_" + staff_id.to_upper()), count, maximum]
		info.text = spec.info.call()
		StationCard.update_button(button, "ACTION_HIRE", spec.cost.call(), spec.can.call(), count >= maximum, "LABEL_MAX_LEVEL")
	)
	return card


static func area_spec(game: Game, area_id: String) -> Dictionary:
	var state := game.state
	var actions := game.actions
	match area_id:
		"waiting":
			return {"icon": Icons.SEAT, "desc": "WAITING_DESC", "action": "ACTION_BUILD_SEATS",
				"upgrade": actions.upgrade_waiting_area, "can": actions.can_upgrade_waiting_area,
				"level": func() -> int: return state.waiting_level, "max": GameConfig.WAITING_MAX_LEVEL,
				"cost": func() -> float: return Formulas.waiting_area_cost(state),
				"title": "WAITING_TITLE",
				"info": func() -> String: return TranslationServer.translate("FMT_WAITING_INFO") % [state.lobby_capacity(), GameConfig.WAITING_SEATS_PER_LEVEL, state.walkouts]}
		"ticket_machine":
			return {"icon": Icons.TICKET, "desc": "TICKET_MACHINE_DESC", "action": "ACTION_UPGRADE_TICKET_MACHINE",
				"upgrade": actions.upgrade_ticket_machine, "can": actions.can_upgrade_ticket_machine,
				"level": func() -> int: return state.ticket_machine_level, "max": GameConfig.TICKET_MAX_LEVEL,
				"cost": func() -> float: return Formulas.ticket_machine_cost(state),
				"title": "TICKET_MACHINE_TITLE",
				"info": UpgradeCards.ticket_machine_info.bind(state)}
		"ticket_display":
			return {"icon": Icons.CALL_DISPLAY, "desc": "TICKET_DISPLAY_DESC", "action": "ACTION_UPGRADE_TICKET_DISPLAY",
				"upgrade": actions.upgrade_ticket_display, "can": actions.can_upgrade_ticket_display,
				"level": func() -> int: return state.ticket_display_level, "max": GameConfig.TICKET_MAX_LEVEL,
				"cost": func() -> float: return Formulas.ticket_display_cost(state),
				"title": "TICKET_DISPLAY_TITLE",
				"info": UpgradeCards.ticket_display_info.bind(state)}
		"seating":
			return {"icon": Icons.SEAT, "desc": "SEATING_DESC", "action": "ACTION_BUILD_SEATING",
				"upgrade": actions.upgrade_seating_area, "can": actions.can_upgrade_seating_area,
				"level": func() -> int: return state.seating_level, "max": GameConfig.SEATING_MAX_LEVEL,
				"cost": func() -> float: return Formulas.seating_area_cost(state),
				"title": "SEATING_TITLE",
				"info": func() -> String: return TranslationServer.translate("FMT_SEATING_INFO") % [state.seated_citizens(), state.seat_capacity(), GameConfig.SEATING_SEATS_PER_LEVEL]}
		"complaint_clerk":
			return {"icon": Icons.CLERK, "desc": "COMPLAINT_CLERK_DESC", "action": "ACTION_TRAIN_CLERK",
				"upgrade": actions.upgrade_complaint_clerk, "can": actions.can_upgrade_complaint_clerk,
				"level": func() -> int: return state.complaint_clerk_level, "max": GameConfig.COMPLAINT_CLERK_MAX_LEVEL,
				"cost": func() -> float: return Formulas.complaint_clerk_cost(state),
				"title": "COMPLAINT_CLERK_TITLE",
				"info": UpgradeCards.complaint_clerk_info.bind(state)}
		"complaint_box":
			return {"icon": Icons.COMPLAINT_BOX, "desc": "COMPLAINT_BOX_DESC", "action": "ACTION_ENLARGE_BOX",
				"upgrade": actions.upgrade_complaint_box, "can": actions.can_upgrade_complaint_box,
				"level": func() -> int: return state.complaint_box_level, "max": GameConfig.COMPLAINT_BOX_MAX_LEVEL,
				"cost": func() -> float: return Formulas.complaint_box_cost(state),
				"title": "COMPLAINT_BOX_TITLE",
				"info": func() -> String: return TranslationServer.translate("FMT_COMPLAINT_BOX_INFO") % [state.complaints, Formulas.complaint_cap(state), GameConfig.COMPLAINT_BOX_PER_LEVEL]}
		"mail_storage":
			return {"icon": Icons.STORAGE, "desc": "MAIL_STORAGE_DESC", "action": "ACTION_BUILD_SHELVES",
				"upgrade": actions.upgrade_mail_storage, "can": actions.can_upgrade_mail_storage,
				"level": func() -> int: return state.mailroom().storage_level if state.mailroom() != null else 0, "max": GameConfig.MAIL_STORAGE_MAX_LEVEL,
				"cost": func() -> float: return Formulas.mail_storage_cost(state.mailroom()) if state.mailroom() != null else 0.0,
				"title": "MAIL_STORAGE_TITLE",
				"info": UpgradeCards.mail_storage_info.bind(state)}
	return {}


static func complaint_clerk_info(state: GameState) -> String:
	var level := state.complaint_clerk_level
	var text := TranslationServer.translate("FMT_COMPLAINT_CLERK_INFO") % [UiKit.percent(Formulas.complaint_fend_chance(level)), state.complaints_fended]
	if level < GameConfig.COMPLAINT_CLERK_MAX_LEVEL:
		text += "\n" + TranslationServer.translate("FMT_COMPLAINT_CLERK_NEXT") % UiKit.percent(Formulas.complaint_fend_chance(level + 1))
	return text


static func ticket_machine_info(state: GameState) -> String:
	if not state.tickets_unlocked():
		return TranslationServer.translate("FMT_TICKETS_LOCKED") % (GameConfig.TICKET_UNLOCK_STAGE + 1)
	return TranslationServer.translate("FMT_TICKET_MACHINE_INFO") % [UiKit.decimal(Formulas.ticket_draw_time(state.ticket_machine_level)), state.ticket_line.size(), GameConfig.TICKET_LINE_SLOTS]


static func ticket_display_info(state: GameState) -> String:
	if not state.tickets_unlocked():
		return TranslationServer.translate("FMT_TICKETS_LOCKED") % (GameConfig.TICKET_UNLOCK_STAGE + 1)
	return TranslationServer.translate("FMT_TICKET_DISPLAY_INFO") % [UiKit.decimal(Formulas.ticket_call_time(state.ticket_display_level)), state.ticket_waiting.size(), state.tickets_called]


static func mail_storage_info(state: GameState) -> String:
	var room := state.mailroom()
	if room == null:
		return TranslationServer.translate("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1)
	return TranslationServer.translate("FMT_MAIL_STORAGE_INFO") % [room.inbox.size(), room.storage_capacity(), GameConfig.MAIL_STORAGE_PER_LEVEL, Formulas.mail_batch(state), UiKit.duration(state.mail_timer), state.mail_returned, UiKit.percent(Formulas.mail_reward_factor(state))]


static func area_card(sheet: Sheet, area_id: String) -> Control:
	var spec := area_spec(sheet.game, area_id)
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(spec.icon, AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(sheet.tr(spec.desc), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info := UiKit.label("", "BodySmall", true)
	column.add_child(info)
	var button := StationCard.action_button(sheet, spec.upgrade)
	column.add_child(button)
	card.add_child(column)
	var maximum: int = spec.max
	sheet.track(func() -> void:
		var level: int = spec.level.call()
		name_label.text = sheet.tr("FMT_WAITING_LEVEL") % [sheet.tr(spec.title), level, maximum]
		info.text = spec.info.call()
		StationCard.update_button(button, spec.action, spec.cost.call(), spec.can.call(), level >= maximum, "LABEL_MAX_LEVEL")
	)
	return card


static func research_card(sheet: Sheet, research_id: String) -> Control:
	var game := sheet.game
	var config: Dictionary = GameConfig.RESEARCH[research_id]
	var card := UiKit.card("CardRow")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.RESEARCH[research_id], AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(sheet.tr("RESEARCH_DESC_" + research_id.to_upper()), "BodySmall", true))
	row.add_child(texts)
	column.add_child(row)
	var info: Label = null
	if research_id == "tube_capacity":
		info = UiKit.label("", "BodySmall", true)
		column.add_child(info)
	var level_bar := UiKit.progress(0.0, "success")
	column.add_child(level_bar)
	var button := UiKit.button("")
	button.pressed.connect(func() -> void: sheet.act(game.actions.buy_research.bind(research_id)))
	column.add_child(button)
	card.add_child(column)
	sheet.track(func() -> void:
		var level := game.state.research_level(research_id)
		var maximum := int(config.max_level)
		name_label.text = sheet.tr("FMT_RESEARCH_LEVEL") % [sheet.tr("RESEARCH_" + research_id.to_upper()), level, maximum]
		level_bar.value = float(level) / maximum
		if info != null:
			info.text = sheet.tr("FMT_TUBE_CAPACITY") % Formulas.tube_capacity(game.state)
		var reason := Progression.research_block_reason(game.state, research_id)
		button.disabled = not reason.is_empty()
		button.text = research_button_text(research_id, reason, level)
	)
	return card


static func research_button_text(research_id: String, reason: String, level: int) -> String:
	var config: Dictionary = GameConfig.RESEARCH[research_id]
	match reason:
		"max":
			return TranslationServer.translate("LABEL_RESEARCHED")
		"requires":
			return TranslationServer.translate("FMT_REQ_RESEARCH") % TranslationServer.translate("RESEARCH_" + str(config.requires).to_upper())
		"reputation":
			return TranslationServer.translate("FMT_REQ_REPUTATION") % int(config.reputation)
	return UiKit.cost_text("ACTION_RESEARCH", Formulas.research_cost(research_id, level))


static func boost_card(sheet: Sheet, boost_id: String) -> Control:
	var game := sheet.game
	var card := UiKit.card("CardRow")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.BOOSTS[boost_id], AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	texts.add_child(UiKit.label(sheet.tr("BOOST_" + boost_id.to_upper()), "TitleSmall", true))
	texts.add_child(UiKit.label(sheet.tr("BOOST_DESC_" + boost_id.to_upper()), "BodySmall", true))
	row.add_child(texts)
	var active := UiKit.pill("", "success")
	row.add_child(active)
	column.add_child(row)
	var buttons := UiKit.hbox(AppTheme.SPACING_SM)
	var seals := StationCard.action_button(sheet, game.boosts.use.bind(boost_id, Boosts.SEALS))
	var ad := UiKit.button("", "primary", "Outlined")
	ad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ad.custom_minimum_size.y = 56
	ad.pressed.connect(func() -> void: sheet.watch_ad(game.boosts.use.bind(boost_id, Boosts.AD)))
	buttons.add_child(seals)
	buttons.add_child(ad)
	column.add_child(buttons)
	card.add_child(column)
	sheet.track(func() -> void:
		var state := game.state
		active.visible = state.is_boost_active(boost_id)
		active.get_child(0).text = sheet.tr("FMT_BOOST_ACTIVE") % UiKit.duration(state.boost_left(boost_id))
		seals.text = sheet.tr("FMT_BOOST_SEALS") % Boosts.seal_cost(boost_id)
		seals.disabled = not game.boosts.can_use(boost_id, Boosts.SEALS)
		ad.text = boost_ad_text(state, boost_id)
		ad.disabled = not game.boosts.can_use(boost_id, Boosts.AD)
	)
	return card


static func boost_ad_text(state: GameState, boost_id: String) -> String:
	var cooldown := state.boost_cooldown(boost_id)
	if cooldown > 0.0:
		return TranslationServer.translate("FMT_AD_COOLDOWN") % UiKit.duration(cooldown)
	return TranslationServer.translate("ACTION_WATCH_AD")
