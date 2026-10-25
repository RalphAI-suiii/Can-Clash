extends Node2D

## The node position is the slipper's ground track; height is its small visual arc.
signal picked_up
signal can_hit(target: Node2D)
signal player_hit(target: Node2D)
signal returned_after_penalty

const MIN_LAUNCH_SPEED := 312.0
const MAX_LAUNCH_SPEED := 648.0
const GRAVITY: float = 700.0
const AIR_DRAG: float = 0.18
const GROUND_FRICTION: float = 330.0
const FLOOR_BOUNCE: float = 0.34
const WALL_BOUNCE: float = 0.55
const CAN_HIT_RADIUS: float = 35.0
const WALL_COLLISION_MASK: int = 1 | 8 # World and slipper-only dividers.

@export var pickup_radius: float = 72.0

var throw_owner: Node2D
var charge_ratio: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var height: float = 0.0
var vertical_speed: float = 0.0
var spin_angle: float = 0.0
var angular_speed: float = 0.0
var age: float = 0.0
var floor_bounces: int = 0
var resting: bool = false
var launch_origin: Vector2
var arena_bounds: Rect2
var outline_color := Color("329dff")
var lost_remaining := 0.0
var hit_registered := false
var throwoff_stop_at_can := false
var special_kind: StringName = &""
var steer_until := 0.0
var returning := false
var return_complete := false
var ricochet_redirected := false


func launch(thrower: Node2D, release_point: Vector2, aim: Vector2, charge: float, origin: Vector2, speed_multiplier: float = 1.0) -> void:
	throw_owner = thrower
	global_position = release_point
	launch_origin = origin
	charge_ratio = clampf(charge, 0.0, 1.0)
	velocity = aim.normalized() * lerpf(MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED, charge_ratio) * speed_multiplier
	vertical_speed = lerpf(190.0, 305.0, charge_ratio)
	angular_speed = lerpf(TAU * 1.7, TAU * 3.0, charge_ratio)
	queue_redraw()


func is_resting() -> bool:
	return resting


func can_pick_up(actor: Node2D) -> bool:
	if special_kind == &"rapid" or special_kind == &"self_return": return false
	# Retrieve on landing, including the small floor bounce; don't wait for spin/friction.
	var near_ground := resting or (floor_bounces > 0 and height <= 12.0)
	return lost_remaining <= 0.0 and not is_queued_for_deletion() and near_ground and actor == throw_owner and actor.global_position.distance_to(global_position) <= pickup_radius


func pick_up(actor: Node2D) -> bool:
	if not can_pick_up(actor):
		return false
	picked_up.emit()
	queue_free()
	return true


