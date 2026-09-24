class_name Fx
extends Node2D
## Лёгкая система частиц-эффектов: пар, искры, брызги, кольца.
## Все эффекты уровня рисуются одним узлом, без выделения памяти на каждый эффект.

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _size := PackedFloat32Array()
var _col := PackedColorArray()
var _grav := PackedFloat32Array()
var _rings: Array = []   # [pos, t, duration, radius, color]
var _rng := RandomNumberGenerator.new()
var _dirty := false


func burst(at: Vector2, color: Color, count: int, speed: float, size: float, gravity := 0.0, life := 0.6) -> void:
	for i in count:
		_pos.append(at)
		_vel.append(Vector2.from_angle(_rng.randf() * TAU) * speed * _rng.randf_range(0.35, 1.0))
		var l := life * _rng.randf_range(0.7, 1.2)
		_life.append(l)
		_max.append(l)
		_size.append(size * _rng.randf_range(0.6, 1.2))
		_col.append(color)
		_grav.append(gravity)


func ring(at: Vector2, color: Color, radius := 48.0, duration := 0.35) -> void:
	_rings.append([at, 0.0, duration, radius, color])


func _process(delta: float) -> void:
	if _pos.is_empty() and _rings.is_empty():
		if _dirty:
			_dirty = false
			queue_redraw()
		return
	var drag := pow(0.05, delta)
	var i := 0
	while i < _pos.size():
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		_vel[i] = _vel[i] * drag + Vector2(0, _grav[i] * delta)
		_pos[i] += _vel[i] * delta
		i += 1
	for j in range(_rings.size() - 1, -1, -1):
		_rings[j][1] += delta
		if _rings[j][1] >= _rings[j][2]:
			_rings.remove_at(j)
	_dirty = true
	queue_redraw()


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_life[i] = _life[last]
	_max[i] = _max[last]
	_size[i] = _size[last]
	_col[i] = _col[last]
	_grav[i] = _grav[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_max.resize(last)
	_size.resize(last)
	_col.resize(last)
	_grav.resize(last)


func _draw() -> void:
	for i in _pos.size():
		var k := _life[i] / _max[i]
		var c := _col[i]
		c.a *= k
		draw_circle(_pos[i], _size[i] * (0.4 + 0.6 * k), c)
	for r in _rings:
		var p: float = r[1] / r[2]
		var c: Color = r[4]
		c.a *= 1.0 - p
		draw_arc(r[0], r[3] * ease(p, 0.4), 0.0, TAU, 40, c, 4.0 * (1.0 - p) + 1.0, true)
