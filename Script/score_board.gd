
extends Control

@export var row_height: float = 52.0
@export var icon_size: float = 36.0
@export var panel_width: float = 300.0

@onready var player_list: VBoxContainer = $PanelContainer/VBoxContainer

var players: Array[Dictionary] = []
var player_rows: Dictionary = {}

var row_colors: Array[Color] = [
	Color("#ffdf78"),
	Color("#d9edf2"),
	Color("#efb18b"),
	Color("#fff5dc"),
	Color("#fff5dc")
]


func _ready() -> void:
	player_list.add_theme_constant_override("separation", 5)
	$PanelContainer.custom_minimum_size.x = panel_width

	var starting_players: Array = []

	for i in range(5):
		starting_players.append({
			"id": i + 1,
			"name": "Player %d" % (i + 1),
			"score": 0,
			"icon": null
		})

	update_scoreboard(starting_players)


func update_scoreboard(new_players: Array) -> void:
	players.clear()

	for player in new_players:
		players.append(player.duplicate())

	players.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.get("score", 0)) > int(b.get("score", 0))
	)

	var active_ids: Array = []

	for player in players:
		active_ids.append(player.get("id"))

	for old_id in player_rows.keys():
		if not active_ids.has(old_id):
			player_rows[old_id].queue_free()
			player_rows.erase(old_id)

	for player in players:
		var player_id = player.get("id")

		if not player_rows.has(player_id):
			var row := create_player_row()
			player_rows[player_id] = row
			player_list.add_child(row)

	for index in range(players.size()):
		var player: Dictionary = players[index]
		var player_id = player.get("id")
		var row: PanelContainer = player_rows[player_id]

		player_list.move_child(row, index)
		update_player_row(row, player, index)


func create_player_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.name = "PlayerRow"
	row.custom_minimum_size = Vector2(0, row_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color("#fff5dc")
	row_style.set_corner_radius_all(12)
	row_style.set_content_margin(SIDE_LEFT, 8)
	row_style.set_content_margin(SIDE_RIGHT, 10)
	row_style.set_content_margin(SIDE_TOP, 5)
	row_style.set_content_margin(SIDE_BOTTOM, 5)
	row.add_theme_stylebox_override("panel", row_style)

	var contents := HBoxContainer.new()
	contents.name = "Contents"
	contents.add_theme_constant_override("separation", 8)
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(contents)

	var rank := Label.new()
	rank.name = "Rank"
	rank.custom_minimum_size = Vector2(32, 32)
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank.add_theme_font_size_override("font_size", 17)
	rank.add_theme_color_override("font_color", Color("#28231c"))

	var rank_style := StyleBoxFlat.new()
	rank_style.bg_color = Color("#fffaf0")
	rank_style.set_corner_radius_all(20)
	rank_style.set_border_width_all(2)
	rank_style.border_color = Color("#514333")
	rank.add_theme_stylebox_override("normal", rank_style)
	contents.add_child(rank)

	var icon := TextureRect.new()
	icon.name = "CharacterIcon"
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	contents.add_child(icon)

	var player_name := Label.new()
	player_name.name = "PlayerName"
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_name.add_theme_font_size_override("font_size", 13)
	player_name.add_theme_color_override("font_color", Color("#302a22"))
	contents.add_child(player_name)

	var score := Label.new()
	score.name = "Score"
	score.custom_minimum_size.x = 35
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	score.add_theme_font_size_override("font_size", 18)
	score.add_theme_color_override("font_color", Color("#302a22"))
	contents.add_child(score)

	return row


func update_player_row(
	row: PanelContainer,
	player: Dictionary,
	index: int
) -> void:
	var contents: HBoxContainer = row.get_node("Contents")
	var rank: Label = contents.get_node("Rank")
	var icon: TextureRect = contents.get_node("CharacterIcon")
	var player_name: Label = contents.get_node("PlayerName")
	var score: Label = contents.get_node("Score")

	rank.text = str(index + 1)
	player_name.text = str(player.get("name", "Player %d" % (index + 1)))
	score.text = str(player.get("score", 0))

	var player_icon = player.get("icon", null)

	if player_icon is Texture2D:
		icon.texture = player_icon
	else:
		icon.texture = null

	var style := row.get_theme_stylebox("panel") as StyleBoxFlat

	if style:
		style.bg_color = row_colors[index % row_colors.size()]


func update_player_score(player_id: int, new_score: int) -> void:
	for player in players:
		if player.get("id") == player_id:
			player["score"] = new_score
			update_scoreboard(players)
			return


func update_player_name(player_id: int, new_name: String) -> void:
	for player in players:
		if player.get("id") == player_id:
			player["name"] = new_name
			update_scoreboard(players)
			return


func remove_player(player_id: int) -> void:
	var remaining_players: Array = []

	for player in players:
		if player.get("id") != player_id:
			remaining_players.append(player)

	update_scoreboard(remaining_players)


func add_player(
	player_id: int,
	player_name: String = "",
	starting_score: int = 0,
	player_icon: Texture2D = null
) -> void:
	for player in players:
		if player.get("id") == player_id:
			return

	if player_name.is_empty():
		player_name = "Player %d" % player_id

	update_scoreboard(players + [{
		"id": player_id,
		"name": player_name,
		"score": starting_score,
		"icon": player_icon
	}])
