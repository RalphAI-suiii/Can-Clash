extends "res://game/network_world.gd"

const UI = preload("res://ui/game_ui.gd")
const CATALOG = preload("res://game/maps/map_catalog.gd")
const TAG_BURST = preload("res://game/match/tag_burst.gd")
const SCOREBOARD = preload("res://game/match/scoreboard.gd")
# Inner fence edges; shared by slipper limits and camera framing.
const ARENA := Rect2(153, 49, 1568, 1023)
# Cover the visible floor to the fence/curb, not only the inset movement bounds.
const SAFE := Rect2(140, 0, 390, 1072)
const PREPARATION_SECONDS := 7.0
const MATCH_SECONDS := 600.0
const INTRO_SECONDS := 2.8
const RUN_TO_LINE_SECONDS := 5.0
const THROW_OFF_SECONDS := 26.0
const RESULT_SECONDS := 3.5
const TAG_NOTICE_SECONDS := 2.6
const CAN_START := Vector2(1450, 610)
const TAYA_START := CAN_START + Vector2(-180, 0)

var stage := "loading"
var remaining := 7.0
var phase_deadline := 0.0
var opening_label: Label
var match_camera: Camera2D
var scores: Dictionary = {}
var taya_id := 0
var tag_immunity := 0.0
var acknowledgment_clock := 0.0
var can: CharacterBody2D
var phase_label: Label
var score_panel: PanelContainer
var scoreboard
var notice_label: Label
var notice_remaining := 0.0
var tag_notice_id := 0
var tag_notice_until := 0.0
var tag_notice_serial := 0
var tag_notice_position := Vector2.ZERO
var tag_shade: ColorRect
var tag_panel: PanelContainer
var tag_title: Label
var throwoff_distances: Dictionary = {}
var throwoff_last_shot_at := 0.0
var intro_shade: ColorRect
var intro_title: Label
var result_panel: PanelContainer
var result_portrait: TextureRect
var result_title: Label
var result_character: Label
var camera_slipper: Node2D
var camera_landing_point := Vector2.ZERO
var camera_return_at := 0.0
var camera_following_slipper := false

func _ready() -> void:
	Music.play_music("lobby")
	if LanSession.players.is_empty():
		LanSession.begin_local("developer")
		LanSession.players[0].character = 0
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
	# Keep the authored fence-aligned border at the World origin.
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
	LanSession.skill_requested.connect(_skill_requested)
	_build_hud()
	_build_camera()
	# Automatically acknowledge scene loading; no rules dialog gates the match.
	LanSession.acknowledge_tutorial()
	queue_redraw()

func _spawn_point(slot: int) -> Vector2:
	return Vector2(940 + (slot % 2) * 130, 510 + slot * 50)

func _line_point(slot: int) -> Vector2:
	return Vector2(465, 330 + slot * 145)

func _sync_actors() -> void:
	super._sync_actors()
	for id in throwoff_distances.keys():
		if not actors.has(id): throwoff_distances.erase(id)
	if stage == "throw_off_result" and not actors.has(taya_id) and not actors.is_empty():
		taya_id = int(actors.keys()[0])
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
			_announce_new_taya(taya_id, replacement.global_position)

func _actor_added(actor: CharacterBody2D) -> void:
	actor.can_node = can
	actor.require_standing_can = true
	actor.safe_strip_rect = SAFE
	actor.allowed_throw_rect = SAFE
	actor.throw_speed_multiplier = 1.45
	actor.taya_min_x = SAFE.end.x + 1.0
	actor.arena_bounds = ARENA
	actor.tag_requested.connect(_tag_requested.bind(actor))
	scores[actor.get_meta("peer_id")] = 0

func _world_inputs_enabled() -> bool:
	return stage in ["throw_off", "preparation", "active"]

func _actor_inputs_enabled(actor: CharacterBody2D) -> bool:
	return stage == "active" or (stage == "preparation" and actor.is_taya) or (stage == "throw_off" and (remaining > 0.0 or actor.attack_state == actor.AttackState.THROWING or is_instance_valid(actor.active_slipper)))

