class_name Runner
extends Carrier

enum Task { IDLE, TO_SOURCE, TO_TARGET }

var task := Task.IDLE
var source := ""
var target := ""
var reserved := 0


func clear_task() -> void:
	task = Task.IDLE
	source = ""
	target = ""
	reserved = 0


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "items": items_to_dict(), "target": target if not items.is_empty() else ""}


static func from_dict(data: Dictionary, fallback: Vector2) -> Runner:
	var runner := Runner.new(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	runner.items = Carrier.items_from(data.get("items", []))
	if not runner.items.is_empty():
		runner.task = Task.TO_TARGET
		runner.target = str(data.get("target", runner.items[0].next_key()))
	return runner
