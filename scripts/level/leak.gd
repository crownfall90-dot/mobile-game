extends Node2D
## «Лови капли»: над потолком кухни течёт труба. Из дыр падают капли; ведро внизу ездит за
## пальцем и ловит их, промахи уходят в дыру к кухне (у уровня — предел промахов). Дыру
## заклеивают лентой: подержать на ней палец `hold` секунд. Пока палец держит ленту, ведро стоит,
## а вода из этой дыры ещё капает — сначала подставь ведро. Мышь бегает по трубе и прогрызает
## новые дыры; пока она грызёт или бежит, её можно спугнуть тапом. Спугнутая убегает и через
## `back` секунд возвращается, после `scares` испугов уходит насовсем.
## Уровень: "leak": {pipe_y, hold, holes: [{id, x, every, open, grow}], mouse: {speed, gnaw, rest,
## back, scares, from}}. Часы механики идут с первого касания игрока (или хода робота).

const MOUSE_TEX := "res://art/act1/enemies/mouse.png"
const HIT := 64.0           # радиус тапа по дыре
const MOUSE_HIT := 72.0
const MOUSE_SIZE := 96.0
const TAPE := Color("e6d6a8")
const TAPE_DARK := Color("9c8a5c")
const DROP := Color("5ec8f2")
const GNAW := Color("4a3222")
const OFF_LEFT := 40.0
const OFF_RIGHT := 690.0

var pipe_y := 220.0         # нижний край трубы: отсюда растут капли
var pipe_top := 186.0       # верх трубы: по нему бегает мышь
var hold := 0.6
var holes: Array[Dictionary] = []
var started := false
var misses := 0
var miss_limit := 3
var spawn: Callable         # func(pos: Vector2) — уровень создаёт каплю
var changed: Callable       # func(at: Vector2) — дыру заклеили (at) или мышь ушла (ZERO)
var auto := 3.0             # не трогают экран — протечка начнётся сама

var _pressing := ""
var _t := 0.0
var _idle := 0.0
var _hint_t := 0.0            # подсказка: первая открытая дыра светится
var _cfg: Dictionary = {}
var _m_state := "wait"      # wait / run / gnaw / flee / leave / gone
var _m_x := OFF_RIGHT
var _m_hole := -1
var _m_timer := 0.0
var _m_scares := 0
var _m_dir := -1.0
var _m_tex: Texture2D


func setup(cfg: Dictionary) -> void:
	pipe_y = float(cfg.get("pipe_y", 220.0))
	pipe_top = float(cfg.get("pipe_top", pipe_y - 68.0))
	hold = float(cfg.get("hold", 0.6))
	auto = float(cfg.get("auto", 3.0))
	for h in cfg.get("holes", []):
		holes.append({"id": str(h["id"]), "x": float(h["x"]), "every": float(h.get("every", 1.2)),
			"state": "open" if h.get("open", false) else "hidden", "grow": float(h.get("grow", 0.0)),
			"press": 0.0, "flash": 0.0})
	_cfg = cfg.get("mouse", {})
	if _cfg.is_empty():
		_m_state = "gone"
	else:
		_m_x = OFF_LEFT if str(_cfg.get("from", "right")) == "left" else OFF_RIGHT
		_m_timer = float(_cfg.get("rest", 1.5))
	if ResourceLoader.exists(MOUSE_TEX):
		_m_tex = load(MOUSE_TEX)


## Сколько дыр уже не страшны: заклеены или так и не прогрызены (мышь ушла насовсем).
func done_count() -> int:
	var n := 0
	for h in holes:
		if h["state"] == "patched" or (h["state"] == "hidden" and _m_state == "gone"):
			n += 1
	return n


## Всё спокойно: мыши нет, открытых и прогрызаемых дыр нет.
func calm() -> bool:
	return started and _m_state == "gone" and done_count() == holes.size()


func start() -> void:
	started = true


## Палец коснулся: спугнуть мышь или начать клеить дыру. true — касание съедено.
func press(p: Vector2) -> bool:
	start()
	if _mouse_visible() and p.distance_to(_mouse_pos()) < MOUSE_HIT:
		scare()
		return true
	var best := ""
	var best_d := HIT
	for h in holes:
		if h["state"] != "open":
			continue
		var d := p.distance_to(Vector2(h["x"], pipe_y))
		if d < best_d:
			best = h["id"]
			best_d = d
	_pressing = best
	return best != ""


func press_hole(id: String) -> void:
	start()
	_pressing = id


## Кнопка подсказки: подсветить дыру, которую пора клеить.
func hint() -> void:
	_hint_t = 3.0


func release() -> void:
	_pressing = ""


func pressing() -> bool:
	return _pressing != ""


func scare() -> void:
	start()
	if not _mouse_visible() or _m_state == "flee" or _m_state == "leave":
		return
	_m_scares += 1
	if _m_state == "gnaw" and _m_hole >= 0:
		holes[_m_hole]["state"] = "hidden"
	_m_hole = -1
	_m_dir = -1.0 if _m_x - OFF_LEFT < OFF_RIGHT - _m_x else 1.0
	_m_state = "flee"


func step(delta: float) -> void:
	_t += delta
	_hint_t = maxf(0.0, _hint_t - delta)
	queue_redraw()
	if not started:
		_idle += delta
		if _idle < auto:
			return
		start()
	for h in holes:
		h["flash"] = maxf(0.0, float(h["flash"]) - delta * 2.0)
		if h["state"] != "open":
			continue
		if _pressing == h["id"]:
			h["press"] = float(h["press"]) + delta
			if float(h["press"]) >= hold:
				h["state"] = "patched"
				h["flash"] = 1.0
				_pressing = ""
				changed.call(Vector2(float(h["x"]), pipe_y))
		else:
			h["press"] = maxf(0.0, float(h["press"]) - delta * 3.0)
		if h["state"] == "open":
			h["grow"] = float(h["grow"]) + delta / float(h["every"])
			if float(h["grow"]) >= 1.0:
				h["grow"] = 0.0
				spawn.call(Vector2(float(h["x"]), pipe_y + 10.0))
	_step_mouse(delta)


