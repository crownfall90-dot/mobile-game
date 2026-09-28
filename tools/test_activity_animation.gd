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
	assert(activities.available("room/room_chest").is_empty(), "Archived dialogue must not appear as a playable action")
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
	assert(count == 5)
	assert(view.activity_light and view.activity_curtains == 1.0)
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
	hub.call("_offer_actions", "room/room_table_lamp", "", "")
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
	print("ANIMATED ACTIVITIES: 5 clips, anchors, cancellation, progress and actual menu callback OK")
	quit()
