extends "res://game/network_world.gd"

@export var local_player_id: int = 1

@onready var ready_panel: Control = $ReadyPanel/Player_ready
@onready var ready_button: Button = $HUD/Screen/ReadyButton
@onready var ready_status: Label = $HUD/Screen/ReadyStatus
@onready var start_button: Button = $HUD/Screen/StartButton
@onready var start_frame: Panel = $HUD/Screen/StartFrame
@onready var start_frame_style: StyleBoxFlat = start_frame.get_theme_stylebox("panel")
@onready var player: CharacterBody2D = $Player
@onready var practice_cans: Array[CharacterBody2D] = [$PracticeCan, $PracticeCan2, $PracticeCan3]

var practice_hits := 0
var practice_origins: Array[Vector2] = []
var start_glow: StyleBoxFlat
var starting := false
var room_code_button: Button
var bot_controls: PanelContainer
var bot_count_label: Label
var fewer_bots: Button
var more_bots: Button


func _ready() -> void:
	if LanSession.mode == "menu":
		LanSession.begin_local("developer")
	setup_network_world()
	local_player_id = LanSession.local_id()
	player = actors[local_player_id]
	LanSession.roster_changed.connect(_roster_changed)
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
		practice_origins.append(can.base.global_position)
		can.state_changed.connect(_on_can_state_changed.bind(can))
	_on_ready_toggled(false)
	_build_room_code()
	_build_bot_controls()
	_roster_changed()
	_refresh_start_button()
	if LanSession.mode == "practice":
		ready_button.hide()
		$HUD/Screen/ReadyFrame.hide()
		ready_status.hide()
		$ReadyPanel.hide()
		$HUD/Screen/Title.text = "FREE PRACTICE"
	$HUD/Screen/ResetPractice.visible = LanSession.is_host()
	$HUD/Screen/ResetFrame.visible = LanSession.is_host()


func _is_local_host() -> bool:
	return LanSession.is_host()


func _refresh_start_button() -> void:
	var host := _is_local_host()
	var can_start: bool = LanSession.can_start() and not starting
	start_button.visible = host and LanSession.mode != "practice"
	start_frame.visible = start_button.visible
	start_button.disabled = not can_start
	start_button.tooltip_text = "Start the game" if can_start else "Wait for another player, and make sure every member is ready." if LanSession.mode == "lan" and LanSession.players.size() < 2 else "Every player must be ready to start."
	start_frame.add_theme_stylebox_override("panel", start_glow if can_start else start_frame_style)
	$HUD/Screen/ReadyFrame.offset_left = -608.0 if host else -440.0
	$HUD/Screen/ReadyFrame.offset_right = -308.0 if host else -48.0
	ready_button.offset_left = -600.0 if host else -432.0
	ready_button.offset_right = -316.0 if host else -56.0
	ready_button.add_theme_font_size_override("font_size", 36 if host else 42)
	_refresh_bot_controls()


func _on_start_pressed() -> void:
	# Recheck at activation as readiness can change after the button was enabled.
	if starting or not LanSession.can_start():
		return
	starting = true
	_refresh_start_button()
	if not LanSession.start_match():
		starting = false
		ready_status.text = "COULDN'T START. TRY AGAIN."
		_refresh_start_button()


func _on_can_state_changed(_new_state: int, can: CharacterBody2D) -> void:
	if can.is_toppled():
		practice_hits += 1
		$HUD/Screen/PracticeHits.text = "%d %s" % [practice_hits, "HIT" if practice_hits == 1 else "HITS"]


func _reset_practice() -> void:
	if not LanSession.is_host():
		return
	# Keep the full Thrower scene's cancellation and retrieval behavior.
	player.set_taya_role(false)
	if is_instance_valid(player.active_slipper):
		player.active_slipper.queue_free()
	player.active_slipper = null
	for i in range(practice_cans.size()):
		var can := practice_cans[i]
		can.base.global_position = practice_origins[i]
		can.reset_for_preview(practice_origins[i])
	practice_hits = 0
	$HUD/Screen/PracticeHits.text = "0 HITS"


