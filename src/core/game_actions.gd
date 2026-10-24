class_name GameActions
extends RefCounted

var state: GameState
var simulation: Simulation


func _init(p_state: GameState, p_simulation: Simulation) -> void:
	state = p_state
	simulation = p_simulation


func can_add_desk(key: String) -> bool:
	var station := state.station(key)
	return station != null and station.desks < state.max_desks() and state.can_afford(Formulas.desk_cost(station))


func add_desk(key: String) -> bool:
	if not can_add_desk(key):
		return false
	var station := state.station(key)
	state.spend(Formulas.desk_cost(station))
	station.add_desk()
	return true


func can_hire(key: String) -> bool:
	var station := state.station(key)
	return station != null and not station.machine and station.staff < station.desks and state.can_afford(Formulas.hire_cost(station))


func hire(key: String) -> bool:
	if not can_hire(key):
		return false
	var station := state.station(key)
	state.spend(Formulas.hire_cost(station))
	station.staff += 1
	state.staff_hired += 1
	return true


func can_upgrade(key: String) -> bool:
	var station := state.station(key)
	return station != null and station.level < GameConfig.MAX_STATION_LEVEL and state.can_afford(Formulas.upgrade_cost(station))


func upgrade(key: String) -> bool:
	if not can_upgrade(key):
		return false
	var station := state.station(key)
	state.spend(Formulas.upgrade_cost(station))
	station.level += 1
	return true


func is_trainable(key: String, desk: int) -> bool:
	var station := state.station(key)
	return station != null and not station.machine and desk >= 0 and desk < station.moods.size() and station.is_staffed(desk)


func can_train_official(key: String, desk: int, track: String) -> bool:
	if not is_trainable(key, desk):
		return false
	var station := state.station(key)
	var mood := station.moods[desk]
	return mood.can_train(track) and state.can_afford(Formulas.training_cost(station, track, mood.training_level(track)))


func train_official(key: String, desk: int, track: String) -> bool:
	if not can_train_official(key, desk, track):
		return false
	var station := state.station(key)
	var mood := station.moods[desk]
	state.spend(Formulas.training_cost(station, track, mood.training_level(track)))
	mood.train(track)
	state.trainings += 1
	return true


func can_hire_specialist(key: String) -> bool:
	var station := state.station(key)
	return station != null and station.supports_specialists() and station.specialists < GameConfig.MAX_SPECIALISTS and state.can_afford(Formulas.specialist_cost(station))


func hire_specialist(key: String) -> bool:
	if not can_hire_specialist(key):
		return false
	var station := state.station(key)
	state.spend(Formulas.specialist_cost(station))
	station.add_specialist()
	state.staff_hired += 1
	return true


func can_hire_supervisor(dept_id: String) -> bool:
	var dept := state.department(dept_id)
	return dept != null and dept.unlocked and dept.supervisors < GameConfig.MAX_SUPERVISORS and state.can_afford(Formulas.supervisor_cost(dept))


func hire_supervisor(dept_id: String) -> bool:
	if not can_hire_supervisor(dept_id):
		return false
	var dept := state.department(dept_id)
	state.spend(Formulas.supervisor_cost(dept))
	dept.supervisors += 1
	state.staff_hired += 1
	return true


func can_hire_runner() -> bool:
	return state.runners.size() < GameConfig.MAX_RUNNERS and state.can_afford(Formulas.runner_cost(state))


func hire_runner() -> bool:
	if not can_hire_runner():
		return false
	state.spend(Formulas.runner_cost(state))
	state.add_runner()
	state.staff_hired += 1
	return true


func can_hire_collector() -> bool:
	return state.collectors.size() < GameConfig.MAX_COLLECTORS and state.can_afford(Formulas.collector_cost(state))


func hire_collector() -> bool:
	if not can_hire_collector():
		return false
	state.spend(Formulas.collector_cost(state))
	state.add_collector()
	state.staff_hired += 1
	return true


func can_hire_coffee_intern() -> bool:
	return state.coffee_interns.size() < GameConfig.MAX_COFFEE_INTERNS and state.can_afford(Formulas.coffee_intern_cost(state))


func hire_coffee_intern() -> bool:
	if not can_hire_coffee_intern():
		return false
	state.spend(Formulas.coffee_intern_cost(state))
	state.add_coffee_intern()
	state.staff_hired += 1
	return true


func can_upgrade_waiting_area() -> bool:
	return state.waiting_level < GameConfig.WAITING_MAX_LEVEL and state.can_afford(Formulas.waiting_area_cost(state))


func upgrade_waiting_area() -> bool:
	if not can_upgrade_waiting_area():
		return false
	state.spend(Formulas.waiting_area_cost(state))
	state.waiting_level += 1
	return true


func can_upgrade_seating_area() -> bool:
	return state.seating_level < GameConfig.SEATING_MAX_LEVEL and state.can_afford(Formulas.seating_area_cost(state))


func upgrade_seating_area() -> bool:
	if not can_upgrade_seating_area():
		return false
	state.spend(Formulas.seating_area_cost(state))
	state.seating_level += 1
	return true


func can_hire_helper() -> bool:
	return state.has_research("shredder_service") and state.helpers.size() < GameConfig.MAX_HELPERS and state.can_afford(Formulas.helper_cost(state))


func hire_helper() -> bool:
	if not can_hire_helper():
		return false
	state.spend(Formulas.helper_cost(state))
	state.add_helper()
	state.staff_hired += 1
	return true


func can_hire_hr() -> bool:
	return state.hr < GameConfig.MAX_HR and state.can_afford(Formulas.hr_cost(state))


func hire_hr() -> bool:
	if not can_hire_hr():
		return false
	state.spend(Formulas.hr_cost(state))
	state.hr += 1
	state.staff_hired += 1
	return true


func can_hire_guard() -> bool:
	return state.guards < GameConfig.MAX_GUARDS and state.can_afford(Formulas.guard_cost(state))


func hire_guard() -> bool:
	if not can_hire_guard():
		return false
	state.spend(Formulas.guard_cost(state))
	state.guards += 1
	state.staff_hired += 1
	return true


func set_thoroughness(dept_id: String, value: int) -> bool:
	var dept := state.department(dept_id)
	if dept == null or value < 0 or value >= GameConfig.THOROUGHNESS.size():
		return false
	dept.thoroughness = value
	return true


func set_prioritize_urgent(dept_id: String, value: bool) -> bool:
	var dept := state.department(dept_id)
	if dept == null:
		return false
	dept.prioritize_urgent = value
	return true


func set_scan_all(dept_id: String, value: bool) -> bool:
	var dept := state.department(dept_id)
	if dept == null or not dept.is_customs():
		return false
	dept.scan_all = value
	return true


func unlock_department(dept_id: String) -> bool:
	return simulation.unlock(dept_id)


func buy_research(research_id: String) -> bool:
	if not Progression.research_block_reason(state, research_id).is_empty():
		return false
	state.spend(Formulas.research_cost(research_id, state.research_level(research_id)))
	state.research[research_id] += 1
	return true


func expand_building() -> bool:
	if not Progression.expansion_block_reason(state).is_empty():
		return false
	state.building_stage += 1
	state.spend(float(state.stage_config().cost))
	return true


func set_player_input(direction: Vector2) -> void:
	state.player.input = direction.limit_length(1.0)
