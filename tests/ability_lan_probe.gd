extends Node

# Two local processes: -- host and -- client. Exercises the real ENet snapshots.
var role := ""
var arena_match: Node2D
var started := false
var elapsed := 0.0
var shot_sent := false
var stun_sent := false
var mind_sent := false
var arm_sent := false
var rapid_seen := false
var burst_seen := false
var stun_seen := false
var taya_shot_seen := false
var mind_seen := false
var wall_elapsed := 0.0
var client_id := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else ""
	print("LAN_PROBE_READY ", role)
	if role == "host":
		if LanSession.host_room() != OK: get_tree().quit(1)
	elif role == "client":
		if LanSession.join_room("127.0.0.1") != OK: get_tree().quit(1)
	else:
		get_tree().quit(1)

func _process(delta: float) -> void:
	wall_elapsed += delta
	if wall_elapsed > 12.0:
		push_error("LAN probe timed out: %s phase=%s roster=%d" % [role, LanSession.phase, LanSession.players.size()])
		get_tree().quit(1)
		return
	if not started and LanSession.players.size() == 2 and LanSession.phase == "waiting":
		for entry in LanSession.players:
			if entry.id != 1: client_id = entry.id
		if role == "host":
			LanSession.member(1).character = 0
			for entry in LanSession.players:
				if entry.id != 1: entry.character = 4
			LanSession._publish_roster()
		elif LanSession.players.any(func(entry: Dictionary) -> bool: return entry.character < 0):
			return
		started = true
		LanSession.phase = "match"
		arena_match = load("res://game/match/match.tscn").instantiate()
		get_tree().root.add_child(arena_match)
		if role == "host":
			arena_match._start_preparation()
			arena_match.taya_id = -99
			arena_match._start_scoring()
		else:
			arena_match.set_physics_process(false)
	if not started: return
	elapsed += delta
	if role == "host":
		if elapsed > 0.6 and not mind_sent:
			arena_match.actors[client_id].set_skill_charge(3)
			mind_sent = true
		if not shot_sent and elapsed > 1.0:
			shot_sent = true
			var actor = arena_match.actors[1]
			actor.accept_local_input = true
			actor.set_skill_charge(3)
			arena_match._skill_requested(1, true, actor.global_position + Vector2(300, 0))
			actor.attack_state = actor.AttackState.THROWING
			actor.attack_direction = Vector2.RIGHT
			actor.charge_ratio = 0.5
			actor.slipper_spawned = false
			actor.attack_sprite.play(&"special_throw_right")
			actor.attack_sprite.set_frame_and_progress(2, 0.0)
			actor._on_attack_frame_changed()
		if elapsed > 1.8 and arena_match.actors.has(client_id) and not arena_match.actors[client_id].get_meta("mind_probe_launched", false):
			var client_actor = arena_match.actors[client_id]
			if not client_actor.special_armed:
				push_error("LAN client arming request did not reach host")
				get_tree().quit(1)
				return
			client_actor.set_meta("mind_probe_launched", true)
			client_actor.accept_local_input = true
			client_actor.attack_state = client_actor.AttackState.THROWING
			client_actor.attack_direction = Vector2.RIGHT
			client_actor.charge_ratio = 0.5
			client_actor.slipper_spawned = false
			client_actor.attack_sprite.play(&"special_throw_right")
			client_actor.attack_sprite.set_frame_and_progress(2, 0.0)
			client_actor._on_attack_frame_changed()
		if not stun_sent and elapsed > 3.0:
			stun_sent = true
			if arena_match.actors.has(client_id): arena_match.actors[client_id].apply_stun()
		if elapsed > 3.6 and arena_match.taya_id != 1:
			var guard = arena_match.actors[1]
			guard.set_taya_role(true)
			arena_match.taya_id = 1
			guard.begin_taya_stun_aim()
			guard.release_taya_stun(guard.global_position + Vector2(400, 0))
		if elapsed > 6.0:
			print("LAN_HOST_DONE")
			get_tree().quit(0)
	else:
		if not arm_sent and elapsed > 0.95:
			arm_sent = true
			LanSession.request_skill(true, Vector2(950, 400))
		if elapsed > 1.0 and elapsed < 3.0:
			LanSession.send_input({"move": Vector2.ZERO, "aim": Vector2(600, -1000) if elapsed > 2.0 else Vector2(950, 400), "sprint": false, "interact": false, "lunge": false, "throw": false})
		if arena_match.actors.has(1):
			var host_actor = arena_match.actors[1]
			if not rapid_seen and (is_instance_valid(host_actor.active_slipper) and host_actor.active_slipper.special_kind == &"rapid" or not host_actor.rapid_slippers.is_empty()):
				rapid_seen = true
				print("LAN_RAPID_SEEN")
			if not burst_seen and host_actor.rapid_slippers.size() >= 2:
				burst_seen = true
				print("LAN_BURST_SEEN")
			if not taya_shot_seen and is_instance_valid(host_actor.taya_stun_projectile) and host_actor.taya_stun_ready_at > LanSession.clock_time() + 100.0:
				taya_shot_seen = true
				print("LAN_TAYA_SHOT_SEEN")
		var local_actor = arena_match.actors.get(LanSession.local_id())
		if local_actor != null and not mind_seen and is_instance_valid(local_actor.active_slipper) and local_actor.active_slipper.special_kind == &"mind_control" and local_actor.active_slipper.velocity.y < -20.0:
			mind_seen = true
			print("LAN_MIND_STEER_SEEN")
		if local_actor != null and not stun_seen and local_actor.is_stunned():
			stun_seen = true
			print("LAN_STUN_SEEN")
		if rapid_seen and burst_seen and mind_seen and stun_seen and taya_shot_seen:
			print("LAN_CLIENT_OK")
			get_tree().quit(0)
		elif elapsed > 7.0:
			push_error("LAN snapshot did not carry rapid projectile and stun")
			get_tree().quit(1)
