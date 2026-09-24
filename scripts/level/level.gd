class_name Level
extends Node2D
## Собирает уровень из JSON и ведёт его правила: реакции, победу, поражение.
## Формат данных описан в docs/LEVEL_FORMAT.md.

signal won(stars: int)
signal lost(reason: String)
signal gold_changed(collected: int, needed: int, total: int)
signal pin_pulled(pin: Pin)

const DESIGN_SIZE := Vector2(720, 1280)
const CHAIN_RADIUS := 25.0      # на каком расстоянии остывание перекидывается на соседнюю лаву
const CHAIN_DELAY := 0.04       # скорость "волны" застывания
const WIN_DELAY := 0.8
const STUCK_TIMEOUT := 5.0
const RESULT_DELAY := 1.0
const FALL_LIMIT := 1500.0
const SCARE_DISTANCE := 260.0

const STEAM := Color(1, 1, 1, 0.55)
const SPARK := Color("ffe27a")
const GOO := Color("b561ff")
const ACID_FIZZ := Color("b6ff6a")

var data: Dictionary = {}
var items: Array[Item] = []
var enemies: Array[Enemy] = []
var pins: Array[Pin] = []
var hero: Hero
var fx: Fx
var gold_total := 0
var gold_needed := 0
var gold_collected := 0
var finished := false
var camera: Camera2D   # для тряски экрана; задаёт Main

var _bodies: Node2D
var _rng := RandomNumberGenerator.new()
var _contacts: Array = []   # [other, source] — обрабатываются в _physics_process
var _zone_hits: Array = []
var _cooling: Array = []    # [оставшееся время, Item]
var _win_timer := -1.0
var _stuck_timer := -1.0
var _shake := 0.0
var _scare_timer := 0.0


func build(level_data: Dictionary) -> void:
	data = level_data
	_rng.seed = hash(str(data.get("id", "level")))

	var backdrop := Backdrop.new()
	backdrop.setup(_rect(data["tower"]["rect"]))
	add_child(backdrop)

	hero = Hero.new()
	hero.setup(_vec(data["hero"]["pos"]))
	add_child(hero)

	var fluid := FluidRenderer.new()
	add_child(fluid)

	_bodies = Node2D.new()
	add_child(_bodies)

	var walls := Walls.new()
	walls.setup(data.get("walls", []))
	add_child(walls)

	var glint := 0.0
	for p in data.get("pins", []):
		var pin := Pin.new()
		pin.setup(str(p["id"]), _vec(p["from"]), _vec(p["to"]), glint)
		pin.pulled_out.connect(_on_pin_out)
		add_child(pin)
		pins.append(pin)
		glint += 0.7

	fx = Fx.new()
	add_child(fx)

	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = Substances.LAYER_ITEMS | Substances.LAYER_ENEMY
	zone.monitorable = false
	var zr := _rect(data["hero"]["zone"])
	var zshape := RectangleShape2D.new()
	zshape.size = zr.size
	var zcs := CollisionShape2D.new()
	zcs.shape = zshape
	zcs.position = zr.get_center()
	zone.add_child(zcs)
	zone.body_entered.connect(func(b: Node2D) -> void: _zone_hits.append(b))
	add_child(zone)

	var fluid_count := 0
	for fill in data.get("fills", []):
		var kind := Substances.from_name(str(fill["kind"]))
		var n := _spawn_fill(kind, _rect(fill["rect"]), int(fill["count"]))
		if Substances.is_fluid(kind):
			fluid_count += n
		if kind == Substances.Kind.GOLD:
			gold_total += n

	for e in data.get("enemies", []):
		var enemy := Enemy.new()
		enemy.setup(_vec(e["pos"]), hero.position + Vector2(0, -70), report_contact)
		_bodies.add_child(enemy)
		enemies.append(enemy)

	var ratio := float(data.get("goal", {}).get("gold", 0.7))
	gold_needed = maxi(1, ceili(gold_total * ratio)) if gold_total > 0 else 0
	fluid.setup(self, DESIGN_SIZE, fluid_count)
	gold_changed.emit.call_deferred(gold_collected, gold_needed, gold_total)


func pin_by_id(pin_id: String) -> Pin:
	for pin in pins:
		if pin.id == pin_id:
			return pin
	return null


