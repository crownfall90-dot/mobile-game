class_name GameScreen
extends Control
## Экран уровня: фон, мир уровня под камерой, HUD, перезапуск и итог.
##
## open({id, mods, dev, file, jitter}):
##   id     — уровень из levels/<id>.json; без id и file — текущий уровень игрока;
##   mods   — {"golden": true} для «Золотой лихорадки»;
##   dev    — запуск DevRunner: без Profile, Economy и обучения;
##   file   — путь к уровню вне индекса (levels/test/*.json), тоже без прогресса;
##   jitter — Level.jitter_seed для проверок.

signal level_ready(level: Level)
signal level_finished(result: Dictionary)

const BG_SHADER := preload("res://shaders/background.gdshader")
const RESULT_DELAY := 1.0   # героиня празднует или пугается, потом окно итога
const LOSE_REASONS: PackedStringArray = ["lava", "acid", "enemy", "stuck", "water", "blocked"]

var _dug_ms := 0
var level: Level
var level_id := ""
var mods: Dictionary = {}
var dev := false

var _file := ""
var _jitter := 0
var _data: Dictionary = {}
var _world: Node2D
var _camera: Camera2D
var _hud: Hud
var _attempt := 0
var _result_tween: Tween
var _pause: Node
var _repair := ""
var _result_recorded := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# касания должны доходить до Level._unhandled_input
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	bg.material = mat
	bg_layer.add_child(bg)

	_world = Node2D.new()
	add_child(_world)
	# Уровень всегда живёт в координатах 720x1280; под экран его подгоняет камера,
	# а не масштаб узлов, чтобы не трогать физику.
	_camera = Camera2D.new()
	_camera.position = Level.DESIGN_SIZE * 0.5
	add_child(_camera)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_hud = Hud.new()
	ui.add_child(_hud)
	_hud.restart_requested.connect(restart)
	_hud.next_requested.connect(_go_next)
	_hud.home_requested.connect(func() -> void: Router.go(&"hub", {"repaired": _repair}))
	_hud.pause_requested.connect(func() -> void: _open_pause(false))
	_hud.hint_requested.connect(_hint)
	_hud.rotate_requested.connect(func(dir: int) -> void:
		if level and level.rotate_world(dir):
			_hud.hint_rotate(0))

	get_viewport().size_changed.connect(_layout)
	_layout()


func open(args: Dictionary) -> void:
	level_id = str(args.get("id", ""))
	var m: Variant = args.get("mods", {})
	mods = m if m is Dictionary else {}
	dev = bool(args.get("dev", false))
	_file = str(args.get("file", ""))
	_jitter = int(args.get("jitter", 0))
	if level_id == "" and _file == "":
		level_id = _default_level()
	_attempt = 0
	if not is_node_ready():
		await ready
	restart()


func restart() -> void:
	_repair = ""
	_result_recorded = false
	if _result_tween:
		_result_tween.kill()
	if level:
		_world.remove_child(level)
		level.queue_free()
		level = null
	_camera.offset = Vector2.ZERO
	_data = Game.load_level_file(_file, mods) if _file != "" else Game.load_level(level_id, mods)
	if _data.is_empty():
		_hud.set_level(Loc.t("level.no_level"), "")
		return
	level_id = str(_data["id"])
	_attempt += 1
	level = Level.new()
	level.camera = null if _setting(&"low_fx", false) else _camera
	level.view_camera = _camera
	level.jitter_seed = _jitter
	_dress_hero(level)
	_world.add_child(level)
	level.build(_data)
	level.gold_changed.connect(_hud.set_gold)
	level.pin_pulled.connect(_on_pin_pulled)
	level.dug.connect(_on_dug)
	level.switched.connect(func(_id: String) -> void:
		Sfx.play(&"pin")
		Sfx.haptic(15)
		_hud.hide_hint())
	level.won.connect(_on_won)
	level.lost.connect(_on_lost)
	_hud.set_level(_title(), Loc.pick(_data.get("hint", "")))
	_layout()
	_hud.set_goal_kind(str(_data.get("receiver", {}).get("kind", "gold")))
	_hud.show_rotate(level.can_rotate())
	if level.putty:
		_hud.set_ink(level.putty.ink_left, level.putty.ink)
		level.putty.ink_changed.connect(_hud.set_ink)
	else:
		_hud.set_ink(0.0, 0.0)
	_hud.hint_rotate(0)
	if _attempt <= 1:
		_hud.show_place(LevelSkin.place(str(_data.get("theme", ""))))
	_world.modulate.a = 0.0
	create_tween().tween_property(_world, "modulate:a", 1.0, 0.35)
	# обучение «рука»: показать первый засов решения
	var sol: Array = _data.get("solution", [])
	if not dev and str(_data.get("tutorial", "")) == "hand" and not sol.is_empty():
		if level.has_strokes():
			level.show_dig_hint(sol)
		else:
			level.set_hint_pin(str(sol[0]))
	level_ready.emit(level)


