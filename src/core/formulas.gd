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
	return float(GameConfig.station_kind(station.kind).desk_cost) * cost_multiplier_for(station) * pow(GameConfig.DESK_GROWTH, station.desks - 1)


static func hire_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).hire_cost) * staff_multiplier_for(station) * pow(GameConfig.HIRE_GROWTH, station.staff)


static func upgrade_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).upgrade_cost) * cost_multiplier_for(station) * pow(GameConfig.UPGRADE_GROWTH, station.level - 1)


static func specialist_cost(station: Station) -> float:
	return float(GameConfig.station_kind(station.kind).hire_cost) * GameConfig.SPECIALIST_FACTOR * staff_multiplier_for(station) * pow(GameConfig.SPECIALIST_GROWTH, station.specialists)


static func supervisor_cost(dept: Department) -> float:
	return GameConfig.SUPERVISOR_COST * department_staff_multiplier(dept.config()) * pow(GameConfig.SUPERVISOR_GROWTH, dept.supervisors)


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
	return base + float(config.get("step", 0.0)) * capped


static func upgrade_value(state: GameState, upgrade_id: String, room_id: String = "") -> float:
	return track_value(upgrade_id, state.upgrade_level(upgrade_id, room_id))


static func track_room_factor(upgrade_id: String, room_id: String) -> float:
	if room_id.is_empty():
		return 1.0
	if upgrade_id == "tube_station":
		if room_id == GameConfig.ROOM_INSPECTION:
			return GameConfig.TUBE_STATION_INSPECTION_FACTOR
		var unlock_cost := float(GameConfig.department(room_id).get("unlock_cost", 0.0))
		return maxf(1.0, unlock_cost * GameConfig.TUBE_STATION_FACTOR / GameConfig.TUBE_STATION_MIN_COST)
	return float(GameConfig.department(room_id).get("cost_multiplier", 1.0))


static func track_cost(upgrade_id: String, level: int, room_id: String = "") -> float:
	var config := GameConfig.upgrade(upgrade_id)
	return float(config.cost) * track_room_factor(upgrade_id, room_id) * pow(float(config.growth), level)


static func track_bulk_cost(upgrade_id: String, level: int, count: int, room_id: String = "") -> float:
	return geometric_sum(track_cost(upgrade_id, level, room_id), float(GameConfig.upgrade(upgrade_id).growth), count)


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


static func complaint_fend_chance(level: int) -> float:
	return track_value("complaint_clerk", level)


static func review_base_cost(state: GameState) -> float:
	return maxf(GameConfig.REVIEW_DELETE_BASE, income_per_second(state) * GameConfig.REVIEW_DELETE_INCOME_SECONDS)


static func review_delete_cost(state: GameState, review: Review) -> float:
	var stars := 5 if review.forced else review.stars
	return review_base_cost(state) * GameConfig.REVIEW_DELETE_STAR_FACTORS[clampi(stars, 1, 5) - 1] * pow(GameConfig.REVIEW_DELETE_LAWSUIT_GROWTH, review.lawsuits)


static func income_per_second(state: GameState) -> float:
	var total := 0.0
	for dept in state.unlocked_departments():
		total += department_throughput(state, dept) * expected_case_value(state, dept)
	return total


static func review_lawsuit_cost(state: GameState, review: Review) -> float:
	return review_base_cost(state) * GameConfig.REVIEW_LAWSUIT_FACTOR * pow(GameConfig.REVIEW_LAWSUIT_GROWTH, review.lawsuits)


static func review_lawsuit_chance(review: Review) -> float:
	return minf(GameConfig.REVIEW_LAWSUIT_MAX_CHANCE, GameConfig.REVIEW_LAWSUIT_CHANCE + GameConfig.REVIEW_LAWSUIT_CHANCE_STEP * review.lawsuits)


static func training_cost(station: Station, track: String, level: int) -> float:
	var config: Dictionary = GameConfig.OFFICIAL_TRAININGS[track]
	return float(GameConfig.station_kind(station.kind).hire_cost) * staff_multiplier_for(station) * float(config.cost) * pow(float(config.growth), level)


