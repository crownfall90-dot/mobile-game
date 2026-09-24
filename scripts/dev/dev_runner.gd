class_name DevRunner
extends Node
## Запуски для разработки и проверки уровней. Router.boot() отдаёт управление сюда,
## если после "--" в командной строке есть флаги (их разбирает Game.parse_flags):
##
##   --level=<id|номер>    уровень по id (levels/<id>.json, даже вне индекса) или по номеру в индексе с нуля
##   --file=<res-путь>     уровень из файла, например res://levels/test/t_grate.json
##   --autoplay            тянуть засовы по полю "solution"
##   --pins=a,b,c          тянуть засовы в этом порядке
##   --all-at-once         вытащить все засовы (или те, что в --pins) в одном кадре
##   --interval=<сек>      пауза между засовами, по умолчанию 1.5
##   --interval=settle     следующий засов, когда все тела уснули (но не дольше 4 с)
##   --jitter=<seed>       ±1 px к каждому телу и ±15% к паузам из этого seed; 0 — выкл.
##   --mods=golden         «Золотая лихорадка»: золото становится самоцветами
##   --json                напечатать итог строкой RESULT_JSON {...}
##   --screen=<имя>        открыть экран или попап Router с аргументами по умолчанию
##   --shot=путь.png@сек   сохранить скриншот через столько секунд (нужно окно, не headless)
##   --smoke               открыть по очереди все готовые экраны и попапы, сообщить об ошибках
##
## Итог уровня печатается строкой RESULT: WON stars=3 gold=22/22 или RESULT: LOST reason=enemy
## (плюс RESULT_JSON с --json), код выхода 0. Код 2 — таймаут, 3 — уровень или экран
## не открылся, 1 — smoke нашёл ошибки. Сохранение не пишется (Profile.volatile), звука нет,
## экрана загрузки нет.

const START_DELAY := 1.0
const INTERVAL := 1.5
const SETTLE_MIN := 0.6
const SETTLE_MAX := 4.0
const TIME_JITTER := 0.15
const AFTER_LAST := 20.0        # сколько игровых секунд ждать итога после последнего засова
const WALL_LIMIT_MS := 100000   # предел по часам: запуск никогда не виснет
const SMOKE_SCREEN_FRAMES := 30
const SMOKE_POPUP_FRAMES := 20

var _flags: Dictionary = {}
var _screen: GameScreen
var _level: Level
var _ticks := 0                 # физические кадры с момента открытия уровня
var _deadline := -1             # кадр, после которого запуск считается зависшим
var _start_ms := 0
var _done := false
var _shot_pending := false
var _quit_after_shot := true
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func run(flags: Dictionary) -> void:
	_flags = flags
	_start_ms = Time.get_ticks_msec()
	var profile := get_node_or_null(^"/root/Profile")
	if profile:
		profile.set(&"volatile", true)
	AudioServer.set_bus_mute(0, true)
	var jitter := int(flags.get("jitter", 0))
	_rng.seed = jitter
	if flags.has("shot"):
		_take_shot(str(flags["shot"]))
	if flags.get("smoke", false):
		_quit_after_shot = false
		_smoke()
	elif flags.has("screen"):
		_open_screen(str(flags["screen"]))
	else:
		_run_level()


func _physics_process(_delta: float) -> void:
	_ticks += 1


func _process(_delta: float) -> void:
	if _done or _deadline < 0:
		return
	if _ticks > _deadline or Time.get_ticks_msec() - _start_ms > WALL_LIMIT_MS:
		_done = true
		_report({"won": false, "reason": "timeout", "stars": 0, "pieces": 0, "pieces_total": 0, "relic": false})
		print("RESULT: TIMEOUT")
		_quit(2)


# --- уровень -----------------------------------------------------------------

func _run_level() -> void:
	var args := {"dev": true, "mods": _flags.get("mods", {}), "jitter": int(_flags.get("jitter", 0))}
	if _flags.has("file"):
		args["file"] = str(_flags["file"])
	else:
		args["id"] = _resolve_level(str(_flags.get("level", "")))
	_screen = GameScreen.new()
	# как под Router: экран встаёт на паузу вместе с деревом, сам DevRunner — нет
	_screen.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_screen)
	_screen.level_finished.connect(_on_finished)
	_screen.open(args)
	_level = _screen.level
	if _level == null:
		print("RESULT: ERROR level '%s' not loaded" % args.get("file", args.get("id", "")))
		_quit(3)
		return
	var order := _order()
	if order.is_empty():
		# ручная игра: без засовов по сценарию и без таймаута
		return
	_quit_after_shot = false
	_ticks = 0
	_play(order)


