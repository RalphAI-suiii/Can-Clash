extends Node

# Practice uses the real character, slipper, and can scripts in the waiting room.
const UI = preload("res://ui/game_ui.gd")
const DUMMY_SCENE = preload("res://scenes/Thrower Head Band.tscn")
const TOE_LINE := Rect2(905, 170, 145, 790)

class InputIcon extends Control:
	var kind := ""

	func _draw() -> void:
		if kind == "":
			return
		var outline := Color("3c2417")
		var cream := Color("fff0ca")
		var active := Color("ffb52d")
		if kind in ["left_mouse", "right_mouse"]:
			# A compact mouse diagram highlights the button used by this lesson.
			draw_rect(Rect2(17, 5, 38, 38), cream)
			draw_arc(Vector2(36, 24), 19, 0, TAU, 40, outline, 3.0)
			draw_rect(Rect2(18, 6, 18, 17), active if kind == "left_mouse" else cream)
			draw_rect(Rect2(36, 6, 18, 17), active if kind == "right_mouse" else cream)
			draw_line(Vector2(36, 6), Vector2(36, 24), outline, 3.0)
			draw_line(Vector2(18, 23), Vector2(54, 23), outline, 3.0)
		else:
			draw_rect(Rect2(5, 6, 62, 34), outline)
			draw_rect(Rect2(8, 9, 56, 28), cream)
			var font := ThemeDB.fallback_font
			draw_string(font, Vector2(8, 29), kind.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 56, 16, outline)

enum Lesson { MOVE, SPRINT, HIT, RETRIEVE, RETURN, ORBS, ARM, SPECIAL, PICKUP, RESET_CAN, LUNGE, TAG, STUN, DONE }

var room: Node2D
var player: CharacterBody2D
var panel: PanelContainer
var progress: Label
var heading: Label
var instruction: Label
var feedback: Label
var control_hint: HBoxContainer
var control_icon: Control
var control_caption: Label
var continue_button: Button
var free_button: Button
var line_art: Node2D
var base_art: Node2D
var dummy: CharacterBody2D
var tracked_slipper: Node2D
var lesson := -1
var free_mode := false
var travel := 0.0
var sprint_time := 0.0
var last_position := Vector2.ZERO
var last_hits := 0
var picked_up := false
var tagged := false
var special_launched := false
var lesson_complete := false


func _ready() -> void:
	room = get_parent()
	_build_line()
	_build_base_marker()
	_build_panel()
	panel.hide()
	line_art.hide()
	base_art.hide()


func _process(delta: float) -> void:
	if lesson < 0:
		if not is_instance_valid(room.selection_overlay) and int(LanSession.member(LanSession.local_id()).get("character", -1)) >= 0:
			restart()
		return
	player = room.actors.get(LanSession.local_id())
	if not is_instance_valid(player):
		return
	_track_slipper()
	if is_instance_valid(player.active_slipper) and player.active_slipper.special_kind != &"":
		special_launched = true
	if room.practice_hits > last_hits:
		if not player.is_taya and player.has_thrower_special():
			player.set_skill_charge(player.skill_charge + room.practice_hits - last_hits)
		last_hits = room.practice_hits
	if free_mode:
		return
	if lesson_complete:
		return
	var distance: float = player.global_position.distance_to(last_position)
	if distance < 80.0:
		travel += distance
	last_position = player.global_position
	match lesson:
		Lesson.MOVE:
			if TOE_LINE.has_point(player.global_position) and travel > 120.0: _complete()
		Lesson.SPRINT:
			if Input.is_action_pressed("sprint") and Input.get_vector("left", "right", "up", "down").length() > 0.1 and player.velocity.length() > player.walk_speed * 0.9:
				sprint_time += delta
			if sprint_time >= 0.7: _complete()
		Lesson.HIT:
			if room.practice_hits > 0: _complete()
		Lesson.RETRIEVE:
			if picked_up: _complete()
		Lesson.RETURN:
			if TOE_LINE.has_point(player.global_position): _complete()
		Lesson.ORBS:
			if player.skill_charge == 3: _complete()
		Lesson.ARM:
			if player.special_armed: _complete()
		Lesson.SPECIAL:
			if special_launched: _complete()
		Lesson.PICKUP:
			if player.carrying_can: _complete()
		Lesson.RESET_CAN:
			if room.practice_cans[0].is_standing() and not player.carrying_can: _complete()
		Lesson.LUNGE:
			if player.taya_action == &"lunge": _complete()
		Lesson.TAG:
			if tagged: _complete()
		Lesson.STUN:
			if is_instance_valid(dummy) and dummy.is_stunned(): _complete()
			elif not is_instance_valid(player.taya_stun_projectile) and player.taya_stun_ready_at > LanSession.clock_time():
				# A missed training shot can be retried without the match cooldown.
				player.taya_stun_ready_at = 0.0
	if not lesson_complete:
		_update_feedback()


