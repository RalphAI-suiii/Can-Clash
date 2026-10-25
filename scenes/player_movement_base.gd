extends CharacterBody2D

## Reusable eight-direction movement. The scene origin is at the character's feet.
@export var walk_speed: float = 100.0
@export var sprint_speed: float = 150.0
@export var acceleration: float = 850.0
@export var stopping_friction: float = 1050.0
@export var idle_sprite_y: float = -87.0
@export var walk_sprite_y: float = -87.0
@export var walk_scale_multiplier: float = 1.0
@export var mirror_down_left_walk: bool = false
@export var mirror_up_left_walk: bool = false
@export var diagonal_walk_scale: float = 1.0
@export var down_diagonal_walk_scale: float = 1.0
@export var up_diagonal_walk_scale: float = 1.0
@export var up_diagonal_lean_degrees: float = 0.0
@export var diagonal_walk_y_offset: float = 0.0
@export var sprint_cardinal_scale: float = 1.0
@export var sprint_cardinal_y_offset: float = 0.0

const DIRECTIONS: Array[String] = [
	"right", "down_right", "down", "down_left",
	"left", "up_left", "up", "up_right",
]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var idle_sprite_scale: Vector2 = sprite.scale

var facing: Vector2 = Vector2.DOWN
var network_controlled := false
var network_input: Dictionary = {}
var network_edges: Dictionary = {}
var movement_min_x := -INF
var movement_locked := false


func apply_network_input(packet: Dictionary) -> void:
	for action in ["interact", "lunge"]:
		if packet.get(action, false) and not network_input.get(action, false):
			network_edges[action] = true
	network_input = packet


func _action_pressed(action: String) -> bool:
	return bool(network_input.get(action, false)) if network_controlled else Input.is_action_pressed(action)


func _action_just_pressed(action: String) -> bool:
	if network_controlled:
		return network_edges.erase(action)
	return Input.is_action_just_pressed(action)


func _movement_input() -> Vector2:
	if movement_locked:
		return Vector2.ZERO
	return network_input.get("move", Vector2.ZERO) if network_controlled else Input.get_vector("left", "right", "up", "down")


func _throw_pressed() -> bool:
	return bool(network_input.get("throw", false)) if network_controlled else Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and get_viewport().gui_get_hovered_control() == null


func _aim_position() -> Vector2:
	return network_input.get("aim", global_position + facing * 300.0) if network_controlled else get_global_mouse_position()


func _ready() -> void:
	# Center the character when running this scene directly; keep its origin for level instances.
	if get_parent() == get_tree().root:
		global_position = get_viewport_rect().size * 0.5
	_play("idle", facing)


func _physics_process(delta: float) -> void:
	move_from_input(delta, _movement_input(), _action_pressed("sprint"))


func move_from_input(delta: float, input_direction: Vector2, sprinting: bool, animate: bool = true, explicit_delta: bool = false) -> void:
	var speed: float = sprint_speed if sprinting else walk_speed
	var target_velocity: Vector2 = input_direction * speed
	var change_rate: float = acceleration if input_direction != Vector2.ZERO else stopping_friction

	velocity = velocity.move_toward(target_velocity, change_rate * delta)
	if explicit_delta: _move_character_delta(delta)
	else: _move_character()

	if input_direction != Vector2.ZERO:
		facing = input_direction

	if not animate: return
	if velocity.length_squared() > 12.0 * 12.0:
		var sprint_animation: bool = sprinting and sprite.sprite_frames.has_animation("sprint_down")
		_play("sprint" if sprint_animation else "walk", facing)
		sprite.speed_scale = clampf(velocity.length() / 150.0, 0.45, 1.35)
	else:
		_play("idle", facing)
		sprite.speed_scale = 1.0


func _play(action: String, direction: Vector2) -> void:
	var sector: int = (roundi(direction.angle() / (PI / 4.0)) + 8) % 8
	var moving: bool = action == "walk" or action == "sprint"
	var mirror_down_left: bool = mirror_down_left_walk and moving and DIRECTIONS[sector] == "down_left"
	var mirror_up_left: bool = mirror_up_left_walk and moving and DIRECTIONS[sector] == "up_left"
	var mirror_sprint_left: bool = action == "sprint" and DIRECTIONS[sector] == "left"
	var direction_name: String = DIRECTIONS[sector]
	if mirror_down_left:
		direction_name = "down_right"
	elif mirror_up_left:
		direction_name = "up_right"
	elif mirror_sprint_left:
		direction_name = "right"
	var animation_name: StringName = StringName(action + "_" + direction_name)
	var visual_y: float = idle_sprite_y if action == "idle" else walk_sprite_y
	if moving and sector % 2 == 1:
		visual_y += diagonal_walk_y_offset
	elif action == "sprint":
		visual_y += sprint_cardinal_y_offset
	sprite.flip_h = mirror_down_left or mirror_up_left or mirror_sprint_left
	var visual_scale: float = walk_scale_multiplier if moving else 1.0
	if moving and sector % 2 == 1:
		visual_scale *= diagonal_walk_scale
		var direction_scale: float = down_diagonal_walk_scale if sector == 1 or sector == 3 else up_diagonal_walk_scale
		visual_scale *= direction_scale
	elif action == "sprint":
		visual_scale *= sprint_cardinal_scale
	sprite.scale = idle_sprite_scale * visual_scale
	var lean: float = 0.0
	if moving and (sector == 5 or sector == 7):
		var lean_degrees: float = up_diagonal_lean_degrees + (3.0 if action == "sprint" else 0.0)
		lean = deg_to_rad(lean_degrees) * (-1.0 if sector == 5 else 1.0)
	sprite.rotation = lean
	# Compensate for center-based rotation so the feet stay at the same world position.
	sprite.position = Vector2(sin(lean) * sprite.scale.y * 150.0, visual_y)
	if sprite.animation != animation_name or not sprite.is_playing():
		var previous_motion: bool = String(sprite.animation).begins_with("walk_") or String(sprite.animation).begins_with("sprint_")
		var keep_step: bool = moving and previous_motion
		var step_frame: int = sprite.frame
		var step_progress: float = sprite.frame_progress
		sprite.play(animation_name)
		if keep_step:
			sprite.set_frame_and_progress(step_frame, step_progress)


func _move_character() -> void:
	if is_finite(movement_min_x):
		var step := maxf(get_physics_process_delta_time(), 0.001)
		velocity.x = maxf(velocity.x, (movement_min_x - global_position.x) / step)
	move_and_slide()
	global_position.x = maxf(global_position.x, movement_min_x)


func _move_character_delta(delta: float) -> void:
	# Replaying input outside a physics callback must use its recorded timestep.
	var step := maxf(delta, 0.001)
	if is_finite(movement_min_x):
		velocity.x = maxf(velocity.x, (movement_min_x - global_position.x) / step)
	var motion := velocity * step
	for slide in range(4):
		var collision := move_and_collide(motion)
		if collision == null: break
		motion = collision.get_remainder().slide(collision.get_normal())
		velocity = velocity.slide(collision.get_normal())
	global_position.x = maxf(global_position.x, movement_min_x)
