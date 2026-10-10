
extends CharacterBody2D

const SPEED: float = 150.0
const SPRINT_SPEED: float = 200.0
const MAX_CHARGE_TIME: float = 1.5

var last_direction: Vector2 = Vector2.RIGHT
var is_charging: bool = false
var is_throwing: bool = false
var charge_time: float = 0.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var charge_bar: ProgressBar = $ChargeBar


func _ready() -> void:
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.step = 0.01
	charge_bar.value = 0.0
	charge_bar.hide()


func _physics_process(delta: float) -> void:
	# Keep the player still while throwing.
	if is_throwing:
		velocity = Vector2.ZERO

		if not animated_sprite_2d.is_playing():
			is_throwing = false
			process_animation()

		move_and_slide()
		return

	# Charge while holding the left mouse button.
	if is_charging:
		velocity = Vector2.ZERO
		charge_time += delta

		# Cycle from 0 to 1 and back to 0.
		var cycle: float = fmod(
			charge_time,
			MAX_CHARGE_TIME * 2.0
		)

		if cycle <= MAX_CHARGE_TIME:
			charge_bar.value = cycle / MAX_CHARGE_TIME
		else:
			charge_bar.value = 1.0 - (
				(cycle - MAX_CHARGE_TIME) / MAX_CHARGE_TIME
			)

		# Release the mouse button to throw.
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			throw_slipper()

		move_and_slide()
		return

	# Begin charging on left-click.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_charging = true
		charge_time = 0.0
		charge_bar.value = 0.0
		charge_bar.show()

		velocity = Vector2.ZERO
		move_and_slide()
		return

	process_movement()
	process_animation()
	move_and_slide()


func process_movement() -> void:
	var direction: Vector2 = Input.get_vector(
		"left", "right", "up", "down"
	)

	var current_speed: float = SPEED

	if Input.is_action_pressed("sprint"):
		current_speed = SPRINT_SPEED

	if direction != Vector2.ZERO:
		velocity = direction * current_speed
		last_direction = direction
	else:
		velocity = Vector2.ZERO


func process_animation() -> void:
	var direction: Vector2 = Input.get_vector(
		"left", "right", "up", "down"
	)

	if direction == Vector2.ZERO:
		play_animation("idle", last_direction)
	else:
		last_direction = direction
		play_animation("walk", direction)


func play_animation(prefix: String, dir: Vector2) -> void:
	var animation_name: String = ""

	# Diagonal animations.
	if dir.x < 0 and dir.y < 0:
		animation_name = "diagonal_" + prefix + "_throw_up_left"
	elif dir.x > 0 and dir.y < 0:
		animation_name = "diagonal_" + prefix + "_throw_up_right"
	elif dir.x < 0 and dir.y > 0:
		animation_name = "diagonal_" + prefix + "_throw_down_left"
	elif dir.x > 0 and dir.y > 0:
		animation_name = "diagonal_" + prefix + "_throw_down_right"

	# Horizontal animations.
	elif dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animation_name = prefix + "_throw_right"

	# Vertical animations.
	elif dir.y < 0:
		animation_name = prefix + "_throw_up"
	elif dir.y > 0:
		animation_name = prefix + "_throw_down"

	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)
	else:
		print("Missing animation: ", animation_name)


func throw_slipper() -> void:
	is_charging = false
	is_throwing = true

	# Save the charge amount before hiding the bar.
	var final_charge: float = charge_bar.value
	print("Final charge: ", final_charge)

	charge_bar.hide()

	var animation_name: String = ""

	# Diagonal throwing animations.
	if last_direction.x < 0 and last_direction.y < 0:
		animation_name = "diagonal_throw_up_left"
	elif last_direction.x > 0 and last_direction.y < 0:
		animation_name = "diagonal_throw_up_right"
	elif last_direction.x < 0 and last_direction.y > 0:
		animation_name = "diagonal_throw_down_left"
	elif last_direction.x > 0 and last_direction.y > 0:
		animation_name = "diagonal_throw_down_right"

	# Straight throwing animations.
	elif last_direction.x != 0:
		animated_sprite_2d.flip_h = last_direction.x < 0
		animation_name = "throw_right"
	elif last_direction.y < 0:
		animation_name = "throw_up"
	else:
		animation_name = "throw_down"

	if animated_sprite_2d.sprite_frames.has_animation(animation_name):
		animated_sprite_2d.play(animation_name)
	else:
		print("Missing throwing animation: ", animation_name)
		is_throwing = false
		process_animation()

	charge_time = 0.0
