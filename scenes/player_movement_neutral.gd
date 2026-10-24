extends "res://scenes/player_movement_base.gd"

signal tag_requested(thrower: Node2D)

@export var charge_duration: float = 2.5 # Complete out-and-back meter cycle.
const THROW_METER = preload("res://scenes/throw_meter.gd")
@export var accept_local_input: bool = true
@export var is_taya: bool = false
@export var carry_speed: float = 68.0
@export var can_path: NodePath
@export var lunge_distance: float = 300.0
@export var lunge_lock_radius: float = 260.0
@export var lunge_cooldown_seconds: float = 10.0
@export var safe_strip_rect: Rect2
@export var allowed_throw_rect: Rect2
@export var throw_speed_multiplier := 1.0
@export var show_player_ring := true
var taya_min_x := -INF
@export var arena_bounds: Rect2
@export var player_color := Color("329dff")

const SLIPPER_VISUAL = preload("res://scenes/slipper_visual.gd")
const SPRINT_DUST = preload("res://scenes/sprint_dust.gd")
const THROW_BURST = preload("res://scenes/throw_burst.gd")
const THROW_ORIGIN: Vector2 = Vector2(0.0, -103.0)
const TAG_DISTANCE: float = 132.0
const PLAYER_CLEARANCE: float = 134.0
const LUNGE_WINDUP: float = 0.13
const LUNGE_TRAVEL_TIME: float = 0.30
# Order matches DIRECTIONS in player_movement_base.gd.
const AIM_SCALES: Array[float] = [0.89, 0.83, 0.90, 0.83, 0.88, 0.87, 0.93, 0.89]
const THROW_SCALES: Array[float] = [0.95, 0.86, 0.96, 0.86, 0.95, 0.87, 0.94, 0.87]

enum AttackState { FREE, CHARGING, THROWING }

@onready var attack_sprite: AnimatedSprite2D = $AttackSprite
@onready var charge_bar: ProgressBar = $ChargeBar
@onready var taya_visual: Variant = $TayaVisual
@onready var interact_prompt: Label = $InteractPrompt

var attack_state: int = AttackState.FREE
var attack_direction: Vector2 = Vector2.DOWN
var aim_distance: float = 48.0
var charge_elapsed: float = 0.0
var charge_ratio: float = 0.0
var charge_id := 0
var charge_started := 0.0
var sweet_spot := 0.5
var throw_feedback := ""
var feedback_until := 0.0
var release_spread := 0.0
var slipper_spawned: bool = false
var active_slipper: Node2D
var dust_cooldown: float = 0.0
var next_foot_left: bool = false
var can_node
var carrying_can: bool = false
var taya_action: StringName = &""
var lunge_direction: Vector2 = Vector2.DOWN
var lunge_target: Node2D
var lunge_collision_exception: PhysicsBody2D
var lunge_target_reached: bool = false
var lunge_elapsed: float = 0.0
var lunge_travelled: float = 0.0
var lunge_launched: bool = false
var lunge_landed: bool = false
var next_lunge_time: float = 0.0
var last_tagged_target: Node2D
var throw_status: Label
var predicted_path := PackedVector2Array()
var hit_flash_remaining := 0.0


func _ready() -> void:
	super._ready()
	attack_sprite.animation_finished.connect(_on_attack_finished)
	attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	attack_sprite.hide()
	charge_bar.set_script(THROW_METER)
	charge_bar.offset_left = -122
	charge_bar.offset_right = 122
	charge_bar.offset_top = -275
	charge_bar.offset_bottom = -253
	charge_bar._ready()
	charge_bar.hide()
	taya_visual.hide()
	interact_prompt.hide()
	taya_visual.action_finished.connect(_on_taya_action_finished)
	if not String(can_path).is_empty():
		can_node = get_node_or_null(can_path)
	if not is_taya:
		add_to_group("throwers")
	_update_taya_prompt()
	throw_status = Label.new()
	throw_status.position = Vector2(-110, -312)
	throw_status.size = Vector2(220, 26)
	throw_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	throw_status.add_theme_font_override("font", preload("res://assets/fonts/TitanOne-Regular.ttf"))
	throw_status.add_theme_font_size_override("font_size", 17)
	throw_status.add_theme_color_override("font_outline_color", Color("20130f"))
	throw_status.add_theme_constant_override("outline_size", 5)
	throw_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(throw_status)


