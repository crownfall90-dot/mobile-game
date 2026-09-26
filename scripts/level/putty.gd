class_name Putty
extends Node2D
## «Замазка»: игрок рисует пальцем жёлоба и заплатки. Каждая линия становится стенкой (тонкий
## шланг из отрезков-капсул), замазки в тюбике ограниченно (ink — длина в px). Пока палец ведёт,
## виден бледный след; отпустили — линия застывает. Уровень задаёт "putty": {ink, width}.

signal ink_changed(left: float, total: float)

const PUTTY := Color("e9e1cf")
const PUTTY_DARK := Color("8f8069")
const PREVIEW := Color(1, 1, 1, 0.55)
const MIN_STEP := 10.0

var ink := 900.0
var ink_left := 900.0
var width := 18.0
var _lines: Array[PackedVector2Array] = []
var _draft := PackedVector2Array()
var _body: StaticBody2D


func setup(total_ink: float, line_width: float) -> void:
	ink = total_ink
	ink_left = total_ink
	width = line_width
	_body = StaticBody2D.new()
	_body.collision_layer = Substances.LAYER_WORLD
	add_child(_body)


## Палец: начать, продолжить, отпустить. Возвращает true, если линия легла.
func begin(p: Vector2) -> void:
	_draft = PackedVector2Array([p])
	queue_redraw()


func extend(p: Vector2) -> void:
	if _draft.is_empty() or ink_left - _length(_draft) <= 0.0:
		return
	if p.distance_to(_draft[_draft.size() - 1]) >= MIN_STEP:
		_draft.append(p)
		queue_redraw()


func finish() -> bool:
	var ok := add_line(_draft)
	_draft = PackedVector2Array()
	queue_redraw()
	return ok


func is_drawing() -> bool:
	return not _draft.is_empty()


## Линия целиком (DevRunner или палец): обрезается по остатку замазки и становится стенкой.
func add_line(points: PackedVector2Array) -> bool:
	if points.size() < 2 or ink_left <= 1.0:
		return false
	var line := PackedVector2Array([points[0]])
	var used := 0.0
	for i in range(1, points.size()):
		var seg := points[i].distance_to(line[line.size() - 1])
		if used + seg > ink_left:
			var k := (ink_left - used) / seg
			line.append(line[line.size() - 1].lerp(points[i], k))
			used = ink_left
			break
		line.append(points[i])
		used += seg
	if used < 4.0:
		return false
	ink_left -= used
	_lines.append(line)
	for i in range(1, line.size()):
		var cs := CollisionShape2D.new()
		var cap := CapsuleShape2D.new()
		var a := line[i - 1]
		var b := line[i]
		cap.radius = width * 0.5
		cap.height = a.distance_to(b) + width
		cs.shape = cap
		cs.position = (a + b) * 0.5
		cs.rotation = (b - a).angle() - PI * 0.5
		_body.add_child(cs)
	ink_changed.emit(ink_left, ink)
	queue_redraw()
	return true


func _length(pts: PackedVector2Array) -> float:
	var s := 0.0
	for i in range(1, pts.size()):
		s += pts[i].distance_to(pts[i - 1])
	return s


func _draw() -> void:
	for line in _lines:
		draw_polyline(line, PUTTY_DARK, width + 5.0, true)
		draw_polyline(line, PUTTY, width, true)
		draw_polyline(line, Color(1, 1, 1, 0.5), 3.0, true)
		for p in [line[0], line[line.size() - 1]]:
			draw_circle(p, width * 0.5 + 2.0, PUTTY_DARK)
			draw_circle(p, width * 0.5, PUTTY)
	if _draft.size() >= 2:
		draw_polyline(_draft, PREVIEW, width, true)
	elif _draft.size() == 1:
		draw_circle(_draft[0], width * 0.5, PREVIEW)
