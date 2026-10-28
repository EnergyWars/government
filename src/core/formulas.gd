class_name Formulas
extends RefCounted


static func cost_multiplier_for(station: Station) -> float:
	if station.is_shared():
		return float(GameConfig.SHARED_STATIONS.get(station.key, {}).get("cost_multiplier", 1.0))
	return float(GameConfig.department(station.dept_id).get("cost_multiplier", 1.0))


static func staff_multiplier_for(station: Station) -> float:
	if station.is_shared():
		return cost_multiplier_for(station)
	return department_staff_multiplier(GameConfig.department(station.dept_id))


static func department_staff_multiplier(config: Dictionary) -> float:
	return float(config.get("staff_multiplier", config.get("cost_multiplier", 1.0)))


static func desk_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).desk_cost) * cost_multiplier_for(station) * pow(GameConfig.DESK_GROWTH, station.desks - 1) * early_discount(station.desks - 1)


static func hire_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).hire_cost) * staff_multiplier_for(station) * pow(GameConfig.HIRE_GROWTH, station.staff) * early_discount(station.staff)


static func reject_pile_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).desk_cost) * cost_multiplier_for(station) * GameConfig.REJECT_PILE_COST_FACTOR * pow(GameConfig.REJECT_PILE_GROWTH, station.reject_level) * early_discount(station.reject_level)


static func staff_walk_time(from: Vector2, to: Vector2) -> float:
	return clampf(from.distance_to(to) / GameConfig.STAFF_WALK_SPEED, GameConfig.STAFF_WALK_MIN_SECONDS, GameConfig.STAFF_WALK_MAX_SECONDS)


static func track_value(upgrade_id: String, level: int) -> float:
	var config := GameConfig.upgrade(upgrade_id)
	var base := float(config.get("base", 0.0))
	var capped := clampi(level, 0, int(config.get("max", 0)))
	match str(config.get("curve", "linear")):
		"decay":
			return base * pow(float(config.rate), capped)
		"unlock_decay":
			return -1.0 if capped <= 0 else base * pow(float(config.rate), capped - 1)
		"chance":
			return 1.0 - (1.0 - base) * pow(float(config.rate), capped)
		"unlock":
			return 1.0 if capped > 0 else 0.0
		"milestone":
			return level_speed(capped + 1)
	return base + float(config.get("step", 0.0)) * capped


static func upgrade_value(state: GameState, upgrade_id: String, room_id: String = "") -> float:
	return state.upgrade_value(upgrade_id, room_id)


static func track_room_factor(upgrade_id: String, room_id: String) -> float:
	if room_id.is_empty():
		return 1.0
	if upgrade_id == "tube_station":
		if room_id == GameConfig.ROOM_INSPECTION:
			return GameConfig.TUBE_STATION_INSPECTION_FACTOR
		var unlock_cost := float(GameConfig.department(room_id).get("unlock_cost", 0.0))
		return maxf(1.0, unlock_cost * GameConfig.TUBE_STATION_FACTOR / GameConfig.TUBE_STATION_MIN_COST)
	if room_id == GameConfig.ROOM_INSPECTION:
		return float(GameConfig.SHARED_STATIONS[GameConfig.INSPECTION].cost_multiplier)
	var config := GameConfig.department(room_id)
	if bool(GameConfig.upgrade(upgrade_id).get("staff_cost", false)):
		return department_staff_multiplier(config) if not config.is_empty() else 1.0
	return float(config.get("cost_multiplier", 1.0))


static func track_cost(upgrade_id: String, level: int, room_id: String = "") -> float:
	var config := GameConfig.upgrade(upgrade_id)
	return float(config.cost) * track_room_factor(upgrade_id, room_id) * pow(float(config.growth), level) * early_discount(track_price_level(upgrade_id, level))


static func track_bulk_cost(upgrade_id: String, level: int, count: int, room_id: String = "") -> float:
	return ramped_sum(track_cost(upgrade_id, level, room_id), float(GameConfig.upgrade(upgrade_id).growth), track_price_level(upgrade_id, level), count)


static func track_price_level(upgrade_id: String, level: int) -> int:
	return level + int(GameConfig.upgrade(upgrade_id).get("price_offset", 0))


static func early_discount(level: int) -> float:
	if level >= GameConfig.EARLY_DISCOUNT_LEVELS:
		return 1.0
	return lerpf(GameConfig.EARLY_DISCOUNT_START, 1.0, maxi(0, level) / float(GameConfig.EARLY_DISCOUNT_LEVELS))


static func ramped_sum(cost: float, growth: float, level: int, count: int) -> float:
	if count <= 0:
		return 0.0
	var start := maxi(0, level)
	var raw := cost / early_discount(start)
	var total := 0.0
	var index := 0
	while index < count and start + index < GameConfig.EARLY_DISCOUNT_LEVELS:
		total += raw * pow(growth, index) * early_discount(start + index)
		index += 1
	return total + geometric_sum(raw * pow(growth, index), growth, count - index)


static func ramped_affordable(cost: float, growth: float, level: int, remaining: int, money: float) -> int:
	if remaining <= 0 or money + 0.0001 < cost:
		return 0
	var low := 1
	var high := remaining
	while low < high:
		var middle := ceili((low + high) / 2.0)
		if ramped_sum(cost, growth, level, middle) <= money + 0.0001:
			low = middle
		else:
			high = middle - 1
	return low


static func geometric_sum(first: float, growth: float, count: int) -> float:
	if count <= 0:
		return 0.0
	if is_equal_approx(growth, 1.0):
		return first * count
	return first * (pow(growth, count) - 1.0) / (growth - 1.0)


static func geometric_affordable(first: float, growth: float, remaining: int, money: float) -> int:
	if remaining <= 0 or money + 0.0001 < first:
		return 0
	if first <= 0.0:
		return remaining
	var count := floori(money / first) if is_equal_approx(growth, 1.0) else floori(log(money * (growth - 1.0) / first + 1.0) / log(growth))
	count = clampi(count, 1, remaining)
	while count > 1 and geometric_sum(first, growth, count) > money + 0.0001:
		count -= 1
	while count < remaining and geometric_sum(first, growth, count + 1) <= money + 0.0001:
		count += 1
	return count


