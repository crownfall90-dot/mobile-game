extends SceneTree
## godot --headless --path . --fixed-fps 120 --script res://tools/test_breakfast_animation.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Breakfast check timed out")
		quit(1))
	var home = load("res://scripts/core/home.gd")
	var activities = load("res://scripts/core/activities.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	var key := "kitchen/kitchen_table"
	assert(activities.available(key) == [[0, "Позавтракать вместе"]])
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	home.is_done("kitchen_stove") # Run the existing save migration before snapshots.
	var clip: Dictionary = activities.animation(key, 0)
	for mode in ["finish", "cancel", "moved", "teddy", "missing_chair"]:
		if mode == "teddy":
			profile.grant("vita_teddy")
		var before: Dictionary = profile.data.duplicate(true)
		var view = load("res://scripts/art/location_view.gd").new()
		view.setup(home.location("kitchen").duplicate(true), Vector2(720, 1560))
		root.add_child(view)
		var table: Dictionary = view.activity_item(key)
		if mode == "moved":
			table["rect"] = [220, 950, 310, 300]
			table["draw"] = [375, 1100, 350, 340]
			table["flip"] = true
			table["rot"] = 0.2
		if mode == "missing_chair":
			view.loc["props"].erase(view.activity_item("kitchen/kitchen_chair"))
		var scene_before: Dictionary = view.loc.duplicate(true)
		var player: Node = load("res://scripts/art/activity_player.gd").new()
		view.add_child(player)
		var done := [false]
		player.finished.connect(func() -> void: done[0] = true)
		player.run.call_deferred(view, key, clip)
		while not done[0] and player.phase != "eat":
			await process_frame
		if mode != "missing_chair":
			var mount: Node2D = player.get_node("Breakfast")
			assert(mount.position.is_equal_approx(view.activity_rect(table).get_center()))
			assert(is_equal_approx(mount.rotation, float(table.get("rot", 0))))
			assert(mount.scale.x < 0 if mode == "moved" else mount.scale.x > 0)
			assert(view.activity_hidden and view.activity_props.size() == 7)
			assert(view.activity_prop == "kitchen/kitchen_table")
			assert(mount.get_node("kitchen_table").get_index() > mount.get_node("Mother").get_index(), "Table must cover laps/legs")
			var first: Array = []
			for spec: Dictionary in clip["poses"]:
				var body: Sprite2D = mount.get_node(spec["actor"])
				var at := Vector2(spec["at"][0], spec["at"][1])
				assert(body.global_position.is_equal_approx(view.activity_point(table, at)))
				first.append(body.texture.region)
			await create_timer(0.7).timeout
			for i in clip["poses"].size():
				assert(mount.get_node(clip["poses"][i]["actor"]).texture.region != first[i], "Both spoons must reach the mouth frame")
			if mode == "cancel":
				player.queue_free()
		while not done[0]:
			await process_frame
		await process_frame
		assert(not view.activity_hidden and view.activity_prop.is_empty() and view.activity_props.is_empty())
		assert(JSON.stringify(view.loc) == JSON.stringify(scene_before), "Breakfast must not change furniture: " + mode)
		assert(profile.data == before, "Breakfast must not change repairs, stars or purchases: " + mode)
		view.queue_free()
		await process_frame
	var router := root.get_node("Router")
	router.forward_app_pause = false
	profile.set_flag("seen.kitchen")
	router.go(&"hub", {"location": "kitchen"})
	while router.is_busy():
		await process_frame
	var hub: Node = router.current_screen()
	for mark: Dictionary in hub._mark_list():
		var callback: Callable = mark["do"]
		if callback.get_method() == &"_offer_actions" and callback.get_bound_arguments()[0] == key:
			callback.call()
	assert(router.top_popup() != null)
	router.top_popup().close(0)
	await create_timer(0.3).timeout
	assert(hub._busy and not hub._marks.visible and hub._view.activity_hidden)
	while hub._busy:
		assert(router.current_screen() == hub)
		await process_frame
	assert(hub._marks.visible and hub._view.activity_props.is_empty())
	hub._play_activity(key, clip)
	await create_timer(0.3).timeout
	var old_view: Node = hub._view
	router.go(&"hub", {"location": "room"})
	while router.is_busy():
		await process_frame
	assert(not is_instance_valid(old_view) and home.completed() == 19)
	print("BREAKFAST: both eating frames, table occlusion, finish/cancel, edited table, teddy/missing chair, unchanged data, actual menu and leaving hub OK")
	quit()
