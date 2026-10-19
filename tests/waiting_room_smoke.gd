extends SceneTree

## Run: godot --headless --path . --script res://tests/waiting_room_smoke.gd
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var panel: Control = scene.get_node("ReadyPanel/Player_ready")
	var button: Button = scene.get_node("HUD/Screen/ReadyButton")
	var player: CharacterBody2D = scene.get_node("Player")
	var background: Node2D = scene.get_node("Background")
	assert(background.get_child_count() == 3)
	assert(background.has_node("Backdrop") and background.has_node("Ground") and background.has_node("Decals"))
	assert(not background.has_node("World") and not background.has_node("Camera2D"))
	assert(panel.players.size() == 5)
	assert(not panel.players[0]["ready"])
	for row in panel.player_rows.values():
		assert(row is PanelContainer and not row is Button)

	# Clicking a roster row cannot ready a player.
	_click(panel.player_rows[1].get_global_rect().get_center())
	await process_frame
	assert(not panel.players[0]["ready"])

	# Only the bottom-right button changes the local player's status.
	_click(button.get_global_rect().get_center())
	await process_frame
	assert(panel.players[0]["ready"])
	for i in range(1, 5):
		assert(not panel.players[i]["ready"])
	assert(scene.get_node("HUD/Screen/ReadyStatus").text == "YOU ARE READY")
	_click(button.get_global_rect().get_center())
	await process_frame
	assert(not panel.players[0]["ready"])

	# Movement continues when ready, and the player stays on the empty court.
	button.button_pressed = true
	var start := player.position
	Input.action_press("right")
	for i in range(20):
		await physics_frame
	Input.action_release("right")
	assert(player.position.x > start.x + 10.0)
	assert(panel.players[0]["ready"])
	player.position = Vector2(10000, 10000)
	await physics_frame
	await physics_frame
	assert(player.position.x <= player.movement_bounds.end.x)
	assert(player.position.y <= player.movement_bounds.end.y)
	assert(button.get_global_rect().end.x <= scene.get_viewport_rect().size.x)
	assert(button.get_global_rect().end.y <= scene.get_viewport_rect().size.y)

	# Stable player IDs continue to work if someone leaves the middle of the list.
	panel.remove_player(2)
	panel.set_player_ready(3, true)
	assert(panel.players[1]["id"] == 3 and panel.players[1]["ready"])
	assert(not panel.player_rows.has(2))
	panel.set_player_ready(999, true)
	print("PASS: background only, non-clickable rows, ready/unready button, movement while ready, bounds, player IDs.")
	scene.free()
	quit()


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.global_position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