static func complaint_cap(state: GameState) -> int:
	return int(upgrade_value(state, "complaint_box"))


static func intern_steadfast(state: GameState) -> int:
	return int(upgrade_value(state, "intern_steadfast"))


static func intern_run_size(state: GameState) -> int:
	return int(upgrade_value(state, "intern_box_runs"))


static func intern_speed(state: GameState) -> float:
	return GameConfig.INTERN_SPEED * upgrade_value(state, "intern_speed")


static func intern_trip_time(state: GameState) -> float:
	return WorldLayout.get_default().intern_trip_length() / intern_speed(state)


static func security_chance(state: GameState) -> float:
	if not state.has_upgrade("complaint_security"):
		return 0.0
	return clampf(upgrade_value(state, "security_training"), 0.0, 1.0)


static func review_delete_cost(state: GameState, review: Review) -> float:
	var stars := 5 if review.forced else review.stars
	return float(GameConfig.building_stage(state.building_stage).review_delete) * review.price_factor * GameConfig.REVIEW_DELETE_STAR_FACTORS[clampi(stars, 1, 5) - 1] * pow(GameConfig.REVIEW_DELETE_LAWSUIT_GROWTH, review.lawsuits)


static func income_per_second(state: GameState) -> float:
	var total := 0.0
	for dept in state.unlocked_departments():
		total += department_throughput(state, dept) * expected_case_value(state, dept)
	return total


static func review_lawsuit_cost(state: GameState, review: Review) -> float:
	return float(GameConfig.building_stage(state.building_stage).review_lawsuit) * review.price_factor * GameConfig.REVIEW_LAWSUIT_STAR_FACTORS[clampi(review.stars, 1, 5) - 1] * pow(GameConfig.REVIEW_LAWSUIT_GROWTH, review.lawsuits)


static func bulk_delete_cost(state: GameState, review_ids: Array) -> float:
	var total := 0.0
	for review_id in review_ids:
		var review := state.find_review(int(review_id))
		if review != null:
			total += review_delete_cost(state, review)
	return total


static func bulk_lawsuit_cost(state: GameState, review_ids: Array) -> float:
	var total := 0.0
	for review_id in review_ids:
		var review := state.find_review(int(review_id))
		if review != null and review.can_be_sued():
			total += review_lawsuit_cost(state, review)
	return total


static func review_lawsuit_chance(review: Review) -> float:
	return minf(GameConfig.REVIEW_LAWSUIT_MAX_CHANCE, GameConfig.REVIEW_LAWSUIT_CHANCE + GameConfig.REVIEW_LAWSUIT_CHANCE_STEP * review.lawsuits)


static func station_room(station: Station) -> String:
	return GameConfig.station_room(station.key)


static func lead_room(station: Station) -> String:
	return GameConfig.lead_room(station.key)


static func has_lead(state: GameState, room_id: String) -> bool:
	return state.has_upgrade("team_lead", room_id)


static func lead_value(state: GameState, upgrade_id: String, room_id: String) -> float:
	if not GameConfig.upgrade_rooms(upgrade_id).has(room_id) or not has_lead(state, room_id):
		return lead_neutral(upgrade_id)
	return upgrade_value(state, upgrade_id, room_id)


static func lead_neutral(upgrade_id: String) -> float:
	return float(GameConfig.upgrade(upgrade_id).get("neutral", track_value(upgrade_id, 0)))


static func department_calm(state: GameState, dept_id: String) -> float:
	if not has_lead(state, dept_id):
		return 0.0
	return clampf(lead_value(state, "lead_calm", dept_id), 0.0, 1.0)


static func team_lead_count(state: GameState) -> int:
	var count := 0
	for room_id in GameConfig.lead_rooms():
		if has_lead(state, room_id):
			count += 1
	return count


static func patrol_speed(state: GameState, room_id: String) -> float:
	if not state.is_patrolling(room_id):
		return 1.0
	return lead_value(state, "lead_patrol", room_id)


static func patrol_cooldown(state: GameState, room_id: String) -> float:
	return lead_value(state, "lead_cooldown", room_id)


static func tray_size(state: GameState, room_id: String) -> int:
	if not GameConfig.office_rooms().has(room_id):
		return GameConfig.TRAY_BASE
	return clampi(int(upgrade_value(state, "room_trays", room_id)), GameConfig.TRAY_BASE, GameConfig.TRAY_MAX)


static func tube_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "tube_capacity"))


static func tube_segment_capacity(state: GameState, tube_id: String) -> int:
	return tube_capacity(state) + state.tube_level(tube_id) * GameConfig.TUBE_SEGMENT_CAPACITY_PER_LEVEL


static func tube_segment_factor(level: int) -> float:
	return 1.0 + GameConfig.TUBE_SEGMENT_SPEED_PER_LEVEL * level


static func tube_segment_speed(state: GameState, tube_id: String) -> float:
	return GameConfig.TUBE_SPEED * tube_segment_factor(state.tube_level(tube_id)) * upgrade_value(state, "tube_speed")


static func tube_segment_cost(level: int) -> float:
	return GameConfig.TUBE_SEGMENT_COST * pow(GameConfig.TUBE_SEGMENT_GROWTH, level) * early_discount(level)


static func coffee_intern_cost(state: GameState) -> float:
	return GameConfig.COFFEE_INTERN_COST * pow(GameConfig.COFFEE_INTERN_GROWTH, state.coffee_interns.size()) * early_discount(state.coffee_interns.size())


static func ticket_machines(state: GameState) -> int:
	var count := 1
	for machine in range(1, GameConfig.MAX_TICKET_MACHINES):
		if state.upgrade_level(GameConfig.TICKET_MACHINE_TRACKS[machine]) > 0:
			count += 1
	return count


static func ticket_machine_rate(state: GameState, machine: int) -> float:
	if machine < 0 or machine >= ticket_machines(state):
		return 0.0
	return upgrade_value(state, GameConfig.TICKET_SPEED_TRACKS[machine])


