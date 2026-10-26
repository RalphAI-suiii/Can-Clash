extends Node2D

func _ready() -> void:
	call_deferred("_capture")


func _capture() -> void:
	for index in range(3):
		var character: String = ["Hat Thrower", "Leonardo", "Kay"][index]
		var actor = load("res://scenes/Thrower %s.tscn" % character).instantiate()
		actor.position = Vector2(500 + index * 460, 640)
		actor.accept_local_input = false
		actor.show_gameplay_overlays = false
		add_child(actor)
		actor.set_physics_process(false)
		actor._play("idle", Vector2.DOWN)
		var label := Label.new()
		label.text = character
		label.position = Vector2(380 + index * 460, 390)
		label.add_theme_font_size_override("font_size", 36)
		add_child(label)
	for frame in range(5):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://tests/new_roster_render.png")
	print("NEW ROSTER RENDER: saved preview")
	get_tree().quit()
