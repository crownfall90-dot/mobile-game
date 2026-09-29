extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var home = load("res://scripts/core/home.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	profile.set_flag("seen.kitchen")
	root.content_scale_size = Vector2i(720, 1280)
	var router := root.get_node("Router")
	router.forward_app_pause = false
	router.go(&"hub", {"location": "kitchen"})
	await create_timer(0.6).timeout
	var hub: Node = router.current_screen()
	hub._play_activity("kitchen_stove", load("res://scripts/core/activities.gd").animation("kitchen_stove", 0))
	for state in ["stir-a", "stir-b", "restored"]:
		if state == "restored":
			while hub._busy:
				await process_frame
		else:
			await create_timer(0.3 if state == "stir-a" else 0.45).timeout
		await RenderingServer.frame_post_draw
		var ratio := "20x9" if root.size.y > root.size.x * 2 else "16x9"
		assert(root.get_texture().get_image().save_png("res://art/act1/reviews/2026-09-29-cooking/" + state + "-" + ratio + ".png") == OK)
	quit()
