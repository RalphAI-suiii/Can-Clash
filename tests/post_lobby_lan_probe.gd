extends SceneTree

## Run two processes with: --script res://tests/post_lobby_lan_probe.gd -- host|client
func _initialize() -> void:
	create_timer(12.0).timeout.connect(func() -> void:
		printerr("FAIL: post-lobby character claim timed out")
		quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var role := OS.get_cmdline_user_args()[0]
	if role == "host":
		assert(session.host_room() == OK)
		print("HOST ADDRESS: %s ROOM: %s" % [session.host_address, session.room_code])
		assert(session.member(1).character == -1)
		while session.players.size() < 2:
			await process_frame
		assert(session.players[1].character == -1)
		assert(session.select_character(6))
		while session.players[1].character != 6:
			await process_frame
		assert(session.players[0].character == 6)
	else:
		var address := OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else "127.0.0.1"
		assert(session.join_room(address) == OK)
		while session.phase != "waiting" or session.member(session.local_id()).is_empty():
			await process_frame
		assert(session.member(session.local_id()).character == -1)
		assert(session.select_character(6))
		while session.member(session.local_id()).character != 6:
			await process_frame
	print("PASS: %s joined unselected and chose Kay in the room" % role)
	if role == "host":
		await create_timer(2.0).timeout
	session.close_room()
	quit()
