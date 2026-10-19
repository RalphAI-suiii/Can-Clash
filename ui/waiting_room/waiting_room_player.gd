extends "res://scenes/player_movement_base.gd"

## Movement only: clicking the Ready button must never charge or throw a slipper.
@export var movement_bounds := Rect2(-740, -420, 1480, 840)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	position = position.clamp(movement_bounds.position, movement_bounds.end)
