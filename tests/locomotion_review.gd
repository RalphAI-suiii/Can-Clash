extends Node2D

const CHARACTERS := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head", "Leonardo", "Kay"]
const ACTIONS := ["idle", "walk", "sprint", "sprint"]
const DIRECTIONS := ["down", "down", "down", "right"]
const GROUND := [220.0, 460.0, 700.0, 940.0]


func _ready() -> void:
	_capture.call_deferred()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("4b4b4b"))
	for y in GROUND:
		draw_line(Vector2(40, y), Vector2(1880, y), Color("a9a9a9"), 2.0)


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
				var direction: String = ["down", "left", "up", "right"][column] if row == 0 else DIRECTIONS[row]
				var motion: Vector2 = Vector2.RIGHT.rotated(actor.DIRECTIONS.find(direction) * PI / 4.0)
				actor._play(ACTIONS[row], motion)
				var frame_count: int = actor.sprite.sprite_frames.get_frame_count(actor.sprite.animation)
				actor.sprite.frame = 0 if row == 0 else mini(column * frame_count / 4, frame_count - 1)
				if actor.has_method("_fit_polished_frame"):
					actor._fit_polished_frame()
				if actor.has_method("_align_current_motion_frame"):
					actor._align_current_motion_frame()
				actor.sprite.pause()
				nodes.append(actor)
				var label := Label.new()
				label.text = "%s %s %d" % [ACTIONS[row], direction, actor.sprite.frame + 1]
				label.position = actor.position + Vector2(-125, -200)
				label.add_theme_font_size_override("font_size", 24)
				add_child(label)
				nodes.append(label)
		await get_tree().process_frame
		await get_tree().process_frame
		var path := "res://tests/locomotion_review_%s.png" % character.to_lower().replace(" ", "_")
		get_viewport().get_texture().get_image().save_png(path)
		print("REVIEW: ", path)
		for node in nodes:
			node.queue_free()
		await get_tree().process_frame
	get_tree().quit()
