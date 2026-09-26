extends Node2D
## «Сшей диван»: обивка порвана, вдоль разрыва — пары дырок (слева L1..Ln, справа R1..Rn). Тап по
## дырке — игла ведёт нитку туда. Шить надо зигзагом сверху вниз: L1, R1, L2, R2 … Не та дырка —
## узелок (`knots` узелков — нитка запуталась, проигрыш). Сквозь разрыв торчат пружины: стежок над
## пружиной не пройдёт (узелок), сначала тап по пружине — она прячется на `hide` секунд. Мышь
## прибегает и грызёт нитку — последний стежок распускается; тап по мыши — убегает насовсем.
## Разрыв стягивается с каждым стежком. Все дырки прошиты — диван целый (победа).
## Уровень: "sew": {top: [x, y], step, gap, pairs, springs: [{id, pair}], hide, knots,
## mouse: {at, speed, gnaw}}.

signal stitched(n: int)
signal knotted(n: int)
signal unraveled
signal done
signal mouse_scared

const MOUSE_TEX := "res://art/act1/enemies/mouse.png"
const THREAD := Color("c7433a")
const HOLE := Color("3a2a1c")
const HOLE_RIM := Color("e8d4a8")
const TEAR := Color("2a1d14")
const SPRING := Color("8d969b")
const HIT := 46.0

var top := Vector2(360, 330)
var step := 150.0
var gap := 70.0             # полуширина разрыва: от него до дырок
var pairs := 5
var hide := 3.0
var knot_limit := 3
var knots := 0
var order: Array[String] = []
var progress := 0           # сколько дырок уже прошито
var springs := {}           # id -> {pair, out: bool, timer}
var finished := false
var _mouse := {}            # at, speed, gnaw
var _m_state := "wait"      # wait / run / gnaw / flee / gone
var _m_pos := Vector2(-60, 0)
var _m_timer := 0.0
var _m_tex: Texture2D
var _t := 0.0
var _close := 0.0           # насколько стянут разрыв (для анимации)
var _flash := {}            # id дырки или пружины -> вспышка


func setup(cfg: Dictionary) -> void:
	top = Vector2(cfg.get("top", [360, 330])[0], cfg.get("top", [360, 330])[1])
	step = float(cfg.get("step", step))
	gap = float(cfg.get("gap", gap))
	pairs = int(cfg.get("pairs", pairs))
	hide = float(cfg.get("hide", hide))
	knot_limit = int(cfg.get("knots", knot_limit))
	for i in pairs:
		order.append("L%d" % (i + 1))
		order.append("R%d" % (i + 1))
	for s in cfg.get("springs", []):
		springs[str(s["id"])] = {"pair": int(s["pair"]), "out": true, "timer": 0.0}
	_mouse = cfg.get("mouse", {})
	if _mouse.is_empty():
		_m_state = "gone"
	if ResourceLoader.exists(MOUSE_TEX):
		_m_tex = load(MOUSE_TEX)


func hole_pos(id: String) -> Vector2:
	var i := int(id.substr(1)) - 1
	var side := -1.0 if id[0] == "L" else 1.0
	# с каждым стежком края сходятся: дырки чуть ближе к шву
	var g := gap * (1.0 - 0.35 * _close)
	return top + Vector2(side * g, i * step)


func spring_pos(id: String) -> Vector2:
	var pair: int = springs[id]["pair"]
	return top + Vector2(0, (pair - 1) * step)


func next_hole() -> String:
	return order[progress] if progress < order.size() else ""


## Тап в точке: мышь, пружина или дырка. true — тап попал во что-то.
func tap_at(p: Vector2) -> bool:
	if finished:
		return false
	if _mouse_visible() and p.distance_to(_m_pos) < 70.0:
		scare()
		return true
	for id: String in springs:
		if springs[id]["out"] and p.distance_to(spring_pos(id)) < HIT:
			push_spring(id)
			return true
	for id in order:
		if p.distance_to(hole_pos(id)) < HIT:
			stitch(id)
			return true
	return false


func push_spring(id: String) -> void:
	if not springs.has(id) or finished:
		return
	springs[id]["out"] = false
	springs[id]["timer"] = hide
	_flash[id] = 1.0


## Стежок в дырку id: верная по порядку и не перекрытая пружиной — нитка идёт дальше.
func stitch(id: String) -> void:
	if finished:
		return
	if id != next_hole() or _blocked(id):
		knots += 1
		_flash[id] = 1.0
		knotted.emit(knots)
		return
	progress += 1
	_flash[id] = 1.0
	stitched.emit(progress)
	if progress >= order.size():
		finished = true
		done.emit()


## Стежок через разрыв (в правую дырку пары) не пройдёт, пока над этой парой торчит пружина.
func _blocked(id: String) -> bool:
	if id[0] != "R":
		return false
	var pair := int(id.substr(1))
	for sid: String in springs:
		if springs[sid]["pair"] == pair and springs[sid]["out"]:
			return true
	return false


func scare() -> void:
	if not _mouse_visible():
		return
	_m_state = "flee"
	mouse_scared.emit()


func _mouse_visible() -> bool:
	return _m_state in ["run", "gnaw"]


