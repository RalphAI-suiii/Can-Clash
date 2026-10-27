extends SceneTree

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		printerr("FAIL: tag reset LAN probe timed out")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var role: String = OS.get_cmdline_user_args()[0]
	print("LAN TAG PROBE START ", role)
	if role == "host":
		assert(session.host_room() == OK)
		assert(session.select_character(0))
	else:
		assert(session.join_room("127.0.0.1") == OK)
		while session.phase != "waiting" or session.member(session.local_id()).is_empty(): await process_frame
		assert(session.select_character(6))
	while session.players.size() < 2 or session.players.any(func(member: Dictionary) -> bool: return int(member.character) < 0):
		await process_frame
	print("LAN TAG PROBE ROSTER ", role, " ", session.players.size())
	var client_id: int = int(session.players[1].id)
	session.phase = "match"
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	print("LAN TAG PROBE MATCH ", role)
	if role == "host":
		game.taya_id = 1
		game._start_preparation()
		game._start_scoring()
		game.remaining = 200.0
		game.phase_deadline = session.clock_time() + game.remaining
		await create_timer(0.8).timeout
		var guard: CharacterBody2D = game.actors[1]
		var tagged: CharacterBody2D = game.actors[client_id]
		guard.position = Vector2(1190, 610)
		tagged.position = Vector2(1260, 610)
		guard.tag_ready_at = 0.0
		game.tag_immunity = 0.0
		var before: int = game.scores[1]
		game._tag_requested(tagged, guard)
		assert(game.stage == "tag_reset")
		while game.stage == "tag_reset": await process_frame
		assert(game.scores[1] == before + 1 and game.remaining > 196.0)
		assert(game.can.receive_slipper_hit(Vector2(400, 0), 1.0, game.can.get_hit_center()))
		await create_timer(0.8).timeout
		game.can.reset_for_preview(game.CAN_START)
		await create_timer(0.8).timeout
		print("PASS: LAN host tag reset, role handoff, paused clock, and can-state updates")
	else:
		var saw_reset := false
		var saw_reposition := false
		while game.stage != "active" or not saw_reset:
			await process_frame
			if game.stage == "tag_reset":
				saw_reset = true
				assert(game.taya_id == client_id and game.actors[client_id].is_taya)
				assert(game.tag_notice_id == client_id)
				assert(game.remaining > 196.0)
				if game.actors[1].position.distance_to(game._line_point(int(session.member(1).slot))) < 2.0:
					saw_reposition = true
		assert(saw_reposition, "Joiner did not see the toe-line reposition")
		assert(game.actors[client_id].position.distance_to(game.TAG_RESET_TAYA_START) < 5.0)
		assert(game.scores[1] == 1 and game.remaining > 196.0)
		while not game.can.is_toppled(): await process_frame
		while not game.can.is_standing(): await process_frame
		print("PASS: LAN joiner saw tag notice, roles, toe-line reset, score, resumed play, and can fall/reset")
	session.close_room()
	quit()
