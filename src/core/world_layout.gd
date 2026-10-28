class_name WorldLayout
extends RefCounted

const MAIN_WIDTH := 1400.0
const SIDE_WIDTH := 660.0
const MARGIN := 40.0
const WIDTH := MAIN_WIDTH + SIDE_WIDTH + MARGIN
const PLACE_COLUMNS := 10
const PLACE_ROWS := 7
const PLACE_PITCH := Vector2(32.0, 30.0)
const PLACE_AREA_SIZE := Vector2(336.0, 216.0)
const TICKET_LINE_ROWS := 3
const TICKET_LINE_SPACING := Vector2(36.0, 34.0)
const TICKET_MACHINE_SPACING := 170.0
const HALL_TOP := 56.0
const HALL_SIDE := 24.0
const HALL_AISLE := 72.0
const WAITING_ROOM_HEIGHT := 570.0
const ROOM_BAND := 40.0
const OFFICE_COUNT := 6
const OFFICE_TOP := 32.0
const OFFICE_DEPTH := 130.0
const OFFICE_DESK_Y := 110.0
const TRAY_ROW_Y := 196.0
const HALL_AREA_HEIGHT := 220.0
const DOOR_WIDTH := 360.0
const DESK_FRONT := Vector2(0.0, 46.0)
const GAP := 20.0
const ROW_HEIGHT := 460.0
const AREA_HEIGHT := 320.0
const UTILITY_Y := 414.0
const HALL_HEIGHT := 850.0
const TECH_HEIGHT := 430.0
const TOILETS_HEIGHT := 300.0
const KITCHEN_HEIGHT := 460.0
const PHONE_HEIGHT := 220.0
const MAIL_HEIGHT := 360.0
const PLAYER_OFFICE_HEIGHT := 340.0
const STAFF_HEIGHT := 280.0
const STAFF_BOARD_COLUMNS := 4
const STAFF_BOARD_GAP := 12.0
const SHREDDER_HEIGHT := 300.0
const COMPLAINT_HEIGHT := 400.0
const MAIL_SHELF_WIDTH := 160.0
const MAIL_STATION_X := 200.0
const MAIL_STATION_WIDTH := 260.0
const MAIL_SIDE_X := 560.0
const INTERN_SPACING := 80.0
const HEADER := 56.0
const DESK_COLUMNS := 3
const DESK_ROWS := 3
const LOO_COLUMNS := 12
const LOO_PITCH := 50.0
const LOO_ROW_HEIGHT := 150.0
const LOO_SPOT := Vector2(25.0, 132.0)
const SLOT_SIZE := Vector2(88.0, 52.0)
const KITCHEN_SPOTS: Array[Vector2] = [
	Vector2(440, 190), Vector2(490, 200), Vector2(540, 190), Vector2(590, 200), Vector2(465, 236), Vector2(615, 236),
	Vector2(470, 300), Vector2(570, 300), Vector2(455, 345), Vector2(520, 360), Vector2(585, 345), Vector2(520, 290),
	Vector2(110, 262), Vector2(190, 262), Vector2(270, 262), Vector2(110, 338), Vector2(190, 338), Vector2(270, 338),
]
const DESK_WORK_OFFSET := Vector2(0.0, -26.0)
const SHAFT_X := 20.0
const OUTPUT_SHAFT_X := MAIN_WIDTH - SHAFT_X
const OUTPUT_LANE := 6.0
const ROWS: Array = [
	["customs"],
	["housing", "social_benefits"],
	["vehicle_registration", "building_permits"],
	["business_licences", "inspection"],
	["general_services", "tax_services"],
]
const ROOM_PREFIX := "room:"
const DEPT_PREFIX := "dept:"
const STATION_PREFIX := "station:"
const TRAYS_PREFIX := "trays:"
const TRAY_TAP_OFFSET := Vector2(-34.0, -36.0)
const TRAY_TAP_SIZE := Vector2(100.0, 70.0)
const TUBE_PREFIX := "tube:"
const LEAD_PREFIX := "lead:"
const LEAD_OFFICE_SIZE := Vector2(180.0, 72.0)
const LEAD_ROOM_OFFSET := Vector2(312.0, 382.0)
const LEAD_HALL_SIZE := Vector2(150.0, 104.0)
const LEAD_HALL_INSET := Vector2(100.0, 282.0)
const LEAD_MAIL_OFFSET := Vector2(470.0, 150.0)
const LEAD_DESK_OFFSET := Vector2(0.0, 10.0)
const RUNNER_LOUNGE := Rect2(1130.0, 652.0, 176.0, 140.0)
const RUNNER_REST_COLUMNS := 6
const RUNNER_REST_PITCH := Vector2(26.0, 16.0)
const RUNNER_REST_ORIGIN := Vector2(22.0, 98.0)

static var _default: WorldLayout

