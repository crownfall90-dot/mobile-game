extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var home = load("res://scripts/core/home.gd")
	var profile := root.get_node("Profile")
	profile.volatile = true
	profile.data = profile.defaults()
	root.content_scale_size = Vector2i(720, 1280)
	var router := root.get_node("Router")
	router.forward_app_pause = false
	var ratio := "20x9" if root.size.y > root.size.x * 2 else "16x9"
	for repaired in [false, true]:
		for task: Dictionary in home.tasks():
			profile.set_flag("home." + task["id"], repaired or task["loc"] in ["room", "kitchen", "bath"])
		profile.set_flag("seen.living")
		router.go(&"hub", {"location": "living"})
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var state := "fixed" if repaired else "broken"
		assert(root.get_texture().get_image().save_png("res://art/act1/reviews/2026-09-29-living/" + state + "-" + ratio + ".png") == OK)
	profile.grant("vita_teddy")
	router.go(&"hub", {"location": "living"})
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://art/act1/reviews/2026-09-29-living/teddy-" + ratio + ".png") == OK)
	quit()
