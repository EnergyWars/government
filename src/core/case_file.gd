class_name CaseFile
extends RefCounted

enum Phase { NONE, LINE, WAITING, CALLED, SERVED, WAITING_DOC, CALLED_DOC, COLLECTING, CALLED_PHOTO, PHOTO }

var dept_id: String
var complex: bool
var urgent: bool
var suspicious: bool
var variant := ""
var follow_up := false
var route: Array[String] = []
var step := 0
var flawed := false
var flagged := false
var scanned := false
var contraband := false
var produced := false
var invalid := false
var big := false
var mail := false
var companion := false
var extras: Array[String] = []
var age := 0.0
var waited := 0.0
var handled := 0
var ticket := 0
var walk := 0.0
var draw_progress := 0.0
var line_slot := -1
var machine := -1
var phase := Phase.NONE
var place := -1
var seated := false
var desk := -1
var spot := Vector2.ZERO
var abandoned := false
var raged := false


func _init(p_dept_id: String = "", p_complex: bool = false, p_urgent: bool = false, p_suspicious: bool = false) -> void:
	dept_id = p_dept_id
	complex = p_complex
	urgent = p_urgent
	suspicious = p_suspicious


func current_key() -> String:
	return route[step] if step < route.size() else ""


func next_key() -> String:
	return route[step + 1] if step + 1 < route.size() else ""


func is_final_step() -> bool:
	return step >= route.size() - 1


func needs_inspection() -> bool:
	return route.find(GameConfig.INSPECTION, step + 1) > step


func needs_referral() -> bool:
	var referral := str(GameConfig.department(dept_id).get("referral", ""))
	return not referral.is_empty() and route.find(referral, step + 1) > step


func is_overdue() -> bool:
	return urgent and age > GameConfig.URGENT_DEADLINE


func has_citizen() -> bool:
	return phase != Phase.NONE


func is_before_reception() -> bool:
	return phase == Phase.LINE or phase == Phase.WAITING or phase == Phase.CALLED


func waits_for_pickup() -> bool:
	return phase == Phase.WAITING_DOC or phase == Phase.CALLED_DOC or is_at_photo()


func is_at_photo() -> bool:
	return phase == Phase.CALLED_PHOTO or phase == Phase.PHOTO


func waiting_room() -> String:
	return GameConfig.HALL_PICKUP if phase == Phase.WAITING_DOC or is_at_photo() else GameConfig.HALL_INTAKE


func is_in_hall() -> bool:
	return place >= 0 and (phase == Phase.WAITING or phase == Phase.WAITING_DOC)


func takes_seat() -> bool:
	return not mail and not companion and not GameConfig.is_customs(dept_id)


func remove_from_route(key: String) -> void:
	var index := route.find(key, step + 1)
	if index > step:
		route.remove_at(index)


func insert_before(key: String, before: String) -> void:
	var index := route.find(before, step + 1)
	if index > step and not route.slice(step + 1).has(key):
		route.insert(index, key)


func to_dict() -> Dictionary:
	return {
		"dept": dept_id,
		"complex": complex,
		"urgent": urgent,
		"suspicious": suspicious,
		"variant": variant,
		"follow_up": follow_up,
		"route": route.duplicate(),
		"step": step,
		"flawed": flawed,
		"flagged": flagged,
		"scanned": scanned,
		"contraband": contraband,
		"produced": produced,
		"invalid": invalid,
		"big": big,
		"mail": mail,
		"companion": companion,
		"extras": extras.duplicate(),
		"age": age,
		"waited": waited,
		"handled": handled,
		"ticket": ticket,
	}


static func from_dict(data: Dictionary) -> CaseFile:
	var case_file := CaseFile.new(
		str(data.get("dept", "")),
		bool(data.get("complex", false)),
		bool(data.get("urgent", false)),
		bool(data.get("suspicious", false)),
	)
	case_file.variant = str(data.get("variant", ""))
	case_file.follow_up = bool(data.get("follow_up", false))
	for key in data.get("route", []):
		case_file.route.append(str(key))
	case_file.step = clampi(int(data.get("step", 0)), 0, maxi(0, case_file.route.size() - 1))
	case_file.flawed = bool(data.get("flawed", false))
	case_file.flagged = bool(data.get("flagged", false))
	case_file.scanned = bool(data.get("scanned", false))
	case_file.contraband = bool(data.get("contraband", false))
	case_file.produced = bool(data.get("produced", false))
	case_file.invalid = bool(data.get("invalid", false))
	case_file.big = bool(data.get("big", false))
	case_file.mail = bool(data.get("mail", false))
	case_file.companion = bool(data.get("companion", false))
	for extra in data.get("extras", []):
		var extra_id := str(extra)
		if not GameConfig.department(extra_id).is_empty() and not GameConfig.is_customs(extra_id) and case_file.extras.size() < GameConfig.MULTI_MAX_EXTRAS:
			case_file.extras.append(extra_id)
	case_file.age = float(data.get("age", 0.0))
	case_file.waited = float(data.get("waited", 0.0))
	case_file.handled = maxi(0, int(data.get("handled", 0)))
	case_file.ticket = maxi(0, int(data.get("ticket", 0)))
	return case_file