func pull_pin(pin: Pin) -> void:
	if finished or pin == null or pin.pulled:
		return
	pin.pull()
	fx.ring(pin.position, Pin.GOLD, 42.0)
	_wake_all()
	pin_pulled.emit(pin)


## Вызывается из сигналов body_entered капель и врагов.
func report_contact(other: Node, source: Node) -> void:
	_contacts.append([other, source])


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = make_input_local(event).position
	var best: Pin = null
	var best_d := Pin.HIT_RADIUS
	for pin in pins:
		if pin.pulled:
			continue
		var d := pin.distance_to_point(p)
		if d < best_d:
			best = pin
			best_d = d
	if best:
		pull_pin(best)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _contacts.is_empty():
		var batch := _contacts
		_contacts = []
		for c in batch:
			_resolve_contact(c[0], c[1])
	if not _zone_hits.is_empty():
		var hits := _zone_hits
		_zone_hits = []
		for b in hits:
			_on_zone_hit(b)
	_process_cooling(delta)
	_cull_fallen()
	_update_outcome(delta)


func _process(delta: float) -> void:
	if camera:
		if _shake > 0.0:
			camera.offset = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _shake
			_shake = move_toward(_shake, 0.0, delta * 40.0)
		elif camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
	_scare_timer -= delta
	if _scare_timer <= 0.0 and not finished:
		_scare_timer = 0.25
		hero.set_scared(_danger_near())


# --- реакции ---------------------------------------------------------------

func _resolve_contact(other: Node, source: Node) -> void:
	var enemy: Enemy = null
	var item: Item = null
	if source is Enemy and other is Item:
		enemy = source
		item = other
	elif source is Item and other is Enemy:
		enemy = other
		item = source
	if enemy:
		if enemy.alive and _alive(item) and Substances.is_deadly(item.kind):
			_kill_enemy(enemy)
		return
	if source is Item and other is Item and _alive(source) and _alive(other):
		_react(source, other)


func _react(a: Item, b: Item) -> void:
	var water := Substances.Kind.WATER
	var lava := Substances.Kind.LAVA
	var acid := Substances.Kind.ACID
	var stone := Substances.Kind.STONE
	if _is_pair(a, b, water, lava):
		# вода + лава = камень; от камня застывание волной идёт по соседней лаве
		var w := a if a.kind == water else b
		var l := b if w == a else a
		_solidify(l)
		_remove(w)
	elif _is_pair(a, b, acid, stone):
		# кислота растворяет камень
		fx.burst(a.position, ACID_FIZZ, 6, 120.0, 4.0, -200.0)
		_remove(a)
		_remove(b)
	elif _is_pair(a, b, acid, water):
		# вода разбавляет кислоту
		var ac := a if a.kind == acid else b
		ac.set_kind(water)
		fx.burst(ac.position, ACID_FIZZ, 3, 60.0, 3.0, -150.0)


func _solidify(item: Item) -> void:
	if not _alive(item) or item.kind != Substances.Kind.LAVA:
		return
	item.set_kind(Substances.Kind.STONE)
	item.sleeping = false
	fx.burst(item.position, STEAM, 2, 90.0, 7.0, -260.0, 0.8)
	var r2 := CHAIN_RADIUS * CHAIN_RADIUS
	for other in items:
		if other.kind == Substances.Kind.LAVA and not other.cooling and not other.removed \
				and other.position.distance_squared_to(item.position) < r2:
			other.cooling = true
			_cooling.append([CHAIN_DELAY, other])


func _process_cooling(delta: float) -> void:
	if _cooling.is_empty():
		return
	var due: Array[Item] = []
	for i in range(_cooling.size() - 1, -1, -1):
		_cooling[i][0] -= delta
		if _cooling[i][0] <= 0.0:
			due.append(_cooling[i][1])
			_cooling.remove_at(i)
	for item in due:
		_solidify(item)


func _kill_enemy(enemy: Enemy) -> void:
	enemy.kill()
	fx.burst(enemy.position, GOO, 22, 420.0, 7.0, 900.0, 0.7)
	fx.ring(enemy.position, GOO, 70.0, 0.4)
	_shake = 7.0


# --- зона героя и исход -----------------------------------------------------

