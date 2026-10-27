class_name ComplaintVisitor
extends Carrier

enum Phase { ARRIVING, TALKING, LEAVING, STOPPED, TO_BOX }

var phase := Phase.ARRIVING
var angry := false
var files_complaint := false
var stopped := false
var dialog := 0
var slot := 0
var look := 0
var timer := 0.0
var duration := 0.0
var rage_timer := 0.0


func progress() -> float:
	if duration <= 0.0:
		return 0.0
	return clampf(1.0 - timer / duration, 0.0, 1.0)


func line() -> int:
	return mini(GameConfig.VISITOR_LINES - 1, floori(progress() * GameConfig.VISITOR_LINES))


func visitor_speaks() -> bool:
	return line() % 2 == 0


func is_stopped() -> bool:
	return stopped


func is_at_clerk() -> bool:
	return not stopped and (phase == Phase.ARRIVING or phase == Phase.TALKING)
