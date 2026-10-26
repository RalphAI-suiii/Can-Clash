extends SceneTree

const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const ACTIONS := {"idle": 4, "walk": 8, "sprint": 8, "aim": 1, "throw": 4}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var problems: Array[String] = []
	var hat_frames := load("res://scenes/player_movement_neutral_frames.tres") as SpriteFrames
	print("HAT REFERENCE FRAMES: idle_down=%d walk_down=%d sprint_down=%d" % [hat_frames.get_frame_count(&"idle_down"), hat_frames.get_frame_count(&"walk_down"), hat_frames.get_frame_count(&"sprint_down")])
	for character in ["Leonardo", "Kay"]:
		for role in ["Thrower", "Taya"]:
			var path := "res://scenes/%s %s.tscn" % [role, character]
			var scene := load(path) as PackedScene
			if scene == null:
				problems.append("Missing scene " + path)
				continue
			var actor := scene.instantiate() as CharacterBody2D
			root.add_child(actor)
			var body := actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
			var attack := actor.get_node("AttackSprite") as AnimatedSprite2D
			for direction in DIRECTIONS:
				for action in ACTIONS:
					var animation := StringName(action + "_" + direction)
					var frames := attack.sprite_frames if action in ["aim", "throw"] else body.sprite_frames
					if not frames.has_animation(animation) or frames.get_frame_count(animation) != ACTIONS[action]:
						problems.append("%s: %s" % [path, animation])
						continue
					for frame in range(frames.get_frame_count(animation)):
						var texture := frames.get_frame_texture(animation, frame)
						if texture == null or texture.get_image().get_used_rect().size == Vector2i.ZERO:
							problems.append("Empty %s %s frame %d" % [path, animation, frame])
				for action in ["idle", "walk", "sprint"]:
					var taya_animation := StringName("taya_" + action + "_" + direction)
					if not body.sprite_frames.has_animation(taya_animation):
						problems.append("%s: %s" % [path, taya_animation])
			var visual = actor.get_node("TayaVisual")
			for can_action in [&"can_pickup", &"can_place"]:
				if not visual.body.sprite_frames.has_animation(can_action) or visual.body.sprite_frames.get_frame_count(can_action) != 4:
					problems.append("%s: %s" % [path, can_action])
			for direction in ["right", "down_right", "down", "up_right", "up"]:
				var lunge := StringName("lunge_" + direction)
				if not visual.body.sprite_frames.has_animation(lunge) or visual.body.sprite_frames.get_frame_count(lunge) != 4:
					problems.append("%s: %s" % [path, lunge])
			if actor.has_thrower_special():
				problems.append("Unexpected special: " + path)
			actor.queue_free()
			await process_frame
	if problems.is_empty():
		print("NEW ROSTER: four scenes, eight directions, movement/throw/Taya/lunge frames OK")
	else:
		for problem in problems:
			push_error(problem)
	quit(0 if problems.is_empty() else 1)