func _on_zone_hit(body: Node) -> void:
	if body is Enemy:
		if body.alive and not finished:
			_lose("enemy")
		return
	if not (body is Item) or not _alive(body):
		return
	var item: Item = body
	match item.kind:
		Substances.Kind.GOLD:
			_collect(item)
		Substances.Kind.LAVA:
			if not finished:
				_lose("lava")
		Substances.Kind.ACID:
			if not finished:
				_lose("acid")


func _collect(item: Item) -> void:
	gold_collected += 1
	fx.burst(item.position, SPARK, 6, 220.0, 3.5, 0.0, 0.45)
	_remove(item)
	hero.bounce()
	gold_changed.emit(gold_collected, gold_needed, gold_total)


func _update_outcome(delta: float) -> void:
	if finished:
		return
	if _win_timer >= 0.0:
		_win_timer -= delta
		if _win_timer <= 0.0:
			_win()
		return
	if gold_collected >= gold_needed and _alive_enemies() == 0:
		_win_timer = WIN_DELAY
		return
	if _stuck_timer >= 0.0:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIMEOUT:
			_lose("stuck")


func _win() -> void:
	finished = true
	hero.celebrate()
	var c := hero.position + Vector2(0, -80)
	for col in [SPARK, Color("39d6ff"), Color("ff4fd8")]:
		fx.burst(c, col, 14, 520.0, 5.0, 700.0, 1.1)
	fx.ring(c, SPARK, 120.0, 0.5)
	var ratio := float(gold_collected) / maxf(1.0, gold_total)
	var stars := 3 if ratio >= 0.95 else (2 if ratio >= (1.0 + float(gold_needed) / gold_total) * 0.5 else 1)
	get_tree().create_timer(RESULT_DELAY).timeout.connect(func() -> void: won.emit(stars))


func _lose(reason: String) -> void:
	finished = true
	hero.die()
	_shake = 12.0
	get_tree().create_timer(RESULT_DELAY).timeout.connect(func() -> void: lost.emit(reason))


func _on_pin_out(_pin: Pin) -> void:
	_wake_all()
	for pin in pins:
		if not pin.pulled:
			return
	_stuck_timer = 0.0


# --- служебное --------------------------------------------------------------

func _spawn_fill(kind: int, rect: Rect2, count: int) -> int:
	var r := Substances.radius(kind)
	var step := r * 2.05
	var cols := maxi(1, int(rect.size.x / step))
	for i in count:
		var cx := i % cols
		var cy := int(i / float(cols))
		var shift := step * 0.25 if cy % 2 == 1 else 0.0
		var pos := Vector2(rect.position.x + step * 0.5 + cx * step + shift, rect.end.y - step * 0.5 - cy * step)
		var item := Item.new()
		item.setup(kind, pos, _rng.randi())
		if item.contact_monitor:
			item.body_entered.connect(report_contact.bind(item))
		_bodies.add_child(item)
		items.append(item)
	return count


func _remove(item: Item) -> void:
	if item.removed:
		return
	item.removed = true
	items.erase(item)
	item.queue_free()


func _cull_fallen() -> void:
	for i in range(items.size() - 1, -1, -1):
		if items[i].position.y > FALL_LIMIT:
			_remove(items[i])


func _wake_all() -> void:
	for item in items:
		item.sleeping = false
	for e in enemies:
		if e.alive:
			e.sleeping = false


func _danger_near() -> bool:
	var head := hero.position + Vector2(0, -60)
	var d2 := SCARE_DISTANCE * SCARE_DISTANCE
	for e in enemies:
		if e.alive and e.position.distance_squared_to(head) < d2:
			return true
	for item in items:
		if Substances.is_deadly(item.kind) and item.position.distance_squared_to(head) < d2:
			return true
	return false


func _alive_enemies() -> int:
	var n := 0
	for e in enemies:
		if e.alive:
			n += 1
	return n


static func _alive(item: Item) -> bool:
	return item != null and is_instance_valid(item) and not item.removed


static func _is_pair(a: Item, b: Item, k1: int, k2: int) -> bool:
	return (a.kind == k1 and b.kind == k2) or (a.kind == k2 and b.kind == k1)


static func _vec(v: Array) -> Vector2:
	return Vector2(v[0], v[1])


static func _rect(v: Array) -> Rect2:
	return Rect2(v[0], v[1], v[2], v[3])
