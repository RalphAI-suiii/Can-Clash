extends SceneTree

## Run: godot --headless --path . --script res://tests/post_lobby_character_select_smoke.gd
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var profile: Node = root.get_node("UserSettings")
	profile.selected_character_scene = session.CHARACTER_SCENES[0]
	session.begin_local("developer")
	assert(session.member(1).character == -1)
	var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	for i in range(4):
		await process_frame
	assert(is_instance_valid(room.selection_overlay))
	assert(room.selection_overlay.popup_mode)
	assert(not room.selection_overlay.get_node("Background").visible)
	assert(room.ready_button.disabled)
	assert(not room._local_inputs_enabled())
	room.selection_overlay._select(6)
	room.selection_overlay._confirm()
	for i in range(5):
		await process_frame
	assert(session.member(1).character == 6)
	assert(profile.selected_character_scene == session.CHARACTER_SCENES[6])
	assert(not is_instance_valid(room.selection_overlay))
	assert(not room.ready_button.disabled)
	assert(room._local_inputs_enabled())
	print("PASS: room opens first, character popup claims Kay, then lobby controls return")
	session.close_room()
	quit()
