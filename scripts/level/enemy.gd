class_name Enemy
extends RigidBody2D
## «Нарушитель» внутри вещи: у каждой вещи свой (docs/CAST.md). Физика у всех одна — круглое
## тело; вид, слабость (Level.VULNERABLE) и уход разные. Для 0+ никто не погибает: крыса и мышь
## мокрыми убегают, паука смывает вместе с паутиной, моль улетает, засор и плесень растворяются.
## Картинка art/act1/enemies/<kind>.png (если есть) заменяет рисунок кодом.

const RADIUS := 30.0
const TOP := Color("b561ff")
const BOTTOM := Color("5b1f9e")
const OUTLINE := Color("2a0b4d")
const ART := "res://art/act1/enemies/%s.png"
## Как нарушитель уходит: dissolve — оседает и тает, run — отскок и бег вбок, climb — вверх по нити,
## fly — улетает зигзагом.
const LEAVE := {&"slime": &"dissolve", &"grime": &"dissolve", &"mold": &"dissolve", &"rat": &"run",
	&"mouse": &"run", &"cockroach": &"run", &"spider": &"climb", &"moth": &"fly"}

var alive := true
var kind: StringName = &"slime"
var target := Vector2.ZERO   # куда смотрят глаза (обычно на приёмник или героя)

var _t := 0.0
var _death := 0.0
var _tex: Texture2D
var _side := 1.0             # куда убегать: от цели


func setup(pos: Vector2, look_at_pos: Vector2, on_contact: Callable) -> void:
	position = pos
	target = look_at_pos
	_t = pos.x
	_side = -1.0 if look_at_pos.x > pos.x else 1.0
	lock_rotation = true
	mass = 3.0
	collision_layer = Substances.LAYER_ENEMY
	collision_mask = Substances.LAYER_WORLD | Substances.LAYER_ITEMS | Substances.LAYER_ENEMY
	contact_monitor = true
	max_contacts_reported = 4
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = circle
	add_child(cs)
	body_entered.connect(on_contact.bind(self))


## Вид задаётся до добавления в сцену; картинка грузится сразу, не во время рисования.
func set_kind(k: StringName) -> void:
	kind = k
	var path := ART % kind
	_tex = load(path) if ResourceLoader.exists(path) else null


