extends "res://game/network_world.gd"

const UI = preload("res://ui/game_ui.gd")
const CATALOG = preload("res://game/maps/map_catalog.gd")
const RULES := "Move: WASD / arrows. Shift sprints.\nThrow ONLY from the blue area. Hold left-click, then release in the tiny GREEN window for full power.\nOrange is weaker; red is inaccurate. Retrieve YOUR colored slipper and return to blue for a point.\n\nOne random player becomes Taya. Throwers wait 7 seconds while Taya prepares.\nTaya cannot enter blue or tag protected throwers. Tags work ONLY while the can stands. Space lunges (10s cooldown).\nWhen the can falls, Taya uses E to pick it up, carries it to its original circle, then uses E to place it.\n\nEarn +1 for a can hit, safe return, Taya tag, or a thrower's miss while you are Taya.\nPlay for 10 minutes. Highest score wins; ties share victory."
const ARENA := Rect2(253, 220, 1350, 785)
# Cover the visible floor to the fence/curb, not only the inset movement bounds.
const SAFE := Rect2(140, 0, 390, 1040)
const PREPARATION_SECONDS := 7.0
const MATCH_SECONDS := 600.0
const CAN_START := Vector2(1450, 610)
const TAYA_START := CAN_START + Vector2(-180, 0)

var stage := "tutorial"
var remaining := 7.0
var phase_deadline := 0.0
var opening_label: Label
var match_camera: Camera2D
var scores: Dictionary = {}
var taya_id := 0
var tag_immunity := 0.0
var acknowledgment_clock := 0.0
var tutorial_open := false
var can: CharacterBody2D
var phase_label: Label
var score_label: Label
var notice_label: Label
var notice_remaining := 0.0

func _ready() -> void:
	if LanSession.players.is_empty():
		LanSession.begin_local("developer")
		LanSession.players[0].ready = true
		LanSession.add_developer_bots()
	LanSession.phase = "match"
	var level: Node2D = load("res://level/basketball_court.tscn").instantiate()
	level.get_node("World/PlayerMovementNeutral").free()
	level.get_node("Camera2D").free()
	# Sort players and props together by their feet; keep only floor art behind them.
	level.y_sort_enabled = true
	for layer in ["Backdrop", "Ground", "Decals"]:
		level.get_node(layer).z_index = -10
	level.get_node("World/FenceLayer").y_sort_enabled = true
	level.get_node("World/World Border").collision_layer = 16
	# Match spawns and ARENA use the established court bounds.
	level.get_node("World/World Border").position = Vector2.ZERO
	CATALOG.configure(level, LanSession.selected_map)
	add_child(level)
	var base := Node2D.new()
	base.name = "CanBase"
	base.position = CAN_START
	add_child(base)
	can = load("res://scenes/Taya can.tscn").instantiate()
	can.name = "Can"
	can.position = base.position
	can.starts_toppled = false
	can.auto_stand_up = false
	can.show_target_ring = true
	can.base_path = NodePath("../CanBase")
	can.collision_mask = 1 | 16
	add_child(can)
	setup_network_world()
	LanSession.match_event_received.connect(_match_event)
	_build_hud()
	_build_camera()
	if not UserSettings.tutorial_seen:
		_show_rules(true)
	else:
		LanSession.acknowledge_tutorial()
	queue_redraw()

func _spawn_point(slot: int) -> Vector2:
	return Vector2(420, 360 + slot * 145)

func _sync_actors() -> void:
	super._sync_actors()
	if LanSession.is_host() and stage in ["preparation", "active"] and taya_id != 0 and not actors.has(taya_id) and not actors.is_empty():
		taya_id = int(LanSession.players[0].id)
		var replacement: CharacterBody2D = actors[taya_id]
		if is_instance_valid(replacement.active_slipper):
			replacement.active_slipper.queue_free()
		replacement.active_slipper = null
		replacement.set_meta("returning", false)
		replacement.position = TAYA_START
		replacement.set_taya_role(true)
		can.reset_for_preview(can.base.position)
		tag_immunity = 1.0
		if notice_label != null:
			_notice("%s TAKES OVER AS TAYA" % LanSession.member(taya_id).name)

