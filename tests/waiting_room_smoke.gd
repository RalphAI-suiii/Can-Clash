extends SceneTree

## Run: godot --headless --path . --script res://tests/waiting_room_smoke.gd
func _initialize() -> void:
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	create_timer(35.0).timeout.connect(func() -> void:
		printerr("FAIL: waiting-room check timed out")
		quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	var scene: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	var panel: Control = scene.get_node("ReadyPanel/Player_ready")
	var button: Button = scene.get_node("HUD/Screen/ReadyButton")
	var start: Button = scene.get_node("HUD/Screen/StartButton")
	var start_frame: Panel = scene.get_node("HUD/Screen/StartFrame")
	var player: CharacterBody2D = scene.get_node("Player")
	var can: CharacterBody2D = scene.get_node("PracticeCan")
	assert(scene.practice_cans.size() == 3)
	for target in scene.practice_cans:
		assert(target.is_standing())
	assert(player.get_script() == load("res://scenes/player_movement_neutral.gd"))
	assert(scene.get_node("Background/Room").texture.resource_path.ends_with("clubhouse.png"))
	assert(not scene.has_node("HUD/Screen/Help"))
	assert(panel.players.size() == 5 and not panel.players[0]["ready"])
	assert(start.visible and start.disabled)
	var inactive_style: StyleBoxFlat = start_frame.get_theme_stylebox("panel")
	scene._on_start_pressed()
	assert(not scene.starting)
	assert(button.get_global_rect().end.x < start.get_global_rect().position.x)
	for row in panel.player_rows.values():
		assert(row is PanelContainer and not row is Button)

	await _click(panel.player_rows[1].get_global_rect().get_center())
	assert(not panel.players[0]["ready"])
	assert(player.attack_state == player.AttackState.FREE)
	await _click(button.get_global_rect().get_center())
	assert(panel.players[0]["ready"])
	assert(player.attack_state == player.AttackState.FREE)
	assert(not is_instance_valid(player.active_slipper))
	for i in range(1, 5):
		assert(not panel.players[i]["ready"])
	await _click(button.get_global_rect().get_center())
	assert(not panel.players[0]["ready"])
	button.button_pressed = true

	# Walk from the room into the practice bay while ready.
	Input.action_press("left")
	await _frames(145)
	Input.action_release("left")
	assert(player.position.x < 1000.0)
	assert(panel.players[0]["ready"])

	# Use actual input and the full Thrower's release animation to hit the can.
	player.position = can.global_position + Vector2(360, 76)
	player.velocity = Vector2.ZERO
	_move_mouse(can.get_hit_center())
	await _frames(2)
	_mouse_button(can.get_hit_center(), true)
	await _frames(60)
	assert(player.attack_state == player.AttackState.CHARGING)
	assert(player.charge_bar.value > 0.3)
	_mouse_button(can.get_hit_center(), false)
	for i in range(90):
		await physics_frame
		if is_instance_valid(player.active_slipper):
			break
	assert(is_instance_valid(player.active_slipper))
	var slipper: Node2D = player.active_slipper
	assert(slipper.throw_owner == player and slipper.charge_ratio > 0.3)
	for i in range(180):
		await physics_frame
		if can.is_toppled():
			break
	assert(can.is_toppled() and scene.practice_hits == 1)
	assert(panel.players[0]["ready"])

	# The target resets automatically; retrieve the same slipper with E.
	for i in range(480):
		await physics_frame
		if can.is_standing() and slipper.is_resting():
			break
	assert(can.is_standing() and slipper.is_resting())
	player.position = slipper.global_position + Vector2(0, 42)
	player.velocity = Vector2.ZERO
	await _frames(2)
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	assert(not is_instance_valid(player.active_slipper))

	# Reset recovers a pending charged throw as well as resetting the practice count.
	player._start_charge()
	await _click(scene.get_node("HUD/Screen/ResetPractice").get_global_rect().get_center())
	assert(player.attack_state == player.AttackState.FREE)
	assert(scene.practice_hits == 0 and can.is_standing())
	assert(not is_instance_valid(player.active_slipper))

	# Each target counts a hit and returns to its own base automatically.
	for target in scene.practice_cans:
		assert(target.topple())
	assert(scene.practice_hits == 3)
	for i in range(480):
		await physics_frame
		if scene.practice_cans.all(func(target: CharacterBody2D) -> bool: return target.is_standing()):
			break
	for target in scene.practice_cans:
		assert(target.is_standing())
		assert(target.global_position.is_equal_approx(target.base.global_position))

	# Fast slippers bounce off the dividing line in both directions.
	var divider_x: float = scene.get_node("SlipperDivider").global_position.x
	for side in [-1.0, 1.0]:
		await _check_divider(scene, player, divider_x, side, 0.0)
		# The hand can be just before the line while the release art is beyond it.
		await _check_divider(scene, player, divider_x, side, 48.0)

	# The slipper-only layer must not block the player from either side.
	player.position = Vector2(divider_x - 80.0, 800)
	player.velocity = Vector2.ZERO
	Input.action_press("right")
	await _frames(40)
	Input.action_release("right")
	assert(player.position.x > divider_x + 30.0)
	await _click(scene.get_node("HUD/Screen/ResetPractice").get_global_rect().get_center())
	assert(scene.practice_hits == 0)
	for target in scene.practice_cans:
		assert(target.is_standing())

	player.position = Vector2(1740, 900)
	Input.action_press("right")
	await _frames(50)
	Input.action_release("right")
	assert(player.position.x < 1840.0)
	assert(button.get_global_rect().end.x <= scene.get_viewport_rect().size.x)
	assert(button.get_global_rect().end.y <= scene.get_viewport_rect().size.y)
	panel.remove_player(2)
	panel.set_player_ready(3, true)
	assert(panel.players[1]["id"] == 3 and panel.players[1]["ready"])
	assert(not panel.player_rows.has(2))
	for member in panel.players:
		panel.set_player_ready(member["id"], true)
	assert(not start.disabled)
	assert(start_frame.get_theme_stylebox("panel") == scene.start_glow)
	assert(scene.start_glow.shadow_size > inactive_style.shadow_size)
	await _click(button.get_global_rect().get_center())
	assert(start.disabled and not panel.players[0]["ready"])
	assert(start_frame.get_theme_stylebox("panel") == inactive_style)
	await _click(button.get_global_rect().get_center())
	assert(not start.disabled)

	# Guest previews never expose Start, even with a fully ready roster.
	scene.local_is_host = false
	assert(not start.visible and not start_frame.visible and start.disabled)
	scene._on_start_pressed()
	assert(not scene.starting)
	scene.local_is_host = true
	assert(start.visible and not start.disabled)
	panel.set_player_ready(3, false)
	assert(start.disabled)
	panel.remove_player(3)
	assert(not start.disabled)
	for member in panel.players.duplicate():
		panel.remove_player(member["id"])
	assert(start.disabled and not panel.all_players_ready())
	scene._on_start_pressed()
	assert(not scene.starting)

	# A ready host opens the existing playable level through the actual control.
	scene.free()
	scene = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await _frames(3)
	panel = scene.get_node("ReadyPanel/Player_ready")
	for member in panel.players:
		panel.set_player_ready(member["id"], true)
	await _click(scene.get_node("HUD/Screen/StartButton").get_global_rect().get_center())
	for i in range(10):
		if current_scene != null and current_scene.scene_file_path == "res://level/level.tscn":
			break
		await process_frame
	assert(current_scene != null and current_scene.scene_file_path == "res://level/level.tscn")
	print("PASS: practice mechanics, divider, ready controls, host-only Start, readiness glow, member removal, empty roster, and level transition.")
	quit()


func _check_divider(scene: Node2D, player: CharacterBody2D, divider_x: float, side: float, release_offset: float) -> void:
	var slipper: Node2D = load("res://scenes/slipper_visual.gd").new()
	scene.add_child(slipper)
	var direction := Vector2(-side, 0)
	var origin := Vector2(divider_x + side * (4.0 if release_offset > 0.0 else 120.0), 500)
	slipper.launch(player, origin + direction * release_offset, direction, 1.0, origin)
	slipper.velocity = direction * 14000.0
	for i in range(3):
		await physics_frame
		assert((slipper.global_position.x - divider_x) * side >= 0.0)
	assert(slipper.velocity.x * side > 0.0)
	slipper.free()


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _move_mouse(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * at
	motion.global_position = motion.position
	Input.parse_input_event(motion)


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = root.get_final_transform() * at
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	_move_mouse(at)
	await _frames(2)
	_mouse_button(at, true)
	await _frames(4)
	_mouse_button(at, false)
	await _frames(2)
