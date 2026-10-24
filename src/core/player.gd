class_name Player
extends Carrier

var input := Vector2.ZERO
var pad_dept := ""
var pad_progress := 0.0
var complaints := 0
var rejects := 0
var complaint_timer := 0.0
var call_progress := 0.0


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "items": items_to_dict(), "complaints": complaints, "rejects": rejects}


static func from_dict(data: Dictionary, fallback: Vector2) -> Player:
	var player := Player.new(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	player.items = Carrier.items_from(data.get("items", []))
	player.complaints = maxi(0, int(data.get("complaints", 0)))
	player.rejects = maxi(0, int(data.get("rejects", 0)))
	return player
