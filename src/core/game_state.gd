class_name GameState
extends RefCounted

const SAVE_VERSION := 2

var money := GameConfig.START_MONEY
var reputation := 0.0
var reputation_peak := 0.0
var reputation_loss_budget := GameConfig.REP_MAX_LOSS_PER_MINUTE
var seals := GameConfig.START_SEALS
var boosts: Dictionary[String, float] = {}
var boost_cooldowns: Dictionary[String, float] = {}
var ads_watched := 0
var boosts_used := 0
var mail_timer := GameConfig.MAIL_FIRST_SECONDS
var mail_received := 0
var mail_returned := 0
var mail_promised: Array[String] = []
var bundles := 0
var kranz_elapsed := 0.0
var building_stage := 0
var goal_index := 0
var tutorial_step := 0
var departments: Dictionary[String, Department] = {}
var stations: Dictionary[String, Station] = {}
var research: Dictionary[String, int] = {}
var player := Player.new()
var runners: Array[Runner] = []
var collectors: Array[RejectCollector] = []
var tube_parcels: Array[TubeParcel] = []
var coffee_interns: Array[CoffeeIntern] = []
var visitors: Array[ComplaintVisitor] = []
var disputes: Array[Dispute] = []
var calls: Array[PhoneCall] = []
var intern := ComplaintIntern.new(WorldLayout.get_default().intern_home())
var helpers: Array[ComplaintIntern] = []
var event_id := ""
var event_time_left := 0.0
var event_cooldown := GameConfig.EVENT_FIRST_COOLDOWN
var event_scope := ""
var event_choice := ""
var cases_spawned := 0
var cases_rejected := 0
var cases_completed := 0
var cases_flawed := 0
var citizens_lost := 0
var cases_shredded := 0
var contraband_seized := 0
var staff_hired := 0
var wakes := 0
var trainings := 0
var complaints := 0
var reviews: Array[Review] = []
var review_seq := 0
var review_fear := 0.0
var complaint_tube_timer := 0.0
var complaints_shredded := 0
var complaint_timer := GameConfig.COMPLAINT_INTERVAL
var leave_complaint_cooldown := 0.0
var complaints_filed := 0
var complaints_fended := 0
var complaint_clerk_level := 0
var complaint_box_level := 0
var shred_timer: float:
	get:
		return intern.work_timer
	set(value):
		intern.work_timer = value
var yell_timer := GameConfig.YELL_INTERVAL
var dispute_timer := GameConfig.DISPUTE_FIRST_SECONDS
var waiting_level := 0
var walkouts := 0
var seating_level := 0
var breakdowns := 0
var coffees_served := 0
var disputes_solved := 0
var kranz := false
var hr := 0
var guards := 0
var visitors_stopped := 0
var sick_timer := GameConfig.SICK_FIRST_SECONDS
var calls_made := 0
var bonuses_paid := 0
var calls_answered := 0
var calls_missed := 0
var kranz_timer := GameConfig.KRANZ_FIRST_SECONDS
var kranz_progress := 0.0
var money_earned := 0.0
var income := IncomeTracker.new()
var production := ProductionStats.new()
var play_time := 0.0
var saved_at := 0
var rng := RandomNumberGenerator.new()
var life_rng := RandomNumberGenerator.new()
var review_rng := RandomNumberGenerator.new()
var _ordered_keys: Array[String] = []
var _ordered_signature := -1


func _init() -> void:
	for dept_id in GameConfig.department_ids():
		departments[dept_id] = Department.new(dept_id)
	for research_id in GameConfig.RESEARCH_ORDER:
		research[research_id] = 0
	player.position = WorldLayout.get_default().player_start()


static func create_new(seed_value: int = -1) -> GameState:
	var state := GameState.new()
	if seed_value >= 0:
		state.rng.seed = seed_value
	else:
		state.rng.randomize()
	state.life_rng.seed = state.rng.seed + 1
	state.review_rng.seed = state.rng.seed + 2
	state.unlock_department("general_services")
	state.station("general_services/review").staff = 1
	return state


func department(dept_id: String) -> Department:
	return departments.get(dept_id)


