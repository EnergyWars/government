extends Node

const AUTOSAVE_INTERVAL := 20.0

var settings: AppSettings
var save_service: SaveService
var game: Game
var office: WorldView
var joystick: JoystickView
var hud: Hud
var tutorial_card: TutorialCard
var intro: IntroScreen
var overlay: Control
var sfx: SfxPlayer
var celebrations: CelebrationLayer
var rewards: RewardDirector
var _sheet: Sheet
var _autosave_timer := 0.0
var _resetting := false


func _ready() -> void:
	settings = AppSettings.new().load_settings()
	settings.apply()
	sfx = SfxPlayer.new().setup(settings)
	add_child(sfx)
	save_service = SaveService.new()
	var state := save_service.load_state()
	if state == null:
		state = GameState.create_new()
	var offline := OfflineCalculator.apply(state, now())
	game = Game.new(state)
	_build_scene()
	if offline.money > 0.0:
		_show_offline(offline)


func now() -> int:
	return int(Time.get_unix_time_from_system())


func _build_scene() -> void:
	RenderingServer.set_default_clear_color(AppTheme.BACKGROUND)
	office = WorldView.new()
	add_child(office)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = AppTheme.build()
	layer.add_child(root)
	hud = Hud.new().setup(game, _safe_top())
	joystick = JoystickView.new()
	root.add_child(joystick)
	hud.open_sheet.connect(open_sheet)
	hud.focus_department.connect(func(dept_id: String) -> void: office.focus(dept_id))
	root.add_child(hud)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	celebrations = CelebrationLayer.new()
	root.add_child(celebrations)
	office.setup(game, joystick)
	office.open_spot.connect(func(spot: String) -> void: open_sheet("spot", spot))
	office.open_sheet.connect(open_sheet)
	game.changed.connect(hud.refresh)
	tutorial_card = TutorialCard.new().setup(game, hud, _safe_top())
	tutorial_card.highlight_changed.connect(hud.highlight)
	root.add_child(tutorial_card)
	rewards = RewardDirector.new().setup(game, sfx, celebrations, hud, office)
	add_child(rewards)
	if IntroScreen.should_show(game.state):
		intro = IntroScreen.new().setup(game.state, _safe_top())
		intro.finished.connect(save)
		root.add_child(intro)


func _safe_top() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if screen.y <= 0:
		return 0.0
	var viewport_height := get_viewport().get_visible_rect().size.y
	return safe.position.y * viewport_height / screen.y


func _process(delta: float) -> void:
	if not is_intro_open():
		game.advance(delta)
	office.top_inset = hud.top_height()
	office.bottom_inset = hud.bottom_height()
	celebrations.top_inset = hud.top_height()
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL:
		_autosave_timer = 0.0
		save()


func is_intro_open() -> bool:
	return is_instance_valid(intro) and not intro.is_queued_for_deletion()


func save() -> void:
	if not _resetting:
		save_service.save(game.state, now())


func open_sheet(sheet_id: String, argument: String = "") -> void:
	if sheet_id == "reset":
		_confirm_reset()
		return
	if sheet_id == "tutorial":
		_restart_tutorial()
		return
	if sheet_id == "locate":
		_locate(argument)
		return
	if is_instance_valid(_sheet):
		_sheet.close_sheet()
	var sheet: Sheet
	match sheet_id:
		"upgrades":
			sheet = UpgradesSheet.new()
		"spot":
			sheet = SpotSheet.new()
		"goals":
			sheet = GoalsSheet.new()
		"reviews":
			sheet = ReviewsSheet.new()
		"complaints":
			sheet = ComplaintsSheet.new()
		"statistics":
			sheet = StatisticsSheet.new()
		"boosts":
			sheet = BoostSheet.new()
		"settings":
			sheet = SettingsSheet.new().with_settings(settings)
		_:
			return
	sheet.setup(game, argument)
	sheet.navigate.connect(open_sheet)
	sheet.closed.connect(game.tutorial.set_open_sheet.bind(""))
	_sheet = sheet
	overlay.add_child(sheet)
	game.tutorial.set_open_sheet(sheet_id)


func _locate(spot: String) -> void:
	if is_instance_valid(_sheet):
		_sheet.close_sheet()
	office.focus_spot(spot)


func _restart_tutorial() -> void:
	if is_instance_valid(_sheet):
		_sheet.close_sheet()
	game.tutorial.restart()


func _dialog(dialog: AppDialog) -> AppDialog:
	overlay.add_child(dialog)
	return dialog


func _show_offline(offline: Dictionary) -> AppDialog:
	var text := tr("FMT_OFFLINE_TEXT") % [UiKit.duration(offline.seconds), UiKit.money(offline.money)]
	var dialog := _dialog(AppDialog.new().configure(Icons.SCHEDULE, tr("OFFLINE_TITLE"), text, tr("ACTION_DOUBLE_AD"), tr("ACTION_OK")))
	dialog.confirmed.connect(func() -> void: AdPlaceholder.play(overlay, game.perform.bind(_double_offline.bind(offline))))
	dialog.dismissed.connect(rewards.windfall)
	return dialog


func _double_offline(offline: Dictionary) -> bool:
	if OfflineCalculator.double_up(game.state, offline) <= 0.0:
		return false
	rewards.windfall()
	return true


func _confirm_reset() -> void:
	var dialog := _dialog(AppDialog.new().configure(Icons.RESTART, tr("RESET_TITLE"), tr("RESET_TEXT"), tr("ACTION_RESET"), tr("ACTION_CANCEL"), "error"))
	dialog.confirmed.connect(_reset)


func _reset() -> void:
	_resetting = true
	save_service.delete()
	get_tree().reload_current_scene()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if game != null:
				save()
		NOTIFICATION_APPLICATION_RESUMED:
			if game != null:
				var offline := OfflineCalculator.apply(game.state, now())
				if offline.money > 0.0:
					_show_offline(offline)
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if is_instance_valid(_sheet) and not _sheet.is_queued_for_deletion():
				_sheet.close_sheet()
			else:
				save()
				get_tree().quit()
