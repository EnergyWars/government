class_name WorldView
extends Node2D

signal open_department(dept_id: String)
signal open_departments
signal open_room(room_id: String)
signal open_complaints

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
const TUBES_LAYER := "_tubes"
const TUBE_SPEED := GameConfig.TUBE_SPEED
const COMPLAINT_TUBE_SPEED := 110.0
const TUBE_WINDOW_SPACING := 170.0
const TUBE_WINDOW_LENGTH := 34.0
const MAX_CAPSULES := 40
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
	sim.case_arrived.connect(_on_case_arrived)
	sim.case_completed.connect(_on_case_completed)
	sim.citizen_left.connect(_on_citizen_left)
	sim.contraband_found.connect(func(_dept_id: String) -> void: _float(layout.area("customs/signature").get_center(), tr("FLOAT_SEIZED"), AppTheme.accent("error")))
	sim.smuggling_missed.connect(func(_dept_id: String) -> void: _float(layout.area("customs/clearance").get_center(), tr("FLOAT_SMUGGLED"), AppTheme.accent("error")))
	sim.employee_dozed.connect(_on_employee_dozed)
	sim.mail_delivered.connect(_on_mail_delivered)
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
	sim.complaint_piped.connect(_on_complaint_piped)
	sim.review_posted.connect(_on_review_posted)
	sim.review_removed.connect(_on_review_removed)
	sim.case_piped.connect(_on_case_piped)
	sim.intern_broke_down.connect(_on_intern_broke_down)
	sim.intern_recovered.connect(_on_intern_recovered)
	sim.coffee_served.connect(_on_coffee_served)
	sim.dispute_started.connect(_on_dispute_started)
	sim.dispute_ended.connect(_on_dispute_ended)
	sim.department_unlocked.connect(func(dept_id: String) -> void: focus(dept_id))


func focus(slot: String) -> void:
	_focus_point = layout.room(slot).get_center()
	_focus_left = FOCUS_TIME
	_highlight_dept = slot


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
	if layout.complaint_read_rect().has_point(point):
		open_complaints.emit()
		return
	var room_id := layout.header_at(point)
	if room_id.is_empty():
		return
	if GameConfig.department(room_id).is_empty():
		if UpgradeCards.has_upgrades(game.state, room_id):
			open_room.emit(room_id)
	elif game.state.department(room_id).unlocked:
		open_department.emit(room_id)
	else:
		open_departments.emit()


func _advance_effects(delta: float) -> void:
	_shred_time = maxf(0.0, _shred_time - delta)
	for return_key in _returning.keys():
		_returning[return_key] = float(_returning[return_key]) - delta
		if float(_returning[return_key]) <= 0.0:
			_returning.erase(return_key)
	for list: Array[Dictionary] in [_walkers, _floaters, _capsules]:
		var index := list.size() - 1
		while index >= 0:
			list[index].t += delta
			if list[index].t >= list[index].duration:
				list.remove_at(index)
			index -= 1


func _float(pos: Vector2, text: String, color: Color, size: int = 24) -> void:
	_floaters.append({"pos": pos, "text": text, "color": color, "size": size, "t": 0.0, "duration": FLOAT_TIME})


func _float_flavor(pos: Vector2, flawed: bool, color: Color) -> void:
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(pos, Flavor.flawed(_flavor_count) if flawed else Flavor.done(_flavor_count), color, AppTheme.SIZE_TITLE_SMALL)


func _walker(from: Vector2, to: Vector2, kind: String, dept_id: String, duration: float = WALK_TIME) -> void:
	if _walkers.size() > 40:
		return
	_walkers.append({"from": from, "to": to, "kind": kind, "dept": dept_id, "t": 0.0, "duration": duration, "look": _walkers.size() + _flavor_count, "color": AppTheme.CITIZEN_COLORS[_walkers.size() % AppTheme.CITIZEN_COLORS.size()]})


func _on_case_arrived(dept_id: String) -> void:
	if GameConfig.is_customs(dept_id):
		return
	var queue := game.state.station(GameConfig.RECEPTION).inbox.size()
	_walker(layout.door_in(), layout.queue_point(maxi(0, queue - 1)), "arrive", dept_id, 1.4)