static func training_effect(track: String, level: int) -> float:
	var effect := float(GameConfig.OFFICIAL_TRAININGS[track].effect)
	if track == "stamina":
		return 1.0 - pow(effect, level)
	return effect * level


static func official_speed(mood: DeskMood) -> float:
	return 1.0 + training_effect("skill", mood.training_level("skill"))


static func official_sick_resist(mood: DeskMood) -> float:
	return training_effect("health", mood.training_level("health"))


static func official_drowsy_factor(mood: DeskMood) -> float:
	return 1.0 - training_effect("stamina", mood.training_level("stamina"))


static func official_calm(mood: DeskMood) -> float:
	return training_effect("calm", mood.training_level("calm"))


static func effective_workers(station: Station) -> float:
	var total := 0.0
	for desk in station.moods.size():
		if station.is_staffed(desk):
			total += official_speed(station.moods[desk])
	return total


static func department_calm(state: GameState, dept_id: String) -> float:
	var total := 0.0
	var count := 0
	for key in GameConfig.department_station_keys(dept_id):
		var station := state.station(key)
		if station == null or station.machine:
			continue
		for desk in station.moods.size():
			if station.is_staffed(desk):
				total += official_calm(station.moods[desk])
				count += 1
	return total / count if count > 0 else 0.0


static func intern_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "intern_training"))


static func intern_stress_free(state: GameState) -> int:
	return GameConfig.INTERN_STRESS_FREE + floori(state.upgrade_level("intern_resilience") / float(GameConfig.INTERN_STRESS_FREE_STEP))


static func intern_stress_factor(state: GameState) -> float:
	return upgrade_value(state, "intern_resilience")


static func intern_cry_seconds(state: GameState) -> float:
	return GameConfig.INTERN_CRY_SECONDS * upgrade_value(state, "intern_resilience")


static func helper_cost(state: GameState) -> float:
	return GameConfig.HELPER_COST * pow(GameConfig.HELPER_GROWTH, state.helpers.size())


static func tube_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "tube_capacity"))


static func tube_segment_capacity(state: GameState, tube_id: String) -> int:
	return tube_capacity(state) + state.tube_level(tube_id) * GameConfig.TUBE_SEGMENT_CAPACITY_PER_LEVEL


static func tube_segment_factor(level: int) -> float:
	return 1.0 + GameConfig.TUBE_SEGMENT_SPEED_PER_LEVEL * level


static func tube_segment_speed(state: GameState, tube_id: String) -> float:
	return GameConfig.TUBE_SPEED * tube_segment_factor(state.tube_level(tube_id)) * upgrade_value(state, "tube_speed")


static func tube_segment_cost(level: int) -> float:
	return GameConfig.TUBE_SEGMENT_COST * pow(GameConfig.TUBE_SEGMENT_GROWTH, level)


static func collector_cost(state: GameState) -> float:
	return GameConfig.COLLECTOR_COST * pow(GameConfig.COLLECTOR_GROWTH, state.collectors.size())


static func collector_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "collector_carts"))


static func collector_capacity_limit() -> int:
	return int(track_value("collector_carts", int(GameConfig.upgrade("collector_carts").max)))


static func coffee_intern_cost(state: GameState) -> float:
	return GameConfig.COFFEE_INTERN_COST * pow(GameConfig.COFFEE_INTERN_GROWTH, state.coffee_interns.size())


static func crowding_factor(state: GameState) -> float:
	var room := state.standing_capacity()
	if room <= 0:
		return 1.0
	var share := clampf(float(state.standing_citizens()) / float(room), 0.0, 1.0)
	return 1.0 - GameConfig.STANDING_PATIENCE_PENALTY * share


static func ticket_machines(state: GameState) -> int:
	return int(upgrade_value(state, "ticket_machines"))


static func ticket_draw_time(state: GameState) -> float:
	return upgrade_value(state, "ticket_speed") / ticket_machines(state)


