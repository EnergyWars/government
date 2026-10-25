class_name UpgradeEntryCard
extends RefCounted

const AMOUNTS: Array[int] = [1, 10, 0]

static var amount_index := 0


static func amount() -> int:
	return AMOUNTS[clampi(amount_index, 0, AMOUNTS.size() - 1)]


static func amount_selector(sheet: Sheet) -> Control:
	var options: Array[String] = [sheet.tr("AMOUNT_ONE"), sheet.tr("AMOUNT_TEN"), sheet.tr("AMOUNT_MAX")]
	return UiKit.segmented(options, amount_index, func(index: int) -> void:
		amount_index = index
		sheet.refresh()
	)


static func purchase_count(state: GameState, entry: UpgradeEntry, chosen: int) -> int:
	if entry.single:
		return 1
	if chosen > 0:
		return maxi(1, entry.amount_for(chosen))
	return maxi(1, entry.affordable(state.money))


static func can_buy(state: GameState, entry: UpgradeEntry, count: int) -> bool:
	return entry.is_buyable() and count > 0 and count <= entry.remaining() and state.can_afford(entry.bulk_cost(count))


static func buy(game: Game, entry_id: String) -> bool:
	var entry := UpgradeCatalog.find(game.state, entry_id)
	if entry == null:
		return false
	var count := purchase_count(game.state, entry, amount())
	return can_buy(game.state, entry, count) and game.actions.buy_entry(entry_id, count)


static func buy_button(sheet: Sheet, entry_id: String) -> Button:
	var game := sheet.game
	var button := StationCard.action_button(sheet, func() -> bool: return buy(game, entry_id))
	sheet.track(func() -> void:
		var entry := UpgradeCatalog.find(game.state, entry_id)
		button.visible = entry != null
		if entry == null:
			return
		var count := purchase_count(game.state, entry, amount())
		button.text = UpgradeTexts.button_text(game.state, entry, count)
		button.disabled = not can_buy(game.state, entry, count)
	)
	return button


static func build(sheet: Sheet, entry_id: String, show_place: bool = false) -> Control:
	var game := sheet.game
	var card := UiKit.card()
	var first := UpgradeCatalog.find(game.state, entry_id)
	if first == null:
		card.visible = false
		return card
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(UpgradeTexts.icon(first), AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_child(UiKit.label(UpgradeTexts.title(first), "TitleSmall", true))
	texts.add_child(UiKit.label(UpgradeTexts.description(first), "BodySmall", true))
	if show_place:
		texts.add_child(UiKit.label(UpgradeTexts.place(first), "LabelSmall", true))
	row.add_child(texts)
	var level := UiKit.pill("", "primary")
	row.add_child(level)
	if show_place:
		var locate := UiKit.icon_button(Icons.LOCATE)
		locate.tooltip_text = sheet.tr("ACTION_LOCATE")
		locate.pressed.connect(func() -> void: sheet.navigate.emit("locate", first.spot))
		row.add_child(locate)
	column.add_child(row)
	var effect := UiKit.label("", "BodySmall", true)
	column.add_child(effect)
	var bar := UiKit.progress(0.0, "success")
	column.add_child(bar)
	column.add_child(buy_button(sheet, entry_id))
	card.add_child(column)
	var level_label: Label = level.get_child(0)
	sheet.track(func() -> void:
		var entry := UpgradeCatalog.find(game.state, entry_id)
		card.visible = entry != null
		if entry == null:
			return
		level_label.text = UpgradeTexts.level_text(entry)
		effect.text = UpgradeTexts.effect(game.state, entry)
		effect.visible = not effect.text.is_empty()
		bar.visible = not entry.single
		bar.value = float(entry.level) / maxf(1.0, float(entry.max_level))
	)
	return card
