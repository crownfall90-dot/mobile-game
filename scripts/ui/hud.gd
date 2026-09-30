class_name Hud
extends Control
## Интерфейс поверх уровня: верхняя панель, подсказка, экран результата.
## Всё строится кодом, без внешних ассетов. Временный: его заменит поток Game UX.

signal restart_requested
signal home_requested
signal pause_requested
signal hint_requested
## «Поверни»: игрок нажал ↻ (1) или ↺ (-1).
signal rotate_requested(dir: int)
signal next_requested

const ACCENT := Color("f5c542")
const PANEL := Color("33261f")
const MUTED := Color(1, 1, 1, 0.7)

var _bar: HBoxContainer
var _bottom_row: HBoxContainer
var _safe_bottom := 0.0
var _title: Label
var _gold: Label
var _hint: Label
var _rotate_row: HBoxContainer
var _ink: InkBar
var _hint_field := -1.0       # последнее место подсказки (place_hint), чтобы переставить её
var _hint_low := 0.7
var _rotate_buttons := {}      # dir -> RotateButton
var _hint_tween: Tween
var _overlay: ColorRect
var _panel: PanelContainer
var _res_title: Label
var _res_sub: Label
var _res_coins: Label      # «+80 монет» и из чего сложилось
var _stars: StarRow
var _res_button: Button
var _won := false
var _res_home: Button
var _goal_icon: Control
var _star_bar: StarBar
var _goal_max := 0            # на счётчике «n / порог трёх звёзд»; 0 — как раньше, до цели


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_hint()
	_build_overlay()


## Кнопки поворота вещи внизу по краям (мини-игра «Поверни»).
func show_rotate(on: bool) -> void:
	if on and _rotate_row == null:
		_rotate_row = HBoxContainer.new()
		_rotate_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_rotate_row.offset_top = -250 - _safe_bottom
		_rotate_row.offset_bottom = -124 - _safe_bottom
		_rotate_row.offset_left = 20
		_rotate_row.offset_right = -20
		_rotate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rotate_row)
		for dir: int in [-1, 1]:
			var b := RotateButton.new()
			b.dir = dir
			b.tooltip_text = "Повернуть по часовой" if dir > 0 else "Повернуть против часовой"
			b.pressed.connect(func() -> void: rotate_requested.emit(dir))
			_rotate_row.add_child(b)
			_rotate_buttons[dir] = b
			if dir < 0:
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_rotate_row.add_child(spacer)
	if _rotate_row:
		_rotate_row.visible = on


## «Замазка»: полоска-тюбик под верхней панелью; total <= 0 — спрятать.
func set_ink(left: float, total: float) -> void:
	if total <= 0.0:
		if _ink and _ink.visible:
			_ink.visible = false
			if _hint_field >= 0.0:
				place_hint(_hint_field, _hint_low)
		return
	if _ink == null:
		_ink = InkBar.new()
		_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ink)
	_ink.visible = true
	_ink.ratio = clampf(left / total, 0.0, 1.0)
	_ink.size = Vector2(300, 40)
	_ink.position = Vector2((size.x - 300.0) * 0.5, _bar.offset_bottom + 6.0)
	_ink.queue_redraw()
	if _hint_field >= 0.0:
		place_hint(_hint_field, _hint_low)


## Подсказка: пульсирует кнопка поворота, которую нажать следующей (0 — никакая).
func hint_rotate(dir: int) -> void:
	for d: int in _rotate_buttons:
		_rotate_buttons[d].hinted = d == dir


## Отступы от выреза камеры сверху и от жестовой полосы / скругления снизу (единицы экрана).
func set_safe(top: float, bottom := 0.0) -> void:
	_bar.offset_top = 20.0 + top
	_bar.offset_bottom = _bar.offset_top + 88.0
	_safe_bottom = bottom
	_bottom_row.offset_top = -104.0 - bottom
	_bottom_row.offset_bottom = -12.0 - bottom
	if _rotate_row:
		_rotate_row.offset_top = -250.0 - bottom
		_rotate_row.offset_bottom = -124.0 - bottom


