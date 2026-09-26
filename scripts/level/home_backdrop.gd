class_name HomePuzzleBackdrop
extends Node2D
## Задник семейной головоломки. theme — ремонтируемая вещь уровня (поле "theme" в JSON):
## своя краска стен, узор и бледный силуэт этой вещи. Всё тихое, чтобы не спорить с физикой.

## theme -> [стена, узор, силуэт]
const PALETTES := {
	"tv": [Color("efe3cf"), Color("e3d3b8"), Color("8d7b6a")],
	"light": [Color("d9dcea"), Color("c8cce0"), Color("8a86a8")],
	"window": [Color("dcebf1"), Color("c7dfe8"), Color("7fa3b5")],
	"bed": [Color("eadff0"), Color("dccbe6"), Color("9a83ad")],
	"sofa": [Color("dcefe2"), Color("c9e2d1"), Color("79a28a")],
	"kitchen": [Color("f4efe4"), Color("dcd6c9"), Color("a08a70")],
	"bath": [Color("dff1f2"), Color("bfdfe2"), Color("6fa3aa")],
	"toilet": [Color("e7f0dc"), Color("d0e0c0"), Color("87a070")],
	"walls": [Color("f1e1d5"), Color("e0c6b3"), Color("b08c78")],
	"floor": [Color("f0e6d6"), Color("d6b894"), Color("9c7650")],
}

## Поле головоломки на картинке художника 1440×3120 (docs/ART_BRIEF.md, «Фоны головоломок»).
const EDGE_SPOTS := 12     # на сколько мягких пятен делится цвет края картинки
const PIC_FIELD := Rect2(260, 400, 920, 2020)
const FULL_PAD := Vector2(700, 900)   # на сколько комната выходит за поле 720×1280
const FLOOR := Color("c79a6e")

var bounds := Rect2()
var theme := ""
var fixed := 0.0          # 0 — вещь сломана (трещины, грязь, капель), 1 — починена (блеск)
## Головоломка-предмет: форма поля — это сами стенки-корпус вещи, фон — просто комната вокруг.
var item_mode := false
var _t := 0.0
var _pic: Texture2D
var _edges := {}          # сторона -> усреднённые цвета края картинки (подложка за её краем)


## Головоломка решена: поломка исчезает на глазах, вещь блестит.
func repair() -> void:
	create_tween().tween_property(self, "fixed", 1.0, 1.2).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if LevelSkin.get_skin(theme).is_empty():
		return
	_t += delta
	queue_redraw()


func setup(rect: Rect2) -> void:
	bounds = rect
	# картинку грузим заранее: загрузка внутри _draw даёт белый кадр
	_pic = LevelSkin.backdrop_texture(theme)


func _draw() -> void:
	var r := bounds
	var pal: Array = PALETTES.get(theme, [Color("e6dfce"), Color("d4d6c8"), Color("9cb7ad")])
	var wall: Color = pal[0]
	var line: Color = pal[1]
	var ink: Color = pal[2]
	# Комната на весь экран: стена с узором тянется за края поля на любой высоте телефона,
	# снизу — пол. Поле головоломки — просто часть этой комнаты.
	var full := Rect2(r.position.x - FULL_PAD.x, r.position.y - FULL_PAD.y,
		r.size.x + FULL_PAD.x * 2.0, r.size.y + FULL_PAD.y * 2.0)
	# Головоломка внутри вещи: своя картинка (если нарисована) или интерьер вещи кодом.
	var sk := LevelSkin.get_skin(theme)
	if _pic:
		_draw_picture(_pic, r, full, sk)
		return
	if not sk.is_empty() and item_mode:
		_draw_room(r, full, sk)
		return
	if not sk.is_empty():
		_draw_inside(r, full, sk)
		return
	draw_rect(full, wall)
	match theme:
		"kitchen", "bath", "toilet":
			_tiles(full, line, 46.0 if theme == "kitchen" else 34.0)
		"bed", "light":
			_dots(full, line)
		"sofa":
			_diamonds(full, line)
		"floor":
			_boards(full, line)
		_:
			_stripes(full, line)
	_silhouette(r, Color(ink, 0.30))
	var floor_top := r.end.y + 14.0
	draw_rect(Rect2(full.position.x, floor_top, full.size.x, full.end.y - floor_top), FLOOR)
	for y in range(int(floor_top) + 34, int(full.end.y), 34):
		draw_line(Vector2(full.position.x, y), Vector2(full.end.x, y), FLOOR.darkened(0.12), 2)
	# Деревянный карниз сверху и плинтус снизу — общие для всех комнат.
	draw_rect(Rect2(full.position.x, r.position.y - 18, full.size.x, 23), Color("b98c66"))
	draw_line(Vector2(full.position.x, r.position.y + 4), Vector2(full.end.x, r.position.y + 4), Color("735f52"), 4)
	draw_rect(Rect2(full.position.x, r.end.y - 7, full.size.x, 21), Color("aa8668"))


