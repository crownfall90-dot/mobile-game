extends Node
## Автозагрузка "Loc": строки интерфейса на русском и английском.
## Склеивает все data/strings/*.json: {"модуль.ключ": {"ru": "…", "en": "…"}}.

signal lang_changed

const STRINGS_DIR := "res://data/strings/"
const LANGS: PackedStringArray = ["auto", "ru", "en"]
## Языки системы, для которых «Авто» выбирает русский.
const RU_LOCALES: PackedStringArray = ["ru", "uk", "be", "kk"]

var _strings: Dictionary = {}
var _warned: Dictionary = {}
var _lang := ""
var _setting_lang := false


func _ready() -> void:
	_load_strings()
	# Profile идёт в автозагрузках после Loc: подписываемся, когда он уже в дереве
	_watch_profile.call_deferred()


## Строка по ключу; {0}, {1}… заменяются на args. Нет ключа: вернёт сам ключ.
func t(key: String, args: Array = []) -> String:
	var entry: Variant = _strings.get(key)
	var s := key
	if entry == null:
		if not _warned.has(key):
			_warned[key] = true
			push_warning("Loc: no string for key '%s'" % key)
	else:
		s = pick(entry)
	for i in args.size():
		s = s.replace("{%d}" % i, str(args[i]))
	return s


## Строка или словарь {ru, en} в текущем языке.
func pick(v: Variant) -> String:
	if v is String or v is StringName:
		return String(v)
	if v is Dictionary:
		var d: Dictionary = v
		var code := lang()
		if d.has(code):
			return str(d[code])
		for other in ["ru", "en"]:
			if d.has(other):
				return str(d[other])
		return ""
	return "" if v == null else str(v)


## Действующий язык: "ru" или "en".
func lang() -> String:
	if _lang == "":
		_lang = _resolve()
	return _lang


## code: "auto" | "ru" | "en". Сохраняет настройку и шлёт lang_changed.
func set_lang(code: String) -> void:
	if not LANGS.has(code):
		push_warning("Loc: unknown language '%s'" % code)
		return
	_setting_lang = true
	Profile.set_setting(&"lang", code)
	_setting_lang = false
	_lang = _resolve()
	lang_changed.emit()


func has_key(key: String) -> bool:
	return _strings.has(key)


func _resolve() -> String:
	var code := str(Profile.setting(&"lang"))
	if code == "ru" or code == "en":
		return code
	return "ru" if RU_LOCALES.has(OS.get_locale_language()) else "en"


func _watch_profile() -> void:
	Profile.changed.connect(_on_profile_changed)
	_on_profile_changed(&"settings")


func _on_profile_changed(key: StringName) -> void:
	if key != &"settings" or _setting_lang:
		return
	var now := _resolve()
	if now == _lang:
		return
	# при старте язык ещё никто не спрашивал: сообщать некому
	var known := _lang != ""
	_lang = now
	if known:
		lang_changed.emit()


func _load_strings() -> void:
	var files := DirAccess.get_files_at(STRINGS_DIR)
	files.sort()
	for f in files:
		if f.get_extension() != "json":
			continue
		var path := STRINGS_DIR + f
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
			push_error("Loc: broken strings file %s (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
			continue
		var d: Dictionary = json.data
		for key in d:
			if _strings.has(key):
				push_warning("Loc: key '%s' in %s overrides an earlier file" % [key, path])
			_strings[key] = d[key]
	if _strings.is_empty():
		push_error("Loc: no strings found in %s" % STRINGS_DIR)
