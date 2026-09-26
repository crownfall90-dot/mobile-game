extends Node2D
## «Луч и зеркальца»: фонарик светит лучом, зеркальца в клетках поля отражают его под прямым
## углом. Тап по зеркальцу поворачивает его (/ ↔ \). Луч дошёл до плафона — лампа горит (победа).
## Моль сидит на зеркальце: пока она там, его не повернуть и луч дальше не идёт; посвети на неё —
## через `scare` секунд улетит. Батарейки хватает на `taps` поворотов: кончилась, а лампа не горит,
## — фонарик гаснет (проигрыш). Звёзды: поворотов не больше `par` — три.
## Уровень: "mirrors": {origin: [x, y], cell, cols, rows, source: [c, r, dir], lamp: [c, r],
## items: [{id, c, r, kind: "/" | "\\" | "wall", fixed}], moth: [c, r], taps, par, scare, look}.

signal turned(id: String)
signal locked_tap(id: String)
signal lit
signal battery_out
signal moth_left(pos: Vector2)

const DIRS := {"right": Vector2i(1, 0), "left": Vector2i(-1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}
const MOTH_TEX := "res://art/act1/enemies/moth.png"
const FRAME := Color("8d969b")
const GLASS := Color("dff3ff")
const WALL := Color("7a6a5c")

var origin := Vector2(135, 250)
var cell := 90.0
var cols := 5
var rows := 8
var source := Vector2i(0, 7)
var source_dir := Vector2i(0, -1)
var lamp := Vector2i(4, 0)
var items := {}             # Vector2i -> {id, kind, fixed}
var moth := Vector2i(-1, -1)
var taps_left := 5
var taps_used := 0
var par := 3
var scare_time := 0.6
var look := "light"
var beam := PackedVector2Array()
var is_lit := false
var out := false
var _moth_lit := 0.0
var _moth_fly := -1.0       # анимация улёта: 0..1
var _moth_from := Vector2.ZERO
var _moth_tex: Texture2D
var _t := 0.0
var _flash := {}            # id -> 0..1 вспышка поворота


func setup(cfg: Dictionary) -> void:
	origin = Vector2(cfg.get("origin", [135, 250])[0], cfg.get("origin", [135, 250])[1])
	cell = float(cfg.get("cell", 90.0))
	cols = int(cfg.get("cols", 5))
	rows = int(cfg.get("rows", 8))
	var s: Array = cfg.get("source", [0, 7, "up"])
	source = Vector2i(int(s[0]), int(s[1]))
	source_dir = DIRS.get(str(s[2]), Vector2i(0, -1))
	var l: Array = cfg.get("lamp", [4, 0])
	lamp = Vector2i(int(l[0]), int(l[1]))
	for it in cfg.get("items", []):
		items[Vector2i(int(it["c"]), int(it["r"]))] = {"id": str(it.get("id", "")), "kind": str(it["kind"]),
			"fixed": bool(it.get("fixed", false))}
	if cfg.has("moth"):
		moth = Vector2i(int(cfg["moth"][0]), int(cfg["moth"][1]))
	taps_left = int(cfg.get("taps", 5))
	par = int(cfg.get("par", 3))
	scare_time = float(cfg.get("scare", 0.6))
	look = str(cfg.get("look", "light"))
	if ResourceLoader.exists(MOTH_TEX):
		_moth_tex = load(MOTH_TEX)
	_trace()


func center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func has_moth() -> bool:
	return moth.x >= 0


## Тап в точке: повернуть зеркальце в этой клетке. true — тап попал в зеркальце.
func tap_at(p: Vector2) -> bool:
	var c := Vector2i(floori((p.x - origin.x) / cell), floori((p.y - origin.y) / cell))
	if not items.has(c):
		return false
	turn(str(items[c]["id"]))
	return true


func turn(id: String) -> void:
	if is_lit or out:
		return
	for c: Vector2i in items:
		var it: Dictionary = items[c]
		if it["id"] != id:
			continue
		if it["kind"] == "wall" or it["fixed"]:
			return
		if c == moth:
			locked_tap.emit(id)
			_flash[id] = 1.0
			return
		it["kind"] = "\\" if it["kind"] == "/" else "/"
		taps_left -= 1
		taps_used += 1
		_flash[id] = 1.0
		turned.emit(id)
		_trace()
		return


func step(delta: float) -> void:
	_t += delta
	for id in _flash.keys():
		_flash[id] = maxf(0.0, float(_flash[id]) - delta * 3.0)
	if _moth_fly >= 0.0:
		_moth_fly += delta * 1.2
		if _moth_fly >= 1.0:
			_moth_fly = -1.0
	if has_moth() and not is_lit:
		# свет на моли: через scare_time она улетает, и луч идёт дальше
		if _beam_reaches(moth):
			_moth_lit += delta
			if _moth_lit >= scare_time:
				_moth_from = center(moth)
				moth = Vector2i(-1, -1)
				_moth_fly = 0.0
				moth_left.emit(_moth_from)
				_trace()
		else:
			_moth_lit = 0.0
	if not is_lit and not out and taps_left <= 0 and _moth_fly < 0.0 and (not has_moth() or not _beam_reaches(moth)):
		out = true
		battery_out.emit()
	queue_redraw()


func _beam_reaches(c: Vector2i) -> bool:
	return beam.size() >= 2 and beam[beam.size() - 1].distance_to(center(c)) < cell * 0.6


## Луч из фонарика клетка за клеткой: зеркальце поворачивает, стена и моль останавливают.
func _trace() -> void:
	beam = PackedVector2Array([center(source)])
	var c := source
	var d := source_dir
	for i in 200:
		c += d
		if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
			beam.append(center(c - d) + Vector2(d) * cell * 0.5)
			break
		if c == lamp:
			beam.append(center(c))
			if not is_lit:
				is_lit = true
				lit.emit()
			break
		if c == moth:
			beam.append(center(c))
			break
		if items.has(c):
			var k: String = items[c]["kind"]
			if k == "wall":
				beam.append(center(c) - Vector2(d) * cell * 0.5)
				break
			beam.append(center(c))
			d = Vector2i(-d.y, -d.x) if k == "/" else Vector2i(d.y, d.x)


func _draw() -> void:
	var glow := Color(0.45, 0.9, 1.0) if look == "signal" else Color(1.0, 0.9, 0.4)
	# лёгкая сетка: видно клетки
	for x in cols + 1:
		draw_line(origin + Vector2(x * cell, 0), origin + Vector2(x * cell, rows * cell), Color(1, 1, 1, 0.06), 2.0)
	for y in rows + 1:
		draw_line(origin + Vector2(0, y * cell), origin + Vector2(cols * cell, y * cell), Color(1, 1, 1, 0.06), 2.0)
	# луч: широкое мягкое свечение и яркая середина
	if beam.size() >= 2:
		var pulse := 0.8 + 0.2 * sin(_t * 6.0)
		draw_polyline(beam, Color(glow, 0.18 * pulse), 34.0, true)
		draw_polyline(beam, Color(glow, 0.45), 16.0, true)
		draw_polyline(beam, Color(1, 1, 0.95, 0.95), 6.0, true)
	for c: Vector2i in items:
		var it: Dictionary = items[c]
		var p := center(c)
		if it["kind"] == "wall":
			var r := Rect2(p - Vector2(cell, cell) * 0.46, Vector2(cell, cell) * 0.92)
			draw_rect(r, WALL)
			draw_rect(r, Color(0, 0, 0, 0.25), false, 3.0)
			draw_line(r.position + Vector2(0, r.size.y * 0.5), Vector2(r.end.x, r.position.y + r.size.y * 0.5), Color(0, 0, 0, 0.2), 2.0)
			continue
		var h := cell * 0.36
		var a := p + (Vector2(-h, h) if it["kind"] == "/" else Vector2(-h, -h))
		var b := p + (Vector2(h, -h) if it["kind"] == "/" else Vector2(h, h))
		draw_circle(p, cell * 0.42, Color(0, 0, 0, 0.12))
		if not it["fixed"]:
			draw_arc(p, cell * 0.44, 0.0, TAU, 28, Color(1, 1, 1, 0.3 + 0.5 * float(_flash.get(it["id"], 0.0))), 3.0, true)
		draw_line(a, b, FRAME, 16.0)
		draw_line(a, b, GLASS, 10.0)
		draw_line(a + (b - a) * 0.15, a + (b - a) * 0.45, Color(1, 1, 1, 0.9), 3.0)
	# фонарик / антенна / конец провода
	var sp := center(source)
	var ang := Vector2(source_dir).angle()
	draw_set_transform(sp, ang, Vector2.ONE)
	if look == "current":
		# ток из провода: трещащая искра на конце
		for k in 5:
			var a := _t * 9.0 + k * TAU / 5.0
			draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * (10.0 + 6.0 * sin(_t * 23.0 + k)), Color(1, 1, 0.8, 0.9), 2.0)
		draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 0.85))
	elif look == "light":
		draw_rect(Rect2(-34, -14, 44, 28), Color("3b4a6b"))
		draw_colored_polygon(PackedVector2Array([Vector2(10, -20), Vector2(30, -26), Vector2(30, 26), Vector2(10, 20)]), Color("5a6b8c"))
		draw_circle(Vector2(30, 0), 12.0, Color(1, 1, 0.8))
	else:
		# антенна: мачта с дугами сигнала
		draw_rect(Rect2(-30, -5, 50, 10), Color("6d777d"))
		for k in 3:
			draw_arc(Vector2(22, 0), 10.0 + k * 9.0, -0.8, 0.8, 8, Color(0.45, 0.9, 1.0, 0.8), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# плафон: лампа загорается, когда в неё попал луч; у «тока» патрон нарисован на картинке —
	# при попадании в нём загорается лампочка
	var lp := center(lamp)
	if is_lit:
		draw_circle(lp, cell * 0.62 + 4.0 * sin(_t * 5.0), Color(glow, 0.25))
	if look == "current":
		if is_lit:
			draw_circle(lp + Vector2(0, -cell * 0.2), cell * 0.34, Color("fff6c9"))
		else:
			draw_arc(lp, cell * 0.45 + 3.0 * sin(_t * 4.0), 0.0, TAU, 32, Color(1, 1, 1, 0.35), 3.0, true)
	else:
		draw_circle(lp, cell * 0.36, Color("fff6c9") if is_lit else Color("a9a49a"))
		draw_arc(lp, cell * 0.36, 0.0, TAU, 32, Color("7c7468"), 4.0, true)
		draw_rect(Rect2(lp + Vector2(-14, -cell * 0.36 - 16), Vector2(28, 16)), Color("7c7468"))
	# моль: сидит на зеркальце (крылышки дрожат) или улетает вверх
	var mp := Vector2.INF
	if has_moth():
		mp = center(moth) + Vector2(0, -cell * 0.2) + Vector2(sin(_t * 30.0), 0) * (2.0 + _moth_lit * 6.0)
	elif _moth_fly >= 0.0:
		mp = _moth_from + Vector2(sin(_moth_fly * 12.0) * 40.0, -_moth_fly * 700.0)
	if mp != Vector2.INF:
		var s := cell * 0.8
		if _moth_tex:
			draw_texture_rect(_moth_tex, Rect2(mp - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		else:
			draw_circle(mp, s * 0.25, Color("b8a68a"))
	# батарейка: сколько поворотов осталось
	var bx := origin.x + cols * cell - 24.0 * (taps_left + taps_used)
	for i in taps_left + taps_used:
		var r := Rect2(Vector2(bx + i * 24.0, origin.y + rows * cell + 18.0), Vector2(18, 30))
		draw_rect(r, Color("f2c14e") if i < taps_left else Color(1, 1, 1, 0.2))
		draw_rect(r, Color(0, 0, 0, 0.35), false, 2.0)
