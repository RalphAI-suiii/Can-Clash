extends RefCounted

const MAPS := [
	{"name": "COURTYARD", "description": "The familiar street court", "tint": Color(1, 1, 1), "preview": "res://level/level assets/basketball_court_toon.png"},
	{"name": "ESKINITA", "description": "A narrow lane with angled cover", "tint": Color(0.78, 0.88, 1), "preview": "res://level/level assets/ground_concrete_subtle.png"},
	{"name": "DUSTY YARD", "description": "A warm yard with scattered crates", "tint": Color(1, 0.87, 0.66), "preview": "res://level/level assets/ground_toon.png"},
]

static func configure(level: Node2D, index: int) -> void:
	level.modulate = MAPS[index].tint
	# Keep the shared safe-strip spawns clear of the barrel cluster's solid body.
	level.get_node("World/BarrelTrio").position = Vector2(100, -230)
	if index == 1:
		level.get_node("Decals").hide()
		level.get_node("World/Crate").position = Vector2(-70, -160)
		level.get_node("World/Crate1_2").position = Vector2(310, 180)
		level.get_node("World/Crate 2").position = Vector2(-80, 210)
	elif index == 2:
		level.get_node("Decals").hide()
		level.get_node("Ground").modulate = Color(1, 0.82, 0.55)
		level.get_node("Backdrop/Grass").modulate = Color(0.9, 0.8, 0.52)
		level.get_node("World/Crate").position = Vector2(80, -200)
		level.get_node("World/Crate1_2").position = Vector2(390, -120)
		level.get_node("World/Crate 2").position = Vector2(-200, 90)
		level.get_node("World/BarrelTrio").position = Vector2(230, 220)
