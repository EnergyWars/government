extends GutTest

var state: GameState
var sim: Simulation
var actions: GameActions


func before_each() -> void:
	state = GameState.create_new(5)
	sim = Simulation.new(state)
	actions = GameActions.new(state, sim)


func _ids(entries: Array[UpgradeEntry]) -> Array[String]:
	var result: Array[String] = []
	for entry in entries:
		result.append(entry.id)
	return result


func _connect_all_tubes() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)


func _ready_segment(dept_id: String) -> String:
	for tube_id in RouteBuilder.segments(dept_id):
		var ends := RouteBuilder.segment_ends(tube_id)
		if state.station(ends[0]) != null and state.station(ends[1]) != null:
			return tube_id
	return ""


func test_every_global_track_has_one_entry() -> void:
	var ids := _ids(UpgradeCatalog.entries(state))
	for upgrade_id in GameConfig.upgrade_ids():
		if not GameConfig.is_room_upgrade(upgrade_id):
			assert_eq(ids.count("track:" + upgrade_id), 1, upgrade_id)


func test_room_tracks_follow_available_rooms() -> void:
	var ids := _ids(UpgradeCatalog.entries(state))
	assert_true(ids.has("track:office_equipment@general_services"))
	assert_true(ids.has("track:shredder@general_services"))
	assert_true(ids.has("track:tube_station@general_services"))
	assert_true(ids.has("track:tube_station@hall"))
	assert_false(ids.has("track:office_equipment@tax_services"))
	assert_false(ids.has("track:tube_station@mail"))
	assert_false(ids.has("track:tube_station@inspection"))
	state.unlock_department("tax_services")
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	ids = _ids(UpgradeCatalog.entries(state))
	assert_true(ids.has("track:office_equipment@tax_services"))
	assert_true(ids.has("track:shredder@tax_services"))
	assert_true(ids.has("track:tube_station@mail"))


func test_entry_ids_are_unique() -> void:
	state.money = 1e12
	state.reputation = 1e6
	_connect_all_tubes()
	state.add_runner()
	var ids := _ids(UpgradeCatalog.entries(state))
	for entry_id in ids:
		assert_eq(ids.count(entry_id), 1, entry_id)


func test_every_entry_has_known_spot_room_and_topic() -> void:
	_connect_all_tubes()
	state.add_runner()
	for entry in UpgradeCatalog.entries(state):
		assert_false(entry.spot.is_empty(), entry.id)
		assert_true(UpgradeCatalog.rooms().has(entry.room), entry.id)
		assert_true(GameConfig.TOPICS.has(entry.topic), entry.id)
		assert_eq(UpgradeCatalog.find(state, entry.id).id, entry.id)


func test_track_entry_fields() -> void:
	state.money = 0.0
	var entry := UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(entry.kind, UpgradeCatalog.TRACK)
	assert_eq(entry.target, "briefcase")
	assert_eq(entry.room_id, "")
	assert_eq(entry.spot, "player")
	assert_eq(entry.room, GameConfig.ROOM_PLAYER)
	assert_eq(entry.topic, "player")
	assert_eq(entry.level, 0)
	assert_eq(entry.max_level, int(GameConfig.upgrade("briefcase").max))
	assert_almost_eq(entry.cost, Formulas.track_cost("briefcase", 0), 0.001)
	assert_almost_eq(entry.growth, float(GameConfig.upgrade("briefcase").growth), 0.0001)
	assert_eq(entry.reason, "money")
	state.money = 1e9
	state.set_upgrade("briefcase", 4)
	entry = UpgradeCatalog.find(state, "track:briefcase")
	assert_eq(entry.level, 4)
	assert_almost_eq(entry.cost, Formulas.track_cost("briefcase", 4), 0.001)
	assert_true(entry.is_buyable())


func test_room_track_entry_uses_room_spot_and_cost() -> void:
	state.unlock_department("tax_services")
	var entry := UpgradeCatalog.find(state, "track:office_equipment@tax_services")
	assert_eq(entry.room_id, "tax_services")
	assert_eq(entry.spot, "dept:tax_services")
	assert_eq(entry.room, "tax_services")
	assert_almost_eq(entry.cost, Formulas.track_cost("office_equipment", 0, "tax_services"), 0.001)
	assert_gt(entry.cost, Formulas.track_cost("office_equipment", 0, "general_services"))


