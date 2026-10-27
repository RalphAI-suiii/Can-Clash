extends Node2D

const NAMES := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const VECTORS := [Vector2.RIGHT, Vector2(1, 1), Vector2.DOWN,
	Vector2(-1, 1), Vector2.LEFT, Vector2(-1, -1),
	Vector2.UP, Vector2(1, -1)]


func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	for character in ["Leonardo", "Kay"]:
		for action in ["carry", "taya_cast"]:
			var nodes: Array[Node] = []
			for index in range(8):
				var actor = load("res://scenes/Taya %s.tscn" % character).instantiate()
				actor.position = Vector2(245 + (index % 4) * 445, 300 + (index / 4) * 470)
				actor.accept_local_input = false
				actor.show_gameplay_overlays = false
				add_child(actor)
				actor.set_process(false)
				actor.set_physics_process(false)
				if action == "carry":
					actor.carrying_can = true
					actor._play("walk", VECTORS[index])
					actor.sprite.frame = 1
					actor.sprite.pause()
				else:
					actor.attack_direction = VECTORS[index]
					actor._set_attack_visual(index, true)
					actor.sprite.hide()
					actor.attack_sprite.show()
					actor.attack_sprite.play(StringName("taya_stun_throw_" + NAMES[index]))
					actor.attack_sprite.frame = 1
					actor.attack_sprite.pause()
				nodes.append(actor)
				var label := Label.new()
				label.text = "%s · %s" % [NAMES[index], action]
				label.position = actor.position + Vector2(-120, -230)
				label.add_theme_font_size_override("font_size", 28)
				add_child(label)
				nodes.append(label)
			for frame in range(3):
				await get_tree().process_frame
			var output := "res://tests/new_roster_%s_%s.png" % [character.to_lower(), action]
			get_viewport().get_texture().get_image().save_png(output)
			print("DIRECTION PREVIEW: ", output)
			for node in nodes:
				node.queue_free()
			await get_tree().process_frame
	get_tree().quit()
