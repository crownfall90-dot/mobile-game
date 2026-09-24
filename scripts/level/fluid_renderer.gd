class_name FluidRenderer
extends Node2D
## Рисует все жидкости как единую "живую" массу (metaballs).
##
## 1. Каждая капля — мягкий круг в MultiMesh (один draw call на все капли).
##    Капли рисуются аддитивно в маленький SubViewport в половинном разрешении,
##    каждое вещество в свой канал: вода -> R, лава -> G, кислота -> B.
## 2. Шейдер fluid.gdshader отсекает поле по порогу, добавляет блики и свечение.

const DOWNSCALE := 0.5
const BLOB_SIZE := 46.0
const SHADER := preload("res://shaders/fluid.gdshader")

var _level: Level
var _mm: MultiMesh


func setup(level: Level, design_size: Vector2, capacity: int) -> void:
	_level = level
	var vp := SubViewport.new()
	vp.size = Vector2i(design_size * DOWNSCALE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(BLOB_SIZE, BLOB_SIZE)
	_mm.mesh = quad
	_mm.instance_count = maxi(capacity, 1)
	_mm.visible_instance_count = 0

	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = _mm
	mmi.texture = _blob_texture()
	mmi.scale = Vector2.ONE * DOWNSCALE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mmi.material = add
	vp.add_child(mmi)

	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = vp.get_texture()
	sprite.scale = Vector2.ONE / DOWNSCALE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	sprite.material = mat
	add_child(sprite)


func _process(_delta: float) -> void:
	var n := 0
	var cap := _mm.instance_count
	for item in _level.items:
		if n >= cap:
			break
		if item.removed or not Substances.is_fluid(item.kind):
			continue
		_mm.set_instance_transform_2d(n, Transform2D(0.0, item.position))
		_mm.set_instance_color(n, Substances.channel(item.kind))
		n += 1
	_mm.visible_instance_count = n


static func _blob_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t
