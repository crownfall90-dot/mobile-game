extends SceneTree

## Art layout review only. Does not change saves or active room data.
func _initialize() -> void:
	_run.call_deferred()

func _put(path: String, pos: Vector2, size: Vector2) -> Sprite2D:
	var img := Image.load_from_file(path)
	assert(img != null and not img.is_empty(), path)
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.centered = false
	sprite.position = pos
	sprite.scale = size / Vector2(img.get_size())
	root.add_child(sprite)
	return sprite

func _run() -> void:
	root.content_scale_size = Vector2i(720, 1560)
	root.get_node("Router").forward_app_pause = false
	var art := "res://art/act1/room/pilot/"
	_put(art + "background-warped.png", Vector2.ZERO, Vector2(720,1560))
	var window := _put(art + "room_window_fixed.png", Vector2(230,589), Vector2(111,232))
	_put(art + "room_curtains.png", Vector2(211,549), Vector2(143,293))
	var wall := _put(art + "room_wall_broken.png", Vector2(487,690), Vector2(86,101))
	_put(art + "room_shelf_books.png", Vector2(543,643), Vector2(119,68))
	_put(art + "room_drawings.png", Vector2(410,691), Vector2(58,63))
	_put(art + "room_nightstand.png", Vector2(313,850), Vector2(83,113))
	_put(art + "room_table_lamp.png", Vector2(331,789), Vector2(49,74))
	_put(art + "room_chest.png", Vector2(233,814), Vector2(152,182))
	var bed := _put(art + "room_bed_fixed.png", Vector2(281,866), Vector2(391,237))
	_put("res://art/act1/room/room_rug.png", Vector2(114,1036), Vector2(374,211))
	var floor_hole := _put(art + "room_floor_broken.png", Vector2(282,1043), Vector2(130,64))
	_put(art + "room_toybox.png", Vector2(399,989), Vector2(143,165))
	_put(art + "room_slippers.png", Vector2(327,1011), Vector2(90,57))
	_put(art + "room_blocks.png", Vector2(354,1070), Vector2(121,92))
	_put(art + "room_suitcase.png", Vector2(489,985), Vector2(145,210))
	_put("res://art/act1/family/family_mood0.png", Vector2(63,654), Vector2(275,503))
	for stage: String in ["fixed", "broken"]:
		var damaged := stage == "broken"
		wall.visible = damaged
		floor_hole.visible = damaged
		window.texture = ImageTexture.create_from_image(Image.load_from_file(art + "room_window_" + stage + ".png"))
		bed.texture = ImageTexture.create_from_image(Image.load_from_file(art + "room_bed_" + stage + ".png"))
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var path := "res://art/act1/reviews/2026-09-28-pilot/full-" + stage + ".png"
		assert(root.get_texture().get_image().save_png(path) == OK)
	quit()
