extends RefCounted
## Integration check for win, repair, wallet and persistence.

static func run() -> void:
	var profile := (Engine.get_main_loop() as SceneTree).root.get_node("Profile")
	var old_path: String = profile.save_path
	var temp := "user://vita_home_selfcheck.json"
	profile.volatile = true
	profile.save_path = temp
	profile.reset_progress()
	assert(Home.completed() == 0)
	for i in 10:
		var slot: Rect2 = HomeArt.IMAGE_SLOTS[Home.TASKS[i].id]
		assert(Rect2(Vector2.ZERO,Vector2(720,1280)).encloses(slot))
	assert(Home.finish("home_02",true) == "")
	assert(Home.finish("home_01",false) == "")
	assert(Home.finish("home_01",true) == "tv")
	assert(Home.finish("home_01",true) == "")
	assert(Home.finish("home_02",true) == "light")
	assert(Home.completed() == 2)
	profile.add_coins(200,"selfcheck")
	assert(Home.buy("vita_plant"))
	assert(profile.owns("vita_plant"))
	assert(not Home.buy("vita_plant"))
	assert(profile.coins() == 80)
	profile.volatile = false
	profile.save()
	profile.flush()
	profile.data = profile.defaults()
	profile.load()
	assert(Home.completed() == 2)
	assert(profile.owns("vita_plant"))
	assert(profile.coins() == 80)
	profile.set_setting("music",false)
	profile.reset_progress()
	profile.flush()
	profile.load()
	assert(Home.completed() == 0)
	assert(profile.coins() == 0)
	assert(not profile.owns("vita_plant"))
	assert(not profile.setting("music"))
	# битый save.json после сброса: из save.bak должен вернуться сброшенный прогресс, а не старый
	var f := FileAccess.open(temp, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	profile.data = profile.defaults()
	profile.load()
	assert(Home.completed() == 0)
	assert(profile.coins() == 0)
	assert(not profile.owns("vita_plant"))
	profile.volatile = true
	profile.save_path = old_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp.get_basename() + ".bak"))
	print("HOME SELF-CHECK OK")
	(Engine.get_main_loop() as SceneTree).quit(0)
