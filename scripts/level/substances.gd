class_name Substances
extends RefCounted
## Каталог веществ башни: физика, цвета и слои столкновений.
## Реакции между веществами описаны в Level._react().

enum Kind { WATER, LAVA, ACID, GOLD, STONE }

# Слои физики (битовые маски).
const LAYER_WORLD := 1   # стены, штыри, тело героя
const LAYER_ITEMS := 2   # капли, золото, камни
const LAYER_ENEMY := 4   # враги

const RADIUS := 9.0
const GOLD_RADIUS := 11.0

static var _materials: Dictionary = {}


static func from_name(kind_name: String) -> Kind:
	match kind_name:
		"water":
			return Kind.WATER
		"lava":
			return Kind.LAVA
		"acid":
			return Kind.ACID
		"gold":
			return Kind.GOLD
		"stone":
			return Kind.STONE
	push_error("Unknown substance '%s'" % kind_name)
	return Kind.WATER


static func is_fluid(kind: int) -> bool:
	return kind == Kind.WATER or kind == Kind.LAVA or kind == Kind.ACID


static func is_deadly(kind: int) -> bool:
	return kind == Kind.LAVA or kind == Kind.ACID


## Жидкости рисуются одним проходом: каждая пишет своё поле в свой канал.
static func channel(kind: int) -> Color:
	match kind:
		Kind.WATER:
			return Color(1, 0, 0, 1)
		Kind.LAVA:
			return Color(0, 1, 0, 1)
		_:
			return Color(0, 0, 1, 1)


static func radius(kind: int) -> float:
	return GOLD_RADIUS if kind == Kind.GOLD else RADIUS


static func mass(kind: int) -> float:
	match kind:
		Kind.GOLD:
			return 0.4
		Kind.STONE:
			return 0.5
		Kind.LAVA:
			return 0.3
	return 0.2


static func damp(kind: int) -> float:
	return 1.2 if kind == Kind.LAVA else 0.2


static func material(kind: int) -> PhysicsMaterial:
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
