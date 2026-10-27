class_name ComplaintIntern
extends Carrier

enum Mood { DESK, TO_LOO, CRYING, RETURNING, TO_BOX, TO_SHREDDER, FROM_SHREDDER }

var mood := Mood.DESK
var handled := 0
var carried := 0
var comfort_progress := 0.0
var slot := 0


func is_at_desk() -> bool:
	return mood == Mood.DESK


func is_away() -> bool:
	return mood == Mood.TO_LOO or mood == Mood.CRYING


func is_running() -> bool:
	return mood == Mood.TO_BOX or mood == Mood.TO_SHREDDER or mood == Mood.FROM_SHREDDER


func to_dict() -> Dictionary:
	return {"x": position.x, "y": position.y, "mood": mood, "handled": handled}


static func from_dict(data: Variant, fallback: Vector2, p_slot: int = 0) -> ComplaintIntern:
	var intern := ComplaintIntern.new(fallback)
	intern.slot = p_slot
	if not data is Dictionary:
		return intern
	intern.position = WorldLayout.get_default().clamp_to_world(Vector2(float(data.get("x", fallback.x)), float(data.get("y", fallback.y))))
	var saved_mood := int(data.get("mood", Mood.DESK))
	intern.mood = saved_mood if Mood.values().has(saved_mood) else Mood.DESK
	intern.handled = clampi(int(data.get("handled", 0)), 0, GameConfig.INTERN_MAX_STEADFAST)
	if intern.is_running():
		intern.mood = Mood.RETURNING
	return intern
