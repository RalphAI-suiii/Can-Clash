extends Control

@onready var quick_play: Button = $QuckPlay
@onready var play_local: Button = $PlayLocal
@onready var popup: Control = $LocalPlayPopup
@onready var backdrop: ColorRect = $LocalPlayPopup/Backdrop
@onready var card: Panel = $LocalPlayPopup/Card
@onready var host: Button = $LocalPlayPopup/Card/Host
@onready var join: Button = $LocalPlayPopup/Card/Join
@onready var close_button: Button = $LocalPlayPopup/Card/Close
var popup_tween: Tween


func _ready() -> void:
	quick_play.pressed.connect(_open_character_select)
	play_local.pressed.connect(_show_local_popup)
	host.pressed.connect(_open_host)
	join.pressed.connect(_open_join)
	close_button.pressed.connect(_hide_local_popup)
	backdrop.gui_input.connect(_on_backdrop_input)


func _show_local_popup() -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()
	popup.show()
	backdrop.modulate.a = 0.0
	card.modulate.a = 0.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(card, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	host.grab_focus()


func _hide_local_popup() -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()
	popup.hide()
	play_local.grab_focus()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_local_popup()


func _unhandled_key_input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		_hide_local_popup()
		get_viewport().set_input_as_handled()


func _open_host() -> void:
	get_tree().change_scene_to_file("res://ui/lobby/lobby.tscn")


func _open_join() -> void:
	get_tree().change_scene_to_file("res://ui/lobby/join_local.tscn")


func _open_character_select() -> void:
	get_tree().change_scene_to_file("res://ui/character_select/character_select.tscn")
