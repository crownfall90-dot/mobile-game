class_name Level
extends Node2D
const HOME_BACKDROP := preload("res://scripts/level/home_backdrop.gd")
const RECEIVER := preload("res://scripts/level/receiver.gd")   # не зависит от кэша class_name
const PIPE_SWITCH := preload("res://scripts/level/pipe_switch.gd")
const PUTTY := preload("res://scripts/level/putty.gd")
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
## Палец выкопал землю (для звука и лёгкой вибрации).
signal dug(pos: Vector2)
## Повернули колено трубы (или другой переключатель мини-игры).
signal switched(id: String)

const DESIGN_SIZE := Vector2(720, 1280)
const CHAIN_RADIUS := 25.0      # на каком расстоянии остывание перекидывается на соседнюю лаву
const CHAIN_DELAY := 0.04       # скорость "волны" застывания
const WIN_QUIET := 0.8          # победа, когда цель выполнена и столько секунд не пришло ни монеты...
const WIN_CAP := 3.0            # ...но не позже, чем через столько после выполнения цели
const STUCK_TIMEOUT := 5.0
const STUCK_HARD := 14.0
const FALL_LIMIT := 1500.0
const SCARE_DISTANCE := 260.0
const DROWN_CELL := 380.0       # площадь зоны на одну каплю воды при плотной укладке
const DROWN_FILL := 0.45
const DROWN_SPEED := 150.0       # быстрее — это поток, а не стоящая вода
const DROWN_TIME := 0.35
# Ходьба семьи к двери на уровнях с "exit".
const WALK_SPEED := 95.0
const WALK_DELAY := 0.8
const STEP_UP := 34.0
const STEP_DOWN := 46.0
const WALK_ZONE := Rect2(-46, -150, 92, 146)   # зона семьи относительно ступней
# Реплики семьи (облачко над головами): страх, облегчение, радость.
const LINES_START := ["Мама, мне страшно…", "Держись за меня, солнышко.", "Мы справимся!", "Мама, а мы успеем?"]
const LINES_DANGER := {
	"lava": ["Ой, горячо!", "Мама, лава!"], "acid": ["Осторожно, кислота!", "Фу, она шипит!"],
	"enemy": ["Там слизень!", "Мама, он на нас смотрит!"], "water": ["Вода прибывает!", "Мама, мокро!"],
}
const LINES_RELIEF := ["Фух…", "Пронесло!", "Еле-еле!"]
const THREE_STAR_PERCENT := 95  # 3 звезды за столько % сокровищ (для цели-доли)

## Кого чем можно убить: вид врага -> вещества.
## Кто от чего уходит (docs/CAST.md). Кислота в доме — чистящее средство, лава — огонь плиты.
const VULNERABLE := {
	&"slime": [Substances.Kind.LAVA, Substances.Kind.ACID],
	&"grime": [Substances.Kind.ACID],
	&"mold": [Substances.Kind.ACID],
	&"cockroach": [Substances.Kind.ACID, Substances.Kind.LAVA],   # и от огня плиты
	&"rat": [Substances.Kind.WATER],
	&"mouse": [Substances.Kind.WATER],
	&"spider": [Substances.Kind.WATER],
	&"moth": [Substances.Kind.WATER],
}

const STEAM := Color(1, 1, 1, 0.55)
const SPARK := Color("ffe27a")
const GOO := Color("b561ff")
const ACID_FIZZ := Color("b6ff6a")

