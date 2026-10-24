extends Node2D

const PLAYER_FONT = preload("res://assets/fonts/TitanOne-Regular.ttf")
const SLIPPER = preload("res://scenes/slipper_visual.gd")
@export_range(0.5, 1.0, 0.001) var player_scale := 0.576
var actors: Dictionary = {}
var world_tick := 0.0
var send_tick := 0.0
var observed_slippers: Dictionary = {}
var lan_movement: RefCounted
var lan_remote_motion: Dictionary = {}
var lan_phase := ""

func setup_network_world() -> void:
	if has_node("Player"):
		get_node("Player").free()
	LanSession.roster_changed.connect(_sync_actors)
	LanSession.input_received.connect(_receive_input)
	LanSession.throw_input_received.connect(_receive_throw)
	LanSession.world_snapshot_received.connect(_apply_snapshot)
	LanSession.room_closed.connect(_room_closed)
	_sync_actors()
	if not LanSession.is_host():
		for can in get_tree().get_nodes_in_group("can_targets"):
			can.set_physics_process(false)
			if LanSession.mode != "lan": can.collision_layer = 0

func _spawn_point(slot: int) -> Vector2:
	if LanSession.players.size() == 1:
		return Vector2(1210, 820)
	return Vector2(1140 + (slot % 2) * 230, 450 + int(slot / 2) * 250)

func _sync_actors() -> void:
	for id in actors.keys():
		if LanSession.member(id).is_empty():
			actors[id].set_taya_role(false)
			if is_instance_valid(actors[id].active_slipper):
				actors[id].active_slipper.queue_free()
			actors[id].queue_free()
			actors.erase(id)
	for entry in LanSession.players:
		if actors.has(entry.id):
			continue
		var path := "res://scenes/Thrower %s.tscn" % LanSession.CHARACTERS[entry.character]
		var actor: CharacterBody2D = load(path).instantiate()
		actor.name = "Player" if entry.id == 1 else "Player_%s" % entry.id
		actor.position = _spawn_point(entry.slot)
		actor.scale = Vector2.ONE * player_scale
		actor.walk_speed = 240.0
		actor.sprint_speed = 340.0
		actor.player_color = entry.color
		actor.set_meta("peer_id", entry.id)
		actor.set_meta("bot", entry.bot)
		actor.network_controlled = entry.id != LanSession.local_id() or entry.bot
		actor.accept_local_input = LanSession.is_host()
		actor.collision_mask = 1 | 2 | 16
		add_child(actor)
		var shadow := Node2D.new()
		shadow.name = "GroundShadow"
		shadow.show_behind_parent = true
		shadow.set_script(preload("res://ui/waiting_room/ground_shadow.gd"))
		actor.add_child(shadow)
		if not LanSession.is_host():
			actor.set_physics_process(false)
			actor.collision_layer = 2 if LanSession.mode == "lan" else 0
		actor.throw_status.visible = entry.id == LanSession.local_id()
		actor.throw_status.scale = Vector2.ONE / player_scale
		actor.throw_status.position.x /= player_scale
		var name_label := Label.new()
		name_label.position = Vector2(-90 / player_scale, -250)
		name_label.scale = Vector2.ONE / player_scale
		name_label.size = Vector2(180, 28)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.text = entry.name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_override("font", PLAYER_FONT)
		name_label.add_theme_font_size_override("font_size", 20)
		name_label.add_theme_color_override("font_outline_color", Color("20130f"))
		name_label.add_theme_constant_override("outline_size", 6)
		actor.add_child(name_label)
		actor.name_label = name_label
		actor.update_name_color()
		actors[entry.id] = actor
		_actor_added(actor)
		if LanSession.mode == "lan" and not LanSession.is_host() and entry.id == LanSession.local_id():
			lan_movement = preload("res://game/lan_movement.gd").new(actor)

func _actor_added(_actor: CharacterBody2D) -> void:
	pass

func _world_inputs_enabled() -> bool:
	return true

func _actor_inputs_enabled(_actor: CharacterBody2D) -> bool:
	return _world_inputs_enabled()

func _local_inputs_enabled() -> bool:
	return _world_inputs_enabled()

