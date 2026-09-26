extends Control
## Старая фотография прабабушки из четырёх кусочков; недостающие — пустые места с «?».
## Кусочек i находится в конце i-й локации: он есть, если локация починена целиком (так и у тех,
## кто прошёл локации до появления фото).
## Картинка художника art/act1/story/photo_full.png режется на четверти; пока её нет — рисует код.
## Используют новелла (кусочек проявляется) и альбом.

const FULL := "res://art/act1/story/photo_full.png"

var pieces: Array[bool] = []
var fresh := -1               # только что найденный кусочек: проявляется
var tex: Texture2D
var _t := 0.0


## Кусочки из профиля; fresh_index (0..3) — только что найденный, считается найденным.
func collect(fresh_index := -1) -> void:
	pieces.clear()
	var locs := Home.locations()
	for i in 4:
		pieces.append(i < locs.size() and Home.location_done(str(locs[i]["id"])))
	fresh = fresh_index
	if fresh >= 0 and fresh < 4:
		pieces[fresh] = true
	tex = load(FULL) if ResourceLoader.exists(FULL) else null


func found() -> int:
	return pieces.count(true)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(frame.position + Vector2(6, 10), frame.size), Color(0, 0, 0, 0.3))
	draw_rect(frame, Color("fbf6ea"))
	var inner := frame.grow(-22)
	if tex:
		draw_texture_rect(tex, inner, false)
	else:
		_placeholder(inner)
	for i in 4:
		var q := _quarter(inner, i)
		var a := 0.0 if pieces[i] else 1.0
		if i == fresh:
			a = clampf(1.0 - _t / 0.9, 0.0, 1.0)
		if a > 0.0:
			draw_rect(q, Color(0.86, 0.8, 0.7, a))
			draw_rect(q.grow(-8), Color(0.55, 0.45, 0.35, 0.5 * a), false, 3.0)
			draw_string(ThemeDB.fallback_font, q.get_center() + Vector2(-12, 16), "?",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.55, 0.45, 0.35, 0.8 * a))
	# рваные швы между кусочками
	# швы склейки: пока кусочков не хватает — заметные, у целого фото — едва видны
	var seam := Color(1, 1, 1, 0.18 if found() >= 4 else 0.55)
	draw_line(Vector2(inner.get_center().x, inner.position.y), Vector2(inner.get_center().x, inner.end.y), seam, 2.0)
	draw_line(Vector2(inner.position.x, inner.get_center().y), Vector2(inner.end.x, inner.get_center().y), seam, 2.0)
	if fresh >= 0 and _t < 1.4:
		var q := _quarter(inner, fresh)
		draw_rect(q.grow(4.0 + 8.0 * _t), Color(1.0, 0.9, 0.55, 1.0 - _t / 1.4), false, 5.0)


func _quarter(inner: Rect2, i: int) -> Rect2:
	var half := inner.size * 0.5
	return Rect2(inner.position + Vector2(float(i % 2), floorf(i * 0.5)) * half, half)


## Сепия: окно, кресло, бабушка Вера с маленькой девочкой на коленях, лампа.
func _placeholder(r: Rect2) -> void:
	var o := r.position
	var s := r.size / Vector2(500, 380)
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	draw_rect(r, Color("c9ae86"))
	draw_rect(Rect2(p.call(40, 40), Vector2(130, 170) * s), Color("e6d6b4"))
	draw_rect(Rect2(p.call(40, 40), Vector2(130, 170) * s), Color("8a6a48"), false, 4.0)
	draw_line(p.call(105, 40), p.call(105, 210), Color("8a6a48"), 3.0)
	draw_rect(Rect2(p.call(0, 300), Vector2(500, 80) * s), Color("a88762"))
	# кресло
	draw_rect(Rect2(p.call(200, 150), Vector2(190, 170) * s), Color("7d5a3c"))
	draw_rect(Rect2(p.call(185, 230), Vector2(40, 110) * s), Color("6b4a30"))
	draw_rect(Rect2(p.call(365, 230), Vector2(40, 110) * s), Color("6b4a30"))
	# бабушка
	draw_circle(p.call(295, 125), 34.0 * s.x, Color("e8cfae"))
	draw_circle(p.call(295, 100), 30.0 * s.x, Color("d9d4cc"))
	draw_rect(Rect2(p.call(250, 158), Vector2(90, 140) * s), Color("5e4a5a"))
	# девочка на коленях
	draw_circle(p.call(270, 205), 20.0 * s.x, Color("f0d8b8"))
	draw_circle(p.call(262, 192), 20.0 * s.x, Color("6b4a2e"))
	draw_rect(Rect2(p.call(250, 222), Vector2(46, 56) * s), Color("8fa3b8"))
	# лампа
	draw_line(p.call(450, 150), p.call(450, 300), Color("6b4a30"), 5.0)
	draw_colored_polygon(PackedVector2Array([p.call(420, 150), p.call(480, 150), p.call(465, 110),
		p.call(435, 110)]), Color("efe0bc"))
