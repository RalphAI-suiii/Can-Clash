extends SceneTree

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		printerr("FAIL: guard circle and impact test timed out")
		quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var base := Node2D.new()
	base.name = "CanBase"
	base.position = Vector2(400, 400)
	world.add_child(base)
	var can: CharacterBody2D = load("res://scenes/Taya can.tscn").instantiate()
	can.starts_toppled = false
	can.auto_stand_up = false
	can.position = base.position
	world.add_child(can)
	var guard: CharacterBody2D = load("res://scenes/Thrower Hat Thrower.tscn").instantiate()
	world.add_child(guard)
	guard.can_node = can
	guard.require_standing_can = true
	guard.set_taya_role(true)
	assert(guard.CAN_GUARD_CLEARANCE == 100.0)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN, Vector2(-1, -1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, 1).normalized(), Vector2(1, 1).normalized()]:
		guard.global_position = can.get_hit_center() + direction * 160.0
		guard.velocity = -direction * 700.0
		for step in range(20):
			guard._move_character_delta(1.0 / 60.0)
			assert(guard.global_position.distance_to(can.get_hit_center()) >= guard.CAN_GUARD_CLEARANCE - 0.1, "Taya entered the standing can circle from %s" % direction)
	guard.global_position = can.get_hit_center()
	guard._keep_out_of_can_circle()
	assert(guard.global_position.distance_to(can.get_hit_center()) >= guard.CAN_GUARD_CLEARANCE - 0.1)
	var slipper_script: GDScript = load("res://scenes/slipper_visual.gd")
	var green_speed: float = slipper_script.launch_speed(1.0, 1.45)
	var good_speed: float = slipper_script.launch_speed(0.95, 1.45)
	assert(green_speed > good_speed * 1.15, "Green must launch visibly faster than good")
	assert(can.receive_slipper_hit(Vector2(350, 0), 0.5, can.get_hit_center()))
	var normal_push: float = can.velocity.length()
	var normal_hop: float = can.vertical_speed
	can.reset_for_preview(base.position)
	assert(can.receive_slipper_hit(Vector2(green_speed, 0), 1.0, can.get_hit_center()))
	assert(can.velocity.length() > normal_push * 2.0, "Fast green impact must move the can much farther")
	assert(can.vertical_speed > normal_hop, "Fast green impact must loft the can higher")
	guard.global_position = can.global_position
	guard._move_character_delta(1.0 / 60.0)
	assert(guard.global_position.distance_to(can.get_hit_center()) < guard.CAN_GUARD_CLEARANCE, "Taya must be able to recover a toppled can")
	can.velocity = Vector2.ZERO
	can.vertical_speed = 0.0
	can.height = 0.0
	assert(can.pick_up(guard))
	guard.carrying_can = true
	assert(can.reset_at_base(guard))
	guard.carrying_can = false
	guard._keep_out_of_can_circle()
	assert(guard.global_position.distance_to(can.get_hit_center()) >= guard.CAN_GUARD_CLEARANCE - 0.1, "Reset must move Taya out of the circle")
	assert(can.receive_slipper_hit(Vector2(green_speed, 0), 1.0, can.get_hit_center()))
	for frame in range(60):
		await physics_frame
	assert(can.global_position.distance_to(base.global_position) > 150.0, "Fast hits must carry the can away from its base")
	print("PASS: eight-way guard clearance, toppled-can access, reset clearance, green launch power, and speed-based can travel")
	quit()
