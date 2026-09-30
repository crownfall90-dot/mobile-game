extends SceneTree
## VITA-CRASH-HUB-01: repeated Game -> Hub repair teardown, including room completion.

const CYCLES := 20


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile := root.get_node("Profile")
	var router := root.get_node("Router")
	var home: Script = load("res://scripts/core/home.gd")
	var saved: Dictionary = profile.data.duplicate(true)
	var was_volatile: bool = profile.volatile
	profile.volatile = true
	router.forward_app_pause = false
	Engine.time_scale = 12.0
	for key in ["seen.room", "seen.kitchen", "tut.putty", "tut.dirt", "tut.pipes", "tut.pins"]:
		profile.set_flag(key)
	var baseline := -1
	var noise_rid := RID()
	for i in CYCLES:
		# Last room repair: repair -> cheer -> completion novel -> kitchen.
		for id in ["room_window", "room_floor", "room_bed"]:
			profile.set_flag("home." + id)
		profile.set_flag("home.room_wall", false)
		await _open_game(router, "home_04")
		var old_game_id: int = router.current_screen().get_instance_id()
		assert(home.finish("home_04", true) == "room_wall")
		router.go(&"hub", {"repaired": "room_wall"})
		await _wait_current(router, &"hub")
		_assert_single(router, &"hub", old_game_id)
		noise_rid = _assert_noise(router.current_screen(), noise_rid)
		await _wait_current(router, &"novel")
		(router.current_screen() as Node).call(&"_skip_all")
		await _wait_current(router, &"hub")
		assert(router.current_screen()._loc_id == "kitchen")

		# First kitchen repair: repair completes and remains in one stable Hub.
		profile.set_flag("home.kitchen_sink", false)
		await _open_game(router, "home_05")
		old_game_id = router.current_screen().get_instance_id()
		assert(home.finish("home_05", true) == "kitchen_sink")
		router.go(&"hub", {"repaired": "kitchen_sink"})
		await _wait_current(router, &"hub")
		await _wait_hub_idle(router)
		_assert_single(router, &"hub", old_game_id)
		noise_rid = _assert_noise(router.current_screen(), noise_rid)
		assert(router._queued.is_empty())
		var count := _nodes(router)
		if baseline < 0:
			baseline = count
		else:
			assert(count == baseline, "Router nodes changed after identical repair cycles: %d != %d" % [count, baseline])
	profile.data = saved
	profile.volatile = was_volatile
	Engine.time_scale = 1.0
	print("HUB CRASH STRESS OK: ", CYCLES, " room completion + ", CYCLES,
		" kitchen repair cycles; Router nodes ", baseline, "; one shared wear texture RID")
	await process_frame
	quit()


func _open_game(router: Node, id: String) -> void:
	router.go(&"game", {"id": id, "dev": true})
	await _wait_current(router, &"game")
	assert(router.current_screen().level != null)


func _wait_current(router: Node, expected: StringName) -> void:
	var until := Time.get_ticks_msec() + 30000
	while router.is_busy() or router.current() != expected:
		assert(Time.get_ticks_msec() < until, "Timed out waiting for " + str(expected))
		await process_frame
	await process_frame


func _wait_hub_idle(router: Node) -> void:
	var until := Time.get_ticks_msec() + 30000
	while router.is_busy() or router.current_screen()._busy:
		assert(Time.get_ticks_msec() < until, "Timed out waiting for repair")
		await process_frame
	await process_frame


func _assert_single(router: Node, expected: StringName, old_game_id: int) -> void:
	assert(router.current() == expected and router._screens.get_child_count() == 1)
	var old_game := instance_from_id(old_game_id)
	assert(old_game == null or not old_game.is_inside_tree(), "Old GameScreen survived Hub creation")
	assert(router.current_screen()._view != null and router.current_screen()._view.get_parent() != null)


func _assert_noise(hub: Node, expected: RID) -> RID:
	var tex: Texture2D = hub._view._bg_sprite.material.get_shader_parameter("stains")
	var rid := tex.get_rid()
	assert(rid.is_valid())
	if expected.is_valid():
		assert(rid == expected, "Hub recreated its threaded wear texture")
	return rid


func _nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _nodes(child)
	return count
