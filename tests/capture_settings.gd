extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var screen = load("res://ui/settings/settings.tscn").instantiate()
	root.add_child(screen)
	for frame in 5:
		await process_frame
	root.get_texture().get_image().save_png("res://tests/settings_preview.png")
	print("SETTINGS CAPTURED")
	quit()
