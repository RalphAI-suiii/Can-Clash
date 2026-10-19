extends Node2D

@export var local_player_id: int = 1
# Offline preview role; connected peers use the multiplayer server role.
@export var local_is_host: bool = true:
	set(value):
		local_is_host = value
		if is_node_ready():
			_refresh_start_button()

const CAN_RESET_DELAY := 2.0

@onready var ready_panel: Control = $ReadyPanel/Player_ready
@onready var ready_button: Button = $HUD/Screen/ReadyButton
@onready var ready_status: Label = $HUD/Screen/ReadyStatus
@onready var start_button: Button = $HUD/Screen/StartButton
@onready var start_frame: Panel = $HUD/Screen/StartFrame
@onready var start_frame_style: StyleBoxFlat = start_frame.get_theme_stylebox("panel")
@onready var player: CharacterBody2D = $Player
@onready var practice_cans: Array[CharacterBody2D] = [$PracticeCan, $PracticeCan2, $PracticeCan3]

var practice_hits := 0
var reset_elapsed: Array[float] = [0.0, 0.0, 0.0]
var start_glow: StyleBoxFlat
var starting := false


func _ready() -> void:
	start_glow = start_frame_style.duplicate()
	start_glow.shadow_color = Color(1.0, 0.72, 0.12, 0.9)
	start_glow.shadow_size = 22
	start_glow.shadow_offset = Vector2.ZERO
	ready_panel.readiness_changed.connect(_refresh_start_button)
	start_button.pressed.connect(_on_start_pressed)
	ready_button.toggled.connect(_on_ready_toggled)
	$HUD/Screen/LeaveButton.pressed.connect(_leave)
	$HUD/Screen/ResetPractice.pressed.connect(_reset_practice)
	for can in practice_cans:
		can.state_changed.connect(_on_can_state_changed.bind(can))
	_on_ready_toggled(false)
	_refresh_start_button()


func _is_local_host() -> bool:
	if multiplayer.multiplayer_peer == null or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		return local_is_host
	return multiplayer.is_server()


func _refresh_start_button() -> void:
	var host := _is_local_host()
	var can_start: bool = host and ready_panel.all_players_ready() and not starting
	start_button.visible = host
	start_frame.visible = host
	start_button.disabled = not can_start
	start_button.tooltip_text = "Start the game" if can_start else "Every player must be ready to start."
	start_frame.add_theme_stylebox_override("panel", start_glow if can_start else start_frame_style)
	$HUD/Screen/ReadyFrame.offset_left = -608.0 if host else -440.0
	$HUD/Screen/ReadyFrame.offset_right = -308.0 if host else -48.0
	ready_button.offset_left = -600.0 if host else -432.0
	ready_button.offset_right = -316.0 if host else -56.0
	ready_button.add_theme_font_size_override("font_size", 36 if host else 42)


func _on_start_pressed() -> void:
	# Recheck at activation as readiness can change after the button was enabled.
	if starting or not _is_local_host() or not ready_panel.all_players_ready():
		return
	starting = true
	_refresh_start_button()
	var error := get_tree().change_scene_to_file("res://level/level.tscn")
	if error != OK:
		starting = false
		ready_status.text = "COULDN'T START. TRY AGAIN."
		_refresh_start_button()


func _process(delta: float) -> void:
	for i in range(practice_cans.size()):
		var can := practice_cans[i]
		if can.is_toppled() and can.is_settled():
			reset_elapsed[i] += delta
			if reset_elapsed[i] >= CAN_RESET_DELAY:
				can.reset_for_preview(can.base.global_position)
				reset_elapsed[i] = 0.0
		else:
			reset_elapsed[i] = 0.0


func _on_can_state_changed(_new_state: int, can: CharacterBody2D) -> void:
	if can.is_toppled():
		practice_hits += 1
		$HUD/Screen/PracticeHits.text = "%d %s" % [practice_hits, "HIT" if practice_hits == 1 else "HITS"]


func _reset_practice() -> void:
	# Keep the full Thrower scene's cancellation and retrieval behavior.
	player.set_taya_role(false)
	if is_instance_valid(player.active_slipper):
		player.active_slipper.queue_free()
	player.active_slipper = null
	for i in range(practice_cans.size()):
		var can := practice_cans[i]
		can.reset_for_preview(can.base.global_position)
		reset_elapsed[i] = 0.0
	practice_hits = 0
	$HUD/Screen/PracticeHits.text = "0 HITS"


func _on_ready_toggled(is_ready: bool) -> void:
	ready_panel.set_player_ready(local_player_id, is_ready)
	ready_status.text = "YOU ARE READY" if is_ready else "YOU ARE NOT READY"
	ready_button.text = "Not ready" if is_ready else "Ready"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()


func _leave() -> void:
	get_tree().change_scene_to_file("res://ui/lobby/lobby.tscn")
