class_name Enemy
extends RigidBody2D
## Болотный слизень: погибает от лавы и кислоты, опасен для героя.

const RADIUS := 30.0
const TOP := Color("b561ff")
const BOTTOM := Color("5b1f9e")
const OUTLINE := Color("2a0b4d")

var alive := true
var target := Vector2.ZERO   # куда смотрят глаза (обычно на героя)

var _t := 0.0
var _death := 0.0


func setup(pos: Vector2, look_at_pos: Vector2, on_contact: Callable) -> void:
	position = pos
	target = look_at_pos
	_t = pos.x
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


func kill() -> void:
	if not alive:
		return
	alive = false
	set_deferred("freeze", true)
	collision_layer = 0
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(self, "_death", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(hide)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var wob := sin(_t * 4.0) * 0.05
	var sx := 1.0 + wob + _death * 0.7
	var sy := 1.0 - wob - _death * 0.85
	var a := 1.0 - _death
	# нижний край остаётся на месте, "сплющивание" как у желе
	draw_set_transform(Vector2(0, RADIUS * (1.0 - sy)), 0.0, Vector2(sx, sy))
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 28:
		var ang := TAU * i / 28.0
		var p := Vector2(cos(ang), sin(ang)) * RADIUS
		if p.y > 0.0:
			p.y *= 0.88
		p.x += sin(ang * 3.0 + _t * 3.0) * 1.2
		pts.append(p)
		var c := TOP.lerp(BOTTOM, (p.y + RADIUS) / (2.0 * RADIUS))
		c.a = a
		cols.append(c)
	draw_polygon(pts, cols)
	pts.append(pts[0])
	draw_polyline(pts, Color(OUTLINE, a), 2.5, true)
	draw_circle(Vector2(-11, -15), 6.0, Color(1, 1, 1, 0.35 * a), true, -1.0, true)
	var look := (target - position).normalized() * 2.5
	for s in [-1.0, 1.0]:
		var e := Vector2(10.0 * s, -5.0)
		draw_circle(e, 7.5, Color(1, 1, 1, a), true, -1.0, true)
		draw_circle(e + look, 3.8, Color(0.1, 0.03, 0.15, a), true, -1.0, true)
		draw_line(Vector2(19.0 * s, -17.0), Vector2(4.0 * s, -12.0), Color(OUTLINE, a), 3.5, true)
	var dark := Color(OUTLINE, a)
	draw_arc(Vector2(0, 18), 8.0, PI + 0.5, TAU - 0.5, 10, dark, 3.0, true)
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([
			Vector2(4.0 * s, 11.0), Vector2(8.0 * s, 11.5), Vector2(6.0 * s, 16.0)]), Color(1, 1, 1, a))
