extends Node2D

const DUST_COLOR: Color = Color(0.88, 0.75, 0.54)
const DUST_OUTLINE: Color = Color(0.43, 0.30, 0.18)
const CLOUD_KNOTS: Array[Vector2] = [
	Vector2(-48, 1), Vector2(-52, -10), Vector2(-46, -20),
	Vector2(-35, -23), Vector2(-28, -20), Vector2(-25, -31),
	Vector2(-14, -36), Vector2(-4, -33), Vector2(2, -40),
	Vector2(15, -39), Vector2(25, -31), Vector2(27, -24),
	Vector2(40, -24), Vector2(51, -14), Vector2(49, -3),
	Vector2(39, 5), Vector2(-38, 5),
]

var drift_direction: Vector2 = Vector2.ZERO
var lifetime: float = 0.52
var drift_speed: float = 44.0
var age: float = 0.0


func _process(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	position += drift_direction * drift_speed * delta
	queue_redraw()


func _draw() -> void:
	var progress: float = age / lifetime
	var fade: float = 1.0 - progress
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	for index in range(CLOUD_KNOTS.size()):
		var previous: Vector2 = CLOUD_KNOTS[(index - 1 + CLOUD_KNOTS.size()) % CLOUD_KNOTS.size()]
		var current: Vector2 = CLOUD_KNOTS[index]
		var following: Vector2 = CLOUD_KNOTS[(index + 1) % CLOUD_KNOTS.size()]
		var after: Vector2 = CLOUD_KNOTS[(index + 2) % CLOUD_KNOTS.size()]
		for section in range(4):
			var point: Vector2 = current.cubic_interpolate(following, previous, after, float(section) / 4.0)
			point = Vector2(point.x * (0.8 + progress * 0.5), point.y * (0.85 + progress * 0.4) - progress * 12.0)
			outline.append(point)
			fill.append(point * Vector2(0.94, 0.91) + Vector2(0, -progress * 1.1))
	draw_colored_polygon(outline, Color(DUST_OUTLINE.r, DUST_OUTLINE.g, DUST_OUTLINE.b, 0.52 * fade))
	draw_colored_polygon(fill, Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.78 * fade))
	draw_line(Vector2(-24, -17 - progress * 12), Vector2(-8, -24 - progress * 12), Color(1, 0.92, 0.75, 0.27 * fade), 2.0, true)
