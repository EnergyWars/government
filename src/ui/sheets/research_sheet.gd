class_name ResearchSheet
extends Sheet


func title() -> String:
	return tr("SHEET_RESEARCH")


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(tr("RESEARCH_INTRO"), "BodySmall", true))
	for room_id in research_rooms():
		container.add_child(UiKit.label(UpgradeCards.room_title(room_id), "TitleMedium"))
		container.add_child(UiKit.label(UpgradeCards.room_description(room_id), "BodySmall", true))
		for research_id in GameConfig.room_items(room_id, "research"):
			container.add_child(UpgradeCards.research_card(self, research_id))


static func research_rooms() -> Array[String]:
	var rooms: Array[String] = []
	for room: Dictionary in GameConfig.ROOMS:
		if not GameConfig.room_items(room.id, "research").is_empty():
			rooms.append(room.id)
	return rooms
