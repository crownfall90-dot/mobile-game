extends Node2D
## Хмурь — серое облачко-грусть, от которой ветшает квартира (сюжет: docs/ROADMAP.md, раздел 2).
## Висит под потолком локации; чем больше в ней несделанных ремонтов, тем она больше и темнее,
## моросит дождиком. Ремонт — облачко съёживается; локация готова — улетает в следующую комнату.
## После всего акта Хмурь становится белым облачком-другом и улыбается.
## Картинки художника art/act1/story/gloom_grey.png и gloom_white.png, если есть; иначе рисует код.
## Координаты — сцены локации (720×1560), как у LocationView.

signal left

const ART := "res://art/act1/story/gloom_%s.png"
const GREY := Color("8a909c")
const GREY_DARK := Color("6b7180")
const WHITE := Color("f4f7fb")
const SIZE := 170.0          # ширина облачка при полной силе

var amount := 1.0            # 0..1 — доля несделанных ремонтов локации
var friendly := false        # весь акт починен: белое облачко-друг
var _shown := 1.0            # плавно догоняет amount
var _t := 0.0
var _leave := -1.0           # анимация улёта 0..1
var _talk := 0.0             # «говорит»: подпрыгивает
var _tex: Texture2D


func setup(pos: Vector2, share: float, is_friend: bool) -> void:
	position = pos
	amount = share
	_shown = share
	friendly = is_friend
	var path := ART % ("white" if friendly else "grey")
	_tex = load(path) if ResourceLoader.exists(path) else null
	visible = friendly or amount > 0.0


## Ремонт сделан: облачко съёживается; если больше нечего чинить — улетает.
func set_amount(share: float) -> void:
	amount = share
	if amount <= 0.0 and not friendly:
		_leave = 0.0


func talk() -> void:
	_talk = 1.0


## Куда тапать и откуда хвостик реплики — снизу облачка (в координатах локации).
func hit(p: Vector2) -> bool:
	return visible and _leave < 0.0 and p.distance_to(position) < _size() * 0.45


func speech_point() -> Vector2:
	return position + Vector2(0, _size() * 0.42)


func _size() -> float:
	return SIZE * (1.0 if friendly else lerpf(0.55, 1.0, _shown))


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, amount, delta * 0.6)
	_talk = maxf(0.0, _talk - delta * 2.5)
	if _leave >= 0.0:
		_leave += delta * 0.5
		if _leave >= 1.0:
			visible = false
			_leave = -1.0
			left.emit()
	queue_redraw()


func _draw() -> void:
	var s := _size()
	var bob := Vector2(sin(_t * 0.9) * 8.0, sin(_t * 1.3) * 5.0 - _talk * 14.0 * absf(sin(_t * 14.0)))
	var a := 1.0
	if _leave >= 0.0:
		# улетает вверх-вправо и тает — в следующую комнату
		bob += Vector2(_leave * 260.0, -_leave * 320.0)
		a = 1.0 - _leave
	var c := bob
	if not friendly and _leave < 0.0:
		# морось под облачком: чем больше хмури, тем гуще
		var n := int(3 + 5 * _shown)
		for i in n:
			var ph := fmod(_t * 0.9 + i * 0.37, 1.0)
			var x := c.x - s * 0.35 + s * 0.7 * fmod(i * 0.618, 1.0)
			var y := c.y + s * 0.2 + ph * s * 0.7
			draw_line(Vector2(x, y), Vector2(x - 2.0, y + 9.0), Color(0.65, 0.72, 0.85, (1.0 - ph) * 0.7 * a), 2.0)
	if _tex:
		var ts := _tex.get_size()
		var h := s * ts.y / ts.x
		draw_texture_rect(_tex, Rect2(c - Vector2(s, h) * 0.5, Vector2(s, h)), false, Color(1, 1, 1, a))
		return
	var body := WHITE if friendly else GREY.lerp(GREY_DARK, _shown * 0.5)
	var shade := Color(0.78, 0.83, 0.9) if friendly else GREY_DARK
	# облачко из кружков: снизу тень, сверху светлее
	var puffs := [Vector2(-0.3, 0.05), Vector2(0.0, -0.12), Vector2(0.28, 0.02), Vector2(-0.12, 0.12), Vector2(0.14, 0.13)]
	var radii := [0.26, 0.32, 0.26, 0.24, 0.24]
	for i in puffs.size():
		draw_circle(c + puffs[i] * s + Vector2(0, 6), radii[i] * s, Color(shade, a))
	for i in puffs.size():
		draw_circle(c + puffs[i] * s, radii[i] * s, Color(body, a))
	draw_circle(c + Vector2(-0.08, -0.2) * s, 0.1 * s, Color(1, 1, 1, 0.25 * a))
	# глазки и рот: грустная бровка у серой, улыбка у белой
	var eye := Color("3a3a48")
	for side in [-1.0, 1.0]:
		var e := c + Vector2(side * 0.13 * s, -0.02 * s)
		draw_circle(e, 0.035 * s, Color(eye, a))
		draw_circle(e + Vector2(-0.01, -0.012) * s, 0.012 * s, Color(1, 1, 1, a))
		if not friendly:
			draw_line(e + Vector2(-side * 0.07, -0.09) * s, e + Vector2(side * 0.02, -0.06) * s, Color(eye, a), 3.0)
	var m := c + Vector2(0, 0.1 * s)
	if friendly:
		draw_arc(m + Vector2(0, -0.04 * s), 0.07 * s, 0.2, PI - 0.2, 12, Color(eye, a), 3.0)
		for side in [-1.0, 1.0]:
			draw_circle(c + Vector2(side * 0.22 * s, 0.06 * s), 0.04 * s, Color(1.0, 0.7, 0.72, 0.6 * a))
	else:
		draw_arc(m + Vector2(0, 0.04 * s), 0.06 * s, PI + 0.4, TAU - 0.4, 12, Color(eye, a), 3.0)
