extends Node2D

const CAN := preload("res://assets/characters/sprites/taya/tin_can_upright.png")
const SLIPPER := preload("res://scenes/slipper_visual.gd")
var item: StringName = &"":
	set(value):
		if item != value:
			item = value
			queue_redraw()
		visible = item != &""

func _draw() -> void:
	if item == &"": return
	draw_circle(Vector2(3, 5), 32, Color(0.12, 0.08, 0.04, 0.28))
	draw_circle(Vector2.ZERO, 31, Color("291b13"))
	draw_circle(Vector2.ZERO, 26, Color("fff1c6"))
	if item == &"can":
		draw_texture_rect_region(CAN, Rect2(-12, -18, 24, 36), Rect2(397, 295, 486, 655))
	else:
		draw_set_transform(Vector2.ZERO, -0.65, Vector2.ONE * 0.6)
		SLIPPER.draw_footwear(self)