var size := Vector2.ZERO
var hall := Rect2()
var kitchen := Rect2()
var toilets := Rect2()
var phone_office := Rect2()
var mail_room := Rect2()
var complaint_office := Rect2()
var shredder_room := Rect2()
var tech_room := Rect2()
var player_office := Rect2()
var staff_room := Rect2()
var entrance := Vector2.ZERO
var ticket_area := Rect2()
var waiting_rooms: Dictionary[String, Rect2] = {}
var place_areas: Dictionary[String, Rect2] = {}
var rooms: Dictionary[String, Rect2] = {}
var areas: Dictionary[String, Rect2] = {}
var spots: Dictionary[String, Array] = {}
var _input_points: Dictionary = {}
var _desk_reach: Dictionary = {}
var _output_points: Dictionary = {}
var _tube_paths: Dictionary = {}


static func get_default() -> WorldLayout:
	if _default == null:
		_default = WorldLayout.new()
		_default._build()
	return _default


func _build() -> void:
	var column_width := (MAIN_WIDTH - MARGIN * 2.0 - GAP) / 2.0
	var full_width := MAIN_WIDTH - MARGIN * 2.0
	var y := MARGIN
	for row: Array in ROWS:
		if row.size() == 1:
			rooms[row[0]] = Rect2(MARGIN, y, full_width, ROW_HEIGHT)
		else:
			for i in row.size():
				rooms[row[i]] = Rect2(MARGIN + i * (column_width + GAP), y, column_width, ROW_HEIGHT)
		y += ROW_HEIGHT + GAP
	hall = Rect2(MARGIN, y, full_width, HALL_HEIGHT)
	size = Vector2(WIDTH, hall.end.y + MARGIN)
	entrance = Vector2(MAIN_WIDTH * 0.5, hall.end.y - 12.0)
	_build_side_column()
	_build_waiting_rooms()
	ticket_area = _in_hall(Rect2(90, 626, 520, 190))
	areas[GameConfig.INSPECTION] = _local("inspection", Rect2(24, HEADER, 602, AREA_HEIGHT))
	areas[GameConfig.MAILROOM] = Rect2(mail_room.position + Vector2(MAIL_STATION_X, HEADER), Vector2(MAIL_STATION_WIDTH, MAIL_HEIGHT - HEADER - 24))
	for dept_id in GameConfig.department_ids():
		var keys := GameConfig.department_station_keys(dept_id)
		if keys.size() == 2:
			areas[keys[0]] = _local(dept_id, Rect2(24, HEADER, 340, AREA_HEIGHT))
			areas[keys[1]] = _local(dept_id, Rect2(388, HEADER, 238, AREA_HEIGHT))
		else:
			var width := (rooms[dept_id].size.x - 48.0 - GAP * (keys.size() - 1)) / keys.size()
			for i in keys.size():
				areas[keys[i]] = _local(dept_id, Rect2(24 + i * (width + GAP), HEADER, width, AREA_HEIGHT))
	_build_spots()


func _build_side_column() -> void:
	var heights := [TECH_HEIGHT, TOILETS_HEIGHT, KITCHEN_HEIGHT, PHONE_HEIGHT, MAIL_HEIGHT, PLAYER_OFFICE_HEIGHT, STAFF_HEIGHT, SHREDDER_HEIGHT, COMPLAINT_HEIGHT]
	var total := GAP * (heights.size() - 1)
	for height: float in heights:
		total += height
	var y := hall.end.y - total
	var stack: Array[Rect2] = []
	for height: float in heights:
		stack.append(Rect2(MAIN_WIDTH, y, SIDE_WIDTH, height))
		y += height + GAP
	tech_room = stack[0]
	toilets = stack[1]
	kitchen = stack[2]
	phone_office = stack[3]
	mail_room = stack[4]
	player_office = stack[5]
	staff_room = stack[6]
	shredder_room = stack[7]
	complaint_office = stack[8]


func _build_waiting_rooms() -> void:
	var width := (hall.size.x - HALL_SIDE * 2.0 - HALL_AISLE) / 2.0
	waiting_rooms[GameConfig.HALL_INTAKE] = _in_hall(Rect2(HALL_SIDE, HALL_TOP, width, WAITING_ROOM_HEIGHT))
	waiting_rooms[GameConfig.HALL_PICKUP] = _in_hall(Rect2(HALL_SIDE + width + HALL_AISLE, HALL_TOP, width, WAITING_ROOM_HEIGHT))
	var area_rect := Rect2(8.0, ROOM_BAND + 4.0, width - 16.0, HALL_AREA_HEIGHT)
	areas[GameConfig.RECEPTION] = _in_room(GameConfig.HALL_INTAKE, area_rect)
	areas[GameConfig.COUNTER] = _in_room(GameConfig.HALL_PICKUP, area_rect)
	var place_y := area_rect.end.y + 12.0
	place_areas[GameConfig.HALL_INTAKE] = _in_room(GameConfig.HALL_INTAKE, Rect2(Vector2(width - 8.0 - PLACE_AREA_SIZE.x, place_y), PLACE_AREA_SIZE))
	place_areas[GameConfig.HALL_PICKUP] = _in_room(GameConfig.HALL_PICKUP, Rect2(Vector2(8.0, place_y), PLACE_AREA_SIZE))


