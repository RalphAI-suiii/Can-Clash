extends Node2D

## Hat Thrower artwork for the can interaction. The origin is the planted feet.
signal action_finished(action: StringName)

const LIFT_PLACE: Texture2D = preload("res://assets/characters/sprites/taya/hat_thrower_can_lift_place.png")
const CARRY_CARDINAL: Texture2D = preload("res://assets/characters/sprites/taya/hat_thrower_carry_cardinal.png")
const CARRY_TURNS: Texture2D = preload("res://assets/characters/sprites/taya/hat_thrower_carry_turns.png")
const CARRY_BACK: Texture2D = preload("res://assets/characters/sprites/taya/hat_thrower_carry_back.png")
const LUNGE_SHEETS: Array[Texture2D] = [
	preload("res://assets/characters/sprites/taya/hat_thrower_lunge_right_4.png"),
	preload("res://assets/characters/sprites/taya/hat_thrower_lunge_down_right_4.png"),
	preload("res://assets/characters/sprites/taya/hat_thrower_lunge_down_4.png"),
	preload("res://assets/characters/sprites/taya/hat_thrower_lunge_up_right_4.png"),
	preload("res://assets/characters/sprites/taya/hat_thrower_lunge_up_4.png"),
]
# Four connected full-body drawings per sheet: wind-up, first step, reach, recovery.
# These regions include a six-pixel transparent margin and never include a neighbor.
const LUNGE_REGIONS: Array[Rect2] = [
	Rect2(158, 78, 452, 428), Rect2(846, 66, 472, 440), Rect2(122, 606, 624, 420), Rect2(938, 590, 392, 440),
	Rect2(190, 66, 448, 404), Rect2(914, 70, 436, 412), Rect2(122, 558, 640, 400), Rect2(906, 554, 460, 404),
	Rect2(142, 74, 436, 440), Rect2(766, 70, 436, 488), Rect2(134, 626, 480, 484), Rect2(722, 646, 476, 456),
	Rect2(222, 38, 392, 420), Rect2(898, 38, 488, 432), Rect2(214, 530, 516, 448), Rect2(890, 554, 460, 416),
	Rect2(274, 74, 364, 368), Rect2(894, 58, 348, 428), Rect2(266, 506, 384, 460), Rect2(922, 534, 300, 420),
]
const LUNGE_HEIGHTS: Array[float] = [184.0, 192.0, 200.0, 188.0]
const LUNGE_SHEET_FOR_SECTOR: Array[int] = [0, 1, 2, 1, 0, 3, 4, 3]

const ACTION_FEET := [471, 482, 480, 471, 416, 416, 426, 423]
const CARDINAL_FEET := [475, 473, 482, 477, 425, 434, 448, 453]
const TURN_FEET := [487, 480, 487, 494, 454, 451, 442, 461]
const BACK_FEET := [641, 646, 646, 645]

var action: StringName = &""
var elapsed: float = 0.0
var walking: bool = false
var sector: int = 2
var lunge_recovery_at: float = INF


func play_action(next_action: StringName, direction_sector: int = 2) -> void:
	action = next_action
	sector = direction_sector
	elapsed = 0.0
	lunge_recovery_at = INF
	show()
	queue_redraw()


func begin_lunge_recovery() -> void:
	if action == &"lunge" and lunge_recovery_at == INF:
		lunge_recovery_at = elapsed
		queue_redraw()


func show_carry(direction_sector: int, is_walking: bool) -> void:
	if action != &"":
		return
	sector = direction_sector
	walking = is_walking
	show()
	queue_redraw()


func _process(delta: float) -> void:
	if not visible and action == &"":
		return
	elapsed += delta
	var lunge_done: bool = action == &"lunge" and lunge_recovery_at < INF and elapsed >= lunge_recovery_at + 0.20
	if action != &"" and (lunge_done or (action != &"lunge" and elapsed >= 0.68)):
		var completed: StringName = action
		action = &""
		elapsed = 0.0
		action_finished.emit(completed)
	queue_redraw()


func _draw() -> void:
	if action == &"lunge":
		_draw_lunge()
		return
	if action == &"pickup" or action == &"place":
		var frame: int = mini(int(elapsed / 0.17), 3)
		if action == &"place":
			frame += 4
		_draw_cell(LIFT_PLACE, 384, 512, frame, ACTION_FEET[frame], 192.0, 0.50)
		return

	var step: int = int(elapsed * 6.0) % 2 if walking else 0
	var mirror: bool = sector == 3 or sector == 4 or sector == 5
	var drawing: Texture2D = CARRY_CARDINAL
	var index: int = 0
	if sector == 2:
		drawing = CARRY_TURNS if walking else CARRY_CARDINAL
		index = 3 + step * 4 if walking else 0
	elif sector == 0 or sector == 4:
		drawing = CARRY_TURNS if walking else CARRY_CARDINAL
		index = 2 if walking else 2
		if walking and step == 1:
			drawing = CARRY_CARDINAL
			index = 3
	elif sector == 6:
		drawing = CARRY_BACK
		index = (1 + int(elapsed * 7.0) % 3) if walking else 0
	elif sector == 1 or sector == 3:
		drawing = (CARRY_TURNS if step == 0 else CARRY_CARDINAL) if walking else CARRY_CARDINAL
		index = (0 if step == 0 else 7) if walking else 7
	else:
		drawing = (CARRY_TURNS if step == 0 else CARRY_CARDINAL) if walking else CARRY_CARDINAL
		index = (1 if step == 0 else 6) if walking else 6

	if mirror:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	if drawing == CARRY_BACK:
		_draw_cell(drawing, 543, 724, index, BACK_FEET[index], 271.5, 0.34)
	else:
		var feet: int = TURN_FEET[index] if drawing == CARRY_TURNS else CARDINAL_FEET[index]
		_draw_cell(drawing, 384, 512, index, feet, 192.0, 0.48)
	if mirror:
		draw_set_transform(Vector2.ZERO)


func _draw_cell(texture: Texture2D, width: int, height: int, index: int, feet: int, center_x: float, size: float) -> void:
	var columns: int = int(texture.get_width() / width)
	var source := Rect2((index % columns) * width, floori(float(index) / columns) * height, width, height)
	var destination := Rect2(-center_x * size, -feet * size, width * size, height * size)
	draw_texture_rect_region(texture, destination, source)


func _draw_lunge() -> void:
	var sheet_index: int = LUNGE_SHEET_FOR_SECTOR[sector]
	var frame: int = 0
	if lunge_recovery_at < INF:
		frame = 3
	elif elapsed >= 0.22:
		frame = 2
	elif elapsed >= 0.13:
		frame = 1
	var source: Rect2 = LUNGE_REGIONS[sheet_index * 4 + frame]
	var size: float = LUNGE_HEIGHTS[frame] / (source.size.y - 12.0)
	var destination := Rect2(
		-source.size.x * size * 0.5,
		-(source.size.y - 6.0) * size,
		source.size.x * size,
		source.size.y * size
	)
	var mirror: bool = sector == 3 or sector == 4 or sector == 5
	if mirror:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	draw_texture_rect_region(LUNGE_SHEETS[sheet_index], destination, source)
	if mirror:
		draw_set_transform(Vector2.ZERO)