func _update_bot(actor: CharacterBody2D) -> void:
	if stage != "throw_off":
		super._update_bot(actor)
		return
	var slot: int = int(LanSession.member(actor.get_meta("peer_id")).get("slot", 0))
	var aim := CAN_START + Vector2(0, (slot - 2) * 110.0)
	var throwing: bool = actor.attack_state != actor.AttackState.CHARGING or actor.charge_bar.value < float(actor.get_meta("bot_release_at", actor.sweet_spot))
	actor.apply_network_input({"move": Vector2.ZERO, "aim": aim, "throw": throwing, "sprint": false, "interact": false, "lunge": false})

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	notice_remaining = maxf(0.0, notice_remaining - delta)
	if notice_label != null and notice_remaining == 0.0:
		notice_label.text = ""
	if not LanSession.is_host():
		if stage == "loading":
			acknowledgment_clock += delta
			if acknowledgment_clock >= 1.0:
				acknowledgment_clock = 0.0
				LanSession.acknowledge_tutorial()
		if stage in ["intro", "run_to_line", "throw_off", "throw_off_result", "preparation", "active"]:
			remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		_update_hud()
		return
	tag_immunity = maxf(0.0, tag_immunity - delta)
	if stage == "loading" and LanSession.humans_ready_for_match():
		_start_intro()
	elif stage == "intro":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		if remaining <= 0.0:
			_start_run_to_line()
	elif stage == "run_to_line":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		var all_arrived := true
		for id in actors:
			var actor: CharacterBody2D = actors[id]
			var slot: int = int(LanSession.member(id).slot)
			var target := _line_point(slot)
			# Cross the clear middle lane, then fan out before reaching the toe-line.
			if actor.position.x > 610.0:
				target = Vector2(600.0, _spawn_point(slot).y)
			var offset: Vector2 = target - actor.position
			if offset.length() > 12.0:
				all_arrived = false
				actor.velocity = actor.get_meta("intro_velocity", Vector2.ZERO)
				actor.move_from_input(delta, offset.normalized(), true, true, true)
				actor.set_meta("intro_velocity", actor.velocity)
			else:
				actor.set_meta("intro_velocity", Vector2.ZERO)
				actor._play("idle", actor.facing)
		if all_arrived or remaining <= 0.0:
			_start_throw_off()
	elif stage == "throw_off":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		_update_throw_off()
		if remaining <= 0.0:
			for actor in actors.values():
				if actor.attack_state == actor.AttackState.CHARGING and not is_instance_valid(actor.active_slipper):
					actor.set_taya_role(false)
		if (throwoff_distances.size() == actors.size() and LanSession.clock_time() - throwoff_last_shot_at >= 1.2) or (remaining <= 0.0 and LanSession.clock_time() >= phase_deadline + 6.0):
			_finish_throw_off()
	elif stage == "throw_off_result":
		remaining = maxf(0.0, phase_deadline - LanSession.clock_time())
		if remaining <= 0.0:
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
			if actor.get_meta("rapid_complete", false):
				actor.set_meta("rapid_complete", false)
				if not actor.is_taya:
					actor.set_meta("retrieved", true)
					if not actor.get_meta("rapid_hit", false) and taya_id != 0:
						_add_point(taya_id)
			if is_instance_valid(actor.active_slipper):
				var slipper: Node2D = actor.active_slipper
				if slipper.special_kind != &"rapid" and not slipper.get_meta("outcome", false) and (slipper.is_resting() or slipper.lost_remaining > 0.0):
					slipper.set_meta("outcome", true)
					if not slipper.hit_registered and taya_id != 0:
						_add_point(taya_id)
			elif actor.get_meta("returning", false) and actor.get_meta("left_safe", false) and actor.get_meta("retrieved", false) and not actor.is_taya and SAFE.has_point(actor.global_position):
				actor.set_meta("returning", false)
				_add_point(actor.get_meta("peer_id"))
		if remaining <= 0.0:
			_finish()
	_update_hud()

