extends SceneTree

func _initialize() -> void:
	_check.call_deferred()

func _check() -> void:
	var actors: Array[CharacterBody2D] = []
	for role in ["Thrower", "Taya"]:
		for character in ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head", "Leonardo", "Kay"]:
			var actor: CharacterBody2D = load("res://scenes/%s %s.tscn" % [role, character]).instantiate()
			root.add_child(actor)
			actor.set_physics_process(false)
			actors.append(actor)
	await process_frame
	for index in range(actors.size()):
		var actor := actors[index]
		var body: CollisionShape2D = actor.get_node("CollisionShape2D")
		assert(body.shape is ConvexPolygonShape2D)
		assert((body.shape as ConvexPolygonShape2D).points.size() >= 6)
		assert(body.position == Vector2.ZERO)
		if index in [5, 6, 12, 13]:
			var lowest_point: float = -INF
			for point in (body.shape as ConvexPolygonShape2D).points:
				lowest_point = maxf(lowest_point, point.y)
			assert(absf(lowest_point) <= 3.0, "New roster body collision must end at the visible feet")
		actor.global_position = Vector2(100, index * 500)
	var first := actors[0]
	var second := actors[1]
	first.global_position = Vector2(100, 8000)
	second.global_position = Vector2(400, 8000)
	await physics_frame
	await physics_frame
	var contact: KinematicCollision2D
	for step in range(26):
		contact = first.move_and_collide(Vector2(10, 0))
		if contact != null:
			break
	assert(contact != null and contact.get_collider() == second)
	var thrower := actors[0]
	var guard := actors[8]
	for direction in [Vector2.RIGHT, Vector2(1, 1).normalized(), Vector2.DOWN, Vector2(-1, 1).normalized(), Vector2.LEFT, Vector2(-1, -1).normalized(), Vector2.UP, Vector2(1, -1).normalized()]:
		guard.scale = Vector2.ONE * 0.52
		thrower.scale = Vector2.ONE * 0.52
		guard.global_position = Vector2(1000, 10000)
		thrower.global_position = guard.global_position + direction * 200.0
		await physics_frame
		await physics_frame
		var touch: KinematicCollision2D
		for step in range(200):
			touch = guard.move_and_collide(direction)
			if touch != null:
				break
		assert(touch != null and touch.get_collider() == thrower)
		var gap: float = guard.global_position.distance_to(thrower.global_position)
		print("CONTACT %s: %.1f px" % [direction, gap])
		assert(gap <= 65.0)
	for index in range(7):
		var candidate := actors[index]
		candidate.scale = Vector2.ONE * 0.52
		guard.global_position = Vector2(1000, 12000 + index * 400)
		candidate.global_position = guard.global_position + Vector2(200, 0)
		await physics_frame
		var touch: KinematicCollision2D
		for step in range(200):
			touch = guard.move_and_collide(Vector2.RIGHT)
			if touch != null:
				break
		assert(touch != null and touch.get_collider() == candidate)
		assert(guard.global_position.distance_to(candidate.global_position) <= 60.0, "A character's body footprint is too wide")
	var can = load("res://scenes/Taya can.tscn").instantiate()
	can.starts_toppled = false
	root.add_child(can)
	can.set_physics_process(false)
	guard.can_node = can
	var tagged: Array[Node2D] = []
	guard.tag_requested.connect(func(target: Node2D) -> void: tagged.append(target))
	guard.global_position = Vector2(1000, 10000)
	thrower.global_position = guard.global_position + Vector2(90, 0)
	await physics_frame
	guard._try_tag()
	assert(tagged.is_empty(), "A visually separated player must not be tagged")
	thrower.global_position = guard.global_position + Vector2(45, 0)
	await physics_frame
	guard._try_tag()
	assert(tagged.size() == 1 and tagged[0] == thrower, "Close contact must tag")
	print("PASS: fourteen role scenes use fitted polygons; match-scale player bodies block at close range")
	quit()