func _physics_process(delta: float) -> void:
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	modulate = Color(1.8, 1.35, 0.9) if hit_flash_remaining > 0.0 else Color.WHITE
	_update_throw_status()
	if not accept_local_input:
		velocity = Vector2.ZERO
		return
	if is_taya:
		_taya_physics_process(delta)
		return
	if attack_state == AttackState.FREE:
		if _throw_pressed() and not is_instance_valid(active_slipper):
			_start_charge()
		else:
			super._physics_process(delta)
			_update_sprint_dust(delta)
			_update_slipper_pickup()
	elif attack_state == AttackState.CHARGING:
		_update_cursor_aim()
		_refresh_meter()
		_update_trajectory()
		if not _throw_pressed():
			_start_throw()


func _process(_delta: float) -> void:
	# Replicas do not simulate physics, but their timing marker must animate smoothly.
	if attack_state == AttackState.CHARGING and not LanSession.is_host():
		_refresh_meter()
		_update_throw_status()
		if int(get_meta("peer_id", -1)) == LanSession.local_id():
			_update_trajectory()

func _refresh_meter() -> void:
	charge_elapsed = maxf(0.0, LanSession.clock_time() - charge_started)
	charge_bar.target_center = sweet_spot
	charge_bar.value = THROW_METER.marker_at(charge_elapsed, charge_duration * 0.5)
	charge_bar.modulate = Color.WHITE

func throw_quality() -> Dictionary:
	return THROW_METER.quality_at(charge_bar.value, sweet_spot)

func release_network_throw(id: int, at_time: float, aim: Vector2) -> bool:
	if attack_state != AttackState.CHARGING or charge_id != id or not can_throw_here():
		return false
	var now := LanSession.clock_time()
	if not is_finite(at_time) or at_time < now - 0.25 or at_time > now + 0.03 or at_time < charge_started:
		return false
	network_input["aim"] = aim
	_update_cursor_aim()
	_start_throw(maxf(0.0, minf(at_time, now) - charge_started))
	return true

func _taya_physics_process(delta: float) -> void:
	if taya_action == &"lunge":
		_advance_lunge(delta)
		return
	if taya_action != &"":
		velocity = Vector2.ZERO
		return
	if _action_just_pressed("lunge") and can_lunge():
		_start_lunge()
		return
	if can_node != null and _action_just_pressed("interact"):
		if carrying_can and can_node.can_reset(self):
			_start_taya_action(&"place")
			return
		if not carrying_can and can_node.pick_up(self):
			carrying_can = true
			_start_taya_action(&"pickup")
			return

	var original_walk: float = walk_speed
	var original_sprint: float = sprint_speed
	if carrying_can:
		walk_speed = carry_speed
		sprint_speed = carry_speed
	super._physics_process(delta)
	walk_speed = original_walk
	sprint_speed = original_sprint
	if carrying_can:
		dust_cooldown = 0.0
		sprite.hide()
		taya_visual.show_carry(_facing_sector(), velocity.length_squared() > 144.0)
	else:
		taya_visual.hide()
		_update_sprint_dust(delta)
	_try_tag()
	_update_taya_prompt()


func _start_taya_action(next_action: StringName) -> void:
	taya_action = next_action
	velocity = Vector2.ZERO
	if next_action != &"lunge":
		facing = Vector2.DOWN
	sprite.hide()
	attack_sprite.hide()
	charge_bar.hide()
	interact_prompt.hide()
	taya_visual.play_action(next_action, _facing_sector())


