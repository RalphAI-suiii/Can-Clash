extends Node

const TRACKS := {
	"menu": "res://assets/audio/music/angry-duck --mainmenu.mp3",
	"lobby": "res://assets/audio/music/rainbow-beat --lobby.mp3",
	"battle": "res://assets/audio/music/silly-duck --battle match.mp3",
	"intense": "res://assets/audio/music/dank-memes --intense battle match.mp3",
}

@export_range(-40, 0, 1) var volume_db := -12.0
@export_range(0.0, 3.0, 0.1) var fade_seconds := 0.8
@export_range(10, 180, 1) var intense_seconds := 60.0

var current_track := ""
var players: Array[AudioStreamPlayer] = []
var active_index := 0
var fade: Tween

func _ready() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		players.append(player)

func play_music(track: String) -> void:
	if track == current_track or not TRACKS.has(track): return
	var stream: AudioStreamMP3 = load(TRACKS[track])
	if stream == null: return
	stream.loop = true
	if fade != null and fade.is_valid(): fade.kill()
	var outgoing := players[active_index]
	active_index = 1 - active_index
	var incoming := players[active_index]
	incoming.stop()
	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()
	current_track = track
	fade = create_tween().set_parallel()
	fade.tween_method(_set_gain.bind(outgoing), db_to_linear(outgoing.volume_db), 0.0, fade_seconds)
	fade.tween_method(_set_gain.bind(incoming), 0.0, db_to_linear(volume_db), fade_seconds)
	fade.chain().tween_callback(outgoing.stop)

func update_match(stage: String, remaining: float) -> void:
	if stage == "active":
		play_music("intense" if remaining <= intense_seconds or current_track == "intense" else "battle")
	elif stage in ["loading", "preparation"]:
		play_music("lobby")

func _set_gain(gain: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(maxf(0.0001, gain))
