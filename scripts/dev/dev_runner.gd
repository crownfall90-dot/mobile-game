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
##   --screen=<имя>        открыть экран или попап Router с аргументами по умолчанию;
##                         без окна и без --shot — выйти через 30 кадров: RESULT: SCREEN <имя> ok|FAIL
##   --shot=путь.png@сек   сохранить скриншот через столько секунд (нужно окно, не headless)
##   --smoke               открыть по очереди все готовые экраны и попапы, потом сыграть первый
##                         уровень индекса как игрок: решение до победы и первый порядок из fails
##                         до поражения, каждый раз с окном итога и кнопкой «Дальше» / «Ещё раз»
##
## Итог уровня печатается строкой RESULT: WON stars=3 gold=22/22 или RESULT: LOST reason=enemy
## (плюс RESULT_JSON с --json), код выхода 0. Код 2 — RESULT: TIMEOUT (итога нет за 20 игровых
## секунд после последнего засова), 3 — RESULT: ERROR (уровень, засовы или экран не нашлись;
## экран из реестра, чей скрипт ещё не написан — Router открыл бы вместо него игру),
## 1 — smoke или --screen нашли ошибки. Без окна любой запуск заканчивается сам; в окне без --shot
## уровень без засовов по сценарию и --screen ждут человека без предела.
## Сохранение не пишется (Profile.volatile), звука нет, экрана загрузки нет.

const START_DELAY := 1.0
const INTERVAL := 1.5
const SETTLE_MIN := 0.6
const SETTLE_MAX := 4.0
const TIME_JITTER := 0.15
const AFTER_LAST := 20.0        # сколько игровых секунд ждать итога после последнего засова
const WALL_LIMIT_MS := 100000   # предел по часам для прогона уровня (вдобавок к кадрам)
const DIG_SPEED := 900.0         # скорость пальца в мазках "strokes", px/с
const SMOKE_SCREEN_FRAMES := 30
const SMOKE_POPUP_FRAMES := 20
const SMOKE_RESULT_WAIT := 2.0  # секунд после итога: окно итога успевает открыться и отыграть

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
	if flags.get("home_selfcheck", false):
		load("res://tools/test_home.gd").run()
		return
	_start_ms = Time.get_ticks_msec()
	var profile := get_node_or_null(^"/root/Profile")
	if profile:
		profile.set(&"volatile", true)
	if flags.has("home-stage"):
		for i in mini(int(flags["home-stage"]), 10):
			Profile.set_flag("home." + Home.TASKS[i].id)
	if flags.has("home-items"):
		for id in str(flags["home-items"]).split(",", false):
			Profile.grant(id)
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
	var scripted: bool = _flags.has("pins") or _flags.get("autoplay", false) or _flags.get("all_at_once", false)
	if scripted and order.is_empty():
		print("RESULT: ERROR no pins to pull")
		_quit(3)
		return
	_ticks = 0
	if order.is_empty():
		# ручная игра без таймаута; без окна играть некому — там обычный предел
		if DisplayServer.get_name() == "headless" and not _flags.has("shot"):
			_deadline = _secs(AFTER_LAST)
		return
	_quit_after_shot = false
	_play(order)


## Порядок засовов из флагов; пусто — играет человек.
func _order() -> PackedStringArray:
	if _flags.has("pins"):
		return _flags["pins"]
	var order := PackedStringArray()
	if _flags.get("all_at_once", false):
		for pin in _level.pins:
			order.append(pin.id)
		for id in _level.data.get("strokes", {}):
			order.append(str(id))
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
		await _act(order[i])
		if i == order.size() - 1:
			_level.actions_done()
		if all_at_once or i == order.size() - 1:
			continue
		if settle:
			await _settle()
		else:
			await _wait(interval)


## Ход сценария: засов по id или мазок пальцем из "strokes" уровня.
func _act(id: String) -> void:
	var strokes: Dictionary = _level.data.get("strokes", {})
	if _level.pin_by_id(id) == null and strokes.has(id):
		await _stroke(strokes[id])
	else:
		_pull(id)


