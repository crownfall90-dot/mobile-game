extends SceneTree
## godot --headless --path . --fixed-fps 120 --script res://tools/test_cooking_animation.gd
## Add -- kettle to check the kettle and its actual prop menu instead.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		push_error("Cooking check timed out")
		quit(1))
	var home = load("res://scripts/core/home.gd")
	var activities = load("res://scripts/core/activities.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	var is_kettle := "kettle" in OS.get_cmdline_user_args()
	var key := "kitchen/kitchen_kettle" if is_kettle else "kitchen_stove"
	var action_phase := "boil" if is_kettle else "stir"
	assert(activities.available(key).is_empty())
	assert(not activities.locked_reason(key).is_empty())
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	assert(activities.available(key) == ([[0, "Вскипятить чайник"], [1, "Налить чай Вите"]] if is_kettle else [[0, "Сварить кашу"]]))
	var before: Dictionary = profile.data.duplicate(true)
	var clip: Dictionary = activities.animation(key, 0)
	for mode in ["finish", "cancel", "moved"]:
		var view = load("res://scripts/art/location_view.gd").new()
		view.setup(home.location("kitchen").duplicate(true), Vector2(720, 1560))
		root.add_child(view)
		var pot: Dictionary = view.activity_item(key if is_kettle else clip["vessel"])
		if mode == "moved":
			pot["rect"] = [350, 900, 140, 95]
			pot["flip"] = true
			pot["rot"] = 0.15
			if is_kettle:
				pot["draw"] = [420, 950, 140, 95]
		var player: Node = load("res://scripts/art/activity_player.gd").new()
		view.add_child(player)
		var done := [false]
		player.finished.connect(func() -> void: done[0] = true)
		player.run.call_deferred(view, key, clip)
		while player.phase != action_phase:
			await process_frame
		var pose: Node2D = player.get_node("Kettle" if is_kettle else "Cooking")
		var moving: Node2D = pose if is_kettle else pose.get_node("Arm")
		assert(view.activity_prop == ("kitchen/kitchen_kettle" if is_kettle else "family/mother_kitchen_v2"))
		assert(not view.activity_hidden, "Daughter must remain in her seated scene pose")
		if is_kettle:
			assert(pose.position.is_equal_approx(view.activity_rect(pot).get_center()))
			assert(pose.flip_h == (mode == "moved"))
			assert((pose.texture.get_size() * pose.scale).is_equal_approx(view.activity_rect(pot).size))
			assert(player.contact.is_equal_approx(view.activity_point(pot, Vector2(0.15, 0.36))))
			assert(player.get_node("Steam").position.is_equal_approx(player.contact))
		else:
			assert(pose.position.is_equal_approx(view.activity_point(pot, Vector2(0.75, 0.5))))
			assert(pose.scale.x < 0 if mode == "moved" else pose.scale.x > 0)
		assert(absf(pose.rotation - float(pot.get("rot", 0))) < 0.019 if is_kettle else is_equal_approx(pose.rotation, float(pot.get("rot", 0))))
		var initial := moving.rotation
		var steam_start: Vector2 = player.get_node("Steam").position
		for i in 30:
			await process_frame
		assert(not is_equal_approx(moving.rotation, initial), "The kettle or arm/spoon must move")
		if not is_kettle:
			assert(pose.position.is_equal_approx(player.contact), "Torso must stay at the vessel anchor")
		assert(player.get_node("Steam").get_child_count() == 3)
		await create_timer(0.35).timeout
		assert(player.get_node("Steam").modulate.a < 1.0 and player.get_node("Steam").position.y < steam_start.y)
		if mode == "cancel":
			player.queue_free()
		while not done[0]:
			await process_frame
		await process_frame
		assert(not view.activity_hidden and view.activity_prop.is_empty())
		assert(profile.data == before, "Household actions cannot grant repairs, stars or purchases")
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
	assert(router.top_popup() != null, "Repaired stove must open the activity menu")
	router.top_popup().close(0)
	await create_timer(0.3).timeout
	assert(hub._busy and not hub._marks.visible)
	while hub._busy:
		assert(router.current_screen() == hub)
		await process_frame
	assert(hub._marks.visible and hub._view.activity_prop.is_empty())
	hub._play_activity(key, clip)
	await create_timer(0.3).timeout
	var old_view: Node = hub._view
	router.go(&"hub", {"location": "room"})
	while router.is_busy():
		await process_frame
	assert(not is_instance_valid(old_view), "Leaving the hub must cancel/free the cooking view")
	assert(home.completed() == 19)
	print(key + ": repair gate, moving object/steam, finish/cancel, moved/flipped/rotated vessel, actual menu and leaving hub OK")
	quit()
