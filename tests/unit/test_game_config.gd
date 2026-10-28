extends GutTest


func test_lookups() -> void:
	assert_eq(GameConfig.department("tax_services").id, "tax_services")
	assert_true(GameConfig.department("nope").is_empty())
	assert_eq(GameConfig.station_kind("review").base_time, 5.0)
	assert_true(GameConfig.station_kind("nope").is_empty())
	assert_eq(GameConfig.building_stage(-5).id, GameConfig.BUILDING_STAGES[0].id)
	assert_eq(GameConfig.building_stage(99).id, GameConfig.BUILDING_STAGES[-1].id)
	assert_eq(GameConfig.department_ids().size(), GameConfig.DEPARTMENTS.size())


func test_station_key_helpers() -> void:
	assert_eq(GameConfig.department_station_keys("general_services"), ["general_services/review", "general_services/signature"] as Array[String])
	assert_eq(GameConfig.station_dept("tax_services/review"), "tax_services")
	assert_eq(GameConfig.station_dept(GameConfig.RECEPTION), "")
	assert_eq(GameConfig.station_kind_of(GameConfig.COUNTER), "counter")
	assert_eq(GameConfig.station_kind_of("customs/dock"), "dock")
	assert_true(GameConfig.is_machine("tax_services/signature"))
	assert_false(GameConfig.is_machine("social_benefits/signature"))
	assert_false(GameConfig.is_machine("tax_services/review"))
	assert_true(GameConfig.is_customs("customs"))
	assert_false(GameConfig.is_customs("housing"))


func test_every_department_has_valid_stations() -> void:
	for dept_id in GameConfig.department_ids():
		for key in RouteBuilder.required_stations(dept_id):
			assert_false(GameConfig.station_kind(GameConfig.station_kind_of(key)).is_empty(), key)
		var referral := str(GameConfig.department(dept_id).referral)
		if not referral.is_empty():
			assert_true(GameConfig.department_station_keys(GameConfig.station_dept(referral)).has(referral), dept_id)


func test_departments_get_progressively_harder() -> void:
	var previous := {"reward": 0.0, "unlock_cost": -1.0, "unlock_reputation": -1.0, "cost_multiplier": 0.0}
	for entry: Dictionary in GameConfig.DEPARTMENTS:
		for field in previous:
			assert_gt(float(entry[field]), float(previous[field]), "%s %s" % [entry.id, field])
			previous[field] = float(entry[field])


func test_building_stages_grow() -> void:
	for i in range(1, GameConfig.BUILDING_STAGES.size()):
		var current: Dictionary = GameConfig.BUILDING_STAGES[i]
		var before: Dictionary = GameConfig.BUILDING_STAGES[i - 1]
		for field in ["max_departments", "max_desks", "lobby"]:
			assert_gt(float(current[field]), float(before[field]), "%s %s" % [current.id, field])
		assert_false(current.has("cost"), current.id)
		assert_false(current.has("reputation"), current.id)
	assert_eq(int(GameConfig.BUILDING_STAGES[-1].max_departments), GameConfig.DEPARTMENTS.size())


