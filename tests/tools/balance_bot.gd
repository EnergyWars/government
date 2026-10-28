extends SceneTree

const DECISION_INTERVAL := 1.0

var hours := 6.0
var active_minutes := 30.0
var tick := 0.1


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hours="):
			hours = arg.trim_prefix("--hours=").to_float()
		elif arg.begins_with("--active="):
			active_minutes = arg.trim_prefix("--active=").to_float()
	var state := GameState.create_new(2024)
	var game := Game.new(state)
	var elapsed := 0.0
	var next_decision := 0.0
	var last_goal := -1
	var next_report := 1800.0
	while elapsed < hours * 3600.0:
		if elapsed < active_minutes * 60.0:
			var task := Guidance.next_task(state)
			var direction := Vector2.ZERO
			if not task.is_empty() and state.player.position.distance_to(task.point) > 20.0:
				direction = state.player.position.direction_to(task.point)
			game.actions.set_player_input(direction)
		else:
			game.actions.set_player_input(Vector2.ZERO)
		game.simulation.tick(tick)
		elapsed += tick
		if elapsed < next_decision:
			continue
		next_decision += DECISION_INTERVAL
		while game.goals.claim():
			pass
		_buy(game)
		if state.goal_index != last_goal:
			last_goal = state.goal_index
			print("%7.1f min | goal %2d | money %12.0f | rep %6.1f | depts %d | stage %d | cases %d | lost %d | staff %d | mail %d/%d/%d | ruckus %d | bundles %d" % [elapsed / 60.0, state.goal_index, state.money, state.reputation, state.unlocked_count(), state.building_stage, state.cases_completed, state.citizens_lost, state.total_staff(), state.mail_received, state.mail_dropped, state.mail_returned, state.ruckus_calmed, state.bundles])
		if elapsed >= next_report:
			next_report += 1800.0
			print("  ~ %5.0f min: money %.0f rep %.1f income/s %.1f flawed %d lost %d mail %d/%d bundles %d" % [elapsed / 60.0, state.money, state.reputation, OfflineCalculator.earnings_per_second(state) / GameConfig.OFFLINE_EFFICIENCY, state.cases_flawed, state.citizens_lost, state.mail_received, state.mail_returned, state.bundles])
	quit()


func _buy(game: Game) -> void:
	var state := game.state
	var actions := game.actions
	for dept_id in GameConfig.department_ids():
		if actions.unlock_department(dept_id):
			return
	for entry in UpgradeCatalog.expansion_entries(state):
		if entry.kind == UpgradeCatalog.RANK and entry.is_buyable() and actions.buy_entry(entry.id):
			return
	if game.goals.has_goal() and str(game.goals.current().type) == "room_speed":
		actions.buy_upgrade("room_speed", GameConfig.ROOM_HALL)
	for dept in state.unlocked_departments():
		var weakest := Formulas.bottleneck(state, dept)
		if weakest == "demand":
			continue
		if weakest == "transport":
			if _install_tube_stations(game, dept.id) or actions.hire_runner():
				continue
			for index in state.runners.size():
				if actions.upgrade_runner(index):
					break
			continue
		var station := state.station(weakest)
		if actions.needs_onboarding(weakest):
			continue
		if not station.machine and station.staff < station.desks:
			actions.hire(weakest)
		elif not actions.add_desk(weakest):
			actions.buy_upgrade("room_speed", GameConfig.station_room(weakest))
	var cheapest := _cheapest_track(state)
	if cheapest != null and state.money > 3.0 * cheapest.cost:
		actions.buy_entry(cheapest.id)
		return
	for key in [GameConfig.RECEPTION, GameConfig.COUNTER]:
		if state.station(key).staff < state.station(key).desks:
			actions.hire(key)
	if state.runners.is_empty():
		actions.hire_runner()
	var mailroom := state.mailroom()
	if mailroom != null:
		if mailroom.staff < mailroom.desks:
			actions.hire(GameConfig.MAILROOM)
		if mailroom.inbox.size() >= mailroom.storage_capacity():
			actions.upgrade_mail_storage()
	for dept in state.unlocked_departments():
		if state.money > 4.0 * Formulas.track_cost("team_lead", 0, dept.id):
			actions.buy_upgrade("team_lead", dept.id)
		if state.money > 4.0 * Formulas.track_cost("room_trays", state.upgrade_level("room_trays", dept.id), dept.id):
			actions.buy_upgrade("room_trays", dept.id)
		if game.simulation.can_patrol(dept.id):
			game.simulation.start_patrol(dept.id)


func _install_tube_stations(game: Game, dept_id: String) -> bool:
	var state := game.state
	if not state.has_upgrade("pneumatic_tubes"):
		return false
	for key in RouteBuilder.build(CaseFile.new(dept_id)):
		var room_id := GameConfig.station_room(key)
		if not state.has_tube_station(room_id) and game.actions.buy_upgrade("tube_station", room_id):
			return true
	return false


func _cheapest_track(state: GameState) -> UpgradeEntry:
	var cheapest: UpgradeEntry = null
	for entry in UpgradeCatalog.entries(state):
		if entry.kind == UpgradeCatalog.TRACK and entry.is_buyable() and (cheapest == null or entry.cost < cheapest.cost):
			cheapest = entry
	return cheapest
