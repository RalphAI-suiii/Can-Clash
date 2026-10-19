extends Node2D

const LIFETIME: float = 0.30

var direction: Vector2 = Vector2.RIGHT
var charge_ratio: float = 0.0
var age: float = 0.0


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress: float = age / LIFETIME
	var fade: float = 1.0 - progress
	var power: float = clampf(charge_ratio, 0.0, 1.0)
	var radius: float = lerpf(15.0, 55.0 + power * 18.0, progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(0.91, 0.43, 0.12, 0.57 * fade), 6.0, true)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 36, Color(1.0, 0.91, 0.55, 0.68 * fade), 2.0, true)
	for index in range(7):
		var ray: Vector2 = direction.rotated((index - 3) * 0.23)
		var start: float = 19.0 + progress * 11.0
		var finish: float = 35.0 + progress * (26.0 + power * 20.0)
		draw_line(ray * start, ray * finish, Color(1.0, 0.79, 0.29, 0.72 * fade), 4.0, true)
