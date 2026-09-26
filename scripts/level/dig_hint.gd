class_name DigHint
extends Node2D
## Подсказка копания: пунктир по пути мазков и светящийся палец, который бежит вдоль него.
## Мазки идут по очереди; всё повторяется, пока подсказку не снимут (set_paths([])).

const SPEED := 420.0
const DOT := Color(1.0, 0.93, 0.6, 0.85)
const FINGER := Color("fff6d8")
const EDGE := Color("6b4a2a")

var _paths: Array[PackedVector2Array] = []
var _t := 0.0


func set_paths(paths: Array) -> void:
	_paths.clear()
	for p in paths:
		var pts := PackedVector2Array()
		for q in p:
			pts.append(Vector2(q[0], q[1]))
		if pts.size() == 1:
			pts.append(pts[0] + Vector2(0, 1))
		_paths.append(pts)
	_t = 0.0
	visible = not _paths.is_empty()
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	if _paths.is_empty():
		return
	var total := 0.0
	var lens: Array[float] = []
	for pts in _paths:
		var l := 0.0
		for i in range(1, pts.size()):
			l += pts[i - 1].distance_to(pts[i])
		lens.append(l)
		total += l + 200.0   # пауза между мазками
	var along := fmod(_t * SPEED, total)
	for k in _paths.size():
		var pts := _paths[k]
		for i in range(1, pts.size()):
			var a := pts[i - 1]
			var b := pts[i]
			var n := int(a.distance_to(b) / 16.0)
			for j in n:
				draw_circle(a.lerp(b, (j + 0.5) / maxf(1.0, n)), 3.5, DOT)
		if along >= 0.0 and along <= lens[k]:
			var p := _point_at(pts, along)
			var pulse := 1.0 + 0.12 * sin(_t * 10.0)
			draw_circle(p, 22.0 * pulse, Color(1, 0.9, 0.5, 0.35))
			draw_circle(p, 13.0, FINGER)
			draw_arc(p, 13.0, 0, TAU, 24, EDGE, 3.0)
		along -= lens[k] + 200.0


static func _point_at(pts: PackedVector2Array, d: float) -> Vector2:
	for i in range(1, pts.size()):
		var l := pts[i - 1].distance_to(pts[i])
		if d <= l:
			return pts[i - 1].lerp(pts[i], d / maxf(l, 0.001))
		d -= l
	return pts[pts.size() - 1]
