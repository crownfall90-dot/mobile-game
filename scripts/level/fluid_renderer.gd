class_name FluidRenderer
extends Node2D
## Рисует все жидкости как единую "живую" массу (metaballs).
##
## 1. Каждая капля — мягкий круг в MultiMesh (один draw call на все капли).
##    Капли рисуются аддитивно в маленький SubViewport в половинном разрешении,
##    каждое вещество в свой канал: вода -> R, лава -> G, кислота -> B.
## 2. Шейдер fluid.gdshader отсекает поле по порогу, добавляет блики и свечение.
## Буфер капель перерисовывается, только пока хоть одна капля движется: когда все уснули,
## он хранит последний кадр (свечение лавы в шейдере при этом живёт дальше). Когда капель
## не осталось совсем (вся лава застыла), спрайт прячется.

const DOWNSCALE := 0.5
const BLOB_SIZE := 46.0
const SHADER := preload("res://shaders/fluid.gdshader")

var _level: Level
var _mm: MultiMesh
var _vp: SubViewport
var _sprite: Sprite2D
var _live := false      # буфер обновляется каждый кадр
var _drops := -1        # капель при последней перестройке
var _sig := -1          # сумма видов капель: ловит смену вида (кислота -> вода) у спящих


func setup(level: Level, design_size: Vector2, capacity: int) -> void:
	_level = level
	var vp := SubViewport.new()
	vp.size = Vector2i(design_size * DOWNSCALE)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	_vp = vp

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
	sprite.visible = false
	add_child(sprite)
	_sprite = sprite


func _process(_delta: float) -> void:
	# дешёвый проход: только читаем флаги, пока не встретим движущуюся каплю
	var n := 0
	var sig := 0
	var moving := false
	for item in _level.items:
		if item.removed or not Substances.is_fluid(item.kind):
			continue
		if not item.sleeping:
			moving = true
			break
		n += 1
		sig += item.kind + 1
	if moving or n != _drops or sig != _sig:
		_rebuild()
		var any := _drops > 0
		_sprite.visible = any
		_set_live(any)
	elif _live:
		# всё уснуло: ещё один кадр с точными позициями, дальше буфер стоит
		_rebuild()
		_set_live(false)
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func _rebuild() -> void:
	var n := 0
	var sig := 0
	var cap := _mm.instance_count
	for item in _level.items:
		if item.removed or not Substances.is_fluid(item.kind):
			continue
		if n < cap:
			_mm.set_instance_transform_2d(n, Transform2D(0.0, item.position))
			_mm.set_instance_color(n, Substances.channel(item.kind))
		n += 1
		sig += item.kind + 1
	_mm.visible_instance_count = mini(n, cap)
	_drops = n
	_sig = sig


func _set_live(on: bool) -> void:
	if on == _live:
		return
	_live = on
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED


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
