extends SceneTree
## Partial pilot assembly, using the agreed 720x1560 camera. No game data/save writes.
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
 var bed: Sprite2D
 var wall: Sprite2D
 var floor_hole: Sprite2D
 if OS.get_environment("VITA_PREVIEW_DETAIL") == "1":
  wall = _sprite("res://art/act1/room/pilot/room_wall_broken.png", Vector2(487,690))
  floor_hole = _sprite("res://art/act1/room/pilot/room_floor_broken.png", Vector2(282,1043))
 if OS.get_environment("VITA_PREVIEW_BED") == "1":
  _sprite("res://art/act1/room/pilot/room_nightstand.png", Vector2(313,850))
  _sprite("res://art/act1/room/pilot/room_chest.png", Vector2(233,814))
  bed = _sprite("res://art/act1/room/pilot/room_bed_fixed.png", Vector2(281,866))
 if wall:
  _sprite("res://art/act1/room/pilot/room_toybox.png", Vector2(399,989))
 for state: String in ["fixed","broken"]:
  if wall:
   wall.visible = state == "broken"
   floor_hole.visible = state == "broken"
  window.texture = ImageTexture.create_from_image(Image.load_from_file("res://art/act1/room/pilot/room_window_"+state+".png"))
  if bed:
   bed.texture = ImageTexture.create_from_image(Image.load_from_file("res://art/act1/room/pilot/room_bed_"+state+".png"))
  await create_timer(0.2).timeout
  await RenderingServer.frame_post_draw
  var prefix := "furniture-" if bed else "window-"
  if wall:
   prefix = "details-"
  var path := "res://art/act1/reviews/2026-09-28-pilot/"+prefix+state+".png"
  var err := root.get_texture().get_image().save_png(path)
  assert(err == OK, path)
  print("WINDOW ASSEMBLY ",state," saved")
 quit()
