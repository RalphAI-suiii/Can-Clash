extends SceneTree

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	root.size = Vector2i(1920, 1080)
	var session: Node = root.get_node("LanSession")
	session.begin_local("developer")
	session.players[0].character = 0
	var game = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	var actor: CharacterBody2D = game.actors[session.local_id()]
	actor.set_physics_process(false)
	assert(is_equal_approx(game.player_scale, 0.52) and actor.scale.is_equal_approx(Vector2.ONE * game.player_scale))
	assert(is_equal_approx(actor.get_node("CollisionShape2D").global_scale.x, game.player_scale))
	assert(actor.get_throw_origin().is_equal_approx(actor.global_position + actor.THROW_ORIGIN * game.player_scale))
	assert(actor.name_label.get_global_transform().get_scale().is_equal_approx(Vector2.ONE))
	actor.global_position = game._line_point(0)
	game.can.global_position = game.CAN_START
	await process_frame
	game._update_camera(10.0)
	game.match_camera.force_update_scroll()
	var normal_zoom: float = game.match_camera.zoom.x
	var toe_focus: Vector2 = game.match_camera.position
	assert(is_equal_approx(normal_zoom, game.CAMERA_NORMAL_ZOOM))
	_assert_visible(game, actor)
	_assert_visible(game, game.can)
	await _capture("res://tests/match_camera_normal.png")
	actor.attack_state = actor.AttackState.CHARGING
	game._update_camera(10.0)
	game.match_camera.force_update_scroll()
	assert(is_equal_approx(game.match_camera.zoom.x, game.CAMERA_AIM_ZOOM))
	assert(game.match_camera.zoom.x < normal_zoom)
	_assert_visible(game, actor)
	_assert_visible(game, game.can)
	await _capture("res://tests/match_camera_aim.png")
	actor.attack_state = actor.AttackState.FREE
	actor.taya_stun_aiming = true
	game._update_camera(10.0)
	assert(is_equal_approx(game.match_camera.zoom.x, game.CAMERA_AIM_ZOOM))
	actor.taya_stun_aiming = false
	actor.global_position = game.CAN_START + Vector2(-115, 0)
	game._update_camera(10.0)
	assert(game.match_camera.position.x > toe_focus.x + 100.0, "The local camera must follow each player's position")
	root.size = Vector2i(960, 540)
	actor.global_position = game._line_point(0)
	await process_frame
	game._update_camera(10.0)
	game.match_camera.force_update_scroll()
	_assert_visible(game, actor)
	_assert_visible(game, game.can)
	print("PASS: smaller player sprite/collider/throw origin, readable name, wider camera and aim view")
	quit()

func _assert_visible(game: Node2D, subject: Node2D) -> void:
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * subject.global_position
	assert(game.get_viewport_rect().grow(-40.0).has_point(screen), "Player and can must stay on screen")

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
