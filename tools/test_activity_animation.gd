extends SceneTree
## godot --headless --path . --fixed-fps 120 --script res://tools/test_activity_animation.gd



func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(80.0).timeout.connect(func() -> void:
		push_error("Animated activity check timed out")
		quit(1))
	var activities = load("res://scripts/core/activities.gd")
	var player_script = load("res://scripts/art/activity_player.gd")
	var home = load("res://scripts/core/home.gd")
	root.get_node("Router").forward_app_pause = false
	var profile := root.get_node("Profile")
	profile.volatile = true
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	var before: int = home.completed()
	var view = load("res://scripts/art/location_view.gd").new()
	var scene: Array = home.data()["scene"]["size"]
	view.setup(home.location("room").duplicate(true), Vector2(scene[0], scene[1]))
	root.add_child(view)
	var count := 0
	assert(activities.available("room/room_shelf_books").is_empty(), "Archived dialogue must not appear as a playable action")
	assert(activities.available("room_bed").size() == 2)
	for key: String in activities.all():
		for i in activities.all()[key]["acts"].size():
			var clip: Dictionary = activities.animation(key, i)
			if clip.is_empty():
				continue
			assert(clip["kind"] in player_script.KINDS)
			assert(clip["actor"] in ["mother", "daughter"])
			assert(not view.activity_item(key).is_empty())
			await view.play_activity(key, clip)
			assert(not view.activity_hidden)
			assert(home.completed() == before, "Activities must not grant repair progress")
			count += 1
	assert(count == 8)
	assert(view.activity_light and view.activity_curtains == 1.0)
	# No front drawer is offered when the owner selects a back-view cabinet.
	for item: Dictionary in home.location("room")["props"]:
		if item["img"] in ["room/room_chest", "room/room_nightstand"]:
			var original_view: Variant = item.get("view")
			item["view"] = "back"
			assert(activities.available("room/" + str(item["img"]).get_file()).is_empty())
			assert(not activities.has_animation("room/" + str(item["img"]).get_file()))
			if original_view == null:
				item.erase("view")
			else:
				item["view"] = original_view
	var lamp: Dictionary = view.activity_item("room/room_table_lamp")
	var at: Vector2 = view.activity_point(lamp, Vector2(0.25, 0.6))
	lamp["rect"][0] += 90
	lamp["rect"][1] += 35
	assert(view.activity_point(lamp, Vector2(0.25, 0.6)).is_equal_approx(at + Vector2(90, 35)))
	lamp["flip"] = true
	var r: Rect2 = view.activity_rect(lamp)
	assert(view.activity_point(lamp, Vector2(0.25, 0.6)).x > r.get_center().x)
	lamp["draw"] = [300, 900, r.size.x, r.size.y]
	lamp["rot"] = PI * 0.5
	assert(view.activity_point(lamp, Vector2(0.5, 0.5)).is_equal_approx(Vector2(300, 900)))
	# Exiting mid-action restores the actors and wakes an awaiting hub exactly once.
	var player: Node = player_script.new()
	view.add_child(player)
	player.run.call_deferred(view, "room_bed", activities.animation("room_bed", 0))
	await create_timer(0.1).timeout
	assert(view.activity_hidden)
	player.queue_free()
	await player.finished
	assert(not view.activity_hidden)
	await process_frame
	# Both original drawer facades follow their own perspective; check edited transforms.
	for key in ["room/room_chest", "room/room_nightstand"]:
		var item: Dictionary = view.activity_item(key)
		if key.ends_with("room_nightstand"):
			item["flip"] = true
			var box: Rect2 = view.activity_rect(item)
			item["draw"] = [box.get_center().x + 30, box.get_center().y + 15, box.size.x, box.size.y]
			item["rot"] = 0.18
		player = player_script.new()
		view.add_child(player)
		player.run.call_deferred(view, key, activities.animation(key, 0))
		while player.get("phase") != "action":
			await process_frame
		await create_timer(0.8).timeout
		var mount: Node2D = player.get_node("Drawer")
		var face: Polygon2D = mount.get_child(1)
		assert(face.texture == load("res://art/act1/" + str(item["img"]) + ".png"))
		assert(mount.position.is_equal_approx(view.activity_rect(item).get_center()))
		assert(face.position.length() > 1.0, "Drawer must visibly slide")
		assert((player.get("_actor").position + player.get("hand_offset")).is_equal_approx(
			player.get("contact") + mount.transform.basis_xform(face.position)), "Hand must follow drawer")
		player.queue_free()
		await player.finished
		assert(not view.activity_hidden)
		await process_frame
	# Sitting uses a floor pivot: breathing/rotating the rug cannot lift the feet.
	var rug: Dictionary = view.activity_item("room/room_rug")
	rug["rot"] = 0.3
	player = player_script.new()
	view.add_child(player)
	player.run.call_deferred(view, "room/room_rug", activities.animation("room/room_rug", 0))
	while player.get("phase") != "action":
		await process_frame
	await create_timer(0.8).timeout
	var rest: Sprite2D = player.get_node("Rest")
	assert(rest.texture == load("res://art/act1/family/actions/daughter_sit0.png"))
	assert(rest.rotation == 0.0, "The child stays upright on a rotated rug")
	assert(player.get("_actor").position.is_equal_approx(player.get("contact")), "Walk to the seat, not a hand stance")
	assert(rest.position.is_equal_approx(player.get("contact")))
	var foot := rest.position + Vector2(0, rest.offset.y + rest.texture.get_height() * 0.475) * rest.scale
	assert(foot.is_equal_approx(player.get("contact")), "Breathing must keep the floor pivot")
	player.queue_free()
	await player.finished
	assert(not view.activity_hidden)
	view.queue_free()
	await process_frame
	await process_frame
	# Real activity menu callback stays in the hub, then restores input/markers.
	var router := root.get_node("Router")
	profile.set_flag("seen.room")
	router.go(&"hub", {"location": "room"})
	while router.is_busy():
		await process_frame
	var hub: Node = router.current_screen()
	var marks: Array = hub.call("_mark_list")
	assert(marks.size() == 9, "Only repairs/replays and five animated props get markers")
	var offered := false
	for mark: Dictionary in marks:
		var callback: Callable = mark["do"]
		if callback.get_method() == &"_offer_actions" and callback.get_bound_arguments()[0] == "room/room_nightstand":
			callback.call()
			offered = true
	assert(offered, "Nightstand must have a working round marker")
	var popup: Node = router.top_popup()
	assert(popup != null)
	popup.call("close", 0)
	await create_timer(0.5).timeout
	assert(hub.get("_busy"))
	while hub.get("_busy"):
		assert(router.current_screen() == hub)
		await process_frame
	assert(hub.get("_marks").visible)
	assert(home.completed() == before)
	assert(await load("res://tools/test_dialogue.gd").run())
	print("ANIMATED ACTIVITIES: 8 clips, anchors, cancellation, progress and actual menu callback OK")
	quit()
