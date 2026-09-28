extends Control
## Загрузка: сверху название с лентой, по центру радостные мама и Вита, снизу прогресс и
## сменяющиеся подсказки (без ленты — решение владельца); когда всё готово — искры, и первый запуск
## ведёт в пролог-новеллу. Варианты оформления (VARIANT или args.variant):
##   room  — уютная комната (фон локации или art/act1/ui/loading_bg.png), луч с пылинками, полоса;
##   house — ночь, звёзды, домик: по ходу загрузки в окнах по одному зажигается свет;
##   book  — страница сказки с узорной рамкой, семья в круглом медальоне, пять сердечек;
##   sky   — утреннее небо с плывущими облаками, полоса;
##   rain  — большое окно, дождь стихает по ходу загрузки, в конце радуга;
##   door  — дверь приоткрывается, из щели льётся тёплый свет;
##   album — на деревянном столе по очереди появляются фотокарточки комнат;
##   story — карточки сюжета с подписями: первая ночь, письмо, прабабушка Вера, наш дом;
##   spread — раскрытый альбом: фото с уголками, подписи, сердечки на страницах;
##   plan  — синий чертёж: по ходу загрузки белыми линиями рисуется домик.

const BG_OWN := "res://art/act1/ui/loading_bg.png"
const BG := "res://art/act1/room/background.png"
const FAMILY := "res://art/act1/family/family_mood3.png"
const TITLE_FONT = preload("res://art/fonts/Fredoka.ttf")
const MIN_WAIT := 1.6          # не короче: название и первая подсказка успевают появиться
const VARIANT := "room"
## Карточки сюжета: картинка и подпись от руки.
const STORY_PHOTOS := [
	["res://art/act1/story/night.png", "Первая ночь"],
	["res://art/act1/story/letter.png", "Письмо прабабушки"],
	["res://art/act1/story/photo_full.png", "Прабабушка Вера"],
	["res://art/act1/room/background.png", "Наш дом"],
]
const TIPS := [
	"Золотая кнопка — сломанная вещь. Нажми и почини!",
	"Бирюзовая кнопка — занятие: мама и Вита что-нибудь сделают вместе.",
	"Три звезды — больше монет на уют для дома.",
	"Собери кусочки старого фото прабабушки Веры.",
]

var _variant := VARIANT
var _art: Control              # фон варианта (house, book, sky), рисуется кодом
var _hearts: HeartsBar
var _medal: Panel
var _canvas: Control
var _bg: TextureRect
var _light: Control
var _family: TextureRect
var _bar: LoadBar
var _tip: Label
var _fx: Fx
var _elapsed := 0.0
var _done := false
var _t := 0.0
var _tip_i := 0
var _tip_t := 0.0


