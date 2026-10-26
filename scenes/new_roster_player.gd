extends "res://scenes/player_movement_neutral.gd"

## Leonardo and Kay use the same host-owned rules as the original roster.
## Their directional art is kept in separate atlases so every action retains
## the character's own head, outfit, and foot placement.
@export_enum("leonardo", "kay") var art_name := "leonardo"

const ROW_TOPS := {
	"leonardo": {
		"walk_cardinal": [36, 363, 682, 995],
		"walk_cardinal_inbetween": [42, 364, 686, 996],
		"walk_diagonal": [19, 351, 673, 1000],
		"walk_diagonal_inbetween": [22, 350, 676, 1001],
		"sprint_cardinal": [22, 350, 669, 1000],
		"sprint_cardinal_inbetween": [25, 350, 672, 996],
		"sprint_diagonal": [16, 347, 675, 1010],
		"sprint_diagonal_inbetween": [19, 351, 678, 1011],
		"throw_cardinal": [36, 369, 695, 1005],
		"throw_diagonal": [61, 382, 700, 1013],
	},
	"kay": {
		"walk_cardinal": [8, 331, 656, 979],
		"walk_cardinal_inbetween": [19, 336, 658, 983],
		"walk_diagonal": [20, 345, 660, 977],
		"walk_diagonal_inbetween": [29, 347, 661, 977],
		"sprint_cardinal": [26, 355, 689, 1015],
		"sprint_cardinal_inbetween": [36, 362, 700, 1020],
		"sprint_diagonal": [44, 372, 699, 1019],
		"sprint_diagonal_inbetween": [49, 376, 694, 1000],
		"throw_cardinal": [62, 374, 688, 1005],
		"throw_diagonal": [25, 356, 683, 1003],
	},
}
const IDLE_ROWS := {
	"leonardo": {"cardinal": [30, 340, 645, 930], "diagonal": [0, 300, 605, 910]},
	"kay": {"cardinal": [5, 310, 615, 920], "diagonal": [5, 300, 595, 890]},
}
const IDLE_HEIGHT := {
	"leonardo": {"cardinal": 300, "diagonal": 300},
	"kay": {"cardinal": 305, "diagonal": 295},
}
const CARDINAL := ["down", "left", "up", "right"]
const DIAGONAL := ["down_right", "up_left", "up_right", "down_left"]
var previous_carry_visual := false
var can_transition_until := 0.0


func _process(delta: float) -> void:
	super._process(delta)
	if not is_taya:
		previous_carry_visual = false
		can_transition_until = 0.0
		return
	if is_taya and carrying_can != previous_carry_visual:
		previous_carry_visual = carrying_can
		taya_visual.play_action(&"pickup" if carrying_can else &"place", 2)
		can_transition_until = LanSession.clock_time() + 0.34
	if can_transition_until > LanSession.clock_time() and is_taya and not is_stunned() and not taya_stun_aiming and taya_action == &"":
		sprite.hide()
		attack_sprite.hide()
		taya_visual.show()
	elif can_transition_until > 0.0:
		can_transition_until = 0.0
		if taya_visual.action == &"pickup" or taya_visual.action == &"place":
			taya_visual.action = &""
			taya_visual.hide()
			sprite.show()
func _ready() -> void:
	var frames := _character_frames()
	sprite.sprite_frames = frames
	attack_sprite.sprite_frames = frames
	idle_sprite_scale = Vector2.ONE * (0.72 if art_name == "leonardo" else 0.68)
	walk_scale_multiplier = 0.75 / idle_sprite_scale.x
	mirror_down_left_walk = false
	mirror_up_left_walk = false
	diagonal_walk_scale = 1.0
	down_diagonal_walk_scale = 1.0
	up_diagonal_walk_scale = 1.0
	up_diagonal_lean_degrees = 0.0
	sprint_cardinal_scale = 1.0
	taya_visual.configure(frames, idle_sprite_scale)
	super._ready()


func has_thrower_special() -> bool:
	return false


