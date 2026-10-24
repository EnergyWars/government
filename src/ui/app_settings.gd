class_name AppSettings
extends RefCounted

const DEFAULT_PATH := "user://settings.cfg"
const LOCALES: Array[String] = ["", "de", "en"]
const FALLBACK_LOCALE := "en"

var path: String
var locale := ""


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


func load_settings() -> AppSettings:
	var config := ConfigFile.new()
	if config.load(path) == OK:
		var stored := str(config.get_value("general", "locale", ""))
		locale = stored if LOCALES.has(stored) else ""
	return self


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("general", "locale", locale)
	config.save(path)


func set_locale(value: String) -> void:
	locale = value if LOCALES.has(value) else ""
	save()
	apply()


func resolved_locale() -> String:
	if not locale.is_empty():
		return locale
	var system := OS.get_locale_language()
	return system if LOCALES.has(system) else FALLBACK_LOCALE


func apply() -> void:
	TranslationServer.set_locale(resolved_locale())