func _start_intro() -> void:
	stage = "intro"
	remaining = INTRO_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	throwoff_distances.clear()
	taya_id = 0
	can.reset_for_preview(can.base.position)
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		if is_instance_valid(actor.active_slipper): actor.active_slipper.queue_free()
		actor.active_slipper = null
		actor.set_taya_role(false)
		actor.position = _spawn_point(int(LanSession.member(id).slot))
		actor.facing = Vector2.LEFT
		actor._play("idle", actor.facing)
		actor.network_input = {}
		actor.network_edges.clear()
		actor.accept_local_input = false
		actor.movement_locked = false
		actor.throwoff_locked = false
		actor.set_meta("intro_velocity", Vector2.ZERO)

func _start_run_to_line() -> void:
	stage = "run_to_line"
	remaining = RUN_TO_LINE_SECONDS
	phase_deadline = LanSession.clock_time() + remaining

func _start_throw_off() -> void:
	stage = "throw_off"
	remaining = THROW_OFF_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		actor.position = _line_point(int(LanSession.member(id).slot))
		actor.remove_meta("intro_velocity")
		actor.velocity = Vector2.ZERO
		actor.facing = Vector2.RIGHT
		actor._play("idle", actor.facing)
		actor.sprite.speed_scale = 1.0
		actor.movement_locked = true
		actor.throwoff_locked = false
		actor.accept_local_input = true
		actor.network_input = {}
		actor.network_edges.clear()
	_notice("AIM AT THE CAN — ONE THROW EACH!")

func _update_throw_off() -> void:
	for id in actors:
		if throwoff_distances.has(id):
			continue
		var actor: CharacterBody2D = actors[id]
		var slipper: Node2D = actor.active_slipper
		if is_instance_valid(slipper):
			actor.throwoff_locked = true
			if slipper.is_resting() or slipper.lost_remaining > 0.0:
				throwoff_distances[id] = INF if slipper.lost_remaining > 0.0 else slipper.global_position.distance_squared_to(CAN_START)
				throwoff_last_shot_at = LanSession.clock_time()

func _finish_throw_off() -> void:
	# A player who does not throw by the deadline takes the Taya role.
	var farthest := -1.0
	var selected_slot := 999
	for id in actors:
		var distance: float = float(throwoff_distances.get(id, INF))
		var slot: int = int(LanSession.member(id).slot)
		if distance > farthest or ((distance == farthest or is_equal_approx(distance, farthest)) and slot < selected_slot):
			farthest = distance
			selected_slot = slot
			taya_id = id
	# Developer Play As remains a local testing override; LAN and online use the distance result.
	if LanSession.mode == "developer":
		if LanSession.developer_role == "taya":
			taya_id = LanSession.local_id()
		elif LanSession.developer_role == "player" and taya_id == LanSession.local_id():
			for id in actors:
				if id != LanSession.local_id():
					taya_id = id
					break
	stage = "throw_off_result"
	remaining = RESULT_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	for actor in actors.values():
		actor.movement_locked = false
		actor.throwoff_locked = true
		actor.accept_local_input = false
		actor.network_input = {}
		actor.network_edges.clear()
		actor.velocity = Vector2.ZERO
	_notice("FARTHEST FROM THE CAN!")

func _start_preparation() -> void:
	stage = "preparation"
	remaining = PREPARATION_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	can.reset_for_preview(can.base.position)
	for id in actors:
		var actor: CharacterBody2D = actors[id]
		if is_instance_valid(actor.active_slipper): actor.active_slipper.queue_free()
		actor.active_slipper = null
		actor.position = TAYA_START if id == taya_id else _line_point(int(LanSession.member(id).slot))
		actor.set_taya_role(id == taya_id)
		actor.set_meta("returning", false)
		actor.network_input = {}
		actor.network_edges.clear()
		actor.accept_local_input = id == taya_id
		actor.movement_locked = false
		actor.throwoff_locked = false

func _start_scoring() -> void:
	if taya_id == 0:
		return
	stage = "active"
	remaining = MATCH_SECONDS
	phase_deadline = LanSession.clock_time() + remaining
	_notice("THROW!")

