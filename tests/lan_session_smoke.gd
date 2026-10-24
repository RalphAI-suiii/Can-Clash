extends SceneTree

var session: Node
var profile: Node
var role := "host"
var folder := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		role = args[0]
		folder = args[1]
	create_timer(65.0).timeout.connect(func() -> void:
		printerr("FAIL: LAN test timed out: ", role)
		quit(1)
	)
	_run.call_deferred()

func _mark(step: String) -> void:
	var file := FileAccess.open(folder.path_join(role + "-" + step), FileAccess.WRITE)
	assert(file != null)
	file.store_string("ok")

func _all_marked(step: String, count: int = 4) -> bool:
	for i in range(1, count + 1):
		if not FileAccess.file_exists(folder.path_join("client%d-" % i + step)):
			return false
	return true

func _room() -> void:
	var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room

func _run() -> void:
	session = root.get_node("LanSession")
	profile = root.get_node("UserSettings")
	profile.display_name = "LAN " + role
	var character_index := 0 if role == "host" else int(role.trim_prefix("client"))
	profile.selected_character_scene = "res://scenes/Thrower %s.tscn" % session.CHARACTERS[character_index]
	profile.tutorial_seen = false
	if role == "host":
		assert(session.host_room() == OK)
		_room()
		assert(session.players.size() == 1 and current_scene.ready_panel.players.size() == 1)
		assert(current_scene.start_button.visible and current_scene.start_button.disabled)
		_mark("listening")
		while session.players.size() < 5:
			await process_frame
		assert(current_scene.actors.size() == 5 and current_scene.ready_panel.players.size() == 5)
		while not _all_marked("joined"):
			await process_frame
		_mark("all-joined")
		var colors: Array = session.players.map(func(member: Dictionary) -> Color: return member.color)
		for i in range(5):
			assert(colors.count(colors[i]) == 1)
		while not _all_marked("moved"):
			await process_frame
		assert(current_scene.start_button.disabled, "Host is still unready")
		session.set_ready(true)
		while not session.all_ready():
			await process_frame
		assert(session.start_match())
		while current_scene == null or current_scene.scene_file_path != "res://game/match/match.tscn":
			await process_frame
		while current_scene.stage == "loading":
			await process_frame
		assert(current_scene.stage == "preparation")
		assert(current_scene.remaining > 6.0)
		current_scene.remaining = 0.01
		while not _all_marked("active"):
			await process_frame
		assert(current_scene.stage == "active")
		var throwers: Array = current_scene.actors.values().filter(func(actor: Node2D) -> bool: return not actor.is_taya)
		for i in range(throwers.size()):
			var actor: Node2D = throwers[i]
			actor.position = Vector2(600 + i * 100, 850)
			var slipper: Node2D = load("res://scenes/slipper_visual.gd").new()
			current_scene.add_child(slipper)
			var point: Vector2 = current_scene.can.get_hit_center() - Vector2(120, 0) if i == 0 else Vector2(650 + i * 80, 450)
			slipper.launch(actor, point, Vector2.RIGHT, 1.0, point)
			slipper.outline_color = actor.player_color
			slipper.arena_bounds = current_scene.ARENA
			actor.active_slipper = slipper
		while not _all_marked("feedback"):
			await process_frame
		while not current_scene.can.is_settled():
			await process_frame
		var landed: Vector2 = current_scene.can.position
		assert(not current_scene.can.is_standing(), "Matches require manual can recovery")
		var guard: CharacterBody2D = current_scene.actors[current_scene.taya_id]
		guard.position = landed + Vector2(55, 0)
		assert(current_scene.can.pick_up(guard))
		guard.carrying_can = true
		guard.position = current_scene.can.base.position + Vector2(55, 0)
		assert(current_scene.can.reset_at_base(guard))
		guard.carrying_can = false
		assert(current_scene.can.position.distance_to(Vector2(1450, 610)) < 0.1)
		assert(current_scene.can.base.position.distance_to(Vector2(1450, 610)) < 0.1)
		assert(landed.distance_to(Vector2(1450, 610)) > 5.0)
		_mark("can-recovered")
		while not _all_marked("can-recovered"):
			await process_frame
		var departing_id: int = 0
		for member in session.players:
			if member.name == "LAN client4":
				departing_id = member.id
		assert(departing_id > 1)
		current_scene.tag_immunity = 10.0
		current_scene.taya_id = departing_id
		for id in current_scene.actors:
			current_scene.actors[id].set_taya_role(id == departing_id)
		current_scene.can.reset_for_preview(current_scene.can.base.position)
		# Preserve coverage of legacy/manual carried-can disconnect recovery.
		current_scene.can.auto_stand_up = false
		current_scene.can.topple()
		while not current_scene.can.is_settled():
			await process_frame
		var departing: Node2D = current_scene.actors[departing_id]
		departing.position = current_scene.can.position
		assert(current_scene.can.pick_up(departing))
		departing.carrying_can = true
		_mark("drop-taya")
		while session.players.size() == 5:
			await process_frame
		assert(session.players.size() == 4 and current_scene.actors.size() == 4)
		assert(current_scene.actors.has(current_scene.taya_id) and current_scene.actors[current_scene.taya_id].is_taya)
		assert(current_scene.can.is_standing() and current_scene.can.carrier == null, "Departing carrier must not hide or strand the can")
		current_scene.scores[1] = 5
		current_scene._finish()
		while current_scene == null or current_scene.scene_file_path != "res://ui/results/results.tscn":
			await process_frame
		assert(profile.statistics.wins == 1)
		while not _all_marked("results", 3):
			await process_frame
		while session.players.size() == 5:
			await process_frame
		assert(session.players.size() == 4, "Departed player must leave the real roster")
		session.close_room()
		while not _all_marked("closed", 3):
			await process_frame
		print("PASS: five-process LAN registration, roster/colors, remote movement, host-only ready/start, shared map/phases, live slipper/hit feedback, active Taya/carried-can disconnect recovery, results/statistics, and host disconnect cleanup.")
	else:
		session.room_joined.connect(_room)
		assert(session.join_room(session.encode_address("127.0.0.1")) == OK)
		while current_scene == null or current_scene.scene_file_path != "res://ui/waiting_room/waiting_room.tscn":
			await process_frame
		assert(not current_scene.start_button.visible)
		while session.players.size() < 5:
			await process_frame
		_mark("joined")
		while not FileAccess.file_exists(folder.path_join("host-all-joined")):
			await process_frame
		var own: Node2D = current_scene.actors[session.local_id()]
		var start_position := own.position
		Input.action_press("left")
		var move_deadline := Time.get_ticks_msec() + 3000
		while own.position.distance_to(start_position) <= 35.0 and Time.get_ticks_msec() < move_deadline:
			await process_frame
		Input.action_release("left")
		assert(own.position.distance_to(start_position) > 20.0, "Host must simulate remote input and replicate movement")
		session.set_ready(true)
		_mark("moved")
		while current_scene == null or current_scene.scene_file_path != "res://game/match/match.tscn":
			await process_frame
		while current_scene.stage != "active":
			await process_frame
		assert(current_scene.remaining > 595.0 and current_scene.remaining <= 600.0, "Replicated match timer: %s" % current_scene.remaining)
		assert(current_scene.actors.size() == 5)
		_mark("active")
		var saw_slipper := false
		var saw_flash := false
		var saw_empty_hand := false
		while not saw_slipper or not saw_flash or not saw_empty_hand:
			await process_frame
			if current_scene == null:
				continue
			for actor in current_scene.actors.values():
				if is_instance_valid(actor.active_slipper):
					assert(actor.active_slipper.outline_color == actor.player_color)
					saw_slipper = true
					if actor.get_script().resource_path.ends_with("character_role_player.gd") and actor.attack_state == actor.AttackState.FREE:
						saw_empty_hand = saw_empty_hand or String(actor.sprite.animation).begins_with("taya_")
			saw_flash = saw_flash or current_scene.can.can_sprite.modulate.r > 1.5
		_mark("feedback")
		var saw_tumble := false
		while not FileAccess.file_exists(folder.path_join("host-can-recovered")) or not current_scene.can.is_standing() or current_scene.can.position.distance_to(current_scene.can.base.position) > 0.1:
			saw_tumble = saw_tumble or absf(current_scene.can.tilt_angle) > 0.5
			await process_frame
		assert(saw_tumble, "Clients must render the can's tumbling rotation")
		assert(current_scene.can.position.distance_to(Vector2(1450, 610)) < 0.1)
		_mark("can-recovered")
		if role == "client4":
			while not FileAccess.file_exists(folder.path_join("host-drop-taya")):
				await process_frame
			session.close_room()
			print("PASS: client4 active Taya disconnect")
			quit()
			return
		while current_scene == null or current_scene.scene_file_path != "res://ui/results/results.tscn":
			await process_frame
		assert(session.results[0].id == 1 and session.results[0].score == 5)
		assert(profile.statistics.losses == 1)
		_mark("results")
		if role == "client4":
			session.close_room()
		else:
			while session.mode != "menu":
				await process_frame
			_mark("closed")
		print("PASS: ", role)
	quit()