func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if returning:
		if not is_instance_valid(throw_owner):
			queue_free()
			return
		global_position = global_position.move_toward(throw_owner.get_throw_origin(), 850.0 * delta)
		spin_angle += 9.0 * delta
		queue_redraw()
		if global_position.distance_to(throw_owner.get_throw_origin()) < 16.0:
			returning = false
			return_complete = true
			visible = false
			picked_up.emit()
			if special_kind == &"self_return":
				if throw_owner.active_slipper == self: throw_owner.active_slipper = null
				queue_free()
		return
	if lost_remaining > 0.0:
		lost_remaining = maxf(0.0, lost_remaining - delta)
		if lost_remaining == 0.0:
			if is_instance_valid(throw_owner) and throw_owner.get("active_slipper") == self:
				throw_owner.active_slipper = null
			returned_after_penalty.emit()
			queue_free()
		return
	if resting:
		if special_kind == &"rapid" or special_kind == &"self_return": returning = true
		return
	# Sweep the hand-to-release gap too, so close throws cannot spawn past a wall.
	var previous_position: Vector2 = launch_origin if age == 0.0 else global_position
	if special_kind == &"mind_control" and age < 2.0 and LanSession.clock_time() < steer_until and is_instance_valid(throw_owner) and not throw_owner.is_stunned():
		var desired: Vector2 = throw_owner._aim_position() - global_position
		if desired.length_squared() > 100.0 and velocity.length_squared() > 1.0:
			var turn := clampf(wrapf(desired.angle() - velocity.angle(), -PI, PI), -deg_to_rad(150.0) * delta, deg_to_rad(150.0) * delta)
			velocity = velocity.rotated(turn)
	var next_position: Vector2 = global_position + velocity * delta
	age += delta
	if (special_kind == &"rapid" or special_kind == &"self_return") and age >= 2.5:
		returning = true
		return
	if velocity.length_squared() > 1.0:
		var ray := PhysicsRayQueryParameters2D.create(previous_position, next_position, WALL_COLLISION_MASK)
		var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			next_position = wall.position + wall.normal * 3.0
			velocity = velocity.bounce(wall.normal) * WALL_BOUNCE
			if special_kind == &"ricochet" and not ricochet_redirected:
				ricochet_redirected = true
				for target in get_tree().get_nodes_in_group("can_targets"):
					if target.is_standing():
						var desired: Vector2 = target.get_hit_center() - next_position
						var turn := clampf(wrapf(desired.angle() - velocity.angle(), -PI, PI), -deg_to_rad(75.0), deg_to_rad(75.0))
						velocity = velocity.rotated(turn)
						break
			angular_speed *= -0.7
			vertical_speed = maxf(vertical_speed, 75.0)
			if special_kind == &"self_return":
				global_position = next_position
				returning = true
				queue_redraw()
				return
	if special_kind == &"stun":
		for candidate in get_tree().get_nodes_in_group("taya_players"):
			if not candidate.is_taya or LanSession.clock_time() < candidate.stun_immune_until: continue
			var point := Geometry2D.get_closest_point_to_segment(candidate.global_position, previous_position, next_position)
			if point.distance_squared_to(candidate.global_position) <= 42.0 * 42.0:
				global_position = point
				velocity = Vector2.ZERO
				resting = true
				player_hit.emit(candidate)
				queue_redraw()
				return

	var hit_can
	var hit_point: Vector2
	var nearest: float = INF
	for candidate in get_tree().get_nodes_in_group("can_targets"):
		if not candidate.is_standing():
			continue
		var center: Vector2 = candidate.get_hit_center()
		var point: Vector2 = Geometry2D.get_closest_point_to_segment(center, previous_position, next_position)
		if point.distance_squared_to(center) > CAN_HIT_RADIUS * CAN_HIT_RADIUS:
			continue
		var distance: float = previous_position.distance_squared_to(point)
		if distance < nearest:
			nearest = distance
			hit_can = candidate
			hit_point = point

	if hit_can != null and throwoff_stop_at_can:
		global_position = hit_point
		velocity = Vector2.ZERO
		vertical_speed = 0.0
		height = 0.0
		resting = true
		queue_redraw()
		return
	if hit_can != null and velocity.length() >= 55.0 and hit_can.receive_slipper_hit(velocity, charge_ratio, hit_point):
		if not hit_registered:
			hit_registered = true
			can_hit.emit(hit_can)
		var normal: Vector2 = (hit_point - hit_can.get_hit_center()).normalized()
		if normal.is_zero_approx():
			normal = -velocity.normalized()
		global_position = hit_point + normal * 6.0
		velocity = velocity.bounce(normal) * 0.38
		vertical_speed = maxf(vertical_speed, 115.0)
		angular_speed *= -0.65
		if special_kind == &"rapid" or special_kind == &"self_return": returning = true
	else:
		global_position = next_position
	if arena_bounds.has_area() and not arena_bounds.has_point(global_position):
		if special_kind == &"rapid" or special_kind == &"self_return":
			returning = true
			return
		lost_remaining = 3.0
		visible = false
		velocity = Vector2.ZERO
		return

	height += vertical_speed * delta - 0.5 * GRAVITY * delta * delta
	vertical_speed -= GRAVITY * delta
	if height <= 0.0:
		height = 0.0
		if vertical_speed < -80.0 and floor_bounces < 3:
			vertical_speed = -vertical_speed * FLOOR_BOUNCE
			velocity *= 0.72
			angular_speed *= 0.58
			floor_bounces += 1
		else:
			vertical_speed = 0.0
			velocity = velocity.move_toward(Vector2.ZERO, GROUND_FRICTION * delta)
			angular_speed *= exp(-8.0 * delta)
			spin_angle = lerp_angle(spin_angle, 0.0, minf(delta * 9.0, 1.0))
			if velocity.length() < 14.0 and absf(angular_speed) < 0.2:
				velocity = Vector2.ZERO
				angular_speed = 0.0
				resting = true
				if special_kind == &"rapid" or special_kind == &"self_return": returning = true
	else:
		velocity *= exp(-AIR_DRAG * delta)
	spin_angle = wrapf(spin_angle + angular_speed * delta, -PI, PI)
	queue_redraw()