func _in_room(room: String, rect: Rect2) -> Rect2:
	return Rect2(waiting_room(room).position + rect.position, rect.size)


func _local(slot: String, rect: Rect2) -> Rect2:
	return Rect2(rooms[slot].position + rect.position, rect.size)


func _in_hall(rect: Rect2) -> Rect2:
	return Rect2(hall.position + rect.position, rect.size)


func _build_spots() -> void:
	for room_id in GameConfig.SERVICE_ROOMS:
		var header_rect := room_header(room_id)
		if header_rect.has_area():
			_add_spot(ROOM_PREFIX + room_id, header_rect)
	_add_spot("entrance", Rect2(entrance + Vector2(-90.0, -56.0), Vector2(180.0, 76.0)))
	for room in GameConfig.WAITING_ROOMS:
		var spot: String = GameConfig.upgrade(str(GameConfig.SEATING_TRACKS[room])).spot
		_add_spot(spot, place_area(room))
		_add_spot(spot, seating_sign_rect(room))
		_add_spot(spot, standing_sign_rect(room))
	_add_spot("tickets", ticket_area)
	_add_spot("runners", runner_lounge())
	_add_spot("complaint_box", Rect2(complaint_box_point() + Vector2(-44.0, -48.0), Vector2(110.0, 96.0)))
	_add_spot("archive", archive_rect())
	_add_spot("complaint_desk", complaint_read_rect())
	_add_spot("security", security_rect())
	_add_spot("shredder", Rect2(shredder_point() + Vector2(-70.0, -100.0), Vector2(140.0, 150.0)))
	_add_spot("server", server_rect())
	_add_spot("climate", climate_rect())
	_add_spot("tube_hub", Rect2(tube_hub_point() + Vector2(-70.0, -70.0), Vector2(140.0, 140.0)))
	_add_spot("coffee_machine", Rect2(coffee_machine_point() + Vector2(-70.0, -64.0), Vector2(140.0, 130.0)))
	_add_spot("kitchen", Rect2(kranz_point() + Vector2(-110.0, -110.0), Vector2(220.0, 190.0)))
	_add_spot("canteen", canteen_counter_rect().grow(12.0))
	_add_spot("canteen", Rect2(lunch_table_point() + Vector2(-140.0, -60.0), Vector2(280.0, 120.0)))
	_add_spot("toilets", Rect2(toilets.position + Vector2(10.0, HEADER), toilets.size - Vector2(20.0, HEADER + 10.0)))
	_add_spot("phone", Rect2(phone_office.position + Vector2(30.0, HEADER + 10.0), Vector2(170.0, PHONE_HEIGHT - HEADER - 20.0)))
	for board in GameConfig.STAFF_ROOM_BOARDS:
		_add_spot(board, staff_board(board))
	_add_spot("mail_shelf", mail_storage_rect())
	_add_spot("mailbox", Rect2(mail_door() + Vector2(-80.0, -56.0), Vector2(86.0, 104.0)))
	for key in areas:
		_add_spot(STATION_PREFIX + key, areas[key])
		for point in tray_points(key):
			_add_spot(TRAYS_PREFIX + key, tray_rect(point))
	for dept_id in GameConfig.department_ids():
		_add_spot(DEPT_PREFIX + dept_id, header(dept_id))
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		_add_spot(TUBE_PREFIX + room_id, slot_rect(tube_station_point(room_id)))
	for room_id in GameConfig.lead_rooms():
		_add_spot(LEAD_PREFIX + room_id, lead_office(room_id))


