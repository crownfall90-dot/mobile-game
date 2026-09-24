class_name Item
extends RigidBody2D
## Одна частица вещества: капля жидкости, монета, самоцвет или камень.
## Жидкости сами себя не рисуют (их рисует FluidRenderer одним проходом),
## остальное рисуется одной готовой текстурой из ItemArt.

var kind: int = Substances.Kind.WATER
var removed := false
var cooling := false
var radius := Substances.RADIUS

var _look := 0


func setup(k: int, pos: Vector2, look_seed: int) -> void:
	position = pos
	_look = look_seed
	# коллайдер задаётся раз и навсегда: смена вида (лава -> камень) его не трогает
	radius = Substances.radius(k)
	collision_layer = Substances.LAYER_ITEMS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var circle := CircleShape2D.new()
	circle.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = circle
	add_child(cs)
	set_kind(k)


## Меняет вещество: физику, маску (сито пропускает жидкости) и отслеживание контактов.
func set_kind(k: int) -> void:
	kind = k
	mass = Substances.mass(k)
	linear_damp = Substances.damp(k)
	physics_material_override = Substances.material(k)
	collision_mask = Substances.collision_mask(k)
	# Реакции отслеживают только "активные" вещества, чтобы не платить за контакты всех тел.
	var active := k == Substances.Kind.WATER or k == Substances.Kind.ACID
	if contact_monitor != active:
		contact_monitor = active
	max_contacts_reported = 3 if active else 0
	# монеты не вращают картинку вместе с телом: блик всегда сверху-слева
	material = ItemArt.upright_material() if Substances.is_piece(k) else null
	visible = not Substances.is_fluid(k)
	queue_redraw()


func _draw() -> void:
	var tex := ItemArt.texture(kind, _look)
	if tex == null:
		return
	var h := ItemArt.half_size(kind, radius)
	draw_texture_rect(tex, Rect2(-h, -h, h * 2.0, h * 2.0), false)
