class_name Substances
extends RefCounted
## Каталог веществ башни: физика, цвета и слои столкновений.
## Реакции между веществами — таблица Level.REACTIONS.

# Новые виды добавляются только в конец: числа видов не должны сдвигаться.
enum Kind { WATER, LAVA, ACID, GOLD, STONE, GEM }

const NAMES := {
	Kind.WATER: "water", Kind.LAVA: "lava", Kind.ACID: "acid",
	Kind.GOLD: "gold", Kind.STONE: "stone", Kind.GEM: "gem",
}

# Слои физики (битовые маски).
const LAYER_WORLD := 1   # стены, штыри, тело героя
const LAYER_ITEMS := 2   # капли, золото, камни
const LAYER_ENEMY := 4   # враги
const LAYER_SIEVE := 8   # сито: держит всё, кроме жидкостей

const RADIUS := 9.0
const GOLD_RADIUS := 11.0

static var _materials: Dictionary = {}


static func from_name(kind_name: String) -> Kind:
	for k in NAMES:
		if NAMES[k] == kind_name:
			return k
	push_error("Unknown substance '%s'" % kind_name)
	return Kind.WATER


static func name_of(kind: int) -> String:
	return NAMES.get(kind, "")


static func is_fluid(kind: int) -> bool:
	return kind == Kind.WATER or kind == Kind.LAVA or kind == Kind.ACID


## Опасно для героини.
static func is_deadly(kind: int) -> bool:
	return kind == Kind.LAVA or kind == Kind.ACID


## Сокровище: идёт в счёт цели и звёзд.
static func is_piece(kind: int) -> bool:
	return kind == Kind.GOLD or kind == Kind.GEM


## Жидкости рисуются одним проходом: каждая пишет своё поле в свой канал.
static func channel(kind: int) -> Color:
	match kind:
		Kind.WATER:
			return Color(1, 0, 0, 1)
		Kind.LAVA:
			return Color(0, 1, 0, 1)
		_:
			return Color(0, 0, 1, 1)


## Маска столкновений: жидкости проходят сквозь сито, всё остальное на нём лежит.
static func collision_mask(kind: int) -> int:
	var m := LAYER_WORLD | LAYER_ITEMS | LAYER_ENEMY
	return m if is_fluid(kind) else m | LAYER_SIEVE


static func radius(kind: int) -> float:
	return GOLD_RADIUS if is_piece(kind) else RADIUS


# Самоцвет физически неотличим от монеты: проверенные решения остаются в силе.
static func mass(kind: int) -> float:
	match kind:
		Kind.GOLD, Kind.GEM:
			return 0.4
		Kind.STONE:
			return 0.5
		Kind.LAVA:
			return 0.3
	return 0.2


static func damp(kind: int) -> float:
	return 1.2 if kind == Kind.LAVA else 0.2


static func material(kind: int) -> PhysicsMaterial:
	if kind == Kind.GEM:
		kind = Kind.GOLD
	if not _materials.has(kind):
		var m := PhysicsMaterial.new()
		m.bounce = 0.0
		match kind:
			Kind.GOLD:
				m.friction = 0.3
			Kind.STONE:
				m.friction = 0.6
			Kind.LAVA:
				m.friction = 0.03
			_:
				m.friction = 0.0
		_materials[kind] = m
	return _materials[kind]
