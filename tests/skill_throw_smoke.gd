extends SceneTree

const METER = preload("res://scenes/throw_meter.gd")

func _initialize() -> void:
	create_timer(25).timeout.connect(func() -> void: printerr("FAIL: skill throw timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	assert(is_equal_approx(METER.marker_at(0), 0))
	assert(is_equal_approx(METER.marker_at(1.25), 1))
	assert(is_equal_approx(METER.marker_at(2.5), 0))
	assert(is_equal_approx(METER.marker_at(3.125), 0.5))
	for center in [0.25, 0.5, 0.75]:
		assert(METER.quality_at(center, center).power == 1.0)
		assert(METER.quality_at(center + 0.02, center).spread == 0.0)
		var yellow: Dictionary = METER.quality_at(center + 0.2, center)
		assert(yellow.band == "GOOD" and yellow.power >= 0.65 and yellow.power <= 0.95 and yellow.spread <= 5)
		var red: Dictionary = METER.quality_at(0 if center >= 0.5 else 1, center)
		assert(red.band == "RISKY" and red.power >= 0.25 and red.power <= 0.6 and red.spread == 20)
	var arena := Node2D.new()
	root.add_child(arena)
	var centers: Array[float] = []
	var can: CharacterBody2D = load("res://scenes/Taya can.tscn").instantiate()
	can.starts_toppled = false
	can.position = Vector2(100, 100)
	arena.add_child(can)
	var guard: CharacterBody2D = load("res://scenes/Thrower Hat Thrower.tscn").instantiate()
	arena.add_child(guard)
	guard.can_node = can
	guard.set_meta("peer_id", 2)
	var match_logic: Node2D = load("res://game/match/match.gd").new()
	match_logic.notice_label = Label.new()
	match_logic.stage = "active"
	match_logic.scores = {1: 0, 2: 0}
	for character in ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]:
		var actor: CharacterBody2D = load("res://scenes/Thrower %s.tscn" % character).instantiate()
		arena.add_child(actor)
		actor.name_label = Label.new()
		actor.add_child(actor.name_label)
		actor.update_name_color()
		assert(actor.name_label.get_theme_color("font_color") == actor.THROWER_NAME_COLOR)
		actor.network_controlled = true
		actor.apply_network_input({"move": Vector2.RIGHT, "aim": Vector2(800, 400), "throw": true})
		actor._start_charge()
		var center: float = actor.sweet_spot
		centers.append(center)
		for frame in range(4): await physics_frame
		assert(actor.sweet_spot == center, "Target must not change while charging")
		assert(center >= 0.25 and center <= 0.75)
		actor._start_throw(center * 1.25)
		assert(actor.charge_ratio == 1 and actor.release_spread == 0)
		actor.set_taya_role(true)
		assert(actor.name_label.get_theme_color("font_color") == actor.TAYA_NAME_COLOR)
		assert(actor.attack_state == actor.AttackState.FREE and actor.taya_action == &"")
		assert(not actor.charge_bar.visible and not actor.attack_sprite.visible and actor.sprite.visible)
		var before := actor.position
		actor._physics_process(1.0 / 60.0)
		assert(actor.position.x > before.x, "New Taya must move on the next frame")
		actor.set_taya_role(false)
		assert(actor.name_label.get_theme_color("font_color") == actor.THROWER_NAME_COLOR)
		actor.taya_action = &"lunge"
		actor.taya_visual.action = &"lunge"
		actor.network_edges["lunge"] = true
		actor.set_taya_role(true)
		assert(actor.name_label.get_theme_color("font_color") == actor.TAYA_NAME_COLOR)
		assert(actor.taya_action == &"" and actor.taya_visual.action == &"" and actor.network_edges.is_empty())
		before = actor.position
		actor._physics_process(1.0 / 60.0)
		assert(actor.position.x > before.x)
		actor.set_taya_role(false)
		assert(actor.name_label.get_theme_color("font_color") == actor.THROWER_NAME_COLOR)
		actor._start_charge()
		assert(not actor.release_network_throw(actor.charge_id - 1, actor.charge_started, Vector2.RIGHT))
		assert(not actor.release_network_throw(actor.charge_id, actor.charge_started - 1, Vector2.RIGHT))
		assert(not actor.release_network_throw(actor.charge_id, actor.charge_started + 1, Vector2.RIGHT))
		actor.set_taya_role(false)
		assert(actor.name_label.get_theme_color("font_color") == actor.THROWER_NAME_COLOR)
		# Exercise the real match handler with overlapping bodies and a charging victim.
		actor.position = Vector2(800, 450)
		actor.set_meta("peer_id", 1)
		actor.can_node = can
		guard.position = actor.position
		guard.set_taya_role(true)
		guard.tag_ready_at = 0.0 # This guard is already past the new-role cooldown.
		actor._start_charge()
		match_logic.tag_immunity = 0.0
		match_logic._tag_requested(actor, guard)
		assert(actor.is_taya and not guard.is_taya)
		assert(match_logic.tag_immunity == 1.0)
		before = actor.position
		actor._physics_process(1.0 / 60.0)
		assert(actor.position.x > before.x, "Overlap and tag immunity must not trap the new Taya: %s -> %s, guard %s, velocity %s" % [before, actor.position, guard.position, actor.velocity])
		match_logic._tag_requested(guard, actor)
		assert(actor.is_taya and not guard.is_taya, "Keep protection against instant re-tagging")
		actor.free()
	assert(centers.any(func(value: float) -> bool: return not is_equal_approx(value, centers[0])))
	assert(root.get_node("LanSession").capacity() == 5)
	match_logic.notice_label.free()
	match_logic.free()
	print("PASS: bouncing marker, green/yellow/red quality, fixed randomized targets, all five characters recover immediately, interrupted states clear, invalid releases rejected.")
	quit(0)
