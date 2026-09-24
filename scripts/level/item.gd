class_name Item
extends RigidBody2D
## Одна частица вещества: капля жидкости, монета/кристалл или камень.
## Жидкости сами себя не рисуют: их рисует FluidRenderer одним проходом.

const GEM_COLORS: Array[Color] = [Color("39d6ff"), Color("ff4fd8"), Color("4dff9a")]

var kind: int = Substances.Kind.WATER
var removed := false
var cooling := false
var radius := Substances.RADIUS

var _shape := PackedVector2Array()
var _shape_colors := PackedColorArray()
var _gem := false
var _gem_color := Color.WHITE
var _rng_seed := 0


func setup(k: int, pos: Vector2, rng_seed: int) -> void:
	position = pos
	_rng_seed = rng_seed
	radius = Substances.radius(k)
	collision_layer = Substances.LAYER_ITEMS
	collision_mask = Substances.LAYER_WORLD | Substances.LAYER_ITEMS | Substances.LAYER_ENEMY
	var circle := CircleShape2D.new()
	circle.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = circle
	add_child(cs)
	# Реакции отслеживают только "активные" вещества, чтобы не платить за контакты всех тел.
	if k == Substances.Kind.WATER or k == Substances.Kind.ACID:
		contact_monitor = true
		max_contacts_reported = 3
	set_kind(k)


func set_kind(k: int) -> void:
	kind = k
	mass = Substances.mass(k)
	linear_damp = Substances.damp(k)
	physics_material_override = Substances.material(k)
	_build_shape()
	queue_redraw()


func _build_shape() -> void:
	_shape.clear()
	_shape_colors.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _rng_seed
	if kind == Substances.Kind.STONE:
		var n := 7
		for i in n:
			var a := TAU * i / n + rng.randf_range(-0.2, 0.2)
			var p := Vector2.from_angle(a) * radius * rng.randf_range(0.85, 1.2)
			_shape.append(p)
			_shape_colors.append(Color("8d8aa3").lerp(Color("4a4760"), (p.y + radius) / (2.0 * radius)))
	elif kind == Substances.Kind.GOLD:
		_gem = rng.randf() < 0.35
		_gem_color = GEM_COLORS[rng.randi() % GEM_COLORS.size()]
		if _gem:
			for i in 6:
				_shape.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * radius * 1.1)


func _draw() -> void:
	match kind:
		Substances.Kind.STONE:
			draw_polygon(_shape, _shape_colors)
			var outline := _shape.duplicate()
			outline.append(_shape[0])
			draw_polyline(outline, Color("2c2a3a"), 1.5, true)
			draw_circle(Vector2(-2.5, -3.0), 2.2, Color(1, 1, 1, 0.25))
		Substances.Kind.GOLD:
			if _gem:
				_draw_gem()
			else:
				_draw_coin()


func _draw_coin() -> void:
	# Блик всегда сверху-слева, даже когда монета катится.
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_circle(Vector2.ZERO, radius, Color("b8741a"), true, -1.0, true)
	draw_circle(Vector2(0, -0.8), radius - 2.0, Color("ffc933"), true, -1.0, true)
	draw_circle(Vector2(0, -0.8), radius - 5.0, Color("ffdf6b"), false, 1.5, true)
	draw_circle(Vector2(-3.5, -4.0), 2.4, Color(1, 1, 1, 0.75))


func _draw_gem() -> void:
	draw_colored_polygon(_shape, _gem_color.darkened(0.35))
	var inner := PackedVector2Array()
	for p in _shape:
		inner.append(p * 0.55 + Vector2(0, -1.5))
	draw_colored_polygon(inner, _gem_color.lightened(0.25))
	draw_line(_shape[3] * 0.9, _shape[4] * 0.9, Color(1, 1, 1, 0.7), 1.5, true)
