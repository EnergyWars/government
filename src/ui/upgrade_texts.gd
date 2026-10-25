class_name UpgradeTexts
extends RefCounted

const FEE_DECIMAL_LIMIT := 10.0
const BLOCK_KEYS := {
	"max": "LABEL_MAX_LEVEL",
	"requires": "LABEL_REQUIRES",
	"reputation": "LABEL_NEEDS_REPUTATION",
	"stage": "LABEL_NEEDS_STAGE",
	"room": "LABEL_ROOM_LOCKED",
	"desks": "LABEL_NEED_DESK",
	"onboarding": "LABEL_ONBOARDING",
	"tubes": "LABEL_NEEDS_TUBE_STATIONS",
	"later": "LOCKED_LATER",
	"space": "LABEL_NEEDS_SPACE",
	"unlocked": "LABEL_MAX_LEVEL",
	"unknown": "LABEL_UNAVAILABLE",
}


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func room_title(room_id: String) -> String:
	if not GameConfig.department(room_id).is_empty():
		return t("DEPT_" + room_id.to_upper())
	return t("ROOM_" + room_id.to_upper())


static func topic_title(topic_id: String) -> String:
	return t("TOPIC_" + topic_id.to_upper())


static func spot_title(spot: String) -> String:
	var target := GameConfig.spot_target(spot)
	match GameConfig.spot_kind(spot):
		"room":
			return room_title(target)
		"dept":
			return room_title(target)
		"station":
			return StationCard.label_for(target)
		"shredder":
			return t("FMT_SPOT_SHREDDER") % room_title(target)
		"tube":
			return t("FMT_SPOT_TUBE_STATION") % room_title(target)
	return t("SPOT_" + spot.to_upper())


static func spot_icon(spot: String) -> String:
	var target := GameConfig.spot_target(spot)
	match GameConfig.spot_kind(spot):
		"room", "dept":
			return Icons.room(target)
		"station":
			return Icons.station_for(target)
		"shredder":
			return Icons.upgrade("shredder")
		"tube":
			return Icons.upgrade("tube_station")
	return Icons.SPOTS.get(spot, Icons.UPGRADE)


static func spot_description(spot: String) -> String:
	return t(spot_description_key(spot))


static func spot_description_key(spot: String) -> String:
	var target := GameConfig.spot_target(spot)
	match GameConfig.spot_kind(spot):
		"room":
			return "ROOM_DESC_" + target.to_upper()
		"dept":
			return "DEPT_DESC_" + target.to_upper()
		"station":
			return "SPOT_DESC_STATION"
		"shredder":
			return "SPOT_DESC_DEPT_SHREDDER"
		"tube":
			return "SPOT_DESC_TUBE_STATION"
	return "SPOT_DESC_" + spot.to_upper()


static func title(entry: UpgradeEntry) -> String:
	match entry.kind:
		UpgradeCatalog.TRACK:
			var name := t("TRACK_" + entry.target.to_upper())
			return name if entry.room_id.is_empty() else t("FMT_ENTRY_IN_ROOM") % [name, room_title(entry.room_id)]
		UpgradeCatalog.LEVEL:
			return t("FMT_ENTRY_LEVEL") % StationCard.label_for(entry.target)
		UpgradeCatalog.DESK:
			return t("FMT_ENTRY_MACHINE" if GameConfig.is_machine(entry.target) else "FMT_ENTRY_DESK") % StationCard.label_for(entry.target)
		UpgradeCatalog.HIRE:
			return t("FMT_ENTRY_HIRE") % StationCard.label_for(entry.target)
		UpgradeCatalog.SPECIALIST:
			return t("FMT_ENTRY_SPECIALIST") % StationCard.label_for(entry.target)
		UpgradeCatalog.SUPERVISOR:
			return t("FMT_ENTRY_SUPERVISOR") % room_title(entry.target)
		UpgradeCatalog.STAFF:
			return t("STAFF_" + entry.target.to_upper())
		UpgradeCatalog.RUNNER_LEVEL:
			return t("FMT_ENTRY_RUNNER_LEVEL") % (entry.index + 1)
		UpgradeCatalog.SEGMENT:
			var ends := RouteBuilder.segment_ends(entry.target)
			return t("FMT_TUBE_SEGMENT") % [StationCard.label_for(ends[0]), StationCard.label_for(ends[1])]
		UpgradeCatalog.STORAGE:
			return t("MAIL_STORAGE_TITLE")
		UpgradeCatalog.UNLOCK:
			return t("FMT_ENTRY_UNLOCK") % room_title(entry.target)
		UpgradeCatalog.RANK:
			return t("FMT_ENTRY_RANK") % room_title(entry.target)
		UpgradeCatalog.STAGE:
			return t("FMT_ENTRY_STAGE") % t("STAGE_" + str(GameConfig.building_stage(entry.level + 1).id).to_upper())
	return entry.id


