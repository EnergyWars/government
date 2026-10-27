class_name RewardDirector
extends Node

const CASE_STREAK_WINDOW := 1.6
const DEED_STREAK_WINDOW := 6.0
const PURCHASE_STREAK_WINDOW := 4.0
const SCALE_STEPS: Array[int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
const MONEY_FIRST := 1000.0
const MONEY_MANTISSAS: Array[float] = [1.0, 5.0]
const CASES_FIRST := 10.0
const CASES_MANTISSAS: Array[float] = [1.0, 2.5, 5.0]
const COINS_PER_CLAIM := 8
const COINS_PER_GIFT := 5
const HAPTIC_TICK := 15
const HAPTIC_SHORT := 30
const HAPTIC_LONG := 70
const RUCKUS_VIBRATION_MS := 400
const STREAK_TEXTS := {2: "STREAK_2", 3: "STREAK_3", 4: "STREAK_4"}
const POSITIVE_REVIEW_OUTCOMES: Array[String] = ["deleted", "won"]

var game: Game
var sfx: SfxPlayer
var celebrations: CelebrationLayer
var hud: Hud
var office: WorldView
var case_streak := StreakCounter.new(CASE_STREAK_WINDOW)
var deed_streak := StreakCounter.new(DEED_STREAK_WINDOW)
var purchase_streak := StreakCounter.new(PURCHASE_STREAK_WINDOW)
var money_ladder := MilestoneLadder.new(MONEY_FIRST, MONEY_MANTISSAS)
var case_ladder := MilestoneLadder.new(CASES_FIRST, CASES_MANTISSAS)
var _goal_ready := false
var _tutorial_step := -1


func setup(p_game: Game, p_sfx: SfxPlayer, p_celebrations: CelebrationLayer, p_hud: Hud, p_office: WorldView) -> RewardDirector:
	game = p_game
	sfx = p_sfx
	celebrations = p_celebrations
	hud = p_hud
	office = p_office
	money_ladder.start(game.state.money_earned)
	case_ladder.start(float(game.state.cases_completed))
	_goal_ready = game.goals.is_complete()
	_tutorial_step = game.state.tutorial_step
	_connect_signals()
	return self


func _connect_signals() -> void:
	var sim := game.simulation
	sim.case_completed.connect(_on_case_completed)
	sim.mail_answered.connect(func(_dept_id: String, _money: float) -> void: _coin())
	sim.department_unlocked.connect(_on_department_unlocked)
	sim.department_ranked_up.connect(_on_department_ranked_up)
	sim.onboarding_completed.connect(func(_dept_id: String) -> void: _play(SoundBank.CHIME))
	sim.gift_arrived.connect(func(_kind: int) -> void: _play(SoundBank.SPARKLE))
	sim.gift_claimed.connect(func(_kind: int, _money: float) -> void: shower_coins(hud.goal_anchor(), COINS_PER_GIFT))
	sim.employee_woke.connect(func(_key: String, _desk: int, by_player: bool) -> void: _deed_if(by_player))
	sim.dispute_ended.connect(func(_kind: String, _dept_id: String, by_player: bool) -> void: _deed_if(by_player))
	sim.intern_recovered.connect(func(_slot: int, by_player: bool) -> void: _deed_if(by_player))
	sim.complaint_shredded.connect(func(by_player: bool) -> void: _deed_if(by_player))
	sim.sick_called.connect(func(by_player: bool, _key: String, _desk: int) -> void: _deed_if(by_player))
	sim.sick_call_answered.connect(func(by_player: bool, _key: String, _desk: int, persuaded: bool) -> void: _deed_if(by_player and persuaded))
	sim.ruckus_calmed.connect(func(_desk: int) -> void: deed())
	sim.mail_picked_up.connect(deed)
	sim.bonus_left.connect(func(_key: String, _desk: int, _tier: int) -> void: deed())
	sim.review_removed.connect(_on_review_removed)
	sim.ruckus_started.connect(func(_desk: int) -> void: _vibrate(RUCKUS_VIBRATION_MS))
	game.boosts.used.connect(func(_boost_id: String, _source: String) -> void: _play(SoundBank.WHOOSH))
	game.actions.purchased.connect(_on_purchased)
	game.goals.claimed.connect(_on_goal_claimed)
	game.changed.connect(check_progress)
	game.tutorial.changed.connect(_on_tutorial_changed)
	if celebrations != null:
		celebrations.coin_landed.connect(_on_coin_landed)


func _process(delta: float) -> void:
	case_streak.advance(delta)
	deed_streak.advance(delta)
	purchase_streak.advance(delta)


static func scale_pitch(step: int) -> float:
	var index := maxi(step, 0) % SCALE_STEPS.size()
	return pow(2.0, SCALE_STEPS[index] / 12.0)


static func streak_text(count: int) -> String:
	if STREAK_TEXTS.has(count):
		return TranslationServer.translate(STREAK_TEXTS[count])
	return TranslationServer.translate("FMT_STREAK_MANY") % count


func _play(id: String, pitch: float = 1.0) -> bool:
	return sfx != null and sfx.play(id, pitch)


func _vibrate(duration_ms: int) -> bool:
	return sfx != null and sfx.vibrate(duration_ms)


func _coin() -> int:
	var count := case_streak.hit()
	_play(SoundBank.COIN, scale_pitch(count - 1))
	return count


func _on_case_completed(_dept_id: String, _money: float, flawed: bool) -> void:
	if flawed:
		return
	var count := _coin()
	if count >= 10 and StreakCounter.is_milestone(count) and office != null:
		office.cheer_at(office.counter_point(), tr("FMT_FLOAT_CASE_STREAK") % count, AppTheme.MONEY)


func _deed_if(condition: bool) -> void:
	if condition:
		deed()


func deed() -> int:
	var count := deed_streak.hit()
	_play(SoundBank.POP, scale_pitch(count - 1))
	_vibrate(HAPTIC_TICK)
	if count >= 2 and office != null:
		office.cheer(streak_text(count), AppTheme.accent("success"))
	if StreakCounter.is_milestone(count):
		_play(SoundBank.SPARKLE)
	return count


func _on_purchased(_entry_id: String, count: int) -> void:
	var streak := purchase_streak.hit()
	_play(SoundBank.CASH, scale_pitch(streak - 1))
	_vibrate(HAPTIC_SHORT)
	if celebrations != null:
		var text := tr("FLOAT_BOUGHT") if count <= 1 else tr("FMT_FLOAT_BOUGHT_MANY") % count
		celebrations.burst(get_viewport().get_mouse_position(), text, AppTheme.MONEY)
		if streak >= 3 and StreakCounter.is_milestone(streak):
			celebrations.toast(Icons.CART, tr("CELEBRATE_SPREE_TITLE"), tr("FMT_CELEBRATE_SPREE") % streak, "tertiary")


func _on_department_unlocked(dept_id: String) -> void:
	_big(Icons.CELEBRATION, tr("CELEBRATE_UNLOCK_TITLE"), tr("FMT_CELEBRATE_UNLOCK") % tr("DEPT_" + dept_id.to_upper()), SoundBank.UNLOCK)


func _on_department_ranked_up(dept_id: String, rank: int) -> void:
	if not DepartmentRank.is_milestone(rank):
		_play(SoundBank.LEVEL_UP)
		return
	var title := tr("FMT_CELEBRATE_RANK_TITLE") % UpgradeTexts.rank_title(rank)
	var text := tr("FMT_CELEBRATE_RANK") % [tr("DEPT_" + dept_id.to_upper()), UpgradeTexts.factor_text(DepartmentRank.milestone_factor(rank))]
	_big(Icons.RANK, title, text, SoundBank.FANFARE)


func _on_goal_claimed(money: float, reputation: float, seals: int) -> void:
	shower_coins(hud.goal_anchor() if hud != null else Vector2.ZERO, COINS_PER_CLAIM)
	_big(Icons.FLAG, tr("CELEBRATE_GOAL_TITLE"), tr("FMT_CELEBRATE_GOAL") % [UiKit.money(money), int(reputation), seals], SoundBank.FANFARE)
	_goal_ready = game.goals.is_complete()


func _on_review_removed(outcome: String) -> void:
	if POSITIVE_REVIEW_OUTCOMES.has(outcome):
		_play(SoundBank.CHIME)


func _on_tutorial_changed() -> void:
	var step := game.state.tutorial_step
	if step > _tutorial_step and _tutorial_step >= 0:
		_play(SoundBank.CHIME)
	_tutorial_step = step


func check_progress() -> void:
	var ready := game.goals.is_complete()
	if ready and not _goal_ready:
		_play(SoundBank.CHIME)
		_vibrate(HAPTIC_SHORT)
		if hud != null:
			hud.pulse_goal()
	_goal_ready = ready
	var money := money_ladder.update(game.state.money_earned)
	if money > 0.0:
		_big(Icons.PAID, tr("FMT_CELEBRATE_MONEY_TITLE") % UiKit.money(money), tr("CELEBRATE_MONEY_TEXT"), SoundBank.FANFARE)
	var cases := case_ladder.update(float(game.state.cases_completed))
	if cases > 0.0:
		_big(Icons.TROPHY, tr("FMT_CELEBRATE_CASES_TITLE") % UiKit.number(cases), tr("CELEBRATE_CASES_TEXT"), SoundBank.LEVEL_UP)


func shower_coins(from: Vector2, count: int) -> int:
	_play(SoundBank.CLAIM)
	_vibrate(HAPTIC_SHORT)
	if celebrations == null or hud == null:
		return 0
	return celebrations.fly_coins(from, hud.money_anchor(), count)


func windfall() -> int:
	return shower_coins(get_viewport().get_visible_rect().size * 0.5, COINS_PER_CLAIM)


func _on_coin_landed(index: int) -> void:
	_play(SoundBank.COIN, scale_pitch(index))
	if hud != null:
		hud.pulse_money()


func _big(icon_code: String, title: String, text: String, sound: String) -> void:
	_play(sound)
	_vibrate(HAPTIC_LONG)
	if celebrations != null:
		celebrations.celebrate(icon_code, title, text, "success")