func _physics_process(delta: float) -> void:
	if LanSession.is_host():
		for id in actors:
			var actor: CharacterBody2D = actors[id]
			actor.accept_local_input = _actor_inputs_enabled(actor) and (_local_inputs_enabled() if id == LanSession.local_id() else true)
			if actor.get_meta("bot", false) and _actor_inputs_enabled(actor):
				_update_bot(actor)
			if is_instance_valid(actor.active_slipper) and observed_slippers.get(id) != actor.active_slipper.get_instance_id():
				observed_slippers[id] = actor.active_slipper.get_instance_id()
				_slipper_spawned(actor, actor.active_slipper)
		world_tick += delta
		if world_tick >= 0.05:
			world_tick = 0.0
			if LanSession.mode == "lan": _publish_lan_snapshot.call_deferred()
			else: LanSession.publish_world(_snapshot())
	elif LanSession.mode == "lan":
		_update_lan_client(delta)
	else:
		send_tick += delta
		if send_tick >= 1.0 / 30.0:
			send_tick = 0.0
			var active: Node2D = actors.get(LanSession.local_id())
			if active != null:
				var enabled := _local_inputs_enabled() and _actor_inputs_enabled(active)
				LanSession.send_input({"move": Input.get_vector("left", "right", "up", "down") if enabled else Vector2.ZERO, "aim": active.get_global_mouse_position(), "sprint": enabled and Input.is_action_pressed("sprint"), "interact": enabled and Input.is_action_pressed("interact"), "lunge": enabled and Input.is_action_pressed("lunge"), "throw": enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null, "charge_id": active.charge_id})

func _publish_lan_snapshot() -> void:
	if LanSession.mode == "lan" and LanSession.is_host(): LanSession.publish_world(_snapshot())

func _update_lan_client(delta: float) -> void:
	var actor: CharacterBody2D = actors.get(LanSession.local_id())
	if actor == null or lan_movement == null: return
	var enabled: bool = _local_inputs_enabled() and _actor_inputs_enabled(actor) and lan_movement.fresh()
	var packet := {"move": Input.get_vector("left", "right", "up", "down") if enabled else Vector2.ZERO, "aim": actor.get_global_mouse_position(), "sprint": enabled and Input.is_action_pressed("sprint"), "interact": enabled and Input.is_action_pressed("interact"), "lunge": enabled and Input.is_action_pressed("lunge"), "throw": enabled and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null, "charge_id": actor.charge_id}
	LanSession.send_input(packet)
	var movable: bool = enabled and actor.attack_state == actor.AttackState.FREE and actor.taya_action == &""
	if not actor.is_taya and packet["throw"] and not is_instance_valid(actor.active_slipper): movable = false
	lan_movement.step(delta, LanSession.send_sequence, packet, movable)

func _process(delta: float) -> void:
	if LanSession.mode != "lan" or LanSession.is_host(): return
	for id in lan_remote_motion.keys():
		if not actors.has(id):
			lan_remote_motion.erase(id)
			continue
		var motion: Dictionary = lan_remote_motion[id]
		motion.age += delta
		var target: Vector2 = motion.position + motion.velocity * minf(motion.age, 0.08)
		actors[id].position = actors[id].position.lerp(target, 1.0 - exp(-delta / 0.045))

func _receive_input(id: int, packet: Dictionary) -> void:
	if LanSession.is_host() and actors.has(id):
		if _actor_inputs_enabled(actors[id]):
			actors[id].apply_network_input(packet)
		else:
			actors[id].network_input = {}
			actors[id].network_edges.clear()

func _receive_throw(id: int, pressed: bool, charge: int, at_time: float, aim: Vector2) -> void:
	if not LanSession.is_host() or not actors.has(id) or not _world_inputs_enabled(): return
	var actor: CharacterBody2D = actors[id]
	if not _actor_inputs_enabled(actor): return
	actor.network_input["aim"] = aim
	actor.network_input["throw"] = pressed
	if pressed:
		if not actor.is_taya and actor.attack_state == actor.AttackState.FREE and not is_instance_valid(actor.active_slipper):
			actor._start_charge()
	else:
		if not actor.release_network_throw(charge, at_time, aim) and actor.attack_state == actor.AttackState.CHARGING:
			# Quick clicks can release before the start snapshot arrives; cancel, never award a perfect throw.
			actor.set_taya_role(actor.is_taya)

func _slipper_spawned(_actor: CharacterBody2D, _slipper: Node2D) -> void:
	pass

