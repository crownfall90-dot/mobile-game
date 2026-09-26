extends Node2D
## «Стопка посуды»: полки в шкафу держатся каждая на одной опоре и качаются (пружина тянет
## к ровному положению). Посуда по одной появляется наверху: палец ведёт её, отпустил — падает.
## Тяжёлое — ближе к опоре, края уравновешивай: перекосило больше, чем держит трение, —
## посуда съезжает и разбивается о дно шкафа (проигрыш). Таракан на полке убегает, если рядом
## поставить посуду. Победа: вся посуда стоит на полках, всё замерло, таракана нет.
## Полка держится на одном винте: перекосило сильнее BREAK_ANGLE дольше BREAK_TIME — винт
## вырывает, полка падает вместе с посудой (проигрыш). Чем ближе к пределу, тем краснее винт.
## Уровень: "dishes": {queue: [plate|cup|bowl|pot], shelves: [{id, rect, pivot, stiff, damp}],
## spawn: [x, y], floor_y, sides: [x0, x1]}.

signal broke(pos: Vector2)
signal snapped(pos: Vector2)
signal dropped
signal touched_enemy(enemy: Node)

const KINDS := {
	"plate": {"size": Vector2(112, 14), "mass": 1.0},
	"cup": {"size": Vector2(44, 44), "mass": 0.6},
	"bowl": {"size": Vector2(88, 34), "mass": 1.2},
	"pot": {"size": Vector2(112, 64), "mass": 2.6},
}
const NEXT_DELAY := 0.5       # через сколько после броска появится следующая посуда
const LIMIT := 0.49           # дальше полка не наклоняется, рад (~28°)
const BREAK_ANGLE := 0.38     # винт не держит, рад (~22°)
const BREAK_TIME := 0.3
const FRICTION := 0.35        # посуда съезжает с полки, наклонённой круче ~19°
const WOOD := Color("c8955f")
const WOOD_DARK := Color("7a5236")
const WOOD_LIGHT := Color("e2b98a")

var queue: Array = []
var shelves: Array[RigidBody2D] = []
var dishes: Array[RigidBody2D] = []
var held: RigidBody2D = null
var spawn := Vector2(360, 230)
var floor_y := 1190.0
var sides := Vector2(114, 604)
var broken := false
var _next_in := 0.0
var _stiff: Array[float] = []
var _damp: Array[float] = []
var _over: Array[float] = []
var _pins: Array[PinJoint2D] = []
var _mat: PhysicsMaterial
var _t := 0.0


func setup(cfg: Dictionary) -> void:
	_mat = PhysicsMaterial.new()
	_mat.friction = FRICTION
	_mat.bounce = 0.05
	queue = cfg.get("queue", []).duplicate()
	spawn = Vector2(cfg.get("spawn", [360, 230])[0], cfg.get("spawn", [360, 230])[1])
	floor_y = float(cfg.get("floor_y", 1190.0))
	var sd: Array = cfg.get("sides", [114, 604])
	sides = Vector2(float(sd[0]), float(sd[1]))
	# стенки шкафа по бокам: съехавшая посуда падает вниз, а не за край
	var walls := StaticBody2D.new()
	walls.collision_layer = Substances.LAYER_WORLD
	walls.physics_material_override = _mat
	for x in [sides.x - 24.0, sides.y]:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(24, floor_y + 200.0)
		cs.shape = sh
		cs.position = Vector2(x + 12.0, (floor_y + 200.0) * 0.5)
		walls.add_child(cs)
	add_child(walls)
	for s in cfg.get("shelves", []):
		_add_shelf(s)
	_next_in = 0.3


func _add_shelf(s: Dictionary) -> void:
	var r := Rect2(s["rect"][0], s["rect"][1], s["rect"][2], s["rect"][3])
	var pivot := Vector2(r.position.x + r.size.x * float(s.get("pivot", 0.5)), r.get_center().y)
	var body := RigidBody2D.new()
	body.collision_layer = Substances.LAYER_WORLD
	body.collision_mask = Substances.LAYER_ITEMS
	body.gravity_scale = 0.0            # полку клонит только посуда
	body.mass = 4.0
	body.angular_damp = 1.5
	body.can_sleep = false
	body.physics_material_override = _mat
	body.position = pivot
	body.set_meta(&"rect", Rect2(r.position - pivot, r.size))
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.get_center() - pivot
	body.add_child(cs)
	add_child(body)
	var anchor := StaticBody2D.new()
	anchor.collision_layer = 0
	anchor.position = pivot
	add_child(anchor)
	var pin := PinJoint2D.new()
	pin.position = pivot
	pin.angular_limit_enabled = true
	pin.angular_limit_lower = -LIMIT
	pin.angular_limit_upper = LIMIT
	pin.disable_collision = true
	add_child(pin)
	pin.node_a = pin.get_path_to(anchor)
	pin.node_b = pin.get_path_to(body)
	shelves.append(body)
	_pins.append(pin)
	_over.append(0.0)
	_stiff.append(float(s.get("stiff", 3.0e6)))
	_damp.append(float(s.get("damp", 2.0e5)))


