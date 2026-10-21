extends SceneTree

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func() -> void:
		printerr("FAIL: can tumble check timed out")
		quit(1)
	)
	_run.call_deferred()

func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame
	await process_frame

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	current_scene = world
	var base := Node2D.new()
	base.name = "CanBase"
	base.position = Vector2(300, 300)
	world.add_child(base)
	var can: CharacterBody2D = load("res://scenes/Taya can.tscn").instantiate()
	can.starts_toppled = false
	can.position = base.position
	world.add_child(can)
	var wall := StaticBody2D.new()
	wall.position = Vector2(420, 300)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 500)
	shape.shape = rectangle
	wall.add_child(shape)
	world.add_child(wall)
	await _frames(3)
	var initial := can.position
	assert(can.receive_slipper_hit(Vector2(540, 0), 1.0, can.get_hit_center()))
	var max_rotation := 0.0
	var max_height := 0.0
	var bounced := false
	for i in range(480):
		await physics_frame
		max_rotation = maxf(max_rotation, absf(can.tilt_angle))
		max_height = maxf(max_height, can.height)
		bounced = bounced or can.velocity.x < -5.0
		if can.is_settled():
			break
	assert(can.is_toppled() and can.is_settled())
	assert(max_rotation > PI and max_height > 10.0, "Strong hits must tumble freely and bounce vertically")
	assert(bounced and can.position.x < 390.0, "Can must ricochet off solid walls")
	assert(can.position.distance_to(initial) > 20.0)
	var resting := can.position
	var actor := Node2D.new()
	actor.position = resting
	world.add_child(actor)
	assert(not can.can_pick_up(actor), "Taya must not interrupt automatic recovery")
	for i in range(150):
		await physics_frame
		if can.is_standing():
			break
	assert(can.is_standing() and can.position.distance_to(resting) < 0.01)
	assert(base.position.distance_to(resting) < 0.01)
	assert(can.tilt_angle == 0.0 and can.height == 0.0 and can.velocity == Vector2.ZERO)
	assert(can.receive_slipper_hit(Vector2(-260, 0), 0.0, can.get_hit_center()))
	for i in range(600):
		await physics_frame
		if can.is_standing():
			break
	assert(can.is_standing() and can.position.distance_to(resting) > 5.0, "Repeated hits must recover at each new landing")
	world.free()
	await _frames(2)
	root.get_node("LanSession").begin_local("practice")
	var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await _frames(3)
	can = room.practice_cans[0]
	initial = room.practice_origins[0]
	assert(can.receive_slipper_hit(Vector2(540, 0), 1.0, can.get_hit_center()))
	for i in range(600):
		await physics_frame
		if can.is_standing():
			break
	assert(can.is_standing() and can.position.distance_to(initial) > 20.0)
	room._reset_practice()
	for i in range(3):
		assert(room.practice_cans[i].position.is_equal_approx(room.practice_origins[i]))
		assert(room.practice_cans[i].base.position.is_equal_approx(room.practice_origins[i]))
	print("PASS: free can tumbling, wall/vertical bounces, rest pause, stand-up at each landing, base relocation, recovery pickup guard, and original practice Reset.")
	root.get_node("LanSession").close_room()
	quit()
