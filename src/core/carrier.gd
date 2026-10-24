class_name Carrier
extends RefCounted

var position := Vector2.ZERO
var items: Array[CaseFile] = []
var transfer_timer := 0.0


func _init(p_position: Vector2 = Vector2.ZERO) -> void:
	position = p_position


func move_towards(target: Vector2, speed: float, delta: float) -> bool:
	position = position.move_toward(target, speed * delta)
	return position.distance_to(target) < 1.0


func items_for(key: String) -> Array[CaseFile]:
	var result: Array[CaseFile] = []
	for item in items:
		if item.next_key() == key:
			result.append(item)
	return result


func items_to_dict() -> Array:
	return items.map(func(c: CaseFile) -> Dictionary: return c.to_dict())


static func items_from(data: Array) -> Array[CaseFile]:
	var result: Array[CaseFile] = []
	for entry in data:
		if entry is Dictionary:
			result.append(CaseFile.from_dict(entry))
	return result
