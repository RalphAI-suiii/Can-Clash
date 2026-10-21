extends SceneTree

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("FAIL: spawn movement check timed out")
		quit(1)
	)
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	for map_index in range(3):
		session.begin_local("developer")
		session.selected_map = map_index
		for slot in range(1, 5):
			session.players.append({"id": -slot, "name": "Bot %d" % slot, "ready": true, "slot": slot, "character": slot, "color": session.COLORS[slot], "bot": true})
		var game: Node2D = load("res://game/match/match.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		for actor in game.actors.values():
			actor.set_meta("bot", false)
		for phase in ["grace", "active"]:
			if phase == "active":
				game._start_scoring()
			var positions: Dictionary = {}
			for id in game.actors:
				positions[id] = game.actors[id].position
			await _frames(5)
			assert(game.stage == phase)
			for id in game.actors:
				var actor: CharacterBody2D = game.actors[id]
				assert(actor.position.distance_to(positions[id]) < 2.0, "Map %d %s player %s spawns inside scenery" % [map_index, phase, id])
				if id == 1:
					var key := InputEventKey.new()
					key.physical_keycode = KEY_D
					key.pressed = true
					Input.parse_input_event(key)
				else:
					actor.apply_network_input({"move": Vector2.RIGHT})
				await _frames(30)
				if id == 1:
					var key := InputEventKey.new()
					key.physical_keycode = KEY_D
					Input.parse_input_event(key)
				else:
					actor.apply_network_input({"move": Vector2.ZERO})
				assert(actor.position.x - positions[id].x > 60.0, "Map %d %s player %s cannot leave spawn" % [map_index, phase, id])
				actor.position = positions[id]
				actor.velocity = Vector2.ZERO
				await _frames(2)
		print("PASS: map %d, all five spawns in grace and active play; keyboard and remote movement." % map_index)
		game.free()
		session.close_room()
		await _frames(2)
	quit()
