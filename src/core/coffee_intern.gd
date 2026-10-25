class_name CoffeeIntern
extends Carrier

enum Task { IDLE, TO_MACHINE, BREWING, TO_DESK }

var task := Task.IDLE
var key := ""
var desk := -1
var carrying := false
var brew := 0.0
var search_timer := 0.0
var dept_id := Runner.ALL_DEPARTMENTS


func clear_task() -> void:
	task = Task.IDLE
	key = ""
	desk = -1
	brew = 0.0


func targets(p_key: String, p_desk: int) -> bool:
	return key == p_key and desk == p_desk


func serves(station_dept: String) -> bool:
	return dept_id == Runner.ALL_DEPARTMENTS or station_dept == dept_id


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "carrying": carrying, "dept": dept_id}


static func from_dict(data: Dictionary, fallback: Vector2) -> CoffeeIntern:
	var intern := CoffeeIntern.new(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	intern.carrying = bool(data.get("carrying", false))
	intern.dept_id = Runner.restore_department(data.get("dept", Runner.ALL_DEPARTMENTS))
	return intern
