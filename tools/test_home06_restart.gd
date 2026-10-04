extends SceneTree
## Actual water loss -> GameScreen.restart -> live dirt/fluid simulation, 50 times.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile := root.get_node("Profile")
	var router := root.get_node("Router")
	profile.volatile = true
	profile.set_flag("seen.room")
	router.forward_app_pause = false
	var baseline := -1
	var orphan_baseline := -1
	var memory: Array[int] = []
	for cycle in 50:
		profile.set_setting(&"low_fx", cycle % 2 == 0)
		router.go(&"game", {"id": "home_06", "dev": true})
		await _idle(router)
		var game: Node = router.current_screen()
		assert(game._attempt == 1)
		await _stroke(game.level, "trap")
		for tick in 1200:
			if game.level.finished:
				break
			await physics_frame
		assert(game.level.finished and game.level.result().reason == "water", "Expected actual water loss")
		var old_id: int = game.level.get_instance_id()
		game.restart()
		await process_frame
		await process_frame
		assert(instance_from_id(old_id) == null, "Restart retained old Level")
		assert(game._attempt == 2 and not game.level.finished)
		# Simulate the same pause handler used by Android, including a repeated event.
		if cycle < 20:
			game.on_app_pause()
			game.on_app_pause()
			assert(paused and router._popups.get_child_count() == 1)
			router.top_popup().close()
			await create_timer(0.5).timeout
			assert(not paused and router._popups.get_child_count() == 0)
		await _stroke(game.level, "coal2")
		await _stroke(game.level, "fire")
		for tick in 60:
			await physics_frame
		var game_id: int = game.get_instance_id()
		router.go(&"hub", {"location": "room"})
		await _idle(router)
		await create_timer(1.0).timeout
		assert(instance_from_id(game_id) == null)
		var count := _nodes(router)
		var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		if cycle == 1:
			baseline = count
			orphan_baseline = orphans
		elif cycle > 1:
			assert(count == baseline and orphans == orphan_baseline, "Node/orphan accumulation")
		memory.append(int(Performance.get_monitor(Performance.MEMORY_STATIC)))
	print("HOME06 RESTART OK: 50 actual water losses/restarts/live physics; 20 pause/resume simulations; alternating low FX; Router nodes ", baseline,
		"; orphans ", orphan_baseline, "; memory first/last/min/max ", memory[1], "/", memory[-1], "/", memory.min(), "/", memory.max())
	quit()


func _stroke(level: Node, id: String) -> void:
	var points: Array = level.data.strokes[id]
	var prev := Vector2(points[0][0], points[0][1])
	for point in points:
		var target := Vector2(point[0], point[1])
		while prev.distance_to(target) > 0.5 and not level.finished:
			await physics_frame
			var next := prev.move_toward(target, 900.0 / Engine.physics_ticks_per_second)
			level.dig(prev, next)
			prev = next


func _idle(router: Node) -> void:
	while router.is_busy():
		await process_frame
	await process_frame


func _nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _nodes(child)
	return count
