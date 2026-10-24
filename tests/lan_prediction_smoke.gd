extends SceneTree

func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("FAIL: LAN prediction unit timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("LanSession")
	session.begin_local("developer")
	session.add_developer_bots()
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process(false)
	for actor in game.actors.values():
		actor.set_physics_process(false)
		actor.position = Vector2(900, -1000 - int(actor.get_meta("peer_id")) * 100)
	await physics_frame
	await process_frame
	for actor in game.actors.values():
		var prediction: RefCounted = load("res://game/lan_movement.gd").new(actor)
		actor.set_taya_role(false)
		prediction.receive({"position": Vector2(1680, 130), "velocity": Vector2.ZERO, "lan_ack": 0}, true)
		for i in range(20): prediction.step(1.0 / 60.0, i + 1, {"move": Vector2.RIGHT, "sprint": true}, true)
		assert(prediction.position.x <= game.ARENA.end.x - 25.0, "Prediction respects the visible fence")
		prediction.receive({"position": Vector2(1600, 130), "velocity": Vector2.ZERO, "lan_ack": 19}, false)
		assert(prediction.pending.size() == 1 and prediction.pending[0].sequence == 20, "Replay only unacknowledged commands")
		assert(prediction.position.x > 1600 and prediction.position.x < 1602)
		prediction.receive({"position": Vector2(900, 400), "velocity": Vector2.ZERO, "lan_ack": 20}, true)
		assert(prediction.pending.is_empty() and actor.position == Vector2(900, 400), "Role/spawn transitions discard old movement immediately")
		actor.set_taya_role(true)
		prediction.receive({"position": Vector2(570, 610), "velocity": Vector2.ZERO, "lan_ack": 20}, true)
		for i in range(30): prediction.step(1.0 / 60.0, 21 + i, {"move": Vector2.LEFT, "sprint": true}, true)
		assert(prediction.position.x >= game.SAFE.end.x + 1.0, "Taya prediction cannot cross into the blue zone")
		prediction.receive({"position": Vector2(900, 400), "velocity": Vector2.ZERO, "lan_ack": 50}, true)
		prediction.step(1.0 / 60.0, 51, {"move": Vector2.RIGHT, "sprint": true}, false)
		assert(prediction.position == Vector2(900, 400), "Preparation/charge/action locks do not predict movement")
		prediction.last_snapshot = Time.get_ticks_msec() / 1000.0 - 0.4
		prediction.step(1.0 / 60.0, 52, {"move": Vector2.RIGHT, "sprint": true}, true)
		assert(prediction.position == Vector2(900, 400) and prediction.pending.size() == 1, "Prediction stops when host updates are stale")
		prediction.receive({"position": Vector2(900, 400), "velocity": Vector2.ZERO, "lan_ack": 52}, true)
		for i in range(100): prediction.step(1.0 / 60.0, 53 + i, {"move": Vector2.ZERO, "sprint": false}, true)
		assert(prediction.pending.size() == prediction.MAX_PENDING, "Input history is bounded")
		actor.position = Vector2(900, -1000)
	game.free()
	session.close_room()
	for player in root.get_node("Music").players: player.stop()
	await create_timer(0.1).timeout
	print("PASS: all five characters reconcile pending input, respect fences/Taya bounds and action locks, snap role/spawn changes, and stop stale prediction with bounded history")
	quit(0)