var data: Dictionary = {}
var items: Array[Item] = []
var enemies: Array[Enemy] = []
var pins: Array[Pin] = []
var pipes: Array = []            # «живые трубы»: PipeSwitch
var putty: Node2D = null         # «замазка»: игрок рисует стенки пальцем
var hero: Hero
var fx: Fx
var camera: Camera2D   # для тряски экрана; задаёт GameScreen (null — без тряски)
var view_camera: Camera2D   # камера экрана всегда: «Поверни» вращает вид вместе с гравитацией

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
var dirt: Dirt = null
var door: ExitDoor = null
var _zone: Area2D
var _zone_origin := Vector2.ZERO
var _zone_rect := Rect2()
var _acted := false          # был ли первый ход: засов или копание
var _dig_from = null         # Vector2 последней точки пальца, null — палец не копает
var _walk_time := 0.0
var _dig_hint: DigHint = null
var _goal_kind := -1          # приёмник: что в него нужно доставить (-1 — монеты, как раньше)
var _bad_kinds: Array[int] = []   # приёмник: что его портит
var _fill_mode := false       # приёмник-«дыра»: считаем, сколько лежит внутри, а не забираем
var _fill_tick := 0
var _walls: Walls
var _danger_kind := ""        # чего семья боится сейчас (для реплик)
var _danger_time := 0.0
var _said := {}               # какие реплики уже звучали в этой попытке
var _say_cooldown := 0.0
var _dig_fx_at := Vector2(-999, -999)
var _stuck_timer := -1.0
var _stuck_total := 0.0
var _drown_time := 0.0
var _shake := 0.0
var _scare_timer := 0.0
var _source: Dictionary = {}     # вода, которая уже бежит: {pos, kind, count, rate, delay}
var _source_left := 0
var _source_acc := 0.0
var _source_time := 0.0
var _hazard_hits: Array = []     # [тело, вид опасности]
var _hazard_arts: Array = []
var _hazard_limits := {}         # вид -> сколько капель ещё можно (подоконник терпит несколько)
var _hazard_count := {}
var _rot: Dictionary = {}        # «Поверни»: {time} — вещь поворачивается на 90° кнопками
var _angle := 0.0                # насколько повёрнута вещь (по часовой — плюс)
var _angle_to := 0.0
var _rot_busy := false
var _rot_queue: Array[int] = []


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

	var recv: Dictionary = data.get("receiver", {})
	var homey: bool = data.get("family", false) or not recv.is_empty()
	var backdrop: Node2D = HOME_BACKDROP.new() if homey else Backdrop.new()
	if backdrop is HomePuzzleBackdrop:
		backdrop.theme = str(data.get("theme", ""))
		backdrop.item_mode = not recv.is_empty()
	backdrop.setup(_rect(data["tower"]["rect"]))
	add_child(backdrop)

	if not recv.is_empty():
		# головоломка внутри вещи: вместо семьи — приёмник (слив, ведро, ящик, конфорка, дыра)
		var rr := _rect(recv["rect"])
		var rc = RECEIVER.new()
		rc.configure(rr, str(recv.get("look", "drain")))
		hero = rc
		hero.setup(Vector2(rr.get_center().x, rr.end.y), false)
		_goal_kind = Substances.from_name(str(recv.get("kind", "gold")))
		_fill_mode = str(recv.get("mode", "collect")) == "fill"
		_bad_kinds.clear()
		for k in recv.get("bad", ["lava", "acid"]):
			_bad_kinds.append(Substances.from_name(str(k)))
	else:
		hero = FamilyHero.new() if data.get("family", false) else Hero.new()
		if hero is FamilyHero:
			hero.stage = Home.stage()
		# идущая семья без твёрдого тела: не толкает камни, вода и лава обтекают её зону
		hero.setup(_vec(data["hero"]["pos"]), not data.has("exit"))
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
	if homey:
		walls.palette = [Color("9a6b4a"), Color("6e4a33"), Color("d8ac80")]
		walls.pattern = "wood"
		var skin := LevelSkin.wall_palette(str(data.get("theme", "")))
		if not skin.is_empty():
			walls.palette = [skin[0], skin[1], skin[2]]
			walls.pattern = skin[3]
	if not recv.is_empty():
		walls.wear = 1.0
	walls.setup(data.get("walls", []))
	add_child(walls)
	_walls = walls
	if recv.get("look", "") == "art":
		# нарисованный слив: невидимое дно под приёмником, чтобы после исхода ничего
		# не проваливалось сквозь картинку
		var rr := _rect(recv["rect"])
		var floor_body := StaticBody2D.new()
		floor_body.collision_layer = Substances.LAYER_WORLD
		var seg := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(rr.size.x + 40.0, 16.0)
		seg.shape = shape
		seg.position = Vector2(rr.get_center().x, rr.end.y + 8.0)
		floor_body.add_child(seg)
		add_child(floor_body)

	if data.has("dirt"):
		dirt = Dirt.new()
		dirt.setup(DESIGN_SIZE, data["dirt"], data.get("holes", []))
		dirt.set_colors(LevelSkin.dirt_colors(str(data.get("theme", ""))))
		dirt.rebuilt.connect(_wake_all)
		add_child(dirt)
	if data.has("exit"):
		door = ExitDoor.new()
		door.position = _vec(data["exit"]["pos"])
		add_child(door)
		move_child(door, get_children().find(hero))

	var glint := 0.0
	for p in data.get("pins", []):
		var pin := Pin.new()
		pin.setup(str(p["id"]), _vec(p["from"]), _vec(p["to"]), glint)
		pin.pulled_out.connect(_on_pin_out)
		add_child(pin)
		pins.append(pin)
		glint += 0.7

	for pp in data.get("pipes", []):
		var ps = PIPE_SWITCH.new()
		ps.setup(str(pp["id"]), _vec(pp["pos"]), bool(pp.get("right", true)), float(pp.get("size", 150.0)))
		add_child(ps)
		pipes.append(ps)
	for hz in data.get("hazards", []):
		_add_hazard(_rect(hz["rect"]), str(hz.get("kind", "socket")), int(hz.get("limit", 0)))
	if data.has("putty"):
		putty = PUTTY.new()
		putty.setup(float(data["putty"].get("ink", 900.0)), float(data["putty"].get("width", 18.0)))
		add_child(putty)

	fx = Fx.new()
	add_child(fx)

	var zone := Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = Substances.LAYER_ITEMS | Substances.LAYER_ENEMY
	zone.monitorable = false
	var zr: Rect2
	if not recv.is_empty():
		zr = _rect(recv["rect"])
	elif door:
		zr = Rect2(hero.position + WALK_ZONE.position, WALK_ZONE.size)
	else:
		zr = _rect(data["hero"]["zone"])
	var zshape := RectangleShape2D.new()
	zshape.size = zr.size
	var zcs := CollisionShape2D.new()
	zcs.shape = zshape
	zcs.position = zr.get_center()
	zone.add_child(zcs)
	zone.body_entered.connect(func(b: Node2D) -> void: _zone_hits.append(b))
	add_child(zone)
	_zone = zone
	_zone_origin = hero.position
	_zone_rect = zr

	var fluid_count := 0
	for fill in data.get("fills", []):
		var kind := Substances.from_name(str(fill["kind"]))
		var n := _spawn_fill(kind, _rect(fill["rect"]), int(fill["count"]))
		if Substances.is_fluid(kind):
			fluid_count += n
		if _is_goal(kind):
			pieces_total += n

	_rot = data.get("rotate", {})
	_source = data.get("source", {})
	if not _source.is_empty():
		_source_left = int(_source.get("count", 40))
		var skind := Substances.from_name(str(_source.get("kind", "water")))
		if Substances.is_fluid(skind):
			fluid_count += _source_left
		if _is_goal(skind):
			pieces_total += _source_left

	for e in data.get("enemies", []):
		var enemy := Enemy.new()
		enemy.setup(_jittered(_vec(e["pos"])), hero.position + Vector2(0, -70), report_contact)
		enemy.collision_mask |= Substances.LAYER_SIEVE
		enemy.set_kind(StringName(str(e.get("kind", "slime"))))
		if e.get("fixed", false):
			# прилип к стенке (плесень, паутина): не катается, когда вещь поворачивают
			enemy.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
			enemy.freeze = true
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


