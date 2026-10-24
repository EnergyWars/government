class_name WorldLayout
extends RefCounted

const WIDTH := 1400.0
const MARGIN := 40.0
const SEAT_COLUMNS := 7
const SEAT_SPACING := Vector2(30.0, 26.0)
const QUEUE_PER_ROW := 14
const QUEUE_ROW_GAP := 30.0
const GAP := 20.0
const ROW_HEIGHT := 400.0
const HALL_HEIGHT := 460.0
const KITCHEN_HEIGHT := 280.0
const KITCHEN_WIDTH := 900.0
const PHONE_HEIGHT := 260.0
const OPERATOR_SPACING := 160.0
const HEADER := 56.0
const DESK_COLUMNS := 3
const LOO_SPOTS: Array[Vector2] = [Vector2(48, 232), Vector2(112, 232), Vector2(176, 232), Vector2(240, 232)]
const KITCHEN_SPOTS: Array[Vector2] = [
	Vector2(115, 195), Vector2(185, 205), Vector2(255, 195), Vector2(150, 248), Vector2(220, 248), Vector2(300, 225),
	Vector2(560, 190), Vector2(835, 190), Vector2(610, 240), Vector2(700, 250), Vector2(790, 240), Vector2(850, 240),
]
const DESK_ROWS := 3
const SHAFT_X := 20.0
const ROWS: Array = [
	["customs"],
	["housing", "social_benefits"],
	["vehicle_registration", "building_permits"],
	["business_licences", "inspection"],
	["general_services", "tax_services"],
]

static var _default: WorldLayout

var size := Vector2.ZERO
var hall := Rect2()
var kitchen := Rect2()
var toilets := Rect2()
var phone_office := Rect2()
var entrance := Vector2.ZERO
var waiting_area := Rect2()
var rooms: Dictionary[String, Rect2] = {}
var areas: Dictionary[String, Rect2] = {}
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
	var y := MARGIN
	for row: Array in ROWS:
		if row.size() == 1:
			rooms[row[0]] = Rect2(MARGIN, y, WIDTH - MARGIN * 2.0, ROW_HEIGHT)
		else:
			for i in row.size():
				rooms[row[i]] = Rect2(MARGIN + i * (column_width + GAP), y, column_width, ROW_HEIGHT)
		y += ROW_HEIGHT + GAP
	kitchen = Rect2(MARGIN, y, KITCHEN_WIDTH, KITCHEN_HEIGHT)
	toilets = Rect2(kitchen.end.x + GAP, y, WIDTH - MARGIN - kitchen.end.x - GAP, KITCHEN_HEIGHT)
	y += KITCHEN_HEIGHT + GAP
	phone_office = Rect2(MARGIN, y, WIDTH - MARGIN * 2.0, PHONE_HEIGHT)
	y += PHONE_HEIGHT + GAP
	hall = Rect2(MARGIN, y, WIDTH - MARGIN * 2.0, HALL_HEIGHT)
	size = Vector2(WIDTH, hall.end.y + MARGIN)
	entrance = Vector2(WIDTH * 0.5, hall.end.y - 12.0)
	areas[GameConfig.RECEPTION] = Rect2(hall.position + Vector2(100, 40), Vector2(440, 240))
	areas[GameConfig.COUNTER] = Rect2(hall.position + Vector2(hall.size.x - 540, 40), Vector2(440, 240))
	waiting_area = Rect2(hall.position + Vector2(hall.size.x * 0.5 - 110, 40), Vector2(220, 260))
	areas[GameConfig.INSPECTION] = _local("inspection", Rect2(24, HEADER, 602, ROW_HEIGHT - HEADER - 24))
	for dept_id in GameConfig.department_ids():
		var keys := GameConfig.department_station_keys(dept_id)
		if keys.size() == 2:
			areas[keys[0]] = _local(dept_id, Rect2(24, HEADER, 340, ROW_HEIGHT - HEADER - 24))
			areas[keys[1]] = _local(dept_id, Rect2(388, HEADER, 238, ROW_HEIGHT - HEADER - 24))
		else:
			var width := (rooms[dept_id].size.x - 48.0 - GAP * (keys.size() - 1)) / keys.size()
			for i in keys.size():
				areas[keys[i]] = _local(dept_id, Rect2(24 + i * (width + GAP), HEADER, width, ROW_HEIGHT - HEADER - 24))


func _local(slot: String, rect: Rect2) -> Rect2:
	return Rect2(rooms[slot].position + rect.position, rect.size)


func area(key: String) -> Rect2:
	return areas.get(key, Rect2())


func room(slot: String) -> Rect2:
	return rooms.get(slot, Rect2())


func header(slot: String) -> Rect2:
	var rect := room(slot)
	return Rect2(rect.position, Vector2(rect.size.x, HEADER))


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