func station(key: String) -> Station:
	return stations.get(key)


func unlocked_departments() -> Array[Department]:
	var result: Array[Department] = []
	for dept_id in GameConfig.department_ids():
		if departments[dept_id].unlocked:
			result.append(departments[dept_id])
	return result


func has_tube(dept_id: String) -> bool:
	var dept := department(dept_id)
	return dept != null and dept.tube and has_research("pneumatic_tubes")


func is_piped(case_file: CaseFile) -> bool:
	return has_tube(case_file.dept_id)


func any_piped() -> bool:
	return unlocked_departments().any(func(dept: Department) -> bool: return has_tube(dept.id))


func all_piped() -> bool:
	var unlocked := unlocked_departments()
	return not unlocked.is_empty() and unlocked.all(func(dept: Department) -> bool: return has_tube(dept.id))


func connect_all_tubes() -> void:
	for dept in unlocked_departments():
		dept.tube = true


func unlocked_count() -> int:
	return unlocked_departments().size()


func stage_config() -> Dictionary:
	return GameConfig.building_stage(building_stage)


func lobby_capacity() -> int:
	return int(stage_config().lobby) + waiting_level * GameConfig.WAITING_SEATS_PER_LEVEL


func seat_capacity() -> int:
	return GameConfig.SEATING_BASE_SEATS + seating_level * GameConfig.SEATING_SEATS_PER_LEVEL


func seated_citizens() -> int:
	var count := 0
	for key in stations:
		if key == GameConfig.RECEPTION or key == GameConfig.MAILROOM or key.begins_with("customs/"):
			continue
		for case_file in stations[key].all_cases():
			if case_file.takes_seat():
				count += 1
	for case_file in carried_cases():
		if case_file.takes_seat():
			count += 1
	return count


func has_free_seat() -> bool:
	return seated_citizens() < seat_capacity()


func reception_may_admit() -> bool:
	var reception_station := station(GameConfig.RECEPTION)
	var pending := reception_station.outbox.size()
	for job in reception_station.jobs:
		if job != null:
			pending += 1
	return seated_citizens() + pending < seat_capacity()


func max_desks() -> int:
	return int(stage_config().max_desks)


func research_level(research_id: String) -> int:
	return research.get(research_id, 0)


func has_research(research_id: String) -> bool:
	return research_level(research_id) > 0


func unlock_department(dept_id: String) -> void:
	var dept := department(dept_id)
	if dept == null or dept.unlocked:
		return
	dept.unlocked = true
	for key in RouteBuilder.required_stations(dept_id):
		if not stations.has(key):
			stations[key] = Station.new(key)


func mail_unlocked() -> bool:
	return building_stage >= GameConfig.MAIL_UNLOCK_STAGE


func mailroom() -> Station:
	return stations.get(GameConfig.MAILROOM)


func ensure_mailroom() -> Station:
	if mail_unlocked() and not stations.has(GameConfig.MAILROOM):
		stations[GameConfig.MAILROOM] = Station.new(GameConfig.MAILROOM)
	return mailroom()


func mail_departments() -> Array[Department]:
	var result: Array[Department] = []
	for dept in unlocked_departments():
		if not dept.is_customs():
			result.append(dept)
	return result


func staffed_officials() -> int:
	var count := 0
	for key in ordered_station_keys():
		var item := stations[key]
		if item.machine:
			continue
		for desk in item.moods.size():
			if item.is_staffed(desk):
				count += 1
	return count


func is_boost_active(boost_id: String) -> bool:
	return boosts.get(boost_id, 0.0) > 0.0


func boost_left(boost_id: String) -> float:
	return boosts.get(boost_id, 0.0)


func boost_cooldown(boost_id: String) -> float:
	return boost_cooldowns.get(boost_id, 0.0)


func advance_boosts(delta: float) -> void:
	for boost_id in boosts.keys():
		boosts[boost_id] -= delta
		if boosts[boost_id] <= 0.0:
			boosts.erase(boost_id)
	for boost_id in boost_cooldowns.keys():
		boost_cooldowns[boost_id] -= delta
		if boost_cooldowns[boost_id] <= 0.0:
			boost_cooldowns.erase(boost_id)


