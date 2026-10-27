class_name ItemPainter
extends RefCounted

const STACK_STEP := 7.0


static func draw_stack(canvas: CanvasItem, base: Vector2, items: Array[CaseFile], limit: int = 10) -> void:
	var shown := mini(items.size(), limit)
	for i in shown:
		draw_item(canvas, base + Vector2(0, -i * STACK_STEP), items[i])


static func draw_item(canvas: CanvasItem, center: Vector2, case_file: CaseFile) -> void:
	if GameConfig.is_customs(case_file.dept_id):
		_cargo(canvas, center, case_file)
	elif case_file.produced:
		draw_output(canvas, center, case_file.dept_id)
	elif case_file.mail:
		draw_letter(canvas, center, AppTheme.department_color(case_file.dept_id))
	else:
		_folder(canvas, center, AppTheme.department_color(case_file.dept_id), case_file.urgent)
	_badges(canvas, center, case_file)


static func _badges(canvas: CanvasItem, center: Vector2, case_file: CaseFile) -> void:
	var x := -12.0
	if case_file.invalid:
		_badge(canvas, center + Vector2(x, -14), AppTheme.accent("error"), 0)
		x += 12.0
	if case_file.needs_inspection():
		_badge(canvas, center + Vector2(x, -14), AppTheme.accent("warning"), 1)
		x += 12.0
	if case_file.needs_referral():
		_badge(canvas, center + Vector2(x, -14), AppTheme.accent("primary"), 2)
		x += 12.0
	if case_file.big:
		_badge(canvas, center + Vector2(x, -14), AppTheme.FLAG_GOLD, 3)


static func _badge(canvas: CanvasItem, at: Vector2, color: Color, glyph: int) -> void:
	disc(canvas, at, 6.0, AppTheme.SURFACE)
	disc(canvas, at, 5.0, color)
	match glyph:
		0:
			canvas.draw_line(at + Vector2(-2.2, -2.2), at + Vector2(2.2, 2.2), AppTheme.SURFACE, 1.6)
			canvas.draw_line(at + Vector2(2.2, -2.2), at + Vector2(-2.2, 2.2), AppTheme.SURFACE, 1.6)
		1:
			canvas.draw_arc(at + Vector2(-0.8, -0.8), 2.4, 0, TAU, 10, AppTheme.SURFACE, 1.3)
			canvas.draw_line(at + Vector2(1.0, 1.0), at + Vector2(3.0, 3.0), AppTheme.SURFACE, 1.6)
		2:
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-2.6, -0.5), at + Vector2(0, -3.4), at + Vector2(2.6, -0.5)]), AppTheme.SURFACE)
			canvas.draw_rect(Rect2(at + Vector2(-1.8, -0.5), Vector2(3.6, 3.2)), AppTheme.SURFACE)
		_:
			disc(canvas, at, 2.0, AppTheme.SURFACE)


