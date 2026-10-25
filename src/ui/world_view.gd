class_name WorldView
extends Node2D

signal open_spot(spot: String)

const VISIBLE_WIDTH := 720.0
const TAP_SLOP := 14.0
const TAP_TIME := 300
const CAMERA_FOLLOW := 6.0
const FOCUS_TIME := 3.0
const POP_STAGGER := 0.07
const WALK_TIME := 2.2
const FLOAT_TIME := 1.4
const GUIDANCE_INTERVAL := 0.25
const ROOM_RADIUS := 20
const AREA_RADIUS := 14
const MAX_FLAVOR_FLOATERS := 4
const SHRED_ANIMATION := 0.8
const LAYERS_PER_FRAME := 1
const SMOOTH_WALKERS := 12
const RETURN_SPEED := 200.0
const MAX_WALKERS := 80
const STAGE_TICKET := "ticket"
const STAGE_WAITING := "waiting"
const STAGE_CALLED := "called"
const STAGE_DESK := "desk"
const STAGE_COUNTER := "counter"
const STAGE_SEATED := "seated"
const COUNTER_STEP := Vector2(0, 46)
const DISPUTE_OFFSET := 26.0
const LIFT_MAX_WIDTH := 500.0
const CROWD_INTERVAL := 0.033
const SHELL_LAYER := "_shell"
const HALL_LAYER := "_hall"
const HALL_STATIC_LAYER := "_hall_static"
const MIN_LAYER_INTERVAL := 0.12
const KITCHEN_LAYER := "_kitchen"
const TOILETS_LAYER := "_toilets"
const PHONE_LAYER := "_phone"
const MAIL_LAYER := "_mail"
const COMPLAINT_LAYER := "_complaint_office"
const SHREDDER_LAYER := "_shredder_room"
const TECH_LAYER := "_tech_room"
const PLAYER_TAP_RADIUS := 36.0
const COFFEE_TIERS := 4
const KITCHEN_PLANTS := 4
const CLERK_LOOKS := 6
const TUBES_LAYER := "_tubes"
const TUBE_SPEED := GameConfig.TUBE_SPEED
const COMPLAINT_TUBE_SPEED := 110.0
const TUBE_WINDOW_SPACING := 170.0
const TUBE_WINDOW_LENGTH := 34.0
const MAX_CAPSULES := 40
const MAIL_FLOOR_VISIBLE := 12
const CULL_MARGIN := 320.0
const RING_POINTS := 40
const RING_START := -PI * 0.5

var game: Game
var layout := WorldLayout.get_default()
var joystick: JoystickView
var top_inset := 0.0
var bottom_inset := 0.0
var camera := Vector2.ZERO
var world_scale := 1.0
var _focus_point := Vector2.ZERO
var _focus_left := 0.0
var _highlight_dept := ""
var _highlight_spot := ""
var _pressing := false
var _press_position := Vector2.ZERO
var _press_time := 0
var _stick_used := false
var _walkers: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _guidance := {}
var _guidance_timer := 0.0
var _time := 0.0
var _seat_born: Array[float] = []
var _slot_born: Array[float] = []
var _furnishing_ready := false
var _styles: Dictionary = {}
var _flavor_count := 0
var _shred_time := 0.0
var _returning: Dictionary = {}
var _leaving: Dictionary = {}
var _shredding: Dictionary = {}
var _dispute_crews: Dictionary = {}
var _crew_desks: Dictionary = {}
var _citizens := CitizenTracker.new()
var _citizen_clock := 0.0
var _capsules: Array[Dictionary] = []
var _tube_signature := -1
var _canvas: CanvasItem
var _actors: Node2D
var _crowd: Node2D
var _crowd_timer := 0.0
var _layers: Array[Dictionary] = []
var _layer_cursor := 0
var _rings: Dictionary = {}
var _ring_layer := ""
var _shell_stage := -1
var _font: Font = AppTheme.FONT_REGULAR
var _bold: Font = AppTheme.FONT_SEMIBOLD
var _icons: Font = AppTheme.FONT_ICONS


func _init() -> void:
	_canvas = self


func _ready() -> void:
	_add_layer(SHELL_LAYER, Rect2(Vector2(-2000, -2000), layout.size + Vector2(4000, 4000)))
	_add_layer(KITCHEN_LAYER, layout.kitchen.grow(24))
	_add_layer(TOILETS_LAYER, layout.toilets.grow(24))
	_add_layer(PHONE_LAYER, layout.phone_office.grow(24))
	_add_layer(MAIL_LAYER, layout.mail_room.grow(24))
	_add_layer(COMPLAINT_LAYER, layout.complaint_office.grow(24))
	_add_layer(SHREDDER_LAYER, layout.shredder_room.grow(24))
	_add_layer(TECH_LAYER, layout.tech_room.grow(24))
	_add_layer(HALL_STATIC_LAYER, layout.hall.grow(24), true)
	_add_layer(HALL_LAYER, layout.hall.grow(24))
	for slot in layout.rooms:
		_add_layer(slot, layout.room(slot).grow(24))
	_add_layer(TUBES_LAYER, Rect2(Vector2(-100, -100), layout.size + Vector2(200, 200)), true)
	_crowd = Node2D.new()
	_crowd.draw.connect(_draw_crowd)
	add_child(_crowd)
	_actors = Node2D.new()
	_actors.draw.connect(_draw_actors)
	add_child(_actors)


func setup(p_game: Game, p_joystick: JoystickView) -> void:
	game = p_game
	joystick = p_joystick
	camera = game.state.player.position
	var sim := game.simulation
	sim.case_completed.connect(_on_case_completed)
	sim.citizen_left.connect(_on_citizen_left)
	sim.contraband_found.connect(func(_dept_id: String) -> void: _float(layout.area("customs/signature").get_center(), tr("FLOAT_SEIZED"), AppTheme.accent("error")))
	sim.smuggling_missed.connect(func(_dept_id: String) -> void: _float(layout.area("customs/clearance").get_center(), tr("FLOAT_SMUGGLED"), AppTheme.accent("error")))
	sim.employee_dozed.connect(_on_employee_dozed)
	sim.mail_delivered.connect(_on_mail_delivered)
	sim.mail_picked_up.connect(func() -> void: _redraw_at(layout.mail_floor_point()))
	sim.mail_answered.connect(_on_mail_answered)
	sim.applications_bundled.connect(_on_applications_bundled)
	sim.form_missing.connect(_on_form_missing)
	sim.onboarding_completed.connect(_on_onboarding_completed)
	game.boosts.used.connect(_on_boost_used)
	sim.employee_woke.connect(_on_employee_woke)
	sim.complaint_filed.connect(_on_complaint_filed)
	sim.complaint_fended.connect(_on_complaint_fended)
	sim.kranz_called.connect(_on_kranz_called)
	sim.sick_called.connect(_on_sick_called)
	sim.sick_call_answered.connect(_on_sick_call_answered)
	sim.sick_call_missed.connect(_on_sick_call_missed)
	sim.bonus_left.connect(_on_bonus_left)
	sim.complaint_shredded.connect(_on_complaint_shredded)
	sim.case_rejected.connect(_on_case_rejected)
	sim.case_shredded.connect(_on_case_shredded)
	sim.dept_shredded.connect(_on_dept_shredded)
	sim.complaint_piped.connect(_on_complaint_piped)
	sim.review_posted.connect(_on_review_posted)
	sim.review_removed.connect(_on_review_removed)
	sim.case_piped.connect(_on_case_piped)
	sim.intern_broke_down.connect(_on_intern_broke_down)
	sim.intern_recovered.connect(_on_intern_recovered)
	sim.coffee_served.connect(_on_coffee_served)
	sim.dispute_started.connect(_on_dispute_started)
	sim.dispute_ended.connect(_on_dispute_ended)
	sim.ticket_called.connect(_on_ticket_called)
	sim.ruckus_started.connect(_on_ruckus_started)
	sim.ruckus_calmed.connect(_on_ruckus_calmed)
	sim.department_unlocked.connect(func(dept_id: String) -> void: focus(dept_id))


func focus(slot: String) -> void:
	_focus_point = layout.room(slot).get_center()
	_focus_left = FOCUS_TIME
	_highlight_dept = slot
	_highlight_spot = ""


func focus_spot(spot: String) -> void:
	if spot == GameConfig.ROOM_PLAYER:
		_focus_point = game.state.player.position
	elif layout.spot_rects(spot).is_empty():
		return
	else:
		_focus_point = layout.spot_center(spot)
	_focus_left = FOCUS_TIME
	_highlight_dept = ""
	_highlight_spot = spot


func highlighted_spot() -> String:
	return _highlight_spot


func focus_point() -> Vector2:
	return _focus_point


func visible_size() -> Vector2:
	var viewport := get_viewport_rect().size
	return Vector2(viewport.x, maxf(1.0, viewport.y - top_inset - bottom_inset)) / world_scale


func view_rect() -> Rect2:
	var size := visible_size()
	return Rect2(camera - size * 0.5, size)


func _process(delta: float) -> void:
	_time += delta
	world_scale = maxf(0.1, get_viewport_rect().size.x / VISIBLE_WIDTH)
	_read_keyboard()
	var target := game.state.player.position
	if _focus_left > 0.0:
		_focus_left -= delta
		target = _focus_point
		if _focus_left <= 0.0:
			_highlight_dept = ""
			_highlight_spot = ""
	camera = camera.lerp(target, 1.0 - exp(-CAMERA_FOLLOW * delta))
	camera = _clamp_camera(camera)
	var viewport := get_viewport_rect().size
	var screen_center := Vector2(viewport.x * 0.5, top_inset + (viewport.y - top_inset - bottom_inset) * 0.5)
	scale = Vector2.ONE * world_scale
	position = (screen_center - camera * world_scale).round()
	_guidance_timer -= delta
	if _guidance_timer <= 0.0:
		_guidance_timer = GUIDANCE_INTERVAL
		_guidance = Guidance.next_task(game.state)
	_advance_effects(delta)
	_refresh_layers()
	_crowd_timer += delta
	_citizen_clock += delta
	if _crowd != null and _crowd_timer >= (0.0 if _walkers.size() + _capsules.size() <= SMOOTH_WALKERS else CROWD_INTERVAL):
		_crowd_timer = 0.0
		_crowd.queue_redraw()
	if _actors != null:
		_actors.queue_redraw()


func _clamp_camera(point: Vector2) -> Vector2:
	var half := visible_size() * 0.5
	var low := half
	var high := layout.size - half
	return Vector2(
		layout.size.x * 0.5 if low.x > high.x else clampf(point.x, low.x, high.x),
		layout.size.y * 0.5 if low.y > high.y else clampf(point.y, low.y, high.y),
	)


func _read_keyboard() -> void:
	if _pressing:
		return
	var direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)),
	)
	game.actions.set_player_input(direction.normalized())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			if button.position.y < top_inset or button.position.y > get_viewport_rect().size.y - bottom_inset:
				return
			_pressing = true
			_stick_used = false
			_press_position = button.position
			_press_time = Time.get_ticks_msec()
		elif _pressing:
			_pressing = false
			joystick.hide_stick()
			game.actions.set_player_input(Vector2.ZERO)
			if not _stick_used and Time.get_ticks_msec() - _press_time < TAP_TIME:
				_handle_tap((button.position - position) / world_scale)
	elif event is InputEventMouseMotion and _pressing:
		var motion := event as InputEventMouseMotion
		var offset := motion.position - _press_position
		if not _stick_used and offset.length() > TAP_SLOP:
			_stick_used = true
		if _stick_used:
			var clamped := offset.limit_length(JoystickView.BASE_RADIUS)
			joystick.show_at(_press_position, _press_position + clamped)
			game.actions.set_player_input(clamped / JoystickView.BASE_RADIUS)


func _handle_tap(point: Vector2) -> void:
	var spot := tap_spot(point)
	if not spot.is_empty():
		open_spot.emit(spot)


func tap_spot(point: Vector2) -> String:
	var state := game.state
	if point.distance_to(state.player.position) <= PLAYER_TAP_RADIUS:
		return GameConfig.ROOM_PLAYER
	var spot := layout.spot_at(point)
	if spot.is_empty():
		var room_id := layout.room_at(point)
		if room_id.is_empty():
			return ""
		spot = UpgradeCatalog.room_spot(room_id)
	return UpgradeCatalog.resolve_spot(state, spot)


func _advance_effects(delta: float) -> void:
	_shred_time = maxf(0.0, _shred_time - delta)
	_count_down(_returning, delta)
	_count_down(_leaving, delta)
	_count_down(_shredding, delta)
	for list: Array[Dictionary] in [_walkers, _floaters, _capsules]:
		var index := list.size() - 1
		while index >= 0:
			list[index].t += delta
			if list[index].t >= list[index].duration:
				list.remove_at(index)
			index -= 1


func _count_down(walks: Dictionary, delta: float) -> void:
	for walk_key in walks.keys():
		var walk: Dictionary = walks[walk_key]
		walk.left = float(walk.left) - delta
		if float(walk.left) <= 0.0:
			walks.erase(walk_key)
			_redraw_at(walk.point)


func _redraw_at(point: Vector2) -> void:
	for layer in _layers:
		if layer.id != SHELL_LAYER and layer.id != HALL_STATIC_LAYER and (layer.rect as Rect2).has_point(point):
			layer.last = _time
			layer.drawn = true
			(layer.node as Node2D).queue_redraw()


static func desk_key(key: String, desk: int) -> String:
	return "%s#%d" % [key, desk]


