@tool
extends Node2D

@export var rect := Rect2(0, 0, 1000, 700):
	set(v):
		rect = v
		queue_redraw()

func _draw() -> void:
	# soft grime where ground meets pavement (stacked translucent strokes)
	draw_rect(rect, Color(0.23, 0.16, 0.13, 0.08), false, 44.0)
	draw_rect(rect, Color(0.23, 0.16, 0.13, 0.10), false, 32.0)
	draw_rect(rect, Color(0.23, 0.16, 0.13, 0.12), false, 20.0)
	# curb: dark outline, then a lighter cool-gray top
	draw_rect(rect, Color("14141a"), false, 14.0)
	draw_rect(rect, Color("a9a5ad"), false, 7.0)
	
