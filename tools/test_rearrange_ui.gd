extends SceneTree
## Расстановка в Hub: перетаскивание касаниями, запись, возврат при недопустимом месте.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var profile: Node = root.get_node("Profile")
	var router: Node = root.get_node("Router")
	var RA: GDScript = load("res://scripts/core/rearrange.gd")
	var HOME: GDScript = load("res://scripts/core/home.gd")
	var saved: Dictionary = profile.data.duplicate(true)
	var was: bool = profile.volatile
	profile.volatile = true
	profile.data = profile.defaults()
	router.forward_app_pause = false
	for key in ["seen.room", "seen.prologue"]:
		profile.set_flag(key)
	router.go(&"hub", {"location": "room"})
	await _until(func() -> bool: return not router.is_busy() and router.current() == &"hub")
	await create_timer(0.5).timeout
	var hub: Node = router.current_screen()
	hub._set_arrange(true)
	assert(hub._arrange)
	var room: Dictionary = HOME.location("room")
	var toy: Dictionary = RA.raw_item(room, "room/room_toybox")
	var base: Rect2 = RA.rect_of(toy)
	var goal := Vector2(520, 1330)                 # свободный пол справа внизу
	await _drag(hub, base.get_center(), goal)
	var now: Rect2 = RA.rect_of(toy)
	assert(now.position.distance_to(base.position) > 100.0, "toybox did not move")
	assert(profile.data["layout"]["room"]["room/room_toybox"] == [now.position.x, now.position.y])
	# на кровать (ремонтируемая вещь) поставить нельзя: возврат
	var bed: Dictionary = HOME.location("room")["targets"][1]
	var bed_r: Rect2 = RA.rect_of(bed)
	var before: Rect2 = RA.rect_of(toy)
	await _drag(hub, before.get_center(), bed_r.get_center())
	assert(RA.rect_of(toy) == before, "drop on the bed must revert")
	assert(profile.data["layout"]["room"]["room/room_toybox"] == [before.position.x, before.position.y])
	# сброс
	hub._reset_arrange()
	assert(RA.rect_of(toy) == base and not profile.data["layout"].has("room"))
	hub._set_arrange(false)
	assert(not hub._arrange)
	profile.volatile = was
	profile.data = saved
	print("REARRANGE UI OK: drag saves, bed drop reverts, reset restores")
	quit()


func _drag(hub: Node, from: Vector2, to: Vector2) -> void:
	var a: Vector2 = from * hub._k + hub._offset
	var b: Vector2 = to * hub._k + hub._offset
	var press := InputEventScreenTouch.new()
	press.position = a
	press.pressed = true
	hub._gui_input(press)
	for i in 6:
		var drag := InputEventScreenDrag.new()
		drag.position = a.lerp(b, float(i + 1) / 6.0)
		hub._gui_input(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.position = b
	release.pressed = false
	hub._gui_input(release)
	await process_frame


func _until(cond: Callable) -> void:
	var limit := Time.get_ticks_msec() + 20000
	while not cond.call():
		assert(Time.get_ticks_msec() < limit, "timeout")
		await process_frame
