class_name WorldLayout
extends RefCounted

const WIDTH := 1400.0
const MARGIN := 40.0
const SEAT_COLUMNS := 7
const SEAT_SPACING := Vector2(30.0, 26.0)
const MAX_VISIBLE_SEATS := 91
const QUEUE_PER_ROW := 12
const QUEUE_SPACING := 34.0
const QUEUE_ROW_GAP := 26.0
const TICKET_LINE_PER_ROW := 10
const TICKET_LINE_SPACING := Vector2(40.0, 34.0)
const TICKET_MACHINE_SPACING := 56.0
const GAP := 20.0
const ROW_HEIGHT := 460.0
const AREA_HEIGHT := 320.0
const UTILITY_Y := 414.0
const HALL_HEIGHT := 760.0
const KITCHEN_HEIGHT := 400.0
const KITCHEN_WIDTH := 900.0
const PHONE_HEIGHT := 260.0
const MAIL_HEIGHT := 400.0
const SERVICE_HEIGHT := 380.0
const OFFICE_WIDTH := 620.0
const SHREDDER_ROOM_WIDTH := 300.0
const MAIL_STATION_X := 420.0
const MAIL_STATION_WIDTH := 460.0
const OPERATOR_SPACING := 160.0
const HEADER := 56.0
const DESK_COLUMNS := 3
const DESK_ROWS := 3
const LOO_COLUMNS := 6
const LOO_PITCH := 50.0
const LOO_ROW_HEIGHT := 150.0
const LOO_SPOT := Vector2(25.0, 132.0)
const INTERN_COLUMNS := 3
const SLOT_SIZE := Vector2(88.0, 52.0)
const KITCHEN_SPOTS: Array[Vector2] = [
	Vector2(115, 195), Vector2(185, 205), Vector2(255, 195), Vector2(150, 248), Vector2(220, 248), Vector2(300, 225),
	Vector2(560, 190), Vector2(835, 190), Vector2(610, 240), Vector2(700, 250), Vector2(790, 240), Vector2(850, 240),
]
const SHAFT_X := 20.0
const OUTPUT_SHAFT_X := WIDTH - SHAFT_X
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
const SHREDDER_PREFIX := "shredder:"
const TUBE_PREFIX := "tube:"

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
var entrance := Vector2.ZERO
var waiting_area := Rect2()
var ticket_area := Rect2()
var rooms: Dictionary[String, Rect2] = {}
var areas: Dictionary[String, Rect2] = {}
var spots: Dictionary[String, Array] = {}
var _input_points: Dictionary = {}
var _output_points: Dictionary = {}
var _work_points: Dictionary = {}
var _tube_paths: Dictionary = {}
var _complaint_tube := PackedVector2Array()


static func get_default() -> WorldLayout:
	if _default == null:
		_default = WorldLayout.new()
		_default._build()
	return _default


