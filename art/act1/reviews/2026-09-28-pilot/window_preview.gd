extends SceneTree
## Window assembly only, using the agreed 720x1560 camera. No game data/save writes.
func _initialize() -> void:
 _run.call_deferred()

func _sprite(path: String, at: Vector2) -> Sprite2D:
 var source := Image.load_from_file(path)
 assert(source != null and not source.is_empty(), path)
 var sprite := Sprite2D.new()
 sprite.texture = ImageTexture.create_from_image(source)
 sprite.centered = false
 sprite.position = at
 sprite.scale = Vector2(0.5,0.5)
 root.add_child(sprite)
 return sprite

func _run() -> void:
 root.content_scale_size = Vector2i(720,1560)
 var router = root.get_node("Router")
 router.forward_app_pause = false
 _sprite("res://art/act1/room/pilot/background-warped.png", Vector2.ZERO)
 var window := _sprite("res://art/act1/room/pilot/room_window_fixed.png", Vector2(230,589))
 _sprite("res://art/act1/room/pilot/room_curtains.png", Vector2(211,549))
 for state: String in ["fixed","broken"]:
  window.texture = ImageTexture.create_from_image(Image.load_from_file("res://art/act1/room/pilot/room_window_"+state+".png"))
  await create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  var path := "res://art/act1/reviews/2026-09-28-pilot/window-"+state+".png"
  var err := root.get_texture().get_image().save_png(path)
  assert(err == OK, path)
  print("WINDOW ASSEMBLY ",state," saved")
 quit()
