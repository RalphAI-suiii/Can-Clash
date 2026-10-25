extends "res://scenes/slipper_visual.gd"

# A separate cooldown projectile. It never topples the can or needs pickup.
func launch_taya(owner: Node2D, start: Vector2, direction: Vector2) -> void:
	throw_owner = owner
	global_position = start
	velocity = direction.normalized() * 610.0
	special_kind = &"stun"
	outline_color = Color("bd70ff")
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(throw_owner) or not throw_owner.is_taya or throw_owner.get_parent().stage != "active":
		queue_free()
		return
	var before := global_position
	var next := before + velocity * delta
	age += delta
	height = maxf(0.0, 38.0 * sin(PI * age / 2.0))
	if age >= 2.0:
		queue_free()
		return
	var wall := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(before, next, WALL_COLLISION_MASK))
	if not wall.is_empty():
		global_position = wall.position
		queue_free()
		return
	var nearest_target: Node2D
	var nearest_point := Vector2.ZERO
	var nearest_distance := INF
	for target in get_tree().get_nodes_in_group("throwers"):
		if not target is Node2D or target == throw_owner or throw_owner.safe_strip_rect.has_point(target.global_position):
			continue
		if LanSession.clock_time() < target.stun_immune_until:
			continue
		var hit := Geometry2D.get_closest_point_to_segment(target.global_position, before, next)
		var distance := before.distance_squared_to(hit)
		if hit.distance_squared_to(target.global_position) <= 42.0 * 42.0 and distance < nearest_distance:
			nearest_target = target
			nearest_point = hit
			nearest_distance = distance
	if nearest_target != null:
		global_position = nearest_point
		if nearest_target.apply_stun(): player_hit.emit(nearest_target)
		queue_free()
		return
	global_position = next
	spin_angle += 12.0 * delta
	queue_redraw()