static func draw_letter(canvas: CanvasItem, center: Vector2, stamp: Color) -> void:
	var body := Rect2(center + Vector2(-12, -8), Vector2(24, 16))
	canvas.draw_rect(Rect2(body.position + Vector2(1, 2), body.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(body, AppTheme.PAPER)
	canvas.draw_rect(body, AppTheme.PAPER_EDGE, false, 1.0)
	canvas.draw_polyline(PackedVector2Array([body.position, body.get_center() + Vector2(0, 1), Vector2(body.end.x, body.position.y)]), AppTheme.PAPER_EDGE, 1.0)
	canvas.draw_rect(Rect2(Vector2(body.end.x - 7, body.position.y + 2), Vector2(5, 5)), stamp)


static func _folder(canvas: CanvasItem, center: Vector2, color: Color, urgent: bool) -> void:
	var body := Rect2(center + Vector2(-13, -8), Vector2(26, 16))
	canvas.draw_rect(Rect2(body.position + Vector2(1, 2), body.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(Rect2(body.position + Vector2(2, -3), Vector2(10, 4)), color.darkened(0.2))
	canvas.draw_rect(body, color)
	canvas.draw_rect(body, color.darkened(0.35), false, 1.0)
	canvas.draw_rect(Rect2(body.position + Vector2(4, 4), Vector2(18, 2)), Color(AppTheme.PAPER, 0.85))
	canvas.draw_rect(Rect2(body.position + Vector2(4, 8), Vector2(12, 2)), Color(AppTheme.PAPER, 0.85))
	if urgent:
		disc(canvas, body.position + Vector2(24, 1), 4, AppTheme.accent("error"))


static func draw_output(canvas: CanvasItem, center: Vector2, dept_id: String) -> void:
	var color := AppTheme.department_color(dept_id)
	match dept_id:
		"general_services":
			var card := Rect2(center + Vector2(-14, -9), Vector2(28, 18))
			canvas.draw_rect(card, AppTheme.SURFACE)
			canvas.draw_rect(Rect2(card.position, Vector2(28, 5)), color)
			disc(canvas, card.position + Vector2(8, 11), 4, AppTheme.SKIN)
			canvas.draw_rect(Rect2(card.position + Vector2(15, 9), Vector2(10, 2)), AppTheme.OUTLINE)
			canvas.draw_rect(card, AppTheme.OUTLINE, false, 1.0)
		"tax_services":
			var slip := Rect2(center + Vector2(-10, -11), Vector2(20, 22))
			canvas.draw_rect(slip, AppTheme.SURFACE)
			canvas.draw_rect(slip, AppTheme.OUTLINE, false, 1.0)
			disc(canvas, center + Vector2(0, 2), 6, color)
			disc(canvas, center + Vector2(0, 2), 3, AppTheme.SURFACE)
		"business_licences":
			var frame := Rect2(center + Vector2(-13, -10), Vector2(26, 20))
			canvas.draw_rect(frame, color.darkened(0.25))
			canvas.draw_rect(frame.grow(-3), AppTheme.PAPER)
			disc(canvas, center + Vector2(6, 4), 3.5, AppTheme.STAMP)
		"vehicle_registration":
			var plate := Rect2(center + Vector2(-16, -6), Vector2(32, 12))
			canvas.draw_rect(plate, AppTheme.SURFACE)
			canvas.draw_rect(plate, AppTheme.PLATE_TEXT, false, 1.5)
			canvas.draw_rect(Rect2(plate.position, Vector2(4, 12)), AppTheme.accent("primary"))
			for i in 4:
				canvas.draw_rect(Rect2(plate.position + Vector2(7 + i * 6, 3), Vector2(4, 6)), AppTheme.PLATE_TEXT)
		"building_permits":
			var roll := Rect2(center + Vector2(-15, -7), Vector2(30, 14))
			canvas.draw_rect(roll, color.lightened(0.15))
			for i in 3:
				canvas.draw_line(roll.position + Vector2(0, 4 + i * 4), roll.position + Vector2(30, 4 + i * 4), Color(AppTheme.SURFACE, 0.6), 1.0)
			disc(canvas, roll.end - Vector2(6, 6), 4, AppTheme.STAMP)
		"housing":
			var envelope := Rect2(center + Vector2(-14, -9), Vector2(28, 18))
			canvas.draw_rect(envelope, color)
			canvas.draw_line(envelope.position, envelope.get_center(), AppTheme.SURFACE, 1.5)
			canvas.draw_line(Vector2(envelope.end.x, envelope.position.y), envelope.get_center(), AppTheme.SURFACE, 1.5)
		"social_benefits":
			var card := Rect2(center + Vector2(-14, -9), Vector2(28, 18))
			canvas.draw_rect(card, color)
			canvas.draw_rect(Rect2(card.position + Vector2(4, 5), Vector2(7, 6)), AppTheme.SURFACE.darkened(0.1))
			canvas.draw_rect(Rect2(card.position + Vector2(4, 13), Vector2(18, 2)), color.darkened(0.3))
		_:
			_folder(canvas, center, color, false)


static func _cargo(canvas: CanvasItem, center: Vector2, case_file: CaseFile) -> void:
	match case_file.variant:
		"vehicles":
			draw_car(canvas, center, AppTheme.department_color("vehicle_registration"), 0.7)
		"electronics":
			var box := Rect2(center + Vector2(-12, -10), Vector2(24, 20))
			canvas.draw_rect(box, AppTheme.MONITOR)
			canvas.draw_rect(Rect2(center + Vector2(-5, -5), Vector2(10, 10)), AppTheme.department_color("building_permits"))
		_:
			var crate := Rect2(center + Vector2(-12, -10), Vector2(24, 20))
			canvas.draw_rect(crate, AppTheme.CRATE)
			canvas.draw_line(crate.position, crate.end, AppTheme.CRATE.darkened(0.3), 1.5)
			canvas.draw_line(Vector2(crate.end.x, crate.position.y), Vector2(crate.position.x, crate.end.y), AppTheme.CRATE.darkened(0.3), 1.5)
	if case_file.contraband:
		canvas.draw_rect(Rect2(center + Vector2(6, -14), Vector2(10, 7)), AppTheme.accent("error"))
	elif case_file.flagged:
		canvas.draw_rect(Rect2(center + Vector2(6, -14), Vector2(10, 7)), AppTheme.accent("warning"))
	elif case_file.scanned or case_file.step >= case_file.route.size() - 1:
		canvas.draw_rect(Rect2(center + Vector2(6, -14), Vector2(10, 7)), AppTheme.CLEARED)


const DISC_SIZES: Array[int] = [16, 32, 64, 128, 256]
const DISC_DETAIL := 6.0

static var _shadow_texture: ImageTexture
static var _discs: Array[ImageTexture] = []


static func disc_texture(radius: float) -> ImageTexture:
	if _discs.is_empty():
		_build_discs()
	var needed := radius * DISC_DETAIL
	for index in DISC_SIZES.size():
		if DISC_SIZES[index] >= needed:
			return _discs[index]
	return _discs[-1]


static func disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	if radius <= 0.0:
		return
	canvas.draw_texture_rect(disc_texture(radius), Rect2(center.x - radius, center.y - radius, radius * 2.0, radius * 2.0), false, color)


static func _build_discs() -> void:
	var size: int = DISC_SIZES[-1]
	var half := size / 2
	var data := PackedByteArray()
	data.resize(size * size * 4)
	data.fill(255)
	for y in half:
		for x in half:
			var dx := half - (x + 0.5)
			var dy := half - (y + 0.5)
			var alpha := int(clampf(half - sqrt(dx * dx + dy * dy), 0.0, 1.0) * 255.0)
			for pixel: int in [y * size + x, y * size + size - 1 - x, (size - 1 - y) * size + x, (size - 1 - y) * size + size - 1 - x]:
				data[pixel * 4 + 3] = alpha
	var master := Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, data)
	for disc_size in DISC_SIZES:
		var copy := master.duplicate() as Image
		if disc_size != size:
			copy.resize(disc_size, disc_size, Image.INTERPOLATE_LANCZOS)
		_discs.append(ImageTexture.create_from_image(copy))


static func shadow_texture() -> ImageTexture:
	if _shadow_texture == null:
		var width := 64
		var height := 32
		var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
		for y in height:
			for x in width:
				var dx := (x + 0.5) / width * 2.0 - 1.0
				var dy := (y + 0.5) / height * 2.0 - 1.0
				var alpha := clampf((1.0 - sqrt(dx * dx + dy * dy)) * 2.0, 0.0, 1.0)
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
		_shadow_texture = ImageTexture.create_from_image(image)
	return _shadow_texture


static func shadow(canvas: CanvasItem, center: Vector2, radius_x: float, radius_y: float) -> void:
	canvas.draw_texture_rect(shadow_texture(), Rect2(center - Vector2(radius_x, radius_y), Vector2(radius_x, radius_y) * 2.0), false, AppTheme.SHADOW_SOFT)


static func draw_car(canvas: CanvasItem, center: Vector2, color: Color, scale: float = 1.0) -> void:
	shadow(canvas, center + Vector2(0, 12) * scale, 26 * scale, 6 * scale)
	canvas.draw_rect(Rect2(center + Vector2(-23, -8) * scale, Vector2(46, 17) * scale), color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-14, -8) * scale, center + Vector2(-9, -17) * scale,
		center + Vector2(10, -17) * scale, center + Vector2(16, -8) * scale,
	]), color.darkened(0.12))
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-10, -9) * scale, center + Vector2(-7, -15) * scale,
		center + Vector2(-1, -15) * scale, center + Vector2(-1, -9) * scale,
	]), AppTheme.WINDOW)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(1, -9) * scale, center + Vector2(1, -15) * scale,
		center + Vector2(9, -15) * scale, center + Vector2(13, -9) * scale,
	]), AppTheme.WINDOW)
	canvas.draw_rect(Rect2(center + Vector2(19, -5) * scale, Vector2(4, 4) * scale), AppTheme.FLAG_GOLD)
	canvas.draw_rect(Rect2(center + Vector2(-23, -5) * scale, Vector2(3, 4) * scale), AppTheme.FLAG_RED)
	for x in [-13.0, 13.0]:
		disc(canvas, center + Vector2(x, 9) * scale, 5.5 * scale, AppTheme.SHOES)
		disc(canvas, center + Vector2(x, 9) * scale, 2.2 * scale, AppTheme.METAL)


