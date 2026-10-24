extends SceneTree

func _initialize() -> void:
	create_timer(20).timeout.connect(func() -> void: printerr("FAIL: map identity timeout"); quit(1))
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("LanSession")
	var layouts := []
	var props := ["Bench 1", "Bench 2", "Crate", "Crate1_2", "Crate 2", "Create 2_2", "Barrel", "Barrel2", "BarrelTrio", "Tire", "Cone", "Cone2", "Cone3", "ConeBox", "TrashCan"]
	for index in range(3):
		session.begin_local("developer")
		session.selected_map = index
		var game: Node2D = load("res://game/match/match.tscn").instantiate()
		root.add_child(game)
		current_scene = game
		game.set_physics_process(false)
		for actor in game.actors.values(): actor.set_physics_process(false)
		var level: Node2D = game.get_child(0)
		var world := level.get_node("World")
		var layout := {}
		for prop_name in props:
			var prop: StaticBody2D = world.get_node(NodePath(prop_name))
			assert(prop.collision_layer != 0)
			assert(not game.SAFE.has_point(prop.global_position), "Blue zone remains clear")
			assert(prop.global_position.distance_to(game.can.base.position) > 160, "Can area remains clear")
			layout[prop_name] = prop.global_position
		layouts.append(layout)
		assert(world.has_node("BottomFence") and world.has_node("World Border"))
		assert(game.can.base.global_position == Vector2(1450, 610))
		if index == 0:
			assert(level.get_node("Ground").visible and level.get_node("Decals").visible)
			assert(world.has_node("Ring 1") and world.has_node("Ring 2"))
			assert(not level.has_node("VariantFloor"))
		else:
			assert(not level.get_node("Ground").visible and not level.get_node("Decals").visible)
			assert(not world.has_node("Ring 1") and not world.has_node("Ring 2"))
			assert(level.get_node("VariantFloor").texture.resource_path == game.CATALOG.MAPS[index].preview)
			assert(not level.get_node("Backdrop/Trees").visible)
			if index == 1:
				assert(level.has_node("Backdrop/LaneHouseLeft0") and level.has_node("Backdrop/LaneHouseRight2") and level.has_node("Backdrop/Clothesline"))
			else:
				assert(level.get_node("Backdrop").get_children().filter(func(node: Node) -> bool: return String(node.name).begins_with("YardPalm") and node is Sprite2D).size() == 4)
		game.free()
		session.close_room()
	for first in range(3):
		for second in range(first + 1, 3):
			var moved := 0
			for prop_name in props:
				if layouts[first][prop_name] != layouts[second][prop_name]: moved += 1
			assert(moved >= 10, "Each map needs a distinct obstacle arrangement")
	for player in root.get_node("Music").players: player.stop()
	await create_timer(0.1).timeout
	print("PASS: three distinct maps; original court/hoops preserved, concrete houses/laundry and sandy palms have unique layouts; all props, blue clearance, can space and fences retained")
	quit(0)
