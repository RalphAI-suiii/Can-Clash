extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("4a4a4a")
	background.size = Vector2(1280, 720)
	root.add_child(background)
	var names := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head", "Leonardo", "Kay"]
	var actors: Array[CharacterBody2D] = []
	for index in range(names.size()):
		var actor: CharacterBody2D = load("res://scenes/Thrower %s.tscn" % names[index]).instantiate()
		background.add_child(actor)
		actor.position = Vector2(110 + index * 175, 440)
		actor.scale = Vector2.ONE * 0.52
		actor.set_physics_process(false)
		actors.append(actor)
	await process_frame
	for actor in actors:
		var collider: CollisionShape2D = actor.get_node("CollisionShape2D")
		var line := Line2D.new()
		line.default_color = Color("61ff9b")
		line.width = 2.0
		line.position = collider.position
		line.points = (collider.shape as ConvexPolygonShape2D).points
		line.add_point(line.points[0])
		actor.add_child(line)
	for frame in range(4):
		await process_frame
	assert(root.get_texture().get_image().save_png("res://tests/player_body_collision_preview.png") == OK)
	print("PASS: rendered seven fitted player collision outlines")
	quit()
