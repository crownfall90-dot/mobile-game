class_name PipeSwitch
extends StaticBody2D
## «Живые трубы»: колено трубы. Вода входит сверху и выходит сбоку — вправо или влево.
## Тап по колену переворачивает его: поток сразу идёт в другую сторону. Физика — две стенки
## канала для каждой стороны; при повороте включается другая пара (без масштабирования тел).
## Уровень задаёт колено в "pipes": {id, pos, right, size}.

const WALL := 14.0
const PIPE := Color("b9c3c8")
const PIPE_DARK := Color("6d777d")
const PIPE_LIGHT := Color("eef4f6")
const KNOB := Color("f2c14e")

var id := ""
var right := true
var size := 150.0
var width := 56.0
var _shapes := {true: [], false: []}   # сторона выхода -> стенки
var _look := 1.0                       # 1 — выход вправо, -1 — влево; в повороте проходит через 0
var hinted := false                    # подсказка: это колено повернуть следующим
var _t := 0.0


func setup(pipe_id: String, pos: Vector2, exit_right: bool, cell := 150.0) -> void:
	id = pipe_id
	position = pos
	right = exit_right
	size = cell
	width = cell * 0.37
	_look = 1.0 if right else -1.0
	collision_layer = Substances.LAYER_WORLD
	collision_mask = 0
	for side: bool in [true, false]:
		for line in _walls(side):
			var cp := CollisionPolygon2D.new()
			cp.polygon = _band(line, WALL)
			cp.disabled = side != right
			add_child(cp)
			_shapes[side].append(cp)


## Стенки канала: внешняя (по которой вода скатывается к выходу) и внутренняя.
func _walls(to_right: bool) -> Array:
	var s := size
	var w := width
	var k := 1.0 if to_right else -1.0
	var outer := PackedVector2Array([Vector2(-k * (w * 0.5 + WALL * 0.5), -s * 0.5), Vector2(-k * (w * 0.5 + WALL * 0.5), s * 0.05),
		Vector2(k * s * 0.2, s * 0.3), Vector2(k * s * 0.5, s * 0.38)])
	var inner := PackedVector2Array([Vector2(k * (w * 0.5 + WALL * 0.5), -s * 0.5), Vector2(k * (w * 0.5 + WALL * 0.5), -s * 0.12),
		Vector2(k * s * 0.5, s * 0.02)])
	return [outer, inner]


## Толстая лента вдоль ломаной (как стенки уровня).
static func _band(line: PackedVector2Array, t: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var rt := PackedVector2Array()
	var n := line.size()
	for i in n:
		var d: Vector2
		if i == 0:
			d = line[1] - line[0]
		elif i == n - 1:
			d = line[i] - line[i - 1]
		else:
			d = (line[i] - line[i - 1]).normalized() + (line[i + 1] - line[i]).normalized()
		var nrm := Vector2(-d.y, d.x).normalized() * t * 0.5
		left.append(line[i] + nrm)
		rt.append(line[i] - nrm)
	rt.reverse()
	left.append_array(rt)
	return left


func hit(p: Vector2) -> bool:
	return p.distance_to(position) < size * 0.5


## Повернуть колено: стенки другой стороны включаются сразу, картинка переворачивается за 0,18 с.
func flip() -> void:
	right = not right
	hinted = false
	for side: bool in [true, false]:
		for cp: CollisionPolygon2D in _shapes[side]:
			cp.set_deferred("disabled", side != right)
	var tw := create_tween()
	tw.tween_property(self, "_look", 1.0 if right else -1.0, 0.18).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_look, 1.0))
	for line in _walls(true):
		draw_polyline(line, PIPE_DARK, WALL + 6.0, true)
		draw_polyline(line, PIPE, WALL, true)
		draw_polyline(line, PIPE_LIGHT, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# ручка поворота: золотое кольцо со стрелкой, мягко пульсирует — «нажми меня»
	var c := Vector2(0, -size * 0.28)
	var pulse := 1.0 + 0.08 * sin(_t * 4.0)
	if hinted:
		var ph := fmod(_t * 1.4, 1.0)
		draw_arc(c, 20.0 + ph * 40.0, 0.0, TAU, 32, Color(KNOB, 1.0 - ph), 4.0, true)
	draw_circle(c, 17.0 * pulse, Color(KNOB, 0.9))
	draw_arc(c, 11.0, -PI * 0.8, PI * 0.5, 12, Color("6b4a33"), 3.0, true)
	var tip := c + Vector2(cos(PI * 0.5), sin(PI * 0.5)) * 11.0
	draw_colored_polygon(PackedVector2Array([tip + Vector2(-6, -2), tip + Vector2(4, -6), tip + Vector2(2, 5)]), Color("6b4a33"))
