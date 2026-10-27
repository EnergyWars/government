@tool
extends EditorExportPlugin


func _get_name() -> String:
	return "BuildInfo"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var payload := BuildInfo.serialize(BuildInfo.project_version(), int(Time.get_unix_time_from_system()))
	add_file(BuildInfo.PATH, payload.to_utf8_buffer(), false)