func _stripes(r: Rect2, c: Color) -> void:
	for x in range(int(r.position.x) + 17, int(r.end.x), 58):
		draw_rect(Rect2(x, r.position.y + 6, 18, r.size.y - 12), c)


func _dots(r: Rect2, c: Color) -> void:
	var odd := false
	for y in range(int(r.position.y) + 30, int(r.end.y), 52):
		var x0 := int(r.position.x) + (44 if odd else 18)
		for x in range(x0, int(r.end.x), 52):
			draw_circle(Vector2(x, y), 4.0, c)
		odd = not odd


func _diamonds(r: Rect2, c: Color) -> void:
	for y in range(int(r.position.y) + 36, int(r.end.y), 72):
		for x in range(int(r.position.x) + 36, int(r.end.x), 72):
			draw_colored_polygon(PackedVector2Array([Vector2(x, y - 14), Vector2(x + 10, y),
				Vector2(x, y + 14), Vector2(x - 10, y)]), c)


func _tiles(r: Rect2, c: Color, step: float) -> void:
	var y := r.position.y + step
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c, 2)
		y += step
	var x := r.position.x + step
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), c, 2)
		x += step


func _boards(r: Rect2, c: Color) -> void:
	var y := r.position.y + 40.0
	var row := 0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), c, 3)
		var x := r.position.x + (60.0 if row % 2 else 150.0)
		while x < r.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + 40), c, 2)
			x += 180.0
		y += 40.0
		row += 1


