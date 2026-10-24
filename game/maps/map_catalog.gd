extends RefCounted

const MAPS := [
	{"name": "COURTYARD", "description": "The familiar street court", "tint": Color.WHITE, "preview": "res://level/level assets/basketball_court_toon.png"},
	{"name": "ESKINITA", "description": "Concrete lane beside colorful homes", "tint": Color.WHITE, "preview": "res://assets/maps/eskinita_floor.png"},
	{"name": "DUSTY YARD", "description": "Sandy clearing with palm trees", "tint": Color.WHITE, "preview": "res://assets/maps/dusty_yard_floor.png"},
]

static func configure(level: Node2D, index: int) -> void:
	level.modulate = MAPS[index].tint
	if index != 0:
		level.get_node("Decals").hide()
		_variant_scenery(level, index)
	# Retain the original props and their collisions, with a distinct layout per map.
	var layout := {
		"Bench 1": Vector2(700, 230), "Bench 2": Vector2(1320, 230),
		"Crate": Vector2(800, 380), "Crate1_2": Vector2(1280, 380),
		"Crate 2": Vector2(800, 820), "Create 2_2": Vector2(1280, 820),
		"Barrel": Vector2(700, 350), "Barrel2": Vector2(1400, 350),
		"BarrelTrio": Vector2(1420, 860), "Tire": Vector2(700, 870),
		"Cone": Vector2(620, 940), "Cone2": Vector2(910, 940),
		"Cone3": Vector2(1550, 940), "ConeBox": Vector2(1190, 940),
		"TrashCan": Vector2(1550, 240),
	}
	if index == 1:
		layout.merge({
			"Bench 1": Vector2(760, 200), "Bench 2": Vector2(1320, 960),
			"Crate": Vector2(680, 430), "Crate1_2": Vector2(1290, 290),
			"Crate 2": Vector2(690, 820), "Create 2_2": Vector2(1230, 830),
			"Barrel": Vector2(790, 300), "Barrel2": Vector2(1500, 360),
			"BarrelTrio": Vector2(1530, 920), "Tire": Vector2(780, 950),
			"Cone": Vector2(620, 180), "Cone2": Vector2(1110, 940),
			"Cone3": Vector2(1620, 920), "ConeBox": Vector2(1130, 180),
			"TrashCan": Vector2(1620, 200),
		}, true)
	elif index == 2:
		layout.merge({
			"Bench 1": Vector2(700, 200), "Bench 2": Vector2(1530, 230),
			"Crate": Vector2(820, 300), "Crate1_2": Vector2(1240, 420),
			"Crate 2": Vector2(700, 820), "Create 2_2": Vector2(1220, 900),
			"Barrel": Vector2(660, 400), "Barrel2": Vector2(1510, 830),
			"BarrelTrio": Vector2(1420, 330), "Tire": Vector2(900, 930),
			"Cone": Vector2(600, 980), "Cone2": Vector2(1100, 980),
			"Cone3": Vector2(1620, 860), "ConeBox": Vector2(1180, 200),
			"TrashCan": Vector2(1620, 400),
		}, true)
	var world := level.get_node("World")
	# Court hoops keep their authored end-line placement; other maps have none.
	if index != 0:
		for hoop_name in ["Ring 1", "Ring 2"]:
			world.get_node(NodePath(hoop_name)).free()
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
	# The visible bottom rail ends one tile above the copied tile bounds.
	bottom_fence.position.y = 1072.0 - world_offset.y - (top_row + copied_rows - 1) * upper_fence.tile_set.tile_size.y
	for cell in upper_fence.get_used_cells():
		if cell.y < top_row + copied_rows:
			bottom_fence.set_cell(cell, upper_fence.get_cell_source_id(cell), upper_fence.get_cell_atlas_coords(cell), upper_fence.get_cell_alternative_tile(cell))
	world.add_child(bottom_fence)

static func _variant_scenery(level: Node2D, index: int) -> void:
	level.get_node("Ground").hide()
	level.get_node("Backdrop/Trees").hide()
	var floor := Sprite2D.new()
	floor.name = "VariantFloor"
	floor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	floor.texture = load(MAPS[index].preview)
	floor.centered = false
	floor.position = Vector2(137, 33) - level.position
	floor.scale = Vector2(1600, 1039) / floor.texture.get_size()
	floor.z_index = -9
	level.add_child(floor)
	var art := "res://level/level assets/"
	if index == 1:
		level.get_node("Backdrop/Grass").hide()
		var street := Polygon2D.new()
		street.name = "StreetExterior"
		street.color = Color("74817a")
		street.polygon = PackedVector2Array([Vector2(-600, -600), Vector2(2500, -600), Vector2(2500, 1800), Vector2(-600, 1800)])
		street.position = -level.position
		level.get_node("Backdrop").add_child(street)
		for row in range(3):
			var roof: String = ["blue", "red", "green"][row]
			_decoration(level, "LaneHouseLeft%d" % row, art + "house-%s-roof-square-left-side.png" % roof, Vector2(-10, 160 + row * 410), 300)
			_decoration(level, "LaneHouseRight%d" % row, art + "house-%s-roof-square-right-side.png" % roof, Vector2(1880, 200 + row * 410), 300)
		var laundry := _decoration(level, "Clothesline", art + "background/clothesline_3q_topdown.png", Vector2(1060, -45), 420, false)
		laundry.z_index = 11 # Overhead and outside the playable floor.
	else:
		level.get_node("Backdrop/Grass").modulate = Color(1.0, 0.94, 0.78)
		for entry in [[Vector2(-50, 250), 310.0], [Vector2(1880, 380), 340.0], [Vector2(-30, 920), 280.0], [Vector2(1870, 1020), 310.0]]:
			_decoration(level, "YardPalm%d" % level.get_node("Backdrop").get_child_count(), art + "background/palm-tree_3q_topdown.png", entry[0], entry[1])
		_decoration(level, "YardPlant", art + "background/potted-plant_3q_topdown.png", Vector2(1810, 760), 100)

static func _decoration(level: Node2D, title: String, path: String, at: Vector2, width: float, shadowed: bool = true) -> Sprite2D:
	var parent := level.get_node("Backdrop")
	var sprite := Sprite2D.new()
	sprite.name = title
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture = load(path)
	sprite.position = at - level.position
	sprite.scale = Vector2.ONE * width / sprite.texture.get_width()
	if shadowed:
		var shadow := Node2D.new()
		shadow.name = title + "Shadow"
		shadow.position = sprite.position + Vector2(0, sprite.texture.get_height() * sprite.scale.y * 0.35)
		shadow.scale = Vector2.ONE * width / 140.0
		shadow.set_script(preload("res://ui/waiting_room/ground_shadow.gd"))
		parent.add_child(shadow)
	parent.add_child(sprite)
	return sprite
