extends SceneTree

func _initialize() -> void:
	create_timer(40).timeout.connect(func() -> void: printerr("FAIL: developer options timeout"); quit(1))
	_run.call_deferred()

func _frames(count: int = 3) -> void:
	for i in range(count): await physics_frame
	await process_frame
	await process_frame

func _choose(picker: OptionButton, index: int) -> void:
	picker.select(index)
	picker.item_selected.emit(index)

func _run() -> void:
	var session := root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	var join: Control = load("res://ui/lobby/join_local.tscn").instantiate()
	root.add_child(join)
	current_scene = join
	assert(not join.status.text.to_lower().contains("developer"))
	assert(not join.address.placeholder_text.to_lower().contains("developer"))
	join.address.text = "developer-mode"
	join._join_pressed()
	await _frames()
	assert(session.mode == "developer" and current_scene.bot_controls != null, "Hidden developer entry must still work")
	current_scene.free()
	for map_index in range(3):
		for role_index in [1, 2]:
			session.begin_local("developer")
			session.developer_bot_count = 0
			session.developer_map = -1
			session.developer_role = "random"
			var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
			root.add_child(room)
			current_scene = room
			await _frames()
			assert(room.developer_map_picker.item_count == 4 and room.developer_role_picker.item_count == 3)
			_choose(room.developer_map_picker, map_index + 1)
			_choose(room.developer_role_picker, role_index)
			assert(session.developer_map == map_index)
			if role_index == 1:
				assert(session.developer_bot_count == 1 and room.fewer_bots.disabled, "Player always has a bot Taya")
				room.fewer_bots.pressed.emit()
				assert(session.developer_bot_count == 1)
			else:
				assert(session.developer_bot_count == 0 and room.fewer_bots.disabled, "Solo Taya stays available")
			room.more_bots.pressed.emit()
			room.ready_button.button_pressed = true
			room._on_start_pressed()
			await _frames(4)
			assert(session.selected_map == map_index, "Start honors chosen developer map")
			assert(current_scene.scene_file_path == "res://ui/map_select/map_select.tscn")
			current_scene.elapsed = 6.3
			await _frames(5)
			var game: Node2D = current_scene
			assert(game.scene_file_path == "res://game/match/match.tscn")
			game.set_physics_process(false)
			for actor in game.actors.values(): actor.set_physics_process(false)
			game._start_preparation()
			assert(game.actors[1].is_taya == (role_index == 2))
			assert((game.taya_id == 1) if role_index == 2 else (game.taya_id < 0))
			assert(game.remaining == 7.0)
			game._start_scoring()
			var guard: CharacterBody2D = game.actors[game.taya_id]
			var player: CharacterBody2D = game.actors.values().filter(func(actor: Node2D) -> bool: return not actor.is_taya)[0]
			guard.position = Vector2(1000, 650)
			player.position = Vector2(1030, 650)
			game._tag_requested(player, guard)
			assert(game.taya_id == player.get_meta("peer_id"), "Role override affects opening only; tags still transfer Taya")
			# A normal network mode ignores the developer opening-role preference.
			session.mode = "lan"
			seed(413)
			var roles := {}
			for i in range(30):
				game._start_preparation()
				roles[game.actors[1].is_taya] = true
			assert(roles.size() == 2)
			game.free()
			session.close_room()
			await _frames(2)
			print("PASS: map ", map_index, " role ", role_index, " selections survive Start/carousel; bot minimum, preparation and role transfers work; normal selection remains random")
	# Developer choices do not leak into normal lobby UI or map selection.
	session.begin_local("practice")
	var practice: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(practice)
	assert(practice.developer_map_picker == null and practice.developer_role_picker == null)
	practice.free()
	assert(session.host_room() == OK)
	session.developer_map = 2
	session.developer_role = "taya"
	session.players.append({"id": 2, "name": "Guest", "ready": true, "slot": 1, "character": 1, "color": Color.WHITE, "bot": false})
	var normal: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(normal)
	current_scene = normal
	assert(normal.developer_map_picker == null and normal.developer_role_picker == null)
	normal.ready_button.button_pressed = true
	assert(session.start_match())
	assert(session.selected_map == session.selection_seed % 3, "LAN uses normal random selection")
	await _frames(4)
	current_scene.free()
	session.close_room()
	for player in root.get_node("Music").players: player.stop()
	await create_timer(0.1).timeout
	print("PASS: developer shortcut hidden in Join; normal LAN and Practice have no developer selectors")
	quit(0)