func test_station_entries_depend_on_station_type() -> void:
	var ids := _ids(UpgradeCatalog.station_entries(state, GameConfig.RECEPTION))
	assert_eq(ids, ["level:shared/reception", "desk:shared/reception", "hire:shared/reception", "trays:shared/reception", "reject_pile:shared/reception"] as Array[String])
	state.unlock_department("tax_services")
	var machine := _ids(UpgradeCatalog.station_entries(state, "tax_services/signature"))
	assert_true(machine.has("level:tax_services/signature"))
	assert_false(machine.has("hire:tax_services/signature"))
	assert_false(machine.has("specialist:tax_services/signature"))
	assert_true(_ids(UpgradeCatalog.station_entries(state, "general_services/review")).has("specialist:general_services/review"))
	assert_true(UpgradeCatalog.station_entries(state, "nope/review").is_empty())


func test_station_entries_point_to_station_spot() -> void:
	for entry in UpgradeCatalog.station_entries(state, "general_services/review"):
		assert_eq(entry.spot, "station:general_services/review")
		assert_eq(entry.room, "general_services")
	var level := UpgradeCatalog.find(state, "level:shared/reception")
	assert_eq(level.room, GameConfig.ROOM_HALL)
	assert_eq(level.max_level, GameConfig.MAX_STATION_LEVEL)
	assert_almost_eq(level.cost, Formulas.upgrade_cost(state.station(GameConfig.RECEPTION)), 0.001)


func test_tray_entries_exist_for_every_station_and_grow_capacity() -> void:
	for key in state.ordered_station_keys():
		assert_true(_ids(UpgradeCatalog.station_entries(state, key)).has("trays:" + key), key)
	var review := state.station("general_services/review")
	var entry := UpgradeCatalog.find(state, "trays:general_services/review")
	assert_eq(entry.kind, UpgradeCatalog.TRAYS)
	assert_eq(entry.topic, "building")
	assert_eq(entry.room, "general_services")
	assert_eq(entry.max_level, GameConfig.MAX_TRAY_LEVEL)
	assert_almost_eq(entry.cost, Formulas.tray_cost(review), 0.001)
	assert_eq(entry.growth, GameConfig.TRAY_GROWTH)
	var inbox := review.inbox_capacity(state.lobby_capacity())
	var outbox := review.outbox_capacity()
	state.money = 1e12
	assert_true(UpgradeCatalog.buy(actions, entry.id, 3))
	assert_eq(review.tray_level, 3)
	assert_eq(review.inbox_capacity(state.lobby_capacity()), inbox + 3 * GameConfig.TRAY_CAPACITY_PER_LEVEL)
	assert_eq(review.outbox_capacity(), outbox + 3 * GameConfig.TRAY_CAPACITY_PER_LEVEL)
	assert_gt(Formulas.tray_cost(review), entry.cost)


func test_tray_upgrade_respects_money_and_maximum() -> void:
	var review := state.station("general_services/review")
	state.money = 0.0
	assert_false(actions.upgrade_trays("general_services/review"))
	assert_eq(UpgradeCatalog.find(state, "trays:general_services/review").reason, "money")
	state.money = 1e15
	review.tray_level = GameConfig.MAX_TRAY_LEVEL
	assert_false(actions.upgrade_trays("general_services/review"))
	assert_eq(UpgradeCatalog.find(state, "trays:general_services/review").reason, "max")
	assert_false(actions.upgrade_trays("nope/review"))
	assert_null(UpgradeCatalog.find(state, "trays:nope/review"))


func test_entry_stations_only_widen_their_out_tray() -> void:
	var reception := state.station(GameConfig.RECEPTION)
	var inbox := reception.inbox_capacity(state.lobby_capacity())
	reception.tray_level = 2
	assert_eq(reception.inbox_capacity(state.lobby_capacity()), inbox)
	assert_eq(reception.outbox_capacity(), GameConfig.OUTBOX_BASE + GameConfig.OUTBOX_PER_DESK * reception.desks + 2 * GameConfig.TRAY_CAPACITY_PER_LEVEL)


