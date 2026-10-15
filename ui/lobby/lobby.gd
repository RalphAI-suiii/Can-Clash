extends Control

@onready var back_button: Button = $Card/Back


func _ready() -> void:
	back_button.pressed.connect(_back_to_menu)


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
