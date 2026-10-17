extends "res://scenes/player_movement_base.gd"

@export var charge_duration: float = 2.5

const SLIPPER_VISUAL = preload("res://scenes/slipper_visual.gd")
const ATTACK_SCALES: Array[float] = [0.92, 0.80, 0.86, 0.80, 0.88, 0.86, 0.94, 0.89]

enum AttackState { FREE, CHARGING, THROWING }

@onready var attack_sprite: AnimatedSprite2D = $AttackSprite
@onready var charge_bar: ProgressBar = $ChargeBar

var attack_state: int = AttackState.FREE
var attack_direction: Vector2 = Vector2.DOWN
var charge_elapsed: float = 0.0
var charge_ratio: float = 0.0
var slipper_spawned: bool = false


func _ready() -> void:
	super._ready()
	attack_sprite.animation_finished.connect(_on_attack_finished)
	attack_sprite.frame_changed.connect(_on_attack_frame_changed)
	attack_sprite.hide()
	charge_bar.hide()


func _physics_process(delta: float) -> void:
	if attack_state == AttackState.FREE:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_charge()
		else:
			super._physics_process(delta)
	elif attack_state == AttackState.CHARGING:
		_update_cursor_aim()
		charge_elapsed = minf(charge_elapsed + delta, charge_duration)
		charge_bar.value = charge_elapsed / maxf(charge_duration, 0.01)
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_start_throw()


func _start_charge() -> void:
	attack_state = AttackState.CHARGING
	velocity = Vector2.ZERO
	charge_elapsed = 0.0
	charge_bar.value = 0.0
	charge_bar.show()
	_update_cursor_aim()
	sprite.hide()
	attack_sprite.show()
	attack_sprite.play(StringName("aim_" + _attack_direction_name()))


func _start_throw() -> void:
	charge_ratio = charge_bar.value
	charge_bar.hide()
	attack_state = AttackState.THROWING
	slipper_spawned = false
	attack_sprite.play(StringName("throw_" + _attack_direction_name()))


func _attack_direction_name() -> String:
	return DIRECTIONS[_attack_sector()]


func _attack_sector() -> int:
	return (roundi(attack_direction.angle() / (PI / 4.0)) + 8) % 8


func _update_cursor_aim() -> void:
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length_squared() <= 0.01:
		return
	var previous_sector: int = _attack_sector()
	var sector: int = (roundi(aim.angle() / (PI / 4.0)) + 8) % 8
	attack_direction = Vector2.RIGHT.rotated(sector * PI / 4.0)
	facing = attack_direction
	var attack_scale: float = ATTACK_SCALES[sector]
	attack_sprite.scale = Vector2.ONE * attack_scale
	attack_sprite.position = Vector2(0, -120.5 * attack_scale)
	if attack_sprite.visible and sector != previous_sector:
		var frame: int = attack_sprite.frame
		var progress: float = attack_sprite.frame_progress
		attack_sprite.play(StringName("aim_" + DIRECTIONS[sector]))
		attack_sprite.set_frame_and_progress(frame, progress)


func _on_attack_frame_changed() -> void:
	if attack_state != AttackState.THROWING or attack_sprite.frame < 2 or slipper_spawned:
		return
	slipper_spawned = true
	var slipper = SLIPPER_VISUAL.new()
	get_parent().add_child(slipper)
	slipper.global_position = global_position + Vector2(0, -103) + attack_direction * 48.0
	slipper.direction = attack_direction
	slipper.speed = lerpf(250.0, 430.0, charge_ratio)


func _on_attack_finished() -> void:
	if attack_state != AttackState.THROWING:
		return
	attack_state = AttackState.FREE
	attack_sprite.hide()
	sprite.show()
	sprite.speed_scale = 1.0
	_play("idle", facing)