## Подсказка — в свободной полосе между верхней панелью и полем головоломки (field_top —
## верх поля на экране). Если полоса слишком узкая, остаётся прежнее место в нижней части.
func place_hint(field_top: float, low := 0.7) -> void:
	_hint_field = field_top
	_hint_low = low
	# полоса замазки — сразу под верхней панелью: подсказка ниже неё, не поверх
	var top := _bar.offset_bottom + 4.0 + (46.0 if _ink and _ink.visible else 0.0)
	if field_top - top >= 64.0:
		_hint.anchor_top = 0.0
		_hint.anchor_bottom = 0.0
		_hint.offset_top = top
		_hint.offset_bottom = field_top - 4.0
	else:
		_hint.anchor_top = low
		_hint.anchor_bottom = low
		_hint.offset_top = -60.0
		_hint.offset_bottom = 60.0


## Заставка в начале уровня: где мы («Внутри раковины»), крупно, на пару секунд.
func show_place(text: String) -> void:
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.label_settings = _label_settings(46, Color("fff0ce"), 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.3
	label.anchor_bottom = 0.3
	label.offset_top = -40.0
	label.offset_bottom = 40.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	label.pivot_offset = Vector2(size.x * 0.5, 40)
	label.scale = Vector2(0.85, 0.85)
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.4)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


func set_level(title: String, hint: String) -> void:
	_title.text = title
	_hint.text = hint
	_hint.visible = hint != ""
	refresh_fx()
	_overlay.visible = false


func refresh_fx() -> void:
	if _hint_tween:
		_hint_tween.kill()
		_hint_tween = null
	_hint.modulate.a = 1.0
	if _hint.visible and not UiKit.low_fx():
		_hint_tween = create_tween().set_loops()
		# мягкое «дыхание», но не бледнее 80%: на светлых фонах подсказка должна читаться
		_hint_tween.tween_property(_hint, "modulate:a", 0.8, 0.9).set_trans(Tween.TRANS_SINE)
		_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


## Что считает счётчик: монеты, воду, камни или огонь (приёмник уровня внутри вещи).
func set_goal_kind(kind: String) -> void:
	if _goal_icon:
		_goal_icon.set(&"kind", kind)
		_goal_icon.queue_redraw()


## Звёзды уровня на счётчике. marks — пороги [★, ★★, ★★★] для сбора: счётчик идёт до порога
## трёх звёзд, звёзды стоят на полосе там, где их дадут. stake — ловкость: три звезды горят сразу
## и гаснут за ошибки. Без порогов полосы нет.
func set_star_marks(marks: Array, stake: bool) -> void:
	_goal_max = 0 if stake or marks.is_empty() else int(marks[2])
	_star_bar.setup(marks, stake)


## Звёзд сейчас (Level.stars_changed): новая звезда вспыхивает, потерянная падает.
func set_live_stars(n: int) -> void:
	_star_bar.set_stars(n)


func set_gold(collected: int, needed: int, total: int) -> void:
	if _goal_max > 0:
		# весь путь до трёх звёзд сразу: 0 / 42, на полосе ★ на 30, ★★ на 36, ★★★ на 42
		_gold.text = "%d / %d" % [mini(collected, _goal_max), _goal_max]
		_star_bar.set_progress(float(collected) / _goal_max)
	else:
		# до цели показываем прогресс к ней, после — сколько собрано из всего золота
		_gold.text = "%d / %d" % [collected, needed if collected < needed else total]
	_gold.label_settings.font_color = ACCENT if collected >= needed else Color.WHITE
	if collected > 0:
		var tw := create_tween()
		_gold.pivot_offset = _gold.size * 0.5
		tw.tween_property(_gold, "scale", Vector2(1.25, 1.25), 0.06)
		tw.tween_property(_gold, "scale", Vector2.ONE, 0.12)


func hide_hint() -> void:
	if not _hint.visible:
		return
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.25)
	_hint_tween.tween_callback(_hint.hide)


## coins — строка награды («+80 монет · первый ремонт 50, звёзды 30»), пусто — не показывать.
func show_result(won: bool, stars: int, text: String, title := "", coins := "") -> void:
	_won = won
	_res_coins.text = coins
	_res_coins.visible = coins != ""
	_res_title.text = title if title != "" else (Loc.t("level.won") if won else Loc.t("level.lost"))
	_res_title.label_settings.font_color = ACCENT if won else Color("ff8a8a")
	_res_sub.text = text
	_res_button.text = "Хорошо" if won else Loc.t("common.retry")
	_res_home.visible = not won
	_stars.visible = won
	_stars.set_stars(0)
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.8, 0.8)
	var tw := create_tween().set_parallel()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if won:
		tw.chain().tween_callback(_stars.animate_to.bind(stars))