## Бледный силуэт вещи, которую чинит этот уровень, в верхней части комнаты.
func _silhouette(r: Rect2, c: Color) -> void:
	var cx := r.get_center().x
	var top := r.position.y
	var w := 5.0
	match theme:
		"tv":
			_box(Rect2(cx - 90, top + 60, 180, 120), c, w)
			_box(Rect2(cx - 72, top + 76, 144, 88), c, 3)
			draw_line(Vector2(cx - 10, top + 60), Vector2(cx - 40, top + 22), c, w)
			draw_line(Vector2(cx + 10, top + 60), Vector2(cx + 40, top + 22), c, w)
		"light":
			draw_line(Vector2(cx, top + 6), Vector2(cx, top + 70), c, 3)
			draw_colored_polygon(PackedVector2Array([Vector2(cx - 50, top + 120), Vector2(cx - 22, top + 70),
				Vector2(cx + 22, top + 70), Vector2(cx + 50, top + 120)]), c)
			draw_circle(Vector2(cx, top + 128), 12.0, c)
		"window":
			_box(Rect2(cx - 100, top + 40, 200, 170), c, w)
			draw_line(Vector2(cx, top + 40), Vector2(cx, top + 210), c, w)
			draw_line(Vector2(cx - 100, top + 125), Vector2(cx + 100, top + 125), c, w)
			draw_rect(Rect2(cx - 130, top + 30, 26, 200), c)
			draw_rect(Rect2(cx + 104, top + 30, 26, 200), c)
		"bed":
			var y := r.end.y - 150
			draw_rect(Rect2(r.position.x + 20, y, 26, 140), c)
			draw_rect(Rect2(r.position.x + 20, y + 60, r.size.x - 40, 30), c)
			_box(Rect2(r.position.x + 56, y + 30, 90, 30), c, 3)
		"sofa":
			var y := r.end.y - 120
			_box(Rect2(r.position.x + 30, y, r.size.x - 60, 70), c, w)
			draw_rect(Rect2(r.position.x + 18, y + 20, 30, 90), c)
			draw_rect(Rect2(r.end.x - 48, y + 20, 30, 90), c)
		"kitchen":
			for i in 3:
				var x := cx - 110 + 110 * i
				draw_rect(Rect2(x - 20, top + 70, 40, 34), c)
				draw_arc(Vector2(x + 22, top + 87), 9, -PI * 0.5, PI * 0.5, 8, c, 4)
			draw_rect(Rect2(cx - 150, top + 106, 300, 8), c)
		"bath":
			for p in [Vector2(cx - 120, top + 90), Vector2(cx - 80, top + 150), Vector2(cx + 100, top + 70),
					Vector2(cx + 140, top + 140), Vector2(cx + 30, top + 110)]:
				draw_arc(p, 14.0, 0, TAU, 20, c, 3)
			draw_arc(Vector2(r.end.x - 60, top + 40), 24, PI * 0.5, PI * 1.5, 10, c, w)
		"toilet":
			_box(Rect2(r.end.x - 120, top + 50, 76, 100), c, w)
			draw_circle(Vector2(r.end.x - 82, top + 100), 14.0, c)
		"walls":
			for p in [Rect2(r.position.x + 30, top + 90, 70, 50), Rect2(r.end.x - 120, top + 260, 80, 60),
					Rect2(r.position.x + 60, top + 520, 60, 70), Rect2(r.end.x - 90, top + 700, 50, 60)]:
				draw_rect(p, c)
		"floor":
			pass


func _box(rect: Rect2, c: Color, w: float) -> void:
	draw_rect(rect, c, false, w)


# --- интерьеры вещей ------------------------------------------------------------

## Картинка художника 1440×3120 (2x): рисуется в натуральную величину сцены (×0.5), её поле
## PIC_FIELD ложится центром на поле головоломки. За краями картинки (сдвинутое поле, очень высокие
## или широкие экраны) — спокойная подложка цветов её края с тенью, без полос и копий предмета.
func _draw_picture(pic: Texture2D, r: Rect2, full: Rect2, sk: Dictionary) -> void:
	draw_rect(full, Color(str(sk.get("outer", "e6dfce"))))
	# ширина картинки = 720 px сцены при любом её размере в пикселях
	var sz := pic.get_size() * (720.0 / pic.get_width())
	var field_c := PIC_FIELD.get_center() * (sz.x / 1440.0)
	var d := Rect2(r.get_center() - field_c, sz)
	draw_texture_rect(pic, d, false)
	# поле уровня сдвинуто или экран длиннее картинки: пустые края — спокойная подложка цветов края
	# (растянутая полоска края давала полосы, зеркало — копию предмета)
	if d.position.y > full.position.y:
		_calm_edge(pic, d, Vector2.UP, d.position.y - full.position.y)
	if d.end.y < full.end.y:
		_calm_edge(pic, d, Vector2.DOWN, full.end.y - d.end.y)
	if d.position.x > full.position.x:
		_calm_edge(pic, d, Vector2.LEFT, d.position.x - full.position.x)
	if d.end.x < full.end.x:
		_calm_edge(pic, d, Vector2.RIGHT, full.end.x - d.end.x)
	if fixed > 0.0:
		_repair_sparkles(r)


