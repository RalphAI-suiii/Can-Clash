extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("LanSession")
	session.begin_local("developer")
	session.add_developer_bots()
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	assert(game.title_sfx.stream.get_length() > 0.3)
	assert(game.tick_sfx.stream.get_length() > 0.1)
	assert(game.go_sfx.stream.get_length() > 0.3)
	assert(game.can_sfx.stream.get_length() > 0.3)
	game._start_intro()
	game._update_match_sfx()
	assert(game.title_sfx.playing, "Throw Off title should sound when its slide starts")
	game._start_run_to_line()
	game._update_match_sfx()
	for count in [3, 2, 1]:
		game.remaining = float(count) - 0.1
		game._update_hud()
		game._update_match_sfx()
		assert(game.last_countdown == count and game.tick_sfx.playing, "Each countdown number should sound")
		assert(game.opening_label.text == str(count), "Sound and visible countdown should agree")
		if count == 3 and DisplayServer.get_name() != "headless":
			for frame in range(12): await process_frame
			assert(root.get_texture().get_image().save_png("res://tests/throwoff_countdown_preview.png") == OK)
	for id in game.actors:
		game.actors[id].position = game._line_point(int(session.member(id).slot))
	game.phase_deadline = session.clock_time() + 2.0
	game._physics_process(0.016)
	assert(game.stage == "run_to_line", "Early arrivals should still get the full countdown")
	game.phase_deadline = session.clock_time() - 0.01
	game._physics_process(0.016)
	game._update_match_sfx()
	assert(game.stage == "throw_off" and game.go_sfx.playing, "Throw opening should sound when inputs unlock")
	game.can.reset_for_preview(game.CAN_START)
	game._update_match_sfx()
	assert(game.can.receive_slipper_hit(Vector2(320, 0), 0.2, game.can.get_hit_center()))
	game._update_match_sfx()
	var weak_volume: float = game.can_sfx.volume_db
	assert(game.can_sfx.playing, "A confirmed can hit should sound")
	game.can.reset_for_preview(game.CAN_START)
	game._update_match_sfx()
	game.can_sfx.stop()
	game.can.state = game.can.State.TOPPLED
	game.can.hit_flash_remaining = 0.0
	game._update_match_sfx()
	assert(not game.can_sfx.playing, "A stale can state change should stay quiet")
	game.can.reset_for_preview(game.CAN_START)
	game._update_match_sfx()
	assert(game.can.receive_slipper_hit(Vector2(900, 0), 1.0, game.can.get_hit_center()))
	game._update_match_sfx()
	assert(game.can_sfx.volume_db > weak_volume, "Fast impacts should sound stronger")
	var snapshot: Dictionary = game._snapshot()
	assert(float(snapshot.cans[0].impact) > 0.8, "Joiners should receive impact strength")
	print("PASS: Throw Off title, 3-2-1 countdown, launch, and can-impact sounds")
	quit()
