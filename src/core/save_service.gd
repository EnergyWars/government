class_name SaveService
extends RefCounted

const DEFAULT_PATH := "user://savegame.json"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func save(state: GameState, now: int) -> bool:
	state.saved_at = now
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state.to_dict()))
	file.close()
	return DirAccess.rename_absolute(temp_path, path) == OK


func has_save() -> bool:
	return FileAccess.file_exists(path)


func load_state() -> GameState:
	if not has_save():
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return null
	return GameState.from_dict(json.data)


func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(path)
