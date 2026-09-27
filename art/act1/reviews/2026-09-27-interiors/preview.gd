extends SceneTree
## Preview proposed placement in memory; never writes game data or player progress.
func _initialize() -> void:
 _run.call_deferred()

func _run() -> void:
 var home = load("res://scripts/core/home.gd")
 var profile = root.get_node("Profile")
 profile.volatile = true
 profile.data = profile.defaults()
 profile.set_flag("home.v2")
 var room := OS.get_environment("VITA_REVIEW_ROOM")
 if room.is_empty(): room = "bath"
 var stage := int(OS.get_environment("VITA_REVIEW_STAGE"))
 for i in mini(stage, home.total()):
  profile.set_flag("home." + str(home.tasks()[i]["id"]))
 for name in ["room", "kitchen", "bath", "living"]:
  profile.set_flag("seen." + name)
 profile.set_flag("seen.novel.act1_end")
 for item in ["vita_teddy", "vita_plant", "vita_picture"]: profile.grant(item)
 var edits: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/act1/reviews/2026-09-27-interiors/layout.json"))
 for loc in home.locations():
  var patch: Dictionary = edits.get(loc["id"], {})
  for group in ["targets", "props", "decor"]:
   for entry in loc.get(group, []):
    var key: String = entry.get("id", entry.get("img", ""))
    if patch.has(key): entry.merge(patch[key], true)
  for extra in patch.get("add", []):
   var exists := false
   for prop in loc["props"]:
    if prop["img"] == extra["img"]:
     prop.merge(extra, true)
     exists = true
   if not exists: loc["props"].append(extra)
 var router = root.get_node("Router")
 router.forward_app_pause = false
 router.go(&"hub", {"location":room})
 await create_timer(2.0).timeout
 if room == "bath":
  var view = router._stack.back()._view
  var candidate := Image.load_from_file("res://art/act1/reviews/2026-09-27-interiors/bath-background-proposed.png")
  assert(candidate != null and not candidate.is_empty(), "Bathroom candidate image must load")
  view._bg = ImageTexture.create_from_image(candidate)
  view._bg_sprite.texture = view._bg
 _audit(router._stack.back(), home.location(room))
 await RenderingServer.frame_post_draw
 var path := OS.get_environment("VITA_ART_REVIEW_OUT")
 var err := root.get_texture().get_image().save_png(path)
 print("INTERIOR REVIEW ",room," stage=",stage," saved=",path," result=",err)
 quit(err)

func _audit(hub, loc: Dictionary) -> void:
 var actions = load("res://scripts/core/activities.gd")
 var view = hub._view
 for group in ["targets", "props"]:
  for entry in loc.get(group, []):
   var key: String = entry.get("id", entry.get("img", ""))
   if key.begins_with("family/"): continue
   var v: Array = entry["rect"]
   var reachable := false
   for y in range(int(v[1])+12, int(v[1]+v[3])-11, 12):
    for x in range(int(v[0])+12, int(v[0]+v[2])-11, 12):
     var p := Vector2(x,y)
     var screen: Vector2 = p * hub._k + hub._offset
     if screen.x < 20 or screen.x > hub.size.x-20 or screen.y < 110 or screen.y > hub.size.y-88: continue
     var hit: Dictionary = view.target_at(p)
     if hit.is_empty():
      if hub._gloom and hub._gloom.hit(p): continue
      if view.family_at(p): continue
      hit = view.target_at(p, true)
     if hit.is_empty(): hit = view.prop_at(p)
     if str(hit.get("id", hit.get("img", ""))) == key:
      reachable = true
      break
    if reachable: break
   var activity_key: String = key if group == "targets" else actions.prop_key(loc["id"],key)
   print("ACCESS ",loc["id"]," ",key," reachable=",reachable," actions=",actions.available(activity_key).size())
