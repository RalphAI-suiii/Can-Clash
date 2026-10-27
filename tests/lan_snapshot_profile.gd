extends SceneTree

## Headless CPU/packet-size probe for current lobby and match snapshots.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	session.begin_local("developer")
	assert(session.select_character(0))
	session.developer_bot_count = 4
	session.add_developer_bots()
	var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await process_frame
	_profile(room, "lobby")
	room.free()
	session.phase = "match"
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	_profile(game, "match")
	session.close_room()
	quit()

func _profile(world: Node2D, label: String) -> void:
	var count := 200
	var raw_size := 0
	var compressed_size := 0
	var started := Time.get_ticks_usec()
	for i in range(count):
		var raw := var_to_bytes(world._snapshot())
		var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
		raw_size += raw.size()
		compressed_size += packed.size()
	var elapsed_ms := (Time.get_ticks_usec() - started) / 1000.0
	print("SNAPSHOT_PROFILE %s actors=%d raw_bytes=%d compressed_bytes=%d build_encode_compress_ms=%.3f" % [label, world.actors.size(), raw_size / count, compressed_size / count, elapsed_ms / count])
