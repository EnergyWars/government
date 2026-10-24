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


func test_research_tables_are_consistent() -> void:
	assert_eq(GameConfig.RESEARCH_ORDER.size(), GameConfig.RESEARCH.size())
	for research_id in GameConfig.RESEARCH_ORDER:
		assert_true(GameConfig.RESEARCH.has(research_id), research_id)
	for kind in GameConfig.RESEARCH_SPEED:
		assert_true(GameConfig.STATION_KINDS.has(kind), kind)
		assert_true(GameConfig.RESEARCH.has(GameConfig.RESEARCH_SPEED[kind].research), kind)


func test_goals_reference_existing_content() -> void:
	var types := ["cases", "staff_hired", "runners", "station_level", "building_stage", "department", "research", "research_level", "reputation"]
	for goal: Dictionary in GameConfig.GOALS:
		assert_true(types.has(goal.type), str(goal))
		if goal.type == "department":
			assert_false(GameConfig.department(goal.param).is_empty(), str(goal))
		if goal.type == "research_level":
			assert_true(GameConfig.RESEARCH.has(goal.param), str(goal))
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


func test_world_layout_helpers() -> void:
	var layout := WorldLayout.get_default()
	assert_eq(layout.input_point(GameConfig.RECEPTION), layout.queue_point(0))
	assert_ne(layout.queue_point(0), layout.queue_point(1))
	assert_ne(layout.queue_point(11), layout.queue_point(12))
	assert_ne(layout.waiting_seat(0), layout.waiting_seat(5))
	assert_ne(layout.desk_position("tax_services/review", 0), layout.desk_position("tax_services/review", 3))
	assert_true(layout.hall.has_point(layout.player_start()))
	assert_true(layout.hall.has_point(layout.runner_home()))
	assert_true(layout.room("tax_services").has_point(layout.pad_point("tax_services")))
	assert_eq(layout.header("tax_services").size.y, WorldLayout.HEADER)
	assert_eq(layout.clamp_to_world(Vector2(-100, 99999)), Vector2(WorldLayout.MARGIN, layout.size.y - WorldLayout.MARGIN))
	assert_true(layout.near(Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS, 0)))
	assert_false(layout.near(Vector2.ZERO, Vector2(GameConfig.INTERACT_RADIUS + 1.0, 0)))
	assert_eq(layout.slot_at(layout.room("customs").get_center()), "customs")
	assert_eq(layout.slot_at(layout.hall.get_center()), "")


func test_room_lookups() -> void:
	assert_eq(GameConfig.room(GameConfig.ROOM_KITCHEN).id, GameConfig.ROOM_KITCHEN)
	assert_true(GameConfig.room("nope").is_empty())
	assert_eq(GameConfig.room_items(GameConfig.ROOM_PHONE, "staff"), ["hr"] as Array[String])
	assert_true(GameConfig.room_items(GameConfig.ROOM_PHONE, "research").is_empty())
	assert_true(GameConfig.room_items("nope", "staff").is_empty())
	assert_eq(GameConfig.room_items(GameConfig.ROOM_HALL, "stations"), [GameConfig.RECEPTION, GameConfig.COUNTER] as Array[String])
	assert_eq(GameConfig.room_items(GameConfig.ROOM_INSPECTION, "stations"), [GameConfig.INSPECTION] as Array[String])


func test_rooms_reference_valid_upgrades() -> void:
	var staff_seen: Array[String] = []
	for room: Dictionary in GameConfig.ROOMS:
		for staff_id in GameConfig.room_items(room.id, "staff"):
			assert_true(Icons.STAFF.has(staff_id), staff_id)
			assert_false(staff_seen.has(staff_id), staff_id)
			staff_seen.append(staff_id)
		for key in GameConfig.room_items(room.id, "stations"):
			assert_true(GameConfig.SHARED_STATIONS.has(key), key)
		for area_id in GameConfig.room_items(room.id, "areas"):
			assert_true(["ticket_machine", "ticket_display", "waiting", "seating", "complaint_clerk", "complaint_box", "mail_storage"].has(area_id), area_id)
		for boost_id in GameConfig.room_items(room.id, "boosts"):
			assert_true(GameConfig.BOOSTS.has(boost_id), boost_id)
			assert_true(Icons.BOOSTS.has(boost_id), boost_id)
	assert_eq(staff_seen.size(), 6)