func _build_top_bar() -> void:
	var bottom := HBoxContainer.new()
	_bottom_row = bottom
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -104
	bottom.offset_bottom = -12
	bottom.offset_left = 24
	bottom.offset_right = -24
	add_child(bottom)
	# круглые кнопки с иконками внизу: дом слева, подсказка по центру, пауза справа
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	for entry in [[&"home","Домой",home_requested],[&"hint","Подсказка",hint_requested],[&"pause","Пауза",pause_requested]]:
		var button := UiKit.icon_button(entry[0], "", &"glass")
		button.tooltip_text = entry[1]
		button.pressed.connect(func() -> void: entry[2].emit())
		bottom.add_child(button)
		if entry[0] != &"pause":
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bottom.add_child(spacer)

	_bar = HBoxContainer.new()
	_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_bar.offset_left = 24.0
	_bar.offset_right = -24.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_theme_constant_override("separation", 16)
	add_child(_bar)
	set_safe(0.0)

	var restart := IconButton.new()
	restart.pressed.connect(func() -> void: restart_requested.emit())
	_bar.add_child(restart)

	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.label_settings = _label_settings(32, Color.WHITE, 8)
	# длинное «Починить: Светильник» — в две строки, счётчик не уезжает за край
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(120, 0)
	_bar.add_child(_title)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.35), 44, Color(1, 1, 1, 0.18), 18))
	pill.custom_minimum_size = Vector2(0, 88)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(row)
	_goal_icon = CoinIcon.new()
	row.add_child(_goal_icon)
	# счётчик, а под ним полоса со звёздами на порогах
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	_gold = Label.new()
	_gold.label_settings = _label_settings(30, Color.WHITE, 0)
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.custom_minimum_size = Vector2(88, 0)
	col.add_child(_gold)
	_star_bar = StarBar.new()
	col.add_child(_star_bar)
	_bar.add_child(pill)


func _build_hint() -> void:
	_hint = Label.new()
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	# в пустой нижней камере, над героиней
	_hint.anchor_top = 0.7
	_hint.anchor_bottom = 0.7
	_hint.offset_left = 36.0
	_hint.offset_right = -36.0
	_hint.offset_top = -60.0
	_hint.offset_bottom = 60.0
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.label_settings = _label_settings(26, Color.WHITE, 8)
	# тень под буквами — контраст на светлых фонах (раковина, плита, потолок)
	_hint.label_settings.shadow_color = Color(0.05, 0.03, 0.08, 0.7)
	_hint.label_settings.shadow_size = 10
	_hint.label_settings.shadow_offset = Vector2(0, 2)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.04, 0.02, 0.1, 0.65)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_panel = PanelContainer.new()
	var sb := _box(PANEL, 40, Color(1, 1, 1, 0.14), 40)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 30
	sb.shadow_offset = Vector2(0, 12)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size = Vector2(540, 0)
	center.add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(col)

	_res_title = Label.new()
	_res_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_title.label_settings = _label_settings(60, ACCENT, 0)
	col.add_child(_res_title)

	_stars = StarRow.new()
	col.add_child(_stars)

	_res_sub = Label.new()
	_res_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_sub.label_settings = _label_settings(28, MUTED, 0)
	col.add_child(_res_sub)
	_res_coins = Label.new()
	_res_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_res_coins.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_res_coins.label_settings = _label_settings(26, Color("ffd66e"), 0)
	col.add_child(_res_coins)

	_res_button = Button.new()
	_res_button.custom_minimum_size = Vector2(0, 100)
	_res_button.focus_mode = Control.FOCUS_NONE
	_res_button.add_theme_font_size_override("font_size", 36)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		_res_button.add_theme_color_override(state, Color("2a1a05"))
	_res_button.add_theme_stylebox_override("normal", _box(ACCENT, 50, Color("fff1b8"), 0, 3))
	_res_button.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.1), 50, Color("fff1b8"), 0, 3))
	_res_button.add_theme_stylebox_override("pressed", _box(ACCENT.darkened(0.15), 50, Color("fff1b8"), 0, 3))
	_res_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_res_button.pressed.connect(_on_result_button)
	col.add_child(_res_button)
	_res_home = UiKit.button("Домой", &"secondary")
	col.add_child(_res_home)
	_res_home.pressed.connect(func() -> void: home_requested.emit())


func _on_result_button() -> void:
	_overlay.visible = false
	if _won:
		next_requested.emit()
	else:
		restart_requested.emit()