static func ticket_draw_time(state: GameState, machine: int) -> float:
	var rate := ticket_machine_rate(state, machine)
	return 1.0 / rate if rate > 0.0 else INF


static func ticket_speed(by_hand: bool) -> float:
	return GameConfig.TICKET_HAND_FACTOR if by_hand else 1.0


static func ticket_draw_rate(state: GameState) -> float:
	var rate := 0.0
	for machine in ticket_machines(state):
		rate += ticket_machine_rate(state, machine)
	return rate


static func ticket_line_capacity(state: GameState) -> int:
	return ticket_machines(state) * GameConfig.TICKET_LINE_SLOTS


static func citizen_patience(case_file: CaseFile) -> float:
	match case_file.phase:
		CaseFile.Phase.LINE:
			return GameConfig.LINE_PATIENCE
		CaseFile.Phase.WAITING, CaseFile.Phase.WAITING_DOC:
			return GameConfig.SEAT_PATIENCE if case_file.seated else GameConfig.STAND_PATIENCE
		CaseFile.Phase.CALLED, CaseFile.Phase.CALLED_DOC:
			return GameConfig.DESK_PATIENCE
	return 0.0


static func citizen_time_left(case_file: CaseFile) -> float:
	return maxf(0.0, citizen_patience(case_file) - case_file.waited)


static func seat_leave_chance(waited: float) -> float:
	var chance := 0.0
	for tier: Dictionary in GameConfig.SEAT_LEAVE_CHANCES:
		if waited + 0.000001 >= float(tier.after):
			chance = float(tier.chance)
	return chance


static func seat_leave_checks(before: float, after: float) -> Array[float]:
	var result: Array[float] = []
	var first := float(GameConfig.SEAT_LEAVE_CHANCES[0].after)
	var interval := GameConfig.SEAT_LEAVE_INTERVAL
	var index := maxi(0, ceili((before - first) / interval - 0.000001))
	var point := first + index * interval
	if point <= before + 0.000001 and before > 0.0:
		point += interval
	while point <= after + 0.000001 and point < GameConfig.SEAT_PATIENCE:
		result.append(point)
		point += interval
	return result


static func citizen_leaves_soon(case_file: CaseFile) -> bool:
	if not is_citizen_waiting(case_file):
		return false
	var time_left := citizen_time_left(case_file)
	if case_file.seated and case_file.is_seat_waiting():
		return time_left <= GameConfig.SEAT_LEAVE_WARNING_SECONDS
	return time_left < GameConfig.STAND_LEAVE_WARNING_SECONDS


static func is_citizen_waiting(case_file: CaseFile) -> bool:
	if citizen_patience(case_file) <= 0.0:
		return false
	return case_file.walk <= 0.0 or case_file.phase == CaseFile.Phase.LINE


static func coffee_alert(state: GameState) -> float:
	return alert_duration(state) * GameConfig.COFFEE_SERVE_BONUS


static func coffee_threshold(state: GameState) -> float:
	return alert_duration(state) * GameConfig.COFFEE_SERVE_THRESHOLD


static func dispute_speed(state: GameState, station: Station) -> float:
	if state.disputes.is_empty() or station.machine or station.dept_id.is_empty():
		return 1.0
	var dispute := state.dispute_in(station.dept_id)
	return 1.0 if dispute == null else dispute.speed()


static func dispute_allowed(state: GameState, kind: String) -> bool:
	var climate := int(GameConfig.DISPUTES[kind].climate)
	return climate == 0 or state.upgrade_level("climate_control") < climate


static func dispute_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.DISPUTE_MIN_INTERVAL, GameConfig.DISPUTE_MAX_INTERVAL, clampf(roll, 0.0, 1.0))
	return base * upgrade_value(state, "climate_control") * (1.0 + GameConfig.LEAD_DISPUTE_RELIEF * team_lead_count(state))


static func ruckus_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.RUCKUS_MIN_INTERVAL, GameConfig.RUCKUS_MAX_INTERVAL, clampf(roll, 0.0, 1.0))
	return base * (1.0 + GameConfig.RUCKUS_SECURITY_RELIEF * (1.0 if state.has_upgrade("complaint_security") else 0.0))


static func sick_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, clampf(roll, 0.0, 1.0))
	return base / maxi(1, state.staffed_officials()) * (1.0 + GameConfig.SICK_HR_RELIEF * state.hr) * upgrade_value(state, "toilet_hygiene")


static func sick_share(state: GameState, room_id: String = "") -> float:
	var interval := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, 0.5) * (1.0 + GameConfig.SICK_HR_RELIEF * state.hr) * upgrade_value(state, "toilet_hygiene")
	return clampf(rest_limit(state, DeskMood.SICK, room_id) / interval, 0.0, 1.0)


static func availability(state: GameState, station: Station) -> float:
	if station.machine:
		return 1.0
	var alert := alert_duration(state) / maxf(0.01, drowsiness_rate(state, station))
	var rest := 0.0
	var weights := doze_weights(state)
	var room_id := lead_room(station)
	for rest_state: String in weights:
		var limit := rest_limit(state, rest_state, room_id)
		rest += float(weights[rest_state]) * (GameConfig.UNATTENDED_REST_ESTIMATE if is_inf(limit) else limit)
	return alert / (alert + rest) * (1.0 - sick_share(state, room_id))


static func lunch_interval(roll: float) -> float:
	return lerpf(GameConfig.LUNCH_MIN_INTERVAL, GameConfig.LUNCH_MAX_INTERVAL, clampf(roll, 0.0, 1.0))


static func gift_interval(roll: float) -> float:
	return lerpf(GameConfig.GIFT_MIN_INTERVAL, GameConfig.GIFT_MAX_INTERVAL, clampf(roll, 0.0, 1.0))


static func gift_value(state: GameState) -> float:
	return maxf(GameConfig.GIFT_MIN_MONEY, state.income.per_minute() / 60.0 * GameConfig.GIFT_INCOME_SECONDS)


static func kranz_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.KRANZ_MIN_INTERVAL, GameConfig.KRANZ_MAX_INTERVAL, clampf(roll, 0.0, 1.0))
	return base * (1.0 + GameConfig.KRANZ_COFFEE_RELIEF * state.coffee_interns.size())