func _on_ready_toggled(is_ready: bool) -> void:
	LanSession.set_ready(is_ready)
	ready_status.text = "YOU ARE READY" if is_ready else "YOU ARE NOT READY"
	ready_button.text = "Not ready" if is_ready else "Ready"


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_leave()


func _leave() -> void:
	LanSession.close_room()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _roster_changed() -> void:
	ready_panel.set_roster(LanSession.players)
	var own: Dictionary = LanSession.member(local_player_id)
	if not own.is_empty():
		ready_button.set_pressed_no_signal(own.ready)
		ready_button.text = "Not ready" if own.ready else "Ready"
		ready_status.text = "YOU ARE READY" if own.ready else "YOU ARE NOT READY"
	_refresh_start_button()


func _build_room_code() -> void:
	room_code_button = Button.new()
	room_code_button.name = "RoomCode"
	room_code_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	room_code_button.offset_left = -825
	room_code_button.offset_right = -630
	room_code_button.offset_top = -145
	room_code_button.offset_bottom = -55
	room_code_button.add_theme_font_size_override("font_size", 23)
	room_code_button.text = "ROOM CODE\n" + LanSession.room_code if LanSession.mode == "lan" else "DEVELOPER\n%d BOTS" % LanSession.developer_bot_count if LanSession.mode == "developer" else "PRACTICE"
	room_code_button.tooltip_text = "Copy room code • Host IP: " + LanSession.host_address if LanSession.mode == "lan" else "Developer games and practice do not change saved statistics."
	room_code_button.pressed.connect(func() -> void:
		if LanSession.mode == "lan":
			DisplayServer.clipboard_set(LanSession.room_code)
	)
	$HUD/Screen.add_child(room_code_button)


func _build_bot_controls() -> void:
	if LanSession.mode != "developer" or not LanSession.is_host():
		return
	var ui = preload("res://ui/game_ui.gd")
	bot_controls = PanelContainer.new()
	bot_controls.name = "BotCount"
	bot_controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	bot_controls.offset_left = -440
	bot_controls.offset_right = -48
	bot_controls.offset_top = 704
	bot_controls.offset_bottom = 800
	bot_controls.add_theme_stylebox_override("panel", ui.panel())
	$HUD/Screen.add_child(bot_controls)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	bot_controls.add_child(row)
	bot_count_label = ui.label("", 26)
	bot_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(bot_count_label)
	fewer_bots = Button.new()
	more_bots = Button.new()
	for button in [fewer_bots, more_bots]:
		button.custom_minimum_size = Vector2(64, 56)
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, start_button.get_theme_stylebox(state))
		row.add_child(button)
	fewer_bots.text = "-"
	fewer_bots.tooltip_text = "Remove one bot"
	fewer_bots.pressed.connect(_change_bot_count.bind(-1))
	more_bots.text = "+"
	more_bots.tooltip_text = "Add one bot"
	more_bots.pressed.connect(_change_bot_count.bind(1))
	_refresh_bot_controls()


func _change_bot_count(change: int) -> void:
	if LanSession.mode != "developer" or not LanSession.is_host() or LanSession.phase != "waiting" or starting:
		return
	LanSession.developer_bot_count += change
	_refresh_bot_controls()


func _refresh_bot_controls() -> void:
	if bot_controls == null:
		return
	bot_controls.visible = not starting
	bot_count_label.text = "BOTS  %d" % LanSession.developer_bot_count
	fewer_bots.disabled = LanSession.developer_bot_count == 0
	more_bots.disabled = LanSession.developer_bot_count == LanSession.MAX_PLAYERS - 1
	bot_controls.tooltip_text = "No opponents; solo mechanics test." if LanSession.developer_bot_count == 0 else "Bots join when you press Start."
	room_code_button.text = "DEVELOPER\n%d %s" % [LanSession.developer_bot_count, "BOT" if LanSession.developer_bot_count == 1 else "BOTS"]


func _extra_snapshot() -> Dictionary:
	return {"hits": practice_hits}


func _apply_extra_snapshot(data: Dictionary) -> void:
	practice_hits = int(data.get("hits", 0))
	$HUD/Screen/PracticeHits.text = "%d HITS" % practice_hits