func open(args: Dictionary) -> void:
	_variant = str(args.get("variant", VARIANT))
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
	if _variant != "room":
		_bg.visible = false
		_light.visible = false
		_art = {"house": HouseNight, "book": StoryPage, "sky": MorningSky, "rain": RainWindow, "door": WarmDoor,
			"album": PhotoAlbum, "plan": Blueprint, "story": PhotoAlbum, "spread": AlbumSpread}.get(_variant, MorningSky).new()
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _variant == "story":
			_art.call(&"use", STORY_PHOTOS)
		add_child(_art)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_family = TextureRect.new()
	_family.texture = load(FAMILY) if ResourceLoader.exists(FAMILY) else null
	_family.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_family.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_family.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _variant == "book":
		# медальон: круг обрезает картинку семьи, золотое кольцо рисует StoryPage
		_medal = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("f6e7c8")
		sb.set_corner_radius_all(400)
		sb.anti_aliasing = true
		_medal.add_theme_stylebox_override("panel", sb)
		_medal.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		_medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(_medal)
		_medal.add_child(_family)
	else:
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
	var tw := create_tween().set_parallel()
	tw.tween_property(title, "modulate:a", 1.0, 0.5)
	tw.tween_property(title, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bar = LoadBar.new()
	_bar.size = Vector2(520, 34)
	_canvas.add_child(_bar)
	# у домика прогресс — свет в окнах, у сказки — сердечки
	_bar.visible = _variant in ["room", "sky", "rain"]
	if _variant == "book":
		_hearts = HeartsBar.new()
		_hearts.size = Vector2(420, 70)
		_canvas.add_child(_hearts)
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
	_show_progress(_bar.progress)
	if ready_audio and _elapsed >= MIN_WAIT and Assets.idle():
		_done = true
		_bar.progress = 1.0
		_show_progress(1.0)
		# дом готов — искры над полосой; первый запуск ведёт в пролог-новеллу
		for col in [Color("ffe5a3"), Color("fff4d6"), Color("ffc660")]:
			_fx.burst(_bar.position + Vector2(_bar.size.x, _bar.size.y * 0.5), col, 12, 260.0, 5.0, 300.0, 0.9)
		await get_tree().create_timer(0.9).timeout
		if Profile.flag("seen.prologue"):
			Router.go(&"hub")
		else:
			Router.go(&"novel", {"scene": "prologue"})


## Прогресс в оформлении варианта: окна домика, сердечки, светлеющая Хмурь утром.
func _show_progress(v: float) -> void:
	if _art:
		_art.set(&"progress", v)
	if _hearts:
		_hearts.progress = v


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
	# вырез камеры сверху и скругление/жестовая полоса снизу не накрывают надпись и полосу
	var inset := UiKit.safe_insets(get_viewport()) / u
	(_canvas.get_node(^"Title") as Control).position = Vector2(40, h * 0.06 + inset.x)
	var fh := minf(h * 0.5, 740.0)
	_family.size = Vector2(fh * 0.625, fh)
	_family.position = Vector2(360 - _family.size.x * 0.5, h * 0.8 - fh - 40)
	_bar.position = Vector2(100, h * 0.82 - inset.y)
	_tip.size = Vector2(620, 80)
	_tip.position = Vector2(50, h * 0.82 + 50 - inset.y)
	match _variant:
		"house":
			# семья у двери домика
			fh = minf(h * 0.26, 380.0)
			_family.size = Vector2(fh * 0.625, fh)
			_family.position = Vector2(360 - _family.size.x * 0.5 - 150, h * 0.8 - fh)
			_art.set(&"ground_y", h * 0.8)
		"book":
			# на светлой бумаге подсказка тёмная
			var ls := _tip.label_settings.duplicate() as LabelSettings
			ls.font_color = Color("5a3a24")
			ls.outline_color = Color(1, 0.96, 0.88, 0.8)
			_tip.label_settings = ls
			var d := minf(h * 0.42, 470.0)
			_medal.size = Vector2(d, d)
			_medal.position = Vector2(360 - d * 0.5, h * 0.3)
			_art.set(&"medal", Rect2(_medal.position, _medal.size))
			_family.size = Vector2(d * 0.78 * 0.625, d * 0.78) * 1.25
			_family.position = Vector2(d * 0.5 - _family.size.x * 0.5, d - _family.size.y * 0.9)
			_hearts.position = Vector2(150, h * 0.3 + d + 30)
			_tip.position = Vector2(50, h * 0.3 + d + 110)
		"door", "plan":
			fh = minf(h * 0.36, 520.0)
			_family.size = Vector2(fh * 0.625, fh)
			_family.position = Vector2(60, h * 0.8 - fh)
		"album", "story", "spread":
			fh = minf(h * 0.3, 420.0)
			_family.size = Vector2(fh * 0.625, fh)
			_family.position = Vector2(360 - _family.size.x * 0.5, h * 0.8 - fh)
	_family.set_meta(&"y", _family.position.y)


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


## «Домик в ночи»: глубокое небо со звёздами и луной, на холме домик; progress зажигает окна
## по одному (тёплый свет с ореолом), в самом конце — и фонарь у двери.
class HouseNight extends Control:
	var progress := 0.0
	var ground_y := 1000.0
	var _t := 0.0
	var _stars: Array[Vector3] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for i in 60:
			_stars.append(Vector3(rng.randf(), rng.randf() * 0.55, rng.randf() * TAU))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
			PackedColorArray([Color("1b2350"), Color("2a2a66"), Color("5a3f6e"), Color("3a2f62")]))
		for st in _stars:
			var tw := 0.5 + 0.5 * sin(_t * 2.0 + st.z)
			draw_circle(Vector2(st.x * s.x, st.y * s.y), (1.2 + tw * 1.3) * u, Color(1, 0.96, 0.85, 0.4 + 0.5 * tw), true, -1.0, true)
		# луна
		var m := Vector2(s.x * 0.84, s.y * 0.22)
		draw_circle(m, 46 * u, Color(1, 0.95, 0.78, 0.18), true, -1.0, true)
		draw_circle(m, 34 * u, Color("fff1c4"), true, -1.0, true)
		draw_circle(m + Vector2(-12, -8) * u, 7 * u, Color(0.93, 0.85, 0.66), true, -1.0, true)
		# холм
		var gy := ground_y * u
		draw_colored_polygon(PackedVector2Array([Vector2(0, gy + 30 * u), Vector2(s.x * 0.5, gy - 30 * u), Vector2(s.x, gy + 20 * u), s, Vector2(0, s.y)]), Color("2c4a3e"))
		# домик
		var cx := s.x * 0.5
		var bw := 360.0 * u
		var bh := 250.0 * u
		var base := Rect2(cx - bw * 0.5, gy - 30 * u - bh, bw, bh)
		draw_rect(Rect2(base.end.x - 90 * u, base.position.y - 150 * u, 44 * u, 100 * u), Color("7a4a3a"))
		draw_colored_polygon(PackedVector2Array([base.position + Vector2(-30 * u, 0), Vector2(cx, base.position.y - 170 * u), Vector2(base.end.x + 30 * u, base.position.y)]), Color("a2503f"))
		draw_rect(base, Color("e8c79a"))
		draw_rect(Rect2(base.position.x, base.end.y - 12 * u, bw, 12 * u), Color("b8946a"))
		# дверь
		var door := Rect2(cx - 38 * u, base.end.y - 130 * u, 76 * u, 130 * u)
		draw_rect(door, Color("7a4a3a"))
		draw_circle(door.position + Vector2(62, 70) * u, 5 * u, Color("f2c14e"), true, -1.0, true)
		# окна: 4 штуки, свет по прогрессу
		var wins := [Rect2(base.position.x + 40 * u, base.position.y + 40 * u, 80 * u, 70 * u),
			Rect2(base.end.x - 120 * u, base.position.y + 40 * u, 80 * u, 70 * u),
			Rect2(base.position.x + 40 * u, base.position.y + 140 * u, 80 * u, 70 * u),
			Rect2(base.end.x - 120 * u, base.position.y + 140 * u, 80 * u, 70 * u)]
		for i in wins.size():
			var on := clampf(progress * 4.2 - i, 0.0, 1.0)
			var w: Rect2 = wins[i]
			if on > 0.0:
				draw_circle(w.get_center(), 70 * u, Color(1, 0.8, 0.4, 0.18 * on), true, -1.0, true)
			draw_rect(w, Color("2d3563").lerp(Color("ffd27a"), on))
			draw_line(Vector2(w.get_center().x, w.position.y), Vector2(w.get_center().x, w.end.y), Color("6b4a3a"), 4 * u)
			draw_line(Vector2(w.position.x, w.get_center().y), Vector2(w.end.x, w.get_center().y), Color("6b4a3a"), 4 * u)
			draw_rect(w, Color("6b4a3a"), false, 5 * u)
		# фонарь у двери зажигается последним
		var lamp := Vector2(door.end.x + 26 * u, door.position.y + 20 * u)
		var l_on := clampf(progress * 4.2 - 4.0, 0.0, 1.0)
		draw_circle(lamp, 40 * u, Color(1, 0.8, 0.4, 0.25 * l_on), true, -1.0, true)
		draw_circle(lamp, 10 * u, Color("5a4a3a").lerp(Color("ffe08a"), l_on), true, -1.0, true)


