extends Node

var selected_character_scene := "res://scenes/Thrower Hat Thrower.tscn"
var display_name := "Player"
var tutorial_seen := false
var statistics := {"wins": 0, "losses": 0, "successful_throws": 0, "can_knockdowns": 0}
var completed_matches: Array = []

func _ready() -> void:
	load_profile()

func profile_path() -> String:
	var override := OS.get_environment("CAN_CLASH_SAVE_PATH")
	return override if not override.is_empty() else "user://profile.cfg"

func clean_name(value: String) -> String:
	return value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(20)

func set_display_name(value: String) -> void:
	display_name = clean_name(value)
	if display_name.is_empty():
		display_name = "Player"
	save_profile()

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(profile_path()) != OK:
		return
	display_name = clean_name(str(config.get_value("player", "name", "Player")))
	if display_name.is_empty():
		display_name = "Player"
	selected_character_scene = str(config.get_value("player", "character", selected_character_scene))
	tutorial_seen = bool(config.get_value("player", "tutorial_seen", false))
	for key in statistics:
		statistics[key] = maxi(0, int(config.get_value("statistics", key, 0)))
	completed_matches = config.get_value("statistics", "completed_matches", [])

func save_profile() -> Error:
	var config := ConfigFile.new()
	config.set_value("player", "name", display_name)
	config.set_value("player", "character", selected_character_scene)
	config.set_value("player", "tutorial_seen", tutorial_seen)
	for key in statistics:
		config.set_value("statistics", key, statistics[key])
	config.set_value("statistics", "completed_matches", completed_matches)
	return config.save(profile_path())

func record_hit() -> void:
	statistics.successful_throws += 1
	statistics.can_knockdowns += 1
	save_profile()

func record_result(match_id: String, won: bool) -> void:
	if match_id.is_empty() or completed_matches.has(match_id):
		return
	completed_matches.append(match_id)
	if completed_matches.size() > 40:
		completed_matches.pop_front()
	statistics["wins" if won else "losses"] += 1
	save_profile()
