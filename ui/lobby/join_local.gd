extends Control

@onready var address: LineEdit = $Card/Address
@onready var join_button: Button = $Card/Join
@onready var back_button: Button = $Card/Back
@onready var status: Label = $Card/Status


func _ready() -> void:
	join_button.pressed.connect(_join_pressed)
	back_button.pressed.connect(_back_to_menu)
	address.text_submitted.connect(func(_text: String) -> void: _join_pressed())
	address.placeholder_text = "Room code or host IP address"
	$Card/Instructions.text = "Enter a room code or address from your local network"
	$Card/AddressLabel.text = "ROOM CODE OR HOST IP"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 22)
	LanSession.connection_status_changed.connect(_set_status)
	LanSession.room_joined.connect(_joined)
	status.text = "Same LAN to join. Enter developer-mode to test alone with bots."


func _join_pressed() -> void:
	var value := address.text.strip_edges()
	if value.to_lower() == "developer-mode":
		LanSession.begin_local("developer")
		_joined()
		return
	join_button.disabled = LanSession.join_room(value) == OK


func _set_status(message: String) -> void:
	status.text = message
	if LanSession.phase != "joining":
		join_button.disabled = false


func _joined() -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/waiting_room/waiting_room.tscn")


func _back_to_menu() -> void:
	LanSession.close_room()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