func can_rotate() -> bool:
	return not _rot.is_empty()


## «Поверни»: вещь поворачивается на 90° по часовой (dir = 1) или против (dir = -1). Гравитация
## поворачивается в обратную сторону, а камера — вместе с вещью: всё падает к низу экрана.
func rotate_world(dir: int) -> bool:
	if _rot.is_empty() or finished:
		return false
	if _rot_busy:
		# нажали, пока вещь ещё поворачивается: повернём следующей, ничего не теряется
		_rot_queue.append(dir)
		return true
	_rot_busy = true
	_angle_to += dir * PI * 0.5
	var id := "cw" if dir > 0 else "ccw"
	_pulled.append(id)
	_acted = true
	var tw := create_tween()
	tw.tween_property(self, "_angle", _angle_to, float(_rot.get("time", 0.9))).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func() -> void:
		_rot_busy = false
		if not _rot_queue.is_empty():
			rotate_world(_rot_queue.pop_front()))
	switched.emit(id)
	return true


func _apply_rotation() -> void:
	if _rot.is_empty():
		return
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR,
		Vector2.DOWN.rotated(-_angle))
	if view_camera:
		view_camera.ignore_rotation = false
		view_camera.rotation = -_angle
	if _rot_busy:
		_wake_all()


func _exit_tree() -> void:
	# гравитация общая для мира: после «Поверни» возвращаем её вниз
	if not _rot.is_empty():
		PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2.DOWN)
		if view_camera:
			view_camera.rotation = 0.0


