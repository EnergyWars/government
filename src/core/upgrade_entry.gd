class_name UpgradeEntry
extends RefCounted

var id := ""
var kind := ""
var spot := ""
var room := ""
var topic := ""
var target := ""
var room_id := ""
var index := -1
var level := 0
var max_level := 1
var cost := 0.0
var growth := 1.0
var single := false
var reason := ""


func remaining() -> int:
	return 1 if single and level < max_level else maxi(0, max_level - level)


func is_maxed() -> bool:
	return level >= max_level


func is_buyable() -> bool:
	return reason.is_empty()


func amount_for(count: int) -> int:
	return clampi(count, 0, remaining())


func bulk_cost(count: int) -> float:
	return Formulas.geometric_sum(cost, growth, amount_for(count))


func affordable(money: float) -> int:
	return Formulas.geometric_affordable(cost, growth, remaining(), money)
