class_name Pen
extends RefCounted
## Общие кисти для рисованных персонажей и комнаты.
## Godot делает сглаживающую кайму в локальных единицах, и при увеличении (хаб 1.4–2x,
## растяжение экрана 1.5–2x на телефоне) края мылятся. Pen умножает координаты на
## реальный масштаб пикселя k и сжимает холст обратно на 1/k: кайма всегда около пикселя.
## Рисуем только между begin() и end(); всё однопоточно, поэтому состояние статическое.

const INK := Color("24163d")

static var k := 1.0
static var desat := 0.0     # обесцвечивание 0..1 (сломанные предметы)
static var dim := 0.0       # затемнение 0..1
static var alpha := 1.0     # общий множитель прозрачности
static var _ci: CanvasItem
static var _base := Transform2D.IDENTITY
static var _up := Transform2D.IDENTITY


## Дочерний холст, который отдаёт рисование владельцу: дыхание и прыжки двигают
## только его трансформ, без перерисовки.
class Canvas extends Node2D:
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


## Сколько пикселей экрана в единице холста (с учётом растяжения окна).
static func pixel_scale(ci: CanvasItem) -> float:
	if ci == null or not ci.is_inside_tree():
		return 1.0
	var s := ci.get_global_transform_with_canvas().get_scale().abs()
	var vp := ci.get_viewport()
	var f := vp.get_final_transform().get_scale().abs() if vp else Vector2.ONE
	return snappedf(clampf(maxf(s.x * f.x, s.y * f.y), 0.25, 8.0), 0.05)


## xf — дополнительная локальная трансформация (сдвиг, поворот, масштаб) для всего рисунка.
static func begin(ci: CanvasItem, xf := Transform2D.IDENTITY, scale := -1.0) -> void:
	_ci = ci
	k = (scale if scale > 0.0 else pixel_scale(ci)) * maxf(xf.get_scale().x, 0.01)
	_base = xf
	_up = Transform2D.IDENTITY.scaled(Vector2(k, k))
	desat = 0.0
	dim = 0.0
	alpha = 1.0
	push(Transform2D.IDENTITY)


## Локальная трансформация поверх базовой (наклон шляпы и т.п.).
static func push(local: Transform2D) -> void:
	_ci.draw_set_transform_matrix(_base * local * Transform2D.IDENTITY.scaled(Vector2(1.0 / k, 1.0 / k)))


static func end() -> void:
	_ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	desat = 0.0
	dim = 0.0
	alpha = 1.0


static func col(c: Color) -> Color:
	if desat > 0.0:
		var l := c.get_luminance()
		c = c.lerp(Color(l, l, l, c.a), desat)
	if dim > 0.0:
		c = c.darkened(dim)
	c.a *= alpha
	return c


static func poly(pts: PackedVector2Array, c: Color) -> void:
	_ci.draw_colored_polygon(_up * pts, col(c))