func kill() -> void:
	if not alive:
		return
	alive = false
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0
	var slow: bool = LEAVE.get(kind, &"dissolve") != &"dissolve"
	var tw := create_tween()
	tw.tween_property(self, "_death", 1.0, 1.1 if slow else 0.35).set_trans(
		Tween.TRANS_SINE if slow else Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var leave: StringName = LEAVE.get(kind, &"dissolve")
	var a := 1.0 - _death
	# художник рисует лицом влево — к цели справа отражаем всю отрисовку масштабом -1 по x
	# (прямоугольник картинки с отрицательной шириной Godot рисует со сдвигом на ширину)
	var face := -1.0 if _tex and target.x > position.x else 1.0
	if leave == &"dissolve":
		var wob := sin(_t * 4.0) * 0.05
		# нижний край остаётся на месте, "сплющивание" как у желе
		var sy := 1.0 - wob - _death * 0.85
		draw_set_transform(Vector2(0, RADIUS * (1.0 - sy)), 0.0, Vector2((1.0 + wob + _death * 0.7) * face, sy))
	else:
		a = 1.0 - clampf((_death - 0.6) / 0.4, 0.0, 1.0)
		draw_set_transform(_leave_offset(leave), _leave_tilt(leave), Vector2(face, 1.0))
	if kind == &"spider":
		_web(a)
	if _tex:
		# картинка крупнее тела, низом стоит на полу (отражение — в draw_set_transform выше)
		var s := RADIUS * 3.4
		draw_texture_rect(_tex, Rect2(-s * 0.5, RADIUS - s, s, s), false, Color(1, 1, 1, a))
		return
	match kind:
		&"rat", &"mouse":
			_rodent(a, 1.0 if kind == &"rat" else 0.78)
		&"spider":
			_spider(a)
		&"grime":
			_blob(a, Color("8a7a4e"), Color("4f4328"), Color("2c2415"), true)
		&"mold":
			_blob(a, Color("9fd36a"), Color("4f8a3a"), Color("24401c"), false)
		&"cockroach":
			_roach(a)
		&"moth":
			_moth(a)
		_:
			_blob(a, TOP, BOTTOM, OUTLINE, false)


func _leave_offset(leave: StringName) -> Vector2:
	var k := _death
	match leave:
		&"run":
			# отряхнулся, подпрыгнул и убежал вбок
			return Vector2(_side * 520.0 * k * k, -60.0 * sin(minf(k * 3.0, 1.0) * PI))
		&"climb":
			return Vector2(0, -700.0 * k * k)
		&"fly":
			return Vector2(sin(k * 14.0) * 40.0 + _side * 200.0 * k, -620.0 * k)
	return Vector2.ZERO


func _leave_tilt(leave: StringName) -> float:
	return _side * 0.25 * sin(_death * 30.0) if leave == &"run" and _death > 0.0 else 0.0


func _eyes(a: float, at: Vector2, gap: float, r: float, angry: bool) -> void:
	var look := (target - position).normalized() * r * 0.35
	for s in [-1.0, 1.0]:
		var e := at + Vector2(gap * s, 0)
		draw_circle(e, r, Color(1, 1, 1, a), true, -1.0, true)
		draw_circle(e + look, r * 0.5, Color(0.1, 0.05, 0.1, a), true, -1.0, true)
		if angry:
			draw_line(e + Vector2(r * 1.2 * s, -r * 1.3), e + Vector2(-r * 0.4 * s, -r * 0.7), Color(0.1, 0.05, 0.05, a), 3.0, true)


## Слизень, засор, плесень: мягкий комок; у засора торчат волосы и мусор, у плесени — пятна.
func _blob(a: float, top: Color, bottom: Color, outline: Color, hairy: bool) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 28:
		var ang := TAU * i / 28.0
		var p := Vector2(cos(ang), sin(ang)) * RADIUS
		if p.y > 0.0:
			p.y *= 0.88
		p.x += sin(ang * 3.0 + _t * 3.0) * 1.2
		pts.append(p)
		var c := top.lerp(bottom, (p.y + RADIUS) / (2.0 * RADIUS))
		c.a = a
		cols.append(c)
	draw_polygon(pts, cols)
	pts.append(pts[0])
	draw_polyline(pts, Color(outline, a), 2.5, true)
	if hairy:
		for i in 7:
			var ang := -PI * 0.9 + i * PI * 0.8 / 6.0
			var b := Vector2(cos(ang), sin(ang)) * RADIUS * 0.9
			var tip := b * 1.45 + Vector2(sin(_t * 2.0 + i) * 3.0, 0)
			draw_line(b, tip, Color(outline, a), 2.0, true)
		draw_rect(Rect2(8, 10, 9, 6), Color(0.9, 0.85, 0.6, a))
	else:
		for d: Vector3 in [Vector3(-12, 8, 4), Vector3(14, 4, 3), Vector3(2, 16, 3)]:
			draw_circle(Vector2(d.x, d.y), d.z, Color(outline, 0.35 * a), true, -1.0, true)
	draw_circle(Vector2(-11, -15), 6.0, Color(1, 1, 1, 0.3 * a), true, -1.0, true)
	_eyes(a, Vector2(0, -5), 10.0, 7.0, true)


## Крыса (серая, крупнее) и мышь: тело, уши, хвост, усы.
func _rodent(a: float, k: float) -> void:
	var fur := Color("8d8a92") if k >= 1.0 else Color("b8aea4")
	var dark := Color("4a4650")
	var face := -_side
	draw_set_transform(_leave_offset(&"run"), _leave_tilt(&"run"), Vector2(k, k))
	var tail := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		tail.append(Vector2(-face * (26.0 + u * 38.0), 18.0 - u * 20.0 + sin(u * 5.0 + _t * 4.0) * 6.0))
	draw_polyline(tail, Color("d99a9a", a), 4.0, true)
	draw_circle(Vector2(0, 8), RADIUS * 0.95, Color(fur, a), true, -1.0, true)
	draw_circle(Vector2(face * 20.0, -6), 17.0, Color(fur, a), true, -1.0, true)
	for s in [-1.0, 1.0]:
		var ear := Vector2(face * 12.0 + s * 9.0, -22)
		draw_circle(ear, 9.0, Color(fur, a), true, -1.0, true)
		draw_circle(ear, 5.5, Color("e8a8b0", a), true, -1.0, true)
	draw_circle(Vector2(face * 36.0, -2), 4.0, Color("e87890", a), true, -1.0, true)
	for s in [-1.0, 1.0]:
		draw_line(Vector2(face * 34.0, -1), Vector2(face * 50.0, -4 + s * 6.0), Color(dark, 0.7 * a), 1.5, true)
	_eyes(a, Vector2(face * 22.0, -10), 6.0, 4.5, false)


## Паук и его паутина: нить вверх и сеточка над ним.
func _web(a: float) -> void:
	var web := Color(1, 1, 1, 0.55 * a)
	draw_line(Vector2(0, -RADIUS * 0.6), Vector2(0, -150), web, 1.5, true)
	var c := Vector2(0, -150)
	for i in 8:
		var ang := PI + i * PI / 7.0
		draw_line(c, c + Vector2(cos(ang), sin(ang)) * 70.0, web, 1.2, true)
	for r in [22.0, 44.0, 66.0]:
		draw_arc(c, r, PI, TAU, 12, web, 1.2, true)


func _spider(a: float) -> void:
	var body := Color("2e2630")
	for s in [-1.0, 1.0]:
		for i in 4:
			var base := Vector2(s * 10.0, -6.0 + i * 6.0)
			var knee := base + Vector2(s * 22.0, -14.0 + i * 5.0 + sin(_t * 6.0 + i) * 2.0)
			var foot := knee + Vector2(s * 12.0, 22.0)
			draw_polyline(PackedVector2Array([base, knee, foot]), Color(body, a), 3.0, true)
	draw_circle(Vector2(0, 6), 20.0, Color(body, a), true, -1.0, true)
	draw_circle(Vector2(0, -12), 13.0, Color(body.lightened(0.1), a), true, -1.0, true)
	draw_circle(Vector2(-6, 2), 4.0, Color(1, 1, 1, 0.25 * a), true, -1.0, true)
	_eyes(a, Vector2(0, -14), 6.0, 5.0, true)


func _roach(a: float) -> void:
	var shell := Color("7a4a26")
	for s in [-1.0, 1.0]:
		for i in 3:
			var base := Vector2(s * 12.0, -4.0 + i * 10.0)
			draw_line(base, base + Vector2(s * 20.0, 6.0 + sin(_t * 12.0 + i) * 3.0), Color("3a2412", a), 2.5, true)
		draw_line(Vector2(s * 5.0, -24), Vector2(s * 24.0, -46.0 + sin(_t * 5.0) * 4.0), Color("3a2412", a), 2.0, true)
	draw_set_transform(_leave_offset(&"run"), _leave_tilt(&"run"), Vector2(0.8, 1.0))
	draw_circle(Vector2(0, 4), RADIUS * 0.85, Color(shell, a), true, -1.0, true)
	draw_set_transform(_leave_offset(&"run"), _leave_tilt(&"run"), Vector2.ONE)
	draw_line(Vector2(0, -14), Vector2(0, 26), Color("3a2412", a), 2.0, true)
	draw_circle(Vector2(-7, -6), 5.0, Color(1, 1, 1, 0.25 * a), true, -1.0, true)
	_eyes(a, Vector2(0, -20), 6.0, 4.0, false)


func _moth(a: float) -> void:
	var flap := 0.75 + 0.25 * sin(_t * 18.0)
	var wing := Color("c9bba0")
	for s in [-1.0, 1.0]:
		draw_set_transform(_leave_offset(&"fly"), 0.0, Vector2(flap, 1.0))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -4), Vector2(s * 34.0, -26), Vector2(s * 40.0, 4), Vector2(s * 8.0, 10)]), Color(wing, a))
		draw_circle(Vector2(s * 24.0, -8), 5.0, Color(wing.darkened(0.3), a), true, -1.0, true)
	draw_set_transform(_leave_offset(&"fly"), 0.0, Vector2.ONE)
	draw_rect(Rect2(-5, -16, 10, 34), Color("8a7a62", a))
	_eyes(a, Vector2(0, -14), 5.0, 4.0, false)