## Android «назад»: пауза (пока её попапа нет — перезапуск). true — обработано.
func on_back() -> bool:
	if not is_instance_valid(_pause):
		_open_pause(true)
	return true


## Приложение свернули: ставим на паузу посреди попытки.
func on_app_pause() -> void:
	if level == null or level.finished or is_instance_valid(_pause):
		return
	_open_pause(not level.pulled_ids().is_empty())


func _open_pause(restart_fallback: bool) -> void:
	var router := get_node_or_null(^"/root/Router")
	_pause = router.call(&"popup", &"pause", {"level_id": level_id}) if router else null
	if _pause == null and restart_fallback:
		restart()


func _on_pin_pulled(_pin: Pin) -> void:
	Sfx.play(&"pin")
	Sfx.haptic(15)
	_hud.hide_hint()
	if str(_data.get("tutorial", "")) == "hand":
		level.set_hint_pin("")


## Копание: мягкий шорох (стук камешка) и лёгкая вибрация не чаще раза в 0,12 с.
func _on_dug(_pos: Vector2) -> void:
	_hud.hide_hint()
	var now := Time.get_ticks_msec()
	if now - _dug_ms > 120:
		_dug_ms = now
		Sfx.play(&"stone_tock")
		Sfx.haptic(6)


func _on_won(stars: int) -> void:
	if _result_recorded:
		return
	_result_recorded = true
	var res := level.result()
	res["first_try"] = _attempt == 1 and (not _tracks_progress() or Profile.fails(level_id) == 0)
	if _tracks_progress():
		res.merge(Profile.record_result(level_id, stars), true)
		# разбивка награды пригодится окну итога
		res["reward"] = Economy.level_reward(level_id, res, mods)
		Profile.reset_fails(level_id)
		_repair = Home.finish(level_id, true)
	Sfx.play(&"win")
	level_finished.emit(res)
	var win_text := Loc.t("level.gold", [res["pieces"], res["pieces_total"]])
	if _data.has("receiver"):
		var thing := str(Home.task_for_level(level_id).get("name", "")).to_lower()
		win_text = ("Ремонт: %s — готово!\nВернёмся домой и посмотрим." % thing) if thing != "" \
			else "Вернёмся домой и посмотрим."
		_hud.show_place("Починено!")
	elif _data.get("family", false):
		win_text = "Мама и дочка спасены!\nВернёмся домой и увидим результат."
	_show_result_later(true, stars, win_text)


func _on_lost(reason: String) -> void:
	if _result_recorded:
		return
	_result_recorded = true
	Sfx.play(&"lose")
	var res := level.result()
	res["first_try"] = false
	if _tracks_progress():
		Profile.add_fail(level_id)
		Economy.level_lost(level_id, reason)
	level_finished.emit(res)
	_show_result_later(false, 0, _item_lose_text(res) if _data.has("receiver") else Loc.t(lose_key(res)))


## Ключ строки причины поражения по result(). «Застряли» при собранном золоте значит,
## что победе мешает живой враг — это отдельная строка, а не «Не хватило золота».
static func lose_key(res: Dictionary) -> String:
	var reason := str(res.get("reason", ""))
	if reason == "stuck" and int(res.get("pieces", 0)) >= int(res.get("needed", 0)):
		return "lose.enemy_alive"
	return "lose." + reason if LOSE_REASONS.has(reason) else "lose.other"


## Почему не вышло починить вещь: что испортило приёмник или чего не хватило.
## Нарушитель в тексте поражения: [кто, что сделал с %s-местом].
const ENEMY_TEXT := {
	"slime": ["Слизень", "забил %s"], "grime": ["Засор", "ушёл в %s и всё забил"],
	"mold": ["Плесень", "проросла в %s"], "cockroach": ["Таракан", "залез в %s"],
	"rat": ["Крыса", "пролезла в %s"], "mouse": ["Мышь", "пролезла в %s"],
	"spider": ["Паук", "затянул %s паутиной"], "moth": ["Моль", "залетела в %s"],
}


func _item_lose_text(res: Dictionary) -> String:
	var recv: Dictionary = _data.get("receiver", {})
	var where: String = str(recv.get("where", {"drain": "трубу", "bucket": "ведро", "toolbox": "ящик",
		"burner": "конфорку", "hole": "пол", "sewer": "трубу"}.get(str(recv.get("look", "")), "вещь")))
	var enemies: Array = _data.get("enemies", [])
	var who: Array = ENEMY_TEXT.get(str(enemies[0].get("kind", "slime")) if not enemies.is_empty() else "slime", ENEMY_TEXT["slime"])
	match str(res.get("reason", "")):
		"lava":
			return "Огонь прожёг %s" % where
		"acid":
			return "Средство разъело %s" % where
		"water":
			return "Вода залила %s" % where
		"socket":
			return "Вода попала в розетку — искры!"
		"sill":
			return "Дождь залил подоконник"
		"enemy":
			return "%s %s" % [who[0], who[1] % where]
		"stuck":
			if int(res.get("pieces", 0)) >= int(res.get("needed", 0)):
				return "%s ещё мешает" % who[0]
			return {"water": "Воды не хватило", "stone": "Дыру не заделали", "lava": "Огонь не дошёл",
				"gold": "Не хватило деталей"}.get(str(recv.get("kind", "gold")), "Не получилось")
	return "Попробуй по-другому"