## «Замазка» для DevRunner: линия по точкам сразу застывает.
func putty_line(points: Array) -> void:
	if putty == null or finished:
		return
	var line := PackedVector2Array()
	for q in points:
		line.append(Vector2(q[0], q[1]))
	if putty.add_line(line):
		_acted = true
		_wake_all()
		switched.emit("putty")


func pipe_by_id(pipe_id: String) -> Node:
	for pp in pipes:
		if pp.id == pipe_id:
			return pp
	return null


## Повернуть колено трубы (палец или DevRunner). false — такого колена нет.
func flip_pipe(pipe_id: String) -> bool:
	var pp := pipe_by_id(pipe_id)
	if pp == null or finished:
		return pp != null
	pp.flip()
	_pulled.append(pipe_id)
	_acted = true
	fx.ring(pp.position + Vector2(0, -pp.size * 0.28), PIPE_SWITCH.KNOB, 30.0)
	_wake_all()
	switched.emit(pipe_id)
	return true


func pull_pin(pin: Pin) -> void:
	if finished or pin == null or pin.pulled:
		return
	pin.pull()
	_pulled.append(pin.id)
	_acted = true
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
	for pp in pipes:
		pp.hinted = pin_id != "" and pp.id == pin_id
	if _dig_hint and pin_id == "":
		_dig_hint.set_paths([])


## Подсказка копания: палец проходит по мазкам решения (ids из "strokes") по очереди.
func show_dig_hint(ids: Array) -> void:
	var strokes: Dictionary = data.get("strokes", {})
	var paths: Array = []
	for id in ids:
		if strokes.has(str(id)):
			paths.append(strokes[str(id)])
	if paths.is_empty():
		return
	if _dig_hint == null:
		_dig_hint = DigHint.new()
		add_child(_dig_hint)
	_dig_hint.set_paths(paths)


func has_strokes() -> bool:
	return not data.get("strokes", {}).is_empty()


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
	if dirt:
		if event is InputEventScreenTouch and not event.pressed:
			_dig_from = null
		elif event is InputEventScreenDrag and _dig_from != null:
			var q: Vector2 = make_input_local(event).position
			dig(_dig_from, q)
			_dig_from = q
			get_viewport().set_input_as_handled()
			return
	if putty:
		if event is InputEventScreenTouch and not event.pressed and putty.is_drawing():
			if putty.finish():
				_acted = true
				_wake_all()
				switched.emit("putty")
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenDrag and putty.is_drawing():
			putty.extend(make_input_local(event).position)
			get_viewport().set_input_as_handled()
			return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = make_input_local(event).position
	if putty:
		var on_pin := false
		for pin in pins:
			on_pin = on_pin or (not pin.pulled and pin.distance_to_point(p) < Pin.HIT_RADIUS)
		if not on_pin:
			putty.begin(p)
			get_viewport().set_input_as_handled()
			return
	for pp in pipes:
		if pp.hit(p):
			flip_pipe(pp.id)
			get_viewport().set_input_as_handled()
			return
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
	elif dirt:
		_dig_from = p
		dig(p, p)
		get_viewport().set_input_as_handled()


## Выкопать землю по отрезку a→b (палец или DevRunner).
func dig(a: Vector2, b: Vector2) -> void:
	if finished or dirt == null:
		return
	if dirt.carve(a, b):
		if _dig_hint and _dig_hint.visible and not _acted:
			_dig_hint.set_paths([])
		# крошки из-под пальца цвета того, что копаем
		if b.distance_to(_dig_fx_at) > 26.0 and fx:
			_dig_fx_at = b
			var cols := LevelSkin.dirt_colors(str(data.get("theme", "")))
			fx.burst(b, cols[0] if not cols.is_empty() else Color("9e6b45"), 4, 160.0, 3.5, 900.0, 0.45)
		_acted = true
		_wake_all()
		dug.emit(b)


