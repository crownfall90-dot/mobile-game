extends Node2D
## «Вантуз»: в сифоне под раковиной засор. Тап — качнуть вантуз: если он успел расправиться
## (кольцо заполнилось), волна толкает засор по трубе на `push` px. Качнул раньше — вода
## выплёскивается из раковины (после `splashes` — проигрыш). На подъёме трубы засор сам сползает
## назад, поэтому качать надо ровно, в ритм. Кран подкапывает: раковина наполняется и через
## `overflow` секунд переливается (проигрыш). Засор дошёл до конца трубы — победа.
## Уровень: "plunger": {path: [[x, y], ...], start, push, slide, recover, splashes, overflow,
## sink: [x, y, w, h], cup: [x, y]}. Часы идут с первого тапа (или через `auto` секунд).

signal pumped(ok: bool)
signal splashed(n: int)
signal cleared
signal overflowed

const PIPE := Color("b9c3c8")
const PIPE_DARK := Color("6d777d")
const WATER := Color(0.36, 0.72, 0.95, 0.85)
const CLOG := Color("6b5236")
const MOLD := Color("5f8f4e")
const RUBBER := Color("c7433a")
const HANDLE := Color("b88350")

var path := PackedVector2Array()
var push := 70.0
var slide := 40.0
var recover := 0.6
var splash_limit := 3
var overflow := 22.0
var sink := Rect2(200, 240, 320, 170)
var cup := Vector2(360, 330)
var auto := 3.0
var started := false
var done := false
var splashes := 0
var pos := 0.0              # где засор: px вдоль трубы от начала
var _len: Array[float] = [] # длина пути до каждой точки
var _total := 0.0
var _ready := 1.0           # 0..1: насколько вантуз расправился
var _down := 0.0            # анимация нажатия
var _level_t := 0.0         # сколько раковина наполняется
var _idle := 0.0
var _t := 0.0
var _wave := -1.0           # бегущая по трубе волна (px), -1 — нет


func setup(cfg: Dictionary) -> void:
	for p in cfg.get("path", []):
		path.append(Vector2(p[0], p[1]))
	_len.append(0.0)
	for i in range(1, path.size()):
		_total += path[i].distance_to(path[i - 1])
		_len.append(_total)
	pos = _total * float(cfg.get("start", 0.2))
	push = float(cfg.get("push", push))
	slide = float(cfg.get("slide", slide))
	recover = float(cfg.get("recover", recover))
	splash_limit = int(cfg.get("splashes", splash_limit))
	overflow = float(cfg.get("overflow", overflow))
	auto = float(cfg.get("auto", auto))
	var s: Array = cfg.get("sink", [200, 240, 320, 170])
	sink = Rect2(s[0], s[1], s[2], s[3])
	var c: Array = cfg.get("cup", [360, 330])
	cup = Vector2(c[0], c[1])


## Доля пути, которую прошёл засор (для счётчика цели).
func progress() -> float:
	return clampf(pos / _total, 0.0, 1.0) if _total > 0.0 else 0.0


func fill() -> float:
	return clampf(_level_t / overflow, 0.0, 1.0)


## Тап: качнуть вантуз.
func pump() -> void:
	if done:
		return
	started = true
	_down = 1.0
	if _ready >= 1.0:
		pos = minf(pos + push, _total)
		_wave = 0.0
		pumped.emit(true)
	else:
		splashes += 1
		pumped.emit(false)
		splashed.emit(splashes)
	_ready = 0.0


func step(delta: float) -> void:
	_t += delta
	queue_redraw()
	if done:
		return
	if not started:
		_idle += delta
		if _idle < auto:
			return
		started = true
	_ready = minf(1.0, _ready + delta / recover)
	_down = maxf(0.0, _down - delta * 5.0)
	if _wave >= 0.0:
		_wave += delta * 900.0
		if _wave > pos:
			_wave = -1.0
	# на подъёме засор сползает назад: чем круче, тем быстрее
	var tan := _tangent(pos)
	if tan.y < 0.0 and pos < _total:
		pos = maxf(0.0, pos + tan.y * slide * delta)
	_level_t += delta
	if pos >= _total - 0.5:
		done = true
		cleared.emit()
	elif _level_t >= overflow:
		done = true
		overflowed.emit()


