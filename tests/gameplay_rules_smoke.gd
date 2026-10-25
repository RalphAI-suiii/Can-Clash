extends SceneTree

const METER = preload("res://scenes/throw_meter.gd")
var session: Node

func _initialize() -> void:
	create_timer(50).timeout.connect(func() -> void: printerr("FAIL: gameplay rules timeout"); quit(1))
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count): await physics_frame
	await process_frame

func _run() -> void:
	session = root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	assert(METER.quality_at(0.52, 0.5).band == "PERFECT")
	assert(METER.quality_at(0.521, 0.5).band == "GOOD")
	assert(METER.quality_at(0.75, 0.5).band == "GOOD")
	assert(METER.quality_at(0.751, 0.5).band == "RISKY")
	for map_index in range(3):
		session.begin_local("developer")
		session.selected_map = map_index
		session.add_developer_bots()
		var game: Node2D = load("res://game/match/match.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_physics_process(false)
		for actor in game.actors.values():
			actor.set_meta("bot", false)
			actor.network_controlled = true
		game.taya_id = int(game.actors.keys()[0])
		game._start_preparation()
		assert(game.remaining == 7.0 and game.stage == "preparation")
		var guard: CharacterBody2D = game.actors[game.taya_id]
		var thrower: CharacterBody2D = game.actors.values().filter(func(actor: Node2D) -> bool: return not actor.is_taya)[0]
		assert(game.SAFE.position == Vector2(140, 0) and game.SAFE.end == Vector2(530, 1072), "Blue must fill the visible floor to the fence and curb")
		var positions := {}
		for id in game.actors:
			positions[id] = game.actors[id].position
			game._receive_input(id, {"move": Vector2.RIGHT, "throw": true})
		game._physics_process(1.0 / 60.0)
		await _frames(15)
		for id in game.actors:
			var actor: CharacterBody2D = game.actors[id]
			assert(actor.position.x > positions[id].x if actor.is_taya else actor.position.is_equal_approx(positions[id]), "Only Taya moves during preparation")
			if not actor.is_taya: assert(actor.attack_state == actor.AttackState.FREE)
		game.remaining = 0.02
		game._physics_process(0.01)
		assert(game.stage == "preparation")
		game._physics_process(0.01)
		assert(game.stage == "active" and game.remaining == 600.0)
		game._physics_process(0.01)
		for actor in game.actors.values(): actor.network_input = {}
		guard.position = Vector2(game.SAFE.end.x + 3, 610)
		guard.apply_network_input({"move": Vector2.LEFT, "aim": Vector2.ZERO})
		await _frames(20)
		assert(guard.position.x >= game.SAFE.end.x)
		guard._start_lunge()
		await _frames(45)
		assert(guard.position.x >= game.SAFE.end.x, "Lunges cannot cross into blue")
		guard.set_taya_role(true)
		guard.position = Vector2(1250, 700)
		guard.network_input = {}
		thrower.position = Vector2(700, 610)
		thrower._start_charge()
		assert(thrower.attack_state == thrower.AttackState.FREE, "Outside-blue charge rejected")
		thrower.position = Vector2(490, 610)
		thrower._start_charge()
		assert(thrower.attack_state == thrower.AttackState.CHARGING)
		thrower.position = Vector2(550, 610)
		assert(not thrower.release_network_throw(thrower.charge_id, session.clock_time(), game.CAN_START))
		thrower.set_taya_role(false)
		thrower.position = Vector2(490, 610)
		thrower._start_charge()
		thrower._start_throw(thrower.sweet_spot * 1.25)
		thrower.position = Vector2(550, 610)
		thrower.attack_sprite.frame = 2
		thrower._on_attack_frame_changed()
		assert(not is_instance_valid(thrower.active_slipper), "Crossing before release animation spawns a slipper must cancel")
		thrower.position = Vector2(490, 950)
		var score_before: int = game.scores[game.taya_id]
		game._tag_requested(thrower, guard)
		assert(game.scores[game.taya_id] == score_before)
		# Exercise actual E pickup/place actions, not only direct can setters.
		game.can.position = game.CAN_START - Vector2(70, 0)
		game.can.topple()
		await _frames(180)
		assert(game.can.is_toppled() and game.can.is_settled() and not guard.can_tag())
		assert(game.can.base.position == game.CAN_START)
		guard.position = game.can.position + Vector2(55, 0)
		guard.apply_network_input({"interact": true})
		await _frames(45)
		assert(guard.carrying_can and game.can.is_carried() and not guard.can_tag())
		guard.apply_network_input({"interact": false})
		guard.position = game.CAN_START - Vector2(55, 0)
		guard.apply_network_input({"interact": true})
		await _frames(45)
		assert(game.can.is_standing() and game.can.position == game.CAN_START and not guard.carrying_can)
		for actor in game.actors.values():
			actor.network_input = {}
			assert(actor.scale == Vector2.ONE * 0.576)
		var world := game.get_child(0).get_node("World")
		if map_index == 0:
			assert(world.get_node("Ring 1").position.is_equal_approx(Vector2(668.5, 21)), "Right hoop must retain its authored court position")
			assert(world.get_node("Ring 2").position.is_equal_approx(Vector2(-629.99255, 19.454887)), "Left hoop must retain its authored court position")
		else:
			assert(not world.has_node("Ring 1") and not world.has_node("Ring 2"), "Non-court maps must have no hoop nodes or collisions")
		assert(world.has_node("BarrelTrio") and world.has_node("ConeBox"), "Cleanup must retain the original props")
		for prop_name in ["Crate", "Crate1_2", "Barrel", "Barrel2"]:
			var prop: Node2D = world.get_node(NodePath(prop_name))
			assert(not game.SAFE.has_point(prop.global_position))
			assert(prop.global_position.distance_to(game.can.base.position) > 160)
		game.actors[session.local_id()].position = game.ARENA.position + Vector2(45, 50)
		game.can.position = game.ARENA.end - Vector2(45, 50)
		game._update_camera(10.0)
		game.match_camera.force_update_scroll()
		for subject in [game.actors[session.local_id()], game.can]:
			var screen_position: Vector2 = game.get_viewport().get_canvas_transform() * subject.global_position
			assert(game.get_viewport_rect().grow(-30).has_point(screen_position), "Both player and can remain visible")
		assert(game.match_camera.zoom.x <= 0.9)
		print("PASS: map ", map_index, " preparation, boundaries, throws, manual E recovery, court-only hoops, cover and camera")
		game.free()
		session.close_room()
		await _frames(2)
	# Compare equal-direction hits in an empty world: power must increase tumble distance.
	var distance := []
	for power in [0.25, 1.0]:
		var can: CharacterBody2D = load("res://scenes/Taya can.tscn").instantiate()
		can.starts_toppled = false
		can.auto_stand_up = false
		root.add_child(can)
		can.set_physics_process(false)
		can.receive_slipper_hit(Vector2.RIGHT * 500, power, can.get_hit_center())
		for tick in range(1200):
			can._physics_process(1.0 / 60.0)
			if can.is_settled(): break
		assert(can.is_settled())
		distance.append(can.position.length())
		can.free()
	assert(distance[1] > distance[0] * 1.3)
	for count in [1, 2, 3, 5]:
		session.mode = "developer"
		session.results = []
		for i in range(count): session.results.append({"id": i + 1, "name": "Player %d" % (i + 1), "score": 5 - i, "character": i, "color": Color.WHITE})
		var results: Control = load("res://ui/results/results.tscn").instantiate()
		root.add_child(results)
		assert(results.podium_players.size() == mini(3, count))
		for actor in results.podium_players:
			assert(not actor.show_gameplay_overlays and not actor.possession_icon.visible, "Podium ranks must stay clear of gameplay circles/icons")
		assert(results.get_node("Podium").get_child_count() >= 3)
		results.free()
	print("PASS: power-dependent tumble and podium layouts for 1, 2, 3 and 5 players")
	quit(0)