## Порядок засовов из флагов; пусто — играет человек.
func _order() -> PackedStringArray:
	if _flags.has("pins"):
		return _flags["pins"]
	var order := PackedStringArray()
	if _flags.get("all_at_once", false):
		for pin in _level.pins:
			order.append(pin.id)
	elif _flags.get("autoplay", false):
		for id in _level.data.get("solution", []):
			order.append(str(id))
		if order.is_empty():
			push_error("DevRunner: level has no solution")
	return order


func _play(order: PackedStringArray) -> void:
	var all_at_once := bool(_flags.get("all_at_once", false))
	var settle := str(_flags.get("interval", "")) == "settle"
	var interval := float(_flags.get("interval", INTERVAL)) if not settle else INTERVAL
	# предел: все паузы с запасом плюс время на развязку
	_deadline = _secs(START_DELAY * 2.0 + order.size() * (SETTLE_MAX if settle else interval * 1.2) + AFTER_LAST)
	if settle:
		await _settle()
	else:
		await _wait(START_DELAY)
	for i in order.size():
		if _done:
			return
		_pull(order[i])
		if all_at_once or i == order.size() - 1:
			continue
		if settle:
			await _settle()
		else:
			await _wait(interval)


func _pull(id: String) -> void:
	var pin := _level.pin_by_id(id)
	if pin == null:
		push_error("DevRunner: no pin '%s'" % id)
		return
	print("pull ", id)
	_level.pull_pin(pin)


## Пауза в физических кадрах: одинаково на любом компьютере с --fixed-fps.
func _wait(sec: float) -> void:
	var until := _ticks + _secs(_vary(sec))
	while _ticks < until and not _done:
		await get_tree().physics_frame


## Ждёт, пока все тела уснут (не меньше SETTLE_MIN и не больше SETTLE_MAX).
func _settle() -> void:
	var start := _ticks
	var min_t := _secs(_vary(SETTLE_MIN))
	var max_t := _secs(SETTLE_MAX)
	while not _done:
		await get_tree().physics_frame
		var n := _ticks - start
		if n >= max_t or (n >= min_t and _all_asleep()):
			return


func _all_asleep() -> bool:
	for item in _level.items:
		if not item.sleeping:
			return false
	for e in _level.enemies:
		if e.alive and not e.sleeping:
			return false
	return true


func _vary(sec: float) -> float:
	if int(_flags.get("jitter", 0)) == 0:
		return sec
	return sec * (1.0 + _rng.randf_range(-TIME_JITTER, TIME_JITTER))


func _secs(sec: float) -> int:
	return roundi(sec * Engine.physics_ticks_per_second)


func _on_finished(result: Dictionary) -> void:
	if _done:
		return
	_done = true
	_report(result)
	if result.get("won", false):
		print("RESULT: WON stars=%d gold=%d/%d" % [result["stars"], result["pieces"], result["pieces_total"]])
	else:
		print("RESULT: LOST reason=%s" % result.get("reason", ""))
	if _deadline >= 0:
		_quit(0)


func _report(result: Dictionary) -> void:
	if not _flags.get("json", false):
		return
	var order: Array = Array(_level.pulled_ids()) if _level else []
	var out := {
		"level": _level.data.get("id", "") if _level else str(_flags.get("level", "")),
		"order": order,
		"won": bool(result.get("won", false)),
		"reason": str(result.get("reason", "")),
		"stars": int(result.get("stars", 0)),
		"pieces": int(result.get("pieces", 0)),
		"total": int(result.get("pieces_total", 0)),
		"relic": bool(result.get("relic", false)),
		"t": snappedf(float(_ticks) / Engine.physics_ticks_per_second, 0.01),
	}
	print("RESULT_JSON ", JSON.stringify(out, "", false))