static func description(entry: UpgradeEntry) -> String:
	match entry.kind:
		UpgradeCatalog.TRACK:
			return t("TRACK_DESC_" + entry.target.to_upper())
		UpgradeCatalog.STAFF:
			return t("STAFF_DESC_" + entry.target.to_upper())
		UpgradeCatalog.SPECIALIST:
			return t("STAFF_DESC_SPECIALISTS")
		UpgradeCatalog.SUPERVISOR:
			return t("STAFF_DESC_SUPERVISORS")
	return t("ENTRY_DESC_" + entry.kind.to_upper())


static func icon(entry: UpgradeEntry) -> String:
	match entry.kind:
		UpgradeCatalog.TRACK:
			return Icons.upgrade(entry.target)
		UpgradeCatalog.LEVEL:
			return Icons.ARROW_UP
		UpgradeCatalog.DESK:
			return Icons.ADD
		UpgradeCatalog.HIRE:
			return Icons.PERSON_ADD
		UpgradeCatalog.SPECIALIST:
			return Icons.STAFF.specialists
		UpgradeCatalog.SUPERVISOR:
			return Icons.STAFF.supervisors
		UpgradeCatalog.STAFF:
			return Icons.STAFF.get(entry.target, Icons.PERSON_ADD)
		UpgradeCatalog.RUNNER_LEVEL:
			return Icons.STAFF.runners
		UpgradeCatalog.SEGMENT:
			return Icons.upgrade("tube_capacity")
		UpgradeCatalog.STORAGE:
			return Icons.STORAGE
		UpgradeCatalog.UNLOCK:
			return Icons.department(entry.target)
		UpgradeCatalog.RANK:
			return Icons.RANK
		UpgradeCatalog.STAGE:
			return Icons.DOMAIN
	return Icons.UPGRADE


static func place(entry: UpgradeEntry) -> String:
	return t("FMT_ENTRY_PLACE") % [room_title(entry.room), spot_title(entry.spot)]


static func level_text(entry: UpgradeEntry) -> String:
	if entry.kind == UpgradeCatalog.STAGE:
		return t("FMT_LEVEL_OF") % [entry.level + 1, entry.max_level + 1]
	if entry.kind == UpgradeCatalog.RANK:
		return t("FMT_LEVEL_OF") % [entry.level, entry.max_level]
	if entry.single:
		return t("LABEL_ONCE")
	return t("FMT_LEVEL_OF") % [entry.level, entry.max_level]


static func effect(state: GameState, entry: UpgradeEntry) -> String:
	match entry.kind:
		UpgradeCatalog.TRACK:
			var config := GameConfig.upgrade(entry.target)
			var unit := str(config.get("unit", "count"))
			var now := format_value(unit, Formulas.track_value(entry.target, entry.level))
			if entry.is_maxed():
				return t("FMT_EFFECT_MAX") % now
			return t("FMT_EFFECT") % [now, format_value(unit, Formulas.track_value(entry.target, entry.level + 1))]
		UpgradeCatalog.LEVEL:
			return _change("FMT_EFFECT_SPEED", entry, "×%s" % UiKit.decimal(Formulas.level_speed(entry.level), 2), "×%s" % UiKit.decimal(Formulas.level_speed(entry.level + 1), 2))
		UpgradeCatalog.SEGMENT:
			var capacity := Formulas.tube_segment_capacity(state, entry.target)
			return _change("FMT_EFFECT_CAPACITY", entry, str(capacity), str(capacity + GameConfig.TUBE_SEGMENT_CAPACITY_PER_LEVEL))
		UpgradeCatalog.STORAGE:
			var room := state.mailroom()
			var capacity := room.storage_capacity() if room != null else 0
			return _change("FMT_EFFECT_CAPACITY", entry, str(capacity), str(capacity + GameConfig.MAIL_STORAGE_PER_LEVEL))
		UpgradeCatalog.RUNNER_LEVEL:
			var runner: Runner = state.runners[entry.index] if entry.index >= 0 and entry.index < state.runners.size() else null
			if runner == null:
				return ""
			var carried := Formulas.runner_load(state, runner)
			return _change("FMT_EFFECT_CAPACITY", entry, str(carried), str(carried + GameConfig.RUNNER_LEVEL_CAPACITY))
		UpgradeCatalog.STAGE:
			if entry.is_maxed():
				return ""
			var next := GameConfig.building_stage(entry.level + 1)
			return t("FMT_STAGE_INFO") % [int(next.max_departments), int(next.max_desks), int(next.lobby)]
		UpgradeCatalog.UNLOCK:
			return gain_text("FMT_EFFECT_UNLOCK_GAIN", UpgradeCatalog.income_gain(state, entry), entry.cost)
		UpgradeCatalog.RANK:
			return rank_effect(state, entry)
	return _change("FMT_EFFECT_COUNT", entry, str(entry.level), str(entry.level + 1))


static func rank_name(rank: int) -> String:
	return t("DEPT_RANK_%d" % DepartmentRank.title_index(rank))