func _start_lunge() -> void:
	_restore_lunge_collision(false)
	lunge_target = _find_lunge_target()
	if lunge_target != null and lunge_target.global_position.distance_to(global_position) <= TAG_DISTANCE:
		_try_tag()
		return
	var aim: Vector2 = _aim_position() - global_position
	if lunge_target != null:
		aim = lunge_target.global_position - global_position
	lunge_direction = aim.normalized() if aim.length_squared() > 400.0 else facing.normalized()
	facing = lunge_direction
	lunge_elapsed = 0.0
	lunge_travelled = 0.0
	lunge_target_reached = false
	lunge_launched = false
	lunge_landed = false
	# Only phase through the locked thrower when the dash can land beyond their body.
	if lunge_target is PhysicsBody2D and aim.length() + PLAYER_CLEARANCE + 16.0 <= lunge_distance:
		lunge_collision_exception = lunge_target
		add_collision_exception_with(lunge_collision_exception)
	next_lunge_time = Time.get_ticks_msec() / 1000.0 + lunge_cooldown_seconds
	_start_taya_action(&"lunge")


func _advance_lunge(delta: float) -> void:
	lunge_elapsed += delta
	if lunge_landed:
		velocity = Vector2.ZERO
		return
	if lunge_elapsed < LUNGE_WINDUP:
		velocity = Vector2.ZERO
		return
	if not lunge_launched:
		lunge_launched = true
		_spawn_lunge_dust(false)
	if lunge_elapsed >= LUNGE_WINDUP + LUNGE_TRAVEL_TIME:
		_land_lunge()
		return

	var target_distance: float = INF
	if is_instance_valid(lunge_target) and _is_eligible_thrower(lunge_target):
		var toward_target: Vector2 = lunge_target.global_position - global_position
		target_distance = toward_target.length()
		if target_distance <= TAG_DISTANCE:
			_try_tag()
			if not is_taya or taya_action != &"lunge":
				return
			lunge_target_reached = true
			if lunge_collision_exception == null:
				_land_lunge()
				return
		if not lunge_target_reached:
			var desired_direction: Vector2 = toward_target / target_distance
			lunge_direction = lunge_direction.lerp(desired_direction, minf(delta * 15.0, 1.0)).normalized()
			facing = lunge_direction
			taya_visual.sector = _facing_sector()
			taya_visual.queue_redraw()

	var step: float = minf(lunge_distance / LUNGE_TRAVEL_TIME * delta, lunge_distance - lunge_travelled)
	if target_distance < INF and lunge_collision_exception == null:
		step = minf(step, maxf(target_distance - TAG_DISTANCE + 2.0, 0.0))
	var before: Vector2 = global_position
	velocity = lunge_direction * step / maxf(delta, 0.001)
	_move_character()
	var moved: float = global_position.distance_to(before)
	lunge_travelled += moved
	_try_tag()
	if not is_taya or taya_action != &"lunge":
		return
	if is_instance_valid(lunge_target) and global_position.distance_to(lunge_target.global_position) <= TAG_DISTANCE:
		lunge_target_reached = true
	var reached_target: bool = is_instance_valid(lunge_target) and _is_eligible_thrower(lunge_target) and global_position.distance_to(lunge_target.global_position) <= TAG_DISTANCE
	if moved < step * 0.2 or lunge_travelled >= lunge_distance - 0.5 or (reached_target and lunge_collision_exception == null):
		_land_lunge()


func _land_lunge() -> void:
	if lunge_landed:
		return
	lunge_landed = true
	velocity = Vector2.ZERO
	_restore_lunge_collision(true)
	taya_visual.begin_lunge_recovery()
	_spawn_lunge_dust(true)


func _restore_lunge_collision(separate: bool) -> void:
	if separate and is_instance_valid(lunge_target) and lunge_target is PhysicsBody2D:
		var away: Vector2 = global_position - lunge_target.global_position
		var direction: Vector2 = away.normalized() if not away.is_zero_approx() else -lunge_direction
		if away.length() < PLAYER_CLEARANCE:
			global_position = lunge_target.global_position + direction * PLAYER_CLEARANCE
	if is_instance_valid(lunge_collision_exception):
		remove_collision_exception_with(lunge_collision_exception)
	lunge_collision_exception = null


