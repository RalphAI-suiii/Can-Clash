extends Node2D

## Clear, grounded reset target for the can.
func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.39))
	draw_circle(Vector2.ZERO, 69.0, Color(0.10, 0.08, 0.05, 0.25))
	draw_set_transform(Vector2.ZERO)
	draw_arc(Vector2.ZERO, 61.0, 0.0, TAU, 48, Color(0.13, 0.09, 0.05), 6.0, true)
	draw_arc(Vector2.ZERO, 57.0, 0.0, TAU, 48, Color(1.0, 0.66, 0.12), 7.0, true)
	draw_arc(Vector2.ZERO, 39.0, 0.0, TAU, 48, Color(1.0, 0.92, 0.58, 0.85), 2.0, true)
