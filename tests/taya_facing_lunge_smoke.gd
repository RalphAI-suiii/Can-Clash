extends SceneTree

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var can = load("res://scenes/Taya can.tscn").instantiate()
	can.starts_toppled = false
	world.add_child(can)
	can.set_physics_process(false)
	var taya: CharacterBody2D = load("res://scenes/Taya Hat Thrower.tscn").instantiate()
	var thrower: CharacterBody2D = load("res://scenes/Thrower Head Band.tscn").instantiate()
	world.add_child(taya)
	world.add_child(thrower)
	taya.set_physics_process(false)
	thrower.set_physics_process(false)
	taya.scale = Vector2.ONE * 0.52
	thrower.scale = Vector2.ONE * 0.52
	taya.can_node = can
	taya.network_controlled = true
	taya.network_input["aim"] = Vector2(300, 100)
	taya.global_position = Vector2(300, 500)
	thrower.global_position = Vector2(1200, 1200)
	await physics_frame
	await physics_frame
	for direction in [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized(), Vector2.UP, Vector2(1, -1).normalized()]:
		taya.facing = direction
		taya._start_lunge()
		assert(taya.lunge_direction.is_equal_approx(direction) and taya.taya_visual.sector == taya._facing_sector())
	taya.facing = Vector2(1, 0.3).normalized()
	taya._start_lunge()
	assert(taya.lunge_direction.is_equal_approx(Vector2.RIGHT), "Dash direction must match its eight-way facing pose")
	taya.facing = Vector2.RIGHT
	thrower.global_position = Vector2(420, 360)
	await physics_frame
	taya._start_lunge()
	assert(taya.lunge_direction == Vector2.RIGHT and taya.lunge_target == null)
	for frame in range(30):
		await physics_frame
		taya._advance_lunge(1.0 / 60.0)
	assert(taya.global_position.x > 520.0 and absf(taya.global_position.y - 500.0) < 1.0, "Dash must ignore nearby players and cursor outside its facing line")
	taya.global_position = Vector2(300, 700)
	thrower.global_position = Vector2(430, 700)
	taya.facing = Vector2.RIGHT
	taya.taya_action = &""
	taya.tag_ready_at = 0.0
	var tagged: Array[Node2D] = []
	taya.tag_requested.connect(func(target: Node2D) -> void: tagged.append(target))
	await physics_frame
	taya._start_lunge()
	assert(taya.lunge_direction == Vector2.RIGHT and taya.lunge_target == thrower)
	for frame in range(30):
		await physics_frame
		taya._advance_lunge(1.0 / 60.0)
	assert(tagged.size() == 1 and tagged[0] == thrower)
	assert(taya.global_position.x > thrower.global_position.x + 30.0, "Straight dash should pass a thrower in its path and land beyond")
	assert(taya.lunge_collision_exception == null)
	print("PASS: eight facing directions, cursor/off-line-player independence, straight-path tag and collision restoration")
	quit()
