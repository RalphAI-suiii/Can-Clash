extends CharacterBody2D

## Local 2D can motion. The eventual match host must own these state changes.
signal state_changed(new_state: int)

enum State { STANDING, TOPPLED, CARRIED }

const GRAVITY: float = 760.0
const GROUND_FRICTION: float = 190.0
const WALL_BOUNCE: float = 0.42
const FLOOR_BOUNCE: float = 0.42

@export var starts_toppled: bool = true
@export var pickup_radius: float = 60.0
@export var reset_radius: float = 62.0
@export var base_path: NodePath
@export var auto_stand_up := true
@export var show_target_ring := false
@export_range(0.0, 5.0, 0.1) var stand_up_delay := 2.0

@onready var can_sprite: Sprite2D = $CanSprite
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var base: Node2D = get_node_or_null(base_path)

var state: State = State.TOPPLED
var carrier: Node2D
var height: float = 0.0
var vertical_speed: float = 0.0
var tilt_angle: float = -PI / 2.0
var target_tilt: float = -PI / 2.0
var angular_speed: float = 0.0
var squash: float = 0.0
var settled: bool = true
var hit_flash_remaining := 0.0
var auto_stand_pending := false
var rest_elapsed := 0.0


func _ready() -> void:
	add_to_group("can_targets")
	state = State.TOPPLED if starts_toppled else State.STANDING
	if state == State.STANDING:
		tilt_angle = 0.0
		target_tilt = 0.0
	_refresh_visual()


func _physics_process(delta: float) -> void:
	hit_flash_remaining = maxf(0.0, hit_flash_remaining - delta)
	can_sprite.modulate = Color(2.0, 1.8, 1.1) if hit_flash_remaining > 0.0 else Color.WHITE
	if state != State.TOPPLED:
		return
	if settled:
		if auto_stand_pending:
			rest_elapsed += delta
			if rest_elapsed >= stand_up_delay:
				stand_up_here()
		return
	var collision: KinematicCollision2D = move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * WALL_BOUNCE
		angular_speed = -angular_speed * 0.72
		squash = 0.16
	if height > 0.0 or vertical_speed > 0.0:
		height += vertical_speed * delta - 0.5 * GRAVITY * delta * delta
		vertical_speed -= GRAVITY * delta
		if height <= 0.0:
			height = 0.0
			squash = 0.18
			if vertical_speed < -75.0:
				vertical_speed = -vertical_speed * FLOOR_BOUNCE
				velocity *= 0.78
				angular_speed *= 0.82
			else:
				vertical_speed = 0.0
	if height <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, GROUND_FRICTION * delta)
	else:
		velocity *= exp(-0.55 * delta)
	var grounded := height == 0.0 and vertical_speed == 0.0
	var error := 0.0
	if grounded:
		# Finish on the nearest side after freely tumbling through the air.
		target_tilt = roundf((tilt_angle - PI / 2.0) / PI) * PI + PI / 2.0
		error = target_tilt - tilt_angle
		angular_speed += error * 34.0 * delta
	angular_speed *= exp((-7.5 if grounded else -0.6) * delta)
	tilt_angle += angular_speed * delta
	squash = move_toward(squash, 0.0, delta * 1.5)
	if grounded and velocity.length() < 5.0 and absf(error) < 0.025 and absf(angular_speed) < 0.08:
		velocity = Vector2.ZERO
		tilt_angle = target_tilt
		angular_speed = 0.0
		squash = 0.0
		settled = true
	_refresh_visual()
	queue_redraw()


func get_hit_center() -> Vector2:
	return global_position + Vector2(0, -27)


func is_standing() -> bool:
	return state == State.STANDING


func is_toppled() -> bool:
	return state == State.TOPPLED


func is_carried() -> bool:
	return state == State.CARRIED


func is_settled() -> bool:
	return settled


func can_pick_up(actor: Node2D) -> bool:
	return state == State.TOPPLED and settled and not auto_stand_pending and actor.global_position.distance_to(global_position) <= pickup_radius


