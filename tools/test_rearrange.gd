extends SceneTree
## Расстановка: зоны, места для каждой вещи, сохранение, сброс, мусор в сохранении.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var RA: GDScript = load("res://scripts/core/rearrange.gd")
	var HOME: GDScript = load("res://scripts/core/home.gd")
	var profile: Node = root.get_node("Profile")
	var saved: Dictionary = profile.data.duplicate(true)
	var was: bool = profile.volatile
	profile.volatile = true
	profile.data = profile.defaults()
	profile.grant("vita_plant")
	profile.grant("vita_picture")
	var total := 0
	for loc: Dictionary in HOME.locations():
		RA.apply(loc)
		var keys: Array = RA.movable(loc)
		assert(not keys.is_empty(), "no movable items in " + str(loc.id))
		for key in keys:
			var it: Dictionary = RA.raw_item(loc, key)
			var base: Rect2 = RA.rect_of(it)
			var fits_n := 0
			var step := 40.0
			var y := 400.0
			while y < 1420.0:
				var x := 0.0
				while x < 720.0:
					var r: Rect2 = RA.clamp_rect(str(loc.id), key, Rect2(Vector2(x, y), base.size))
					assert(RA.zone_ok(str(loc.id), key, r), "clamp left zone: %s %s" % [loc.id, key])
					if RA.fits(loc, key, r):
						fits_n += 1
					x += step
				y += step
			assert(fits_n >= 6, "too few free spots for %s %s: %d" % [loc.id, key, fits_n])
			total += 1
	# сохранение, повторное применение и сброс
	var room: Dictionary = HOME.location("room")
	var toy: Dictionary = RA.raw_item(room, "room/room_toybox")
	var base: Rect2 = RA.rect_of(toy)
	var shadow0: Array = toy["shadow"].duplicate(true)
	var target := Rect2(Vector2(base.position.x + 140, base.position.y + 150), base.size)
	target = RA.clamp_rect("room", "room/room_toybox", target)
	RA.place(toy, target)
	assert(RA.rect_of(toy) == target and toy["shadow"] != shadow0)
	RA.save(room, "room/room_toybox")
	RA.place(toy, base)
	RA.apply(room)
	assert(RA.rect_of(toy) == target, "saved place not applied")
	RA.reset(room)
	assert(RA.rect_of(toy) == base and toy["shadow"] == shadow0, "reset must restore rect and shadow")
	assert(not profile.data["layout"].has("room"))
	# мусор и недопустимые позиции в сохранении игнорируются
	profile.data["layout"] = {"room": {"room/room_toybox": [5, 5], "room/room_rug": "x", "room/room_blocks": [1]}, "bath": 7}
	for loc: Dictionary in HOME.locations():
		RA.apply(loc)
	assert(RA.rect_of(toy) == base)
	profile.data.erase("layout")
	RA.apply(room)
	# декор не куплен — не двигается
	profile.data = profile.defaults()
	assert(RA.item(room, "decor:vita_plant").is_empty())
	assert(not RA.movable(room).has("decor:vita_plant"))
	profile.volatile = was
	profile.data = saved
	for loc: Dictionary in HOME.locations():
		RA.apply(loc)
	print("REARRANGE OK: ", total, " items with free spots, zones, save/apply/reset, junk save")
	quit()