func test_tray_texts() -> void:
	var entry := UpgradeCatalog.find(state, "trays:general_services/review")
	assert_eq(UpgradeTexts.title(entry), TranslationServer.translate("FMT_ENTRY_TRAYS") % StationCard.label_for("general_services/review"))
	assert_eq(UpgradeTexts.icon(entry), Icons.INBOX)
	assert_eq(UpgradeTexts.description(entry), TranslationServer.translate("ENTRY_DESC_TRAYS"))
	assert_eq(UpgradeTexts.effect(state, entry), TranslationServer.translate("FMT_EFFECT_TRAYS") % ["0", str(GameConfig.TRAY_CAPACITY_PER_LEVEL)])
	state.station("general_services/review").tray_level = GameConfig.MAX_TRAY_LEVEL
	entry = UpgradeCatalog.find(state, "trays:general_services/review")
	assert_eq(UpgradeTexts.effect(state, entry), TranslationServer.translate("FMT_EFFECT_TRAYS_MAX") % str(GameConfig.MAX_TRAY_LEVEL * GameConfig.TRAY_CAPACITY_PER_LEVEL))
	for key in ["FMT_ENTRY_TRAYS", "ENTRY_DESC_TRAYS", "FMT_EFFECT_TRAYS", "FMT_EFFECT_TRAYS_MAX"]:
		assert_ne(TranslationServer.translate(key), key)


func test_desk_entry_needs_next_stage_when_full() -> void:
	state.money = 1e12
	var station := state.station(GameConfig.RECEPTION)
	while station.desks < state.max_desks():
		station.add_desk()
	var desk := UpgradeCatalog.find(state, "desk:shared/reception")
	assert_true(desk.is_maxed())
	assert_eq(desk.reason, "stage")
	state.building_stage = GameConfig.BUILDING_STAGES.size() - 1
	while station.desks < state.max_desks():
		station.add_desk()
	desk = UpgradeCatalog.find(state, "desk:shared/reception")
	assert_eq(desk.max_level, UpgradeCatalog.final_desks())
	assert_eq(desk.reason, "max")


func test_final_desks_matches_last_stage() -> void:
	assert_eq(UpgradeCatalog.final_desks(), int(GameConfig.BUILDING_STAGES[GameConfig.BUILDING_STAGES.size() - 1].max_desks))


func test_hire_entry_reasons() -> void:
	state.money = 1e9
	var hire := UpgradeCatalog.find(state, "hire:shared/reception")
	assert_eq(hire.reason, "")
	state.station(GameConfig.RECEPTION).staff = state.station(GameConfig.RECEPTION).desks
	assert_eq(UpgradeCatalog.find(state, "hire:shared/reception").reason, "desks")
	state.unlock_department("tax_services")
	assert_eq(UpgradeCatalog.find(state, "hire:tax_services/review").reason, "onboarding")
	state.department("tax_services").hands_on = GameConfig.HANDS_ON_CASES
	assert_eq(UpgradeCatalog.find(state, "hire:tax_services/review").reason, "")


func test_supervisor_entry() -> void:
	var entry := UpgradeCatalog.find(state, "supervisor:general_services")
	assert_eq(entry.spot, "dept:general_services")
	assert_eq(entry.max_level, GameConfig.MAX_SUPERVISORS)
	assert_almost_eq(entry.cost, Formulas.supervisor_cost(state.department("general_services")), 0.001)
	assert_null(UpgradeCatalog.find(state, "supervisor:tax_services"))
	assert_null(UpgradeCatalog.find(state, "supervisor:nope"))


func test_staff_entries_live_on_their_boards() -> void:
	for staff_type: String in UpgradeCatalog.STAFF_SPOTS:
		var entry := UpgradeCatalog.find(state, "staff:" + staff_type)
		assert_eq(entry.spot, UpgradeCatalog.STAFF_SPOTS[staff_type], staff_type)
		assert_true(GameConfig.BOARD_SPOTS.has(entry.spot), staff_type)
		assert_eq(entry.room, GameConfig.spot_room(entry.spot), staff_type)
		assert_eq(entry.max_level, int(UpgradeCatalog.STAFF_LIMITS[staff_type]), staff_type)
		assert_almost_eq(entry.cost, UpgradeCatalog.staff_cost(state, staff_type), 0.001)
	assert_null(UpgradeCatalog.find(state, "staff:nope"))
	assert_eq(UpgradeCatalog.staff_count(state, "nope"), 0)
	assert_eq(UpgradeCatalog.staff_cost(state, "nope"), 0.0)


func test_staff_counts_follow_state() -> void:
	state.add_runner()
	state.add_collector()
	state.add_coffee_intern()
	state.hr = 3
	assert_eq(UpgradeCatalog.staff_count(state, "runners"), 1)
	assert_eq(UpgradeCatalog.staff_count(state, "collectors"), 1)
	assert_eq(UpgradeCatalog.staff_count(state, "coffee_interns"), 1)
	assert_eq(UpgradeCatalog.staff_count(state, "hr"), 3)


