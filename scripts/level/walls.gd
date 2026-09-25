class_name Walls
extends Node2D
## Статичные стены уровня из полигонов JSON: одна коллизия, одна отрисовка.
## type "sieve" — сито (дуршлаг): жидкости проходят насквозь, монеты, камни и враги лежат.

const FILL_TOP := Color("514574")
const FILL_BOTTOM := Color("2b2345")
const EDGE := Color("9d8fd0")
const SHADOW := Color(0, 0, 0, 0.32)
const SHADOW_OFFSET := Vector2(5, 8)
const SIEVE_FILL := Color("c9d3dc")
const SIEVE_EDGE := Color("6f7f8f")
const SIEVE_HOLE := Color("56657a")

var _polys: Array[PackedVector2Array] = []
var _colors: Array[PackedColorArray] = []
var _sieves: Array[PackedVector2Array] = []


func setup(list: Array) -> void:
	var body := _body(Substances.LAYER_WORLD)
	var sieve := _body(Substances.LAYER_SIEVE)
	for entry in list:
		var pts := PackedVector2Array()
		for p in entry["poly"]:
			pts.append(Vector2(p[0], p[1]))
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
		if str(entry.get("type", "solid")) == "sieve":
			sieve.add_child(cp)
			_sieves.append(pts)
			continue
		body.add_child(cp)
		_polys.append(pts)
		var top := INF
		var bottom := -INF
		for p in pts:
			top = minf(top, p.y)
			bottom = maxf(bottom, p.y)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(FILL_TOP.lerp(FILL_BOTTOM, inverse_lerp(top, bottom + 1.0, p.y)))
		_colors.append(cols)
	add_child(body)
	add_child(sieve)


func _body(layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	return body


func _draw() -> void:
	for pts in _polys:
		var shadow := PackedVector2Array()
		for p in pts:
			shadow.append(p + SHADOW_OFFSET)
		draw_colored_polygon(shadow, SHADOW)
	for i in _polys.size():
		var pts := _polys[i]
		draw_polygon(pts, _colors[i])
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, EDGE, 2.0, true)
	for pts in _sieves:
		_draw_sieve(pts)


## Сито: светлая металлическая полоса с рядом отверстий вдоль длинной стороны.
func _draw_sieve(pts: PackedVector2Array) -> void:
	draw_colored_polygon(pts, SIEVE_FILL)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, SIEVE_EDGE, 2.0, true)
	var a := pts[0]
	var b := pts[1]
	for i in range(1, pts.size()):
		var j := (i + 1) % pts.size()
		if pts[i].distance_to(pts[j]) > a.distance_to(b):
			a = pts[i]
			b = pts[j]
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var dir := (b - a).normalized()
	var mid := (a + b) * 0.5
	var n := int(a.distance_to(b) / 18.0)
	for k in range(1, n):
		var p := a + dir * (18.0 * k) + (c - mid)
		draw_circle(p, 3.0, SIEVE_HOLE)