func departments_using(key: String) -> Array[Department]:
	var result: Array[Department] = []
	for dept in unlocked_departments():
		if RouteBuilder.required_stations(dept.id).has(key):
			result.append(dept)
	return result


func ordered_station_keys() -> Array[String]:
	var signature := stations.size()
	for dept_id in GameConfig.department_ids():
		signature = signature * 2 + (1 if departments[dept_id].unlocked else 0)
	if signature != _ordered_signature:
		_ordered_signature = signature
		_ordered_keys = _compute_ordered_keys()
	return _ordered_keys


func kitchen_slot_taken(slot: int) -> bool:
	for key in stations:
		for mood in stations[key].moods:
			if mood.is_away() and mood.slot == slot:
				return true
	return false


func free_kitchen_slot(start: int = 0) -> int:
	for offset in GameConfig.KITCHEN_SLOTS:
		var slot := (start + offset) % GameConfig.KITCHEN_SLOTS
		if not kitchen_slot_taken(slot):
			return slot
	return -1


func sick_count() -> int:
	var count := 0
	for key in ordered_station_keys():
		var station := stations[key]
		for desk in station.moods.size():
			if station.is_staffed(desk) and station.moods[desk].is_sick():
				count += 1
	return count


func ringing_count() -> int:
	var count := 0
	for phone_call in calls:
		if phone_call.is_incoming() and phone_call.is_ringing():
			count += 1
	return count


func reported_sick_count() -> int:
	var count := 0
	for key in ordered_station_keys():
		var station := stations[key]
		for desk in station.moods.size():
			if station.is_staffed(desk) and station.moods[desk].can_be_called():
				count += 1
	return count


func line_call(line: int) -> PhoneCall:
	for phone_call in calls:
		if phone_call.line == line:
			return phone_call
	return null


func call_for(key: String, desk: int) -> PhoneCall:
	for phone_call in calls:
		if phone_call.targets(key, desk):
			return phone_call
	return null


func free_loo_slot() -> int:
	for slot in range(GameConfig.KITCHEN_SLOTS, GameConfig.KITCHEN_SLOTS + GameConfig.LOO_SLOTS):
		if not kitchen_slot_taken(slot):
			return slot
	return -1


func _slot_valid(mood: DeskMood) -> bool:
	if mood.state == DeskMood.LOO:
		return mood.slot >= GameConfig.KITCHEN_SLOTS
	return mood.slot >= 0 and mood.slot < GameConfig.KITCHEN_SLOTS


func _repair_kitchen_slots() -> void:
	var used := {}
	var broken: Array[DeskMood] = []
	for fetching in [false, true]:
		for key in stations:
			for mood in stations[key].moods:
				if not mood.is_away() or (mood.state == DeskMood.FETCH) != fetching:
					continue
				if _slot_valid(mood) and not used.has(mood.slot):
					used[mood.slot] = true
				else:
					broken.append(mood)
	for mood in broken:
		var free := -1
		var first := GameConfig.KITCHEN_SLOTS if mood.state == DeskMood.LOO else 0
		var last := GameConfig.KITCHEN_SLOTS + GameConfig.LOO_SLOTS if mood.state == DeskMood.LOO else GameConfig.KITCHEN_SLOTS
		for slot in range(first, last):
			if not used.has(slot):
				free = slot
				break
		if free < 0:
			mood.rest(DeskMood.ASLEEP)
		else:
			mood.slot = free
			used[free] = true


func _compute_ordered_keys() -> Array[String]:
	var keys: Array[String] = []
	if stations.has(GameConfig.MAILROOM):
		keys.append(GameConfig.MAILROOM)
	for dept in unlocked_departments():
		for key in RouteBuilder.required_stations(dept.id):
			if not keys.has(key) and stations.has(key):
				keys.append(key)
	return keys


func total_staff() -> int:
	var count := runners.size() + collectors.size() + coffee_interns.size() + helpers.size()
	for key in stations:
		var item := stations[key]
		count += item.specialists + (0 if item.machine else item.staff)
	for dept in unlocked_departments():
		count += dept.supervisors
	return count


