extends Node
## Автозагрузка "Profile": всё состояние игрока и его сохранение (save v2).
## Только состояние, без правил экономики: их держит Economy.
##
## Файл user://save.json пишется атомарно: сначала save.tmp, прошлый файл
## копируется в save.bak, затем save.tmp переименовывается поверх save.json.
## Если save.json не читается, берём save.bak.

signal changed(key: StringName)

const VERSION := 2
const SAVE_DELAY := 0.5
const OLD_SAVE := "user://progress.cfg"
## Старые уровни по индексу из progress.cfg: level_001 стал f1_05.
const OLD_LEVELS: PackedStringArray = ["f1_05"]
const SETTINGS := {"sfx": true, "music": true, "vibration": true, "lang": "auto", "low_fx": false}
const CHANGE_KEYS: Array[StringName] = [&"coins", &"hints", &"stars", &"levels", &"owned",
		&"equipped", &"lab", &"grimoire", &"settings", &"daily"]

## true: никогда не трогать диск (dev-запуски и проверки).
var volatile := false
## Подмена даты для тестов: "YYYY-MM-DD" или "".
var fake_today := ""
## Путь сохранения; .tmp и .bak лежат рядом.
var save_path := "user://save.json"
## Всё сохранение как есть. Economy может менять поля без отдельного API
## (streak, chest, daily, last_open) и затем звать mark_changed().
var data: Dictionary = {}
## Итог последнего record_result: {id, first_clear, new_stars}.
var last_record: Dictionary = {}

var _pending := false
var _save_left := 0.0
# save.json прочитан без ошибок: только тогда он годится в save.bak
var _main_ok := false


func _init() -> void:
	data = defaults()
	set_process(false)


func _ready() -> void:
	# dev-флаги (всё после "--") означают проверочный запуск: реальное сохранение не трогаем
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			volatile = true
			break
	# self.: без него вызов уходит во встроенную load(path)
	self.load()
	# _process нужен только пока ждёт запись
	set_process(_pending)


func _process(delta: float) -> void:
	_save_left -= delta
	if _save_left <= 0.0:
		flush()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_EXIT_TREE:
			flush()


static func defaults() -> Dictionary:
	return {
		"v": VERSION, "coins": 0, "hints": 3, "stars_spent": 0,
		"levels": {}, "fails": {}, "streak": 0, "chest": 0,
		"owned": ["apprentice"], "equipped": {"outfit": "apprentice", "familiar": ""},
		"lab": [], "grimoire": [],
		"daily": {"slot": 0, "cycle": 0, "last_claim": "", "potion_done": "", "owl_last": ""},
		"last_open": "", "flags": {},
		"settings": SETTINGS.duplicate(),
		"stats": {},
	}


# --- сохранение --------------------------------------------------------------

## Читает сохранение с диска (или .bak, или переносит progress.cfg).
func load() -> void:
	flush()
	var loaded := {}
	var migrated := false
	if not volatile:
		loaded = _read(save_path)
		_main_ok = not loaded.is_empty()
		if loaded.is_empty() and FileAccess.file_exists(save_path):
			push_warning("Profile: %s is broken, using the backup" % save_path)
		if loaded.is_empty():
			loaded = _read(_bak_path())
		if loaded.is_empty() and not FileAccess.file_exists(save_path) \
				and not FileAccess.file_exists(_bak_path()):
			loaded = _migrate_v1()
			migrated = not loaded.is_empty()
	data = _sanitize(loaded)
	if migrated:
		_write()
	for key in CHANGE_KEYS:
		changed.emit(key)


## Отложенная запись (0.5 с); несколько вызовов подряд дают одну запись.
func save() -> void:
	if volatile or _pending:
		return
	_pending = true
	_save_left = SAVE_DELAY
	set_process(true)


## Записать немедленно, если есть отложенная запись.
func flush() -> void:
	set_process(false)
	if not _pending:
		return
	_pending = false
	_write()


## Для Economy: поле в data изменено напрямую.
func mark_changed(key: StringName) -> void:
	changed.emit(key)
	save()


## Сброс прогресса; настройки остаются.
func reset_progress() -> void:
	var keep: Dictionary = data.get("settings", {})
	data = defaults()
	data["settings"] = keep
	last_record = {}
	for key in CHANGE_KEYS:
		changed.emit(key)
	save()


# --- валюты ------------------------------------------------------------------

func coins() -> int:
	return int(data["coins"])


func add_coins(n: int, reason: String) -> void:
	if n == 0:
		return
	data["coins"] = maxi(0, coins() + n)
	stat_inc("coins_in." + reason, n)
	changed.emit(&"coins")
	save()


func spend_coins(n: int, reason: String) -> bool:
	if n < 0 or coins() < n:
		return false
	data["coins"] = coins() - n
	stat_inc("coins_out." + reason, n)
	changed.emit(&"coins")
	save()
	return true


func hints() -> int:
	return int(data["hints"])