func restart() -> void:
	player = room.actors.get(LanSession.local_id())
	if not is_instance_valid(player):
		return
	free_mode = false
	room.stage = "waiting"
	if is_instance_valid(dummy): dummy.queue_free()
	dummy = null
	if is_instance_valid(player.active_slipper): player.active_slipper.queue_free()
	if is_instance_valid(player.taya_stun_projectile): player.taya_stun_projectile.queue_free()
	for shot in player.rapid_slippers:
		if is_instance_valid(shot): shot.queue_free()
	player.active_slipper = null
	player.taya_stun_projectile = null
	player.rapid_slippers.clear()
	player.rapid_remaining = 0
	player.set_taya_role(false)
	player.can_node = room.practice_cans[0]
	player.require_standing_can = false
	player.allowed_throw_rect = TOE_LINE
	player.safe_strip_rect = TOE_LINE
	player.taya_stun_ready_at = 0.0
	player.next_lunge_time = 0.0
	player.position = Vector2(1190, 575)
	player.facing = Vector2.LEFT
	player.velocity = Vector2.ZERO
	player.set_skill_charge(0)
	for index in range(room.practice_cans.size()):
		var can: CharacterBody2D = room.practice_cans[index]
		can.show()
		can.collision_layer = 4
		can.auto_stand_up = true
		can.base.global_position = room.practice_origins[index]
		can.reset_for_preview(room.practice_origins[index])
	room.practice_hits = 0
	room.get_node("HUD/Screen/PracticeHits").text = "0 HITS"
	last_hits = 0
	tracked_slipper = null
	picked_up = false
	tagged = false
	special_launched = false
	travel = 0.0
	sprint_time = 0.0
	last_position = player.global_position
	line_art.show()
	base_art.hide()
	panel.show()
	_set_lesson(Lesson.MOVE)


func _complete() -> void:
	lesson_complete = true
	if lesson == Lesson.RESET_CAN:
		# Automatic reset happens under Taya's feet; reveal the can on its base.
		player.global_position = room.practice_cans[0].base.global_position + Vector2(125, 60)
		player.velocity = Vector2.ZERO
	feedback.text = "NICE WORK! Press Continue when you're ready."
	continue_button.show()
	continue_button.grab_focus()


func _continue_lesson() -> void:
	if not lesson_complete or lesson == Lesson.DONE:
		return
	if lesson == Lesson.RETURN and not player.has_thrower_special() or lesson == Lesson.SPECIAL:
		_enter_taya()
	elif lesson == Lesson.RESET_CAN:
		_prepare_tag_drill()
		_set_lesson(Lesson.LUNGE)
	elif lesson == Lesson.TAG:
		_prepare_stun_drill()
		_set_lesson(Lesson.STUN)
	else:
		_set_lesson(lesson + 1)


func _set_lesson(next_lesson: int) -> void:
	lesson = next_lesson
	lesson_complete = false
	continue_button.hide()
	continue_button.text = "Try Taya" if lesson == Lesson.RETURN and not player.has_thrower_special() or lesson == Lesson.SPECIAL else "Continue"
	var titles := ["FIND THE TOE LINE", "PICK UP THE PACE", "KNOCK DOWN A CAN", "GET YOUR SLIPPER BACK", "RETURN TO SAFETY", "FILL THE THREE ORBS", "ARM YOUR SPECIAL", "LAUNCH YOUR SPECIAL", "RECOVER THE CAN", "GUARD THE BASE", "LUNGE FORWARD", "TAG THE THROWER", "STUN WITH A SLIPPER", "READY FOR A MATCH!"]
	var directions := [
		"Walk into the blue training strip. Arrow keys also work.",
		"Hold while moving. A short sprint is enough.",
		"From the blue strip, aim at a can. Hold to charge, then release near the green mark.",
		"Run over your landed slipper to pick it up. Only its owner can collect it.",
		"Cross back into the blue strip. In a match, retrieving and returning safely earns a point.",
		"Hit cans two more times. Each confirmed hit fills one orb. Retrieve your slipper between throws.",
		"With three glowing orbs, press to arm your character's special throw.",
		"Hold and release to launch the armed special. The three orbs are spent on launch.",
		"You are Taya now. Walk to the fallen can; you pick it up automatically. You cannot tag until it stands again.",
		"Carry the can back to its yellow ground marker. It stands up automatically at the base.",
		"Face the practice thrower, then press to lunge in that direction.",
		"Touch the thrower while the can stands to tag them. A lunge can also reach them.",
		"Hold to aim Taya's stun slipper, then release toward the thrower. In a match it has a 120-second cooldown.",
		"You learned both roles. Practice freely, restart, or leave for a real match."
	]
	var has_special: bool = player.has_thrower_special()
	var number: int = lesson + 1 if has_special or lesson < Lesson.PICKUP else lesson - 2
	progress.text = "%s  •  %d / %d" % ["THROWER" if lesson <= Lesson.SPECIAL else "TAYA", number, 13 if has_special else 10] if lesson != Lesson.DONE else "TUTORIAL COMPLETE"
	heading.text = titles[lesson]
	instruction.text = directions[lesson]
	var hints := ["WASD", "SHIFT", "left_mouse", "WASD", "WASD", "left_mouse", "right_mouse", "left_mouse", "WASD", "WASD", "SPACE", "WASD", "right_mouse", ""]
	control_icon.kind = hints[lesson]
	control_icon.queue_redraw()
	control_hint.visible = hints[lesson] != ""
	control_caption.text = "LEFT CLICK" if hints[lesson] == "left_mouse" else "RIGHT CLICK" if hints[lesson] == "right_mouse" else "MOVE" if hints[lesson] == "WASD" else "SPRINT" if hints[lesson] == "SHIFT" else "LUNGE" if hints[lesson] == "SPACE" else ""
	if UserSettings.active_mode() == "controller":
		control_icon.hide()
		var action := "throw" if hints[lesson] == "left_mouse" else "special" if hints[lesson] == "right_mouse" else "sprint" if hints[lesson] == "SHIFT" else "lunge" if hints[lesson] == "SPACE" else ""
		control_caption.text = UserSettings.short_binding_text(action) if not action.is_empty() else "LEFT STICK" if hints[lesson] == "WASD" else ""
	else:
		control_icon.show()
	free_button.text = "Free practice" if lesson != Lesson.DONE else "Keep practicing"
	_update_feedback()