func _spawn_lunge_dust(landing: bool) -> void:
	var side := Vector2(-lunge_direction.y, lunge_direction.x)
	var count: int = 4 if landing else 3
	for index in range(count):
		var spread: float = float(index) - float(count - 1) * 0.5
		var dust = SPRINT_DUST.new()
		get_parent().add_child(dust)
		dust.global_position = global_position + side * spread * 20.0 - lunge_direction * (0.0 if landing else 12.0) + Vector2(0, -3)
		dust.drift_direction = (side * spread * 0.55 + lunge_direction * (0.7 if landing else -0.7)).normalized()
		dust.drift_speed = 82.0 if landing else 64.0
		dust.lifetime = 0.66 if landing else 0.57
		dust.scale = Vector2.ONE * (1.35 if landing else 1.12)


func _find_lunge_target() -> Node2D:
	var nearest: Node2D
	var nearest_distance_squared: float = lunge_lock_radius * lunge_lock_radius
	for candidate in get_tree().get_nodes_in_group("throwers"):
		if not candidate is Node2D or not _is_eligible_thrower(candidate):
			continue
		var distance_squared: float = global_position.distance_squared_to(candidate.global_position)
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared
	return nearest


func _is_eligible_thrower(candidate: Node2D) -> bool:
	return candidate != self and not (safe_strip_rect.has_area() and safe_strip_rect.has_point(candidate.global_position))


func _try_tag() -> void:
	if not can_tag():
		return
	var current_target: Node2D
	for candidate in get_tree().get_nodes_in_group("throwers"):
		if candidate is Node2D and _is_eligible_thrower(candidate) and candidate.global_position.distance_squared_to(global_position) <= TAG_DISTANCE * TAG_DISTANCE:
			current_target = candidate
			break
	if current_target == null:
		for index in get_slide_collision_count():
			var collider: Object = get_slide_collision(index).get_collider()
			if collider is Node2D and collider.is_in_group("throwers") and _is_eligible_thrower(collider):
				current_target = collider
				break
	if current_target != last_tagged_target:
		last_tagged_target = current_target
		if current_target != null:
			tag_requested.emit(current_target)


func _on_taya_action_finished(completed: StringName) -> void:
	if completed == &"place" and can_node != null:
		if can_node.reset_at_base(self):
			carrying_can = false
	taya_action = &""
	if carrying_can:
		taya_visual.show_carry(_facing_sector(), false)
	else:
		taya_visual.hide()
		sprite.show()
		_play("idle", facing)
	_update_taya_prompt()


func _update_taya_prompt() -> void:
	interact_prompt.hide()
	if not is_taya or can_node == null or taya_action != &"":
		return
	if carrying_can:
		interact_prompt.text = "E  Stand can up" if can_node.can_reset(self) else "Carry can to base"
	elif can_node.can_pick_up(self):
		interact_prompt.text = "E  Pick up can"
	else:
		return
	interact_prompt.show()


func can_tag() -> bool:
	return is_taya and not carrying_can and can_node != null and can_node.is_standing()


func can_lunge() -> bool:
	return can_tag() and Time.get_ticks_msec() / 1000.0 >= next_lunge_time


func _facing_sector() -> int:
	return (roundi(facing.angle() / (PI / 4.0)) + 8) % 8


func set_taya_role(enabled: bool) -> void:
	_restore_lunge_collision(taya_action == &"lunge")
	if is_taya and not enabled and carrying_can and can_node != null:
		can_node.drop(self)
		carrying_can = false
	is_taya = enabled
	movement_min_x = taya_min_x if enabled else -INF
	global_position.x = maxf(global_position.x, movement_min_x)
	velocity = Vector2.ZERO
	attack_sprite.stop()
	charge_elapsed = 0.0
	charge_started = 0.0
	predicted_path.clear()
	slipper_spawned = true
	lunge_target = null
	lunge_elapsed = 0.0
	lunge_landed = false
	taya_visual.action = &""
	network_edges.clear()
	queue_redraw()
	attack_state = AttackState.FREE
	attack_sprite.hide()
	charge_bar.hide()
	last_tagged_target = null
	if enabled:
		remove_from_group("throwers")
	else:
		add_to_group("throwers")
	taya_action = &""
	taya_visual.hide()
	sprite.show()
	_update_taya_prompt()


