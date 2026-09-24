class_name Pin
extends AnimatableBody2D
## Штырь: держит содержимое камеры, по тапу выезжает в сторону ручки.

signal pulled_out(pin: Pin)

const THICKNESS := 14.0
const HANDLE_R := 22.0
const HIT_RADIUS := 46.0   # щедрая зона касания для пальца
const GOLD_DARK := Color("a8741a")
const GOLD := Color("f5c542")
const GOLD_LIGHT := Color("fff1b8")

var id := ""
var length := 0.0
var dir := Vector2.RIGHT     # от ручки внутрь уровня
var pulled := false

var _shape: CollisionShape2D
var _glint := -1.0
var _glint_wait := 0.0


func setup(pin_id: String, from: Vector2, to: Vector2, glint_offset: float) -> void:
	id = pin_id
	position = from
	var v := to - from
	length = v.length()
	dir = v / length
	rotation = dir.angle()
	collision_layer = Substances.LAYER_WORLD
	collision_mask = 0
	sync_to_physics = true
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, THICKNESS)
	_shape = CollisionShape2D.new()
	_shape.shape = rect
	_shape.position = Vector2(length * 0.5, 0)
	add_child(_shape)
	_glint_wait = 1.5 + glint_offset


## Расстояние от точки (в координатах уровня) до штыря вместе с ручкой.
func distance_to_point(p: Vector2) -> float:
	var local := (p - position).rotated(-rotation)
	return local.distance_to(Vector2(clampf(local.x, -HANDLE_R, length), 0))


func pull() -> void:
	if pulled:
		return
	pulled = true
	var out := position - dir * (length + HANDLE_R * 2.0 + 60.0)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position", position + dir * 6.0, 0.06).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", out, 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_finish_pull)
	tw.tween_property(self, "modulate:a", 0.0, 0.2)


func _finish_pull() -> void:
	_shape.set_deferred("disabled", true)
	pulled_out.emit(self)


func _process(delta: float) -> void:
	if pulled:
		return
	if _glint < 0.0:
		_glint_wait -= delta
		if _glint_wait <= 0.0:
			_glint = 0.0
	else:
		_glint += delta * 1.6
		if _glint > 1.0:
			_glint = -1.0
			_glint_wait = 3.0
		queue_redraw()


func _draw() -> void:
	var up := Vector2(0, -1).rotated(-rotation)
	var shadow := Vector2(4, 7).rotated(-rotation)
	var a := Vector2(HANDLE_R * 0.8, 0)
	var b := Vector2(length, 0)
	# тень
	draw_line(a + shadow, b + shadow, Color(0, 0, 0, 0.3), THICKNESS, true)
	draw_circle(shadow, HANDLE_R, Color(0, 0, 0, 0.3), false, 9.0, true)
	# стержень
	draw_line(a, b, GOLD_DARK, THICKNESS, true)
	draw_circle(b, THICKNESS * 0.5, GOLD_DARK, true, -1.0, true)
	draw_line(a + up * 1.5, b + up * 1.5, GOLD, THICKNESS * 0.55, true)
	draw_line(a + up * 3.5, b + up * 3.5, GOLD_LIGHT, 2.0, true)
	# ручка-кольцо
	draw_circle(Vector2.ZERO, HANDLE_R, GOLD_DARK, false, 10.0, true)
	draw_circle(Vector2.ZERO, HANDLE_R, GOLD, false, 6.0, true)
	draw_circle(up * 2.0, HANDLE_R, GOLD_LIGHT, false, 1.5, true)
	# пробегающий блик
	if _glint >= 0.0:
		var x := lerpf(-HANDLE_R, length, _glint)
		var alpha := sin(_glint * PI) * 0.9
		draw_line(Vector2(x - 14, 0) + up * 2, Vector2(x + 14, 0) + up * 2, Color(1, 1, 1, alpha), 4.0, true)