## DevRunner: сценарий ходов закончился — дальше без победы считается «застряли».
func actions_done() -> void:
	if _stuck_timer < 0.0:
		_stuck_timer = 0.0


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
	_apply_rotation()
	_run_source(delta)
	if not _hazard_hits.is_empty():
		var hh := _hazard_hits
		_hazard_hits = []
		for h in hh:
			_on_hazard(h[0], h[1])
	_check_drowning(delta)
	_count_fill()
	_walk(delta)
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
	_say_cooldown -= delta
	if _danger_kind != "":
		_danger_time += delta
	if _scare_timer <= 0.0 and not finished:
		_scare_timer = 0.25
		var kind := _danger_kind_near()
		hero.set_scared(kind != "")
		_react_to_danger(kind)


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
	# брызги по тому, что его прогнало: вода — голубые капли, средство — зелёная пена
	var c: Color = GOO if _enemy_kind(enemy) == &"slime" else (Color("8ce6ff") if killer.kind == Substances.Kind.WATER else ACID_FIZZ)
	fx.burst(enemy.position, c, 22, 420.0, 7.0, 900.0, 0.7)
	fx.ring(enemy.position, c, 70.0, 0.4)
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
	if _goal_kind >= 0:
		if item.kind == _goal_kind and not _fill_mode:
			_collect(item)
		elif _bad_kinds.has(item.kind):
			_lose(Substances.name_of(item.kind))
		return
	if Substances.is_piece(item.kind):
		_collect(item)
	elif Substances.is_deadly(item.kind):
		_lose(Substances.name_of(item.kind))


func _collect(item: Item) -> void:
	var gem := item.kind == Substances.Kind.GEM
	pieces += 1
	if gem:
		gems += 1
	elif item.kind == Substances.Kind.GOLD:
		coins_pieces += 1
	_since_collect = 0.0
	var pos := item.position
	fx.burst(pos, Color("8ce6ff") if item.kind == Substances.Kind.WATER else SPARK, 6, 220.0, 3.5, 0.0, 0.45)
	_remove(item)
	hero.bounce()
	if pieces == 1:
		say("coins", ["Монетки!", "Ой, денежка!"])
	collected.emit(&"gem" if gem else (&"coin" if item.kind == Substances.Kind.GOLD else StringName(Substances.name_of(item.kind))), pos)
	gold_changed.emit(pieces, pieces_needed, pieces_total)


func _update_outcome(delta: float) -> void:
	if finished:
		return
	_since_collect += delta
	# до первого хода уровень не решается, даже если собирать нечего
	if not _acted:
		return
	if door:
		# уровень с дверью выигрывается только у двери (_walk); здесь — «застряли»,
		# но только когда всё успокоилось: вода может долго бежать по длинному ходу
		if _stuck_timer >= 0.0:
			_stuck_timer = 0.0 if _anything_moving() else _stuck_timer + delta
			if _stuck_timer > STUCK_TIMEOUT:
				_lose("blocked")
		return
	if pieces >= pieces_needed and _alive_enemies() == 0 and _family_safe():
		# окно победы: ждём, пока докатятся монеты, но не бесконечно. Тишина считается
		# не раньше, чем цель выполнена: лава, убившая последнего врага, ещё может
		# долететь до героини, и поражение должно успеть сработать.
		_goal_time = maxf(_goal_time, 0.0) + delta
		if _goal_time >= WIN_CAP or minf(_since_collect, _goal_time) >= WIN_QUIET:
			_win()
		return
	if _stuck_timer >= 0.0:
		# где копают или вода течёт из трубы, она может долго бежать: «застряли» — когда всё успокоилось,
		# но не позже STUCK_HARD после последнего хода (капля может кататься без конца)
		_stuck_total += delta
		_stuck_timer = 0.0 if (dirt or not _source.is_empty() or not _rot.is_empty()) and _anything_moving() \
			else _stuck_timer + delta
		if _stuck_timer > STUCK_TIMEOUT or _stuck_total > STUCK_HARD:
			_lose("stuck")


