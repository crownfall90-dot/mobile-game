extends SceneTree
## godot --headless --path . --fixed-fps 120 --script res://tools/test_breakfast_animation.gd
## Add -- --home-stage=0 tea to check the living-room tea; add review for windowed screenshots.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Meal/tea check timed out")
		quit(1))
	var home = load("res://scripts/core/home.gd")
	var activities = load("res://scripts/core/activities.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	var tea := "tea" in OS.get_cmdline_user_args()
	var location := "living" if tea else "kitchen"
	var key := "living/living_table" if tea else "kitchen/kitchen_table"
	var action := 1 if tea else 0
	assert(activities.available(key) == [[action, "Попить чаю" if tea else "Позавтракать вместе"]])
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	home.is_done("kitchen_stove") # Run the existing save migration before snapshots.
	var clip: Dictionary = activities.animation(key, action)
	for mode in (["finish", "cancel", "cancel_walk", "moved", "teddy", "missing_table"] if tea else ["finish", "cancel", "moved", "teddy", "missing_chair"]):
		if mode == "teddy":
			profile.grant("vita_teddy")
		var before: Dictionary = profile.data.duplicate(true)
		var view = load("res://scripts/art/location_view.gd").new()
		view.setup(home.location(location).duplicate(true), Vector2(720, 1560))
		root.add_child(view)
		var table: Dictionary = view.activity_item(key)
		if mode == "moved":
			table["rect"] = [220, 950, 310, 300]
			table["draw"] = [375, 1050, 200, 110] if tea else [375, 1100, 350, 340]
			table["flip"] = true
			table["rot"] = 0.2
		if mode == "missing_chair":
			view.loc["props"].erase(view.activity_item("kitchen/kitchen_chair"))
		if mode == "missing_table":
			view.loc["props"].erase(table)
		var scene_before: Dictionary = view.loc.duplicate(true)
		var player: Node = load("res://scripts/art/activity_player.gd").new()
		view.add_child(player)
		var done := [false]
		player.finished.connect(func() -> void: done[0] = true)
		player.run.call_deferred(view, key, clip)
		if mode == "cancel_walk":
			while not done[0] and not view.activity_hidden:
				await process_frame
			assert(player.phase == "approach")
			player.queue_free()
		while not done[0] and player.phase != clip.get("phase", "eat"):
			await process_frame
		if not mode in ["missing_chair", "missing_table", "cancel_walk"]:
			var mount: Node2D = player.get_node(clip.get("mount", "Breakfast"))
			assert(mount.position.is_equal_approx(view.activity_rect(table).get_center()))
			assert(is_equal_approx(mount.rotation, float(table.get("rot", 0))))
			assert(mount.scale.x < 0 if mode == "moved" else mount.scale.x > 0)
			assert(view.activity_hidden and view.activity_props.size() == (3 if tea else 7))
			assert(view.activity_prop == location + "/" + location + "_table")
			assert(mount.get_node(location + "_table").get_index() > mount.get_node("Mother").get_index(), "Table must cover laps/legs")
			if tea:
				assert(not mount.get_node("cup_mother").visible and not mount.get_node("cup_daughter").visible, "Cups are in hands, not duplicated on table")
			var first: Array = []
			for spec: Dictionary in clip["poses"]:
				var body: Sprite2D = mount.get_node(spec["actor"])
				var at := Vector2(spec["at"][0], spec["at"][1])
				assert(body.global_position.is_equal_approx(view.activity_point(table, at)))
				first.append(body.texture.region)
			await create_timer(0.7).timeout
			for i in clip["poses"].size():
				assert(mount.get_node(clip["poses"][i]["actor"]).texture.region != first[i], "Both actors must reach the mouth frame")
			if mode == "cancel":
				player.queue_free()
		while not done[0]:
			await process_frame
		await process_frame
		assert(not view.activity_hidden and view.activity_prop.is_empty() and view.activity_props.is_empty())
		assert(JSON.stringify(view.loc) == JSON.stringify(scene_before), "Meal/tea must not change furniture: " + mode)
		assert(profile.data == before, "Meal/tea must not change repairs, stars or purchases: " + mode)
		view.queue_free()
		await process_frame
	var router := root.get_node("Router")
	router.forward_app_pause = false
	profile.set_flag("seen." + location)
	profile.set_flag("seen.room") # The destination intro is independent of drinking tea.
	router.go(&"hub", {"location": location})
	while router.is_busy():
		await process_frame
	var hub: Node = router.current_screen()
	var data_before_menu: Dictionary = profile.data.duplicate(true)
	for mark: Dictionary in hub._mark_list():
		var callback: Callable = mark["do"]
		if callback.get_method() == &"_offer_actions" and callback.get_bound_arguments()[0] == key:
			callback.call()
	assert(router.top_popup() != null)
	router.top_popup().close(action)
	await create_timer(0.3).timeout
	assert(hub._busy and not hub._marks.visible and hub._view.activity_hidden)
	if "review" in OS.get_cmdline_user_args():
		var player: Node = hub._view.get_child(hub._view.get_child_count() - 1)
		while player.phase != clip.get("phase", "eat"):
			await process_frame
		for frame in 2:
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://build/tea-review-%d.png" % frame) == OK)
			await create_timer(0.7).timeout
	while hub._busy:
		assert(router.current_screen() == hub)
		await process_frame
	assert(hub._marks.visible and hub._view.activity_props.is_empty())
	assert(profile.data == data_before_menu, "The actual activity menu must not grant progress")
	if "review" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://build/tea-review-restored.png") == OK)
	var data_before_exit: Dictionary = profile.data.duplicate(true)
	hub._play_activity(key, clip)
	await create_timer(0.3).timeout
	var old_view: Node = hub._view
	router.go(&"hub", {"location": "room"})
	while router.is_busy():
		await process_frame
	assert(not is_instance_valid(old_view) and home.completed() == 19)
	assert(profile.data == data_before_exit)
	assert(router.current_screen()._marks.visible and not router.current_screen()._busy)
	print(("TEA" if tea else "BREAKFAST") + ": both mouth frames, table occlusion, finish/cancel, edited table, purchases/missing prop, unchanged data, actual menu and leaving hub OK")
	quit()
