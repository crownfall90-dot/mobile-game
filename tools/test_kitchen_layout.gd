extends SceneTree
## godot --headless --path . --script res://tools/test_kitchen_layout.gd
## Add -- bath or -- living for one location only; editable sprites and five reachable repairs/replays.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var home = load("res://scripts/core/home.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	var router := root.get_node("Router")
	router.forward_app_pause = false
	var loc_id := "living" if "living" in OS.get_cmdline_user_args() else ("bath" if "bath" in OS.get_cmdline_user_args() else "kitchen")
	var loc: Dictionary = home.location(loc_id)
	assert(home.tasks().size() == 19)
	assert(loc["targets"].size() == 5)
	var scene: Node = load("res://scenes/locations/%s.tscn" % loc_id).instantiate()
	var keys := {}
	for node in scene.get_children():
		if node.get_meta("kind", "") not in ["target", "prop"]:
			continue
		assert(node is Sprite2D and node.texture != null)
		var key: String = node.get_meta("key")
		assert(not keys.has(key), "Duplicate keys would link two independent furniture pieces")
		keys[key] = node
	var items: Array = loc["targets"] + loc["props"]
	for item: Dictionary in items:
		var key: String = item.get("id", item.get("img", ""))
		assert(keys.has(key), "Missing editable sprite: " + key)
		var r: Array = item["rect"]
		assert(keys[key].position.distance_to(Vector2(r[0] + r[2] / 2.0, r[1] + r[3] / 2.0)) < 0.2)
	assert(keys.size() == items.size())
	scene.free()
	for repaired in [false, true]:
		for task: Dictionary in home.tasks():
			profile.set_flag("home." + task["id"], repaired or task["loc"] == "room" or (loc_id in ["bath", "living"] and task["loc"] == "kitchen") or (loc_id == "living" and task["loc"] == "bath"))
		profile.set_flag("seen." + loc_id)
		router.go(&"hub", {"location": loc_id})
		await create_timer(0.4).timeout
		var hub: Node = router.current_screen()
		var marks: Array = hub._mark_list()
		assert(marks.size() == (7 if loc_id == "kitchen" else 5))
		if loc_id == "kitchen":
			assert(marks[5]["kind"] == "act")
			assert(marks[6]["kind"] == ("act" if repaired else "lock"))
			for mark: Dictionary in marks.slice(5):
				assert(Rect2(60, 110, 600, 1260).has_point(mark["at"]))
		for i in loc["targets"].size():
			var task: Dictionary = loc["targets"][i]
			assert(task["level"] == "home_%02d" % (({"kitchen": 5, "bath": 10, "living": 15}[loc_id]) + i))
			assert(marks[i]["kind"] == ("act" if repaired else "repair"))
			assert(hub._view.target_at(marks[i]["at"], repaired).get("id") == task["id"])
			assert(Rect2(60, 110, 600, 1260).has_point(marks[i]["at"]))
	profile.grant("vita_teddy")
	router.go(&"hub", {"location": loc_id})
	await create_timer(0.4).timeout
	assert(router.current_screen()._view._teddy != null)
	assert(router.current_screen()._view._teddy_in_art == (loc_id == "living"))
	assert(home.completed() == 19, "Opening the location must not change repair progress")
	print(loc_id + ": editable props, five repair/replay markers, teddy overlay OK")
	quit()
