@tool
extends EditorPlugin

const BuildInfoExport := preload("res://addons/build_info/build_info_export.gd")

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_export_plugin = BuildInfoExport.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null
