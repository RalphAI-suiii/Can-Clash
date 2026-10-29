extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session: Node = root.get_node("LanSession")
	session.begin_local("practice")
	change_scene_to_file("res://ui/waiting_room/waiting_room.tscn")
	await process_frame
	await process_frame
	var room: Node2D = current_scene
	assert(is_instance_valid(room.selection_overlay), "Practice should ask for a character first")
	assert(room.tutorial.lesson < 0, "Tutorial should wait for character selection")
	room.selection_overlay._select(0)
	room.selection_overlay._confirm()
	for index in range(4): await process_frame
	var guide: Node = room.tutorial
	assert(guide.lesson == guide.Lesson.MOVE, "Selected player should enter movement lesson")
	assert(guide.line_art.visible and guide.panel.visible, "Training line and guide should be visible")
	assert(guide.player.allowed_throw_rect.has_area(), "Thrower should practice from the marked line")
	await process_frame
	if DisplayServer.get_name() != "headless":
		assert(root.get_texture().get_image().save_png("res://tests/practice_tutorial_preview.png") == OK)
	guide.player.position = Vector2(980, 575)
	guide.travel = 125.0
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.MOVE and guide.lesson_complete and guide.continue_button.visible, "Movement should wait for Continue")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.SPRINT, "Continue should open sprint lesson")
	Input.action_press("sprint")
	Input.action_press("left")
	guide.player.velocity = Vector2(-250, 0)
	guide._process(0.8)
	Input.action_release("sprint")
	Input.action_release("left")
	assert(guide.lesson == guide.Lesson.SPRINT and guide.lesson_complete, "Sprinting should wait for Continue")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.HIT, "Continue should open aiming lesson")
	room.practice_cans[0].topple()
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.HIT and guide.lesson_complete and guide.player.skill_charge == 1, "A can hit should fill one orb and wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.RETRIEVE, "Continue should teach retrieval")
	guide._on_slipper_picked_up()
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.RETRIEVE and guide.lesson_complete, "Retrieval should wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.RETURN, "Continue should teach safe return")
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.RETURN and guide.lesson_complete, "Safe return should wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.ORBS, "Continue should teach orbs")
	for index in [1, 2]:
		room.practice_cans[index].topple()
		guide._process(0.016)
	assert(guide.lesson == guide.Lesson.ORBS and guide.lesson_complete and guide.player.skill_charge == 3, "Three hits should wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.ARM, "Continue should teach special arming")
	if DisplayServer.get_name() != "headless":
		await process_frame
		assert(root.get_texture().get_image().save_png("res://tests/practice_input_icon_preview.png") == OK)
	guide.player.special_armed = true
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.ARM and guide.lesson_complete, "Arming should wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.SPECIAL, "Continue should teach special launch")
	guide.player._start_charge()
	guide.player._start_throw(0.45)
	guide.player.attack_sprite.frame = 2
	guide.player._on_attack_frame_changed()
	assert(is_instance_valid(guide.player.active_slipper) and guide.player.active_slipper.special_kind != &"", "The lesson should launch the real character special")
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.SPECIAL and guide.lesson_complete, "Special launch should wait")
	# Thrower-phase auto stand can move the can's internal base away from the
	# guide's fixed yellow marker. Taya entry must restore the original base.
	room.practice_cans[0].base.global_position = room.practice_origins[0] + Vector2(-95, 0)
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.PICKUP and guide.player.is_taya, "Continue should use the real Taya role")
	var can: CharacterBody2D = room.practice_cans[0]
	assert(can.base.global_position == room.practice_origins[0], "Taya base must return to the yellow marker after thrower hits")
	assert(can.is_toppled() and can.global_position.distance_to(can.base.global_position) > 200.0, "Taya must recover a displaced can")
	guide.player.global_position = can.global_position
	for index in range(3): await physics_frame
	assert(guide.player.carrying_can and can.is_carried(), "Taya should pick up the fallen can automatically")
	for index in range(8):
		if guide.lesson_complete: break
		await process_frame
	assert(guide.lesson == guide.Lesson.PICKUP and guide.lesson_complete, "Pickup should wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.RESET_CAN, "Pickup should lead to the carry lesson")
	guide.player.global_position = can.base.global_position
	for index in range(4): await physics_frame
	for index in range(8):
		if guide.lesson_complete: break
		await process_frame
	assert(can.is_standing() and not guide.player.carrying_can, "Returning to base should reset the can")
	assert(can.global_position.distance_to(can.base.global_position) < 0.01, "Can should stand exactly at its ground marker")
	assert(guide.lesson == guide.Lesson.RESET_CAN and guide.lesson_complete, "Can reset should wait")
	if DisplayServer.get_name() != "headless":
		await process_frame
		assert(root.get_texture().get_image().save_png("res://tests/practice_taya_reset_preview.png") == OK)
	guide._continue_lesson()
	assert(is_instance_valid(guide.dummy) and guide.lesson == guide.Lesson.LUNGE, "Reset should open the tag drill")
	Input.action_press("lunge")
	for index in range(3): await physics_frame
	Input.action_release("lunge")
	for index in range(34): await physics_frame
	assert(guide.lesson == guide.Lesson.LUNGE and guide.lesson_complete, "Space should finish the lunge lesson and wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.TAG, "Continue should open tag lesson")
	if guide.lesson == guide.Lesson.TAG:
		guide.player.global_position = guide.dummy.global_position + Vector2(-35, 0)
		for index in range(6): await physics_frame
	assert(guide.lesson == guide.Lesson.TAG and guide.lesson_complete, "Contact should wait")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.STUN, "Continue should open stun lesson")
	assert(guide.player.taya_action == &"", "Tag drill should clear an in-progress lunge")
	guide.player.taya_stun_ready_at = session.clock_time() + 120.0
	guide._process(0.016)
	assert(guide.player.taya_stun_ready_at == 0.0, "A missed tutorial stun should be retryable")
	assert(guide.player.begin_taya_stun_aim(), "Taya should be able to aim the stun slipper")
	assert(guide.player.release_taya_stun(guide.dummy.global_position), "Taya should launch the stun slipper")
	for index in range(60): await physics_frame
	assert(guide.dummy.is_stunned() and guide.lesson == guide.Lesson.STUN and guide.lesson_complete, "Stun should wait for Continue")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.DONE, "Continue should finish the tutorial")
	guide.restart()
	assert(guide.lesson == guide.Lesson.MOVE and not guide.player.is_taya, "Restart should restore thrower training")
	assert(session.select_character(5), "Leonardo should remain selectable in Practice")
	for index in range(3): await process_frame
	guide.restart()
	assert(not guide.player.has_thrower_special(), "Leonardo has ordinary throws for now")
	guide._set_lesson(guide.Lesson.RETURN)
	guide.player.position = Vector2(980, 575)
	guide._process(0.016)
	assert(guide.lesson == guide.Lesson.RETURN and guide.lesson_complete, "Characters without specials should finish safe return first")
	guide._continue_lesson()
	assert(guide.lesson == guide.Lesson.PICKUP, "Continue should take them to Taya training")
	guide._free_practice()
	assert(guide.free_mode and not guide.player.allowed_throw_rect.has_area() and guide.base_art.visible, "Free practice should remove restrictions and retain the Taya base marker")
	print("PASS: Practice tutorial character entry, can recovery, stun and restart")
	quit()
