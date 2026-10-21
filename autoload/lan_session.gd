extends Node

signal roster_changed
signal connection_status_changed(message: String)
signal room_joined
signal room_closed(reason: String)
signal input_received(peer_id: int, packet: Dictionary)
signal world_snapshot_received(snapshot: Dictionary)
signal match_event_received(event: Dictionary)

const PORT := 54652
const MAX_PLAYERS := 5
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const COLORS := [Color("329dff"), Color("ff7344"), Color("51c878"), Color("bf83ff"), Color("ff6fae")]
const CHARACTERS := ["Hat Thrower", "Head Band", "Glasses Thrower", "Curly Haired", "Bullcap Head"]

var players: Array[Dictionary] = []
var mode := "menu"
var phase := "menu"
var room_code := ""
var host_address := ""
var selected_map := 0
var selection_seed := 0
var match_id := ""
var results: Array = []
var join_deadline := 0.0
var tutorial_ready: Dictionary = {}
var last_input_time: Dictionary = {}
var input_deadline: Dictionary = {}
var event_sequence := 0
var developer_bot_count := 4:
	set(value):
		developer_bot_count = clampi(value, 0, MAX_PLAYERS - 1)

func _ready() -> void:
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func() -> void: _failed("Could not connect. Check the code/address and the host's firewall."))
	multiplayer.server_disconnected.connect(func() -> void: _failed("The host closed the room."))
	multiplayer.peer_disconnected.connect(_peer_left)

func is_networked() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer

func is_host() -> bool:
	return not is_networked() or multiplayer.is_server()

func local_id() -> int:
	return multiplayer.get_unique_id() if is_networked() else 1

func member(id: int) -> Dictionary:
	for entry in players:
		if entry.id == id:
			return entry
	return {}

func _own_member(id: int, slot: int) -> Dictionary:
	var character := CHARACTERS.find(UserSettings.selected_character_scene.get_file().trim_prefix("Thrower ").trim_suffix(".tscn"))
	return {"id": id, "name": UserSettings.display_name, "ready": false, "slot": slot, "character": maxi(0, character), "color": COLORS[slot], "bot": false}

func close_room() -> void:
	if is_networked():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	tutorial_ready.clear()
	last_input_time.clear()
	input_deadline.clear()
	mode = "menu"
	phase = "menu"
	room_code = ""
	join_deadline = 0.0

func begin_local(local_mode: String = "developer") -> void:
	close_room()
	mode = local_mode
	phase = "waiting"
	room_code = "DEV" if mode == "developer" else "PRACTICE"
	players.append(_own_member(1, 0))
	roster_changed.emit()

func host_room() -> Error:
	close_room()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		connection_status_changed.emit("Couldn't host. Another room may already be using port %d." % PORT)
		return error
	multiplayer.multiplayer_peer = peer
	mode = "lan"
	phase = "waiting"
	host_address = _lan_address()
	room_code = encode_address(host_address)
	players.append(_own_member(1, 0))
	roster_changed.emit()
	return OK

func join_room(address_or_code: String) -> Error:
	close_room()
	var target := address_or_code.strip_edges()
	if not target.is_valid_ip_address():
		target = decode_code(target)
	if target.is_empty():
		connection_status_changed.emit("Enter a valid room code or the host's LAN IP address.")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(target, PORT)
	if error != OK:
		connection_status_changed.emit("Couldn't open the connection. Check the address.")
		return error
	multiplayer.multiplayer_peer = peer
	mode = "lan"
	phase = "joining"
	join_deadline = Time.get_ticks_msec() / 1000.0 + 10.0
	connection_status_changed.emit("Connecting to the host…")
	return OK

func _connected() -> void:
	_register.rpc_id(1, UserSettings.display_name, _own_member(local_id(), 0).character)

@rpc("any_peer", "call_remote", "reliable")
func _register(player_name: String, character: int) -> void:
	if not is_host() or phase != "waiting":
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender <= 1 or not member(sender).is_empty():
		return
	if players.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(sender)
		return
	var used: Array = players.map(func(entry: Dictionary) -> int: return entry.slot)
	var slot := 0
	while used.has(slot):
		slot += 1
	var clean := UserSettings.clean_name(player_name)
	players.append({"id": sender, "name": clean if not clean.is_empty() else "Player", "ready": false, "slot": slot, "character": clampi(character, 0, 4), "color": COLORS[slot], "bot": false})
	_publish_roster()

func _publish_roster() -> void:
	roster_changed.emit()
	if is_networked() and is_host():
		_sync_roster.rpc(players, room_code)

@rpc("authority", "call_remote", "reliable")
func _sync_roster(roster: Array, code: String) -> void:
	players.assign(roster)
	room_code = code
	var was_joining := phase == "joining"
	var own_registered := not member(local_id()).is_empty()
	if was_joining and own_registered:
		phase = "waiting"
		join_deadline = 0.0
	roster_changed.emit()
	if was_joining and own_registered:
		room_joined.emit()

func set_ready(value: bool) -> void:
	if is_host():
		_apply_ready(local_id(), value)
	else:
		_request_ready.rpc_id(1, value)

@rpc("any_peer", "call_remote", "reliable")
func _request_ready(value: bool) -> void:
	if is_host():
		_apply_ready(multiplayer.get_remote_sender_id(), value)

func _apply_ready(id: int, value: bool) -> void:
	var entry := member(id)
	if phase != "waiting" or entry.is_empty():
		return
	entry.ready = value
	_publish_roster()

func all_ready() -> bool:
	return not players.is_empty() and players.all(func(entry: Dictionary) -> bool: return entry.ready)

func can_start() -> bool:
	return is_host() and phase == "waiting" and all_ready() and (mode == "developer" or players.size() >= 2)

