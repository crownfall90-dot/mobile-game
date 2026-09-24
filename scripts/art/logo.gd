class_name Logo
extends Control
## Логотип: колба с иконки приложения (в 3,5 раза крупнее) с пузырьками и название игры
## золотом с толстым чернильным контуром. Маленький засов продет сквозь «и» / «&»: лежит
## поверх союза, чуть поднимаясь вправо, кольцо и кончик — в зазорах по бокам.
## У колбы длиннее горлышко, чем на иконке: на тёмном фоне видно и пробку, и горлышко
## между засовом и шаром, а светлая кромка отделяет стекло от фона.
## progress >= 0 — уровень жидкости на экране загрузки (0..1), -1 — как на иконке.
## Всё вписывается в размер узла с сохранением пропорций DESIGN.
## Колба разложена на холсты. Стекло, горлышко, засов, шляпа и название перерисовываются
## только при смене размера, языка или масштаба пикселя; 30 раз в секунду — лишь жидкость
## с пузырьками и искорки. Свечение пульсирует через modulate, шляпа качается поворотом.

const DESIGN := Vector2(600, 380)
const FALLBACK_TITLE := "Зелья и засовы"
const INK := Color("1b1236")
const GOLD := Color("f5c542")
const GOLD_DARK := Color("a8741a")
const GOLD_LIGHT := Color("fff1b8")
const GLASS := Color(0.165, 0.13, 0.28, 0.92)
const RIM := Color(0.62, 0.56, 0.82, 0.9)      # светлая кромка стекла (#9d8fd0)
# колба в координатах иконки 108x108: центр, радиус, дно, горлышко, засов, поля шляпы
const C := Vector2(54, 70)
const R := 17.0
const BOTTOM := 87.0
const ICON_LEVEL := 65.0
const NECK := Rect2(48.5, 36.0, 11.0, 19.0)
const PIN_Y := 44.5
const BRIM := Vector2(54, 31)
const SCALE := 3.5
const TITLE_Y := 270.0
const GAP_L := 0.42      # зазоры вокруг союза в долях кегля: слева кольцо, справа кончик
const GAP_R := 0.32
const PIN_UP := 0.2      # кольцо чуть ниже середины строчных букв
const PIN_TILT := 0.12   # засов слегка поднимается вправо, чтобы не читаться зачёркиванием

var progress := -1.0

var _t := 0.0
var _tick := -1
var _drawn_k := 0.0
var _prev_k := 0.0
var _glow: Pen.Canvas
var _anim: Pen.Canvas
var _front: Pen.Canvas
var _hat: Pen.Canvas
var _font: FontVariation
var _title := ""


func _init() -> void:
	custom_minimum_size = DESIGN * 0.4
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = FontVariation.new()
	_font.base_font = ThemeDB.fallback_font
	_font.variation_embolden = 0.6
	_glow = _canvas(_paint_glow)
	_anim = _canvas(_paint_anim)
	_front = _canvas(_paint_front)
	_hat = _canvas(_paint_hat)


func _canvas(paint: Callable) -> Pen.Canvas:
	var c := Pen.Canvas.new()
	c.paint = paint
	add_child(c)
	return c


func _ready() -> void:
	var loc := get_node_or_null("/root/Loc")
	if loc and loc.has_signal("lang_changed"):
		loc.connect("lang_changed", _update_title)
	resized.connect(_redraw_all)
	_update_title()
	_redraw_all()
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


## Всё статичное заново: название, холсты колбы и точка качания шляпы.
func _redraw_all() -> void:
	_hat.position = _flask_xf() * BRIM
	queue_redraw()
	for c: Pen.Canvas in [_glow, _anim, _front, _hat]:
		c.queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	# сглаживание и кегль запечены под масштаб пикселя: когда он устоялся на новом значении
	# (конец анимации всплывающего окна 0.6 -> 1), всё статичное рисуется заново; на каждом
	# шаге анимации — нет, новые кегли шрифта дорого растеризовать
	var k := Pen.pixel_scale(self)
	if k != _drawn_k and k == _prev_k:
		_redraw_all()
	_prev_k = k
	_glow.modulate.a = 0.85 + 0.15 * sin(_t * 3.0)
	_hat.rotation = sin(_t * 1.7) * 0.05
	if int(_t * 30.0) != _tick:
		_tick = int(_t * 30.0)
		_anim.queue_redraw()


