class_name Hero
extends Node2D
## Ученица алхимика. Позиция узла = точка между ступнями.

enum Mood { IDLE, SCARED, HAPPY, DEAD }

const ROBE := Color("3d7bff")
const ROBE_DARK := Color("1f3f9e")
const HAT := Color("8a4dff")
const HAT_DARK := Color("5427b8")
const TRIM := Color("f5c542")
const SKIN := Color("ffd9bd")
const HAIR := Color("ff7a45")
const INK := Color("24163d")

var mood := Mood.IDLE

var _t := 0.0
var _blink := 3.0
var _hop := 0.0
var _tilt := 0.0


func setup(pos: Vector2) -> void:
	position = pos
	var body := StaticBody2D.new()
	body.collision_layer = Substances.LAYER_WORLD
	body.collision_mask = 0
	var cap := CapsuleShape2D.new()
	cap.radius = 24.0
	cap.height = 120.0
	var cs := CollisionShape2D.new()
	cs.shape = cap
	cs.position = Vector2(0, -62)
	body.add_child(cs)
	add_child(body)


func set_scared(value: bool) -> void:
	if mood == Mood.IDLE or mood == Mood.SCARED:
		mood = Mood.SCARED if value else Mood.IDLE


func bounce() -> void:
	if mood == Mood.DEAD:
		return
	var tw := create_tween()
	tw.tween_property(self, "_hop", 10.0, 0.08).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_hop", 0.0, 0.14).set_ease(Tween.EASE_IN)


func celebrate() -> void:
	mood = Mood.HAPPY
	var tw := create_tween().set_loops(4)
	tw.tween_property(self, "_hop", 26.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_hop", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func die() -> void:
	mood = Mood.DEAD
	_hop = 0.0
	create_tween().tween_property(self, "_tilt", -0.35, 0.3).set_trans(Tween.TRANS_BACK)
	create_tween().tween_property(self, "modulate", Color(0.55, 0.52, 0.62), 0.3)


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.0, 4.5)
	queue_redraw()


func _draw() -> void:
	# мягкая тень на полу
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 34.0 - _hop * 0.3, Color(0, 0, 0, 0.3), true, -1.0, true)

	var breath := sin(_t * 2.4) * 0.018
	var jitter := sin(_t * 45.0) * 1.2 if mood == Mood.SCARED else 0.0
	draw_set_transform(Vector2(jitter, -_hop), _tilt, Vector2(1.0 - breath, 1.0 + breath))

	# руки (под мантией)
	var hand := Vector2(26, -26)
	match mood:
		Mood.SCARED:
			hand = Vector2(17, -66)
		Mood.HAPPY:
			hand = Vector2(34, -98)
	for s in [-1.0, 1.0]:
		var h := Vector2(hand.x * s, hand.y)
		draw_line(Vector2(13.0 * s, -52), h, ROBE_DARK, 10.0, true)
		draw_circle(h, 5.5, SKIN, true, -1.0, true)

	# мантия
	draw_polygon(PackedVector2Array([Vector2(-29, 0), Vector2(29, 0), Vector2(15, -60), Vector2(-15, -60)]),
		PackedColorArray([ROBE_DARK, ROBE_DARK, ROBE, ROBE]))
	draw_line(Vector2(-28, -3), Vector2(28, -3), TRIM, 4.0, true)
	draw_line(Vector2(-19, -34), Vector2(19, -34), TRIM, 4.0, true)
	draw_circle(Vector2(0, -34), 4.0, Color("ff4fd8"), true, -1.0, true)

	# голова и волосы
	draw_circle(Vector2(0, -78), 20.0, HAIR, true, -1.0, true)
	draw_circle(Vector2(0, -75), 18.0, SKIN, true, -1.0, true)
	draw_circle(Vector2(-19, -70), 7.0, HAIR, true, -1.0, true)
	draw_circle(Vector2(19, -70), 7.0, HAIR, true, -1.0, true)

	# лицо
	if mood == Mood.DEAD:
		for s in [-1.0, 1.0]:
			var e := Vector2(7.0 * s, -76)
			draw_line(e + Vector2(-3, -3), e + Vector2(3, 3), INK, 2.5, true)
			draw_line(e + Vector2(-3, 3), e + Vector2(3, -3), INK, 2.5, true)
		draw_line(Vector2(-5, -64), Vector2(5, -64), INK, 2.5, true)
	else:
		var eye_h := 0.25 if _blink < 0.0 else 1.0
		if mood == Mood.HAPPY:
			for s in [-1.0, 1.0]:
				draw_arc(Vector2(7.0 * s, -74), 4.0, PI + 0.3, TAU - 0.3, 8, INK, 2.5, true)
			draw_arc(Vector2(0, -68), 6.0, 0.2, PI - 0.2, 10, INK, 2.5, true)
		else:
			for s in [-1.0, 1.0]:
				draw_set_transform(Vector2(jitter + 7.0 * s, -76 - _hop), _tilt, Vector2(1.0, eye_h))
				draw_circle(Vector2.ZERO, 3.2, INK, true, -1.0, true)
				draw_circle(Vector2(1, -1.2), 1.1, Color.WHITE)
			draw_set_transform(Vector2(jitter, -_hop), _tilt, Vector2(1.0 - breath, 1.0 + breath))
			if mood == Mood.SCARED:
				draw_circle(Vector2(0, -65), 3.5, INK, false, 2.0, true)
			else:
				draw_arc(Vector2(0, -68), 4.5, 0.4, PI - 0.4, 8, INK, 2.2, true)
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(12.0 * s, -68), 3.5, Color(1.0, 0.45, 0.5, 0.35))

	# шляпа
	draw_polygon(PackedVector2Array([Vector2(-21, -88), Vector2(21, -88), Vector2(9, -116), Vector2(20, -140), Vector2(-5, -118)]),
		PackedColorArray([HAT_DARK, HAT_DARK, HAT, HAT.lightened(0.2), HAT]))
	var brim := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		brim.append(Vector2(cos(a) * 32.0, -88 + sin(a) * 7.0))
	draw_colored_polygon(brim, HAT_DARK)
	draw_line(Vector2(-19, -93), Vector2(19, -93), TRIM, 4.0, true)
	_draw_star(Vector2(2, -106), 6.0, TRIM)


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2.from_angle(-PI / 2.0 + PI * i / 5.0) * rr)
	draw_colored_polygon(pts, col)