## Сколько посуды уже стоит на полках (для счётчика цели).
func placed_count() -> int:
	var n := 0
	for d in dishes:
		if d.get_meta(&"landed", false):
			n += 1
	return n


func total() -> int:
	return queue.size() + dishes.size() + (1 if held else 0)


## Всё расставлено и замерло.
func calm() -> bool:
	if broken or held != null or not queue.is_empty():
		return false
	for d in dishes:
		if d.linear_velocity.length() > 6.0 or absf(d.angular_velocity) > 0.3:
			return false
	for s in shelves:
		if absf(s.angular_velocity) > 0.05:
			return false
	return true


## Палец взял текущую посуду (если она уже появилась) и ведёт её.
func grab(p: Vector2) -> bool:
	if held == null or broken:
		return false
	hold_at(p)
	return true


func hold_at(p: Vector2) -> void:
	if held == null:
		return
	var half: Vector2 = KINDS[held.get_meta(&"kind")]["size"] * 0.5
	held.position = Vector2(clampf(p.x, sides.x + half.x, sides.y - half.x), clampf(p.y, 150.0, floor_y - 200.0))


## Отпустить: посуда падает оттуда, где её держали.
func drop() -> void:
	if held == null:
		return
	var d := held
	held = null
	d.freeze = false
	d.linear_velocity = Vector2.ZERO
	d.set_meta(&"dropped", true)
	dishes.append(d)
	_next_in = NEXT_DELAY
	dropped.emit()


func ready_to_drop() -> bool:
	return held != null


func step(delta: float) -> void:
	_t += delta
	for i in shelves.size():
		var s := shelves[i]
		if _pins[i] == null:
			continue
		s.apply_torque(-_stiff[i] * s.rotation - _damp[i] * s.angular_velocity)
		if absf(s.rotation) > LIMIT and s.angular_velocity * signf(s.rotation) > 0.0:
			s.angular_velocity = 0.0
		_over[i] = _over[i] + delta if absf(s.rotation) > BREAK_ANGLE else 0.0
		if _over[i] > BREAK_TIME:
			_snap(i)
	if held == null and not queue.is_empty() and not broken:
		_next_in -= delta
		if _next_in <= 0.0:
			_spawn_next()
	for d in dishes:
		if not d.get_meta(&"landed", false) and d.get_contact_count() > 0 and d.linear_velocity.length() < 40.0:
			d.set_meta(&"landed", true)
		if not broken and (d.position.y > floor_y or d.position.x < sides.x - 30.0 or d.position.x > sides.y + 30.0):
			broken = true
			broke.emit(d.position)
	queue_redraw()


## Починено: полки и посуда замирают как есть (дальше физика их не трогает).
func settle_all() -> void:
	for d in dishes:
		d.freeze = true
	for sh in shelves:
		sh.freeze = true
	if held:
		held.queue_free()
		held = null
	queue.clear()


## Винт вырвало: полка падает, посуда с ней.
func _snap(i: int) -> void:
	var s := shelves[i]
	_pins[i].queue_free()
	_pins[i] = null
	s.gravity_scale = 1.0
	s.collision_mask = 0
	snapped.emit(s.position)


