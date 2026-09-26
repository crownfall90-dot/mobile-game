extends Control
## Загрузка: уютная починенная комната (фон локации, по ширине, без искажения), по центру
## радостные мама и Вита, сверху название, снизу «Загружаем наш дом…» и полоса. Над полосой
## висит серая Хмурь; когда всё готово — улетает. Первый запуск ведёт в пролог-новеллу.

const GLOOM := preload("res://scripts/art/gloom.gd")
const BG := "res://art/act1/room/background.png"
const FAMILY := "res://art/act1/family/family_mood3.png"
const TITLE_FONT = preload("res://art/fonts/Fredoka.ttf")
const MIN_WAIT := 1.2          # не короче: название успевает появиться

var _canvas: Control
var _bg: TextureRect
var _family: TextureRect
var _bar: Panel
var _fill: Panel
var _gloom: Node2D
var _elapsed := 0.0
var _done := false
var _t := 0.0


func open(_args: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color("2b2233")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	_bg = TextureRect.new()
	_bg.texture = load(BG) if ResourceLoader.exists(BG) else null
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# лёгкая тень — надписи читаются на любом фоне
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = Color(0.12, 0.07, 0.1, 0.28)
	add_child(shade)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_family = TextureRect.new()
	_family.texture = load(FAMILY) if ResourceLoader.exists(FAMILY) else null
	_family.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_family.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_family.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_family)
	var title := UiKit.label("Vita", 124, Color("fff4d6"))
	var title_font := FontVariation.new()
	title_font.base_font = TITLE_FONT
	title_font.variation_opentype = {&"wght": 700}
	title_font.variation_embolden = 2.0
	title.label_settings.font = title_font
	title.name = "Title"
	title.size = Vector2(640, 160)
	title.modulate.a = 0.0
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2(0.8, 0.8)
	_canvas.add_child(title)
	var tw := create_tween().set_parallel()
	tw.tween_property(title, "modulate:a", 1.0, 0.5)
	tw.tween_property(title, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var loading := UiKit.label("Загружаем наш дом…", 28, Color("fff4d6"))
	loading.name = "Loading"
	loading.size = Vector2(600, 45)
	_canvas.add_child(loading)
	_bar = _rounded(Color(0.2, 0.13, 0.1, 0.7), Color("fff4d6"))
	_bar.size = Vector2(500, 26)
	_canvas.add_child(_bar)
	_fill = _rounded(Color("ffc660"), Color(0, 0, 0, 0))
	_fill.position = Vector2(4, 4)
	_fill.size = Vector2(0, 18)
	_bar.add_child(_fill)
	_gloom = GLOOM.new()
	_gloom.setup(Vector2.ZERO, 0.8, false)
	_canvas.add_child(_gloom)
	# размеренная фоновая подгрузка: картинки локации, куда откроется хаб (и пролога при первом
	# запуске) — полоса показывает настоящий прогресс
	var paths := Assets.location_paths(Home.current_location())
	if not Profile.flag("seen.prologue"):
		paths.append_array(Assets.prologue_paths())
	Assets.want(paths)
	Assets.reset_progress()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _rounded(fill: Color, edge: Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(13)
	if edge.a > 0.0:
		sb.border_color = edge
		sb.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _process(delta: float) -> void:
	if _fill == null:
		return
	_t += delta
	# семья чуть «дышит»
	_family.position.y = float(_family.get_meta(&"y", _family.position.y)) + sin(_t * 1.6) * 3.0
	if _done:
		return
	_elapsed += delta
	var ready_audio := Sfx.prepare(4)
	var k := minf(Assets.progress(), _elapsed / MIN_WAIT)
	_fill.size.x = maxf(_fill.size.x, 492.0 * minf(0.97, k))
	if ready_audio and _elapsed >= MIN_WAIT and Assets.idle():
		_done = true
		_fill.size.x = 492.0
		# дом готов — Хмурь улетает; первый запуск ведёт в пролог-новеллу, потом главный экран
		_gloom.call(&"set_amount", 0.0)
		await get_tree().create_timer(0.8).timeout
		if Profile.flag("seen.prologue"):
			Router.go(&"hub")
		else:
			Router.go(&"novel", {"scene": "prologue"})


func _layout() -> void:
	if _canvas == null:
		return
	var view := get_viewport_rect().size
	_bg.size = view
	# всё остальное — в единицах 720 по меньшей стороне, по центру экрана
	var u := minf(view.x / 720.0, view.y / 1280.0)
	var h := view.y / u
	_canvas.scale = Vector2(u, u)
	_canvas.position = Vector2((view.x - 720.0 * u) * 0.5, 0)
	(_canvas.get_node(^"Title") as Control).position = Vector2(40, h * 0.07)
	var fh := minf(h * 0.52, 760.0)
	_family.size = Vector2(fh * 0.625, fh)
	_family.position = Vector2(360 - _family.size.x * 0.5, h * 0.8 - fh - 40)
	_family.set_meta(&"y", _family.position.y)
	(_canvas.get_node(^"Loading") as Control).position = Vector2(60, h * 0.83)
	_bar.position = Vector2(110, h * 0.83 + 56)
	_gloom.position = Vector2(560, h * 0.3)