func max_station_level() -> int:
	var best := 0
	for key in stations:
		best = maxi(best, stations[key].level)
	return best


func research_count() -> int:
	var count := 0
	for research_id in research:
		count += research[research_id]
	return count


func negative_review_count() -> int:
	var count := 0
	for review in reviews:
		if review.is_negative():
			count += 1
	return count


func pile_complaint_serials(limit: int) -> Array[int]:
	var result: Array[int] = []
	for offset in mini(complaints, limit):
		result.append(complaints_filed - 1 - offset)
	return result


func review_drain() -> float:
	var total := 0.0
	for review in reviews:
		total += review.drain_weight()
	return total


func find_review(review_id: int) -> Review:
	for review in reviews:
		if review.id == review_id:
			return review
	return null


func star_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for review in reviews:
		counts[review.stars - 1] += 1
	return counts


func average_rating() -> float:
	if reviews.is_empty():
		return 0.0
	var total := 0
	for review in reviews:
		total += review.stars
	return float(total) / float(reviews.size())


func add_review(stars: int, forced_text: int = -1) -> Review:
	var review := Review.new(
		review_seq,
		stars,
		review_rng.randi_range(0, GameConfig.review_texts(stars) - 1),
		review_rng.randi_range(0, GameConfig.REVIEW_AUTHORS - 1),
		play_time
	)
	if forced_text >= 0:
		review.force_praise(forced_text)
	review_seq += 1
	reviews.append(review)
	_trim_reviews()
	return review


func _trim_reviews() -> void:
	while reviews.size() > GameConfig.MAX_STORED_REVIEWS:
		var drop := 0
		for index in reviews.size():
			if not reviews[index].is_negative():
				drop = index
				break
		reviews.remove_at(drop)


func review_time_left(review: Review) -> float:
	return maxf(0.0, GameConfig.REVIEW_LIFETIME - (play_time - review.posted_at))


func expire_reviews() -> int:
	var removed := 0
	for index in range(reviews.size() - 1, -1, -1):
		if review_time_left(reviews[index]) <= 0.0:
			reviews.remove_at(index)
			removed += 1
	return removed


func _restore_reviews(entries: Variant) -> void:
	reviews.clear()
	if entries is float or entries is int:
		for index in clampi(int(entries), 0, GameConfig.MAX_NEGATIVE_REVIEWS):
			var legacy := Review.new(index, 1, index % GameConfig.review_texts(1), index % GameConfig.REVIEW_AUTHORS, play_time)
			reviews.append(legacy)
		review_seq = reviews.size()
		return
	if not entries is Array:
		return
	var highest := -1
	for entry in entries:
		var review := Review.from_dict(entry)
		if review != null and reviews.size() < GameConfig.MAX_STORED_REVIEWS and find_review(review.id) == null:
			review.posted_at = minf(review.posted_at, play_time)
			reviews.append(review)
			highest = maxi(highest, review.id)
	review_seq = highest + 1


func add_reputation(amount: float) -> void:
	if amount >= 0.0:
		reputation += amount
		reputation_peak = maxf(reputation_peak, reputation)
		return
	var loss := minf(-amount * GameConfig.REP_LOSS_FACTOR, reputation_loss_budget)
	reputation_loss_budget -= loss
	reputation = maxf(0.0, reputation - loss)


func refill_loss_budget(delta: float) -> void:
	reputation_loss_budget = minf(GameConfig.REP_MAX_LOSS_PER_MINUTE, reputation_loss_budget + GameConfig.REP_MAX_LOSS_PER_MINUTE * delta / 60.0)


func standing() -> float:
	return maxf(reputation, reputation_peak)


func earn(amount: float) -> void:
	money += amount
	money_earned += maxf(amount, 0.0)


func grant(amount: float) -> void:
	money += amount


func rejects_waiting() -> int:
	var total := 0
	for key in stations:
		total += stations[key].rejects
	return total


func can_afford(cost: float) -> bool:
	return money + 0.0001 >= cost


func spend(cost: float) -> bool:
	if not can_afford(cost):
		return false
	money = maxf(0.0, money - cost)
	return true