func tray_points(key: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if not GameConfig.is_entry_station(key):
		points.append(input_point(key))
	if not GameConfig.is_final_station(key):
		points.append(output_point(key))
	if GameConfig.has_reject_pile(key):
		points.append(reject_point(key))
	return points


func tray_rect(point: Vector2) -> Rect2:
	return Rect2(point + TRAY_TAP_OFFSET, TRAY_TAP_SIZE)


func _add_spot(spot: String, rect: Rect2) -> void:
	if not spots.has(spot):
		spots[spot] = []
	spots[spot].append(rect)


func spot_rects(spot: String) -> Array:
	return spots.get(spot, [])


func spot_center(spot: String) -> Vector2:
	var rects := spot_rects(spot)
	return (rects[0] as Rect2).get_center() if not rects.is_empty() else Vector2.ZERO


func spot_at(point: Vector2) -> String:
	var best := ""
	var best_area := INF
	for spot in spots:
		for rect: Rect2 in spots[spot]:
			if rect.has_point(point) and rect.get_area() < best_area:
				best = spot
				best_area = rect.get_area()
	return best


func slot_rect(center: Vector2) -> Rect2:
	return Rect2(center - SLOT_SIZE * 0.5, SLOT_SIZE)


func area(key: String) -> Rect2:
	return areas.get(key, Rect2())


func room(slot: String) -> Rect2:
	return rooms.get(slot, Rect2())


func header(slot: String) -> Rect2:
	var rect := room(slot)
	return Rect2(rect.position, Vector2(rect.size.x, HEADER))


func service_room(room_id: String) -> Rect2:
	match room_id:
		GameConfig.ROOM_HALL:
			return hall
		GameConfig.ROOM_KITCHEN:
			return kitchen
		GameConfig.ROOM_TOILETS:
			return toilets
		GameConfig.ROOM_PHONE:
			return phone_office
		GameConfig.ROOM_MAIL:
			return mail_room
		GameConfig.ROOM_COMPLAINTS:
			return complaint_office
		GameConfig.ROOM_SHREDDER:
			return shredder_room
		GameConfig.ROOM_TECH:
			return tech_room
		GameConfig.ROOM_OFFICE:
			return player_office
		GameConfig.ROOM_STAFF:
			return staff_room
		GameConfig.ROOM_INSPECTION:
			return room("inspection")
	return room(room_id)


func room_header(room_id: String) -> Rect2:
	if room_id == GameConfig.ROOM_HALL:
		return hall_plate()
	var rect := service_room(room_id)
	return Rect2(rect.position, Vector2(rect.size.x, HEADER)) if rect.has_area() else Rect2()


func hall_plate() -> Rect2:
	return _in_hall(Rect2(hall.size.x * 0.5 - 170.0, 13, 340, 30))


func waiting_room(room: String) -> Rect2:
	return waiting_rooms.get(room, Rect2())


func place_area(room: String) -> Rect2:
	return place_areas.get(room, Rect2())


func room_band(room: String) -> Rect2:
	var rect := waiting_room(room)
	return Rect2(rect.position, Vector2(rect.size.x, ROOM_BAND))


func room_clock_point(room: String) -> Vector2:
	var band := room_band(room)
	return Vector2(band.end.x - 30.0, band.get_center().y + 2.0)


func room_walls(room: String) -> PackedVector2Array:
	var rect := waiting_room(room)
	var wall := rect.size.x - DOOR_WIDTH
	var door_top := rect.position.y + ROOM_BAND + 4.0 + OFFICE_TOP + OFFICE_DEPTH
	if room == GameConfig.HALL_PICKUP:
		return PackedVector2Array([Vector2(rect.end.x - wall, rect.end.y), rect.end, Vector2(rect.end.x, rect.position.y), rect.position, Vector2(rect.position.x, door_top)])
	return PackedVector2Array([Vector2(rect.position.x + wall, rect.end.y), Vector2(rect.position.x, rect.end.y), rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, door_top)])


static func has_offices(key: String) -> bool:
	return key == GameConfig.RECEPTION or key == GameConfig.COUNTER


func office_rect(key: String, index: int) -> Rect2:
	var rect := area(key)
	var width := (rect.size.x - 8.0) / OFFICE_COUNT
	var slot := clampi(index, 0, OFFICE_COUNT - 1)
	return Rect2(rect.position + Vector2(4.0 + slot * width, OFFICE_TOP), Vector2(width, OFFICE_DEPTH))


func hall_tray_point(key: String, slot: int) -> Vector2:
	var rect := area(key)
	if key == GameConfig.COUNTER:
		return Vector2(rect.end.x - 40.0 - (1 - slot) * 110.0, rect.position.y + TRAY_ROW_Y)
	return Vector2(rect.position.x + 40.0 + slot * 110.0, rect.position.y + TRAY_ROW_Y)


func input_point(key: String) -> Vector2:
	if not _input_points.has(key):
		_input_points[key] = _compute_input_point(key)
	return _input_points[key]


func _compute_input_point(key: String) -> Vector2:
	var rect := area(key)
	if key == GameConfig.COUNTER:
		return hall_tray_point(key, 0)
	if GameConfig.station_kind_of(key) == "dock":
		return Vector2(rect.position.x + 30.0, rect.get_center().y)
	return Vector2(rect.position.x + 40.0, rect.end.y - 40.0)


func output_point(key: String) -> Vector2:
	if not _output_points.has(key):
		var rect := area(key)
		_output_points[key] = hall_tray_point(key, 0) if key == GameConfig.RECEPTION else Vector2(rect.end.x - 40.0, rect.end.y - 40.0)
	return _output_points[key]


