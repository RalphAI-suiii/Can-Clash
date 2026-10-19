extends Camera2D

@export var top_y := 0.0
@export var bottom_y := 1190.0
@export var center_x := 940.0
@export var y_offset := -150.0  # negative = level moves down on screen

func _ready():
	var screen_h := get_viewport_rect().size.y
	var z := screen_h / (bottom_y - top_y)
	zoom = Vector2(z, z)
	global_position = Vector2(center_x, (top_y + bottom_y) / 2.0 + y_offset)
	limit_top = int(top_y + y_offset)
	limit_bottom = int(bottom_y + y_offset)
