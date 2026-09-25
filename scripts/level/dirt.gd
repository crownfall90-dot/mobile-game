class_name Dirt
extends Node2D
## Земля, которую игрок копает пальцем. Поле делится на клетки CELL×CELL: клетка либо земля,
## либо пусто. Столкновения — прямоугольники по непрерывным отрезкам каждой строки
## (пересобираются только изменённые строки), вид — маска клеток через шейдер с мягким краем.
##
## JSON: "dirt": [{"rect": [x, y, w, h]} | {"poly": [[x, y], ...]}, ...] — где есть земля;
##       "holes": [{"rect": ...} | {"circle": [x, y, r]}, ...] — заранее пустые карманы.

signal dug(at: Vector2)

const CELL := 4
const BRUSH := 24.0
const SHADER := preload("res://shaders/dirt.gdshader")

var cols := 0
var rows := 0
var _cells := PackedByteArray()
var _body: StaticBody2D
var _row_shapes: Array = []        # строка -> Array[CollisionShape2D]
var _dirty_rows := {}
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _mask_dirty := false
var _count := 0


func setup(size: Vector2, shapes: Array, holes: Array) -> void:
	cols = int(ceil(size.x / CELL))
	rows = int(ceil(size.y / CELL))
	_cells.resize(cols * rows)
	_cells.fill(0)
	for s in shapes:
		_paint(s, 1)
	for h in holes:
		_paint(h, 0)
	_body = StaticBody2D.new()
	_body.collision_layer = Substances.LAYER_WORLD
	_body.collision_mask = 0
	add_child(_body)
	_row_shapes.resize(rows)
	for r in rows:
		_row_shapes[r] = []
		_build_row(r)
	_image = Image.create(cols, rows, false, Image.FORMAT_L8)
	_update_image()
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _texture
	_sprite.scale = Vector2(CELL, CELL)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter(&"cells", Vector2(cols, rows))
	_sprite.material = mat
	add_child(_sprite)


func is_empty() -> bool:
	return _count == 0


func solid_at(p: Vector2) -> bool:
	var c := int(p.x / CELL)
	var r := int(p.y / CELL)
	return c >= 0 and r >= 0 and c < cols and r < rows and _cells[r * cols + c] == 1


## Выкопать полосу от a до b кистью BRUSH. true — что-то выкопано.
func carve(a: Vector2, b: Vector2, radius := BRUSH) -> bool:
	var any := false
	var steps := maxi(1, int(a.distance_to(b) / 4.0))
	for i in steps + 1:
		if _carve_circle(a.lerp(b, float(i) / steps), radius):
			any = true
	if any:
		dug.emit(b)
	return any


func _physics_process(_delta: float) -> void:
	if not _dirty_rows.is_empty():
		for r in _dirty_rows:
			_build_row(r)
		_dirty_rows.clear()
	if _mask_dirty:
		_mask_dirty = false
		_update_image()
		_texture.update(_image)


func _carve_circle(p: Vector2, radius: float) -> bool:
	var any := false
	var r2 := radius * radius
	var c0 := maxi(0, int((p.x - radius) / CELL))
	var c1 := mini(cols - 1, int((p.x + radius) / CELL))
	var r0 := maxi(0, int((p.y - radius) / CELL))
	var r1 := mini(rows - 1, int((p.y + radius) / CELL))
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			var i := r * cols + c
			if _cells[i] == 0:
				continue
			var center := Vector2((c + 0.5) * CELL, (r + 0.5) * CELL)
			if center.distance_squared_to(p) <= r2:
				_cells[i] = 0
				_count -= 1
				_dirty_rows[r] = true
				any = true
	if any:
		_mask_dirty = true
	return any


func _paint(shape: Dictionary, value: int) -> void:
	var poly := PackedVector2Array()
	var circle := Vector3.ZERO
	var box := Rect2()
	if shape.has("poly"):
		for p in shape["poly"]:
			poly.append(Vector2(p[0], p[1]))
	elif shape.has("circle"):
		var c: Array = shape["circle"]
		circle = Vector3(c[0], c[1], c[2])
	elif shape.has("rect"):
		var v: Array = shape["rect"]
		box = Rect2(v[0], v[1], v[2], v[3])
	for r in rows:
		for c in cols:
			var p := Vector2((c + 0.5) * CELL, (r + 0.5) * CELL)
			var inside := false
			if poly.size() >= 3:
				inside = Geometry2D.is_point_in_polygon(p, poly)
			elif circle.z > 0.0:
				inside = p.distance_to(Vector2(circle.x, circle.y)) <= circle.z
			else:
				inside = box.has_point(p)
			if inside:
				var i := r * cols + c
				if _cells[i] != value:
					_count += 1 if value == 1 else -1
				_cells[i] = value


func _build_row(r: int) -> void:
	for cs: CollisionShape2D in _row_shapes[r]:
		cs.queue_free()
	var list: Array = []
	var c := 0
	while c < cols:
		if _cells[r * cols + c] == 0:
			c += 1
			continue
		var start := c
		while c < cols and _cells[r * cols + c] == 1:
			c += 1
		var shape := RectangleShape2D.new()
		shape.size = Vector2((c - start) * CELL, CELL)
		var cs := CollisionShape2D.new()
		cs.shape = shape
		cs.position = Vector2((start + c) * 0.5 * CELL, (r + 0.5) * CELL)
		_body.add_child(cs)
		list.append(cs)
	_row_shapes[r] = list


func _update_image() -> void:
	for r in rows:
		for c in cols:
			_image.set_pixel(c, r, Color(1, 1, 1) if _cells[r * cols + c] == 1 else Color(0, 0, 0))
