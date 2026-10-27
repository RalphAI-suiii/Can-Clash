extends Node2D


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var directions := [Vector2.DOWN, Vector2(1, -1).normalized()]
	for row in range(4):
		var character: String = ["Leonardo", "Kay"][row / 2]
		var direction: Vector2 = directions[row % 2]
		var direction_name := "down" if row % 2 == 0 else "up_right"
		for column in range(4):
			var action: String = ["carry", "stunned", "recover", "taya cast"][column]
			var actor = load("res://scenes/Taya %s.tscn" % character).instantiate()
			actor.position = Vector2(260 + column * 445, 270 + row * 235)
			actor.accept_local_input = false
			actor.show_gameplay_overlays = false
			add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			if action == "carry":
				actor.carrying_can = true
				actor._play("walk", direction)
				actor.sprite.frame = 1
				actor.sprite.pause()
			elif action == "taya cast":
				actor.attack_direction = direction
				actor._set_attack_visual(actor._attack_sector(), true)
				actor.sprite.hide()
				actor.attack_sprite.show()
				actor.attack_sprite.play(StringName("taya_stun_throw_" + direction_name))
				actor.attack_sprite.frame = 1
				actor.attack_sprite.pause()
			else:
				actor._play(action, direction)
				actor.sprite.frame = 0
				actor.sprite.pause()
			var label := Label.new()
			label.text = "%s %s · %s" % [character, direction_name, action]
			label.position = Vector2(90 + column * 445, 70 + row * 235)
			label.add_theme_font_size_override("font_size", 23)
			add_child(label)
	for frame in range(5):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://tests/new_roster_completion_preview.png")
	print("NEW ROSTER COMPLETION PREVIEW: saved")
	get_tree().quit()
