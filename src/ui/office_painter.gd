class_name OfficePainter
extends RefCounted

const SWITCHBOARD_LAMPS := 8
const TILE := 44.0
const POP_SECONDS := 0.45


static var _tile_texture: ImageTexture


static func tile_texture() -> ImageTexture:
	if _tile_texture == null:
		var cell := int(TILE)
		var image := Image.create_empty(cell * 2, cell * 2, false, Image.FORMAT_RGBA8)
		image.fill_rect(Rect2i(cell, 0, cell, cell), AppTheme.TILE_SHADE)
		image.fill_rect(Rect2i(0, cell, cell, cell), AppTheme.TILE_SHADE)
		_tile_texture = ImageTexture.create_from_image(image)
		_tile_texture.set_size_override(Vector2i(cell * 2, cell * 2))
	return _tile_texture


static func tiles(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_texture_rect(tile_texture(), rect, true)


static func plant(canvas: CanvasItem, base: Vector2, scale: float = 1.0) -> void:
	ItemPainter.shadow(canvas, base + Vector2(0, 2) * scale, 16 * scale, 4 * scale)
	canvas.draw_colored_polygon(PackedVector2Array([
		base + Vector2(-11, -16) * scale, base + Vector2(11, -16) * scale,
		base + Vector2(8, 0) * scale, base + Vector2(-8, 0) * scale,
	]), AppTheme.POT)
	canvas.draw_rect(Rect2(base + Vector2(-12, -19) * scale, Vector2(24, 4) * scale), AppTheme.POT.lightened(0.15))
	canvas.draw_circle(base + Vector2(-8, -28) * scale, 9 * scale, AppTheme.LEAF_DARK)
	canvas.draw_circle(base + Vector2(8, -28) * scale, 9 * scale, AppTheme.LEAF_DARK)
	canvas.draw_circle(base + Vector2(0, -36) * scale, 10 * scale, AppTheme.PLANT)
	canvas.draw_circle(base + Vector2(-3, -26) * scale, 8 * scale, AppTheme.PLANT_LIGHT)


static func cabinet(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(rect, AppTheme.CABINET)
	canvas.draw_rect(rect, AppTheme.CABINET_DARK, false, 2.0)
	var drawers := maxi(2, int(rect.size.y / 36.0))
	var step := rect.size.y / drawers
	for i in drawers:
		var drawer := Rect2(rect.position + Vector2(5, 5 + i * step), Vector2(rect.size.x - 10, step - 8))
		canvas.draw_rect(drawer, AppTheme.CABINET.lightened(0.12))
		canvas.draw_rect(drawer, AppTheme.CABINET_DARK, false, 1.0)
		canvas.draw_rect(Rect2(drawer.get_center() + Vector2(-8, -2), Vector2(16, 4)), AppTheme.CABINET_DARK)


static func clock(canvas: CanvasItem, center: Vector2, radius: float) -> void:
	canvas.draw_circle(center + Vector2(2, 3), radius, AppTheme.SHADOW_SOFT)
	canvas.draw_circle(center, radius, AppTheme.SIGN_BOARD)
	canvas.draw_circle(center, radius - 3, AppTheme.SURFACE)
	for i in 12:
		var angle := TAU * i / 12.0
		var tick := Vector2(sin(angle), -cos(angle))
		canvas.draw_line(center + tick * (radius - 7), center + tick * (radius - 4), AppTheme.SIGN_BOARD, 1.5)
	canvas.draw_line(center, center + Vector2(0, -radius * 0.7), AppTheme.SHOES, 2.5)
	canvas.draw_line(center, center + Vector2(radius * 0.25, -radius * 0.55), AppTheme.SHOES, 3.0)
	canvas.draw_circle(center, 2.5, AppTheme.FLAG_RED)


static func flag(canvas: CanvasItem, pole_base: Vector2, height: float, time: float) -> void:
	canvas.draw_line(pole_base, pole_base + Vector2(0, -height), AppTheme.METAL_DARK, 4.0)
	canvas.draw_circle(pole_base + Vector2(0, -height), 4, AppTheme.FLAG_GOLD)
	var width := 66.0
	var stripe := 13.0
	var colors: Array[Color] = [AppTheme.FLAG_BLACK, AppTheme.FLAG_RED, AppTheme.FLAG_GOLD]
	for i in 3:
		var points := PackedVector2Array()
		for step in 9:
			var x := width * step / 8.0
			points.append(pole_base + Vector2(4 + x, -height + 6 + i * stripe + sin(time * 3.0 + x * 0.12) * 2.5 * x / width))
		for step in range(8, -1, -1):
			var x := width * step / 8.0
			points.append(pole_base + Vector2(4 + x, -height + 6 + (i + 1) * stripe + sin(time * 3.0 + x * 0.12) * 2.5 * x / width))
		canvas.draw_colored_polygon(points, colors[i])


static func pop_scale(age: float) -> float:
	if age <= 0.0:
		return 0.0
	if age >= POP_SECONDS:
		return 1.0
	var t := age / POP_SECONDS - 1.0
	return 1.0 + 2.70158 * t * t * t + 1.70158 * t * t


static func waiting_chair(canvas: CanvasItem, center: Vector2, scale: float = 1.0) -> void:
	if scale <= 0.0:
		return
	canvas.draw_set_transform(center, 0.0, Vector2(scale, scale))
	canvas.draw_rect(Rect2(Vector2(-10, -4), Vector2(20, 5)), AppTheme.BENCH.darkened(0.2))
	canvas.draw_rect(Rect2(Vector2(-10, 1), Vector2(20, 8)), AppTheme.BENCH)
	canvas.draw_rect(Rect2(Vector2(-9, 9), Vector2(3, 5)), AppTheme.WOOD_DARK)
	canvas.draw_rect(Rect2(Vector2(6, 9), Vector2(3, 5)), AppTheme.WOOD_DARK)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func queue_mark(canvas: CanvasItem, center: Vector2, scale: float = 1.0) -> void:
	if scale <= 0.0:
		return
	canvas.draw_set_transform(center, 0.0, Vector2(scale, scale))
	canvas.draw_circle(Vector2(0, 10), 11.0, Color(AppTheme.OUTLINE, 0.18))
	canvas.draw_arc(Vector2(0, 10), 11.0, 0.0, TAU, 16, Color(AppTheme.OUTLINE, 0.55), 2.0)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func ticket_dispenser(canvas: CanvasItem, center: Vector2) -> void:
	ItemPainter.shadow(canvas, center + Vector2(0, 30), 18, 4)
	canvas.draw_rect(Rect2(center + Vector2(-4, 8), Vector2(8, 22)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(center + Vector2(-16, -22), Vector2(32, 32)), AppTheme.FLAG_RED)
	canvas.draw_rect(Rect2(center + Vector2(-16, -22), Vector2(32, 32)), AppTheme.FLAG_RED.darkened(0.3), false, 2.0)
	canvas.draw_rect(Rect2(center + Vector2(-9, -16), Vector2(18, 10)), AppTheme.SCREEN)
	canvas.draw_rect(Rect2(center + Vector2(-6, 2), Vector2(12, 6)), AppTheme.PAPER)
	canvas.draw_rect(Rect2(center + Vector2(-6, 8), Vector2(12, 7)), AppTheme.PAPER)


static func desk(canvas: CanvasItem, pos: Vector2, occupied: bool, active: bool, time: float, expert: bool = false) -> void:
	if expert:
		canvas.draw_rect(Rect2(pos + Vector2(-46, -40), Vector2(92, 66)), Color(AppTheme.FLAG_GOLD, 0.2))
		canvas.draw_rect(Rect2(pos + Vector2(-46, -40), Vector2(92, 66)), Color(AppTheme.FLAG_GOLD, 0.7), false, 2.0)
	ItemPainter.shadow(canvas, pos + Vector2(0, 20), 36, 6)
	var chair := pos + Vector2(0, -22)
	canvas.draw_circle(chair + Vector2(0, 4), 12, AppTheme.SHOES if occupied else Color(AppTheme.OUTLINE, 0.25))
	canvas.draw_rect(Rect2(pos + Vector2(-33, -6), Vector2(66, 26)), AppTheme.WOOD_FRONT)
	canvas.draw_rect(Rect2(pos + Vector2(-35, -9), Vector2(70, 9)), AppTheme.WOOD_TOP)
	canvas.draw_rect(Rect2(pos + Vector2(-35, -9), Vector2(70, 9)), AppTheme.WOOD_DARK, false, 1.0)
	canvas.draw_rect(Rect2(pos + Vector2(-28, 3), Vector2(22, 13)), AppTheme.WOOD_DARK.lightened(0.1))
	canvas.draw_rect(Rect2(pos + Vector2(-20, 8), Vector2(6, 2)), AppTheme.METAL)
	canvas.draw_rect(Rect2(pos + Vector2(2, 3), Vector2(26, 13)), AppTheme.WOOD_DARK.lightened(0.1))
	canvas.draw_rect(Rect2(pos + Vector2(12, 8), Vector2(6, 2)), AppTheme.METAL)
	canvas.draw_rect(Rect2(pos + Vector2(8, -22), Vector2(20, 14)), AppTheme.MONITOR)
	var glow := AppTheme.SCREEN if active else AppTheme.SCREEN.darkened(0.45)
	canvas.draw_rect(Rect2(pos + Vector2(10, -20), Vector2(16, 9)), glow)
	if active and fmod(time, 0.8) < 0.4:
		canvas.draw_rect(Rect2(pos + Vector2(12, -18), Vector2(8, 1.5)), AppTheme.MONITOR)
	canvas.draw_rect(Rect2(pos + Vector2(16, -8), Vector2(4, 3)), AppTheme.MONITOR)
	canvas.draw_rect(Rect2(pos + Vector2(-26, -14), Vector2(12, 6)), AppTheme.PAPER)
	canvas.draw_rect(Rect2(pos + Vector2(-26, -14), Vector2(12, 6)), AppTheme.PAPER_EDGE, false, 1.0)
	canvas.draw_rect(Rect2(pos + Vector2(-10, -14), Vector2(7, 6)), AppTheme.PAPER)
	canvas.draw_rect(Rect2(pos + Vector2(-9, -14), Vector2(5, 6)), AppTheme.FLAG_RED.lightened(0.1))
	canvas.draw_rect(Rect2(pos + Vector2(-8, -17), Vector2(3, 3)), AppTheme.PAPER_EDGE)
	if expert:
		canvas.draw_rect(Rect2(pos + Vector2(-12, 11), Vector2(24, 5)), AppTheme.FLAG_GOLD)
		canvas.draw_rect(Rect2(pos + Vector2(-12, 11), Vector2(24, 5)), AppTheme.WOOD_DARK, false, 1.0)


static func machine(canvas: CanvasItem, dept_id: String, pos: Vector2, color: Color, active: bool, time: float) -> void:
	ItemPainter.shadow(canvas, pos + Vector2(0, 20), 36, 6)
	var blink := active and fmod(time, 0.6) < 0.3
	match dept_id:
		"general_services":
			canvas.draw_rect(Rect2(pos + Vector2(-24, -32), Vector2(48, 52)), color.darkened(0.3))
			canvas.draw_rect(Rect2(pos + Vector2(-24, -32), Vector2(48, 10)), AppTheme.SURFACE)
			canvas.draw_circle(pos + Vector2(0, -27), 3.5, AppTheme.SHOES)
			canvas.draw_rect(Rect2(pos + Vector2(-18, -18), Vector2(36, 38)), AppTheme.CURTAIN)
			for i in 4:
				canvas.draw_rect(Rect2(pos + Vector2(-18 + i * 9.5, -18), Vector2(4, 38)), AppTheme.CURTAIN.darkened(0.15))
			if blink:
				canvas.draw_rect(Rect2(pos + Vector2(-24, -32), Vector2(48, 10)), AppTheme.FLAG_GOLD)
		"tax_services":
			canvas.draw_rect(Rect2(pos + Vector2(-24, -28), Vector2(48, 48)), AppTheme.MONITOR)
			canvas.draw_rect(Rect2(pos + Vector2(-19, -23), Vector2(38, 12)), AppTheme.SCREEN if active else AppTheme.SCREEN.darkened(0.4))
			for row in 3:
				for column in 4:
					var key_color := AppTheme.FLAG_RED if column == 3 and row == 0 else AppTheme.METAL
					canvas.draw_rect(Rect2(pos + Vector2(-19 + column * 10, -6 + row * 8), Vector2(8, 6)), key_color)
		"business_licences":
			canvas.draw_rect(Rect2(pos + Vector2(-26, 6), Vector2(52, 14)), AppTheme.WOOD_DARK)
			canvas.draw_rect(Rect2(pos + Vector2(-22, 2), Vector2(44, 8)), AppTheme.INK)
			var lift := -8.0 if active and fmod(time, 1.0) < 0.5 else 0.0
			canvas.draw_rect(Rect2(pos + Vector2(-15, -4 + lift), Vector2(30, 8)), AppTheme.STAMP.darkened(0.2))
			canvas.draw_rect(Rect2(pos + Vector2(-4, -18 + lift), Vector2(8, 14)), AppTheme.WOOD_FRONT)
			canvas.draw_circle(pos + Vector2(0, -22 + lift), 9, AppTheme.WOOD_TOP)
			canvas.draw_circle(pos + Vector2(0, -22 + lift), 9, AppTheme.WOOD_DARK, false, 1.0)
		"vehicle_registration":
			canvas.draw_rect(Rect2(pos + Vector2(-28, -12), Vector2(56, 32)), AppTheme.METAL)
			canvas.draw_rect(Rect2(pos + Vector2(-28, -12), Vector2(56, 8)), AppTheme.METAL_DARK)
			canvas.draw_rect(Rect2(pos + Vector2(-20, -2), Vector2(40, 5)), AppTheme.SHOES)
			var plate := Rect2(pos + Vector2(-17, -22), Vector2(34, 13))
			canvas.draw_rect(plate, AppTheme.SURFACE)
			canvas.draw_rect(plate, AppTheme.PLATE_TEXT, false, 1.5)
			canvas.draw_rect(Rect2(plate.position, Vector2(5, 13)), AppTheme.PLATE_BLUE)
			for i in 3:
				canvas.draw_rect(Rect2(plate.position + Vector2(9 + i * 8, 3), Vector2(5, 7)), AppTheme.PLATE_TEXT)
			canvas.draw_circle(pos + Vector2(20, 10), 3, AppTheme.accent("success") if blink else AppTheme.METAL_DARK)
		"housing":
			canvas.draw_rect(Rect2(pos + Vector2(-26, -10), Vector2(52, 30)), color.darkened(0.2))
			canvas.draw_rect(Rect2(pos + Vector2(-26, -10), Vector2(52, 7)), color.lightened(0.15))
			canvas.draw_rect(Rect2(pos + Vector2(-14, -26), Vector2(28, 18)), AppTheme.PAPER)
			canvas.draw_rect(Rect2(pos + Vector2(-14, -26), Vector2(28, 18)), AppTheme.PAPER_EDGE, false, 1.0)
			canvas.draw_line(pos + Vector2(-9, -20), pos + Vector2(9, -20), color, 2.0)
			canvas.draw_line(pos + Vector2(-9, -15), pos + Vector2(4, -15), color, 2.0)
		"customs":
			canvas.draw_rect(Rect2(pos + Vector2(-34, 8), Vector2(68, 9)), AppTheme.SHOES)
			for i in 6:
				canvas.draw_rect(Rect2(pos + Vector2(-32 + i * 11, 10), Vector2(5, 5)), AppTheme.METAL_DARK)
			canvas.draw_rect(Rect2(pos + Vector2(-26, -28), Vector2(52, 38)), AppTheme.METAL_DARK)
			canvas.draw_rect(Rect2(pos + Vector2(-18, -18), Vector2(36, 28)), AppTheme.SHOES)
			canvas.draw_rect(Rect2(pos + Vector2(-26, -28), Vector2(52, 6)), color)
			if active:
				var sweep := -16.0 + fposmod(time * 30.0, 32.0)
				canvas.draw_rect(Rect2(pos + Vector2(sweep, -18), Vector2(3, 28)), AppTheme.PLATE_BLUE.lightened(0.4))
		_:
			canvas.draw_rect(Rect2(pos + Vector2(-26, -22), Vector2(52, 42)), color.darkened(0.25))
			canvas.draw_rect(Rect2(pos + Vector2(-26, -22), Vector2(52, 8)), color)


static func kitchen_counter(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(rect, AppTheme.WOOD_FRONT)
	canvas.draw_rect(Rect2(rect.position + Vector2(-4, -8), Vector2(rect.size.x + 8, 12)), AppTheme.CABINET)
	canvas.draw_rect(Rect2(rect.position + Vector2(-4, -8), Vector2(rect.size.x + 8, 12)), AppTheme.CABINET_DARK, false, 1.5)
	var doors := maxi(2, int(rect.size.x / 70.0))
	var step := rect.size.x / doors
	for i in doors:
		var door := Rect2(rect.position + Vector2(4 + i * step, 8), Vector2(step - 8, rect.size.y - 12))
		canvas.draw_rect(door, AppTheme.WOOD_DARK.lightened(0.12))
		canvas.draw_rect(door, AppTheme.WOOD_DARK, false, 1.0)
		canvas.draw_rect(Rect2(door.position + Vector2(door.size.x - 8, 6), Vector2(3, 10)), AppTheme.METAL)


static func fridge(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(rect, AppTheme.FRIDGE)
	canvas.draw_rect(rect, AppTheme.METAL_DARK, false, 2.0)
	canvas.draw_line(rect.position + Vector2(0, rect.size.y * 0.35), rect.position + Vector2(rect.size.x, rect.size.y * 0.35), AppTheme.METAL_DARK, 2.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x - 10, 10), Vector2(3, 18)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(rect.position + Vector2(rect.size.x - 10, rect.size.y * 0.35 + 10), Vector2(3, 28)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(rect.position + Vector2(8, 12), Vector2(10, 10)), AppTheme.FLAG_RED)
	canvas.draw_rect(Rect2(rect.position + Vector2(20, 24), Vector2(10, 10)), AppTheme.FLAG_GOLD)
	canvas.draw_rect(Rect2(rect.position + Vector2(8, rect.size.y * 0.35 + 14), Vector2(14, 14)), AppTheme.PAPER)


static func sink(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_rect(Rect2(center + Vector2(-26, -4), Vector2(52, 14)), AppTheme.METAL)
	canvas.draw_rect(Rect2(center + Vector2(-20, -1), Vector2(40, 8)), AppTheme.WATER.darkened(0.2))
	canvas.draw_line(center + Vector2(0, -4), center + Vector2(0, -18), AppTheme.METAL_DARK, 3.0)
	canvas.draw_line(center + Vector2(0, -18), center + Vector2(10, -18), AppTheme.METAL_DARK, 3.0)


static func microwave(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_rect(Rect2(center + Vector2(-24, -22), Vector2(48, 26)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(center + Vector2(-20, -18), Vector2(28, 18)), AppTheme.SHOES)
	canvas.draw_rect(Rect2(center + Vector2(12, -18), Vector2(8, 4)), AppTheme.SCREEN)
	canvas.draw_circle(center + Vector2(16, -8), 3, AppTheme.METAL)


static func coffee_machine(canvas: CanvasItem, base: Vector2, level: int, active: bool, time: float, tier: int = 0) -> void:
	ItemPainter.shadow(canvas, base + Vector2(0, 2), 36, 6)
	canvas.draw_rect(Rect2(base + Vector2(-30, -56), Vector2(60, 58)), AppTheme.MONITOR)
	canvas.draw_rect(Rect2(base + Vector2(-30, -56), Vector2(60, 58)), AppTheme.SHOES, false, 2.0)
	canvas.draw_rect(Rect2(base + Vector2(-24, -52), Vector2(22, 20)), AppTheme.WATER)
	canvas.draw_rect(Rect2(base + Vector2(-24, -52), Vector2(22, 8)), Color(AppTheme.SURFACE, 0.45))
	canvas.draw_rect(Rect2(base + Vector2(4, -52), Vector2(20, 8)), AppTheme.COFFEE_DARK)
	canvas.draw_rect(Rect2(base + Vector2(-6, -30), Vector2(12, 8)), AppTheme.METAL)
	if active and fmod(time, 0.4) < 0.2:
		canvas.draw_line(base + Vector2(0, -22), base + Vector2(0, -10), AppTheme.COFFEE_LIQUID, 2.0)
	canvas.draw_rect(Rect2(base + Vector2(-14, -10), Vector2(28, 8)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(base + Vector2(-9, -9), Vector2(18, 7)), AppTheme.SURFACE)
	canvas.draw_rect(Rect2(base + Vector2(-9, -6), Vector2(18, 4)), AppTheme.COFFEE_LIQUID)
	for i in GameConfig.RESEARCH.coffee.max_level:
		var lit := i < level
		canvas.draw_circle(base + Vector2(-20 + i * 8, 10), 2.5, AppTheme.accent("success") if lit else AppTheme.METAL_DARK)
	for i in tier:
		canvas.draw_rect(Rect2(base + Vector2(-30 + i * 15, -60), Vector2(12, 4)), AppTheme.FLAG_GOLD)
	if active:
		for i in 2:
			var drift := fmod(time * 1.2 + i * 0.5, 1.0)
			canvas.draw_circle(base + Vector2(-5 + i * 10, -60 - drift * 14), 3.0, Color(AppTheme.OUTLINE, 0.8 - drift * 0.8))


static func kitchen_table(canvas: CanvasItem, center: Vector2) -> void:
	ItemPainter.shadow(canvas, center + Vector2(0, 24), 70, 9)
	for x in [-82.0, 82.0]:
		canvas.draw_circle(center + Vector2(x, 6), 15, AppTheme.WOOD_DARK)
		canvas.draw_circle(center + Vector2(x, 6), 15, AppTheme.WOOD_FRONT, false, 2.0)
	canvas.draw_rect(Rect2(center + Vector2(-64, -14), Vector2(128, 34)), AppTheme.WOOD_FRONT)
	canvas.draw_rect(Rect2(center + Vector2(-68, -20), Vector2(136, 12)), AppTheme.WOOD_TOP)
	canvas.draw_rect(Rect2(center + Vector2(-68, -20), Vector2(136, 12)), AppTheme.WOOD_DARK, false, 1.0)
	for x in [-36.0, 8.0, 40.0]:
		canvas.draw_rect(Rect2(center + Vector2(x, -30), Vector2(10, 11)), AppTheme.SURFACE)
		canvas.draw_rect(Rect2(center + Vector2(x, -30), Vector2(10, 11)), AppTheme.METAL_DARK, false, 1.0)
		canvas.draw_rect(Rect2(center + Vector2(x + 1, -28), Vector2(8, 4)), AppTheme.COFFEE_LIQUID)


static func complaint_pile(canvas: CanvasItem, base: Vector2, count: int) -> void:
	for i in mini(count, GameConfig.COMPLAINT_PILE_DRAWN):
		var offset := Vector2((i % 3) * 13.0 - 13.0, -floorf(i / 3.0) * 5.0)
		canvas.draw_rect(Rect2(base + offset + Vector2(-9, -4), Vector2(18, 10)), AppTheme.PAPER)
		canvas.draw_rect(Rect2(base + offset + Vector2(-9, -4), Vector2(18, 10)), AppTheme.METAL_DARK, false, 1.0)
		canvas.draw_line(base + offset + Vector2(-6, 0), base + offset + Vector2(5, 0), AppTheme.FLAG_RED, 1.0)


static func complaint_box(canvas: CanvasItem, base: Vector2, fill: float) -> void:
	ItemPainter.shadow(canvas, base + Vector2(0, 20), 22, 5)
	canvas.draw_rect(Rect2(base + Vector2(-3, -10), Vector2(6, 30)), AppTheme.METAL_DARK)
	var box := Rect2(base + Vector2(-23, -46), Vector2(46, 38))
	canvas.draw_rect(Rect2(box.position + Vector2(2, 3), box.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(box, AppTheme.FLAG_RED)
	canvas.draw_rect(box, AppTheme.FLAG_RED.darkened(0.35), false, 2.0)
	canvas.draw_rect(Rect2(box.position + Vector2(9, 7), Vector2(28, 4)), AppTheme.SHOES)
	var gauge := Rect2(box.position + Vector2(7, 18), Vector2(32, 13))
	canvas.draw_rect(gauge, AppTheme.PAPER_EDGE)
	canvas.draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * clampf(fill, 0.0, 1.0), gauge.size.y)), AppTheme.PAPER)
	canvas.draw_rect(gauge, AppTheme.FLAG_RED.darkened(0.35), false, 1.0)
	if fill >= 1.0:
		for i in 3:
			var sheet := Rect2(box.position + Vector2(10 + i * 9, 1 - (i % 2) * 4), Vector2(8, 10))
			canvas.draw_rect(sheet, AppTheme.PAPER)
			canvas.draw_rect(sheet, AppTheme.PAPER_EDGE, false, 1.0)


static func shredder(canvas: CanvasItem, base: Vector2, active: bool, time: float) -> void:
	ItemPainter.shadow(canvas, base + Vector2(0, 4), 40, 7)
	canvas.draw_rect(Rect2(base + Vector2(-34, -38), Vector2(68, 42)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(base + Vector2(-34, -38), Vector2(68, 42)), AppTheme.SHOES, false, 2.0)
	canvas.draw_rect(Rect2(base + Vector2(-34, -48), Vector2(68, 12)), AppTheme.METAL)
	canvas.draw_rect(Rect2(base + Vector2(-24, -44), Vector2(48, 4)), AppTheme.SHOES)
	canvas.draw_circle(base + Vector2(24, -20), 3.0, AppTheme.accent("error") if active else AppTheme.accent("success"))
	for i in 7:
		var x := -24.0 + i * 8.0
		canvas.draw_line(base + Vector2(x, -12), base + Vector2(x, 2), AppTheme.SHOES, 2.0)
	if active:
		for i in 3:
			var drift := fmod(time * 2.0 + i * 0.33, 1.0)
			canvas.draw_rect(Rect2(base + Vector2(-14 + i * 14 + sin(time * 9.0 + i) * 3.0, -56 + drift * 20.0), Vector2(5, 7)), Color(AppTheme.PAPER, 1.0 - drift))


static func phone(canvas: CanvasItem, base: Vector2, ringing: bool, time: float) -> void:
	var shake := Vector2(sin(time * 40.0) * 1.5, 0.0) if ringing else Vector2.ZERO
	canvas.draw_rect(Rect2(base + shake + Vector2(-16, -6), Vector2(32, 14)), AppTheme.METAL_DARK)
	canvas.draw_rect(Rect2(base + shake + Vector2(-20, -12), Vector2(40, 7)), AppTheme.SHOES)
	canvas.draw_circle(base + shake + Vector2(-20, -8), 4.0, AppTheme.SHOES)
	canvas.draw_circle(base + shake + Vector2(20, -8), 4.0, AppTheme.SHOES)
	for i in 3:
		canvas.draw_circle(base + shake + Vector2(-6 + i * 6, 2), 1.5, AppTheme.METAL)
	if ringing:
		for i in 2:
			var radius := 14.0 + i * 8.0 + fmod(time * 10.0, 8.0)
			canvas.draw_arc(base + Vector2(0, -12), radius, -PI * 0.85, -PI * 0.15, 10, Color(AppTheme.accent("warning"), 0.8 - i * 0.3), 2.0)


static func switchboard(canvas: CanvasItem, base: Vector2, ringing: int, time: float) -> void:
	ItemPainter.shadow(canvas, base + Vector2(0, 24), 52, 7)
	canvas.draw_rect(Rect2(base + Vector2(-50, -70), Vector2(100, 92)), AppTheme.WOOD_FRONT)
	canvas.draw_rect(Rect2(base + Vector2(-50, -70), Vector2(100, 92)), AppTheme.WOOD_DARK, false, 2.0)
	canvas.draw_rect(Rect2(base + Vector2(-42, -62), Vector2(84, 48)), AppTheme.METAL_DARK)
	var blink := fmod(time, 0.5) < 0.25
	for i in SWITCHBOARD_LAMPS:
		var lamp := base + Vector2(-30 + (i % 4) * 20, -50 + floori(i / 4.0) * 22)
		var lit := i < ringing
		canvas.draw_circle(lamp, 6.0, AppTheme.accent("warning") if lit and blink else AppTheme.METAL)
		canvas.draw_arc(lamp, 6.0, 0, TAU, 12, AppTheme.SHOES, 1.5)
	for i in 5:
		canvas.draw_line(base + Vector2(-34 + i * 17, -4), base + Vector2(-30 + i * 15, 14), AppTheme.SHOES, 2.0)


static func toilet_stalls(canvas: CanvasItem, origin: Vector2, occupied: Array[bool]) -> void:
	canvas.draw_rect(Rect2(origin + Vector2(-4, -4), Vector2(264, 98)), AppTheme.METAL_DARK)
	for i in occupied.size():
		var door := Rect2(origin + Vector2(2 + i * 64, 0), Vector2(56, 88))
		canvas.draw_rect(door, AppTheme.FRIDGE.darkened(0.05))
		canvas.draw_rect(door, AppTheme.METAL_DARK, false, 2.0)
		for x in [14.0, 28.0, 42.0]:
			canvas.draw_line(door.position + Vector2(x, 10), door.position + Vector2(x, 70), AppTheme.METAL, 1.5)
		var lamp := AppTheme.accent("error") if occupied[i] else AppTheme.accent("success")
		canvas.draw_circle(door.position + Vector2(44, 44), 4.0, lamp)
		if occupied[i]:
			canvas.draw_rect(Rect2(door.position + Vector2(14, 82), Vector2(10, 6)), AppTheme.SHOES)
			canvas.draw_rect(Rect2(door.position + Vector2(32, 82), Vector2(10, 6)), AppTheme.SHOES)


static func mail_shelf(canvas: CanvasItem, rect: Rect2, stored: int, capacity: int) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(rect, AppTheme.WOOD_FRONT)
	canvas.draw_rect(rect, AppTheme.WOOD_DARK, false, 2.0)
	var boards := maxi(1, ceili(capacity / 8.0))
	var step := rect.size.y / boards
	var per_board := maxi(1, ceili(capacity / float(boards)))
	var slot_width := (rect.size.x - 16.0) / per_board
	for board in boards:
		var y := rect.position.y + step * (board + 1) - 4.0
		canvas.draw_rect(Rect2(Vector2(rect.position.x + 4, y), Vector2(rect.size.x - 8, 4)), AppTheme.WOOD_TOP)
		for slot in per_board:
			var index := board * per_board + slot
			if index >= stored:
				return
			var letter := Rect2(Vector2(rect.position.x + 8 + slot * slot_width, y - minf(22.0, step - 10.0)), Vector2(maxf(3.0, slot_width - 2.0), minf(22.0, step - 10.0)))
			canvas.draw_rect(letter, AppTheme.PAPER)
			canvas.draw_rect(letter, AppTheme.PAPER_EDGE, false, 1.0)


static func mailbox(canvas: CanvasItem, base: Vector2) -> void:
	canvas.draw_rect(Rect2(base + Vector2(-3, -10), Vector2(6, 30)), AppTheme.METAL_DARK)
	var box := Rect2(base + Vector2(-22, -44), Vector2(44, 36))
	canvas.draw_rect(Rect2(box.position + Vector2(2, 3), box.size), AppTheme.SHADOW_SOFT)
	canvas.draw_rect(box, AppTheme.POST_YELLOW)
	canvas.draw_rect(box, AppTheme.POST_YELLOW.darkened(0.35), false, 2.0)
	canvas.draw_rect(Rect2(box.position + Vector2(8, 8), Vector2(28, 4)), AppTheme.POST_HORN)
	canvas.draw_arc(box.get_center() + Vector2(0, 6), 7.0, 0, PI, 10, AppTheme.POST_HORN, 2.0)