func _actor_added(actor: CharacterBody2D) -> void:
	actor.can_node = can
	actor.safe_strip_rect = SAFE
	actor.allowed_throw_rect = SAFE
	actor.throw_speed_multiplier = 1.45
	actor.taya_min_x = SAFE.end.x + 1.0
	actor.arena_bounds = ARENA
	actor.tag_requested.connect(_tag_requested.bind(actor))
	scores[actor.get_meta("peer_id")] = 0

func _world_inputs_enabled() -> bool:
	return stage in ["preparation", "active"]

func _actor_inputs_enabled(actor: CharacterBody2D) -> bool:
	return stage == "active" or (stage == "preparation" and actor.is_taya)

func _local_inputs_enabled() -> bool:
	return _world_inputs_enabled() and not tutorial_open

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	notice_remaining = maxf(0.0, notice_remaining - delta)
	if notice_label != null and notice_remaining == 0.0:
		notice_label.text = ""
	if not LanSession.is_host():
		if stage == "tutorial" and not tutorial_open:
			acknowledgment_clock += delta
			if acknowledgment_clock >= 1.0:
				acknowledgment_clock = 0.0
				LanSession.acknowledge_tutorial()
		if stage in ["preparation", "active"]:
			remaining = clampf(phase_deadline - LanSession.clock_time(), 0.0, PREPARATION_SECONDS if stage == "preparation" else MATCH_SECONDS)
		_update_hud()
		return
	tag_immunity = maxf(0.0, tag_immunity - delta)
	if stage == "tutorial" and LanSession.humans_ready_for_match():
		_start_preparation()
	elif stage == "preparation":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			_start_scoring()
	elif stage == "active":
		remaining = maxf(0.0, remaining - delta)
		for actor in actors.values():
			if actor.get_meta("returning", false) and not SAFE.has_point(actor.global_position):
				actor.set_meta("left_safe", true)
			if is_instance_valid(actor.active_slipper):
				var slipper: Node2D = actor.active_slipper
				if not slipper.get_meta("outcome", false) and (slipper.is_resting() or slipper.lost_remaining > 0.0):
					slipper.set_meta("outcome", true)
					if not slipper.hit_registered and taya_id != 0:
						_add_point(taya_id)
			elif actor.get_meta("returning", false) and actor.get_meta("left_safe", false) and actor.get_meta("retrieved", false) and not actor.is_taya and SAFE.has_point(actor.global_position):
				actor.set_meta("returning", false)
				_add_point(actor.get_meta("peer_id"))
		if remaining <= 0.0:
			_finish()
	_update_hud()

func _start_preparation() -> void:
	stage = "preparation"
	remaining = PREPARATION_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	can.reset_for_preview(can.base.position)
	taya_id = int(LanSession.players.pick_random().id)
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		if is_instance_valid(actor.active_slipper): actor.active_slipper.queue_free()
		actor.active_slipper = null
		actor.position = TAYA_START if id == taya_id else _spawn_point(LanSession.member(id).slot)
		actor.set_taya_role(id == taya_id)
		actor.set_meta("returning", false)
		actor.network_input = {}
		actor.network_edges.clear()
		actor.accept_local_input = id == taya_id

func _start_scoring() -> void:
	if taya_id == 0: _start_preparation()
	stage = "active"
	remaining = MATCH_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	_notice("THROW!")

func _slipper_spawned(actor: CharacterBody2D, slipper: Node2D) -> void:
	if stage == "active":
		actor.set_meta("returning", true)
		actor.set_meta("left_safe", not SAFE.has_point(actor.global_position))
		actor.set_meta("retrieved", false)
	slipper.can_hit.connect(_can_hit.bind(actor, slipper))
	slipper.picked_up.connect(func() -> void:
		actor.set_meta("retrieved", true)
		if stage == "active" and not slipper.get_meta("outcome", false):
			slipper.set_meta("outcome", true)
			if not slipper.hit_registered and taya_id != 0:
				_add_point(taya_id)
	)
	slipper.returned_after_penalty.connect(func() -> void: actor.set_meta("returning", false))

