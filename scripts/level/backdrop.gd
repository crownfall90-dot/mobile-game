class_name Backdrop
extends Node2D
## Задник башни: градиент, кладка и мягкое свечение. Рисуется один раз.

const TOP := Color("231a3f")
const BOTTOM := Color("140f26")
const BRICK := Color(1, 1, 1, 0.045)
const GLOW := Color(0.62, 0.42, 1.0, 0.05)
const CROWN_TOP := Color("5d5186")
const CROWN_BOTTOM := Color("3a3060")
const CROWN_EDGE := Color("9d8fd0")

var _rect := Rect2()


func setup(rect: Rect2) -> void:
	_rect = rect


func _draw() -> void:
	for i in 5:
		draw_rect(_rect.grow(14.0 + i * 12.0), Color(GLOW, GLOW.a * (1.0 - i * 0.18)))
	var r := _rect
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
	var bw := 76.0
	var bh := 38.0
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), BRICK, 1.0)
		var x := r.position.x + (bw * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			draw_line(Vector2(x, y), Vector2(x, minf(y + bh, r.end.y)), BRICK, 1.0)
			x += bw
		y += bh
		row += 1
	_draw_crown()
	# виньетка по краям камеры
	var edge := 60.0
	var dark := Color(0, 0, 0, 0.35)
	var clear := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(edge, 0), Vector2(r.position.x + edge, r.end.y), Vector2(r.position.x, r.end.y)]),
		PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(r.end.x - edge, r.position.y), Vector2(r.end.x, r.position.y), r.end, Vector2(r.end.x - edge, r.end.y)]),
		PackedColorArray([clear, dark, dark, clear]))


## Зубцы башни над камерами — чисто декоративные, без коллизий.
func _draw_crown() -> void:
	var left := _rect.position.x - 34.0
	var right := _rect.end.x + 34.0
	var y := _rect.position.y
	var band := Rect2(left, y - 30.0, right - left, 24.0)
	_block(band)
	var count := 7
	var w := 38.0
	var gap := (band.size.x - w * count) / (count - 1)
	for i in count:
		_block(Rect2(left + i * (w + gap), band.position.y - 26.0, w, 28.0))


func _block(r: Rect2) -> void:
	draw_rect(Rect2(r.position + Vector2(5, 8), r.size), Color(0, 0, 0, 0.3))
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([CROWN_TOP, CROWN_TOP, CROWN_BOTTOM, CROWN_BOTTOM]))
	draw_rect(r, CROWN_EDGE, false, 2.0, true)
