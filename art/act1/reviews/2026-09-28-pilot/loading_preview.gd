extends SceneTree

## Candidate art with existing loading UI; no active asset or save replacement.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.content_scale_size = Vector2i(720, 1280)
	root.get_node("Router").forward_app_pause = false
	var screen = load("res://scripts/screens/loading_screen.gd").new()
	root.add_child(screen)
	screen.open({"variant": "room"})
	screen.set_process(false)
	screen.set("_done", true)
	screen.get("_family").hide()
	screen.get("_bar").set("progress", 0.55)
	screen.get("_tip").set("text", "Починим дом вместе.")
	for variant: String in ["album_open", "album_photos", "album_together"]:
		var art := Image.load_from_file("res://art/act1/ui/loading/" + variant + ".png")
		assert(art != null and not art.is_empty())
		screen.get("_bg").set("texture", ImageTexture.create_from_image(art))
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var ratio := "20x9" if root.size.y > root.size.x * 2 else "16x9"
		var path := "res://art/act1/reviews/2026-09-28-pilot/loading-" + variant + "-" + ratio + ".png"
		assert(root.get_texture().get_image().save_png(path) == OK)
	quit()