static func draw_truck(canvas: CanvasItem, center: Vector2) -> void:
	shadow(canvas, center + Vector2(0, 22), 46, 7)
	canvas.draw_rect(Rect2(center + Vector2(-42, -20), Vector2(58, 36)), AppTheme.TRUCK)
	canvas.draw_rect(Rect2(center + Vector2(-42, -20), Vector2(58, 5)), AppTheme.TRUCK.lightened(0.25))
	canvas.draw_rect(Rect2(center + Vector2(-34, -6), Vector2(42, 4)), AppTheme.TRUCK.darkened(0.2))
	canvas.draw_rect(Rect2(center + Vector2(-34, 2), Vector2(42, 4)), AppTheme.TRUCK.darkened(0.2))
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(16, -12), center + Vector2(32, -12), center + Vector2(40, -1),
		center + Vector2(40, 16), center + Vector2(16, 16),
	]), AppTheme.TRUCK.darkened(0.25))
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(22, -8), center + Vector2(30, -8), center + Vector2(35, -2), center + Vector2(22, -2),
	]), AppTheme.WINDOW)
	canvas.draw_rect(Rect2(center + Vector2(36, 8), Vector2(5, 4)), AppTheme.FLAG_GOLD)
	for x in [-28.0, -10.0, 28.0]:
		disc(canvas, center + Vector2(x, 17), 6.5, AppTheme.SHOES)
		disc(canvas, center + Vector2(x, 17), 2.6, AppTheme.METAL)