## Полоса шириной gap за краем картинки d (сторона side) — спокойная подложка: цвета края картинки,
## усреднённые в несколько мягких пятен (без деталей предмета и без полос), к краю экрана темнее.
func _calm_edge(pic: Texture2D, d: Rect2, side: Vector2, gap: float) -> void:
	var vertical := side.y != 0.0
	var edge := d.position.y if side.y < 0.0 else d.end.y
	if not vertical:
		edge = d.position.x if side.x < 0.0 else d.end.x
	var far := edge + gap * (side.y if vertical else side.x)
	var strip := _edge_strip(pic, side)
	var band := Rect2(d.position.x, minf(edge, far), d.size.x, gap) if vertical \
		else Rect2(minf(edge, far), d.position.y, gap, d.size.y)
	if strip:
		draw_texture_rect(strip, band, false)
	# к краю экрана темнее; у шва — мягкая тень на картинку и светлая кромка (край — полка, не обрыв)
	var clear := Color(0.07, 0.05, 0.04, 0.12)
	var dark := Color(0.07, 0.05, 0.04, 0.6)
	var none := Color(clear, 0.0)
	var soft := Color(clear, 0.3)
	var inner := edge - 26.0 * (side.y if vertical else side.x)
	var rim := Color(1, 0.94, 0.8, 0.22)
	var a: Vector2
	var b: Vector2
	if vertical:
		a = Vector2(d.position.x, edge)
		b = Vector2(d.end.x, far)
		draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]),
			PackedColorArray([clear, clear, dark, dark]))
		draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), Vector2(b.x, inner), Vector2(a.x, inner)]),
			PackedColorArray([soft, soft, none, none]))
		draw_line(a, Vector2(b.x, a.y), rim, 3.0)
	else:
		a = Vector2(edge, d.position.y)
		b = Vector2(far, d.end.y)
		draw_polygon(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]),
			PackedColorArray([clear, dark, dark, clear]))
		draw_polygon(PackedVector2Array([a, Vector2(inner, a.y), Vector2(inner, b.y), Vector2(a.x, b.y)]),
			PackedColorArray([soft, none, none, soft]))
		draw_line(a, Vector2(a.x, b.y), rim, 3.0)


## Цвета края картинки со стороны side, усреднённые в EDGE_SPOTS пятен (текстура 12×1 или 1×12,
## линейный фильтр растягивает её плавно). Считается один раз на сторону.
func _edge_strip(pic: Texture2D, side: Vector2) -> Texture2D:
	var key := str(side)
	if _edges.has(key):
		return _edges[key]
	var img := pic.get_image()
	var tex: Texture2D = null
	if img:
		if img.is_compressed():
			img.decompress()
		var w := img.get_width()
		var h := img.get_height()
		var vertical := side.y != 0.0
		var depth := 12                                  # сколько рядов у края усредняем
		var out := Image.create(EDGE_SPOTS if vertical else 1, 1 if vertical else EDGE_SPOTS, false, Image.FORMAT_RGBA8)
		for i in EDGE_SPOTS:
			var sum := Color(0, 0, 0, 0)
			var n := 0
			var from := int(float(i) / EDGE_SPOTS * (w if vertical else h))
			var to := int(float(i + 1) / EDGE_SPOTS * (w if vertical else h))
			for u in range(from, to, 3):
				for v in depth:
					var x := u if vertical else (v if side.x < 0.0 else w - 1 - v)
					var y := (v if side.y < 0.0 else h - 1 - v) if vertical else u
					sum += img.get_pixel(x, y)
					n += 1
			var c := sum / maxf(1.0, n)
			c.a = 1.0
			out.set_pixel(i if vertical else 0, 0 if vertical else i, c)
		tex = ImageTexture.create_from_image(out)
	_edges[key] = tex
	return tex


## Комната вокруг вещи-головоломки: стена с узором и пол ниже поля; мягкое затемнение по краям,
## чтобы корпус вещи читался. Блеск при починке — на стенках (Walls.repair).
func _draw_room(r: Rect2, full: Rect2, sk: Dictionary) -> void:
	var outer := Color(str(sk["outer"]))
	draw_rect(full, outer)
	if theme in ["sink", "stove", "fridge", "cabinet", "ceiling", "tub", "toilet"]:
		_tiles(full, outer.darkened(0.06), 34.0 if theme in ["tub", "toilet"] else 46.0)
	else:
		_stripes(full, outer.darkened(0.05))
	var floor_top := r.end.y + 44.0
	draw_rect(Rect2(full.position.x, floor_top, full.size.x, full.end.y - floor_top), FLOOR)
	for y in range(int(floor_top) + 34, int(full.end.y), 34):
		draw_line(Vector2(full.position.x, y), Vector2(full.end.x, y), FLOOR.darkened(0.12), 2)
	draw_circle(r.get_center(), r.size.y * 0.62, Color(1, 1, 1, 0.08))
	if fixed > 0.0:
		_repair_sparkles(r)


