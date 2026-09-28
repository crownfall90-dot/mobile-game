extends RefCounted
## Бытовые сценки из data/activities.json: что можно сделать у починенной вещи или предмета
## в комнате (уложить Виту спать, поставить чайник…). Ключ — id вещи из act1.json или
## «локация/картинка» предмета-наполнителя. Сценки играет новелла, id сценки — "act:<ключ>:<n>".

const DATA := "res://data/activities.json"

static var _cache := {}


static func all() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(DATA, FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			_cache = d
			_cache.erase("_about")
	return _cache


## Ключ предмета-наполнителя: «локация/имя картинки» (room/room_rug).
static func prop_key(loc_id: String, img: String) -> String:
	return "%s/%s" % [loc_id, img.get_file()]


## Действия, доступные сейчас: [[индекс, подпись], ...]. after — нужна починенная вещь,
## need — нужна покупка из магазина.
static func available(key: String) -> Array:
	var out := []
	var acts: Array = all().get(key, {}).get("acts", [])
	for i in acts.size():
		var a: Dictionary = acts[i]
		if a.get("animation", {}).is_empty():
			continue
		if a.has("after") and not Home.is_done(str(a["after"])):
			continue
		if a.has("need") and not Profile.owns(str(a["need"])):
			continue
		out.append([i, str(a.get("label", ""))])
	return out


## Почему занятий пока нет: «Сначала почини: плита» / «Нужна покупка: цветок». Пусто — всё открыто
## или у ключа нет занятий.
static func locked_reason(key: String) -> String:
	for a: Dictionary in all().get(key, {}).get("acts", []):
		if a.get("animation", {}).is_empty():
			continue
		if a.has("after") and not Home.is_done(str(a["after"])):
			return "Сначала почини: %s" % str(Home.task(str(a["after"])).get("name", "вещь")).to_lower()
		if a.has("need") and not Profile.owns(str(a["need"])):
			for it: Dictionary in Home.SHOP:
				if str(it["id"]) == str(a["need"]):
					return "Нужна покупка: %s" % str(it["name"]).to_lower()
	return ""


static func title(key: String, fallback := "") -> String:
	return str(all().get(key, {}).get("name", fallback))


static func scene_id(key: String, index: int) -> String:
	return "act:%s:%d" % [key, index]


static func animation(key: String, index: int) -> Dictionary:
	var acts: Array = all().get(key, {}).get("acts", [])
	return acts[index].get("animation", {}) if index >= 0 and index < acts.size() else {}


static func has_animation(key: String) -> bool:
	for a: Dictionary in all().get(key, {}).get("acts", []):
		if not a.get("animation", {}).is_empty():
			return true
	return false


## Все сценки для новеллы: id -> шаги.
static func scenes() -> Dictionary:
	var out := {}
	for key: String in all():
		var acts: Array = all()[key].get("acts", [])
		for i in acts.size():
			out[scene_id(key, i)] = acts[i].get("scene", [])
	return out