func add_hints(n: int) -> void:
	data["hints"] = maxi(0, hints() + n)
	changed.emit(&"hints")
	save()


func spend_hint() -> bool:
	if hints() <= 0:
		return false
	data["hints"] = hints() - 1
	changed.emit(&"hints")
	save()
	return true


# --- уровни ------------------------------------------------------------------

func best_stars(id: String) -> int:
	return int(_level(id).get("stars", 0))


## Пропущенный уровень тоже считается пройденным.
func is_cleared(id: String) -> bool:
	return bool(_level(id).get("cleared", false))


## Первый уровень открыт всегда, любой другой — когда пройден предыдущий.
## Поэтому переигровка старого уровня никогда не отодвигает прогресс назад.
func is_unlocked(id: String) -> bool:
	var ids := _level_ids()
	var i := ids.find(id)
	if i < 0:
		return false
	return i == 0 or is_cleared(ids[i - 1])


## Первый открытый и не пройденный уровень, иначе последний.
func current_level_id() -> String:
	var ids := _level_ids()
	for id in ids:
		if is_unlocked(id) and not is_cleared(id):
			return id
	return ids[ids.size() - 1] if ids.size() > 0 else ""


## Запоминает лучший результат. skipped: пропуск за монеты (0★, но пройден).
## first_clear: уровень раньше не был пройден (и пропущен тоже).
func record_result(id: String, stars: int, skipped := false) -> Dictionary:
	var levels: Dictionary = data["levels"]
	var e: Dictionary = levels.get(id, {"stars": 0, "cleared": false, "skipped": false, "relic": false})
	var first_clear := not bool(e.get("cleared", false))
	var old := int(e.get("stars", 0))
	var new_stars := 0
	if skipped:
		if first_clear:
			e["skipped"] = true
	else:
		var s := clampi(stars, 0, 3)
		new_stars = maxi(0, s - old)
		e["stars"] = maxi(old, s)
		e["skipped"] = false
	e["cleared"] = true
	levels[id] = e
	last_record = {"id": id, "first_clear": first_clear, "new_stars": new_stars}
	changed.emit(&"levels")
	if new_stars > 0:
		changed.emit(&"stars")
	save()
	return {"first_clear": first_clear, "new_stars": new_stars}


func stars_total() -> int:
	var n := 0
	for id in data["levels"]:
		n += int(data["levels"][id].get("stars", 0))
	return n


func stars_wallet() -> int:
	return stars_total() - int(data["stars_spent"])


func spend_stars(n: int) -> bool:
	if n < 0 or stars_wallet() < n:
		return false
	data["stars_spent"] = int(data["stars_spent"]) + n
	changed.emit(&"stars")
	save()
	return true


func fails(id: String) -> int:
	return int(data["fails"].get(id, 0))


func add_fail(id: String) -> void:
	data["fails"][id] = fails(id) + 1
	changed.emit(&"levels")
	save()


func reset_fails(id: String) -> void:
	if not data["fails"].has(id):
		return
	data["fails"].erase(id)
	changed.emit(&"levels")
	save()


func has_relic(level_id: String) -> bool:
	return bool(_level(level_id).get("relic", false))


func add_relic(level_id: String) -> void:
	if has_relic(level_id):
		return
	var levels: Dictionary = data["levels"]
	var e: Dictionary = levels.get(level_id, {"stars": 0, "cleared": false, "skipped": false, "relic": false})
	e["relic"] = true
	levels[level_id] = e
	changed.emit(&"levels")
	changed.emit(&"grimoire")
	save()


# --- коллекции ---------------------------------------------------------------

func owns(item_id: String) -> bool:
	return data["owned"].has(item_id)


func grant(item_id: String) -> void:
	if owns(item_id):
		return
	data["owned"].append(item_id)
	changed.emit(&"owned")
	save()


## slot: &"outfit" | &"familiar"; "" — ничего не надето.
func equipped(slot: StringName) -> String:
	return str(data["equipped"].get(String(slot), ""))


func equip(slot: StringName, item_id: String) -> void:
	data["equipped"][String(slot)] = item_id
	changed.emit(&"equipped")
	save()


func lab_restored(obj_id: String) -> bool:
	return data["lab"].has(obj_id)


func mark_restored(obj_id: String) -> void:
	if lab_restored(obj_id):
		return
	data["lab"].append(obj_id)
	changed.emit(&"lab")
	save()


func grimoire_has(page_id: String) -> bool:
	return data["grimoire"].has(page_id)


## true, если страница новая.
func grimoire_add(page_id: String) -> bool:
	if grimoire_has(page_id):
		return false
	data["grimoire"].append(page_id)
	changed.emit(&"grimoire")
	save()
	return true


# --- настройки, флаги, статистика ----------------------------------------------

## sfx, music, vibration, low_fx: bool; lang: "auto" | "ru" | "en".
func setting(key: StringName) -> Variant:
	return data["settings"].get(String(key), SETTINGS.get(String(key)))