func add_runner(role: String = "") -> Runner:
	var runner := Runner.new(WorldLayout.get_default().runner_home() + Vector2(runners.size() * 18.0, 0))
	runner.role = role if Runner.ROLES.has(role) else least_staffed_role()
	runners.append(runner)
	return runner


func runners_in(role: String) -> int:
	var count := 0
	for runner in runners:
		if runner.role == role:
			count += 1
	return count


func transfer_backlog(role: String) -> int:
	var count := 0
	for key in ordered_station_keys():
		for case_file in station(key).outbox:
			if not is_piped(case_file) and Runner.role_for(key, case_file.next_key()) == role:
				count += 1
	return count


func least_staffed_role() -> String:
	var best := Runner.ROLES[0]
	for role in Runner.ROLES:
		if runners_in(role) < runners_in(best):
			best = role
	return best


func all_interns() -> Array[ComplaintIntern]:
	var units: Array[ComplaintIntern] = [intern]
	units.append_array(helpers)
	return units


func add_helper() -> ComplaintIntern:
	var slot := helpers.size() + 1
	var helper := ComplaintIntern.new(WorldLayout.get_default().intern_home(slot))
	helper.slot = slot
	helpers.append(helper)
	return helper


func add_collector() -> RejectCollector:
	var collector := RejectCollector.new(WorldLayout.get_default().collector_home() + Vector2(collectors.size() * 18.0, 0))
	collectors.append(collector)
	return collector


func add_coffee_intern() -> CoffeeIntern:
	var layout := WorldLayout.get_default()
	var coffee_intern := CoffeeIntern.new(layout.coffee_home() + Vector2(coffee_interns.size() * 18.0, 0))
	coffee_interns.append(coffee_intern)
	return coffee_intern


func dispute_in(dept_id: String) -> Dispute:
	for dispute in disputes:
		if dispute.dept_id == dept_id:
			return dispute
	return null


func carried_cases() -> Array[CaseFile]:
	var cases: Array[CaseFile] = []
	cases.append_array(player.items)
	for runner in runners:
		cases.append_array(runner.items)
	for parcel in tube_parcels:
		cases.append(parcel.case_file)
	return cases


func to_dict() -> Dictionary:
	var dept_data := {}
	for dept_id in departments:
		dept_data[dept_id] = departments[dept_id].to_dict()
	var station_data := {}
	for key in stations:
		station_data[key] = stations[key].to_dict()
	return {
		"version": SAVE_VERSION,
		"money": money,
		"reputation": reputation,
		"reputation_peak": standing(),
		"seals": seals,
		"boosts": boosts.duplicate(),
		"boost_cooldowns": boost_cooldowns.duplicate(),
		"ads_watched": ads_watched,
		"boosts_used": boosts_used,
		"mail_timer": mail_timer,
		"mail_received": mail_received,
		"mail_returned": mail_returned,
		"mail_promised": mail_promised.duplicate(),
		"bundles": bundles,
		"building_stage": building_stage,
		"goal_index": goal_index,
		"tutorial_step": tutorial_step,
		"departments": dept_data,
		"stations": station_data,
		"research": research.duplicate(),
		"player": player.to_dict(),
		"runners": runners.map(func(r: Runner) -> Dictionary: return r.to_dict()),
		"tube_parcels": tube_parcels.map(func(t: TubeParcel) -> Dictionary: return t.to_dict()),
		"collectors": collectors.map(func(c: RejectCollector) -> Dictionary: return c.to_dict()),
		"coffee_interns": coffee_interns.map(func(c: CoffeeIntern) -> Dictionary: return c.to_dict()),
		"disputes": disputes.map(func(d: Dispute) -> Dictionary: return d.to_dict()),
		"intern": intern.to_dict(),
		"reviews": reviews.map(func(r: Review) -> Dictionary: return r.to_dict()),
		"review_seq": review_seq,
		"review_fear": review_fear,
		"helpers": helpers.map(func(h: ComplaintIntern) -> Dictionary: return h.to_dict()),
		"dispute_timer": dispute_timer,
		"waiting_level": waiting_level,
		"seating_level": seating_level,
		"complaint_clerk_level": complaint_clerk_level,
		"complaint_box_level": complaint_box_level,
		"walkouts": walkouts,
		"breakdowns": breakdowns,
		"coffees_served": coffees_served,
		"disputes_solved": disputes_solved,
		"event_id": event_id,
		"event_time_left": event_time_left,
		"event_cooldown": event_cooldown,
		"event_scope": event_scope,
		"event_choice": event_choice,
		"cases_spawned": cases_spawned,
		"cases_rejected": cases_rejected,
		"cases_completed": cases_completed,
		"cases_flawed": cases_flawed,
		"citizens_lost": citizens_lost,
		"cases_shredded": cases_shredded,
		"contraband_seized": contraband_seized,
		"staff_hired": staff_hired,
		"wakes": wakes,
		"trainings": trainings,
		"complaints": complaints,
		"complaints_shredded": complaints_shredded,
		"complaint_timer": complaint_timer,
		"complaints_filed": complaints_filed,
		"complaints_fended": complaints_fended,
		"kranz": kranz,
		"hr": hr,
		"guards": guards,
		"sick_timer": sick_timer,
		"calls_made": calls_made,
		"bonuses_paid": bonuses_paid,
		"calls_answered": calls_answered,
		"visitors_stopped": visitors_stopped,
		"calls_missed": calls_missed,
		"kranz_timer": kranz_timer,
		"money_earned": money_earned,
		"play_time": play_time,
		"saved_at": saved_at,
		"rng_seed": str(rng.seed),
		"rng_state": str(rng.state),
	}


