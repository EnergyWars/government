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
		for field in ["cost", "reputation", "max_departments", "max_desks", "lobby"]:
			assert_gt(float(current[field]), float(before[field]), "%s %s" % [current.id, field])
	assert_eq(int(GameConfig.BUILDING_STAGES[-1].max_departments), GameConfig.DEPARTMENTS.size())


func test_upgrade_tracks_are_consistent() -> void:
	var curves := ["linear", "decay", "unlock_decay", "chance", "unlock"]
	var units := ["count", "bonus", "reduction", "seconds", "chance", "percent", "unlock"]
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
		assert_lt(int(config.get("stage", 0)), GameConfig.BUILDING_STAGES.size(), upgrade_id)
		match str(config.curve):
			"linear":
				assert_true(config.has("base") and config.has("step"), upgrade_id)
			"decay", "unlock_decay", "chance":
				assert_true(config.has("base"), upgrade_id)
				assert_gt(float(config.rate), 0.0, upgrade_id)
				assert_lt(float(config.rate), 1.0, upgrade_id)
			"unlock":
				assert_eq(int(config.max), 1, upgrade_id)
		var requires: Dictionary = config.get("requires", {})
		for required_id: String in requires:
			assert_ne(required_id, upgrade_id)
			assert_false(GameConfig.upgrade(required_id).is_empty(), "%s %s" % [upgrade_id, required_id])
			assert_false(GameConfig.is_room_upgrade(required_id), "%s %s" % [upgrade_id, required_id])
			assert_between(int(requires[required_id]), 1, int(GameConfig.upgrade(required_id).max), "%s %s" % [upgrade_id, required_id])


func test_upgrade_spots_point_to_existing_rooms() -> void:
	for upgrade_id in GameConfig.upgrade_ids():
		var room_upgrade := GameConfig.is_room_upgrade(upgrade_id)
		assert_eq(str(GameConfig.upgrade(upgrade_id).spot).contains("%s"), room_upgrade, upgrade_id)
		var room_ids: Array[String] = [""]
		if room_upgrade:
			room_ids = GameConfig.upgrade_rooms(upgrade_id)
			assert_false(room_ids.is_empty(), upgrade_id)
		for room_id in room_ids:
			var spot := GameConfig.upgrade_spot(upgrade_id, room_id)
			var room := GameConfig.spot_room(spot)
			assert_true(GameConfig.SERVICE_ROOMS.has(room) or not GameConfig.department(room).is_empty(), "%s %s" % [upgrade_id, spot])
			if room_upgrade:
				assert_eq(room, room_id, upgrade_id)


func test_station_speed_and_event_mitigation_use_global_tracks() -> void:
	for kind: String in GameConfig.UPGRADE_SPEED:
		var upgrade_id := str(GameConfig.UPGRADE_SPEED[kind])
		assert_true(GameConfig.STATION_KINDS.has(kind), kind)
		assert_false(GameConfig.upgrade(upgrade_id).is_empty(), kind)
		assert_false(GameConfig.is_room_upgrade(upgrade_id), kind)
	for event_id: String in GameConfig.EVENTS:
		var mitigation := str(GameConfig.EVENTS[event_id].get("mitigation", ""))
		if not mitigation.is_empty():
			assert_false(GameConfig.upgrade(mitigation).is_empty(), event_id)
			assert_false(GameConfig.is_room_upgrade(mitigation), event_id)


func test_track_limits_match_world_limits() -> void:
	var lobby_limit := int(GameConfig.BUILDING_STAGES[-1].lobby) + int(Formulas.track_value("waiting_places", int(GameConfig.upgrade("waiting_places").max)))
	assert_lte(lobby_limit, GameConfig.MAX_LOBBY_SLOTS)
	assert_eq(int(Formulas.track_value("ticket_line", int(GameConfig.upgrade("ticket_line").max))), GameConfig.MAX_TICKET_LINE_SLOTS)
	assert_eq(int(Formulas.track_value("ticket_machines", int(GameConfig.upgrade("ticket_machines").max))), GameConfig.MAX_TICKET_MACHINES)
	assert_eq(int(Formulas.track_value("toilet_stalls", int(GameConfig.upgrade("toilet_stalls").max))), GameConfig.MAX_LOO_SLOTS)
	assert_eq(int(Formulas.track_value("ticket_line", 0)), GameConfig.TICKET_LINE_SLOTS)
	assert_eq(int(Formulas.track_value("toilet_stalls", 0)), GameConfig.LOO_SLOTS)
	assert_eq(int(Formulas.track_value("seating", 0)), GameConfig.SEATING_BASE_SEATS)


func test_upgrade_lookups() -> void:
	assert_eq(GameConfig.upgrade("briefcase").spot, "player")
	assert_true(GameConfig.upgrade("nope").is_empty())
	assert_true(GameConfig.upgrade_ids().has("tube_station"))
	assert_true(GameConfig.is_room_upgrade("office_equipment"))
	assert_true(GameConfig.is_room_upgrade("shredder"))
	assert_true(GameConfig.is_room_upgrade("tube_station"))
	assert_false(GameConfig.is_room_upgrade("briefcase"))
	assert_false(GameConfig.is_room_upgrade("nope"))
	assert_eq(GameConfig.upgrade_key("briefcase"), "briefcase")
	assert_eq(GameConfig.upgrade_key("shredder", "housing"), "shredder@housing")
	assert_eq(GameConfig.upgrade_spot("briefcase"), "player")
	assert_eq(GameConfig.upgrade_spot("scanners"), "station:" + GameConfig.RECEPTION)
	assert_eq(GameConfig.upgrade_spot("office_equipment", "customs"), "dept:customs")
	assert_eq(GameConfig.upgrade_spot("shredder", "housing"), "shredder:housing")
	assert_eq(GameConfig.upgrade_spot("tube_station", GameConfig.ROOM_MAIL), "tube:" + GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.upgrade_spot("nope"), "")