static func ticket_call_time(state: GameState) -> float:
	return upgrade_value(state, "ticket_call_speed")


static func ticket_speed(by_hand: bool) -> float:
	return GameConfig.TICKET_HAND_FACTOR if by_hand else 1.0


static func ticket_draw_rate(state: GameState) -> float:
	return 1.0 / ticket_draw_time(state)


static func ticket_call_rate(state: GameState) -> float:
	return 1.0 / ticket_call_time(state)


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
	return base * upgrade_value(state, "climate_control") * (1.0 + GameConfig.DISPUTE_SUPERVISOR_RELIEF * total_supervisors(state))


static func ruckus_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.RUCKUS_MIN_INTERVAL, GameConfig.RUCKUS_MAX_INTERVAL, clampf(roll, 0.0, 1.0))
	return base * (1.0 + GameConfig.RUCKUS_GUARD_RELIEF * state.guards)


static func total_supervisors(state: GameState) -> int:
	var total := 0
	for dept in state.unlocked_departments():
		total += dept.supervisors
	return total


static func sick_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, clampf(roll, 0.0, 1.0))
	return base / maxi(1, state.staffed_officials()) * (1.0 + GameConfig.SICK_HR_RELIEF * state.hr) * upgrade_value(state, "toilet_hygiene")


static func sick_share(state: GameState) -> float:
	var interval := lerpf(GameConfig.SICK_MIN_PER_OFFICIAL, GameConfig.SICK_MAX_PER_OFFICIAL, 0.5) * (1.0 + GameConfig.SICK_HR_RELIEF * state.hr) * upgrade_value(state, "toilet_hygiene")
	return clampf(GameConfig.SICK_SECONDS / interval, 0.0, 1.0)


static func availability(state: GameState, station: Station) -> float:
	if station.machine:
		return 1.0
	var alert := alert_duration(state) / maxf(0.01, drowsiness_rate(state, station))
	var rest := 0.0
	var weights := doze_weights(state)
	for rest_state: String in weights:
		var limit := rest_limit(state, rest_state)
		rest += float(weights[rest_state]) * (GameConfig.UNATTENDED_REST_ESTIMATE if is_inf(limit) else limit)
	return alert / (alert + rest) * (1.0 - sick_share(state))


static func kranz_interval(state: GameState, roll: float) -> float:
	var base := lerpf(GameConfig.KRANZ_MIN_INTERVAL, GameConfig.KRANZ_MAX_INTERVAL, clampf(roll, 0.0, 1.0))
	return base * (1.0 + GameConfig.KRANZ_COFFEE_RELIEF * state.coffee_interns.size())


static func complaint_interval(state: GameState, roll: float) -> float:
	var base := GameConfig.COMPLAINT_INTERVAL * lerpf(0.7, 1.3, clampf(roll, 0.0, 1.0))
	return base * (1.0 + GameConfig.COMPLAINT_STAFF_RELIEF * (state.guards + state.helpers.size()))


static func sick_bonus_cost(state: GameState, tier: int) -> float:
	var minutes: float = GameConfig.SICK_BONUS_MINUTES[clampi(tier, 0, GameConfig.sick_bonus_tiers())]
	return ceilf(maxf(GameConfig.SICK_BONUS_MIN_INCOME, state.income.per_minute()) * minutes)


static func sick_bonus_price(state: GameState, mood: DeskMood, tier: int) -> float:
	return maxf(0.0, sick_bonus_cost(state, tier) - sick_bonus_cost(state, mood.bonus))


static func sick_recovery_speed(tier: int) -> float:
	return GameConfig.SICK_BONUS_SPEED[clampi(tier, 0, GameConfig.sick_bonus_tiers())]


static func sick_time_left(state: GameState, mood: DeskMood) -> float:
	return sick_time_left_with(state, mood, mood.bonus)


static func sick_time_left_with(state: GameState, mood: DeskMood, tier: int) -> float:
	if not mood.is_sick():
		return 0.0
	return maxf(0.0, rest_limit(state, DeskMood.SICK) - mood.resting) / sick_recovery_speed(maxi(tier, mood.bonus))