func _enter_taya() -> void:
	room.stage = "active" # The shared Taya stun projectile checks the active phase.
	line_art.hide()
	base_art.show()
	if is_instance_valid(player.active_slipper): player.active_slipper.queue_free()
	player.active_slipper = null
	for shot in player.rapid_slippers:
		if is_instance_valid(shot): shot.queue_free()
	player.rapid_slippers.clear()
	player.rapid_remaining = 0
	for index in range(1, room.practice_cans.size()):
		room.practice_cans[index].hide()
		room.practice_cans[index].collision_layer = 0
	var can: CharacterBody2D = room.practice_cans[0]
	can.auto_stand_up = false
	# Thrower practice lets cans stand up where they land and moves their base.
	# Restore the fixed Taya target so the reset and yellow marker agree.
	can.base.global_position = room.practice_origins[0]
	can.reset_for_preview(room.practice_origins[0])
	can.topple()
	can.global_position = Vector2(640, 575)
	can.velocity = Vector2.ZERO
	player.can_node = can
	player.require_standing_can = true
	player.allowed_throw_rect = Rect2()
	player.safe_strip_rect = Rect2()
	player.set_taya_role(true)
	player.tag_ready_at = 0.0
	player.position = Vector2(1040, 575)
	player.facing = Vector2.LEFT
	player.velocity = Vector2.ZERO
	if not player.tag_requested.is_connected(_on_tag_requested):
		player.tag_requested.connect(_on_tag_requested)
	_set_lesson(Lesson.PICKUP)


func _prepare_tag_drill() -> void:
	if not is_instance_valid(dummy):
		dummy = DUMMY_SCENE.instantiate() as CharacterBody2D
		dummy.name = "PracticeThrower"
		dummy.scale = Vector2.ONE * room.player_scale
		dummy.network_controlled = true
		dummy.accept_local_input = false
		dummy.show_gameplay_overlays = false
		room.add_child(dummy)
		var nameplate := UI.label("PRACTICE THROWER", 24)
		nameplate.position = Vector2(-165, -260)
		nameplate.size = Vector2(330, 42)
		dummy.add_child(nameplate)
	dummy.position = Vector2(570, 575)
	player.position = Vector2(355, 575)
	player.facing = Vector2.RIGHT
	player.next_lunge_time = 0.0
	player.tag_ready_at = 0.0
	player.last_tagged_target = null
	tagged = false


func _prepare_stun_drill() -> void:
	# Contact can happen mid-lunge; clear that action before the next drill.
	player.set_taya_role(true)
	dummy.position = Vector2(650, 575)
	dummy.stun_immune_until = 0.0
	player.position = Vector2(355, 575)
	player.facing = Vector2.RIGHT
	player.taya_stun_ready_at = 0.0
	player.last_tagged_target = null


func _on_tag_requested(target: Node2D) -> void:
	if target == dummy and lesson in [Lesson.LUNGE, Lesson.TAG]:
		tagged = true