## «Сказка»: тёплая страница книги с узорной рамкой и золотым кольцом медальона.
class StoryPage extends Control:
	var progress := 0.0
	var medal := Rect2()
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color("f3e3c3"))
		# лёгкие пятна бумаги
		for i in 9:
			var p := Vector2(fposmod(i * 0.37, 1.0) * s.x, fposmod(i * 0.61, 1.0) * s.y)
			draw_circle(p, (80 + i * 9) * u, Color(0.85, 0.72, 0.5, 0.06), true, -1.0, true)
		# рамка страницы: двойная линия и завитки в углах
		var r := Rect2(Vector2(26, 26) * u, s - Vector2(52, 52) * u)
		draw_rect(r, Color("a0703f"), false, 4 * u)
		draw_rect(r.grow(-12 * u), Color("c89a5c"), false, 2 * u)
		for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			draw_arc(c, 34 * u, 0, TAU, 32, Color("a0703f"), 3 * u, true)
			draw_circle(c, 8 * u, Color("c0564a"), true, -1.0, true)
		# лучики за медальоном и золотое кольцо
		if medal.size.x > 0.0:
			var mc := medal.get_center() * u + Vector2((s.x - 720.0 * u) * 0.5, 0)
			var mr := medal.size.x * 0.5 * u
			for i in 16:
				var a := TAU * i / 16.0 + _t * 0.08
				var p1 := mc + Vector2.from_angle(a - 0.08) * (mr + 10 * u)
				var p2 := mc + Vector2.from_angle(a + 0.08) * (mr + 10 * u)
				var p3 := mc + Vector2.from_angle(a) * (mr + 90 * u)
				draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1, 0.85, 0.45, 0.25))
			draw_arc(mc, mr + 6 * u, 0, TAU, 96, Color("d9a441"), 12 * u, true)
			draw_arc(mc, mr + 6 * u, 0, TAU, 96, Color(1, 0.95, 0.7, 0.6), 3 * u, true)