func _resolve_level(v: String) -> String:
	var ids := Game.level_ids()
	if v == "":
		var profile := get_node_or_null(^"/root/Profile")
		if profile and profile.has_method(&"current_level_id"):
			return str(profile.call(&"current_level_id"))
		return ids[0] if not ids.is_empty() else ""
	if Game.has_level(v) or FileAccess.file_exists(Game.LEVEL_DIR + v + ".json"):
		return v
	if v.is_valid_int() and not ids.is_empty():
		return ids[clampi(v.to_int(), 0, ids.size() - 1)]
	return v


# --- экраны, скриншоты, smoke --------------------------------------------------

func _open_screen(screen_name: String) -> void:
	var router := get_node_or_null(^"/root/Router")
	if router == null:
		print("RESULT: ERROR no Router")
		_quit(3)
		return
	var sn := StringName(screen_name)
	if _registry(&"SCREENS").has(sn):
		router.call(&"go", sn, _screen_args(sn))
		return
	# попап показываем поверх лаборатории (или того, что Router откроет вместо неё)
	router.call(&"go", &"hub", {})
	await _frames(SMOKE_SCREEN_FRAMES)
	if router.call(&"popup", sn, {}) == null:
		print("RESULT: ERROR no screen or popup '%s'" % screen_name)
		_quit(3)


func _screen_args(sn: StringName) -> Dictionary:
	if sn == &"game":
		return {"id": _resolve_level(str(_flags.get("level", ""))), "mods": _flags.get("mods", {})}
	return {}


func _registry(key: StringName) -> Dictionary:
	var router := get_node_or_null(^"/root/Router")
	if router == null or router.get_script() == null:
		return {}
	var v: Variant = router.get_script().get_script_constant_map().get(key, {})
	return v if v is Dictionary else {}


func _smoke() -> void:
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var router := get_node_or_null(^"/root/Router")
	var failed := router == null
	var opened := 0
	var missing := PackedStringArray()
	var screens := _registry(&"SCREENS")
	var popups := _registry(&"POPUPS")
	for sn in screens:
		if not ResourceLoader.exists(screens[sn]):
			missing.append(String(sn))
			continue
		var before := errors.count
		router.call(&"go", sn, _screen_args(sn))
		await _frames(SMOKE_SCREEN_FRAMES)
		var ok: bool = router.call(&"current") == sn and errors.count == before
		print("SMOKE screen %s: %s" % [sn, "ok" if ok else "FAIL " + errors.last])
		failed = failed or not ok
		opened += 1
	for pn in popups:
		if not ResourceLoader.exists(popups[pn]):
			missing.append(String(pn))
			continue
		var before := errors.count
		var p: Node = router.call(&"popup", pn, {})
		await _frames(SMOKE_POPUP_FRAMES)
		var ok := p != null and errors.count == before
		if is_instance_valid(p):
			if p.has_method(&"close"):
				p.call(&"close")
			else:
				p.queue_free()
			await _frames(SMOKE_POPUP_FRAMES)
		ok = ok and errors.count == before
		print("SMOKE popup %s: %s" % [pn, "ok" if ok else "FAIL " + errors.last])
		failed = failed or not ok
		opened += 1
	if not missing.is_empty():
		print("SMOKE not written yet: ", ", ".join(missing))
	print("SMOKE: %s (%d opened, %d missing, %d errors)" % ["FAIL" if failed else "OK", opened, missing.size(), errors.count])
	OS.remove_logger(errors)
	_quit(1 if failed else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _take_shot(spec: String) -> void:
	_shot_pending = true
	var path := spec.get_slice("@", 0)
	var delay := spec.get_slice("@", 1).to_float() if spec.contains("@") else 2.5
	await get_tree().create_timer(delay, true, false, true).timeout
	if DisplayServer.get_name() == "headless":
		push_warning("DevRunner: no screenshots in headless mode")
	else:
		await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(path) == OK:
			print("screenshot saved: ", path)
		else:
			push_error("DevRunner: cannot save %s" % path)
	_shot_pending = false
	if _quit_after_shot:
		get_tree().quit(0)


func _quit(code: int) -> void:
	while _shot_pending:
		await get_tree().process_frame
	get_tree().quit(code)


## Считает ошибки движка и скриптов, пока идёт smoke.
class ErrorCounter extends Logger:
	var count := 0
	var last := ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		count += 1
		last = "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]

	func _log_message(_message: String, _error: bool) -> void:
		pass