static func dispute_limit(state: GameState) -> float:
	var delay := upgrade_value(state, "mediation")
	return GameConfig.DISPUTE_MAX_SECONDS if delay < 0.0 else minf(GameConfig.DISPUTE_MAX_SECONDS, delay)


static func runner_cost(state: GameState) -> float:
	return GameConfig.RUNNER_COST * pow(GameConfig.RUNNER_GROWTH, state.runners.size())


static func upgrade_speed_multiplier(state: GameState, kind: String) -> float:
	if not GameConfig.UPGRADE_SPEED.has(kind):
		return 1.0
	return upgrade_value(state, str(GameConfig.UPGRADE_SPEED[kind]))


static func level_speed(level: int) -> float:
	var milestones := floori(level / float(GameConfig.LEVEL_MILESTONE_STEP))
	return (1.0 + GameConfig.LEVEL_SPEED_BONUS * (level - 1)) * pow(GameConfig.LEVEL_MILESTONE_BONUS, milestones)


static func levels_to_milestone(level: int) -> int:
	return GameConfig.LEVEL_MILESTONE_STEP - posmod(level, GameConfig.LEVEL_MILESTONE_STEP)


static func station_speed(state: GameState, station: Station) -> float:
	var speed := level_speed(station.level)
	speed *= upgrade_speed_multiplier(state, station.kind)
	var dept := state.department(station.dept_id)
	if dept != null:
		speed *= (1.0 + GameConfig.SUPERVISOR_BONUS * dept.supervisors) * upgrade_value(state, "office_equipment", dept.id)
	return speed


static func complex_time_factor(state: GameState, by_specialist: bool) -> float:
	if by_specialist:
		return 1.0
	return 1.0 + GameConfig.COMPLEX_TIME_PENALTY * upgrade_value(state, "ai_classification")


static func base_time(station: Station, case_dept: Department, complex: bool, by_specialist: bool, state: GameState) -> float:
	var config := case_dept.config()
	var time := float(GameConfig.station_kind(station.kind).base_time)
	if station.kind == "review" and station.dept_id == case_dept.id:
		time = float(config.review_time)
	elif station.kind == "signature":
		time = float(config.signature_time)
	if station.kind == "review":
		time *= float(GameConfig.THOROUGHNESS[case_dept.thoroughness].time)
	if complex and (station.kind == "review" or station.kind == "inspection"):
		time *= complex_time_factor(state, by_specialist)
	return time


static func required_time(state: GameState, station: Station, case_file: CaseFile, by_specialist: bool = false) -> float:
	var dept := state.department(case_file.dept_id)
	var time := base_time(station, dept, case_file.complex, by_specialist, state) / station_speed(state, station)
	if station.kind == "reception":
		time *= 1.0 + GameConfig.MULTI_TIME_PER_EXTRA * case_file.extras.size()
	return time * GameConfig.BIG_CASE_TIME_FACTOR if case_file.big else time


static func work_speed(state: GameState, station: Station) -> float:
	var speed := event_speed(state, station) * dispute_speed(state, station)
	if station.rush > 0.0:
		speed *= GameConfig.UPGRADE_RUSH_SPEED
	if state.is_boost_active("overtime"):
		speed *= GameConfig.BOOST_OVERTIME_SPEED
	if station.machine and state.is_boost_active("stamp_turbo"):
		speed *= GameConfig.BOOST_STAMP_SPEED
	if station.is_mailroom() and state.is_boost_active("express_post"):
		speed *= GameConfig.BOOST_POST_SPEED
	return speed


static func error_chance(state: GameState, dept: Department, by_specialist: bool = false) -> float:
	var chance := float(GameConfig.THOROUGHNESS[dept.thoroughness].error)
	chance *= upgrade_value(state, "quality_training") * upgrade_value(state, "ai_classification")
	if by_specialist:
		chance *= GameConfig.SPECIALIST_ERROR_FACTOR
	return clampf(chance, 0.0, 1.0)