func collector_home() -> Vector2:
	return shredder_point() + Vector2(-90.0, 10.0)


func door_in() -> Vector2:
	return entrance + Vector2(-30.0, 0.0)


func door_out() -> Vector2:
	return entrance + Vector2(30.0, 0.0)


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
		var gap_from := tube_gap(from_key)
		var gap_to := tube_gap(to_key)
		path.append(Vector2(start.x, gap_from))
		path.append(Vector2(SHAFT_X, gap_from))
		path.append(Vector2(SHAFT_X, gap_to))
		path.append(Vector2(finish.x, gap_to))
	path.append(finish)
	_tube_paths[cache_key] = path
	return path


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
	var rect := areas[GameConfig.RECEPTION]
	var head := Vector2(rect.get_center().x, rect.end.y + 30.0)
	var per_row := QUEUE_PER_ROW
	var row := floori(index / float(per_row))
	var col := index % per_row
	var offset := col if row % 2 == 0 else per_row - 1 - col
	return Vector2(head.x - offset * 34.0 + 180.0, head.y + row * QUEUE_ROW_GAP)


func waiting_seat(index: int) -> Vector2:
	var col := index % SEAT_COLUMNS
	var row := floori(index / float(SEAT_COLUMNS))
	return waiting_area.position + Vector2(22.0 + col * SEAT_SPACING.x, 22.0 + row * SEAT_SPACING.y)


func queue_sign_rect() -> Rect2:
	return Rect2(waiting_area.position + Vector2(10, waiting_area.size.y + 6), Vector2(200, 24))


func seating_sign_rect() -> Rect2:
	return Rect2(waiting_area.position + Vector2(10, waiting_area.size.y + 34), Vector2(200, 24))


func complaint_desk_point() -> Vector2:
	return hall.position + Vector2(900.0, 392.0)


func complaint_read_rect() -> Rect2:
	var desk := complaint_desk_point()
	return Rect2(desk + Vector2(-120.0, -80.0), Vector2(240.0, 120.0))


func shredder_point() -> Vector2:
	return hall.position + Vector2(1195.0, 396.0)


func complaint_tube_path() -> PackedVector2Array:
	if _complaint_tube.is_empty():
		var desk := complaint_desk_point()
		var shredder := shredder_point()
		_complaint_tube = PackedVector2Array([desk + Vector2(130.0, -30.0), desk + Vector2(130.0, -100.0), Vector2(shredder.x, desk.y - 100.0), shredder + Vector2(0.0, -56.0)])
	return _complaint_tube


func intern_home(slot: int = 0) -> Vector2:
	return complaint_desk_point() + Vector2(78.0 + slot * 40.0, -4.0 + (slot % 2) * 14.0)


func intern_cry_point(slot: int = 0) -> Vector2:
	return toilets.position + Vector2(352.0, 96.0 + slot * 26.0)


func intern_shred_point(slot: int = 0) -> Vector2:
	return shredder_point() + Vector2(-56.0 - slot * 24.0, 10.0)


func visitor_spot(slot: int) -> Vector2:
	var index := clampi(slot, 0, GameConfig.VISITOR_SLOTS - 1)
	return complaint_desk_point() + Vector2(-70.0 - index * 44.0, 30.0 + (index % 2) * 18.0)


func guard_post(index: int) -> Vector2:
	return complaint_desk_point() + Vector2(-212.0 - index * 40.0, 20.0 + (index % 2) * 16.0)


func guard_stop_spot(index: int) -> Vector2:
	return guard_post(index) + Vector2(-30.0, 4.0)


func dispute_point(dept_id: String) -> Vector2:
	var rect := room(dept_id)
	return rect.position + Vector2(rect.size.x - 86.0, HEADER + 44.0)


func coffee_home() -> Vector2:
	return coffee_machine_point() + Vector2(70.0, 40.0)


func coffee_brew_point() -> Vector2:
	return coffee_machine_point() + Vector2(0.0, 36.0)


func slot_point(slot: int) -> Vector2:
	if slot >= GameConfig.KITCHEN_SLOTS:
		return toilets.position + LOO_SPOTS[clampi(slot - GameConfig.KITCHEN_SLOTS, 0, GameConfig.LOO_SLOTS - 1)]
	return kitchen_slot(slot)


func loo_origin() -> Vector2:
	return toilets.position + Vector2(20.0, 100.0)


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
	return Vector2(rect.get_center().x, rect.end.y - 70.0)


func player_start() -> Vector2:
	return hall.get_center() + Vector2(0, 100)


func runner_home() -> Vector2:
	return hall.get_center() + Vector2(0, 40)


func clamp_to_world(point: Vector2) -> Vector2:
	return point.clamp(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN))


func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= GameConfig.INTERACT_RADIUS


func slot_at(point: Vector2) -> String:
	for slot in rooms:
		if rooms[slot].has_point(point):
			return slot
	return ""
