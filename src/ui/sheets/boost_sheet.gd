class_name BoostSheet
extends Sheet


func title() -> String:
	return tr("SHEET_BOOSTS")


func build(container: VBoxContainer) -> void:
	var state := game.state
	var seals := UiKit.banner(Icons.SEAL, "", tr("BOOSTS_INTRO"), "tertiary")
	container.add_child(seals)
	var seal_title: Label = seals.get_child(0).get_child(1).get_child(0)
	track(func() -> void: seal_title.text = tr("FMT_SEALS") % state.seals)
	var swamped := UiKit.banner(Icons.SWAMPED, tr("BOOSTS_SWAMPED_TITLE"), tr("BOOSTS_SWAMPED_TEXT"), "warning")
	container.add_child(swamped)
	track(func() -> void: swamped.visible = _swamped_count(state) > 0)
	container.add_child(UiKit.label(tr("SECTION_BOOSTS"), "TitleMedium"))
	for boost_id in GameConfig.BOOST_ORDER:
		if game.boosts.is_available(boost_id) or state.is_boost_active(boost_id) or not bool(GameConfig.boost(boost_id).get("requires_mail", false)):
			container.add_child(BoostCard.build(self, boost_id))
	container.add_child(UiKit.label(tr("SECTION_SEAL_SHOP"), "TitleMedium"))
	container.add_child(UiKit.label(tr("SEAL_SHOP_MOCK"), "BodySmall", true))
	var packs := UiKit.hbox(AppTheme.SPACING_SM)
	for index in GameConfig.SEAL_PACKS.size():
		var button := UiKit.button(tr("FMT_SEAL_PACK") % GameConfig.SEAL_PACKS[index], "primary", "Outlined")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(confirm_pack.bind(index))
		packs.add_child(button)
	container.add_child(packs)


func confirm_pack(index: int) -> AppDialog:
	var dialog := AppDialog.new().configure(Icons.CART, tr("SEAL_SHOP_TITLE"), tr("FMT_SEAL_SHOP_TEXT") % GameConfig.SEAL_PACKS[index], tr("ACTION_TEST_BUY"), tr("ACTION_CANCEL"))
	dialog.confirmed.connect(func() -> void: act(game.boosts.buy_seals.bind(index)))
	get_parent().add_child(dialog)
	return dialog


func _swamped_count(state: GameState) -> int:
	var count := 0
	var lobby := state.lobby_capacity()
	for key in state.ordered_station_keys():
		if state.station(key).is_swamped(lobby):
			count += 1
	return count
