class_name Walls
extends Node2D
## Статичные стены уровня из полигонов JSON: одна коллизия, одна отрисовка.

const FILL_TOP := Color("514574")
const FILL_BOTTOM := Color("2b2345")
const EDGE := Color("9d8fd0")
const SHADOW := Color(0, 0, 0, 0.32)
const SHADOW_OFFSET := Vector2(5, 8)

var _polys: Array[PackedVector2Array] = []
var _colors: Array[PackedColorArray] = []


func setup(list: Array) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Substances.LAYER_WORLD
	body.collision_mask = 0
	for entry in list:
		var pts := PackedVector2Array()
		for p in entry["poly"]:
			pts.append(Vector2(p[0], p[1]))
		var cp := CollisionPolygon2D.new()
		cp.polygon = pts
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