func test_stage_follows_the_number_of_departments() -> void:
	var expected := [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
	for count in expected.size():
		assert_eq(GameConfig.stage_for_departments(count), expected[count], str(count))
	for stage in GameConfig.BUILDING_STAGES.size():
		var needed := GameConfig.departments_for_stage(stage)
		assert_eq(GameConfig.stage_for_departments(needed), stage, str(stage))
		if stage > 0:
			assert_eq(GameConfig.stage_for_departments(needed - 1), stage - 1, str(stage))
	assert_eq(GameConfig.departments_for_stage(-1), 1)
	assert_eq(GameConfig.departments_for_stage(GameConfig.MAIL_UNLOCK_STAGE), 2)


func test_reputation_strongly_limits_department_openings() -> void:
	var ids := GameConfig.department_ids()
	for index in range(2, ids.size()):
		var before := float(GameConfig.department(ids[index - 1]).unlock_reputation)
		assert_gte(float(GameConfig.department(ids[index]).unlock_reputation), before * GameConfig.UNLOCK_REPUTATION_MIN_GROWTH, ids[index])


func test_upgrade_tracks_are_consistent() -> void:
	var curves := ["linear", "decay", "unlock_decay", "chance", "unlock", "milestone"]
	var units := ["count", "bonus", "reduction", "seconds", "chance", "percent", "unlock", "per_second", "factor"]
	assert_eq(GameConfig.upgrade_ids().size(), GameConfig.UPGRADES.size())
	for upgrade_id in GameConfig.upgrade_ids():
		var config := GameConfig.upgrade(upgrade_id)
		for field in ["spot", "topic", "max", "cost", "growth", "curve", "unit"]:
			assert_true(config.has(field), "%s %s" % [upgrade_id, field])
		assert_true(curves.has(config.curve), upgrade_id)
		assert_true(units.has(config.unit), upgrade_id)
		assert_eq(config.curve == "unlock", config.unit == "unlock", upgrade_id)
		assert_true(GameConfig.TOPICS.has(config.topic), upgrade_id)
		assert_gt(int(config.max), 0, upgrade_id)
		assert_gt(float(config.cost), 0.0, upgrade_id)
		assert_gte(float(config.growth), 1.0, upgrade_id)
		assert_gte(float(config.get("reputation", 0.0)), 0.0, upgrade_id)
		assert_false(config.has("stage"), upgrade_id)
		match str(config.curve):
			"linear":
				assert_true(config.has("base") and config.has("step"), upgrade_id)
			"decay", "unlock_decay", "chance":
				assert_true(config.has("base"), upgrade_id)
				assert_gt(float(config.rate), 0.0, upgrade_id)
				assert_lt(float(config.rate), 1.0, upgrade_id)
			"unlock":
				assert_eq(int(config.max), 1, upgrade_id)
			"milestone":
				assert_eq(Formulas.track_value(upgrade_id, 0), 1.0, upgrade_id)
		var requires: Dictionary = config.get("requires", {})
		for required_id: String in requires:
			assert_ne(required_id, upgrade_id)
			assert_false(GameConfig.upgrade(required_id).is_empty(), "%s %s" % [upgrade_id, required_id])
			if GameConfig.is_room_upgrade(required_id):
				assert_true(GameConfig.is_room_upgrade(upgrade_id), "%s %s" % [upgrade_id, required_id])
				for room_id in GameConfig.upgrade_rooms(upgrade_id):
					assert_true(GameConfig.upgrade_rooms(required_id).has(room_id), "%s %s %s" % [upgrade_id, required_id, room_id])
			assert_between(int(requires[required_id]), 1, int(GameConfig.upgrade(required_id).max), "%s %s" % [upgrade_id, required_id])


func test_upgrade_spots_point_to_existing_rooms() -> void:
	for upgrade_id in GameConfig.upgrade_ids():
		var room_upgrade := GameConfig.is_room_upgrade(upgrade_id)
		var spot_text := str(GameConfig.upgrade(upgrade_id).spot)
		assert_eq(spot_text.contains("%s") or spot_text == GameConfig.ROOM_SPOT, room_upgrade, upgrade_id)
		var room_ids: Array[String] = [""]
		if room_upgrade:
			room_ids = GameConfig.upgrade_rooms(upgrade_id)
			assert_false(room_ids.is_empty(), upgrade_id)
		for room_id in room_ids:
			var spot := GameConfig.upgrade_spot(upgrade_id, room_id)
			var room := GameConfig.spot_room(spot)
			assert_true(GameConfig.SERVICE_ROOMS.has(room) or not GameConfig.department(room).is_empty(), "%s %s" % [upgrade_id, spot])
			if room_upgrade:
				assert_eq(room, GameConfig.lead_parent_room(room_id), upgrade_id)


func test_station_upgrades_were_replaced_by_room_tracks() -> void:
	for upgrade_id: String in ["scanners", "digital_records", "digital_signatures", "letter_opener", "office_equipment"]:
		assert_true(GameConfig.upgrade(upgrade_id).is_empty(), upgrade_id)
	for kind: String in GameConfig.STATION_KINDS:
		assert_false(GameConfig.station_kind(kind).has("upgrade_cost"), kind)
	assert_eq(int(GameConfig.upgrade("room_speed").max), GameConfig.ROOM_SPEED_LEVELS)
	assert_eq(str(GameConfig.upgrade("room_speed").unit), "factor")
	assert_eq(int(Formulas.track_value("room_trays", 0)), GameConfig.TRAY_BASE)
	assert_eq(int(Formulas.track_value("room_trays", int(GameConfig.upgrade("room_trays").max))), GameConfig.TRAY_MAX)
	assert_eq(GameConfig.TRAY_BASE, 6)
	assert_eq(GameConfig.TRAY_MAX, 25)


func test_event_mitigation_uses_global_tracks() -> void:
	for event_id: String in GameConfig.EVENTS:
		var mitigation := str(GameConfig.EVENTS[event_id].get("mitigation", ""))
		if not mitigation.is_empty():
			assert_false(GameConfig.upgrade(mitigation).is_empty(), event_id)
			assert_false(GameConfig.is_room_upgrade(mitigation), event_id)


func test_track_limits_match_world_limits() -> void:
	assert_eq(GameConfig.TICKET_MACHINE_TRACKS.size(), GameConfig.MAX_TICKET_MACHINES)
	assert_eq(GameConfig.TICKET_SPEED_TRACKS.size(), GameConfig.MAX_TICKET_MACHINES)
	for upgrade_id in GameConfig.TICKET_SPEED_TRACKS:
		assert_eq(int(GameConfig.upgrade(upgrade_id).max), GameConfig.TICKET_MACHINE_LEVELS, upgrade_id)
		assert_almost_eq(Formulas.track_value(upgrade_id, GameConfig.TICKET_MACHINE_LEVELS), GameConfig.TICKET_MAX_RATE, 0.0001)
	assert_almost_eq(GameConfig.MAX_TICKET_MACHINES * GameConfig.TICKET_MAX_RATE * 60.0, GameConfig.MAX_ARRIVALS_PER_MINUTE, 0.0001)
	assert_eq(int(Formulas.track_value("seating", int(GameConfig.upgrade("seating").max))), GameConfig.WAITING_PLACES)
	assert_eq(int(Formulas.track_value("toilet_stalls", int(GameConfig.upgrade("toilet_stalls").max))), GameConfig.MAX_LOO_SLOTS)
	assert_eq(int(Formulas.track_value("toilet_stalls", 0)), GameConfig.LOO_SLOTS)
	assert_eq(int(Formulas.track_value("seating", 0)), GameConfig.BASE_SEATS)
	assert_eq(int(Formulas.track_value("pickup_seating", int(GameConfig.upgrade("pickup_seating").max))), GameConfig.WAITING_PLACES)
	assert_eq(int(Formulas.track_value("pickup_seating", 0)), GameConfig.BASE_SEATS)


func test_waiting_rooms_hold_seventy_places() -> void:
	assert_eq(GameConfig.WAITING_PLACES, 70)
	assert_eq(GameConfig.BASE_SEATS, 15)
	assert_eq(WorldLayout.PLACE_COLUMNS, 10)
	assert_eq(WorldLayout.PLACE_ROWS, 7)
	assert_eq(WorldLayout.PLACE_COLUMNS * WorldLayout.PLACE_ROWS, GameConfig.WAITING_PLACES)
	assert_eq(int(GameConfig.upgrade("seating").max), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS)
	assert_eq(int(GameConfig.upgrade("pickup_seating").max), GameConfig.WAITING_PLACES - GameConfig.BASE_SEATS)


func test_reject_pile_runs_from_twelve_to_thirty_two() -> void:
	assert_eq(GameConfig.REJECT_CAPACITY, 12)
	assert_eq(GameConfig.REJECT_CAPACITY + GameConfig.MAX_REJECT_LEVEL * GameConfig.REJECT_CAPACITY_PER_LEVEL, 32)


func test_waiting_patience_and_leave_chances() -> void:
	assert_eq(GameConfig.SEAT_PATIENCE, 300.0)
	assert_eq(GameConfig.STAND_PATIENCE, 90.0)
	assert_eq(GameConfig.SEAT_LEAVE_INTERVAL, 20.0)
	assert_eq(GameConfig.SEAT_LEAVE_CHANCES.size(), 3)
	var expected := [[120.0, 0.1], [180.0, 0.15], [240.0, 0.2]]
	for index in expected.size():
		var tier: Dictionary = GameConfig.SEAT_LEAVE_CHANCES[index]
		assert_eq(float(tier.after), float(expected[index][0]), str(index))
		assert_almost_eq(float(tier.chance), float(expected[index][1]), 0.0001, str(index))
		assert_lt(float(tier.after), GameConfig.SEAT_PATIENCE, str(index))
		if index > 0:
			assert_gt(float(tier.after), float(GameConfig.SEAT_LEAVE_CHANCES[index - 1].after), str(index))
			assert_gt(float(tier.chance), float(GameConfig.SEAT_LEAVE_CHANCES[index - 1].chance), str(index))


func test_further_ticket_machines_unlock_at_half_speed() -> void:
	assert_eq(GameConfig.TICKET_UNLOCK_LEVEL, 50)
	assert_eq(GameConfig.TICKET_SECOND_COST, 5526.0)
	assert_eq(GameConfig.TICKET_THIRD_COST, 101791.0)
	assert_almost_eq(GameConfig.TICKET_SECOND_COST, 300.0 * pow(1.06, GameConfig.TICKET_UNLOCK_LEVEL), 1.0)
	assert_almost_eq(GameConfig.TICKET_THIRD_COST, GameConfig.TICKET_SECOND_COST * pow(1.06, GameConfig.TICKET_UNLOCK_LEVEL), 5.0)
	var second := GameConfig.upgrade("ticket_machine_2")
	assert_eq(second.requires, {"ticket_speed": GameConfig.TICKET_UNLOCK_LEVEL})
	assert_eq(float(second.cost), GameConfig.TICKET_SECOND_COST)
	assert_eq(float(GameConfig.upgrade("ticket_speed_2").cost), GameConfig.TICKET_SECOND_COST)
	var third := GameConfig.upgrade("ticket_machine_3")
	assert_eq(third.requires, {"ticket_speed_2": GameConfig.TICKET_UNLOCK_LEVEL})
	assert_eq(float(third.cost), GameConfig.TICKET_THIRD_COST)
	assert_eq(float(GameConfig.upgrade("ticket_speed_3").cost), GameConfig.TICKET_THIRD_COST)
	assert_lt(GameConfig.TICKET_UNLOCK_LEVEL, GameConfig.TICKET_MACHINE_LEVELS)


func test_upgrade_lookups() -> void:
	assert_eq(GameConfig.upgrade("briefcase").spot, "player")
	assert_true(GameConfig.upgrade("nope").is_empty())
	assert_true(GameConfig.upgrade_ids().has("tube_station"))
	assert_true(GameConfig.is_room_upgrade("room_speed"))
	assert_true(GameConfig.is_room_upgrade("room_trays"))
	assert_true(GameConfig.is_room_upgrade("team_lead"))
	assert_false(GameConfig.is_room_upgrade("shredder"))
	assert_false(GameConfig.is_room_upgrade("shredder_blades"))
	assert_true(GameConfig.is_room_upgrade("tube_station"))
	assert_false(GameConfig.is_room_upgrade("briefcase"))
	assert_false(GameConfig.is_room_upgrade("nope"))
	assert_eq(GameConfig.upgrade_key("briefcase"), "briefcase")
	assert_eq(GameConfig.upgrade_key("tube_station", "housing"), "tube_station@housing")
	assert_eq(GameConfig.upgrade_spot("briefcase"), "player")
	assert_eq(GameConfig.upgrade_spot("room_speed", "customs"), "dept:customs")
	assert_eq(GameConfig.upgrade_spot("room_trays", "general_services"), "dept:general_services")
	assert_eq(GameConfig.upgrade_spot("room_speed", GameConfig.ROOM_HALL), "room:" + GameConfig.ROOM_HALL)
	assert_eq(GameConfig.upgrade_spot("room_speed", GameConfig.ROOM_MAIL), "room:" + GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.upgrade_spot("room_trays", GameConfig.ROOM_INSPECTION), "room:" + GameConfig.ROOM_INSPECTION)
	assert_eq(GameConfig.upgrade_spot("team_lead", "housing"), "lead:housing")
	assert_eq(GameConfig.upgrade_spot("lead_patrol", GameConfig.HALL_INTAKE), "lead:" + GameConfig.HALL_INTAKE)
	assert_eq(GameConfig.upgrade_spot("shredder_blades"), "shredder")
	assert_eq(GameConfig.upgrade_spot("tube_station", GameConfig.ROOM_MAIL), "tube:" + GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.upgrade_spot("nope"), "")


func test_lead_rooms_split_the_hall_into_intake_and_pickup() -> void:
	var rooms := GameConfig.lead_rooms()
	assert_eq(rooms.slice(0, 4), [GameConfig.HALL_INTAKE, GameConfig.HALL_PICKUP, GameConfig.ROOM_MAIL, GameConfig.ROOM_INSPECTION] as Array[String])
	assert_false(rooms.has(GameConfig.ROOM_HALL))
	for dept_id in GameConfig.department_ids():
		assert_true(rooms.has(dept_id), dept_id)
	assert_same(GameConfig.lead_rooms(), rooms)
	assert_eq(GameConfig.lead_room(GameConfig.RECEPTION), GameConfig.HALL_INTAKE)
	assert_eq(GameConfig.lead_room(GameConfig.COUNTER), GameConfig.HALL_PICKUP)
	assert_eq(GameConfig.lead_room("general_services/review"), "general_services")
	assert_eq(GameConfig.lead_room(GameConfig.MAILROOM), GameConfig.station_room(GameConfig.MAILROOM))
	assert_eq(GameConfig.lead_parent_room(GameConfig.HALL_INTAKE), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.lead_parent_room(GameConfig.HALL_PICKUP), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.lead_parent_room("tax_services"), "tax_services")
	assert_eq(GameConfig.spot_room("lead:" + GameConfig.HALL_PICKUP), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.spot_room("trays:general_services/review"), "general_services")
	assert_eq(GameConfig.spot_room("trays:" + GameConfig.COUNTER), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.upgrade_rooms(GameConfig.ROOMS_LEADS), [] as Array[String])


func test_room_tracks_list_their_rooms() -> void:
	assert_eq(GameConfig.upgrade_rooms("room_speed"), GameConfig.office_rooms())
	assert_eq(GameConfig.upgrade_rooms("room_trays"), GameConfig.office_rooms())
	assert_eq(GameConfig.upgrade_rooms("team_lead"), GameConfig.lead_rooms())
	assert_eq(GameConfig.upgrade_rooms("lead_focus"), GameConfig.lead_rooms())
	assert_eq(GameConfig.upgrade_rooms("lead_calm"), GameConfig.department_ids())
	assert_true(GameConfig.upgrade_rooms("shredder").is_empty())
	assert_true(GameConfig.upgrade_rooms("shredder_blades").is_empty())
	var tubes := GameConfig.upgrade_rooms("tube_station")
	assert_eq(tubes.size(), GameConfig.TUBE_ROOMS.size() + GameConfig.department_ids().size())
	for room_id in GameConfig.TUBE_ROOMS:
		assert_true(tubes.has(room_id), room_id)
	for dept_id in GameConfig.department_ids():
		assert_true(tubes.has(dept_id), dept_id)
	assert_true(GameConfig.upgrade_rooms("briefcase").is_empty())
	assert_true(GameConfig.upgrade_rooms("nope").is_empty())


func test_goals_reference_existing_content() -> void:
	var types := ["cases", "staff_hired", "runners", "room_speed", "department", "upgrades", "upgrade_level", "reputation"]
	var room_speed_goals := 0
	for goal: Dictionary in GameConfig.GOALS:
		assert_true(types.has(goal.type), str(goal))
		assert_ne(goal.type, "station_level", str(goal))
		if goal.type == "room_speed":
			room_speed_goals += 1
			assert_lte(int(goal.target), GameConfig.ROOM_SPEED_LEVELS, str(goal))
		if goal.type == "department":
			assert_false(GameConfig.department(goal.param).is_empty(), str(goal))
		if goal.type == "upgrade_level":
			assert_false(GameConfig.upgrade(goal.param).is_empty(), str(goal))
			assert_false(GameConfig.is_room_upgrade(goal.param), str(goal))
			assert_lte(int(goal.target), int(GameConfig.upgrade(goal.param).max), str(goal))
	assert_gt(room_speed_goals, 0)


func test_reputation_goals_ascend_towards_the_next_department() -> void:
	var last_target := 0.0
	var pending := -1.0
	for goal: Dictionary in GameConfig.GOALS:
		if goal.type == "reputation":
			assert_gt(float(goal.target), last_target, str(goal))
			last_target = float(goal.target)
			pending = last_target
		elif goal.type == "department" and pending >= 0.0:
			assert_lt(pending, float(GameConfig.department(goal.param).unlock_reputation), str(goal))
			pending = -1.0


func test_events_reference_departments() -> void:
	for event_id in GameConfig.EVENTS:
		var dept_id := str(GameConfig.EVENTS[event_id].department)
		if not dept_id.is_empty():
			assert_false(GameConfig.department(dept_id).is_empty(), event_id)


func test_thoroughness_trades_time_for_accuracy() -> void:
	for i in range(1, GameConfig.THOROUGHNESS.size()):
		assert_gt(float(GameConfig.THOROUGHNESS[i].time), float(GameConfig.THOROUGHNESS[i - 1].time))
		assert_lt(float(GameConfig.THOROUGHNESS[i].error), float(GameConfig.THOROUGHNESS[i - 1].error))
		assert_gte(float(GameConfig.THOROUGHNESS[i].reward), float(GameConfig.THOROUGHNESS[i - 1].reward))


func test_thoroughness_table_values() -> void:
	var expected := [
		{"id": "fast", "time": 0.45, "error": 0.3, "reward": 1.0},
		{"id": "normal", "time": 1.0, "error": 0.12, "reward": 1.0},
		{"id": "thorough", "time": 2.0, "error": 0.02, "reward": 2.6},
	]
	assert_eq(GameConfig.THOROUGHNESS.size(), expected.size())
	for index in expected.size():
		var mode: Dictionary = GameConfig.THOROUGHNESS[index]
		var wanted: Dictionary = expected[index]
		assert_eq(str(mode.id), str(wanted.id), str(index))
		for field: String in ["time", "error", "reward"]:
			assert_almost_eq(float(mode[field]), float(wanted[field]), 0.0001, "%s %s" % [wanted.id, field])


func test_customs_variants_have_suspicion() -> void:
	for variant in GameConfig.CUSTOMS_VARIANTS:
		assert_true(GameConfig.CUSTOMS_VARIANT_SUSPICION.has(variant), variant)


func _route(dept_id: String, follow_up: bool = false) -> Array[String]:
	var case_file := CaseFile.new(dept_id)
	case_file.follow_up = follow_up
	return RouteBuilder.build(case_file)


func test_routes_follow_shared_workflow() -> void:
	assert_eq(_route("general_services"), [GameConfig.RECEPTION, "general_services/review", "general_services/signature", GameConfig.COUNTER] as Array[String])
	assert_eq(_route("business_licences"), [GameConfig.RECEPTION, "business_licences/review", GameConfig.INSPECTION, "business_licences/signature", GameConfig.COUNTER] as Array[String])
	assert_eq(_route("housing"), [GameConfig.RECEPTION, "housing/review", "general_services/review", "housing/signature", GameConfig.COUNTER] as Array[String])
	assert_eq(_route("social_benefits", true), [GameConfig.RECEPTION, "social_benefits/review", GameConfig.COUNTER] as Array[String])
	assert_eq(_route("customs"), ["customs/dock", "customs/review", "customs/signature", "customs/clearance"] as Array[String])
	assert_true(_route("nope").is_empty())


func test_required_stations() -> void:
	assert_eq(RouteBuilder.required_stations("customs")[-1], GameConfig.INSPECTION)
	assert_true(RouteBuilder.required_stations("housing").has("general_services/review"))
	assert_true(RouteBuilder.required_stations("building_permits").has(GameConfig.INSPECTION))
	assert_eq(RouteBuilder.required_stations("general_services").size(), 4)


func test_world_layout_places_every_station() -> void:
	var layout := WorldLayout.get_default()
	assert_eq(layout, WorldLayout.get_default())
	var world := Rect2(Vector2.ZERO, layout.size)
	for dept_id in GameConfig.department_ids():
		assert_true(layout.room(dept_id).has_area(), dept_id)
		for key in RouteBuilder.required_stations(dept_id):
			var area := layout.area(key)
			assert_true(area.has_area(), key)
			assert_true(world.encloses(area), key)
			for point in [layout.input_point(key), layout.output_point(key), layout.desk_work_point(key, 0)]:
				assert_true(world.has_point(point), key)
	assert_false(layout.area("nope").has_area())
	assert_false(layout.room("nope").has_area())


func test_world_layout_rooms_do_not_overlap() -> void:
	var layout := WorldLayout.get_default()
	var slots := layout.rooms.keys()
	for i in slots.size():
		assert_false(layout.rooms[slots[i]].intersects(layout.hall), slots[i])
		for j in range(i + 1, slots.size()):
			assert_false(layout.rooms[slots[i]].intersects(layout.rooms[slots[j]]), "%s %s" % [slots[i], slots[j]])
	for dept_id in GameConfig.department_ids():
		var keys := GameConfig.department_station_keys(dept_id)
		for i in range(1, keys.size()):
			assert_false(layout.area(keys[i - 1]).intersects(layout.area(keys[i])), dept_id)


func test_world_layout_service_rooms_do_not_overlap() -> void:
	var layout := WorldLayout.get_default()
	var world := Rect2(Vector2.ZERO, layout.size)
	var rects: Dictionary[String, Rect2] = {}
	for room_id in GameConfig.SERVICE_ROOMS:
		var rect := layout.service_room(room_id)
		if room_id == GameConfig.ROOM_PLAYER:
			assert_false(rect.has_area())
			continue
		assert_true(rect.has_area(), room_id)
		assert_true(world.encloses(rect), room_id)
		rects[room_id] = rect
	for slot: String in layout.rooms:
		rects[slot] = layout.rooms[slot]
	var ids := rects.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			assert_false(rects[ids[i]].intersects(rects[ids[j]]), "%s %s" % [ids[i], ids[j]])
	assert_eq(layout.service_room(GameConfig.ROOM_INSPECTION), layout.room("inspection"))
	assert_eq(layout.service_room("customs"), layout.room("customs"))


func test_world_layout_helpers() -> void:
	var layout := WorldLayout.get_default()
	assert_true(layout.hall.has_point(layout.output_point(GameConfig.RECEPTION)))
	assert_true(layout.hall.has_point(layout.input_point(GameConfig.COUNTER)))
	assert_ne(layout.standing_point(0, GameConfig.BASE_SEATS), layout.standing_point(1, GameConfig.BASE_SEATS))
	assert_ne(layout.ticket_line_point(0, 0), layout.ticket_line_point(1, 0))
	assert_ne(layout.waiting_seat(0), layout.waiting_seat(5))
	assert_ne(layout.desk_position("tax_services/review", 0), layout.desk_position("tax_services/review", 3))
	assert_true(layout.hall.has_point(layout.player_start()))
	assert_true(layout.hall.has_point(layout.runner_home()))
	assert_true(layout.runner_lounge().has_point(layout.runner_home()))
	assert_true(layout.room("tax_services").has_point(layout.pad_point("tax_services")))
	assert_eq(layout.header("tax_services").size.y, WorldLayout.HEADER)
	assert_eq(layout.clamp_to_world(Vector2(-100, 99999)), Vector2(WorldLayout.MARGIN, layout.size.y - WorldLayout.MARGIN))
	assert_true(layout.near(Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS, 0)))
	assert_false(layout.near(Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS + 1.0, 0)))
	assert_eq(layout.slot_at(layout.room("customs").get_center()), "customs")
	assert_eq(layout.slot_at(layout.hall.get_center()), "")