func reject_point(key: String) -> Vector2:
	if has_offices(key):
		return hall_tray_point(key, 1)
	return output_point(key) + Vector2(-64.0, 0.0)


func review_key(dept_id: String) -> String:
	var keys := GameConfig.department_station_keys(dept_id)
	for key in keys:
		if GameConfig.station_kind_of(key) == "review":
			return key
	return keys[0] if not keys.is_empty() else ""


func tube_station_point(room_id: String) -> Vector2:
	match room_id:
		GameConfig.ROOM_HALL:
			return waiting_room(GameConfig.HALL_PICKUP).position + Vector2(520.0, 520.0)
		GameConfig.ROOM_MAIL:
			return mail_room.position + Vector2(MAIL_SIDE_X, MAIL_HEIGHT - 44.0)
	var rect := service_room(room_id)
	return Vector2(rect.end.x - 110.0, rect.position.y + UTILITY_Y)


func lead_office(room_id: String) -> Rect2:
	match room_id:
		GameConfig.HALL_INTAKE:
			return _in_room(room_id, Rect2(LEAD_HALL_INSET, LEAD_HALL_SIZE))
		GameConfig.HALL_PICKUP:
			var width := waiting_room(room_id).size.x
			return _in_room(room_id, Rect2(Vector2(width - LEAD_HALL_INSET.x - LEAD_HALL_SIZE.x, LEAD_HALL_INSET.y), LEAD_HALL_SIZE))
		GameConfig.ROOM_MAIL:
			return Rect2(mail_room.position + LEAD_MAIL_OFFSET, LEAD_OFFICE_SIZE)
	var rect := service_room(room_id)
	return Rect2(rect.position + LEAD_ROOM_OFFSET, LEAD_OFFICE_SIZE)


func lead_desk_point(room_id: String) -> Vector2:
	return lead_office(room_id).get_center() + LEAD_DESK_OFFSET


func lead_seat(room_id: String) -> Vector2:
	return lead_desk_point(room_id) + Vector2(0.0, -24.0)


func patrol_path(room_id: String, desks: Array[Vector2]) -> PackedVector2Array:
	var start := lead_seat(room_id)
	var path := PackedVector2Array([start])
	for point in desks:
		path.append(point)
	path.append(start)
	return path


func door_in() -> Vector2:
	return entrance + Vector2(-30.0, 0.0)


func door_out() -> Vector2:
	return entrance + Vector2(30.0, 0.0)


func office_door() -> Vector2:
	return side_door(complaint_office)


func shredder_door() -> Vector2:
	return side_door(shredder_room)


func tech_door() -> Vector2:
	return side_door(tech_room)


func player_office_door() -> Vector2:
	return side_door(player_office)


func staff_door() -> Vector2:
	return side_door(staff_room)


func staff_board(board: String) -> Rect2:
	var index := maxi(0, GameConfig.STAFF_ROOM_BOARDS.find(board))
	var rows := ceili(GameConfig.STAFF_ROOM_BOARDS.size() / float(STAFF_BOARD_COLUMNS))
	var width := (SIDE_WIDTH - 32.0 - STAFF_BOARD_GAP * (STAFF_BOARD_COLUMNS - 1)) / STAFF_BOARD_COLUMNS
	var height := (STAFF_HEIGHT - HEADER - 20.0 - STAFF_BOARD_GAP * (rows - 1)) / rows
	var column := index % STAFF_BOARD_COLUMNS
	var row := floori(index / float(STAFF_BOARD_COLUMNS))
	return Rect2(staff_room.position + Vector2(16.0 + column * (width + STAFF_BOARD_GAP), HEADER + 8.0 + row * (height + STAFF_BOARD_GAP)), Vector2(width, height))


static func side_door(rect: Rect2) -> Vector2:
	return Vector2(rect.position.x, rect.get_center().y + HEADER * 0.5)


func room_slot(key: String) -> String:
	if key == GameConfig.INSPECTION:
		return "inspection"
	return GameConfig.station_dept(key)


func tube_gap(key: String) -> float:
	var slot := room_slot(key)
	if slot.is_empty():
		return hall.position.y - GAP * 0.5
	return room(slot).end.y + GAP * 0.5


func tube_path(from_key: String, to_key: String) -> PackedVector2Array:
	var cache_key := "%s>%s" % [from_key, to_key]
	if _tube_paths.has(cache_key):
		return _tube_paths[cache_key]
	var start := output_point(from_key)
	var finish := input_point(to_key)
	var path := PackedVector2Array([start])
	if room_slot(from_key) == room_slot(to_key):
		path.append(start + Vector2(0.0, 20.0))
		path.append(finish + Vector2(0.0, 20.0))
	else:
		var output := is_output_tube(to_key)
		var shaft := OUTPUT_SHAFT_X if output else SHAFT_X
		var lane := OUTPUT_LANE if output else 0.0
		var gap_from := tube_gap(from_key) + lane
		var gap_to := tube_gap(to_key) + lane
		path.append(Vector2(start.x, gap_from))
		path.append(Vector2(shaft, gap_from))
		path.append(Vector2(shaft, gap_to))
		path.append(Vector2(finish.x, gap_to))
	path.append(finish)
	_tube_paths[cache_key] = path
	return path


