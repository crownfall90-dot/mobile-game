class_name UiKit
extends RefCounted
## Общий набор интерфейса (DESIGN §10): цвета, шрифты и конструкторы виджетов.
## Всё рисуется кодом; стили кнопок кэшируются, перерисовка только при смене состояния.
## Анимации появления, тряски и переходов — в UiTransition (transition.gd).

# --- токены ---------------------------------------------------------------
const BG_TOP := Color("120c24")
const BG_BOTTOM := Color("2a1a4a")
const PANEL := Color("2a2147")
const PANEL_ALPHA := 0.88
const PANEL_BORDER := Color("9d8fd0")
const INK := Color("1b1236")
const INK_CHAR := Color("24163d")
const TEXT := Color(1, 1, 1)
const TEXT_MUTED := Color(1, 1, 1, 0.7)
const GOLD := Color("f5c542")
const GOLD_DARK := Color("a8741a")
const GOLD_LIGHT := Color("fff1b8")
const VIOLET := Color("8a4dff")
const VIOLET_DARK := Color("5427b8")
const VIOLET_LIGHT := Color("c4a3ff")
const MAGENTA := Color("ff4fd8")
const DANGER := Color("ff5a5a")
const WATER := Color("1a6bfa")
const WATER_LIGHT := Color("8ce6ff")
const LAVA := Color("f2380f")
const LAVA_LIGHT := Color("ffdb4d")
const ACID := Color("4dcc1a")
const ACID_LIGHT := Color("d9ff73")
const SLIME := Color("b561ff")
const MAGMA := Color("ff6a1f")
const MAGMA_CRACK := Color("3a0f05")

const RADIUS := 22
const BORDER := 3
const LIP := 6
const TOUCH := 88          # минимальная зона нажатия
const SIZE_S := 28
const SIZE_M := 36
const SIZE_L := 56
const SIZE_XL := 84
const GAP := 24

# стиль кнопки: лицо, губа снизу, блик, обводка текста
const STYLES := {
	&"primary": [Color("f5c542"), Color("a8741a"), Color("fff1b8"), Color("6e3f06")],
	&"secondary": [Color("8a4dff"), Color("5427b8"), Color("c9adff"), Color("2c1170")],
	&"danger": [Color("ff5a5a"), Color("b3263d"), Color("ffc4c4"), Color("67101f")],
	&"green": [Color("56cf22"), Color("2d8410"), Color("d9ff73"), Color("1c4a07")],
	&"glass": [Color("4a3d88"), Color("231a45"), Color("9384dc"), Color("1b1236")],
	&"ghost": [Color(0.62, 0.56, 0.82, 0.16), Color(0.11, 0.07, 0.21, 0.55), Color(1, 1, 1, 0.25), Color("1b1236")],
	&"disabled": [Color("7a7396"), Color("46405e"), Color("aaa4c4"), Color("2f2a45")],
}

static var _bold: FontVariation
static var _body: FontVariation
static var _theme: Theme
static var _boxes: Dictionary = {}     # "стиль|радиус" -> [StyleBoxFlat]
static var _empties: Dictionary = {}
static var _fx: CanvasLayer
static var _rng := RandomNumberGenerator.new()


# --- шрифты и текст ---------------------------------------------------------

## Шрифт Godot по умолчанию (есть кириллица), утолщённый для заголовков.
static func font(bold := true) -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.6
		_body = FontVariation.new()
		_body.base_font = ThemeDB.fallback_font
		_body.variation_embolden = 0.2
	return _bold if bold else _body


static func outline_for(size: int) -> int:
	return clampi(roundi(size * 0.22), 5, 14)


## Новый LabelSettings: жирный, чернильный контур и тень под ним. outline = 0 — без контура.
static func text_style(size := SIZE_M, color := TEXT, outline := -1, bold := true) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font(bold)
	ls.font_size = size
	ls.font_color = color
	var o := outline_for(size) if outline < 0 else outline
	if o > 0:
		ls.outline_size = o
		ls.outline_color = INK
		ls.shadow_size = o
		ls.shadow_color = Color(INK, 0.6)
		ls.shadow_offset = Vector2(0, maxf(2.0, roundf(size / 12.0)))
	return ls


