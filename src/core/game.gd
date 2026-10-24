class_name Game
extends RefCounted

signal changed

var state: GameState
var simulation: Simulation
var actions: GameActions
var goals: GoalTracker
var tutorial: Tutorial
const CHANGE_INTERVAL := 0.1

var _accumulator := 0.0
var _since_change := CHANGE_INTERVAL


func _init(p_state: GameState) -> void:
	state = p_state
	simulation = Simulation.new(state)
	actions = GameActions.new(state, simulation)
	goals = GoalTracker.new(state)
	tutorial = Tutorial.new(state)


func advance(delta: float) -> int:
	_accumulator += delta
	var steps := 0
	while _accumulator >= GameConfig.TICK and steps < GameConfig.MAX_STEPS_PER_FRAME:
		simulation.tick(GameConfig.TICK)
		_accumulator -= GameConfig.TICK
		steps += 1
	if steps >= GameConfig.MAX_STEPS_PER_FRAME:
		_accumulator = 0.0
	tutorial.update()
	_since_change += delta
	if steps > 0 and _since_change >= CHANGE_INTERVAL:
		_since_change = 0.0
		changed.emit()
	return steps


func perform(action: Callable) -> bool:
	var success: bool = action.call()
	if success:
		changed.emit()
	return success
