class_name RoomSheet
extends Sheet


func title() -> String:
	return UpgradeCards.room_title(argument)


func build(container: VBoxContainer) -> void:
	container.add_child(UiKit.label(UpgradeCards.room_description(argument), "BodySmall", true))
	if argument == GameConfig.ROOM_MAIL and game.state.mailroom() == null:
		container.add_child(UiKit.banner(Icons.LOCK, tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1), "", "neutral"))
	UpgradeCards.add_room(self, container, argument)
