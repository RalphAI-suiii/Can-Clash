extends Control

const UI = preload("res://ui/game_ui.gd")
var podium_players: Array[Node2D] = []

func _ready() -> void:
	Music.play_music("menu")
	LanSession.room_closed.connect(func(reason: String) -> void:
		LanSession.set_meta("notice", reason)
		get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menuu.tscn")
	)
	theme = UI.theme()
	var rankings: Array = LanSession.results
	var best := int(rankings[0].score) if not rankings.is_empty() else 0
	var leaders := rankings.filter(func(member: Dictionary) -> bool: return int(member.score) == best).size()
	for member in rankings:
		if member.id == LanSession.local_id() and LanSession.mode in ["lan", "online"]:
			UserSettings.record_result(LanSession.match_id, int(member.score) == best)
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/Sunset Campground Battle Stage.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.12, 0.06, 0.02, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title := "SHARED VICTORY" if leaders > 1 else "%s WINS!" % rankings[0].name if not rankings.is_empty() else "MATCH RESULTS"
	_text(title, Vector2(160, 65), Vector2(1600, 80), 56)
	_text("FINAL STANDINGS", Vector2(460, 155), Vector2(1000, 50), 26)
	var stage := Control.new()
	stage.name = "Podium"
	stage.position = Vector2(360, 280)
	stage.size = Vector2(1200, 550)
	add_child(stage)
	var positions := [600.0, 240.0, 960.0]
	var heights := [260.0, 200.0, 165.0]
	var colors := [Color("eeb63c"), Color("aebfc8"), Color("b87742")]
	for rank in range(3):
		var top: float = 500.0 - heights[rank]
		var block := Panel.new()
		block.name = "Place%d" % (rank + 1)
		block.position = Vector2(positions[rank] - 160, top)
		block.size = Vector2(320, heights[rank])
		block.add_theme_stylebox_override("panel", UI.panel(colors[rank], 6))
		stage.add_child(block)
		var place := UI.label(str(rank + 1), 64)
		place.position = Vector2(0, 20)
		place.size = Vector2(320, 85)
		block.add_child(place)
		if rank >= rankings.size(): continue
		var member: Dictionary = rankings[rank]
		var character := clampi(int(member.get("character", 0)), 0, LanSession.CHARACTERS.size() - 1)
		var actor: CharacterBody2D = load("res://scenes/Taya %s.tscn" % LanSession.CHARACTERS[character]).instantiate()
		actor.position = Vector2(positions[rank], top - 10)
		actor.scale = Vector2.ONE * 0.85
		actor.accept_local_input = false
		actor.show_player_ring = false
		actor.collision_layer = 0
		actor.collision_mask = 0
		stage.add_child(actor)
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.throw_status.hide()
		podium_players.append(actor)
		var name_label := UI.label(str(member.name), 28)
		name_label.position = Vector2(positions[rank] - 175, top - 240)
		name_label.size = Vector2(350, 45)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stage.add_child(name_label)
		var score := UI.label("%d POINTS" % int(member.score), 26)
		score.position = Vector2(0, 110)
		score.size = Vector2(320, 45)
		block.add_child(score)
	for rank in range(3, rankings.size()):
		var member: Dictionary = rankings[rank]
		_text("%d. %s   %d points" % [rank + 1, member.name, member.score], Vector2(200 + (rank - 3) * 760, 825), Vector2(760, 55), 26)
	if LanSession.mode == "developer":
		_text("Developer games do not affect saved statistics.", Vector2(300, 895), Vector2(1320, 40), 22)
	var leave := UI.button("Main Menu", func() -> void:
		LanSession.close_room()
		get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")
	)
	leave.position = Vector2(760, 965)
	leave.size = Vector2(400, 75)
	add_child(leave)

func _text(copy: String, at: Vector2, dimensions: Vector2, font_size: int) -> void:
	var label := UI.label(copy, font_size)
	label.position = at
	label.size = dimensions
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(label)