func test_place_slots_fill_ten_columns_and_clamp_to_seventy() -> void:
	var layout := WorldLayout.get_default()
	for room in GameConfig.WAITING_ROOMS:
		var area := layout.place_area(room)
		assert_eq(area.size, WorldLayout.PLACE_AREA_SIZE, room)
		var seen: Array[Vector2] = []
		for index in GameConfig.WAITING_PLACES:
			var point := layout.place_slot(room, index)
			assert_true(area.has_point(point), "%s %d" % [room, index])
			assert_false(seen.has(point), "%s %d" % [room, index])
			seen.append(point)
		var origin := layout.place_slot(room, 0)
		assert_eq(layout.place_slot(room, 9), origin + Vector2(9.0 * WorldLayout.PLACE_PITCH.x, 0.0), room)
		assert_eq(layout.place_slot(room, 10), origin + Vector2(0.0, WorldLayout.PLACE_PITCH.y), room)
		assert_eq(layout.place_slot(room, GameConfig.WAITING_PLACES - 1), origin + Vector2(9.0 * WorldLayout.PLACE_PITCH.x, 6.0 * WorldLayout.PLACE_PITCH.y), room)
		assert_eq(layout.place_slot(room, GameConfig.WAITING_PLACES), layout.place_slot(room, GameConfig.WAITING_PLACES - 1), room)
		assert_eq(layout.place_slot(room, 500), layout.place_slot(room, GameConfig.WAITING_PLACES - 1), room)
		assert_eq(layout.place_slot(room, -3), origin, room)
		assert_eq(layout.waiting_seat(4, room), layout.place_slot(room, 4), room)
		assert_eq(layout.standing_point(2, GameConfig.BASE_SEATS, room), layout.place_slot(room, GameConfig.BASE_SEATS + 2), room)