## Починено: по кругу поля мерцают искры.
func _repair_sparkles(r: Rect2) -> void:
	for i in 10:
		var a := float(i) / 10.0 * TAU + _t * 0.4
		var p := r.get_center() + Vector2(cos(a) * r.size.x * 0.5, sin(a) * r.size.y * 0.45)
		var pulse := 0.5 + 0.5 * sin(_t * 4.0 + i)
		draw_circle(p, 3.0 + 4.0 * pulse, Color(1.0, 0.95, 0.7, 0.8 * fixed * pulse))


## Комната вокруг, корпус вещи вокруг поля и то, что внутри вещи. Всё приглушённое:
## на первом плане физика, фон только подсказывает, где мы.
func _draw_inside(r: Rect2, full: Rect2, sk: Dictionary) -> void:
	var outer := Color(str(sk["outer"]))
	var inner := Color(str(sk["inner"]))
	draw_rect(full, outer)
	if theme in ["sink", "stove", "fridge", "cabinet", "ceiling", "tub", "toilet"]:
		_tiles(full, outer.darkened(0.06), 34.0 if theme in ["tub", "toilet"] else 46.0)
	else:
		_stripes(full, outer.darkened(0.05))
	var floor_top := r.end.y + 44.0
	draw_rect(Rect2(full.position.x, floor_top, full.size.x, full.end.y - floor_top), FLOOR)
	for y in range(int(floor_top) + 34, int(full.end.y), 34):
		draw_line(Vector2(full.position.x, y), Vector2(full.end.x, y), FLOOR.darkened(0.12), 2)
	var body := r.grow(34.0)
	_draw_item(r, body)
	_draw_damage(r, body)


