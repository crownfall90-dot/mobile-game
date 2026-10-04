class_name Rearrange
extends RefCounted
## Расстановка: игрок двигает лёгкие вещи (коврики, коробки, полки, купленный декор) по полу
## и стенам комнаты. Тяжёлые вещи (кровать, плита, ванна…), семья и всё, что нужно для
## ремонтов, остаются на местах. Позиции хранятся в Profile.data["layout"][локация][ключ] = [x, y]
## (середина низа rect) и необязательный третий элемент — отражение. Ключ — img вещи или "decor:<id>" у декора. Размер на полу зависит от глубины, z не меняется.

## Пол: «ноги» вещи (середина низа rect) должны быть здесь. Стены: rect целиком.
const FLOOR := Rect2(60, 1060, 600, 340)
const WALL := Rect2(20, 450, 680, 480)

const ITEMS := {
	"room": {"room/room_rug": &"floor", "room/room_toybox": &"floor", "room/room_suitcase": &"floor",
		"room/room_slippers": &"floor", "room/room_blocks": &"floor",
		"room/room_shelf_books": &"wall", "room/room_drawings": &"wall",
		"decor:vita_plant": &"floor", "decor:vita_picture": &"wall"},
	"kitchen": {"kitchen/kitchen_rug": &"floor", "kitchen/kitchen_clock": &"wall"},
	"bath": {"bath/bath_basket": &"floor", "bath/bath_mirror": &"wall",
		"bath/bath_towel": &"wall", "bath/bath_shelf": &"wall"},
	"living": {"living/living_floorlamp": &"floor",
		"decor:vita_plant": &"floor", "decor:vita_picture": &"wall"},
}
## Коврики под стоящей на коленях дочкой (санузел, гостиная) не двигаются: поза привязана к ним.
## Стенные вещи, которые не двигаются, но занимают место на стене.
const WALL_FIXED := {
	"room": ["room/room_curtains"], "kitchen": ["room/room_window_fixed"], "living": ["living/living_window"],
}


static func _profile() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Profile")


static func kind(loc_id: String, key: String) -> StringName:
	return ITEMS.get(loc_id, {}).get(key, &"")


static func rect_of(item: Dictionary) -> Rect2:
	var v: Array = item.get("rect", [0, 0, 0, 0])
	return Rect2(v[0], v[1], v[2], v[3])


## Вещь локации по ключу: проп или декор (декор — только если он есть в данных локации).
static func raw_item(loc: Dictionary, key: String) -> Dictionary:
	if key.begins_with("decor:"):
		var id := key.trim_prefix("decor:")
		for d: Dictionary in loc.get("decor", []):
			if str(d.get("id", "")) == id:
				return d
		return {}
	for pr: Dictionary in loc.get("props", []):
		if str(pr.get("img", "")) == key:
			return pr
	return {}


## Вещь, которая сейчас есть в комнате: купленный декор или обычный проп.
static func item(loc: Dictionary, key: String) -> Dictionary:
	var it := raw_item(loc, key)
	if it.is_empty() or not key.begins_with("decor:"):
		return it
	var profile := _profile()
	return it if profile != null and profile.owns(key.trim_prefix("decor:")) else {}


