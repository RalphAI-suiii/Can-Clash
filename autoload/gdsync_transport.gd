extends Node

## Transport only. LanSession still validates and owns every gameplay outcome.
signal joined(creator: bool)
signal message_received(sender: int, method: String, arguments: Array)
signal peer_left(id: int)
signal failed(reason: String)

const KEYS = preload("res://addons/GD-Sync/Scripts/KeyStore.gd")
const ERRORS = preload("res://addons/GD-Sync/Scripts/Enums/Enums.gd")
const CAPACITY := 4
var gd: Node
var creator := false
var active := false
var code := ""
var original_host := -1
var attempts := 0
var pending_join := false
var test_local := false
var test_drop_every := 0
var test_sent := 0

func _ready() -> void:
	gd = get_node("/root/GDSync")
	gd.connected.connect(_connected)
	gd.connection_failed.connect(_connection_failed)
	gd.disconnected.connect(func() -> void:
		if active: failed.emit("Online connection lost. Check your internet connection or GD-Sync data allowance, then try again.")
	)
	gd.lobby_created.connect(func(name: String) -> void:
		if active and creator: gd.lobby_join(name, "")
	)
	gd.lobby_creation_failed.connect(_creation_failed)
	gd.lobby_joined.connect(func(name: String) -> void: _joined.call_deferred(name)) # Host identity arrives in the same packet, after lobby data.
	gd.lobby_join_failed.connect(_join_failed)
	gd.client_left.connect(_left)
	gd.host_changed.connect(_host_changed)
	gd.kicked.connect(func(reason: String) -> void:
		if active: failed.emit(reason if not reason.is_empty() else "The host closed the room.")
	)
	gd.expose_func(_receive)

func configured() -> bool:
	var keys := KEYS.load_keys()
	return not str(keys.PublicKey).is_empty() and not str(keys.PrivateKey).is_empty()

func begin(make_room: bool, room_code: String = "") -> Error:
	if not test_local and not configured():
		failed.emit("Online play isn't configured in this build. Ask the developer for an online-enabled build, or choose Play Local or Practice.")
		return ERR_UNCONFIGURED
	creator = make_room
	code = room_code
	original_host = -1
	pending_join = false
	attempts = 0
	active = true
	if test_local:
		gd.start_local_multiplayer()
	else:
		gd.start_multiplayer()
	return OK

func stop() -> void:
	active = false
	pending_join = false
	original_host = -1
	if gd != null:
		gd.stop_multiplayer()

func local_id() -> int:
	return game_id(gd.get_client_id())

func game_id(raw_id: int) -> int:
	return 1 if raw_id == original_host else raw_id + 2

func raw_id(id: int) -> int:
	return original_host if id == 1 else id - 2

func is_host() -> bool:
	return original_host >= 0 and gd.get_client_id() == original_host

func send(id: int, method: String, arguments: Array, reliable: bool) -> void:
	if not active or original_host < 0:
		return
	if test_local and not reliable and test_drop_every > 0:
		test_sent += 1
		if test_sent % test_drop_every == 0: return
	if id == 0:
		if reliable: gd.call_func(_receive, method, arguments)
		else: gd.call_func_unreliable(_receive, method, arguments)
	elif reliable:
		gd.call_func_on(raw_id(id), _receive, method, arguments)
	else:
		gd.call_func_on_unreliable(raw_id(id), _receive, method, arguments)

func close_admission() -> void:
	if active and is_host(): gd.lobby_close()

func _connected() -> void:
	if not active: return
	if creator: _create()
	else: gd.lobby_join(code, "")

func _create() -> void:
	attempts += 1
	code = ""
	for index in range(7):
		code += "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"[randi() % 32]
	gd.lobby_create(code, "", false, CAPACITY, {"game": "CanClash", "protocol": "rules-3"})

func _creation_failed(_name: String, error: int) -> void:
	if not active: return
	if error == ERRORS.LOBBY_CREATION_ERROR.LOBBY_ALREADY_EXISTS and attempts < 3:
		_create()
	else:
		failed.emit("Couldn't create an online room (code %d). Wait a moment and try again." % error)


func _joined(name: String) -> void:
	if not active or original_host >= 0 or name != code: return
	code = name
	pending_join = true
	if gd.get_host() >= 0: _finish_join(gd.get_host())

func _host_changed(_is_host: bool, host_id: int) -> void:
	if not active: return
	if pending_join and original_host < 0:
		_finish_join(host_id)
	elif original_host >= 0 and host_id != original_host:
		failed.emit("The host left the online room. Create or join another room.")

func _finish_join(host_id: int) -> void:
	if not active or not pending_join or original_host >= 0: return
	pending_join = false
	original_host = host_id
	if creator and not is_host():
		failed.emit("Couldn't establish room ownership. Please create another room.")
		return
	joined.emit(creator)

func _receive(method: String, arguments: Array) -> void:
	if not active: return
	var sender: int = gd.get_sender_id()
	if sender < 0: return
	message_received.emit(game_id(sender), method, arguments)

func _left(raw: int) -> void:
	if not active: return
	if raw == original_host:
		failed.emit("The host closed the online room.")
	else:
		peer_left.emit(game_id(raw))

func _join_failed(_name: String, error: int) -> void:
	if not active: return
	var messages := ["Room not found. Check the code and try again.", "This match has already started.", "This online room is full (4 players).", "Incorrect room password.", "This player name is already in use."]
	failed.emit(messages[error] if error >= 0 and error < messages.size() else "Couldn't join the online room. Try again.")

func _connection_failed(error: int) -> void:
	if active:
		failed.emit("GD-Sync rejected the game keys. Check the developer configuration." if error == ERRORS.CONNECTION_FAILED.INVALID_PUBLIC_KEY else "Couldn't reach GD-Sync. Check the internet connection and try again.")
