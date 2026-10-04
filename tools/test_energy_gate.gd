extends SceneTree
## Энергия: ворота повтора в игре, списание по итогу попытки, возврат после рекламы.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile: Node = root.get_node("Profile")
	var router: Node = root.get_node("Router")
	var saved: Dictionary = profile.data.duplicate(true)
	var was: bool = profile.volatile
	profile.volatile = true
	profile.data = profile.defaults()
	router.forward_app_pause = false
	for key in ["seen.room", "tut.putty", "tut.dirt", "tut.pipes", "tut.pins"]:
		profile.set_flag(key)
	router.go(&"game", {"id": "home_01"})
	await _until(func() -> bool: return not router.is_busy() and router.current() == &"game")
	var game: Node = router.current_screen()
	assert(Energy.current() == 5)
	# проигрыш списывает 2
	game._on_lost("test")
	assert(Energy.current() == 3)
	game._on_lost("test")             # тот же итог не списывает дважды
	assert(Energy.current() == 3)
	game._try_restart()               # хватает: повтор без окна
	await process_frame
	assert(router.top_popup() == null)
	game._on_lost("test")
	assert(Energy.current() == 1)
	game._try_restart()               # не хватает: окно энергии
	await _until(func() -> bool: return router.top_popup() != null)
	var popup: Node = router.top_popup()
	assert(popup.get_script().resource_path.ends_with("energy_popup.gd"))
	var attempt_before: int = game._attempt
	popup._on_ad(&"energy_refill", true)      # «реклама» засчитана → окно закрывается, повтор идёт
	await _until(func() -> bool: return router.top_popup() == null)
	await process_frame
	assert(Energy.current() == 3 and game._attempt == attempt_before + 1)
	profile.volatile = was
	profile.data = saved
	print("ENERGY GATE OK: spend on result once, restart gate, ad refill resumes")
	quit()


func _until(cond: Callable) -> void:
	var limit := Time.get_ticks_msec() + 20000
	while not cond.call():
		assert(Time.get_ticks_msec() < limit, "timeout")
		await process_frame