func test_complaint_tracks_need_desk_interns_and_security() -> void:
	state.money = 1e9
	assert_eq(UpgradeCatalog.find(state, "track:complaint_interns").reason, "")
	assert_eq(UpgradeCatalog.find(state, "track:intern_steadfast").reason, "requires")
	assert_eq(UpgradeCatalog.find(state, "track:intern_box_runs").reason, "requires")
	assert_eq(UpgradeCatalog.find(state, "track:security_training").reason, "requires")
	state.set_upgrade("complaint_interns", 1)
	assert_eq(UpgradeCatalog.find(state, "track:intern_steadfast").reason, "")
	assert_eq(UpgradeCatalog.find(state, "track:intern_speed").reason, "")
	assert_eq(UpgradeCatalog.find(state, "track:intern_box_runs").reason, "requires")
	state.set_upgrade("complaint_interns", 2)
	assert_eq(UpgradeCatalog.find(state, "track:intern_box_runs").reason, "")
	state.set_upgrade("complaint_security", 1)
	assert_eq(UpgradeCatalog.find(state, "track:security_training").reason, "")


func test_runner_level_entries_exist_per_runner() -> void:
	assert_null(UpgradeCatalog.find(state, "runner_level:0"))
	state.add_runner()
	state.add_runner()
	var ids := _ids(UpgradeCatalog.entries(state))
	assert_true(ids.has("runner_level:0"))
	assert_true(ids.has("runner_level:1"))
	var entry := UpgradeCatalog.find(state, "runner_level:1")
	assert_eq(entry.index, 1)
	assert_eq(entry.spot, "runners")
	assert_eq(entry.max_level, GameConfig.MAX_RUNNER_LEVEL)
	assert_null(UpgradeCatalog.find(state, "runner_level:2"))
	assert_null(UpgradeCatalog.find(state, "runner_level:-1"))
	assert_null(UpgradeCatalog.find(state, "runner_level:abc"))


func test_segments_need_tubes_and_stations() -> void:
	var tube_id := _ready_segment("general_services")
	assert_false(tube_id.is_empty())
	assert_true(UpgradeCatalog.segments(state).is_empty())
	assert_null(UpgradeCatalog.segment(state, tube_id))
	state.set_upgrade("pneumatic_tubes", 1)
	var entry := UpgradeCatalog.segment(state, tube_id)
	assert_eq(entry.reason, "tubes")
	assert_eq(entry.spot, "tube:general_services")
	assert_eq(entry.room, "general_services")
	_connect_all_tubes()
	state.money = 1e12
	assert_eq(UpgradeCatalog.segment(state, tube_id).reason, "")
	assert_true(_ids(UpgradeCatalog.segments(state)).has("segment:" + tube_id))


func test_segment_rejects_unknown_tubes() -> void:
	_connect_all_tubes()
	assert_null(UpgradeCatalog.segment(state, "nope>other"))
	assert_null(UpgradeCatalog.find(state, "segment:" + RouteBuilder.tube_id("tax_services/review", "tax_services/signature")))


func test_storage_entry_needs_mailroom() -> void:
	assert_null(UpgradeCatalog.find(state, "storage:" + GameConfig.MAILROOM))
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	var entry := UpgradeCatalog.find(state, "storage:" + GameConfig.MAILROOM)
	assert_eq(entry.spot, "mail_shelf")
	assert_eq(entry.room, GameConfig.ROOM_MAIL)
	assert_eq(entry.topic, "mail")
	assert_eq(entry.max_level, GameConfig.MAIL_STORAGE_MAX_LEVEL)


func test_unlock_entries_only_offer_the_next_department() -> void:
	var ids := _ids(UpgradeCatalog.entries(state))
	assert_false(ids.has("unlock:general_services"))
	assert_true(ids.has("unlock:tax_services"))
	var next := UpgradeCatalog.find(state, "unlock:tax_services")
	assert_true(next.single)
	assert_eq(next.remaining(), 1)
	assert_eq(next.reason, Progression.unlock_block_reason(state, "tax_services"))
	assert_eq(UpgradeCatalog.find(state, "unlock:business_licences").reason, "later")
	assert_null(UpgradeCatalog.find(state, "unlock:general_services"))
	assert_null(UpgradeCatalog.find(state, "unlock:nope"))


func test_building_stage_is_not_for_sale() -> void:
	assert_null(UpgradeCatalog.find(state, "stage:building"))
	for entry in UpgradeCatalog.entries(state):
		assert_false(entry.id.begins_with("stage:"), entry.id)
	assert_false(UpgradeCatalog.buy(actions, "stage:building"))
	assert_eq(state.building_stage, 0)


