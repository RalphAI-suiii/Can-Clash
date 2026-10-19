extends Node2D

@onready var can_node: Variant = $Can
@onready var status_label: Label = $HUD/Status
@onready var lunge_label: Label = $HUD/LungeStatus
@onready var taya: Variant = $Taya
@onready var target: Node2D = $LungeTarget
@onready var tag_notice: Label = $HUD/TagNotice

var topple_key_held: bool = false
var notice_elapsed: float = 0.0


func _ready() -> void:
	taya.tag_requested.connect(_on_tag_requested)


func _process(delta: float) -> void:
	# Demo-only shortcut for repeating the Taya pickup/reset loop.
	var pressed: bool = Input.is_key_pressed(KEY_T)
	if pressed and not topple_key_held and can_node.is_standing():
		can_node.global_position = Vector2(840, 590)
		can_node.topple()
	topple_key_held = pressed
	if can_node.is_toppled():
		status_label.text = "CAN MOVING  •  Wait for it to settle" if not can_node.is_settled() else "CAN DOWN  •  Approach and press E to pick it up"
	elif can_node.is_carried():
		status_label.text = "CARRYING  •  Walk to the gold base and press E"
	else:
		status_label.text = "CAN RESET  •  Taya may tag; press T to topple again"
	if not can_node.is_standing():
		lunge_label.text = "Lunge locked until the can is upright"
	elif taya.can_lunge():
		lunge_label.text = "Lunge ready  •  Nearby thrower auto-locks; otherwise aim with mouse"
	else:
		var remaining: float = maxf(taya.next_lunge_time - Time.get_ticks_msec() / 1000.0, 0.0)
		lunge_label.text = "Lunge cooldown  %.1f s" % remaining
	if notice_elapsed > 0.0:
		notice_elapsed -= delta
		tag_notice.visible = notice_elapsed > 0.0


func _on_tag_requested(thrower: Node2D) -> void:
	if thrower != target:
		return
	tag_notice.show()
	notice_elapsed = 1.4
	var flash := create_tween()
	flash.tween_property(target, "modulate", Color(1.0, 0.72, 0.45), 0.1)
	flash.tween_property(target, "modulate", Color.WHITE, 0.28)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color(0.88, 0.82, 0.68))
	draw_rect(Rect2(0, 0, 360, 1080), Color(0.64, 0.8, 0.67, 0.48))
	draw_line(Vector2(360, 0), Vector2(360, 1080), Color(0.98, 0.96, 0.81), 7.0, true)
	draw_rect(Rect2(0, 570, 1920, 510), Color(0.77, 0.68, 0.51))
	draw_line(Vector2(0, 570), Vector2(1920, 570), Color(0.51, 0.43, 0.31), 7.0, true)
	draw_line(Vector2(0, 690), Vector2(1920, 690), Color(0.94, 0.86, 0.67, 0.68), 5.0, true)
