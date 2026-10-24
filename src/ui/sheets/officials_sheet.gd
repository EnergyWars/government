class_name OfficialsSheet
extends Sheet


func station() -> Station:
	return game.state.station(argument)


func title() -> String:
	if station() == null:
		return tr("SHEET_OFFICIALS")
	return tr("FMT_OFFICIALS_TITLE") % StationCard.label_for(argument)


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("OFFICIALS_INTRO"), "BodySmall", true))
	var target := station()
	if target == null or target.machine:
		container.add_child(UiKit.label(tr("OFFICIALS_MACHINE"), "BodyMedium", true))
		return
	var desks := staffed_desks(target)
	if desks.is_empty():
		container.add_child(UiKit.label(tr("OFFICIALS_EMPTY"), "BodyMedium", true))
		return
	for desk in desks:
		container.add_child(_official_card(target, desk))


static func staffed_desks(target: Station) -> Array[int]:
	var result: Array[int] = []
	for desk in target.moods.size():
		if target.is_staffed(desk):
			result.append(desk)
	return result


static func official_name(target: Station, desk: int) -> String:
	if target.is_specialist_desk(desk):
		return TranslationServer.translate("FMT_SPECIALIST_NAME") % (desk - target.desks + 1)
	return TranslationServer.translate("FMT_OFFICIAL_NAME") % (desk + 1)


static func state_text(mood: DeskMood) -> String:
	return TranslationServer.translate("OFFICIAL_STATE_" + mood.state.to_upper())


static func effect_text(track: String, level: int) -> String:
	return TranslationServer.translate("FMT_TRAINING_EFFECT_" + track.to_upper()) % UiKit.percent(Formulas.training_effect(track, level))


func _official_card(target: Station, desk: int) -> Control:
	var mood := target.moods[desk]
	var card := UiKit.card()
	var column := UiKit.vbox(AppTheme.SPACING_SM)
	var head := UiKit.hbox(AppTheme.SPACING_MD)
	var icon_code: String = Icons.STAFF.specialists if target.is_specialist_desk(desk) else Icons.PERSON
	head.add_child(UiKit.icon_disc(icon_code, AppTheme.accent("primary")))
	var names := UiKit.vbox(2)
	names.add_child(UiKit.label(official_name(target, desk), "TitleSmall", true))
	var status := UiKit.label("", "BodySmall", true)
	names.add_child(status)
	head.add_child(names)
	column.add_child(head)
	var stats := UiKit.label("", "BodySmall", true)
	column.add_child(stats)
	var rows: Array[Dictionary] = []
	for track_id in GameConfig.OFFICIAL_TRAINING_ORDER:
		column.add_child(HSeparator.new())
		rows.append(_training_row(column, target, desk, track_id))
	card.add_child(column)
	track(func() -> void:
		var state := game.state
		status.text = state_text(mood)
		stats.text = tr("FMT_OFFICIAL_STATS") % [UiKit.decimal(mood.output.per_minute(state.play_time, state.production.started)), mood.output.total, mood.sick_count, mood.doze_count]
		for row in rows:
			var track_id: String = row.track
			var level := mood.training_level(track_id)
			(row.name as Label).text = tr("FMT_TRAINING_LEVEL") % [tr("TRAINING_" + track_id.to_upper()), level, GameConfig.MAX_OFFICIAL_TRAINING]
			(row.effect as Label).text = effect_text(track_id, level)
			StationCard.update_button(row.button, "ACTION_TRAIN", Formulas.training_cost(target, track_id, level), game.actions.can_train_official(target.key, desk, track_id), not mood.can_train(track_id), "LABEL_MAX_LEVEL")
	)
	return card


func _training_row(column: VBoxContainer, target: Station, desk: int, track_id: String) -> Dictionary:
	var row := UiKit.hbox(AppTheme.SPACING_MD)
	row.add_child(UiKit.icon(Icons.TRAININGS[track_id], AppTheme.accent("primary")))
	var texts := UiKit.vbox(2)
	var name_label := UiKit.label("", "TitleSmall", true)
	texts.add_child(name_label)
	texts.add_child(UiKit.label(tr("TRAINING_DESC_" + track_id.to_upper()), "BodySmall", true))
	var effect := UiKit.label("", "BodySmall", true)
	texts.add_child(effect)
	row.add_child(texts)
	var button := StationCard.action_button(self, game.actions.train_official.bind(target.key, desk, track_id))
	button.size_flags_horizontal = Control.SIZE_FILL
	button.custom_minimum_size.x = 132
	row.add_child(button)
	column.add_child(row)
	return {"track": track_id, "name": name_label, "effect": effect, "button": button}
