extends SceneTree
## godot --headless --path . --fixed-fps 120 --script res://tools/test_pouring_animation.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Pouring check timed out")
		quit(1))
	var home = load("res://scripts/core/home.gd")
	var activities = load("res://scripts/core/activities.gd")
	assert(load("res://tools/test_activities.gd").run())
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	var key := "kitchen/kitchen_kettle"
	assert(activities.available(key).is_empty())
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	home.is_done("kitchen_stove")
	assert(activities.available(key) == [[0, "Вскипятить чайник"], [1, "Налить чай Вите"]])
	var clip: Dictionary = activities.animation(key, 1)
	for mode in ["finish", "cancel", "moved", "missing_cup"]:
		var before: Dictionary = profile.data.duplicate(true)
		var view = load("res://scripts/art/location_view.gd").new()
		view.setup(home.location("kitchen").duplicate(true), Vector2(720, 1560))
		root.add_child(view)
		var kettle: Dictionary = view.activity_item(key)
		var cup: Dictionary = view.activity_item("kitchen/cup_daughter")
		if mode == "moved":
			kettle["draw"] = [440, 890, 85, 75]
			kettle["flip"] = true
			kettle["rot"] = 0.17
			cup["rect"] = [340, 1070, 28, 32]
			cup["rot"] = -0.1
		if mode == "missing_cup":
			view.loc["props"].erase(cup)
		var scene_before: Dictionary = view.loc.duplicate(true)
		var player: Node = load("res://scripts/art/activity_player.gd").new()
		view.add_child(player)
		var done := [false]
		player.finished.connect(func() -> void: done[0] = true)
		player.run.call_deferred(view, key, clip)
		while not done[0] and player.phase != "pour":
			await process_frame
		if mode != "missing_cup":
			assert(view.activity_hidden and view.activity_prop == "kitchen/kitchen_kettle")
			assert(player.has_node("SeatedDaughter"), "Vita keeps her authored kitchen pose")
			var vessel: Sprite2D = player.get_node("CarriedKettle")
			var stream: Line2D = player.get_node("TeaStream")
			assert(vessel.flip_h == (mode == "moved"))
			assert(stream.points[1].is_equal_approx(view.activity_point(cup, Vector2(0.5, 0.15))))
			assert(stream.points[0].distance_to(stream.points[1]) < 55.0)
			await create_timer(0.2).timeout
			assert(stream.width > 0.0)
			if mode == "cancel":
				player.queue_free()
		while not done[0]:
			await process_frame
		await process_frame
		assert(not view.activity_hidden and view.activity_prop.is_empty())
		assert(JSON.stringify(view.loc) == JSON.stringify(scene_before))
		assert(profile.data == before)
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
	router.top_popup().close(1)
	await create_timer(0.3).timeout
	assert(hub._busy and hub._view.activity_hidden)
	hub._play_activity(key, clip)
	await create_timer(0.3).timeout
	var old_view: Node = hub._view
	router.go(&"hub", {"location": "room"})
	while router.is_busy():
		await process_frame
	assert(not is_instance_valid(old_view) and home.completed() == 19)
	print("POUR: gate, cup anchor/tea stream, finish/cancel, edited kettle/cup, missing cup, actual menu and hub exit OK")
	quit()
