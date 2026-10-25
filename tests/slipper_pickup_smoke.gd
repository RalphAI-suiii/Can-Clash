extends SceneTree

## Run: godot --headless --path . --script res://tests/slipper_pickup_smoke.gd
func _initialize() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		printerr("FAIL: moving slipper pickup timed out")
		quit(1)
	)
	_run.call_deferred()


func _run() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var stranger := Node2D.new()
	arena.add_child(stranger)
	for character in ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]:
		var player: CharacterBody2D = load("res://scenes/Thrower %s.tscn" % character).instantiate()
		arena.add_child(player)
		player.position = Vector2(400, 500)
		player.walk_speed = 240.0
		player.sprint_speed = 340.0
		player.velocity = Vector2(340, 0)
		var slipper: Node2D = load("res://scenes/slipper_visual.gd").new()
		arena.add_child(slipper)
		slipper.launch(player, Vector2(500, 500), Vector2.RIGHT, 0.0, Vector2(500, 500))
		player.active_slipper = slipper
		player.position = slipper.position
		assert(not slipper.can_pick_up(player), "Cannot retrieve at launch")
		player.position = Vector2(400, 500)
		var pickup := {"frame": -1, "landed": false, "resting": true, "player_speed": 0.0, "slipper_speed": 0.0}
		slipper.picked_up.connect(func() -> void:
			stranger.global_position = slipper.global_position
			assert(not slipper.pick_up(stranger), "Another player cannot retrieve it")
			pickup.frame = Engine.get_physics_frames()
			pickup.landed = slipper.floor_bounces > 0
			pickup.resting = slipper.is_resting()
			pickup.player_speed = player.velocity.length()
			pickup.slipper_speed = slipper.velocity.length()
		)
		# No interact input: collect automatically on the run at first landing.
		Input.action_press("right")
		Input.action_press("sprint")
		var landing_frame := -1
		for i in range(90):
			await physics_frame
			if pickup.frame >= 0:
				break
			if is_instance_valid(slipper) and slipper.floor_bounces > 0 and landing_frame < 0:
				landing_frame = Engine.get_physics_frames()
		assert(pickup.frame >= 0, "Running over the slipper must collect without E: " + character)
		assert(pickup.landed, "Cannot retrieve during initial flight")
		assert(not pickup.resting and pickup.slipper_speed > 14.0, "No settling delay")
		assert(pickup.player_speed > 330.0, "Pickup must not stop the player")
		if landing_frame >= 0:
			assert(pickup.frame - landing_frame <= 1, "Collect by the next physics tick")
		await physics_frame
		assert(not is_instance_valid(player.active_slipper))
		Input.action_release("interact")

		# A landed slipper outside reach stays out; walking into reach collects it.
		var grounded: Node2D = load("res://scenes/slipper_visual.gd").new()
		arena.add_child(grounded)
		grounded.throw_owner = player
		grounded.resting = true
		grounded.position = player.position + Vector2(500, 0)
		assert(not grounded.can_pick_up(player), "Cannot retrieve outside reach")
		player.active_slipper = grounded
		await physics_frame
		await physics_frame
		assert(is_instance_valid(player.active_slipper), "Out-of-range slipper must remain")
		assert(String(player.sprite.animation).begins_with("empty_"), "Use relaxed empty hands while retrieving: " + character)
		grounded.position = player.position + Vector2(20, 0)
		var before: Vector2 = player.position
		Input.action_release("sprint")
		await physics_frame
		await physics_frame
		assert(not is_instance_valid(player.active_slipper), "Walking collects without E")
		assert(player.position.x > before.x and player.velocity.x >= player.walk_speed)
		await physics_frame
		assert(not String(player.sprite.animation).begins_with("empty_") and player.possession_icon.visible, "Pickup restores held-slipper movement: " + character)
		player._start_charge()
		assert(player.attack_state == player.AttackState.CHARGING, "No post-pickup cooldown")
		Input.action_release("interact")
		Input.action_release("right")
		player._start_throw()
		for i in range(40):
			await physics_frame
			if player.attack_state == player.AttackState.FREE:
				break
		assert(player.attack_state == player.AttackState.FREE and is_instance_valid(player.active_slipper))
		assert(String(player.sprite.animation).begins_with("empty_idle_"), "Release must end in empty-hand idle: " + character)
		# The same empty-hand state lasts through an out-of-bounds return countdown.
		player.active_slipper.lost_remaining = 0.05
		for i in range(8):
			await physics_frame
		assert(not is_instance_valid(player.active_slipper))
		assert(not String(player.sprite.animation).begins_with("empty_") and player.possession_icon.visible, "Penalty return restores the slipper pose: " + character)
		player.free()
	print("PASS: all five throwers collect while moving, use empty-hand idle/movement after release and during retrieval, restore normal poses on pickup/penalty return, and can throw again immediately.")
	arena.free()
	quit()