## Ключи вещей, которые сейчас можно двигать.
static func movable(loc: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key: String in ITEMS.get(str(loc.get("id", "")), {}):
		if not item(loc, key).is_empty():
			out.append(key)
	return out


## Глубина пола: вещь у дальней стены меньше, у зрителя — больше (относительно исходного места).
const HORIZON := 420.0
const DEPTH_MIN := 0.8
const DEPTH_MAX := 1.25


## Сохранённое место: {foot: Vector2, flip: bool} или null.
static func _saved(loc_id: String, key: String) -> Variant:
	var profile := _profile()
	var layout: Variant = profile.data.get("layout") if profile else null
	if not layout is Dictionary:
		return null
	var room: Variant = layout.get(loc_id)
	if not room is Dictionary:
		return null
	var p: Variant = room.get(key)
	if not p is Array or p.size() < 2 or p.size() > 3:
		return null
	for v: Variant in p:
		if not (v is float or v is int or v is bool):
			return null
	return {"foot": Vector2(float(p[0]), float(p[1])), "flip": p.size() == 3 and bool(p[2])}


static func base_rect(it: Dictionary) -> Rect2:
	var b: Array = it.get("base_rect", it.get("rect", [0, 0, 0, 0]))
	return Rect2(b[0], b[1], b[2], b[3])


static func foot_of(r: Rect2) -> Vector2:
	return Vector2(r.position.x + r.size.x * 0.5, r.end.y)


## Масштаб вещи на полу в точке foot_y относительно исходного места; стены — 1.
static func depth_k(loc_id: String, key: String, it: Dictionary, foot_y: float) -> float:
	if kind(loc_id, key) != &"floor":
		return 1.0
	var b := foot_of(base_rect(it)).y - HORIZON
	if b <= 1.0:
		return 1.0
	return clampf((foot_y - HORIZON) / b, DEPTH_MIN, DEPTH_MAX)


## Rect вещи, стоящей «ногами» в foot (середина низа).
static func rect_at(loc_id: String, key: String, it: Dictionary, foot: Vector2) -> Rect2:
	var sz := (base_rect(it).size * depth_k(loc_id, key, it, foot.y)).round()
	return Rect2(Vector2(roundf(foot.x - sz.x * 0.5), foot.y - sz.y), sz)


## Подтягивает точку в допустимую зону: пол — ноги в FLOOR, стена — rect внутри WALL.
## Целые координаты (так они хранятся), с запасом в 1–2 px от краёв зоны.
static func clamp_foot(loc_id: String, key: String, it: Dictionary, foot: Vector2) -> Vector2:
	match kind(loc_id, key):
		&"floor":
			return Vector2(clampf(foot.x, FLOOR.position.x + 2, FLOOR.end.x - 2),
				clampf(foot.y, FLOOR.position.y + 2, FLOOR.end.y - 2)).round()
		&"wall":
			var sz := base_rect(it).size
			var pos := Vector2(foot.x - sz.x * 0.5, foot.y - sz.y)
			pos = Vector2(clampf(pos.x, WALL.position.x + 2, maxf(WALL.position.x + 2, WALL.end.x - sz.x - 2)),
				clampf(pos.y, WALL.position.y + 2, maxf(WALL.position.y + 2, WALL.end.y - sz.y - 2)))
			return Vector2(pos.x + sz.x * 0.5, pos.y + sz.y).round()
	return foot.round()


## Ставит вещи локации на сохранённые места; без записи — расстановка по умолчанию.
static func apply(loc: Dictionary) -> void:
	var loc_id := str(loc.get("id", ""))
	for key: String in ITEMS.get(loc_id, {}):
		var it := raw_item(loc, key)
		if it.is_empty():
			continue
		if not it.has("base_rect"):
			it["base_rect"] = it["rect"].duplicate()
			it["base_flip"] = bool(it.get("flip", false))
			if it.has("shadow"):
				it["base_shadow"] = it["shadow"].duplicate(true)
		var base := base_rect(it)
		var flip := bool(it["base_flip"])
		var r := base
		var at: Variant = _saved(loc_id, key)
		if at != null:
			var moved := rect_at(loc_id, key, it, at.foot)
			if zone_ok(loc_id, key, moved):
				r = moved
				flip = at.flip != bool(it["base_flip"])
		place(it, r, flip)


## Ставит вещь в rect; flip — отражение относительно картинки. Тень едет, растёт и отражается.
static func place(it: Dictionary, r: Rect2, flip: bool) -> void:
	it["rect"] = [roundi(r.position.x), roundi(r.position.y), roundi(r.size.x), roundi(r.size.y)]
	it["flip"] = flip
	if it.has("base_shadow"):
		var b := base_rect(it)
		it["shadow"] = Home.moved_poly(it["base_shadow"], foot_of(b), foot_of(r),
			r.size.y / maxf(1.0, b.size.y), flip != bool(it.get("base_flip", false)))


static func zone_ok(loc_id: String, key: String, r: Rect2) -> bool:
	match kind(loc_id, key):
		&"floor":
			return FLOOR.has_point(foot_of(r))
		&"wall":
			return WALL.encloses(r)
	return false


static func _core(r: Rect2, k: float) -> Rect2:
	return r.grow_individual(-r.size.x * k, -r.size.y * k, -r.size.x * k, -r.size.y * k)


## Свободно ли место: не на ремонтируемой вещи, не на семье, на стене — не на другой стенной вещи.
static func fits(loc: Dictionary, key: String, r: Rect2) -> bool:
	var loc_id := str(loc.get("id", ""))
	if not zone_ok(loc_id, key, r):
		return false
	var core := _core(r, 0.15)
	for t: Dictionary in loc.get("targets", []):
		if core.intersects(_core(rect_of(t), 0.12)):
			return false
	for pr: Dictionary in loc.get("props", []):
		if str(pr.get("img", "")).begins_with("family/") and core.intersects(_core(rect_of(pr), 0.25)):
			return false
	var fam: Dictionary = loc.get("family", {})
	if fam.has("pos"):
		var h := float(fam.get("height", 500.0))
		var foot := Vector2(fam["pos"][0], fam["pos"][1])
		if core.intersects(Rect2(foot.x - h * 0.3, foot.y - h, h * 0.6, h * 0.95)):
			return false
	if kind(loc_id, key) == &"wall":
		for other: String in ITEMS.get(loc_id, {}):
			if other != key and kind(loc_id, other) == &"wall":
				var o := item(loc, other)
				if not o.is_empty() and core.intersects(_core(rect_of(o), 0.1)):
					return false
		for img: String in WALL_FIXED.get(loc_id, []):
			var o := raw_item(loc, img)
			if not o.is_empty() and core.intersects(_core(rect_of(o), 0.1)):
				return false
	return true


## Вещь под пальцем (сверху — большее z); "" — нет.
static func hit(loc: Dictionary, p: Vector2) -> String:
	var best := ""
	var best_z := -INF
	for key in movable(loc):
		var it := item(loc, key)
		var z := float(it.get("z", 5.0))
		if rect_of(it).grow(10).has_point(p) and z >= best_z:
			best = key
			best_z = z
	return best


static func save(loc: Dictionary, key: String) -> void:
	var profile := _profile()
	var layout: Variant = profile.data.get("layout")
	if not layout is Dictionary:
		layout = {}
		profile.data["layout"] = layout
	var loc_id := str(loc.get("id", ""))
	if not layout.get(loc_id) is Dictionary:
		layout[loc_id] = {}
	var it := raw_item(loc, key)
	var foot := foot_of(rect_of(it))
	var flip := bool(it.get("flip", false)) != bool(it.get("base_flip", false))
	layout[loc_id][key] = [foot.x, foot.y, flip]
	profile.mark_changed(&"layout")


static func reset(loc: Dictionary) -> void:
	var profile := _profile()
	var layout: Variant = profile.data.get("layout")
	if layout is Dictionary:
		layout.erase(str(loc.get("id", "")))
	apply(loc)
	profile.mark_changed(&"layout")
