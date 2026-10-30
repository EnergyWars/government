extends SceneTree

const OUTPUT := "res://tools/upgrade_editor/web/assets/map.png"
const SCALE := 1.5
const VISIBLE_WIDTH := 720.0
const TILE_HEIGHT := 1280.0
const WAIT_FRAMES := 30

var _viewport: SubViewport
var _office: WorldView
var _layout: WorldLayout
var _canvas: Image
var _tiles: Array[Vector2] = []
var _frame := 0
var _index := 0


func _initialize() -> void:
	var state := GameState.create_new(1)
	for dept_id in GameConfig.department_ids():
		state.unlock_department(dept_id)
	state.set_upgrade("pneumatic_tubes", 1)
	for room_id in GameConfig.upgrade_rooms("tube_station"):
		state.set_upgrade("tube_station", 1, room_id)
	state.player.position = Vector2(-2000.0, -2000.0)
	var game := Game.new(state)
	_layout = WorldLayout.get_default()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(VISIBLE_WIDTH * SCALE), int(TILE_HEIGHT * SCALE))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	RenderingServer.set_default_clear_color(AppTheme.BACKGROUND)
	_office = WorldView.new()
	_viewport.add_child(_office)
	_office.setup(game, JoystickView.new())
	_canvas = Image.create(int(_layout.size.x * SCALE), int(_layout.size.y * SCALE), false, Image.FORMAT_RGBA8)
	_canvas.fill(AppTheme.BACKGROUND)
	for y in _starts(_layout.size.y, TILE_HEIGHT):
		for x in _starts(_layout.size.x, VISIBLE_WIDTH):
			_tiles.append(Vector2(x, y))


func _starts(total: float, step: float) -> Array[float]:
	var result: Array[float] = []
	var position := 0.0
	while position + step < total:
		result.append(position)
		position += step
	result.append(maxf(0.0, total - step))
	return result


func _process(_delta: float) -> bool:
	if _index >= _tiles.size():
		return false
	var origin := _tiles[_index]
	var centre := origin + Vector2(VISIBLE_WIDTH, TILE_HEIGHT) * 0.5
	_office.top_inset = 0.0
	_office.bottom_inset = 0.0
	_office.camera = centre
	_office._focus_point = centre
	_office._focus_left = 5.0
	_frame += 1
	if _frame < WAIT_FRAMES:
		return false
	var tile := _viewport.get_texture().get_image()
	tile.convert(Image.FORMAT_RGBA8)
	_canvas.blit_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(origin * SCALE))
	_frame = 0
	_index += 1
	if _index >= _tiles.size():
		_canvas.save_png(OUTPUT)
		print("map rendered: %s (%dx%d)" % [OUTPUT, _canvas.get_width(), _canvas.get_height()])
		quit()
	return false