static func _label_settings(font_size: int, color: Color, outline: int) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = font_size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = Color(0.08, 0.04, 0.16, 0.9)
	return ls


static func _box(bg: Color, radius: int, border: Color, padding: int, border_w := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = padding
	sb.content_margin_right = padding
	sb.content_margin_top = padding * 0.6
	sb.content_margin_bottom = padding * 0.6
	sb.anti_aliasing = true
	return sb


## Тюбик замазки: сколько осталось.
class InkBar extends Control:
	var ratio := 1.0

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0, 26), "Замазка", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
		var r := Rect2(104, 10, 190, 20)
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0, 0, 0, 0.35)
		box.set_corner_radius_all(10)
		draw_style_box(box, r)
		if ratio > 0.0:
			var fill := StyleBoxFlat.new()
			fill.bg_color = Color("e9e1cf") if ratio > 0.25 else Color("f2a65a")
			fill.set_corner_radius_all(10)
			draw_style_box(fill, Rect2(r.position, Vector2(r.size.x * ratio, r.size.y)))


## Большая круглая кнопка поворота: дуга со стрелкой по или против часовой.
class RotateButton extends Button:
	var dir := 1
	var hinted := false
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(124, 124)
		focus_mode = Control.FOCUS_NONE
		add_theme_stylebox_override("normal", Hud._box(Color(0.95, 0.76, 0.3, 0.92), 62, Color(1, 1, 1, 0.7), 0, 4))
		add_theme_stylebox_override("hover", Hud._box(Color(1.0, 0.82, 0.38, 0.95), 62, Color(1, 1, 1, 0.8), 0, 4))
		add_theme_stylebox_override("pressed", Hud._box(Color(0.85, 0.62, 0.2, 0.95), 62, Color(1, 1, 1, 0.9), 0, 4))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	func _process(delta: float) -> void:
		_t += delta
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + (0.08 * sin(_t * 8.0) if hinted else 0.0))
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := 34.0
		var ink := Color("4a3226")
		var a0 := -PI * 0.75
		var a1 := PI * 0.6
		if dir < 0:
			var t0 := a0
			a0 = PI - a1
			a1 = PI - t0
		draw_arc(c, r, a0, a1, 32, ink, 9.0, true)
		var end := a1 if dir > 0 else a0
		var p := c + Vector2.from_angle(end) * r
		var tangent := Vector2(-sin(end), cos(end)) * float(dir)
		var nrm := Vector2.from_angle(end)
		draw_colored_polygon(PackedVector2Array([p + tangent * 16.0, p + nrm * 13.0 - tangent * 4.0,
			p - nrm * 13.0 - tangent * 4.0]), ink)


## Круглая кнопка "заново" с нарисованной иконкой.
class IconButton extends Button:
	func _init() -> void:
		custom_minimum_size = Vector2(88, 88)
		focus_mode = Control.FOCUS_NONE
		add_theme_stylebox_override("normal", Hud._box(Color(0, 0, 0, 0.35), 44, Color(1, 1, 1, 0.18), 0))
		add_theme_stylebox_override("hover", Hud._box(Color(0, 0, 0, 0.45), 44, Color(1, 1, 1, 0.3), 0))
		add_theme_stylebox_override("pressed", Hud._box(Color(1, 1, 1, 0.15), 44, Color(1, 1, 1, 0.4), 0))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button_down.connect(func() -> void: _press(0.9))
		button_up.connect(func() -> void: _press(1.0))

	func _press(s: float) -> void:
		pivot_offset = size * 0.5
		create_tween().tween_property(self, "scale", Vector2(s, s), 0.08)

	func _draw() -> void:
		var c := size * 0.5
		var r := 19.0
		var start := -PI / 2.0 + 0.7
		var end := -PI / 2.0 + TAU - 0.35
		draw_arc(c, r, start, end, 32, Color.WHITE, 6.0, true)
		var p := c + Vector2.from_angle(end) * r
		var t := Vector2(-sin(end), cos(end))
		var n := Vector2.from_angle(end)
		draw_colored_polygon(PackedVector2Array([p + t * 11.0, p + n * 9.0 - t * 2.0, p - n * 9.0 - t * 2.0]), Color.WHITE)