static func complaint_interval(roll: float) -> float:
	return GameConfig.COMPLAINT_INTERVAL * lerpf(0.7, 1.3, clampf(roll, 0.0, 1.0))


static func complaint_letter_interval(roll: float) -> float:
	return lerpf(GameConfig.COMPLAINT_LETTER_MIN_INTERVAL, GameConfig.COMPLAINT_LETTER_MAX_INTERVAL, clampf(roll, 0.0, 1.0))


static func praise_interval(roll: float) -> float:
	return lerpf(GameConfig.REVIEW_PRAISE_MIN_INTERVAL, GameConfig.REVIEW_PRAISE_MAX_INTERVAL, clampf(roll, 0.0, 1.0))


static func praise_stars(roll: float) -> int:
	var total := 0.0
	for index in GameConfig.REVIEW_PRAISE_WEIGHTS.size():
		total += GameConfig.REVIEW_PRAISE_WEIGHTS[index]
		if roll < total:
			return GameConfig.REVIEW_PRAISE_MIN_STARS + index
	return GameConfig.REVIEW_PRAISE_MIN_STARS + GameConfig.REVIEW_PRAISE_WEIGHTS.size() - 1


static func complaint_letter_rate() -> float:
	return 2.0 / (GameConfig.COMPLAINT_LETTER_MIN_INTERVAL + GameConfig.COMPLAINT_LETTER_MAX_INTERVAL)


static func sick_bonus_cost(state: GameState, tier: int) -> float:
	var minutes: float = GameConfig.SICK_BONUS_MINUTES[clampi(tier, 0, GameConfig.sick_bonus_tiers())]
	return ceilf(maxf(GameConfig.SICK_BONUS_MIN_INCOME, state.income.per_minute()) * minutes)


static func sick_bonus_price(state: GameState, mood: DeskMood, tier: int) -> float:
	return maxf(0.0, sick_bonus_cost(state, tier) - sick_bonus_cost(state, mood.bonus))


static func sick_recovery_speed(tier: int) -> float:
	return GameConfig.SICK_BONUS_SPEED[clampi(tier, 0, GameConfig.sick_bonus_tiers())]


static func sick_time_left(state: GameState, mood: DeskMood, room_id: String = "") -> float:
	return sick_time_left_with(state, mood, mood.bonus, room_id)


static func sick_time_left_with(state: GameState, mood: DeskMood, tier: int, room_id: String = "") -> float:
	if not mood.is_sick():
		return 0.0
	return maxf(0.0, rest_limit(state, DeskMood.SICK, room_id) - mood.resting) / sick_recovery_speed(maxi(tier, mood.bonus))


static func dispute_limit(state: GameState) -> float:
	var delay := upgrade_value(state, "mediation")
	return GameConfig.DISPUTE_MAX_SECONDS if delay < 0.0 else minf(GameConfig.DISPUTE_MAX_SECONDS, delay)


static func runner_cost(state: GameState) -> float:
	return GameConfig.RUNNER_COST * pow(GameConfig.RUNNER_GROWTH, state.runners.size()) * early_discount(state.runners.size())


static func level_speed(level: int) -> float:
	var milestones := floori(level / float(GameConfig.LEVEL_MILESTONE_STEP))
	return (1.0 + GameConfig.LEVEL_SPEED_BONUS * (level - 1)) * pow(GameConfig.LEVEL_MILESTONE_BONUS, milestones)


static func levels_to_milestone(level: int) -> int:
	return GameConfig.LEVEL_MILESTONE_STEP - posmod(level, GameConfig.LEVEL_MILESTONE_STEP)


static func station_speed(state: GameState, station: Station) -> float:
	var room_id := station_room(station)
	if not GameConfig.office_rooms().has(room_id):
		return 1.0
	return upgrade_value(state, "room_speed", room_id)


static func complex_time_factor(state: GameState) -> float:
	return 1.0 + GameConfig.COMPLEX_TIME_PENALTY * upgrade_value(state, "ai_classification")


static func thoroughness(dept: Department) -> Dictionary:
	return GameConfig.THOROUGHNESS[clampi(dept.thoroughness, 0, GameConfig.THOROUGHNESS.size() - 1)]


static func signature_thoroughness(dept: Department) -> Dictionary:
	return GameConfig.THOROUGHNESS[clampi(dept.signature_mode(), 0, GameConfig.THOROUGHNESS.size() - 1)]


static func thoroughness_time(station: Station, case_dept: Department) -> float:
	if station.machine or station.dept_id != case_dept.id:
		return 1.0
	if station.kind == "signature":
		return float(signature_thoroughness(case_dept).time)
	return float(thoroughness(case_dept).time)


static func _mode_average(dept: Department, key: String, fallback: float) -> float:
	var main := float(thoroughness(dept).get(key, fallback))
	if not dept.has_signature_part():
		return main
	return (main + float(signature_thoroughness(dept).get(key, fallback))) * 0.5


static func thoroughness_reward(dept: Department) -> float:
	return _mode_average(dept, "reward", 1.0)


static func base_time(station: Station, case_dept: Department, complex: bool, state: GameState) -> float:
	var config := case_dept.config()
	var time := float(GameConfig.station_kind(station.kind).base_time)
	if station.kind == "review" and station.dept_id == case_dept.id:
		time = float(config.review_time)
	elif station.kind == "signature":
		time = float(config.signature_time)
	time *= thoroughness_time(station, case_dept)
	if station.dept_id == case_dept.id:
		time *= DepartmentRank.time_factor(case_dept.rank)
	if complex and (station.kind == "review" or station.kind == "inspection"):
		time *= complex_time_factor(state)
	return time


static func required_time(state: GameState, station: Station, case_file: CaseFile) -> float:
	var dept := state.department(case_file.dept_id)
	var time := base_time(station, dept, case_file.complex, state) / station_speed(state, station)
	if station.kind == "reception":
		time *= 1.0 + GameConfig.MULTI_TIME_PER_EXTRA * case_file.extras.size()
	return time * GameConfig.BIG_CASE_TIME_FACTOR if case_file.big else time