## Ведёт палец по ломаной со скоростью DIG_SPEED px/с, копая по пути.
func _stroke(points: Array) -> void:
	print("dig ", points.size(), " pts")
	var prev := Vector2(points[0][0], points[0][1])
	_level.dig(prev, prev)
	for k in range(1, points.size()):
		var target := Vector2(points[k][0], points[k][1])
		while prev.distance_to(target) > 0.5 and not _done:
			await get_tree().physics_frame
			var next := prev.move_toward(target, DIG_SPEED / 60.0)
			_level.dig(prev, next)
			prev = next


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
	# без окна и без снимка смотреть некому: проверяем, что открылось без ошибок, и выходим
	var check := DisplayServer.get_name() == "headless" and not _flags.has("shot")
	var errors := ErrorCounter.new()
	if check:
		OS.add_logger(errors)
	var sn := StringName(screen_name)
	var is_screen := _registry(&"SCREENS").has(sn)
	if is_screen:
		router.call(&"go", sn, _screen_args(sn))
		await _router_idle(router)
		# вместо ненаписанного экрана Router открывает игру — это не «экран открылся»
		var shown: StringName = router.call(&"current")
		if shown != sn:
			print("RESULT: ERROR screen '%s' is not written yet (Router opened %s)" % [screen_name, shown])
			if check:
				OS.remove_logger(errors)
			_shot_pending = false   # снимок чужого экрана не нужен
			_quit(3)
			return
	else:
		# попап показываем поверх лаборатории (или того, что Router откроет вместо неё)
		router.call(&"go", &"hub", {})
		await _frames(SMOKE_SCREEN_FRAMES)
		if router.call(&"popup", sn, {}) == null:
			print("RESULT: ERROR no screen or popup '%s'" % screen_name)
			if check:
				OS.remove_logger(errors)
			_quit(3)
			return
	if not check:
		return
	await _frames(SMOKE_SCREEN_FRAMES)
	OS.remove_logger(errors)
	var ok := errors.count == 0
	print("RESULT: SCREEN %s %s" % [screen_name, "ok" if ok else "FAIL " + errors.last])
	_quit(0 if ok else 1)


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
	# окно итога с настоящими данными: победа по решению и поражение по первому из fails
	if router != null and screens.has(&"game") and ResourceLoader.exists(screens[&"game"]):
		for win in [true, false]:
			var ok: bool = await _smoke_level(router, errors, win)
			failed = failed or not ok
	if not missing.is_empty():
		print("SMOKE not written yet: ", ", ".join(missing))
	print("SMOKE: %s (%d opened, %d missing, %d errors)" % ["FAIL" if failed else "OK", opened, missing.size(), errors.count])
	OS.remove_logger(errors)
	_quit(1 if failed else 0)


## Первый уровень индекса как у игрока (с Profile и Economy, но без записи на диск):
## засовы по порядку, итог, окно итога, затем «Дальше» после победы или «Ещё раз» после
## поражения. true — дошли до конца без ошибок.
func _smoke_level(router: Node, errors: ErrorCounter, win: bool) -> bool:
	var what := "win" if win else "lose"
	var ids := Game.level_ids()
	if ids.is_empty():
		print("SMOKE level %s: FAIL no levels" % what)
		return false
	var before := errors.count
	# go() закрывает и попапы прошлого шага (окно итога)
	router.call(&"go", &"game", {"id": ids[0]})
	await _frames(SMOKE_SCREEN_FRAMES)
	var gs := router.call(&"current_screen") as GameScreen
	if gs == null or gs.level == null:
		print("SMOKE level %s: FAIL game screen did not open %s" % [what, ids[0]])
		return false
	var order := PackedStringArray()
	var fails: Array = gs.level.data.get("fails", [])
	var src: Variant = gs.level.data.get("solution", []) if win else (fails[0] if not fails.is_empty() else [])
	for id in src:
		order.append(str(id))
	if order.is_empty():
		print("SMOKE level %s: skipped (%s has no %s)" % [what, ids[0], "solution" if win else "fails"])
		return true
	var got: Array = []
	gs.level_finished.connect(func(res: Dictionary) -> void: got.append(res), CONNECT_ONE_SHOT)
	var level := gs.level
	await _wait(START_DELAY)
	for i in order.size():
		if i > 0:
			await _wait(INTERVAL)
		if not got.is_empty() or not is_instance_valid(level):
			break
		level.pull_pin(level.pin_by_id(order[i]))
	var limit := _ticks + _secs(AFTER_LAST)
	while got.is_empty() and _ticks < limit:
		await get_tree().physics_frame
	if got.is_empty():
		print("SMOKE level %s: FAIL %s %s did not finish" % [what, ids[0], ",".join(order)])
		return false
	var res: Dictionary = got[0]
	# окно итога появляется через GameScreen.RESULT_DELAY и анимируется
	await _wait(SMOKE_RESULT_WAIT)
	var action := &"_go_next" if win else &"restart"
	if is_instance_valid(gs) and gs.has_method(action):
		gs.call(action)
		await _frames(SMOKE_SCREEN_FRAMES)
	var won := bool(res.get("won", false))
	var outcome := "WON %d stars" % int(res.get("stars", 0)) if won else "LOST " + str(res.get("reason", ""))
	var ok: bool = errors.count == before and won == win
	var why := errors.last if errors.count != before else "expected a " + what
	print("SMOKE level %s: %s (%s %s: %s, then %s)" % [what, "ok" if ok else "FAIL " + why,
		ids[0], ",".join(order), outcome, action])
	return ok


## Ждёт конца перехода Router (затемнения), но не дольше 120 кадров: в окне под xvfb
## кадры медленные, и счёт кадров не говорит, успел ли экран смениться.
func _router_idle(router: Node) -> void:
	for i in 120:
		if not router.call(&"is_busy"):
			return
		await get_tree().process_frame


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