func _update_bot(actor: CharacterBody2D) -> void:
	var can: CharacterBody2D = actor.can_node
	if can == null:
		return
	var destination := can.global_position
	var interact := false
	var lunge := false
	var throwing := false
	if actor.is_taya:
		if actor.carrying_can:
			destination = can.base.global_position
			interact = actor.global_position.distance_to(destination) <= 60.0
		elif can.is_toppled():
			interact = can.can_pick_up(actor)
		else:
			var nearest := INF
			for candidate in actors.values():
				if candidate == actor or actor.safe_strip_rect.has_point(candidate.global_position):
					continue
				var distance: float = actor.global_position.distance_to(candidate.global_position)
				if distance < nearest:
					nearest = distance
					destination = candidate.global_position
			lunge = actor.can_lunge() and nearest < 290.0
	elif is_instance_valid(actor.active_slipper):
		if actor.active_slipper.lost_remaining > 0.0:
			destination = actor.global_position
		else:
			destination = actor.active_slipper.global_position
	elif actor.get_meta("returning", false):
		destination = Vector2(actor.safe_strip_rect.get_center().x, actor.global_position.y)
	else:
		if actor.allowed_throw_rect.has_area():
			var slot := int(LanSession.member(int(actor.get_meta("peer_id"))).get("slot", 0))
			var throwing_y: float = can.global_position.y + (slot - 2) * 125.0
			destination = Vector2(actor.allowed_throw_rect.end.x - 35.0, clampf(throwing_y, actor.allowed_throw_rect.position.y + 90.0, actor.allowed_throw_rect.end.y - 90.0))
		var aim_distance: float = (destination - actor.global_position).length()
		if (actor.allowed_throw_rect.has_area() and aim_distance < 35.0) or (not actor.allowed_throw_rect.has_area() and aim_distance < 300.0):
			destination = actor.global_position
			throwing = actor.attack_state != actor.AttackState.CHARGING or actor.charge_bar.value < float(actor.get_meta("bot_release_at", actor.sweet_spot))
	var toward := destination - actor.global_position
	actor.apply_network_input({"move": toward.normalized() if toward.length() > 18.0 else Vector2.ZERO, "aim": can.get_hit_center() if not actor.is_taya else destination, "throw": throwing, "sprint": true, "interact": interact, "lunge": lunge})

func _snapshot() -> Dictionary:
	var state := {"actors": [], "cans": [], "extra": _extra_snapshot()}
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		var data := {"id": id, "position": actor.position, "velocity": actor.velocity, "taya": actor.is_taya, "carrying": actor.carrying_can, "taya_action": String(actor.taya_action), "facing": actor.facing, "attack": actor.attack_state, "aim": actor.attack_direction, "distance": actor.aim_distance, "charge": actor.charge_bar.value, "charge_id": actor.charge_id, "charge_started": actor.charge_started, "sweet_spot": actor.sweet_spot, "feedback": actor.throw_feedback, "feedback_until": actor.feedback_until, "sprite": actor.sprite.animation, "frame": actor.sprite.frame, "flip": actor.sprite.flip_h, "sprite_pos": actor.sprite.position, "sprite_scale": actor.sprite.scale, "rotation": actor.sprite.rotation, "attack_sprite": actor.attack_sprite.animation, "attack_frame": actor.attack_sprite.frame, "attack_pos": actor.attack_sprite.position, "attack_scale": actor.attack_sprite.scale, "attack_flip": actor.attack_sprite.flip_h, "flash": actor.hit_flash_remaining, "slipper": {}}
		if is_instance_valid(actor.active_slipper):
			var slipper: Node2D = actor.active_slipper
			data.slipper = {"position": slipper.position, "velocity": slipper.velocity, "height": slipper.height, "spin": slipper.spin_angle, "charge": slipper.charge_ratio, "resting": slipper.resting, "bounces": slipper.floor_bounces, "lost": slipper.lost_remaining, "age": slipper.age}
		if LanSession.mode == "lan": data["lan_ack"] = actor.lan_processed_input_sequence
		state.actors.append(data)
	for can in get_tree().get_nodes_in_group("can_targets"):
		state.cans.append({"name": String(can.name), "position": can.position, "state": can.state, "height": can.height, "tilt": can.tilt_angle, "settled": can.settled, "flash": can.hit_flash_remaining, "squash": can.squash, "auto_stand": can.auto_stand_pending, "base": can.base.global_position if can.base != null else can.global_position})
	return state

