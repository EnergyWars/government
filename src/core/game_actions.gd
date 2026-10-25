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


func needs_onboarding(key: String) -> bool:
	var station := state.station(key)
	if station == null or station.is_shared():
		return false
	var dept := state.department(station.dept_id)
	return dept != null and not dept.is_onboarded()


func can_hire(key: String) -> bool:
	var station := state.station(key)
	return station != null and not station.machine and station.staff < station.desks and not needs_onboarding(key) and state.can_afford(Formulas.hire_cost(station))


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
	station.rush = GameConfig.UPGRADE_RUSH_SECONDS
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


func hire_runner(role: String = "") -> bool:
	if not can_hire_runner():
		return false
	state.spend(Formulas.runner_cost(state))
	state.add_runner(role if Runner.ROLES.has(role) else Formulas.weakest_runner_role(state))
	state.staff_hired += 1
	return true


func can_upgrade_runner(index: int) -> bool:
	if index < 0 or index >= state.runners.size():
		return false
	var runner := state.runners[index]
	return runner.level < GameConfig.MAX_RUNNER_LEVEL and state.can_afford(Formulas.runner_level_cost(runner))


func upgrade_runner(index: int) -> bool:
	if not can_upgrade_runner(index):
		return false
	var runner := state.runners[index]
	state.spend(Formulas.runner_level_cost(runner))
	runner.level += 1
	return true


func tube_segment_ready(tube_id: String) -> bool:
	var dept := state.department(RouteBuilder.segment_department(tube_id))
	if dept == null or not dept.unlocked or not RouteBuilder.segments(dept.id).has(tube_id):
		return false
	var ends := RouteBuilder.segment_ends(tube_id)
	return state.station(ends[0]) != null and state.station(ends[1]) != null and state.tube_link(ends[0], ends[1])


func can_upgrade_tube(tube_id: String) -> bool:
	var level := state.tube_level(tube_id)
	return tube_segment_ready(tube_id) and level < GameConfig.TUBE_SEGMENT_MAX_LEVEL and state.can_afford(Formulas.tube_segment_cost(level))


func upgrade_tube(tube_id: String) -> bool:
	if not can_upgrade_tube(tube_id):
		return false
	var level := state.tube_level(tube_id)
	state.spend(Formulas.tube_segment_cost(level))
	state.tube_levels[tube_id] = level + 1
	return true


func set_runner_role(index: int, role: String) -> bool:
	if index < 0 or index >= state.runners.size() or not Runner.ROLES.has(role):
		return false
	var runner := state.runners[index]
	if runner.role == role:
		return false
	runner.role = role
	if runner.task == Runner.Task.TO_SOURCE:
		runner.clear_task()
	return true


func runner_department_options() -> Array[String]:
	var options: Array[String] = [Runner.ALL_DEPARTMENTS]
	for dept in state.unlocked_departments():
		options.append(dept.id)
	return options


func next_department_option(current: String) -> String:
	var options := runner_department_options()
	return options[(options.find(current) + 1) % options.size()]


func cycle_runner_department(index: int) -> bool:
	if index < 0 or index >= state.runners.size():
		return false
	var runner := state.runners[index]
	runner.dept_id = next_department_option(runner.dept_id)
	if runner.task == Runner.Task.TO_SOURCE:
		runner.clear_task()
	return true


func cycle_collector_department(index: int) -> bool:
	if index < 0 or index >= state.collectors.size():
		return false
	var collector := state.collectors[index]
	collector.dept_id = next_department_option(collector.dept_id)
	collector.source = ""
	return true


func cycle_coffee_intern_department(index: int) -> bool:
	if index < 0 or index >= state.coffee_interns.size():
		return false
	var coffee_intern := state.coffee_interns[index]
	coffee_intern.dept_id = next_department_option(coffee_intern.dept_id)
	if not coffee_intern.carrying:
		coffee_intern.clear_task()
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


func can_upgrade_mail_storage() -> bool:
	var room := state.mailroom()
	return room != null and room.storage_level < GameConfig.MAIL_STORAGE_MAX_LEVEL and state.can_afford(Formulas.mail_storage_cost(room))


func upgrade_mail_storage() -> bool:
	if not can_upgrade_mail_storage():
		return false
	var room := state.mailroom()
	state.spend(Formulas.mail_storage_cost(room))
	room.storage_level += 1
	return true


func can_hire_helper() -> bool:
	return state.has_upgrade("shredder_service") and state.helpers.size() < GameConfig.MAX_HELPERS and state.can_afford(Formulas.helper_cost(state))


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


func buy_upgrade(upgrade_id: String, room_id: String = "", count: int = 1) -> bool:
	var level := state.upgrade_level(upgrade_id, room_id)
	var amount := mini(count, int(GameConfig.upgrade(upgrade_id).get("max", 0)) - level)
	if amount <= 0 or not Progression.upgrade_block_reason(state, upgrade_id, room_id, amount).is_empty():
		return false
	state.spend(Formulas.track_bulk_cost(upgrade_id, level, amount, room_id))
	state.set_upgrade(upgrade_id, level + amount, room_id)
	return true


func buy_entry(entry_id: String, count: int = 1) -> bool:
	return UpgradeCatalog.buy(self, entry_id, count)


func expand_building() -> bool:
	if not Progression.expansion_block_reason(state).is_empty():
		return false
	state.building_stage += 1
	state.spend(float(state.stage_config().cost))
	state.ensure_mailroom()
	return true


func set_player_input(direction: Vector2) -> void:
	state.player.input = direction.limit_length(1.0)
