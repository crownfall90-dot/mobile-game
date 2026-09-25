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

const FULL_PAD := Vector2(700, 900)   # на сколько комната выходит за поле 720×1280
const FLOOR := Color("c79a6e")

var bounds := Rect2()
var theme := ""


func setup(rect: Rect2) -> void:
	bounds = rect


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
