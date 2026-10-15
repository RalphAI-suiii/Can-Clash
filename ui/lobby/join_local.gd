extends Control

@onready var address: LineEdit = $Card/Address
@onready var join_button: Button = $Card/Join
@onready var back_button: Button = $Card/Back
@onready var status: Label = $Card/Status


func _ready() -> void:
	join_button.pressed.connect(_join_pressed)
	back_button.pressed.connect(_back_to_menu)
	address.text_submitted.connect(func(_text: String) -> void: _join_pressed())


func _join_pressed() -> void:
	if address.text.strip_edges().is_empty():
		status.text = "Enter the host's local IP address."
		address.grab_focus()
	else:
		status.text = "LAN joining will be connected later."


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
