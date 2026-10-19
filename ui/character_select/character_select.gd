extends Control

const CHARACTER_NAMES := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]
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

var selected_index := 0


func _ready() -> void:
	for index in cards.size():
		cards[index].pressed.connect(_select.bind(index))
	back_button.pressed.connect(_back_to_menu)
	confirm_button.pressed.connect(_confirm)


func _select(index: int) -> void:
	selected_index = index
	status.text = CHARACTER_NAMES[index] + " selected"


func _confirm() -> void:
	UserSettings.selected_character_scene = CHARACTER_SCENES[selected_index]
	status.text = CHARACTER_NAMES[selected_index] + " saved. Match setup comes later."


func _back_to_menu() -> void:
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back_to_menu()