func _staff_walk(station: Station, desk: int, from: Vector2, to: Vector2) -> float:
	var duration := clampf(from.distance_to(to) / RETURN_SPEED, 0.4, 8.0)
	var expert := station.is_specialist_desk(desk)
	_walkers.append({"from": from, "to": to, "kind": "staff", "dept": "", "t": 0.0, "duration": duration, "color": AppTheme.SPECIALIST_COAT if expert else AppTheme.STAFF_COLOR, "tie": AppTheme.SPECIALIST if expert else AppTheme.TIE, "expert": expert, "look": staff_look(station, desk)})
	_redraw_at(from)
	_redraw_at(to)
	return duration


static func staff_look(station: Station, desk: int) -> int:
	return desk + 3 if station.is_specialist_desk(desk) else desk


func _desk_seat(key: String, desk: int) -> Vector2:
	return layout.desk_position(key, desk) + Vector2(0, -24)


func _float(pos: Vector2, text: String, color: Color, size: int = 24) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "size": size, "t": 0.0, "duration": FLOAT_TIME})


func _float_flavor(pos: Vector2, flawed: bool, color: Color) -> void:
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(pos, Flavor.flawed(_flavor_count) if flawed else Flavor.done(_flavor_count), color, AppTheme.SIZE_TITLE_SMALL)


func _walker(from: Vector2, to: Vector2, kind: String, dept_id: String, duration: float = WALK_TIME) -> void:
	if _walkers.size() > MAX_WALKERS:
		return
	_walkers.append({"from": from, "to": to, "kind": kind, "dept": dept_id, "t": 0.0, "duration": duration, "look": _walkers.size() + _flavor_count, "color": AppTheme.CITIZEN_COLORS[_walkers.size() % AppTheme.CITIZEN_COLORS.size()]})


func _on_mail_delivered(count: int, dropped: int, returned: int) -> void:
	if count + dropped + returned <= 0:
		return
	_walker(layout.mail_street(), layout.mail_drop_point(), "postman", "", 2.0)
	if count > 0:
		_float(layout.mail_drop_point() + Vector2(0, -40), tr("FMT_FLOAT_MAIL") % count, AppTheme.accent("primary"))
	if dropped > 0:
		_float(layout.mail_floor_point() + Vector2(0, -50), tr("FMT_FLOAT_MAIL_DROPPED") % dropped, AppTheme.accent("warning"))
		_redraw_at(layout.mail_floor_point())
	if returned > 0:
		_float(layout.mail_door() + Vector2(60, -70), tr("FMT_FLOAT_MAIL_RETURNED") % returned, AppTheme.accent("warning"))


func _on_mail_answered(_dept_id: String, money: float) -> void:
	_float(layout.mail_desk_point(), UiKit.money(money), AppTheme.MONEY)


func _on_applications_bundled(_dept_id: String, extras: int) -> void:
	_float(layout.area(GameConfig.RECEPTION).get_center() + Vector2(0, -50), tr("FMT_FLOAT_BUNDLE") % (extras + 1), AppTheme.accent("tertiary"))


func _on_form_missing(dept_id: String) -> void:
	var review := layout.area(GameConfig.department_station_keys(dept_id)[0])
	_float(review.get_center(), tr("FLOAT_FORM_MISSING"), AppTheme.accent("warning"), AppTheme.SIZE_TITLE_SMALL)
	_walker(review.get_center(), layout.door_out(), "leave", dept_id)


func _on_onboarding_completed(dept_id: String) -> void:
	var dept_room := layout.room(dept_id)
	_float(dept_room.get_center(), tr("FLOAT_ONBOARDED"), AppTheme.accent("success"))


func _on_boost_used(boost_id: String, _source: String) -> void:
	_float(game.state.player.position + Vector2(0, -60), tr("BOOST_" + boost_id.to_upper()), AppTheme.accent("tertiary"))


func _on_case_completed(dept_id: String, money: float, flawed: bool) -> void:
	var color := AppTheme.accent("warning") if flawed else AppTheme.MONEY
	if GameConfig.is_customs(dept_id):
		var area := layout.area("customs/clearance")
		_float(area.get_center(), UiKit.money(money), color)
		_float_flavor(area.get_center() + Vector2(0, -40), flawed, color)
		_walker(area.get_center(), Vector2(layout.size.x + 80, area.get_center().y), "truck", dept_id, 2.5)
		return
	var counter := layout.area(GameConfig.COUNTER)
	_float(counter.get_center() + Vector2(0, -20), UiKit.money(money), color)
	_float_flavor(counter.get_center() + Vector2(0, -62), flawed, color)
	if dept_id == "vehicle_registration":
		_walker(layout.door_out() + Vector2(0, -30), layout.door_out() + Vector2(0, 260), "car", dept_id, 1.8)


func _on_employee_dozed(key: String, desk: int, rest_state: String) -> void:
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	var text := Flavor.coffee_break(_flavor_count)
	match rest_state:
		DeskMood.ASLEEP:
			text = Flavor.nap(_flavor_count)
		DeskMood.CHAT:
			text = Flavor.go_kitchen(_flavor_count)
		DeskMood.FETCH:
			text = Flavor.fetch(_flavor_count)
		DeskMood.SLOW:
			text = Flavor.slow(_flavor_count)
		DeskMood.SICK:
			text = Flavor.sick_note(_flavor_count)
		DeskMood.LOO:
			text = Flavor.go_loo(_flavor_count)
	_float(layout.desk_position(key, desk) + Vector2(0, -76), text, AppTheme.accent("warning"), AppTheme.SIZE_TITLE_SMALL)
	_start_away_walk(key, desk)


func _start_away_walk(key: String, desk: int) -> void:
	var station := game.state.station(key)
	if station == null or desk >= station.moods.size():
		return
	var mood := station.moods[desk]
	if not mood.is_away() or mood.slot < 0:
		_redraw_at(layout.desk_position(key, desk))
		return
	var id := desk_key(key, desk)
	_returning.erase(id)
	var from := _desk_seat(key, desk)
	if _crew_desks.has(id):
		from = _crew_desks[id]
		_release_crew_desk(id)
	var to := layout.slot_point(mood.slot)
	_leaving[id] = {"left": _staff_walk(station, desk, from, to), "point": to}


func _start_return_walk(key: String, desk: int) -> void:
	var station := game.state.station(key)
	if station == null or desk >= station.moods.size():
		return
	var left := station.moods[desk].left_slot
	var id := desk_key(key, desk)
	_leaving.erase(id)
	if left < 0:
		_redraw_at(layout.desk_position(key, desk))
		return
	var to := _desk_seat(key, desk)
	_returning[id] = {"left": _staff_walk(station, desk, layout.slot_point(left), to), "point": to}


func is_desk_hidden(key: String, desk: int) -> bool:
	var id := desk_key(key, desk)
	return _returning.has(id) or _crew_desks.has(id)


func is_guest_arriving(key: String, desk: int) -> bool:
	return _leaving.has(desk_key(key, desk))


