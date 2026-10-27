class_name MilestoneLadder
extends RefCounted

const MAX_STEPS := 64

var first: float
var mantissas: Array[float]
var reached := -1


func _init(p_first: float, p_mantissas: Array[float]) -> void:
	first = maxf(p_first, 0.0001)
	mantissas = p_mantissas.duplicate()
	if mantissas.is_empty():
		mantissas.append(1.0)


func value_at(index: int) -> float:
	if index < 0:
		return 0.0
	var steps := mantissas.size()
	return first * mantissas[index % steps] * pow(10.0, float(index / steps))


func index_of(value: float) -> int:
	var index := -1
	while index + 1 < MAX_STEPS and value_at(index + 1) <= value:
		index += 1
	return index


func start(value: float) -> void:
	reached = index_of(value)


func update(value: float) -> float:
	var index := index_of(value)
	if index <= reached:
		return 0.0
	reached = index
	return value_at(index)