func _on_mail_delivered(count: int, returned: int) -> void:
	if count + returned <= 0:
		return
	_walker(layout.mail_street(), layout.mail_drop_point(), "postman", "", 2.0)
	if count > 0:
		_float(layout.mail_drop_point() + Vector2(0, -40), tr("FMT_FLOAT_MAIL") % count, AppTheme.accent("primary"))
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
	_walker(Vector2(counter.get_center().x, counter.end.y + 20), layout.door_out(), "leave", dept_id)


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


func _start_return_walk(key: String, desk: int) -> void:
	var station := game.state.station(key)
	if station == null or desk >= station.moods.size():
		return
	var left := station.moods[desk].left_slot
	if left < 0:
		return
	var from := layout.slot_point(left)
	var to := layout.desk_position(key, desk) + Vector2(0, -24)
	var duration := clampf(from.distance_to(to) / RETURN_SPEED, 0.8, 6.0)
	_returning["%s#%d" % [key, desk]] = duration
	_walkers.append({"from": from, "to": to, "kind": "return", "dept": "", "t": 0.0, "duration": duration, "color": AppTheme.SPECIALIST_COAT if station.is_specialist_desk(desk) else AppTheme.STAFF_COLOR, "look": desk})


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


func _on_intern_broke_down() -> void:
	_float(game.state.intern.position + Vector2(0, -60), tr("FLOAT_INTERN_BREAKDOWN"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)


func _on_intern_recovered(by_player: bool) -> void:
	_float(layout.intern_home() + Vector2(0, -60), tr("FLOAT_INTERN_COMFORTED" if by_player else "FLOAT_INTERN_BACK"), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_coffee_served(key: String, desk: int) -> void:
	_flavor_count += 1
	if _floaters.size() > MAX_FLAVOR_FLOATERS:
		return
	_float(layout.desk_position(key, desk) + Vector2(0, -76), Flavor.coffee_served(_flavor_count), AppTheme.accent("tertiary"), AppTheme.SIZE_TITLE_SMALL)


func _on_dispute_started(_kind: String, dept_id: String) -> void:
	_float(layout.dispute_point(dept_id) + Vector2(0, -90), tr("FLOAT_DISPUTE_START"), AppTheme.accent("error"), AppTheme.SIZE_TITLE_SMALL)


func _on_dispute_ended(_kind: String, dept_id: String, by_player: bool) -> void:
	_float(layout.dispute_point(dept_id) + Vector2(0, -90), tr("FLOAT_DISPUTE_PEACE" if by_player else "FLOAT_DISPUTE_OVER"), AppTheme.accent("success"), AppTheme.SIZE_TITLE_SMALL)


func _on_case_piped(from_key: String, to_key: String, dept_id: String) -> void:
	if _capsules.size() >= MAX_CAPSULES or to_key.is_empty():
		return
	var path := layout.tube_path(from_key, to_key)
	var length := WorldLayout.path_length(path)
	_capsules.append({"path": path, "color": AppTheme.department_color(dept_id), "t": 0.0, "duration": maxf(0.2, length / TUBE_SPEED)})


func _on_citizen_left(dept_id: String) -> void:
	if GameConfig.is_customs(dept_id):
		return
	_float(layout.queue_point(0) + Vector2(0, -30), tr("FLOAT_CITIZEN_LEFT"), AppTheme.accent("error"))
	_walker(layout.queue_point(0), layout.door_out(), "angry", dept_id, 1.6)


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
	_draw_visitors(state, view)
	_draw_complaint_intern(state, view)
	_draw_coffee_interns(state, view)
	_draw_disputes(state, view)
	_draw_effects()
	_canvas = self


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
	var stopped := false
	for visitor in state.visitors:
		if not view.has_point(visitor.position):
			continue
		var talking := visitor.phase == ComplaintVisitor.Phase.TALKING
		if visitor.phase == ComplaintVisitor.Phase.STOPPED and not stopped:
			stopped = true
			_draw_stopped_visitor(visitor, visitor.position)
		var bob := 0.0 if talking or visitor.phase == ComplaintVisitor.Phase.STOPPED else -absf(sin(_time * 9.0 + visitor.slot)) * 3.0
		var shake := sin(_time * 40.0) * 1.5 if visitor.angry and talking else 0.0
		var pos := visitor.position + Vector2(shake, bob)
		var body: Color = AppTheme.accent("error") if visitor.angry else AppTheme.CITIZEN_COLORS[visitor.look % AppTheme.CITIZEN_COLORS.size()]
		ItemPainter.draw_person(_canvas, pos, body, 1.0, Color.TRANSPARENT, visitor.look)
		if visitor.angry:
			_icon(pos + Vector2(16, -30), Icons.PRIORITY, 18, AppTheme.accent("error"))
		if talking and not spoke:
			spoke = true
			var tip := pos + Vector2(0, -28) if visitor.visitor_speaks() else _clerk_tip()
			_speech(tip, Flavor.visit_line(visitor.angry, visitor.dialog, visitor.line()))


func _visitor_speaking(state: GameState) -> bool:
	for visitor in state.visitors:
		if visitor.phase == ComplaintVisitor.Phase.TALKING:
			return true
	return false


func _draw_complaint_intern(state: GameState, view: Rect2) -> void:
	if not state.has_research("shredder_service"):
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


func _draw_disputes(state: GameState, view: Rect2) -> void:
	for dispute in state.disputes:
		var point := layout.dispute_point(dispute.dept_id)
		if not view.has_point(point):
			continue
		var look := absi(dispute.dept_id.hash()) % 12
		var shake := sin(_time * 22.0) * 1.2
		ItemPainter.draw_person(_canvas, point + Vector2(-26 + shake, 0), AppTheme.STAFF_COLOR, 1.0, Color.TRANSPARENT, look, AppTheme.TIE)
		ItemPainter.draw_person(_canvas, point + Vector2(26 - shake, 0), AppTheme.STAFF_COLOR, 1.0, Color.TRANSPARENT, look + 5, AppTheme.TIE)
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		_canvas.draw_arc(point, 44.0 + pulse * 3.0, 0, TAU, 32, Color(AppTheme.accent("error"), 0.5 + pulse * 0.4), 3.0)
		_canvas.draw_circle(point + Vector2(0, -6), 14, AppTheme.accent("error"))
		_icon(point + Vector2(0, -6), Icons.DISPUTES[dispute.kind], 18, AppTheme.on_accent("error"))
		_progress_ring(point, 44.0, 6.0, AppTheme.accent("success"), func() -> float: return dispute.progress / GameConfig.MEDIATE_TIME)
		var turn := int(_time / 2.5)
		_speech(point + Vector2(-26 if turn % 2 == 0 else 26, -28), Flavor.dispute_line(dispute.kind, turn))
		var label := tr("FMT_DISPUTE") % [tr("DISPUTE_" + dispute.kind.to_upper()), roundi((1.0 - dispute.speed()) * 100.0)]
		_text_centered_outlined(point + Vector2(0, 50), label, AppTheme.SIZE_LABEL_SMALL, AppTheme.accent("error"), AppTheme.SURFACE, _bold)


func _draw_actors() -> void:
	if game == null:
		return
	_canvas = _actors
	var state := game.state
	_draw_live_rings()
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
	_draw_hall_sign(layout.queue_sign_rect(), "FMT_WAITING_SIGN", state.station(GameConfig.RECEPTION).inbox.size(), state.lobby_capacity())
	_draw_hall_sign(layout.seating_sign_rect(), "FMT_SEATING_SIGN", state.seated_citizens(), state.seat_capacity())


func _draw_hall_sign(rect: Rect2, format_key: String, used: int, capacity: int) -> void:
	var full := used >= capacity
	_rounded(rect, AppTheme.accent("error") if full else AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(rect.get_center(), tr(format_key) % [used, capacity], AppTheme.SIZE_LABEL_SMALL, AppTheme.on_accent("error") if full else AppTheme.SIGN_TEXT, _bold)


func _draw_hall(state: GameState, view: Rect2) -> void:
	_draw_complaint_corner(state)
	_draw_waiting_sign(state)
	_draw_station(state, GameConfig.RECEPTION, "")
	_draw_station(state, GameConfig.COUNTER, "")
	_draw_hall_furnishing(state, view)
	var reception := state.station(GameConfig.RECEPTION)
	var patience := Formulas.patience(state)
	for i in mini(reception.inbox.size(), GameConfig.MAX_LOBBY_SLOTS):
		var case_file := reception.inbox[i]
		var pos := layout.queue_point(i)
		if not view.has_point(pos):
			continue
		var mood := clampf(case_file.waited / patience, 0.0, 1.0)
		ItemPainter.draw_person_lite(_canvas, pos, AppTheme.CITIZEN_COLORS[i % AppTheme.CITIZEN_COLORS.size()], 0.9, i)
		_canvas.draw_arc(pos + Vector2(0, 7), 12, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - mood), 16, AppTheme.accent("success").lerp(AppTheme.accent("error"), mood), 2.0)
		if i < 12:
			_bubble(pos + Vector2(0, -26), case_file.dept_id, case_file.urgent)
	for i in mini(state.seated_citizens(), state.seat_capacity()):
		if view.has_point(layout.waiting_seat(i)):
			ItemPainter.draw_person_lite(_canvas, layout.waiting_seat(i), AppTheme.CITIZEN_COLORS[(i + 3) % AppTheme.CITIZEN_COLORS.size()], 0.8, i + 3)
	if not reception.inbox.is_empty():
		_speech(layout.queue_point(0) + Vector2(0, -30), Flavor.quip(int(_time / 5.0)))


func _draw_hall_furnishing(state: GameState, view: Rect2) -> void:
	_sync_pop(_seat_born, state.seat_capacity())
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
	OfficePainter.coffee_machine(_canvas, layout.coffee_machine_point() + Vector2(0, 20), state.research_level("coffee"), fetching, _time, state.research_level("coffee_machine"))
	OfficePainter.kitchen_table(_canvas, origin + Vector2(700, 185))
	var board := Rect2(origin + Vector2(560, 62), Vector2(220, 30))
	_rounded(board, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(board.get_center(), tr("SIGN_COFFEE_FUND"), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	var rules := Rect2(origin + Vector2(560, 96), Vector2(220, 30))
	_rounded(rules, AppTheme.SURFACE, 8, AppTheme.OUTLINE, 2)
	_text_centered(rules.get_center(), tr("SIGN_KITCHEN_RULES"), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE, _bold)
	OfficePainter.plant(_canvas, origin + Vector2(865, 150), 1.1)
	for i in state.research_level("kitchen"):
		OfficePainter.plant(_canvas, origin + Vector2(470 + 44 * i, 135), 0.8)
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
	_text(header.position + Vector2(24, 36), tr("AREA_TOILETS"), AppTheme.SIZE_TITLE_MEDIUM, on_band, _bold, header.size.x - 40)
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
	var room := state.mailroom()
	if room == null:
		_text_centered(rect.get_center(), tr("FMT_MAIL_LOCKED") % (GameConfig.MAIL_UNLOCK_STAGE + 1), AppTheme.SIZE_TITLE_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)
		return
	OfficePainter.mailbox(_canvas, layout.mail_door() + Vector2(40, 0))
	var storage := layout.mail_storage_rect()
	OfficePainter.mail_shelf(_canvas, storage, room.inbox.size(), room.storage_capacity())
	_draw_hall_sign(Rect2(storage.position + Vector2(0, storage.size.y + 6), Vector2(storage.size.x, 26)), "FMT_MAIL_SHELF_SIGN", room.inbox.size(), room.storage_capacity())
	_draw_station(state, GameConfig.MAILROOM, "")
	var sign_rect := Rect2(layout.mail_desk_point() + Vector2(-110, -40), Vector2(220, 26))
	_rounded(sign_rect, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(sign_rect.get_center(), tr("SIGN_MAIL_%d" % (int(_time / 6.0) % 3 + 1)), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	_text_centered(layout.mail_desk_point() + Vector2(0, 20), tr("FMT_MAIL_NEXT") % ceili(state.mail_timer), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)


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
	var occupied: Array[bool] = []
	for i in GameConfig.LOO_SLOTS:
		occupied.append(state.kitchen_slot_taken(GameConfig.KITCHEN_SLOTS + i))
	OfficePainter.toilet_stalls(_canvas, origin, occupied)


func _draw_kitchen_guest(station: Station, desk: int, mood: DeskMood, with_quip: bool) -> void:
	var pos := layout.slot_point(mood.slot)
	if mood.state == DeskMood.LOO:
		_draw_loo_guest(pos, mood, with_quip)
		return
	var expert := station.is_specialist_desk(desk)
	ItemPainter.draw_person(_canvas, pos, AppTheme.SPECIALIST_COAT if expert else AppTheme.STAFF_COLOR, 1.0, Color.TRANSPARENT, desk + mood.slot, AppTheme.SPECIALIST if expert else AppTheme.TIE, false, expert)
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
	var plate := Rect2(Vector2(hall.get_center().x - 170.0, hall.position.y + 6.0), Vector2(340, 30))
	_rounded(plate, AppTheme.SIGN_BOARD, 10, AppTheme.WALL, 2, true)
	_text_centered(plate.get_center(), tr("SIGN_BUILDING"), AppTheme.SIZE_TITLE_SMALL, AppTheme.SIGN_TEXT, _bold)
	_text(Vector2(plate.end.x + 18.0, plate.position.y + 24.0), tr("AREA_PUBLIC"), AppTheme.SIZE_BODY_SMALL, AppTheme.ON_SURFACE_VARIANT, _bold)
	OfficePainter.clock(_canvas, hall.position + Vector2(52, 40), 22.0)
	OfficePainter.cabinet(_canvas, Rect2(hall.position + Vector2(18, 76), Vector2(60, 108)))
	var board := Rect2(hall.position + Vector2(6, 202), Vector2(88, 96))
	_rounded(board, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(board.position + Vector2(44, 18), tr("SIGN_HOURS_TITLE"), AppTheme.SIZE_LABEL_SMALL - 1, AppTheme.FLAG_GOLD, _bold)
	_canvas.draw_multiline_string(_bold, board.position + Vector2(4, 42), tr("SIGN_HOURS_TEXT"), HORIZONTAL_ALIGNMENT_CENTER, board.size.x - 8, AppTheme.SIZE_LABEL_SMALL - 1, 3, AppTheme.SIGN_TEXT)
	OfficePainter.flag(_canvas, Vector2(hall.end.x - 96.0, hall.position.y + 160.0), 120.0, _time)
	OfficePainter.ticket_dispenser(_canvas, Vector2(hall.end.x - 56.0, hall.position.y + 216.0))
	_canvas.draw_multiline_string(_bold, Vector2(hall.end.x - 100.0, hall.position.y + 270.0), tr("SIGN_TICKET"), HORIZONTAL_ALIGNMENT_CENTER, 90.0, AppTheme.SIZE_LABEL_SMALL - 1, 2, AppTheme.ON_SURFACE)
	OfficePainter.plant(_canvas, Vector2(hall.position.x + 50.0, hall.end.y - 30.0), 1.2)
	OfficePainter.plant(_canvas, Vector2(hall.end.x - 40.0, hall.position.y + 380.0), 1.2)
	_draw_closed_sign(layout.closed_sign_rect())


func _draw_closed_sign(rect: Rect2) -> void:
	ItemPainter.shadow(_canvas, Vector2(rect.get_center().x, rect.end.y + 4.0), rect.size.x * 0.4, 5)
	for leg in [rect.position.x + 18.0, rect.end.x - 18.0]:
		_canvas.draw_line(Vector2(leg, rect.end.y - 6.0), Vector2(leg, rect.end.y + 6.0), AppTheme.WOOD_DARK, 4.0)
	_rounded(rect, AppTheme.FLAG_RED, 8, AppTheme.FLAG_RED.darkened(0.3), 2)
	_canvas.draw_multiline_string(_bold, rect.position + Vector2(6, 15), tr("SIGN_CLOSED"), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12.0, AppTheme.SIZE_LABEL_SMALL - 3, 3, AppTheme.SURFACE)


func _draw_complaint_corner(state: GameState) -> void:
	var desk := layout.complaint_desk_point()
	var sign_rect := Rect2(desk + Vector2(-120, -92), Vector2(240, 26))
	_rounded(sign_rect, AppTheme.SIGN_BOARD, 8, AppTheme.WALL, 2)
	_text_centered(sign_rect.get_center(), tr("SIGN_COMPLAINTS"), AppTheme.SIZE_LABEL_SMALL, AppTheme.SIGN_TEXT, _bold)
	ItemPainter.draw_person(_canvas, layout.complaint_clerk_point(), AppTheme.SIGN_BOARD, 1.0, Color.TRANSPARENT, 3 + state.complaint_clerk_level, AppTheme.TIE)
	OfficePainter.desk(_canvas, desk, false, false, _time)
	var box := layout.complaint_box_point()
	var cap := Formulas.complaint_cap(state)
	var full := state.complaints >= cap
	OfficePainter.complaint_box(_canvas, box, float(state.complaints) / float(cap))
	_text_centered_outlined(box + Vector2(0, 34), "%d/%d" % [state.complaints, cap], AppTheme.SIZE_LABEL_SMALL + 1, AppTheme.accent("error") if full else AppTheme.ON_SURFACE, AppTheme.SURFACE, _bold)
	if state.research_level("complaint_tube") > 0:
		_draw_tube(layout.complaint_tube_path())
	var shredder := layout.shredder_point()
	OfficePainter.shredder(_canvas, shredder, _shred_time > 0.0, _time)
	var label := Rect2(shredder + Vector2(-64, -90), Vector2(128, 26))
	_rounded(label, AppTheme.SURFACE, 8, AppTheme.OUTLINE, 2)
	_text_centered(label.get_center(), tr("SIGN_SHREDDER"), AppTheme.SIZE_LABEL_SMALL, AppTheme.ON_SURFACE, _bold)


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
	var weakest := ""
	if slot != "inspection":
		var dept := state.department(slot)
		weakest = Formulas.bottleneck(state, dept)
		var stats := tr("FMT_PER_MINUTE") % UiKit.decimal(Formulas.department_throughput(state, dept) * 60.0)
		var size := _bold.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, AppTheme.SIZE_BODY_SMALL)
		_text(Vector2(header.end.x - 44 - size.x, header.position.y + 34), stats, AppTheme.SIZE_BODY_SMALL, on_band, _bold)
		_icon(Vector2(header.end.x - 24, header.position.y + 28), Icons.CHEVRON, 26, on_band)
		for key in dept.station_keys():
			_draw_station(state, key, weakest)
	else:
		_draw_station(state, GameConfig.INSPECTION, "")


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
		var present := occupied and not mood.is_absent() and not _returning.has("%s#%d" % [station.key, desk])
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
	var signature := 0
	for dept in state.unlocked_departments():
		signature = signature * 3 + (2 if state.has_tube(dept.id) else 1)
	return signature


func _draw_tubes(state: GameState) -> void:
	var seen := {}
	for dept in state.unlocked_departments():
		if not state.has_tube(dept.id):
			continue
		var route := RouteBuilder.build(CaseFile.new(dept.id))
		for i in route.size() - 1:
			var pair := "%s>%s" % [route[i], route[i + 1]]
			if seen.has(pair):
				continue
			seen[pair] = true
			_draw_tube(layout.tube_path(route[i], route[i + 1]))


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
		var eased := t * t * (3.0 - 2.0 * t)
		var pos: Vector2 = (walker.from as Vector2).lerp(walker.to, eased)
		if not view.has_point(pos):
			continue
		match str(walker.kind):
			"car":
				ItemPainter.draw_car(_canvas, pos, AppTheme.CAR)
			"truck":
				ItemPainter.draw_truck(_canvas, pos)
			"leave":
				ItemPainter.draw_person_lite(_canvas, pos, walker.color, 1.0, int(walker.look))
				ItemPainter.draw_output(_canvas, pos + Vector2(14, -4), walker.dept)
			"return":
				ItemPainter.draw_person(_canvas, pos + Vector2(0, -absf(sin(t * walker.duration * 7.0)) * 3.0), walker.color, 1.0, Color.TRANSPARENT, int(walker.look), AppTheme.TIE)
			"angry":
				ItemPainter.draw_person(_canvas, pos, AppTheme.accent("error"), 1.0, Color.TRANSPARENT, int(walker.look))
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