static func work_speed(state: GameState, station: Station) -> float:
	var speed := event_speed(state, station) * dispute_speed(state, station) * patrol_speed(state, lead_room(station))
	if station.rush > 0.0:
		speed *= GameConfig.UPGRADE_RUSH_SPEED
	if state.is_boost_active("overtime"):
		speed *= GameConfig.BOOST_OVERTIME_SPEED
	if station.machine and state.is_boost_active("stamp_turbo"):
		speed *= GameConfig.BOOST_STAMP_SPEED
	if station.is_mailroom() and state.is_boost_active("express_post"):
		speed *= GameConfig.BOOST_POST_SPEED
	return speed


static func error_chance(state: GameState, dept: Department) -> float:
	var chance := _mode_average(dept, "error", 0.0)
	chance *= upgrade_value(state, "quality_training") * upgrade_value(state, "ai_classification")
	return clampf(chance, 0.0, 1.0)


static func flag_chance() -> float:
	return clampf(GameConfig.FLAG_BASE_CHANCE, 0.0, 1.0)


static func reputation_multiplier(state: GameState) -> float:
	return 1.0 + sqrt(state.reputation) / GameConfig.REPUTATION_REWARD_DIVISOR


static func review_arrival_factor(state: GameState) -> float:
	if state.reviews.is_empty():
		return 1.0
	var rating := state.average_rating()
	for tier: Dictionary in GameConfig.REVIEW_ARRIVAL_TIERS:
		if rating + 0.000001 >= float(tier.min):
			return float(tier.factor)
	return float(GameConfig.REVIEW_ARRIVAL_TIERS.back().factor)


static func event_fee(state: GameState) -> float:
	if not event_effective(state):
		return 1.0
	return float(GameConfig.EVENTS[state.event_id].get("fee", 1.0))


static func event_effective(state: GameState) -> bool:
	if state.event_id.is_empty():
		return false
	return not (bool(GameConfig.EVENTS[state.event_id].get("pending", false)) and state.event_choice.is_empty())


static func event_speed(state: GameState, station: Station) -> float:
	if not event_effective(state):
		return 1.0
	var event: Dictionary = GameConfig.EVENTS[state.event_id]
	var speed := float(event.get("speed", 1.0))
	if is_equal_approx(speed, 1.0):
		return 1.0
	var scope := state.event_scope
	if scope.is_empty() or station.key == scope or station.dept_id == scope:
		return speed
	return 1.0


static func event_drowsy(state: GameState) -> float:
	if not event_effective(state):
		return 1.0
	return float(GameConfig.EVENTS[state.event_id].get("drowsy", 1.0))


static func event_duration(state: GameState, event_id: String) -> float:
	var event: Dictionary = GameConfig.EVENTS[event_id]
	var duration := float(event.get("duration", GameConfig.EVENT_DURATION))
	if bool(event.get("pending", false)):
		return GameConfig.EVENT_CHOICE_SECONDS
	var mitigation := str(event.get("mitigation", ""))
	if not mitigation.is_empty():
		duration *= event_mitigation_factor(state, mitigation)
	return duration


static func event_mitigation_factor(state: GameState, upgrade_id: String) -> float:
	var share := float(state.upgrade_level(upgrade_id)) / float(GameConfig.upgrade(upgrade_id).max)
	return 1.0 - (1.0 - GameConfig.EVENT_MIN_DURATION_FACTOR) * clampf(share, 0.0, 1.0)


static func population(state: GameState) -> int:
	return maxi(GameConfig.POPULATION_BASE, GameConfig.POPULATION_BASE + state.cases_completed * GameConfig.POPULATION_PER_CASE - state.citizens_lost * GameConfig.POPULATION_PER_LOST)


static func settlement(state: GameState) -> String:
	var inhabitants := population(state)
	var result := "village"
	for rank in GameConfig.SETTLEMENT_RANKS:
		if inhabitants >= int(rank.population):
			result = str(rank.id)
	return result


static func is_invalid_case(state: GameState, serial: int) -> bool:
	if state.cases_completed < GameConfig.REJECT_MIN_CASES:
		return false
	return float(posmod(hash([state.rng.seed, serial]), 1000)) / 1000.0 < GameConfig.REJECT_CHANCE


static func full_boxes(state: GameState, dept: Department) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null:
			continue
		if not station.is_final() and not station.has_outbox_space():
			result.append({"key": key, "side": "out"})
		if not station.has_inbox_space(state.lobby_capacity()):
			result.append({"key": key, "side": "in"})
		if station.has_reject_pile() and not station.is_shared() and not station.has_reject_space():
			result.append({"key": key, "side": "rejects"})
	return result


static func base_arrivals_per_minute(departments: int) -> float:
	if departments >= GameConfig.DEPARTMENTS.size():
		return GameConfig.MAX_ARRIVALS_PER_MINUTE
	var extra := GameConfig.ARRIVALS_PER_DEPARTMENT * maxi(0, departments - 1)
	return minf(GameConfig.MAX_ARRIVALS_PER_MINUTE, GameConfig.START_ARRIVALS_PER_MINUTE + extra)


static func arrivals_per_minute(state: GameState) -> float:
	return _capped_arrivals(base_arrivals_per_minute(state.unlocked_count()), review_arrival_factor(state))


static func arrival_interval(state: GameState) -> float:
	var departments := maxi(1, state.unlocked_count())
	return 60.0 * departments / _capped_arrivals(base_arrivals_per_minute(departments), review_arrival_factor(state))


static func _capped_arrivals(base: float, factor: float) -> float:
	return minf(GameConfig.MAX_ARRIVALS_PER_MINUTE, base * factor)


static func mail_batch(state: GameState) -> int:
	return GameConfig.MAIL_BATCH_BASE + GameConfig.MAIL_BATCH_PER_DEPT * state.mail_departments().size() + int(upgrade_value(state, "mail_subscription"))


static func mail_interval(state: GameState) -> float:
	return upgrade_value(state, "mail_frequency")


