class_name RejectCollector
extends Carrier

var source := ""
var loaded := 0
var dept_id := Runner.ALL_DEPARTMENTS


func serves(station_dept: String) -> bool:
	return dept_id == Runner.ALL_DEPARTMENTS or station_dept == dept_id


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "loaded": loaded, "dept": dept_id}


static func from_dict(data: Dictionary, fallback: Vector2) -> RejectCollector:
	var collector := RejectCollector.new(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	collector.loaded = clampi(int(data.get("loaded", 0)), 0, Formulas.collector_capacity_limit())
	collector.dept_id = Runner.restore_department(data.get("dept", Runner.ALL_DEPARTMENTS))
	return collector