func start_match() -> bool:
	if not can_start():
		return false
	add_developer_bots()
	_publish_roster()
	selection_seed = randi()
	selected_map = int(selection_seed % 3)
	match_id = "%s-%d-%d" % [room_code, Time.get_unix_time_from_system(), selection_seed]
	tutorial_ready.clear()
	phase = "roulette"
	if is_networked():
		_begin_selection.rpc(selected_map, selection_seed, match_id)
	_open_selection()
	return true

func add_developer_bots() -> void:
	if mode != "developer":
		return
	for slot in range(1, developer_bot_count + 1):
		if member(-slot).is_empty():
			players.append({"id": -slot, "name": "Bot %d" % slot, "ready": true, "slot": slot, "character": slot, "color": COLORS[slot], "bot": true})

@rpc("authority", "call_remote", "reliable")
func _begin_selection(map_index: int, seed_value: int, id: String) -> void:
	selected_map = map_index
	selection_seed = seed_value
	match_id = id
	tutorial_ready.clear()
	phase = "roulette"
	_open_selection()

func _open_selection() -> void:
	get_tree().change_scene_to_file.call_deferred("res://ui/map_select/map_select.tscn")

func acknowledge_tutorial() -> void:
	if is_host():
		tutorial_ready[local_id()] = true
	else:
		_tutorial_ack.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func _tutorial_ack() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host() and phase == "match" and not member(sender).is_empty():
		tutorial_ready[sender] = true

func humans_ready_for_match() -> bool:
	return players.all(func(entry: Dictionary) -> bool: return entry.bot or tutorial_ready.has(entry.id))

func send_input(packet: Dictionary) -> void:
	if is_networked() and not is_host():
		_submit_input.rpc_id(1, packet)

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_input(packet: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host() or member(sender).is_empty() or not phase in ["waiting", "match"]:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_input_time.get(sender, 0.0)) < 0.006:
		return
	var move = packet.get("move")
	var aim = packet.get("aim")
	if not move is Vector2 or not aim is Vector2 or not move.is_finite() or not aim.is_finite():
		return
	var clean := {"move": move.limit_length(), "aim": aim.clamp(Vector2(-10000, -10000), Vector2(10000, 10000))}
	for key in ["sprint", "interact", "lunge", "throw"]:
		clean[key] = packet.get(key, false) == true
	last_input_time[sender] = now
	input_deadline[sender] = now + 0.5
	input_received.emit(sender, clean)

func publish_world(snapshot: Dictionary) -> void:
	if is_networked() and is_host():
		var bytes := var_to_bytes(snapshot)
		_world_state.rpc(bytes.compress(FileAccess.COMPRESSION_ZSTD), bytes.size())

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _world_state(payload: PackedByteArray, original_size: int) -> void:
	if original_size <= 0 or original_size > 65536:
		return
	var snapshot = bytes_to_var(payload.decompress(original_size, FileAccess.COMPRESSION_ZSTD))
	if snapshot is Dictionary:
		world_snapshot_received.emit(snapshot)

func publish_event(event: Dictionary) -> void:
	event_sequence += 1
	event["sequence"] = event_sequence
	match_event_received.emit(event)
	if is_networked() and is_host():
		_match_event.rpc(event)

@rpc("authority", "call_remote", "reliable")
func _match_event(event: Dictionary) -> void:
	match_event_received.emit(event)

func finish_match(rankings: Array) -> void:
	if not is_host() or phase != "match":
		return
	results = rankings
	phase = "results"
	if is_networked():
		_show_results.rpc(rankings)
	get_tree().change_scene_to_file.call_deferred("res://ui/results/results.tscn")

@rpc("authority", "call_remote", "reliable")
func _show_results(rankings: Array) -> void:
	results = rankings
	phase = "results"
	get_tree().change_scene_to_file.call_deferred("res://ui/results/results.tscn")

func _peer_left(id: int) -> void:
	if not is_host():
		return
	players = players.filter(func(entry: Dictionary) -> bool: return entry.id != id)
	tutorial_ready.erase(id)
	input_deadline.erase(id)
	_publish_roster()

func _failed(reason: String) -> void:
	close_room()
	connection_status_changed.emit(reason)
	room_closed.emit(reason)

func _process(_delta: float) -> void:
	if join_deadline > 0.0 and Time.get_ticks_msec() / 1000.0 > join_deadline:
		_failed("Connection timed out. Check the room code, LAN connection, and firewall.")
	if is_host():
		var now := Time.get_ticks_msec() / 1000.0
		for id in input_deadline.keys():
			if now > input_deadline[id]:
				input_received.emit(id, {"move": Vector2.ZERO, "aim": Vector2.ZERO})
				input_deadline.erase(id)

func _lan_address() -> String:
	for prefix in ["192.168.", "10.", "172."]:
		for address in IP.get_local_addresses():
			if address.begins_with(prefix) and address.is_valid_ip_address() and not address.contains(":"):
				return address
	return "127.0.0.1"

func encode_address(address: String) -> String:
	var parts := address.split(".")
	if parts.size() != 4:
		return ""
	var value: int = 0
	for part in parts:
		if not part.is_valid_int() or int(part) < 0 or int(part) > 255:
			return ""
		value = (value << 8) | int(part)
	var code := ""
	for i in range(7):
		code = CODE_ALPHABET[value & 31] + code
		value >>= 5
	return code

func decode_code(raw: String) -> String:
	var code := raw.strip_edges().to_upper().replace("-", "")
	if code.length() != 7:
		return ""
	var value: int = 0
	for character in code:
		var digit := CODE_ALPHABET.find(character)
		if digit < 0:
			return ""
		value = (value << 5) | digit
	if value > 0xffffffff:
		return ""
	return "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255, (value >> 8) & 255, value & 255]