static func mail_rate(state: GameState) -> float:
	if state.mailroom() == null:
		return 0.0
	return mail_batch(state) / mail_interval(state)


static func mail_reward_factor(state: GameState) -> float:
	return upgrade_value(state, "registered_mail")


static func mail_storage_cost(station: Station) -> float:
	return GameConfig.MAIL_STORAGE_COST * pow(GameConfig.MAIL_STORAGE_GROWTH, station.storage_level) * early_discount(station.storage_level)


static func hands_on_reward(dept: Department) -> float:
	return department_fee(dept) * GameConfig.HANDS_ON_REWARD_FACTOR


static func department_fee(dept: Department) -> float:
	return float(dept.config().reward) * DepartmentRank.fee_factor(dept.rank)


static func reject_fee(state: GameState, dept: Department) -> float:
	return department_fee(dept) * reputation_multiplier(state) * GameConfig.REJECT_FEE_FACTOR


static func budget_injection(state: GameState) -> float:
	return ceilf(maxf(GameConfig.BOOST_MIN_INCOME, state.income.per_minute()) * GameConfig.BOOST_BUDGET_MINUTES)


static func multi_application_chance(others: int) -> float:
	if others <= 0:
		return 0.0
	return minf(GameConfig.MULTI_MAX_CHANCE, GameConfig.MULTI_BASE_CHANCE + GameConfig.MULTI_PER_DEPT * others)


static func downstream_keys(state: GameState, key: String) -> Array[String]:
	var result: Array[String] = []
	var probes: Array[CaseFile] = []
	if key == GameConfig.MAILROOM:
		for dept in state.mail_departments():
			var probe := CaseFile.new(dept.id)
			probe.mail = true
			probes.append(probe)
	else:
		for dept in state.departments_using(key):
			probes.append(CaseFile.new(dept.id))
	for probe in probes:
		var route := RouteBuilder.build(probe)
		var index := route.find(key)
		if index >= 0 and index + 1 < route.size() and not result.has(route[index + 1]) and state.station(route[index + 1]) != null:
			result.append(route[index + 1])
	return result


static func leave_complaint_rate(state: GameState) -> float:
	return state.production.per_minute(ProductionStats.LOST, "", state.play_time) / 60.0


static func carry_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "briefcase"))


static func player_speed(state: GameState) -> float:
	return GameConfig.PLAYER_SPEED * upgrade_value(state, "sneakers") * (GameConfig.BOOST_PLAYER_SPEED if state.is_boost_active("roller_skates") else 1.0)


static func runner_speed(state: GameState) -> float:
	return GameConfig.RUNNER_SPEED * upgrade_value(state, "runner_speed") * _skates(state)


static func coffee_intern_speed(state: GameState) -> float:
	return GameConfig.COFFEE_INTERN_SPEED * upgrade_value(state, "coffee_intern_speed")


static func _skates(state: GameState) -> float:
	return GameConfig.BOOST_RUNNER_SPEED if state.is_boost_active("roller_skates") else 1.0


static func complaint_transfer_interval(state: GameState) -> float:
	return GameConfig.COMPLAINT_TRANSFER_INTERVAL * upgrade_value(state, "shredder_blades")


static func phone_speed(state: GameState) -> float:
	return 1.0 / upgrade_value(state, "phone_training")


static func loo_slots(state: GameState) -> int:
	return clampi(int(upgrade_value(state, "toilet_stalls")), GameConfig.LOO_SLOTS, GameConfig.MAX_LOO_SLOTS)


static func wake_time(rest_state: String) -> float:
	return GameConfig.ENCOURAGE_TIME if rest_state == DeskMood.LOO else GameConfig.WAKE_TIME


static func hr_cost(state: GameState) -> float:
	return GameConfig.HR_COST * pow(GameConfig.HR_GROWTH, state.hr) * early_discount(state.hr)


static func complaint_text_index(serial: int) -> int:
	return posmod(serial * GameConfig.COMPLAINT_TEXT_STEP + 7, GameConfig.COMPLAINT_TEXTS)


static func runner_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "runner_trolleys"))


static func runner_load(state: GameState, runner: Runner) -> int:
	return runner_capacity(state) + GameConfig.RUNNER_LEVEL_CAPACITY * runner.level


static func runner_load_limit(level: int) -> int:
	return int(track_value("runner_trolleys", int(GameConfig.upgrade("runner_trolleys").max))) + GameConfig.RUNNER_LEVEL_CAPACITY * level


static func runner_level_cost(runner: Runner) -> float:
	return GameConfig.RUNNER_LEVEL_COST * pow(GameConfig.RUNNER_LEVEL_GROWTH, runner.level) * early_discount(runner.level)


static func alert_duration(state: GameState) -> float:
	return GameConfig.BASE_ALERT_SECONDS * upgrade_value(state, "coffee")


static func roll_alert(state: GameState) -> float:
	return alert_duration(state) * state.rng.randf_range(1.0 - GameConfig.ALERT_VARIANCE, 1.0 + GameConfig.ALERT_VARIANCE)


static func wake_alert(state: GameState, previous_state: String) -> float:
	var factor := 1.0
	if previous_state == DeskMood.FETCH:
		factor = upgrade_value(state, "espresso")
	elif previous_state == DeskMood.SLOW:
		factor = GameConfig.FETCH_ALERT_FACTOR
	elif previous_state == DeskMood.LUNCH:
		factor = upgrade_value(state, "canteen_menu")
	return roll_alert(state) * factor


static func doze_weights(state: GameState) -> Dictionary:
	var weights: Dictionary = GameConfig.DOZE_WEIGHTS.duplicate()
	var shift := float(weights["chat"]) * clampf(1.0 - upgrade_value(state, "kitchen"), 0.0, 1.0)
	weights["chat"] = float(weights["chat"]) - shift
	weights["fetch"] = float(weights["fetch"]) + shift
	return weights


static func drowsiness_rate(state: GameState, station: Station) -> float:
	return lead_value(state, "lead_focus", lead_room(station)) * event_drowsy(state)


