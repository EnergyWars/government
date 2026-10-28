extends SceneTree

const SIM_METHODS: Array[String] = [
	"_update_event", "_age_cases", "_spawn_citizens", "_update_tickets", "_update_mail", "_update_moods",
	"_update_complaints", "_update_visitors", "_update_intern", "_update_coffee_interns", "_update_disputes",
	"_update_ruckus", "_update_kranz", "_update_lunch", "_update_gift", "_update_sickness", "_work_stations",
	"_update_player", "_update_runners", "_pneumatic_transport",
]

var _main: Node
var _frames := 0
var _warmup := 900.0
var _measure_frames := 300
var _sim_ticks := 600
var _late := false
var _totals: Dictionary = {}
var _counts: Dictionary = {}
var _starts: Dictionary = {}
var _frame_start := 0
var _frame_times: Array[int] = []
var _process_total := 0.0
var _disable := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--warmup="):
			_warmup = arg.trim_prefix("--warmup=").to_float()
		elif arg.begins_with("--frames="):
			_measure_frames = arg.trim_prefix("--frames=").to_int()
		elif arg.begins_with("--disable="):
			_disable = arg.trim_prefix("--disable=")
		elif arg == "--late":
			_late = true
		elif arg.begins_with("--ticks="):
			_sim_ticks = arg.trim_prefix("--ticks=").to_int()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_prepare()
		_profile_simulation()
		_hook_draws()
	if _frames == 50 and not _disable.is_empty():
		for part in _disable.split(","):
			var node: Node = _main if part == "main" else _main.get(part)
			node.set_process(false)
			if node is CanvasItem and part != "main":
				(node as CanvasItem).visible = false
	if _frames == 59:
		_totals.clear()
		_counts.clear()
	elif _frames > 3 and _frames < 60:
		pass
	elif _frames >= 60:
		if _frame_start > 0:
			_frame_times.append(Time.get_ticks_usec() - _frame_start)
			_process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		_frame_start = Time.get_ticks_usec()
		if _frame_times.size() >= _measure_frames:
			_report()
			quit()
	return false


func _prepare() -> void:
	for child in _main.overlay.get_children():
		child.queue_free()
	if is_instance_valid(_main.intro):
		_main.intro.queue_free()
	_main.tutorial_card.visible = false
	var state: GameState = _main.game.state
	state.tutorial_step = -1
	state.money = 5000000.0
	state.reputation = 300.0
	state.building_stage = 3
	for dept in GameConfig.DEPARTMENTS:
		state.unlock_department(str(dept.id))
	for i in 6:
		state.add_runner()
	for key in state.stations:
		var station := state.stations[key]
		station.staff = station.desks if not station.machine else station.staff
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	if _late:
		state.money = 1e18
		state.reputation = 1e6
		for round in 6:
			for entry in UpgradeCatalog.entries(state):
				if entry.is_buyable():
					_main.game.actions.buy_entry(entry.id, 25)
	var steps := int(_warmup / GameConfig.TICK)
	for i in steps:
		_main.game.simulation.tick(GameConfig.TICK)
	_main.game.state.money = 5000000.0
	_main.office._floaters.clear()
	_main.office._walkers.clear()
	_main.office._capsules.clear()
	_main.office._furnishing_ready = false
	_main.office._seat_born.clear()
	_main.office._slot_born.clear()


