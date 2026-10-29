extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var settings = root.get_node("UserSettings")
	var old_path := OS.get_environment("CAN_CLASH_SAVE_PATH")
	var path := "res://tests/.controller_controls_test.cfg"
	OS.set_environment("CAN_CLASH_SAVE_PATH", path)
	settings.set_input_mode("keyboard")
	assert(InputMap.has_action("special"))
	assert(settings.binding_text("throw") == "LEFT MOUSE")
	settings.set_binding("lunge", "key:70")
	assert(settings.binding_text("lunge") == "F")
	settings.set_binding("interact", "key:70")
	assert(settings.binding_text("interact") == "F")
	assert(settings.binding_text("lunge") == "E")
	settings.load_profile()
	assert(settings.binding_text("interact") == "F")
	assert(settings.binding_text("lunge") == "E")
	settings.set_input_mode("controller")
	assert(settings.active_mode() == "keyboard" or not Input.get_connected_joypads().is_empty())
	if Input.get_connected_joypads().is_empty():
		assert(InputMap.action_get_events("throw")[0] is InputEventMouseButton)
	settings.reset_bindings()
	assert(settings.binding_text("throw") == "RIGHT TRIGGER")
	for action in settings.CONTROL_ACTIONS:
		for token in settings.bindings["controller"].get(action, []):
			assert(settings.token_to_event(token) != null)
	var screen = load("res://ui/settings/settings.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	assert(screen.rows.get_child_count() == 13)
	screen.rows.get_child(0).get_child(1).pressed.emit()
	assert(screen.capture_action == "up")
	screen._capture("lunge")
	var press := InputEventJoypadButton.new()
	press.button_index = 2
	press.pressed = true
	screen._input(press)
	assert(settings.binding_text("lunge") == "X / SQUARE")
	var menu = load("res://ui/main_menu/main_menuu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	var before: int = menu.get_child_count()
	menu.get_node("Settings").pressed.emit()
	assert(menu.get_child_count() == before + 1)
	menu.queue_free()
	assert(load("res://ui/waiting_room/waiting_room.tscn") != null)
	assert(load("res://game/match/match.tscn") != null)
	screen.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("CAN_CLASH_SAVE_PATH", old_path)
	print("CONTROLLER CONTROLS SMOKE PASS")
	quit()
