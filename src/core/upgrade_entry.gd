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
var price_level := -1
var single := false
var cap := -1
var reason := ""


func remaining() -> int:
	if single:
		return 1 if level < max_level else 0
	var top := max_level if cap < 0 else mini(max_level, cap)
	return maxi(0, top - level)


func is_maxed() -> bool:
	return level >= max_level


func is_buyable() -> bool:
	return reason.is_empty()


func amount_for(count: int) -> int:
	return clampi(count, 0, remaining())


func bulk_cost(count: int) -> float:
	if price_level < 0:
		return Formulas.geometric_sum(cost, growth, amount_for(count))
	return Formulas.ramped_sum(cost, growth, price_level, amount_for(count))


func affordable(money: float) -> int:
	if price_level < 0:
		return Formulas.geometric_affordable(cost, growth, remaining(), money)
	return Formulas.ramped_affordable(cost, growth, price_level, remaining(), money)
