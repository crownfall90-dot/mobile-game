extends SceneTree
## Preview only. Run with --path . --script res://art/act1/reviews/2026-09-27-bath-props/preview.gd.
## Adds proposed props to Home's memory copy. Does not write game data or player progress.
const PROPS := [
 {"img":"bath/bath_mirror","rect":[235,560,150,191],"z":0},
 {"img":"bath/bath_towel","rect":[118,630,84,156],"z":1},
 {"img":"bath/bath_shelf","rect":[488,491,200,93],"z":1},
 {"img":"bath/bath_duck","rect":[623,859,45,40],"z":2},
 {"img":"bath/bath_mat","rect":[474,1050,220,83],"z":0},
 {"img":"bath/bath_basket","rect":[35,1135,140,154],"z":2}
]
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var home = load("res://scripts/core/home.gd")
 var profile = root.get_node("Profile")
 profile.volatile = true
 profile.data = profile.defaults()
 profile.set_flag("home.v2")
 for t in home.tasks():
  profile.set_flag("home." + str(t["id"]))
 profile.set_flag("seen.bath")
 profile.set_flag("seen.novel.act1_end")
 profile.grant("vita_teddy")
 home.location("bath")["props"].append_array(PROPS)
 var router = root.get_node("Router")
 router.forward_app_pause = false
 router.go(&"hub", {"location":"bath"})
 await create_timer(2.0).timeout
 await RenderingServer.frame_post_draw
 var out := OS.get_environment("VITA_ART_REVIEW_OUT")
 if out.is_empty():
  out = "D:/Cache/Temp/vita-bath-props-preview.png"
 var err := root.get_texture().get_image().save_png(out)
 print("BATH ART PREVIEW ", out, " result=", err)
 quit(err)


