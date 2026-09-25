extends Node
## Автозагрузка "Game": каталог уровней (levels/index.json v2) и dev-флаги запуска.
## Прогресс игрока здесь не хранится: он в Profile.
##
## Game.dev — разобранные флаги после "--" (см. scripts/dev/dev_runner.gd):
##   level: String, file: String, autoplay: bool, pins: PackedStringArray, all_at_once: bool,
##   interval: float или "settle", jitter: int, mods: Dictionary, json: bool,
##   screen: String, shot: String, smoke: bool. Нет флагов — пустой словарь.

const INDEX_PATH := "res://levels/index.json"
const LEVEL_DIR := "res://levels/"
const SOLUTIONS_DIR := "res://levels/solutions/"

var dev: Dictionary = {}
## Тизер следующего этажа из индекса: {title, text}.
var teaser: Dictionary = {}

var _floors: Array = []          # этажи индекса; в levels только уровни с файлами
var _ids := PackedStringArray()   # все существующие уровни по порядку
var _floor_of: Dictionary = {}    # id -> этаж
var _labels: Dictionary = {}      # id -> "2-3"
var _raw: Dictionary = {}         # id -> разобранный файл (кэш)


func _init() -> void:
	dev = parse_flags(OS.get_cmdline_user_args())
	_load_index()


func floors() -> Array:
	return _floors


func floor_of(level_id: String) -> Dictionary:
	return _floor_of.get(level_id, {})


func level_ids() -> PackedStringArray:
	return _ids


func has_level(id: String) -> bool:
	return _floor_of.has(id)


## Номер для интерфейса: "этаж-позиция", например "2-3". Для уровня вне индекса — "".
func level_label(id: String) -> String:
	return _labels.get(id, "")


## {id, floor, floor_id, n, label, hard, title, relic, intro, tutorial, daily}.
## title — строка или {ru, en}: показывать через Loc.pick().
func level_meta(id: String) -> Dictionary:
	var d := _read(id)
	var fl: Dictionary = _floor_of.get(id, {})
	var relic := ""
	for fill in d.get("fills", []):
		if fill is Dictionary and str(fill.get("kind", "")) == "relic":
			relic = str(fill.get("relic", ""))
	var label: String = _labels.get(id, "")
	return {
		"id": id,
		"floor": int(fl.get("n", d.get("floor", 0))),
		"floor_id": str(fl.get("id", "")),
		"n": int(label.get_slice("-", 1)) if label != "" else 0,
		"label": label,
		"hard": bool(d.get("hard", false)),
		"title": d.get("title", ""),
		"relic": relic,
		"intro": str(d.get("intro", "")),
		"tutorial": str(d.get("tutorial", "")),
		"daily": bool(d.get("verify", {}).get("daily", true)) if d.get("verify") is Dictionary else true,
	}


## Уровень по id: читает levels/<id>.json, даже если id нет в индексе.
## mods: {"golden": true} — всё золото становится самоцветами. Пустой словарь — ошибка.
func load_level(id: String, mods: Dictionary = {}) -> Dictionary:
	var d := _read(id)
	if d.is_empty():
		return {}
	return _prepare(d, id, mods)


## Уровень из произвольного файла (levels/test/*.json и т. п.).
func load_level_file(path: String, mods: Dictionary = {}) -> Dictionary:
	var d := _parse_file(path)
	if d.is_empty():
		return {}
	return _prepare(d, str(d.get("id", path.get_file().get_basename())), mods)


## Проверенные выигрышные порядки: levels/solutions/<id>.json (список порядков),
## иначе [solution] из самого уровня.
func winning_orders(id: String) -> Array:
	var path := SOLUTIONS_DIR + id + ".json"
	if FileAccess.file_exists(path):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			v = v.get("orders", [])
		if v is Array and not v.is_empty():
			return v
		push_warning("Game: bad solutions file %s" % path)
	var sol: Variant = _read(id).get("solution", [])
	return [sol] if sol is Array and not sol.is_empty() else []


## Следующий уровень по индексу; "" для последнего и для уровней вне индекса.
func next_level_after(id: String) -> String:
	var i := _ids.find(id)
	if i < 0 or i + 1 >= _ids.size():
		return ""
	return _ids[i + 1]


static func parse_flags(args: PackedStringArray) -> Dictionary:
	var d := {}
	for arg in args:
		if not arg.begins_with("--"):
			continue
		var parts := arg.substr(2).split("=", true, 1)
		var key := parts[0]
		var val := parts[1] if parts.size() > 1 else ""
		match key:
			"level", "file", "screen", "shot", "home-stage", "home-items", "screen-args":
				d[key] = val
			"autoplay", "all-at-once", "json", "smoke", "home-selfcheck":
				d[key.replace("-", "_")] = true
			"pins":
				d["pins"] = val.split(",", false)
			"interval":
				d["interval"] = "settle" if val == "settle" else maxf(0.0, val.to_float())
			"jitter":
				d["jitter"] = val.to_int()
			"mods":
				var mods := {}
				for m in val.split(",", false):
					mods[m] = true
				d["mods"] = mods
			_:
				push_warning("Game: unknown dev flag '%s'" % arg)
	return d


# --- чтение -------------------------------------------------------------------

func _load_index() -> void:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if not index is Dictionary:
		push_error("Game: broken %s" % INDEX_PATH)
		return
	teaser = index.get("teaser", {})
	var floors_src: Array = index.get("floors", [])
	# формат 1: {"levels": ["level_001.json"]} — один безымянный этаж
	if floors_src.is_empty() and index.has("levels"):
		var ids := []
		for f in index["levels"]:
			ids.append(str(f).get_basename())
		floors_src = [{"id": "floor1", "n": 1, "title": "", "levels": ids}]
	var missing := PackedStringArray()
	for src in floors_src:
		var fl: Dictionary = src.duplicate(true)
		var all: Array = fl.get("levels", [])
		var present := PackedStringArray()
		for i in all.size():
			var id := str(all[i])
			if not FileAccess.file_exists(_path(id)):
				missing.append(id)
				continue
			present.append(id)
			_ids.append(id)
			_floor_of[id] = fl
			# позиция из полного списка: подпись не съезжает, если уровня не хватает
			_labels[id] = "%d-%d" % [int(fl.get("n", _floors.size() + 1)), i + 1]
		fl["levels"] = present
		_floors.append(fl)
	if not missing.is_empty():
		push_warning("Game: %d level file(s) missing, skipped: %s" % [missing.size(), ", ".join(missing)])
	if _ids.is_empty():
		push_error("Game: no playable levels in %s" % INDEX_PATH)


func _path(id: String) -> String:
	return LEVEL_DIR + id + ".json"


func _read(id: String) -> Dictionary:
	if not _raw.has(id):
		_raw[id] = _parse_file(_path(id))
	return _raw[id]


func _parse_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Game: no level file %s" % path)
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		push_error("Game: broken level %s (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data


## Копия данных уровня в формате 2 с применёнными модификаторами.
func _prepare(src: Dictionary, id: String, mods: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	d["id"] = id
	d["format"] = int(d.get("format", 1))
	if not d.has("floor"):
		d["floor"] = int(_floor_of.get(id, {}).get("n", 0))
	for key in ["title", "hint", "tutorial", "intro"]:
		if not d.has(key):
			d[key] = ""
	d["mods"] = mods.duplicate()
	if mods.get("golden", false):
		for fill in d.get("fills", []):
			if fill is Dictionary and str(fill.get("kind", "")) == "gold":
				fill["kind"] = "gem"
	return d
