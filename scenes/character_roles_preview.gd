extends Node2D

## Local visual/mechanic preview. The R reset/topple shortcut is not a match rule.
const THROWER_SCENES: Array[PackedScene] = [
	preload("res://scenes/Thrower Hat Thrower.tscn"),
	preload("res://scenes/Thrower Head Band.tscn"),
	preload("res://scenes/Thrower Glasses Thrower.tscn"),
	preload("res://scenes/Thrower Curly Haired.tscn"),
	preload("res://scenes/Thrower Bullcap Head.tscn"),
]
const TAYA_SCENES: Array[PackedScene] = [
	preload("res://scenes/Taya Hat Thrower.tscn"),
	preload("res://scenes/Taya Head Band.tscn"),
	preload("res://scenes/Taya Glasses Thrower.tscn"),
	preload("res://scenes/Taya Curly Haired.tscn"),
	preload("res://scenes/Taya Bullcap Head.tscn"),
]
const NAMES: Array[String] = ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]
const CAN_START := Vector2(1000, 640)

@onready var can_node = $Can
@onready var status_label: Label = $HUD/Status

var chosen: int = 0
var active_taya: bool = false
var active_player
var other_player
var tag_notice: float = 0.0


func _ready() -> void:
	_spawn_players()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:
		chosen = event.keycode - KEY_1
		_spawn_players()
	elif event.keycode == KEY_TAB:
		active_taya = not active_taya
		_spawn_players()
	elif event.keycode == KEY_R:
		if can_node.is_standing():
			can_node.topple()
		elif can_node.is_toppled() and can_node.is_settled():
			can_node.reset_for_preview(CAN_START)


func _spawn_players() -> void:
	if is_instance_valid(active_player):
		if is_instance_valid(active_player.active_slipper):
			active_player.active_slipper.queue_free()
		active_player.free()
	if is_instance_valid(other_player):
		other_player.free()
	can_node.reset_for_preview(CAN_START)
	var other_index: int = (chosen + 1) % NAMES.size()
	active_player = (TAYA_SCENES[chosen] if active_taya else THROWER_SCENES[chosen]).instantiate()
	other_player = (THROWER_SCENES[other_index] if active_taya else TAYA_SCENES[other_index]).instantiate()
	active_player.name = "ActivePlayer"
	other_player.name = "OtherPlayer"
	active_player.position = Vector2(800, 640) if active_taya else Vector2(510, 640)
	other_player.position = Vector2(1330, 640)
	active_player.can_path = NodePath("../Can")
	other_player.can_path = NodePath("../Can")
	other_player.accept_local_input = false
	add_child(active_player)
	add_child(other_player)
	if active_taya:
		active_player.tag_requested.connect(_on_tag_requested)
	_tag_label(active_player, "PLAYER: " + NAMES[chosen])
	_tag_label(other_player, "OTHER: " + NAMES[other_index])
	queue_redraw()


func _tag_label(actor: Node2D, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.position = Vector2(-130, -257)
	label.add_theme_color_override("font_color", Color(0.2, 0.13, 0.08))
	label.add_theme_font_size_override("font_size", 20)
	actor.add_child(label)


func _on_tag_requested(_thrower: Node2D) -> void:
	tag_notice = 1.4


func _process(delta: float) -> void:
	tag_notice = maxf(tag_notice - delta, 0.0)
	var role: String = "TAYA" if active_taya else "THROWER"
	var can_state: String = "standing" if can_node.is_standing() else ("carried" if can_node.is_carried() else "toppled")
	status_label.text = "%s: %s     Can: %s     R: preview topple/reset" % [role, NAMES[chosen], can_state]
	if tag_notice > 0.0:
		status_label.text += "     TAG CONTACT!"


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.88, 0.82, 0.68))
	draw_rect(Rect2(0, 570, 1920, 510), Color(0.77, 0.68, 0.51))
	draw_line(Vector2(0, 570), Vector2(1920, 570), Color(0.51, 0.43, 0.31), 7.0, true)
	draw_line(Vector2(0, 690), Vector2(1920, 690), Color(0.94, 0.86, 0.67, 0.68), 5.0, true)
	draw_circle(CAN_START, 46, Color(0.96, 0.7, 0.26, 0.65))
