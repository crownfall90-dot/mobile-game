class_name Logo
extends Control
## Логотип: колба с иконки приложения (в 3,5 раза крупнее) с пузырьками и название игры
## золотом с толстым чернильным контуром; маленький засов продет за «и» / «&».
## У колбы длиннее горлышко, чем на иконке: на тёмном фоне видно и пробку, и горлышко
## между засовом и шаром, а светлая кромка отделяет стекло от фона.
## progress >= 0 — уровень жидкости на экране загрузки (0..1), -1 — как на иконке.
## Всё вписывается в размер узла с сохранением пропорций DESIGN.

const DESIGN := Vector2(600, 380)
const FALLBACK_TITLE := "Зелья и засовы"
const INK := Color("1b1236")
const GOLD := Color("f5c542")
const GOLD_DARK := Color("a8741a")
const GOLD_LIGHT := Color("fff1b8")
const GLASS := Color(0.165, 0.13, 0.28, 0.92)
const RIM := Color(0.62, 0.56, 0.82, 0.9)      # светлая кромка стекла (#9d8fd0)
# колба в координатах иконки 108x108: центр, радиус, дно, горлышко, засов
const C := Vector2(54, 70)
const R := 17.0
const BOTTOM := 87.0
const ICON_LEVEL := 65.0
const NECK := Rect2(48.5, 36.0, 11.0, 19.0)
const PIN_Y := 44.5
const HAT_Y := 31.0      # центр полей шляпы
const SCALE := 3.5
const TITLE_Y := 270.0
const GAP_L := 0.56      # зазоры вокруг союза в долях кегля: слева кольцо засова
const GAP_R := 0.42

var progress := -1.0

var _t := 0.0
var _flask: Pen.Canvas
var _font: FontVariation
var _title := ""


func _init() -> void:
	custom_minimum_size = DESIGN * 0.4
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.6
	_flask = Pen.Canvas.new()
	_flask.paint = _paint_flask
	add_child(_flask)


func _ready() -> void:
	var loc := get_node_or_null("/root/Loc")
	if loc and loc.has_signal("lang_changed"):
		loc.connect("lang_changed", _update_title)
	resized.connect(queue_redraw)
	_update_title()
	if DisplayServer.get_name() == "headless":
		set_process(false)


func _update_title() -> void:
	_title = FALLBACK_TITLE
	var loc := get_node_or_null("/root/Loc")
	if loc and loc.has_method("t"):
		var s := str(loc.call("t", "app.title"))
		if s != "" and s != "app.title":
			_title = s
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_flask.queue_redraw()


## Масштаб и сдвиг, чтобы DESIGN вписался в текущий размер узла.
func _fit() -> Transform2D:
	var sz := size if size.x > 1.0 and size.y > 1.0 else DESIGN
	var s := minf(sz.x / DESIGN.x, sz.y / DESIGN.y)
	return Transform2D(0.0, Vector2(s, s), 0.0, (sz - DESIGN * s) * 0.5)


# --- название ------------------------------------------------------------------

