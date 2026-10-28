class_name SpotStatus
extends RefCounted


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func lines(state: GameState, spot: String) -> Array[String]:
	var result: Array[String] = []
	var target := GameConfig.spot_target(spot)
	match GameConfig.spot_kind(spot):
		"tube":
			result.append(tube_station(state, target))
			return result
		"lead":
			result.append_array(team_lead(state, target))
			return result
		"station":
			var station := state.station(target)
			if station != null and station.is_output_jammed():
				result.append(t("STATUS_OUTPUTS_JAMMED"))
			return result
		"trays":
			result.append_array(trays(state, target))
			return result
	match spot:
		"player":
			result.append(t("FMT_STATUS_PLAYER") % [Formulas.carry_capacity(state), UiKit.decimal(Formulas.player_speed(state) / GameConfig.PLAYER_SPEED, 2)])
		"entrance":
			result.append(t("FMT_STATUS_STAGE") % [t("STAGE_" + str(state.stage_config().id).to_upper()), state.unlocked_count(), GameConfig.DEPARTMENTS.size()])
			result.append(population(state))
		"seating":
			result.append(waiting_room(state, GameConfig.HALL_INTAKE))
			result.append(t("FMT_STATUS_WALKOUTS") % state.walkouts)
		"pickup_seating":
			result.append(waiting_room(state, GameConfig.HALL_PICKUP))
		"tickets":
			result.append(tickets(state))
		"complaint_box":
			result.append(t("FMT_STATUS_COMPLAINT_BOX") % [state.complaints, Formulas.complaint_cap(state)])
		"complaint_desk":
			result.append_array(complaint_desk(state))
		"security":
			result.append(security(state))
		"shredder":
			result.append(t("FMT_STATUS_SHREDDER") % [state.rejects_waiting(), state.runners_in(Runner.REJECT)])
		"coffee_interns":
			result.append(t("FMT_COFFEE_INTERN_INFO") % state.coffees_served)
		"canteen":
			result.append(t("FMT_STATUS_CANTEEN") % [state.lunches, UiKit.decimal(Formulas.upgrade_value(state, "canteen_speed")), UiKit.decimal(Formulas.upgrade_value(state, "canteen_menu"), 2)])
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
		"mail_shelf", "mailbox":
			result.append(mail(state))
	return result


static func trays(state: GameState, key: String) -> Array[String]:
	var result: Array[String] = []
	var station := state.station(key)
	if station == null:
		return result
	if not station.is_entry():
		result.append(t("FMT_INBOX") % [station.inbox.size(), station.inbox_capacity(state.lobby_capacity())])
	if not station.is_final():
		result.append(t("FMT_OUTBOX") % [station.outbox.size(), station.outbox_capacity()])
	if station.has_reject_pile():
		result.append(t("FMT_STATUS_REJECT_PILE") % [station.rejects, station.reject_capacity()])
	if station.is_output_jammed():
		result.append(t("STATUS_OUTPUTS_JAMMED"))
	return result


static func tickets(state: GameState) -> String:
	return t("FMT_STATUS_TICKETS") % [Formulas.ticket_machines(state), UiKit.decimal(Formulas.ticket_draw_rate(state) * 60.0, 0), state.ticket_line.size(), Formulas.ticket_line_capacity(state)]


static func waiting_room(state: GameState, room: String) -> String:
	return t("FMT_STATUS_SEATING") % [state.seated_citizens(room), state.seat_capacity(room), state.standing_citizens(room), state.standing_capacity(room)]


static func complaint_desk(state: GameState) -> Array[String]:
	var steadfast := Formulas.intern_steadfast(state)
	var result: Array[String] = [t("FMT_STATUS_COMPLAINT_DESK") % [state.interns_at_desk(), state.interns.size(), steadfast, state.complaints_absorbed]]
	for unit in state.interns:
		var mood := t("INTERN_MOOD_" + str(ComplaintIntern.Mood.keys()[unit.mood]))
		result.append(t("FMT_INTERN_STATUS") % [t("FMT_INTERN_NAME") % (unit.slot + 1), mood, unit.handled, steadfast])
	return result


static func security(state: GameState) -> String:
	if not state.has_upgrade("complaint_security"):
		return t("STATUS_NO_SECURITY")
	return t("FMT_SECURITY_INFO") % [roundi(Formulas.security_chance(state) * 100.0), state.visitors_stopped]


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


static func team_lead(state: GameState, room_id: String) -> Array[String]:
	var result: Array[String] = []
	if not Formulas.has_lead(state, room_id):
		result.append(t("STATUS_NO_LEAD"))
		return result
	result.append(t("FMT_STATUS_LEAD") % [UiKit.percent(1.0 - Formulas.lead_value(state, "lead_breaks", room_id)), UiKit.percent(1.0 - Formulas.lead_value(state, "lead_health", room_id)), UiKit.percent(1.0 - Formulas.lead_value(state, "lead_focus", room_id))])
	result.append(t("FMT_STATUS_PATROL") % [UiKit.decimal(Formulas.lead_value(state, "lead_patrol", room_id), 2), UiKit.duration(GameConfig.LEAD_PATROL_SECONDS), UiKit.duration(Formulas.patrol_cooldown(state, room_id))])
	return result


static func mail(state: GameState) -> String:
	var room := state.mailroom()
	if room == null:
		return t("FMT_MAIL_LOCKED") % GameConfig.departments_for_stage(GameConfig.MAIL_UNLOCK_STAGE)
	return t("FMT_MAIL_STORAGE_INFO") % [room.inbox.size(), room.storage_capacity(), GameConfig.MAIL_STORAGE_PER_LEVEL, Formulas.mail_batch(state), UiKit.duration(state.mail_timer), state.mail_floor.size(), state.mail_returned, UiKit.percent(Formulas.mail_reward_factor(state))]


static func population(state: GameState) -> String:
	return t("FMT_POPULATION") % [UiKit.number(Formulas.population(state)), t("SETTLEMENT_" + Formulas.settlement(state).to_upper())]
