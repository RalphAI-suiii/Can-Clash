extends Control

const CHARACTER_SCENES := [
	"res://scenes/Thrower Hat Thrower.tscn",
	"res://scenes/Thrower Head Band.tscn",
	"res://scenes/Thrower Glasses Thrower.tscn",
	"res://scenes/Thrower Curly Haired.tscn",
	"res://scenes/Thrower Bullcap Head.tscn",
]

@onready var cards: Array[Button] = [
	$Panel/HatThrower,
	$Panel/HeadBand,
	$Panel/GlassesThrower,
	$Panel/CurlyHaired,
	$Panel/BullcapHead,
]
@onready var status: Label = $Panel/Status
@onready var back_button: Button = $Panel/Back
@onready var confirm_button: Button = $Panel/Confirm

var lobby_mode := false
var selected_index := -1
var pending_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for index in cards.size():
		cards[index].set_pressed_no_signal(false)
		cards[index].pressed.connect(_select.bind(index))
		var taken := Label.new()
		taken.name = "Taken"
		taken.position = Vector2(10, 8)
		taken.size = Vector2(240, 44)
		taken.text = "TAKEN"
		taken.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		taken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		taken.add_theme_font_override("font", preload("res://assets/fonts/TitanOne-Regular.ttf"))
		taken.add_theme_font_size_override("font_size", 26)
		taken.add_theme_color_override("font_color", Color("ad2d22"))
		taken.add_theme_color_override("font_outline_color", Color("fff5dc"))
		taken.add_theme_constant_override("outline_size", 5)
		taken.hide()
		cards[index].add_child(taken)
	back_button.pressed.connect(_close)
	confirm_button.pressed.connect(_confirm)
	confirm_button.disabled = true
	if lobby_mode:
		back_button.text = "Back to Lobby"
		confirm_button.text = "Claim Character"
		LanSession.roster_changed.connect(_refresh_cards)
		LanSession.character_claim_result.connect(_claim_result)
		_refresh_cards()
	else:
		status.text = "Join a lobby to choose a character."


func _select(index: int) -> void:
	if cards[index].disabled:
		return
	selected_index = index
	status.text = "%s — confirm to claim." % LanSession.CHARACTERS[index]
	confirm_button.disabled = false


func _confirm() -> void:
	if not lobby_mode or selected_index < 0 or cards[selected_index].disabled:
		return
	pending_index = selected_index
	confirm_button.disabled = true
	status.text = "Claiming %s..." % LanSession.CHARACTERS[pending_index]
	if not LanSession.select_character(pending_index):
		_claim_result(pending_index, false)


func _claim_result(index: int, accepted: bool) -> void:
	if index != pending_index:
		return
	if not accepted:
		pending_index = -1
		status.text = "That character is taken. Choose another."
		confirm_button.disabled = selected_index < 0 or cards[selected_index].disabled


func _refresh_cards() -> void:
	if not lobby_mode:
		return
	var own := LanSession.member(LanSession.local_id())
	var current := int(own.get("character", -1))
	for index in cards.size():
		var holder := ""
		for entry in LanSession.players:
			if entry.id != LanSession.local_id() and int(entry.character) == index:
				holder = str(entry.name)
				break
		cards[index].disabled = not holder.is_empty()
		cards[index].modulate = Color(0.62, 0.62, 0.62) if cards[index].disabled else Color.WHITE
		var taken_label: Label = cards[index].get_node("Taken")
		taken_label.visible = cards[index].disabled
		cards[index].tooltip_text = "Chosen by %s" % holder if cards[index].disabled else "Choose %s" % LanSession.CHARACTERS[index]
		cards[index].set_pressed_no_signal(index == (selected_index if selected_index >= 0 else current) and not cards[index].disabled)
	if pending_index >= 0:
		if current == pending_index:
			UserSettings.selected_character_scene = CHARACTER_SCENES[current]
			UserSettings.save_profile()
			_close()
			return
		if cards[pending_index].disabled:
			_claim_result(pending_index, false)
	elif selected_index < 0:
		status.text = "Your character: %s" % LanSession.CHARACTERS[current] if current >= 0 else "Choose a free character before pressing Ready."
	confirm_button.disabled = selected_index < 0 or cards[selected_index].disabled or pending_index >= 0


func _close() -> void:
	if lobby_mode:
		queue_free()
	else:
		get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()
