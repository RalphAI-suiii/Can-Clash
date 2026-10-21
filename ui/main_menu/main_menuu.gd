extends Control

const UI = preload("res://ui/game_ui.gd")
var name_input: LineEdit

@onready var play_local: Button = $PlayLocal
@onready var popup: Control = $LocalPlayPopup
@onready var backdrop: ColorRect = $LocalPlayPopup/Backdrop
@onready var card: Panel = $LocalPlayPopup/Card
@onready var host: Button = $LocalPlayPopup/Card/Host
@onready var join: Button = $LocalPlayPopup/Card/Join
@onready var close_button: Button = $LocalPlayPopup/Card/Close
var popup_tween: Tween


func _ready() -> void:
	_build_profile_controls()
	_color_menu_buttons()
	play_local.pressed.connect(_show_local_popup)
	host.pressed.connect(_open_host)
	join.pressed.connect(_open_join)
	close_button.pressed.connect(_hide_local_popup)
	backdrop.gui_input.connect(_on_backdrop_input)
	$Avatar.pressed.connect(_open_character_select)
	if LanSession.has_meta("notice"):
		var notice = UI.modal(self, "ROOM CLOSED", str(LanSession.get_meta("notice")))
		notice.content.add_child(UI.button("Back to menu", notice.layer.queue_free))
		LanSession.remove_meta("notice")


func _show_local_popup() -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()
	popup.show()
	backdrop.modulate.a = 0.0
	card.modulate.a = 0.0
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.92, 0.92)
	popup_tween = create_tween().set_parallel()
	popup_tween.tween_property(backdrop, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(card, "modulate:a", 1.0, 0.18)
	popup_tween.tween_property(card, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	host.grab_focus()


func _hide_local_popup() -> void:
	if popup_tween and popup_tween.is_running():
		popup_tween.kill()
	popup.hide()
	play_local.grab_focus()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_hide_local_popup()


func _unhandled_key_input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		_hide_local_popup()
		get_viewport().set_input_as_handled()


func _open_host() -> void:
	_save_name()
	if LanSession.host_room() == OK:
		get_tree().change_scene_to_file("res://ui/waiting_room/waiting_room.tscn")
	else:
		var notice = UI.modal(self, "COULDN'T HOST", "Another room may be open on this PC. Close it and try again.")
		notice.content.add_child(UI.button("Okay", notice.layer.queue_free))


func _open_join() -> void:
	_save_name()
	get_tree().change_scene_to_file("res://ui/lobby/join_local.tscn")


func _open_character_select() -> void:
	_save_name()
	get_tree().change_scene_to_file("res://ui/character_select/character_select.tscn")


func _build_profile_controls() -> void:
	var profile_title := UI.label("YOUR NAME", 24)
	profile_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	profile_title.offset_left = -195
	profile_title.offset_right = 195
	profile_title.offset_top = -140
	profile_title.offset_bottom = -106
	profile_title.theme = UI.theme()
	add_child(profile_title)
	name_input = LineEdit.new()
	name_input.name = "PlayerName"
	name_input.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	name_input.offset_left = -195
	name_input.offset_right = 195
	name_input.offset_top = -98
	name_input.offset_bottom = -36
	name_input.theme = UI.theme()
	name_input.max_length = 20
	name_input.placeholder_text = "Enter your name"
	name_input.text = UserSettings.display_name
	name_input.text_submitted.connect(func(_value: String) -> void: _save_name(); name_input.release_focus())
	name_input.focus_exited.connect(_save_name)
	add_child(name_input)
	var practice_shadow := $ButtonShadow_PlayLocal.duplicate()
	practice_shadow.name = "ButtonShadow_Practice"
	practice_shadow.position.y += 128
	add_child(practice_shadow)
	var practice: Button = $PlayLocal.duplicate()
	practice.name = "Practice"
	practice.position.y += 128
	practice.text = "Practice"
	practice.pressed.connect(_open_practice)
	add_child(practice)
	var statistics_shadow := $ButtonShadow_Friends.duplicate()
	statistics_shadow.name = "ButtonShadow_Statistics"
	statistics_shadow.position.y += 128
	add_child(statistics_shadow)
	var statistics_button: Button = $Friends.duplicate()
	statistics_button.name = "Statistics"
	statistics_button.position.y += 128
	statistics_button.text = "Statistics"
	statistics_button.pressed.connect(_show_statistics)
	add_child(statistics_button)


func _color_menu_buttons() -> void:
	var colors := {
		"PlayOnline": Color("4d91e8"), "PlayLocal": Color("57b948"),
		"Practice": Color("33b8b2"), "Avatar": Color("a575e0"),
		"Friends": Color("e96eb4"), "Statistics": Color("f5d34c"),
		"Messages": Color("f26c60"), "Settings": Color("e6c79b"),
	}
	for button_name in colors:
		var button: Button = get_node(NodePath(button_name))
		var color: Color = colors[button_name]
		for state in ["normal", "hover", "pressed"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.bg_color = color.lightened(0.12) if state == "hover" else color.darkened(0.12) if state == "pressed" else color
			if state != "pressed" and button_name not in ["Messages", "Settings"]:
				style.border_color = color.darkened(0.32)
			button.add_theme_stylebox_override(state, style)
		var shadow: Panel = get_node_or_null(NodePath("ButtonShadow_" + button_name))
		if shadow != null:
			var style: StyleBoxFlat = shadow.get_theme_stylebox("panel").duplicate()
			style.bg_color = color.darkened(0.32)
			shadow.add_theme_stylebox_override("panel", style)


func _save_name() -> void:
	UserSettings.set_display_name(name_input.text)
	name_input.text = UserSettings.display_name


func _open_practice() -> void:
	_save_name()
	LanSession.begin_local("practice")
	get_tree().change_scene_to_file("res://ui/waiting_room/waiting_room.tscn")


func _show_statistics() -> void:
	var stats: Dictionary = UserSettings.statistics
	var body := "Wins: %d       Losses: %d\n\nSuccessful throws: %d\nCan knockdowns: %d\n\nSaved on this PC. Practice and developer games do not affect totals." % [stats.wins, stats.losses, stats.successful_throws, stats.can_knockdowns]
	var view = UI.modal(self, "YOUR STATISTICS", body)
	view.content.add_child(UI.button("Back", view.layer.queue_free))