func step_time(delta: float) -> void:
	_t += delta
	_close = move_toward(_close, float(progress) / maxf(1.0, order.size()), delta)
	for id in _flash.keys():
		_flash[id] = maxf(0.0, float(_flash[id]) - delta * 3.0)
	for id: String in springs:
		var s: Dictionary = springs[id]
		if not s["out"]:
			# пружина прячется на время; если стежок над ней сделан — остаётся под нитками
			if progress >= 2 * int(s["pair"]):
				continue
			s["timer"] = float(s["timer"]) - delta
			if float(s["timer"]) <= 0.0:
				s["out"] = true
				_flash[id] = 1.0
	_step_mouse(delta)
	queue_redraw()


func _step_mouse(delta: float) -> void:
	if finished and _m_state != "flee":
		return
	match _m_state:
		"wait":
			_m_timer += delta
			if _m_timer >= float(_mouse.get("at", 6.0)):
				_m_state = "run"
				_m_pos = Vector2(-60, top.y + (maxf(0, progress - 1) / 2) * step + step * 0.3)
		"run":
			var tail := _tail()
			_m_pos = _m_pos.move_toward(tail, float(_mouse.get("speed", 150.0)) * delta)
			if _m_pos.distance_to(tail) < 4.0:
				_m_state = "gnaw"
				_m_timer = float(_mouse.get("gnaw", 1.5))
		"gnaw":
			_m_timer -= delta
			if _m_timer <= 0.0:
				if progress > 0 and not finished:
					progress -= 1
					unraveled.emit()
				_m_state = "flee"
		"flee":
			_m_pos.x -= 520.0 * delta
			if _m_pos.x < -80.0:
				_m_state = "gone"


## Куда бежит мышь: к последнему стежку (или к началу разрыва).
func _tail() -> Vector2:
	if progress == 0:
		return hole_pos("L1") + Vector2(-40, 20)
	return hole_pos(order[progress - 1]) + Vector2(-30 if order[progress - 1][0] == "L" else 30, 26)


func _draw() -> void:
	# разрыв: тёмная рваная щель, сходится по мере шитья
	var len := (pairs - 1) * step + step * 0.8
	var w := gap * 0.55 * (1.0 - 0.8 * _close)
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var y := top.y - step * 0.4 + len * i / float(n)
		var j := 7.0 * sin(i * 2.3) + 5.0 * sin(i * 5.1)
		left.append(Vector2(top.x - w + j, y))
		right.append(Vector2(top.x + w + j * 0.6, y))
	right.reverse()
	var gap_poly := left.duplicate()
	gap_poly.append_array(right)
	draw_colored_polygon(gap_poly, TEAR)
	# пружины в разрыве
	for id: String in springs:
		var s: Dictionary = springs[id]
		var p := spring_pos(id)
		var up := 1.0 if s["out"] else 0.25
		for k in 5:
			var y := p.y + 16.0 - k * 9.0 * up
			draw_arc(Vector2(p.x, y), 14.0, 0.0, PI, 10, SPRING, 4.0)
		if s["out"]:
			var ring := 30.0 + 4.0 * sin(_t * 6.0)
			draw_arc(p, ring, 0.0, TAU, 24, Color(1, 1, 1, 0.3 + 0.4 * float(_flash.get(id, 0.0))), 3.0, true)
	# дырки
	for id in order:
		var hp := hole_pos(id)
		draw_circle(hp, 13.0, HOLE_RIM)
		draw_circle(hp, 8.0, HOLE)
		var f := float(_flash.get(id, 0.0))
		if f > 0.0:
			draw_arc(hp, 18.0 + 10.0 * (1.0 - f), 0.0, TAU, 20, Color(1, 0.9, 0.5, f), 3.0, true)
	# подсказка: первая дырка пульсирует, пока шитьё не началось
	if progress == 0 and not finished:
		var ph := fmod(_t * 1.4, 1.0)
		draw_arc(hole_pos("L1"), 20.0 + ph * 30.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 1.0 - ph), 4.0, true)
	# нитка по прошитым дыркам и игла на конце
	if progress >= 2:
		var line := PackedVector2Array()
		for i in progress:
			line.append(hole_pos(order[i]))
		draw_polyline(line, Color(THREAD, 0.35), 9.0, true)
		draw_polyline(line, THREAD, 5.0, true)
	if progress >= 1 and not finished:
		var np := hole_pos(order[progress - 1])
		draw_line(np + Vector2(-6, -44), np + Vector2(2, 6), Color("d9dee0"), 5.0)
		draw_circle(np + Vector2(-6, -44), 4.0, Color("8d969b"))
	# мышь
	if _m_state in ["run", "gnaw", "flee"]:
		var s := 80.0
		var bob := sin(_t * (30.0 if _m_state == "gnaw" else 18.0)) * 3.0
		var face := 1.0 if _m_state == "flee" else -1.0
		if _m_tex:
			# отражаем масштабом, а не отрицательной шириной прямоугольника (та рисуется со сдвигом)
			draw_set_transform(_m_pos, 0.0, Vector2(face, 1.0))
			draw_texture_rect(_m_tex, Rect2(-s * 0.5, -s * 0.8 + bob, s, s), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(_m_pos, 22.0, Color("c9a27a"))
	# узелки: сколько ошибок осталось
	for i in knot_limit:
		var kp := Vector2(top.x - 70.0 + i * 70.0, top.y + (pairs - 1) * step + step * 0.9)
		draw_circle(kp, 12.0, Color(0.9, 0.35, 0.3) if i < knots else Color(1, 1, 1, 0.3))
