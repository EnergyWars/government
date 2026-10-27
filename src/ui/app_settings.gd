class_name AppSettings
extends RefCounted

const DEFAULT_PATH := "user://settings.cfg"
const LOCALES: Array[String] = ["", "de", "en"]
const FALLBACK_LOCALE := "en"

var path: String
var locale := ""
var sound := true
var haptics := true


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_settings() -> AppSettings:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var stored := str(config.get_value("general", "locale", ""))
		locale = stored if LOCALES.has(stored) else ""
		sound = _flag(config.get_value("feedback", "sound", true))
		haptics = _flag(config.get_value("feedback", "haptics", true))
	return self


static func _flag(value: Variant) -> bool:
	return value if value is bool else true


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.set_value("feedback", "sound", sound)
	config.set_value("feedback", "haptics", haptics)
	config.save(path)


func set_locale(value: String) -> void:
	locale = value if LOCALES.has(value) else ""
	save()
	apply()


func set_sound(value: bool) -> void:
	sound = value
	save()


func set_haptics(value: bool) -> void:
	haptics = value
	save()


func resolved_locale() -> String:
	if not locale.is_empty():
		return locale
	var system := OS.get_locale_language()
	return system if LOCALES.has(system) else FALLBACK_LOCALE


func apply() -> void:
	TranslationServer.set_locale(resolved_locale())