## Прогресс сердечками: пять сердец наливаются по очереди, полное — с бликом.
class HeartsBar extends Control:
	var progress := 0.0:
		set(v):
			progress = clampf(v, 0.0, 1.0)
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := 5
		for i in n:
			var c := Vector2(size.x * (i + 0.5) / n, size.y * 0.5)
			var fill := clampf(progress * n - i, 0.0, 1.0)
			_heart(c, 26.0, Color(0.55, 0.35, 0.3, 0.35))
			if fill > 0.0:
				_heart(c, 26.0 * (0.4 + 0.6 * fill), Color("e8574a"))
				if fill >= 1.0:
					draw_circle(c + Vector2(-9, -8), 4.0, Color(1, 1, 1, 0.6), true, -1.0, true)

	func _heart(c: Vector2, r: float, col: Color) -> void:
		draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.55, col, true, -1.0, true)
		draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.55, col, true, -1.0, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.98, -r * 0.1), c + Vector2(r * 0.98, -r * 0.1),
			c + Vector2(0, r * 0.95)]), col)


## «Утро»: небо от персика к голубому, мягкие облака плывут, солнце с лучами за семьёй.
class MorningSky extends Control:
	var progress := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
			PackedColorArray([Color("8cc6ec"), Color("a9d6f2"), Color("ffe0b8"), Color("ffd2a8")]))
		# солнце с медленными лучами за семьёй
		var sun := Vector2(s.x * 0.5, s.y * 0.55)
		for i in 14:
			var a := TAU * i / 14.0 + _t * 0.05
			draw_colored_polygon(PackedVector2Array([sun + Vector2.from_angle(a - 0.07) * 140 * u,
				sun + Vector2.from_angle(a + 0.07) * 140 * u, sun + Vector2.from_angle(a) * 620 * u]), Color(1, 0.93, 0.7, 0.22))
		draw_circle(sun, 150 * u, Color(1, 0.94, 0.72, 0.5), true, -1.0, true)
		# облака: три слоя, плывут с разной скоростью
		for i in 7:
			var sp := 8.0 + i * 3.0
			var x := fposmod(i * 173.0 + _t * sp, 900.0) - 90.0
			var y := 180.0 + (i % 4) * 150.0
			_cloud(Vector2(x, y) * u + Vector2((s.x - 720.0 * u) * 0.5, 0), (0.7 + (i % 3) * 0.25) * u)
		# лужайка у дома внизу
		draw_colored_polygon(PackedVector2Array([Vector2(0, s.y * 0.8), Vector2(s.x * 0.5, s.y * 0.77), Vector2(s.x, s.y * 0.8), s, Vector2(0, s.y)]), Color("8cc27a"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, s.y * 0.84), Vector2(s.x, s.y * 0.83), s, Vector2(0, s.y)]), Color("79b36a"))

	func _cloud(c: Vector2, k: float) -> void:
		var col := Color(1, 1, 1, 0.85)
		for p in [Vector2(-50, 10), Vector2(0, -12), Vector2(50, 8), Vector2(-20, 18), Vector2(25, 20)]:
			draw_circle(c + p * k, 38 * k, col, true, -1.0, true)


