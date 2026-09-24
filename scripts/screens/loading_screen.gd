extends Control

const SPLASH = preload("res://art/home/splash_outside.png")
const TITLE_FONT = preload("res://art/fonts/Fredoka.ttf")
const MIN_WAIT := 5.0

var _canvas: Control
var _bar: ColorRect
var _elapsed := 0.0
var _done := false


func open(_args: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas = Control.new()
	_canvas.size = Vector2(720,1280)
	add_child(_canvas)
	var scene := TextureRect.new()
	scene.texture = SPLASH
	scene.size = Vector2(720,1280)
	scene.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scene.stretch_mode = TextureRect.STRETCH_SCALE
	scene.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(scene)
	var title := UiKit.label("Vita",112,Color("fff4d6"))
	var title_font := FontVariation.new()
	title_font.base_font = TITLE_FONT
	title_font.variation_opentype = {&"wght":700}
	title_font.variation_embolden = 2.0
	title.label_settings.font = title_font
	title.position = Vector2(40,40)
	title.size = Vector2(640,150)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.visible_characters = 0
	title.modulate.a = 0.0
	_canvas.add_child(title)
	var title_in := create_tween().set_parallel()
	title_in.tween_property(title,"visible_characters",4,0.95)
	title_in.tween_property(title,"modulate:a",1.0,0.35)
	var subtitle := UiKit.label("История одной семьи",30,Color("fff1d9"))
	subtitle.position = Vector2(40,180)
	subtitle.size = Vector2(640,46)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(subtitle)
	var loading := UiKit.label("Загружаем наш дом...",26,Color("fff4d6"))
	loading.position = Vector2(60,260)
	loading.size = Vector2(600,45)
	loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_canvas.add_child(loading)
	var track := ColorRect.new()
	track.color = Color("6b5848")
	track.position = Vector2(110,315)
	track.size = Vector2(500,18)
	_canvas.add_child(track)
	_bar = ColorRect.new()
	_bar.color = Color("ffc660")
	_bar.position = track.position
	_bar.size = Vector2(0,18)
	_canvas.add_child(_bar)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _bar == null or _done:
		return
	_elapsed += delta
	var ready_audio := Sfx.prepare(4)
	_bar.size.x = 500.0 * minf(0.95,_elapsed / MIN_WAIT)
	if ready_audio and _elapsed >= MIN_WAIT:
		_done = true
		_bar.size.x = 500
		Router.go(&"hub")


func _layout() -> void:
	if _canvas == null:
		return
	var view := get_viewport_rect().size
	_canvas.scale = Vector2(view.x / 720.0,view.y / 1280.0)
	_canvas.position = Vector2.ZERO