func _profile_simulation() -> void:
	var sim: Simulation = _main.game.simulation
	var state: GameState = _main.game.state
	var per_method: Dictionary = {}
	for method in SIM_METHODS:
		per_method[method] = 0
	var total := 0
	var guidance := 0
	var catalog := 0
	for i in _sim_ticks:
		var begin := Time.get_ticks_usec()
		sim.tick(GameConfig.TICK)
		total += Time.get_ticks_usec() - begin
	for i in _sim_ticks:
		state.play_time += GameConfig.TICK
		for method in SIM_METHODS:
			var begin := Time.get_ticks_usec()
			sim.call(method, GameConfig.TICK)
			per_method[method] += Time.get_ticks_usec() - begin
		state.income.advance(GameConfig.TICK, state.money_earned)
	var minimum: Dictionary = {}
	for method in SIM_METHODS:
		var best := 1 << 30
		for i in 200:
			var begin := Time.get_ticks_usec()
			sim.call(method, GameConfig.TICK)
			best = mini(best, Time.get_ticks_usec() - begin)
		minimum[method] = best
	for i in 60:
		var begin := Time.get_ticks_usec()
		Guidance.next_task(state)
		guidance += Time.get_ticks_usec() - begin
	for i in 20:
		var begin := Time.get_ticks_usec()
		UpgradeCatalog.entries(state)
		catalog += Time.get_ticks_usec() - begin
	var hud_time := 0
	for i in 60:
		var begin := Time.get_ticks_usec()
		_main.hud.refresh()
		hud_time += Time.get_ticks_usec() - begin
	for part in ["task_panel.refresh", "_refresh_boost_button", "_refresh_bonus_card", "_refresh_desk_card", "income_per_minute"]:
		var node: Object = _main.hud.task_panel if part == "task_panel.refresh" else _main.hud
		var method: String = "refresh" if part == "task_panel.refresh" else part
		var t0 := Time.get_ticks_usec()
		for i in 30:
			if method in ["_refresh_boost_button", "_refresh_bonus_card", "_refresh_desk_card"]:
				node.call(method, state)
			else:
				node.call(method)
		print("hud part %s: %.1f us" % [part, (Time.get_ticks_usec() - t0) / 30.0])
	for dept in state.unlocked_departments():
		var t1 := Time.get_ticks_usec()
		for i in 30:
			Formulas.workload(state, dept)
		var t2 := Time.get_ticks_usec()
		for i in 30:
			Formulas.resting_count(state, dept)
		var t3 := Time.get_ticks_usec()
		for i in 30:
			Formulas.waiting_count(state, dept)
		print("dept %s workload %.1f resting %.1f waiting %.1f" % [dept.id, (t2 - t1) / 30.0, (t3 - t2) / 30.0, (Time.get_ticks_usec() - t3) / 30.0])
		break
	print("== Simulation (%d Ticks) ==" % _sim_ticks)
	print("tick avg: %.1f us" % (float(total) / _sim_ticks))
	var ordered := per_method.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return per_method[a] > per_method[b])
	for method in ordered:
		print("  %-26s %8.1f us  (min %d us)" % [method, float(per_method[method]) / _sim_ticks, minimum[method]])
	print("Guidance.next_task avg: %.1f us" % (float(guidance) / 60))
	print("UpgradeCatalog.entries avg: %.1f us" % (float(catalog) / 20))
	print("hud.refresh avg: %.1f us" % (float(hud_time) / 60))
	var desks := 0
	var queued := 0
	for key in state.stations:
		desks += state.stations[key].jobs.size()
		queued += state.stations[key].inbox.size() + state.stations[key].outbox.size()
	print("stations: %d  desks: %d  queued: %d  runners: %d  reject runners: %d  parcels: %d  ticket_line: %d  reviews: %d" % [state.stations.size(), desks, queued, state.runners.size(), state.runners_in(Runner.REJECT), state.tube_parcels.size(), state.ticket_line.size(), state.reviews.size()])


func _hook_draws() -> void:
	var office: WorldView = _main.office
	for child in office.get_children():
		var node := child as Node2D
		if node == null:
			continue
		var label := _label(office, node)
		var connections := node.get_signal_connection_list("draw")
		for connection in connections:
			node.disconnect("draw", connection.callable)
		node.draw.connect(_begin.bind(label))
		for connection in connections:
			node.draw.connect(connection.callable)
		node.draw.connect(_end.bind(label))


func _label(office: WorldView, node: Node2D) -> String:
	for layer in office._layers:
		if layer.node == node:
			return "layer " + str(layer.id)
	if node == office._crowd:
		return "crowd"
	if node == office._queue:
		return "queue"
	if node == office._actors:
		return "actors"
	return node.name


func _begin(label: String) -> void:
	_starts[label] = Time.get_ticks_usec()


func _end(label: String) -> void:
	_totals[label] = int(_totals.get(label, 0)) + Time.get_ticks_usec() - int(_starts[label])
	_counts[label] = int(_counts.get(label, 0)) + 1


func _report() -> void:
	var sum := 0
	for value in _frame_times:
		sum += value
	var sorted := _frame_times.duplicate()
	sorted.sort()
	print("== Frames (%d) ==" % _frame_times.size())
	print("frame avg: %.2f ms  p50: %.2f ms  p95: %.2f ms  max: %.2f ms" % [sum / 1000.0 / _frame_times.size(), sorted[sorted.size() / 2] / 1000.0, sorted[int(sorted.size() * 0.95)] / 1000.0, sorted[-1] / 1000.0])
	print("process time avg: %.2f ms" % (_process_total * 1000.0 / _frame_times.size()))
	print("draw calls: %d  objects: %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	var labels := _totals.keys()
	labels.sort_custom(func(a: String, b: String) -> bool: return _totals[a] > _totals[b])
	print("== Draw-Callbacks (Summe über alle Frames / Anzahl / pro Frame) ==")
	for label in labels:
		print("  %-28s %9.2f ms  %4d×  %7.3f ms/Frame" % [label, _totals[label] / 1000.0, _counts[label], _totals[label] / 1000.0 / _frame_times.size()])
