extends RefCounted

const MAPS := [
	{"name": "COURTYARD", "description": "The familiar street court", "tint": Color(1, 1, 1), "preview": "res://level/level assets/basketball_court_toon.png"},
	{"name": "ESKINITA", "description": "A narrow lane with angled cover", "tint": Color(0.78, 0.88, 1), "preview": "res://level/level assets/ground_concrete_subtle.png"},
	{"name": "DUSTY YARD", "description": "A warm yard with scattered crates", "tint": Color(1, 0.87, 0.66), "preview": "res://level/level assets/ground_toon.png"},
]

static func configure(level: Node2D, index: int) -> void:
	level.modulate = MAPS[index].tint
	if index != 0: level.get_node("Decals").hide()
	if index == 2:
		level.get_node("Ground").modulate = Color(1, 0.82, 0.55)
		level.get_node("Backdrop/Grass").modulate = Color(0.9, 0.8, 0.52)
	# Keep every original prop, arranged in spaced groups around an open center.
	var layout := {
		"Bench 1": Vector2(700, 230), "Bench 2": Vector2(1320, 230),
		"Ring 1": Vector2(1540, 650), "Ring 2": Vector2(630, 400),
		"Crate": Vector2(800, 380), "Crate1_2": Vector2(1280, 380),
		"Crate 2": Vector2(800, 820), "Create 2_2": Vector2(1280, 820),
		"Barrel": Vector2(700, 350), "Barrel2": Vector2(1400, 350),
		"BarrelTrio": Vector2(1420, 860), "Tire": Vector2(700, 870),
		"Cone": Vector2(620, 940), "Cone2": Vector2(910, 940),
		"Cone3": Vector2(1550, 940), "ConeBox": Vector2(1190, 940),
		"TrashCan": Vector2(1550, 240),
	}
	var world := level.get_node("World")
	# configure runs before add_child; include the scene root's authored offset.
	var world_offset: Vector2 = level.position + world.position
	for prop_name in layout:
		var prop: Node2D = world.get_node(NodePath(prop_name))
		prop.position = Vector2(layout[prop_name]) - world_offset

	# Reuse the upper fence tiles for a matching foreground fence along the curb.
	var upper_fence: TileMapLayer = world.get_node("FenceLayer")
	var bottom_fence := TileMapLayer.new()
	bottom_fence.name = "BottomFence"
	bottom_fence.tile_set = upper_fence.tile_set
	bottom_fence.collision_enabled = false # The existing bottom world border owns collision.
	var top_row := upper_fence.get_used_rect().position.y
	var copied_rows := 13
	bottom_fence.position.y = 1040.0 - world_offset.y - (top_row + copied_rows) * upper_fence.tile_set.tile_size.y
	for cell in upper_fence.get_used_cells():
		if cell.y < top_row + copied_rows:
			bottom_fence.set_cell(cell, upper_fence.get_cell_source_id(cell), upper_fence.get_cell_atlas_coords(cell), upper_fence.get_cell_alternative_tile(cell))
	world.add_child(bottom_fence)