static func is_output_tube(to_key: String) -> bool:
	return to_key == GameConfig.COUNTER


static func path_length(path: PackedVector2Array) -> float:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


static func path_point(path: PackedVector2Array, distance: float) -> Vector2:
	var remaining := maxf(0.0, distance)
	for i in path.size() - 1:
		var segment := path[i].distance_to(path[i + 1])
		if remaining <= segment:
			return path[i] if segment <= 0.0 else path[i].lerp(path[i + 1], remaining / segment)
		remaining -= segment
	return path[path.size() - 1]


func desk_reach(key: String, count: int) -> Rect2:
	var by_count: Dictionary = _desk_reach.get(key, {})
	if by_count.is_empty():
		_desk_reach[key] = by_count
	if not by_count.has(count):
		var bounds := Rect2(desk_position(key, 0), Vector2.ZERO)
		for desk in range(1, count):
			bounds = bounds.expand(desk_position(key, desk))
		by_count[count] = bounds.grow(GameConfig.INTERACT_RADIUS + 1.0)
	return by_count[count]


func desk_work_point(key: String, desk: int) -> Vector2:
	return desk_position(key, desk) + DESK_WORK_OFFSET


func desk_position(key: String, index: int) -> Vector2:
	if has_offices(key):
		var office := office_rect(key, index)
		return Vector2(office.get_center().x, area(key).position.y + OFFICE_DESK_Y)
	var rect := area(key)
	var grid := Rect2(rect.position + Vector2(24, 28), Vector2(rect.size.x - 48, rect.size.y - 120))
	var cell := Vector2(grid.size.x / DESK_COLUMNS, grid.size.y / DESK_ROWS)
	var col := index % DESK_COLUMNS
	var row := floori(index / float(DESK_COLUMNS))
	return grid.position + Vector2(cell.x * (col + 0.5), cell.y * (row + 0.5))


func desk_front(key: String, desk: int) -> Vector2:
	return desk_position(key, desk) + DESK_FRONT


func place_slot(room: String, slot: int) -> Vector2:
	var index := clampi(slot, 0, GameConfig.WAITING_PLACES - 1)
	var col := index % PLACE_COLUMNS
	var row := floori(index / float(PLACE_COLUMNS))
	return place_area(room).position + Vector2(24.0 + col * PLACE_PITCH.x, 20.0 + row * PLACE_PITCH.y)


func waiting_seat(index: int, room: String = GameConfig.HALL_INTAKE) -> Vector2:
	return place_slot(room, index)


func standing_point(index: int, seats: int, room: String = GameConfig.HALL_INTAKE) -> Vector2:
	return place_slot(room, seats + index)


func ticket_machine_point(machine: int = 0) -> Vector2:
	var index := clampi(machine, 0, GameConfig.MAX_TICKET_MACHINES - 1)
	return hall.position + Vector2(560.0 - index * TICKET_MACHINE_SPACING, 670.0)


func ticket_line_point(machine: int, slot: int) -> Vector2:
	var index := clampi(slot, 0, GameConfig.TICKET_LINE_SLOTS - 1)
	var col := floori(index / float(TICKET_LINE_ROWS))
	var row := index % TICKET_LINE_ROWS
	if col % 2 == 1:
		row = TICKET_LINE_ROWS - 1 - row
	return ticket_machine_point(machine) + Vector2(-col * TICKET_LINE_SPACING.x, 54.0 + row * TICKET_LINE_SPACING.y)


func seating_sign_rect(room: String = GameConfig.HALL_INTAKE) -> Rect2:
	var rect := place_area(room)
	return Rect2(rect.position + Vector2(4, rect.size.y + 8), Vector2(200, 24))


func standing_sign_rect(room: String = GameConfig.HALL_INTAKE) -> Rect2:
	var rect := place_area(room)
	return Rect2(rect.position + Vector2(4, rect.size.y + 38), Vector2(200, 24))


func ruckus_point(desk: int) -> Vector2:
	return desk_front(GameConfig.RECEPTION, desk)


func archive_rect() -> Rect2:
	return _in_room(GameConfig.HALL_INTAKE, Rect2(20, 300, 72, 116))


func depot_rect() -> Rect2:
	return _in_hall(Rect2(700, 646, 150, 72))


func depot_point() -> Vector2:
	return depot_rect().get_center() + Vector2(0.0, 52.0)


func hours_board() -> Rect2:
	return _in_hall(Rect2(880, 650, 96, 64))


func training_board() -> Rect2:
	return staff_board("training")


