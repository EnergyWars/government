class_name SpotSheet
extends Sheet

const REFRESH_MSEC := 200


func refresh_interval() -> int:
	return REFRESH_MSEC


func title() -> String:
	return UpgradeTexts.spot_title(argument)


func room_id() -> String:
	return GameConfig.spot_room(argument)


static func is_room_open(state: GameState, room: String) -> bool:
	return not GameConfig.department(room).is_empty() or Progression.room_available(state, room)


static func locked_text(state: GameState, room: String) -> String:
	if room == GameConfig.ROOM_MAIL:
		return TranslationServer.translate("FMT_MAIL_LOCKED") % GameConfig.departments_for_stage(GameConfig.MAIL_UNLOCK_STAGE)
	if room == GameConfig.ROOM_INSPECTION and state.station(GameConfig.INSPECTION) == null:
		return TranslationServer.translate("ROOM_LOCKED_INSPECTION")
	return TranslationServer.translate("LABEL_ROOM_LOCKED")


static func visible_entries(state: GameState, spot: String) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	for entry in UpgradeCatalog.entries_for_spot(state, spot):
		if spot == "runners" and entry.kind == UpgradeCatalog.RUNNER_LEVEL:
			continue
		result.append(entry)
	return result


static func room_boosts(game: Game, spot: String) -> Array[String]:
	var room := ""
	if spot == GameConfig.ROOM_PLAYER:
		room = GameConfig.ROOM_PLAYER
	elif spot.begins_with(UpgradeCatalog.ROOM_PREFIX):
		room = spot.trim_prefix(UpgradeCatalog.ROOM_PREFIX)
	var result: Array[String] = []
	for boost_id in GameConfig.room_boosts(room):
		if game.boosts.is_available(boost_id) or game.state.is_boost_active(boost_id) or not bool(GameConfig.boost(boost_id).get("requires_mail", false)):
			result.append(boost_id)
	return result


func build(container: VBoxContainer) -> void:
	var state := game.state
	container.add_child(_intro())
	var room := room_id()
	if not is_room_open(state, room):
		container.add_child(UiKit.banner(Icons.LOCK, tr("ROOM_LOCKED_TITLE"), locked_text(state, room), "warning"))
		return
	var before := container.get_child_count()
	_add_status(container)
	_add_extras(container)
	var entries := visible_entries(state, argument)
	if entries.any(func(entry: UpgradeEntry) -> bool: return not entry.single):
		container.add_child(UpgradeEntryCard.amount_selector(self))
	_add_entries(container, entries)
	if GameConfig.BOARD_SPOTS.has(argument):
		BoardSection.build(self, container, argument)
	_add_boosts(container)
	if container.get_child_count() == before:
		container.add_child(UiKit.label(tr("SPOT_EMPTY"), "BodyMedium", true))


func _intro() -> Control:
	var card := UiKit.card("CardPrimary")
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(UpgradeTexts.spot_icon(argument), AppTheme.accent("primary")))
	var column := UiKit.vbox(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var room := room_id()
	if not room.is_empty() and not argument.begins_with(UpgradeCatalog.ROOM_PREFIX) and not argument.begins_with(UpgradeCatalog.DEPT_PREFIX) and room != GameConfig.ROOM_PLAYER:
		var place := UiKit.label(UpgradeTexts.room_title(room), "LabelSmall", true)
		place.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
		column.add_child(place)
	var description := UiKit.label(UpgradeTexts.spot_description(argument), "BodyMedium", true)
	description.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	column.add_child(description)
	row.add_child(column)
	card.add_child(row)
	return card


func _add_status(container: VBoxContainer) -> void:
	if SpotStatus.lines(game.state, argument).is_empty():
		return
	var card := UiKit.card()
	var info := UiKit.label("", "BodySmall", true)
	card.add_child(info)
	container.add_child(card)
	track(func() -> void: info.text = "\n".join(SpotStatus.lines(game.state, argument)))


func _add_extras(container: VBoxContainer) -> void:
	var state := game.state
	if argument.begins_with(UpgradeCatalog.DEPT_PREFIX):
		DepartmentSection.build(self, container, argument.trim_prefix(UpgradeCatalog.DEPT_PREFIX))
		return
	if argument.begins_with(UpgradeCatalog.STATION_PREFIX):
		var key := argument.trim_prefix(UpgradeCatalog.STATION_PREFIX)
		if state.station(key) != null:
			container.add_child(StationCard.build(self, key))
		return
	if argument == "complaint_desk":
		var read := UiKit.button(tr("ACTION_READ_COMPLAINTS"))
		read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		read.pressed.connect(func() -> void: navigate.emit("complaints", ""))
		container.add_child(read)


func _add_entries(container: VBoxContainer, entries: Array[UpgradeEntry]) -> void:
	var spots := UpgradeCatalog.spots_of(entries)
	var grouped := spots.size() > 1
	for spot in spots:
		if grouped:
			container.add_child(_group_header(spot))
			_add_group_status(container, spot)
		for entry in entries:
			if entry.spot == spot:
				container.add_child(UpgradeEntryCard.build(self, entry.id))


func _add_group_status(container: VBoxContainer, spot: String) -> void:
	if spot == argument or SpotStatus.lines(game.state, spot).is_empty():
		return
	var info := UiKit.label("", "BodySmall", true)
	container.add_child(info)
	track(func() -> void: info.text = "\n".join(SpotStatus.lines(game.state, spot)))


func _group_header(spot: String) -> Control:
	var row := UiKit.hbox(AppTheme.SPACING_SM)
	row.add_child(UiKit.icon(UpgradeTexts.spot_icon(spot), AppTheme.accent("primary")))
	var heading := UiKit.label(UpgradeTexts.spot_title(spot), "TitleMedium", true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	if spot != argument:
		var open := UiKit.icon_button(Icons.CHEVRON)
		open.tooltip_text = tr("ACTION_OPEN_SPOT")
		open.pressed.connect(func() -> void: navigate.emit("spot", spot))
		row.add_child(open)
	return row


func _add_boosts(container: VBoxContainer) -> void:
	var boosts := room_boosts(game, argument)
	if boosts.is_empty():
		return
	container.add_child(UiKit.label(tr("SECTION_ROOM_BOOSTS"), "TitleMedium"))
	for boost_id in boosts:
		container.add_child(BoostCard.build(self, boost_id))
