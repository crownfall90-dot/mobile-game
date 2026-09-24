class_name Level
extends Node2D
## Собирает уровень из JSON и ведёт его правила: реакции, победу, поражение.
## Формат данных описан в docs/LEVEL_FORMAT.md.
##
## Уровень не зовёт звук, вибрацию, Profile и Economy: он только шлёт сигналы,
## а экран и слой эффектов на них отвечают. Так проверка без окна остаётся чистой.

signal won(stars: int)
signal lost(reason: String)
signal gold_changed(collected: int, needed: int, total: int)
signal pin_pulled(pin: Pin)
## steam {}, stone {n}, wave_end {n}, slime_pop {enemy, killer}, acid_stone, dilute, noble_gold
signal reaction(id: StringName, pos: Vector2, info: Dictionary)
## &"coin", &"gem", &"relic"
signal collected(kind: StringName, pos: Vector2)

const DESIGN_SIZE := Vector2(720, 1280)
const CHAIN_RADIUS := 25.0      # на каком расстоянии остывание перекидывается на соседнюю лаву
const CHAIN_DELAY := 0.04       # скорость "волны" застывания
const WIN_QUIET := 0.8          # победа, когда цель выполнена и столько секунд не пришло ни монеты...
const WIN_CAP := 3.0            # ...но не позже, чем через столько после выполнения цели
const STUCK_TIMEOUT := 5.0
const FALL_LIMIT := 1500.0
const SCARE_DISTANCE := 260.0
const THREE_STAR_PERCENT := 95  # 3 звезды за столько % сокровищ (для цели-доли)

## Кого чем можно убить: вид врага -> вещества.
const VULNERABLE := {
	&"slime": [Substances.Kind.LAVA, Substances.Kind.ACID],
}

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
var camera: Camera2D   # для тряски экрана; задаёт GameScreen (null — без тряски)

## Задать до build(): ±1 px к каждому телу при появлении (0 — выкл.). Только для проверок.
var jitter_seed := 0
var hero_outfit: Dictionary = {}
var familiar_kind: StringName = &""

var pieces_total := 0      # монеты + самоцветы на уровне
var pieces_needed := 0
var pieces := 0            # собрано
var coins_pieces := 0
var gems := 0
var relic := false
var finished := false

var _three_needed := 0
var _two_needed := 0
var _result: Dictionary = {}
var _reactions: Dictionary = {}   # вид_a * 16 + вид_b -> Callable(a, b)
var _pulled := PackedStringArray()
var _bodies: Node2D
var _rng := RandomNumberGenerator.new()      # только внешний вид
var _jitter: RandomNumberGenerator = null
var _contacts: Array = []   # [other, source] — обрабатываются в _physics_process
var _zone_hits: Array = []
var _cooling: Array = []    # [оставшееся время, Item]
var _wave_n := 0
var _wave_pos := Vector2.ZERO
var _noble_seen := false
var _goal_time := -1.0      # сколько цель уже выполнена (-1 — ещё нет)
var _since_collect := 0.0
var _stuck_timer := -1.0
var _shake := 0.0
var _scare_timer := 0.0


## Таблица реакций: пара веществ -> обработчик. Новая реакция — одна строка здесь.
func _init() -> void:
	_add_reaction(Substances.Kind.WATER, Substances.Kind.LAVA, _water_lava)
	_add_reaction(Substances.Kind.ACID, Substances.Kind.STONE, _acid_stone)
	_add_reaction(Substances.Kind.ACID, Substances.Kind.WATER, _acid_water)
	_add_reaction(Substances.Kind.ACID, Substances.Kind.GOLD, _acid_gold)
	_add_reaction(Substances.Kind.ACID, Substances.Kind.GEM, _acid_gold)


func build(level_data: Dictionary) -> void:
	data = level_data
	_rng.seed = hash(str(data.get("id", "level")))
	if jitter_seed != 0:
		_jitter = RandomNumberGenerator.new()
		_jitter.seed = jitter_seed

	var backdrop := Backdrop.new()
	backdrop.setup(_rect(data["tower"]["rect"]))
	add_child(backdrop)

	hero = Hero.new()
	hero.setup(_vec(data["hero"]["pos"]))
	if not hero_outfit.is_empty() and hero.has_method(&"set_outfit"):
		hero.call(&"set_outfit", hero_outfit)
	if familiar_kind != &"" and hero.has_method(&"set_familiar"):
		hero.call(&"set_familiar", familiar_kind)
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
		if Substances.is_piece(kind):
			pieces_total += n

	for e in data.get("enemies", []):
		var enemy := Enemy.new()
		enemy.setup(_jittered(_vec(e["pos"])), hero.position + Vector2(0, -70), report_contact)
		enemy.collision_mask |= Substances.LAYER_SIEVE
		enemy.set_meta(&"kind", StringName(str(e.get("kind", "slime"))))
		_bodies.add_child(enemy)
		enemies.append(enemy)

	_setup_goal()
	fluid.setup(self, DESIGN_SIZE, fluid_count)
	gold_changed.emit.call_deferred(pieces, pieces_needed, pieces_total)


