extends SceneTree

var session: Node
var role := "host"
var folder := ""
var baseline := false
var stress := false
var delayed_world: Node
var received_packets := 0
var applied_packets := 0
var apply_usec := 0
var last_world: Dictionary = {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	folder = args[1]
	baseline = args.size() > 2 and args[2] == "baseline"
	stress = args.has("stress")
	create_timer(25).timeout.connect(func() -> void: printerr("FAIL: responsiveness timeout ", role); quit(1))
	_run.call_deferred()

func _mark(name: String, data: Dictionary = {}) -> void:
	var file := FileAccess.open(folder.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func _exists(name: String) -> bool:
	return FileAccess.file_exists(folder.path_join(name))

func _room() -> void:
	var world: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(world)
	current_scene = world

func _enable_movement() -> void:
	assert(session.select_character(0))
	while int(session.member(session.local_id()).get("character", -1)) != 0: await process_frame
	while session.players.any(func(entry: Dictionary) -> bool: return entry.character < 0): await process_frame
	current_scene.selection_overlay.queue_free()
	await process_frame
	# This probe measures transport interpolation, so props must not stop its one-second walk.
	for actor in current_scene.actors.values(): actor.collision_mask = 0

func _delayed_snapshot(snapshot: Dictionary) -> void:
	# Delay only received snapshots: real ENet input and host simulation still run.
	received_packets += 1
	if received_packets % (5 if stress else 10) == 0: return
	await create_timer(0.16 if stress else 0.12).timeout
	if is_instance_valid(delayed_world):
		var started := Time.get_ticks_usec()
		delayed_world._apply_snapshot(snapshot)
		last_world = snapshot
		apply_usec += Time.get_ticks_usec() - started
		applied_packets += 1

func _run() -> void:
	session = root.get_node("LanSession")
	root.get_node("UserSettings").display_name = role
	if role == "host":
		assert(session.host_room() == OK)
		_room()
		while session.players.size() < 2: await process_frame
		await _enable_movement()
		while not _exists("measure"): await process_frame
		var start_sequence: int = session.world_sequence
		Input.action_press("right")
		await create_timer(1.0).timeout
		Input.action_release("right")
		print("HOST SNAPSHOTS: %d fps=%d" % [session.world_sequence - start_sequence, Engine.get_frames_per_second()])
		while not _exists("stopped"): await process_frame
		await create_timer(0.65).timeout
		var positions := {}
		for id in current_scene.actors: positions[str(id)] = {"x": current_scene.actors[id].position.x, "y": current_scene.actors[id].position.y}
		_mark("authoritative", positions)
		while not _exists("checked"): await process_frame
		session.close_room()
		print("PASS: host authoritative positions published")
	else:
		session.room_joined.connect(_room)
		assert(session.join_room(session.encode_address("127.0.0.1")) == OK)
		while current_scene == null or session.players.size() < 2: await process_frame
		await _enable_movement()
		delayed_world = current_scene
		session.world_snapshot_received.disconnect(current_scene._apply_snapshot)
		session.world_snapshot_received.connect(_delayed_snapshot)
		# Wait for startup imports/shaders before measuring steady-state packet cadence.
		while received_packets < 10: await process_frame
		await create_timer(0.2).timeout
		var own: CharacterBody2D = current_scene.actors[session.local_id()]
		var remote: CharacterBody2D = current_scene.actors[1]
		var initial := own.position
		var previous := own.position
		var previous_remote := remote.position
		var started := Time.get_ticks_usec()
		var latency_ms := -1.0
		var moving := 0
		var remote_moving := 0
		var frames := 0
		Input.action_press("down")
		_mark("measure")
		while Time.get_ticks_usec() - started < 1000000:
			await physics_frame
			await process_frame
			frames += 1
			if own.position.distance_to(previous) > 0.02: moving += 1
			if remote.position.distance_to(previous_remote) > 0.02: remote_moving += 1
			if latency_ms < 0.0 and own.position.distance_to(initial) > 0.02: latency_ms = (Time.get_ticks_usec() - started) / 1000.0
			previous = own.position
			previous_remote = remote.position
		Input.action_release("down")
		var checked_remote_frame := false
		for data in last_world.get("actors", []):
			if data.id != 1 or not String(data.sprite).contains("walk_"): continue
			var frame_count: int = remote.sprite.sprite_frames.get_frame_count(data.sprite)
			if frame_count < 2: continue
			var independent_frame: int = (int(data.frame) + 1) % frame_count
			remote.sprite.frame = independent_frame
			delayed_world._apply_snapshot(last_world)
			assert(remote.sprite.frame == independent_frame, "Remote walking frames must not be reset by each snapshot")
			checked_remote_frame = true
		assert(checked_remote_frame, "Expected a multi-frame remote walking animation")
		_mark("stopped")
		while not _exists("authoritative"): await process_frame
		await create_timer(0.3).timeout
		var authoritative: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("authoritative")))
		var host_position := Vector2(authoritative[str(session.local_id())].x, authoritative[str(session.local_id())].y)
		var drift := own.position.distance_to(host_position)
		var remote_position := Vector2(authoritative["1"].x, authoritative["1"].y)
		var remote_drift := remote.position.distance_to(remote_position)
		var metrics := {"response_ms": latency_ms, "moving_frames": moving, "remote_moving_frames": remote_moving, "frames": frames, "settled_drift_px": drift, "remote_settled_drift_px": remote_drift, "received_snapshots": received_packets, "apply_ms": float(apply_usec) / maxf(applied_packets, 1) / 1000.0}
		print("METRICS: ", JSON.stringify(metrics))
		_mark("metrics.json", metrics)
		if not baseline:
			assert(latency_ms >= 0 and latency_ms < 55, "Own movement should respond within a few physics frames despite delayed snapshots")
			assert(moving > frames * 0.75, "Own movement must progress smoothly at physics rate")
			assert(remote_moving > frames * 0.65, "Remote actor movement must be smoothed between snapshots")
			assert(drift < 3.0, "Prediction must converge back to authoritative position after stopping")
			assert(remote_drift < 3.0, "Remote smoothing must converge after stopping")
		_mark("checked")
		print("PASS: LAN responsiveness measurement completed")
	for player in root.get_node("Music").players: player.stop()
	await create_timer(0.1).timeout
	quit(0)
