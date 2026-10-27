extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(960, 540)
	var session: Node = root.get_node("LanSession")
	session.begin_local("developer")
	session.add_developer_bots()
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.set_physics_process(false)
	for actor in game.actors.values(): actor.hide()
	game.match_camera.position = game.CAN_START + Vector2(-120, -25)
	game.match_camera.zoom = Vector2.ONE * 1.5
	for frame in range(5): await process_frame
	root.get_texture().get_image().save_png("res://tests/can_ring_standing.png")
	game.can.receive_slipper_hit(Vector2.ZERO, 0.0, game.can.get_hit_center())
	game.can.set_physics_process(false)
	game.can.tilt_angle = -PI / 2.0
	game.can.position += Vector2(110, 65)
	game.can._refresh_visual()
	for frame in range(5): await process_frame
	root.get_texture().get_image().save_png("res://tests/can_ring_toppled.png")
	var carrier := Node2D.new()
	carrier.position = game.can.position
	game.add_child(carrier)
	assert(game.can.pick_up(carrier))
	for frame in range(5): await process_frame
	root.get_texture().get_image().save_png("res://tests/can_ring_carried.png")
	carrier.position = game.CAN_START
	assert(game.can.reset_at_base(carrier))
	for frame in range(5): await process_frame
	root.get_texture().get_image().save_png("res://tests/can_ring_reset.png")
	print("PASS: rendered standing, toppled, carried, and reset can states at 960x540")
	quit()