func pin_by_id(pin_id: String) -> Pin:
	for pin in pins:
		if pin.id == pin_id:
			return pin
	return null


func pull_pin(pin: Pin) -> void:
	if finished or pin == null or pin.pulled:
		return
	pin.pull()
	_pulled.append(pin.id)
	fx.ring(pin.position, Pin.GOLD, 42.0)
	_wake_all()
	pin_pulled.emit(pin)


## Засовы в порядке, в котором их тянули.
func pulled_ids() -> PackedStringArray:
	return _pulled.duplicate()


## Подсветка засова для подсказки: кольцо и рука. "" снимает.
func set_hint_pin(pin_id: String) -> void:
	for pin in pins:
		pin.set_hint(pin_id != "" and pin.id == pin_id and not pin.pulled)


## Итог уровня: {won, stars, pieces, pieces_total, needed, coins_pieces, gems, relic, reason}.
## После won/lost — снимок того момента, из которого посчитаны звёзды; дальше он не меняется.
func result() -> Dictionary:
	if finished:
		return _result.duplicate()
	return _snapshot(false, "")


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

func _add_reaction(k1: int, k2: int, handler: Callable) -> void:
	_reactions[k1 * 16 + k2] = handler


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
		if enemy.alive and _alive(item) and VULNERABLE.get(_enemy_kind(enemy), []).has(item.kind):
			_kill_enemy(enemy, item)
		return
	if source is Item and other is Item and _alive(source) and _alive(other):
		_react(source, other)


## Ищет обработчик пары в любом порядке; первым аргументом идёт тело первого вида.
func _react(a: Item, b: Item) -> void:
	var handler: Callable = _reactions.get(a.kind * 16 + b.kind, Callable())
	if handler.is_valid():
		handler.call(a, b)
		return
	handler = _reactions.get(b.kind * 16 + a.kind, Callable())
	if handler.is_valid():
		handler.call(b, a)


# вода + лава = камень; от камня застывание волной идёт по соседней лаве
func _water_lava(water: Item, lava: Item) -> void:
	reaction.emit(&"steam", lava.position, {})
	_solidify(lava)
	_remove(water)


# кислота растворяет камень
func _acid_stone(acid: Item, stone: Item) -> void:
	fx.burst(acid.position, ACID_FIZZ, 6, 120.0, 4.0, -200.0)
	reaction.emit(&"acid_stone", stone.position, {})
	_remove(acid)
	_remove(stone)


# вода разбавляет кислоту
func _acid_water(acid: Item, _water: Item) -> void:
	acid.set_kind(Substances.Kind.WATER)
	fx.burst(acid.position, ACID_FIZZ, 3, 60.0, 3.0, -150.0)
	reaction.emit(&"dilute", acid.position, {})


# благородный металл: кислота золоту ничего не делает (секрет гримуара)
func _acid_gold(_acid: Item, gold: Item) -> void:
	if not _noble_seen:
		_noble_seen = true
		reaction.emit(&"noble_gold", gold.position, {})


func _solidify(item: Item) -> void:
	if not _alive(item) or item.kind != Substances.Kind.LAVA:
		return
	item.set_kind(Substances.Kind.STONE)
	item.sleeping = false
	fx.burst(item.position, STEAM, 2, 90.0, 7.0, -260.0, 0.8)
	_wave_n += 1
	_wave_pos = item.position
	reaction.emit(&"stone", item.position, {"n": _wave_n})
	var r2 := CHAIN_RADIUS * CHAIN_RADIUS
	for other in items:
		if other.kind == Substances.Kind.LAVA and not other.cooling and not other.removed \
				and other.position.distance_squared_to(item.position) < r2:
			other.cooling = true
			_cooling.append([CHAIN_DELAY, other])


func _process_cooling(delta: float) -> void:
	if not _cooling.is_empty():
		var due: Array[Item] = []
		for i in range(_cooling.size() - 1, -1, -1):
			_cooling[i][0] -= delta
			if _cooling[i][0] <= 0.0:
				due.append(_cooling[i][1])
				_cooling.remove_at(i)
		for item in due:
			_solidify(item)
	if _cooling.is_empty() and _wave_n > 0:
		reaction.emit(&"wave_end", _wave_pos, {"n": _wave_n})
		_wave_n = 0


func _kill_enemy(enemy: Enemy, killer: Item) -> void:
	enemy.kill()
	fx.burst(enemy.position, GOO, 22, 420.0, 7.0, 900.0, 0.7)
	fx.ring(enemy.position, GOO, 70.0, 0.4)
	_shake = 7.0
	reaction.emit(&"slime_pop", enemy.position,
		{"enemy": _enemy_kind(enemy), "killer": StringName(Substances.name_of(killer.kind))})


# --- зона героя и исход -----------------------------------------------------