func _can_hit(_target: Node2D, actor: CharacterBody2D, slipper: Node2D) -> void:
	if stage != "active":
		return
	slipper.set_meta("outcome", true)
	var id: int = actor.get_meta("peer_id")
	_add_point(id)
	LanSession.publish_event({"kind": "hit", "player": id, "match_id": LanSession.match_id})
	_notice("%s KNOCKED DOWN THE CAN!" % LanSession.member(id).get("name", "Player"))

func _tag_requested(thrower: Node2D, guard: CharacterBody2D) -> void:
	if not LanSession.is_host() or stage != "active" or tag_immunity > 0.0 or not guard.can_tag() or thrower.is_taya or SAFE.has_point(thrower.global_position):
		return
	var guard_id: int = guard.get_meta("peer_id")
	_add_point(guard_id)
	guard.flash_hit()
	thrower.flash_hit()
	# Separate bodies along the court before transferring roles; neither player is stunned.
	var away: Vector2 = thrower.global_position - guard.global_position
	if away.is_zero_approx(): away = guard.facing
	var gap: float = guard.PLAYER_CLEARANCE * maxf(guard.scale.x, thrower.scale.x) + 8.0
	if away.length() < gap:
		# Ignore only the tagging partner while separating; scenery still blocks movement.
		thrower.add_collision_exception_with(guard)
		guard.add_collision_exception_with(thrower)
		var direction := away.normalized()
		thrower.move_and_collide(direction * (gap - away.length()))
		var remaining_gap := gap - thrower.global_position.distance_to(guard.global_position)
		if remaining_gap > 0.0:
			guard.move_and_collide(-direction * remaining_gap)
		thrower.remove_collision_exception_with(guard)
		guard.remove_collision_exception_with(thrower)
	guard.set_taya_role(false)
	if is_instance_valid(thrower.active_slipper):
		thrower.active_slipper.queue_free()
	thrower.active_slipper = null
	thrower.set_taya_role(true)
	thrower.set_meta("returning", false)
	taya_id = thrower.get_meta("peer_id")
	tag_immunity = 1.0
	_notice("%s IS NOW TAYA" % LanSession.member(taya_id).get("name", "Player"))

func _add_point(id: int) -> void:
	scores[id] = int(scores.get(id, 0)) + 1

func _match_event(event: Dictionary) -> void:
	if event.get("kind") == "hit" and event.get("player") == LanSession.local_id() and event.get("match_id") == LanSession.match_id and LanSession.mode in ["lan", "online"]:
		UserSettings.record_hit()

func _finish() -> void:
	if stage != "active":
		return
	stage = "finished"
	var rankings: Array = []
	for member in LanSession.players:
		rankings.append({"id": member.id, "name": member.name, "score": scores.get(member.id, 0), "color": member.color, "character": member.character})
	rankings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.score > b.score if a.score != b.score else a.id < b.id)
	LanSession.finish_match(rankings)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 4
	add_child(hud)
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.theme = UI.theme()
	hud.add_child(screen)
	phase_label = UI.label("WAITING FOR PLAYERS TO READ THE RULES", 30)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_label.position = Vector2(-650, 35)
	phase_label.size = Vector2(1300, 60)
	screen.add_child(phase_label)
	var score_panel := PanelContainer.new()
	score_panel.position = Vector2(25, 145)
	score_panel.custom_minimum_size = Vector2(215, 0)
	score_panel.add_theme_stylebox_override("panel", UI.panel())
	screen.add_child(score_panel)
	score_label = UI.label("", 19)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	score_panel.add_child(score_label)
	notice_label = UI.label("", 30)
	notice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	notice_label.position = Vector2(-700, -65)
	notice_label.size = Vector2(1400, 50)
	screen.add_child(notice_label)
	opening_label = UI.label("", 48)
	opening_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	opening_label.position = Vector2(-700, -100)
	opening_label.size = Vector2(1400, 200)
	screen.add_child(opening_label)
	var rules_button := UI.button("Rules", func() -> void: _show_rules(false))
	rules_button.position = Vector2(1675, 28)
	screen.add_child(rules_button)
	var leave := UI.button("Leave", _leave_match)
	leave.position = Vector2(25, 28)
	screen.add_child(leave)

