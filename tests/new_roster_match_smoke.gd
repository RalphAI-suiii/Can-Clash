extends Node

# Run with: godot --headless --path . res://tests/new_roster_match_smoke.tscn
func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	LanSession.begin_local("developer")
	LanSession.developer_bot_count = 1
	LanSession.players[0].character = 5
	LanSession.add_developer_bots()
	LanSession.players[1].character = 6
	var match_scene := load("res://game/match/match.tscn") as PackedScene
	var arena_match = match_scene.instantiate()
	get_tree().root.add_child(arena_match)
	await get_tree().process_frame
	var leonardo = arena_match.actors.get(LanSession.local_id())
	var kay = arena_match.actors.get(-1)
	if leonardo == null or kay == null or leonardo.art_name != "leonardo" or kay.art_name != "kay":
		push_error("Leonardo or Kay did not spawn with the selected art")
		get_tree().quit(1)
		return
	if leonardo.has_thrower_special() or kay.has_thrower_special():
		push_error("New characters gained an unassigned thrower special")
		get_tree().quit(1)
		return
	for actor in [leonardo, kay]:
		actor.set_taya_role(true)
		if not actor.is_taya or not actor.taya_visual.body.sprite_frames.has_animation(&"can_pickup"):
			push_error("New character could not take the Taya role")
			get_tree().quit(1)
			return
		actor.carrying_can = true
		actor._process(1.0 / 60.0)
		if actor.taya_visual.action != &"pickup" or actor.sprite.visible:
			push_error("Taya can pickup did not trigger its visual")
			get_tree().quit(1)
			return
		actor.carrying_can = false
		actor._process(1.0 / 60.0)
		if actor.taya_visual.action != &"place":
			push_error("Taya can reset did not trigger its visual")
			get_tree().quit(1)
			return
		actor.set_taya_role(false)
	print("NEW ROSTER MATCH: Leonardo and Kay spawned, ordinary throws, Taya role and can visuals OK")
	get_tree().quit()