func can_throw_here() -> bool:
	return not is_taya and accept_local_input and (not allowed_throw_rect.has_area() or allowed_throw_rect.has_point(global_position))


func _start_charge() -> void:
	if not can_throw_here() or is_instance_valid(active_slipper):
		return
	attack_state = AttackState.CHARGING
	velocity = Vector2.ZERO
	dust_cooldown = 0.0
	charge_elapsed = 0.0
	charge_id += 1
	charge_started = LanSession.clock_time()
	sweet_spot = randf_range(0.25, 0.75)
	charge_bar.target_center = sweet_spot
	set_meta("bot_release_at", sweet_spot + randf_range(-0.025, 0.025))
	charge_bar.value = 0.0
	charge_bar.show()
	interact_prompt.hide()
	_update_cursor_aim()
	sprite.hide()
	attack_sprite.show()
	attack_sprite.play(StringName("aim_" + _attack_direction_name()))


func _start_throw(release_elapsed: float = -1.0) -> void:
	if not can_throw_here():
		set_taya_role(is_taya)
		return
	predicted_path.clear()
	queue_redraw()
	if release_elapsed >= 0.0:
		charge_bar.value = THROW_METER.marker_at(release_elapsed, charge_duration * 0.5)
	var quality := throw_quality()
	charge_ratio = quality.power
	release_spread = quality.spread
	throw_feedback = "%s %d%%" % [quality.band, roundi(charge_ratio * 100.0)]
	feedback_until = LanSession.clock_time() + 0.8
	attack_direction = attack_direction.rotated(deg_to_rad(randf_range(-release_spread, release_spread)))
	charge_bar.hide()
	attack_state = AttackState.THROWING
	slipper_spawned = false
	_set_attack_visual(_attack_sector(), true)
	attack_sprite.play(StringName("throw_" + _attack_direction_name()))


func _attack_direction_name() -> String:
	return DIRECTIONS[_attack_sector()]


func _attack_sector() -> int:
	return (roundi(attack_direction.angle() / (PI / 4.0)) + 8) % 8


func _update_cursor_aim() -> void:
	var aim: Vector2 = _aim_position() - get_throw_origin()
	if aim.length_squared() <= 0.01:
		return
	var previous_sector: int = _attack_sector()
	var sector: int = (roundi(aim.angle() / (PI / 4.0)) + 8) % 8
	aim_distance = aim.length()
	attack_direction = aim.normalized()
	facing = attack_direction
	_set_attack_visual(sector, false)
	if attack_sprite.visible and sector != previous_sector:
		var frame: int = attack_sprite.frame
		var progress: float = attack_sprite.frame_progress
		attack_sprite.play(StringName("aim_" + DIRECTIONS[sector]))
		attack_sprite.set_frame_and_progress(frame, progress)


func _set_attack_visual(sector: int, releasing: bool) -> void:
	var attack_scale: float = THROW_SCALES[sector] if releasing else AIM_SCALES[sector]
	attack_sprite.scale = Vector2.ONE * attack_scale
	attack_sprite.position = Vector2(0, -120.5 * attack_scale)
	# These atlas rows do not share one mirror rule: the down-left aim and
	# release drawings face opposite sides, while up-left needs mirroring.
	attack_sprite.flip_h = sector == 5 or (sector == 3 and not releasing)


func _on_attack_frame_changed() -> void:
	if attack_state != AttackState.THROWING or attack_sprite.frame < 2 or slipper_spawned:
		return
	if not can_throw_here():
		set_taya_role(is_taya)
		return
	slipper_spawned = true
	var release_point: Vector2 = get_throw_origin() + attack_direction * minf(48.0, aim_distance * 0.5)
	var burst = THROW_BURST.new()
	get_parent().add_child(burst)
	burst.global_position = release_point
	burst.direction = attack_direction
	burst.charge_ratio = charge_ratio
	var slipper = SLIPPER_VISUAL.new()
	get_parent().add_child(slipper)
	slipper.launch(self, release_point, attack_direction, charge_ratio, get_throw_origin(), throw_speed_multiplier)
	slipper.arena_bounds = arena_bounds
	slipper.outline_color = player_color
	active_slipper = slipper