func _slipper_spawned(actor: CharacterBody2D, slipper: Node2D) -> void:
	if stage == "throw_off":
		actor.throwoff_locked = true
		slipper.throwoff_stop_at_can = true
	if stage == "active":
		if slipper == actor.active_slipper:
			actor.set_meta("returning", true)
			actor.set_meta("left_safe", not SAFE.has_point(actor.global_position))
			actor.set_meta("retrieved", false)
	slipper.can_hit.connect(_can_hit.bind(actor, slipper))
	slipper.player_hit.connect(_special_player_hit.bind(actor))
	slipper.picked_up.connect(func() -> void:
		if slipper.special_kind != &"rapid": actor.set_meta("retrieved", true)
		if slipper.special_kind == &"rapid": return
		if stage == "active" and not slipper.get_meta("outcome", false):
			slipper.set_meta("outcome", true)
			if not slipper.hit_registered and taya_id != 0:
				_add_point(taya_id)
	)
	slipper.returned_after_penalty.connect(func() -> void: actor.set_meta("returning", false))

func _can_hit(_target: Node2D, actor: CharacterBody2D, slipper: Node2D) -> void:
	if not LanSession.is_host() or stage != "active" or actor.is_taya or slipper.get_meta("skill_counted", false):
		return
	if slipper.special_kind == &"rapid":
		if actor.get_meta("rapid_hit", false): return
		actor.set_meta("rapid_hit", true)
	slipper.set_meta("skill_counted", true)
	slipper.set_meta("outcome", true)
	var id: int = actor.get_meta("peer_id")
	_add_point(id)
	actor.set_skill_charge(actor.skill_charge + 1)
	LanSession.publish_event({"kind": "hit", "player": id, "match_id": LanSession.match_id})
	var player_name: String = LanSession.member(id).get("name", "Player")
	if actor.skill_charge == 3:
		_notice("%s'S SPECIAL IS READY — RIGHT-CLICK!" % player_name)
	else:
		_notice("%s KNOCKED DOWN THE CAN!" % player_name)

func _special_player_hit(target: Node2D, actor: CharacterBody2D) -> void:
	if not LanSession.is_host() or stage != "active" or actor.is_taya or not target.is_taya:
		return
	if target.apply_stun():
		_notice("%s IS STUNNED!" % LanSession.member(int(target.get_meta("peer_id"))).get("name", "Player"))

func _taya_stun_spawned(_actor: CharacterBody2D, slipper: Node2D) -> void:
	slipper.player_hit.connect(func(target: Node2D) -> void:
		_notice("%s IS STUNNED!" % LanSession.member(int(target.get_meta("peer_id"))).get("name", "Player"))
	)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_RIGHT or stage != "active":
		return
	if mouse_event.pressed and get_viewport().gui_get_hovered_control() != null:
		return
	var aim := get_global_mouse_position()
	if LanSession.is_host():
		_skill_requested(LanSession.local_id(), mouse_event.pressed, aim)
	else:
		LanSession.request_skill(mouse_event.pressed, aim)
	get_viewport().set_input_as_handled()

func _skill_requested(id: int, pressed: bool, aim: Vector2) -> void:
	if not LanSession.is_host() or stage != "active" or not actors.has(id) or not aim.is_finite():
		return
	var actor: CharacterBody2D = actors[id]
	if actor.is_stunned(): return
	if actor.is_taya:
		if pressed: actor.begin_taya_stun_aim()
		else: actor.release_taya_stun(aim)
	elif pressed and (actor.special_armed or actor.skill_charge == 3 and actor.throw_target_ready()):
		actor.special_armed = not actor.special_armed
		actor.queue_redraw()

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
	thrower.set_meta("rapid_complete", false)
	for shot in thrower.rapid_slippers:
		if is_instance_valid(shot): shot.queue_free()
	thrower.rapid_slippers.clear()
	taya_id = thrower.get_meta("peer_id")
	tag_immunity = 1.0
	_announce_new_taya(taya_id, thrower.global_position)

func _announce_new_taya(id: int, position: Vector2) -> void:
	tag_notice_id = id
	tag_notice_until = LanSession.clock_time() + TAG_NOTICE_SECONDS
	tag_notice_serial += 1
	tag_notice_position = position
	_spawn_tag_burst(position)