func _point(d: float) -> Vector2:
	for i in range(1, path.size()):
		if d <= _len[i] or i == path.size() - 1:
			var seg := _len[i] - _len[i - 1]
			var k := clampf((d - _len[i - 1]) / seg, 0.0, 1.0) if seg > 0.0 else 0.0
			return path[i - 1].lerp(path[i], k)
	return path[path.size() - 1] if not path.is_empty() else Vector2.ZERO


func _tangent(d: float) -> Vector2:
	for i in range(1, path.size()):
		if d < _len[i] or i == path.size() - 1:
			return (path[i] - path[i - 1]).normalized()
	return Vector2.ZERO


func _draw() -> void:
	# труба: тёмный край, светлое тело, внутри вода до засора
	if path.size() >= 2:
		draw_polyline(path, PIPE_DARK, 62.0, true)
		draw_polyline(path, PIPE, 52.0, true)
		draw_polyline(path, Color(0.2, 0.22, 0.24, 0.55), 36.0, true)
		var wet := PackedVector2Array()
		var d := 0.0
		while d < pos:
			wet.append(_point(d))
			d += 12.0
		wet.append(_point(pos))
		if wet.size() >= 2:
			draw_polyline(wet, WATER, 30.0, true)
		if _wave >= 0.0:
			var w := _point(_wave)
			draw_circle(w, 20.0, Color(1, 1, 1, 0.5))
		# засор: бурый ком с пятнами плесени, дрожит, пока его толкают
		var c := _point(pos) + Vector2(sin(_t * 40.0), 0) * _down * 3.0
		if not done or pos < _total - 0.5:
			draw_circle(c, 25.0, CLOG)
			for k in 5:
				var a := k * TAU / 5.0 + 0.4
				draw_circle(c + Vector2(cos(a), sin(a)) * 13.0, 5.5, MOLD)
			draw_circle(c + Vector2(-6, -7), 4.0, Color(1, 1, 1, 0.25))
	# раковина: чаша с водой, уровень растёт
	var bowl := PackedVector2Array([sink.position, Vector2(sink.end.x, sink.position.y),
		Vector2(sink.end.x - 40.0, sink.end.y), Vector2(sink.position.x + 40.0, sink.end.y)])
	draw_colored_polygon(bowl, Color("f2efe8"))
	draw_polyline(PackedVector2Array([bowl[0], bowl[1], bowl[2], bowl[3], bowl[0]]), Color("9aa0a3"), 5.0, true)
	var f := fill()
	if f > 0.0:
		var top := lerpf(sink.end.y - 14.0, sink.position.y + 10.0, f)
		var k := (top - sink.position.y) / sink.size.y
		var water := PackedVector2Array([Vector2(sink.position.x + 40.0 * k + 6.0, top),
			Vector2(sink.end.x - 40.0 * k - 6.0, top), Vector2(sink.end.x - 44.0, sink.end.y - 6.0),
			Vector2(sink.position.x + 44.0, sink.end.y - 6.0)])
		draw_colored_polygon(water, WATER.lerp(Color(0.95, 0.4, 0.3, 0.85), maxf(0.0, f - 0.75) * 4.0))
	# вантуз: резиновая чашка на сливе и ручка; кольцо готовности
	var press := _down * 22.0
	var cp := cup + Vector2(0, press)
	draw_rect(Rect2(cp.x - 7.0, cp.y - 190.0, 14.0, 170.0), HANDLE)
	draw_colored_polygon(PackedVector2Array([cp + Vector2(-46, 0), cp + Vector2(46, 0), cp + Vector2(30, -34),
		cp + Vector2(-30, -34)]), RUBBER)
	var ring := cp + Vector2(0, -210.0)
	draw_arc(ring, 26.0, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 6.0, true)
	draw_arc(ring, 26.0, -PI * 0.5, -PI * 0.5 + TAU * _ready, 32,
		Color("f2c14e") if _ready >= 1.0 else Color(1, 1, 1, 0.8), 6.0, true)
	if _ready >= 1.0 and not done:
		draw_circle(ring, 10.0 + 2.0 * sin(_t * 10.0), Color("f2c14e"))
	# выплески: капли у раковины, по числу ошибок
	for i in splash_limit:
		var p := Vector2(sink.end.x + 34.0, sink.position.y + 20.0 + i * 34.0)
		draw_circle(p, 11.0, Color(0.95, 0.4, 0.3) if i < splashes else Color(1, 1, 1, 0.35))