## «Дождь за окном»: большое окно, за стеклом дождь; по ходу загрузки капли редеют, небо
## светлеет, в конце радуга.
class RainWindow extends Control:
	var progress := 0.0
	var _t := 0.0
	var _drops: Array[Vector3] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 3
		for i in 90:
			_drops.append(Vector3(rng.randf(), rng.randf(), 0.6 + rng.randf() * 0.8))

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color("f1d9a8"))
		draw_rect(Rect2(0, s.y * 0.72, s.x, s.y * 0.28), Color("c98e5a"))
		var w := Rect2(s.x * 0.12, s.y * 0.2, s.x * 0.76, s.y * 0.46)
		var sky := Color("4f6078").lerp(Color("8fc9f0"), progress)
		draw_rect(w, sky)
		if progress > 0.85:
			var a := (progress - 0.85) / 0.15
			var c := Vector2(w.get_center().x, w.end.y + 40 * u)
			var cols := [Color("e8574a"), Color("f2a33a"), Color("f2d64e"), Color("6cc36a"), Color("4a90d9"), Color("8a6bd8")]
			for i in cols.size():
				draw_arc(c, (260 - i * 16) * u, PI, TAU, 64, Color(cols[i], 0.7 * a), 16 * u, true)
		var rain := 1.0 - progress
		for dp in _drops:
			if dp.x > rain * 1.05:
				continue
			var y := fposmod(dp.y + _t * dp.z, 1.0)
			var p := w.position + Vector2(fposmod(dp.x * 7.3, 1.0) * w.size.x, y * w.size.y)
			draw_line(p, p + Vector2(-4, 22) * u, Color(0.85, 0.92, 1.0, 0.6), 2.0 * u)
		draw_rect(w, Color("8a5a36"), false, 24 * u)
		draw_line(Vector2(w.get_center().x, w.position.y), Vector2(w.get_center().x, w.end.y), Color("8a5a36"), 14 * u)
		draw_line(Vector2(w.position.x, w.get_center().y), Vector2(w.end.x, w.get_center().y), Color("8a5a36"), 14 * u)
		draw_rect(Rect2(w.position.x - 30 * u, w.end.y, w.size.x + 60 * u, 26 * u), Color("a8764a"))


## «Ключ от дома»: тёплая стена и дверь, по ходу загрузки дверь приоткрывается внутрь и из
## щели льётся свет.
class WarmDoor extends Control:
	var progress := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)]),
			PackedColorArray([Color("6a4a7a"), Color("7a4f6e"), Color("3c2a3e"), Color("3c2a3e")]))
		draw_rect(Rect2(0, s.y * 0.8, s.x, s.y * 0.2), Color("4a3326"))
		var d := Rect2(s.x * 0.52, s.y * 0.34, 250 * u, s.y * 0.46)
		# свет из проёма
		var open := progress
		draw_rect(d, Color("ffe7a8").lerp(Color("fff4d6"), open))
		var glow := Color(1, 0.85, 0.5, 0.35 * open)
		draw_colored_polygon(PackedVector2Array([d.position, Vector2(d.end.x, d.position.y), Vector2(d.end.x + 200 * u, s.y), Vector2(d.position.x - 200 * u, s.y)]), glow)
		# полотно двери поворачивается внутрь: сужается к левому косяку
		var dw := d.size.x * (1.0 - 0.8 * open)
		var leaf := PackedVector2Array([d.position, d.position + Vector2(dw, d.size.y * 0.04 * open),
			d.position + Vector2(dw, d.size.y * (1.0 - 0.04 * open)), Vector2(d.position.x, d.end.y)])
		draw_colored_polygon(leaf, Color("8a4f36"))
		draw_polyline(leaf + PackedVector2Array([leaf[0]]), Color("5a321f"), 4 * u)
		draw_circle(d.position + Vector2(dw - 22 * u, d.size.y * 0.52), 8 * u, Color("f2c14e"), true, -1.0, true)
		draw_rect(d.grow(10 * u), Color("5a321f"), false, 16 * u)