static func from_dict(data: Dictionary) -> GameState:
	var state := GameState.new()
	if int(data.get("version", 0)) != SAVE_VERSION:
		state.rng.randomize()
		state.unlock_department("general_services")
		state.station("general_services/review").staff = 1
		return state
	state.money = maxf(0.0, float(data.get("money", GameConfig.START_MONEY)))
	state.reputation = maxf(0.0, float(data.get("reputation", 0.0)))
	state.reputation_peak = maxf(state.reputation, float(data.get("reputation_peak", 0.0)))
	state.seals = maxi(0, int(data.get("seals", GameConfig.START_SEALS)))
	state._restore_boost_timers(state.boosts, data.get("boosts", {}), "duration")
	state._restore_boost_timers(state.boost_cooldowns, data.get("boost_cooldowns", {}), "cooldown")
	state.ads_watched = maxi(0, int(data.get("ads_watched", 0)))
	state.boosts_used = maxi(0, int(data.get("boosts_used", 0)))
	state.mail_timer = clampf(float(data.get("mail_timer", GameConfig.MAIL_FIRST_SECONDS)), 0.0, GameConfig.MAIL_INTERVAL)
	state.mail_received = maxi(0, int(data.get("mail_received", 0)))
	state.mail_returned = maxi(0, int(data.get("mail_returned", 0)))
	for dept_id in data.get("mail_promised", []):
		if not GameConfig.department(str(dept_id)).is_empty() and not GameConfig.is_customs(str(dept_id)):
			state.mail_promised.append(str(dept_id))
	state.bundles = maxi(0, int(data.get("bundles", 0)))
	state.building_stage = clampi(int(data.get("building_stage", 0)), 0, GameConfig.BUILDING_STAGES.size() - 1)
	state.goal_index = clampi(int(data.get("goal_index", 0)), 0, GameConfig.GOALS.size())
	state.tutorial_step = Tutorial.clamp_saved(int(data.get("tutorial_step", Tutorial.FINISHED)))
	var dept_data: Dictionary = data.get("departments", {})
	var legacy_tube := int((data.get("research", {}) as Dictionary).get("pneumatic_tubes", 0)) > 0
	for dept_id in dept_data:
		if state.departments.has(dept_id):
			state.departments[dept_id] = Department.from_dict(dept_data[dept_id], legacy_tube)
	var station_data: Dictionary = data.get("stations", {})
	for key in station_data:
		var restored := Station.from_dict(station_data[key])
		if GameConfig.station_kind(restored.kind).is_empty() or restored.key != str(key):
			continue
		state.stations[restored.key] = restored
	var research_data: Dictionary = data.get("research", {})
	for research_id in research_data:
		if state.research.has(research_id):
			state.research[research_id] = clampi(int(research_data[research_id]), 0, GameConfig.RESEARCH[research_id].max_level)
	var layout := WorldLayout.get_default()
	state.player = Player.from_dict(data.get("player", {}), layout.player_start())
	state.player.position = layout.clamp_to_world(state.player.position)
	for entry in data.get("runners", []):
		if entry is Dictionary and state.runners.size() < GameConfig.MAX_RUNNERS:
			state.runners.append(Runner.from_dict(entry, layout.runner_home()))
	for runner in state.runners:
		if runner.role.is_empty():
			runner.role = state.least_staffed_role()
	for entry in data.get("tube_parcels", []):
		var parcel := TubeParcel.from_dict(entry)
		if parcel != null and state.tube_parcels.size() < GameConfig.MAX_TUBE_PARCELS:
			state.tube_parcels.append(parcel)
	for entry in data.get("collectors", []):
		if entry is Dictionary and state.collectors.size() < GameConfig.MAX_COLLECTORS:
			state.collectors.append(RejectCollector.from_dict(entry, layout.collector_home()))
	for entry in data.get("coffee_interns", []):
		if entry is Dictionary and state.coffee_interns.size() < GameConfig.MAX_COFFEE_INTERNS:
			state.coffee_interns.append(CoffeeIntern.from_dict(entry, layout.coffee_home()))
	state.intern = ComplaintIntern.from_dict(data.get("intern"), layout.intern_home())
	state.play_time = maxf(0.0, float(data.get("play_time", 0.0)))
	state._restore_reviews(data.get("reviews", []))
	state.review_seq = maxi(state.review_seq, int(data.get("review_seq", 0)))
	state.review_fear = clampf(float(data.get("review_fear", 0.0)), 0.0, GameConfig.REVIEW_FEAR_SECONDS)
	for entry in data.get("helpers", []):
		if entry is Dictionary and state.helpers.size() < GameConfig.MAX_HELPERS:
			state.helpers.append(ComplaintIntern.from_dict(entry, layout.intern_home(state.helpers.size() + 1), state.helpers.size() + 1))
	state.waiting_level = clampi(int(data.get("waiting_level", 0)), 0, GameConfig.WAITING_MAX_LEVEL)
	state.seating_level = clampi(int(data.get("seating_level", 0)), 0, GameConfig.SEATING_MAX_LEVEL)
	state.complaint_clerk_level = clampi(int(data.get("complaint_clerk_level", 0)), 0, GameConfig.COMPLAINT_CLERK_MAX_LEVEL)
	var legacy_box := int(research_data.get("complaint_desk", 0))
	state.complaint_box_level = clampi(maxi(int(data.get("complaint_box_level", 0)), legacy_box), 0, GameConfig.COMPLAINT_BOX_MAX_LEVEL)
	state.walkouts = maxi(0, int(data.get("walkouts", 0)))
	state.breakdowns = maxi(0, int(data.get("breakdowns", 0)))
	state.coffees_served = maxi(0, int(data.get("coffees_served", 0)))
	state.disputes_solved = maxi(0, int(data.get("disputes_solved", 0)))
	state.dispute_timer = clampf(float(data.get("dispute_timer", GameConfig.DISPUTE_FIRST_SECONDS)), 0.0, GameConfig.DISPUTE_MAX_INTERVAL * 2.0)
	state.event_id = str(data.get("event_id", ""))
	if not GameConfig.EVENTS.has(state.event_id):
		state.event_id = ""
	state.event_time_left = float(data.get("event_time_left", 0.0))
	state.event_cooldown = float(data.get("event_cooldown", GameConfig.EVENT_FIRST_COOLDOWN))
	state.event_scope = str(data.get("event_scope", "")) if state.event_id != "" else ""
	state.event_choice = str(data.get("event_choice", "")) if state.event_id != "" else ""
	state.cases_spawned = maxi(0, int(data.get("cases_spawned", 0)))
	state.cases_rejected = maxi(0, int(data.get("cases_rejected", 0)))
	state.cases_completed = int(data.get("cases_completed", 0))
	state.cases_flawed = int(data.get("cases_flawed", 0))
	state.citizens_lost = int(data.get("citizens_lost", 0))
	state.cases_shredded = maxi(0, int(data.get("cases_shredded", 0)))
	state.contraband_seized = int(data.get("contraband_seized", 0))
	state.staff_hired = int(data.get("staff_hired", 0))
	state.wakes = maxi(0, int(data.get("wakes", 0)))
	state.trainings = maxi(0, int(data.get("trainings", 0)))
	state.complaints = clampi(int(data.get("complaints", 0)), 0, Formulas.complaint_cap(state))
	state.hr = clampi(int(data.get("hr", 0)), 0, GameConfig.MAX_HR)
	state.guards = clampi(int(data.get("guards", 0)), 0, GameConfig.MAX_GUARDS)
	state.sick_timer = clampf(float(data.get("sick_timer", GameConfig.SICK_FIRST_SECONDS)), 0.0, GameConfig.SICK_MAX_PER_OFFICIAL)
	state.calls_made = maxi(0, int(data.get("calls_made", 0)))
	state.bonuses_paid = maxi(0, int(data.get("bonuses_paid", 0)))
	state.calls_answered = maxi(0, int(data.get("calls_answered", 0)))
	state.visitors_stopped = maxi(0, int(data.get("visitors_stopped", 0)))
	state.calls_missed = maxi(0, int(data.get("calls_missed", 0)))
	state.kranz = bool(data.get("kranz", false))
	state.kranz_timer = clampf(float(data.get("kranz_timer", GameConfig.KRANZ_FIRST_SECONDS)), 0.0, GameConfig.KRANZ_MAX_INTERVAL)
	state.complaints_shredded = maxi(0, int(data.get("complaints_shredded", 0)))
	state.complaints_filed = maxi(state.complaints, int(data.get("complaints_filed", 0)))
	state.complaints_fended = maxi(0, int(data.get("complaints_fended", 0)))
	state.complaint_timer = clampf(float(data.get("complaint_timer", GameConfig.COMPLAINT_INTERVAL)), 0.0, GameConfig.COMPLAINT_INTERVAL)
	state.money_earned = float(data.get("money_earned", 0.0))
	state.saved_at = int(data.get("saved_at", 0))
	if data.has("rng_seed"):
		state.rng.seed = str(data.rng_seed).to_int()
		state.rng.state = str(data.get("rng_state", "0")).to_int()
	else:
		state.rng.randomize()
	state.life_rng.seed = state.rng.seed + 1
	state.review_rng.seed = state.rng.seed + 2
	if state.unlocked_count() == 0:
		state.unlock_department("general_services")
	state._ensure_stations()
	state.ensure_mailroom()
	state._restore_disputes(data.get("disputes", []))
	state._repair_kitchen_slots()
	return state


