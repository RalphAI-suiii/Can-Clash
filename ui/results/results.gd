extends Control

const UI = preload("res://ui/game_ui.gd")

func _ready() -> void:
	LanSession.room_closed.connect(func(reason: String) -> void:
		LanSession.set_meta("notice", reason)
		get_tree().change_scene_to_file.call_deferred("res://ui/main_menu/main_menuu.tscn")
	)
	var rankings: Array = LanSession.results
	var best := int(rankings[0].score) if not rankings.is_empty() else 0
	var own_score := -1
	var leaders := 0
	var body := ""
	for i in range(rankings.size()):
		var member: Dictionary = rankings[i]
		body += "%d.  %s     %d points\n\n" % [i + 1, member.name, member.score]
		if member.score == best:
			leaders += 1
		if member.id == LanSession.local_id():
			own_score = member.score
	if LanSession.mode == "lan" and own_score >= 0:
		UserSettings.record_result(LanSession.match_id, own_score == best)
	else:
		body += "Developer games do not affect saved statistics."
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/Sunset Campground Battle Stage.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)
	var title: String = "SHARED VICTORY" if leaders > 1 else "%s WINS!" % rankings[0].name if not rankings.is_empty() else "MATCH RESULTS"
	var view = UI.modal(self, title, body.strip_edges())
	view.content.add_child(UI.button("Main menu", func() -> void:
		LanSession.close_room()
		get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")
	))
