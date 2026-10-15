extends Node2D

# Each character stays in one piece; the shader fades motion out before the legs.
@export_enum("hat", "band", "glasses") var character_kind: String = "hat"
@export var sway_offset: float = 0.0

const HAT_FRAMES: SpriteFrames = preload("res://ui/main_menu/menu_idle_hat_gesture.tres")
const BAND_FRAMES: SpriteFrames = preload("res://ui/main_menu/menu_idle_band_gesture.tres")
const GLASSES_FRAMES: SpriteFrames = preload("res://ui/main_menu/menu_idle_glasses_gesture.tres")
const ANCHORED_SWAY: Shader = preload("res://ui/main_menu/menu_anchored_sway.gdshader")


func _ready() -> void:
	var sprite := Sprite2D.new()
	var frame: AtlasTexture
	match character_kind:
		"hat":
			frame = HAT_FRAMES.get_frame_texture("idle", 0) as AtlasTexture
			sprite.position.y = -142.0
		"band":
			frame = BAND_FRAMES.get_frame_texture("idle", 0) as AtlasTexture
			sprite.position.y = -156.0
		_:
			frame = GLASSES_FRAMES.get_frame_texture("idle", 0) as AtlasTexture
			sprite.position.y = -150.0
	sprite.texture = frame.atlas
	sprite.region_enabled = true
	sprite.region_rect = frame.region
	var material := ShaderMaterial.new()
	material.shader = ANCHORED_SWAY
	material.set_shader_parameter("phase", sway_offset)
	sprite.material = material
	add_child(sprite)