static func fee_factor_text(rank: int) -> String:
	return factor_text(DepartmentRank.fee_factor(rank))


static func factor_text(factor: float) -> String:
	if factor < FEE_DECIMAL_LIMIT and not is_equal_approx(factor, roundf(factor)):
		return "×" + UiKit.decimal(factor, 2)
	return "×" + UiKit.number(factor)


static func rank_effect(state: GameState, entry: UpgradeEntry) -> String:
	var dept := state.department(entry.target)
	if dept == null:
		return ""
	if entry.is_maxed():
		return t("FMT_EFFECT_RANK_MAX") % [rank_name(dept.rank), fee_factor_text(dept.rank)]
	var lines: Array[String] = [t("FMT_EFFECT_RANK") % [dept.rank, dept.rank + 1, fee_factor_text(dept.rank), fee_factor_text(dept.rank + 1)]]
	lines.append(milestone_text(dept.rank))
	var gain := gain_text("FMT_EFFECT_RANK_GAIN", UpgradeCatalog.income_gain(state, entry), entry.cost)
	if not gain.is_empty():
		lines.append(gain)
	return "\n".join(lines)


static func milestone_text(rank: int) -> String:
	var next := DepartmentRank.next_milestone(rank)
	return t("FMT_EFFECT_RANK_MILESTONE") % [next, rank_name(next), factor_text(DepartmentRank.milestone_factor(next))]


static func rank_title(rank: int) -> String:
	return t("FMT_RANK_TITLE") % [rank_name(rank), DepartmentRank.clamp_level(rank)]


static func gain_text(format_key: String, per_second: float, cost: float) -> String:
	if per_second <= 0.0:
		return ""
	return t(format_key) % [UiKit.money(per_second * 60.0), UiKit.duration(cost / per_second)]


static func _change(format_key: String, entry: UpgradeEntry, now: String, next: String) -> String:
	if entry.is_maxed():
		return t(format_key + "_MAX") % now
	return t(format_key) % [now, next]


static func format_value(unit: String, value: float) -> String:
	match unit:
		"count":
			return str(int(value))
		"bonus":
			return "+%s %%" % UiKit.decimal((value - 1.0) * 100.0)
		"reduction":
			return "−%s %%" % UiKit.decimal((1.0 - value) * 100.0)
		"seconds":
			return t("LABEL_OFF") if value < 0.0 else t("FMT_EFFECT_SECONDS") % UiKit.decimal(value)
		"chance", "percent":
			return "%s %%" % UiKit.decimal(value * 100.0)
		"unlock":
			return t("LABEL_YES") if value > 0.0 else t("LABEL_NO")
	return UiKit.decimal(value)


static func block_text(state: GameState, entry: UpgradeEntry) -> String:
	if entry.reason == "onboarding":
		var station := state.station(entry.target)
		var dept: Department = state.department(station.dept_id) if station != null else null
		if dept != null:
			return StationCard.onboarding_text(dept)
	if entry.reason == "requires" and entry.kind == UpgradeCatalog.STAFF:
		return t("LABEL_NEEDS_SHREDDER_SERVICE")
	if entry.reason == "requires" and entry.kind == UpgradeCatalog.TRACK:
		var requires: Dictionary = GameConfig.upgrade(entry.target).get("requires", {})
		var names: Array[String] = []
		for required_id: String in requires:
			names.append(t("TRACK_" + required_id.to_upper()))
		return t("FMT_REQ_UPGRADE") % ", ".join(names)
	if entry.reason == "reputation":
		return t("FMT_REQ_REPUTATION") % int(required_reputation(entry))
	if entry.reason == "stage" and entry.kind == UpgradeCatalog.TRACK:
		return t("FMT_REQ_STAGE") % (int(GameConfig.upgrade(entry.target).get("stage", 0)) + 1)
	return t(BLOCK_KEYS.get(entry.reason, "LABEL_UNAVAILABLE"))


static func required_reputation(entry: UpgradeEntry) -> float:
	match entry.kind:
		UpgradeCatalog.TRACK:
			return float(GameConfig.upgrade(entry.target).get("reputation", 0.0))
		UpgradeCatalog.UNLOCK:
			return float(GameConfig.department(entry.target).unlock_reputation)
		UpgradeCatalog.RANK:
			return DepartmentRank.level_reputation(entry.target, entry.level)
		UpgradeCatalog.STAGE:
			return float(GameConfig.building_stage(entry.level + 1).reputation)
	return 0.0


static func button_text(state: GameState, entry: UpgradeEntry, amount: int) -> String:
	if not entry.reason.is_empty() and entry.reason != "money":
		return block_text(state, entry)
	var count := maxi(1, amount)
	var action := t("ACTION_BUY") if count == 1 else t("FMT_ACTION_BUY_MANY") % count
	return t("FMT_ACTION_COST") % [action, UiKit.money(entry.bulk_cost(count))]