func set_setting(key: StringName, v: Variant) -> void:
	if data["settings"].get(String(key)) == v:
		return
	data["settings"][String(key)] = v
	changed.emit(&"settings")
	save()


func flag(key: String) -> bool:
	return bool(data["flags"].get(key, false))


func set_flag(key: String, v := true) -> void:
	if flag(key) == v:
		return
	data["flags"][key] = v
	save()


## Местная дата "YYYY-MM-DD".
func today() -> String:
	return fake_today if fake_today != "" else Time.get_date_string_from_system(false)


## Локальные счётчики (без сети): path вида "levels.f1_05.plays".
func stat_inc(path: String, n := 1) -> void:
	var node: Dictionary = data["stats"]
	var parts := path.split(".", false)
	if parts.is_empty():
		return
	for i in parts.size() - 1:
		var next: Variant = node.get(parts[i])
		if not next is Dictionary:
			next = {}
			node[parts[i]] = next
		node = next
	var last := parts[parts.size() - 1]
	node[last] = int(node.get(last, 0)) + n
	save()


# --- внутреннее ---------------------------------------------------------------

func _level(id: String) -> Dictionary:
	return data["levels"].get(id, {})


func _level_ids() -> PackedStringArray:
	# через дерево движка, а не get_node: работает и у экземпляра вне дерева (тесты)
	var game := (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Game")
	if game and game.has_method(&"level_ids"):
		var ids: Variant = game.call(&"level_ids")
		return PackedStringArray(ids)
	return PackedStringArray()


func _bak_path() -> String:
	return save_path.get_basename() + ".bak"


func _tmp_path() -> String:
	return save_path.get_basename() + ".tmp"


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _write() -> void:
	if volatile:
		return
	var dir := save_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp := _tmp_path()
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Profile: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(data))
	f.close()
	# битый save.json не должен затереть хорошую копию
	if _main_ok and FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, _bak_path())
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		push_error("Profile: cannot replace %s (%s)" % [save_path, error_string(err)])
		return
	_main_ok = true


## Однократный перенос звёзд из старого user://progress.cfg (версия 0.1).
func _migrate_v1() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(OLD_SAVE) != OK:
		return {}
	var d := defaults()
	var best: Variant = cfg.get_value("progress", "best_stars", {})
	if best is Dictionary:
		for i in best:
			var idx := int(i)
			var stars := clampi(int(best[i]), 0, 3)
			if idx >= 0 and idx < OLD_LEVELS.size() and stars > 0:
				d["levels"][OLD_LEVELS[idx]] = {"stars": stars, "cleared": true, "skipped": false, "relic": false}
	d["flags"]["migrated_v1"] = true
	return d


## Приводит прочитанный JSON к save v2: числа из JSON приходят float,
## недостающие поля берутся по умолчанию, лишние поля сохраняются.
func _sanitize(src: Dictionary) -> Dictionary:
	var d := defaults()
	for key in src:
		if not d.has(key):
			d[key] = src[key]
	for key in ["coins", "hints", "stars_spent", "streak", "chest"]:
		d[key] = maxi(0, int(src.get(key, d[key])))
	d["v"] = VERSION
	var levels: Dictionary = {}
	var src_levels: Variant = src.get("levels", {})
	if src_levels is Dictionary:
		for id in src_levels:
			var e: Variant = src_levels[id]
			if e is Dictionary:
				levels[str(id)] = {"stars": clampi(int(e.get("stars", 0)), 0, 3),
						"cleared": bool(e.get("cleared", false)),
						"skipped": bool(e.get("skipped", false)), "relic": bool(e.get("relic", false))}
	d["levels"] = levels
	var fails_d: Dictionary = {}
	var src_fails: Variant = src.get("fails", {})
	if src_fails is Dictionary:
		for id in src_fails:
			fails_d[str(id)] = int(src_fails[id])
	d["fails"] = fails_d
	for key in ["owned", "lab", "grimoire"]:
		var arr: Variant = src.get(key)
		if arr is Array:
			var clean: Array = []
			for x in arr:
				if not clean.has(str(x)):
					clean.append(str(x))
			d[key] = clean
	for key in ["equipped", "daily", "settings"]:
		var sub: Variant = src.get(key)
		if sub is Dictionary:
			for k in sub:
				var def: Variant = d[key].get(k)
				d[key][k] = _like(def, sub[k])
	for key in ["last_open"]:
		d[key] = str(src.get(key, ""))
	for key in ["flags", "stats"]:
		if src.get(key) is Dictionary:
			d[key] = src[key]
	return d


## Значение v с типом образца (JSON отдаёт числа как float).
static func _like(sample: Variant, v: Variant) -> Variant:
	match typeof(sample):
		TYPE_INT:
			return int(v)
		TYPE_BOOL:
			return bool(v)
		TYPE_STRING:
			return str(v)
	return v
