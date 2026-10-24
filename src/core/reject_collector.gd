class_name RejectCollector
extends Carrier

var source := ""
var loaded := 0


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "loaded": loaded}


static func from_dict(data: Dictionary, fallback: Vector2) -> RejectCollector:
	var collector := RejectCollector.new(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	collector.loaded = clampi(int(data.get("loaded", 0)), 0, Formulas.collector_capacity_limit())
	return collector