static func flag_chance(station: Station) -> float:
	return clampf(GameConfig.FLAG_BASE_CHANCE + GameConfig.FLAG_PER_SPECIALIST * station.specialists, 0.0, 1.0)


static func reputation_multiplier(state: GameState) -> float:
	return 1.0 + sqrt(state.reputation) / GameConfig.REPUTATION_REWARD_DIVISOR


static func popularity(state: GameState) -> float:
	return minf(1.0 + sqrt(state.reputation) / GameConfig.POPULARITY_DIVISOR, GameConfig.MAX_POPULARITY)


static func rating_factor(state: GameState) -> float:
	if state.reviews.is_empty():
		return 1.0
	return lerpf(GameConfig.RATING_ARRIVAL_MIN, GameConfig.RATING_ARRIVAL_MAX, clampf((state.average_rating() - 1.0) / 4.0, 0.0, 1.0))


static func event_fee(state: GameState) -> float:
	if not event_effective(state):
		return 1.0
	return float(GameConfig.EVENTS[state.event_id].get("fee", 1.0))


static func event_arrival_multiplier(state: GameState, dept_id: String) -> float:
	if state.event_id.is_empty():
		return 1.0
	var event: Dictionary = GameConfig.EVENTS[state.event_id]
	var target := str(event.department) if not str(event.department).is_empty() else state.event_scope
	if target.is_empty() or target == dept_id:
		return float(event.arrival)
	return 1.0


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


static func event_patience(state: GameState) -> float:
	if not event_effective(state):
		return 1.0
	return float(GameConfig.EVENTS[state.event_id].get("patience", 1.0))


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


static func demand_growth(state: GameState) -> float:
	return 1.0 + GameConfig.DEMAND_GROWTH_SCALE * log(1.0 + state.cases_completed / GameConfig.DEMAND_GROWTH_DIVISOR) / log(10.0)


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
		if station.has_reject_pile() and not station.has_reject_space():
			result.append({"key": key, "side": "rejects"})
	return result


static func arrival_interval(state: GameState, dept: Department) -> float:
	var rate := popularity(state)
	rate *= upgrade_value(state, "online_portal")
	rate *= event_arrival_multiplier(state, dept.id)
	rate *= demand_growth(state)
	rate *= rating_factor(state)
	if state.is_boost_active("gazette_ad"):
		rate *= GameConfig.BOOST_ARRIVAL_FACTOR
	return float(dept.config().arrival_interval) / rate


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
	return GameConfig.MAIL_STORAGE_COST * pow(GameConfig.MAIL_STORAGE_GROWTH, station.storage_level)


static func hands_on_reward(dept: Department) -> float:
	return float(dept.config().reward) * GameConfig.HANDS_ON_REWARD_FACTOR


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


static func patience(state: GameState) -> float:
	return GameConfig.BASE_PATIENCE * upgrade_value(state, "comfortable_lobby") * event_patience(state)


static func patience_factor(state: GameState, serial: int) -> float:
	if state.cases_completed < GameConfig.PATIENCE_SPREAD_MIN_CASES:
		return 1.0
	var roll := float(posmod(hash([state.rng.seed, serial, GameConfig.PATIENCE_HASH_SALT]), 1000)) / 1000.0
	return lerpf(GameConfig.PATIENCE_MIN_FACTOR, GameConfig.PATIENCE_MAX_FACTOR, roll)


static func citizen_patience(state: GameState, case_file: CaseFile, crowding: float = 1.0) -> float:
	return patience(state) * crowding * case_file.patience_factor


static func leave_complaint_chance(case_file: CaseFile) -> float:
	return clampf(GameConfig.LEAVE_COMPLAINT_CHANCE * case_file.patience_factor, 0.0, 1.0)


static func leave_complaint_rate(state: GameState) -> float:
	var lost := state.production.per_minute(ProductionStats.LOST, "", state.play_time) / 60.0
	return minf(lost * GameConfig.LEAVE_COMPLAINT_CHANCE, 1.0 / GameConfig.LEAVE_COMPLAINT_COOLDOWN)


