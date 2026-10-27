extends SceneTree

## Visual check of the same procedural slipper used in matches and the HUD.
func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	root.size = Vector2i(960, 540)
	var background := ColorRect.new()
	background.color = Color("d7ac70")
	background.size = Vector2(1920, 1080)
	root.add_child(background)
	var slipper_script: GDScript = load("res://scenes/slipper_visual.gd")
	var can: Node2D = load("res://scenes/Taya can.tscn").instantiate()
	can.set("starts_toppled", false)
	background.add_child(can)
	can.position = Vector2(150, 300)
	can.set_physics_process(false)
	var positions := [Vector2(430, 300), Vector2(960, 300), Vector2(1490, 300)]
	for index in range(3):
		for scale_factor in [1.0, 3.0]:
			var slipper: Node2D = slipper_script.new()
			background.add_child(slipper)
			slipper.position = positions[index] + Vector2(0, 470 if scale_factor > 1.0 else 0)
			slipper.scale = Vector2.ONE * scale_factor
			slipper.age = 0.3
			slipper.resting = index == 0
			slipper.height = 0.0 if index == 0 else 42.0
			slipper.velocity = Vector2.ZERO if index == 0 else Vector2(500, 0)
			slipper.spin_angle = [0.0, PI * 0.5 + 0.35, -0.55][index]
			slipper.charge_ratio = 0.75
			slipper.outline_color = Color("329dff")
			if index == 2: slipper.special_kind = &"ricochet"
			slipper.set_physics_process(false)
			slipper.queue_redraw()
	for frame in range(5): await process_frame
	var error := root.get_texture().get_image().save_png("res://tests/slipper_shape_preview.png")
	assert(error == OK)
	print("PASS: rendered grounded, flying, and special slippers at game size")
	quit()
