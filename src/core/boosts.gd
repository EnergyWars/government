class_name Boosts
extends RefCounted

signal used(boost_id: String, source: String)

const AD := "ad"
const SEALS := "seals"
const SICK_NOTE := "sick_note"

var state: GameState
var simulation: Simulation


func _init(p_state: GameState, p_simulation: Simulation) -> void:
	state = p_state
	simulation = p_simulation


static func seal_cost(boost_id: String) -> int:
	return int(GameConfig.boost(boost_id).get("seals", 0))


func is_available(boost_id: String) -> bool:
	var config := GameConfig.boost(boost_id)
	if config.is_empty() or state.is_boost_active(boost_id):
		return false
	return not bool(config.get("requires_mail", false)) or state.mailroom() != null


func can_use(boost_id: String, source: String) -> bool:
	if not is_available(boost_id):
		return false
	match source:
		AD:
			return state.boost_cooldown(boost_id) <= 0.0
		SEALS:
			return state.seals >= seal_cost(boost_id)
	return false


func use(boost_id: String, source: String) -> bool:
	if not can_use(boost_id, source):
		return false
	var config := GameConfig.boost(boost_id)
	if source == SEALS:
		state.seals -= seal_cost(boost_id)
	else:
		state.boost_cooldowns[boost_id] = float(config.cooldown)
		state.ads_watched += 1
	state.boosts_used += 1
	_apply(boost_id, float(config.duration))
	used.emit(boost_id, source)
	return true


func _apply(boost_id: String, duration: float) -> void:
	if duration > 0.0:
		state.boosts[boost_id] = duration
	match boost_id:
		"coffee_round":
			simulation.wake_everyone(false)
		"doctor_visit":
			simulation.wake_everyone(true)
		"works_outing":
			simulation.calm_office()
		"complaint_amnesty":
			state.complaints = 0
		"weekend_shift":
			simulation.finish_all_jobs()
		"budget_injection":
			state.grant(Formulas.budget_injection(state))


func buy_seals(pack: int) -> bool:
	if pack < 0 or pack >= GameConfig.SEAL_PACKS.size():
		return false
	state.seals += GameConfig.SEAL_PACKS[pack]
	return true


func can_cure_by_ad(key: String, desk: int) -> bool:
	var station := state.station(key)
	if station == null or station.machine or desk < 0 or desk >= station.moods.size():
		return false
	return station.is_staffed(desk) and station.moods[desk].is_sick() and state.boost_cooldown(SICK_NOTE) <= 0.0


func cure_by_ad(key: String, desk: int) -> bool:
	if not can_cure_by_ad(key, desk):
		return false
	simulation.wake_up(state.station(key), desk, true)
	state.boost_cooldowns[SICK_NOTE] = GameConfig.AD_SICK_COOLDOWN
	state.ads_watched += 1
	return true