## Иконка монеты для счётчика золота.
class CoinIcon extends Control:
	var kind := "gold"   # что считаем: gold, water, stone, lava, tape (заклеенные дыры), plate (посуда)

	func _init() -> void:
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		match kind:
			"water", "lava":
				var col := Color("3a8dff") if kind == "water" else Color("ff6a1f")
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -17), c + Vector2(11, 2), c + Vector2(-11, 2)]), col)
				draw_circle(c + Vector2(0, 5), 11.0, col, true, -1.0, true)
				draw_circle(c + Vector2(-4, 3), 3.0, Color(1, 1, 1, 0.7), true, -1.0, true)
				return
			"stone":
				draw_circle(c, 16.0, Color("6d6560"), true, -1.0, true)
				draw_circle(c + Vector2(-5, -5), 5.0, Color("9a918a"), true, -1.0, true)
				return
			"thread":
				# катушка ниток: «сколько стежков»
				draw_rect(Rect2(c + Vector2(-12, -14), Vector2(24, 28)), Color("c7433a"))
				draw_rect(Rect2(c + Vector2(-15, -16), Vector2(30, 5)), Color("b88350"))
				draw_rect(Rect2(c + Vector2(-15, 11), Vector2(30, 5)), Color("b88350"))
				return
			"lamp":
				# лампочка: «зажги свет»
				draw_circle(c + Vector2(0, -3), 12.0, Color("ffe27a"), true, -1.0, true)
				draw_rect(Rect2(c + Vector2(-6, 8), Vector2(12, 8)), Color("8d969b"))
				draw_circle(c + Vector2(-4, -7), 3.0, Color(1, 1, 1, 0.8), true, -1.0, true)
				return
			"clog":
				# засор: бурый ком с пятнышками плесени
				draw_circle(c, 15.0, Color("6b5236"), true, -1.0, true)
				for k in 4:
					var a := k * TAU / 4.0 + 0.5
					draw_circle(c + Vector2(cos(a), sin(a)) * 7.0, 3.5, Color("5f8f4e"), true, -1.0, true)
				return
			"plate":
				# тарелка сбоку: «сколько посуды на полках»
				draw_rect(Rect2(c + Vector2(-18, 2), Vector2(36, 8)), Color("5a6b8c"))
				draw_rect(Rect2(c + Vector2(-17, 1), Vector2(34, 6)), Color("f4f4f0"))
				draw_rect(Rect2(c + Vector2(-10, -14), Vector2(20, 16)), Color("f4f4f0"))
				draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 4)), Color("d95a5a"))
				return
			"tape":
				# рулон ленты: «сколько дыр заклеено»
				draw_rect(Rect2(c + Vector2(4, 8), Vector2(16, 8)), Color("c9b98a"))
				draw_circle(c, 16.0, Color("9c8a5c"), true, -1.0, true)
				draw_circle(c, 14.0, Color("e6d6a8"), true, -1.0, true)
				draw_circle(c, 6.5, Color("6b5a3a"), true, -1.0, true)
				return
		draw_circle(c, 18.0, Color("b8741a"), true, -1.0, true)
		draw_circle(c + Vector2(0, -1.5), 15.0, Color("ffc933"), true, -1.0, true)
		draw_circle(c + Vector2(0, -1.5), 10.0, Color("ffdf6b"), false, 2.0, true)
		draw_circle(c + Vector2(-6, -7), 3.5, Color(1, 1, 1, 0.8), true, -1.0, true)