static func rest_limit(state: GameState, rest_state: String, room_id: String = "") -> float:
	if rest_state == DeskMood.SICK:
		return GameConfig.SICK_SECONDS * lead_value(state, "lead_health", room_id)
	var limit := base_rest_limit(state, rest_state)
	if is_inf(limit) or rest_state == DeskMood.ASLEEP or rest_state == DeskMood.CHAT:
		return limit
	return limit * lead_value(state, "lead_breaks", room_id)


static func base_rest_limit(state: GameState, rest_state: String) -> float:
	if rest_state == DeskMood.FETCH:
		return GameConfig.FETCH_SECONDS * upgrade_value(state, "coffee_machine")
	if rest_state == DeskMood.SLOW:
		return GameConfig.SLOW_SECONDS
	if rest_state == DeskMood.SICK:
		return GameConfig.SICK_SECONDS
	if rest_state == DeskMood.LUNCH:
		return upgrade_value(state, "canteen_speed")
	var delay := upgrade_value(state, "wake_service")
	if rest_state == DeskMood.LOO:
		var loo_time := upgrade_value(state, "toilet_speed")
		return loo_time if delay < 0.0 else minf(loo_time, delay)
	if rest_state == DeskMood.COFFEE:
		return GameConfig.COFFEE_BREAK_SECONDS if delay < 0.0 else minf(GameConfig.COFFEE_BREAK_SECONDS, delay)
	return INF if delay < 0.0 else delay


static func work_power(state: GameState) -> float:
	return GameConfig.PLAYER_WORK_POWER * upgrade_value(state, "work_ethic")


static func audit_factor(state: GameState) -> float:
	return GameConfig.AUDIT_FACTOR if state.event_id == "audit_visit" else 1.0


static func case_outcome(state: GameState, case_file: CaseFile, smuggled: bool = false) -> Dictionary:
	var dept := state.department(case_file.dept_id)
	var money := department_fee(dept) * reputation_multiplier(state) * thoroughness_reward(dept)
	var rep := 0.0
	if case_file.follow_up:
		money *= GameConfig.FOLLOW_UP_REWARD_FACTOR
	if case_file.complex:
		money *= GameConfig.COMPLEX_REWARD_FACTOR
	if case_file.big:
		money *= GameConfig.BIG_CASE_REWARD_FACTOR
	if case_file.urgent:
		if case_file.is_overdue():
			rep += GameConfig.REP_URGENT_LATE
		else:
			money *= GameConfig.URGENT_REWARD_FACTOR
			rep += GameConfig.REP_URGENT_ON_TIME
	if case_file.contraband:
		money *= GameConfig.CONTRABAND_REWARD_FACTOR
		rep += GameConfig.REP_CONTRABAND
	money *= hand_reward_factor(case_file)
	if case_file.mail:
		money *= mail_reward_factor(state)
	money *= event_fee(state)
	if state.is_boost_active("fee_increase"):
		money *= GameConfig.BOOST_FEE_FACTOR
	if smuggled:
		return {"money": 0.0, "reputation": rep + GameConfig.REP_SMUGGLED * audit_factor(state)}
	if case_file.flawed:
		money *= GameConfig.FLAWED_REWARD_FACTOR
		rep += GameConfig.REP_FLAWED * audit_factor(state)
	else:
		rep += GameConfig.REP_CORRECT * audit_factor(state)
	return {"money": money, "reputation": rep}


static func hand_slots(case_file: CaseFile) -> int:
	var slots := maxi(0, case_file.route.size() - 1)
	for key in case_file.route:
		if not GameConfig.is_machine(key):
			slots += 1
	return maxi(1, slots)


static func hand_share(case_file: CaseFile) -> float:
	return clampf(float(case_file.handled) / hand_slots(case_file), 0.0, 1.0)


static func hand_reward_factor(case_file: CaseFile) -> float:
	return 1.0 + GameConfig.HAND_REWARD_BONUS * hand_share(case_file)


static func demand(state: GameState, dept: Department) -> float:
	return 1.0 / arrival_interval(state)


static func station_demand(state: GameState, key: String) -> float:
	if key == GameConfig.MAILROOM:
		return mail_rate(state)
	var total := 0.0
	for dept in state.departments_using(key):
		total += demand(state, dept)
	return total


static func station_throughput(state: GameState, station: Station) -> float:
	if station.workers() <= 0:
		return 0.0
	var case_time := station_case_time(state, station)
	return station.workers() * availability(state, station) / case_time if case_time > 0.0 else 0.0


static func station_case_time(state: GameState, station: Station) -> float:
	if station.is_mailroom():
		return float(GameConfig.station_kind(station.kind).base_time) / station_speed(state, station)
	var users := state.departments_using(station.key)
	if users.is_empty():
		return 0.0
	var total_time := 0.0
	var total_weight := 0.0
	for dept in users:
		var weight := demand(state, dept)
		var complex_chance := float(dept.config().complex_chance)
		var simple_time := base_time(station, dept, false, state)
		var complex_time := base_time(station, dept, true, state)
		total_time += weight * lerpf(simple_time, complex_time, complex_chance)
		total_weight += weight
	return total_time / total_weight / station_speed(state, station)


static func transport_throughput(state: GameState, extra_role: String = "") -> float:
	var total := total_transfer_demand(state)
	if total <= 0.0 and state.all_piped():
		return INF
	if total <= 0.0:
		var loads := (0 if extra_role.is_empty() else runner_capacity(state))
		for runner in state.runners:
			if not runner.is_reject() and not runner.is_deposit():
				loads += runner_load(state, runner)
		return loads / runner_trip_time(state)
	var result := INF
	for role in Runner.CASE_ROLES:
		var share := role_demand(state, role) / total
		if share > 0.0:
			result = minf(result, role_capacity(state, role, 1 if role == extra_role else 0) / share)
	return result


static func role_loads(state: GameState, role: String) -> int:
	var loads := 0
	for runner in state.runners:
		if runner.role == role:
			loads += runner_load(state, runner)
	return loads


static func role_capacity(state: GameState, role: String, extra: int = 0) -> float:
	var loads := extra * runner_capacity(state) + role_loads(state, role)
	return loads / (reject_trip_time(state) if role == Runner.REJECT else runner_trip_time(state))