func get_throw_origin() -> Vector2:
	return to_global(THROW_ORIGIN)


func _update_slipper_pickup() -> void:
	interact_prompt.hide()
	if not is_instance_valid(active_slipper) or not active_slipper.can_pick_up(self):
		return
	if active_slipper.pick_up(self):
		active_slipper = null
		interact_prompt.hide()


func _update_sprint_dust(delta: float) -> void:
	if not _action_pressed("sprint") or velocity.length() < walk_speed * 0.85:
		dust_cooldown = 0.0
		return
	dust_cooldown -= delta
	if dust_cooldown > 0.0:
		return
	dust_cooldown = 0.16
	var travel: Vector2 = velocity.normalized()
	var side: Vector2 = Vector2(-travel.y, travel.x) * (-11.0 if next_foot_left else 11.0)
	next_foot_left = not next_foot_left
	var dust = SPRINT_DUST.new()
	get_parent().add_child(dust)
	dust.global_position = global_position + side - travel * 16.0 + Vector2(0, -4)
	dust.drift_direction = -travel


func _on_attack_finished() -> void:
	if attack_state != AttackState.THROWING:
		return
	attack_state = AttackState.FREE
	attack_sprite.hide()
	sprite.show()
	sprite.speed_scale = 1.0
	_play("idle", facing)


func flash_hit() -> void:
	hit_flash_remaining = 0.18


func _update_throw_status() -> void:
	if throw_status == null:
		return
	throw_status.add_theme_color_override("font_color", player_color.lightened(0.4))
	if is_taya:
		throw_status.text = "TAYA • LUNGE READY" if can_lunge() else "TAYA • GUARD THE CAN"
	elif attack_state == AttackState.CHARGING:
		var quality := throw_quality()
		throw_status.text = "%s %d%%" % [quality.band, roundi(quality.power * 100.0)]
		throw_status.add_theme_color_override("font_color", quality.color)
	elif LanSession.clock_time() < feedback_until:
		throw_status.text = throw_feedback
	elif is_instance_valid(active_slipper):
		throw_status.text = "RETURNS IN %.1fs" % active_slipper.lost_remaining if active_slipper.lost_remaining > 0.0 else "RUN OVER YOUR SLIPPER" if active_slipper.can_pick_up(self) else "SLIPPER IN PLAY"
	else:
		throw_status.text = "READY TO THROW"


func _update_trajectory() -> void:
	var origin := get_throw_origin()
	var release := origin + attack_direction * minf(48.0, aim_distance * 0.5)
	predicted_path = SLIPPER_VISUAL.predict_path(get_world_2d(), origin, release, attack_direction, float(throw_quality().power), get_tree().get_nodes_in_group("can_targets"), throw_speed_multiplier)
	queue_redraw()


func _draw() -> void:
	if show_player_ring:
		draw_arc(Vector2(0, 5), 43.0, 0, TAU, 32, Color(player_color, 0.8), 4.0, true)
	if attack_state != AttackState.CHARGING or predicted_path.is_empty():
		return
	var spread: float = throw_quality().spread
	if spread > 0.0:
		var origin := to_local(get_throw_origin())
		var reach := origin.distance_to(to_local(predicted_path[-1]))
		var left := origin + attack_direction.rotated(deg_to_rad(-spread)) * reach
		var right := origin + attack_direction.rotated(deg_to_rad(spread)) * reach
		draw_colored_polygon(PackedVector2Array([origin, left, right]), Color(player_color, 0.13))
		draw_line(origin, left, Color(player_color, 0.5), 2.0, true)
		draw_line(origin, right, Color(player_color, 0.5), 2.0, true)
	for point in predicted_path:
		draw_circle(to_local(point), 3.5, Color(player_color.lightened(0.3), 0.8))
	var landing := to_local(predicted_path[-1])
	draw_arc(landing, 20.0, 0, TAU, 32, player_color.lightened(0.3), 3.0, true)
	draw_line(landing - Vector2(9, 0), landing + Vector2(9, 0), player_color, 2.0, true)
	draw_line(landing - Vector2(0, 9), landing + Vector2(0, 9), player_color, 2.0, true)
