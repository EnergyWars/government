class_name BoostCard
extends RefCounted


static func build(sheet: Sheet, boost_id: String) -> Control:
	var game := sheet.game
	var card := UiKit.card("CardRow")
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon_disc(Icons.BOOSTS[boost_id], AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		ad.text = ad_text(state, boost_id)
		ad.disabled = not game.boosts.can_use(boost_id, Boosts.AD)
	)
	return card


static func ad_text(state: GameState, boost_id: String) -> String:
	var cooldown := state.boost_cooldown(boost_id)
	if cooldown > 0.0:
		return TranslationServer.translate("FMT_AD_COOLDOWN") % UiKit.duration(cooldown)
	return TranslationServer.translate("ACTION_WATCH_AD")