func test_office_rooms_and_lead_tracks() -> void:
	var expected: Array[String] = []
	expected.append_array(GameConfig.TUBE_ROOMS)
	expected.append_array(GameConfig.department_ids())
	assert_eq(GameConfig.office_rooms(), expected)
	assert_eq(GameConfig.office_rooms().size(), GameConfig.TUBE_ROOMS.size() + GameConfig.DEPARTMENTS.size())
	assert_eq(GameConfig.TUBE_ROOMS, [GameConfig.ROOM_HALL, GameConfig.ROOM_MAIL, GameConfig.ROOM_INSPECTION] as Array[String])
	assert_false(GameConfig.office_rooms().has(GameConfig.ROOM_KITCHEN))
	assert_eq(GameConfig.ROOMS_OFFICES, "offices")
	assert_eq(GameConfig.LEAD_TRACKS, ["team_lead", "lead_breaks", "lead_health", "lead_focus", "lead_calm", "lead_patrol", "lead_cooldown"] as Array[String])
	for upgrade_id in GameConfig.LEAD_TRACKS:
		var config := GameConfig.upgrade(upgrade_id)
		assert_true(GameConfig.is_lead_track(upgrade_id), upgrade_id)
		assert_eq(str(config.spot), GameConfig.LEAD_SPOT, upgrade_id)
		assert_eq(str(config.topic), "staff", upgrade_id)
		assert_true(bool(config.get("staff_cost", false)), upgrade_id)
		assert_true(GameConfig.is_room_upgrade(upgrade_id), upgrade_id)
		for room_id in GameConfig.upgrade_rooms(upgrade_id):
			assert_true(GameConfig.lead_rooms().has(room_id), "%s %s" % [upgrade_id, room_id])
			assert_eq(GameConfig.upgrade_spot(upgrade_id, room_id), GameConfig.lead_spot(room_id), upgrade_id)
		if upgrade_id == "team_lead":
			assert_eq(int(config.max), 1)
			assert_false(config.has("requires"))
		else:
			assert_eq(config.requires, {"team_lead": 1}, upgrade_id)
	for upgrade_id: String in ["room_speed", "room_trays", "briefcase", "nope"]:
		assert_false(GameConfig.is_lead_track(upgrade_id), upgrade_id)
	assert_almost_eq(float(GameConfig.upgrade("lead_breaks").rate), 0.995, 0.0001)
	assert_almost_eq(float(GameConfig.upgrade("lead_breaks").base), 0.75, 0.0001)
	assert_almost_eq(float(GameConfig.upgrade("lead_cooldown").base), 180.0, 0.0001)
	assert_almost_eq(float(GameConfig.upgrade("lead_cooldown").rate), 0.995, 0.0001)
	assert_almost_eq(float(GameConfig.upgrade("lead_patrol").base), 3.0, 0.0001)
	assert_almost_eq(float(GameConfig.upgrade("lead_patrol").step), 0.01, 0.0001)
	assert_eq(GameConfig.LEAD_PATROL_SECONDS, 90.0)
	assert_eq(GameConfig.LEAD_PATROL_LAPS, 5)


