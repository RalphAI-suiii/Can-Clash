extends SceneTree

func _initialize() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("FAIL: far-right can test timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	for index in range(3):
		session.begin_local("developer")
		session.selected_map = index
		session.add_developer_bots()
		var game: Node2D = load("res://game/match/match.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_physics_process(false)
		game._start_preparation()
		game._start_scoring()
		for actor in game.actors.values(): actor.set_physics_process(false)
		assert(game.can.position == Vector2(1450, 610) and game.can.base.position == game.can.position)
		var thrower: CharacterBody2D = game.actors.values().filter(func(actor: Node2D) -> bool: return not actor.is_taya)[0]
		thrower.network_controlled = true
		thrower.accept_local_input = true
		thrower.position = Vector2(495, 610)
		thrower.apply_network_input({"aim": game.can.get_hit_center()})
		thrower._start_charge()
		thrower._start_throw(thrower.sweet_spot * 1.25)
		thrower.attack_sprite.frame = 2
		thrower._on_attack_frame_changed()
		assert(is_instance_valid(thrower.active_slipper))
		for frame in range(240):
			await physics_frame
			if game.can.is_toppled(): break
		assert(game.can.is_toppled(), "A perfect throw from blue must reach the far-right can on map %d; slipper %s, speed %s, power %s" % [index, thrower.active_slipper.position, thrower.active_slipper.velocity, thrower.active_slipper.charge_ratio])
		for frame in range(500):
			await physics_frame
			if game.can.is_settled(): break
		assert(game.can.is_settled())
		var guard: CharacterBody2D = game.actors[game.taya_id]
		guard.position = game.can.position - Vector2(55, 0)
		assert(game.can.pick_up(guard))
		guard.carrying_can = true
		guard.position = game.CAN_START - Vector2(55, 0)
		assert(game.can.reset_at_base(guard))
		guard.carrying_can = false
		assert(game.can.position == Vector2(1450, 610))
		print("PASS: map ", index, " far-right can, green throw reach, manual return to far-right base")
		game.free()
		session.close_room()
		await process_frame
	quit(0)
