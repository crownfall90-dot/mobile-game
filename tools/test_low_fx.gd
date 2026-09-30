extends SceneTree
## godot --headless --path . --fixed-fps 120 --script res://tools/test_low_fx.gd -- --home-stage=0

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(20.0).timeout.connect(func() -> void: push_error("Low FX check timed out"); quit(1))
	var profile := root.get_node("Profile")
	profile.save_path = "user://vita_low_fx_selfcheck.json"
	profile.volatile = false
	profile.data = profile.defaults()
	profile._main_ok = false
	assert(profile.setting(&"low_fx") == false)
	var other_settings: Dictionary = profile.data["settings"].duplicate(true)
	other_settings.erase("low_fx")
	profile.set_setting(&"low_fx", true)
	profile.flush()
	profile.data = profile.defaults() # Simulate a fresh process loading the saved profile.
	profile.load()
	assert(profile.setting(&"low_fx") == true)
	assert(UiKit.low_fx())
	var reduced := Fx.new()
	root.add_child(reduced)
	reduced.burst(Vector2.ZERO, Color.WHITE, 12, 100.0, 4.0)
	assert(reduced._pos.size() == 6)
	reduced.queue_free()
	profile.set_setting(&"low_fx", false)
	profile.flush()
	profile.data = profile.defaults()
	profile.load()
	assert(profile.setting(&"low_fx") == false)
	assert(not UiKit.low_fx())
	var normal := Fx.new()
	root.add_child(normal)
	normal.burst(Vector2.ZERO, Color.WHITE, 12, 100.0, 4.0)
	assert(normal._pos.size() == 12)
	normal.queue_free()
	var router := root.get_node("Router")
	router.forward_app_pause = false
	router.go(&"game", {"id": "home_01", "dev": true})
	while router.is_busy():
		await process_frame
	var game: Node = router.current_screen()
	assert(game.level.camera == game._camera)
	assert(game._hud._hint_tween != null)
	var game_data: Dictionary = profile.data.duplicate(true)
	game_data.erase("settings")
	profile.set_setting(&"low_fx", true)
	assert(game.level.camera == null and game._camera.offset == Vector2.ZERO)
	assert(game._hud._hint_tween == null and game._hud._hint.modulate.a == 1.0)
	profile.set_setting(&"low_fx", false)
	assert(game.level.camera == game._camera)
	assert(game._hud._hint_tween != null)
	var after: Dictionary = profile.data.duplicate(true)
	after.erase("settings")
	assert(after == game_data, "Visual setting must not change progress or rewards")
	var final_settings: Dictionary = profile.data["settings"].duplicate(true)
	final_settings.erase("low_fx")
	assert(final_settings == other_settings, "Sound, music and vibration are independent")
	var settings = router.popup(&"settings")
	assert(settings.content.get_children().any(func(c: Node) -> bool:
		return c is Label and "Уменьшает тряску" in c.text))
	settings.close()
	print("LOW FX: saved on/off, fewer visual particles, live camera switch, unchanged progress OK")
	quit()
