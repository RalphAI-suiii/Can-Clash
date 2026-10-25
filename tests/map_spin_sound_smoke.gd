extends SceneTree

func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("FAIL: map spin audio timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("LanSession")
	var music := root.get_node("Music")
	session.begin_local("developer")
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "SpinTest")
	AudioServer.set_bus_volume_db(bus, -80)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 0.5
	AudioServer.add_bus_effect(bus, capture)
	for map in range(3):
		session.selected_map = map
		var selection: Control = load("res://ui/map_select/map_select.tscn").instantiate()
		root.add_child(selection)
		selection.set_process(false)
		var sound: AudioStreamPlayer = selection.spin_audio
		sound.bus = "SpinTest"
		assert(sound.playing and not sound.stream.loop)
		assert(sound.stream.get_length() > 13 and sound.stream.get_length() < 15)
		assert(is_equal_approx((selection.SOUND_LANDING - selection.SOUND_START) / sound.pitch_scale, selection.SPIN_SECONDS))
		assert(music.current_track == "lobby" and music.players[music.active_index].playing)
		await create_timer(0.3).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in samples: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		assert(peak > 0.001, "Effect must produce non-silent PCM immediately after the skipped lead-in")
		assert(sound.get_playback_position() >= selection.SOUND_START)
		var position := sound.get_playback_position()
		selection._process(4.9)
		assert(not selection.landed and sound.playing)
		selection._process(0.1)
		assert(selection.landed and selection.caption.text.ends_with(" SELECTED"))
		assert(sound.playing and sound.get_playback_position() >= position, "Landing must not restart the ending cue")
		selection._process(0.5)
		assert(sound.playing)
		selection._exit_tree()
		assert(not sound.playing, "Early leave/host disconnect must stop the effect")
		selection.free()
		capture.clear_buffer()
		print("PASS: map %d one-shot wheel audio, immediate PCM, five-second cue alignment, unchanged music, no landing restart and exit cleanup" % map)
	for player in music.players: player.stop()
	AudioServer.remove_bus(bus)
	await create_timer(0.1).timeout
	session.close_room()
	quit(0)