func _show_result_later(won: bool, stars: int, text: String) -> void:
	_result_tween = create_tween()
	_result_tween.tween_interval(RESULT_DELAY)
	var title := "Починено!" if won and _data.has("receiver") else ""
	_result_tween.tween_callback(_hud.show_result.bind(won, stars, text, title))


func _go_next() -> void:
	if not dev and not Home.task_for_level(level_id).is_empty():
		Router.go(&"hub", {"repaired": _repair})
		return
	var next := ""
	if _file == "" and mods.is_empty():
		next = Game.next_level_after(level_id)
	if next != "":
		open({"id": next, "dev": dev})
		return
	var router := get_node_or_null(^"/root/Router")
	if router and not dev:
		router.call(&"go", &"hub")
	else:
		restart()


func _title() -> String:
	var task := Home.task_for_level(level_id)
	if not task.is_empty():
		return "Починить: " + task.name
	var title := Loc.pick(_data.get("title", ""))
	var label := Game.level_label(level_id)
	if label == "":
		return title
	if title == "":
		return Loc.t("common.level", [label])
	return "%s · %s" % [label, title]


## Прогресс пишется только в обычной игре по уровню из индекса.
func _tracks_progress() -> bool:
	return not dev and _file == "" and Game.has_level(level_id)


func _default_level() -> String:
	var profile := get_node_or_null(^"/root/Profile")
	if profile and profile.has_method(&"current_level_id"):
		var id := str(profile.call(&"current_level_id"))
		if id != "":
			return id
	var ids := Game.level_ids()
	return ids[0] if not ids.is_empty() else ""


## Наряд и питомец героини из профиля (если Hero это уже умеет).
func _dress_hero(lv: Level) -> void:
	var profile := get_node_or_null(^"/root/Profile")
	var economy := get_node_or_null(^"/root/Economy")
	if profile == null or not profile.has_method(&"equipped"):
		return
	var outfit_id := str(profile.call(&"equipped", &"outfit"))
	if economy and economy.has_method(&"outfit") and outfit_id != "":
		var o: Variant = economy.call(&"outfit", outfit_id)
		if o is Dictionary:
			lv.hero_outfit = o
	lv.familiar_kind = StringName(str(profile.call(&"equipped", &"familiar")))


func _setting(key: StringName, fallback: Variant) -> Variant:
	var profile := get_node_or_null(^"/root/Profile")
	if profile and profile.has_method(&"setting"):
		var v: Variant = profile.call(&"setting", key)
		return fallback if v == null else v
	return fallback


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := minf(vs.x / Level.DESIGN_SIZE.x, vs.y / Level.DESIGN_SIZE.y)
	_camera.zoom = Vector2(s, s)
	# отступ под вырез камеры / статус-бар
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y > 0:
		_hud.set_safe_top(maxf(0.0, safe.position.y) * vs.y / win.y)
	if _data.has("tower"):
		_hud.place_hint((_content_top() - _camera.position.y) * s + vs.y * 0.5)


## Верх того, что есть на поле (стенки, засовы, жидкости), в координатах уровня.
func _content_top() -> float:
	var top := INF
	for w: Dictionary in _data.get("walls", []):
		for p: Array in w.get("poly", []):
			top = minf(top, float(p[1]))
	for pin: Dictionary in _data.get("pins", []):
		top = minf(top, float(pin["from"][1]) - 14.0)
	for f: Dictionary in _data.get("fills", []):
		top = minf(top, float(f["rect"][1]))
	return top if top < INF else float(_data["tower"]["rect"][1])


func _hint() -> void:
	if level == null or level.finished:
		return
	if level.has_strokes():
		# копать можно где угодно: показываем весь путь решения, засовы — кольцом
		var order: Array = Game.winning_orders(level_id)[0] if not Game.winning_orders(level_id).is_empty() else []
		level.show_dig_hint(order)
		for id in order:
			if level.pin_by_id(str(id)) and not level.pin_by_id(str(id)).pulled:
				level.set_hint_pin(str(id))
				break
		return
	var pulled := level.pulled_ids()
	for order in Game.winning_orders(level_id):
		var matches := true
		for i in pulled.size():
			if i >= order.size() or pulled[i] != str(order[i]):
				matches = false
		if matches and pulled.size() < order.size():
			var next := str(order[pulled.size()])
			if next == "cw" or next == "ccw":
				_hud.hint_rotate(1 if next == "cw" else -1)
			else:
				level.set_hint_pin(next)
			return
	Router.toast("Попробуй начать заново: порядок уже изменился")