## Полоса под счётчиком: заполняется к трём звёздам, звёзды на порогах. Новая звезда вспыхивает
## (увеличивается и искрит), в режиме stake потерянная звезда вздрагивает, падает и гаснет.
class StarBar extends Control:
	const GAP := 30.0
	var _marks: Array = []
	var _stake := false
	var _progress := 0.0
	var _shown := -1
	var _pop: Array[float] = [0.0, 0.0, 0.0]    # 0..1 вспышка новой звезды
	var _drop: Array[float] = [0.0, 0.0, 0.0]   # 0..1 падение потерянной

	func _init() -> void:
		custom_minimum_size = Vector2(180, 36)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(marks: Array, stake: bool) -> void:
		_marks = marks
		_stake = stake
		_progress = 0.0
		_shown = -1
		for i in 3:
			_pop[i] = 0.0
			_drop[i] = 0.0
		visible = stake or (not marks.is_empty() and int(marks[2]) > 0)
		queue_redraw()

	func set_progress(v: float) -> void:
		_progress = clampf(v, 0.0, 1.0)
		queue_redraw()

	func set_stars(n: int) -> void:
		var was := _shown
		_shown = n
		if was < 0:
			queue_redraw()
			return
		var tw := create_tween().set_parallel()
		for i in 3:
			if i >= was and i < n:
				_pop[i] = 0.0
				tw.tween_method(_set_pop.bind(i), 0.0, 1.0, 0.6).set_delay((i - was) * 0.18)
			elif i >= n and i < was:
				_drop[i] = 0.0
				tw.tween_method(_set_drop.bind(i), 0.0, 1.0, 0.7)

	func _set_pop(v: float, i: int) -> void:
		_pop[i] = v
		queue_redraw()

	func _set_drop(v: float, i: int) -> void:
		_drop[i] = v
		queue_redraw()

	## Центры звёзд: у сбора — по порогам на полосе (не теснее GAP), у stake — рядом справа.
	func _centers() -> Array[float]:
		var x0 := 14.0
		var x1 := size.x - 16.0
		var xs: Array[float] = [x1 - GAP * 2.0, x1 - GAP, x1]
		if not _stake and int(_marks[2]) > 0:
			for i in 3:
				xs[i] = lerpf(x0, x1, float(_marks[i]) / float(_marks[2]))
			for i in [1, 0]:
				xs[i] = minf(xs[i], xs[i + 1] - GAP)
		return xs

	func _draw() -> void:
		if not visible:
			return
		var y := size.y * 0.5
		var xs := _centers()
		if not _stake:
			var r := Rect2(4.0, y - 4.0, size.x - 12.0, 8.0)
			draw_rect(r, Color(1, 1, 1, 0.16), true)
			if _progress > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * _progress, r.size.y)), Hud.ACCENT, true)
		for i in 3:
			var c := Vector2(xs[i], y)
			var lit := i < _shown
			if _drop[i] > 0.0 and _drop[i] < 1.0 and not lit:
				# потеряна: вздрогнула, упала вниз и погасла
				var d := _drop[i]
				c += Vector2(sin(d * 40.0) * 4.0 * (1.0 - d), d * d * 30.0)
				_star(c, 14.0, Color(Hud.ACCENT, 1.0 - d))
				continue
			var k := 1.0
			if lit and _pop[i] > 0.0 and _pop[i] < 1.0:
				k = 1.0 + sin(_pop[i] * PI) * 0.8
				# искры вокруг новой звезды
				for a in 6:
					var dir := Vector2.from_angle(TAU * a / 6.0 + 0.3)
					draw_circle(c + dir * (14.0 + _pop[i] * 24.0), 3.0 * (1.0 - _pop[i]), Color(1, 0.95, 0.6, 1.0 - _pop[i]))
			_star(c, 16.5 * k, Color(0.1, 0.06, 0.12, 0.55))
			_star(c, 14.0 * k, Hud.ACCENT if lit else Color(1, 1, 1, 0.3))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var rr := r if k % 2 == 0 else r * 0.48
			pts.append(c + Vector2.from_angle(-PI / 2.0 + PI * k / 5.0) * rr)
		draw_colored_polygon(pts, col)


## Три звезды на экране победы, появляются по очереди.
class StarRow extends Control:
	var _fill: Array[float] = [0.0, 0.0, 0.0]

	func _init() -> void:
		custom_minimum_size = Vector2(320, 110)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_stars(n: int) -> void:
		for i in 3:
			_fill[i] = 1.0 if i < n else 0.0
		queue_redraw()

	func animate_to(n: int) -> void:
		var tw := create_tween()
		for i in n:
			tw.tween_method(_set_fill.bind(i), 0.0, 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _set_fill(v: float, i: int) -> void:
		_fill[i] = v
		queue_redraw()

	func _draw() -> void:
		for i in 3:
			var c := Vector2(size.x * 0.5 + (i - 1) * 100.0, size.y * 0.5 + (0.0 if i == 1 else 10.0))
			var r := 44.0 if i == 1 else 36.0
			_star(c, r, Color(1, 1, 1, 0.12))
			if _fill[i] > 0.0:
				_star(c, r * _fill[i], Hud.ACCENT)
				_star(c + Vector2(-r * 0.15, -r * 0.2) * _fill[i], r * 0.35 * _fill[i], Color(1, 1, 1, 0.35))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for k in 10:
			var rr := r if k % 2 == 0 else r * 0.48
			pts.append(c + Vector2.from_angle(-PI / 2.0 + PI * k / 5.0) * rr)
		draw_colored_polygon(pts, col)