func _spawn_tag_burst(position: Vector2) -> void:
	var burst := TAG_BURST.new()
	burst.position = position + Vector2(0, -55)
	burst.z_index = 30
	add_child(burst)

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
	intro_shade = ColorRect.new()
	intro_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_shade.color = Color(0.07, 0.08, 0.13, 0.0)
	intro_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	intro_shade.visible = false
	screen.add_child(intro_shade)
	intro_title = UI.label("THROW OFF!!", 92)
	intro_title.size = Vector2(900, 160)
	intro_title.position = Vector2(-900, -80)
	intro_title.add_theme_color_override("font_color", Color("ffb52a"))
	intro_title.add_theme_color_override("font_outline_color", Color("2a160e"))
	intro_title.add_theme_constant_override("outline_size", 10)
	intro_title.visible = false
	screen.add_child(intro_title)
	result_panel = PanelContainer.new()
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -390
	result_panel.offset_top = -135
	result_panel.offset_right = 390
	result_panel.offset_bottom = 135
	result_panel.add_theme_stylebox_override("panel", UI.panel(Color("b95519"), 7))
	result_panel.visible = false
	screen.add_child(result_panel)
	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 18)
	result_panel.add_child(result_row)
	result_portrait = TextureRect.new()
	result_portrait.custom_minimum_size = Vector2(160, 180)
	result_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	result_row.add_child(result_portrait)
	var result_copy := VBoxContainer.new()
	result_copy.add_theme_constant_override("separation", 8)
	result_row.add_child(result_copy)
	result_title = UI.label("", 43)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_title.custom_minimum_size.x = 520
	result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_title.add_theme_color_override("font_color", Color("fff5dc"))
	result_copy.add_child(result_title)
	result_character = UI.label("", 24)
	result_character.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	result_character.add_theme_color_override("font_color", Color("ffe49a"))
	result_copy.add_child(result_character)
	phase_label = UI.label("WAITING FOR PLAYERS TO LOAD", 30)
	phase_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	phase_label.position = Vector2(-650, 35)
	phase_label.size = Vector2(1300, 60)
	screen.add_child(phase_label)
	score_panel = PanelContainer.new()
	score_panel.anchor_left = 1.0
	score_panel.anchor_right = 1.0
	score_panel.offset_left = -392
	score_panel.offset_right = -24
	score_panel.offset_top = 24
	score_panel.offset_bottom = 446
	score_panel.add_theme_stylebox_override("panel", UI.panel())
	score_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(score_panel)
	scoreboard = SCOREBOARD.new()
	score_panel.add_child(scoreboard)
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
	var leave := UI.button("Leave", _leave_match)
	leave.position = Vector2(25, 28)
	screen.add_child(leave)
	tag_shade = ColorRect.new()
	tag_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tag_shade.color = Color(0.18, 0.015, 0.01, 0.0)
	tag_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_shade.hide()
	screen.add_child(tag_shade)
	tag_panel = PanelContainer.new()
	tag_panel.set_anchors_preset(Control.PRESET_CENTER)
	tag_panel.offset_left = -455
	tag_panel.offset_top = -103
	tag_panel.offset_right = 455
	tag_panel.offset_bottom = 103
	tag_panel.pivot_offset = Vector2(455, 103)
	tag_panel.add_theme_stylebox_override("panel", UI.panel(Color("c5271d"), 8))
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.hide()
	screen.add_child(tag_panel)
	tag_title = UI.label("", 47)
	tag_title.custom_minimum_size = Vector2(790, 110)
	tag_title.add_theme_color_override("font_color", Color("fff3d8"))
	tag_title.add_theme_color_override("font_outline_color", Color("50150e"))
	tag_title.add_theme_constant_override("outline_size", 7)
	tag_panel.add_child(tag_title)

