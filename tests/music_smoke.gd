extends SceneTree

func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("FAIL: music check timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var music := root.get_node("Music")
	var session := root.get_node("LanSession")
	root.get_node("UserSettings").tutorial_seen = true
	for file in ["angry-duck --mainmenu.mp3", "rainbow-beat --lobby.mp3", "silly-duck --battle match.mp3", "dank-memes --intense battle match.mp3", "mr-snarky-destructoid --trailer music.mp3"]:
		var stream: AudioStreamMP3 = load("res://assets/audio/music/" + file)
		assert(stream.get_length() > 5.0, "Supplied MP3 must decode: " + file)
		print("MP3: ", file, " ", snappedf(stream.get_length(), 0.01), " seconds")
	var bus := AudioServer.get_bus_index("Music")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.2
	AudioServer.add_bus_effect(bus, capture)
	var menu: Control = load("res://ui/main_menu/main_menuu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await create_timer(1.0).timeout
	assert(music.current_track == "menu")
	assert(music.players[music.active_index].playing and music.players[music.active_index].stream.loop)
	assert(is_equal_approx(music.players[music.active_index].volume_db, music.volume_db))
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in samples: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	assert(peak > 0.00001, "Music bus must produce actual non-silent PCM audio")
	menu.free()
	assert(music.players[music.active_index].playing, "Music must survive scene changes")
	session.begin_local("practice")
	var room: Node2D = load("res://ui/waiting_room/waiting_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	await create_timer(1.0).timeout
	assert(music.current_track == "lobby")
	assert(not music.players[1 - music.active_index].playing, "Old music stops after the fade")
	var lobby_player: AudioStreamPlayer = music.players[music.active_index]
	var position := lobby_player.get_playback_position()
	room.free()
	var selection: Control = load("res://ui/map_select/map_select.tscn").instantiate()
	root.add_child(selection)
	current_scene = selection
	assert(music.players[music.active_index] == lobby_player and lobby_player.get_playback_position() >= position)
	selection.free()
	session.begin_local("developer")
	session.add_developer_bots()
	var game: Node2D = load("res://game/match/match.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	for actor in game.actors.values(): actor.set_physics_process(false)
	for phase in ["loading", "preparation"]:
		game.stage = phase
		game._update_hud()
		assert(music.current_track == "lobby")
	game.stage = "active"
	game.remaining = 600
	game._update_hud()
	assert(music.current_track == "battle")
	game.remaining = 60.001
	game._update_hud()
	assert(music.current_track == "battle")
	game.remaining = 60
	game._update_hud()
	assert(music.current_track == "intense")
	await create_timer(1.0).timeout
	var intense_player: AudioStreamPlayer = music.players[music.active_index]
	position = intense_player.get_playback_position()
	for i in range(30): game._update_hud()
	assert(music.players[music.active_index] == intense_player and intense_player.get_playback_position() >= position, "Snapshots must not restart intense music")
	assert(not music.players[1 - music.active_index].playing)
	# Clock correction near the threshold must not oscillate between the tracks.
	game.remaining = 60.02
	game._update_hud()
	assert(music.current_track == "intense")
	game.free()
	session.results = [{"id": 1, "name": "Player", "score": 1, "character": 0, "color": Color.WHITE}]
	var results: Control = load("res://ui/results/results.tscn").instantiate()
	root.add_child(results)
	current_scene = results
	assert(music.current_track == "menu")
	await create_timer(1.0).timeout
	assert(music.players[music.active_index].playing and not music.players[1 - music.active_index].playing)
	# A new match resets the closing-minute cue.
	music.play_music("lobby")
	music.update_match("active", 600)
	assert(music.current_track == "battle")
	await create_timer(1.0).timeout
	assert(not music.players[1 - music.active_index].playing)
	results.free()
	session.close_room()
	for player in music.players: player.stop()
	AudioServer.remove_bus_effect(bus, AudioServer.get_bus_effect_count(bus) - 1)
	await create_timer(0.1).timeout
	print("PASS: five MP3s decode; non-silent playback, looping, crossfades, scene continuity, final-60-second cue, no snapshot restarts, results and new-match reset")
	quit(0)
