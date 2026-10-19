extends Node2D

@export var local_player_id: int = 1

@onready var ready_panel: Control = $ReadyPanel/Player_ready
@onready var ready_button: Button = $HUD/Screen/ReadyButton
@onready var ready_status: Label = $HUD/Screen/ReadyStatus


func _ready() -> void:
	ready_button.toggled.connect(_on_ready_toggled)
	$HUD/Screen/LeaveButton.pressed.connect(_leave)
	_on_ready_toggled(false)


func _on_ready_toggled(is_ready: bool) -> void:
	ready_panel.set_player_ready(local_player_id, is_ready)
	ready_status.text = "YOU ARE READY" if is_ready else "YOU ARE NOT READY"
	ready_button.text = "Not ready" if is_ready else "Ready"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()


func _leave() -> void:
	get_tree().change_scene_to_file("res://ui/lobby/lobby.tscn")