func _build() -> void:
	var column_width := (WIDTH - MARGIN * 2.0 - GAP) / 2.0
	var full_width := WIDTH - MARGIN * 2.0
	var y := MARGIN
	for row: Array in ROWS:
		if row.size() == 1:
			rooms[row[0]] = Rect2(MARGIN, y, full_width, ROW_HEIGHT)
		else:
			for i in row.size():
				rooms[row[i]] = Rect2(MARGIN + i * (column_width + GAP), y, column_width, ROW_HEIGHT)
		y += ROW_HEIGHT + GAP
	kitchen = Rect2(MARGIN, y, KITCHEN_WIDTH, KITCHEN_HEIGHT)
	toilets = Rect2(kitchen.end.x + GAP, y, WIDTH - MARGIN - kitchen.end.x - GAP, KITCHEN_HEIGHT)
	y += KITCHEN_HEIGHT + GAP
	phone_office = Rect2(MARGIN, y, full_width, PHONE_HEIGHT)
	y += PHONE_HEIGHT + GAP
	mail_room = Rect2(MARGIN, y, full_width, MAIL_HEIGHT)
	y += MAIL_HEIGHT + GAP
	complaint_office = Rect2(MARGIN, y, OFFICE_WIDTH, SERVICE_HEIGHT)
	shredder_room = Rect2(complaint_office.end.x + GAP, y, SHREDDER_ROOM_WIDTH, SERVICE_HEIGHT)
	tech_room = Rect2(shredder_room.end.x + GAP, y, WIDTH - MARGIN - shredder_room.end.x - GAP, SERVICE_HEIGHT)
	y += SERVICE_HEIGHT + GAP
	hall = Rect2(MARGIN, y, full_width, HALL_HEIGHT)
	size = Vector2(WIDTH, hall.end.y + MARGIN)
	entrance = Vector2(WIDTH * 0.5, hall.end.y - 12.0)
	areas[GameConfig.RECEPTION] = _in_hall(Rect2(100, 130, 440, 240))
	areas[GameConfig.COUNTER] = _in_hall(Rect2(780, 130, 440, 240))
	waiting_area = _in_hall(Rect2(550, 130, 220, 360))
	ticket_area = _in_hall(Rect2(860, 400, 440, 320))
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
	_add_spot("waiting", Rect2(queue_point(QUEUE_PER_ROW - 1) + Vector2(-24.0, -24.0), Vector2(QUEUE_SPACING * QUEUE_PER_ROW + 14.0, QUEUE_ROW_GAP * ceili(GameConfig.MAX_LOBBY_SLOTS / float(QUEUE_PER_ROW)) + 22.0)))
	_add_spot("waiting", queue_sign_rect())
	_add_spot("seating", waiting_area)
	_add_spot("seating", seating_sign_rect())
	_add_spot("seating", standing_sign_rect())
	_add_spot("tickets", ticket_area)
	_add_spot("ticket_display", ticket_display_rect().grow(16.0))
	_add_spot("complaint_box", Rect2(complaint_box_point() + Vector2(-44.0, -48.0), Vector2(110.0, 96.0)))
	_add_spot("guards", guards_board())
	_add_spot("archive", archive_rect())
	_add_spot("training", training_board())
	_add_spot("complaint_desk", complaint_read_rect())
	_add_spot("interns", interns_board())
	_add_spot("interns", Rect2(intern_home(0) + Vector2(-44.0, -60.0), Vector2(78.0 * INTERN_COLUMNS + 10.0, 200.0)))
	_add_spot("shredder", Rect2(shredder_point() + Vector2(-70.0, -100.0), Vector2(140.0, 150.0)))
	_add_spot("collectors", collectors_board())
	_add_spot("runners", runners_board())
	_add_spot("server", server_rect())
	_add_spot("climate", climate_rect())
	_add_spot("tube_hub", Rect2(tube_hub_point() + Vector2(-70.0, -70.0), Vector2(140.0, 140.0)))
	_add_spot("coffee_machine", Rect2(coffee_machine_point() + Vector2(-70.0, -64.0), Vector2(140.0, 130.0)))
	_add_spot("kitchen", Rect2(kitchen.position + Vector2(560.0, 140.0), Vector2(320.0, 140.0)))
	_add_spot("coffee_interns", coffee_interns_board())
	_add_spot("works_council", works_council_board())
	_add_spot("toilets", Rect2(toilets.position + Vector2(10.0, HEADER), toilets.size - Vector2(20.0, HEADER + 10.0)))
	_add_spot("phone", Rect2(phone_office.position + Vector2(30.0, 70.0), Vector2(380.0, 170.0)))
	_add_spot("phone_clerks", sick_board())
	_add_spot("phone_clerks", Rect2(phone_office.position + Vector2(420.0, 70.0), Vector2(OPERATOR_SPACING * GameConfig.MAX_HR, 170.0)))
	_add_spot("mail_shelf", mail_storage_rect())
	_add_spot("mailbox", Rect2(mail_door() + Vector2(-6.0, -56.0), Vector2(96.0, 104.0)))
	for key in areas:
		_add_spot(STATION_PREFIX + key, areas[key])
	for dept_id in GameConfig.department_ids():
		_add_spot(DEPT_PREFIX + dept_id, header(dept_id))
		if not GameConfig.is_customs(dept_id):
			_add_spot(SHREDDER_PREFIX + dept_id, slot_rect(dept_shredder_point(dept_id)))
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		_add_spot(TUBE_PREFIX + room_id, slot_rect(tube_station_point(room_id)))


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
		GameConfig.ROOM_INSPECTION:
			return room("inspection")
	return room(room_id)


func room_header(room_id: String) -> Rect2:
	if room_id == GameConfig.ROOM_HALL:
		return hall_plate()
	var rect := service_room(room_id)
	return Rect2(rect.position, Vector2(rect.size.x, HEADER)) if rect.has_area() else Rect2()