func _draw() -> void:
	var power: float = charge_ratio
	if special_kind != &"":
		var glow := Color("ffb83e") if special_kind == &"rapid" else Color("61d8ff") if special_kind == &"ricochet" else Color("70edb7") if special_kind == &"self_return" else Color("db8aff") if special_kind == &"stun" else Color("ff83ca")
		draw_arc(Vector2(0, -height * 0.55), 37.0, 0, TAU, 32, Color(glow, 0.7), 5.0, true)
	var shadow_alpha: float = 0.23 / (1.0 + height * 0.02)
	draw_set_transform(Vector2(6, 6), 0.0, Vector2(1.0, 0.4))
	for ring in range(6, 0, -1):
		draw_circle(Vector2.ZERO, 23.0 + ring * 2.0, Color(0.18, 0.12, 0.08, shadow_alpha / 6.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not resting and velocity.length() > 55.0 and height > 2.0:
		var trail: Vector2 = -velocity.normalized()
		var side: Vector2 = Vector2(-trail.y, trail.x)
		var origin: Vector2 = Vector2(0, -height * 0.55)
		var trail_color := Color("ffb83e") if special_kind == &"rapid" else Color("61d8ff") if special_kind == &"ricochet" else Color("70edb7") if special_kind == &"self_return" else Color("db8aff") if special_kind == &"stun" else Color("ff83ca") if special_kind == &"mind_control" else Color("ffba32")
		draw_colored_polygon(PackedVector2Array([
			origin + trail * 20.0 + side * 12.0,
			origin + trail * (76.0 + power * 44.0),
			origin + trail * 20.0 - side * 12.0,
		]), Color(trail_color, 0.12 + power * 0.18))
		draw_line(origin + trail * 27.0, origin + trail * (72.0 + power * 42.0), Color(trail_color, 0.31 + power * 0.34), 8.0, true)
		draw_line(origin + trail * 32.0, origin + trail * (64.0 + power * 34.0), Color(trail_color.lightened(0.45), 0.34 + power * 0.38), 3.0, true)
		for index in range(3):
			var offset: float = (index - 1) * 13.0
			var start: Vector2 = origin + trail * (34.0 + index * 7.0) + side * offset
			var finish: Vector2 = origin + trail * (53.0 + power * 35.0 + index * 10.0) + side * offset * 1.4
			draw_line(start, finish, Color(1.0, 0.89, 0.52, 0.21 + power * 0.25), 3.0, true)
	var flash: float = 1.0 - minf(age / 0.15, 1.0)
	if flash > 0.0:
		for index in range(8):
			var ray: Vector2 = Vector2.RIGHT.rotated(index * TAU / 8.0)
			draw_line(ray * 27.0, ray * (36.0 + power * 10.0), Color(1.0, 0.92, 0.58, flash * 0.6), 2.0, true)

	# Keep the original slipper silhouette at one size in every motion state.
	draw_set_transform(Vector2(0, -height * 0.55), spin_angle, Vector2.ONE)
	var outline: PackedVector2Array = PackedVector2Array([
		Vector2(-29, -14), Vector2(-17, -20), Vector2(12, -19),
		Vector2(28, -12), Vector2(32, -1), Vector2(27, 11),
		Vector2(10, 17), Vector2(-16, 17), Vector2(-30, 9),
		Vector2(-33, -1),
	])
	var footbed: PackedVector2Array = PackedVector2Array([
		Vector2(-26, -10), Vector2(-16, -16), Vector2(11, -15),
		Vector2(24, -9), Vector2(28, -1), Vector2(23, 8),
		Vector2(9, 13), Vector2(-15, 13), Vector2(-27, 6),
	])
	var strap: PackedVector2Array = PackedVector2Array([
		Vector2(-10, -15), Vector2(2, -18), Vector2(12, -14),
		Vector2(14, 11), Vector2(3, 14), Vector2(-8, 12),
	])
	var colored_outline := outline.duplicate()
	colored_outline.append(outline[0])
	draw_polyline(colored_outline, outline_color, 8.0, true)
	draw_colored_polygon(outline, Color("20130f"))
	draw_colored_polygon(footbed, Color("9b653d"))
	draw_colored_polygon(strap, Color("63391f"))
	draw_line(Vector2(-15, -11), Vector2(8, -12), Color("d1a16d"), 2.0, true)
	draw_line(Vector2(-20, 10), Vector2(13, 10), Color("4e2c1b"), 2.0, true)


static func predict_path(world: World2D, origin: Vector2, release: Vector2, aim: Vector2, charge: float, targets: Array, speed_multiplier: float = 1.0) -> PackedVector2Array:
	var path := PackedVector2Array([release])
	var point := release
	var speed := aim.normalized() * lerpf(MIN_LAUNCH_SPEED, MAX_LAUNCH_SPEED, charge) * speed_multiplier
	var rise := lerpf(190.0, 305.0, charge)
	var elevation := 0.0
	const STEP := 1.0 / 60.0
	for tick in range(120):
		var before := origin if tick == 0 else point
		var next := point + speed * STEP
		var ray := PhysicsRayQueryParameters2D.create(before, next, WALL_COLLISION_MASK)
		var wall := world.direct_space_state.intersect_ray(ray)
		if not wall.is_empty():
			next = wall.position + wall.normal * 3.0
			speed = speed.bounce(wall.normal) * WALL_BOUNCE
			rise = maxf(rise, 75.0)
		var target_hit: Node2D
		var hit_point := Vector2.ZERO
		var nearest := INF
		for target in targets:
			if not target.is_standing():
				continue
			var center: Vector2 = target.get_hit_center()
			var contact := Geometry2D.get_closest_point_to_segment(center, before, next)
			var distance := before.distance_squared_to(contact)
			if contact.distance_squared_to(center) <= CAN_HIT_RADIUS * CAN_HIT_RADIUS and distance < nearest:
				nearest = distance
				target_hit = target
				hit_point = contact
		if target_hit != null and speed.length() >= 55.0:
			var normal: Vector2 = (hit_point - target_hit.get_hit_center()).normalized()
			if normal.is_zero_approx():
				normal = -speed.normalized()
			next = hit_point + normal * 6.0
			speed = speed.bounce(normal) * 0.38
			rise = maxf(rise, 115.0)
			# A toppled target does not block subsequent steps in the real throw.
			targets = targets.filter(func(candidate: Node2D) -> bool: return candidate != target_hit)
		point = next
		elevation += rise * STEP - 0.5 * GRAVITY * STEP * STEP
		rise -= GRAVITY * STEP
		if elevation <= 0.0:
			path.append(point)
			break
		speed *= exp(-AIR_DRAG * STEP)
		if tick % 5 == 0:
			path.append(point)
	return path