func test_room_and_lead_spots() -> void:
	assert_eq(GameConfig.ROOM_SPOT, "@room")
	assert_eq(GameConfig.room_spot(GameConfig.ROOM_HALL), "room:" + GameConfig.ROOM_HALL)
	assert_eq(GameConfig.room_spot(GameConfig.ROOM_MAIL), "room:" + GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.room_spot(GameConfig.ROOM_INSPECTION), "room:" + GameConfig.ROOM_INSPECTION)
	assert_eq(GameConfig.room_spot("customs"), "dept:customs")
	assert_eq(GameConfig.room_spot(GameConfig.ROOM_KITCHEN), "room:" + GameConfig.ROOM_KITCHEN)
	assert_eq(UpgradeCatalog.room_spot("tax_services"), GameConfig.room_spot("tax_services"))
	assert_eq(GameConfig.lead_spot(GameConfig.ROOM_HALL), "lead:" + GameConfig.ROOM_HALL)
	assert_eq(GameConfig.lead_spot("tax_services"), "lead:tax_services")
	assert_eq(GameConfig.lead_spot("tax_services"), UpgradeCatalog.LEAD_PREFIX + "tax_services")
	for room_id in GameConfig.office_rooms():
		assert_eq(GameConfig.upgrade_spot("room_speed", room_id), GameConfig.room_spot(room_id), room_id)
		assert_eq(GameConfig.spot_room(GameConfig.room_spot(room_id)), room_id, room_id)
		assert_eq(GameConfig.spot_room(GameConfig.lead_spot(room_id)), room_id, room_id)
		assert_eq(GameConfig.spot_kind(GameConfig.lead_spot(room_id)), "lead", room_id)


