extends Control

@export var row_height: float = 44.0
@export var panel_width: float = 280.0

@onready var player_list: VBoxContainer = $PanelContainer/VBoxContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/title_label

var players: Array[Dictionary] = []
var player_rows: Dictionary = {}

const ROW_COLORS: Array[Color] = [
	Color("#ffdf78"), Color("#d9edf2"), Color("#f0b18d"),
	Color("#fff4dc"), Color("#fff4dc"),
]


func _ready() -> void:
	title_label.text = "READY UP!"
	player_list.add_theme_constant_override("separation", 5)
	$PanelContainer.custom_minimum_size.x = panel_width
	for i in range(5):
		players.append({"id": i + 1, "name": "Player %d" % (i + 1), "ready": false})
	_create_player_rows()


func _create_player_rows() -> void:
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var row := PanelContainer.new()
		row.name = "PlayerRow%d" % player["id"]
		row.custom_minimum_size = Vector2(panel_width - 20.0, row_height)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = ROW_COLORS[i % ROW_COLORS.size()]
		style.set_corner_radius_all(10)
		style.content_margin_left = 10
		style.content_margin_right = 10
		row.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.name = "PlayerText"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(label)
		player_list.add_child(row)
		player_rows[player["id"]] = row
		_update_player_row(player)
	var instruction := Label.new()
	instruction.text = "Use the Ready button below"
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.add_theme_font_size_override("font_size", 18)
	instruction.custom_minimum_size.y = 32
	player_list.add_child(instruction)


# Readiness is display-only here. The waiting room's button calls this setter.
func set_player_ready(player_id: int, ready: bool) -> void:
	for player in players:
		if player["id"] == player_id:
			player["ready"] = ready
			_update_player_row(player)
			_update_title()
			return


func _update_player_row(player: Dictionary) -> void:
	var row: PanelContainer = player_rows[player["id"]]
	var label: Label = row.get_node("PlayerText")
	label.text = "%s     %s" % [player["name"], "READY" if player["ready"] else "NOT READY"]
	label.add_theme_color_override("font_color", Color("#1c5930") if player["ready"] else Color("#51483b"))


func _all_players_ready() -> bool:
	if players.is_empty():
		return false
	for player in players:
		if not player["ready"]:
			return false
	return true


func _update_title() -> void:
	title_label.text = "ALL PLAYERS READY!" if _all_players_ready() else "READY UP!"


func remove_player(player_id: int) -> void:
	for i in range(players.size()):
		if players[i]["id"] == player_id:
			var row: PanelContainer = player_rows[player_id]
			player_list.remove_child(row)
			row.queue_free()
			player_rows.erase(player_id)
			players.remove_at(i)
			_update_title()
			return
