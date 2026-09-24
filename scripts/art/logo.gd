class_name Logo
extends Control
## Логотип: колба с иконки приложения (в 4 раза крупнее) с пузырьками и название игры
## золотом с толстым чернильным контуром; маленький засов пронзает «и» / «&».
## progress >= 0 — уровень жидкости на экране загрузки (0..1), -1 — как на иконке.
## Всё вписывается в размер узла с сохранением пропорций DESIGN.

const DESIGN := Vector2(600, 380)
const FALLBACK_TITLE := "Зелья и засовы"
const INK := Color("1b1236")
const GOLD := Color("f5c542")
const GOLD_DARK := Color("a8741a")
const GOLD_LIGHT := Color("fff1b8")
const GLASS := Color(0.165, 0.13, 0.28, 0.92)
# колба в координатах иконки 108x108: центр, радиус, дно
const C := Vector2(54, 68)
const R := 17.0
const BOTTOM := 85.0
const ICON_LEVEL := 63.0

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
	# союз «и» / «&» выделяется цветом зелья, вокруг него место для засова
	var parts := [_title, "", ""]
	for sep: String in [" и ", " & ", " and ", " И "]:
		var at := _title.find(sep)
		if at >= 0:
			parts = [_title.substr(0, at + 1), sep.strip_edges(), _title.substr(at + sep.length() - 1)]
			break
	var fs := 64
	var gap := 20.0
	var w := _width(parts, fs, gap)
	if w > DESIGN.x - 40.0:
		fs = int(fs * (DESIGN.x - 40.0) / w)
		gap *= fs / 64.0
		w = _width(parts, fs, gap)
	var base := Vector2((DESIGN.x - w) * 0.5, 262.0 + _font.get_ascent(fs))
	var x := base.x
	for i in 3:
		if parts[i] == "":
			continue
		if i == 2:
			x += gap
		var p := Vector2(x, base.y)
		var s: String = parts[i]
		Pen.text(_font, p + Vector2(0, 7), s, fs, Color(0, 0, 0, 0.35), 22)
		Pen.text(_font, p, s, fs, INK, 20)
		Pen.text(_font, p + Vector2(0, 4), s, fs, GOLD_DARK if i != 1 else Color("a3208c"))
		Pen.text(_font, p + Vector2(0, -1.5), s, fs, GOLD_LIGHT if i != 1 else Color("ffc2f2"))
		Pen.text(_font, p, s, fs, GOLD if i != 1 else Color("ff5ad9"))
		var sw := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if i == 1:
			_pin(Vector2(x - gap * 0.35, base.y - fs * 0.3), x + sw + gap * 0.3, fs / 64.0)
		x += sw
		if i == 0 and parts[1] != "":
			x += gap
	if parts[1] == "":
		_pin(Vector2(DESIGN.x * 0.5 - w * 0.3, base.y + 20.0), DESIGN.x * 0.5 + w * 0.3, fs / 64.0)
	Pen.end()


func _width(parts: Array, fs: int, gap: float) -> float:
	var w := 0.0
	for s: String in parts:
		w += _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w + (gap * 2.0 if parts[1] != "" else 0.0)


## Тонкий засов с кольцом слева: a — кольцо, до x_end — стержень.
func _pin(a: Vector2, x_end: float, s: float) -> void:
	var b := Vector2(x_end, a.y)
	var ring := a - Vector2(7, 0) * s
	Pen.line(a, b, INK, 10.0 * s)
	Pen.ring(ring, 6.5 * s, INK, 9.0 * s)
	Pen.line(a, b, GOLD_DARK, 6.0 * s)
	Pen.disc(b, 3.0 * s, GOLD_DARK)
	Pen.line(a + Vector2(0, -1) * s, b + Vector2(0, -1) * s, GOLD, 3.0 * s)
	Pen.ring(ring, 6.5 * s, GOLD_DARK, 5.0 * s)
	Pen.ring(ring, 6.5 * s, GOLD, 2.5 * s)


# --- колба ---------------------------------------------------------------------

func _paint_flask(ci: CanvasItem) -> void:
	# координаты иконки 108x108, вершина шляпы (y=23) у верхнего края DESIGN
	Pen.begin(ci, _fit() * Transform2D(0.0, Vector2(4, 4), 0.0, Vector2(300 - 54 * 4, -92)))
	for p: Vector3 in [Vector3(26, 30, 0.0), Vector3(84, 34, 2.1), Vector3(80, 80, 4.2)]:
		var tw := 0.6 + 0.4 * sin(_t * 2.2 + p.z)
		Pen.sparkle(Vector2(p.x, p.y), 3.8 * tw, Color(1.0, 0.89, 0.48, 0.85 * tw))
	Pen.glow(Vector2(56, 67), Vector2(21, 21), Color(1.0, 0.54, 0.16, 0.55 + 0.1 * sin(_t * 3.0)), 20)
	Pen.disc(C, R, GLASS)
	var level := ICON_LEVEL if progress < 0.0 else lerpf(BOTTOM - 0.5, 53.5, clampf(progress, 0.0, 1.0))
	if level < BOTTOM - 1.0:
		_liquid(level)
	Pen.ring(C, R, INK, 3.0)
	Pen.arc(C, 13.5, PI * 1.2, PI * 1.4, Color(1, 1, 1, 0.6), 2.5, 8)
	Pen.rect(Rect2(48.5, 43, 11, 10.5), GLASS)
	Pen.line(Vector2(48.5, 43), Vector2(48.5, 52), INK, 3.0)
	Pen.line(Vector2(59.5, 43), Vector2(59.5, 52), INK, 3.0)
	Pen.blob(Pen.rrect(Rect2(45.5, 40, 17, 4.5), 2.0, 2), Color("9d8fd0"), 2.0)
	# штырь через горлышко
	Pen.line(Vector2(35, 47.5), Vector2(79, 47.5), INK, 7.5)
	Pen.ring(Vector2(31, 47.5), 4.5, INK, 7.0)
	Pen.line(Vector2(35, 47.5), Vector2(79, 47.5), GOLD_DARK, 5.0)
	Pen.line(Vector2(36, 46.6), Vector2(78, 46.6), GOLD, 2.5)
	Pen.ring(Vector2(31, 47.5), 4.5, GOLD_DARK, 4.5)
	Pen.ring(Vector2(31, 47.5), 4.5, GOLD, 2.5)
	# шляпа Мирры чуть покачивается
	Pen.push(Transform2D(sin(_t * 1.7) * 0.05, Vector2(54, 39.5)) * Transform2D(0.0, Vector2(-54, -39.5)))
	Pen.blob(Pen.oval(Vector2(54, 39.5), Vector2(12, 3), 20), Color("5427b8"), 2.0)
	var cone := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 9:
		var p := Pen.qbez(Vector2(45, 39), Vector2(51, 32), Vector2(57, 23), i / 8.0)
		cone.append(p)
	for i in range(7, 0, -1):
		cone.append(Pen.qbez(Vector2(63, 39), Vector2(59, 31), Vector2(57, 23), i / 8.0))
	for p in cone:
		cols.append(Color("a878ff").lerp(Color("6a36d8"), (p.y - 23.0) / 16.0))
	Pen.grad(cone, cols)
	Pen.loop(cone, Color("24163d"), 2.0)
	Pen.pline(Pen.smooth([Vector2(46.6, 37.2), Vector2(54, 36.2), Vector2(61.8, 37.2)], 3), GOLD, 1.6)
	Pen.soft(Pen.star_pts(Vector2(55.4, 32.2), 2.9), Color("ffc933"))
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