func pick_up(actor: Node2D) -> bool:
	if not can_pick_up(actor):
		return false
	carrier = actor
	state = State.CARRIED
	_clear_motion()
	_refresh_visual()
	state_changed.emit(state)
	return true


func can_reset(actor: Node2D) -> bool:
	return state == State.CARRIED and carrier == actor and base != null and actor.global_position.distance_to(base.global_position) <= reset_radius


func reset_at_base(actor: Node2D) -> bool:
	if not can_reset(actor):
		return false
	global_position = base.global_position
	carrier = null
	state = State.STANDING
	_clear_motion()
	tilt_angle = 0.0
	target_tilt = 0.0
	_refresh_visual()
	state_changed.emit(state)
	return true


func reset_for_preview(at: Vector2) -> void:
	# Explicit reset for scene previews, practice Reset, and match setup.
	global_position = at
	carrier = null
	state = State.STANDING
	_clear_motion()
	tilt_angle = 0.0
	target_tilt = 0.0
	_refresh_visual()
	state_changed.emit(state)


func stand_up_here() -> void:
	if state != State.TOPPLED or not settled:
		return
	if base != null:
		base.global_position = global_position
	reset_for_preview(global_position)


func drop(actor: Node2D) -> void:
	if state != State.CARRIED or carrier != actor:
		return
	global_position = actor.global_position + Vector2(26, 0)
	carrier = null
	state = State.TOPPLED
	_clear_motion()
	tilt_angle = -PI / 2.0
	target_tilt = tilt_angle
	_refresh_visual()
	state_changed.emit(state)


func topple() -> bool:
	return receive_slipper_hit(Vector2.ZERO, 0.0, get_hit_center())


func receive_slipper_hit(incoming_velocity: Vector2, charge: float, impact_point: Vector2) -> bool:
	if state != State.STANDING:
		return false
	state = State.TOPPLED
	hit_flash_remaining = 0.18
	settled = false
	auto_stand_pending = auto_stand_up
	rest_elapsed = 0.0
	var power: float = clampf(charge, 0.0, 1.0)
	if incoming_velocity.length() > 1.0:
		velocity = incoming_velocity * lerpf(0.32, 0.58, power)
		vertical_speed = lerpf(90.0, 190.0, power)
		var side: float = signf(incoming_velocity.x)
		if side == 0.0:
			side = -1.0
		target_tilt = side * PI / 2.0
		angular_speed = side * lerpf(12.0, 22.0, power) + clampf((impact_point.x - global_position.x) * 0.04, -1.5, 1.5)
	else:
		velocity = Vector2.ZERO
		vertical_speed = 0.0
		target_tilt = -PI / 2.0
		angular_speed = -4.0
	_refresh_visual()
	state_changed.emit(state)
	return true


func _clear_motion() -> void:
	velocity = Vector2.ZERO
	height = 0.0
	vertical_speed = 0.0
	angular_speed = 0.0
	squash = 0.0
	settled = true
	auto_stand_pending = false
	rest_elapsed = 0.0
	queue_redraw()


func _refresh_visual() -> void:
	can_sprite.visible = state != State.CARRIED
	body_shape.set_deferred("disabled", state == State.CARRIED)
	var half_height: float = 28.0 * absf(cos(tilt_angle)) + 21.0 * absf(sin(tilt_angle))
	can_sprite.position = Vector2(0, -half_height - height * 0.75)
	can_sprite.rotation = tilt_angle
	can_sprite.scale = Vector2(0.085 * (1.0 + squash * 0.35), 0.085 * (1.0 - squash * 0.28))
	queue_redraw()


func _draw() -> void:
	if state == State.CARRIED:
		return
	if show_target_ring:
		draw_arc(can_sprite.position, 48.0, 0, TAU, 40, Color("ffdb77"), 4.0, true)
	var alpha: float = 0.24 / (1.0 + height * 0.025)
	draw_set_transform(Vector2(7, 6), 0.0, Vector2(1.0, 0.38))
	for ring in range(6, 0, -1):
		draw_circle(Vector2.ZERO, 27.0 + ring * 2.0, Color(0.17, 0.12, 0.09, alpha / 6.0))
