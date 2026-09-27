extends Control
## Загрузка: уютная комната (фон локации или своя картинка art/act1/ui/loading_bg.png), тёплый
## вечерний свет из окна и пылинки в луче, по центру радостные мама и Вита, сверху название
## с лентой, снизу полоса с бликом и сердечком и сменяющиеся подсказки. Над полосой висит серая
## Хмурь; когда всё готово — она светлеет, искры, и первый запуск ведёт в пролог-новеллу.

const GLOOM := preload("res://scripts/art/gloom.gd")
const BG_OWN := "res://art/act1/ui/loading_bg.png"
const BG := "res://art/act1/room/background.png"
const FAMILY := "res://art/act1/family/family_mood3.png"
const TITLE_FONT = preload("res://art/fonts/Fredoka.ttf")
const MIN_WAIT := 1.6          # не короче: название и первая подсказка успевают появиться
const TIPS := [
	"Золотая кнопка — сломанная вещь. Нажми и почини!",
	"Бирюзовая кнопка — занятие: мама и Вита что-нибудь сделают вместе.",
	"Три звезды — больше монет на уют для дома.",
	"Хмурь грустит, пока дом холодный. Почини — и он подобреет.",
	"Собери кусочки старого фото прабабушки Веры.",
]

var _canvas: Control
var _bg: TextureRect
var _light: Control
var _family: TextureRect
var _bar: LoadBar
var _tip: Label
var _gloom: Node2D
var _fx: Fx
var _elapsed := 0.0
var _done := false
var _t := 0.0
var _tip_i := 0
var _tip_t := 0.0


func open(_args: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base := ColorRect.new()
	base.color = Color("2b2233")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	_bg = TextureRect.new()
	var path := BG_OWN if ResourceLoader.exists(BG_OWN) else BG
	_bg.texture = load(path) if ResourceLoader.exists(path) else null
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	# вечерний свет: тёплый луч из окна, пылинки в нём, тёмные края — надписи читаются
	_light = WarmLight.new()
	_light.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_light)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_family = TextureRect.new()
	_family.texture = load(FAMILY) if ResourceLoader.exists(FAMILY) else null
	_family.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_family.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_family.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_family)
	var title := UiKit.label("Vita", 132, Color("fff4d6"))
	var title_font := FontVariation.new()
	title_font.base_font = TITLE_FONT
	title_font.variation_opentype = {&"wght": 700}
	title_font.variation_embolden = 2.0
	title.label_settings.font = title_font
	title.label_settings.shadow_color = Color(0.35, 0.16, 0.05, 0.55)
	title.label_settings.shadow_size = 18
	title.label_settings.shadow_offset = Vector2(0, 6)
	title.name = "Title"
	title.size = Vector2(640, 170)
	title.modulate.a = 0.0
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2(0.8, 0.8)
	_canvas.add_child(title)
	var ribbon := UiKit.ribbon("Починим дом вместе", &"secondary")
	ribbon.name = "Ribbon"
	ribbon.modulate.a = 0.0
	_canvas.add_child(ribbon)
	var tw := create_tween().set_parallel()
	tw.tween_property(title, "modulate:a", 1.0, 0.5)
	tw.tween_property(title, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ribbon, "modulate:a", 1.0, 0.5).set_delay(0.35)
	_bar = LoadBar.new()
	_bar.size = Vector2(520, 34)
	_canvas.add_child(_bar)
	_tip = UiKit.label(TIPS[0], 26, Color("fff4d6"))
	_tip.name = "Tip"
	# перенос — до размера: иначе метка растягивается по длине строки
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(620, 0)
	_tip.size = Vector2(620, 80)
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.add_theme_constant_override("outline_size", 8)
	_tip.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.05, 0.75))
	_canvas.add_child(_tip)
	_gloom = GLOOM.new()
	_gloom.setup(Vector2.ZERO, 0.8, false)
	_canvas.add_child(_gloom)
	_fx = Fx.new()
	_canvas.add_child(_fx)
	_tip_i = randi() % TIPS.size()
	_tip.text = TIPS[_tip_i]
	# размеренная фоновая подгрузка: картинки локации, куда откроется хаб (и пролога при первом
	# запуске) — полоса показывает настоящий прогресс
	var paths := Assets.location_paths(Home.current_location())
	if not Profile.flag("seen.prologue"):
		paths.append_array(Assets.prologue_paths())
	Assets.want(paths)
	Assets.reset_progress()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if _bar == null:
		return
	_t += delta
	# семья чуть «дышит»
	_family.position.y = float(_family.get_meta(&"y", _family.position.y)) + sin(_t * 1.6) * 3.0
	# подсказки сменяются мягко: гаснет — новая — проявляется
	_tip_t += delta
	if _tip_t > 2.8 and not _done:
		_tip_t = 0.0
		_tip_i = (_tip_i + 1) % TIPS.size()
		var tw := create_tween()
		tw.tween_property(_tip, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func() -> void: _tip.text = TIPS[_tip_i])
		tw.tween_property(_tip, "modulate:a", 1.0, 0.3)
	if _done:
		return
	_elapsed += delta
	var ready_audio := Sfx.prepare(4)
	var k := minf(Assets.progress(), _elapsed / MIN_WAIT)
	_bar.progress = maxf(_bar.progress, minf(0.97, k))
	if ready_audio and _elapsed >= MIN_WAIT and Assets.idle():
		_done = true
		_bar.progress = 1.0
		# дом готов — Хмурь светлеет, над ней искры; первый запуск ведёт в пролог-новеллу
		_gloom.call(&"set_amount", 0.0)
		for col in [Color("ffe5a3"), Color("fff4d6"), Color("ffc660")]:
			_fx.burst(_gloom.position, col, 12, 260.0, 5.0, 300.0, 0.9)
		await get_tree().create_timer(0.9).timeout
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
	(_canvas.get_node(^"Title") as Control).position = Vector2(40, h * 0.06)
	var ribbon := _canvas.get_node(^"Ribbon") as Control
	ribbon.size = ribbon.get_combined_minimum_size()
	ribbon.scale = Vector2(0.85, 0.85)
	ribbon.position = Vector2(360 - ribbon.size.x * 0.85 * 0.5, h * 0.06 + 150)
	var fh := minf(h * 0.5, 740.0)
	_family.size = Vector2(fh * 0.625, fh)
	_family.position = Vector2(360 - _family.size.x * 0.5, h * 0.8 - fh - 40)
	_family.set_meta(&"y", _family.position.y)
	_bar.position = Vector2(100, h * 0.82)
	_tip.size = Vector2(620, 80)
	_tip.position = Vector2(50, h * 0.82 + 50)
	_gloom.position = Vector2(565, h * 0.33)


