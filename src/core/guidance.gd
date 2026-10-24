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


static func next_task(state: GameState) -> Dictionary:
	var layout := WorldLayout.get_default()
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
			if station.needs_manual_work():
				options.append({"action": WORK, "key": key, "point": layout.work_point(key)})
			if room and not station.outbox.is_empty() and not _automated(state, station):
				options.append({"action": PICKUP, "key": key, "point": layout.output_point(key)})
			if station.rejects > 0 and state.collectors.is_empty() and player.rejects == 0 and player.complaints == 0 and room:
				options.append({"action": REJECT, "key": key, "point": layout.reject_point(key)})
	if state.ringing_count() > 0 or state.reported_sick_count() > 0:
		options.append({"action": CALL, "key": "", "point": layout.phone_point()})
	if state.has_research("shredder_service"):
		for unit in state.all_interns():
			if unit.is_away():
				options.append({"action": COMFORT, "key": "", "point": unit.position})
	for dispute in state.disputes:
		options.append({"action": DISPUTE, "key": dispute.dept_id, "point": layout.dispute_point(dispute.dept_id)})
	if state.kranz:
		options.append({"action": KRANZ, "key": "", "point": layout.kranz_point()})
	if player.complaints > 0 or player.rejects > 0:
		options.append({"action": SHRED, "key": "", "point": layout.shredder_point()})
	elif state.complaints > 0 and player.items.size() < Formulas.carry_capacity(state):
		options.append({"action": COMPLAINT, "key": "", "point": layout.complaint_desk_point()})
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
	if state.has_research("pneumatic_tubes"):
		return true
	return state.runners.size() * Formulas.runner_capacity(state) >= station.outbox.size() and not state.runners.is_empty()