func hall_plate() -> Rect2:
	return _in_hall(Rect2(800, 8, 340, 30))


func input_point(key: String) -> Vector2:
	if not _input_points.has(key):
		_input_points[key] = _compute_input_point(key)
	return _input_points[key]


func _compute_input_point(key: String) -> Vector2:
	var rect := area(key)
	if key == GameConfig.RECEPTION:
		return queue_point(0)
	if GameConfig.station_kind_of(key) == "dock":
		return Vector2(rect.position.x + 30.0, rect.get_center().y)
	return Vector2(rect.position.x + 40.0, rect.end.y - 40.0)


func output_point(key: String) -> Vector2:
	if not _output_points.has(key):
		var rect := area(key)
		_output_points[key] = Vector2(rect.end.x - 40.0, rect.end.y - 40.0)
	return _output_points[key]


func reject_point(key: String) -> Vector2:
	return output_point(key) + Vector2(-64.0, 0.0)


func review_key(dept_id: String) -> String:
	var keys := GameConfig.department_station_keys(dept_id)
	for key in keys:
		if GameConfig.station_kind_of(key) == "review":
			return key
	return keys[0] if not keys.is_empty() else ""


func dept_shredder_point(dept_id: String) -> Vector2:
	var rect := room(dept_id)
	var key := review_key(dept_id)
	var x := reject_point(key).x if not key.is_empty() else rect.position.x + 120.0
	return Vector2(x, rect.position.y + UTILITY_Y)


func tube_station_point(room_id: String) -> Vector2:
	match room_id:
		GameConfig.ROOM_HALL:
			return hall.position + Vector2(1265.0, 300.0)
		GameConfig.ROOM_MAIL:
			return mail_room.position + Vector2(1220.0, 300.0)
	var rect := service_room(room_id)
	return Vector2(rect.end.x - 110.0, rect.position.y + UTILITY_Y)


func collector_home() -> Vector2:
	return shredder_point() + Vector2(80.0, 70.0)


func door_in() -> Vector2:
	return entrance + Vector2(-30.0, 0.0)


func door_out() -> Vector2:
	return entrance + Vector2(30.0, 0.0)


func office_door() -> Vector2:
	return Vector2(complaint_office.position.x + 300.0, complaint_office.end.y)


func shredder_door() -> Vector2:
	return Vector2(shredder_room.get_center().x, shredder_room.end.y)


func tech_door() -> Vector2:
	return Vector2(tech_room.get_center().x, tech_room.end.y)


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


func work_point(key: String) -> Vector2:
	if not _work_points.has(key):
		var rect := area(key)
		_work_points[key] = Vector2(rect.get_center().x, rect.end.y - 44.0)
	return _work_points[key]


func desk_position(key: String, index: int) -> Vector2:
	var rect := area(key)
	var grid := Rect2(rect.position + Vector2(24, 28), Vector2(rect.size.x - 48, rect.size.y - 120))
	var cell := Vector2(grid.size.x / DESK_COLUMNS, grid.size.y / DESK_ROWS)
	var col := index % DESK_COLUMNS
	var row := floori(index / float(DESK_COLUMNS))
	return grid.position + Vector2(cell.x * (col + 0.5), cell.y * (row + 0.5))


func queue_point(index: int) -> Vector2:
	var row := floori(index / float(QUEUE_PER_ROW))
	var col := index % QUEUE_PER_ROW
	var offset := col if row % 2 == 0 else QUEUE_PER_ROW - 1 - col
	return hall.position + Vector2(510.0 - offset * QUEUE_SPACING, 396.0 + row * QUEUE_ROW_GAP)


func waiting_seat(index: int) -> Vector2:
	var col := index % SEAT_COLUMNS
	var row := floori(index / float(SEAT_COLUMNS))
	return waiting_area.position + Vector2(22.0 + col * SEAT_SPACING.x, 22.0 + row * SEAT_SPACING.y)


func ticket_machine_point(index: int = 0) -> Vector2:
	var slot := clampi(index, 0, GameConfig.MAX_TICKET_MACHINES - 1)
	return hall.position + Vector2(1270.0 - slot * TICKET_MACHINE_SPACING, 470.0)