## Тёплый свет вечера: мягкий луч из окна сверху слева, пылинки медленно плывут в нём,
## по краям затемнение. Рисуется кодом поверх фона, картинок не нужно.
class WarmLight extends Control:
	var _t := 0.0
	var _motes: Array[Vector3] = []   # x, y (0..1), фаза

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		for i in 26:
			_motes.append(Vector3(rng.randf(), rng.randf(), rng.randf() * TAU))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		# вечерняя дымка сверху и снизу: название и полоса читаются на любом фоне
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y * 0.3), Vector2(0, s.y * 0.3)]),
			PackedColorArray([Color(0.16, 0.08, 0.1, 0.45), Color(0.16, 0.08, 0.1, 0.45), Color(0.16, 0.08, 0.1, 0.0), Color(0.16, 0.08, 0.1, 0.0)]))
		draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.7), Vector2(s.x, s.y * 0.7), s, Vector2(0, s.y)]),
			PackedColorArray([Color(0.14, 0.07, 0.08, 0.0), Color(0.14, 0.07, 0.08, 0.0), Color(0.14, 0.07, 0.08, 0.6), Color(0.14, 0.07, 0.08, 0.6)]))
		# луч из окна: широкий тёплый клин сверху слева к центру, чуть дышит
		var a := 0.13 + 0.03 * sin(_t * 0.7)
		var warm := Color(1.0, 0.82, 0.5, a)
		var none := Color(1.0, 0.82, 0.5, 0.0)
		draw_polygon(PackedVector2Array([Vector2(-s.x * 0.1, s.y * 0.05), Vector2(s.x * 0.28, -s.y * 0.02),
			Vector2(s.x * 0.95, s.y * 0.78), Vector2(s.x * 0.25, s.y * 0.95)]),
			PackedColorArray([warm, warm, none, none]))
		# пылинки: светятся в луче и медленно поднимаются
		for m in _motes:
			var y := fposmod(m.y - _t * 0.012 * (0.6 + m.x), 1.0)
			var x := m.x + sin(_t * 0.5 + m.z) * 0.015
			var p := Vector2(x * s.x, y * s.y)
			var glow := 0.35 + 0.35 * sin(_t * 1.3 + m.z)
			draw_circle(p, 2.2 + 1.2 * glow, Color(1.0, 0.93, 0.75, 0.25 + 0.35 * glow), true, -1.0, true)


## Полоса загрузки: скруглённый жёлоб, тёплая заливка с бегущим бликом и сердечко на конце.
class LoadBar extends Control:
	var progress := 0.0:
		set(v):
			progress = clampf(v, 0.0, 1.0)
			queue_redraw()
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var rad := size.y * 0.5
		_round(r, rad, Color(0.2, 0.12, 0.1, 0.75))
		_round(r.grow(-1.5), rad, Color(1, 0.95, 0.84, 0.18), false)
		if progress <= 0.0:
			return
		var fw := maxf(size.y, (size.x - 8.0) * progress)
		var f := Rect2(Vector2(4, 4), Vector2(fw, size.y - 8.0))
		_round(f, f.size.y * 0.5, Color("ffc660"))
		_round(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.45)), f.size.y * 0.22, Color(1, 1, 1, 0.28))
		# блик бежит по заливке
		var bx := fposmod(_t * 220.0, f.size.x + 80.0) - 40.0
		if bx > 0.0 and bx < f.size.x:
			draw_rect(Rect2(f.position + Vector2(bx, 0), Vector2(14, f.size.y)), Color(1, 1, 1, 0.3))
		# сердечко на конце заливки
		var c := Vector2(f.end.x, size.y * 0.5)
		var k := 1.0 + 0.08 * sin(_t * 5.0)
		for p in [Vector2(-5, -3), Vector2(5, -3)]:
			draw_circle(c + p * k, 7.0 * k, Color("e8574a"), true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-11.5, -1) * k, c + Vector2(11.5, -1) * k,
			c + Vector2(0, 12) * k]), Color("e8574a"))
		draw_circle(c + Vector2(-6, -5) * k, 2.2 * k, Color(1, 1, 1, 0.6), true, -1.0, true)

	func _round(r: Rect2, rad: float, col: Color, filled := true) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col if filled else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(int(rad))
		if not filled:
			sb.border_color = col
			sb.set_border_width_all(2)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
