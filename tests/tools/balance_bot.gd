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
			print("%7.1f min | goal %2d | money %12.0f | rep %6.1f | depts %d | stage %d | cases %d | lost %d | staff %d" % [elapsed / 60.0, state.goal_index, state.money, state.reputation, state.unlocked_count(), state.building_stage, state.cases_completed, state.citizens_lost, state.total_staff()])
		if elapsed >= next_report:
			next_report += 1800.0
			print("  ~ %5.0f min: money %.0f rep %.1f income/s %.1f flawed %d lost %d" % [elapsed / 60.0, state.money, state.reputation, OfflineCalculator.earnings_per_second(state) / GameConfig.OFFLINE_EFFICIENCY, state.cases_flawed, state.citizens_lost])
	quit()


func _buy(game: Game) -> void:
	var state := game.state
	var actions := game.actions
	for dept_id in GameConfig.department_ids():
		if actions.unlock_department(dept_id):
			return
	if actions.expand_building():
		return
	for research_id in GameConfig.RESEARCH_ORDER:
		if Progression.research_block_reason(state, research_id).is_empty() and state.money > 3.0 * Formulas.research_cost(research_id, state.research_level(research_id)):
			actions.buy_research(research_id)
			return
	for dept in state.unlocked_departments():
		var weakest := Formulas.bottleneck(state, dept)
		if weakest == "demand":
			continue
		if weakest == "transport":
			actions.hire_runner()
			continue
		var station := state.station(weakest)
		if not station.machine and station.staff < station.desks:
			actions.hire(weakest)
		elif not actions.add_desk(weakest):
			actions.upgrade(weakest)
	for key in [GameConfig.RECEPTION, GameConfig.COUNTER]:
		if state.station(key).staff < state.station(key).desks:
			actions.hire(key)
	if state.runners.is_empty():
		actions.hire_runner()
	for dept in state.unlocked_departments():
		if state.money > 4.0 * Formulas.supervisor_cost(dept):
			actions.hire_supervisor(dept.id)
		var review := state.station(dept.station_keys()[0 if not dept.is_customs() else 1])
		if state.money > 4.0 * Formulas.specialist_cost(review):
			actions.hire_specialist(review.key)
