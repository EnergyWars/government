class_name SfxPlayer
extends Node

const VOICES := 8
const MIN_PITCH := 0.5
const MAX_PITCH := 2.5

var settings: AppSettings
var bank := SoundBank.new()
var clock := 0.0
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _last_played := {}
var _warm_queue: Array[String] = []


func setup(p_settings: AppSettings) -> SfxPlayer:
	settings = p_settings
	return self


func _ready() -> void:
	for index in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	_warm_queue = SoundBank.ids()
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	clock += delta
	if not _warm_queue.is_empty():
		bank.stream(_warm_queue.pop_back())


func is_enabled() -> bool:
	return settings == null or settings.sound


func can_play(id: String) -> bool:
	if not is_enabled() or not SoundBank.has(id) or _players.is_empty():
		return false
	return not _last_played.has(id) or clock - float(_last_played[id]) >= SoundBank.gap(id)


func play(id: String, pitch: float = 1.0) -> bool:
	if not can_play(id):
		return false
	_last_played[id] = clock
	var player := _players[_cursor]
	_cursor = (_cursor + 1) % _players.size()
	player.stream = bank.stream(id)
	player.pitch_scale = clampf(pitch, MIN_PITCH, MAX_PITCH)
	player.volume_db = SoundBank.volume_db(id)
	player.play()
	return true


func vibrate(duration_ms: int) -> bool:
	if settings != null and not settings.haptics:
		return false
	Input.vibrate_handheld(duration_ms)
	return true


func watch_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		watch_button(node as BaseButton)


func _on_button_pressed() -> void:
	play(SoundBank.CLICK)