func test_room_lookups() -> void:
	assert_eq(GameConfig.station_room(GameConfig.RECEPTION), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.station_room(GameConfig.COUNTER), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.station_room(GameConfig.MAILROOM), GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.station_room(GameConfig.INSPECTION), GameConfig.ROOM_INSPECTION)
	assert_eq(GameConfig.station_room("tax_services/review"), "tax_services")
	for key: String in GameConfig.SHARED_STATIONS:
		assert_true(GameConfig.SERVICE_ROOMS.has(GameConfig.station_room(key)), key)
	for board in GameConfig.STAFF_ROOM_BOARDS:
		assert_eq(GameConfig.spot_room(board), GameConfig.ROOM_STAFF, board)
	for board in GameConfig.BOARD_SPOTS:
		assert_eq(GameConfig.STAFF_ROOM_BOARDS.has(board), board != "runners", board)
	assert_eq(GameConfig.spot_room("runners"), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.spot_room("station:" + GameConfig.MAILROOM), GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.spot_room("station:customs/dock"), "customs")
	assert_eq(GameConfig.spot_room("dept:housing"), "housing")
	assert_eq(GameConfig.spot_room("tube:" + GameConfig.ROOM_INSPECTION), GameConfig.ROOM_INSPECTION)
	assert_eq(GameConfig.room_boosts(GameConfig.ROOM_PHONE), ["doctor_visit"] as Array[String])
	assert_true(GameConfig.room_boosts(GameConfig.ROOM_TOILETS).is_empty())
	assert_true(GameConfig.room_boosts("nope").is_empty())