func _character_frames() -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var path := "res://assets/characters/sprites/new_roster/%s/" % art_name
	for direction in DIRECTIONS:
		var diagonal := direction.contains("_")
		# The front diagonal atlas's leftward art is inconsistent. Mirror its
		# reliable right-facing action row so head, body, and throwing hand agree.
		var source_direction := "down_right" if direction == "down_left" else direction
		var row: int = (DIAGONAL if diagonal else CARDINAL).find(source_direction)
		var suffix := "diagonal" if diagonal else "cardinal"
		var idle_sheet := load(path + "idle_" + suffix + ".png") as Texture2D
		var idle_row: int = (DIAGONAL if diagonal else CARDINAL).find(direction)
		var idle_cells: Array[Texture2D] = []
		for column in range(4):
			idle_cells.append(_idle_action_cell(idle_sheet, column, int(IDLE_ROWS[art_name][suffix][idle_row]), int(IDLE_HEIGHT[art_name][suffix])))
		_add(result, "idle_" + direction, idle_cells, true, 3.0)
		for action in ["walk", "sprint", "throw"]:
			var key: String = action + "_" + suffix
			var sheet := load(path + key + ".png") as Texture2D
			var inbetween_sheet := load(path + key + "_inbetween.png") as Texture2D if action != "throw" else null
			var cells: Array[Texture2D] = []
			for column in range(4):
				cells.append(_action_cell(sheet, column, int(ROW_TOPS[art_name][key][row])))
				if inbetween_sheet != null:
					cells.append(_action_cell(inbetween_sheet, column, int(ROW_TOPS[art_name][key + "_inbetween"][row])))
			_add(result, action + "_" + direction, cells, action != "throw", 8.0 if action == "walk" else 11.0 if action == "sprint" else 12.0)
		var throw_name := StringName("throw_" + direction)
		if result.has_animation(throw_name):
			var aim_cells: Array[Texture2D] = [result.get_frame_texture(throw_name, 0)]
			_add(result, "aim_" + direction, aim_cells, true, 1.0)
		for action in ["idle", "walk", "sprint"]:
			var source := StringName(action + "_" + direction)
			var copies: Array[Texture2D] = []
			for frame in range(result.get_frame_count(source)):
				copies.append(result.get_frame_texture(source, frame))
			_add(result, "taya_" + action + "_" + direction, copies, true, result.get_animation_speed(source))
	return result


func _add(frames: SpriteFrames, name: String, cells: Array[Texture2D], looped: bool, speed: float) -> void:
	var animation := StringName(name)
	frames.add_animation(animation)
	frames.set_animation_loop(animation, looped)
	frames.set_animation_speed(animation, speed)
	for cell in cells:
		frames.add_frame(animation, cell)


func _idle_action_cell(sheet: Texture2D, column: int, top: int, height: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(column * sheet.get_width() / 4.0, top, sheet.get_width() / 4.0, height)
	atlas.filter_clip = true
	return atlas


func _action_cell(sheet: Texture2D, column: int, top: int) -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = Rect2(column * sheet.get_width() / 4.0, top, sheet.get_width() / 4.0, 320)
	atlas.filter_clip = true
	return atlas


func _play(action: String, direction: Vector2) -> void:
	super._play(action, direction)
	var sector := (roundi(direction.angle() / (PI / 4.0)) + 8) % 8
	# Down-left mirrors one clean right-facing pose; the other directions use
	# their own authored head and body orientation.
	sprite.flip_h = sector == 3 and action != "idle"
	if action == "sprint" and DIRECTIONS[sector] == "left":
		var name := _movement_animation(action, "left")
		if sprite.animation != name:
			var previous_frame := sprite.frame
			sprite.play(name)
			sprite.frame = mini(previous_frame, sprite.sprite_frames.get_frame_count(name) - 1)
	if art_name == "kay" and action == "sprint" and sector % 2 == 1:
		sprite.scale *= 1.18
		sprite.position.y = -107.0
	if action == "sprint":
		sprite.scale *= 0.93


func _set_attack_visual(_sector: int, _releasing: bool) -> void:
	attack_sprite.scale = Vector2.ONE
	attack_sprite.position = Vector2(0, -92)
	attack_sprite.flip_h = _sector == 3
