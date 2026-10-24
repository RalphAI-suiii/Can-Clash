extends "res://scenes/player_movement_neutral.gd"

## Adapts each character's existing drawings to the shared thrower/Taya rules.
@export var art_kind: StringName = &"thrower"


func _ready() -> void:
	var scale_at_rest: Vector2 = sprite.scale
	var frames: SpriteFrames = _normalized_frames(sprite.sprite_frames)
	sprite.sprite_frames = frames
	attack_sprite.sprite_frames = frames
	idle_sprite_scale = scale_at_rest
	walk_scale_multiplier = 1.0
	mirror_down_left_walk = false
	mirror_up_left_walk = false
	diagonal_walk_scale = 1.0
	down_diagonal_walk_scale = 1.0
	up_diagonal_walk_scale = 1.0
	up_diagonal_lean_degrees = 0.0
	diagonal_walk_y_offset = 0.0
	sprint_cardinal_scale = 1.0
	sprint_cardinal_y_offset = 0.0
	taya_visual.configure(frames, scale_at_rest)
	super._ready()


func _normalized_frames(source: SpriteFrames) -> SpriteFrames:
	var result := SpriteFrames.new()
	if result.has_animation(&"default"):
		result.remove_animation(&"default")
	for direction in DIRECTIONS:
		var lookup: String = "right" if direction == "left" else direction
		var diagonal: bool = lookup.contains("_")
		var prefix: String = "diagonal_" if diagonal else ""
		var suffix: String = "" if art_kind == &"bullcap" else "_throw"
		var idle_source: StringName = StringName(prefix + "idle" + suffix + "_" + lookup)
		var walk_source: StringName = StringName(prefix + "walk" + suffix + "_" + lookup)
		var release_source: StringName = StringName(prefix + "throw_" + lookup)
		if art_kind == &"bullcap":
			release_source = walk_source
		_copy_frames(result, source, StringName("idle_" + direction), idle_source, true, 5.0)
		_copy_frames(result, source, StringName("walk_" + direction), walk_source, true, 8.0)
		_copy_frames(result, source, StringName("sprint_" + direction), walk_source, true, 11.0)
		_copy_frames(result, source, StringName("aim_" + direction), idle_source, true, 5.0)
		_copy_frames(result, source, StringName("throw_" + direction), release_source, false, 12.0, art_kind == &"bullcap")
		if art_kind == &"bullcap":
			_copy_frames(result, source, StringName("taya_idle_" + direction), idle_source, true, 5.0)
			_copy_frames(result, source, StringName("taya_walk_" + direction), walk_source, true, 8.0)
			_copy_frames(result, source, StringName("taya_sprint_" + direction), walk_source, true, 11.0)
		else:
			_copy_empty_hand(result, source, StringName("taya_idle_" + direction), release_source, false)
			_copy_empty_hand(result, source, StringName("taya_walk_" + direction), release_source, true)
			_copy_empty_hand(result, source, StringName("taya_sprint_" + direction), release_source, true)
	return result


func _copy_frames(target: SpriteFrames, source: SpriteFrames, name: StringName, original: StringName, looped: bool, speed: float, select_three: bool = false) -> void:
	target.add_animation(name)
	target.set_animation_loop(name, looped)
	target.set_animation_speed(name, speed)
	if not source.has_animation(original):
		push_error("Missing character animation: " + String(original))
		return
	var count: int = source.get_frame_count(original)
	if select_three and count >= 3:
		for index in [0, floori(float(count) / 3.0), floori(float(count * 2) / 3.0)]:
			target.add_frame(name, source.get_frame_texture(original, index))
	else:
		for index in range(count):
			target.add_frame(name, source.get_frame_texture(original, index), source.get_frame_duration(original, index))


func _copy_empty_hand(target: SpriteFrames, source: SpriteFrames, name: StringName, original: StringName, moving: bool) -> void:
	target.add_animation(name)
	target.set_animation_loop(name, true)
	target.set_animation_speed(name, 8.0 if moving else 1.0)
	var count: int = source.get_frame_count(original)
	if count < 3:
		push_error("No empty-hand frames in " + String(original))
		return
	if moving:
		for index in [count - 2, count - 1, count - 2, count - 1]:
			target.add_frame(name, source.get_frame_texture(original, index))
	else:
		target.add_frame(name, source.get_frame_texture(original, count - 1))


func _play(action: String, direction: Vector2) -> void:
	var empty_handed := is_taya or is_instance_valid(active_slipper)
	super._play("taya_" + action if empty_handed else action, direction)
	sprite.flip_h = DIRECTIONS[(roundi(direction.angle() / (PI / 4.0)) + 8) % 8] == "left"


func _set_attack_visual(sector: int, _releasing: bool) -> void:
	attack_sprite.scale = idle_sprite_scale
	attack_sprite.position = Vector2(0.0, idle_sprite_y)
	attack_sprite.flip_h = sector == 4
