extends CharacterBody2D

## Reusable eight-direction movement. The scene origin is at the character's feet.
@export var walk_speed: float = 150.0
@export var sprint_speed: float = 200.0
@export var acceleration: float = 850.0
@export var stopping_friction: float = 1050.0
@export var idle_sprite_y: float = -87.0
@export var walk_sprite_y: float = -87.0

const DIRECTIONS: Array[String] = [
	"right", "down_right", "down", "down_left",
	"left", "up_left", "up", "up_right",
]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	# Center the character when running this scene directly; keep its origin for level instances.
	if get_parent() == get_tree().root:
		global_position = get_viewport_rect().size * 0.5
	_play("idle", facing)


func _physics_process(delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector("left", "right", "up", "down")
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity: Vector2 = input_direction * speed
	var change_rate: float = acceleration if input_direction != Vector2.ZERO else stopping_friction

	velocity = velocity.move_toward(target_velocity, change_rate * delta)
	move_and_slide()

	if input_direction != Vector2.ZERO:
		facing = input_direction

	if velocity.length_squared() > 12.0 * 12.0:
		_play("walk", facing)
		sprite.speed_scale = clampf(velocity.length() / walk_speed, 0.65, 1.35)
	else:
		_play("idle", facing)
		sprite.speed_scale = 1.0


func _play(action: String, direction: Vector2) -> void:
	var sector: int = (roundi(direction.angle() / (PI / 4.0)) + 8) % 8
	var animation_name: StringName = StringName(action + "_" + DIRECTIONS[sector])
	var visual_y: float = idle_sprite_y if action == "idle" else walk_sprite_y
	sprite.position = Vector2(sprite.position.x, visual_y)
	if sprite.animation != animation_name or not sprite.is_playing():
		var keep_step: bool = action == "walk" and String(sprite.animation).begins_with("walk_")
		var step_frame: int = sprite.frame
		var step_progress: float = sprite.frame_progress
		sprite.play(animation_name)
		if keep_step:
			sprite.set_frame_and_progress(step_frame, step_progress)
