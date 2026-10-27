extends SceneTree


func _initialize() -> void:
	create_timer(25.0).timeout.connect(func() -> void:
		printerr("FAIL: tag reset check timed out")
		quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("LanSession")
	session.begin_local("developer")
	session.add_developer_bots()
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	for actor in game.actors.values():
		actor.accept_local_input = false
		actor.set_meta("bot", false)
	var ids: Array = game.actors.keys()
	assert(ids.size() >= 3)
	var guard: CharacterBody2D = game.actors[ids[0]]
	var tagged: CharacterBody2D = game.actors[ids[1]]
	var other: CharacterBody2D = game.actors[ids[2]]
	game.stage = "active"
	game.remaining = 240.0
	game.phase_deadline = session.clock_time() + game.remaining
	game.taya_id = ids[0]
	guard.set_taya_role(true)
	guard.tag_ready_at = 0.0
	guard.position = Vector2(1190, 610)
	tagged.position = Vector2(1260, 610)
	other.position = Vector2(480, 610)
	tagged.set_skill_charge(2)
	other.set_skill_charge(1)
	guard.taya_stun_ready_at = session.clock_time() + 30.0
	var old_cooldown: float = guard.taya_stun_ready_at
	var slipper_script: GDScript = load("res://scenes/slipper_visual.gd")
	for actor in [tagged, other]:
		actor.active_slipper = slipper_script.new()
		game.add_child(actor.active_slipper)
		actor.set_meta("returning", true)
		actor.set_meta("left_safe", true)
		actor.set_meta("retrieved", true)
	other.rapid_remaining = 2
	var extra: Node2D = slipper_script.new()
	game.add_child(extra)
	other.rapid_slippers.append(extra)
	guard.taya_stun_projectile = Node2D.new()
	game.add_child(guard.taya_stun_projectile)
	var score_before: int = game.scores[ids[0]]
	game._tag_requested(tagged, guard)
	assert(game.stage == "tag_reset" and game.taya_id == ids[1])
	assert(game.can.is_standing())
	assert(game.scores[ids[0]] == score_before + 1)
	assert(game.remaining == 240.0)
	assert(tagged.is_taya and not guard.is_taya)
	assert(tagged.skill_charge == 2 and other.skill_charge == 1)
	assert(guard.taya_stun_ready_at == old_cooldown)
	for actor in game.actors.values():
		assert(not actor.accept_local_input and actor.movement_locked)
		assert(not is_instance_valid(actor.active_slipper) and actor.rapid_slippers.is_empty() and actor.rapid_remaining == 0)
		assert(not is_instance_valid(actor.taya_stun_projectile))
		assert(not actor.get_meta("returning", false))
	await physics_frame
	assert(game.can.is_standing(), "Canceled slippers must not hit the can during the reset")
	game._physics_process(1.0)
	assert(game.remaining == 240.0 and game.stage == "tag_reset", "Match clock must pause during the handoff")
	game.phase_deadline = session.clock_time() + game.TAG_RESET_SECONDS * 0.49
	game._physics_process(1.0 / 60.0)
	assert(game.tag_reset_repositioned)
	for id in ids:
		var actor: CharacterBody2D = game.actors[id]
		var expected: Vector2 = game.TAG_RESET_TAYA_START if id == game.taya_id else game._line_point(int(session.member(id).get("slot", 0)))
		assert(actor.position.distance_to(expected) < 0.1, "Player %s did not return to the assigned role position" % id)
	game.phase_deadline = session.clock_time() - 0.01
	game._physics_process(1.0 / 60.0)
	assert(game.stage == "active" and game.remaining == 240.0)
	assert(game.can.is_standing())
	assert(absf(game.phase_deadline - session.clock_time() - 240.0) < 0.2)
	assert(game.scores[ids[0]] == score_before + 1 and game.scores[ids[1]] == 0 and game.scores[ids[2]] == 0, "Canceled shots must award no points")
	print("PASS: host tag point, paused clock, canceled shots and burst, preserved charge/cooldown, toe-line reset, and resume")
	quit()
