class_name ComplaintsSheet
extends Sheet


func title() -> String:
	return tr("SHEET_COMPLAINTS")


func build(container: VBoxContainer) -> void:
	var state := game.state
	container.add_child(UiKit.label(tr("COMPLAINTS_INTRO"), "BodySmall", true))
	if state.complaints <= 0:
		container.add_child(UiKit.label(tr("COMPLAINTS_EMPTY"), "BodyMedium", true))
		return
	container.add_child(UiKit.label(tr("FMT_COMPLAINTS_PILE") % [state.complaints, Formulas.complaint_cap(state)], "TitleSmall"))
	for serial in state.pile_complaint_serials(GameConfig.COMPLAINT_READ_MAX):
		container.add_child(_complaint_card(serial))
	var hidden := state.complaints - GameConfig.COMPLAINT_READ_MAX
	if hidden > 0:
		container.add_child(UiKit.label(tr("FMT_COMPLAINTS_MORE") % hidden, "BodySmall", true))


func _complaint_card(serial: int) -> Control:
	var card := UiKit.card("CardOutlined")
	card.add_child(UiKit.label(Flavor.complaint(serial), "BodyMedium", true))
	return card