func _spawn_next() -> void:
	var kind := str(queue.pop_front())
	var d := Dish.new()
	d.kind = kind
	d.set_meta(&"kind", kind)
	d.collision_layer = Substances.LAYER_ITEMS
	d.collision_mask = Substances.LAYER_WORLD | Substances.LAYER_ITEMS | Substances.LAYER_ENEMY
	d.mass = float(KINDS[kind]["mass"])
	d.physics_material_override = _mat
	d.contact_monitor = true
	d.max_contacts_reported = 4
	d.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	d.freeze = true
	d.position = spawn
	var size: Vector2 = KINDS[kind]["size"]
	var cs := CollisionShape2D.new()
	if kind == "bowl":
		var poly := ConvexPolygonShape2D.new()
		poly.points = PackedVector2Array([Vector2(-size.x * 0.5, -size.y * 0.5), Vector2(size.x * 0.5, -size.y * 0.5),
			Vector2(size.x * 0.3, size.y * 0.5), Vector2(-size.x * 0.3, size.y * 0.5)])
		cs.shape = poly
	else:
		var sh := RectangleShape2D.new()
		sh.size = size
		cs.shape = sh
	d.add_child(cs)
	d.body_entered.connect(func(b: Node) -> void:
		if b is Enemy:
			touched_enemy.emit(b))
	add_child(d)
	held = d


func _draw() -> void:
	for s in shelves:
		var r: Rect2 = s.get_meta(&"rect")
		draw_set_transform(s.position, s.rotation, Vector2.ONE)
		draw_rect(r.grow(2.0), WOOD_DARK)
		draw_rect(r, WOOD)
		draw_line(r.position + Vector2(4, 3), Vector2(r.end.x - 4, r.position.y + 3), WOOD_LIGHT, 2.0)
		# винт опоры — ось качания; краснеет, когда полку перекашивает
		var strain := clampf(absf(s.rotation) / BREAK_ANGLE, 0.0, 1.0)
		var screw := Color("8d969b").lerp(Color("e0452b"), strain * strain)
		if strain > 0.7:
			draw_arc(Vector2.ZERO, 14.0 + 4.0 * sin(_t * 18.0), 0.0, TAU, 20, Color(0.9, 0.3, 0.2, strain - 0.5), 3.0)
		draw_circle(Vector2.ZERO, 8.0, screw)
		draw_line(Vector2(-5, -5), Vector2(5, 5), Color("4d5559"), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if held:
		# куда упадёт: пунктир вниз от посуды
		var y := held.position.y + 30.0
		while y < floor_y:
			draw_line(Vector2(held.position.x, y), Vector2(held.position.x, y + 12.0), Color(1, 1, 1, 0.45), 3.0)
			y += 26.0


## Посуда: тарелка, чашка, миска, кастрюля (рисует код; художник может заменить картинками).
class Dish extends RigidBody2D:
	var kind := "plate"

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var a := 0.75 if freeze else 1.0
		match kind:
			"plate":
				draw_rect(Rect2(-56, -7, 112, 14), Color(0.35, 0.42, 0.55, a))
				draw_rect(Rect2(-54, -7, 108, 10), Color(0.97, 0.97, 0.95, a))
				draw_line(Vector2(-46, -4), Vector2(46, -4), Color(0.36, 0.56, 0.85, a), 2.0)
			"cup":
				draw_arc(Vector2(22, -2), 10.0, -PI * 0.5, PI * 0.5, 10, Color(0.95, 0.95, 0.93, a), 5.0)
				draw_rect(Rect2(-22, -22, 44, 44), Color(0.35, 0.42, 0.55, a))
				draw_rect(Rect2(-20, -22, 40, 42), Color(0.97, 0.97, 0.95, a))
				draw_rect(Rect2(-20, -10, 40, 7), Color(0.85, 0.35, 0.35, a))
			"bowl":
				var pts := PackedVector2Array([Vector2(-44, -17), Vector2(44, -17), Vector2(26, 17), Vector2(-26, 17)])
				draw_colored_polygon(pts, Color(0.95, 0.9, 0.8, a))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.45, 0.35, 0.25, a), 2.0)
				draw_line(Vector2(-36, -8), Vector2(36, -8), Color(0.3, 0.6, 0.4, a), 3.0)
			"pot":
				draw_rect(Rect2(-64, -18, 10, 8), Color(0.3, 0.3, 0.32, a))
				draw_rect(Rect2(54, -18, 10, 8), Color(0.3, 0.3, 0.32, a))
				draw_rect(Rect2(-56, -32, 112, 64), Color(0.43, 0.47, 0.49, a))
				draw_rect(Rect2(-53, -30, 106, 60), Color(0.73, 0.76, 0.78, a))
				draw_line(Vector2(-53, -20), Vector2(53, -20), Color(0.55, 0.58, 0.6, a), 3.0)
