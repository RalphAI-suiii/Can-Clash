extends Node2D

## Role actions using this character's full-body frames, keeping the feet anchored.
signal action_finished(action: StringName)

const CAN_TEXTURE: Texture2D = preload("res://assets/characters/sprites/taya/tin_can_upright.png")
const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]

var action: StringName = &""
var elapsed: float = 0.0
var walking: bool = false
var sector: int = 2
var lunge_recovery_at: float = INF
var body: AnimatedSprite2D
var carried_can: Sprite2D
var base_body_scale := Vector2.ONE
var polished_bounds: Dictionary = {}


func _ready() -> void:
	body = AnimatedSprite2D.new()
	body.position = Vector2(0, -104)
	add_child(body)
	body.frame_changed.connect(_fit_polished_pose)
	carried_can = Sprite2D.new()
	carried_can.texture = CAN_TEXTURE
	carried_can.region_enabled = true
	carried_can.region_rect = Rect2(397, 295, 486, 655)
	carried_can.scale = Vector2.ONE * 0.057
	carried_can.position = Vector2(0, -78)
	carried_can.hide()
	add_child(carried_can)


func configure(frames: SpriteFrames, size: Vector2) -> void:
	body.sprite_frames = frames
	body.scale = size
	base_body_scale = size
	_show_pose("idle")


func play_action(next_action: StringName, direction_sector: int = 2) -> void:
	action = next_action
	sector = direction_sector
	elapsed = 0.0
	lunge_recovery_at = INF
	carried_can.visible = next_action == &"place"
	show()
	_show_pose("walk" if next_action == &"lunge" else "idle")


func begin_lunge_recovery() -> void:
	if action == &"lunge" and lunge_recovery_at == INF:
		lunge_recovery_at = elapsed


func show_carry(direction_sector: int, is_walking: bool) -> void:
	if action != &"":
		return
	sector = direction_sector
	walking = is_walking
	carried_can.show()
	show()
	_show_pose("walk" if walking else "idle")


func _show_pose(prefix: String) -> void:
	if body == null or body.sprite_frames == null:
		return
	var direction: String = DIRECTIONS[sector]
	carried_can.position = Vector2(0, -78) if sector == 2 else Vector2(-38 if sector in [3, 4, 5] else 38, -80)
	var name: StringName = StringName("taya_" + prefix + "_" + direction)
	if body.animation != name or not body.is_playing():
		body.play(name)
	var texture: Texture2D = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	var drawn_left: bool = texture is AtlasTexture and "/motion_polish/" in (texture as AtlasTexture).atlas.resource_path and prefix == "idle"
	body.flip_h = direction == "left" and not drawn_left
	_fit_polished_pose()


func _fit_polished_pose(bob: float = 0.0) -> void:
	if body == null or body.sprite_frames == null:
		return
	var texture: Texture2D = body.sprite_frames.get_frame_texture(body.animation, body.frame)
	if not texture is AtlasTexture or not "/motion_polish/" in (texture as AtlasTexture).atlas.resource_path:
		body.scale = base_body_scale
		return
	var id := texture.get_instance_id()
	if not polished_bounds.has(id):
		polished_bounds[id] = texture.get_image().get_used_rect()
	var bounds: Rect2i = polished_bounds[id]
	if bounds.size.y <= 0:
		return
	var fitted_scale := 210.0 / float(bounds.size.y)
	body.scale = Vector2.ONE * fitted_scale
	body.position = Vector2(0.0, -(float(bounds.end.y) - texture.get_size().y * 0.5) * fitted_scale + bob)


func _process(delta: float) -> void:
	if not visible and action == &"":
		return
	elapsed += delta
	var visual_bob := 0.0
	if action == &"lunge":
		_show_pose("walk")
		body.speed_scale = 1.5
		body.position = Vector2(0, -104)
	elif action == &"pickup" or action == &"place":
		_show_pose("idle")
		body.speed_scale = 1.0
		visual_bob = 11.0 * sin(PI * clampf(elapsed / 0.68, 0.0, 1.0))
		body.position = Vector2(0, -104 + visual_bob)
		carried_can.visible = action == &"place" or elapsed > 0.37
	else:
		body.speed_scale = 1.0
		body.position = Vector2(0, -104)
		_show_pose("walk" if walking else "idle")
	_fit_polished_pose(visual_bob)
	var done: bool = action == &"lunge" and lunge_recovery_at < INF and elapsed >= lunge_recovery_at + 0.20
	if action != &"" and (done or (action != &"lunge" and elapsed >= 0.68)):
		var completed: StringName = action
		action = &""
		elapsed = 0.0
		action_finished.emit(completed)