func ticket_line_point(index: int) -> Vector2:
	var slot := clampi(index, 0, GameConfig.MAX_TICKET_LINE_SLOTS - 1)
	var col := slot % TICKET_LINE_PER_ROW
	var row := floori(slot / float(TICKET_LINE_PER_ROW))
	return hall.position + Vector2(1270.0 - col * TICKET_LINE_SPACING.x, 540.0 + row * TICKET_LINE_SPACING.y)


func ticket_display_rect() -> Rect2:
	return _in_hall(Rect2(880.0, 410.0, 140.0, 28.0))


func ticket_display_point() -> Vector2:
	return ticket_display_rect().get_center() + Vector2(0.0, 46.0)


func queue_sign_rect() -> Rect2:
	return Rect2(waiting_area.position + Vector2(10, waiting_area.size.y + 6), Vector2(200, 24))


func seating_sign_rect() -> Rect2:
	return Rect2(waiting_area.position + Vector2(10, waiting_area.size.y + 34), Vector2(200, 24))


func standing_sign_rect() -> Rect2:
	return Rect2(waiting_area.position + Vector2(10, waiting_area.size.y + 62), Vector2(200, 24))


func ruckus_point(desk: int) -> Vector2:
	return desk_position(GameConfig.RECEPTION, desk) + Vector2(0.0, 46.0)


func archive_rect() -> Rect2:
	return _in_hall(Rect2(14, 116, 72, 116))


func hours_board() -> Rect2:
	return _in_hall(Rect2(6, 246, 88, 96))


func training_board() -> Rect2:
	return _in_hall(Rect2(6, 354, 88, 110))


func guards_board() -> Rect2:
	return _in_hall(Rect2(650, 18, 140, 84))


func complaint_desk_point() -> Vector2:
	return complaint_office.position + Vector2(150.0, 200.0)


func complaint_box_point() -> Vector2:
	return hall.position + Vector2(370.0, 56.0)


func complaint_clerk_point() -> Vector2:
	return complaint_desk_point() + Vector2(0.0, -26.0)


func complaint_read_rect() -> Rect2:
	return Rect2(complaint_desk_point() + Vector2(-110.0, -86.0), Vector2(220.0, 130.0))


func closed_sign_rect() -> Rect2:
	return _in_hall(Rect2(726.0, 680.0, 120.0, 54.0))


func shredder_point() -> Vector2:
	return shredder_room.position + Vector2(150.0, 230.0)


func shredder_points(dept_ids: Array[String]) -> Array[Vector2]:
	var points: Array[Vector2] = [shredder_point()]
	for dept_id in dept_ids:
		points.append(dept_shredder_point(dept_id))
	return points


func nearest_shredder(from: Vector2, dept_ids: Array[String]) -> Vector2:
	var best := shredder_point()
	for point in shredder_points(dept_ids):
		if from.distance_squared_to(point) < from.distance_squared_to(best):
			best = point
	return best


func complaint_tube_path() -> PackedVector2Array:
	if _complaint_tube.is_empty():
		var box := complaint_box_point()
		var shredder := shredder_point()
		var lane := hall.position.y - GAP * 0.5
		_complaint_tube = PackedVector2Array([box + Vector2(0.0, -40.0), Vector2(box.x, lane), Vector2(shredder.x, lane), shredder + Vector2(0.0, 56.0)])
	return _complaint_tube


func interns_board() -> Rect2:
	return Rect2(complaint_office.position + Vector2(380.0, 66.0), Vector2(220.0, 64.0))


func intern_home(slot: int = 0) -> Vector2:
	var index := clampi(slot, 0, GameConfig.MAX_HELPERS)
	return complaint_office.position + Vector2(380.0 + (index % INTERN_COLUMNS) * 78.0, 200.0 + floori(index / float(INTERN_COLUMNS)) * 96.0)


func intern_cry_point(slot: int = 0) -> Vector2:
	return toilets.position + Vector2(352.0, 96.0 + slot * 26.0)


func intern_shred_point(slot: int = 0) -> Vector2:
	return shredder_point() + Vector2(-46.0 - slot * 18.0, 12.0 + (slot % 2) * 10.0)


func visitor_spot(slot: int) -> Vector2:
	var index := clampi(slot, 0, GameConfig.VISITOR_SLOTS - 1)
	return complaint_desk_point() + Vector2(-60.0 + index * 60.0, 74.0 + (index % 2) * 12.0)


