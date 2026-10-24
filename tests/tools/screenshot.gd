extends SceneTree

var _frames := 0
var _out := "user://screenshot.png"
var _sheet := ""
var _argument := ""
var _seconds := 0.0
var _main: Node
var _rich := false
var _focus := ""
var _locale := ""
var _camera := Vector2.INF
var _rest := false
var _tubes := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--sheet="):
			_sheet = arg.trim_prefix("--sheet=")
		elif arg.begins_with("--arg="):
			_argument = arg.trim_prefix("--arg=")
		elif arg.begins_with("--simulate="):
			_seconds = arg.trim_prefix("--simulate=").to_float()
		elif arg == "--rich":
			_rich = true
		elif arg.begins_with("--focus="):
			_focus = arg.trim_prefix("--focus=")
		elif arg.begins_with("--locale="):
			_locale = arg.trim_prefix("--locale=")
		elif arg == "--rest":
			_rest = true
		elif arg == "--tubes":
			_tubes = true
		elif arg.begins_with("--camera="):
			var parts := arg.trim_prefix("--camera=").split(",")
			_camera = Vector2(parts[0].to_float(), parts[1].to_float())
	if not _locale.is_empty():
		TranslationServer.set_locale(_locale)
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		if not _locale.is_empty():
			TranslationServer.set_locale(_locale)
		for child in _main.overlay.get_children():
			child.queue_free()
		if _rich:
			var state: GameState = _main.game.state
			state.money = 5000000.0
			state.reputation = 300.0
			state.building_stage = 3
			for dept_id in ["tax_services", "business_licences", "vehicle_registration", "building_permits"]:
				state.unlock_department(dept_id)
			for i in 3:
				state.add_runner()
			for key in state.stations:
				var station := state.stations[key]
				station.staff = station.desks if not station.machine else station.staff
			state.station("general_services/review").add_specialist()
		if _tubes:
			_main.game.state.research["pneumatic_tubes"] = 1
		if _seconds > 0.0:
			var state: GameState = _main.game.state
			var steps := int(_seconds / GameConfig.TICK)
			for i in steps:
				var task := Guidance.next_task(state)
				var direction := Vector2.ZERO
				if not task.is_empty() and state.player.position.distance_to(task.point) > 20.0:
					direction = state.player.position.direction_to(task.point)
				_main.game.actions.set_player_input(direction)
				_main.game.simulation.tick(GameConfig.TICK)
			_main.game.actions.set_player_input(Vector2.ZERO)
		_main.office.camera = _main.game.state.player.position
		if not _focus.is_empty():
			_main.office.focus(_focus)
			_main.office.camera = _main.office.layout.room(_focus).get_center()
		if _rest:
			var rest_state: GameState = _main.game.state
			var toggle := 0
			for key in rest_state.stations:
				for mood in rest_state.stations[key].moods:
					mood.rest(DeskMood.ASLEEP if toggle % 2 == 0 else DeskMood.COFFEE)
					toggle += 1
		if _camera != Vector2.INF:
			_main.office.camera = _camera
			_main.office._focus_point = _camera
			_main.office._focus_left = 3.0
		if not _sheet.is_empty():
			_main.open_sheet(_sheet, _argument)
	if _frames == 40:
		root.get_texture().get_image().save_png(_out)
		quit()
	return false
