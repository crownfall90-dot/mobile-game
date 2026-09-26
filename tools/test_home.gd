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
	assert(Home.total() == 19)
	assert(Home.unlocked_count() == 1 and Home.current_location() == "room")
	# всё нажимаемое — в safe-области сцены, у каждой цели свой уровень
	var sv: Array = Home.data()["scene"]["safe"]
	var safe := Rect2(sv[0], sv[1], sv[2], sv[3])
	var levels := {}
	for t in Home.tasks():
		var v: Array = t["rect"]
		assert(safe.encloses(Rect2(v[0], v[1], v[2], v[3])))
		assert(not levels.has(t["level"]))
		levels[t["level"]] = true
	# кухня закрыта, пока комната не готова; в комнате — любой порядок
	assert(Home.finish("home_05",true) == "")
	assert(Home.finish("home_02",false) == "")
	assert(Home.finish("home_02",true) == "room_bed")
	assert(Home.finish("home_02",true) == "")
	assert(Home.finish("home_01",true) == "room_window")
	assert(Home.completed() == 2 and Home.unlocked_count() == 1)
	assert(Home.finish("home_04",true) == "room_wall")
	assert(Home.finish("home_03",true) == "room_floor")
	assert(Home.location_done("room") and Home.unlocked_count() == 2)
	assert(Home.current_location() == "kitchen")
	assert(Home.finish("home_10",true) == "")
	assert(Home.finish("home_06",true) == "kitchen_sink")
	assert(Home.completed() == 5)
	# перенос старого прогресса (10 ремонтов подряд) — один раз, по числу ремонтов
	profile.reset_progress()
	for id in ["tv", "light", "window"]:
		profile.set_flag("home." + id)
	assert(Home.completed() == 3 and Home.unlocked_count() == 1)
	profile.set_flag("home.tv", false)
	assert(Home.completed() == 3)
	profile.reset_progress()
	assert(Home.finish("home_01",true) == "room_window")
	assert(Home.finish("home_02",true) == "room_bed")
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