func test_room_tracks_list_their_rooms() -> void:
	assert_eq(GameConfig.upgrade_rooms("office_equipment"), GameConfig.department_ids())
	var shredders := GameConfig.upgrade_rooms("shredder")
	assert_eq(shredders.size(), GameConfig.department_ids().size() - 1)
	assert_false(shredders.has("customs"))
	assert_true(shredders.has("general_services"))
	var tubes := GameConfig.upgrade_rooms("tube_station")
	assert_eq(tubes.size(), GameConfig.TUBE_ROOMS.size() + GameConfig.department_ids().size())
	for room_id in GameConfig.TUBE_ROOMS:
		assert_true(tubes.has(room_id), room_id)
	for dept_id in GameConfig.department_ids():
		assert_true(tubes.has(dept_id), dept_id)
	assert_true(GameConfig.upgrade_rooms("briefcase").is_empty())
	assert_true(GameConfig.upgrade_rooms("nope").is_empty())


func test_goals_reference_existing_content() -> void:
	var types := ["cases", "staff_hired", "runners", "station_level", "building_stage", "department", "upgrades", "upgrade_level", "reputation"]
	for goal: Dictionary in GameConfig.GOALS:
		assert_true(types.has(goal.type), str(goal))
		if goal.type == "department":
			assert_false(GameConfig.department(goal.param).is_empty(), str(goal))
		if goal.type == "upgrade_level":
			assert_false(GameConfig.upgrade(goal.param).is_empty(), str(goal))
			assert_false(GameConfig.is_room_upgrade(goal.param), str(goal))
			assert_lte(int(goal.target), int(GameConfig.upgrade(goal.param).max), str(goal))
		if goal.type == "building_stage":
			assert_lt(int(goal.target), GameConfig.BUILDING_STAGES.size(), str(goal))


func test_goal_departments_fit_building_progress() -> void:
	var stage := 0
	var unlocked := 1
	for goal: Dictionary in GameConfig.GOALS:
		if goal.type == "building_stage":
			stage = int(goal.target)
		elif goal.type == "department":
			unlocked += 1
			assert_lte(unlocked, int(GameConfig.building_stage(stage).max_departments), str(goal))


func test_events_reference_departments() -> void:
	for event_id in GameConfig.EVENTS:
		var dept_id := str(GameConfig.EVENTS[event_id].department)
		if not dept_id.is_empty():
			assert_false(GameConfig.department(dept_id).is_empty(), event_id)


func test_thoroughness_trades_time_for_accuracy() -> void:
	for i in range(1, GameConfig.THOROUGHNESS.size()):
		assert_gt(float(GameConfig.THOROUGHNESS[i].time), float(GameConfig.THOROUGHNESS[i - 1].time))
		assert_lt(float(GameConfig.THOROUGHNESS[i].error), float(GameConfig.THOROUGHNESS[i - 1].error))


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
			for point in [layout.input_point(key), layout.output_point(key), layout.work_point(key)]:
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
	assert_eq(layout.input_point(GameConfig.RECEPTION), layout.queue_point(0))
	assert_ne(layout.queue_point(0), layout.queue_point(1))
	assert_ne(layout.queue_point(11), layout.queue_point(12))
	assert_ne(layout.waiting_seat(0), layout.waiting_seat(5))
	assert_ne(layout.desk_position("tax_services/review", 0), layout.desk_position("tax_services/review", 3))
	assert_true(layout.hall.has_point(layout.player_start()))
	assert_true(layout.tech_room.has_point(layout.runner_home()))
	assert_true(layout.room("tax_services").has_point(layout.pad_point("tax_services")))
	assert_eq(layout.header("tax_services").size.y, WorldLayout.HEADER)
	assert_eq(layout.clamp_to_world(Vector2(-100, 99999)), Vector2(WorldLayout.MARGIN, layout.size.y - WorldLayout.MARGIN))
	assert_true(layout.near(Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS, 0)))
	assert_false(layout.near(Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS + 1.0, 0)))
	assert_eq(layout.slot_at(layout.room("customs").get_center()), "customs")
	assert_eq(layout.slot_at(layout.hall.get_center()), "")


func test_room_lookups() -> void:
	assert_eq(GameConfig.station_room(GameConfig.RECEPTION), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.station_room(GameConfig.COUNTER), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.station_room(GameConfig.MAILROOM), GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.station_room(GameConfig.INSPECTION), GameConfig.ROOM_INSPECTION)
	assert_eq(GameConfig.station_room("tax_services/review"), "tax_services")
	for key: String in GameConfig.SHARED_STATIONS:
		assert_true(GameConfig.SERVICE_ROOMS.has(GameConfig.station_room(key)), key)
	assert_eq(GameConfig.spot_room("guards"), GameConfig.ROOM_HALL)
	assert_eq(GameConfig.spot_room("runners"), GameConfig.ROOM_TECH)
	assert_eq(GameConfig.spot_room("station:" + GameConfig.MAILROOM), GameConfig.ROOM_MAIL)
	assert_eq(GameConfig.spot_room("station:customs/dock"), "customs")
	assert_eq(GameConfig.spot_room("dept:housing"), "housing")
	assert_eq(GameConfig.spot_room("shredder:housing"), "housing")
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
