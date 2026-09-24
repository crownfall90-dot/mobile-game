class_name LabArt
extends RefCounted
## Лаборатория Мастера — хаб. Комната и 9 предметов в трёх состояниях.
## Рисует в чужой CanvasItem в дизайн-координатах 720x1280 (начало холста = угол экрана).
## Комнату рисуйте один раз на статичном холсте, каждый предмет — на своём узле и только
## при смене состояния; анимируется лишь GHOST (пульс по t). Порядок рисования — ORDER.

const BROKEN := 0
const GHOST := 1
const RESTORED := 2
const SLOTS := {
	&"shelves": Rect2(40, 300, 190, 220),
	&"barrels": Rect2(30, 760, 180, 200),
	&"lantern": Rect2(240, 130, 70, 120),
	&"workbench": Rect2(480, 760, 210, 200),
	&"window": Rect2(260, 170, 200, 290),
	&"bookcase": Rect2(500, 260, 190, 440),
	&"rug": Rect2(180, 960, 360, 110),
	&"telescope": Rect2(420, 470, 140, 200),
	&"alembic": Rect2(240, 520, 240, 380),
}
## От дальних к ближним.
const ORDER: Array[StringName] = [&"window", &"shelves", &"bookcase", &"lantern", &"telescope", &"rug",
	&"alembic", &"barrels", &"workbench"]
const FLOOR_Y := 660.0

const INK := Pen.INK
const WOOD := Color("8a5a3c")
const WOOD_DARK := Color("5a3626")
const WOOD_LIGHT := Color("b57f52")
const METAL := Color("4a4764")
const BRASS := Color("d9a441")
const COPPER := Color("d97a3f")
const GLASS := Color(0.78, 0.92, 1.0, 0.28)
const GOLD := Color("f5c542")
const MAGENTA := Color("ff4fd8")
const CYAN := Color("39d6ff")
const LIME := Color("7dff4d")
const AMBER := Color("f5a142")
const VIOLET := Color("8a4dff")
const RED := Color("d9463a")
const BOOKS: Array[Color] = [Color("c0392b"), Color("3d7bff"), Color("4fae5a"), Color("8a4dff"), Color("f5a142"),
	Color("2fb5a8"), Color("d95f9a")]

static var _lit := true   # светятся ли жидкости и огонь (только у восстановленных)


# --- комната -----------------------------------------------------------------

static func draw_room(ci: CanvasItem, size: Vector2) -> void:
	Pen.begin(ci)
	var w := size.x
	Pen.rect(Rect2(0, 0, w, 100), Color("150e28"))
	Pen.vgrad(Rect2(0, 100, w, FLOOR_Y - 100), Color("231940"), Color("3a2b5e"))
	# каменная кладка: полупрозрачные светлые камни поверх градиента
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var y := 124.0
	while y < FLOOR_Y - 20.0:
		var x := -rng.randf_range(10.0, 70.0)
		while x < w:
			var sw := rng.randf_range(70.0, 120.0)
			var r := Rect2(x + 3, y + 3, sw - 6, 40)
			Pen.soft(Pen.rrect(r, 8, 2), Color(0.66, 0.58, 0.95, rng.randf_range(0.07, 0.13)))
			Pen.line(r.position + Vector2(8, 1.5), Vector2(r.end.x - 8, r.position.y + 1.5), Color(1, 1, 1, 0.07), 2.0)
			Pen.line(Vector2(r.position.x + 8, r.end.y - 1), r.end - Vector2(8, 1), Color(0, 0, 0, 0.2), 2.0)
			x += sw
		y += 46.0
	_draw_window_hole()
	# балка под потолком и плинтус
	Pen.vgrad(Rect2(0, 96, w, 30), Color("4a2e3e"), Color("2e1c2c"))
	Pen.line(Vector2(0, 126), Vector2(w, 126), INK, 3.0)
	for bx: float in [70.0, 650.0]:
		Pen.blob(PackedVector2Array([Vector2(bx - 10, 126), Vector2(bx + 10, 126), Vector2(bx + 10, 150), Vector2(bx, 162),
			Vector2(bx - 10, 150)]), Color("3a2434"), 2.0)
	Pen.vgrad(Rect2(0, FLOOR_Y - 20, w, 20), Color("3e2838"), Color("2a1a28"))
	Pen.line(Vector2(0, FLOOR_Y - 20), Vector2(w, FLOOR_Y - 20), Color(1, 1, 1, 0.08), 2.0)
	_draw_floor(size)
	# лунный луч из окна и пятно на полу
	Pen.grad(PackedVector2Array([Vector2(275, 455), Vector2(445, 455), Vector2(330, 930), Vector2(90, 930)]),
		PackedColorArray([Color(0.6, 0.7, 1.0, 0.1), Color(0.6, 0.7, 1.0, 0.1), Color(0.6, 0.7, 1.0, 0.0), Color(0.6, 0.7, 1.0, 0.0)]))
	Pen.poly(PackedVector2Array([Vector2(170, 800), Vector2(330, 800), Vector2(290, 900), Vector2(100, 900)]), Color(0.65, 0.75, 1.0, 0.05))
	# тёплый свет лаборатории и виньетка
	Pen.glow(Vector2(360, 880), Vector2(560, 420), Color(1.0, 0.62, 0.3, 0.2), 32)
	Pen.glow(Vector2(360, 640), Vector2(330, 260), Color(1.0, 0.55, 0.35, 0.1), 24)
	var clear := Color(0, 0, 0, 0)
	var dark := Color(0.03, 0.01, 0.08, 0.5)
	Pen.grad(PackedVector2Array([Vector2(0, 0), Vector2(110, 0), Vector2(110, size.y), Vector2(0, size.y)]), PackedColorArray([dark, clear, clear, dark]))
	Pen.grad(PackedVector2Array([Vector2(w - 110, 0), Vector2(w, 0), Vector2(w, size.y), Vector2(w - 110, size.y)]), PackedColorArray([clear, dark, dark, clear]))
	Pen.grad(PackedVector2Array([Vector2(0, size.y - 220), Vector2(w, size.y - 220), Vector2(w, size.y), Vector2(0, size.y)]), PackedColorArray([clear, clear, dark, dark]))
	Pen.end()