static func carry_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "briefcase"))


static func player_speed(state: GameState) -> float:
	return GameConfig.PLAYER_SPEED * upgrade_value(state, "sneakers") * (GameConfig.BOOST_PLAYER_SPEED if state.is_boost_active("roller_skates") else 1.0)


static func runner_speed(state: GameState) -> float:
	return GameConfig.RUNNER_SPEED * upgrade_value(state, "runner_speed") * _skates(state)


static func collector_speed(state: GameState) -> float:
	return GameConfig.COLLECTOR_SPEED * upgrade_value(state, "collector_speed") * _skates(state)


static func coffee_intern_speed(state: GameState) -> float:
	return GameConfig.COFFEE_INTERN_SPEED * upgrade_value(state, "coffee_intern_speed")


static func _skates(state: GameState) -> float:
	return GameConfig.BOOST_RUNNER_SPEED if state.is_boost_active("roller_skates") else 1.0


static func complaint_transfer_interval(state: GameState) -> float:
	return GameConfig.COMPLAINT_TRANSFER_INTERVAL * upgrade_value(state, "shredder_blades")


static func shredder_interval(state: GameState, dept_id: String) -> float:
	return upgrade_value(state, "shredder", dept_id)


static func phone_speed(state: GameState) -> float:
	return 1.0 / upgrade_value(state, "phone_training")


static func loo_slots(state: GameState) -> int:
	return clampi(int(upgrade_value(state, "toilet_stalls")), GameConfig.LOO_SLOTS, GameConfig.MAX_LOO_SLOTS)


static func wake_time(rest_state: String) -> float:
	return GameConfig.ENCOURAGE_TIME if rest_state == DeskMood.LOO else GameConfig.WAKE_TIME


static func hr_cost(state: GameState) -> float:
	return GameConfig.HR_COST * pow(GameConfig.HR_GROWTH, state.hr)


static func guard_cost(state: GameState) -> float:
	return GameConfig.GUARD_COST * pow(GameConfig.GUARD_GROWTH, state.guards)


static func guard_chance(state: GameState) -> float:
	return clampf(upgrade_value(state, "guard_training"), 0.0, 1.0)


static func guard_block_chance(state: GameState) -> float:
	return 1.0 - pow(1.0 - guard_chance(state), state.guards)


static func complaint_text_index(serial: int) -> int:
	return posmod(serial * GameConfig.COMPLAINT_TEXT_STEP + 7, GameConfig.COMPLAINT_TEXTS)


static func runner_capacity(state: GameState) -> int:
	return int(upgrade_value(state, "runner_trolleys"))


static func runner_load(state: GameState, runner: Runner) -> int:
	return runner_capacity(state) + GameConfig.RUNNER_LEVEL_CAPACITY * runner.level


static func runner_level_cost(runner: Runner) -> float:
	return GameConfig.RUNNER_LEVEL_COST * pow(GameConfig.RUNNER_LEVEL_GROWTH, runner.level)


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
	return roll_alert(state) * factor


static func doze_weights(state: GameState) -> Dictionary:
	var weights: Dictionary = GameConfig.DOZE_WEIGHTS.duplicate()
	var shift := float(weights["chat"]) * clampf(1.0 - upgrade_value(state, "kitchen"), 0.0, 1.0)
	weights["chat"] = float(weights["chat"]) - shift
	weights["fetch"] = float(weights["fetch"]) + shift
	return weights


static func drowsiness_rate(state: GameState, station: Station) -> float:
	var supervisors := 0
	var dept := state.department(station.dept_id)
	if dept != null:
		supervisors = dept.supervisors
	else:
		for user in state.departments_using(station.key):
			supervisors = maxi(supervisors, user.supervisors)
	return pow(GameConfig.SUPERVISOR_DROWSY_FACTOR, supervisors) * event_drowsy(state)


