class_name ConfettiView
extends Control

const GRAVITY := 980.0
const DRAG := 1.1
const LIFETIME := 2.0
const MAX_PIECES := 260
const PIECE_SIZE := Vector2(12, 7)
const SPARK_RADIUS := 4.0
const MIN_SPEED := 420.0
const MAX_SPEED := 980.0
const SPREAD := 1.25
const SPARK_SPEED := 260.0
const SPARK_LIFETIME := 0.6

var pieces: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func burst(center: Vector2, count: int) -> int:
	var colors := AppTheme.confetti_colors()
	var added := 0
	while added < count and pieces.size() < MAX_PIECES:
		var angle := -PI * 0.5 + rng.randf_range(-SPREAD, SPREAD)
		pieces.append({
			"pos": center,
			"vel": Vector2.from_angle(angle) * rng.randf_range(MIN_SPEED, MAX_SPEED),
			"rot": rng.randf_range(0.0, TAU),
			"spin": rng.randf_range(-9.0, 9.0),
			"flip": rng.randf_range(0.0, TAU),
			"color": colors[rng.randi() % colors.size()],
			"t": 0.0,
			"life": LIFETIME * rng.randf_range(0.7, 1.0),
			"spark": false,
		})
		added += 1
	queue_redraw()
	return added


func sparkle(center: Vector2, count: int, color: Color) -> int:
	var added := 0
	while added < count and pieces.size() < MAX_PIECES:
		var angle := TAU * float(added) / float(maxi(count, 1))
		pieces.append({
			"pos": center,
			"vel": Vector2.from_angle(angle) * SPARK_SPEED * rng.randf_range(0.7, 1.0),
			"rot": 0.0,
			"spin": 0.0,
			"flip": 0.0,
			"color": color,
			"t": 0.0,
			"life": SPARK_LIFETIME,
			"spark": true,
		})
		added += 1
	queue_redraw()
	return added


func advance(delta: float) -> void:
	var index := pieces.size() - 1
	while index >= 0:
		var piece := pieces[index]
		piece.t = float(piece.t) + delta
		if float(piece.t) >= float(piece.life):
			pieces.remove_at(index)
			index -= 1
			continue
		var velocity: Vector2 = piece.vel
		if not bool(piece.spark):
			velocity.y += GRAVITY * delta
		velocity *= maxf(0.0, 1.0 - DRAG * delta)
		piece.vel = velocity
		piece.pos = (piece.pos as Vector2) + velocity * delta
		piece.rot = float(piece.rot) + float(piece.spin) * delta
		piece.flip = float(piece.flip) + float(piece.spin) * delta * 1.3
		index -= 1
	queue_redraw()


func _process(delta: float) -> void:
	if not pieces.is_empty():
		advance(delta)


func _draw() -> void:
	for piece in pieces:
		var fade := 1.0 - pow(float(piece.t) / float(piece.life), 3.0)
		var color := Color(piece.color as Color, fade)
		if bool(piece.spark):
			draw_circle(piece.pos, SPARK_RADIUS * fade + 1.0, color)
			continue
		draw_set_transform(piece.pos, float(piece.rot), Vector2(1.0, maxf(0.15, absf(cos(float(piece.flip))))))
		draw_rect(Rect2(-PIECE_SIZE * 0.5, PIECE_SIZE), color)
	draw_set_transform_matrix(Transform2D.IDENTITY)
