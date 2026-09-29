extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var home = load("res://scripts/core/home.gd")
	var activities = load("res://scripts/core/activities.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	root.content_scale_size = Vector2i(720, 1280)
	var router := root.get_node("Router")
	router.forward_app_pause = false
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	profile.set_flag("seen.room")
	router.go(&"hub", {"location": "room"})
	await create_timer(0.5).timeout
	var hub: Node = router.current_screen()
	var ratio := "20x9" if root.size.y > root.size.x * 2 else "16x9"
	for kind in ["blocks", "toybox"]:
		var key: String = "room/room_" + kind
		hub.call("_play_activity", key, activities.animation(key, 0))
		var view: Node = hub.get("_view")
		var player: Node = view.get_children()[-1]
		while player.get("phase") != ("tower" if kind == "blocks" else "carry"):
			await process_frame
		if kind == "toybox":
			await create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://art/act1/reviews/2026-09-28-pilot/action-" + kind + "-" + ratio + ".png") == OK)
		await player.finished
		await process_frame
	quit()
