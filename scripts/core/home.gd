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
	{"id":"vita_plant", "name":"Зелёный друг", "text":"Растение для дома", "price":120},
	{"id":"vita_teddy", "name":"Мишка для дочки", "text":"Любимая игрушка рядом с кроватью", "price":180},
	{"id":"vita_clothes", "name":"Семейное обновление", "text":"Новые наряды маме и дочке", "price":260},
	{"id":"vita_picture", "name":"Наши счастливые дни", "text":"Семейная картина на стене", "price":220},
]


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text()) if f else {}
		for loc in _data.get("locations", []):
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
