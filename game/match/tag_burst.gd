extends Node2D

const LIFETIME := 0.65
var age := 0.0

func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := age / LIFETIME
	var fade := 1.0 - progress
	var radius := lerpf(22.0, 112.0, progress)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(1.0, 0.16, 0.12, fade), 11.0, true)
	draw_arc(Vector2.ZERO, radius - 10.0, 0.0, TAU, 48, Color(1.0, 0.88, 0.43, fade * 0.9), 4.0, true)
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(index * TAU / 8.0)
		draw_line(direction * (radius + 8.0), direction * (radius + 35.0), Color(1.0, 0.3, 0.15, fade), 7.0, true)