func test_spots_and_boards_belong_to_service_rooms() -> void:
	for spot: String in GameConfig.SPOTS:
		var room_id := str(GameConfig.SPOTS[spot])
		assert_true(GameConfig.SERVICE_ROOMS.has(room_id), spot)
		assert_eq(GameConfig.spot_room(spot), room_id, spot)
	for spot in GameConfig.BOARD_SPOTS:
		assert_true(GameConfig.SPOTS.has(spot), spot)
		assert_eq(GameConfig.BOARD_SPOTS.count(spot), 1, spot)
	var staff_seen: Array[String] = []
	for staff_type: String in UpgradeCatalog.STAFF_SPOTS:
		var board := str(UpgradeCatalog.STAFF_SPOTS[staff_type])
		assert_true(Icons.STAFF.has(staff_type), staff_type)
		assert_true(GameConfig.BOARD_SPOTS.has(board), staff_type)
		assert_false(staff_seen.has(board), staff_type)
		staff_seen.append(board)
	assert_eq(staff_seen.size(), GameConfig.BOARD_SPOTS.size())
	for topic in GameConfig.TOPICS:
		assert_eq(GameConfig.TOPICS.count(topic), 1, topic)
	for room_id in GameConfig.SERVICE_ROOMS:
		assert_eq(GameConfig.SERVICE_ROOMS.count(room_id), 1, room_id)
		assert_true(GameConfig.department(room_id).is_empty(), room_id)


func test_every_boost_belongs_to_exactly_one_room() -> void:
	var seen: Array[String] = []
	for room_id: String in GameConfig.BOOST_ROOMS:
		assert_true(GameConfig.SERVICE_ROOMS.has(room_id), room_id)
		for boost_id in GameConfig.room_boosts(room_id):
			assert_true(GameConfig.BOOSTS.has(boost_id), boost_id)
			assert_true(Icons.BOOSTS.has(boost_id), boost_id)
			assert_false(seen.has(boost_id), boost_id)
			seen.append(boost_id)
	assert_eq(seen.size(), GameConfig.BOOSTS.size())
	for boost_id in GameConfig.BOOST_ORDER:
		assert_true(seen.has(boost_id), boost_id)
