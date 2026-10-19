@tool
extends Node2D


func _draw() -> void:
	draw_set_transform(Vector2(9, 8), 0.0, Vector2(1.0, 0.3))
	for ring in range(6, 0, -1):
		draw_circle(Vector2.ZERO, 54.0 + ring * 3.0, Color(0.12, 0.07, 0.03, 0.045))
