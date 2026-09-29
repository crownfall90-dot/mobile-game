extends SceneTree
## godot --headless --path . --script res://tools/test_kitchen_layout.gd
## Kitchen-only: editable sprites agree with the live layout; all five repairs stay reachable.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var home = load("res://scripts/core/home.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	var router := root.get_node("Router")
	router.forward_app_pause = false
	var kitchen: Dictionary = home.location("kitchen")
	assert(home.tasks().size() == 19)
	assert(kitchen["targets"].size() == 5)
	var scene: Node = load("res://scenes/locations/kitchen.tscn").instantiate()
	var keys := {}
	for node in scene.get_children():
		if node.get_meta("kind", "") not in ["target", "prop"]:
			continue
		assert(node is Sprite2D and node.texture != null)
		var key: String = node.get_meta("key")
		assert(not keys.has(key), "Duplicate keys would link two independent furniture pieces")
		keys[key] = node
	var items: Array = kitchen["targets"] + kitchen["props"]
	for item: Dictionary in items:
		var key: String = item.get("id", item.get("img", ""))
		assert(keys.has(key), "Missing editable sprite: " + key)
		var r: Array = item["rect"]
		assert(keys[key].position.distance_to(Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)) < 0.2)
	assert(keys.size() == items.size())
	scene.free()
	for repaired in [false, true]:
		for task: Dictionary in home.tasks():
			profile.set_flag("home." + task["id"], repaired or task["loc"] == "room")
		profile.set_flag("seen.kitchen")
		router.go(&"hub", {"location": "kitchen"})
		await create_timer(0.4).timeout
		var hub: Node = router.current_screen()
		var marks: Array = hub._mark_list()
		assert(marks.size() == 5)
		for i in kitchen["targets"].size():
			var task: Dictionary = kitchen["targets"][i]
			assert(task["level"] == "home_%02d" % (5 + i))
			assert(marks[i]["kind"] == ("act" if repaired else "repair"))
			assert(hub._view.target_at(marks[i]["at"], repaired).get("id") == task["id"])
			assert(Rect2(60, 110, 600, 1260).has_point(marks[i]["at"]))
	profile.grant("vita_teddy")
	router.go(&"hub", {"location": "kitchen"})
	await create_timer(0.4).timeout
	assert(router.current_screen()._view._teddy != null)
	assert(not router.current_screen()._view._teddy_in_art)
	assert(home.completed() == 19, "Opening the kitchen must not change repair progress")
	print("Kitchen: editable props, five repair/replay markers, teddy overlay OK")
	quit()
