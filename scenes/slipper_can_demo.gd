extends Node2D

@onready var can_node: Variant = $Can
@onready var thrower: Variant = $Thrower
@onready var status_label: Label = $HUD/Status

const CAN_START: Vector2 = Vector2(960, 610)
var reset_key_held: bool = false


func _process(_delta: float) -> void:
	var reset_pressed: bool = Input.is_key_pressed(KEY_R)
	if reset_pressed and not reset_key_held and can_node.is_toppled() and can_node.is_settled():
		can_node.reset_for_preview(CAN_START)
	reset_key_held = reset_pressed
	if can_node.is_standing():
		status_label.text = "CAN READY  •  Aim at the can and hold M1 to charge"
	elif not can_node.is_settled():
		status_label.text = "CAN TUMBLING  •  Watch the bounce and roll"
	else:
		status_label.text = "CAN DOWN  •  Press R to reset this preview"
	if is_instance_valid(thrower.active_slipper) and thrower.active_slipper.is_resting():
		status_label.text += "    •    E picks up your slipper when close"


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.88, 0.82, 0.68))
	draw_rect(Rect2(0, 570, 1920, 510), Color(0.77, 0.68, 0.51))
	draw_line(Vector2(0, 570), Vector2(1920, 570), Color(0.51, 0.43, 0.31), 7.0, true)
	draw_line(Vector2(0, 690), Vector2(1920, 690), Color(0.94, 0.86, 0.67, 0.68), 5.0, true)
