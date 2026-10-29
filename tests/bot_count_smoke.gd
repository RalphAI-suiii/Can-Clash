extends SceneTree

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func() -> void:
		printerr("FAIL: bot count check timed out")
		quit(1)
	)
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame
	await process_frame

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	assert(session.developer_bot_count == 4)
	for count in range(5):
		session.begin_local("developer")
		var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
		root.add_child(room)
		current_scene = room
		await _frames(3)
		assert(room.bot_controls.visible)
		for i in range(5):
			room.fewer_bots.pressed.emit()
		assert(session.developer_bot_count == 0 and room.fewer_bots.disabled)
		for i in range(count):
			room.more_bots.pressed.emit()
		assert(session.developer_bot_count == count)
		assert(room.bot_count_label.text == "BOTS  %d" % count)
		assert(room.more_bots.disabled == (count == 4))
		assert(session.players.size() == 1, "Bots join at Start")
		assert(room.player.attack_state == room.player.AttackState.FREE)
		assert(session.select_character(0), "Developer must claim a character before Ready")
		room.ready_button.button_pressed = true
		room._on_start_pressed()
		await _frames(4)
		assert(session.players.size() == count + 1)
		assert(current_scene.scene_file_path == "res://ui/map_select/map_select.tscn")
		current_scene.elapsed = 6.3
		await _frames(5)
		var game: Node2D = current_scene
		assert(game.scene_file_path == "res://game/match/match.tscn")
		assert(game.actors.size() == count + 1)
		for actor in game.actors.values():
			assert(actor.scale.is_equal_approx(Vector2.ONE * game.player_scale))
			assert(is_equal_approx(actor.get_node("CollisionShape2D").global_scale.x, game.player_scale))
			assert(actor.throw_status.get_global_transform().get_scale().is_equal_approx(Vector2.ONE))
			assert(actor.get_throw_origin().is_equal_approx(actor.global_position + actor.THROW_ORIGIN * game.player_scale))
		game.taya_id = int(game.actors.keys()[0])
		game._start_preparation()
		game._start_scoring()
		assert(game.actors.has(game.taya_id) and game.actors[game.taya_id].is_taya)
		var player: CharacterBody2D = game.actors[1]
		var initial := player.position
		Input.action_press("right")
		await _frames(30)
		Input.action_release("right")
		assert(player.position.x > initial.x + 60, "Local player remains movable")
		if count == 0:
			assert(game.can.topple())
			await _frames(360)
			assert(game.can.is_toppled(), "Solo Taya must also reset the can manually")
			player.position = game.can.position - Vector2(55, 0)
			assert(game.can.pick_up(player))
			player.carrying_can = true
			player.position = game.can.base.position - Vector2(55, 0)
			assert(game.can.reset_at_base(player))
			player.carrying_can = false
		game.free()
		session.close_room()
		await _frames(2)
		print("PASS: %d bots, lobby controls, real Start/map flow, role selection, scaled colliders/throw origin and local movement." % count)
	# Running the match directly uses the same selected count.
	session.developer_bot_count = 2
	var direct: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(direct)
	current_scene = direct
	await _frames(3)
	assert(direct.actors.size() == 3)
	direct.free()
	session.begin_local("practice")
	var practice: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(practice)
	await _frames(3)
	assert(practice.bot_controls == null)
	practice.free()
	session.close_room()
	print("PASS: direct match honors bot count; Practice has no bot controls.")
	quit()