func _show_rules(first_time: bool) -> void:
	tutorial_open = true
	var view = UI.modal(self, "HOW TO PLAY", RULES)
	view.content.add_child(UI.button("Got it, let's play" if first_time else "Back to game", func() -> void:
		tutorial_open = false
		if first_time:
			UserSettings.tutorial_seen = true
			UserSettings.save_profile()
		LanSession.acknowledge_tutorial()
		view.layer.queue_free()
	))

func _update_hud() -> void:
	if phase_label == null:
		return
	var time_text := "%d:%02d" % [int(ceil(remaining)) / 60, int(ceil(remaining)) % 60]
	phase_label.text = "WAITING FOR PLAYERS TO READ THE RULES" if stage == "tutorial" else "TAYA PREPARATION  " + time_text if stage == "preparation" else "MATCH  " + time_text
	if opening_label != null:
		opening_label.text = "%s IS TAYA\n%d" % [LanSession.member(taya_id).get("name", "Player"), ceili(remaining)] if stage == "preparation" else "THROW!" if stage == "active" and remaining > MATCH_SECONDS - 2.0 else ""
	var text: String = CATALOG.MAPS[LanSession.selected_map].name + "\n\n"
	for member in LanSession.players:
		text += "%s  %d%s\n\n" % [str(member.name).left(12), scores.get(member.id, 0), "  TAYA" if member.id == taya_id else ""]
	if LanSession.mode == "developer":
		text += "DEVELOPER\nSTATS OFF"
	score_label.text = text.strip_edges()

func _notice(message: String) -> void:
	notice_label.text = message
	notice_remaining = 2.0

func _extra_snapshot() -> Dictionary:
	return {"stage": stage, "remaining": remaining, "deadline": phase_deadline, "scores": scores, "taya": taya_id, "notice": notice_label.text if notice_label != null else ""}

func _apply_extra_snapshot(data: Dictionary) -> void:
	stage = data.get("stage", stage)
	phase_deadline = float(data.get("deadline", phase_deadline))
	remaining = clampf(phase_deadline - LanSession.clock_time(), 0.0, PREPARATION_SECONDS if stage == "preparation" else MATCH_SECONDS) if stage in ["preparation", "active"] else float(data.get("remaining", remaining))
	scores = data.get("scores", scores)
	taya_id = data.get("taya", taya_id)
	if notice_label != null:
		notice_label.text = data.get("notice", "")

func _leave_match() -> void:
	LanSession.close_room()
	get_tree().change_scene_to_file("res://ui/main_menu/main_menuu.tscn")

func _draw() -> void:
	if is_instance_valid(can) and can.base != null:
		draw_arc(can.base.position + Vector2(0, -27), 48.0, 0, TAU, 48, Color("fff5dc"), 3.0, true)
	draw_rect(SAFE, Color(0.1, 0.48, 0.9, 0.14))
	draw_line(Vector2(SAFE.end.x, SAFE.position.y), Vector2(SAFE.end.x, SAFE.end.y), Color("80c9ff"), 5.0)


func _build_camera() -> void:
	match_camera = Camera2D.new()
	match_camera.zoom = Vector2.ONE * 0.9
	match_camera.position = ARENA.get_center()
	add_child(match_camera)
	_update_camera(1.0)
	match_camera.reset_smoothing()

func _process(delta: float) -> void:
	_update_camera(delta)

func _update_camera(delta: float) -> void:
	if match_camera == null or can == null: return
	var actor: Node2D = actors.get(LanSession.local_id())
	if actor == null: return
	var focus := (actor.global_position + can.global_position) * 0.5
	var span := (actor.global_position - can.global_position).abs() + Vector2(320, 480)
	var viewport_size := get_viewport_rect().size
	var target_zoom := minf(0.9, minf(viewport_size.x / span.x, viewport_size.y / span.y))
	var weight := 1.0 - exp(-delta / 0.15)
	match_camera.position = match_camera.position.lerp(focus - Vector2(0, 65), weight)
	# Widen immediately to keep both subjects visible, ease the return to baseline.
	var zoom_value := minf(target_zoom, lerpf(match_camera.zoom.x, target_zoom, weight))
	match_camera.zoom = Vector2.ONE * zoom_value