func test_unlock_is_not_blocked_by_the_building() -> void:
	state.money = 1e12
	state.reputation = float(GameConfig.department("tax_services").unlock_reputation)
	assert_eq(UpgradeCatalog.find(state, "unlock:tax_services").reason, "")
	assert_true(actions.buy_entry("unlock:tax_services"))
	assert_eq(state.building_stage, GameConfig.stage_for_departments(2))


func test_find_rejects_malformed_ids() -> void:
	for entry_id in ["", "track", "track:nope", "track:office_equipment", "track:briefcase@hall", "track:office_equipment@hall", "level:nope", "desk:", "bogus:1"]:
		assert_null(UpgradeCatalog.find(state, entry_id), entry_id)


func test_entries_for_room_spot() -> void:
	var entries := UpgradeCatalog.entries_for_spot(state, "room:hall")
	var ids := _ids(entries)
	assert_true(ids.has("track:seating"))
	assert_true(ids.has("track:ticket_speed"))
	assert_true(ids.has("track:ticket_machine_2"))
	assert_true(ids.has("level:shared/reception"))
	assert_false(ids.has("track:complaint_security"))
	assert_false(ids.has("stage:building"))
	for entry in entries:
		assert_eq(entry.room, GameConfig.ROOM_HALL, entry.id)


func test_entries_for_department_spot() -> void:
	var entries := UpgradeCatalog.entries_for_spot(state, "dept:general_services")
	var ids := _ids(entries)
	for entry_id in ["level:general_services/review", "track:office_equipment@general_services", "track:shredder@general_services", "supervisor:general_services"]:
		assert_true(ids.has(entry_id), entry_id)
	for entry in entries:
		assert_eq(entry.room, "general_services", entry.id)


func test_entries_for_single_spot() -> void:
	var ids := _ids(UpgradeCatalog.entries_for_spot(state, "toilets"))
	assert_eq(ids, ["track:toilet_stalls", "track:toilet_speed", "track:toilet_hygiene", "track:wake_service"] as Array[String])
	assert_true(UpgradeCatalog.entries_for_spot(state, "nope").is_empty())


func test_tube_hub_lists_all_tube_stations() -> void:
	state.set_upgrade("pneumatic_tubes", 1)
	var ids := _ids(UpgradeCatalog.entries_for_spot(state, UpgradeCatalog.TUBE_HUB))
	assert_true(ids.has("track:pneumatic_tubes"))
	assert_true(ids.has("track:tube_capacity"))
	assert_true(ids.has("track:tube_station@hall"))
	assert_true(ids.has("track:tube_station@general_services"))
	var station_ids := _ids(UpgradeCatalog.entries_for_spot(state, "tube:general_services"))
	assert_true(station_ids.has("track:tube_station@general_services"))
	assert_false(station_ids.has("track:tube_station@hall"))


func test_board_spot_lists_staff_and_their_tracks() -> void:
	state.add_runner()
	var ids := _ids(UpgradeCatalog.entries_for_spot(state, "runners"))
	for entry_id in ["staff:runners", "track:runner_speed", "track:runner_trolleys", "runner_level:0"]:
		assert_true(ids.has(entry_id), entry_id)


func test_spots_of_follows_the_map_order() -> void:
	var spots := UpgradeCatalog.spots_of(UpgradeCatalog.entries_for_spot(state, "room:player"))
	assert_eq(spots, ["player"] as Array[String])
	var hall := UpgradeCatalog.spots_of(UpgradeCatalog.entries_for_spot(state, "room:hall"))
	var expected: Array[String] = ["seating", "pickup_seating", "tickets", "archive", "station:" + GameConfig.RECEPTION, "station:" + GameConfig.COUNTER, "tube:hall"]
	assert_eq(hall, expected)
	var kitchen := UpgradeCatalog.spots_of(UpgradeCatalog.entries_for_spot(state, "room:kitchen"))
	assert_eq(kitchen, ["coffee_machine", "kitchen", "canteen"] as Array[String])
	var complaints := UpgradeCatalog.spots_of(UpgradeCatalog.entries_for_spot(state, "room:complaint_office"))
	assert_eq(complaints, ["complaint_desk", "complaint_box", "security"] as Array[String])
	assert_true(UpgradeCatalog.spots_of([] as Array[UpgradeEntry]).is_empty())


