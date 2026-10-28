class_name Runner
extends Carrier

enum Task { IDLE, TO_SOURCE, TO_TARGET }

const INTAKE := "intake"
const INTERNAL := "internal"
const OUTPUT := "output"
const REJECT := "reject"
const DEPOSIT := "deposit"
const CASE_ROLES: Array[String] = [INTAKE, INTERNAL, OUTPUT]
const ROLES: Array[String] = [INTAKE, INTERNAL, OUTPUT, REJECT, DEPOSIT]
const ALL_DEPARTMENTS := ""

var task := Task.IDLE
var source := ""
var target := ""
var reserved := 0
var role := INTAKE
var dept_id := ALL_DEPARTMENTS
var level := 0
var loaded := 0
var complaints_loaded := 0


func clear_task() -> void:
	task = Task.IDLE
	source = ""
	target = ""
	reserved = 0


func is_reject() -> bool:
	return role == REJECT


func is_deposit() -> bool:
	return role == DEPOSIT


func carries_waste() -> bool:
	return loaded > 0 or complaints_loaded > 0


func reset_route() -> void:
	if task == Task.TO_SOURCE or task == Task.IDLE:
		clear_task()


func serves_rejects_of(station_dept: String) -> bool:
	return dept_id == ALL_DEPARTMENTS or station_dept == dept_id


static func role_for(source_key: String, target_key: String) -> String:
	if target_key == GameConfig.COUNTER:
		return OUTPUT
	if source_key == GameConfig.RECEPTION or source_key == GameConfig.MAILROOM or GameConfig.station_kind_of(source_key) == "dock":
		return INTAKE
	return INTERNAL


func serves(case_file: CaseFile, source_key: String) -> bool:
	if dept_id != ALL_DEPARTMENTS and case_file.dept_id != dept_id:
		return false
	return role_for(source_key, case_file.next_key()) == role


static func restore_department(value: Variant) -> String:
	var saved := str(value)
	return saved if GameConfig.department_ids().has(saved) else ALL_DEPARTMENTS


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "items": items_to_dict(), "target": target if not items.is_empty() else "", "role": role, "dept": dept_id, "level": level, "loaded": loaded, "complaints_loaded": complaints_loaded}


static func from_dict(data: Dictionary, fallback: Vector2) -> Runner:
	var runner := Runner.new(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	runner.items = Carrier.items_from(data.get("items", []))
	if not runner.items.is_empty():
		runner.task = Task.TO_TARGET
		runner.target = str(data.get("target", runner.items[0].next_key()))
	var saved_role := str(data.get("role", ""))
	runner.role = saved_role if ROLES.has(saved_role) else ""
	runner.dept_id = restore_department(data.get("dept", ALL_DEPARTMENTS))
	runner.level = clampi(int(data.get("level", 0)), 0, GameConfig.MAX_RUNNER_LEVEL)
	runner.loaded = clampi(int(data.get("loaded", 0)), 0, Formulas.runner_load_limit(runner.level))
	runner.complaints_loaded = clampi(int(data.get("complaints_loaded", 0)), 0, Formulas.runner_load_limit(runner.level))
	return runner