## Семья идёт к двери, пока впереди безопасно; у ямы, стены или опасности — ждёт.
func _walk(delta: float) -> void:
	if door == null or finished:
		return
	_walk_time += delta
	var fam := hero as FamilyHero
	var dir := signf(door.position.x - hero.position.x)
	if absf(door.position.x - hero.position.x) < 10.0:
		if fam:
			fam.walking = false
		door.open()
		_win()
		# семья входит в дверной проём и исчезает в свете
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(hero, "modulate:a", 0.0, 0.6)
		return
	var moved := false
	if _walk_time >= WALK_DELAY and not _hazard_ahead(dir):
		var nx := hero.position.x + dir * WALK_SPEED * delta
		var ground := _ground_y(nx + dir * 14.0, hero.position.y)
		var dy := ground - hero.position.y
		if dy > -STEP_UP and dy < STEP_DOWN and not _wall_ahead(dir):
			hero.position = Vector2(nx, move_toward(hero.position.y, ground, 260.0 * delta + maxf(0.0, -dy) * 0.5))
			moved = true
	elif _walk_time >= WALK_DELAY:
		hero.set_scared(true)
	if fam:
		fam.walking = moved
	if moved:
		_zone.position = hero.position - _zone_origin
		if _stuck_timer > 0.0:
			_stuck_timer = 0.0


## Верх твёрдой опоры под x: стены, земля, засовы, камни. Жидкости и монеты не держат.
func _ground_y(x: float, y: float) -> float:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(Vector2(x, y - 60.0), Vector2(x, y + 400.0),
		Substances.LAYER_WORLD | Substances.LAYER_ITEMS)
	var skip: Array[RID] = []
	for i in 8:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return INF
		var col: Object = hit["collider"]
		if col is Item and (Substances.is_fluid(col.kind) or Substances.is_piece(col.kind)):
			skip.append(hit["rid"])
			continue
		return hit["position"].y
	return INF


func _wall_ahead(dir: float) -> bool:
	var space := get_world_2d().direct_space_state
	for h in [40.0, 100.0]:
		var from := hero.position + Vector2(0, -h)
		var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * 34.0, 0), Substances.LAYER_WORLD)
		if not space.intersect_ray(q).is_empty():
			return true
	return false


func _hazard_ahead(dir: float) -> bool:
	for item in items:
		if Substances.is_deadly(item.kind) and not item.removed:
			var dx := (item.position.x - hero.position.x) * dir
			var dy := item.position.y - hero.position.y
			if dx > -30.0 and dx < 130.0 and dy > -200.0 and dy < 30.0:
				return true
	for e in enemies:
		if e.alive:
			var dx := (e.position.x - hero.position.x) * dir
			if dx > -30.0 and dx < 170.0 and absf(e.position.y - hero.position.y) < 200.0:
				return true
	return false


## Вода стоит в зоне семьи и заполняет больше половины её — семья тонет (только семейные уровни).
## Пролетающий над головами поток не считается: капли должны почти стоять.
func _check_drowning(delta: float) -> void:
	if finished or not data.get("family", false):
		return
	var zr := Rect2(_zone_rect.position + _zone.position, _zone_rect.size)
	var capacity := zr.get_area() / DROWN_CELL
	var n := 0
	for item in items:
		if item.kind == Substances.Kind.WATER and not item.removed and zr.has_point(item.position) \
				and item.linear_velocity.length() < DROWN_SPEED:
			n += 1
	_drown_time = _drown_time + delta if n >= capacity * DROWN_FILL else 0.0
	if _drown_time >= DROWN_TIME:
		_lose("water")


## Сокровище или цель приёмника: то, что идёт в счёт.
func _is_goal(kind: int) -> bool:
	return kind == _goal_kind if _goal_kind >= 0 else Substances.is_piece(kind)


