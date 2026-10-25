extends Node

# Run with: godot --headless --path . res://tests/ability_smoke.tscn
func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	LanSession.begin_local("developer")
	LanSession.developer_bot_count = 4
	LanSession.players[0].character = 0
	LanSession.add_developer_bots()
	var arena_match = load("res://game/match/match.tscn").instantiate()
	get_tree().root.add_child(arena_match)
	await get_tree().process_frame
	arena_match._start_preparation()
	arena_match.taya_id = -99
	arena_match._start_scoring()
	var kinds := [&"rapid", &"ricochet", &"self_return", &"stun", &"mind_control"]
	if arena_match.actors.size() != 5:
		push_error("Expected five character actors")
		get_tree().quit(1)
		return
	for id in arena_match.actors:
		var actor = arena_match.actors[id]
		var index: int = actor.get_meta("character_index")
		for direction in actor.DIRECTIONS:
			for cast in ["special_aim_", "special_throw_", "taya_stun_aim_", "taya_stun_throw_"]:
				if not actor.attack_sprite.sprite_frames.has_animation(StringName(cast + direction)):
					push_error("Missing cast direction %s for character %d" % [direction, index])
					get_tree().quit(1)
					return
			for reaction in ["hit_", "stunned_", "recover_"]:
				if not actor.sprite.sprite_frames.has_animation(StringName(reaction + direction)):
					push_error("Missing reaction direction %s for character %d" % [direction, index])
					get_tree().quit(1)
					return
		actor.accept_local_input = true
		actor.set_skill_charge(3)
		arena_match._skill_requested(id, true, actor.global_position + Vector2(300, 0))
		if not actor.special_armed or actor.skill_charge != 3:
			push_error("Arm failed for character %d" % index)
			get_tree().quit(1)
			return
		actor.attack_state = actor.AttackState.THROWING
		actor.attack_direction = Vector2.RIGHT
		actor.charge_ratio = 0.5
		actor.slipper_spawned = false
		actor.attack_sprite.play(&"throw_right")
		actor.attack_sprite.set_frame_and_progress(2, 0.0)
		actor._on_attack_frame_changed()
		if not is_instance_valid(actor.active_slipper) or actor.active_slipper.special_kind != kinds[index] or actor.skill_charge != 0:
			push_error("Launch failed for character %d" % index)
			get_tree().quit(1)
			return
	var rapid = arena_match.actors[LanSession.local_id()]
	var previous_score: int = arena_match.scores[LanSession.local_id()]
	arena_match._can_hit(arena_match.can, rapid, rapid.active_slipper)
	arena_match._can_hit(arena_match.can, rapid, rapid.active_slipper)
	if arena_match.scores[LanSession.local_id()] != previous_score + 1 or rapid.skill_charge != 1:
		push_error("Rapid Fire awarded a duplicate hit")
		get_tree().quit(1)
		return
	rapid.rapid_next_at = LanSession.clock_time() - 1.0
	rapid._advance_rapid_burst()
	arena_match.can.state = 1
	rapid.rapid_next_at = LanSession.clock_time() - 1.0
	rapid._advance_rapid_burst()
	if rapid.rapid_slippers.size() != 1 or rapid.rapid_remaining != 0:
		push_error("Rapid Fire did not cancel pending shots when the can fell")
		get_tree().quit(1)
		return
	arena_match.can.state = 0
	var mind = arena_match.actors[-4]
	mind.network_controlled = true
	mind.network_input = {"aim": mind.active_slipper.global_position + Vector2(0, -500)}
	mind.active_slipper.steer_until = LanSession.clock_time() + 2.0
	var mind_speed: float = mind.active_slipper.velocity.length()
	mind.active_slipper._physics_process(0.1)
	if mind.active_slipper.velocity.y >= -1.0 or mind.active_slipper.velocity.length() > mind_speed + 1.0:
		push_error("Mind-Controlled slipper did not steer without gaining speed")
		get_tree().quit(1)
		return
	var taya = arena_match.actors[LanSession.local_id()]
	var victim = arena_match.actors[-1]
	victim.position = Vector2(740, 610)
	taya.position = Vector2(930, 610)
	taya.set_skill_charge(3)
	taya.set_taya_role(true)
	taya.carrying_can = true
	arena_match.can.state = 2
	arena_match.can.carrier = taya
	arena_match.taya_id = LanSession.local_id()
	if taya.skill_charge != 3 or taya.special_armed:
		push_error("Role change lost orbs or kept armed state")
		get_tree().quit(1)
		return
	if not taya.begin_taya_stun_aim() or not taya.release_taya_stun(taya.global_position + Vector2(300, 0)):
		push_error("Taya stun did not launch")
		get_tree().quit(1)
		return
	if not taya.carrying_can or arena_match.can.carrier != taya or taya.possession_icon.item != &"can" or not taya.sprite.visible or taya.taya_visual.visible:
		push_error("Taya stun dropped the carried can or replaced its overhead icon")
		get_tree().quit(1)
		return
	if taya.taya_stun_ready_at <= LanSession.clock_time() + 119.0 or taya.begin_taya_stun_aim():
		push_error("Taya cooldown not enforced")
		get_tree().quit(1)
		return
	if not victim.apply_stun() or not victim.is_stunned():
		push_error("Three-second stun failed")
		get_tree().quit(1)
		return
	var first_stun_end: float = victim.stunned_until
	if victim.apply_stun() or victim.stunned_until != first_stun_end or victim.stun_immune_until < first_stun_end + 4.9:
		push_error("Stun immunity failed")
		get_tree().quit(1)
		return
	taya.set_taya_role(false)
	taya.set_taya_role(true)
	if taya.taya_stun_ready_at <= LanSession.clock_time() + 119.0:
		push_error("Taya cooldown was reset by role change")
		get_tree().quit(1)
		return
	print("ABILITY_SMOKE_OK")
	get_tree().quit(0)
