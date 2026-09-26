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

## Тёплое дерево для семейных уровней (комнаты квартиры); у башни Мирры — фиолетовый камень.
var palette := [FILL_TOP, FILL_BOTTOM, EDGE]
## Узор материала (LevelSkin): wood — волокна, pipe — блик и кольца стыков, tile/enamel — глянец.
var pattern := "plain"
## Износ стенок-корпуса вещи (1 — сломано: трещины, ржавчина; 0 — починено, блестит).
var wear := 0.0
var _shine := 0.0


## Вещь починена: трещины и грязь гаснут, по корпусу пробегает блеск.
func repair() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		wear = 1.0 - v
		_shine = sin(v * PI)
		queue_redraw(), 0.0, 1.0, 1.2)

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
			cols.append((palette[0] as Color).lerp(palette[1], inverse_lerp(top, bottom + 1.0, p.y)))
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
		draw_polyline(outline, palette[2], 2.0, true)
		_draw_pattern(pts)
		_draw_wear(pts, i)
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


## Узор по длинной стороне «планки» (засова, полки, трубы). Большие блоки остаются гладкими.
func _draw_pattern(pts: PackedVector2Array) -> void:
	if pattern == "plain" or pts.size() < 3:
		return
	var a := pts[0]
	var b := pts[1]
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		if p.distance_to(q) > a.distance_to(b):
			a = p
			b = q
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var along := (b - a).normalized()
	var inward := along.orthogonal()
	if inward.dot(c - a) < 0.0:
		inward = -inward
	var thick := absf((c - a).dot(inward)) * 2.0
	if thick > 60.0 or thick < 6.0 or a.distance_to(b) < 30.0:
		return
	var light := (palette[2] as Color)
	var dark := (palette[1] as Color).darkened(0.35)
	match pattern:
		"wood":
			for k in [0.3, 0.68]:
				draw_line(a + inward * thick * k + along * 6.0, b + inward * thick * k - along * 6.0, Color(dark, 0.35), 1.5, true)
		"pipe":
			draw_line(a + inward * thick * 0.28 + along * 4.0, b + inward * thick * 0.28 - along * 4.0, Color(light, 0.75), 3.0, true)
			draw_line(a + inward * thick * 0.8 + along * 4.0, b + inward * thick * 0.8 - along * 4.0, Color(dark, 0.3), 2.0, true)
			var n := int(a.distance_to(b) / 90.0)
			for k in range(1, n + 1):
				var m := a + along * (a.distance_to(b) * k / (n + 1))
				draw_line(m + inward * 1.0, m + inward * (thick - 1.0), Color(dark, 0.45), 5.0, true)
		"tile", "enamel":
			draw_line(a + inward * thick * 0.25 + along * 6.0, b + inward * thick * 0.25 - along * 6.0, Color(1, 1, 1, 0.6), 3.0, true)


## Трещины и пятна на стенке (по seed номера стенки) и блеск при починке.
func _draw_wear(pts: PackedVector2Array, index: int) -> void:
	if wear <= 0.0 and _shine <= 0.0:
		return
	var box := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		box = box.expand(p)
	if box.size.x < 40.0 and box.size.y < 40.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 7919 + 13
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	if wear > 0.0:
		var start := c + Vector2(rng.randf_range(-0.3, 0.3) * box.size.x, rng.randf_range(-0.3, 0.3) * box.size.y)
		var crack := PackedVector2Array([start])
		for k in 4:
			start += Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9))
			crack.append(start)
		draw_polyline(crack, Color(0.15, 0.1, 0.08, 0.6 * wear), 2.0, true)
		draw_circle(c + Vector2(rng.randf_range(-0.35, 0.35) * box.size.x, rng.randf_range(-0.35, 0.35) * box.size.y),
			minf(10.0, minf(box.size.x, box.size.y) * 0.3), Color(0.45, 0.28, 0.12, 0.3 * wear))
	if _shine > 0.0:
		draw_polyline(PackedVector2Array([pts[0], pts[1]]), Color(1, 1, 0.85, 0.8 * _shine), 4.0, true)