## Приёмник-«дыра»: сколько целевых тел лежит внутри прямо сейчас (камни, заделавшие дыру).
func _count_fill() -> void:
	if not _fill_mode or finished:
		return
	_fill_tick += 1
	if _fill_tick % 6 != 0:
		return
	var zr := _zone_rect
	var n := 0
	for item in items:
		if item.kind == _goal_kind and not item.removed and zr.has_point(item.position):
			n += 1
	if n != pieces:
		if n > pieces:
			_since_collect = 0.0
			hero.bounce()
		pieces = n
		gold_changed.emit(pieces, pieces_needed, pieces_total)


func _family_safe() -> bool:
	if _goal_kind >= 0:
		# приёмник: пока к нему летит то, что его испортит, победу не объявляем
		# опасно только то, что летит к приёмнику (или уже рядом); уползающее прочь — не мешает
		var zc := _zone_rect.get_center()
		for item in items:
			if _alive(item) and _bad_kinds.has(item.kind) and item.linear_velocity.length() > 12.0:
				var to_zone := zc - item.position
				if to_zone.length() < 200.0 or item.linear_velocity.dot(to_zone) > 0.0:
					_goal_time = -1.0
					return false
		return true
	if not data.get("family", false):
		return true
	# Не все засовы обязательны: хватает собранного золота и отсутствия летящей опасности.
	var zr := Rect2(_zone_rect.position + _zone.position, _zone_rect.size).grow(40.0)
	for item in items:
		if not _alive(item):
			continue
		if Substances.is_deadly(item.kind) and item.linear_velocity.length() > 12.0:
			_goal_time = -1.0
			return false
		# вода ещё льётся на семью: сначала посмотрим, не затопит ли
		if item.kind == Substances.Kind.WATER and item.linear_velocity.length() > DROWN_SPEED \
				and zr.has_point(item.position):
			_goal_time = -1.0
			return false
	return true


func _win() -> void:
	_finish(true, "")
	hero.celebrate()
	if _goal_kind >= 0:
		_walls.repair()
		for c in get_children():
			if c is HomePuzzleBackdrop:
				c.repair()
	say("win", ["Ура, выход!", "Мы дома!"] if door else ["Получилось!", "Ура, мама!", "Мы спасены!"], true)
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
	# где можно копать, игрок ещё не исчерпал ходы: «застряли» не объявляем
	if dirt or door:
		return
	for pin in pins:
		if not pin.pulled:
			return
	_stuck_timer = 0.0


# --- вода из трубы и опасности -----------------------------------------------

## Вода уже бежит: через delay секунд источник выпускает count капель со скоростью rate в секунду.
func _run_source(delta: float) -> void:
	if _source_left <= 0 or finished:
		return
	_source_time += delta
	if _source_time < float(_source.get("delay", 1.0)):
		return
	_acted = true
	_source_acc += delta * float(_source.get("rate", 12.0))
	var kind := Substances.from_name(str(_source.get("kind", "water")))
	var at := _vec(_source["pos"])
	var x1 := float(_source.get("x1", at.x))
	while _source_acc >= 1.0 and _source_left > 0:
		_source_acc -= 1.0
		_source_left -= 1
		var off := Vector2(float(_source_left % 5 - 2) * 4.0, 0.0)
		if x1 > at.x:
			# дождь: капли по всей ширине, ровно и без случайностей (одинаково при проверке)
			off = Vector2(fmod(_source_left * 0.6180339, 1.0) * (x1 - at.x), 0.0)
		var item := _spawn_item(kind, at + off)
		item.linear_velocity = Vector2(0, 140)
	if _source_left == 0 and _stuck_timer < 0.0:
		_stuck_timer = 0.0


## Опасное место: розетка. Вода в ней — искры и поражение.
func _add_hazard(r: Rect2, kind: String, limit := 0) -> void:
	_hazard_limits[kind] = limit
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = Substances.LAYER_ITEMS
	area.monitorable = false
	var shape := RectangleShape2D.new()
	shape.size = r.size
	var cs := CollisionShape2D.new()
	cs.shape = shape
	cs.position = r.get_center()
	area.add_child(cs)
	area.body_entered.connect(func(b: Node2D) -> void: _hazard_hits.append([b, kind]))
	add_child(area)
	var art := HazardArt.new()
	art.rect = r
	art.kind = kind
	add_child(art)
	_hazard_arts.append(art)


