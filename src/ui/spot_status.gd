class_name SpotStatus
extends RefCounted


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func lines(state: GameState, spot: String) -> Array[String]:
	var result: Array[String] = []
	var target := GameConfig.spot_target(spot)
	match GameConfig.spot_kind(spot):
		"shredder":
			result.append(dept_shredder(state, target))
			return result
		"tube":
			result.append(tube_station(state, target))
			return result
	match spot:
		"player":
			result.append(t("FMT_STATUS_PLAYER") % [Formulas.carry_capacity(state), UiKit.decimal(Formulas.player_speed(state) / GameConfig.PLAYER_SPEED, 2)])
		"entrance":
			result.append(t("FMT_STATUS_STAGE") % [state.building_stage + 1, GameConfig.BUILDING_STAGES.size(), state.unlocked_count(), int(state.stage_config().max_departments)])
			result.append(population(state))
		"waiting":
			result.append(t("FMT_STATUS_WAITING") % [state.lobby_capacity(), state.standing_citizens(), state.standing_capacity(), state.walkouts])
		"seating":
			result.append(t("FMT_STATUS_SEATING") % [mini(state.seated_citizens(), state.seat_capacity()), state.seat_capacity()])
		"tickets":
			result.append(tickets(state))
		"ticket_display":
			result.append(ticket_display(state))
		"complaint_box":
			result.append(t("FMT_STATUS_COMPLAINT_BOX") % [state.complaints, Formulas.complaint_cap(state)])
		"complaint_desk":
			result.append(t("FMT_STATUS_COMPLAINT_DESK") % [UiKit.percent(Formulas.complaint_fend_chance(state.upgrade_level("complaint_clerk"))), state.complaints_fended])
		"interns":
			result.append(interns(state))
		"shredder":
			result.append(t("FMT_STATUS_SHREDDER") % [state.rejects_waiting(), state.shredder_rooms().size()])
		"collectors":
			result.append(t("FMT_COLLECTOR_INFO") % [Formulas.collector_capacity(state), state.rejects_waiting()])
		"coffee_interns":
			result.append(t("FMT_COFFEE_INTERN_INFO") % state.coffees_served)
		"runners":
			result.append(runners(state))
		"tube_hub":
			result.append(tube_hub(state))
		"climate", "works_council":
			result.append(t("FMT_STATUS_DISPUTES") % [state.disputes.size(), state.disputes_solved])
		"toilets":
			result.append(t("FMT_STATUS_TOILETS") % state.loo_slots())
		"phone", "phone_clerks":
			result.append(t("FMT_HR_INFO") % [state.sick_count(), state.reported_sick_count(), state.ringing_count()])
		"guards":
			result.append(t("FMT_GUARD_INFO") % [roundi(Formulas.guard_block_chance(state) * 100.0), state.visitors_stopped])
		"mail_shelf", "mailbox":
			result.append(mail(state))
	return result


static func tickets(state: GameState) -> String:
	if not state.tickets_unlocked():
		return t("FMT_TICKETS_LOCKED") % (GameConfig.TICKET_UNLOCK_STAGE + 1)
	return t("FMT_STATUS_TICKETS") % [Formulas.ticket_machines(state), UiKit.decimal(Formulas.ticket_draw_time(state)), state.ticket_line.size(), state.ticket_line_capacity()]


static func ticket_display(state: GameState) -> String:
	if not state.tickets_unlocked():
		return t("FMT_TICKETS_LOCKED") % (GameConfig.TICKET_UNLOCK_STAGE + 1)
	return t("FMT_STATUS_TICKET_DISPLAY") % [Formulas.ticket_displays(state), UiKit.decimal(Formulas.ticket_call_time(state)), state.ticket_waiting.size(), state.last_called_ticket]


static func interns(state: GameState) -> String:
	if not state.has_upgrade("shredder_service"):
		return t("LABEL_NEEDS_SHREDDER_SERVICE")
	return t("FMT_HELPER_INFO") % Formulas.intern_capacity(state)


static func runners(state: GameState) -> String:
	if state.all_piped():
		return t("LABEL_TUBES_ACTIVE")
	return t("FMT_RUNNER_INFO") % [Formulas.runner_capacity(state), UiKit.decimal(Formulas.transport_throughput(state) * 60.0)]


static func tube_hub(state: GameState) -> String:
	if not state.has_upgrade("pneumatic_tubes"):
		return t("STATUS_TUBES_LOCKED")
	var connected := 0
	var total := 0
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		if Progression.room_available(state, room_id):
			total += 1
			if state.has_tube_station(room_id):
				connected += 1
	return t("FMT_STATUS_TUBE_HUB") % [Formulas.tube_capacity(state), state.tube_parcels.size(), connected, total]


static func tube_station(state: GameState, room_id: String) -> String:
	if not state.has_upgrade("pneumatic_tubes"):
		return t("STATUS_TUBES_LOCKED")
	return t("STATUS_TUBE_CONNECTED") if state.has_tube_station(room_id) else t("STATUS_TUBE_MISSING")


static func dept_shredder(state: GameState, dept_id: String) -> String:
	if not state.has_upgrade("shredder", dept_id):
		return t("STATUS_NO_SHREDDER")
	return t("FMT_STATUS_DEPT_SHREDDER") % UiKit.decimal(Formulas.shredder_interval(state, dept_id))


static func mail(state: GameState) -> String:
	var room := state.mailroom()
	if room == null:
		return t("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1)
	return t("FMT_MAIL_STORAGE_INFO") % [room.inbox.size(), room.storage_capacity(), GameConfig.MAIL_STORAGE_PER_LEVEL, Formulas.mail_batch(state), UiKit.duration(state.mail_timer), state.mail_floor.size(), state.mail_returned, UiKit.percent(Formulas.mail_reward_factor(state))]


static func population(state: GameState) -> String:
	return t("FMT_POPULATION") % [UiKit.number(Formulas.population(state)), t("SETTLEMENT_" + Formulas.settlement(state).to_upper())]
