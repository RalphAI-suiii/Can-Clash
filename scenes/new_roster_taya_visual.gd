extends "res://scenes/character_taya_visual.gd"

@export var lunge_sheet: Texture2D
@export_enum("leonardo", "kay") var art_name := "leonardo"
const CAN_ACTION_SHEETS := {
	"leonardo": preload("res://assets/characters/sprites/new_roster/leonardo/can_pickup_place.png"),
	"kay": preload("res://assets/characters/sprites/new_roster/kay/can_pickup_place.png"),
}

const LUNGE_ROWS := ["right", "down_right", "down", "up_right", "up"]
const LUNGE_FOOT_OFFSETS := {
	"leonardo": [[122, 124, 123, 125], [122, 118, 115, 117], [87, 92, 91, 87], [74, 75, 74, 78], [57, 61, 59, 60]],
	"kay": [[107, 107, 107, 107], [95, 95, 95, 95], [81, 81, 81, 81], [74, 72, 74, 73], [63, 64, 62, 63]],
}
const SECTOR_TO_ROW := [0, 1, 2, 1, 0, 3, 4, 3]


func configure(frames: SpriteFrames, size: Vector2) -> void:
	var complete := frames.duplicate(true)
	var can_sheet: Texture2D = CAN_ACTION_SHEETS[art_name]
	var row_regions := [Rect2(0, 0, can_sheet.get_width(), 438), Rect2(0, 440, can_sheet.get_width(), 440)] if art_name == "leonardo" else [Rect2(0, 0, can_sheet.get_width(), 446), Rect2(0, 446, can_sheet.get_width(), 441)]
	for row in range(2):
		var animation := StringName("can_pickup" if row == 0 else "can_place")
		complete.add_animation(animation)
		complete.set_animation_loop(animation, false)
		complete.set_animation_speed(animation, 12.0)
		for column in range(4):
			var cell := AtlasTexture.new()
			cell.atlas = can_sheet
			cell.region = Rect2(column * can_sheet.get_width() / 4.0, row_regions[row].position.y, can_sheet.get_width() / 4.0, row_regions[row].size.y)
			cell.filter_clip = true
			complete.add_frame(animation, cell)
	if lunge_sheet != null:
		var cell := Vector2(lunge_sheet.get_width() / 4.0, lunge_sheet.get_height() / 5.0)
		for row in range(LUNGE_ROWS.size()):
			var name := StringName("lunge_" + LUNGE_ROWS[row])
			complete.add_animation(name)
			complete.set_animation_loop(name, false)
			complete.set_animation_speed(name, 12.0)
			for column in range(4):
				var texture := AtlasTexture.new()
				texture.atlas = lunge_sheet
				texture.region = Rect2(Vector2(column, row) * cell, cell)
				texture.filter_clip = true
				complete.add_frame(name, texture)
	super.configure(complete, size)


func play_action(next_action: StringName, direction_sector: int = 2) -> void:
	super.play_action(next_action, direction_sector)
	if next_action == &"lunge":
		body.frame = 0
		body.play()


func _show_pose(prefix: String) -> void:
	if action == &"pickup" or action == &"place":
		var can_animation := &"can_pickup" if action == &"pickup" else &"can_place"
		if body.animation != can_animation:
			body.play(can_animation)
		body.flip_h = false
		body.scale = Vector2.ONE * 0.46
		return
	if action == &"lunge" and lunge_sheet != null:
		var direction: String = DIRECTIONS[sector]
		var lookup: String = "right" if direction == "left" else "down_right" if direction == "down_left" else "up_right" if direction == "up_left" else direction
		var name := StringName("lunge_" + lookup)
		body.flip_h = direction in ["left", "down_left", "up_left"]
		if body.animation != name:
			body.play(name)
		body.scale = Vector2.ONE * 1.1
		return
	super._show_pose(prefix)
	body.flip_h = DIRECTIONS[sector] == "down_left" and prefix != "idle"
	body.scale = Vector2.ONE * ((0.72 if art_name == "leonardo" else 0.68) if prefix == "idle" else 0.75)


func _process(delta: float) -> void:
	super._process(delta)
	if action == &"pickup" or action == &"place":
		carried_can.hide()
	if action == &"lunge":
		var row: int = SECTOR_TO_ROW[sector]
		var frame: int = mini(body.frame, 3)
		body.position.y = -float(LUNGE_FOOT_OFFSETS[art_name][row][frame])
