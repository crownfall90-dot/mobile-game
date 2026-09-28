extends SceneTree


func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var activities = load("res://scripts/core/activities.gd")
	var home = load("res://scripts/core/home.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	root.content_scale_size = Vector2i(720, 1280)
	var router := root.get_node("Router")
	router.forward_app_pause = false
	for task: Dictionary in home.tasks():
		profile.set_flag("home." + task["id"])
	profile.set_flag("seen.room")
	for entry in [["room/room_table_lamp", 0], ["room_bed", 0], ["room_bed", 1], ["room_floor", 0], ["room/room_curtains", 0]]:
		router.go(&"hub", {"location": "room"})
		await create_timer(0.5).timeout
		var hub: Node = router.current_screen()
		hub.call("_play_activity", entry[0], activities.animation(entry[0], entry[1]))
		var view: Node = hub.get("_view")
		var player: Node = view.get_children()[-1]
		while is_instance_valid(player) and player.get("phase") != "action":
			await process_frame
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		var name := str(entry[0]).replace("/", "-") + "-" + str(entry[1])
		var ratio := "20x9" if root.size.y > root.size.x * 2 else "16x9"
		assert(root.get_texture().get_image().save_png("res://art/act1/reviews/2026-09-28-pilot/action-" + name + "-" + ratio + ".png") == OK)
		if is_instance_valid(player):
			await player.finished
	quit()
