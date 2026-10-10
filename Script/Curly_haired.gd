
extends CharacterBody2D

const SPEED = 150.0
const SPRINT_SPEED = 200.0
const MAX_CHARGE_TIME = 1.5

var last_direction: Vector2 = Vector2.RIGHT
var is_charging: bool = false
var is_throwing: bool = false
var charge_time: float = 0.0

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var charge_bar: ProgressBar = $ChargeBar


func _ready() -> void:
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.value = 0.0
	charge_bar.step = 0.01
	charge_bar.hide()


func _physics_process(delta: float) -> void:
	# Wait for the throwing animation to finish.
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

		# Repeatedly fill from 0 to 1, then drain from 1 to 0.
		var cycle: float = fmod(charge_time, MAX_CHARGE_TIME * 2.0)

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

	# Start charging when the left mouse button is pressed.
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
	var direction := Input.get_vector(
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
	if velocity != Vector2.ZERO:
		play_animation("walk", last_direction)
	else:
		play_animation("idle", last_direction)


func play_animation(prefix: String, dir: Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_throw_right")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_throw_up")
	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_throw_down")


func throw_slipper() -> void:
	is_charging = false
	is_throwing = true

	charge_bar.hide()

	# Play the throwing animation in the last facing direction.
	if last_direction.x != 0:
		animated_sprite_2d.flip_h = last_direction.x < 0
		animated_sprite_2d.play("throw_right")
	elif last_direction.y < 0:
		animated_sprite_2d.play("throw_up")
	else:
		animated_sprite_2d.play("throw_down")

	# Current charge level, from 0 to 1.
	var charge_fraction: float = charge_bar.value
	print("Throw charge: ", charge_fraction)

	charge_time = 0.0
