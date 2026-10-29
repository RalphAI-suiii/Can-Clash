extends Node2D

const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
var actors: Array = []

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("d9c6a0")
	background.size = Vector2(1920, 1080)
	add_child(background)
	for row in range(4):
		for column in range(5):
			var path := "res://scenes/Thrower %s.tscn" % LanSession.CHARACTERS[column]
			var actor = load(path).instantiate()
			actor.position = Vector2(230 + column * 360, 225 + row * 225)
			actor.scale = Vector2.ONE * 0.52
			add_child(actor)
			actor.set_physics_process(false)
			actor.show_player_ring = false
			actor.throw_status.hide()
			actors.append(actor)
			var label := Label.new()
			label.position = actor.position + Vector2(-150, 94)
			label.size = Vector2(300, 24)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.text = LanSession.CHARACTERS[column] + " / " + ["Special", "Taya stun", "Stunned", "Recover"][row]
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color("312116"))
			add_child(label)
	call_deferred("_capture")

func _capture() -> void:
	for direction in DIRECTIONS:
		for row in range(4):
			for column in range(5):
				var actor = actors[row * 5 + column]
				var sector: int = DIRECTIONS.find(direction)
				actor.facing = Vector2.RIGHT.rotated(sector * PI / 4.0)
				if row < 2:
					actor.sprite.hide()
					actor.attack_sprite.show()
					actor.special_armed = row == 0
					actor.is_taya = row == 1
					actor.taya_stun_aiming = row == 1
					actor.attack_direction = actor.facing
					actor._set_attack_visual(sector, true)
					actor.attack_sprite.play(StringName(("special_throw_" if row == 0 else "taya_stun_throw_") + direction))
					actor.attack_sprite.set_frame_and_progress(2, 0.0)
					actor.attack_sprite.pause()
				else:
					actor.special_armed = false
					actor.is_taya = false
					actor.taya_stun_aiming = false
					actor.sprite.show()
					actor.attack_sprite.hide()
					actor._play("stunned" if row == 2 else "recover", actor.facing)
					actor.sprite.pause()
					actor.modulate = Color("c3a6f4") if row == 2 else Color.WHITE
				actor.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://tests/ability_visual/%s.png" % direction)
	print("ABILITY_VISUAL_SAVED")
	get_tree().quit()