func complaint_desk_point() -> Vector2:
	return complaint_office.position + Vector2(250.0, 220.0)


func complaint_player_point() -> Vector2:
	return complaint_desk_point() + Vector2(-125.0, -34.0)


func complaint_counter_rect() -> Rect2:
	return Rect2(complaint_desk_point() + Vector2(-130.0, -4.0), Vector2(260.0, 40.0))


func complaint_box_point() -> Vector2:
	return complaint_office.position + Vector2(450.0, 236.0)


func complaint_read_rect() -> Rect2:
	return complaint_counter_rect().grow(12.0)


func security_post() -> Vector2:
	return office_door() + Vector2(46.0, -46.0)


func security_stop_spot() -> Vector2:
	return office_door() + Vector2(-50.0, 14.0)


func security_rect() -> Rect2:
	return Rect2(security_post() + Vector2(-34.0, -58.0), Vector2(68.0, 90.0))


func closed_sign_rect() -> Rect2:
	return _in_hall(Rect2(736.0, 740.0, 120.0, 54.0))


func shredder_point() -> Vector2:
	return shredder_room.position + Vector2(170.0, 200.0)


func intern_home(slot: int = 0) -> Vector2:
	var index := clampi(slot, 0, GameConfig.MAX_DESK_INTERNS - 1)
	return complaint_desk_point() + Vector2((index - 1) * INTERN_SPACING, -30.0)


func intern_cry_point(slot: int = 0) -> Vector2:
	return toilets.position + Vector2(60.0 + clampi(slot, 0, GameConfig.MAX_DESK_INTERNS - 1) * 44.0, TOILETS_HEIGHT - 30.0)


func intern_shred_point(slot: int = 0) -> Vector2:
	return shredder_point() + Vector2(-46.0 - slot * 18.0, 12.0 + (slot % 2) * 10.0)


func intern_box_point(slot: int = 0) -> Vector2:
	return complaint_box_point() + Vector2(-18.0 * clampi(slot, 0, GameConfig.MAX_DESK_INTERNS - 1), -52.0)


func intern_trip_length(slot: int = 1) -> float:
	var home := intern_home(slot)
	return home.distance_to(intern_box_point(slot)) + intern_box_point(slot).distance_to(intern_shred_point(slot)) + intern_shred_point(slot).distance_to(home)


func visitor_spot(slot: int) -> Vector2:
	var index := clampi(slot, 0, GameConfig.VISITOR_SLOTS - 1)
	return complaint_desk_point() + Vector2((index - 1) * INTERN_SPACING, 70.0 + (index % 2) * 12.0)


func complaint_drop_spot() -> Vector2:
	return complaint_box_point() + Vector2(-44.0, 24.0)


func runners_board() -> Rect2:
	return runner_lounge()


func runner_lounge() -> Rect2:
	return _in_hall(RUNNER_LOUNGE)


func runner_rest_point(index: int) -> Vector2:
	var slot := posmod(index, GameConfig.MAX_RUNNERS)
	var column := slot % RUNNER_REST_COLUMNS
	var row := floori(slot / float(RUNNER_REST_COLUMNS))
	return runner_lounge().position + RUNNER_REST_ORIGIN + Vector2(column * RUNNER_REST_PITCH.x, (row % 3) * RUNNER_REST_PITCH.y)


func server_rect() -> Rect2:
	return Rect2(tech_room.position + Vector2(250.0, 66.0), Vector2(94.0, 150.0))


func climate_rect() -> Rect2:
	return Rect2(tech_room.position + Vector2(236.0, 236.0), Vector2(108.0, 64.0))


func tube_hub_point() -> Vector2:
	return tech_room.position + Vector2(110.0, 240.0)


func runner_home() -> Vector2:
	return runner_rest_point(0)


func dispute_point(dept_id: String) -> Vector2:
	var rect := room(dept_id)
	return rect.position + Vector2(rect.size.x - 86.0, HEADER + 44.0)


func dispute_spot(dept_id: String, index: int) -> Vector2:
	return dispute_point(dept_id) + Vector2(-GameConfig.DISPUTE_CREW_OFFSET if index == 0 else GameConfig.DISPUTE_CREW_OFFSET, 0.0)


func coffee_home() -> Vector2:
	return coffee_machine_point() + Vector2(70.0, 40.0)


func coffee_brew_point() -> Vector2:
	return coffee_machine_point() + Vector2(0.0, 36.0)


func coffee_interns_board() -> Rect2:
	return staff_board("coffee_interns")


func works_council_board() -> Rect2:
	return staff_board("works_council")


func canteen_counter_rect() -> Rect2:
	return Rect2(kitchen.position + Vector2(24.0, HEADER + 54.0), Vector2(330.0, 44.0))


func cook_point() -> Vector2:
	return canteen_counter_rect().position + Vector2(240.0, -10.0)


