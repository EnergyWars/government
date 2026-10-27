class_name SaveMigration
extends RefCounted

const LEVEL_SCALES := {
	"briefcase": 2.0,
	"work_ethic": 20.0,
	"coffee": 35.0,
	"scanners": 30.0,
	"digital_records": 20.0,
	"quality_training": 28.6,
	"coffee_machine": 22.0,
	"kitchen": 60.0,
	"it_support": 25.0,
	"digital_signatures": 40.0,
	"pneumatic_tubes": 1.0,
	"tube_capacity": 2.0,
	"intern_training": 1.0,
	"ai_classification": 99.0,
	"letter_opener": 40.0,
	"mail_subscription": 2.0,
	"registered_mail": 20.0,
}
const LEVEL_STEPS := {
	"shredder_service": [0, 1, 47, 107],
	"climate_control": [0, 25, 60],
	"mediation": [0, 1, 47, 105],
	"wake_service": [0, 1, 25, 52, 87, 135],
	"complaint_tube": [0, 1, 28, 55],
}
const SPLITS := {
	"trolleys": ["runner_trolleys", "collector_carts"],
}
const DERIVED := {
	"coffee_machine": {"espresso": 50.0},
	"intern_training": {"intern_resilience": 19.0},
}
const CLERK_STEPS: Array[int] = [0, 19, 38, 57, 75, 94]
const TICKET_SCALE := 13.1
const BOX_SCALE := 10
const STORAGE_SCALE := 8
const TUBE_LEVEL_SCALE := 2
const TRAINING_SCALE := 10
const LEGACY_RANK_FEE_FACTOR := 2.5
const LEGACY_MAX_RANK := 10
const LEGACY_TUTORIAL: Array[String] = [
	"welcome", "move", "resources", "arrow", "first_case", "queue", "goal", "tasks", "team_open", "hire", "runner", "upgrade",
	"department_open", "work_modes", "research_open", "research_info", "building_open", "building_info", "departments_open",
	"departments_info", "wake", "events", "offline", "goals_open", "settings_open", "finish",
]
const RENAMED_TUTORIAL := {
	"team_open": "upgrades_open",
	"department_open": "spot_open",
	"research_open": "spots_info",
	"research_info": "spots_info",
	"building_open": "expand_info",
	"building_info": "expand_info",
	"departments_open": "expand_info",
	"departments_info": "expand_info",
}
const V3_REMOVED_UPGRADES: Array[String] = ["shredder_service", "intern_training", "intern_resilience", "complaint_tube", "complaint_clerk", "guard_training"]
const V3_REMOVED_KEYS: Array[String] = ["intern", "helpers", "guards", "complaints_fended"]
const RESILIENCE_PER_STEADFAST := 25
const LEGACY_GUARD_CHANCE := 0.35
const LEGACY_GUARD_STEP := 0.003
const LEGACY_GUARD_LEVELS := 150
const REMOVED_KEYS: Array[String] = ["research", "waiting_level", "seating_level", "ticket_machine_level", "ticket_display_level", "complaint_clerk_level", "complaint_box_level"]


