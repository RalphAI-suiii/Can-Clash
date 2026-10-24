extends SceneTree

func _initialize() -> void:
	create_timer(65.0).timeout.connect(func() -> void:
		printerr("FAIL: adjustments flow timed out")
		quit(1)
	)
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame
	await process_frame

func _run() -> void:
	var session: Node = root.get_node("LanSession")
	var profile: Node = root.get_node("UserSettings")
	for address in ["127.0.0.1", "192.168.1.2", "10.0.0.45"]:
		assert(session.decode_code(session.encode_address(address)) == address)
	assert(session.decode_code("INVALID").is_empty())
	assert(session.decode_code("ZZZZZZZ").is_empty())
	var menu: Control = load("res://ui/main_menu/main_menuu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.name_input.text = "  Test Player  "
	menu._save_name()
	assert(profile.display_name == "Test Player")
	assert(menu.has_node("Practice") and menu.has_node("Statistics"))
	menu._open_practice()
	await _frames(5)
	var room: Node2D = current_scene
	assert(session.mode == "practice" and room.actors.size() == 1)
	assert(not room.start_button.visible and not room.ready_button.visible)
	assert(room.practice_cans.size() == 3)
	room._leave()
	await _frames(4)
	current_scene._open_join()
	await _frames(4)
	current_scene.address.text = "developer-mode"
	profile.tutorial_seen = false
	current_scene._join_pressed()
	await _frames(5)
	room = current_scene
	assert(session.mode == "developer" and session.players.size() == 1)
	assert(room.ready_panel.players.size() == 1)
	assert(room.ready_panel.player_rows.size() == 1)
	assert(room.room_code_button.text.contains("DEVELOPER"))
	room.ready_button.button_pressed = true
	assert(session.all_ready() and not room.start_button.disabled)
	room._on_start_pressed()
	await _frames(5)
	assert(current_scene.scene_file_path == "res://ui/map_select/map_select.tscn")
	assert(session.players.size() == 5 and session.players[1].bot)
	assert(current_scene.cards.size() == 3)
	current_scene.elapsed = 4.99
	await _frames(3)
	assert(current_scene.landed and current_scene.caption.text.contains("SELECTED"))
	current_scene.elapsed = 6.3
	await _frames(6)
	var game: Node2D = current_scene
	assert(game.scene_file_path == "res://game/match/match.tscn")
	assert(game.actors.size() == 5 and game.stage == "tutorial" and game.tutorial_open)
	await _frames(10)
	assert(game.remaining == 7.0)
	for button in game.find_children("*", "Button", true, false):
		if button.text.begins_with("Got it"):
			button.pressed.emit()
	await _frames(4)
	assert(profile.tutorial_seen and game.stage == "preparation")
	assert(game.remaining > 6.0 and game.remaining <= 7.0)
	game.remaining = 0.01
	await _frames(4)
	assert(game.stage == "active" and game.remaining > 599.0)
	assert(game.actors.has(game.taya_id) and game.actors[game.taya_id].is_taya)
	var moving_bot: Node2D = game.actors.values().filter(func(actor: Node2D) -> bool: return actor.get_meta("bot", false) and not actor.is_taya)[0]
	var original_bot: Vector2 = moving_bot.position
	await _frames(240)
	assert(moving_bot.position.distance_to(original_bot) > 30.0, "Bots must move")
	assert(not game.observed_slippers.is_empty(), "Bots must throw")
	for actor in game.actors.values():
		actor.set_meta("bot", false)
		actor.apply_network_input({"move": Vector2.ZERO})
		# Isolate projectile assertions from the bots' final collision positions.
		if actor.get_meta("peer_id") != 1:
			actor.collision_layer = 0
			actor.set_physics_process(false)
		if is_instance_valid(actor.active_slipper):
			actor.active_slipper.free()
		actor.active_slipper = null
	game.taya_id = -1
	game.actors[-1].set_taya_role(true)
	game.can.reset_for_preview(game.can.base.position)
	game.tag_immunity = 10.0
	var player: CharacterBody2D = game.actors[1]
	player.set_taya_role(false)
	player.accept_local_input = true
	player.position = Vector2(700, 700)
	var before_score: int = game.scores[1]
	var slipper: Node2D = load("res://scenes/slipper_visual.gd").new()
	game.add_child(slipper)
	var launch: Vector2 = game.can.get_hit_center() - Vector2(120, 0)
	slipper.launch(player, launch, Vector2.RIGHT, 1.0, launch)
	slipper.outline_color = player.player_color
	slipper.arena_bounds = game.ARENA
	player.active_slipper = slipper
	for i in range(50):
		await physics_frame
		if game.can.is_toppled():
			break
	assert(game.can.is_toppled() and game.can.hit_flash_remaining > 0.0)
	assert(game.scores[1] == before_score + 1)
	assert(slipper.hit_registered and slipper.outline_color == player.player_color)
	for i in range(150):
		await physics_frame
		if slipper.floor_bounces > 0:
			break
	player.position = slipper.position + Vector2(0, 30)
	await _frames(3)
	assert(not is_instance_valid(player.active_slipper))
	player.position = game.SAFE.get_center()
	await _frames(3)
	assert(game.scores[1] == before_score + 2, "One actual retrieval and safe return earns one point")
	var after_return: int = game.scores[1]
	var lost: Node2D = load("res://scenes/slipper_visual.gd").new()
	game.add_child(lost)
	launch = Vector2(game.ARENA.end.x - 2, 700)
	lost.launch(player, launch, Vector2.RIGHT, 1.0, launch)
	lost.arena_bounds = game.ARENA
	player.active_slipper = lost
	await _frames(3)
	assert(lost.lost_remaining > 2.8 and not lost.visible)
	assert(not lost.can_pick_up(player))
	assert(player.throw_status.text.contains("RETURNS"))
	await _frames(185)
	assert(not is_instance_valid(player.active_slipper))
	assert(game.scores[1] == after_return, "Penalty respawn must not award a safe return")
	var prediction: PackedVector2Array = load("res://scenes/slipper_visual.gd").predict_path(game.get_world_2d(), Vector2(700, 500), Vector2(700, 500), Vector2.RIGHT, 1.0, [])
	assert(prediction.size() > 3 and prediction[-1].x > 900.0)
	var probe: Node2D = load("res://scenes/slipper_visual.gd").new()
	game.add_child(probe)
	launch = Vector2(1100, 400)
	var expected: PackedVector2Array = load("res://scenes/slipper_visual.gd").predict_path(game.get_world_2d(), launch, launch, Vector2.LEFT, 0.5, [])
	probe.launch(player, launch, Vector2.LEFT, 0.5, launch)
	for i in range(100):
		await physics_frame
		if probe.floor_bounces > 0:
			break
	assert(probe.floor_bounces > 0 and probe.position.distance_to(expected[-1]) < 2.0, "Predicted landing must match actual physics, including cover ricochets")
	probe.free()
	var old_wins: int = profile.statistics.wins
	game.remaining = 0.01
	await _frames(6)
	assert(current_scene.scene_file_path == "res://ui/results/results.tscn")
	assert(session.results.size() == 5 and profile.statistics.wins == old_wins)
	var old_hits: int = profile.statistics.successful_throws
	profile.record_hit()
	profile.record_result("smoke-result", true)
	profile.record_result("smoke-result", true)
	profile.load_profile()
	assert(profile.statistics.successful_throws == old_hits + 1)
	assert(profile.statistics.wins == old_wins + 1)
	assert(profile.tutorial_seen and profile.display_name == "Test Player")
	print("PASS: names, Practice, developer entry, one-member roster, ready Start, roulette, seven-second preparation and ten-minute match phases, four active bots, hit feedback/scoring, trajectory, out-of-bounds return, results, and persistent/idempotent statistics.")
	session.close_room()
	quit()