func _on_hazard(body: Node, kind: String) -> void:
	if finished or not (body is Item) or not _alive(body):
		return
	var item: Item = body
	if not Substances.is_fluid(item.kind):
		return
	_hazard_count[kind] = int(_hazard_count.get(kind, 0)) + 1
	for art in _hazard_arts:
		if art.rect.grow(20).has_point(item.position):
			art.spark()
			if kind == "socket":
				fx.burst(art.rect.get_center(), SPARK, 30, 520.0, 6.0, 600.0, 0.8)
	if _hazard_count[kind] > int(_hazard_limits.get(kind, 0)):
		_lose(kind)


## Розетка на стене: белая пластина, два отверстия; при беде — искры.
class HazardArt extends Node2D:
	var rect := Rect2()
	var kind := "socket"
	var _flash := 0.0

	func spark() -> void:
		_flash = 1.0
		create_tween().tween_property(self, "_flash", 0.0, 0.8)

	func _process(_delta: float) -> void:
		if _flash > 0.0:
			queue_redraw()

	func _draw() -> void:
		if kind != "socket":
			# подоконник и пол нарисованы на фоне: только тревожная вспышка при каждой капле
			if _flash > 0.0:
				draw_rect(rect, Color(1.0, 0.5, 0.3, 0.25 * _flash))
			return
		var c := rect.get_center()
		var r := Rect2(c - Vector2(34, 34), Vector2(68, 68))
		var box := StyleBoxFlat.new()
		box.bg_color = Color("f4f1ea")
		box.border_color = Color("8a8078")
		box.set_border_width_all(3)
		box.set_corner_radius_all(12)
		draw_style_box(box, r)
		draw_circle(c, 22.0, Color("e2ddd3"))
		for sx in [-9.0, 9.0]:
			draw_circle(c + Vector2(sx, 0), 4.5, Color("3a3230"))
		# предупреждающая молния
		var z := c + Vector2(0, -52)
		draw_colored_polygon(PackedVector2Array([z + Vector2(-4, -14), z + Vector2(6, -14), z + Vector2(0, -2),
			z + Vector2(7, -2), z + Vector2(-5, 16), z + Vector2(-1, 3), z + Vector2(-7, 3)]), Color("f2c14e"))
		if _flash > 0.0:
			for i in 8:
				var a := i * TAU / 8.0
				draw_line(c, c + Vector2(cos(a), sin(a)) * (30.0 + 40.0 * _flash), Color(1.0, 0.9, 0.3, _flash), 4.0)


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


## Реплика семьи; одна и та же — не чаще раза за попытку, между любыми — пауза.
func say(key: String, lines: Array, force := false) -> void:
	if not hero.has_method(&"say") or lines.is_empty():
		return
	if not force and (_said.has(key) or _say_cooldown > 0.0):
		return
	_said[key] = true
	_say_cooldown = 2.2
	hero.call(&"say", str(lines[_rng.randi() % lines.size()]))


func _react_to_danger(kind: String) -> void:
	if kind != "" and _danger_kind == "":
		say("danger_" + kind, LINES_DANGER.get(kind, []))
		_danger_time = 0.0
	elif kind == "" and _danger_kind != "" and _danger_time > 0.6:
		say("relief", LINES_RELIEF)
	_danger_kind = kind


## Что грозит семье рядом: lava, acid, enemy, water (вода поднялась до пояса) или "".
func _danger_kind_near() -> String:
	var head := hero.position + Vector2(0, -60)
	var d2 := SCARE_DISTANCE * SCARE_DISTANCE
	for e in enemies:
		if e.alive and e.position.distance_squared_to(head) < d2:
			return "enemy"
	for item in items:
		if Substances.is_deadly(item.kind) and not item.removed and item.position.distance_squared_to(head) < d2:
			return Substances.name_of(item.kind)
	if data.get("family", false) and _zone:
		var zr := Rect2(_zone_rect.position + _zone.position, _zone_rect.size)
		var n := 0
		for item in items:
			if item.kind == Substances.Kind.WATER and not item.removed and zr.has_point(item.position):
				n += 1
		if n >= zr.get_area() / DROWN_CELL * 0.22:
			return "water"
	return ""


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


func _anything_moving() -> bool:
	for item in items:
		if not item.removed and not item.sleeping and item.linear_velocity.length() > 25.0:
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
