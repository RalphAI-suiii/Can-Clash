extends Node2D

const DIRECTIONS := {
	"down": Vector2.DOWN,
	"down_right": Vector2(1, 1),
	"right": Vector2.RIGHT,
	"up_right": Vector2(1, -1),
	"up": Vector2.UP,
	"up_left": Vector2(-1, -1),
	"left": Vector2.LEFT,
	"down_left": Vector2(-1, 1),
}


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	for character in ["Leonardo", "Kay"]:
		for direction_name in DIRECTIONS:
			for page in range(2 if direction_name in ["down", "up"] else 1):
				await _capture_page(character, direction_name, page)
	get_tree().quit()


func _capture_page(character: String, direction_name: String, page: int) -> void:
	var nodes: Array[Node] = []
	for row in range(2):
		var action := "walk" if row == 0 else "sprint"
		var foot_y := 340.0 + row * 490.0
		var ground := Line2D.new()
		ground.points = PackedVector2Array([Vector2(60, foot_y), Vector2(1850, foot_y)])
		ground.width = 2.0
		ground.default_color = Color("999999")
		add_child(ground)
		nodes.append(ground)
		for column in range(4):
			var actor = load("res://scenes/Thrower %s.tscn" % character).instantiate()
			actor.position = Vector2(250 + column * 440, foot_y)
			actor.accept_local_input = false
			actor.show_gameplay_overlays = false
			add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor._play(action, DIRECTIONS[direction_name])
			actor.sprite.frame = column * 2 + page if direction_name in ["down", "up"] else column
			actor.sprite.pause()
			nodes.append(actor)
			var label := Label.new()
			label.text = "%s %s · %s %d" % [character, direction_name, action, column * 2 + page + 1 if direction_name in ["down", "up"] else column + 1]
			label.position = actor.position + Vector2(-145, -260)
			label.add_theme_font_size_override("font_size", 25)
			add_child(label)
			nodes.append(label)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var suffix := "_inbetween" if page == 1 else ""
	var output := "res://tests/new_roster_gait_%s_%s%s.png" % [character.to_lower(), direction_name, suffix]
	get_viewport().get_texture().get_image().save_png(output)
	print("GAIT PREVIEW: ", output)
	for node in nodes:
		node.queue_free()
	await get_tree().process_frame
