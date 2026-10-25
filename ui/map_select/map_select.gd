extends Control

const UI = preload("res://ui/game_ui.gd")
const CATALOG = preload("res://game/maps/map_catalog.gd")
const SPIN_SOUND = preload("res://assets/audio/sfx/Spinning Wheel Sound Effect - A.B.S. Playz.mp3")
const SPIN_SECONDS := 5.0
# Skip the source's silent lead-in and align its final cue with the map reveal.
const SOUND_START := 1.5
const SOUND_LANDING := 10.7
@export_range(-40.0, 0.0, 1.0) var spin_volume_db := -10.0
var spin_audio: AudioStreamPlayer

var elapsed := 0.0
var cards: Array[PanelContainer] = []
var caption: Label
var rail: Control
var landed := false

func _ready() -> void:
	Music.play_music("lobby")
	spin_audio = AudioStreamPlayer.new()
	spin_audio.name = "SpinSound"
	spin_audio.stream = SPIN_SOUND
	spin_audio.volume_db = spin_volume_db
	spin_audio.pitch_scale = (SOUND_LANDING - SOUND_START) / SPIN_SECONDS
	add_child(spin_audio)
	spin_audio.play(SOUND_START)
	theme = UI.theme()
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/Sunset Campground Battle Stage.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.35, 0.28, 0.22)
	add_child(background)
	caption = UI.label("SELECTING THE ARENA", 48)
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	caption.position = Vector2(-600, 200)
	caption.size = Vector2(1200, 80)
	add_child(caption)
	rail = Control.new()
	rail.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	rail.size = Vector2(1400, 360)
	rail.position = Vector2(-700, -180)
	rail.clip_contents = true
	add_child(rail)
	for map in CATALOG.MAPS:
		var card := PanelContainer.new()
		card.size = Vector2(380, 340)
		card.add_theme_stylebox_override("panel", UI.panel())
		var content := VBoxContainer.new()
		card.add_child(content)
		var preview := TextureRect.new()
		preview.texture = load(map.preview)
		preview.custom_minimum_size = Vector2(320, 195)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		preview.modulate = map.tint
		content.add_child(preview)
		content.add_child(UI.label(map.name, 30))
		content.add_child(UI.label(map.description, 17))
		rail.add_child(card)
		cards.append(card)
	var marker := Control.new()
	marker.position = Vector2(660, 0)
	marker.size = Vector2(80, 40)
	marker.draw.connect(func() -> void:
		marker.draw_colored_polygon(PackedVector2Array([Vector2(18, 0), Vector2(62, 0), Vector2(40, 28)]), Color("ffdc72"))
	)
	rail.add_child(marker)
	var footer := UI.label("The host selects one map for everyone", 24)
	footer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	footer.position = Vector2(-600, -180)
	footer.size = Vector2(1200, 50)
	add_child(footer)
	LanSession.room_closed.connect(func(reason: String) -> void:
		LanSession.set_meta("notice", reason)
		get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")
	)

func _process(delta: float) -> void:
	elapsed += delta
	var progress := clampf(elapsed / SPIN_SECONDS, 0, 1)
	var end := 18.0 + float(LanSession.selected_map)
	var scroll := end * (1.0 - pow(1.0 - progress, 4.0))
	for i in range(cards.size()):
		var distance := wrapf(float(i) - scroll, -1.5, 1.5)
		cards[i].position = Vector2(510 + distance * 430.0, 10)
		cards[i].modulate = Color.WHITE if absf(distance) < 0.45 else Color(0.65, 0.60, 0.52)
	if progress >= 1.0 and not landed:
		landed = true
		caption.text = CATALOG.MAPS[LanSession.selected_map].name + " SELECTED"
		cards[LanSession.selected_map].add_theme_stylebox_override("panel", UI.panel(Color("f3a71d")))
	if elapsed >= 6.3:
		set_process(false)
		spin_audio.stop()
		LanSession.phase = "match"
		get_tree().change_scene_to_file("res://game/match/match.tscn")


func _exit_tree() -> void:
	if spin_audio != null: spin_audio.stop()