static func reject_trip_time(state: GameState, speed_factor: float = 1.0) -> float:
	var layout := WorldLayout.get_default()
	var speed := runner_speed(state) * speed_factor
	var weighted := 0.0
	var total := 0.0
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if not station.has_reject_pile() or station.is_shared():
			continue
		var weight := demand(state, state.department(station.dept_id))
		weighted += weight * 2.0 * layout.reject_point(key).distance_to(layout.shredder_point()) / speed
		total += weight
	if total <= 0.0:
		return GameConfig.REJECT_RUNNER_TRIP_ESTIMATE
	return maxf(GameConfig.REJECT_RUNNER_TRIP_ESTIMATE, weighted / total)


static func reject_demand(state: GameState) -> float:
	if state.cases_completed < GameConfig.REJECT_MIN_CASES:
		return 0.0
	var total := 0.0
	for dept in state.unlocked_departments():
		if not dept.is_customs():
			total += demand(state, dept) * GameConfig.REJECT_CHANCE
	return total


static func runner_trip_time(state: GameState) -> float:
	return GameConfig.RUNNER_TRIP_ESTIMATE / upgrade_value(state, "runner_speed")


static func runner_share(state: GameState, dept: Department, from_key: String, to_key: String) -> float:
	if not state.tube_link(from_key, to_key):
		return 1.0
	return 0.0 if state.has_upgrade("large_capsules") else float(dept.config().complex_chance)


static func runner_transfers(state: GameState, dept: Department) -> Dictionary:
	var counts := {Runner.INTAKE: 0.0, Runner.INTERNAL: 0.0, Runner.OUTPUT: 0.0}
	var route := RouteBuilder.base_route(dept.id)
	for index in range(1, route.size()):
		var role := Runner.role_for(route[index - 1], route[index])
		counts[role] = float(counts[role]) + runner_share(state, dept, route[index - 1], route[index])
	return counts


static func department_runner_transfers(state: GameState, dept: Department) -> float:
	var total := 0.0
	for share: float in runner_transfers(state, dept).values():
		total += share
	return total


static func role_demand(state: GameState, role: String) -> float:
	if role == Runner.REJECT:
		return reject_demand(state)
	if role == Runner.DEPOSIT:
		return 0.0
	var total := 0.0
	for dept in state.unlocked_departments():
		total += demand(state, dept) * float(runner_transfers(state, dept)[role])
	return total


static func weakest_runner_role(state: GameState) -> String:
	var best := ""
	var best_ratio := INF
	for role in Runner.CASE_ROLES:
		var needed := role_demand(state, role)
		if needed <= 0.0:
			continue
		var ratio := role_capacity(state, role) / needed
		if ratio < best_ratio:
			best_ratio = ratio
			best = role
	return best if not best.is_empty() else state.least_staffed_role()


static func total_transfer_demand(state: GameState) -> float:
	var total := 0.0
	for dept in state.unlocked_departments():
		total += demand(state, dept) * department_runner_transfers(state, dept)
	return total


static func department_transport(state: GameState, dept: Department) -> float:
	var transfers := department_runner_transfers(state, dept)
	if transfers <= 0.0:
		return INF
	var capacity := transport_throughput(state)
	if is_inf(capacity):
		return INF
	var total := total_transfer_demand(state)
	var share := demand(state, dept) * transfers / total if total > 0.0 else 0.0
	return capacity * share / transfers


static func station_share(state: GameState, station: Station, dept: Department) -> float:
	var total := station_demand(state, station.key)
	if total <= 0.0:
		return 0.0
	return station_throughput(state, station) * demand(state, dept) / total


static func department_throughput(state: GameState, dept: Department) -> float:
	return float(department_flow(state, dept).throughput)


static func bottleneck(state: GameState, dept: Department) -> String:
	return str(department_flow(state, dept).bottleneck)


static func department_flow(state: GameState, dept: Department) -> Dictionary:
	var weakest := "demand"
	var weakest_value := demand(state, dept)
	var transport := department_transport(state, dept)
	if transport < weakest_value:
		weakest = "transport"
		weakest_value = transport
	var complete := true
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null:
			complete = false
			continue
		if key == GameConfig.INSPECTION and dept.is_customs():
			continue
		var value := station_share(state, station, dept)
		if value < weakest_value:
			weakest = key
			weakest_value = value
	return {"bottleneck": weakest, "throughput": weakest_value if complete else 0.0}


static func expected_case_value(state: GameState, dept: Department) -> float:
	var money := department_fee(dept) * reputation_multiplier(state) * thoroughness_reward(dept)
	money *= 1.0 + float(dept.config().complex_chance) * (GameConfig.COMPLEX_REWARD_FACTOR - 1.0)
	var error := error_chance(state, dept)
	return money * (1.0 - error + error * GameConfig.FLAWED_REWARD_FACTOR)


static func potential_income(state: GameState, dept: Department) -> float:
	return demand(state, dept) * expected_case_value(state, dept)


static func workload(state: GameState, dept: Department) -> float:
	var used := 0
	var capacity := 0
	for key in dept.station_keys():
		var station := state.station(key)
		if station == null:
			continue
		used += station.inbox.size() + station.outbox.size()
		capacity += station.inbox_capacity(state.lobby_capacity()) + station.outbox_capacity()
	return clampf(float(used) / capacity, 0.0, 1.0) if capacity > 0 else 0.0


static func resting_count(state: GameState, dept: Department) -> int:
	var count := 0
	for key in dept.station_keys():
		var station := state.station(key)
		if station != null:
			count += station.resting_count()
	return count


static func waiting_count(state: GameState, dept: Department) -> int:
	var count := 0
	var entry := state.station(GameConfig.RECEPTION if not dept.is_customs() else "customs/dock")
	if entry == null:
		return 0
	if dept.is_customs():
		for case_file in entry.inbox:
			if case_file.dept_id == dept.id:
				count += 1
		return count
	for case_file in state.citizens:
		if case_file.dept_id == dept.id and case_file.is_before_reception():
			count += 1
	return count