## Масштаб и сдвиг, чтобы DESIGN вписался в текущий размер узла.
func _fit() -> Transform2D:
	var sz := size if size.x > 1.0 and size.y > 1.0 else DESIGN
	var s := minf(sz.x / DESIGN.x, sz.y / DESIGN.y)
	return Transform2D(0.0, Vector2(s, s), 0.0, (sz - DESIGN * s) * 0.5)


## Координаты иконки 108x108 → узел; вершина шляпы у верхнего края DESIGN.
func _flask_xf() -> Transform2D:
	var top := BRIM.y - 16.5
	return _fit() * Transform2D(0.0, Vector2(SCALE, SCALE), 0.0, Vector2(300 - 54 * SCALE, 2.0 - top * SCALE))


# --- название ------------------------------------------------------------------

func _draw() -> void:
	_drawn_k = Pen.pixel_scale(self)
	Pen.begin(self, _fit(), _drawn_k)
	# союз «и» / «&» выделяется цветом зелья, засов продет сквозь него
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
	var joined: bool = parts[1] != ""
	var xs: Array[float] = []
	var x := (DESIGN.x - w) * 0.5
	for i in 3:
		xs.append(x)
		x += _font.get_string_size(parts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if joined and i < 2:
			x += fs * (GAP_L if i == 0 else GAP_R)
	var base_y := TITLE_Y + _font.get_ascent(fs)
	# кольцо в левом зазоре, кончик в правом; без союза засов лежит под всем названием
	var a := Vector2(xs[1] - fs * GAP_L * 0.5, base_y - fs * PIN_UP)
	var b := Vector2(xs[2] - fs * GAP_R * 0.62, a.y)
	b.y -= (b.x - a.x) * PIN_TILT
	if not joined:
		a = Vector2(DESIGN.x * 0.5 - w * 0.3, base_y + 20.0 * k)
		b = Vector2(DESIGN.x * 0.5 + w * 0.3, a.y)
	for i in 3:
		if parts[i] != "":
			Pen.text(_font, Vector2(xs[i], base_y + 7.0), parts[i], fs, Color(0, 0, 0, 0.35), 22)
	for i in 3:
		if parts[i] != "":
			Pen.text(_font, Vector2(xs[i], base_y), parts[i], fs, INK, 20)
	for i in 3:
		if parts[i] == "":
			continue
		var p := Vector2(xs[i], base_y)
		var s: String = parts[i]
		Pen.text(_font, p + Vector2(0, 4), s, fs, GOLD_DARK if i != 1 else Color("a3208c"))
		Pen.text(_font, p + Vector2(0, -1.5), s, fs, GOLD_LIGHT if i != 1 else Color("ffc2f2"))
		Pen.text(_font, p, s, fs, GOLD if i != 1 else Color("ff5ad9"))
	_pin_shaft(a, b, k)
	_pin_ends(a, b, k)
	Pen.end()


func _width(parts: Array, fs: int) -> float:
	var w := 0.0
	for s: String in parts:
		w += _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return w + (fs * (GAP_L + GAP_R) if parts[1] != "" else 0.0)


## Стержень засова от кольца a до кончика b, со своим тонким чернильным краем.
func _pin_shaft(a: Vector2, b: Vector2, s: float) -> void:
	Pen.line(a, b, INK, 10.5 * s)
	Pen.line(a, b, GOLD_DARK, 6.5 * s)
	Pen.line(a + Vector2(0, -0.9) * s, b + Vector2(0, -0.9) * s, GOLD, 3.2 * s)
	Pen.line(a + Vector2(0, -2.1) * s, b + Vector2(0, -2.1) * s, GOLD_LIGHT, 1.1 * s)


## Кольцо-ручка у a и заострённый кончик за b — поверх букв, как у засовов в уровнях.
func _pin_ends(a: Vector2, b: Vector2, s: float) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var point := PackedVector2Array([b + (n * 4.5 - d) * s, b + d * 8.0 * s, b - (n * 4.5 + d) * s])
	Pen.blob(point, GOLD_DARK, 2.0 * s, INK)
	Pen.line(b - d * 3.0 * s + n * 0.8 * s, b + d * 3.5 * s + n * 0.4 * s, GOLD, 1.8 * s)
	a -= d * 3.0 * s
	Pen.ring(a, 9.0 * s, INK, 8.0 * s)
	Pen.ring(a, 9.0 * s, GOLD_DARK, 5.0 * s)
	Pen.ring(a, 9.0 * s, GOLD, 2.6 * s)
	Pen.arc(a, 9.5 * s, PI * 1.1, PI * 1.6, GOLD_LIGHT, 1.1 * s, 8)


# --- колба ---------------------------------------------------------------------

## Тёплое свечение лавы: пульсирует через modulate.a холста.
func _paint_glow(ci: CanvasItem) -> void:
	Pen.begin(ci, _flask_xf())
	Pen.glow(C + Vector2(2, -1), Vector2(21, 21), Color(1.0, 0.54, 0.16, 0.65), 20)
	Pen.end()


## Мигающие искорки, стекло и жидкость с пузырьками — единственное, что перерисовывается.
func _paint_anim(ci: CanvasItem) -> void:
	Pen.begin(ci, _flask_xf())
	for p: Vector3 in [Vector3(27, 30, 0.0), Vector3(83, 27, 2.1), Vector3(81, 80, 4.2)]:
		var tw := 0.6 + 0.4 * sin(_t * 2.2 + p.z)
		Pen.sparkle(Vector2(p.x, p.y), 3.8 * tw, Color(1.0, 0.89, 0.48, 0.85 * tw))
	Pen.disc(C, R, GLASS)
	var level := ICON_LEVEL if progress < 0.0 else lerpf(BOTTOM - 0.5, C.y - R + 2.5, clampf(progress, 0.0, 1.0))
	if level < BOTTOM - 1.0:
		_liquid(level)
	Pen.end()


## Контур шара, горлышко, пробка и засов — статичны.
func _paint_front(ci: CanvasItem) -> void:
	Pen.begin(ci, _flask_xf())
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
	Pen.end()


## Шляпа Мирры в координатах от середины полей: холст качается вокруг этой точки.
func _paint_hat(ci: CanvasItem) -> void:
	Pen.begin(ci, Transform2D(0.0, _flask_xf().get_scale(), 0.0, Vector2.ZERO) * Transform2D(0.0, -BRIM))
	Pen.blob(Pen.oval(BRIM, Vector2(12, 3), 20), Color("5427b8"), 2.0)
	var tip := BRIM + Vector2(3, -16.5)
	var cone := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 9:
		cone.append(Pen.qbez(BRIM + Vector2(-9, -0.5), BRIM + Vector2(-3, -7.5), tip, i / 8.0))
	for i in range(7, 0, -1):
		cone.append(Pen.qbez(BRIM + Vector2(9, -0.5), BRIM + Vector2(5, -8.5), tip, i / 8.0))
	for p in cone:
		cols.append(Color("a878ff").lerp(Color("6a36d8"), (p.y - tip.y) / 16.0))
	Pen.grad(cone, cols)
	Pen.loop(cone, Color("24163d"), 2.0)
	Pen.pline(Pen.smooth([BRIM + Vector2(-7.4, -2.3), BRIM + Vector2(0, -3.3), BRIM + Vector2(7.8, -2.3)], 3), GOLD, 1.6)
	Pen.soft(Pen.star_pts(BRIM + Vector2(1.4, -7.3), 2.9), Color("ffc933"))
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
					Pen.arc(Vector2(x, y), 0.9 + b * 0.25, 0.0, TAU, Color(1, 1, 1, 0.8), 0.45, 8)
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