## «Альбом»: деревянный стол, на него по очереди ложатся фотокарточки комнат (их фоны).
class PhotoAlbum extends Control:
	var progress := 0.0
	var _pics: Array[Texture2D] = []
	var _caps: Array[String] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for loc in ["room", "kitchen", "bath", "living"]:
			var p := "res://art/act1/%s/background.png" % loc
			if ResourceLoader.exists(p):
				_pics.append(load(p))

	## Свои карточки с подписями: [[путь, подпись], ...].
	func use(list: Array) -> void:
		_pics.clear()
		_caps.clear()
		for e: Array in list:
			if ResourceLoader.exists(str(e[0])):
				_pics.append(load(str(e[0])))
				_caps.append(str(e[1]))

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color("a86f42"))
		for i in 14:
			var y := s.y * i / 14.0
			draw_line(Vector2(0, y), Vector2(s.x, y + 6 * u), Color(0.45, 0.27, 0.15, 0.25), 3 * u)
		var spots := [Vector2(0.3, 0.32), Vector2(0.7, 0.36), Vector2(0.32, 0.6), Vector2(0.7, 0.63)]
		var tilt := [-0.12, 0.09, 0.07, -0.1]
		for i in _pics.size():
			var a := clampf(progress * 4.2 - i, 0.0, 1.0)
			if a <= 0.0:
				continue
			var c := Vector2(spots[i].x * s.x, spots[i].y * s.y)
			var sz := Vector2(230, 280) * u * (1.2 - 0.2 * a)
			draw_set_transform(c, tilt[i], Vector2.ONE)
			draw_rect(Rect2(-sz * 0.5 + Vector2(6, 8) * u, sz), Color(0, 0, 0, 0.25 * a))
			draw_rect(Rect2(-sz * 0.5, sz), Color(1, 0.98, 0.93, a))
			var ph := Rect2(-sz * 0.5 + Vector2(14, 14) * u, Vector2(sz.x - 28 * u, sz.y - 70 * u))
			var tex := _pics[i]
			var src_h := minf(tex.get_height(), tex.get_width() * ph.size.y / ph.size.x)
			var src := Rect2(Vector2(0, (tex.get_height() - src_h) * 0.35), Vector2(tex.get_width(), src_h))
			draw_texture_rect_region(tex, ph, src, Color(1, 1, 1, a))
			if i < _caps.size():
				var f := ThemeDB.fallback_font
				draw_string(f, Vector2(-sz.x * 0.5, sz.y * 0.5 - 20 * u), _caps[i], HORIZONTAL_ALIGNMENT_CENTER, sz.x, int(19 * u), Color(0.35, 0.22, 0.14, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## «Чертёж»: синяя миллиметровка, по ходу загрузки белыми линиями рисуется план-фасад домика.
class Blueprint extends Control:
	var progress := 0.0
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color("2d5b9a"))
		var step := 32.0 * u
		var x := 0.0
		while x < s.x:
			draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.08), 1.0)
			x += step
		var y := 0.0
		while y < s.y:
			draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.08), 1.0)
			y += step
		var cx := s.x * 0.62
		var gy := s.y * 0.72
		var W := 300.0 * u
		var H := 220.0 * u
		var segs := [
			[Vector2(cx - W / 2, gy), Vector2(cx + W / 2, gy)], [Vector2(cx - W / 2, gy), Vector2(cx - W / 2, gy - H)],
			[Vector2(cx + W / 2, gy), Vector2(cx + W / 2, gy - H)], [Vector2(cx - W / 2 - 20 * u, gy - H), Vector2(cx, gy - H - 160 * u)],
			[Vector2(cx, gy - H - 160 * u), Vector2(cx + W / 2 + 20 * u, gy - H)], [Vector2(cx - W / 2 - 20 * u, gy - H), Vector2(cx + W / 2 + 20 * u, gy - H)],
			[Vector2(cx - 30 * u, gy), Vector2(cx - 30 * u, gy - 110 * u)], [Vector2(cx - 30 * u, gy - 110 * u), Vector2(cx + 30 * u, gy - 110 * u)],
			[Vector2(cx + 30 * u, gy - 110 * u), Vector2(cx + 30 * u, gy)],
			[Vector2(cx - 120 * u, gy - 170 * u), Vector2(cx - 60 * u, gy - 170 * u)], [Vector2(cx - 120 * u, gy - 120 * u), Vector2(cx - 60 * u, gy - 120 * u)],
			[Vector2(cx + 60 * u, gy - 170 * u), Vector2(cx + 120 * u, gy - 170 * u)], [Vector2(cx + 60 * u, gy - 120 * u), Vector2(cx + 120 * u, gy - 120 * u)],
		]
		var n := segs.size()
		for i in n:
			var k := clampf(progress * n - i, 0.0, 1.0)
			if k <= 0.0:
				continue
			var a: Vector2 = segs[i][0]
			var b: Vector2 = segs[i][1]
			draw_line(a, a.lerp(b, k), Color(1, 1, 1, 0.92), 4 * u, true)
		# карандаш на конце текущей линии
		var cur := clampi(int(progress * n), 0, n - 1)
		var tip: Vector2 = segs[cur][0].lerp(segs[cur][1], clampf(progress * n - cur, 0.0, 1.0))
		draw_line(tip, tip + Vector2(40, -60) * u, Color("f2c14e"), 10 * u)
		draw_circle(tip, 5 * u, Color(1, 1, 1, 0.9), true, -1.0, true)