static func migrate_v2(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var research := _dictionary(data.get("research"))
	var upgrades := {}
	for research_id in research:
		_convert_research(upgrades, str(research_id), int(research[research_id]))
	var box := maxi(int(data.get("complaint_box_level", 0)), int(research.get("complaint_desk", 0)))
	_raise(upgrades, "complaint_box", box * BOX_SCALE)
	_raise(upgrades, "seating", seats_for_level(int(data.get("seating_level", 0))))
	_raise(upgrades, "ticket_speed", roundi(int(data.get("ticket_machine_level", 0)) * TICKET_SCALE))
	_raise(upgrades, "complaint_clerk", CLERK_STEPS[clampi(int(data.get("complaint_clerk_level", 0)), 0, CLERK_STEPS.size() - 1)])
	_migrate_tubes(result, upgrades, int(research.get("pneumatic_tubes", 0)) > 0)
	_migrate_stations(result)
	_migrate_tube_levels(result)
	result["tutorial_step"] = tutorial_step(int(data.get("tutorial_step", Tutorial.FINISHED)))
	for key in REMOVED_KEYS:
		result.erase(key)
	result["upgrades"] = upgrades
	result["version"] = GameState.PREVIOUS_SAVE_VERSION
	return result


static func migrate_v3(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	var upgrades := _dictionary(result.get("upgrades"))
	var helpers: Variant = data.get("helpers", [])
	var helper_count: int = helpers.size() if helpers is Array else 0
	var interns := 0
	if int(upgrades.get("shredder_service", 0)) > 0:
		interns = mini(GameConfig.MAX_DESK_INTERNS, 1 + helper_count)
	_raise(upgrades, "complaint_interns", interns)
	_raise(upgrades, "intern_steadfast", mini(int(GameConfig.upgrade("intern_steadfast").max), floori(int(upgrades.get("intern_resilience", 0)) / float(RESILIENCE_PER_STEADFAST))))
	if interns >= 2:
		_raise(upgrades, "intern_box_runs", mini(GameConfig.MAX_INTERN_RUN, int(upgrades.get("intern_training", 0)) + 1))
	var box := mini(GameConfig.COMPLAINT_BOX_LEVELS, ceili(int(upgrades.get("complaint_box", 0)) / float(GameConfig.COMPLAINT_BOX_STEP)))
	upgrades.erase("complaint_box")
	_raise(upgrades, "complaint_box", box)
	var guards := maxi(0, int(data.get("guards", 0)))
	if guards > 0:
		upgrades["complaint_security"] = 1
		_raise(upgrades, "security_training", security_level(guards, int(upgrades.get("guard_training", 0))))
	for key in V3_REMOVED_UPGRADES:
		upgrades.erase(key)
	for key in V3_REMOVED_KEYS:
		result.erase(key)
	result["upgrades"] = upgrades
	result["version"] = GameState.SAVE_VERSION
	return result


static func split_seating(upgrades: Dictionary) -> Dictionary:
	var result := upgrades.duplicate()
	var level := int(result.get("seating", 0))
	var limit := int(GameConfig.upgrade("seating").max)
	if level > limit:
		result["seating"] = limit
		result["pickup_seating"] = mini(limit, maxi(int(result.get("pickup_seating", 0)), level - limit))
	return result


static func security_level(guards: int, training: int) -> int:
	var single := LEGACY_GUARD_CHANCE + LEGACY_GUARD_STEP * clampi(training, 0, LEGACY_GUARD_LEVELS)
	var combined := 1.0 - pow(1.0 - single, maxi(0, guards))
	var step := float(GameConfig.upgrade("security_training").step)
	return clampi(roundi((combined - GameConfig.SECURITY_BASE_CHANCE) / step), 0, GameConfig.SECURITY_LEVELS)


static func tutorial_step(legacy: int) -> int:
	if legacy < 0 or legacy >= LEGACY_TUTORIAL.size():
		return Tutorial.FINISHED
	var step_id := LEGACY_TUTORIAL[legacy]
	return Tutorial.index_of(str(RENAMED_TUTORIAL.get(step_id, step_id)))


static func seats_for_level(level: int) -> int:
	var clamped := maxi(0, level)
	return clamped * 3 + roundi(clamped * (clamped - 1) * 0.5)


static func _convert_research(upgrades: Dictionary, research_id: String, level: int) -> void:
	if level <= 0:
		return
	if LEVEL_STEPS.has(research_id):
		var steps: Array = LEVEL_STEPS[research_id]
		_raise(upgrades, research_id, int(steps[clampi(level, 0, steps.size() - 1)]))
	elif SPLITS.has(research_id):
		for target: String in SPLITS[research_id]:
			_raise(upgrades, target, level)
	elif LEVEL_SCALES.has(research_id):
		_raise(upgrades, research_id, roundi(level * float(LEVEL_SCALES[research_id])))
	var derived: Dictionary = DERIVED.get(research_id, {})
	for target: String in derived:
		_raise(upgrades, target, roundi(level * float(derived[target])))


static func _raise(upgrades: Dictionary, key: String, level: int) -> void:
	if level > 0:
		upgrades[key] = maxi(int(upgrades.get(key, 0)), level)


static func _migrate_tubes(result: Dictionary, upgrades: Dictionary, legacy_tube: bool) -> void:
	var departments := _dictionary(result.get("departments"))
	var piped := false
	var inspection := false
	for dept_id in departments:
		var entry := _dictionary(departments[dept_id])
		var config := GameConfig.department(str(dept_id))
		if config.is_empty():
			continue
		var connected := bool(entry.get("unlocked", false)) and bool(entry.get("tube", legacy_tube))
		entry.erase("tube")
		if not connected:
			continue
		piped = true
		inspection = inspection or bool(config.inspection) or GameConfig.is_customs(str(dept_id))
		upgrades[GameConfig.upgrade_key("tube_station", str(dept_id))] = 1
	if not piped:
		return
	upgrades["pneumatic_tubes"] = 1
	upgrades["large_capsules"] = 1
	upgrades[GameConfig.upgrade_key("tube_station", GameConfig.ROOM_HALL)] = 1
	upgrades[GameConfig.upgrade_key("tube_station", GameConfig.ROOM_MAIL)] = 1
	if inspection:
		upgrades[GameConfig.upgrade_key("tube_station", GameConfig.ROOM_INSPECTION)] = 1


static func _migrate_stations(result: Dictionary) -> void:
	var stations := _dictionary(result.get("stations"))
	for key in stations:
		var entry := _dictionary(stations[key])
		if str(key) == GameConfig.MAILROOM:
			entry["storage_level"] = int(entry.get("storage_level", 0)) * STORAGE_SCALE
		var moods: Variant = entry.get("moods")
		if not moods is Array:
			continue
		for mood: Variant in moods:
			var training := _dictionary(_dictionary(mood).get("training"))
			for track in training:
				training[track] = int(training[track]) * TRAINING_SCALE


static func _migrate_tube_levels(result: Dictionary) -> void:
	var levels := _dictionary(result.get("tube_levels"))
	for tube_id in levels:
		levels[tube_id] = int(levels[tube_id]) * TUBE_LEVEL_SCALE


static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func legacy_rank_level(rank: int) -> int:
	var target := pow(LEGACY_RANK_FEE_FACTOR, clampi(rank, 1, LEGACY_MAX_RANK) - 1)
	for level in range(1, GameConfig.MAX_DEPARTMENT_RANK + 1):
		if DepartmentRank.fee_factor(level) >= target * (1.0 - 1e-9):
			return level
	return GameConfig.MAX_DEPARTMENT_RANK
