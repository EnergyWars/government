class_name DeskMood
extends RefCounted

const AWAKE := "awake"
const ASLEEP := "asleep"
const COFFEE := "coffee"
const CHAT := "chat"
const FETCH := "fetch"
const SLOW := "slow"
const SICK := "sick"
const LOO := "loo"
const STATES: Array[String] = [AWAKE, ASLEEP, COFFEE, CHAT, FETCH, SLOW, SICK, LOO]

var state := AWAKE
var alert := GameConfig.BASE_ALERT_SECONDS
var resting := 0.0
var wake_progress := 0.0
var slot := -1
var left_slot := -1


static func is_away_state(p_state: String) -> bool:
	return p_state == CHAT or p_state == FETCH or p_state == SLOW or p_state == LOO


func is_resting() -> bool:
	return state != AWAKE


func is_away() -> bool:
	return is_away_state(state)


func is_sick() -> bool:
	return state == SICK


func is_absent() -> bool:
	return is_away() or is_sick()


func needs_help() -> bool:
	return state == ASLEEP or state == COFFEE or state == CHAT or state == SLOW


func rest(p_state: String, p_slot: int = -1) -> void:
	state = p_state
	resting = 0.0
	wake_progress = 0.0
	slot = p_slot if is_away() else -1


func wake(p_alert: float) -> void:
	left_slot = slot if is_away() else -1
	state = AWAKE
	resting = 0.0
	wake_progress = 0.0
	slot = -1
	alert = p_alert


func to_dict() -> Dictionary:
	return {"state": state, "alert": alert, "resting": resting, "slot": slot}


static func from_dict(data: Variant) -> DeskMood:
	var mood := DeskMood.new()
	if not data is Dictionary:
		return mood
	var saved_state := str(data.get("state", AWAKE))
	mood.state = saved_state if STATES.has(saved_state) else AWAKE
	mood.alert = clampf(float(data.get("alert", GameConfig.BASE_ALERT_SECONDS)), 0.0, GameConfig.MAX_ALERT_SECONDS)
	mood.resting = maxf(0.0, float(data.get("resting", 0.0)))
	mood.slot = clampi(int(data.get("slot", -1)), -1, GameConfig.KITCHEN_SLOTS + GameConfig.LOO_SLOTS - 1) if mood.is_away() else -1
	return mood
