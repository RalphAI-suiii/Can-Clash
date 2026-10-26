extends Control

const CHARACTER_SCENES := [
	"res://scenes/Thrower Hat Thrower.tscn",
	"res://scenes/Thrower Head Band.tscn",
	"res://scenes/Thrower Glasses Thrower.tscn",
	"res://scenes/Thrower Curly Haired.tscn",
	"res://scenes/Thrower Bullcap Head.tscn",
	"res://scenes/Thrower Leonardo.tscn",
	"res://scenes/Thrower Kay.tscn",
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
	_add_new_cards()
	for index in cards.size():
		cards[index].set_pressed_no_signal(false)
		cards[index].pressed.connect(_select.bind(index))
	back_button.pressed.connect(_close)
	confirm_button.pressed.connect(_confirm)
	confirm_button.disabled = true
	if lobby_mode:
		back_button.text = "Back to Lobby"
		confirm_button.text = "Choose Character"
		LanSession.roster_changed.connect(_refresh_cards)
		LanSession.character_claim_result.connect(_claim_result)
		_refresh_cards()
	else:
		status.text = "Join a lobby to choose a character."


func _add_new_cards() -> void:
	var art_paths := [
		"res://assets/characters/sprites/new_roster/leonardo/idle.png",
		"res://assets/characters/sprites/new_roster/kay/idle.png",
	]
	for index in range(art_paths.size()):
		var card := cards[4].duplicate() as Button
		card.name = "Leonardo" if index == 0 else "Kay"
		card.set_pressed_no_signal(false)
		$Panel.add_child(card)
		var portrait := AtlasTexture.new()
		portrait.atlas = load(art_paths[index]) as Texture2D
		portrait.region = Rect2(0, 0, portrait.atlas.get_width() / 4.0, portrait.atlas.get_height() / 2.0)
		(card.get_node("Portrait") as TextureRect).texture = portrait
		(card.get_node("Name") as Label).text = card.name
		cards.append(card)
	# Keep all seven full-height portraits in one balanced row.
	for index in range(cards.size()):
		var card := cards[index]
		card.position = Vector2(30 + index * 225, 125)
		card.size = Vector2(210, 390)
		var portrait: TextureRect = card.get_node("Portrait")
		portrait.position = Vector2(15, 34)
		portrait.size = Vector2(180, 234)
		var label: Label = card.get_node("Name")
		label.position = Vector2(6, 300)
		label.size = Vector2(198, 62)
		label.add_theme_font_size_override("font_size", 19)


func _select(index: int) -> void:
	if cards[index].disabled:
		return
	selected_index = index
	status.text = "%s — confirm to choose." % LanSession.CHARACTERS[index]
	confirm_button.disabled = false


func _confirm() -> void:
	if not lobby_mode or selected_index < 0 or cards[selected_index].disabled:
		return
	pending_index = selected_index
	confirm_button.disabled = true
	status.text = "Choosing %s..." % LanSession.CHARACTERS[pending_index]
	if not LanSession.select_character(pending_index):
		_claim_result(pending_index, false)


func _claim_result(index: int, accepted: bool) -> void:
	if index != pending_index:
		return
	if not accepted:
		pending_index = -1
		status.text = "Could not choose that character. Please try again."
		confirm_button.disabled = selected_index < 0 or cards[selected_index].disabled


func _refresh_cards() -> void:
	if not lobby_mode:
		return
	var own := LanSession.member(LanSession.local_id())
	var current := int(own.get("character", -1))
	for index in cards.size():
		cards[index].disabled = false
		cards[index].tooltip_text = "Choose %s" % LanSession.CHARACTERS[index]
		cards[index].set_pressed_no_signal(index == (selected_index if selected_index >= 0 else current))
	if pending_index >= 0:
		if current == pending_index:
			UserSettings.selected_character_scene = CHARACTER_SCENES[current]
			UserSettings.save_profile()
			_close()
			return
	elif selected_index < 0:
		status.text = "Your character: %s" % LanSession.CHARACTERS[current] if current >= 0 else "Choose a character before pressing Ready."
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
