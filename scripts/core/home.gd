class_name Home
extends RefCounted
## Первый акт: 4 локации открываются по очереди (data/act1.json), в каждой — свои ремонты.
## Внутри открытой локации игрок сам выбирает, что чинить; одна победа чинит ровно одну цель.
## Прогресс — флаги Profile "home.<id цели>". Profile отвечает за сохранение.

const DATA_PATH := "res://data/act1.json"
# Старый первый акт (10 ремонтов по порядку): переносим число сделанных ремонтов.
const OLD_ORDER := ["tv", "light", "window", "bed", "sofa", "kitchen", "bath", "toilet", "walls", "floor"]

static var _data: Dictionary = {}
static var _tasks: Array = []

const SHOP := [
	{"id":"vita_plant", "name":"Зелёный друг", "text":"Цветок на столе: +10 монет к каждой награде", "price":120},
	{"id":"vita_teddy", "name":"Мишка для дочки", "text":"С мишкой не страшно: одна ошибка в уровне прощается", "price":180},
	{"id":"vita_clothes", "name":"Тёплые кофты", "text":"Семья не мёрзнет, а за звезду — 20 монет", "price":260},
	{"id":"vita_picture", "name":"Наши счастливые дни", "text":"Картина на стене: +30 монет за новый ремонт", "price":220},
]


## Расстановка, сохранённая из сцены комнаты в редакторе (scenes/locations/<id>.tscn → Ctrl+S
## → data/layout/<id>.json): rect, z, отражение и поворот предметов, место и отражение семьи,
## rect купленного декора — поверх act1.json. Тени-следы на полу переезжают вместе с вещью.
static func _apply_layout(loc: Dictionary) -> void:
	var path := "res://data/layout/%s.json" % loc["id"]
	if not FileAccess.file_exists(path):
		return
	var lay: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not lay is Dictionary:
		return
	for t: Dictionary in loc.get("targets", []):
		var o: Dictionary = lay.get("targets", {}).get(str(t["id"]), {})
		if not o.is_empty():
			_move_shadow(t, o)
			t.merge(o, true)
			t.erase("more")
	for pr: Dictionary in loc.get("props", []):
		var o: Dictionary = lay.get("props", {}).get(str(pr["img"]), {})
		_move_shadow(pr, o)
		pr.merge(o, true)
	for d: Dictionary in loc.get("decor", []):
		d.merge(lay.get("decor", {}).get(str(d["id"]), {}), true)
	if lay.has("family") and loc.has("family"):
		var fam: Dictionary = loc["family"]
		var o: Dictionary = lay["family"]
		if fam.has("shadow") and o.has("pos"):
			var h0 := float(fam.get("height", 560.0))
			var p0: Array = fam.get("pos", [360, 1300])
			fam["shadow"] = moved_poly(fam["shadow"], Vector2(p0[0], p0[1]), Vector2(o["pos"][0], o["pos"][1]),
				float(o.get("height", h0)) / h0, bool(o.get("flip", false)) != bool(fam.get("flip", false)))
		fam.merge(o, true)


## Тень-след переезжает вместе с вещью: от середины низа старого rect к середине низа нового,
## с тем же масштабом; отражённая вещь — отражённый след.
static func _move_shadow(item: Dictionary, o: Dictionary) -> void:
	if not item.has("shadow") or not o.has("rect"):
		return
	var r0: Array = item["rect"]
	var r1: Array = o["rect"]
	item["shadow"] = moved_poly(item["shadow"], Vector2(r0[0] + r0[2] * 0.5, r0[1] + r0[3]),
		Vector2(r1[0] + r1[2] * 0.5, r1[1] + r1[3]), float(r1[3]) / maxf(1.0, float(r0[3])),
		bool(o.get("flip", item.get("flip", false))) != bool(item.get("flip", false)))