func _on_sick_called(by_player: bool, _key: String, _desk: int) -> void:
	_float(_phone_float_point(by_player), tr("FLOAT_SICK_BACK"), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_sick_call_answered(by_player: bool, _key: String, _desk: int, persuaded: bool) -> void:
	var text := tr("FLOAT_SICK_PERSUADED") if persuaded else tr("FLOAT_SICK_NOTED")
	_float(_phone_float_point(by_player), text, AppTheme.accent("success") if persuaded else AppTheme.accent("primary"), AppTheme.SIZE_TITLE_SMALL)


func _on_sick_call_missed(_key: String, _desk: int) -> void:
	_float(layout.switchboard_point() + Vector2(0, -110), tr("FLOAT_SICK_MISSED"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)


func _on_bonus_left(key: String, desk: int, _tier: int) -> void:
	_float(layout.desk_position(key, desk) + Vector2(0, -70), tr("FLOAT_SICK_BONUS"), AppTheme.MONEY, AppTheme.SIZE_TITLE_SMALL)


func _phone_float_point(by_player: bool) -> Vector2:
	var anchor := layout.phone_point() if by_player else layout.phone_office.get_center()
	return anchor + Vector2(0, -100)


func _on_kranz_called() -> void:
	_flavor_count += 1
	_float(layout.kranz_point() + Vector2(0, -90), Flavor.kranz(_flavor_count), AppTheme.accent("tertiary"), AppTheme.SIZE_TITLE_SMALL)


func _on_complaint_filed(overflow: bool) -> void:
	_flavor_count += 1
	var text := tr("FLOAT_COMPLAINT_OVERFLOW") if overflow else Flavor.complaint_subject(game.state.complaints_filed - 1)
	_float(layout.complaint_box_point() + Vector2(0, -80), text, AppTheme.accent("error" if overflow else "warning"), AppTheme.SIZE_TITLE_SMALL)


func _on_complaint_fended() -> void:
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(layout.complaint_clerk_point() + Vector2(0, -70), Flavor.fend(_flavor_count), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_complaint_shredded(_by_player: bool) -> void:
	_flavor_count += 1
	_shred_time = SHRED_ANIMATION
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(layout.shredder_point() + Vector2(0, -80), Flavor.shred(_flavor_count), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_employee_woke(key: String, desk: int, by_player: bool) -> void:
	_start_return_walk(key, desk)
	if not by_player:
		return
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(layout.desk_position(key, desk) + Vector2(0, -76), Flavor.woke(_flavor_count), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_case_rejected(dept_id: String) -> void:
	_flavor_count += 1
	var keys := GameConfig.department_station_keys(dept_id)
	if keys.is_empty() or _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(layout.area(keys[0]).get_center() + Vector2(0, -30), Flavor.reject(_flavor_count), AppTheme.accent("warning"), AppTheme.SIZE_TITLE_SMALL)
	_walker(layout.queue_point(0), layout.door_out(), "angry", dept_id, 1.6)


func _on_complaint_piped() -> void:
	if _capsules.size() >= MAX_CAPSULES:
		return
	var path := layout.complaint_tube_path()
	_capsules.append({"path": path, "color": AppTheme.accent("warning"), "t": 0.0, "duration": maxf(0.2, WorldLayout.path_length(path) / COMPLAINT_TUBE_SPEED), "speed": COMPLAINT_TUBE_SPEED})


func _on_review_posted(review: Review) -> void:
	if not review.is_negative():
		return
	_float(layout.complaint_desk_point() + Vector2(0, -110), tr("FLOAT_REVIEW_POSTED"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)


func _on_review_removed(outcome: String) -> void:
	var color := AppTheme.accent("success")
	if outcome == "lost":
		color = AppTheme.accent("error")
	elif outcome == "expired":
		color = AppTheme.accent("neutral")
	_float(layout.complaint_desk_point() + Vector2(0, -110), tr("FLOAT_REVIEW_" + outcome.to_upper()), color, AppTheme.SIZE_TITLE_SMALL)


func _on_case_shredded(_dept_id: String) -> void:
	_shred_time = SHRED_ANIMATION


func _on_dept_shredded(dept_id: String) -> void:
	var point := layout.dept_shredder_point(dept_id)
	_shredding[dept_id] = {"left": SHRED_ANIMATION, "point": point}
	_redraw_at(point)


func _on_intern_broke_down(slot: int) -> void:
	_float(_intern_position(slot) + Vector2(0, -60), tr("FLOAT_INTERN_BREAKDOWN"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)


func _on_intern_recovered(slot: int, by_player: bool) -> void:
	var anchor := _intern_position(slot) if by_player else layout.intern_home(slot)
	_float(anchor + Vector2(0, -60), tr("FLOAT_INTERN_COMFORTED" if by_player else "FLOAT_INTERN_BACK"), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _intern_position(slot: int) -> Vector2:
	var units := game.state.all_interns()
	return units[slot].position if slot >= 0 and slot < units.size() else layout.intern_home(slot)


func _on_coffee_served(key: String, desk: int) -> void:
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(layout.desk_position(key, desk) + Vector2(0, -76), Flavor.coffee_served(_flavor_count), AppTheme.accent("tertiary"), AppTheme.SIZE_TITLE_SMALL)


func _on_ruckus_started(desk: int) -> void:
	_float(layout.ruckus_point(desk) + Vector2(0, -70), tr("FLOAT_RUCKUS_START"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)


func _on_ruckus_calmed(desk: int) -> void:
	_float(layout.ruckus_point(desk) + Vector2(0, -70), tr("FLOAT_RUCKUS_CALMED"), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_dispute_started(_kind: String, dept_id: String) -> void:
	_float(layout.dispute_point(dept_id) + Vector2(0, -90), tr("FLOAT_DISPUTE_START"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)
	var crew := _assign_crew(dept_id)
	var arrival := 0.0
	for index in crew.size():
		var member: Dictionary = crew[index]
		var station := game.state.station(str(member.key))
		arrival = maxf(arrival, _staff_walk(station, int(member.desk), _desk_seat(str(member.key), int(member.desk)), _crew_spot(dept_id, index)))
	if arrival > 0.0:
		_leaving[_dispute_id(dept_id)] = {"left": arrival, "point": layout.dispute_point(dept_id)}


func _on_dispute_ended(_kind: String, dept_id: String, by_player: bool) -> void:
	_float(layout.dispute_point(dept_id) + Vector2(0, -90), tr("FLOAT_DISPUTE_PEACE" if by_player else "FLOAT_DISPUTE_OVER"), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)
	_leaving.erase(_dispute_id(dept_id))
	var crew: Array = _dispute_crews.get(dept_id, [])
	_dispute_crews.erase(dept_id)
	for index in crew.size():
		var member: Dictionary = crew[index]
		var key := str(member.key)
		var desk := int(member.desk)
		var id := desk_key(key, desk)
		if not _crew_desks.has(id):
			continue
		_release_crew_desk(id)
		var station := game.state.station(key)
		if station == null or desk >= station.moods.size() or not station.is_staffed(desk) or station.moods[desk].is_absent():
			continue
		var to := _desk_seat(key, desk)
		_returning[id] = {"left": _staff_walk(station, desk, _crew_spot(dept_id, index), to), "point": to}


func _dispute_id(dept_id: String) -> String:
	return "dispute#" + dept_id


func _crew_spot(dept_id: String, index: int) -> Vector2:
	return layout.dispute_point(dept_id) + Vector2(-DISPUTE_OFFSET if index == 0 else DISPUTE_OFFSET, 0)


func dispute_crew(dept_id: String) -> Array:
	if not _dispute_crews.has(dept_id):
		_assign_crew(dept_id)
	return _dispute_crews[dept_id]


func _assign_crew(dept_id: String) -> Array:
	var crew: Array = []
	for key in GameConfig.department_station_keys(dept_id):
		var station := game.state.station(key)
		if station == null or station.machine:
			continue
		for desk in station.moods.size():
			if crew.size() >= 2:
				break
			var id := desk_key(key, desk)
			if station.is_staffed(desk) and not station.moods[desk].is_absent() and not _crew_desks.has(id) and not _returning.has(id):
				crew.append({"key": key, "desk": desk})
				_crew_desks[id] = _crew_spot(dept_id, crew.size() - 1)
				_redraw_at(layout.desk_position(key, desk))
	_dispute_crews[dept_id] = crew
	return crew


func _release_crew_desk(id: String) -> void:
	_crew_desks.erase(id)
	for dept_id in _dispute_crews:
		var crew: Array = _dispute_crews[dept_id]
		for index in range(crew.size() - 1, -1, -1):
			if desk_key(str(crew[index].key), int(crew[index].desk)) == id:
				crew.remove_at(index)


func _on_ticket_called(number: int) -> void:
	_float(layout.ticket_display_rect().get_center() + Vector2(0, 30), tr("FMT_TICKET_CALL") % number, AppTheme.accent("primary"), AppTheme.SIZE_TITLE_SMALL)


func _on_case_piped(from_key: String, to_key: String, dept_id: String) -> void:
	if _capsules.size() >= MAX_CAPSULES or to_key.is_empty():
		return
	var path := layout.tube_path(from_key, to_key)
	var length := WorldLayout.path_length(path)
	var speed := Formulas.tube_segment_speed(game.state, RouteBuilder.tube_id(from_key, to_key))
	_capsules.append({"path": path, "color": AppTheme.department_color(dept_id), "t": 0.0, "duration": maxf(0.2, length / speed), "speed": speed})


func _on_citizen_left(dept_id: String) -> void:
	if GameConfig.is_customs(dept_id):
		return
	_float(layout.queue_point(0) + Vector2(0, -30), tr("FLOAT_CITIZEN_LEFT"), AppTheme.accent("error"))


func _style(color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0, lifted: bool = false, top_only: bool = false) -> StyleBoxFlat:
	var id := Vector4i(color.to_rgba32(), border.to_rgba32(), radius, width | (int(lifted) << 16) | (int(top_only) << 17))
	if not _styles.has(id):
		var style := AppTheme.box(color, radius)
		if width > 0:
			style.border_color = border
			style.set_border_width_all(width)
		if lifted:
			style.shadow_color = AppTheme.SHADOW_SOFT
			style.shadow_size = 9
			style.shadow_offset = Vector2(0, 4)
		if top_only:
			style.corner_radius_bottom_left = 0
			style.corner_radius_bottom_right = 0
		_styles[id] = style
	return _styles[id]


func _rounded(rect: Rect2, color: Color, radius: int, border: Color = Color.TRANSPARENT, width: int = 0, lifted: bool = false, top_only: bool = false) -> void:
	_canvas.draw_style_box(_style(color, radius, border, width, lifted and rect.size.x < LIFT_MAX_WIDTH, top_only), rect)


func _on_color(color: Color) -> Color:
	return AppTheme.ON_SURFACE if color.get_luminance() > 0.45 else AppTheme.SURFACE


func _text_outlined(pos: Vector2, text: String, size: int, color: Color, outline: Color, font: Font = null, width: float = -1.0) -> void:
	var used := font if font != null else _font
	_canvas.draw_string_outline(used, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, 5, outline)
	_canvas.draw_string(used, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


func _text_centered_outlined(center: Vector2, text: String, size: int, color: Color, outline: Color, font: Font = null) -> void:
	var used := font if font != null else _font
	var text_size := used.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_text_outlined(center + Vector2(-text_size.x * 0.5, size * 0.35), text, size, color, outline, used)


func _speech(tip: Vector2, text: String) -> void:
	var size := AppTheme.SIZE_BODY_SMALL
	var text_size := _bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var box := Rect2(tip + Vector2(-text_size.x * 0.5 - 12, -text_size.y - 26), Vector2(text_size.x + 24, text_size.y + 12))
	_rounded(box, AppTheme.SURFACE, 12, AppTheme.OUTLINE, 2, true)
	_canvas.draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -14), tip + Vector2(7, -14), tip]), AppTheme.SURFACE)
	_canvas.draw_line(tip + Vector2(-7, -14), tip, AppTheme.OUTLINE, 2.0)
	_canvas.draw_line(tip + Vector2(7, -14), tip, AppTheme.OUTLINE, 2.0)
	_canvas.draw_rect(Rect2(tip + Vector2(-5, -17), Vector2(10, 5)), AppTheme.SURFACE)
	_text(box.position + Vector2(12, text_size.y + 2), text, size, AppTheme.ON_SURFACE, _bold)


func _text(pos: Vector2, text: String, size: int, color: Color, font: Font = null, width: float = -1.0) -> void:
	_canvas.draw_string(font if font != null else _font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


func _text_centered(center: Vector2, text: String, size: int, color: Color, font: Font = null) -> void:
	var used := font if font != null else _font
	var text_size := used.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_canvas.draw_string(used, center + Vector2(-text_size.x * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _icon(center: Vector2, code: String, size: int, color: Color) -> void:
	var text_size := _icons.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	_canvas.draw_string(_icons, center + Vector2(-text_size.x * 0.5, size * 0.5), code, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _add_layer(id: String, rect: Rect2, once: bool = false) -> void:
	var node := Node2D.new()
	node.draw.connect(_draw_layer.bind(node, id))
	add_child(node)
	_layers.append({"id": id, "node": node, "rect": rect, "drawn": false, "once": once or id == SHELL_LAYER, "last": -1.0})


func _refresh_layers() -> void:
	if game == null or _layers.is_empty():
		return
	var stage := game.state.building_stage
	if stage != _shell_stage:
		_shell_stage = stage
		for layer in _layers:
			if layer.once:
				layer.drawn = false
				if layer.id == SHELL_LAYER:
					layer.node.queue_redraw()
	var signature := _tube_layout_signature(game.state)
	if signature != _tube_signature:
		_tube_signature = signature
		for layer in _layers:
			if layer.id == TUBES_LAYER:
				layer.drawn = false
	var view := view_rect().grow(CULL_MARGIN)
	var budget := LAYERS_PER_FRAME
	for step in _layers.size():
		var index := (_layer_cursor + step) % _layers.size()
		var layer := _layers[index]
		if layer.id == SHELL_LAYER or not (layer.rect as Rect2).intersects(view):
			continue
		if not layer.drawn:
			layer.drawn = true
			layer.last = _time
			(layer.node as Node2D).queue_redraw()
			continue
		if layer.once or _time - float(layer.last) < MIN_LAYER_INTERVAL:
			continue
		layer.last = _time
		(layer.node as Node2D).queue_redraw()
		_layer_cursor = (index + 1) % _layers.size()
		budget -= 1
		if budget <= 0:
			break


func _draw_layer(node: Node2D, id: String) -> void:
	if game == null:
		return
	var state := game.state
	_canvas = node
	_ring_layer = id
	_rings[id] = []
	match id:
		SHELL_LAYER:
			_draw_shell(state)
		KITCHEN_LAYER:
			_draw_kitchen(state)
		TOILETS_LAYER:
			_draw_toilets(state)
		PHONE_LAYER:
			_draw_phone_office(state)
		MAIL_LAYER:
			_draw_mail_room(state)
		COMPLAINT_LAYER:
			_draw_complaint_office(state)
		SHREDDER_LAYER:
			_draw_shredder_room(state)
		TECH_LAYER:
			_draw_tech_room(state)
		HALL_STATIC_LAYER:
			_draw_hall_static()
		HALL_LAYER:
			_draw_hall(state, view_rect().grow(CULL_MARGIN))
		TUBES_LAYER:
			_draw_tubes(state)
		_:
			_draw_room(state, id)
	_ring_layer = ""
	_canvas = self


func _draw_shell(state: GameState) -> void:
	_canvas.draw_rect(Rect2(-2000, -2000, layout.size.x + 4000, layout.size.y + 4000), AppTheme.OUTSIDE)
	_canvas.draw_rect(Rect2(layout.entrance + Vector2(-60, 0), Vector2(120, 600)), AppTheme.ROAD)
	_draw_crossing()
	_rounded(Rect2(Vector2(16, 16), layout.size - Vector2(32, 32)), AppTheme.FLOOR_STAGES[clampi(state.building_stage, 0, AppTheme.FLOOR_STAGES.size() - 1)], 28, AppTheme.WALL, 6, true)


func _draw_crowd() -> void:
	if game == null:
		return
	_canvas = _crowd
	var state := game.state
	var view := view_rect().grow(CULL_MARGIN)
	for index in state.runners.size():
		var runner := state.runners[index]
		if not view.has_point(runner.position):
			continue
		ItemPainter.draw_person(_canvas, runner.position, AppTheme.RUNNER, 1.0, Color.TRANSPARENT, index + 2, AppTheme.TIE)
		ItemPainter.draw_stack(_canvas, runner.position + Vector2(0, -28), runner.items)
	for index in state.collectors.size():
		var collector := state.collectors[index]
		if not view.has_point(collector.position):
			continue
		ItemPainter.draw_person(_canvas, collector.position, AppTheme.accent("neutral"), 1.0, Color.TRANSPARENT, index + 5, AppTheme.accent("error"))
		if collector.loaded > 0:
			OfficePainter.complaint_pile(_canvas, collector.position + Vector2(-24, -8), collector.loaded)
	_draw_citizens(state, view)
	_draw_visitors(state, view)
	_draw_complaint_intern(state, view)
	_draw_coffee_interns(state, view)
	_draw_disputes(state, view)
	_draw_ruckus(state, view)
	_draw_effects()
	_canvas = self


func citizen_placements(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in state.ticket_line.size():
		result.append({"case": state.ticket_line[index], "target": layout.ticket_line_point(index), "stage": STAGE_TICKET})
	var queued := 0
	var reception := state.station(GameConfig.RECEPTION)
	if reception != null:
		for case_file in reception.inbox:
			result.append({"case": case_file, "target": layout.queue_point(mini(queued, GameConfig.MAX_LOBBY_SLOTS - 1)), "stage": STAGE_CALLED})
			queued += 1
	for case_file in state.ticket_waiting:
		result.append({"case": case_file, "target": layout.queue_point(mini(queued, GameConfig.MAX_LOBBY_SLOTS - 1)), "stage": STAGE_WAITING})
		queued += 1
	var standing := layout.waiting_area.position + Vector2(layout.waiting_area.size.x + 18.0, 20.0)
	for key in state.ordered_station_keys():
		var station := state.station(key)
		if key == GameConfig.MAILROOM or key.begins_with("customs/"):
			continue
		var entry := key == GameConfig.RECEPTION
		if not entry:
			for case_file in station.inbox:
				_add_seated(result, case_file, standing)
		for case_file in station.outbox:
			_add_seated(result, case_file, standing)
		for desk in station.jobs.size():
			var job := station.jobs[desk]
			if job == null or not job.case_file.takes_seat():
				continue
			if entry or key == GameConfig.COUNTER:
				result.append({"case": job.case_file, "target": layout.desk_position(key, desk) + COUNTER_STEP, "stage": STAGE_DESK if entry else STAGE_COUNTER})
			else:
				_add_seated(result, job.case_file, standing)
	for case_file in state.carried_cases():
		_add_seated(result, case_file, standing)
	return result


func _add_seated(result: Array[Dictionary], case_file: CaseFile, standing: Vector2) -> void:
	if case_file.takes_seat():
		result.append({"case": case_file, "target": standing, "seat": true, "stage": STAGE_SEATED})


func _sync_citizens(state: GameState) -> void:
	var gone := _citizens.sync(citizen_placements(state), _citizen_clock, layout.door_in(), layout.waiting_seat, mini(state.seat_capacity(), WorldLayout.MAX_VISIBLE_SEATS))
	_citizen_clock = 0.0
	for entry in gone:
		var from: Vector2 = entry.pos
		var duration := clampf(from.distance_to(layout.door_out()) / CitizenTracker.SPEED, 0.4, 8.0)
		var kind := "leave" if str(entry.stage) == STAGE_COUNTER else "exit"
		if _walkers.size() <= MAX_WALKERS:
			_walkers.append({"from": from, "to": layout.door_out(), "kind": kind, "dept": entry.dept, "t": 0.0, "duration": duration, "look": int(entry.look), "color": citizen_color(int(entry.look)), "linear": true})


static func citizen_color(look: int) -> Color:
	return AppTheme.CITIZEN_COLORS[look % AppTheme.CITIZEN_COLORS.size()]


func _draw_citizens(state: GameState, view: Rect2) -> void:
	_sync_citizens(state)
	var quipped := false
	var crowding := Formulas.crowding_factor(state)
	for case_file: CaseFile in _citizens.entries:
		var entry: Dictionary = _citizens.entries[case_file]
		var pos: Vector2 = entry.pos
		if not view.has_point(pos):
			continue
		var walking := CitizenTracker.is_walking(entry)
		var bob := -absf(sin(_time * 9.0 + int(entry.look))) * 3.0 if walking else 0.0
		var stage := str(entry.stage)
		var seated := stage == STAGE_SEATED and not walking
		ItemPainter.draw_person_lite(_canvas, pos + Vector2(0, bob), citizen_color(int(entry.look)), 0.8 if seated else 0.9, int(entry.look))
		if walking or seated or stage == STAGE_DESK or stage == STAGE_COUNTER:
			continue
		var mood := clampf(case_file.waited / Formulas.citizen_patience(state, case_file, crowding), 0.0, 1.0)
		_canvas.draw_arc(pos + Vector2(0, 7), 12, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - mood), 16, AppTheme.accent("success").lerp(AppTheme.accent("error"), mood), 2.0)
		if stage == STAGE_WAITING:
			_icon(pos + Vector2(0, -26), Icons.TICKET, 16, AppTheme.accent("primary"))
		elif stage == STAGE_CALLED:
			_bubble(pos + Vector2(0, -26), case_file.dept_id, case_file.urgent)
			if not quipped and (entry.target as Vector2) == layout.queue_point(0):
				quipped = true
				_speech(pos + Vector2(0, -30), Flavor.quip(int(_time / 5.0)))


func _clerk_tip() -> Vector2:
	return layout.complaint_clerk_point() + Vector2(0, -28)


func _draw_guards(state: GameState, view: Rect2) -> void:
	for guard in state.guards:
		var pos := layout.guard_post(guard)
		if not view.has_point(pos):
			continue
		ItemPainter.draw_person(_canvas, pos, AppTheme.GUARD, 1.0, AppTheme.GUARD_CAP, guard + 8, AppTheme.GUARD_CAP)
		_canvas.draw_circle(pos + Vector2(5, 2), 2.5, AppTheme.GUARD_BADGE)


func _draw_stopped_visitor(visitor: ComplaintVisitor, pos: Vector2) -> void:
	var line := mini(GameConfig.GUARD_LINES - 1, floori(visitor.progress() * GameConfig.GUARD_LINES))
	var tip := layout.guard_post(visitor.guard) + Vector2(0, -28) if line % 2 == 0 else pos + Vector2(0, -28)
	_speech(tip, Flavor.guard_line(visitor.dialog, line))


func _draw_visitors(state: GameState, view: Rect2) -> void:
	_draw_guards(state, view)
	var spoke := false
	var venter: ComplaintVisitor = null
	var stopped := false
	for visitor in state.visitors:
		if not view.has_point(visitor.position):
			continue
		var talking := visitor.phase == ComplaintVisitor.Phase.TALKING
		var venting := visitor.phase == ComplaintVisitor.Phase.VENTING
		if visitor.phase == ComplaintVisitor.Phase.STOPPED and not stopped:
			stopped = true
			_draw_stopped_visitor(visitor, visitor.position)
		var bob := 0.0 if talking or venting or visitor.phase == ComplaintVisitor.Phase.STOPPED else -absf(sin(_time * 9.0 + visitor.slot)) * 3.0
		var shake := sin(_time * 40.0) * 1.5 if visitor.angry and (talking or venting) else 0.0
		var pos := visitor.position + Vector2(shake, bob)
		var body: Color = AppTheme.accent("error") if visitor.angry else AppTheme.CITIZEN_COLORS[visitor.look % AppTheme.CITIZEN_COLORS.size()]
		ItemPainter.draw_person(_canvas, pos, body, 1.0, Color.TRANSPARENT, visitor.look)
		if visitor.angry:
			_icon(pos + Vector2(16, -30), Icons.PRIORITY, 18, AppTheme.accent("error"))
		if talking and not spoke:
			spoke = true
			var tip := pos + Vector2(0, -28) if visitor.visitor_speaks() else _clerk_tip()
			_speech(tip, Flavor.visit_line(visitor.angry, visitor.dialog, visitor.line()))
		if venting and venter == null:
			venter = visitor
	if venter != null and not spoke:
		_draw_vent_dialogue(state, venter)


func _draw_vent_dialogue(state: GameState, visitor: ComplaintVisitor) -> void:
	if visitor.vent_speaks():
		_speech(visitor.position + Vector2(0, -28), Flavor.vent(visitor.dialog + visitor.look))
		return
	for unit in state.all_interns():
		if unit.is_at_desk():
			_speech(unit.position + Vector2(0, -44), Flavor.intern_nervous(visitor.dialog + visitor.look))
			return


func _visitor_speaking(state: GameState) -> bool:
	for visitor in state.visitors:
		if visitor.phase == ComplaintVisitor.Phase.TALKING or visitor.phase == ComplaintVisitor.Phase.VENTING:
			return true
	return false


func _draw_complaint_intern(state: GameState, view: Rect2) -> void:
	if not state.has_upgrade("shredder_service"):
		return
	for unit in state.all_interns():
		_draw_intern_unit(state, view, unit)


func _draw_intern_unit(state: GameState, view: Rect2, intern: ComplaintIntern) -> void:
	var home := layout.intern_home(intern.slot)
	if intern.is_away() or intern.mood == ComplaintIntern.Mood.RETURNING:
		var note := Rect2(home + Vector2(-75, -50), Vector2(150, 22))
		if view.intersects(note):
			_rounded(note, AppTheme.SURFACE, 6, AppTheme.OUTLINE, 2)
			_text_centered(note.get_center(), tr("SIGN_INTERN_AWAY"), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE, _bold)
	if not view.has_point(intern.position):
		return
	var running := intern.mood != ComplaintIntern.Mood.DESK and intern.mood != ComplaintIntern.Mood.CRYING
	var pos := intern.position + Vector2(0, -absf(sin(_time * 12.0)) * 4.0 if running else 0.0)
	ItemPainter.draw_person(_canvas, pos, AppTheme.accent("tertiary"), 1.0, Color.TRANSPARENT, 7 + intern.slot, AppTheme.COLLAR)
	if intern.mood == ComplaintIntern.Mood.TO_SHREDDER:
		OfficePainter.complaint_pile(_canvas, pos + Vector2(-22, -8), maxi(1, Formulas.intern_capacity(state)))
	if intern.is_away():
		for i in 2:
			var drop := fmod(_time * 1.5 + i * 0.5, 1.0)
			_canvas.draw_circle(pos + Vector2(-5 + i * 10, -4 + drop * 18), 2.2, AppTheme.WATER)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_canvas.draw_arc(pos + Vector2(0, -2), 30.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("warning"), 0.5 + pulse * 0.4), 3.0)
		_progress_ring(pos + Vector2(0, -2), 30.0, 6.0, AppTheme.accent("success"), func() -> float: return intern.comfort_progress / GameConfig.INTERN_COMFORT_TIME)
		_speech(pos + Vector2(0, -30), Flavor.intern_cry(int(_time / 3.0) + intern.slot))
		return
	if intern.stress > 0.05:
		var bar := Rect2(pos + Vector2(-20, -38), Vector2(40, 6))
		_canvas.draw_rect(bar, AppTheme.SURFACE)
		_canvas.draw_rect(Rect2(bar.position, Vector2(bar.size.x * intern.stress, bar.size.y)), AppTheme.accent("success").lerp(AppTheme.accent("error"), intern.stress))
		_canvas.draw_rect(bar, AppTheme.OUTLINE, false, 1.0)
	if intern.stress > 0.5 and intern.slot == 0 and not _visitor_speaking(state):
		_speech(pos + Vector2(0, -44), Flavor.intern_nervous(int(_time / 3.0)))


func _draw_coffee_interns(state: GameState, view: Rect2) -> void:
	for index in state.coffee_interns.size():
		var coffee_intern := state.coffee_interns[index]
		if not view.has_point(coffee_intern.position):
			continue
		var pos := coffee_intern.position
		ItemPainter.draw_person(_canvas, pos, AppTheme.COFFEE_LIQUID, 1.0, Color.TRANSPARENT, index + 8, AppTheme.COLLAR)
		if not coffee_intern.carrying:
			continue
		var cup := pos + Vector2(14, -6)
		_canvas.draw_rect(Rect2(cup + Vector2(-4, -4), Vector2(8, 8)), AppTheme.SURFACE)
		_canvas.draw_rect(Rect2(cup + Vector2(-4, -4), Vector2(8, 8)), AppTheme.METAL_DARK, false, 1.0)
		_canvas.draw_rect(Rect2(cup + Vector2(-3, -3), Vector2(6, 3)), AppTheme.COFFEE_LIQUID)
		_canvas.draw_line(cup + Vector2(-1, -6), cup + Vector2(-1 + sin(_time * 4.0) * 2.0, -12), AppTheme.METAL, 1.5)


func _draw_ruckus(state: GameState, view: Rect2) -> void:
	if not state.has_ruckus():
		return
	var point := layout.ruckus_point(state.ruckus_desk)
	if not view.has_point(point):
		return
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	_canvas.draw_arc(point, 34.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("error"), 0.5 + pulse * 0.4), 3.0)
	_canvas.draw_circle(point + Vector2(0, -40), 13, AppTheme.accent("error"))
	_icon(point + Vector2(0, -40), Icons.DESCRIPTION, 16, AppTheme.on_accent("error"))
	_progress_ring(point, 34.0, 6.0, AppTheme.accent("success"), func() -> float: return state.ruckus_progress / GameConfig.RUCKUS_CALM_TIME)
	_speech(point + Vector2(0, -62), Flavor.ruckus_line(int(_time / 2.5)))
	_text_centered_outlined(point + Vector2(0, 42), tr("LABEL_RUCKUS"), AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error"), AppTheme.SURFACE, _bold)


func _draw_disputes(state: GameState, view: Rect2) -> void:
	for dispute in state.disputes:
		var point := layout.dispute_point(dispute.dept_id)
		if not view.has_point(point):
			continue
		if not _leaving.has(_dispute_id(dispute.dept_id)):
			_draw_dispute_crew(dispute.dept_id)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_canvas.draw_arc(point, 44.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("error"), 0.5 + pulse * 0.4), 3.0)
		_canvas.draw_circle(point + Vector2(0, -6), 14, AppTheme.accent("error"))
		_icon(point + Vector2(0, -6), Icons.DISPUTES[dispute.kind], 18, AppTheme.on_accent("error"))
		_progress_ring(point, 44.0, 6.0, AppTheme.accent("success"), func() -> float: return dispute.progress / GameConfig.MEDIATE_TIME)
		var turn := int(_time / 2.5)
		_speech(point + Vector2(-26 if turn % 2 == 0 else 26, -28), Flavor.dispute_line(dispute.kind, turn))
		var label := tr("FMT_DISPUTE") % [tr("DISPUTE_" + dispute.kind.to_upper()), roundi((1.0 - dispute.speed()) * 100.0)]
		_text_centered_outlined(point + Vector2(0, 50), label, AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error"), AppTheme.SURFACE, _bold)


func _draw_dispute_crew(dept_id: String) -> void:
	var crew := dispute_crew(dept_id)
	var shake := sin(_time * 22.0) * 1.2
	for index in 2:
		var pos := _crew_spot(dept_id, index) + Vector2(shake if index == 0 else -shake, 0)
		if index >= crew.size():
			ItemPainter.draw_person(_canvas, pos, AppTheme.STAFF_COLOR, 1.0, Color.TRANSPARENT, absi(dept_id.hash()) % 12 + index * 5, AppTheme.TIE)
			continue
		var station := game.state.station(str(crew[index].key))
		var desk := int(crew[index].desk)
		var expert := station.is_specialist_desk(desk)
		ItemPainter.draw_person(_canvas, pos, AppTheme.SPECIALIST_COAT if expert else AppTheme.STAFF_COLOR, 1.0, Color.TRANSPARENT, staff_look(station, desk), AppTheme.SPECIALIST if expert else AppTheme.TIE, false, expert)


func _draw_actors() -> void:
	if game == null:
		return
	_canvas = _actors
	var state := game.state
	_draw_live_rings()
	_draw_spot_highlight()
	_draw_player(state.player)
	_draw_guidance()
	_canvas = self


func _progress_ring(center: Vector2, radius: float, width: float, color: Variant, ratio: Callable) -> void:
	if _ring_layer.is_empty():
		_draw_ring(center, radius, width, color, float(ratio.call()))
		return
	(_rings[_ring_layer] as Array).append({"center": center, "radius": radius, "width": width, "color": color, "ratio": ratio})


func _draw_live_rings() -> void:
	for entries: Array in _rings.values():
		for entry: Dictionary in entries:
			_draw_ring(entry.center, entry.radius, entry.width, entry.color, float((entry.ratio as Callable).call()))


func _draw_ring(center: Vector2, radius: float, width: float, color: Variant, ratio: float) -> void:
	if ratio <= 0.0:
		return
	var tint: Color = color.call() if color is Callable else color
	_canvas.draw_arc(center, radius, RING_START, RING_START + TAU * minf(ratio, 1.0), RING_POINTS, tint, width)


func _draw_crossing() -> void:
	var y := layout.entrance.y + 40.0
	for i in 8:
		_canvas.draw_rect(Rect2(layout.entrance.x - 60.0 + i * 16.0, y, 8, 30), AppTheme.ROAD_LINE)


func _draw_hall_static() -> void:
	var hall := layout.hall
	_rounded(hall, AppTheme.HALL_FLOOR, ROOM_RADIUS, Color(AppTheme.WALL, 0.4), 2)
	OfficePainter.tiles(_canvas, Rect2(hall.position + Vector2(10, 10), hall.size - Vector2(20, 24)))
	_draw_hall_decor(hall)
	_rounded(Rect2(layout.entrance + Vector2(-56, -14), Vector2(112, 26)), AppTheme.WALL, 8)
	_icon(layout.entrance, Icons.DOOR, 20, AppTheme.SURFACE)


func _draw_waiting_sign(state: GameState) -> void:
	_draw_hall_sign(layout.queue_sign_rect(), "FMT_WAITING_SIGN", state.lobby_used(), state.lobby_capacity())
	var seated := state.seated_citizens()
	var seats := state.seat_capacity()
	_draw_hall_sign(layout.seating_sign_rect(), "FMT_SEATING_SIGN", mini(seated, seats), seats)
	if state.standing_capacity() > 0:
		_draw_hall_sign(layout.standing_sign_rect(), "FMT_STANDING_SIGN", maxi(0, seated - seats), state.standing_capacity())


func _draw_hall_sign(rect: Rect2, format_key: String, used: int, capacity: int) -> void:
	var full := used >= capacity
	_rounded(rect, AppTheme.accent("error") if full else AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(rect.get_center(), tr(format_key) % [used, capacity], AppTheme.SIZE_LABEL_SMALL, AppTheme.on_accent("error") if full else AppTheme.SIGN_TEXT, _bold)


func _draw_hall(state: GameState, view: Rect2) -> void:
	_draw_complaint_box(state)
	_draw_waiting_sign(state)
	_draw_station(state, GameConfig.RECEPTION, "")
	_draw_station(state, GameConfig.COUNTER, "")
	_draw_hall_furnishing(state, view)
	_draw_board(layout.guards_board(), tr("BOARD_GUARDS"), tr("FMT_BOARD_STAFF") % [state.guards, GameConfig.MAX_GUARDS])
	_draw_board(layout.training_board(), tr("BOARD_TRAINING"), tr("FMT_BOARD_LEVEL") % state.upgrade_level("quality_training"))
	_draw_tube_slot(state, GameConfig.ROOM_HALL)
	if state.tickets_unlocked():
		_draw_ticket_corner(state)


func _draw_ticket_corner(state: GameState) -> void:
	for index in Formulas.ticket_machines(state):
		OfficePainter.ticket_dispenser(_canvas, layout.ticket_machine_point(index))
	var machine := layout.ticket_machine_point()
	_canvas.draw_multiline_string(_bold, machine + Vector2(-46, -58), tr("SIGN_TICKET"), HORIZONTAL_ALIGNMENT_CENTER, 92.0, AppTheme.SIZE_LABEL_SMALL - 1, 2, AppTheme.ON_SURFACE)
	var draw_ratio := func() -> float: return state.ticket_progress / Formulas.ticket_draw_time(state) if not state.ticket_line.is_empty() else 0.0
	var draw_color := func() -> Color: return AppTheme.accent("success") if layout.near(state.player.position, machine) else AppTheme.accent("primary")
	_progress_ring(machine + Vector2(0, 6), 30.0, 4.0, draw_color, draw_ratio)
	var display := layout.ticket_display_rect()
	OfficePainter.call_display(_canvas, display)
	_text_centered(display.get_center(), tr("FMT_TICKET_NUMBER") % state.tickets_called, AppTheme.SIZE_LABEL_SMALL + 2, AppTheme.CALL_DISPLAY_TEXT, _bold)
	var call_ratio := func() -> float: return state.ticket_call_progress / Formulas.ticket_call_time(state) if not state.ticket_waiting.is_empty() else 0.0
	var call_color := func() -> Color: return AppTheme.accent("success") if layout.near(state.player.position, layout.ticket_display_point()) else AppTheme.accent("primary")
	_progress_ring(layout.ticket_display_point(), 22.0, 4.0, call_color, call_ratio)


func _draw_hall_furnishing(state: GameState, view: Rect2) -> void:
	_sync_pop(_seat_born, mini(state.seat_capacity(), WorldLayout.MAX_VISIBLE_SEATS))
	_sync_pop(_slot_born, state.lobby_capacity())
	for i in _slot_born.size():
		var pos := layout.queue_point(i)
		if view.has_point(pos):
			OfficePainter.queue_mark(_canvas, pos, OfficePainter.pop_scale(_time - _slot_born[i]))
	for i in _seat_born.size():
		var pos := layout.waiting_seat(i)
		if view.has_point(pos):
			OfficePainter.waiting_chair(_canvas, pos + Vector2(0, 8), OfficePainter.pop_scale(_time - _seat_born[i]))
	_furnishing_ready = true


func _sync_pop(born: Array[float], capacity: int) -> void:
	if _furnishing_ready:
		var step := 0
		while born.size() < capacity:
			born.append(_time + step * POP_STAGGER)
			step += 1
	else:
		while born.size() < capacity:
			born.append(-1.0e6)
	if born.size() > capacity:
		born.resize(capacity)


func _draw_kitchen(state: GameState) -> void:
	var rect := layout.kitchen
	var header := layout.kitchen_header()
	var color := AppTheme.KITCHEN
	var on_band := _on_color(color)
	_rounded(rect, color.lerp(AppTheme.SURFACE, 0.82), ROOM_RADIUS, color.darkened(0.15), 3, false)
	OfficePainter.tiles(_canvas, Rect2(rect.position + Vector2(10, WorldLayout.HEADER), rect.size - Vector2(20, WorldLayout.HEADER + 12)))
	_rounded(header, color, ROOM_RADIUS, color.darkened(0.15), 3, false, true)
	_canvas.draw_circle(header.position + Vector2(32, 28), 20, on_band)
	_icon(header.position + Vector2(32, 28), Icons.COFFEE, 24, color.darkened(0.3))
	_text(header.position + Vector2(62, 36), tr("AREA_KITCHEN"), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 120)
	_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
	var origin := rect.position
	OfficePainter.fridge(_canvas, Rect2(origin + Vector2(24, 66), Vector2(58, 118)))
	OfficePainter.kitchen_counter(_canvas, Rect2(origin + Vector2(96, 110), Vector2(340, 40)))
	OfficePainter.sink(_canvas, origin + Vector2(340, 108))
	OfficePainter.microwave(_canvas, origin + Vector2(400, 108))
	var fetching := false
	var chatting := false
	for key in state.stations:
		var station := state.stations[key]
		if station.machine:
			continue
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if station.is_staffed(desk) and mood.is_away() and mood.state != DeskMood.LOO:
				fetching = fetching or mood.state == DeskMood.FETCH or mood.state == DeskMood.SLOW
				_draw_kitchen_guest(station, desk, mood, not chatting)
				chatting = chatting or mood.state == DeskMood.CHAT or mood.state == DeskMood.SLOW
	OfficePainter.coffee_machine(_canvas, layout.coffee_machine_point() + Vector2(0, 20), _tier(state, "coffee", OfficePainter.COFFEE_LIGHTS), fetching, _time, _tier(state, "coffee_machine", COFFEE_TIERS))
	OfficePainter.kitchen_table(_canvas, origin + Vector2(700, 185))
	var board := Rect2(origin + Vector2(560, 62), Vector2(220, 30))
	_rounded(board, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(board.get_center(), tr("SIGN_COFFEE_FUND"), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	var rules := Rect2(origin + Vector2(560, 96), Vector2(220, 30))
	_rounded(rules, AppTheme.SURFACE, 8, AppTheme.OUTLINE, 2)
	_text_centered(rules.get_center(), tr("SIGN_KITCHEN_RULES"), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE, _bold)
	OfficePainter.plant(_canvas, origin + Vector2(865, 150), 1.1)
	for i in _tier(state, "kitchen", KITCHEN_PLANTS):
		OfficePainter.plant(_canvas, origin + Vector2(470 + 44 * i, 135), 0.8)
	_draw_board(layout.coffee_interns_board(), tr("BOARD_COFFEE_INTERNS"), tr("FMT_BOARD_STAFF") % [state.coffee_interns.size(), GameConfig.MAX_COFFEE_INTERNS])
	_draw_board(layout.works_council_board(), tr("BOARD_WORKS_COUNCIL"), tr("FMT_BOARD_DISPUTES") % [state.disputes.size(), state.disputes_solved])
	if state.kranz:
		_draw_kranz_banner(state)


func _draw_toilets(state: GameState) -> void:
	var rect := layout.toilets
	var header := layout.toilets_header()
	var color := AppTheme.METAL
	var on_band := _on_color(color)
	_rounded(rect, color.lerp(AppTheme.SURFACE, 0.82), ROOM_RADIUS, color.darkened(0.15), 3, false)
	OfficePainter.tiles(_canvas, Rect2(rect.position + Vector2(10, WorldLayout.HEADER), rect.size - Vector2(20, WorldLayout.HEADER + 12)))
	_rounded(header, color, ROOM_RADIUS, color.darkened(0.15), 3, false, true)
	_text(header.position + Vector2(24, 36), tr("AREA_TOILETS"), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 70)
	_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
	_draw_loo_block(state)
	var voiced := false
	for key in state.stations:
		var station := state.stations[key]
		if station.machine:
			continue
		for desk in station.moods.size():
			var mood := station.moods[desk]
			if station.is_staffed(desk) and mood.state == DeskMood.LOO:
				_draw_loo_guest(layout.slot_point(mood.slot), mood, not voiced)
				voiced = true


func _draw_phone_office(state: GameState) -> void:
	var rect := layout.phone_office
	var header := layout.phone_header()
	var color := AppTheme.SPECIALIST
	var on_band := _on_color(color)
	_rounded(rect, color.lerp(AppTheme.SURFACE, 0.88), ROOM_RADIUS, color.darkened(0.15), 3, false)
	_rounded(header, color, ROOM_RADIUS, color.darkened(0.15), 3, false, true)
	_canvas.draw_circle(header.position + Vector2(32, 28), 20, on_band)
	_icon(header.position + Vector2(32, 28), Icons.STAFF.hr, 24, color.darkened(0.3))
	_text(header.position + Vector2(62, 36), tr("AREA_PHONE_OFFICE"), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 120)
	_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
	var ringing := state.ringing_count()
	var board := layout.switchboard_point()
	OfficePainter.switchboard(_canvas, board, ringing, _time)
	if ringing > 0:
		_text_centered_outlined(board + Vector2(0, 48), tr("FMT_RINGING") % ringing, AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("warning"), AppTheme.SURFACE, _bold)
	_draw_phone_line(state, PhoneCall.PLAYER, ringing > 0)
	var sign_rect := Rect2(layout.phone_point() + Vector2(-70, 30), Vector2(140, 26))
	_rounded(sign_rect, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(sign_rect.get_center(), tr("SIGN_SICK_PHONE"), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	for line in GameConfig.MAX_HR:
		_draw_phone_line(state, line, ringing > 0)
	_draw_sick_board(state, ringing)
	_draw_call_dialogue(state)


func _draw_mail_room(state: GameState) -> void:
	var rect := layout.mail_room
	var header := layout.mail_header()
	var color := AppTheme.POST_YELLOW.darkened(0.25)
	var on_band := _on_color(color)
	_rounded(rect, color.lerp(AppTheme.SURFACE, 0.88), ROOM_RADIUS, color.darkened(0.15), 3, false)
	_rounded(header, color, ROOM_RADIUS, color.darkened(0.15), 3, false, true)
	_canvas.draw_circle(header.position + Vector2(32, 28), 20, on_band)
	_icon(header.position + Vector2(32, 28), Icons.MAIL, 24, color.darkened(0.3))
	_text(header.position + Vector2(62, 36), tr("AREA_MAIL_ROOM"), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 120)
	_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
	var room := state.mailroom()
	if room == null:
		_text_centered(rect.get_center(), tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1), AppTheme.SIZE_TITLE_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)
		return
	OfficePainter.mailbox(_canvas, layout.mail_door() + Vector2(40, 0))
	var storage := layout.mail_storage_rect()
	OfficePainter.mail_shelf(_canvas, storage, room.inbox.size(), room.storage_capacity())
	_draw_mail_floor(state)
	_draw_hall_sign(Rect2(storage.position + Vector2(0, storage.size.y + 6), Vector2(storage.size.x, 26)), "FMT_MAIL_SHELF_SIGN", room.inbox.size(), room.storage_capacity())
	_draw_station(state, GameConfig.MAILROOM, "")
	_draw_tube_slot(state, GameConfig.ROOM_MAIL)
	var sign_rect := Rect2(layout.mail_desk_point() + Vector2(-110, -40), Vector2(220, 26))
	_rounded(sign_rect, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(sign_rect.get_center(), tr("SIGN_MAIL_%d" % (int(_time / 6.0) % 3 + 1)), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	_text_centered(layout.mail_desk_point() + Vector2(0, 20), tr("FMT_MAIL_NEXT") % ceili(state.mail_timer), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)


func _draw_mail_floor(state: GameState) -> void:
	var count := state.mail_floor.size()
	if count == 0:
		return
	var center := layout.mail_floor_point()
	for index in mini(count, MAIL_FLOOR_VISIBLE):
		var angle := index * 2.4
		var offset := Vector2(cos(angle), sin(angle)) * (6.0 + index * 2.5)
		ItemPainter.draw_letter(_canvas, center + offset, AppTheme.department_color(state.mail_floor[index].dept_id))
	_text_centered_outlined(center + Vector2(0, 44), tr("FMT_MAIL_FLOOR") % count, AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("warning"), AppTheme.SURFACE, _bold)


func _draw_phone_line(state: GameState, line: int, ringing: bool) -> void:
	var point := layout.line_point(line)
	var staffed := line == PhoneCall.PLAYER or line < state.hr
	var phone_call := state.line_call(line)
	if staffed and line != PhoneCall.PLAYER:
		ItemPainter.draw_person(_canvas, point + Vector2(0, -28), AppTheme.SPECIALIST, 0.9, Color.TRANSPARENT, line + 5, AppTheme.TIE)
	OfficePainter.desk(_canvas, point, staffed and line != PhoneCall.PLAYER, phone_call != null, _time)
	OfficePainter.phone(_canvas, point + Vector2(-18, -14), staffed and phone_call == null and ringing, _time)
	if phone_call != null:
		var tint := AppTheme.accent("warning") if phone_call.is_incoming() else AppTheme.accent("success")
		_progress_ring(point + Vector2(0, -14), 44.0, 6.0, tint, func() -> float: return phone_call.ratio() if state.calls.has(phone_call) else 0.0)


func _draw_sick_board(state: GameState, ringing: int) -> void:
	var rect := layout.sick_board()
	_rounded(rect, AppTheme.SIGN_BOARD, 10, AppTheme.WALL, 2)
	_text_centered(rect.position + Vector2(rect.size.x * 0.5, 22), tr("SIGN_SICK_BOARD"), AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.FLAG_GOLD, _bold)
	var sick := state.sick_count()
	var reported := state.reported_sick_count()
	var lines: Array[String] = [
		tr("FMT_BOARD_SICK") % sick,
		tr("FMT_BOARD_REPORTED") % reported,
		tr("FMT_BOARD_UNEXCUSED") % maxi(0, sick - reported - ringing),
		tr("FMT_BOARD_CALLS") % [state.calls_answered, state.calls_made],
	]
	for i in lines.size():
		_text(rect.position + Vector2(14, 56 + i * 26), lines[i], AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold, rect.size.x - 28)


func _draw_call_dialogue(state: GameState) -> void:
	var phone_call := state.line_call(PhoneCall.PLAYER)
	if phone_call == null:
		for candidate in state.calls:
			if not candidate.is_ringing():
				phone_call = candidate
				break
	if phone_call == null:
		return
	var point := layout.line_point(phone_call.line)
	var index := posmod(phone_call.key.hash() + phone_call.desk, Flavor.SICK_CALL_COUNT)
	if phone_call.ratio() < 0.5:
		_speech(point + Vector2(-20, -70), Flavor.sick_excuse(index))
	elif phone_call.is_incoming():
		_speech(point + Vector2(20, -70), Flavor.sick_answer(index))
	else:
		_speech(point + Vector2(20, -70), Flavor.sick_reply(index))


func _draw_kranz_banner(state: GameState) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var point := layout.kranz_point()
	var banner := Rect2(point + Vector2(-130, -142), Vector2(260, 34))
	_rounded(banner, AppTheme.accent("tertiary"), 10, AppTheme.accent("tertiary").darkened(0.3), 2)
	_text_centered(banner.get_center(), tr("SIGN_KRANZ"), AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.on_accent("tertiary"), _bold)
	_canvas.draw_arc(point, 44.0 + pulse * 4.0, 0, TAU, 32, Color(AppTheme.accent("tertiary"), 0.5 + pulse * 0.4), 3.0)
	_progress_ring(point, 44.0, 6.0, AppTheme.accent("success"), func() -> float: return state.kranz_progress / GameConfig.KRANZ_END_TIME if state.kranz else 0.0)


func _draw_loo_guest(pos: Vector2, mood: DeskMood, with_quip: bool) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	_canvas.draw_arc(pos + Vector2(0, -26), 30.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("warning"), 0.5 + pulse * 0.4), 3.0)
	_progress_ring(pos + Vector2(0, -26), 30.0, 6.0, AppTheme.accent("success"), _mood_ratio(mood, func() -> float: return mood.wake_progress / GameConfig.ENCOURAGE_TIME))
	if with_quip:
		_speech(pos + Vector2(0, -96), Flavor.loo_voice(int(_time / 4.0) + mood.slot))


func _draw_loo_block(state: GameState) -> void:
	var origin := layout.loo_origin()
	var plate := Rect2(origin + Vector2(0, -24), Vector2(256, 22))
	_rounded(plate, AppTheme.SIGN_BOARD, 6, AppTheme.WALL, 2)
	_text_centered(plate.get_center(), tr("SIGN_LOO"), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	var slots := state.loo_slots()
	for row in ceili(float(slots) / WorldLayout.LOO_COLUMNS):
		var occupied: Array[bool] = []
		for column in mini(WorldLayout.LOO_COLUMNS, slots - row * WorldLayout.LOO_COLUMNS):
			occupied.append(state.kitchen_slot_taken(GameConfig.KITCHEN_SLOTS + row * WorldLayout.LOO_COLUMNS + column))
		OfficePainter.toilet_stalls(_canvas, layout.loo_origin(row), occupied, WorldLayout.LOO_PITCH)


func _draw_kitchen_guest(station: Station, desk: int, mood: DeskMood, with_quip: bool) -> void:
	var pos := layout.slot_point(mood.slot)
	if mood.state == DeskMood.LOO:
		_draw_loo_guest(pos, mood, with_quip)
		return
	if is_guest_arriving(station.key, desk):
		return
	var expert := station.is_specialist_desk(desk)
	ItemPainter.draw_person(_canvas, pos, AppTheme.SPECIALIST_COAT if expert else AppTheme.STAFF_COLOR, 1.0, Color.TRANSPARENT, staff_look(station, desk), AppTheme.SPECIALIST if expert else AppTheme.TIE, false, expert)
	var cup := pos + Vector2(14, 2)
	_canvas.draw_rect(Rect2(cup + Vector2(-4, -4), Vector2(8, 8)), AppTheme.SURFACE)
	_canvas.draw_rect(Rect2(cup + Vector2(-4, -4), Vector2(8, 8)), AppTheme.METAL_DARK, false, 1.0)
	_canvas.draw_rect(Rect2(cup + Vector2(-3, -3), Vector2(6, 3)), AppTheme.COFFEE_LIQUID)
	if mood.state == DeskMood.FETCH:
		_progress_ring(pos + Vector2(0, 6), 26.0, 4.0, AppTheme.accent("success"), _mood_ratio(mood, func() -> float: return mood.resting / Formulas.rest_limit(game.state, DeskMood.FETCH)))
		return
	if mood.state == DeskMood.SLOW:
		var ring_color := func() -> Color: return AppTheme.accent("success") if layout.near(game.state.player.position, pos) else AppTheme.accent("warning")
		_progress_ring(pos + Vector2(0, 6), 26.0, 4.0, ring_color, _mood_ratio(mood, func() -> float: return mood.resting / GameConfig.SLOW_SECONDS))
		if with_quip:
			_speech(pos + Vector2(0, -26), Flavor.slow(int(_time / 4.0) + mood.slot))
		return
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	_canvas.draw_arc(pos + Vector2(0, 6), 28.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("warning"), 0.5 + pulse * 0.4), 3.0)
	_progress_ring(pos + Vector2(0, 6), 28.0, 6.0, AppTheme.accent("success"), _mood_ratio(mood, func() -> float: return mood.wake_progress / GameConfig.WAKE_TIME))
	if with_quip:
		_speech(pos + Vector2(0, -26), Flavor.chat(int(_time / 4.0) + mood.slot))
	else:
		var bubble := pos + Vector2(18, -30)
		_canvas.draw_circle(bubble, 11, AppTheme.SURFACE)
		_canvas.draw_arc(bubble, 11, 0, TAU, 20, AppTheme.accent("tertiary"), 2.0)
		for i in 3:
			_canvas.draw_circle(bubble + Vector2(-5 + i * 5, 1), 1.6, AppTheme.accent("tertiary") if int(_time * 3.0) % 3 == i else AppTheme.OUTLINE)


func _draw_hall_decor(hall: Rect2) -> void:
	var plate := layout.hall_plate()
	_rounded(plate, AppTheme.SIGN_BOARD, 10, AppTheme.WALL, 2, true)
	_text_centered(plate.get_center(), tr("SIGN_BUILDING"), AppTheme.SIZE_TITLE_SMALL, AppTheme.SIGN_TEXT, _bold)
	_text(Vector2(plate.end.x + 18.0, plate.position.y + 24.0), tr("AREA_PUBLIC"), AppTheme.SIZE_BODY_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)
	OfficePainter.clock(_canvas, hall.position + Vector2(52, 40), 22.0)
	OfficePainter.cabinet(_canvas, layout.archive_rect())
	var board := layout.hours_board()
	_rounded(board, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(board.position + Vector2(44, 18), tr("SIGN_HOURS_TITLE"), AppTheme.SIZE_LABEL_SMALL - 1, AppTheme.FLAG_GOLD, _bold)
	_canvas.draw_multiline_string(_bold, board.position + Vector2(4, 42), tr("SIGN_HOURS_TEXT"), HORIZONTAL_ALIGNMENT_CENTER, board.size.x - 8, AppTheme.SIZE_LABEL_SMALL - 1, 3, AppTheme.SIGN_TEXT)
	OfficePainter.flag(_canvas, Vector2(hall.end.x - 96.0, hall.position.y + 160.0), 120.0, _time)
	OfficePainter.plant(_canvas, Vector2(hall.position.x + 50.0, hall.end.y - 30.0), 1.2)
	OfficePainter.plant(_canvas, Vector2(hall.end.x - 30.0, hall.end.y - 26.0), 1.0)
	_draw_closed_sign(layout.closed_sign_rect())


func _draw_closed_sign(rect: Rect2) -> void:
	ItemPainter.shadow(_canvas, Vector2(rect.get_center().x, rect.end.y + 4.0), rect.size.x * 0.4, 5)
	for leg in [rect.position.x + 18.0, rect.end.x - 18.0]:
		_canvas.draw_line(Vector2(leg, rect.end.y - 6.0), Vector2(leg, rect.end.y + 6.0), AppTheme.WOOD_DARK, 4.0)
	_rounded(rect, AppTheme.FLAG_RED, 8, AppTheme.FLAG_RED.darkened(0.3), 2)
	_canvas.draw_multiline_string(_bold, rect.position + Vector2(6, 15), tr("SIGN_CLOSED"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, AppTheme.SIZE_LABEL_SMALL - 3, 3, AppTheme.SURFACE)


func _draw_complaint_box(state: GameState) -> void:
	var box := layout.complaint_box_point()
	var cap := Formulas.complaint_cap(state)
	var full := state.complaints >= cap
	OfficePainter.complaint_box(_canvas, box, float(state.complaints) / float(cap))
	_text_centered_outlined(box + Vector2(0, 34), "%d/%d" % [state.complaints, cap], AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.accent("error") if full else AppTheme.ON_SURFACE, AppTheme.SURFACE, _bold)


func _service_shell(room_id: String, color: Color, icon_code: String) -> Rect2:
	var rect := layout.service_room(room_id)
	var header := layout.room_header(room_id)
	var on_band := _on_color(color)
	_rounded(rect, color.lerp(AppTheme.SURFACE, 0.88), ROOM_RADIUS, color.darkened(0.15), 3, false)
	OfficePainter.tiles(_canvas, Rect2(rect.position + Vector2(10, WorldLayout.HEADER), rect.size - Vector2(20, WorldLayout.HEADER + 12)))
	_rounded(header, color, ROOM_RADIUS, color.darkened(0.15), 3, false, true)
	_canvas.draw_circle(header.position + Vector2(32, 28), 20, on_band)
	_icon(header.position + Vector2(32, 28), icon_code, 24, color.darkened(0.3))
	_text(header.position + Vector2(62, 36), UpgradeTexts.room_title(room_id), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 110)
	_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
	return rect


func _draw_door(point: Vector2) -> void:
	_rounded(Rect2(point + Vector2(-34, -8), Vector2(68, 16)), AppTheme.WALL, 6)
	_icon(point, Icons.DOOR, 14, AppTheme.SURFACE)


func _draw_board(rect: Rect2, title: String, body: String) -> void:
	_rounded(rect, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	var size := AppTheme.SIZE_LABEL_SMALL - 1
	var width := rect.size.x - 12.0
	var title_lines := 1 if _bold.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width else 2
	_canvas.draw_multiline_string(_bold, rect.position + Vector2(6, 18), title, HORIZONTAL_ALIGNMENT_CENTER, width, size, title_lines, AppTheme.FLAG_GOLD)
	var top := 22.0 + title_lines * (size + 4.0)
	var lines := maxi(1, floori((rect.size.y - top) / (size + 4.0)) + 1)
	_canvas.draw_multiline_string(_bold, rect.position + Vector2(6, top), body, HORIZONTAL_ALIGNMENT_CENTER, width, size, lines, AppTheme.SIGN_TEXT)


func _draw_complaint_office(state: GameState) -> void:
	_service_shell(GameConfig.ROOM_COMPLAINTS, AppTheme.FLAG_RED, Icons.CLERK)
	var desk := layout.complaint_desk_point()
	var sign_rect := Rect2(desk + Vector2(-120, -92), Vector2(240, 26))
	_rounded(sign_rect, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(sign_rect.get_center(), tr("SIGN_COMPLAINTS"), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	var clerk := state.upgrade_level("complaint_clerk")
	ItemPainter.draw_person(_canvas, layout.complaint_clerk_point(), AppTheme.SIGN_BOARD, 1.0, Color.TRANSPARENT, 3 + tier(clerk, int(GameConfig.upgrade("complaint_clerk").max), CLERK_LOOKS), AppTheme.TIE)
	OfficePainter.desk(_canvas, desk, false, false, _time)
	if state.complaints > 0:
		OfficePainter.complaint_pile(_canvas, desk + Vector2(40, -10), state.complaints)
	var interns := state.all_interns().size() if state.has_upgrade("shredder_service") else 0
	_draw_board(layout.interns_board(), tr("BOARD_INTERNS"), tr("FMT_BOARD_STAFF") % [interns, GameConfig.MAX_HELPERS + 1])
	for slot in GameConfig.MAX_HELPERS + 1:
		OfficePainter.desk(_canvas, layout.intern_home(slot) + Vector2(0, 26), false, false, _time)
	_draw_door(layout.office_door())


func _draw_shredder_room(state: GameState) -> void:
	_service_shell(GameConfig.ROOM_SHREDDER, AppTheme.METAL_DARK, Icons.DELETE)
	_draw_board(layout.collectors_board(), tr("BOARD_COLLECTORS"), tr("FMT_BOARD_COLLECTORS") % [state.collectors.size(), GameConfig.MAX_COLLECTORS, Formulas.collector_capacity(state)])
	var shredder := layout.shredder_point()
	OfficePainter.shredder(_canvas, shredder, _shred_time > 0.0, _time)
	var label := Rect2(shredder + Vector2(-64, -90), Vector2(128, 26))
	_rounded(label, AppTheme.SURFACE, 8, AppTheme.OUTLINE, 2)
	_text_centered(label.get_center(), tr("SIGN_SHREDDER"), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE, _bold)
	_draw_door(layout.shredder_door())


func _draw_tech_room(state: GameState) -> void:
	var tubes := state.has_upgrade("pneumatic_tubes")
	_service_shell(GameConfig.ROOM_TECH, AppTheme.RUNNER, Icons.ROOMS.tech_room)
	_draw_board(layout.runners_board(), tr("BOARD_RUNNERS"), tr("FMT_BOARD_STAFF") % [state.runners.size(), GameConfig.MAX_RUNNERS])
	OfficePainter.server_rack(_canvas, layout.server_rect(), tier(state.upgrade_level("it_support") + state.upgrade_level("ai_classification"), int(GameConfig.upgrade("it_support").max) + int(GameConfig.upgrade("ai_classification").max), OfficePainter.SERVER_UNITS), _time)
	OfficePainter.climate_unit(_canvas, layout.climate_rect(), state.upgrade_level("climate_control"), _time)
	OfficePainter.tube_hub(_canvas, layout.tube_hub_point(), tubes, _time)
	if not tubes:
		_icon(layout.tube_hub_point(), Icons.LOCK, 18, AppTheme.ON_SURFACE_VARIANT)
	_text_centered(layout.tube_hub_point() + Vector2(0, 76), tr("SIGN_TUBE_HUB"), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)
	_draw_door(layout.tech_door())


func _draw_tube_slot(state: GameState, room_id: String) -> void:
	if not state.has_upgrade("pneumatic_tubes"):
		return
	var point := layout.tube_station_point(room_id)
	if state.has_tube_station(room_id):
		OfficePainter.tube_station(_canvas, point, _time)
		return
	OfficePainter.empty_slot(_canvas, layout.slot_rect(point))
	_icon(point, Icons.upgrade("tube_station"), 20, Color(AppTheme.OUTLINE, 0.38))


func _draw_shredder_slot(state: GameState, dept_id: String) -> void:
	if GameConfig.is_customs(dept_id):
		return
	var point := layout.dept_shredder_point(dept_id)
	if state.has_upgrade("shredder", dept_id):
		OfficePainter.shredder(_canvas, point + Vector2(0, 22), _shredding.has(dept_id), _time)
		return
	OfficePainter.empty_slot(_canvas, layout.slot_rect(point))
	_icon(point, Icons.upgrade("shredder"), 20, Color(AppTheme.OUTLINE, 0.38))


func _tier(state: GameState, upgrade_id: String, tiers: int) -> int:
	return tier(state.upgrade_level(upgrade_id), int(GameConfig.upgrade(upgrade_id).get("max", 1)), tiers)


static func tier(level: int, max_level: int, tiers: int) -> int:
	if level <= 0 or max_level <= 0:
		return 0
	return clampi(ceili(float(level) * tiers / max_level), 1, tiers)


func _draw_spot_highlight() -> void:
	if _highlight_spot.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(_time * 6.0)
	var color := Color(AppTheme.accent("warning"), 0.5 + pulse * 0.5)
	if _highlight_spot == GameConfig.ROOM_PLAYER:
		_canvas.draw_arc(game.state.player.position, PLAYER_TAP_RADIUS + pulse * 4.0, 0.0, TAU, 32, color, 4.0)
		return
	for rect: Rect2 in layout.spot_rects(_highlight_spot):
		_canvas.draw_rect(rect.grow(6.0 + pulse * 4.0), color, false, 4.0)


func _bubble(pos: Vector2, dept_id: String, urgent: bool) -> void:
	var color := AppTheme.department_color(dept_id)
	_canvas.draw_circle(pos + Vector2(1, 2), 14, AppTheme.SHADOW_SOFT)
	_canvas.draw_circle(pos, 14, AppTheme.SURFACE)
	_canvas.draw_arc(pos, 14, 0, TAU, 24, color, 2.5)
	_icon(pos, Icons.department(dept_id), 17, color)
	if urgent:
		_canvas.draw_circle(pos + Vector2(11, -10), 5, AppTheme.accent("error"))
		_canvas.draw_arc(pos + Vector2(11, -10), 5, 0, TAU, 12, AppTheme.SURFACE, 1.5)


func _slot_unlocked(state: GameState, slot: String) -> bool:
	if slot == "inspection":
		return state.station(GameConfig.INSPECTION) != null
	return state.department(slot).unlocked


func _draw_room(state: GameState, slot: String) -> void:
	var rect := layout.room(slot)
	var color := AppTheme.department_color(slot)
	if not _slot_unlocked(state, slot):
		_draw_locked_room(state, slot, rect)
		return
	var highlight := _highlight_dept == slot and fmod(_time, 0.6) < 0.4
	_rounded(rect, color.lerp(AppTheme.SURFACE, 0.88), ROOM_RADIUS, AppTheme.accent("warning") if highlight else color.darkened(0.15), 5 if highlight else 3, true)
	OfficePainter.tiles(_canvas, Rect2(rect.position + Vector2(10, WorldLayout.HEADER), rect.size - Vector2(20, WorldLayout.HEADER + 12)))
	var header := layout.header(slot)
	var on_band := _on_color(color)
	_rounded(header, color, ROOM_RADIUS, color.darkened(0.15), 3, false, true)
	_canvas.draw_circle(header.position + Vector2(32, 28), 20, on_band)
	_icon(header.position + Vector2(32, 28), Icons.department(slot), 24, color.darkened(0.25))
	_text(header.position + Vector2(62, 36), tr("DEPT_" + slot.to_upper()), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 220)
	_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
	var weakest := ""
	if slot != "inspection":
		var dept := state.department(slot)
		weakest = Formulas.bottleneck(state, dept)
		var stats := tr("FMT_PER_MINUTE") % UiKit.decimal(Formulas.department_throughput(state, dept) * 60.0)
		var size := _bold.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, AppTheme.SIZE_BODY_SMALL)
		_text(Vector2(header.end.x - 44 - size.x, header.position.y + 34), stats, AppTheme.SIZE_BODY_SMALL, on_band, _bold)
		for key in dept.station_keys():
			_draw_station(state, key, weakest)
		_draw_shredder_slot(state, slot)
	else:
		_draw_station(state, GameConfig.INSPECTION, "")
	_draw_tube_slot(state, slot)


func _draw_locked_room(state: GameState, slot: String, rect: Rect2) -> void:
	_rounded(rect, AppTheme.LOCKED_FLOOR, ROOM_RADIUS, Color(AppTheme.WALL, 0.3), 2)
	var x := rect.position.x - rect.size.y
	while x < rect.end.x:
		var start := Vector2(maxf(x, rect.position.x), rect.position.y + maxf(0.0, rect.position.x - x))
		var finish := Vector2(minf(x + rect.size.y, rect.end.x), rect.position.y + minf(rect.size.y, rect.end.x - x))
		_canvas.draw_line(start, finish, AppTheme.HATCH, 2.0)
		x += 34.0
	var color := AppTheme.department_color(slot)
	_canvas.draw_circle(rect.position + Vector2(32, 28), 18, Color(color, 0.5))
	_icon(rect.position + Vector2(32, 28), Icons.department(slot), 22, AppTheme.SURFACE)
	_text(rect.position + Vector2(60, 35), tr("DEPT_" + slot.to_upper()), AppTheme.SIZE_TITLE_MEDIUM, AppTheme.ON_SURFACE_VARIANT, _bold)
	_icon(rect.get_center() + Vector2(0, -50), Icons.LOCK, 34, AppTheme.ON_SURFACE_VARIANT)
	if slot == "inspection":
		_text_centered(rect.get_center(), tr("INSPECTION_LOCKED"), AppTheme.SIZE_BODY_SMALL, AppTheme.ON_SURFACE_VARIANT)
		return
	if Progression.next_locked_department(state) != slot:
		_text_centered(rect.get_center(), tr("LOCKED_LATER"), AppTheme.SIZE_BODY_SMALL, AppTheme.ON_SURFACE_VARIANT)
		return
	var pad := layout.pad_point(slot)
	var reason := Progression.unlock_block_reason(state, slot)
	var accent := AppTheme.accent("primary") if reason.is_empty() else AppTheme.ON_SURFACE_VARIANT
	_canvas.draw_circle(pad, 48, Color(accent, 0.18))
	_canvas.draw_arc(pad, 48, 0, TAU, 40, accent, 3.0)
	_progress_ring(pad, 48.0, 8.0, AppTheme.MONEY, func() -> float: return state.player.pad_progress / GameConfig.PAD_TIME if state.player.pad_dept == slot else 0.0)
	_icon(pad + Vector2(0, -12), Icons.PAID, 22, accent)
	_text_centered(pad + Vector2(0, 14), UiKit.money(float(GameConfig.department(slot).unlock_cost)), AppTheme.SIZE_TITLE_SMALL, accent, _bold)
	_text_centered(rect.get_center() + Vector2(0, -6), _requirement_text(state, slot, reason), AppTheme.SIZE_BODY_SMALL, AppTheme.ON_SURFACE_VARIANT)


func _requirement_text(state: GameState, slot: String, reason: String) -> String:
	match reason:
		"space":
			return tr("REQ_MORE_SPACE")
		"reputation":
			return tr("FMT_REQ_REPUTATION") % int(GameConfig.department(slot).unlock_reputation)
		"money":
			return tr("PAD_NEED_MONEY")
	return tr("PAD_STAND_HERE") if state.player.pad_dept != slot else tr("PAD_OPENING")


func _draw_station(state: GameState, key: String, weakest: String) -> void:
	var station := state.station(key)
	if station == null:
		return
	var area := layout.area(key)
	var color := AppTheme.department_color(station.dept_id if not station.dept_id.is_empty() else ("inspection" if key == GameConfig.INSPECTION else "shared"))
	var border := AppTheme.accent("warning") if weakest == key else Color(color, 0.45)
	_rounded(area, Color(AppTheme.SURFACE, 0.78), AREA_RADIUS, border, 4 if weakest == key else 2)
	_rounded(Rect2(area.position + Vector2(2, 2), Vector2(area.size.x - 4, 32)), Color(color, 0.2), AREA_RADIUS - 2, Color.TRANSPARENT, 0, false, true)
	_icon(area.position + Vector2(20, 18), Icons.station_for(key), 20, color.darkened(0.2))
	_text(area.position + Vector2(38, 24), _station_label(key), AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.ON_SURFACE, _bold, area.size.x - 90)
	var level := "L%d" % station.level
	var level_size := _bold.get_string_size(level, HORIZONTAL_ALIGNMENT_LEFT, -1, AppTheme.SIZE_LABEL_SMALL)
	_text(Vector2(area.end.x - 12 - level_size.x, area.position.y + 24), level, AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE, _bold)
	for desk in station.jobs.size():
		_draw_desk(station, desk, layout.desk_position(key, desk), color)
	if not station.is_entry():
		_tray(layout.input_point(key), station.inbox, station.inbox_capacity(state.lobby_capacity()), Icons.INBOX)
	if not station.is_final():
		_tray(layout.output_point(key), station.outbox, station.outbox_capacity(), Icons.OUTBOX)
	if station.has_reject_pile():
		_reject_tray(layout.reject_point(key), station.rejects)
	if Formulas.event_speed(state, station) < 1.0:
		_icon(Vector2(area.end.x - 66, area.position.y + 18), str(Icons.EVENTS.get(state.event_id, Icons.BOLT)), 18, AppTheme.accent("warning"))
	if station.kind == "dock":
		for i in mini(station.inbox.size(), 3):
			ItemPainter.draw_truck(_canvas, Vector2(area.position.x + 50, area.position.y + 90 + i * 70))
		if station.inbox.size() > 3:
			_text(Vector2(area.position.x + 20, area.end.y - 70), "+%d" % (station.inbox.size() - 3), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)
	if station.needs_manual_work():
		var spot := layout.work_point(key)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_canvas.draw_circle(spot, 22 + pulse * 4.0, Color(AppTheme.accent("primary"), 0.18))
		_canvas.draw_arc(spot, 22 + pulse * 4.0, 0, TAU, 28, AppTheme.accent("primary"), 2.0)
		_icon(spot, Icons.PERSON, 18, AppTheme.accent("primary"))


func _station_label(key: String) -> String:
	var kind := GameConfig.station_kind_of(key)
	if kind == "signature" or (kind == "review" and not GameConfig.station_dept(key).is_empty()):
		return tr(("STATION_%s_%s" % [GameConfig.station_dept(key), kind]).to_upper())
	return tr("STATION_SHORT_" + kind.to_upper())


func _draw_desk(station: Station, desk: int, pos: Vector2, color: Color) -> void:
	var job := station.jobs[desk]
	var active := job != null
	if station.machine:
		OfficePainter.machine(_canvas, GameConfig.station_dept(station.key), pos, color, active, _time)
	else:
		var specialist := station.is_specialist_desk(desk)
		var occupied := specialist or station.is_staffed(desk)
		var mood := station.moods[desk]
		var asleep := occupied and mood.state == DeskMood.ASLEEP
		var present := occupied and not mood.is_absent() and not is_desk_hidden(station.key, desk)
		OfficePainter.desk(_canvas, pos, present, active and not mood.is_resting(), _time, specialist)
		if specialist and present:
			ItemPainter.draw_person(_canvas, pos + Vector2(0, -24), AppTheme.SPECIALIST_COAT, 0.85, Color.TRANSPARENT, desk + 3, AppTheme.SPECIALIST, asleep, true)
		elif present:
			ItemPainter.draw_person(_canvas, pos + Vector2(0, -24), AppTheme.STAFF_COLOR, 0.85, Color.TRANSPARENT, desk, AppTheme.TIE, asleep)
		if occupied and mood.is_resting():
			_draw_rest(pos, mood)
		if occupied and station.can_cover(desk):
			_draw_cover_hint(pos)
		if occupied and mood.is_sick():
			_draw_sick_timer(pos, mood)
	if job != null:
		var bar := Rect2(pos + Vector2(-28, 24), Vector2(56, 7))
		_rounded(bar, AppTheme.SURFACE_3, 3, AppTheme.OUTLINE, 1)
		var fill := AppTheme.accent("success")
		if job.is_done():
			fill = AppTheme.accent("error")
		elif job.case_file.urgent:
			fill = AppTheme.accent("warning")
		_rounded(Rect2(bar.position, Vector2(maxf(6.0, bar.size.x * job.ratio()), bar.size.y)), fill, 3)
		ItemPainter.draw_item(_canvas, pos + Vector2(-20, -14), job.case_file)


func _draw_cover_hint(pos: Vector2) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var spot := pos + Vector2(0, -24)
	_canvas.draw_circle(spot, 16 + pulse * 3.0, Color(AppTheme.accent("primary"), 0.18))
	_canvas.draw_arc(spot, 16 + pulse * 3.0, 0, TAU, 24, AppTheme.accent("primary"), 2.0)
	_icon(spot, Icons.PERSON, 16, AppTheme.accent("primary"))


func _mood_ratio(mood: DeskMood, ratio: Callable) -> Callable:
	var shown := mood.state
	return func() -> float: return float(ratio.call()) if mood.state == shown else 0.0


func _draw_sick_timer(pos: Vector2, mood: DeskMood) -> void:
	var text := tr("FMT_SICK_RETURN") % NumberFormat.clock(Formulas.sick_time_left(game.state, mood))
	_text_centered_outlined(pos + Vector2(0, 46), text, AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error"), AppTheme.SURFACE, _bold)
	if mood.bonus > 0:
		_icon(pos + Vector2(-30, -4), Icons.PAID, 14 + mood.bonus * 3, AppTheme.MONEY)


func _draw_rest(pos: Vector2, mood: DeskMood) -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	var ring := pos + Vector2(0, -8)
	if mood.needs_help() and not mood.is_away():
		_canvas.draw_arc(ring, 36.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("warning"), 0.5 + pulse * 0.4), 3.0)
	if mood.is_sick():
		_canvas.draw_arc(ring, 36.0, 0, TAU, 32, Color(AppTheme.accent("error"), 0.35), 3.0)
	_progress_ring(ring, 36.0, 6.0, AppTheme.accent("success"), _mood_ratio(mood, func() -> float: return 0.0 if mood.is_away() else mood.wake_progress / GameConfig.WAKE_TIME))
	var bob := sin(_time * 3.0) * 3.0
	var bubble := pos + Vector2(26, -56 + bob)
	_canvas.draw_circle(bubble + Vector2(1, 2), 17, AppTheme.SHADOW_SOFT)
	_canvas.draw_circle(bubble, 17, AppTheme.SURFACE)
	_canvas.draw_arc(bubble, 17, 0, TAU, 24, AppTheme.accent("warning"), 2.5)
	if mood.state == DeskMood.LOO:
		_text_centered(bubble, "WC", AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.accent("tertiary"), _bold)
	elif mood.state == DeskMood.SICK:
		_canvas.draw_rect(Rect2(bubble + Vector2(-3, -10), Vector2(6, 20)), AppTheme.accent("error"))
		_canvas.draw_rect(Rect2(bubble + Vector2(-10, -3), Vector2(20, 6)), AppTheme.accent("error"))
	elif mood.state == DeskMood.CHAT:
		_icon(bubble, Icons.FORUM, 22, AppTheme.accent("tertiary"))
	elif mood.state == DeskMood.FETCH:
		_icon(bubble, Icons.WALK, 22, AppTheme.accent("success"))
	elif mood.state == DeskMood.SLOW:
		_icon(bubble, Icons.WALK, 22, AppTheme.accent("warning"))
	elif mood.state == DeskMood.COFFEE:
		_icon(bubble, Icons.COFFEE, 22, AppTheme.WOOD_DARK)
		for i in 2:
			var drift := fmod(_time * 1.5 + i * 0.5, 1.0)
			_canvas.draw_circle(bubble + Vector2(-4 + i * 8, -20 - drift * 10), 2.5, Color(AppTheme.OUTLINE, 1.0 - drift))
	else:
		_text_centered(bubble, "Zzz", AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.accent("primary"), _bold)


func _tray(point: Vector2, items: Array[CaseFile], capacity: int, icon: String) -> void:
	var full := items.size() >= capacity
	_rounded(Rect2(point + Vector2(-26, -6), Vector2(52, 22)), AppTheme.SIGN_BOARD, 6, AppTheme.accent("error") if full else AppTheme.WALL, 2 if full else 1)
	_icon(point + Vector2(0, 5), icon, 16, Color(AppTheme.SURFACE, 0.9))
	ItemPainter.draw_stack(_canvas, point + Vector2(0, -8), items, 8)
	_text_outlined(point + Vector2(30, 14), "%d/%d" % [items.size(), capacity], AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error") if full else AppTheme.ON_SURFACE, AppTheme.SURFACE, _bold)


func _reject_tray(point: Vector2, count: int) -> void:
	var full := count >= GameConfig.REJECT_CAPACITY
	_rounded(Rect2(point + Vector2(-26, -6), Vector2(52, 22)), AppTheme.SIGN_BOARD, 6, AppTheme.accent("error") if full else AppTheme.accent("warning"), 2)
	_icon(point + Vector2(0, 5), Icons.CLOSE, 16, Color(AppTheme.SURFACE, 0.9))
	OfficePainter.complaint_pile(_canvas, point + Vector2(0, -8), count)
	_text_outlined(point + Vector2(-24, 28), "%d/%d" % [count, GameConfig.REJECT_CAPACITY], AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error") if full else AppTheme.ON_SURFACE, AppTheme.SURFACE, _bold)


func _tube_layout_signature(state: GameState) -> int:
	var parts: Array = [state.has_upgrade("pneumatic_tubes"), state.has_upgrade("complaint_tube"), state.unlocked_count()]
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		parts.append(state.has_upgrade("tube_station", room_id))
	return hash(parts)


static func tube_pairs(state: GameState) -> Array[String]:
	var result: Array[String] = []
	for dept in state.unlocked_departments():
		var route := RouteBuilder.build(CaseFile.new(dept.id))
		for i in route.size() - 1:
			var pair := "%s>%s" % [route[i], route[i + 1]]
			if not result.has(pair) and state.tube_link(route[i], route[i + 1]):
				result.append(pair)
	return result


func _draw_tubes(state: GameState) -> void:
	if state.has_upgrade("complaint_tube"):
		_draw_tube(layout.complaint_tube_path())
	for pair in tube_pairs(state):
		_draw_tube(layout.tube_path(pair.get_slice(">", 0), pair.get_slice(">", 1)))


func _draw_tube(path: PackedVector2Array) -> void:
	_canvas.draw_polyline(path, AppTheme.METAL_DARK, 10.0)
	_canvas.draw_polyline(path, AppTheme.METAL, 6.0)
	var length := WorldLayout.path_length(path)
	var start := TUBE_WINDOW_SPACING * 0.5
	while start + TUBE_WINDOW_LENGTH < length:
		_canvas.draw_line(WorldLayout.path_point(path, start), WorldLayout.path_point(path, start + TUBE_WINDOW_LENGTH), AppTheme.WINDOW, 6.0)
		start += TUBE_WINDOW_SPACING


func _draw_capsules(view: Rect2) -> void:
	for capsule in _capsules:
		var distance: float = capsule.t * float(capsule.get("speed", TUBE_SPEED))
		var phase := fposmod(distance - TUBE_WINDOW_SPACING * 0.5, TUBE_WINDOW_SPACING)
		if phase > TUBE_WINDOW_LENGTH:
			continue
		var path: PackedVector2Array = capsule.path
		var center := WorldLayout.path_point(path, distance)
		if not view.has_point(center):
			continue
		var head := WorldLayout.path_point(path, distance + 8.0)
		var tail := WorldLayout.path_point(path, distance - 8.0)
		_canvas.draw_line(tail, head, capsule.color, 7.0)
		_canvas.draw_line(tail, head, (capsule.color as Color).lightened(0.4), 2.5)


func _draw_player(player: Player) -> void:
	var bob := sin(_time * 14.0) * 1.5 if player.input.length_squared() > 0.0 else 0.0
	_canvas.draw_circle(player.position + Vector2(0, 16), 14, Color(AppTheme.ON_SURFACE, 0.12))
	ItemPainter.draw_person(_canvas, player.position + Vector2(0, bob), AppTheme.PLAYER, 1.2, AppTheme.PLAYER_HAT, 3, AppTheme.TIE)
	ItemPainter.draw_stack(_canvas, player.position + Vector2(0, -32 + bob), player.items, 12)
	if player.complaints > 0:
		OfficePainter.complaint_pile(_canvas, player.position + Vector2(24, -8 + bob), player.complaints)
		_text_centered_outlined(player.position + Vector2(24, -22 + bob), str(player.complaints), AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error"), AppTheme.SURFACE, _bold)
	if player.rejects > 0:
		OfficePainter.complaint_pile(_canvas, player.position + Vector2(-24, -8 + bob), player.rejects)
		_text_centered_outlined(player.position + Vector2(-24, -22 + bob), str(player.rejects), AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("warning"), AppTheme.SURFACE, _bold)
	if player.items.size() >= Formulas.carry_capacity(game.state):
		_text_centered_outlined(player.position + Vector2(0, 38), tr("LABEL_HANDS_FULL"), AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.accent("error"), AppTheme.SURFACE, _bold)


func _draw_guidance() -> void:
	if _guidance.is_empty():
		return
	var point: Vector2 = _guidance.point
	var view := view_rect().grow(-30)
	var accent := AppTheme.accent("primary")
	if view.has_point(point):
		var bounce := sin(_time * 6.0) * 6.0
		var tip := point + Vector2(0, -44 + bounce)
		_canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -20), tip + Vector2(14, -20)]), accent)
		_canvas.draw_arc(point, 30, 0, TAU, 32, Color(accent, 0.6), 3.0)
		return
	var from := camera
	var direction := from.direction_to(point)
	var edge := _edge_point(view, from, direction)
	var side := direction.orthogonal() * 12.0
	_canvas.draw_colored_polygon(PackedVector2Array([edge + direction * 18.0, edge - direction * 6.0 + side, edge - direction * 6.0 - side]), accent)


func _edge_point(rect: Rect2, from: Vector2, direction: Vector2) -> Vector2:
	var t := INF
	if absf(direction.x) > 0.001:
		t = minf(t, ((rect.end.x if direction.x > 0.0 else rect.position.x) - from.x) / direction.x)
	if absf(direction.y) > 0.001:
		t = minf(t, ((rect.end.y if direction.y > 0.0 else rect.position.y) - from.y) / direction.y)
	return from + direction * t


func _draw_effects() -> void:
	var view := view_rect().grow(CULL_MARGIN)
	_draw_capsules(view)
	for walker in _walkers:
		var t: float = walker.t / walker.duration
		var eased := t if bool(walker.get("linear", false)) or str(walker.kind) == "staff" else t * t * (3.0 - 2.0 * t)
		var pos: Vector2 = (walker.from as Vector2).lerp(walker.to, eased)
		if not view.has_point(pos):
			continue
		match str(walker.kind):
			"car":
				ItemPainter.draw_car(_canvas, pos, AppTheme.CAR)
			"truck":
				ItemPainter.draw_truck(_canvas, pos)
			"leave":
				ItemPainter.draw_person_lite(_canvas, pos, walker.color, 0.9, int(walker.look))
				ItemPainter.draw_output(_canvas, pos + Vector2(14, -4), walker.dept)
			"staff":
				ItemPainter.draw_person(_canvas, pos + Vector2(0, -absf(sin(t * walker.duration * 7.0)) * 3.0), walker.color, 1.0, Color.TRANSPARENT, int(walker.look), walker.tie, false, walker.expert)
			"exit":
				ItemPainter.draw_person_lite(_canvas, pos + Vector2(0, -absf(sin(t * walker.duration * 9.0)) * 3.0), walker.color, 0.9, int(walker.look))
			"postman":
				ItemPainter.draw_person(_canvas, pos, AppTheme.POST_YELLOW, 1.0, AppTheme.POST_YELLOW.darkened(0.3), int(walker.look))
				ItemPainter.draw_letter(_canvas, pos + Vector2(16, 0), AppTheme.POST_YELLOW)
			_:
				ItemPainter.draw_person_lite(_canvas, pos, walker.color, 1.0, int(walker.look))
				_bubble(pos + Vector2(0, -26), walker.dept, false)
	for floater in _floaters:
		var progress: float = floater.t / floater.duration
		var pos: Vector2 = floater.pos + Vector2(0, -50.0 * progress)
		if not view.has_point(pos):
			continue
		var fade := 1.0 - progress * progress
		_text_centered_outlined(pos, floater.text, int(floater.size), Color(floater.color, fade), Color(AppTheme.SURFACE, fade), _bold)