func _update_hud() -> void:
	Music.update_match(stage, remaining)
	if phase_label == null:
		return
	var time_text := "%d:%02d" % [int(ceil(remaining)) / 60, int(ceil(remaining)) % 60]
	phase_label.text = "WAITING FOR PLAYERS TO LOAD" if stage == "loading" else "THROW OFF INCOMING" if stage in ["intro", "run_to_line"] else "WAITING FOR SLIPPERS" if stage == "throw_off" and remaining <= 0.0 else "THROW OFF  " + time_text if stage == "throw_off" else "INITIAL TAYA" if stage == "throw_off_result" else "TAYA PREPARATION  " + time_text if stage == "preparation" else "MATCH  " + time_text
	phase_label.visible = stage != "intro" and stage != "throw_off_result"
	score_panel.visible = stage in ["preparation", "active"]
	if opening_label != null:
		opening_label.text = "%s IS TAYA\n%d" % [LanSession.member(taya_id).get("name", "Player"), ceili(remaining)] if stage == "preparation" else "THROW!" if stage == "active" and remaining > MATCH_SECONDS - 2.0 else ""
	_update_intro_visual()
	scoreboard.set_score_state(CATALOG.MAPS[LanSession.selected_map].name, LanSession.players, scores, taya_id, LanSession.mode == "developer")

func _notice(message: String) -> void:
	notice_label.text = message
	notice_remaining = 2.0

func _extra_snapshot() -> Dictionary:
	return {"stage": stage, "remaining": remaining, "deadline": phase_deadline, "scores": scores, "taya": taya_id, "notice": notice_label.text if notice_label != null else "", "tag_notice_id": tag_notice_id, "tag_notice_until": tag_notice_until, "tag_notice_serial": tag_notice_serial, "tag_notice_position": tag_notice_position}

func _apply_extra_snapshot(data: Dictionary) -> void:
	stage = data.get("stage", stage)
	phase_deadline = float(data.get("deadline", phase_deadline))
	remaining = maxf(0.0, phase_deadline - LanSession.clock_time()) if stage in ["intro", "run_to_line", "throw_off", "throw_off_result", "preparation", "active"] else float(data.get("remaining", remaining))
	scores = data.get("scores", scores)
	taya_id = data.get("taya", taya_id)
	var incoming_tag_serial := int(data.get("tag_notice_serial", tag_notice_serial))
	if incoming_tag_serial >= tag_notice_serial:
		tag_notice_id = int(data.get("tag_notice_id", tag_notice_id))
		tag_notice_until = float(data.get("tag_notice_until", tag_notice_until))
		if incoming_tag_serial > tag_notice_serial:
			tag_notice_serial = incoming_tag_serial
			tag_notice_position = data.get("tag_notice_position", tag_notice_position)
			if tag_notice_until > LanSession.clock_time():
				_spawn_tag_burst(tag_notice_position)
	for actor in actors.values():
		actor.movement_locked = stage == "throw_off"
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
	match_camera.zoom = Vector2.ONE * 1.5
	match_camera.position = _spawn_point(int(LanSession.member(LanSession.local_id()).get("slot", 0)))
	add_child(match_camera)
	_update_camera(1.0)
	match_camera.reset_smoothing()

func _process(delta: float) -> void:
	super._process(delta)
	_update_intro_visual()
	_update_tag_announcement()
	_update_camera(delta)

func _update_tag_announcement() -> void:
	if tag_panel == null:
		return
	var time_left := tag_notice_until - LanSession.clock_time()
	var visible := stage == "active" and tag_notice_id != 0 and time_left > 0.0
	tag_panel.visible = visible
	tag_shade.visible = visible
	if not visible:
		return
	var progress := clampf(1.0 - time_left / TAG_NOTICE_SECONDS, 0.0, 1.0)
	var opacity := minf(1.0, minf(progress / 0.15, time_left / 0.35))
	tag_panel.modulate.a = opacity
	tag_panel.scale = Vector2.ONE * lerpf(0.9, 1.0, smoothstep(0.0, 0.28, progress))
	tag_shade.color.a = 0.24 * opacity
	tag_title.text = "%s\nIS NOW TAYA!" % str(LanSession.member(tag_notice_id).get("name", "Player")).to_upper()

