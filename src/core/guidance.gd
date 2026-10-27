class_name Guidance
extends RefCounted

const DROP := "drop"
const PICKUP := "pickup"
const WORK := "work"
const PAD := "pad"
const WAKE := "wake"
const COMPLAINT := "complaint"
const SHRED := "shred"
const KRANZ := "kranz"
const CALL := "call"
const REJECT := "reject"
const COMFORT := "comfort"
const DISPUTE := "dispute"
const COVER := "cover"
const TICKET := "ticket"
const RUCKUS := "ruckus"
const MAIL_FLOOR := "mail_floor"


static func next_task(state: GameState) -> Dictionary:
	var layout := WorldLayout.get_default()
	if state.has_ruckus():
		return {"action": RUCKUS, "key": GameConfig.RECEPTION, "point": layout.ruckus_point(state.ruckus_desk)}
	var player := state.player
	var options: Array[Dictionary] = []
	for item in player.items:
		var key := item.next_key()
		var target := state.station(key)
		if target != null and target.has_inbox_space(state.lobby_capacity()):
			options.append({"action": DROP, "key": key, "point": layout.input_point(key)})
	if options.is_empty():
		var room := player.items.size() < Formulas.carry_capacity(state)
		for key in state.ordered_station_keys():
			var station := state.station(key)
			for desk in station.moods.size():
				var mood := station.moods[desk]
				if station.is_staffed(desk) and mood.needs_help() and not (state.kranz and mood.state == DeskMood.CHAT):
					var spot := layout.slot_point(mood.slot) if mood.is_away() else layout.desk_position(key, desk)
					options.append({"action": WAKE, "key": key, "point": spot})
				if mood.is_sick() and station.can_cover(desk):
					options.append({"action": COVER, "key": key, "point": layout.desk_position(key, desk)})
			var work_desk := _work_desk(station)
			if work_desk >= 0:
				options.append({"action": WORK, "key": key, "point": layout.desk_work_point(key, work_desk)})
			if room and not station.outbox.is_empty() and not _automated(state, station):
				options.append({"action": PICKUP, "key": key, "point": layout.output_point(key)})
			if station.rejects > 0 and state.collectors.is_empty() and player.rejects == 0 and player.complaints == 0 and room:
				options.append({"action": REJECT, "key": key, "point": layout.reject_point(key)})
	if state.ringing_count() > 0 or state.reported_sick_count() > 0:
		options.append({"action": CALL, "key": "", "point": layout.phone_point()})
	for unit in state.interns:
		if unit.is_away():
			options.append({"action": COMFORT, "key": "", "point": unit.position})
	var mailroom := state.mailroom()
	if not state.mail_floor.is_empty() and mailroom != null and mailroom.has_inbox_space(state.lobby_capacity()):
		options.append({"action": MAIL_FLOOR, "key": GameConfig.MAILROOM, "point": layout.mail_floor_point()})
	for dispute in state.disputes:
		options.append({"action": DISPUTE, "key": dispute.dept_id, "point": layout.dispute_point(dispute.dept_id)})
	if state.kranz:
		options.append({"action": KRANZ, "key": "", "point": layout.kranz_point()})
	var busiest := _busiest_line(state)
	if busiest >= 0:
		options.append({"action": TICKET, "key": "", "point": layout.ticket_machine_point(busiest)})
	if player.complaints > 0 or player.rejects > 0:
		options.append({"action": SHRED, "key": "", "point": layout.nearest_shredder(player.position, state.shredder_rooms())})
	elif state.complaints > 0 and player.items.size() < Formulas.carry_capacity(state):
		options.append({"action": COMPLAINT, "key": "", "point": layout.complaint_box_point()})
	var locked := Progression.next_locked_department(state)
	if options.is_empty() and not locked.is_empty() and Progression.unlock_block_reason(state, locked).is_empty():
		options.append({"action": PAD, "key": locked, "point": layout.pad_point(locked)})
	var best := {}
	var best_distance := INF
	for option in options:
		var distance := player.position.distance_to(option.point)
		if distance < best_distance:
			best_distance = distance
			best = option
	return best


static func _automated(state: GameState, station: Station) -> bool:
	var waiting := station.outbox.filter(func(case_file: CaseFile) -> bool: return not state.is_piped(case_file))
	if waiting.is_empty() and not station.outbox.is_empty():
		return true
	var carried := 0
	for runner in state.runners:
		if waiting.is_empty() or waiting.any(func(case_file: CaseFile) -> bool: return runner.serves(case_file, station.key)):
			carried += Formulas.runner_load(state, runner)
	return carried > 0 and carried >= waiting.size()


static func _work_desk(station: Station) -> int:
	if station.needs_manual_work():
		return station.staff
	if station.needs_help():
		for desk in mini(station.staff, station.desks):
			if station.is_working(desk):
				return desk
	return -1


static func _busiest_line(state: GameState) -> int:
	var best := -1
	var best_length := GameConfig.TICKET_RUSH - 1
	for machine in Formulas.ticket_machines(state):
		var length := state.line_length(machine)
		if length > best_length:
			best = machine
			best_length = length
	return best