static func label(text: String, size := SIZE_M, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = text_style(size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Обычный текст абзацем: без контура, с переносом слов.
static func body(text: String, size := SIZE_S, color := TEXT_MUTED) -> Label:
	var l := label(text, size, color)
	l.label_settings = text_style(size, color, 0, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Тема для корня интерфейса: шрифт и размер по умолчанию, тонкие полосы прокрутки.
static func theme() -> Theme:
	if _theme:
		return _theme
	_theme = Theme.new()
	_theme.default_font = font(true)
	_theme.default_font_size = SIZE_M
	_theme.set_color(&"font_color", &"Label", TEXT)
	var grab := _flat(Color(PANEL_BORDER, 0.55), 6)
	grab.content_margin_left = 5
	grab.content_margin_right = 5
	var track := _flat(Color(INK, 0.35), 6)
	for bar in [&"VScrollBar", &"HScrollBar"]:
		_theme.set_stylebox(&"scroll", bar, track)
		for s in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
			_theme.set_stylebox(s, bar, grab)
	return _theme


# --- конструкторы -------------------------------------------------------------

## Кнопка-«леденец»: primary (золото), secondary (фиолет), danger, green, glass, ghost.
static func button(text: String, style := &"primary", icon := &"") -> Chunky:
	var b := Chunky.new(style)
	b.text = text
	b.custom_minimum_size = Vector2(220, 104)
	if icon != &"" and text == "":
		b.icon = Icons.tex(icon, 56)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size.x = 104
	elif icon != &"":
		b.set_side_icon(icon)
	return b


## Круглая кнопка 88 px с иконкой и необязательным значком-счётчиком.
static func icon_button(icon: StringName, badge_text := "", style := &"glass") -> IconButton:
	return IconButton.new(icon, badge_text, style)


static func panel(style := &"glass") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", panel_box(style))
	if style == &"glass" or style == &"card":
		p.draw.connect(_draw_sheen.bind(p))
	return p


## Стиль панели: glass (основная), card (карточка на панели), inset (углубление), gold (выделенная).
static func panel_box(style := &"glass") -> StyleBoxFlat:
	var sb: StyleBoxFlat
	match style:
		&"card":
			sb = _flat(Color("3a2e68"), 18, Color("211a40"), BORDER)
			sb.border_width_bottom = LIP
			_margins(sb, 20, 16, 20, 16 + LIP)
		&"inset":
			sb = _flat(Color(INK, 0.5), 18)
			_margins(sb, 20, 14, 20, 14)
		&"gold":
			sb = _flat(Color("4a3a24"), RADIUS, GOLD, BORDER)
			sb.shadow_color = Color(GOLD, 0.35)
			sb.shadow_size = 14
			_margins(sb, 24, 20, 24, 20)
		_:
			sb = _flat(Color(PANEL, PANEL_ALPHA), RADIUS, PANEL_BORDER, BORDER)
			sb.shadow_color = Color(0.02, 0.0, 0.06, 0.5)
			sb.shadow_size = 24
			sb.shadow_offset = Vector2(0, 12)
			_margins(sb, 32, 28, 32, 32)
	return sb


## Счётчик валюты (монеты, звёзды, зелья). Нажимается; set_value() считает вверх.
static func pill(icon: StringName) -> Pill:
	return Pill.new(icon)


## Ряд звёзд: n закрашено из 3. При size >= 64 — дугой, средняя крупнее.
static func star_row(n: int, size := 48) -> StarRow:
	return StarRow.new(n, size)


static func progress_bar(style := &"primary") -> Bar:
	return Bar.new(style)


## Строка-переключатель: cb(on: bool) вызывается при каждом нажатии.
static func toggle(text: String, value: bool, cb: Callable, icon := &"") -> Toggle:
	return Toggle.new(text, value, cb, icon)


## Пульсирующая точка «есть новое». Добавь ребёнком кнопки (не контейнера) — сядет в угол.
static func red_dot() -> Control:
	return Dot.new()


## Табличка-счётчик («3», «NEW»); цвет по умолчанию — маджента.
static func badge(text: String, color := MAGENTA) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := _flat(color, 17, INK, BORDER)
	_margins(sb, 10, 1, 10, 3)
	p.add_theme_stylebox_override(&"panel", sb)
	var l := label(text, 24)
	l.label_settings.outline_size = 6
	l.label_settings.shadow_color = Color(0, 0, 0, 0)
	l.custom_minimum_size = Vector2(18, 0)
	l.name = "Text"
	p.add_child(l)
	return p


## Лента-заголовок с «хвостами» (заголовок попапа, «Спасена!»).
static func ribbon(text: String, style := &"secondary") -> Ribbon:
	return Ribbon.new(text, style)


static func icon_rect(name: StringName, px := 64) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Icons.tex(name, px)
	r.custom_minimum_size = Vector2(px, px)
	r.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func gap(px := GAP) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Внешний вид всплывающего сообщения (для Router.toast).
static func toast_card(text: String, icon_name := &"") -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _flat(Color(INK, 0.92), 40, Color(PANEL_BORDER, 0.8), BORDER)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	_margins(sb, 22, 12, 30, 12)
	p.add_theme_stylebox_override(&"panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(row)
	if icon_name != &"":
		row.add_child(icon_rect(icon_name, 52))
	var l := label(text, 30)
	# длинный текст переносится, короткий остаётся в одну строку
	if font(true).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x > 540.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 540
	row.add_child(l)
	return p


# --- движение чисел и монет ----------------------------------------------------

## Счёт от a до b в тексте lbl (Label, Button — всё, у чего есть text).
## fmt получает уже отформатированное число: "+%s", "%s / 300".
static func count_up(lbl: Control, a: int, b: int, dur := 0.6, fmt := "%s", delay := 0.0) -> Tween:
	var tw := lbl.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_method(func(v: float) -> void: lbl.set(&"text", fmt % num(roundi(v))), float(a), float(b), dur) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return tw


## Число с пробелами между тысячами: 12 450.
static func num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Монеты разлетаются из from (координаты холста) и по кривым Безье летят в to;
## каждая, долетев, «толкает» цель (to.bump()). Возвращает время до последней.
static func fly_coins(from: Vector2, to: Control, n: int, icon_name := &"coin") -> float:
	if to == null or n <= 0 or not to.is_inside_tree():
		return 0.0
	if low_fx():
		n = maxi(1, n >> 1)
	n = mini(n, 20)
	var layer := fx_layer()
	var target: Vector2 = to.call(&"fly_target") if to.has_method(&"fly_target") else to.get_global_rect().get_center()
	var tex := Icons.tex(icon_name, 56)
	var last := 0.0
	for i in n:
		var c := Sprite2D.new()
		c.texture = tex
		c.position = from
		c.scale = Vector2.ZERO
		layer.add_child(c)
		var delay := i * 0.05
		var dur := _rng.randf_range(0.5, 0.68)
		var burst := from + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(50.0, 120.0)
		var ctrl := Vector2(lerpf(burst.x, target.x, 0.3) + _rng.randf_range(-160.0, 160.0),
				minf(burst.y, target.y) - _rng.randf_range(40.0, 200.0))
		var tw := c.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(c, ^"scale", Vector2.ONE * 1.1, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, ^"position", burst, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_method(_bezier.bind(c, burst, ctrl, target), 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, ^"scale", Vector2.ONE * 0.62, dur).set_ease(Tween.EASE_IN)
		tw.tween_callback(_coin_landed.bind(c, to))
		last = maxf(last, delay + 0.2 + dur)
	return last


## Слой поверх попапов для летящих монет и прочих эффектов интерфейса.
static func fx_layer() -> CanvasLayer:
	if is_instance_valid(_fx):
		return _fx
	_fx = CanvasLayer.new()
	_fx.name = "UiKitFx"
	_fx.layer = 90
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_fx)
	return _fx


static func _bezier(t: float, c: Sprite2D, p0: Vector2, p1: Vector2, p2: Vector2) -> void:
	c.position = p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


static func _coin_landed(c: Sprite2D, to: Control) -> void:
	c.queue_free()
	if is_instance_valid(to) and to.has_method(&"bump"):
		to.call(&"bump")
	sfx(&"coin")


# --- окружение: звук, вибрация, «меньше эффектов» ------------------------------

static func sfx(id: StringName) -> void:
	var s := _autoload(^"/root/Sfx")
	if s and s.has_method(&"play"):
		s.call(&"play", id)


static func haptic(ms: int) -> void:
	var s := _autoload(^"/root/Sfx")
	if s and s.has_method(&"haptic"):
		s.call(&"haptic", ms)


static func low_fx() -> bool:
	var p := _autoload(^"/root/Profile")
	return p != null and p.has_method(&"setting") and bool(p.call(&"setting", &"low_fx"))


## В ScrollContainer кнопка пропускает касание к нему (список листается пальцем по
## кнопкам; поставь списку scroll_deadzone ~16), вне его — останавливает, иначе тап
## по кнопке дойдёт до _unhandled_input уровня.
static func fit_mouse_filter(c: Control) -> void:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	var n := c.get_parent()
	while n is Control:
		if n is ScrollContainer:
			c.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		n = n.get_parent()
	c.mouse_filter = Control.MOUSE_FILTER_STOP


static func _autoload(path: NodePath) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(path) if tree else null


# --- рисование ------------------------------------------------------------------

## Кнопочная «таблетка»: тень, чернильный контур, губа, лицо, блик и искорка.
static func draw_chunky(ci: CanvasItem, r: Rect2, style: StringName, radius: int, lip: int, down := false) -> void:
	var b := _chunky_boxes(style, radius)
	var d := float(lip - 2) if down else 0.0
	var ghost := style == &"ghost"
	if not ghost:
		(b[1] if down else b[0]).draw(ci.get_canvas_item(), r)
	var inner := r.grow(-BORDER)
	b[2].draw(ci.get_canvas_item(), inner)
	var face := Rect2(inner.position + Vector2(0, d), inner.size - Vector2(0, lip))
	b[3].draw(ci.get_canvas_item(), face)
	# нижняя треть лица чуть темнее — объём без градиентов
	var sh := face.size.y * 0.3
	b[6].draw(ci.get_canvas_item(), Rect2(face.position + Vector2(0, face.size.y - sh), Vector2(face.size.x, sh)))
	var gh := face.size.y * 0.46
	b[4].draw(ci.get_canvas_item(), Rect2(face.position + Vector2(5, 4), Vector2(face.size.x - 10, gh)))
	if face.size.x > 60:
		var gw := clampf(face.size.x * 0.14, 12.0, 30.0)
		b[5].draw(ci.get_canvas_item(), Rect2(face.position + Vector2(maxf(12.0, radius * 0.55), 7), Vector2(gw, 7)))


static func _chunky_boxes(style: StringName, radius: int) -> Array:
	var key := "%s|%d" % [style, radius]
	if _boxes.has(key):
		return _boxes[key]
	var c: Array = STYLES.get(style, STYLES[&"primary"])
	var ink := _flat(INK, radius + BORDER)
	ink.shadow_color = Color(0.02, 0.0, 0.08, 0.42)
	ink.shadow_size = 10
	ink.shadow_offset = Vector2(0, 7)
	var ink_down := ink.duplicate() as StyleBoxFlat
	ink_down.shadow_size = 5
	ink_down.shadow_offset = Vector2(0, 3)
	var lip := _flat(c[1], radius)
	var face := _flat(c[0], radius)
	if style == &"ghost":
		face.border_color = Color(PANEL_BORDER, 0.75)
		face.set_border_width_all(BORDER)
	var gloss := _flat(Color(c[2], 0.5 if style != &"ghost" else 0.12), maxi(4, radius - 5))
	gloss.corner_radius_bottom_left = maxi(4, int(radius / 3.0))
	gloss.corner_radius_bottom_right = maxi(4, int(radius / 3.0))
	var glint := _flat(Color(1, 1, 1, 0.8 if style != &"ghost" else 0.3), 4)
	var shade := _flat(Color(c[1], 0.0 if style == &"ghost" else 0.22), radius)
	shade.corner_radius_top_left = 0
	shade.corner_radius_top_right = 0
	var arr := [ink, ink_down, lip, face, gloss, glint, shade]
	_boxes[key] = arr
	return arr


static func _pill_boxes() -> Array:
	if not _boxes.has("pill"):
		var ink: Array = _chunky_boxes(&"glass", 29)
		var capsule := _flat(Color("241b44"), 26, Color(PANEL_BORDER, 0.55), 2)
		var hl := _flat(Color(1, 1, 1, 0.07), 22)
		hl.corner_radius_bottom_left = 6
		hl.corner_radius_bottom_right = 6
		_boxes["pill"] = [ink[0], ink[1], capsule, hl]
	return _boxes["pill"]


static func _draw_sheen(p: Control) -> void:
	# тонкий светлый кант под верхней границей — «стекло»
	if not _boxes.has("sheen"):
		var sb := _flat(Color(0, 0, 0, 0), RADIUS - 2)
		sb.draw_center = false
		sb.border_width_top = 2
		sb.border_color = Color(1, 1, 1, 0.16)
		_boxes["sheen"] = sb
	(_boxes["sheen"] as StyleBox).draw(p.get_canvas_item(), Rect2(Vector2(BORDER, BORDER), p.size - Vector2(BORDER, BORDER) * 2))


static func _flat(bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10 if radius > 16 else 6
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	return sb


static func _margins(sb: StyleBox, l: float, t: float, r: float, b: float) -> void:
	sb.content_margin_left = l
	sb.content_margin_top = t
	sb.content_margin_right = r
	sb.content_margin_bottom = b


static func _empty(l: float, t: float, r: float, b: float) -> StyleBoxEmpty:
	var key := Vector4(l, t, r, b)
	if not _empties.has(key):
		var sb := StyleBoxEmpty.new()
		_margins(sb, l, t, r, b)
		_empties[key] = sb
	return _empties[key]


# --- виджеты ----------------------------------------------------------------------

## Кнопка с «губой»: фон рисует внутренний узел позади текста и иконки самой кнопки,
## поэтому text и icon работают как у обычной Button. Нажатие — сжатие до 0.94 и щелчок.
class Chunky extends Button:
	var style: StringName = &"primary"
	var radius := UiKit.RADIUS
	var lip := UiKit.LIP
	var pad := 30.0
	var face := Control.new()
	## Иконка слева от текста: держится вплотную к нему, даже если кнопка растянута.
	var side_icon: Texture2D
	var _was_off := false
	var _squash: Tween
	var _press := 1.0
	var _pulse := 0.0
	var _pulse_tw: Tween

	func _init(st: StringName = &"primary") -> void:
		focus_mode = Control.FOCUS_NONE
		face.show_behind_parent = true
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.set_anchors_preset(Control.PRESET_FULL_RECT)
		face.draw.connect(_paint)
		add_child(face, false, Node.INTERNAL_MODE_FRONT)
		add_theme_font_override(&"font", UiKit.font(true))
		add_theme_constant_override(&"h_separation", 12)
		set_font_size(UiKit.SIZE_M)
		button_down.connect(_on_down)
		button_up.connect(_on_up)
		resized.connect(func() -> void: pivot_offset = size * 0.5)
		set_style(st)

	func set_style(st: StringName) -> void:
		style = st
		var c: Array = UiKit.STYLES.get(st, UiKit.STYLES[&"primary"])
		add_theme_color_override(&"font_outline_color", c[3])
		for k in [&"font_color", &"font_pressed_color", &"font_hover_color", &"font_hover_pressed_color", &"font_focus_color"]:
			add_theme_color_override(k, UiKit.TEXT)
		add_theme_color_override(&"font_disabled_color", Color(1, 1, 1, 0.75))
		_apply_margins()
		face.queue_redraw()

	func set_font_size(px: int) -> void:
		add_theme_font_size_override(&"font_size", px)
		add_theme_constant_override(&"outline_size", UiKit.outline_for(px))
		face.queue_redraw()

	func set_side_icon(icon_name: StringName) -> void:
		side_icon = Icons.tex(icon_name, 56) if icon_name != &"" else null
		_apply_margins()
		face.queue_redraw()

	func _apply_margins() -> void:
		var left := pad + (side_icon.get_width() + 12.0 if side_icon else 0.0)
		var up := UiKit._empty(left, 2, pad, 2 + lip + UiKit.BORDER)
		var dn := UiKit._empty(left, lip, pad, UiKit.BORDER + 4)
		for k in [&"normal", &"hover", &"focus", &"disabled"]:
			add_theme_stylebox_override(k, up)
		for k in [&"pressed", &"hover_pressed"]:
			add_theme_stylebox_override(k, dn)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_ENTER_TREE:
			UiKit.fit_mouse_filter(self)

	func _is_down() -> bool:
		var m := get_draw_mode()
		return m == DRAW_PRESSED or m == DRAW_HOVER_PRESSED

	func _paint() -> void:
		var dn := _is_down()
		UiKit.draw_chunky(face, Rect2(Vector2.ZERO, size), &"disabled" if disabled else style, radius, lip, dn)
		if side_icon == null:
			return
		# иконка + текст — одна группа по центру (текст сдвинут полями стиля)
		var tw := get_theme_font(&"font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size(&"font_size")).x
		var iw := side_icon.get_size()
		var x := maxf(pad, (size.x - (iw.x + 12.0 + tw)) * 0.5)
		var cy := (size.y - lip - UiKit.BORDER) * 0.5 + (float(lip - 2) if dn else 0.0)
		var at := Vector2(x, cy - iw.y * 0.5).round()
		face.draw_texture(side_icon, at + Vector2(0, 3), Color(0, 0, 0, 0.22))
		face.draw_texture(side_icon, at, Color(1, 1, 1, 0.6 if disabled else 1.0))

	func _draw() -> void:
		if disabled != _was_off:
			_was_off = disabled
			var c: Array = UiKit.STYLES.get(&"disabled" if disabled else style, UiKit.STYLES[&"primary"])
			add_theme_color_override(&"font_outline_color", c[3])
		face.queue_redraw()

	## Мягкая пульсация (главная кнопка «Играть»); не мешает сжатию при нажатии.
	func set_pulse(on: bool) -> void:
		if _pulse_tw:
			_pulse_tw.kill()
			_pulse_tw = null
		_pulse = 0.0
		if on:
			_pulse_tw = create_tween().set_loops()
			_pulse_tw.tween_method(_set_pulse, 0.0, 1.0, 1.2)
		_apply_scale()

	func _set_pulse(v: float) -> void:
		_pulse = 0.04 * (0.5 - 0.5 * cos(v * TAU))
		_apply_scale()

	func _on_down() -> void:
		UiKit.sfx(&"ui_tap")
		if _squash:
			_squash.kill()
		_squash = create_tween()
		_squash.tween_method(_set_press, _press, 0.94, 0.06).set_trans(Tween.TRANS_QUAD)

	func _on_up() -> void:
		if _squash:
			_squash.kill()
		_squash = create_tween()
		# даже при очень коротком тапе сжатие успевает быть видно
		if _press > 0.95:
			_squash.tween_method(_set_press, _press, 0.94, 0.04)
		_squash.tween_method(_set_press, 0.94, 1.0, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _set_press(v: float) -> void:
		_press = v
		_apply_scale()

	func _apply_scale() -> void:
		scale = Vector2.ONE * (_press * (1.0 + _pulse))


## Круглая кнопка с иконкой; set_badge("3") показывает счётчик в углу, "" — прячет.
class IconButton extends Chunky:
	var _badge: PanelContainer

	func _init(icon_name: StringName, badge_text := "", st: StringName = &"glass") -> void:
		super(st)
		radius = 44
		lip = 7
		pad = 0.0
		custom_minimum_size = Vector2(UiKit.TOUCH, UiKit.TOUCH)
		# круглая: в ряду/колонке не растягивается
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon = Icons.tex(icon_name, 52)
		icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_apply_margins()
		set_badge(badge_text)

	func set_icon_name(icon_name: StringName) -> void:
		icon = Icons.tex(icon_name, 52)

	func set_badge(t: String, color := UiKit.MAGENTA) -> void:
		if _badge:
			_badge.queue_free()
			_badge = null
		if t == "":
			return
		_badge = UiKit.badge(t, color)
		_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_badge.offset_left = 12
		_badge.offset_right = 12
		_badge.offset_top = -12
		_badge.offset_bottom = -12
		add_child(_badge)


## Счётчик валюты: иконка наезжает на тёмную капсулу, число справа.
class Pill extends Chunky:
	var value := 0
	var icon_rect := TextureRect.new()
	var value_label: Label
	var _count: Tween
	var _bump: Tween

	func _init(icon_name: StringName) -> void:
		super(&"glass")
		custom_minimum_size = Vector2(180, UiKit.TOUCH)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_rect.texture = Icons.tex(icon_name, 64)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		icon_rect.offset_left = 0
		icon_rect.offset_right = 64
		icon_rect.offset_top = -33
		icon_rect.offset_bottom = 31
		icon_rect.pivot_offset = Vector2(32, 32)
		add_child(icon_rect)
		value_label = UiKit.label("0", 34)
		value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		value_label.offset_left = 62
		value_label.offset_right = -18
		value_label.offset_bottom = -2
		add_child(value_label)
		# Button не зовёт _get_minimum_size, поэтому ширину под число держим сами
		value_label.minimum_size_changed.connect(_fit)

	func _fit() -> void:
		custom_minimum_size.x = maxf(180.0, value_label.get_combined_minimum_size().x + 84.0)

	## Показать n; если anim — число «набегает» за dur секунд (после delay).
	func set_value(n: int, anim := true, dur := 0.6, delay := 0.0) -> void:
		if _count:
			_count.kill()
		var from := value
		value = n
		if not anim or from == n:
			value_label.text = UiKit.num(n)
			return
		_count = UiKit.count_up(value_label, from, n, dur, "%s", delay)

	## Куда летят монеты: центр иконки в координатах холста.
	func fly_target() -> Vector2:
		return icon_rect.get_global_rect().get_center()

	func bump() -> void:
		if _bump:
			_bump.kill()
		_bump = create_tween()
		icon_rect.scale = Vector2.ONE * 1.35
		_bump.tween_property(icon_rect, ^"scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _paint() -> void:
		var b := UiKit._pill_boxes()
		var h := 58.0
		var r := Rect2(22, (size.y - h) * 0.5, size.x - 22, h)
		var ci := face.get_canvas_item()
		(b[1] if _is_down() else b[0]).draw(ci, r)
		var inner := r.grow(-UiKit.BORDER)
		b[2].draw(ci, inner)
		b[3].draw(ci, Rect2(inner.position + Vector2(30, 4), Vector2(inner.size.x - 40, inner.size.y * 0.42)))


## Ряд звёзд. stamp_in(n) — по очереди «впечатывает» звёзды с кольцом и искрами.
class StarRow extends Control:
	var count := 3
	var filled := 0
	var px := 48
	var arc := false
	var _tex: Texture2D
	var _k := PackedFloat32Array()   # 0..1 — ход анимации каждой звезды, 1 — стоит

	func _init(n := 0, size_px := 48, total := 3) -> void:
		count = total
		px = size_px
		arc = px >= 64 and count == 3
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tex = Icons.tex(&"star", roundi(px * (1.25 if arc else 1.0)))
		_k.resize(count)
		var spacing := px * (0.22 if arc else 0.08)
		custom_minimum_size = Vector2(count * px + (count - 1) * spacing + (px * 0.5 if arc else 0.0), px * (1.35 if arc else 1.0))
		set_stars(n)

	func set_stars(n: int) -> void:
		filled = clampi(n, 0, count)
		for i in count:
			_k[i] = 1.0 if i < filled else 0.0
		queue_redraw()

	## Впечатать n звёзд по очереди; возвращает длительность всей анимации.
	func stamp_in(n: int, delay := 0.0, step := 0.34) -> float:
		set_stars(0)
		filled = clampi(n, 0, count)
		for i in filled:
			var tw := create_tween()
			tw.tween_interval(delay + step * i)
			tw.tween_callback(_ping.bind(i))
			tw.tween_method(_set_k.bind(i), 0.0, 1.0, 0.42)
		return delay + step * maxi(0, filled - 1) + 0.42

	func _ping(i: int) -> void:
		UiKit.sfx(StringName("star%d" % (i + 1)))
		UiKit.haptic(12)

	func _set_k(v: float, i: int) -> void:
		_k[i] = v
		queue_redraw()

	func _slot(i: int) -> Transform2D:
		# центр, поворот и масштаб i-й звезды
		var s := 1.0
		var rot := 0.0
		var y := size.y * 0.5
		var step := (size.x - px) / maxf(1.0, count - 1)
		var x := px * 0.5 + step * i
		if arc:
			var side := i - 1
			s = 1.25 if side == 0 else 1.0
			rot = side * 0.26
			y = size.y * 0.5 + (px * 0.14 if side != 0 else -px * 0.08)
		return Transform2D(rot, Vector2(s, s), 0.0, Vector2(x, y))

	func _draw() -> void:
		var base := float(px) * 0.5
		for i in count:
			draw_set_transform_matrix(_slot(i))
			var half := Vector2(base, base)
			# пустое гнездо — тёмный силуэт звезды
			draw_texture_rect(_tex, Rect2(-half, half * 2), false, Color(0.06, 0.03, 0.14, 0.62))
			var k := _k[i]
			if k > 0.0:
				var e := _ease_back(k)
				var sc := lerpf(1.7, 1.0, e)
				var a := clampf(k * 4.0, 0.0, 1.0)
				draw_texture_rect(_tex, Rect2(-half * sc, half * 2 * sc), false, Color(1, 1, 1, a))
				if k < 1.0:
					var rr := base * lerpf(0.7, 1.9, k)
					draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(UiKit.GOLD, 1.0 - k), lerpf(9.0, 1.0, k), true)
					for j in 6:
						var dir := Vector2.from_angle(TAU * j / 6.0 + 0.4)
						draw_circle(dir * base * lerpf(0.8, 2.3, k), lerpf(6.0, 1.5, k), Color(UiKit.GOLD_LIGHT, 1.0 - k * k), true, -1.0, true)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	static func _ease_back(t: float) -> float:
		var c := 1.9
		var u := t - 1.0
		return 1.0 + (c + 1.0) * u * u * u + c * u * u


## Полоса прогресса со скруглением, бликом, делениями (сундук) и подписью.
class Bar extends Control:
	var value := 0.0
	var max_value := 1.0
	var segments := 0
	var style: StringName = &"primary"
	var text_label: Label
	var _shown := 0.0
	var _tw: Tween
	var _sb: Array = []

	func _init(st: StringName = &"primary") -> void:
		style = st
		custom_minimum_size = Vector2(160, 44)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_label = UiKit.label("", 26)
		text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		text_label.offset_bottom = -2
		add_child(text_label)
		resized.connect(_rebuild)

	## Значение v из mx (mx < 0 — оставить прежний максимум); плавно, если anim.
	func set_value(v: float, mx := -1.0, anim := true, dur := 0.5) -> void:
		if mx > 0.0:
			max_value = mx
		value = clampf(v, 0.0, max_value)
		var target := value / maxf(0.0001, max_value)
		if _tw:
			_tw.kill()
		if not anim:
			_set_shown(target)
			return
		_tw = create_tween()
		_tw.tween_method(_set_shown, _shown, target, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	func set_text(t: String) -> void:
		text_label.text = t

	func _set_shown(v: float) -> void:
		_shown = v
		queue_redraw()

	func _rebuild() -> void:
		var r := int(size.y * 0.5)
		var c: Array = UiKit.STYLES.get(style, UiKit.STYLES[&"primary"])
		var ink := UiKit._flat(UiKit.INK, r)
		ink.shadow_color = Color(0, 0, 0, 0.3)
		ink.shadow_size = 6
		ink.shadow_offset = Vector2(0, 3)
		var track := UiKit._flat(Color("120c24"), r - 3)
		var fill := UiKit._flat(c[0], r - 3)
		var low := UiKit._flat(c[1], r - 3)
		low.corner_radius_top_left = 0
		low.corner_radius_top_right = 0
		var gloss := UiKit._flat(Color(c[2], 0.6), maxi(2, r - 7))
		_sb = [ink, track, fill, low, gloss]
		queue_redraw()

	func _draw() -> void:
		if _sb.is_empty():
			_rebuild()
		var ci := get_canvas_item()
		var b := UiKit.BORDER
		_sb[0].draw(ci, Rect2(Vector2.ZERO, size))
		var inner := Rect2(Vector2(b, b), size - Vector2(b, b) * 2)
		_sb[1].draw(ci, inner)
		if _shown > 0.001:
			var w := maxf(inner.size.y, inner.size.x * clampf(_shown, 0.0, 1.0))
			var f := Rect2(inner.position, Vector2(w, inner.size.y))
			_sb[2].draw(ci, f)
			var lh := f.size.y * 0.35
			_sb[3].draw(ci, Rect2(f.position + Vector2(0, f.size.y - lh), Vector2(w, lh)))
			if w > 24:
				_sb[4].draw(ci, Rect2(f.position + Vector2(6, 4), Vector2(w - 12, f.size.y * 0.3)))
		for k in range(1, segments):
			var x := inner.position.x + inner.size.x * k / float(segments)
			draw_line(Vector2(x, b + 2), Vector2(x, size.y - b - 2), Color(UiKit.INK, 0.9), 3.0)


## Строка «текст … [переключатель]», вся строка нажимается.
class Toggle extends Button:
	const OFF := Color("3b2f66")
	const ON := Color("48c21a")
	var _t := 0.0
	var _sb: Array = []
	var _cb: Callable
	var _tw: Tween

	func _init(txt: String, on: bool, cb: Callable, icon_name := &"") -> void:
		text = txt
		_cb = cb
		toggle_mode = true
		set_pressed_no_signal(on)
		_t = 1.0 if on else 0.0
		focus_mode = Control.FOCUS_NONE
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		custom_minimum_size = Vector2(420, UiKit.TOUCH)
		if icon_name != &"":
			icon = Icons.tex(icon_name, 48)
		add_theme_font_override(&"font", UiKit.font(true))
		add_theme_font_size_override(&"font_size", 34)
		add_theme_constant_override(&"outline_size", 7)
		add_theme_constant_override(&"h_separation", 16)
		add_theme_color_override(&"font_outline_color", UiKit.INK)
		for k in [&"font_color", &"font_pressed_color", &"font_hover_color", &"font_hover_pressed_color", &"font_focus_color"]:
			add_theme_color_override(k, UiKit.TEXT)
		var sb := UiKit._empty(6, 0, 140, 0)
		for k in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(k, sb)
		toggled.connect(_on_toggled)
		button_down.connect(func() -> void: UiKit.sfx(&"ui_tap"))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_ENTER_TREE:
			UiKit.fit_mouse_filter(self)

	## Поставить значение без вызова cb (например, после сброса настроек).
	func set_value(on: bool) -> void:
		set_pressed_no_signal(on)
		_t = 1.0 if on else 0.0
		queue_redraw()

	func _on_toggled(on: bool) -> void:
		if _tw:
			_tw.kill()
		_tw = create_tween()
		_tw.tween_method(_set_t, _t, 1.0 if on else 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _cb.is_valid():
			_cb.call(on)

	func _set_t(v: float) -> void:
		_t = v
		queue_redraw()

	func _draw() -> void:
		var track := Rect2(size.x - 114, (size.y - 56) * 0.5, 110, 56)
		var ci := get_canvas_item()
		var k := clampf(_t, 0.0, 1.0)
		if _sb.is_empty():
			var sh := UiKit._flat(Color(0, 0, 0, 0.22), 25)
			sh.corner_radius_bottom_left = 0
			sh.corner_radius_bottom_right = 0
			_sb = [UiKit._flat(UiKit.INK, 28), UiKit._flat(OFF, 25), sh]
		_sb[0].draw(ci, track)
		var inner := track.grow(-3)
		_sb[1].bg_color = OFF.lerp(ON, k)
		_sb[1].draw(ci, inner)
		_sb[2].draw(ci, Rect2(inner.position, Vector2(inner.size.x, 12)))
		var cx := lerpf(inner.position.x + 25.0, inner.end.x - 25.0, _t)
		var c := Vector2(cx, track.get_center().y)
		draw_circle(c + Vector2(0, 3), 24.0, Color(0, 0, 0, 0.25), true, -1.0, true)
		draw_circle(c, 23.0, UiKit.INK, true, -1.0, true)
		draw_circle(c, 20.0, Color("e6e0fa"), true, -1.0, true)
		draw_circle(c + Vector2(0, -2.5), 17.0, Color.WHITE, true, -1.0, true)


## Точка «новое»: маджента с чернильным ободком, пульсирует.
class Dot extends Control:
	var _tw: Tween

	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		size = custom_minimum_size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visibility_changed.connect(_sync)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PARENTED and not (get_parent() is Container):
			set_anchors_preset(Control.PRESET_TOP_RIGHT)
			offset_left = -24
			offset_right = 6
			offset_top = -6
			offset_bottom = 24
		elif what == NOTIFICATION_ENTER_TREE:
			_sync()

	func _sync() -> void:
		if not is_inside_tree():
			return
		if is_visible_in_tree() and _tw == null:
			_tw = create_tween().set_loops()
			_tw.tween_property(self, ^"scale", Vector2.ONE * 1.18, 0.45).set_trans(Tween.TRANS_SINE)
			_tw.tween_property(self, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
		elif not is_visible_in_tree() and _tw:
			_tw.kill()
			_tw = null

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 14.0, UiKit.INK, true, -1.0, true)
		draw_circle(c, 10.5, UiKit.MAGENTA, true, -1.0, true)
		draw_circle(c + Vector2(-3.5, -3.5), 3.2, Color(1, 1, 1, 0.9), true, -1.0, true)


## Лента-заголовок: полоса с губой и загнутые тёмные «хвосты» по краям.
class Ribbon extends MarginContainer:
	var style: StringName
	var text_label: Label

	func _init(txt: String, st: StringName = &"secondary") -> void:
		style = st
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override(&"margin_left", 76)
		add_theme_constant_override(&"margin_right", 76)
		add_theme_constant_override(&"margin_top", 6)
		add_theme_constant_override(&"margin_bottom", 18)
		text_label = UiKit.label(txt, 44)
		text_label.label_settings.outline_color = UiKit.STYLES.get(st, UiKit.STYLES[&"secondary"])[3]
		add_child(text_label)

	func set_text(t: String) -> void:
		text_label.text = t

	func _draw() -> void:
		var c: Array = UiKit.STYLES.get(style, UiKit.STYLES[&"secondary"])
		var h := size.y - 12.0
		var top := 16.0
		var bot := size.y
		var tail := Color(c[1]).darkened(0.1)
		for side: float in [-1.0, 1.0]:
			var edge := 0.0 if side < 0 else size.x
			var inner := 78.0 if side < 0 else size.x - 78.0
			var band := 40.0 if side < 0 else size.x - 40.0
			var pts := PackedVector2Array([Vector2(inner, top), Vector2(edge, top),
					Vector2(edge - side * 14.0, (top + bot) * 0.5), Vector2(edge, bot), Vector2(inner, bot)])
			draw_colored_polygon(pts, tail)
			pts.append(pts[0])
			draw_polyline(pts, UiKit.INK, 3.0, true)
			# складка: тёмный треугольник между концом полосы и хвостом
			draw_colored_polygon(PackedVector2Array([Vector2(band, h - 4), Vector2(inner, bot), Vector2(band, bot)]), Color(c[1]).darkened(0.55))
		UiKit.draw_chunky(self, Rect2(38, 0, size.x - 76, h), style, 16, 7)