func vent_spot(slot: int) -> Vector2:
	var index := clampi(slot, 0, GameConfig.VISITOR_SLOTS - 1)
	return intern_home(index) + Vector2(-4.0, 44.0 - (index % 2) * 10.0)


func complaint_drop_spot() -> Vector2:
	return complaint_box_point() + Vector2(34.0, 20.0)


func guard_post(index: int) -> Vector2:
	return hall.position + Vector2(450.0 + index * 36.0, 60.0 + (index % 2) * 16.0)


func guard_stop_spot(index: int) -> Vector2:
	return guard_post(index) + Vector2(-16.0, 30.0)


func collectors_board() -> Rect2:
	return Rect2(shredder_room.position + Vector2(16.0, 66.0), Vector2(268.0, 64.0))


func runners_board() -> Rect2:
	return Rect2(tech_room.position + Vector2(16.0, 66.0), Vector2(210.0, 64.0))


func server_rect() -> Rect2:
	return Rect2(tech_room.position + Vector2(250.0, 66.0), Vector2(94.0, 150.0))


func climate_rect() -> Rect2:
	return Rect2(tech_room.position + Vector2(236.0, 236.0), Vector2(108.0, 64.0))


func tube_hub_point() -> Vector2:
	return tech_room.position + Vector2(110.0, 240.0)


func runner_home() -> Vector2:
	return tech_room.position + Vector2(180.0, 336.0)


func dispute_point(dept_id: String) -> Vector2:
	var rect := room(dept_id)
	return rect.position + Vector2(rect.size.x - 86.0, HEADER + 44.0)


func coffee_home() -> Vector2:
	return coffee_machine_point() + Vector2(70.0, 40.0)


func coffee_brew_point() -> Vector2:
	return coffee_machine_point() + Vector2(0.0, 36.0)


func coffee_interns_board() -> Rect2:
	return Rect2(kitchen.position + Vector2(24.0, 300.0), Vector2(300.0, 84.0))


func works_council_board() -> Rect2:
	return Rect2(kitchen.position + Vector2(344.0, 300.0), Vector2(240.0, 84.0))


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
	return phone_office.position + Vector2(300.0, 170.0)


func switchboard_point() -> Vector2:
	return phone_office.position + Vector2(110.0, 170.0)


func operator_point(line: int) -> Vector2:
	return phone_office.position + Vector2(500.0 + clampi(line, 0, GameConfig.MAX_HR - 1) * OPERATOR_SPACING, 170.0)


func line_point(line: int) -> Vector2:
	return phone_point() if line == PhoneCall.PLAYER else operator_point(line)


func sick_board() -> Rect2:
	return Rect2(phone_office.position + Vector2(phone_office.size.x - 260.0, HEADER + 20.0), Vector2(236.0, 160.0))


func mail_header() -> Rect2:
	return Rect2(mail_room.position, Vector2(mail_room.size.x, HEADER))


func mail_door() -> Vector2:
	return Vector2(mail_room.position.x + 12.0, mail_room.position.y + HEADER + 250.0)


func mail_street() -> Vector2:
	return Vector2(-60.0, mail_door().y)


func mail_storage_rect() -> Rect2:
	return Rect2(mail_room.position + Vector2(110.0, HEADER + 24.0), Vector2(280.0, MAIL_HEIGHT - HEADER - 72.0))


func mail_drop_point() -> Vector2:
	var rect := mail_storage_rect()
	return Vector2(rect.position.x + 30.0, rect.end.y - 20.0)


func mail_floor_point() -> Vector2:
	return mail_room.position + Vector2(70.0, HEADER + 140.0)


func mail_desk_point() -> Vector2:
	return mail_room.position + Vector2(MAIL_STATION_X + MAIL_STATION_WIDTH + 80.0, HEADER + 90.0)


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
	return kitchen.position + Vector2(700.0, 205.0)


func coffee_machine_point() -> Vector2:
	return kitchen.position + Vector2(190.0, 128.0)


func pad_point(slot: String) -> Vector2:
	var rect := room(slot)
	return Vector2(rect.get_center().x, rect.position.y + HEADER + AREA_HEIGHT - 50.0)


func player_start() -> Vector2:
	return hall.position + Vector2(660.0, 620.0)


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
