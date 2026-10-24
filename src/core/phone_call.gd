class_name PhoneCall
extends RefCounted

const INCOMING := "incoming"
const OUTGOING := "outgoing"
const NONE := -1
const PLAYER := -2

var kind := INCOMING
var key := ""
var desk := 0
var ring := 0.0
var line := NONE
var progress := 0.0


func _init(p_kind: String, p_key: String, p_desk: int, p_ring: float = 0.0) -> void:
	kind = p_kind
	key = p_key
	desk = p_desk
	ring = p_ring


func is_incoming() -> bool:
	return kind == INCOMING


func is_ringing() -> bool:
	return line == NONE


func by_player() -> bool:
	return line == PLAYER


func duration() -> float:
	if by_player():
		return GameConfig.CALL_TIME
	return GameConfig.HR_ANSWER_SECONDS if is_incoming() else GameConfig.HR_CALL_SECONDS


func ratio() -> float:
	return clampf(progress / duration(), 0.0, 1.0)


func targets(p_key: String, p_desk: int) -> bool:
	return key == p_key and desk == p_desk
