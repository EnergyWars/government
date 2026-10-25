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
var reported := false
var bonus := 0
var training := {}
var output := RateCounter.new()
var sick_count := 0
var doze_count := 0


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


func can_be_called() -> bool:
	return is_sick() and reported


func needs_help() -> bool:
	return state == ASLEEP or state == COFFEE or state == CHAT or state == SLOW or state == LOO


func rest(p_state: String, p_slot: int = -1) -> void:
	state = p_state
	resting = 0.0
	wake_progress = 0.0
	reported = false
	bonus = 0
	slot = p_slot if is_away() else -1


func wake(p_alert: float) -> void:
	left_slot = slot if is_away() else -1
	state = AWAKE
	resting = 0.0
	wake_progress = 0.0
	slot = -1
	reported = false
	bonus = 0
	alert = p_alert


func training_level(track: String) -> int:
	return int(training.get(track, 0))


func can_train(track: String) -> bool:
	return GameConfig.OFFICIAL_TRAININGS.has(track) and training_level(track) < GameConfig.MAX_OFFICIAL_TRAINING


func train(track: String) -> void:
	if can_train(track):
		training[track] = training_level(track) + 1


func training_total() -> int:
	var total := 0
	for track: String in training:
		total += int(training[track])
	return total


func to_dict() -> Dictionary:
	return {"state": state, "alert": alert, "resting": resting, "slot": slot, "reported": reported, "bonus": bonus, "training": training.duplicate()}


static func from_dict(data: Variant) -> DeskMood:
	var mood := DeskMood.new()
	if not data is Dictionary:
		return mood
	var saved_state := str(data.get("state", AWAKE))
	mood.state = saved_state if STATES.has(saved_state) else AWAKE
	mood.alert = clampf(float(data.get("alert", GameConfig.BASE_ALERT_SECONDS)), 0.0, GameConfig.MAX_ALERT_SECONDS)
	mood.resting = maxf(0.0, float(data.get("resting", 0.0)))
	mood.reported = bool(data.get("reported", true)) and mood.is_sick()
	mood.bonus = clampi(int(data.get("bonus", 0)), 0, GameConfig.sick_bonus_tiers()) if mood.is_sick() else 0
	var saved_training: Variant = data.get("training", {})
	if saved_training is Dictionary:
		for track: String in GameConfig.OFFICIAL_TRAININGS:
			var level := clampi(int(saved_training.get(track, 0)), 0, GameConfig.MAX_OFFICIAL_TRAINING)
			if level > 0:
				mood.training[track] = level
	if mood.state == LOO:
		mood.slot = clampi(int(data.get("slot", -1)), GameConfig.KITCHEN_SLOTS, GameConfig.KITCHEN_SLOTS + GameConfig.MAX_LOO_SLOTS - 1)
	elif mood.is_away():
		mood.slot = clampi(int(data.get("slot", -1)), -1, GameConfig.KITCHEN_SLOTS - 1)
	else:
		mood.slot = -1
	return mood