func _draw_item(r: Rect2, body: Rect2) -> void:
	match theme:
		"window":
			_body(body, Color("b88352"))
			_grad(r, Color("5f7f9e"), Color("a9c3d6"))
			_rain(r)
			draw_rect(Rect2(r.get_center().x - 6, r.position.y, 12, r.size.y), Color(0.95, 0.85, 0.7, 0.28))
			draw_rect(Rect2(r.position.x, r.get_center().y - 6, r.size.x, 12), Color(0.95, 0.85, 0.7, 0.28))
			for i in 3:
				var x := r.position.x + 60.0 + i * 140.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 40, r.position.y),
					Vector2(x - 60, r.end.y), Vector2(x - 100, r.end.y)]), Color(1, 1, 1, 0.07))
		"bed":
			_body(body, Color("8a5a3a"))
			_grad(r, Color("5b4a63"), Color("2e2436"))
			for i in 7:
				var x := r.position.x + 40.0 + i * 64.0
				for j in 4:
					draw_arc(Vector2(x, r.position.y + 30.0 + j * 14.0), 14.0, 0.2, PI - 0.2, 10, Color(0.75, 0.72, 0.8, 0.35), 3.0)
			draw_rect(Rect2(r.position.x, r.position.y + 96, r.size.x, 18), Color(0.55, 0.38, 0.26, 0.6))
			for p in [Vector2(0.2, 0.93), Vector2(0.55, 0.96), Vector2(0.82, 0.92)]:
				draw_circle(r.position + r.size * p, 14.0, Color(0.72, 0.68, 0.76, 0.45))
		"floor":
			_grad(r, Color("7b5639"), Color("4d3322"))
			for x in [r.position.x + 110.0, r.position.x + 350.0]:
				draw_rect(Rect2(x, r.position.y, 34, r.size.y), Color(0.2, 0.12, 0.07, 0.22))
			draw_rect(Rect2(body.position.x, body.position.y, body.size.x, 44), Color("c79a6e"))
			for x in range(int(body.position.x) + 70, int(body.end.x), 140):
				draw_line(Vector2(x, body.position.y), Vector2(x, body.position.y + 44), Color("9c7650"), 3)
		"walls":
			_body(body, Color("eadccb"))
			draw_rect(r, Color("d8c3ad"))
			var row := 0
			for y in range(int(r.position.y), int(r.end.y), 30):
				var off := 0.0 if row % 2 == 0 else 32.0
				var x := r.position.x - off
				while x < r.end.x:
					var br := Rect2(maxf(x + 3, r.position.x), y + 3, minf(58.0, r.end.x - x - 3), 24).intersection(r)
					if br.size.x > 2:
						draw_rect(br, Color("b0634a") if (int(x / 64.0) + row) % 3 else Color("9a553f"))
					x += 64.0
				row += 1
		"sink":
			_body(body, Color("fbfbf8"))
			draw_rect(body, Color("b9c3c8"), false, 4.0)
			_grad(r, Color("f2f8fa"), Color("cfe2ea"))
			var drain := Vector2(r.get_center().x, r.end.y - 60)
			draw_circle(drain, 46.0, Color("9aa6ad"))
			draw_circle(drain, 36.0, Color("5d676d"))
			draw_line(drain - Vector2(30, 0), drain + Vector2(30, 0), Color("b9c3c8"), 5)
			draw_line(drain - Vector2(0, 30), drain + Vector2(0, 30), Color("b9c3c8"), 5)
			_faucet(Vector2(r.get_center().x, body.position.y))
		"stove":
			_body(body, Color("efe2c8"))
			for i in 4:
				var c := Vector2(r.position.x + 70.0 + i * 107.0, body.position.y - 26.0)
				draw_circle(c, 18.0, Color("3a3230"))
				draw_line(c, c + Vector2(0, -14), Color("efe2c8"), 4)
			_grad(r, Color("4a3f39"), Color("2a221e"))
			for y in [r.position.y + r.size.y * 0.35, r.position.y + r.size.y * 0.7]:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.7, 0.66, 0.6, 0.35), 4)
				for x in range(int(r.position.x) + 20, int(r.end.x), 40):
					draw_line(Vector2(x, y - 10), Vector2(x, y + 10), Color(0.7, 0.66, 0.6, 0.2), 2)
			var zig := PackedVector2Array()
			for i in 12:
				zig.append(Vector2(r.position.x + 40.0 + i * 34.0, r.end.y - 40.0 + (12.0 if i % 2 else -12.0)))
			draw_polyline(zig, Color(0.45, 0.2, 0.15, 0.6), 5.0, true)
		"fridge":
			_body(body, Color("fbfdfe"))
			draw_rect(body, Color("b8cad6"), false, 4.0)
			draw_rect(Rect2(body.end.x + 10, body.position.y + 120, 16, 260), Color("c8d6e0"))
			_grad(r, Color("eaf6fc"), Color("c6e3f2"))
			for y in range(int(r.position.y) + 230, int(r.end.y), 230):
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.7), 5)
				draw_line(Vector2(r.position.x, y + 4), Vector2(r.end.x, y + 4), Color(0.55, 0.7, 0.8, 0.25), 2)
			for p in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
				draw_circle(p, 40.0, Color(1, 1, 1, 0.55))
		"cabinet":
			_body(body, Color("b07a4a"))
			_grad(r, Color("a87850"), Color("7d5537"))
			for x in range(int(r.position.x) + 57, int(r.end.x), 57):
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0.3, 0.18, 0.1, 0.25), 2)
			draw_rect(Rect2(body.position.x - 70, body.position.y, 62, body.size.y), Color("c08a58"))
			draw_rect(Rect2(body.end.x + 8, body.position.y, 62, body.size.y), Color("c08a58"))
		"ceiling":
			_grad(r, Color("8a7a64"), Color("5e5040"))
			for p in [Vector2(0.15, 0.2), Vector2(0.7, 0.35), Vector2(0.3, 0.6), Vector2(0.8, 0.8), Vector2(0.5, 0.9)]:
				draw_circle(r.position + r.size * p, 40.0, Color(0.95, 0.82, 0.45, 0.25))
			draw_rect(Rect2(body.position.x, r.end.y, body.size.x, 34), Color("f6f1e8"))
		"tub":
			_body(body, Color("ffffff"))
			draw_rect(body, Color("a9c7cf"), false, 4.0)
			_grad(r, Color("fbfefe"), Color("dcecef"))
			_faucet(Vector2(body.end.x - 60, body.position.y))
		"toilet":
			_grad(r, Color("7d8883"), Color("58615c"))
			for x in [r.position.x + 90.0, r.position.x + 330.0]:
				draw_rect(Rect2(x, r.position.y, 40, r.size.y), Color(0.85, 0.9, 0.92, 0.18))
			draw_rect(Rect2(r.position.x, r.position.y + 420, r.size.x, 40), Color(0.85, 0.9, 0.92, 0.14))


