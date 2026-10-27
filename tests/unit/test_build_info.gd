extends GutTest

const TEMP_PATH := "user://test_build_info.json"
const BUILT_AT := 1793044260

var _previous_locale: String


func before_each() -> void:
	_previous_locale = TranslationServer.get_locale()


func after_each() -> void:
	TranslationServer.set_locale(_previous_locale)
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)


func _write(text: String) -> void:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _settings_sheet() -> SettingsSheet:
	return autofree(SettingsSheet.new()).with_settings(AppSettings.new("user://test_build_info_settings.cfg"))


func _find_label(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


func test_project_version_comes_from_project_settings() -> void:
	assert_eq(BuildInfo.project_version(), "1.0.0")


func test_serialize_and_parse_round_trip() -> void:
	var info := BuildInfo.parse(BuildInfo.serialize("2.3.4", BUILT_AT), "fallback")
	assert_eq(info.version, "2.3.4")
	assert_eq(info.built_at, BUILT_AT)
	assert_true(info.has_timestamp())


func test_parse_invalid_json_uses_fallback_without_timestamp() -> void:
	var info := BuildInfo.parse("not json", "1.0.0")
	assert_eq(info.version, "1.0.0")
	assert_eq(info.built_at, 0)
	assert_false(info.has_timestamp())


func test_parse_non_dictionary_uses_fallback() -> void:
	var info := BuildInfo.parse("[1, 2]", "1.0.0")
	assert_eq(info.version, "1.0.0")
	assert_false(info.has_timestamp())


func test_parse_missing_fields_uses_fallback() -> void:
	var info := BuildInfo.parse("{}", "1.0.0")
	assert_eq(info.version, "1.0.0")
	assert_false(info.has_timestamp())


func test_parse_rejects_wrong_types_and_empty_version() -> void:
	var info := BuildInfo.parse('{"version": 5, "built_at": "soon"}', "1.0.0")
	assert_eq(info.version, "1.0.0")
	assert_false(info.has_timestamp())
	assert_eq(BuildInfo.parse('{"version": "", "built_at": 10}', "1.0.0").version, "1.0.0")


func test_negative_timestamp_is_clamped() -> void:
	var info := BuildInfo.parse('{"version": "1.0.0", "built_at": -5}', "x")
	assert_eq(info.built_at, 0)
	assert_false(info.has_timestamp())


func test_load_from_missing_file_uses_project_version() -> void:
	var info := BuildInfo.load_from("user://does_not_exist_build_info.json")
	assert_eq(info.version, BuildInfo.project_version())
	assert_false(info.has_timestamp())


func test_load_from_reads_written_file() -> void:
	_write(BuildInfo.serialize("1.2.0", BUILT_AT))
	var info := BuildInfo.load_from(TEMP_PATH)
	assert_eq(info.version, "1.2.0")
	assert_eq(info.built_at, BUILT_AT)


func test_load_from_corrupt_file_uses_project_version() -> void:
	_write("{broken")
	var info := BuildInfo.load_from(TEMP_PATH)
	assert_eq(info.version, BuildInfo.project_version())
	assert_false(info.has_timestamp())


func test_default_path_without_export_has_no_timestamp() -> void:
	assert_false(BuildInfo.load_from().has_timestamp())


func test_local_datetime_applies_time_zone_bias() -> void:
	var info := BuildInfo.new("1.0.0", BUILT_AT)
	var utc := info.local_datetime(0)
	assert_eq([utc.year, utc.month, utc.day, utc.hour, utc.minute], [2026, 10, 26, 19, 51])
	var berlin := info.local_datetime(60)
	assert_eq([berlin.hour, berlin.minute], [20, 51])
	var shifted := info.local_datetime(-1200)
	assert_eq([shifted.day, shifted.hour], [25, 23])


func test_version_text_without_timestamp() -> void:
	TranslationServer.set_locale("de")
	assert_eq(_settings_sheet().version_text(BuildInfo.new("1.0.0"), 60), "Version 1.0.0")
	TranslationServer.set_locale("en")
	assert_eq(_settings_sheet().version_text(BuildInfo.new("1.0.0"), 60), "Version 1.0.0")


func test_version_text_with_timestamp_in_german() -> void:
	TranslationServer.set_locale("de")
	var text := _settings_sheet().version_text(BuildInfo.new("1.0.0", BUILT_AT), 60)
	assert_eq(text, "Version 1.0.0 · Build vom 26.10.2026, 20:51 Uhr")


func test_version_text_with_timestamp_in_english() -> void:
	TranslationServer.set_locale("en")
	var text := _settings_sheet().version_text(BuildInfo.new("1.0.0", BUILT_AT), 0)
	assert_eq(text, "Version 1.0.0 · built 2026-10-26 19:51")


func test_version_text_pads_single_digits() -> void:
	TranslationServer.set_locale("de")
	var text := _settings_sheet().version_text(BuildInfo.new("1.0.0", 1767229500), 0)
	assert_eq(text, "Version 1.0.0 · Build vom 01.01.2026, 01:05 Uhr")


func test_settings_sheet_shows_version() -> void:
	var game := Game.new(GameState.create_new(4))
	var sheet := SettingsSheet.new().with_settings(AppSettings.new("user://test_build_info_settings.cfg"))
	sheet.setup(game, "")
	add_child_autofree(sheet)
	var expected := sheet.version_text(BuildInfo.load_from(), int(Time.get_time_zone_from_system().get("bias", 0)))
	assert_not_null(_find_label(sheet.content, expected))
	await wait_physics_frames(2)