static func moved_poly(poly: Array, from: Vector2, to: Vector2, k: float, mirror: bool) -> Array:
	var out: Array = []
	for p: Array in poly:
		var d := (Vector2(p[0], p[1]) - from) * k
		if mirror:
			d.x = -d.x
		out.append([roundi(to.x + d.x), roundi(to.y + d.y)])
	return out


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text()) if f else {}
		for loc in _data.get("locations", []):
			_apply_layout(loc)
			for t in loc["targets"]:
				t["loc"] = loc["id"]
				_tasks.append(t)
	return _data


static func locations() -> Array:
	return data().get("locations", [])


## Все цели по порядку локаций: {id, name, title, text, level, rect, loc, ...}.
static func tasks() -> Array:
	data()
	return _tasks


static func location(loc_id: String) -> Dictionary:
	for loc in locations():
		if loc["id"] == loc_id:
			return loc
	return {}


static func task(task_id: String) -> Dictionary:
	for t in tasks():
		if t["id"] == task_id:
			return t
	return {}


static func is_done(task_id: String) -> bool:
	migrate()
	return Profile.flag("home." + task_id)


static func location_done(loc_id: String) -> bool:
	for t in location(loc_id).get("targets", []):
		if not is_done(t["id"]):
			return false
	return true


## Сколько локаций открыто: первая всегда, следующая — когда готова предыдущая.
static func unlocked_count() -> int:
	var n := 1
	var locs := locations()
	for i in range(locs.size() - 1):
		if not location_done(locs[i]["id"]):
			break
		n += 1
	return n


static func is_unlocked(loc_id: String) -> bool:
	var locs := locations()
	for i in unlocked_count():
		if locs[i]["id"] == loc_id:
			return true
	return false


## Последняя открытая локация — туда hub ведёт по умолчанию.
static func current_location() -> String:
	return str(locations()[unlocked_count() - 1]["id"])


static func completed() -> int:
	var n := 0
	for t in tasks():
		if is_done(t["id"]):
			n += 1
	return n


static func total() -> int:
	return tasks().size()


## Первая несделанная цель в текущей локации (для подсказки «с чего начать»).
static func next_task() -> Dictionary:
	for t in location(current_location()).get("targets", []):
		if not is_done(t["id"]):
			return t
	return {}


static func task_for_level(id: String) -> Dictionary:
	for t in tasks():
		if t["level"] == id:
			return t
	return {}


## Победа в уровне цели чинит её, если локация открыта и цель ещё сломана. Возвращает id цели.
static func finish(level_id: String, won: bool) -> String:
	var t := task_for_level(level_id)
	if not won or t.is_empty() or is_done(t["id"]) or not is_unlocked(t["loc"]):
		return ""
	Profile.set_flag("home." + t["id"])
	# Сохраняем до анимации итога: закрытие игры не потеряет ремонт.
	Profile.flush()
	return t["id"]


## Настроение семьи по общему прогрессу: 0 устали, 1 надеются, 2 рады, 3 счастливы.
static func mood() -> int:
	var n := completed()
	return 0 if n < 4 else (1 if n < 9 else (2 if n < 14 else 3))


## Картинка семьи в головоломке и старых сценах: 3 — купленная одежда, 2 — радостные, иначе будни.
static func stage() -> int:
	if Profile.owns("vita_clothes"):
		return 3
	return 2 if mood() >= 2 else (1 if mood() == 1 else 0)


## Один раз переносит старый прогресс (10 ремонтов подряд) на столько же первых целей акта.
static func migrate() -> void:
	if Profile.flag("home.v2"):
		return
	Profile.set_flag("home.v2")
	var old := 0
	for id in OLD_ORDER:
		if not Profile.flag("home." + id):
			break
		old += 1
	var list := tasks()
	for i in mini(old, list.size()):
		Profile.set_flag("home." + list[i]["id"])
	Profile.flush()


static func buy(id: String) -> bool:
	for item in SHOP:
		if item.id == id and not Profile.owns(id) and Profile.spend_coins(item.price,"decor"):
			Profile.grant(id)
			Profile.flush()
			return true
	return false
