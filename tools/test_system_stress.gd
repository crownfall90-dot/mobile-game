extends SceneTree
## Repeated screen, popup and activity disposal without touching the user's save.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void: push_error("Stress check timed out"); quit(1))
	var profile := root.get_node("Profile")
	var router := root.get_node("Router")
	profile.volatile = true
	profile.set_flag("seen.room")
	router.forward_app_pause = false
	var samples: Array[int] = []
	for i in 20:
		router.go(&"game", {"id": "home_01"})
		await _idle()
		assert(router.current() == &"game" and router._screens.get_child_count() == 1)
		router.go(&"hub", {"location": "room"})
		await _idle()
		assert(router.current() == &"hub" and router._screens.get_child_count() == 1)
		samples.append(_nodes(router))
	for i in 20:
		await _popup(&"settings")
	for i in 20:
		await _popup(&"feedback")
	for name in [&"shop", &"album", &"howto", &"confirm"]:
		for i in 3:
			await _popup(name)
	var view: Node = router.current_screen()._view
	var activity := load("res://scripts/core/activities.gd")
	var player_script := load("res://scripts/art/activity_player.gd")
	for i in 20:
		var player: Node = player_script.new()
		view.add_child(player)
		player.run.call_deferred(view, "room_bed", activity.animation("room_bed", 0))
		await create_timer(0.1).timeout
		player.queue_free()
		await player.finished
		await process_frame
		assert(not view.activity_hidden)
	assert(router._screens.get_child_count() == 1 and router._popups.get_child_count() == 0)
	# All iterations leave the same screen and should not retain its old descendants.
	assert(samples[-1] <= samples[1], "Router descendants grew across 20 identical returns")
	print("SYSTEM STRESS OK: 20 game returns, 20 settings, 20 feedback, 12 other popups, 20 activity cancels; Router nodes ", samples[1], " -> ", samples[-1])
	quit()


func _popup(name: StringName) -> void:
	var router := root.get_node("Router")
	var popup: Node = router.popup(name)
	assert(popup != null and router.top_popup() == popup)
	assert(router.popup(name) == popup)
	# Same handler as Android Back; a second event while closing must be harmless.
	router._on_back_request()
	router._on_back_request()
	await create_timer(0.4).timeout
	assert(router._popups.get_child_count() == 0 and not paused)


func _idle() -> void:
	while root.get_node("Router").is_busy():
		await process_frame
	await process_frame


func _nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _nodes(child)
	return count