func _update_camera(delta: float) -> void:
	if match_camera == null or can == null: return
	var actor = actors.get(LanSession.local_id())
	if actor == null: return
	var viewport_size := get_viewport_rect().size
	var subject: Vector2 = actor.global_position
	var max_zoom := 1.5
	var following_throw := false
	if stage in ["throw_off", "active"]:
		var own_slipper: Node2D = actor.active_slipper
		if is_instance_valid(own_slipper) and not own_slipper.resting and own_slipper.lost_remaining <= 0.0:
			camera_slipper = own_slipper
			camera_landing_point = own_slipper.global_position
			camera_return_at = 0.0
			camera_following_slipper = true
		elif camera_following_slipper and camera_return_at == 0.0:
			if is_instance_valid(camera_slipper):
				camera_landing_point = camera_slipper.global_position
			camera_landing_point = camera_landing_point.clamp(ARENA.position, ARENA.end)
			camera_return_at = LanSession.clock_time() + 1.0
		if camera_return_at > 0.0 and LanSession.clock_time() >= camera_return_at:
			camera_slipper = null
			camera_return_at = 0.0
			camera_following_slipper = false
		if camera_following_slipper and is_instance_valid(camera_slipper) and camera_return_at == 0.0:
			subject = camera_slipper.global_position
			following_throw = true
		elif camera_return_at > 0.0:
			subject = camera_landing_point
			following_throw = true
	else:
		camera_slipper = null
		camera_return_at = 0.0
		camera_following_slipper = false
	if following_throw:
		max_zoom = 1.42
	elif actor.attack_state == actor.AttackState.CHARGING:
		max_zoom = 1.25
	# Frame the can along with the local player or their slipper, including a little space around both.
	var can_position: Vector2 = can.global_position
	var focus: Vector2 = (subject + can_position) * 0.5 + Vector2(0, -55)
	var span: Vector2 = (subject - can_position).abs() + Vector2(320, 340)
	var target_zoom := minf(max_zoom, minf(viewport_size.x / span.x, viewport_size.y / span.y))
	target_zoom = clampf(target_zoom, 0.9, 1.5)
	var visible_half := viewport_size / (target_zoom * 2.0)
	if visible_half.x * 2.0 < ARENA.size.x:
		focus.x = clampf(focus.x, ARENA.position.x + visible_half.x, ARENA.end.x - visible_half.x)
	else:
		focus.x = ARENA.get_center().x
	if visible_half.y * 2.0 < ARENA.size.y:
		focus.y = clampf(focus.y, ARENA.position.y + visible_half.y, ARENA.end.y - visible_half.y)
	else:
		focus.y = ARENA.get_center().y
	var weight := 1.0 - exp(-delta / (0.16 if following_throw else 0.26))
	match_camera.position = match_camera.position.lerp(focus, weight)
	match_camera.zoom = match_camera.zoom.lerp(Vector2.ONE * target_zoom, weight)

func _update_intro_visual() -> void:
	if intro_shade == null:
		return
	intro_shade.visible = stage in ["intro", "throw_off_result"]
	intro_title.visible = stage == "intro"
	result_panel.visible = stage == "throw_off_result" and taya_id != 0
	if stage == "intro":
		var progress := clampf((INTRO_SECONDS - remaining) / INTRO_SECONDS, 0.0, 1.0)
		var slide_in := smoothstep(0.0, 0.34, progress)
		var slide_out := smoothstep(0.76, 1.0, progress)
		var width := get_viewport_rect().size.x
		intro_title.position.x = lerpf(-900.0, (width - intro_title.size.x) * 0.5, slide_in) + width * slide_out
		intro_title.position.y = (get_viewport_rect().size.y - intro_title.size.y) * 0.5
		intro_shade.color.a = 0.48 * minf(slide_in, 1.0 - slide_out)
	elif stage == "throw_off_result":
		intro_shade.color.a = 0.36
		var member: Dictionary = LanSession.member(taya_id)
		result_title.text = "%s IS TAYA!" % str(member.get("name", "Player")).to_upper()
		result_character.text = str(LanSession.CHARACTERS[int(member.get("character", 0))]).to_upper()
		var winner: CharacterBody2D = actors.get(taya_id)
		if winner != null:
			var frames: SpriteFrames = winner.sprite.sprite_frames
			if frames.has_animation("idle_down"):
				result_portrait.texture = frames.get_frame_texture("idle_down", 0)
