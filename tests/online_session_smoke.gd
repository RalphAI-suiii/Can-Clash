extends SceneTree

var session: Node
var role := "host"
var folder := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	role = args[0]
	folder = args[1]
	create_timer(65).timeout.connect(func() -> void: printerr("FAIL: online adapter timeout ", role); quit(1))
	_run.call_deferred()

func _mark(step: String) -> void:
	var file := FileAccess.open(folder.path_join(role + "-" + step), FileAccess.WRITE)
	file.store_string("ok")

func _all(step: String) -> bool:
	for i in range(1, 4):
		if not FileAccess.file_exists(folder.path_join("client%d-" % i + step)): return false
	return true

func _room() -> void:
	var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room

func _run() -> void:
	session = root.get_node("LanSession")
	session.connection_status_changed.connect(func(message: String) -> void: print(role, " STATUS ", message))
	var profile := root.get_node("UserSettings")
	profile.display_name = role
	profile.tutorial_seen = true
	session.online.gd.set_artificial_latency(40 if role == "host" else 80)
	session.online.test_drop_every = 10
	session.online.test_local = true # Real vendor transport locally; never consumes cloud data.
	session.online.gd._connection_controller._PRIVATE_KEY = "local-transport-test-only" # Vendor 1.0.2 authenticates local packets too.
	if role == "overflow":
		while not FileAccess.file_exists(folder.path_join("host-full")): await process_frame
		var discovery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("code")))
		var failure := {"reason": ""}
		session.connection_status_changed.connect(func(message: String) -> void: failure.reason = message)
		assert(session.join_online(discovery.code) == OK)
		session.online.gd._local_server.found_lobbies[discovery.code] = {"Name": discovery.code, "IP": "127.0.0.1", "Port": discovery.port}
		while session.mode != "menu": await process_frame
		assert(str(failure.reason).contains("full"))
		_mark("checked")
		print("PASS: a fifth online player is rejected with a full-room message.")
		quit(0)
		return
	if role == "host":
		assert(session.host_online() == OK)
		while session.phase != "waiting": await process_frame
		var file := FileAccess.open(folder.path_join("code"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"code": session.room_code, "port": session.online.gd._local_server.local_lobby_port}))
		file.close()
		_room()
		while session.players.size() < 4: await process_frame
		assert(session.capacity() == 4 and session.local_id() == 1 and session.is_host())
		_mark("full")
		while not FileAccess.file_exists(folder.path_join("overflow-checked")): await process_frame
		while not _all("moved"): await process_frame
		while not _all("threw"): await process_frame
		session.set_ready(true)
		while not session.all_ready(): await process_frame
		assert(current_scene.start_button.visible and not current_scene.start_button.disabled)
		assert(session.start_match())
		while current_scene == null or current_scene.scene_file_path != "res://game/match/match.tscn": await process_frame
		while current_scene.stage == "tutorial": await process_frame
		current_scene.remaining = 0.01
		while current_scene.stage != "active": await process_frame
		while not _all("active"): await process_frame
		# Validate registration/version and sender authority without accepting forged data.
		var roster: Array = session.players.duplicate(true)
		session._online_message(99999, "_sync_roster", [[], "FORGED"])
		assert(session.players == roster)
		session._online_message(99999, "_register", [null, "bad", []])
		assert(session.players == roster)
		var peer_id: int = session.players[1].id
		var actor: Node2D = current_scene.actors[peer_id]
		var charge_id: int = actor.charge_id
		session.online_sender = peer_id
		session._throw_edge(true, -1, 0, session.clock_time(), Vector2.ZERO)
		session._submit_input({"sequence": -1, "move": Vector2.ONE, "aim": Vector2.ZERO})
		session.online_sender = 0
		assert(actor.charge_id == charge_id, "Stale actions cannot start a new throw")
		current_scene.remaining = 0.01
		while session.phase != "results": await process_frame
		while not _all("results"): await process_frame
		session.close_room()
		print("PASS: GD-Sync transport host, four-player roster, movement, ready/start, phases, timed throws under latency/loss, stale-action rejection, results and host close (local vendor mode).")
		quit(0)
	else:
		while not FileAccess.file_exists(folder.path_join("code")): await process_frame
		var discovery: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("code")))
		assert(session.join_online(discovery.code) == OK)
		# Seed discovery on this PC: Windows broadcast/firewall settings are not under test.
		# Connection, lobby admission, packets, sender IDs and replication are real vendor code.
		session.online.gd._local_server.found_lobbies[discovery.code] = {"Name": discovery.code, "IP": "127.0.0.1", "Port": discovery.port}
		while session.phase != "waiting": await process_frame
		_room()
		assert(not session.is_host() and session.local_id() > 1 and not current_scene.start_button.visible)
		var actor: Node2D = current_scene.actors[session.local_id()]
		var start := actor.position
		Input.action_press("right")
		await create_timer(0.6).timeout
		Input.action_release("right")
		assert(actor.position.x > start.x + 10, "Client movement must be authoritative and replicated")
		_mark("moved")
		# Use actual mouse input and release against the displayed host-chosen green zone.
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = Vector2(500, 500)
		press.pressed = true
		Input.parse_input_event(press)
		while actor.attack_state != actor.AttackState.CHARGING: await process_frame
		while absf(actor.charge_bar.value - actor.sweet_spot) > 0.015: await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.position = Vector2(500, 500)
		release.pressed = false
		Input.parse_input_event(release)
		while not is_instance_valid(actor.active_slipper): await process_frame
		assert(is_equal_approx(actor.active_slipper.charge_ratio, 1.0), "Displayed green must remain perfect under latency")
		_mark("threw")
		session.set_ready(true)
		while current_scene == null or current_scene.scene_file_path != "res://game/match/match.tscn": await process_frame
		while current_scene.stage != "active": await process_frame
		_mark("active")
		while session.phase != "results": await process_frame
		assert(session.results.size() == 4)
		_mark("results")
		while session.mode != "menu": await process_frame
		print("PASS: GD-Sync transport client ", role, " host departure handled.")
		quit(0)