## Заливка с градиентом по вершинам.
static func grad(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	var cc := PackedColorArray()
	cc.resize(cols.size())
	for i in cols.size():
		cc[i] = col(cols[i])
	_ci.draw_polygon(_up * pts, cc)


## Заливка с чернильным контуром (стиль наклейки).
static func blob(pts: PackedVector2Array, c: Color, w := 2.5, edge := INK) -> void:
	poly(pts, c)
	if w > 0.0:
		loop(pts, edge, w)


## Заливка без контура, но со сглаженным краем.
static func soft(pts: PackedVector2Array, c: Color) -> void:
	poly(pts, c)
	loop(pts, c, 1.0)


static func loop(pts: PackedVector2Array, c: Color, w: float) -> void:
	var closed := _up * pts
	closed.append(closed[0])
	_ci.draw_polyline(closed, col(c), w * k, true)


static func pline(pts: PackedVector2Array, c: Color, w: float) -> void:
	_ci.draw_polyline(_up * pts, col(c), w * k, true)


## Много отдельных отрезков (пары точек) одной командой.
static func multi(pts: PackedVector2Array, c: Color, w: float) -> void:
	if pts.size() >= 2:
		_ci.draw_multiline(_up * pts, col(c), w * k, true)


static func line(a: Vector2, b: Vector2, c: Color, w: float) -> void:
	_ci.draw_line(a * k, b * k, col(c), w * k, true)


static func disc(p: Vector2, r: float, c: Color) -> void:
	_ci.draw_circle(p * k, r * k, col(c), true, -1.0, true)


static func ring(p: Vector2, r: float, c: Color, w: float) -> void:
	_ci.draw_circle(p * k, r * k, col(c), false, w * k, true)


## Круг с чернильным контуром.
static func dot(p: Vector2, r: float, c: Color, w := 2.0, edge := INK) -> void:
	disc(p, r, c)
	if w > 0.0:
		ring(p, r, edge, w)


static func arc(p: Vector2, r: float, a0: float, a1: float, c: Color, w: float, n := 12) -> void:
	_ci.draw_arc(p * k, r * k, a0, a1, n, col(c), w * k, true)


static func rect(r: Rect2, c: Color) -> void:
	_ci.draw_rect(Rect2(r.position * k, r.size * k), col(c))


## Прямоугольник с вертикальным градиентом.
static func vgrad(r: Rect2, top: Color, bottom: Color) -> void:
	grad(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Радиальное свечение: сетка треугольников от яркого центра через средний круг к прозрачному краю.
static func glow(p: Vector2, r: Vector2, c: Color, n := 24) -> void:
	var pts := PackedVector2Array([p * k])
	var cols := PackedColorArray([col(c)])
	var idx := PackedInt32Array()
	var mid := col(Color(c, c.a * 0.4))
	var edge := col(Color(c, 0.0))
	for i in n:
		var d := Vector2.from_angle(TAU * i / n) * r
		pts.append((p + d * 0.45) * k)
		pts.append((p + d) * k)
		cols.append(mid)
		cols.append(edge)
		var a := 1 + i * 2
		var b := 1 + ((i + 1) % n) * 2
		idx.append_array(PackedInt32Array([0, a, b, a, a + 1, b + 1, a, b + 1, b]))
	RenderingServer.canvas_item_add_triangle_array(_ci.get_canvas_item(), idx, pts, cols)


## Огонёк из трёх язычков: красный, оранжевый, светлая сердцевина. sway качает вершину.
static func flame(c: Vector2, r: float, h: float, sway: float) -> void:
	for layer in 3:
		var f := 1.0 - layer * 0.3
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			var up := cos(a) > 0.0
			var y := -cos(a) * (h * f - r * f if up else r * f)
			var x := r * f * sin(a) * pow(absf(sin(a * 0.5)), 1.3)
			pts.append(c + Vector2(x + sway * f * pow(maxf(0.0, -y) / h, 2.0), y - r * 0.2 - layer * r * 0.15))
		soft(pts, [Color("ff5a1f"), Color("ffb02e"), Color("fff1b8")][layer])


static func text(font: Font, p: Vector2, s: String, size: int, c: Color, outline := 0) -> void:
	if outline > 0:
		_ci.draw_string_outline(font, p * k, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * k), int(outline * k), col(c))
	else:
		_ci.draw_string(font, p * k, s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * k), col(c))


# --- геометрия (без рисования) -------------------------------------------------

static func oval(p: Vector2, r: Vector2, n := 20, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = p + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot)
	return pts


static func rrect(r: Rect2, rad: float, seg := 4) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rr := minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [r.position + Vector2(rr, rr), Vector2(r.end.x - rr, r.position.y + rr), r.end - Vector2(rr, rr),
		Vector2(r.position.x + rr, r.end.y - rr)]
	for q in 4:
		for i in seg + 1:
			pts.append(cs[q] + Vector2.from_angle(PI + q * PI / 2.0 + i * PI / 2.0 / seg) * rr)
	return pts


static func star_pts(p: Vector2, r: float, inner := 0.45, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(p + Vector2.from_angle(-PI / 2.0 + rot + PI * i / 5.0) * (r if i % 2 == 0 else r * inner))
	return pts


static func star(p: Vector2, r: float, c: Color, w := 1.5, rot := 0.0) -> void:
	blob(star_pts(p, r, 0.45, rot), c, w)


## Четырёхлучевая искорка.
static func sparkle(p: Vector2, r: float, c: Color) -> void:
	var q := r * 0.28
	soft(PackedVector2Array([p + Vector2(0, -r), p + Vector2(q, -q), p + Vector2(r, 0), p + Vector2(q, q),
		p + Vector2(0, r), p + Vector2(-q, q), p + Vector2(-r, 0), p + Vector2(-q, -q)]), c)


static func qbez(a: Vector2, b: Vector2, c: Vector2, u: float) -> Vector2:
	return a.lerp(b, u).lerp(b.lerp(c, u), u)


## Сглаживает ломаную (Catmull-Rom), steps точек на отрезок.
static func smooth(src: Array, steps := 3) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := src.size()
	for i in n - 1:
		var p0: Vector2 = src[maxi(i - 1, 0)]
		var p1: Vector2 = src[i]
		var p2: Vector2 = src[i + 1]
		var p3: Vector2 = src[mini(i + 2, n - 1)]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			out.append(0.5 * ((2.0 * p1) + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t2 * t))
	out.append(src[n - 1])
	return out