func _draw() -> void:
	Pen.begin(self, _fit())
	# союз «и» / «&» выделяется цветом зелья; засов продет за него, как в уровнях
	var parts := [_title, "", ""]
	for sep: String in [" и ", " & ", " and ", " И "]:
		var at := _title.find(sep)
		if at >= 0:
			parts = [_title.substr(0, at), sep.strip_edges(), _title.substr(at + sep.length())]
			break
	var fs := 64
	var w := _width(parts, fs)
	if w > DESIGN.x - 40.0:
		fs = int(fs * (DESIGN.x - 40.0) / w)
		w = _width(parts, fs)
	var k := fs / 64.0
	var base := Vector2((DESIGN.x - w) * 0.5, TITLE_Y + _font.get_ascent(fs))
	var widths: Array[float] = []
	for part: String in parts:
		widths.append(_font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var joined: bool = parts[1] != ""
	# кольцо в зазоре слева, стержень за союзом (буквы рисуются поверх), кончик справа
	var x0 := base.x + widths[0] + fs * GAP_L
	var pin_a := Vector2(x0 - fs * GAP_L * 0.5, base.y + fs * 0.02)
	var pin_b := Vector2(x0 + widths[1] + fs * GAP_R * 0.45, pin_a.y)
	if not joined:
		pin_a = Vector2(DESIGN.x * 0.5 - w * 0.3, base.y + 20.0 * k)
		pin_b = Vector2(DESIGN.x * 0.5 + w * 0.3, pin_a.y)
	_pin_shaft(pin_a, pin_b, k)
	var x := base.x
	for i in 3:
		if parts[i] == "":
			continue
		var p := Vector2(x, base.y)
		var s: String = parts[i]
		Pen.text(_font, p + Vector2(0, 7), s, fs, Color(0, 0, 0, 0.35), 22)
		Pen.text(_font, p, s, fs, INK, 20)
		Pen.text(_font, p + Vector2(0, 4), s, fs, GOLD_DARK if i != 1 else Color("a3208c"))
		Pen.text(_font, p + Vector2(0, -1.5), s, fs, GOLD_LIGHT if i != 1 else Color("ffc2f2"))
		Pen.text(_font, p, s, fs, GOLD if i != 1 else Color("ff5ad9"))
		x += widths[i] + fs * (GAP_L if i == 0 else GAP_R)
	var tip_from := pin_a.x if not joined else x0 + widths[1] + 2.0 * k
	_pin_ends(pin_a, pin_b, tip_from, k)
	Pen.end()


func _width(parts: Array, fs: int) -> float:
	var w := 0.0
	for s: String in parts:
		w += _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w + (fs * (GAP_L + GAP_R) if parts[1] != "" else 0.0)


## Стержень засова от a до b; рисуется до букв, поэтому уходит за союз, а не зачёркивает его.
func _pin_shaft(a: Vector2, b: Vector2, s: float) -> void:
	Pen.line(a, b, INK, 14.0 * s)
	Pen.line(a, b, GOLD_DARK, 9.0 * s)
	Pen.line(a + Vector2(0, -1.5) * s, b + Vector2(0, -1.5) * s, GOLD, 4.5 * s)
	Pen.line(a + Vector2(0, -3.0) * s, b + Vector2(0, -3.0) * s, GOLD_LIGHT, 1.5 * s)


## Кольцо-ручка у a и заострённый кончик от x_from до b — поверх букв, как у засовов в уровнях.
func _pin_ends(a: Vector2, b: Vector2, x_from: float, s: float) -> void:
	var ring := a - Vector2(6.0, 0) * s
	var t := Vector2(x_from, b.y)
	var point := PackedVector2Array([b + Vector2(-2, -4.5) * s, b + Vector2(7, 0) * s, b + Vector2(-2, 4.5) * s])
	Pen.ring(ring, 9.0 * s, INK, 12.0 * s)
	Pen.line(t, b, INK, 14.0 * s)
	Pen.blob(point, GOLD_DARK, 5.0 * s)
	Pen.line(t, b, GOLD_DARK, 9.0 * s)
	Pen.poly(point, GOLD_DARK)
	Pen.line(t + Vector2(0, -1.5) * s, b + Vector2(0, -1.5) * s, GOLD, 4.5 * s)
	Pen.line(t + Vector2(0, -3.0) * s, b + Vector2(0, -3.0) * s, GOLD_LIGHT, 1.5 * s)
	Pen.ring(ring, 9.0 * s, GOLD_DARK, 7.5 * s)
	Pen.ring(ring, 9.0 * s, GOLD, 4.0 * s)
	Pen.arc(ring, 9.5 * s, PI * 1.1, PI * 1.6, GOLD_LIGHT, 1.5 * s, 8)


# --- колба ---------------------------------------------------------------------

func _paint_flask(ci: CanvasItem) -> void:
	# координаты иконки 108x108, вершина шляпы у верхнего края DESIGN
	var top := HAT_Y - 16.5
	Pen.begin(ci, _fit() * Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2(300 - 54 * SCALE, 2.0 - top * SCALE)))
	for p: Vector3 in [Vector3(27, 30, 0.0), Vector3(83, 27, 2.1), Vector3(81, 80, 4.2)]:
		var tw := 0.6 + 0.4 * sin(_t * 2.2 + p.z)
		Pen.sparkle(Vector2(p.x, p.y), 3.8 * tw, Color(1.0, 0.89, 0.48, 0.85 * tw))
	Pen.glow(C + Vector2(2, -1), Vector2(21, 21), Color(1.0, 0.54, 0.16, 0.55 + 0.1 * sin(_t * 3.0)), 20)
	Pen.disc(C, R, GLASS)
	var level := ICON_LEVEL if progress < 0.0 else lerpf(BOTTOM - 0.5, C.y - R + 2.5, clampf(progress, 0.0, 1.0))
	if level < BOTTOM - 1.0:
		_liquid(level)
	Pen.ring(C, R, INK, 3.0)
	Pen.arc(C, R - 1.9, 0.0, TAU, RIM, 1.1, 40)
	Pen.arc(C, 13.5, PI * 1.2, PI * 1.4, Color(1, 1, 1, 0.6), 2.5, 8)
	# горлышко открывается в шар: заливка перекрывает верх его контура
	var neck_bottom := C.y - sqrt(R * R - 5.5 * 5.5)
	Pen.rect(Rect2(NECK.position, Vector2(NECK.size.x, neck_bottom + 1.0 - NECK.position.y)), GLASS)
	for x: float in [NECK.position.x, NECK.end.x]:
		Pen.line(Vector2(x, NECK.position.y), Vector2(x, neck_bottom), INK, 3.0)
		var inner := x + (1.9 if x < C.x else -1.9)
		Pen.line(Vector2(inner, NECK.position.y + 1.5), Vector2(inner, neck_bottom + 0.5), RIM, 1.1)
	Pen.blob(Pen.rrect(Rect2(46.5, NECK.position.y - 5.0, 15, 5.5), 2.0, 2), Color("b9acec"), 2.0)
	# штырь через горлышко
	Pen.line(Vector2(35, PIN_Y), Vector2(79, PIN_Y), INK, 7.0)
	Pen.ring(Vector2(31, PIN_Y), 4.5, INK, 7.0)
	Pen.line(Vector2(35, PIN_Y), Vector2(79, PIN_Y), GOLD_DARK, 4.6)
	Pen.line(Vector2(36, PIN_Y - 0.8), Vector2(78, PIN_Y - 0.8), GOLD, 2.3)
	Pen.ring(Vector2(31, PIN_Y), 4.5, GOLD_DARK, 4.5)
	Pen.ring(Vector2(31, PIN_Y), 4.5, GOLD, 2.5)
	# шляпа Мирры чуть покачивается
	var brim := Vector2(54, HAT_Y)
	Pen.push(Transform2D(sin(_t * 1.7) * 0.05, brim) * Transform2D(0.0, -brim))
	Pen.blob(Pen.oval(brim, Vector2(12, 3), 20), Color("5427b8"), 2.0)
	var tip := brim + Vector2(3, -16.5)
	var cone := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 9:
		cone.append(Pen.qbez(brim + Vector2(-9, -0.5), brim + Vector2(-3, -7.5), tip, i / 8.0))
	for i in range(7, 0, -1):
		cone.append(Pen.qbez(brim + Vector2(9, -0.5), brim + Vector2(5, -8.5), tip, i / 8.0))
	for p in cone:
		cols.append(Color("a878ff").lerp(Color("6a36d8"), (p.y - tip.y) / 16.0))
	Pen.grad(cone, cols)
	Pen.loop(cone, Color("24163d"), 2.0)
	Pen.pline(Pen.smooth([brim + Vector2(-7.4, -2.3), brim + Vector2(0, -3.3), brim + Vector2(7.8, -2.3)], 3), GOLD, 1.6)
	Pen.soft(Pen.star_pts(brim + Vector2(1.4, -7.3), 2.9), Color("ffc933"))
	Pen.end()