func _on_zone_hit(body: Node) -> void:
	# после победы или поражения счёт замирает: итог уже посчитан
	if finished:
		return
	if body is Enemy:
		if body.alive:
			_lose("enemy")
		return
	if not (body is Item) or not _alive(body):
		return
	var item: Item = body
	if Substances.is_piece(item.kind):
		_collect(item)
	elif Substances.is_deadly(item.kind):
		_lose(Substances.name_of(item.kind))


func _collect(item: Item) -> void:
	var gem := item.kind == Substances.Kind.GEM
	pieces += 1
	if gem:
		gems += 1
	else:
		coins_pieces += 1
	_since_collect = 0.0
	var pos := item.position
	fx.burst(pos, SPARK, 6, 220.0, 3.5, 0.0, 0.45)
	_remove(item)
	hero.bounce()
	collected.emit(&"gem" if gem else &"coin", pos)
	gold_changed.emit(pieces, pieces_needed, pieces_total)


func _update_outcome(delta: float) -> void:
	if finished:
		return
	_since_collect += delta
	# до первого засова уровень не решается, даже если собирать нечего
	if _pulled.is_empty():
		return
	if pieces >= pieces_needed and _alive_enemies() == 0:
		# окно победы: ждём, пока докатятся монеты, но не бесконечно. Тишина считается
		# не раньше, чем цель выполнена: лава, убившая последнего врага, ещё может
		# долететь до героини, и поражение должно успеть сработать.
		_goal_time = maxf(_goal_time, 0.0) + delta
		if _goal_time >= WIN_CAP or minf(_since_collect, _goal_time) >= WIN_QUIET:
			_win()
		return
	if _stuck_timer >= 0.0:
		_stuck_timer += delta
		if _stuck_timer > STUCK_TIMEOUT:
			_lose("stuck")


func _win() -> void:
	_finish(true, "")
	hero.celebrate()
	var c := hero.position + Vector2(0, -80)
	for col in [SPARK, Color("39d6ff"), Color("ff4fd8")]:
		fx.burst(c, col, 14, 520.0, 5.0, 700.0, 1.1)
	fx.ring(c, SPARK, 120.0, 0.5)
	won.emit(int(_result["stars"]))


func _lose(reason: String) -> void:
	_finish(false, reason)
	if hero.has_method(&"oops"):
		hero.call(&"oops", reason)
	else:
		hero.die()
	_shake = 12.0
	lost.emit(reason)


func _finish(win: bool, reason: String) -> void:
	finished = true
	_result = _snapshot(win, reason)
	set_hint_pin("")


func _snapshot(win: bool, reason: String) -> Dictionary:
	return {
		"won": win, "stars": _stars_for(pieces) if win else 0,
		"pieces": pieces, "pieces_total": pieces_total, "needed": pieces_needed,
		"coins_pieces": coins_pieces, "gems": gems, "relic": relic, "reason": reason,
	}


## Цель: доля {"gold": 0.7} или число {"pieces": 16, "three_star": 26}.
func _setup_goal() -> void:
	var goal: Dictionary = data.get("goal", {})
	if goal.has("pieces"):
		pieces_needed = int(goal["pieces"])
		_three_needed = int(goal.get("three_star", pieces_needed))
	elif pieces_total > 0:
		var share := float(goal.get("gold", 0.7))
		pieces_needed = maxi(1, ceili(pieces_total * share - 0.0001))
		_three_needed = (pieces_total * THREE_STAR_PERCENT + 99) / 100
	_three_needed = maxi(_three_needed, pieces_needed)
	_two_needed = ceili((pieces_needed + _three_needed) * 0.5)


## 3 звезды — порог трёх звёзд, 2 — середина между целью и им, 1 — цель.
## На уровне без сокровищ всегда 3.
func _stars_for(n: int) -> int:
	if _three_needed <= 0 or n >= _three_needed:
		return 3
	return 2 if n >= _two_needed else 1


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
		_spawn_item(kind, Vector2(rect.position.x + step * 0.5 + cx * step + shift, rect.end.y - step * 0.5 - cy * step))
	return count


func _spawn_item(kind: int, pos: Vector2) -> Item:
	var item := Item.new()
	item.setup(kind, _jittered(pos), _rng.randi())
	item.body_entered.connect(report_contact.bind(item))
	_bodies.add_child(item)
	items.append(item)
	return item


func _jittered(pos: Vector2) -> Vector2:
	if _jitter == null:
		return pos
	return pos + Vector2(_jitter.randf_range(-1.0, 1.0), _jitter.randf_range(-1.0, 1.0))


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


## Вид врага из JSON ("slime"); когда у Enemy появится своё поле kind, берём его.
static func _enemy_kind(enemy: Enemy) -> StringName:
	var k: Variant = enemy.get(&"kind")
	if k == null:
		k = enemy.get_meta(&"kind", &"slime")
	return StringName(str(k))


static func _alive(item: Item) -> bool:
	return item != null and is_instance_valid(item) and not item.removed


static func _vec(v: Array) -> Vector2:
	return Vector2(v[0], v[1])


static func _rect(v: Array) -> Rect2:
	return Rect2(v[0], v[1], v[2], v[3])