func test_spot_kind_and_target() -> void:
	assert_eq(GameConfig.spot_kind("shredder:housing"), "shredder")
	assert_eq(GameConfig.spot_target("shredder:housing"), "housing")
	assert_eq(GameConfig.spot_kind("station:" + GameConfig.RECEPTION), "station")
	assert_eq(GameConfig.spot_target("station:" + GameConfig.RECEPTION), GameConfig.RECEPTION)
	assert_eq(GameConfig.spot_kind("shredder"), "")
	assert_eq(GameConfig.spot_target("shredder"), "")
	assert_eq(GameConfig.spot_kind(""), "")
	assert_eq(GameConfig.spot_target(""), "")
	assert_eq(GameConfig.spot_room("shredder"), GameConfig.ROOM_SHREDDER)
	assert_eq(GameConfig.spot_room("shredder:housing"), "housing")
	assert_eq(GameConfig.spot_room("nope"), "")


func test_room_spot() -> void:
	assert_eq(UpgradeCatalog.room_spot("general_services"), "dept:general_services")
	assert_eq(UpgradeCatalog.room_spot(GameConfig.ROOM_HALL), "room:hall")
	assert_eq(UpgradeCatalog.room_spot(GameConfig.ROOM_INSPECTION), "room:inspection")


func test_rooms_lists_service_rooms_and_departments() -> void:
	var rooms := UpgradeCatalog.rooms()
	assert_eq(rooms.size(), GameConfig.SERVICE_ROOMS.size() + GameConfig.department_ids().size())
	assert_eq(rooms[0], GameConfig.ROOM_PLAYER)
	assert_true(rooms.has("customs"))


func test_buy_track_in_bulk() -> void:
	state.money = 1e9
	var cost := Formulas.track_bulk_cost("briefcase", 0, 10)
	assert_true(UpgradeCatalog.buy(actions, "track:briefcase", 10))
	assert_eq(state.upgrade_level("briefcase"), 10)
	assert_almost_eq(state.money, 1e9 - cost, 0.01)


func test_buy_room_track() -> void:
	state.money = 1e9
	assert_true(actions.buy_entry("track:office_equipment@general_services"))
	assert_eq(state.upgrade_level("office_equipment", "general_services"), 1)
	assert_false(actions.buy_entry("track:office_equipment@tax_services"))


func test_buy_repeats_until_money_runs_out() -> void:
	var station := state.station(GameConfig.RECEPTION)
	var start := station.level
	state.money = Formulas.upgrade_cost(station) + 0.5
	assert_true(actions.buy_entry("level:shared/reception", 5))
	assert_eq(station.level, start + 1)
	assert_false(actions.buy_entry("level:shared/reception"))


func test_buy_single_kinds_only_once() -> void:
	state.money = 1e12
	state.reputation = 1e6
	assert_true(actions.buy_entry("unlock:tax_services", 3))
	assert_true(state.department("tax_services").unlocked)
	assert_false(state.department("business_licences").unlocked)


func test_buy_every_other_kind() -> void:
	state.money = 1e12
	state.reputation = 1e6
	_connect_all_tubes()
	state.building_stage = GameConfig.MAIL_UNLOCK_STAGE
	state.ensure_mailroom()
	assert_true(actions.buy_entry("desk:shared/reception"))
	assert_true(actions.buy_entry("hire:shared/reception"))
	assert_true(actions.buy_entry("specialist:general_services/review"))
	assert_true(actions.buy_entry("supervisor:general_services"))
	for staff_type: String in UpgradeCatalog.STAFF_SPOTS:
		assert_true(actions.buy_entry("staff:" + staff_type), staff_type)
		assert_eq(UpgradeCatalog.staff_count(state, staff_type), 1, staff_type)
	assert_true(actions.buy_entry("runner_level:0"))
	assert_eq(state.runners[0].level, 1)
	var tube_id := _ready_segment("general_services")
	assert_true(actions.buy_entry("segment:" + tube_id))
	assert_eq(state.tube_level(tube_id), 1)
	assert_true(actions.buy_entry("storage:" + GameConfig.MAILROOM))
	assert_eq(state.mailroom().storage_level, 1)


func test_buy_rejects_unknown_ids() -> void:
	state.money = 1e12
	assert_false(actions.buy_entry("bogus:1"))
	assert_false(actions.buy_entry("runner_level:abc"))
	assert_false(actions.buy_entry("staff:nope"))
	assert_false(UpgradeCatalog.hire_staff(actions, "nope"))