## Вода слева и лава справа, между ними каменный шов; поверхность чуть колышется.
func _liquid(level: float) -> void:
	var hw := sqrt(maxf(R * R - (level - C.y) * (level - C.y), 0.0))
	var seam := PackedVector2Array()
	for i in 9:
		var y := lerpf(BOTTOM, level, i / 8.0)
		seam.append(Vector2(C.x + 1.4 * sin(y * 1.1) * clampf((BOTTOM - y) / 3.0, 0.0, 1.0), y))
	seam[8] = Vector2(C.x, _surface_y(C.x, level, hw))
	for side in 2:
		var sgn := -1.0 if side == 0 else 1.0
		var pts := PackedVector2Array()
		for i in 7:
			var x := C.x + sgn * hw * i / 6.0
			pts.append(Vector2(x, _surface_y(x, level, hw)))
		var a0 := atan2(level - C.y, sgn * hw)
		for j in range(1, 11):
			pts.append(C + Vector2.from_angle(lerp_angle(a0, PI * 0.5, j / 10.0)) * R)
		for i in range(1, 8):
			pts.append(seam[i])
		var top := Color("8ce6ff") if side == 0 else Color("ffdb4d")
		var bot := Color("1a6bfa") if side == 0 else Color("f2380f")
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bot, clampf((p.y - level) / maxf(BOTTOM - level, 1.0), 0.0, 1.0)))
		Pen.grad(pts, cols)
		# пузырьки: в воде колечки, в лаве светлые искры
		for b in 3:
			var ph := fmod(_t * (0.35 + b * 0.12) + b * 0.37 + side * 0.5, 1.0)
			var y := lerpf(BOTTOM - 2.0, level + 1.5, ph)
			var half := sqrt(maxf(R * R - (y - C.y) * (y - C.y), 0.0))
			var x := C.x + sgn * clampf(3.0 + b * 4.0 + sin(_t * 2.0 + b) * 1.2, 2.5, maxf(half - 2.0, 2.5))
			if y > level + 1.0:
				if side == 0:
					Pen.ring(Vector2(x, y), 0.9 + b * 0.25, Color(1, 1, 1, 0.8), 0.45)
				else:
					Pen.disc(Vector2(x, y), 0.7 + b * 0.2, Color(1.0, 0.96, 0.75, 0.85))
	Pen.pline(seam, Color("4a4760"), 3.4)
	Pen.pline(seam, Color("8d8aa3"), 2.2)
	var line := PackedVector2Array()
	for i in 13:
		var x := C.x - hw + 2.0 * hw * i / 12.0
		line.append(Vector2(x, _surface_y(x, level, hw)))
	Pen.pline(line, Color(1, 1, 1, 0.5), 1.2)


func _surface_y(x: float, level: float, hw: float) -> float:
	var taper := clampf((hw - absf(x - C.x)) / 3.0, 0.0, 1.0)
	return level + sin(x * 0.9 + _t * 3.0) * 0.5 * taper