func _step_mouse(delta: float) -> void:
	var speed := float(_cfg.get("speed", 260.0))
	match _m_state:
		"wait":
			_m_timer -= delta
			if _m_timer <= 0.0:
				_m_hole = _next_hole()
				if _m_hole < 0:
					_m_state = "gone"
					changed.call(Vector2.ZERO)
				else:
					_m_state = "run"
		"run":
			var tx := float(holes[_m_hole]["x"])
			_m_dir = signf(tx - _m_x) if absf(tx - _m_x) > 0.5 else _m_dir
			_m_x = move_toward(_m_x, tx, speed * delta)
			if absf(_m_x - tx) < 0.5:
				_m_state = "gnaw"
				_m_timer = float(_cfg.get("gnaw", 1.8))
				holes[_m_hole]["state"] = "gnaw"
		"gnaw":
			_m_timer -= delta
			if _m_timer <= 0.0:
				var h: Dictionary = holes[_m_hole]
				h["state"] = "open"
				h["grow"] = 0.35
				h["flash"] = 1.0
				_m_hole = _next_hole()
				_m_state = "run" if _m_hole >= 0 else "leave"
				if _m_state == "leave":
					_m_dir = -1.0 if _m_x - OFF_LEFT < OFF_RIGHT - _m_x else 1.0
		"flee", "leave":
			_m_x += _m_dir * speed * (2.2 if _m_state == "flee" else 1.3) * delta
			if _m_x < OFF_LEFT or _m_x > OFF_RIGHT:
				if _m_state == "leave" or _m_scares >= int(_cfg.get("scares", 2)):
					_m_state = "gone"
					changed.call(Vector2.ZERO)
				else:
					_m_state = "wait"
					_m_timer = float(_cfg.get("back", 2.5))


func _next_hole() -> int:
	for i in holes.size():
		if holes[i]["state"] == "hidden":
			return i
	return -1


func _mouse_visible() -> bool:
	return _m_state in ["run", "gnaw", "flee", "leave"]


func _mouse_pos() -> Vector2:
	return Vector2(_m_x, pipe_top - MOUSE_SIZE * 0.45)


func _draw() -> void:
	var hinted := _hint_t <= 0.0
	for h in holes:
		var c := Vector2(float(h["x"]), pipe_y)
		match h["state"]:
			"gnaw":
				# следы зубов мигают: здесь скоро будет дыра
				var a := 0.45 + 0.45 * sin(_t * 12.0)
				for i in 3:
					draw_arc(c + Vector2(-10 + i * 10, -8), 6.0, 0.2, PI - 0.2, 6, Color(GNAW, a), 3.0)
				draw_circle(c + Vector2(sin(_t * 17.0) * 14.0, 6.0 + fmod(_t * 60.0, 30.0)), 2.5, Color(GNAW, 0.8))
			"open":
				draw_circle(c, 11.0, Color(0.1, 0.12, 0.14, 0.85))
				var g := float(h["grow"])
				draw_circle(c + Vector2(0, 6.0 + g * 8.0), 3.0 + g * 7.0, DROP)
				draw_circle(c + Vector2(-2.0, 4.0 + g * 7.0), 1.5 + g * 2.0, Color(1, 1, 1, 0.7))
				# подсказка «держи»: пульсирующее кольцо; при нажатии — лента заполняет круг
				var ring := 30.0 + 4.0 * sin(_t * 5.0)
				draw_arc(c, ring, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 3.0, true)
				if not hinted:
					hinted = true
					var ph := fmod(_t * 1.4, 1.0)
					draw_arc(c, 34.0 + ph * 40.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.3, 1.0 - ph), 5.0, true)
				if float(h["press"]) > 0.0:
					draw_arc(c, 30.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(h["press"]) / hold, 0.0, 1.0), 32, TAPE, 9.0, true)
			"patched":
				var k := 1.0 + float(h["flash"]) * 0.4
				draw_set_transform(c, 0.35, Vector2(k, k))
				draw_rect(Rect2(-30, -11, 60, 22), TAPE_DARK)
				draw_rect(Rect2(-28, -9, 56, 18), TAPE)
				draw_set_transform(c, -0.35, Vector2(k, k))
				draw_rect(Rect2(-30, -11, 60, 22), TAPE_DARK)
				draw_rect(Rect2(-28, -9, 56, 18), TAPE)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_mouse()


func _draw_mouse() -> void:
	if not _mouse_visible():
		return
	var p := _mouse_pos()
	var bob := sin(_t * (30.0 if _m_state == "gnaw" else 18.0)) * (3.0 if _m_state == "gnaw" else 2.0)
	var s := MOUSE_SIZE
	# художник рисует лицом влево: бегущую вправо отражаем
	if _m_tex:
		# отражаем масштабом, а не отрицательной шириной прямоугольника (та рисуется со сдвигом)
		draw_set_transform(p, 0.0, Vector2(-1.0 if _m_dir > 0.0 else 1.0, 1.0))
		draw_texture_rect(_m_tex, Rect2(-s * 0.5, -s * 0.55 + bob, s, s), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(p, s * 0.3, Color("c9a27a"))
		draw_circle(p + Vector2(-s * 0.2 * -_m_dir, -s * 0.25), s * 0.14, Color("e8b7a8"))