static func rest_limit(state: GameState, rest_state: String) -> float:
	if rest_state == DeskMood.FETCH:
		return GameConfig.FETCH_SECONDS * upgrade_value(state, "coffee_machine")
	if rest_state == DeskMood.SLOW:
		return GameConfig.SLOW_SECONDS
	if rest_state == DeskMood.SICK:
		return GameConfig.SICK_SECONDS
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
	var config := GameConfig.department(case_file.dept_id)
	var money := float(config.reward) * reputation_multiplier(state)
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
	return 1.0 / arrival_interval(state, dept)


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
	var case_time := station_case_time(state, station, station.specialists > 0)
	return effective_workers(station) * availability(state, station) / case_time if case_time > 0.0 else 0.0


static func station_case_time(state: GameState, station: Station, with_specialist: bool) -> float:
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
		var simple_time := base_time(station, dept, false, false, state)
		var complex_time := base_time(station, dept, true, with_specialist, state)
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
			loads += runner_load(state, runner)
		return loads / runner_trip_time(state)
	var result := INF
	for role in Runner.ROLES:
		var share := role_demand(state, role) / total
		if share > 0.0:
			result = minf(result, role_capacity(state, role, 1 if role == extra_role else 0) / share)
	return result


static func role_capacity(state: GameState, role: String, extra: int = 0) -> float:
	var loads := extra * runner_capacity(state)
	for runner in state.runners:
		if runner.role == role:
			loads += runner_load(state, runner)
	return loads / runner_trip_time(state)


static func runner_trip_time(state: GameState) -> float:
	return GameConfig.RUNNER_TRIP_ESTIMATE / upgrade_value(state, "runner_speed")


static func runner_share(state: GameState, dept: Department, from_key: String, to_key: String) -> float:
	if not state.tube_link(from_key, to_key):
		return 1.0
	return 0.0 if state.has_upgrade("large_capsules") else float(dept.config().complex_chance)


static func runner_transfers(state: GameState, dept: Department) -> Dictionary:
	var counts := {Runner.INTAKE: 0.0, Runner.INTERNAL: 0.0, Runner.OUTPUT: 0.0}
	var route := RouteBuilder.build(CaseFile.new(dept.id))
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
	var total := 0.0
	for dept in state.unlocked_departments():
		total += demand(state, dept) * float(runner_transfers(state, dept)[role])
	return total


static func weakest_runner_role(state: GameState) -> String:
	var best := ""
	var best_ratio := INF
	for role in Runner.ROLES:
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
	var result := minf(demand(state, dept), department_transport(state, dept))
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null:
			return 0.0
		if key == GameConfig.INSPECTION and dept.is_customs():
			continue
		result = minf(result, station_share(state, station, dept))
	return result


static func bottleneck(state: GameState, dept: Department) -> String:
	var weakest := "demand"
	var weakest_value := demand(state, dept)
	var transport := department_transport(state, dept)
	if transport < weakest_value:
		weakest = "transport"
		weakest_value = transport
	for key in RouteBuilder.required_stations(dept.id):
		var station := state.station(key)
		if station == null or (key == GameConfig.INSPECTION and dept.is_customs()):
			continue
		var value := station_share(state, station, dept)
		if value < weakest_value:
			weakest = key
			weakest_value = value
	return weakest


static func expected_case_value(state: GameState, dept: Department) -> float:
	var config := dept.config()
	var money := float(config.reward) * reputation_multiplier(state)
	money *= 1.0 + float(config.complex_chance) * (GameConfig.COMPLEX_REWARD_FACTOR - 1.0)
	var error := error_chance(state, dept)
	return money * (1.0 - error + error * GameConfig.FLAWED_REWARD_FACTOR)


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
	for case_file in entry.inbox:
		if case_file.dept_id == dept.id:
			count += 1
	if not dept.is_customs():
		for holders: Array[CaseFile] in [state.ticket_line, state.ticket_waiting]:
			for case_file in holders:
				if case_file.dept_id == dept.id:
					count += 1
	return count
