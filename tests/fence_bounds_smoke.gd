extends SceneTree

func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("FAIL: fence bounds timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	var cases := [
		[Vector2(340, 130), Vector2(-135, 0), Vector2(-180, 0), "Left Fence"],
		[Vector2(1500, 130), Vector2(180, 0), Vector2(180, 0), "Right Fence"],
		[Vector2(980, 300), Vector2(0, -190), Vector2(0, -180), "Top Fence"],
		[Vector2(980, 950), Vector2(0, 90), Vector2(0, 180), "Bottom"],
	]
	for index in range(3):
		session.begin_local("developer")
		session.selected_map = index
		session.add_developer_bots()
		for slot in range(session.players.size()):
			session.players[slot].character = [5, 6, 2, 3, 4][slot] if index == 1 else slot
		var game: Node2D = load("res://game/match/match.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_physics_process(false)
		game.set_process(false)
		var border: StaticBody2D = game.get_child(0).get_node("World/World Border")
		assert(game.ARENA == Rect2(153, 49, 1568, 1023))
		assert(game.SAFE == Rect2(140, 0, 390, 1072))
		assert(game.can.base.global_position == Vector2(1450, 610))
		for actor in game.actors.values():
			actor.set_physics_process(false)
			actor.position = Vector2(900, -1000 - int(actor.get_meta("peer_id")) * 100)
		await physics_frame
		await process_frame
		for actor in game.actors.values():
			assert(actor.arena_bounds == game.ARENA)
			# The fence collision is authoritative; the inset arena rectangle is approximate.
			for entry in cases:
				actor.global_position = entry[0]
				var approach: KinematicCollision2D = actor.move_and_collide(entry[1])
				if approach != null:
					assert(approach.get_collider() == border, "Only the visible fence may stop an approach: " + entry[3])
					assert(actor.global_position.distance_to(entry[0] + entry[1]) <= 25.0, "A character stopped too far from the visible fence: " + entry[3])
				var collision: KinematicCollision2D = actor.move_and_collide(entry[2])
				assert(collision != null and collision.get_collider() == border, "Visible fence must stop movement: " + entry[3])
				assert(border.shape_owner_get_owner(border.shape_find_owner(collision.get_collider_shape_index())).name == entry[3])
				if not game.ARENA.grow(2.0).has_point(actor.global_position):
					print("FENCE POSITION ", index, " ", actor.name, " ", entry[3], " ", actor.global_position)
				assert(game.ARENA.grow(2.0).has_point(actor.global_position))
			for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				actor.global_position = Vector2(1650 if corner.x > 0 else 220, 970 if corner.y > 0 else 120)
				var hit: KinematicCollision2D = actor.move_and_collide(corner * 300)
				assert(hit != null and hit.get_collider() == border, "Overlapping fence corners must have no gaps")
				if not game.ARENA.grow(2.0).has_point(actor.global_position):
					print("CORNER POSITION ", index, " ", actor.name, " ", corner, " ", actor.global_position)
				assert(game.ARENA.grow(2.0).has_point(actor.global_position))
			actor.position = Vector2(900, -1000)
		print("PASS: map ", index, " all five active characters reach the outer floor and are blocked by all four fences and corners; blue zone and can base preserved")
		game.free()
		session.close_room()
		await process_frame
	for player in root.get_node("Music").players: player.stop()
	await create_timer(0.1).timeout
	quit(0)
