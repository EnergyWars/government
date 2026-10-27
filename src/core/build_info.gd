class_name BuildInfo
extends RefCounted

const PATH := "res://build_info.json"
const VERSION_SETTING := "application/config/version"

var version: String
var built_at: int


func _init(p_version: String = "", p_built_at: int = 0) -> void:
	version = p_version
	built_at = maxi(p_built_at, 0)


static func project_version() -> String:
	return str(ProjectSettings.get_setting(VERSION_SETTING, ""))


static func serialize(p_version: String, p_built_at: int) -> String:
	return JSON.stringify({"version": p_version, "built_at": p_built_at})


static func parse(text: String, fallback_version: String) -> BuildInfo:
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return BuildInfo.new(fallback_version)
	var data: Dictionary = json.data
	var raw_version: Variant = data.get("version")
	var raw_time: Variant = data.get("built_at")
	var parsed_version := raw_version as String if raw_version is String and not (raw_version as String).is_empty() else fallback_version
	var parsed_time := int(raw_time) if raw_time is float or raw_time is int else 0
	return BuildInfo.new(parsed_version, parsed_time)


static func load_from(path: String = PATH) -> BuildInfo:
	var fallback := project_version()
	if not FileAccess.file_exists(path):
		return BuildInfo.new(fallback)
	return parse(FileAccess.get_file_as_string(path), fallback)


func has_timestamp() -> bool:
	return built_at > 0


func local_datetime(bias_minutes: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(built_at + bias_minutes * 60)
