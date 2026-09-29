extends Node2D
## Бытовое действие в самой локации. Кадры и точки контакта — не диалог новеллы.
## ponytail: пока маршрут — отрезок через точку подхода; для обхода произвольной мебели
## понадобится NavigationRegion2D. Точку подхода можно переставить в сцене.

signal finished
signal step_finished

const ART := "res://art/act1/family/actions/"
const KINDS := ["light", "sleep", "jump", "curtains", "drawer", "sit", "blocks", "toy", "cook", "kettle"]
const TOYS := "res://art/act1/room/toys/"
const CARRY_HAND := [Vector2(433, 476), Vector2(491, 443), Vector2(479, 368), Vector2(507, 214)]

var _view: LocationView
var _actor: Node2D
var _frames: Array[Texture2D] = []
var _sprite: Sprite2D
var _walking := false
var _elapsed := 0.0
var _who := ""
var _complete := false
var _pending: Tween
var _held: Sprite2D
var phase := "approach"
var contact := Vector2.ZERO
var hand_offset := Vector2.ZERO


func run(view: LocationView, key: String, clip: Dictionary) -> void:
	_view = view
	_who = str(clip.get("actor", "mother"))
	var kind := str(clip.get("kind", ""))
	var item := view.activity_item(key)
	if item.is_empty() or not kind in KINDS:
		_finish()
		return
	if kind == "cook":
		await _cook(clip)
		return
	if kind == "kettle":
		await _kettle(item, clip)
		return
	for i in 4:
		_frames.append(load(ART + _who + "_%d.png" % i))
	if _frames.any(func(t: Texture2D) -> bool: return t == null):
		_finish()
		return
	var origin := view.activity_actor(_who)
	var height := float(origin["height"])
	var base := Vector2(origin["pos"][0], origin["pos"][1])
	_actor = _make_actor(_who, base, height)
	_sprite = _actor.get_child(0)
	# Общую пару заменяем двумя отдельными фигурами: второй герой остаётся на месте.
	var other := "daughter" if _who == "mother" else "mother"
	var still := view.activity_actor(other)
	_make_actor(other, Vector2(still["pos"][0], still["pos"][1]), float(still["height"]))
	move_child(_actor, get_child_count() - 1)
	view.set_activity_hidden(true)
	var r := view.activity_rect(item)
	var p: Array = clip.get("contact", [0.5, 0.5])
	contact = view.activity_point(item, Vector2(p[0], p[1]))
	# Рука четвёртого кадра; весь герой масштабируется равномерно.
	var hand := Vector2(280, -504) * (height / 707.0) if _who == "mother" else Vector2(215, -530) * (height / 766.0)
	if bool(item.get("flip", false)):
		hand.x = -hand.x
	if kind == "toy":
		var palm: Vector2 = CARRY_HAND[3]
		if bool(item.get("flip", false)):
			palm.x = _frames[3].get_width() - palm.x
		hand = _sprite.position + palm * _sprite.scale
	hand_offset = hand
	var stance := contact - hand
	var approach := contact - hand
	if kind in ["sleep", "jump"]:
		approach = view.activity_point(item, Vector2(0.12, 1.1))
	if kind in ["sit", "blocks"]:
		approach = contact
	if item.has("approach"):
		var at: Array = item["approach"]
		approach = view.activity_point(item, Vector2(at[0], at[1]))
	await _walk_to(approach)
	if _complete:
		return
	if kind in ["light", "curtains", "drawer", "toy"] and approach.distance_to(stance) > 2.0:
		await _walk_to(stance)
		if _complete:
			return
	phase = "action"
	_sprite.texture = _frames[3]
	_sprite.flip_h = bool(item.get("flip", false))
	match kind:
		"toy":
			var box := Sprite2D.new()
			box.name = "Toybox"
			box.texture = load(TOYS + "box_without_ball.png")
			box.position = r.get_center()
			box.scale = Vector2.ONE * r.size.x / box.texture.get_width()
			box.rotation = float(item.get("rot", 0.0))
			box.flip_h = bool(item.get("flip", false))
			add_child(box)
			move_child(box, 0)
			view.activity_prop = str(item["img"])
			var ball := Sprite2D.new()
			ball.name = "Ball"
			ball.texture = load(TOYS + "ball.png")
			ball.scale = Vector2.ONE * r.size.x * 0.23 / ball.texture.get_width()
			ball.position = contact
			add_child(ball)
			_held = ball
			await _pause(0.4)
			if _complete:
				return
			phase = "carry"
			await _walk_to(base)
			if _complete:
				return
			await _pause(1.2)
			if _complete:
				return
			await _walk_to(stance)
			if _complete:
				return
			_sprite.texture = _frames[3]
			_sprite.flip_h = bool(item.get("flip", false))
			await _pause(0.4)
			if _complete:
				return
			_held = null
			ball.queue_free()
			box.queue_free()
			view.activity_prop = ""
		"light":
			view.activity_light = true
			view.activity_light_at = contact
			await _pause(1.8)
		"curtains":
			var close := create_tween()
			close.tween_property(view, "activity_curtains", 1.0 - view.activity_curtains, 1.1)
			await _play(close)
			if _complete:
				return
			await _pause(0.7)
		"drawer":
			# Родной фасад PNG вырезает Polygon2D: корпус/ножки остаются неподвижными.
			var tex := load(LocationView.ART + str(item["img"]) + ".png") as Texture2D
			var mount := Node2D.new()
			mount.name = "Drawer"
			mount.position = r.get_center()
			mount.rotation = float(item.get("rot", 0.0))
			var k := r.size.x / tex.get_width()
			mount.scale = Vector2(-k if bool(item.get("flip", false)) else k, k)
			add_child(mount)
			move_child(mount, 0)
			var source := PackedVector2Array()
			var points := PackedVector2Array()
			for xy: Array in clip["panel"]:
				var uv := Vector2(xy[0], xy[1]) * tex.get_size()
				source.append(uv)
				points.append(uv - tex.get_size() * 0.5)
			var opening := Polygon2D.new()
			opening.polygon = points
			opening.color = Color("35200e")
			mount.add_child(opening)
			var face := Polygon2D.new()
			face.polygon = points
			face.uv = source
			face.texture = tex
			mount.add_child(face)
			var pull: Array = clip.get("pull", [0.08, 0.04])
			var shift := Vector2(pull[0], pull[1]) * tex.get_size()
			var slide := create_tween()
			slide.tween_property(face, "position", shift, 0.6).set_trans(Tween.TRANS_SINE)
			slide.parallel().tween_property(_actor, "position", stance + mount.transform.basis_xform(shift), 0.6).set_trans(Tween.TRANS_SINE)
			slide.tween_interval(1.2)
			slide.tween_property(face, "position", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_SINE)
			slide.parallel().tween_property(_actor, "position", stance, 0.6).set_trans(Tween.TRANS_SINE)
			await _play(slide)
			if _complete:
				return
			mount.queue_free()
		"jump":
			var landing := view.activity_point(item, Vector2(0.5, float(clip.get("surface", 0.5))))
			await _walk_to(landing)
			if _complete:
				return
			_sprite.texture = _frames[0]
			for i in 3:
				var hop := create_tween()
				hop.tween_property(_sprite, "position:y", _sprite.position.y - 35.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				hop.tween_property(_sprite, "position:y", -790.0 * height / 766.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await _play(hop)
				if _complete:
					return
			await _walk_to(approach)
		"sleep", "sit", "blocks":
			var sleep := Sprite2D.new()
			sleep.name = "Rest"
			sleep.texture = load(ART + ("daughter_sleep.png" if kind == "sleep" else "daughter_sit0.png"))
			sleep.centered = true
			sleep.flip_h = bool(item.get("flip", false))
			var w := r.size.x * 0.56 if kind == "sleep" else height * 0.74 * sleep.texture.get_width() / sleep.texture.get_height()
			sleep.scale = Vector2.ONE * w / sleep.texture.get_width()
			sleep.position = view.activity_point(item, Vector2(0.55, 0.38)) if kind == "sleep" else contact
			sleep.rotation = float(item.get("rot", 0.0)) if kind == "sleep" else 0.0
			if kind != "sleep":
				sleep.offset.y = -sleep.texture.get_height() * 0.475
			sleep.modulate.a = 0.0
			add_child(sleep)
			var settle := create_tween().set_parallel(true)
			settle.tween_property(_actor, "modulate:a", 0.0, 0.4)
			settle.tween_property(sleep, "modulate:a", 1.0, 0.4)
			await _play(settle)
			if _complete:
				return
			if kind == "blocks":
				var toys := Node2D.new()
				toys.name = "Blocks"
				add_child(toys)
				view.activity_prop = str(item["img"])
				var spots := [Vector2(0.16, 0.85), Vector2(0.47, 0.65), Vector2(0.48, 0.32), Vector2(0.73, 0.87), Vector2(0.89, 0.53)]
				var names := ["blue", "yellow", "red", "green", "cream"]
				for i in names.size():
					var cube := Sprite2D.new()
					cube.texture = load(TOYS + "cube_" + names[i] + ".png")
					cube.scale = Vector2.ONE * r.size.x * 0.35 / cube.texture.get_width()
					cube.offset.y = -cube.texture.get_height() * 0.43
					cube.position = view.activity_point(item, spots[i])
					cube.rotation = float(item.get("rot", 0.0))
					cube.flip_h = bool(item.get("flip", false))
					toys.add_child(cube)
				for i in toys.get_child_count():
					var cube: Sprite2D = toys.get_child(i)
					sleep.texture = load(ART + "daughter_sit1.png")
					var build := create_tween()
					# ponytail: two authored poses; independent cubes move between hand and tower,
					# full arm articulation would need additional drawn reach frames.
					var palm := sleep.position + Vector2(-145 if sleep.flip_h else 145, -94) * sleep.scale
					build.tween_property(cube, "position", palm, 0.35).set_trans(Tween.TRANS_SINE)
					build.tween_property(cube, "position", view.activity_point(item, Vector2(0.6, 1.0 - i * 0.31)), 0.45).set_trans(Tween.TRANS_SINE)
					await _play(build)
					if _complete:
						return
					sleep.texture = load(ART + "daughter_sit0.png")
					await _pause(0.15)
					if _complete:
						return
				phase = "tower"
				await _pause(1.0)
				if _complete:
					return
				var scatter := create_tween().set_parallel(true)
				for i in toys.get_child_count():
					scatter.tween_property(toys.get_child(i), "position", view.activity_point(item, spots[i]), 0.65).set_trans(Tween.TRANS_BOUNCE)
				await _play(scatter)
				if _complete:
					return
				toys.queue_free()
				view.activity_prop = ""
			else:
				var breath := create_tween().set_loops(3)
				breath.tween_property(sleep, "scale:y", sleep.scale.y * 1.015, 0.65)
				breath.tween_property(sleep, "scale:y", sleep.scale.y, 0.65)
				await _play(breath)
			if _complete:
				return
			var wake := create_tween().set_parallel(true)
			wake.tween_property(sleep, "modulate:a", 0.0, 0.4)
			wake.tween_property(_actor, "modulate:a", 1.0, 0.4)
			await _play(wake)
			if _complete:
				return
			sleep.queue_free()
	if _complete:
		return
	phase = "return"
	await _walk_to(base)
	_finish()


func _cook(clip: Dictionary) -> void:
	var source := _view.activity_item(str(clip["actor_prop"]))
	var vessel := _view.activity_item(str(clip["vessel"]))
	if source.is_empty() or vessel.is_empty():
		_finish()
		return
	var tex := load(LocationView.ART + str(source["img"]) + ".png") as Texture2D
	var at: Array = clip["contact"]
	contact = _view.activity_point(vessel, Vector2(at[0], at[1]))
	# ponytail: authored elbow/outline for mother_kitchen_v2 only; new poses need new cut points.
	var tip := Vector2(758, 700)
	var elbow := Vector2(478, 544)
	var edge := [Vector2(784, 500), Vector2(668, 500), Vector2(617, 499), Vector2(594, 529), Vector2(487, 520), Vector2(469, 505), Vector2(468, 551), Vector2(480, 587), Vector2(539, 582), Vector2(615, 571), Vector2(647, 575), Vector2(667, 625), Vector2(711, 704), Vector2(760, 728), Vector2(784, 728)]
	var pose := Sprite2D.new()
	pose.name = "Cooking"
	pose.position = contact
	var k := _view.activity_rect(source).size.y / tex.get_height()
	pose.scale = Vector2(-k if vessel.get("flip", false) else k, k)
	pose.rotation = float(vessel.get("rot", 0.0))
	add_child(pose)
	var body := Polygon2D.new()
	body.name = "Body"
	body.uv = PackedVector2Array([Vector2.ZERO, Vector2(784, 0)] + edge + [Vector2(784, 1544), Vector2(0, 1544)])
	body.polygon = body.uv
	body.texture = tex
	body.position = -tip
	pose.add_child(body)
	var arm := Polygon2D.new()
	arm.name = "Arm"
	arm.uv = PackedVector2Array(edge)
	var points := PackedVector2Array()
	for point in edge:
		points.append(point - elbow)
	arm.polygon = points
	arm.texture = tex
	arm.position = elbow - tip
	pose.add_child(arm)
	var steam := _make_steam(_view.activity_point(vessel, Vector2(0.5, 0.25)))
	_view.activity_prop = str(source["img"])
	phase = "stir"
	var start := steam.position
	for i in 6:
		steam.position = start
		steam.modulate.a = 1.0
		var stir := create_tween()
		stir.tween_property(arm, "rotation", 0.075, 0.4).set_trans(Tween.TRANS_SINE)
		stir.tween_property(arm, "rotation", -0.065, 0.4).set_trans(Tween.TRANS_SINE)
		stir.parallel().tween_property(steam, "position:y", start.y - 15.0, 0.4)
		stir.parallel().tween_property(steam, "modulate:a", 0.0, 0.4)
		await _play(stir)
		if _complete:
			return
	_finish()


func _kettle(item: Dictionary, clip: Dictionary) -> void:
	var kettle := Sprite2D.new()
	kettle.name = "Kettle"
	kettle.texture = load(LocationView.ART + str(item["img"]) + ".png") as Texture2D
	if kettle.texture == null:
		kettle.free()
		_finish()
		return
	var r := _view.activity_rect(item)
	kettle.position = r.get_center()
	kettle.scale = r.size / kettle.texture.get_size()
	kettle.flip_h = bool(item.get("flip", false))
	var angle := float(item.get("rot", 0.0))
	kettle.rotation = angle
	add_child(kettle)
	var at: Array = clip["contact"]
	contact = _view.activity_point(item, Vector2(at[0], at[1]))
	var steam := _make_steam(contact, 3.0)
	steam.modulate = Color(0.55, 0.68, 0.78)
	_view.activity_prop = str(item["img"])
	phase = "boil"
	for i in 6:
		steam.position = contact
		steam.modulate.a = 1.0
		var boil := create_tween()
		boil.tween_property(kettle, "rotation", angle + 0.018, 0.4).set_trans(Tween.TRANS_SINE)
		boil.tween_property(kettle, "rotation", angle - 0.018, 0.4).set_trans(Tween.TRANS_SINE)
		boil.parallel().tween_property(steam, "position:y", contact.y - 15.0, 0.4)
		boil.parallel().tween_property(steam, "modulate:a", 0.0, 0.4)
		await _play(boil)
		if _complete:
			return
	_finish()


func _make_steam(at: Vector2, spread := 9.0) -> Node2D:
	var steam := Node2D.new()
	steam.name = "Steam"
	steam.position = at
	add_child(steam)
	for i in 3:
		var curl := Line2D.new()
		var x := (i - 1) * spread
		curl.points = PackedVector2Array([Vector2(x, 0), Vector2(x + 3, -8), Vector2(x - 3, -16), Vector2(x, -24)])
		curl.width = 2.0
		curl.default_color = Color(1, 0.96, 0.86, 0.6)
		curl.begin_cap_mode = Line2D.LINE_CAP_ROUND
		curl.end_cap_mode = Line2D.LINE_CAP_ROUND
		steam.add_child(curl)
	return steam


func _finish() -> void:
	if _complete:
		return
	_complete = true
	if is_instance_valid(_view):
		_view.set_activity_hidden(false)
	finished.emit()
	queue_free()


func _make_actor(who: String, feet: Vector2, height: float) -> Node2D:
	var actor := Node2D.new()
	actor.position = feet
	var sp := Sprite2D.new()
	sp.texture = load(ART + who + "_0.png")
	sp.centered = false
	var k := height / (707.0 if who == "mother" else 766.0)
	sp.scale = Vector2.ONE * k
	sp.position = -Vector2(320, 714 if who == "mother" else 790) * k
	actor.add_child(sp)
	add_child(actor)
	return actor


func _walk_to(at: Vector2) -> void:
	_walking = true
	_sprite.flip_h = at.x < _actor.position.x
	var tween := create_tween()
	tween.tween_property(_actor, "position", at, clampf(_actor.position.distance_to(at) / 180.0, 0.3, 2.5))
	await _play(tween)
	if _complete:
		return
	_walking = false
	_sprite.texture = _frames[0]


func _play(tween: Tween) -> void:
	_pending = tween
	tween.finished.connect(_step_done, CONNECT_ONE_SHOT)
	await step_finished
	_pending = null


func _step_done() -> void:
	step_finished.emit()


func _pause(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	await _play(tween)


func _process(delta: float) -> void:
	_elapsed += delta
	if _walking and is_instance_valid(_sprite):
		_sprite.texture = _frames[1 + (int(_elapsed * 7.0) % 2)]
	if is_instance_valid(_held):
		var palm: Vector2 = CARRY_HAND[maxi(0, _frames.find(_sprite.texture))]
		if _sprite.flip_h:
			palm.x = _sprite.texture.get_width() - palm.x
		_held.position = _actor.position + _sprite.position + palm * _sprite.scale
	queue_redraw()


func _draw() -> void:
	if _frames.is_empty():
		return
	for actor: Node in get_children():
		if actor is Node2D and not actor is Sprite2D:
			draw_set_transform(actor.position, 0.0, Vector2(1, 0.25))
			draw_circle(Vector2.ZERO, 35.0, Color(0.15, 0.09, 0.04, 0.2 * actor.modulate.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _exit_tree() -> void:
	if is_instance_valid(_view):
		_view.set_activity_hidden(false)
	if not _complete:
		_complete = true
		if _pending and _pending.is_valid():
			_pending.kill()
		step_finished.emit()
		finished.emit()
