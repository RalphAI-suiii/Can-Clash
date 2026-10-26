extends Node2D

func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var actions := ["idle", "walk", "sprint", "throw"]
	for row in range(2):
		var character: String = ["Leonardo", "Kay"][row]
		for column in range(actions.size()):
			var actor = load("res://scenes/Thrower %s.tscn" % character).instantiate()
			actor.position = Vector2(280 + column * 440, 450 + row * 440)
			actor.accept_local_input = false
			actor.show_gameplay_overlays = false
			add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			if actions[column] == "throw":
				actor._set_attack_visual(2, true)
				actor.sprite.hide()
				actor.attack_sprite.show()
				actor.attack_sprite.play(&"throw_down")
				actor.attack_sprite.frame = 2
				actor.attack_sprite.pause()
			else:
				actor._play(actions[column], Vector2.DOWN)
				actor.sprite.frame = 3 if actions[column] != "idle" else 0
				actor.sprite.pause()
			var label := Label.new()
			label.text = "%s · %s" % [character, actions[column]]
			label.position = Vector2(140 + column * 440, 210 + row * 440)
			label.add_theme_font_size_override("font_size", 30)
			add_child(label)
	for frame in range(5):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://tests/new_roster_action_render.png")
	print("NEW ROSTER ACTION RENDER: saved preview")
	get_tree().quit()
