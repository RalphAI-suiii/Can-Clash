extends Node2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var lifetime: float = 0.65


func _process(delta: float) -> void:
	position += direction * speed * delta
	rotation += TAU * 2.0 * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-29, -14), Vector2(-17, -20), Vector2(12, -19),
		Vector2(28, -12), Vector2(32, -1), Vector2(27, 11),
		Vector2(10, 17), Vector2(-16, 17), Vector2(-30, 9),
		Vector2(-33, -1),
	])
	var footbed: PackedVector2Array = PackedVector2Array([
		Vector2(-26, -10), Vector2(-16, -16), Vector2(11, -15),
		Vector2(24, -9), Vector2(28, -1), Vector2(23, 8),
		Vector2(9, 13), Vector2(-15, 13), Vector2(-27, 6),
	])
	var strap: PackedVector2Array = PackedVector2Array([
		Vector2(-10, -15), Vector2(2, -18), Vector2(12, -14),
		Vector2(14, 11), Vector2(3, 14), Vector2(-8, 12),
	])
	draw_colored_polygon(outline, Color("20130f"))
	draw_colored_polygon(footbed, Color("9b653d"))
	draw_colored_polygon(strap, Color("63391f"))
	draw_line(Vector2(-15, -11), Vector2(8, -12), Color("d1a16d"), 2.0, true)
	draw_line(Vector2(-20, 10), Vector2(13, 10), Color("4e2c1b"), 2.0, true)
