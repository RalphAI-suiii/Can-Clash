extends Control

signal readiness_changed

@export var row_height: float = 44.0
@export var panel_width: float = 280.0

@onready var player_list: VBoxContainer = $PanelContainer/VBoxContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/title_label

var players: Array[Dictionary] = []
var player_rows: Dictionary = {}
var ready_count: Label

const ROW_COLORS: Array[Color] = [
	Color("#fff5dc"), Color("#ffedc2"), Color("#fff5dc"),
	Color("#ffedc2"), Color("#fff5dc"),
]


func _ready() -> void:
	title_label.text = "PLAYERS"
	player_list.add_theme_constant_override("separation", 5)
	$PanelContainer.custom_minimum_size.x = panel_width
	set_roster(LanSession.players)


func set_roster(roster: Array) -> void:
	for child in player_list.get_children():
		if child != title_label:
			player_list.remove_child(child)
			child.queue_free()
	player_rows.clear()
	players.assign(roster)
	_create_player_rows()
	readiness_changed.emit()


func _create_player_rows() -> void:
	for i in range(players.size()):
		var player: Dictionary = players[i]
		var row := PanelContainer.new()
		row.name = "PlayerRow%d" % player["id"]
		row.custom_minimum_size = Vector2(panel_width - 20.0, row_height)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var style := StyleBoxFlat.new()
		style.bg_color = ROW_COLORS[i % ROW_COLORS.size()]
		style.set_corner_radius_all(10)
		style.set_border_width_all(3)
		style.border_color = Color("#75370f")
		style.shadow_color = Color(0.2, 0.08, 0.02, 0.22)
		style.shadow_size = 4
		style.shadow_offset = Vector2(2, 3)
		style.content_margin_left = 10
		style.content_margin_right = 10
		row.add_theme_stylebox_override("panel", style)
		var content := HBoxContainer.new()
		content.name = "Content"
		content.add_theme_constant_override("separation", 10)
		row.add_child(content)
		var badge := ColorRect.new()
		badge.color = player.get("color", Color("329dff"))
		badge.custom_minimum_size = Vector2(12, 12)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(badge)
		var label := Label.new()
		label.name = "PlayerText"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 18)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
		player_list.add_child(row)
		player_rows[player["id"]] = row
		_update_player_row(player)
	ready_count = Label.new()
	ready_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_count.add_theme_font_size_override("font_size", 20)
	ready_count.custom_minimum_size.y = 36
	player_list.add_child(ready_count)
	_update_title()


# Readiness is display-only here. The waiting room's button calls this setter.
func set_player_ready(player_id: int, ready: bool) -> void:
	for player in players:
		if player["id"] == player_id:
			player["ready"] = ready
			_update_player_row(player)
			_update_title()
			readiness_changed.emit()
			return


func _update_player_row(player: Dictionary) -> void:
	var row: PanelContainer = player_rows[player["id"]]
	var label: Label = row.get_node("Content/PlayerText")
	label.text = "%s%s\n%s" % [player["name"], " (HOST)" if player["id"] == 1 else "", "READY" if player["ready"] else "NOT READY"]
	label.add_theme_color_override("font_color", Color("#1c5930") if player["ready"] else Color("#51483b"))


func all_players_ready() -> bool:
	if players.is_empty():
		return false
	for player in players:
		if not player["ready"]:
			return false
	return true


func _update_title() -> void:
	title_label.text = "ALL PLAYERS READY!" if all_players_ready() else "PLAYERS  %d / %d" % [players.size(), LanSession.capacity()]
	var count := 0
	for player in players:
		if player["ready"]:
			count += 1
	ready_count.text = "%d / %d READY" % [count, players.size()]


func remove_player(player_id: int) -> void:
	for i in range(players.size()):
		if players[i]["id"] == player_id:
			var row: PanelContainer = player_rows[player_id]
			player_list.remove_child(row)
			row.queue_free()
			player_rows.erase(player_id)
			players.remove_at(i)
			_update_title()
			readiness_changed.emit()
			return
