class_name UpgradesSheet
extends Sheet

const REFRESH_MSEC := 250
const MODES: Array[String] = ["rooms", "topics", "buyable", "recommended", "expansion"]
const LIST_LIMIT := 40

static var mode_index := 0
static var expanded: Dictionary[String, bool] = {}

var _details: Dictionary[String, Label] = {}


func refresh_interval() -> int:
	return REFRESH_MSEC


func title() -> String:
	return tr("SHEET_UPGRADES")


static func mode() -> String:
	return MODES[clampi(mode_index, 0, MODES.size() - 1)]


static func group_key(entry: UpgradeEntry, by_mode: String) -> String:
	return entry.topic if by_mode == "topics" else entry.room


static func group_order(by_mode: String) -> Array[String]:
	if by_mode == "topics":
		return GameConfig.TOPICS
	return UpgradeCatalog.rooms()


static func buyable(entries: Array[UpgradeEntry]) -> Array[UpgradeEntry]:
	var result: Array[UpgradeEntry] = []
	for entry in entries:
		if entry.is_buyable():
			result.append(entry)
	result.sort_custom(func(a: UpgradeEntry, b: UpgradeEntry) -> bool: return a.cost < b.cost)
	return result


static func group_detail(entries: Array[UpgradeEntry]) -> String:
	var ready := 0
	var levels := 0
	var limit := 0
	for entry in entries:
		if entry.is_buyable():
			ready += 1
		levels += entry.level
		limit += entry.max_level
	return TranslationServer.translate("FMT_GROUP_DETAIL") % [ready, levels, limit]


static func grouped(entries: Array[UpgradeEntry], by_mode: String) -> Dictionary[String, Array]:
	var result: Dictionary[String, Array] = {}
	for entry in entries:
		var key := group_key(entry, by_mode)
		if not result.has(key):
			result[key] = []
		result[key].append(entry)
	return result


func build(container: VBoxContainer) -> void:
	_details.clear()
	var state := game.state
	container.add_child(_summary())
	var options: Array[String] = []
	for id in MODES:
		options.append(tr("UPGRADE_MODE_" + id.to_upper()))
	container.add_child(UiKit.segmented(options, mode_index, func(index: int) -> void:
		mode_index = index
		rebuild()
	))
	container.add_child(UiKit.label(tr("UPGRADE_MODE_HINT_" + mode().to_upper()), "BodySmall", true))
	if mode() != "expansion":
		container.add_child(UpgradeEntryCard.amount_selector(self))
	var entries := UpgradeCatalog.entries(state)
	match mode():
		"buyable":
			_add_list(container, buyable(entries), "UPGRADES_NONE_BUYABLE")
		"recommended":
			var recommended: Array[UpgradeEntry] = []
			for entry_id in ThroughputReport.recommended_entries(state):
				var entry := UpgradeCatalog.find(state, entry_id)
				if entry != null and not entry.is_maxed():
					recommended.append(entry)
			_add_list(container, recommended, "UPGRADES_NONE_RECOMMENDED")
		"expansion":
			_add_list(container, UpgradeCatalog.expansion_entries(state), "UPGRADES_NONE_EXPANSION")
		_:
			_add_groups(container, entries)
	track(_update_details)


func _summary() -> Control:
	var card := UiKit.card("CardPrimary")
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.UPGRADE, AppTheme.accent("primary")))
	var text := UiKit.label("", "BodyMedium", true)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	row.add_child(text)
	card.add_child(row)
	_details["_summary"] = text
	return card


func _add_list(container: VBoxContainer, entries: Array[UpgradeEntry], empty_key: String) -> void:
	if entries.is_empty():
		container.add_child(UiKit.label(tr(empty_key), "BodyMedium", true))
		return
	for index in mini(entries.size(), LIST_LIMIT):
		container.add_child(UpgradeEntryCard.build(self, entries[index].id, true))
	if entries.size() > LIST_LIMIT:
		container.add_child(UiKit.label(tr("FMT_MORE_ENTRIES") % (entries.size() - LIST_LIMIT), "BodySmall", true))


func _add_groups(container: VBoxContainer, entries: Array[UpgradeEntry]) -> void:
	var by_mode := mode()
	var groups := grouped(entries, by_mode)
	for key in group_order(by_mode):
		if not groups.has(key):
			continue
		var members: Array[UpgradeEntry] = []
		members.assign(groups[key])
		var expand_key := by_mode + ":" + key
		var open: bool = expanded.get(expand_key, false)
		container.add_child(_group_header(expand_key, key, open))
		if not open:
			continue
		if by_mode == "topics":
			for entry in members:
				container.add_child(UpgradeEntryCard.build(self, entry.id, true))
			continue
		for spot in UpgradeCatalog.spots_of(members):
			container.add_child(_spot_header(spot))
			for entry in members:
				if entry.spot == spot:
					container.add_child(UpgradeEntryCard.build(self, entry.id))


func _group_header(expand_key: String, key: String, open: bool) -> Control:
	var topics := mode() == "topics"
	var button := UiKit.button("", "primary", "Tonal")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size.y = 64
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = AppTheme.SPACING_LG
	row.offset_right = -AppTheme.SPACING_LG
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := UiKit.icon(Icons.topic(key) if topics else Icons.room(key), AppTheme.accent("primary"))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var texts := UiKit.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heading := UiKit.label(UpgradeTexts.topic_title(key) if topics else UpgradeTexts.room_title(key), "TitleSmall")
	heading.add_theme_color_override(&"font_color", AppTheme.accent("primary"))
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(heading)
	var detail := UiKit.label("", "BodySmall")
	detail.add_theme_color_override(&"font_color", AppTheme.on_container("primary"))
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(detail)
	row.add_child(texts)
	var chevron := UiKit.icon(Icons.EXPAND_LESS if open else Icons.EXPAND_MORE, AppTheme.accent("primary"))
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chevron)
	button.add_child(row)
	button.pressed.connect(func() -> void:
		expanded[expand_key] = not open
		rebuild()
	)
	_details[key] = detail
	return button


func _spot_header(spot: String) -> Control:
	var row := UiKit.hbox(AppTheme.SPACING_SM)
	row.add_child(UiKit.icon(UpgradeTexts.spot_icon(spot), AppTheme.accent("primary")))
	var heading := UiKit.label(UpgradeTexts.spot_title(spot), "TitleMedium", true)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var locate := UiKit.icon_button(Icons.LOCATE)
	locate.tooltip_text = tr("ACTION_LOCATE")
	locate.pressed.connect(func() -> void: navigate.emit("locate", spot))
	row.add_child(locate)
	var open := UiKit.icon_button(Icons.CHEVRON)
	open.tooltip_text = tr("ACTION_OPEN_SPOT")
	open.pressed.connect(func() -> void: navigate.emit("spot", spot))
	row.add_child(open)
	return row


func _update_details() -> void:
	var state := game.state
	var entries := UpgradeCatalog.entries(state)
	var ready := 0
	for entry in entries:
		if entry.is_buyable():
			ready += 1
	var summary: Label = _details.get("_summary")
	if summary != null:
		summary.text = tr("FMT_UPGRADES_SUMMARY") % [state.upgrade_count(), entries.size(), ready]
	if _details.size() <= 1:
		return
	var groups := grouped(entries, mode())
	for key: String in _details:
		if key == "_summary":
			continue
		var members: Array[UpgradeEntry] = []
		members.assign(groups.get(key, []))
		_details[key].text = group_detail(members)