func _body(body: Rect2, c: Color) -> void:
	draw_rect(body.grow(10), c.darkened(0.25))
	draw_rect(body, c)


func _grad(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


func _rain(r: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 60:
		var p := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
		draw_line(p, p + Vector2(-6, 22), Color(0.85, 0.93, 1.0, 0.35), 2.0)


## Хромированный кран над вещью: носик вниз, капля.
func _faucet(top: Vector2) -> void:
	draw_rect(Rect2(top.x - 50, top.y - 40, 100, 26), Color("c9d3da"))
	draw_rect(Rect2(top.x - 12, top.y - 20, 24, 44), Color("aeb9c1"))
	draw_circle(top + Vector2(0, 40), 7.0, Color(0.6, 0.8, 1.0, 0.8))


## Поломка на корпусе вещи гаснет при починке, после неё — блеск. Капель из крана или
## потолка прекращается. Всё по seed темы: один и тот же вид при каждом запуске.
func _draw_damage(r: Rect2, body: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(theme)
	var broken := 1.0 - fixed
	if broken > 0.0:
		for i in 6:
			# трещины по краю корпуса
			var side := i % 4
			var p := Vector2.ZERO
			match side:
				0: p = Vector2(rng.randf_range(body.position.x, body.end.x), body.position.y + 8.0)
				1: p = Vector2(body.end.x - 8.0, rng.randf_range(body.position.y, body.end.y))
				2: p = Vector2(rng.randf_range(body.position.x, body.end.x), body.end.y - 8.0)
				_: p = Vector2(body.position.x + 8.0, rng.randf_range(body.position.y, body.end.y))
			var pts := PackedVector2Array([p])
			for k in 4:
				p += Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
				pts.append(p)
			draw_polyline(pts, Color(0.2, 0.12, 0.08, 0.55 * broken), 3.0, true)
		for i in 5:
			var c := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			draw_circle(c, rng.randf_range(18.0, 34.0), Color(0.35, 0.25, 0.15, 0.12 * broken))
		# капель из крана или сквозь потолок
		if theme in ["sink", "tub", "ceiling", "toilet", "walls"]:
			var top := Vector2(r.get_center().x if theme != "tub" else r.end.x - 26.0, r.position.y + 50.0)
			for k in 2:
				var ph := fmod(_t * 0.8 + k * 0.5, 1.0)
				draw_circle(top + Vector2(0, ph * 220.0), 6.0, Color(0.55, 0.78, 1.0, 0.8 * broken * (1.0 - ph * 0.5)))
	if fixed > 0.0:
		for i in 8:
			var a := float(i) / 8.0 * TAU + _t * 0.4
			var p := r.get_center() + Vector2(cos(a) * r.size.x * 0.55, sin(a) * r.size.y * 0.52)
			var pulse := 0.5 + 0.5 * sin(_t * 4.0 + i)
			draw_circle(p, 3.0 + 4.0 * pulse, Color(1.0, 0.95, 0.7, 0.8 * fixed * pulse))
