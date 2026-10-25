class_name Tutorial
extends RefCounted

signal changed

const FINISHED := -1
const MOVE_DISTANCE := 200.0
const STEP_SKIP_DELAY := 20.0

const INFO := "info"
const MOVE := "move"
const SHEET := "sheet"
const STAT := "stat"

const STEPS := [
	{"id": "welcome", "kind": INFO, "target": ""},
	{"id": "move", "kind": MOVE, "target": ""},
	{"id": "resources", "kind": INFO, "target": ""},
	{"id": "arrow", "kind": INFO, "target": ""},
	{"id": "first_case", "kind": STAT, "stat": "cases", "amount": 1, "target": ""},
	{"id": "queue", "kind": INFO, "target": ""},
	{"id": "goal", "kind": STAT, "stat": "goals", "amount": 1, "target": "goal"},
	{"id": "tasks", "kind": INFO, "target": ""},
	{"id": "upgrades_open", "kind": SHEET, "sheet": "upgrades", "target": "upgrades"},
	{"id": "upgrade_groups", "kind": INFO, "target": ""},
	{"id": "hire", "kind": STAT, "stat": "staff", "amount": 1, "target": ""},
	{"id": "runner", "kind": STAT, "stat": "runners", "amount": 1, "target": ""},
	{"id": "upgrade", "kind": STAT, "stat": "levels", "amount": 1, "target": ""},
	{"id": "spot_open", "kind": SHEET, "sheet": "spot", "target": ""},
	{"id": "spots_info", "kind": INFO, "target": ""},
	{"id": "work_modes", "kind": INFO, "target": ""},
	{"id": "boards_info", "kind": INFO, "target": ""},
	{"id": "expand_info", "kind": INFO, "target": ""},
	{"id": "wake", "kind": INFO, "target": ""},
	{"id": "events", "kind": INFO, "target": ""},
	{"id": "offline", "kind": INFO, "target": ""},
	{"id": "goals_open", "kind": SHEET, "sheet": "goals", "target": "goals"},
	{"id": "settings_open", "kind": SHEET, "sheet": "settings", "target": "settings"},
	{"id": "finish", "kind": INFO, "target": ""},
]

var state: GameState
var _entered := -2
var _baseline := 0.0
var _origin := Vector2.ZERO
var _open_sheet := ""
var _elapsed := 0.0
var _skip_offered := false


func _init(p_state: GameState) -> void:
	state = p_state


static func is_valid_index(index: int) -> bool:
	return index >= 0 and index < STEPS.size()


static func clamp_saved(index: int) -> int:
	return index if is_valid_index(index) else FINISHED


static func index_of(step_id: String) -> int:
	for index in STEPS.size():
		if str(STEPS[index].id) == step_id:
			return index
	return FINISHED


func is_active() -> bool:
	return is_valid_index(state.tutorial_step)


func index() -> int:
	return state.tutorial_step


func count() -> int:
	return STEPS.size()


func current() -> Dictionary:
	return STEPS[state.tutorial_step] if is_active() else {}


func is_info() -> bool:
	return current().get("kind", "") == INFO


func is_last() -> bool:
	return state.tutorial_step == STEPS.size() - 1


func open_sheet() -> String:
	return _open_sheet


func set_open_sheet(sheet_id: String) -> void:
	if _open_sheet == sheet_id:
		return
	_open_sheet = sheet_id
	changed.emit()


func can_skip_step() -> bool:
	return is_active() and not is_info() and _entered == state.tutorial_step and _elapsed >= STEP_SKIP_DELAY


func can_advance() -> bool:
	return is_info() or can_skip_step()


func update(delta: float = 0.0) -> void:
	while is_active():
		if _entered != state.tutorial_step:
			_enter()
		if not (_is_complete() or _is_blocked()):
			break
		_go_to(state.tutorial_step + 1)
	if not is_active():
		return
	_elapsed += delta
	if not _skip_offered and can_skip_step():
		_skip_offered = true
		changed.emit()


func advance() -> bool:
	if not can_advance():
		return false
	_go_to(state.tutorial_step + 1)
	return true


func skip() -> void:
	if is_active():
		_go_to(FINISHED)


func restart() -> void:
	_go_to(0)


func _go_to(index: int) -> void:
	state.tutorial_step = index if is_valid_index(index) else FINISHED
	_entered = -2
	changed.emit()


func _enter() -> void:
	_entered = state.tutorial_step
	_elapsed = 0.0
	_skip_offered = false
	_origin = state.player.position
	_baseline = _stat(str(current().get("stat", "")))


func _is_complete() -> bool:
	var step := current()
	match str(step.kind):
		MOVE:
			return state.player.position.distance_to(_origin) >= MOVE_DISTANCE
		SHEET:
			return _open_sheet == str(step.sheet)
		STAT:
			return _stat(str(step.stat)) - _baseline >= float(step.amount)
	return false


func _is_blocked() -> bool:
	var step := current()
	return str(step.get("kind", "")) == STAT and not _can_progress(str(step.stat))


func _can_progress(stat_id: String) -> bool:
	match stat_id:
		"goals":
			return state.goal_index < GameConfig.GOALS.size()
		"runners":
			return state.runners.size() < GameConfig.MAX_RUNNERS
		"levels":
			return state.stations.values().any(func(station: Station) -> bool: return station.level < GameConfig.MAX_STATION_LEVEL)
		"staff":
			return state.runners.size() < GameConfig.MAX_RUNNERS or state.stations.values().any(_has_room_for_staff)
	return true


func _has_room_for_staff(station: Station) -> bool:
	return not station.machine and (station.staff < station.desks or station.desks < state.max_desks())


func _stat(stat_id: String) -> float:
	match stat_id:
		"cases":
			return state.cases_completed
		"goals":
			return state.goal_index
		"staff":
			return state.staff_hired
		"runners":
			return state.runners.size()
		"levels":
			var total := 0
			for key in state.stations:
				total += state.stations[key].level
			return total
	return 0.0
