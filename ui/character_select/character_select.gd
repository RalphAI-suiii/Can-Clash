extends Control

const DESCRIPTIONS := [
	"A steady shot with a rapid-fire special.",
	"Bank a slipper off a wall and toward the can.",
	"Her special slipper finds its way back home.",
	"A direct special hit can stop Taya in their tracks.",
	"Guide his special slipper through the air.",
	"Leonardo joins with the classic charged throw.",
	"Kay joins with the classic charged throw.",
]
const SPECIAL_NAMES := [
	"RAPID FIRE", "RICOCHET", "SELF-RETURNING", "STUNNING SLIPPER",
	"MIND CONTROL", "CLASSIC THROW", "CLASSIC THROW",
]
const CARD_NAMES := ["Hat", "Head Band", "Glasses", "Curly", "Bullcap", "Leonardo", "Kay"]

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
@onready var selected_portrait: TextureRect = $Panel/ShowcasePane/SelectedPortrait
@onready var selected_name: Label = $Panel/ShowcasePane/SelectedName
@onready var ability_caption: Label = $Panel/ShowcasePane/AbilityCaption
@onready var ability_name: Label = $Panel/ShowcasePane/AbilityName
@onready var ability_details: Label = $Panel/ShowcasePane/AbilityDetails

var selected_index := -1
var entering_room := false
var popup_mode := false
var pending_index := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_add_new_cards()
	for index in cards.size():
		cards[index].set_pressed_no_signal(false)
		cards[index].pressed.connect(_select.bind(index))
	back_button.pressed.connect(_back)
	confirm_button.pressed.connect(_confirm)
	if popup_mode:
		$Background.hide()
		$Logo.hide()
		$Dim.color = Color(0.018, 0.04, 0.055, 0.72)
		back_button.text = "LEAVE ROOM"
		confirm_button.text = "CHOOSE CHARACTER"
		confirm_button.add_theme_font_size_override("font_size", 27)
		LanSession.roster_changed.connect(_refresh_claim)
		LanSession.character_claim_result.connect(_claim_result)
	status.add_theme_constant_override("outline_size", 0)
	status.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	var previous := LanSession.chosen_character()
	_select(previous if previous >= 0 else 0)
	if not popup_mode:
		confirm_button.text = "BACK TO MENU"


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
	# The small roster sits beside a full-size selected-character preview.
	for index in range(cards.size()):
		var card := cards[index]
		card.position = Vector2(51 + (index % 4) * 170, 168 + int(index / 4) * 174)
		card.size = Vector2(155, 166)
		card.tooltip_text = DESCRIPTIONS[index]
		var portrait: TextureRect = card.get_node("Portrait")
		portrait.texture = _trim_portrait(portrait.texture as AtlasTexture)
		portrait.position = Vector2(8, 7)
		portrait.size = Vector2(139, 111)
		var label: Label = card.get_node("Name")
		label.text = CARD_NAMES[index]
		label.position = Vector2(4, 119)
		label.size = Vector2(147, 42)
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)


func _trim_portrait(portrait: AtlasTexture) -> AtlasTexture:
	var source: Image = portrait.atlas.get_image()
	var frame := Rect2i(portrait.region)
	var painted := source.get_region(frame).get_used_rect()
	if painted.size == Vector2i.ZERO:
		return portrait
	painted = painted.grow(8).intersection(Rect2i(Vector2i.ZERO, frame.size))
	var trimmed := AtlasTexture.new()
	trimmed.atlas = portrait.atlas
	trimmed.region = Rect2(frame.position + painted.position, painted.size)
	return trimmed


func _select(index: int) -> void:
	if index < 0 or index >= cards.size() or entering_room:
		return
	selected_index = index
	for card_index in range(cards.size()):
		cards[card_index].set_pressed_no_signal(card_index == index)
	selected_portrait.texture = (cards[index].get_node("Portrait") as TextureRect).texture
	selected_name.text = LanSession.CHARACTERS[index].to_upper()
	selected_name.add_theme_font_size_override("font_size", 34 if selected_name.text.length() > 14 else 43)
	ability_caption.text = "THROWER SPECIAL" if index < 5 else "THROW STYLE"
	ability_name.text = SPECIAL_NAMES[index]
	ability_details.text = DESCRIPTIONS[index]
	status.text = "%s  •  Friends can choose the same character" % LanSession.CHARACTERS[index].to_upper()
	confirm_button.disabled = false


func _confirm() -> void:
	if entering_room or selected_index < 0:
		return
	if not popup_mode:
		_back()
		return
	pending_index = selected_index
	entering_room = true
	confirm_button.disabled = true
	status.text = "CHOOSING %s..." % LanSession.CHARACTERS[pending_index].to_upper()
	if not LanSession.select_character(pending_index):
		_claim_result(pending_index, false)
	elif LanSession.is_host():
		_refresh_claim()


func _refresh_claim() -> void:
	if pending_index < 0:
		return
	if int(LanSession.member(LanSession.local_id()).get("character", -1)) != pending_index:
		return
	UserSettings.selected_character_scene = LanSession.CHARACTER_SCENES[pending_index]
	UserSettings.save_profile()
	queue_free()


func _claim_result(index: int, accepted: bool) -> void:
	if index != pending_index:
		return
	if accepted:
		_refresh_claim()
		return
	pending_index = -1
	entering_room = false
	confirm_button.disabled = false
	status.text = "COULDN'T CHOOSE THAT CHARACTER. Try again."


func _back() -> void:
	LanSession.close_room()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_select(wrapi(selected_index - 1, 0, cards.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_select(wrapi(selected_index + 1, 0, cards.size()))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up") and selected_index >= 4:
		_select(selected_index - 4)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") and selected_index < 3:
		_select(selected_index + 4)
		get_viewport().set_input_as_handled()
