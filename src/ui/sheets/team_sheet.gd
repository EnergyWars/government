class_name TeamSheet
extends Sheet


func title() -> String:
	return tr("SHEET_TEAM")


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("TEAM_INTRO"), "BodySmall", true))
	for room: Dictionary in GameConfig.ROOMS:
		var room_id: String = room.id
		var staff := GameConfig.room_items(room_id, "staff")
		var stations := UpgradeCards.available_stations(game.state, room_id)
		if staff.is_empty() and stations.is_empty():
			continue
		container.add_child(UiKit.label(UpgradeCards.room_title(room_id), "TitleMedium"))
		for staff_id in staff:
			container.add_child(UpgradeCards.staff_card(self, staff_id))
		for key in stations:
			container.add_child(StationCard.build(self, key))