## Арочный проём окна: ночное небо, луна, холмы; сам витраж — предмет &"window".
static func _draw_window_hole() -> void:
	var r: Rect2 = SLOTS[&"window"]
	Pen.blob(_arch(r.grow(16)), Color("4b3d72"), 3.0)
	for i in 9:
		var a := PI + PI * i / 8.0
		Pen.line(r.position + Vector2(100, 100) + Vector2.from_angle(a) * 100, r.position + Vector2(100, 100) + Vector2.from_angle(a) * 116, INK, 2.0)
	var sky := _arch(r)
	var cols := PackedColorArray()
	for p in sky:
		cols.append(Color("16225e").lerp(Color("4a3a8e"), (p.y - r.position.y) / r.size.y))
	Pen.grad(sky, cols)
	for p: Vector3 in [Vector3(300, 220, 3), Vector3(335, 300, 2), Vector3(290, 350, 2.5), Vector3(430, 330, 2), Vector3(372, 200, 2)]:
		Pen.sparkle(Vector2(p.x, p.y), p.z * 1.6, Color(1, 1, 1, 0.8))
	Pen.glow(Vector2(405, 255), Vector2(70, 70), Color(1.0, 0.95, 0.8, 0.35), 20)
	Pen.disc(Vector2(405, 255), 30, Color("fff2cf"))
	for c: Vector3 in [Vector3(396, 246, 6), Vector3(414, 266, 4), Vector3(412, 243, 3)]:
		Pen.disc(Vector2(c.x, c.y), c.z, Color(0.85, 0.8, 0.65, 0.6))
	var hills := PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.position.x, 420)])
	for i in 11:
		var x := r.position.x + r.size.x * i / 10.0
		hills.append(Vector2(x, 418.0 + sin(i * 1.3) * 10.0 - (18.0 if i == 7 else 0.0)))
	hills.append(r.end)
	Pen.poly(hills, Color("201845"))
	# далёкая башенка на холме
	Pen.poly(PackedVector2Array([Vector2(420, 412), Vector2(432, 412), Vector2(432, 385), Vector2(426, 372), Vector2(420, 385)]), Color("201845"))
	Pen.disc(Vector2(426, 392), 1.8, Color(1.0, 0.8, 0.4, 0.9))
	Pen.blob(Pen.rrect(Rect2(r.position.x - 22, r.end.y - 4, r.size.x + 44, 16), 4), Color("5a4b84"), 2.5)