func _apply_snapshot(snapshot: Dictionary) -> void:
	if LanSession.is_host():
		return
	var phase: String = snapshot.get("extra", {}).get("stage", "waiting")
	var phase_changed := phase != lan_phase
	lan_phase = phase
	_apply_extra_snapshot(snapshot.get("extra", {}))
	for data in snapshot.get("actors", []):
		if not actors.has(data.id):
			continue
		var actor: CharacterBody2D = actors[data.id]
		var lan_client := LanSession.mode == "lan"
		var own: bool = lan_client and data.id == LanSession.local_id() and lan_movement != null
		var reset: bool = phase_changed or actor.is_taya != data.taya or actor.attack_state != data.attack or actor.carrying_can != data.carrying or String(actor.taya_action) != data.taya_action
		if not lan_client:
			actor.position = data.position
		elif not own:
			if reset or actor.position.distance_to(data.position) > 128.0: actor.position = data.position
			lan_remote_motion[data.id] = {"position": data.position, "velocity": data.velocity, "age": 0.0}
		actor.velocity = data.velocity
		if actor.is_taya != data.taya:
			actor.set_taya_role(data.taya)
		actor.carrying_can = data.carrying
		actor.facing = data.facing
		actor.attack_state = data.attack
		actor.attack_direction = data.aim
		actor.aim_distance = data.distance
		actor.slipper_spawned = true
		actor.charge_id = int(data.get("charge_id", 0))
		actor.charge_started = float(data.get("charge_started", 0.0))
		actor.sweet_spot = float(data.get("sweet_spot", 0.5))
		actor.throw_feedback = str(data.get("feedback", ""))
		actor.feedback_until = float(data.get("feedback_until", 0.0))
		actor.charge_bar.target_center = actor.sweet_spot
		actor.charge_bar.value = data.charge
		actor.charge_bar.visible = data.attack == actor.AttackState.CHARGING
		if not own or data.attack != actor.AttackState.FREE or data.carrying or data.taya_action != "":
			actor.sprite.animation = data.sprite
			actor.sprite.frame = data.frame
			actor.sprite.flip_h = data.flip
			actor.sprite.position = data.sprite_pos
			actor.sprite.scale = data.sprite_scale
			actor.sprite.rotation = data.rotation
		actor.sprite.visible = data.attack == actor.AttackState.FREE and not data.carrying and data.taya_action == ""
		actor.attack_sprite.visible = data.attack != actor.AttackState.FREE
		actor.attack_sprite.animation = data.attack_sprite
		actor.attack_sprite.frame = data.attack_frame
		actor.attack_sprite.position = data.attack_pos
		actor.attack_sprite.scale = data.attack_scale
		actor.attack_sprite.flip_h = data.attack_flip
		actor.modulate = Color(1.8, 1.35, 0.9) if data.flash > 0.0 else Color.WHITE
		if data.carrying and data.taya_action == "":
			actor.taya_visual.show_carry(actor._facing_sector(), data.velocity.length() > 10.0)
		elif not data.taya_action.is_empty():
			if String(actor.taya_action) != data.taya_action:
				actor.taya_visual.play_action(StringName(data.taya_action), actor._facing_sector())
		else:
			actor.taya_visual.hide()
		actor.taya_action = StringName(data.taya_action)
		if data.slipper.is_empty():
			if is_instance_valid(actor.active_slipper):
				actor.active_slipper.queue_free()
			actor.active_slipper = null
		else:
			if not is_instance_valid(actor.active_slipper):
				actor.active_slipper = SLIPPER.new()
				add_child(actor.active_slipper)
				actor.active_slipper.set_physics_process(false)
			var slipper: Node2D = actor.active_slipper
			slipper.throw_owner = actor
			slipper.outline_color = actor.player_color
			slipper.position = data.slipper.position
			slipper.velocity = data.slipper.velocity
			slipper.height = data.slipper.height
			slipper.spin_angle = data.slipper.spin
			slipper.charge_ratio = data.slipper.charge
			slipper.resting = data.slipper.resting
			slipper.floor_bounces = data.slipper.bounces
			slipper.lost_remaining = data.slipper.lost
			slipper.visible = data.slipper.lost <= 0.0
			slipper.age = data.slipper.age
			slipper.queue_redraw()
		if own: lan_movement.receive(data, reset)
		actor._update_throw_status()
		if not lan_client and data.id == LanSession.local_id() and actor.attack_state == actor.AttackState.CHARGING:
			actor._update_trajectory()
		actor.queue_redraw()
	for data in snapshot.get("cans", []):
		var can := get_node_or_null(NodePath(data.name))
		if can != null:
			can.position = data.position
			can.state = data.state
			can.height = data.height
			can.tilt_angle = data.tilt
			can.settled = data.settled
			can.squash = data.squash
			can.auto_stand_pending = data.auto_stand
			if can.base != null and not can.base.global_position.is_equal_approx(data.base):
				can.base.global_position = data.base
				queue_redraw()
			can.can_sprite.modulate = Color(2.0, 1.8, 1.1) if data.flash > 0.0 else Color.WHITE
			can._refresh_visual()

func _extra_snapshot() -> Dictionary:
	return {}

func _apply_extra_snapshot(_data: Dictionary) -> void:
	pass

func _room_closed(reason: String) -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menuu.tscn")
	LanSession.set_meta("notice", reason)