func _track_slipper() -> void:
	var slipper: Node2D = player.active_slipper
	if not is_instance_valid(slipper) or slipper == tracked_slipper:
		return
	tracked_slipper = slipper
	if not slipper.picked_up.is_connected(_on_slipper_picked_up):
		slipper.picked_up.connect(_on_slipper_picked_up)


func _on_slipper_picked_up() -> void:
	picked_up = true


func _update_feedback() -> void:
	if lesson < 0:
		return
	var message := ""
	if lesson <= Lesson.SPECIAL:
		message = "%d CAN HITS  •  %d / 3 ORBS" % [room.practice_hits, player.skill_charge] if player.has_thrower_special() else "%d CAN HITS" % room.practice_hits
		if lesson in [Lesson.HIT, Lesson.ORBS, Lesson.SPECIAL] and is_instance_valid(player.active_slipper):
			message += "  •  COLLECT YOUR SLIPPER BEFORE THROWING AGAIN"
		elif lesson == Lesson.RETRIEVE and not is_instance_valid(player.active_slipper) and not picked_up:
			message += "  •  THROW AGAIN, THEN COLLECT THE LANDED SLIPPER"
	else:
		message = "CAN: %s" % ["CARRIED" if player.carrying_can else "STANDING" if room.practice_cans[0].is_standing() else "TOPPLED"]
	feedback.text = message


func _free_practice() -> void:
	free_mode = true
	panel.hide()
	line_art.hide()
	base_art.visible = player.is_taya
	player.allowed_throw_rect = Rect2()
	player.safe_strip_rect = Rect2()
	player.require_standing_can = false


func _build_line() -> void:
	line_art = Node2D.new()
	line_art.name = "TrainingToeLine"
	room.get_node("Background").add_child(line_art)
	var strip := Polygon2D.new()
	strip.polygon = PackedVector2Array([TOE_LINE.position, Vector2(TOE_LINE.end.x, TOE_LINE.position.y), TOE_LINE.end, Vector2(TOE_LINE.position.x, TOE_LINE.end.y)])
	strip.color = Color(0.08, 0.7, 1.0, 0.25)
	line_art.add_child(strip)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(TOE_LINE.position.x, TOE_LINE.position.y), Vector2(TOE_LINE.position.x, TOE_LINE.end.y)])
	edge.width = 7.0
	edge.default_color = Color("71deff")
	line_art.add_child(edge)


func _build_base_marker() -> void:
	base_art = Node2D.new()
	base_art.name = "TrainingCanBase"
	base_art.position = room.practice_origins[0]
	room.get_node("Background").add_child(base_art)
	var points := PackedVector2Array()
	for index in range(33):
		var angle: float = float(index) * TAU / 32.0
		# The can's visible body sits above its physical ground point.
		points.append(Vector2(cos(angle) * 59.0, sin(angle) * 49.0 - 22.0))
	var dark := Line2D.new()
	dark.points = points
	dark.width = 12.0
	dark.default_color = Color("51301b")
	base_art.add_child(dark)
	var gold := Line2D.new()
	gold.points = points
	gold.width = 6.0
	gold.default_color = Color("ffdb67")
	base_art.add_child(gold)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "TutorialGuide"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = 22
	panel.add_theme_stylebox_override("panel", UI.panel(Color("a94d16"), 6))
	panel.theme = UI.theme()
	room.get_node("HUD/Screen").add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	panel.add_child(stack)
	progress = UI.label("", 18)
	progress.add_theme_color_override("font_color", Color("ffe5a4"))
	stack.add_child(progress)
	heading = UI.label("", 34)
	stack.add_child(heading)
	instruction = UI.label("", 24)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size = Vector2(850, 70)
	stack.add_child(instruction)
	control_hint = HBoxContainer.new()
	control_hint.alignment = BoxContainer.ALIGNMENT_CENTER
	control_hint.add_theme_constant_override("separation", 12)
	stack.add_child(control_hint)
	control_icon = InputIcon.new()
	control_icon.custom_minimum_size = Vector2(72, 46)
	control_hint.add_child(control_icon)
	control_caption = UI.label("", 21)
	control_caption.add_theme_color_override("font_color", Color("ffe5a4"))
	control_hint.add_child(control_caption)
	feedback = UI.label("", 19)
	feedback.add_theme_color_override("font_color", Color("ffe5a4"))
	stack.add_child(feedback)
	continue_button = UI.button("Continue", _continue_lesson)
	continue_button.custom_minimum_size = Vector2(250, 50)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.add_theme_font_size_override("font_size", 21)
	continue_button.hide()
	stack.add_child(continue_button)
	free_button = UI.button("Free practice", _free_practice)
	free_button.custom_minimum_size = Vector2(250, 50)
	free_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	free_button.add_theme_font_size_override("font_size", 21)
	stack.add_child(free_button)
