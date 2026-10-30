extends SceneTree

const SCHEMA := 1
const OUTPUT_DIR := "res://tools/upgrade_editor/data/"
const OUTPUT_CONTEXT := OUTPUT_DIR + "app_context.json"
const OUTPUT_TRANSLATIONS := OUTPUT_DIR + "game_translations.json"
const TRANSLATIONS_CSV := "res://i18n/translations.csv"


func _initialize() -> void:
	var state := _full_state()
	var entries := UpgradeCatalog.entries(state)
	var layout := WorldLayout.get_default()
	var spots := _spots(state, entries, layout)
	var context := {
		"schema": SCHEMA,
		"meta": {"exported_at": Time.get_datetime_string_from_system(true), "entries": entries.size()},
		"rooms": _rooms(),
		"system_entries": _system_entries(entries),
		"spots": spots,
		"map": _map(layout),
		"stations": _stations(state),
		"shared_stations": GameConfig.SHARED_STATIONS.duplicate(true),
		"allowed_rooms": _allowed_rooms(),
		"departments": GameConfig.DEPARTMENTS.duplicate(true),
		"building_stages": GameConfig.BUILDING_STAGES.duplicate(true),
		"constants": _constants(),
		"check": _check(entries),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_write(OUTPUT_CONTEXT, JSON.stringify(context, "\t", false))
	_write(OUTPUT_TRANSLATIONS, JSON.stringify(_load_translations(), "", false))
	var warnings := _warnings(entries)
	for warning in warnings:
		push_warning(warning)
	print("exported %d entries, %d upgrades, %d spots, %d warnings" % [entries.size(), GameConfig.upgrade_ids().size(), spots.size(), warnings.size()])
	quit()


func _full_state() -> GameState:
	var state := GameState.create_new(1)
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	return state


func _load_translations() -> Dictionary:
	var result := {}
	var file := FileAccess.open(TRANSLATIONS_CSV, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() >= 3 and not row[0].is_empty():
			result[row[0]] = {"en": row[1], "de": row[2]}
	return result


func _rooms() -> Array:
	var result := []
	for room_id in UpgradeCatalog.rooms():
		var config := GameConfig.department(room_id)
		result.append({
			"id": room_id,
			"department": not config.is_empty(),
			"cost_multiplier": float(config.get("cost_multiplier", 1.0)),
			"staff_multiplier": Formulas.department_staff_multiplier(config) if not config.is_empty() else 1.0,
			"unlock_cost": float(config.get("unlock_cost", 0.0)),
		})
	return result


func _system_entries(entries: Array[UpgradeEntry]) -> Dictionary:
	var result := {}
	for entry in entries:
		if entry.kind == UpgradeCatalog.TRACK:
			continue
		result[entry.id] = {"kind": entry.kind, "target": entry.target, "spot": entry.spot, "room": entry.room, "topic": entry.topic}
	return result


func _allowed_rooms() -> Dictionary:
	var shredder_rooms: Array[String] = []
	for dept_id in GameConfig.department_ids():
		if not GameConfig.is_customs(dept_id):
			shredder_rooms.append(dept_id)
	var tube_rooms: Array[String] = GameConfig.office_rooms().duplicate()
	var groups := {
		"room_speed": GameConfig.office_rooms(),
		"room_trays": GameConfig.office_rooms(),
		"tube_station": tube_rooms,
		"shredder": shredder_rooms,
		"lead_calm": GameConfig.department_ids(),
	}
	var result := {}
	for upgrade_id in GameConfig.upgrade_ids():
		if not GameConfig.is_room_upgrade(upgrade_id):
			continue
		if groups.has(upgrade_id):
			result[upgrade_id] = groups[upgrade_id]
		elif GameConfig.is_lead_track(upgrade_id):
			result[upgrade_id] = GameConfig.lead_rooms()
		else:
			result[upgrade_id] = GameConfig.upgrade_rooms(upgrade_id)
	return result


func _rect_list(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _spots(state: GameState, entries: Array[UpgradeEntry], layout: WorldLayout) -> Dictionary:
	var ids: Array[String] = []
	for spot: String in GameConfig.SPOTS:
		ids.append(spot)
	for room_id in GameConfig.SERVICE_ROOMS:
		ids.append(UpgradeCatalog.ROOM_PREFIX + room_id)
	for spot: String in layout.spots:
		if not ids.has(spot) and not spot.begins_with(WorldLayout.AREA_PREFIX):
			ids.append(spot)
	for entry in entries:
		if not ids.has(entry.spot) and not entry.spot.begins_with(WorldLayout.AREA_PREFIX):
			ids.append(entry.spot)
	var result := {}
	for spot in ids:
		var rects := []
		for rect: Rect2 in layout.spot_rects(spot):
			rects.append(_rect_list(rect))
		var visible := []
		for entry in UpgradeCatalog.entries_for_spot(state, spot):
			visible.append(entry.id)
		result[spot] = {"room": GameConfig.spot_room(spot), "rects": rects, "visible": visible}
	return result


func _map(layout: WorldLayout) -> Dictionary:
	var rects := []
	for dept_id in GameConfig.department_ids():
		rects.append({"id": dept_id, "kind": "department", "rect": _rect_list(layout.room(dept_id))})
	rects.append({"id": GameConfig.INSPECTION, "kind": "room", "room": GameConfig.ROOM_INSPECTION, "rect": _rect_list(layout.service_room(GameConfig.ROOM_INSPECTION))})
	for room_id in GameConfig.SERVICE_ROOMS:
		if room_id == GameConfig.ROOM_INSPECTION or room_id == GameConfig.ROOM_PLAYER:
			continue
		var rect := layout.service_room(room_id)
		if rect.has_area():
			rects.append({"id": room_id, "kind": "room", "room": room_id, "rect": _rect_list(rect)})
	for room_id: String in layout.waiting_rooms:
		rects.append({"id": room_id, "kind": "waiting", "room": room_id, "rect": _rect_list(layout.waiting_rooms[room_id])})
	for key: String in layout.areas:
		rects.append({"id": key, "kind": "area", "rect": _rect_list(layout.areas[key])})
	return {"size": [layout.size.x, layout.size.y], "rects": rects}


func _stations(state: GameState) -> Dictionary:
	var result := {}
	for key in state.ordered_station_keys():
		var station := state.station(key)
		result[key] = {
			"kind": station.kind,
			"department": station.dept_id,
			"shared": station.is_shared(),
			"machine": station.machine,
			"reject_pile": station.has_reject_pile(),
		}
	return result


func _constants() -> Dictionary:
	var script: GDScript = load("res://src/core/game_config.gd")
	var result := {}
	var map := script.get_script_constant_map()
	for constant_name: String in map:
		if _is_plain(map[constant_name]):
			result[constant_name] = map[constant_name]
	var config := GameConfig.new()
	for constant_name: String in UpgradeData.document().get("system", {}).get("constants", {}):
		result[constant_name] = config.get(constant_name)
	return result


func _is_plain(value: Variant) -> bool:
	if value is int or value is float or value is bool or value is String:
		return true
	if value is Array:
		for item: Variant in value:
			if not (item is int or item is float or item is bool or item is String):
				return false
		return true
	return false


func _check(entries: Array[UpgradeEntry]) -> Dictionary:
	var entry_costs := {}
	for entry in entries:
		entry_costs[entry.id] = entry.cost
	var track_costs := {}
	for upgrade_id in GameConfig.upgrade_ids():
		var max_level := int(GameConfig.upgrade(upgrade_id).max)
		var rooms: Array = GameConfig.upgrade_rooms(upgrade_id) if GameConfig.is_room_upgrade(upgrade_id) else [""]
		for room_id: String in rooms:
			var samples := []
			for level in [0, 4, 9, max_level - 1]:
				if level >= 0 and level < max_level:
					samples.append([level, Formulas.track_cost(upgrade_id, level, room_id), Formulas.track_value(upgrade_id, level)])
			track_costs[GameConfig.upgrade_key(upgrade_id, room_id)] = samples
	var rank_costs := {}
	for dept_id in GameConfig.department_ids():
		rank_costs[dept_id] = [DepartmentRank.level_cost(dept_id, 1), DepartmentRank.level_cost(dept_id, 50), DepartmentRank.fee_factor(26)]
	return {"entry_costs": entry_costs, "track_costs": track_costs, "rank_costs": rank_costs}


func _warnings(entries: Array[UpgradeEntry]) -> Array[String]:
	var result: Array[String] = []
	var placed := 0
	for room: Dictionary in UpgradeData.document().get("menu", {}).get("rooms", []):
		for group: Dictionary in room.groups:
			placed += group.entries.size()
	if placed != entries.size():
		result.append("menu holds %d entries but the catalog has %d" % [placed, entries.size()])
	return result


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