func _restore_boost_timers(target: Dictionary[String, float], entries: Variant, limit_key: String) -> void:
	if not entries is Dictionary:
		return
	for boost_id in entries:
		var value := float(entries[boost_id])
		var limit := _timer_limit(str(boost_id), limit_key)
		if limit > 0.0 and value > 0.0:
			target[str(boost_id)] = minf(value, limit)


static func _timer_limit(boost_id: String, limit_key: String) -> float:
	if boost_id == Boosts.SICK_NOTE and limit_key == "cooldown":
		return GameConfig.AD_SICK_COOLDOWN
	return float(GameConfig.boost(boost_id).get(limit_key, 0.0))


func _restore_disputes(entries: Variant) -> void:
	if not entries is Array:
		return
	for entry in entries:
		var dispute := Dispute.from_dict(entry)
		if dispute == null or disputes.size() >= GameConfig.MAX_DISPUTES:
			continue
		var dept := department(dispute.dept_id)
		if dept != null and dept.unlocked and dispute_in(dispute.dept_id) == null:
			disputes.append(dispute)


func _ensure_stations() -> void:
	for dept in unlocked_departments():
		for key in RouteBuilder.required_stations(dept.id):
			if not stations.has(key):
				var created := Station.new(key)
				if not created.machine:
					created.staff = 1
				stations[key] = created