func lunch_table_point() -> Vector2:
	return kitchen.position + Vector2(190.0, 300.0)


func slot_point(slot: int) -> Vector2:
	if slot >= GameConfig.KITCHEN_SLOTS:
		return loo_spot(slot - GameConfig.KITCHEN_SLOTS)
	return kitchen_slot(slot)


func loo_spot(index: int) -> Vector2:
	var stall := clampi(index, 0, GameConfig.MAX_LOO_SLOTS - 1)
	return loo_origin(floori(stall / float(LOO_COLUMNS))) + LOO_SPOT + Vector2((stall % LOO_COLUMNS) * LOO_PITCH, 0.0)


func loo_origin(row: int = 0) -> Vector2:
	return toilets.position + Vector2(20.0, 84.0 + row * LOO_ROW_HEIGHT)


func phone_point() -> Vector2:
	return office_desk_point() + Vector2(64.0, 0.0)


func office_desk_point() -> Vector2:
	return player_office.position + Vector2(200.0, 210.0)


func office_gift_point() -> Vector2:
	return office_desk_point() + Vector2(-34.0, -6.0)


func office_letter_point() -> Vector2:
	return office_desk_point() + Vector2(4.0, -8.0)


func employee_of_month_rect() -> Rect2:
	return Rect2(player_office.position + Vector2(400.0, HEADER + 16.0), Vector2(110.0, 130.0))


func certificate_rect() -> Rect2:
	return Rect2(player_office.position + Vector2(528.0, HEADER + 16.0), Vector2(110.0, 80.0))


func trophy_shelf_rect() -> Rect2:
	return Rect2(player_office.position + Vector2(380.0, PLAYER_OFFICE_HEIGHT - 110.0), Vector2(258.0, 86.0))


func switchboard_point() -> Vector2:
	return phone_office.position + Vector2(100.0, 140.0)


func operator_point(_line: int = 0) -> Vector2:
	return phone_office.position + Vector2(300.0, 150.0)


func line_point(line: int) -> Vector2:
	return phone_point() if line == PhoneCall.PLAYER else operator_point(line)


func sick_board() -> Rect2:
	return staff_board("phone_clerks")


func mail_header() -> Rect2:
	return Rect2(mail_room.position, Vector2(mail_room.size.x, HEADER))


func mail_door() -> Vector2:
	return Vector2(mail_room.end.x - 12.0, mail_room.position.y + HEADER + 140.0)


func mail_street() -> Vector2:
	return Vector2(WIDTH + 60.0, mail_door().y)


func mail_storage_rect() -> Rect2:
	return Rect2(mail_room.position + Vector2(20.0, HEADER + 20.0), Vector2(MAIL_SHELF_WIDTH, MAIL_HEIGHT - HEADER - 72.0))


func mail_drop_point() -> Vector2:
	var rect := mail_storage_rect()
	return Vector2(rect.position.x + 30.0, rect.end.y - 20.0)


func mail_floor_point() -> Vector2:
	return mail_room.position + Vector2(MAIL_SIDE_X - 30.0, HEADER + 200.0)


func mail_desk_point() -> Vector2:
	return mail_room.position + Vector2(MAIL_SIDE_X, HEADER + 60.0)


func phone_header() -> Rect2:
	return Rect2(phone_office.position, Vector2(phone_office.size.x, HEADER))


func toilets_header() -> Rect2:
	return Rect2(toilets.position, Vector2(toilets.size.x, HEADER))


func kitchen_header() -> Rect2:
	return Rect2(kitchen.position, Vector2(kitchen.size.x, HEADER))


func kitchen_slot(index: int) -> Vector2:
	var slot := clampi(index, 0, GameConfig.KITCHEN_SLOTS - 1)
	return kitchen.position + KITCHEN_SPOTS[slot]


func kranz_point() -> Vector2:
	return kitchen.position + Vector2(520.0, 325.0)


func coffee_machine_point() -> Vector2:
	return kitchen.position + Vector2(530.0, 118.0)


func pad_point(slot: String) -> Vector2:
	var rect := room(slot)
	return Vector2(rect.get_center().x, rect.position.y + HEADER + AREA_HEIGHT - 50.0)


func player_start() -> Vector2:
	return hall.position + Vector2(hall.size.x * 0.5, 640.0)


func clamp_to_world(point: Vector2) -> Vector2:
	return point.clamp(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN))


func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= GameConfig.INTERACT_RADIUS


func room_at(point: Vector2) -> String:
	var slot := slot_at(point)
	if not slot.is_empty():
		return slot
	for room_id in GameConfig.SERVICE_ROOMS:
		if service_room(room_id).has_point(point):
			return room_id
	return ""


func slot_at(point: Vector2) -> String:
	for slot in rooms:
		if rooms[slot].has_point(point):
			return slot
	return ""