static func draw_person_lite(canvas: CanvasItem, center: Vector2, body: Color, scale: float = 1.0, look: int = 0) -> void:
	var s := scale
	shadow(canvas, center + Vector2(0, 18) * s, 11 * s, 3.5 * s)
	canvas.draw_rect(Rect2(center + Vector2(-6, 11) * s, Vector2(12, 8) * s), AppTheme.TROUSERS)
	disc(canvas, center + Vector2(0, 3) * s, 9.5 * s, body)
	canvas.draw_rect(Rect2(center + Vector2(-9.5, 3) * s, Vector2(19, 9) * s), body)
	disc(canvas, center + Vector2(0, -9.5) * s, 7.6 * s, AppTheme.HAIR_COLORS[(look * 5 + 1) % AppTheme.HAIR_COLORS.size()])
	disc(canvas, center + Vector2(0, -7.2) * s, 6.7 * s, AppTheme.SKIN_TONES[look % AppTheme.SKIN_TONES.size()])


static func draw_person(canvas: CanvasItem, center: Vector2, body: Color, scale: float = 1.0, hat: Color = Color.TRANSPARENT, look: int = 0, tie: Color = Color.TRANSPARENT, sleeping: bool = false, expert: bool = false) -> void:
	var s := scale
	shadow(canvas, center + Vector2(0, 18) * s, 11 * s, 3.5 * s)
	canvas.draw_rect(Rect2(center + Vector2(-6, 11) * s, Vector2(5, 7) * s), AppTheme.TROUSERS)
	canvas.draw_rect(Rect2(center + Vector2(1, 11) * s, Vector2(5, 7) * s), AppTheme.TROUSERS)
	canvas.draw_rect(Rect2(center + Vector2(-7, 17) * s, Vector2(6, 2.5) * s), AppTheme.SHOES)
	canvas.draw_rect(Rect2(center + Vector2(1, 17) * s, Vector2(6, 2.5) * s), AppTheme.SHOES)
	disc(canvas, center + Vector2(0, 3) * s, 9.5 * s, body)
	canvas.draw_rect(Rect2(center + Vector2(-9.5, 3) * s, Vector2(19, 9) * s), body)
	canvas.draw_arc(center + Vector2(0, 3) * s, 9.5 * s, PI, TAU, 14, body.darkened(0.3), 1.2 * s)
	canvas.draw_line(center + Vector2(-9.5, 3) * s, center + Vector2(-9.5, 12) * s, body.darkened(0.3), 1.2 * s)
	canvas.draw_line(center + Vector2(9.5, 3) * s, center + Vector2(9.5, 12) * s, body.darkened(0.3), 1.2 * s)
	var skin: Color = AppTheme.SKIN_TONES[look % AppTheme.SKIN_TONES.size()]
	var hair: Color = AppTheme.HAIR_COLORS[(look * 5 + 1) % AppTheme.HAIR_COLORS.size()]
	disc(canvas, center + Vector2(-10, 8) * s, 2.6 * s, skin)
	disc(canvas, center + Vector2(10, 8) * s, 2.6 * s, skin)
	if tie.a > 0.0:
		canvas.draw_colored_polygon(PackedVector2Array([
			center + Vector2(-4, -1) * s, center + Vector2(4, -1) * s, center + Vector2(0, 5) * s,
		]), AppTheme.COLLAR)
		canvas.draw_colored_polygon(PackedVector2Array([
			center + Vector2(-1.6, 0) * s, center + Vector2(1.6, 0) * s, center + Vector2(1.2, 9) * s, center + Vector2(-1.2, 9) * s,
		]), tie)
	if expert:
		canvas.draw_colored_polygon(PackedVector2Array([
			center + Vector2(5, 2) * s, center + Vector2(7.5, 5) * s, center + Vector2(5, 8) * s, center + Vector2(2.5, 5) * s,
		]), AppTheme.FLAG_GOLD)
	disc(canvas, center + Vector2(0, -9.5) * s, 7.6 * s, hair)
	disc(canvas, center + Vector2(0, -7.2) * s, 6.7 * s, skin)
	if sleeping:
		canvas.draw_line(center + Vector2(-4, -7.4) * s, center + Vector2(-1, -7.4) * s, AppTheme.SHOES, 1.2)
		canvas.draw_line(center + Vector2(1, -7.4) * s, center + Vector2(4, -7.4) * s, AppTheme.SHOES, 1.2)
	else:
		disc(canvas, center + Vector2(-2.4, -7.6) * s, maxf(0.9, 1.0 * s), AppTheme.SHOES)
		disc(canvas, center + Vector2(2.4, -7.6) * s, maxf(0.9, 1.0 * s), AppTheme.SHOES)
	if look % 3 == 0 or expert:
		canvas.draw_arc(center + Vector2(-2.6, -7.6) * s, 2.5 * s, 0, TAU, 10, AppTheme.SHOES, 0.9)
		canvas.draw_arc(center + Vector2(2.6, -7.6) * s, 2.5 * s, 0, TAU, 10, AppTheme.SHOES, 0.9)
	if look % 4 == 1:
		canvas.draw_rect(Rect2(center + Vector2(-3, -4.6) * s, Vector2(6, 1.6) * s), hair.darkened(0.2))
	if hat.a > 0.0:
		canvas.draw_rect(Rect2(center + Vector2(-8, -17) * s, Vector2(16, 6) * s), hat)
		canvas.draw_rect(Rect2(center + Vector2(-9, -12) * s, Vector2(18, 2.4) * s), hat.darkened(0.3))
		canvas.draw_rect(Rect2(center + Vector2(-2.5, -16) * s, Vector2(5, 2.5) * s), AppTheme.FLAG_GOLD)
