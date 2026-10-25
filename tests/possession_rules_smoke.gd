extends SceneTree

func _initialize() -> void:
	create_timer(30).timeout.connect(func() -> void: printerr("FAIL: possession/rules timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("LanSession")
	session.begin_local("developer")
	var arena := Node2D.new()
	root.add_child(arena)
	var base := Node2D.new()
	base.name = "Base"
	base.position = Vector2(1100, 700)
	arena.add_child(base)
	var can: CharacterBody2D = load("res://scenes/Taya can.tscn").instantiate()
	can.starts_toppled = false
	can.auto_stand_up = false
	can.base_path = NodePath("../Base")
	can.position = base.position
	arena.add_child(can)
	for character in ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]:
		var actor: CharacterBody2D = load("res://scenes/Thrower %s.tscn" % character).instantiate()
		arena.add_child(actor)
		actor.position = Vector2(500, 500)
		actor.can_node = can
		actor.walk_speed = 240
		actor.sprint_speed = 340
		actor.network_controlled = true
		actor.set_physics_process(false)
		actor.set_meta("peer_id", 1)
		actor.apply_network_input({"aim": Vector2(1300, 500)})
		actor._refresh_possession_visual()
		assert(actor.possession_icon.item == &"slipper" and actor.possession_icon.visible)
		actor._start_charge()
		actor._update_trajectory()
		assert(actor.charge_bar.visible and not actor.predicted_path.is_empty())
		assert(actor.sprite.visible and not actor.attack_sprite.visible, "No baked hand slipper while charging")
		assert(actor.possession_icon.item == &"slipper")
		# Render the very same actor as another participant; stale owner guides also clear.
		actor.set_meta("peer_id", 2)
		actor._update_trajectory()
		actor._refresh_possession_visual()
		assert(not actor.charge_bar.visible and actor.predicted_path.is_empty(), "Other players and the host must not see this actor's aim guides")
		actor.set_meta("peer_id", 1)
		actor.set_taya_role(false)
		actor._start_charge()
		actor._start_throw(actor.sweet_spot * 1.25)
		assert(actor.possession_icon.item == &"slipper" and not actor.attack_sprite.visible)
		actor.attack_sprite.frame = 2
		actor._on_attack_frame_changed()
		actor._refresh_possession_visual()
		assert(is_instance_valid(actor.active_slipper) and actor.possession_icon.item == &"")
		assert(actor.attack_sprite.visible and not actor.sprite.visible, "Only empty-hand release/recovery art is shown")
		actor.active_slipper.free()
		actor.active_slipper = null
		actor.set_taya_role(true)
		var delay: float = actor.tag_ready_at - session.clock_time()
		assert(delay > 2.95 and delay <= 3.001, "%s delay=%.12f" % [character, delay])
		assert(not actor.can_tag() and actor.can_lunge(), "Tag cooldown must not freeze movement or lunge")
		var victim: CharacterBody2D = load("res://scenes/Thrower Hat Thrower.tscn").instantiate()
		arena.add_child(victim)
		victim.set_physics_process(false)
		victim.set_meta("peer_id", 2)
		victim.position = Vector2(850, 500)
		var match_logic: Node2D = load("res://game/match/match.gd").new()
		match_logic.stage = "active"
		match_logic.scores = {1: 0, 2: 0}
		match_logic._tag_requested(victim, actor)
		assert(actor.is_taya and not victim.is_taya and match_logic.scores[1] == 0, "Host rejects tags during the three-second delay")
		var ready_at: float = actor.tag_ready_at
		actor.set_taya_role(true)
		assert(actor.tag_ready_at == ready_at, "Refreshing the same role must not extend immunity")
		actor.apply_network_input({"move": Vector2.RIGHT})
		var initial: Vector2 = actor.position
		actor._physics_process(1.0 / 60.0)
		assert(actor.position.x > initial.x)
		if character == "Hat Thrower":
			actor.apply_network_input({})
			while session.clock_time() < actor.tag_ready_at: await process_frame
		else: actor.tag_ready_at = session.clock_time() - 0.01
		assert(actor.can_tag(), "%s tags: role=%s carrying=%s can=%s now=%s ready=%s" % [character, actor.is_taya, actor.carrying_can, can.state, session.clock_time(), actor.tag_ready_at])
		actor.position = Vector2(770, 500)
		match_logic._tag_requested(victim, actor)
		assert(victim.is_taya and not actor.is_taya and match_logic.scores[1] == 1)
		assert(victim.tag_ready_at > session.clock_time() + 2.95 and not victim.can_tag())
		victim.free()
		match_logic.free()
		actor.set_taya_role(true)
		actor.tag_ready_at = 0.0
		# Real E pickup/placement callbacks must finish even though item artwork is hidden.
		can.reset_for_preview(base.position)
		can.topple()
		can.settled = true
		actor.position = can.position - Vector2(45, 0)
		actor.apply_network_input({"interact": true})
		actor._physics_process(1.0 / 60.0)
		actor._refresh_possession_visual()
		assert(actor.carrying_can and actor.possession_icon.item == &"can")
		assert(actor.sprite.visible and not actor.taya_visual.visible and not can.can_sprite.visible)
		await create_timer(0.72).timeout
		assert(actor.taya_action == &"", "Hidden pickup artwork must not stall gameplay")
		actor.position = Vector2(600, 500)
		actor.velocity = Vector2.ZERO
		actor.apply_network_input({"move": Vector2.RIGHT, "sprint": true})
		actor._physics_process(1.0)
		assert(is_equal_approx(actor.velocity.length(), 204.0), "Carrying is 15% below normal walking and ignores sprint boost")
		assert(not actor.can_tag() and not actor.can_lunge())
		actor.apply_network_input({})
		actor._physics_process(0.2)
		await create_timer(0.1).timeout
		assert(can.is_carried(), "Do not auto-return or auto-place the can")
		actor.position = base.position - Vector2(45, 0)
		actor.apply_network_input({"interact": true})
		actor._physics_process(1.0 / 60.0)
		await create_timer(0.72).timeout
		actor._refresh_possession_visual()
		assert(can.is_standing() and can.position == base.position and not actor.carrying_can)
		assert(actor.possession_icon.item == &"" and not actor.possession_icon.visible)
		actor.free()
		print("PASS: %s possession icons, private aim, three-second tag delay, free movement and manual 15%% slower can carrying" % character)
	arena.free()
	quit(0)