static func _draw_floor(size: Vector2) -> void:
	var w := size.x
	var fy := FLOOR_Y
	var vp := Vector2(w * 0.5, -420.0)
	var k := (fy - vp.y) / (size.y - vp.y)
	for i in range(-9, 10):
		var x0 := w * 0.5 + i * 64.0
		var quad := PackedVector2Array([Vector2(vp.x + (x0 - vp.x) * k, fy), Vector2(vp.x + (x0 + 64.0 - vp.x) * k, fy),
			Vector2(x0 + 64.0, size.y), Vector2(x0, size.y)])
		var tint := 0.04 * float((i * 7 + 3) % 3)
		Pen.grad(quad, PackedColorArray([Color("33223f").lightened(tint), Color("33223f").lightened(tint),
			Color("5a3b52").lightened(tint), Color("5a3b52").lightened(tint)]))
		Pen.line(quad[0], quad[3], Color(0.05, 0.02, 0.08, 0.55), 2.0)
		# стыки досок, вразбежку
		for j in 7:
			var t := pow((j + 0.5 + (0.5 if i % 2 == 0 else 0.0)) / 7.0, 1.4)
			var yy := lerpf(fy, size.y, t)
			var f := (yy - vp.y) / (size.y - vp.y)
			Pen.line(Vector2(vp.x + (x0 - vp.x) * f, yy), Vector2(vp.x + (x0 + 64.0 - vp.x) * f, yy), Color(0.05, 0.02, 0.08, 0.35), 2.0)
	Pen.grad(PackedVector2Array([Vector2(0, fy), Vector2(w, fy), Vector2(w, fy + 60), Vector2(0, fy + 60)]),
		PackedColorArray([Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))


# --- предметы ------------------------------------------------------------------

## rect — куда рисовать (обычно SLOTS[obj_id]); t — время для пульса GHOST.
static func draw_object(ci: CanvasItem, obj_id: StringName, rect: Rect2, state: int, t: float) -> void:
	var design: Rect2 = SLOTS.get(obj_id, rect)
	var s := design.size
	var xf := Transform2D(0.0, rect.size / s, 0.0, rect.position)
	if state == BROKEN:
		# наклон 6° вокруг точки опоры: висячие — сверху, лежащие — по центру
		var pivot := Vector2(s.x * 0.5, 0.0 if obj_id == &"lantern" else (s.y * 0.5 if obj_id in [&"rug", &"window"] else s.y))
		xf = xf * Transform2D(deg_to_rad(6.0), pivot) * Transform2D(0.0, -pivot)
	Pen.begin(ci, xf)
	_lit = state == RESTORED
	if state == BROKEN:
		Pen.desat = 0.6
		Pen.dim = 0.25
	elif state == GHOST:
		Pen.alpha = 0.3 + 0.12 * sin(t * 3.0)
		Pen.desat = 0.2
	match obj_id:
		&"shelves":
			_shelves(s)
		&"barrels":
			_barrels(s)
		&"lantern":
			_lantern(s)
		&"workbench":
			_workbench(s)
		&"window":
			_window(s)
		&"bookcase":
			_bookcase(s)
		&"rug":
			_rug(s)
		&"telescope":
			_telescope(s)
		&"alembic":
			_alembic(s)
	Pen.desat = 0.0
	Pen.dim = 0.0
	Pen.alpha = 1.0
	if state == BROKEN:
		var right := hash(obj_id) & 1 == 1
		_cracks(s, hash(obj_id))
		_web(Vector2(s.x - 4, 4) if right else Vector2(4, 4), minf(46.0, s.x * 0.45), right)
	elif state == GHOST:
		_ghost_frame(s, t)
	Pen.end()


static func _shelves(s: Vector2) -> void:
	for y: float in [96.0, 208.0]:
		for x: float in [24.0, 166.0]:
			Pen.blob(PackedVector2Array([Vector2(x - 6, y), Vector2(x + 6, y), Vector2(x + 6, y + 8), Vector2(x - 2, y + 22)]), WOOD_DARK, 2.0)
		Pen.blob(Pen.rrect(Rect2(0, y - 12, s.x, 13), 3), WOOD, 2.5)
		Pen.line(Vector2(5, y - 9.5), Vector2(s.x - 5, y - 9.5), WOOD_LIGHT, 2.0)
	_bottle(Vector2(28, 84), 22, 64, CYAN)
	_flask(Vector2(74, 84), 21, LIME)
	_bottle(Vector2(114, 84), 18, 36, MAGENTA)
	Pen.blob(Pen.rrect(Rect2(136, 64, 48, 10), 2), BOOKS[0], 2.0)
	Pen.blob(Pen.rrect(Rect2(140, 74, 42, 10), 2), BOOKS[1], 2.0)
	for i in 3:
		_jar(Vector2(22 + i * 36, 196), 28, 34 + (i % 2) * 8, [AMBER, VIOLET, CYAN][i])
	# горшок с плющом
	Pen.blob(PackedVector2Array([Vector2(138, 166), Vector2(178, 166), Vector2(172, 196), Vector2(144, 196)]), Color("c0643a"), 2.0)
	for i in 5:
		var p := Vector2(150 + i * 5, 162 - (i % 3) * 8)
		Pen.blob(Pen.oval(p, Vector2(7, 4), 10, -0.6 + i * 0.3), Color("4fae5a") if i % 2 == 0 else Color("7fd35a"), 1.5)
	Pen.pline(Pen.smooth([Vector2(174, 170), Vector2(184, 188), Vector2(180, 206), Vector2(186, 222)]), Color("3f9a3a"), 3.0)


static func _barrels(s: Vector2) -> void:
	var body := Pen.smooth([Vector2(16, 60), Vector2(6, 125), Vector2(16, 196)]) + Pen.smooth([Vector2(100, 196), Vector2(110, 125), Vector2(100, 60)])
	Pen.blob(body, WOOD, 2.5)
	for dx: float in [-26.0, -9.0, 9.0, 26.0]:
		Pen.pline(Pen.smooth([Vector2(58 + dx, 62), Vector2(58 + dx * 1.2, 125), Vector2(58 + dx, 194)]), WOOD_DARK, 1.5)
	for hy: float in [84.0, 168.0]:
		Pen.pline(Pen.smooth([Vector2(9, hy), Vector2(58, hy + 6), Vector2(107, hy)]), METAL, 6.0)
		Pen.pline(Pen.smooth([Vector2(10, hy - 1.5), Vector2(58, hy + 4.5), Vector2(106, hy - 1.5)]), Color(1, 1, 1, 0.25), 1.5)
	Pen.blob(Pen.oval(Vector2(58, 60), Vector2(42, 10), 22), WOOD_LIGHT, 2.5)
	Pen.loop(Pen.oval(Vector2(58, 60), Vector2(28, 6), 20), WOOD, 1.5)
	# бочонок на боку с краником
	Pen.dot(Vector2(140, 160), 38, WOOD_LIGHT, 2.5)
	for rr: float in [30.0, 20.0, 10.0]:
		Pen.ring(Vector2(140, 160), rr, WOOD, 1.5)
	Pen.ring(Vector2(140, 160), 34, METAL, 4.0)
	Pen.blob(Pen.rrect(Rect2(134, 170, 12, 10), 2), BRASS, 1.5)
	Pen.blob(PackedVector2Array([Vector2(137, 180), Vector2(143, 180), Vector2(142, 188), Vector2(138, 188)]), BRASS, 1.5)
	if _lit:
		Pen.disc(Vector2(140, 194), 2.6, AMBER)


static func _lantern(s: Vector2) -> void:
	if _lit:
		Pen.glow(Vector2(35, 66), Vector2(120, 120), Color(1.0, 0.75, 0.35, 0.35), 24)
	Pen.line(Vector2(35, 0), Vector2(35, 18), METAL, 3.0)
	Pen.ring(Vector2(35, 8), 3.5, METAL, 2.0)
	Pen.dot(Vector2(35, 17), 4.0, METAL, 1.5)
	Pen.blob(PackedVector2Array([Vector2(12, 36), Vector2(58, 36), Vector2(46, 22), Vector2(24, 22)]), METAL, 2.2)
	var glass := Pen.rrect(Rect2(17, 36, 36, 56), 6)
	var cols := PackedColorArray()
	for p in glass:
		cols.append(Color("ffe08a").lerp(Color("ff9a3d"), (p.y - 36.0) / 56.0) if _lit else Color("2c2448"))
	Pen.grad(glass, cols)
	if _lit:
		Pen.flame(Vector2(35, 78), 6.0, 20.0, 0.0)
	for x: float in [17.0, 35.0, 53.0]:
		Pen.line(Vector2(x, 36), Vector2(x, 92), METAL, 3.0)
	Pen.loop(glass, INK, 2.0)
	Pen.line(Vector2(22, 44), Vector2(22, 60), Color(1, 1, 1, 0.5), 2.0)
	Pen.blob(Pen.rrect(Rect2(11, 92, 48, 10), 3), METAL, 2.2)
	Pen.dot(Vector2(35, 108), 4.0, METAL, 1.5)


static func _workbench(s: Vector2) -> void:
	for x: float in [16.0, 178.0]:
		Pen.blob(Pen.rrect(Rect2(x, 108, 16, 92), 3), WOOD_DARK, 2.2)
	Pen.blob(Pen.rrect(Rect2(14, 158, 182, 10), 2), WOOD, 2.0)
	Pen.blob(Pen.rrect(Rect2(0, 94, 210, 18), 4), WOOD, 2.5)
	Pen.line(Vector2(6, 98), Vector2(204, 98), WOOD_LIGHT, 2.0)
	# горелка и круглая колба
	Pen.blob(Pen.rrect(Rect2(38, 80, 26, 14), 3), METAL, 2.0)
	if _lit:
		Pen.flame(Vector2(51, 78), 4.5, 13.0, 0.0)
	Pen.line(Vector2(30, 70), Vector2(26, 94), METAL, 2.5)
	Pen.line(Vector2(72, 70), Vector2(76, 94), METAL, 2.5)
	Pen.line(Vector2(28, 70), Vector2(74, 70), METAL, 3.0)
	_flask(Vector2(51, 68), 22, LIME)
	# штатив с пробирками
	for i in 3:
		var x := 104.0 + i * 16.0
		Pen.blob(Pen.rrect(Rect2(x, 44 + i * 6, 11, 50 - i * 6), 5.5), GLASS, 1.8)
		Pen.soft(Pen.rrect(Rect2(x + 2, 66 + i * 4, 7, 26 - i * 4), 3.5), [MAGENTA, CYAN, AMBER][i])
	Pen.blob(Pen.rrect(Rect2(98, 76, 50, 8), 2), WOOD_LIGHT, 1.8)
	Pen.blob(Pen.rrect(Rect2(98, 88, 50, 6), 2), WOOD_LIGHT, 1.8)
	# ступка с пестиком
	Pen.line(Vector2(178, 88), Vector2(196, 58), WOOD_LIGHT, 5.0)
	var bowl := PackedVector2Array()
	for i in 9:
		bowl.append(Vector2(180, 78) + Vector2.from_angle(PI * i / 8.0) * Vector2(19, 16))
	Pen.blob(bowl, Color("8d8aa3"), 2.2)
	_jar(Vector2(60, 156), 26, 30, VIOLET)
	_bottle(Vector2(130, 156), 18, 40, RED)


static func _window(s: Vector2) -> void:
	var c := Vector2(100, 100)
	var panes: Array[Color] = [VIOLET, Color("3d7bff"), CYAN, MAGENTA, GOLD, Color("4fae5a")]
	var skip := -1 if _lit or Pen.alpha < 1.0 else 2
	for i in 6:
		if i != skip:
			var col := i % 2
			var row := i / 2
			Pen.rect(Rect2(12 + col * 88, 102 + row * 61, 88, 61), Color(panes[(i + row) % 6], 0.62))
	for i in 6:
		var wedge := PackedVector2Array([c])
		for j in 5:
			wedge.append(c + Vector2.from_angle(PI + PI * (i + j / 4.0) / 6.0) * 88.0)
		Pen.poly(wedge, Color(panes[(i + 3) % 6], 0.62))
	Pen.dot(c, 26, Color("233170"), 3.0)
	Pen.soft(Pen.star_pts(c + Vector2(0, -2), 16, 0.42), GOLD)
	Pen.disc(c + Vector2(-5, -8), 3, Color(1, 1, 1, 0.6))
	# свинцовые переплёты и рама
	Pen.line(Vector2(100, 126), Vector2(100, 288), INK, 4.0)
	for y: float in [102.0, 163.0, 224.0]:
		Pen.line(Vector2(12, y), Vector2(188, y), INK, 4.0)
	for i in 5:
		Pen.line(c + Vector2.from_angle(PI + PI * (i + 1) / 6.0) * 26.0, c + Vector2.from_angle(PI + PI * (i + 1) / 6.0) * 88.0, INK, 3.0)
	Pen.loop(_arch(Rect2(0, 0, 200, 290)), WOOD_DARK, 10.0)
	Pen.loop(_arch(Rect2(6, 6, 188, 282)), INK, 2.0)
	for p: Vector2 in [Vector2(40, 140), Vector2(130, 200)]:
		Pen.line(p, p + Vector2(26, -26), Color(1, 1, 1, 0.3), 3.0)


static func _bookcase(s: Vector2) -> void:
	Pen.blob(Pen.rrect(Rect2(0, 44, 190, 396), 6), WOOD_DARK, 2.5)
	Pen.rect(Rect2(12, 58, 166, 370), Color("2a1826"))
	Pen.blob(Pen.rrect(Rect2(-8, 32, 206, 18), 4), WOOD, 2.5)
	Pen.dot(Vector2(150, 12), 17, Color(0.72, 0.55, 1.0, 0.85), 2.2)
	if _lit:
		Pen.glow(Vector2(150, 12), Vector2(46, 46), Color(0.75, 0.5, 1.0, 0.35), 16)
	Pen.disc(Vector2(144, 6), 5, Color(1, 1, 1, 0.55))
	Pen.blob(PackedVector2Array([Vector2(138, 26), Vector2(162, 26), Vector2(166, 33), Vector2(134, 33)]), BRASS, 1.8)
	for row in 4:
		var base := 146.0 + row * 94.0
		var x := 16.0
		var i := row * 11
		while x < 168.0:
			var bw := 11.0 + float((i * 7) % 4) * 3.0
			var bh := 58.0 + float((i * 13) % 5) * 6.0
			var col := BOOKS[(i * 3 + row) % BOOKS.size()]
			if (i * 5 + row) % 9 == 4 and x < 150.0:
				Pen.blob(PackedVector2Array([Vector2(x, base), Vector2(x + bw, base), Vector2(x + bw + 18, base - bh + 6), Vector2(x + 18, base - bh + 6)]), col, 1.5)
				x += bw + 20.0
			else:
				Pen.blob(Pen.rrect(Rect2(x, base - bh, bw, bh), 1.5), col, 1.5)
				Pen.line(Vector2(x + 2, base - bh + 10), Vector2(x + bw - 2, base - bh + 10), Color(1, 1, 1, 0.35), 2.0)
				x += bw + 1.0
			i += 1
		Pen.blob(Pen.rrect(Rect2(6, base, 178, 10), 2), WOOD, 2.0)


static func _rug(s: Vector2) -> void:
	var c := Vector2(180, 55)
	for side: float in [-1.0, 1.0]:
		for i in 7:
			var y := 40.0 + i * 5.0
			Pen.line(Vector2(c.x + side * (176.0 - absf(y - 55.0) * 0.8), y), Vector2(c.x + side * (186.0 - absf(y - 55.0) * 0.8), y), Color("e0b060"), 2.0)
	Pen.blob(Pen.oval(c, Vector2(176, 52), 40), Color("c98a2e"), 2.5)
	Pen.soft(Pen.oval(c, Vector2(164, 45), 40), Color("5b1f5e"))
	Pen.loop(Pen.oval(c, Vector2(122, 33), 36), GOLD, 3.0)
	Pen.loop(Pen.oval(c, Vector2(104, 28), 36), GOLD, 1.5)
	for tri in 2:
		var pts := PackedVector2Array()
		for i in 3:
			var a := -PI / 2.0 + tri * PI / 3.0 + TAU * i / 3.0
			pts.append(c + Vector2(cos(a) * 100.0, sin(a) * 27.0))
		Pen.loop(pts, GOLD, 2.0)
	for i in 12:
		var a := TAU * i / 12.0 + 0.26
		var p := c + Vector2(cos(a) * 113.0, sin(a) * 30.5)
		Pen.line(p + Vector2(-3, -3), p + Vector2(0, 2), MAGENTA if _lit else GOLD, 2.0)
		Pen.line(p + Vector2(0, 2), p + Vector2(3, -3), MAGENTA if _lit else GOLD, 2.0)
	if _lit:
		Pen.glow(c, Vector2(40, 12), Color(1.0, 0.4, 0.9, 0.6), 16)


static func _telescope(s: Vector2) -> void:
	var head := Vector2(80, 116)
	for foot: Vector2 in [Vector2(26, 198), Vector2(84, 200), Vector2(128, 196)]:
		Pen.line(head, foot, INK, 9.0)
		Pen.line(head, foot, WOOD, 5.0)
	var e := Vector2(122, 94)
	var o := Vector2(20, 30)
	var d := (o - e).normalized()
	var n := d.orthogonal()
	var tube := PackedVector2Array([e + n * 7.0, o + n * 12.0, o - n * 12.0, e - n * 7.0])
	Pen.blob(tube, BRASS, 2.5)
	Pen.line(e + n * 4.0, o + n * 8.0, Color("fff1b8"), 2.5)
	for u: float in [0.12, 0.5, 0.88]:
		var p := e.lerp(o, u)
		var hw := lerpf(7.0, 12.0, u) + 1.0
		Pen.line(p + n * hw, p - n * hw, Color("8a5a1c"), 4.0)
	Pen.blob(Pen.oval(o, Vector2(4.5, 12), 14, d.angle()), Color("8ce6ff"), 2.0)
	Pen.blob(PackedVector2Array([e + n * 4.0, e - n * 4.0, e - n * 4.0 - d * 12.0, e + n * 4.0 - d * 12.0]), Color("8a5a1c"), 2.0)
	Pen.line(head, e.lerp(o, 0.45), INK, 7.0)
	Pen.line(head, e.lerp(o, 0.45), METAL, 3.5)
	Pen.dot(head, 6.0, BRASS, 2.0)


static func _alembic(s: Vector2) -> void:
	if _lit:
		Pen.glow(Vector2(120, 250), Vector2(170, 170), Color(1.0, 0.35, 0.85, 0.22), 24)
	# кирпичная печь с огнём
	Pen.blob(Pen.rrect(Rect2(40, 286, 160, 94), 8), Color("7a3a36"), 2.5)
	for row in 3:
		var y := 300.0 + row * 26.0
		Pen.line(Vector2(44, y), Vector2(196, y), Color("4a1f22"), 2.0)
		for bx in 4:
			var x := 62.0 + bx * 40.0 + (20.0 if row % 2 == 1 else 0.0)
			Pen.line(Vector2(x, y), Vector2(x, y + 26), Color("4a1f22"), 2.0)
	var mouth := _arch(Rect2(88, 318, 64, 62))
	Pen.blob(mouth, Color("2a0f10") if not _lit else Color("ff7a1a"), 2.5)
	if _lit:
		Pen.flame(Vector2(106, 378), 9.0, 34.0, -2.0)
		Pen.flame(Vector2(132, 378), 8.0, 28.0, 2.0)
	# медный котёл с окошком
	var pot := Pen.oval(Vector2(120, 226), Vector2(74, 68), 36)
	var cols := PackedColorArray()
	for p in pot:
		cols.append(Color("f0a060").lerp(Color("8a3f1c"), clampf((p.y - 158.0) / 136.0 + (p.x - 120.0) / 300.0, 0.0, 1.0)))
	Pen.grad(pot, cols)
	Pen.loop(pot, INK, 3.0)
	Pen.arc(Vector2(120, 226), 60, PI + 0.5, PI + 1.3, Color(1, 0.85, 0.7, 0.6), 4.0, 10)
	for i in 9:
		Pen.disc(Vector2(120, 226) + Vector2.from_angle(PI * 0.15 + PI * 0.7 * i / 8.0) * Vector2(66, 58), 2.2, Color("8a3f1c"))
	Pen.dot(Vector2(120, 236), 30, Color("2a1a3e"), 3.0)
	Pen.soft(_segment(Vector2(120, 236), 27, 0.25), MAGENTA if _lit else Color("7a4a7a"))
	if _lit:
		for b: Vector3 in [Vector3(110, 246, 3), Vector3(128, 238, 2.2), Vector3(120, 254, 2.6)]:
			Pen.ring(Vector2(b.x, b.y), b.z, Color(1, 1, 1, 0.7), 1.2)
	Pen.ring(Vector2(120, 236), 30, BRASS, 4.0)
	Pen.arc(Vector2(120, 236), 22, PI + 0.6, PI + 1.4, Color(1, 1, 1, 0.5), 3.0, 8)
	# горлышко, стеклянный шлем и носик в приёмник
	Pen.blob(Pen.rrect(Rect2(104, 142, 32, 22), 3), COPPER, 2.2)
	var spout := Pen.smooth([Vector2(146, 100), Vector2(190, 118), Vector2(212, 176), Vector2(212, 262)])
	Pen.pline(spout, INK, 13.0)
	Pen.pline(spout, Color("c9e6f5"), 8.0)
	_orb(Vector2(120, 108), 40, Color(LIME, 0.55 if _lit else 0.3), 0.55, 3.0)
	Pen.dot(Vector2(120, 64), 7.0, COPPER, 2.0)
	# приёмник на табурете
	Pen.blob(Pen.rrect(Rect2(190, 326, 46, 10), 2), WOOD, 2.0)
	Pen.line(Vector2(196, 336), Vector2(194, 380), WOOD_DARK, 5.0)
	Pen.line(Vector2(230, 336), Vector2(232, 380), WOOD_DARK, 5.0)
	if _lit:
		Pen.glow(Vector2(213, 300), Vector2(46, 46), Color(0.5, 1.0, 0.3, 0.3), 16)
	_orb(Vector2(213, 300), 24, LIME if _lit else Color("5a7a4a"), 0.1, 2.5)


# --- мелкие предметы --------------------------------------------------------

static func _bottle(base: Vector2, w: float, h: float, liquid: Color) -> void:
	var body := Pen.rrect(Rect2(base.x - w * 0.5, base.y - h * 0.72, w, h * 0.72), w * 0.3)
	Pen.soft(Pen.rrect(Rect2(base.x - w * 0.5 + 2, base.y - h * 0.45, w - 4, h * 0.45 - 2), w * 0.25), liquid)
	Pen.blob(body, GLASS, 2.0)
	Pen.blob(Pen.rrect(Rect2(base.x - w * 0.18, base.y - h, w * 0.36, h * 0.3), 2), GLASS, 2.0)
	Pen.blob(Pen.rrect(Rect2(base.x - w * 0.22, base.y - h - 5, w * 0.44, 7), 2), WOOD_LIGHT, 1.5)
	Pen.line(Vector2(base.x - w * 0.28, base.y - h * 0.62), Vector2(base.x - w * 0.28, base.y - h * 0.3), Color(1, 1, 1, 0.55), 2.0)


static func _flask(base: Vector2, r: float, liquid: Color) -> void:
	var c := base - Vector2(0, r)
	if _lit:
		Pen.glow(c, Vector2(r * 2.0, r * 2.0), Color(liquid, 0.3), 16)
	Pen.blob(Pen.rrect(Rect2(c.x - r * 0.28, c.y - r * 1.9, r * 0.56, r * 1.2), 2), GLASS, 2.0)
	_orb(c, r, liquid, 0.35, 2.0)
	if _lit:
		Pen.ring(c + Vector2(-r * 0.25, r * 0.3), r * 0.12, Color(1, 1, 1, 0.7), 1.2)
		Pen.ring(c + Vector2(r * 0.2, r * 0.1), r * 0.08, Color(1, 1, 1, 0.7), 1.2)


static func _jar(base: Vector2, w: float, h: float, col: Color) -> void:
	Pen.soft(Pen.rrect(Rect2(base.x - w * 0.5 + 2, base.y - h * 0.7, w - 4, h * 0.7 - 2), 4), col)
	Pen.blob(Pen.rrect(Rect2(base.x - w * 0.5, base.y - h, w, h), 5), GLASS, 2.0)
	Pen.blob(Pen.rrect(Rect2(base.x - w * 0.5 - 2, base.y - h - 6, w + 4, 8), 2), WOOD, 1.8)
	Pen.line(Vector2(base.x - w * 0.3, base.y - h + 8), Vector2(base.x - w * 0.3, base.y - 10), Color(1, 1, 1, 0.5), 2.0)


## Стеклянный шар с жидкостью до уровня level и бликом.
static func _orb(c: Vector2, r: float, liquid: Color, level: float, w: float) -> void:
	Pen.disc(c, r, GLASS)
	Pen.soft(_segment(c, r - w, level), liquid)
	Pen.ring(c, r, INK, w)
	Pen.arc(c, r * 0.72, PI + 0.55, PI + 1.35, Color(1, 1, 1, 0.6), w + 1.0, 8)


## Нижний сегмент круга (жидкость): level 0 — полный, 1 — пустой.
static func _segment(c: Vector2, r: float, level: float) -> PackedVector2Array:
	var y := lerpf(-r, r, level)
	var a := asin(clampf(y / r, -1.0, 1.0))
	var pts := PackedVector2Array()
	for i in 17:
		pts.append(c + Vector2.from_angle(lerpf(a, PI - a, i / 16.0)) * r)
	return pts


static func _arch(r: Rect2) -> PackedVector2Array:
	var rad := r.size.x * 0.5
	var c := r.position + Vector2(rad, rad)
	var pts := PackedVector2Array([Vector2(r.position.x, r.end.y), r.end])
	for i in 17:
		pts.append(c + Vector2.from_angle(TAU - PI * i / 16.0) * rad)
	return pts


# --- состояния --------------------------------------------------------------

static func _cracks(s: Vector2, seed: int) -> void:
	for n in 2:
		var p := Vector2(s.x * (0.25 + 0.5 * n), s.y * (0.2 + 0.15 * ((seed >> n) & 1)))
		var pts := PackedVector2Array([p])
		for i in 4:
			p += Vector2((12.0 if (i + n) % 2 == 0 else -10.0), s.y * 0.09)
			pts.append(p)
		Pen.pline(pts, Color(0.06, 0.03, 0.1, 0.85), 2.5)
		Pen.pline(Transform2D(0.0, Vector2(1.5, 0)) * pts, Color(1, 1, 1, 0.18), 1.0)


static func _web(corner: Vector2, size: float, right: bool) -> void:
	var dir := Vector2(-1 if right else 1, 1)
	var col := Color(0.92, 0.9, 1.0, 0.5)
	var ends: Array[Vector2] = []
	for i in 4:
		var e := corner + Vector2.from_angle(PI * 0.5 * i / 3.0) * size * dir
		ends.append(e)
		Pen.line(corner, e, col, 1.2)
	for ring in 3:
		var f := 0.35 + ring * 0.25
		var pts := PackedVector2Array()
		for e in ends:
			pts.append(corner.lerp(e, f))
		Pen.pline(Pen.smooth(Array(pts), 2), col, 1.0)


## Пульсирующая пунктирная рамка и звёздочка-ярлык над слотом.
static func _ghost_frame(s: Vector2, t: float) -> void:
	var a := 0.65 + 0.35 * sin(t * 4.0)
	var path := Pen.rrect(Rect2(Vector2(-6, -6), s + Vector2(12, 12)), 18, 4)
	path.append(path[0])
	var dash := 18.0
	var gap := 10.0
	var off := fmod(t * 30.0, dash + gap)
	for i in path.size() - 1:
		var p0 := path[i]
		var seg := path[i + 1] - p0
		var len := seg.length()
		var u := -off
		while u < len:
			var u0 := maxf(u, 0.0)
			var u1 := minf(u + dash, len)
			if u1 > u0:
				Pen.line(p0 + seg * (u0 / len), p0 + seg * (u1 / len), Color(1.0, 0.9, 0.5, a), 3.5)
			u += dash + gap
		off = fmod(off + len, dash + gap)
	var tag := Vector2(s.x - 4, -4 + sin(t * 3.0) * 4.0)
	Pen.glow(tag, Vector2(40, 40), Color(1.0, 0.85, 0.3, 0.4 * a), 16)
	Pen.dot(tag, 20, Color("2a2147"), 3.0)
	Pen.star(tag, 14, GOLD, 2.0)
	Pen.disc(tag + Vector2(-4, -5), 2.2, Color(1, 1, 1, 0.8))
