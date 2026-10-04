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
					var foot: Vector2 = RA.clamp_foot(str(loc.id), key, it, Vector2(x, y))
					var r: Rect2 = RA.rect_at(str(loc.id), key, it, foot)
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
	var foot: Vector2 = RA.clamp_foot("room", "room/room_toybox", toy, RA.foot_of(base) + Vector2(140, 250))
	var target: Rect2 = RA.rect_at("room", "room/room_toybox", toy, foot)
	assert(target.size.y > base.size.y, "closer to the viewer must be bigger")
	var far: Rect2 = RA.rect_at("room", "room/room_toybox", toy, Vector2(foot.x, 1062))
	assert(far.size.y < base.size.y, "farther must be smaller")
	RA.place(toy, target, true)
	assert(RA.rect_of(toy) == target and toy["shadow"] != shadow0 and toy["flip"] == true)
	RA.save(room, "room/room_toybox")
	assert(profile.data["layout"]["room"]["room/room_toybox"] == [foot.x, foot.y, true])
	RA.place(toy, base, false)
	RA.apply(room)
	assert(RA.rect_of(toy) == target and toy["flip"] == true, "saved place/flip not applied")
	RA.reset(room)
	assert(RA.rect_of(toy) == base and toy["shadow"] == shadow0 and toy["flip"] == false, "reset must restore rect, shadow, flip")
	assert(not profile.data["layout"].has("room"))
	# глубина: перед семьёй — поверх неё (z >= 2), у дальней стены — за ней
	var front: Vector2 = RA.clamp_foot("room", "room/room_toybox", toy, Vector2(200, 1390))
	RA.place(toy, RA.rect_at("room", "room/room_toybox", toy, front), false)
	RA.settle_z(room, "room/room_toybox")
	assert(float(toy["z"]) >= 2.0, "toybox in front of the family must draw over it")
	RA.place(toy, base, false)
	RA.settle_z(room, "room/room_toybox")
	assert(float(toy["z"]) == float(toy["base_z"]))
	# стена: на другой стене вещь разворачивается, через угол не вешается
	var shelf: Dictionary = RA.raw_item(room, "room/room_shelf_books")
	var sb: Rect2 = RA.base_rect(shelf)
	var left: Vector2 = RA.clamp_foot("room", "room/room_shelf_books", shelf, Vector2(200, 600))
	var lr: Rect2 = RA.rect_at("room", "room/room_shelf_books", shelf, left)
	RA.place(shelf, lr, false)
	assert(shelf["flip"] == true and shelf["user_flip"] == false, "other wall must mirror")
	RA.place(shelf, lr, true)
	assert(shelf["flip"] == false)
	var across := Rect2(Vector2(RA.CORNER_X - sb.size.x * 0.5, 600 - sb.size.y), sb.size)
	assert(not RA.zone_ok("room", "room/room_shelf_books", across), "must not hang across the corner")
	RA.place(shelf, sb, false)
	assert(shelf["flip"] == shelf["base_flip"])
	# мусор и недопустимые позиции в сохранении игнорируются
	profile.data["layout"] = {"room": {"room/room_toybox": [5, 5], "room/room_rug": "x", "room/room_blocks": [1], "room/room_suitcase": [1, 2, 3, 4]}, "bath": 7}
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
	print("REARRANGE OK: ", total, " items with free spots, zones, depth z, wall sides, save/apply/reset, junk save")
	quit()
