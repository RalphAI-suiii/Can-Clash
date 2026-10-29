extends Node2D

const CHARACTERS := ["Head Band", "Glasses Thrower", "Curly Haired"]
const ROW_DIRECTIONS := ["idle", "walk", "sprint", "sprint"]
const GROUND := [225.0, 465.0, 705.0, 945.0]


func _ready() -> void:
	call_deferred("_capture")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("515151"))
	for y in GROUND:
		draw_line(Vector2(30, y), Vector2(1890, y), Color("aaaaaa"), 2.0)


func _capture() -> void:
	for character in CHARACTERS:
		var nodes: Array[Node] = []
		for row in range(4):
			for column in range(4):
				var actor = load("res://scenes/Thrower %s.tscn" % character).instantiate()
				actor.position = Vector2(245 + column * 455, GROUND[row])
				actor.scale = Vector2.ONE * 0.7
				actor.show_gameplay_overlays = false
				add_child(actor)
				actor.set_process(false)
				actor.set_physics_process(false)
				var direction := "down" if row == 0 and column == 0 else "left" if row == 0 and column == 1 or row == 3 else "up" if row == 0 and column == 2 else "right"
				var action: String = ROW_DIRECTIONS[row]
				actor._play(action, _vector(direction))
				actor.sprite.frame = 0 if row == 0 else column
				actor._fit_polished_frame()
				actor.sprite.pause()
				var texture: AtlasTexture = actor.sprite.sprite_frames.get_frame_texture(actor.sprite.animation, actor.sprite.frame)
				assert("/motion_polish/" in texture.atlas.resource_path)
				var bounds: Rect2i = texture.get_image().get_used_rect()
				var foot: float = actor.sprite.position.y + (float(bounds.end.y) - texture.get_size().y * 0.5) * actor.sprite.scale.y
				assert(absf(foot) <= 2.0, "A polished pose floats above or sinks below the foot origin")
				assert(absf(bounds.size.y * actor.sprite.scale.y - 210.0) <= 2.0, "A polished pose changes size")
				nodes.append(actor)
				var label := Label.new()
				label.text = "%s %s %d" % [action, direction, column + 1]
				label.position = actor.position + Vector2(-120, -200)
				label.add_theme_font_size_override("font_size", 24)
				add_child(label)
				nodes.append(label)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var output := "res://tests/motion_polish_%s.png" % character.to_lower().replace(" ", "_")
		get_viewport().get_texture().get_image().save_png(output)
		print("MOTION PREVIEW: ", output)
		for node in nodes:
			node.queue_free()
		await get_tree().process_frame
	get_tree().quit(0)


func _vector(direction: String) -> Vector2:
	match direction:
		"down": return Vector2.DOWN
		"left": return Vector2.LEFT
		"up": return Vector2.UP
	return Vector2.RIGHT