## «Раскрытый альбом»: две страницы, на них по очереди появляются фото с уголками и подписями,
## между фото — сердечки. Фото — сюжет и комнаты.
class AlbumSpread extends Control:
	var progress := 0.0
	var _pics: Array[Texture2D] = []
	var _caps := ["Первая ночь", "Письмо", "Прабабушка Вера", "Кухня", "Ванная", "Гостиная"]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for p in ["res://art/act1/story/night.png", "res://art/act1/story/letter.png", "res://art/act1/story/photo_full.png",
				"res://art/act1/kitchen/background.png", "res://art/act1/bath/background.png", "res://art/act1/living/background.png"]:
			_pics.append(load(p) if ResourceLoader.exists(p) else null)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size
		var u := minf(s.x / 720.0, s.y / 1280.0)
		draw_rect(Rect2(Vector2.ZERO, s), Color("5a3a4a"))
		# обложка и две страницы
		var book := Rect2(s.x * 0.04, s.y * 0.2, s.x * 0.92, s.y * 0.44)
		draw_rect(book.grow(12 * u), Color("8a2f3a"))
		var lp := Rect2(book.position, Vector2(book.size.x * 0.5, book.size.y))
		var rp := Rect2(book.position + Vector2(book.size.x * 0.5, 0), Vector2(book.size.x * 0.5, book.size.y))
		draw_rect(lp, Color("f6ead2"))
		draw_rect(rp, Color("f3e3c6"))
		draw_line(Vector2(book.get_center().x, book.position.y), Vector2(book.get_center().x, book.end.y), Color(0.5, 0.35, 0.25, 0.5), 4 * u)
		var f := ThemeDB.fallback_font
		for i in _pics.size():
			var a := clampf(progress * 6.3 - i, 0.0, 1.0)
			if a <= 0.0 or _pics[i] == null:
				continue
			var page := lp if i < 3 else rp
			var col := i % 3
			var cell := Rect2(page.position + Vector2(18 * u, 12 * u + col * page.size.y / 3.0), Vector2(page.size.x - 36 * u, page.size.y / 3.0 - 24 * u))
			var ph := Rect2(cell.position, Vector2(cell.size.x * 0.58, cell.size.y))
			var tex := _pics[i]
			var src_h := minf(tex.get_height(), tex.get_width() * ph.size.y / ph.size.x)
			draw_rect(ph.grow(4 * u), Color(1, 1, 1, a))
			draw_texture_rect_region(tex, ph, Rect2(Vector2(0, (tex.get_height() - src_h) * 0.35), Vector2(tex.get_width(), src_h)), Color(1, 1, 1, a))
			for c in [ph.position, Vector2(ph.end.x, ph.position.y), ph.end, Vector2(ph.position.x, ph.end.y)]:
				var dx := 1.0 if c.x == ph.position.x else -1.0
				var dy := 1.0 if c.y == ph.position.y else -1.0
				draw_colored_polygon(PackedVector2Array([c, c + Vector2(22 * dx, 0) * u, c + Vector2(0, 22 * dy) * u]), Color(0.45, 0.25, 0.18, a))
			draw_string(f, Vector2(ph.end.x + 8 * u, ph.get_center().y + 8 * u), _caps[i], HORIZONTAL_ALIGNMENT_LEFT, cell.size.x * 0.42, int(15 * u), Color(0.4, 0.24, 0.16, a))
			var hc := Vector2(ph.end.x + cell.size.x * 0.21, ph.end.y - 14 * u)
			draw_circle(hc + Vector2(-5, -3) * u, 6 * u, Color(0.9, 0.35, 0.3, a), true, -1.0, true)
			draw_circle(hc + Vector2(5, -3) * u, 6 * u, Color(0.9, 0.35, 0.3, a), true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([hc + Vector2(-10.5, -1) * u, hc + Vector2(10.5, -1) * u, hc + Vector2(0, 10) * u]), Color(0.9, 0.35, 0.3, a))

