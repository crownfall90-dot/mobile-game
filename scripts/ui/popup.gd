class_name UiPopup
extends Control
## Основа всех попапов: затемнение, стеклянная панель по центру с лентой-заголовком
## и красным крестиком. Router.popup() создаёт узел, добавляет на слой 50 и зовёт open(args).
## Наследник наполняет content (VBoxContainer) в open() и закрывает через close(result).
## Прямые дети content проявляются лесенкой до своей прозрачности; ребёнка с
## modulate.a = 0 (наследник анимирует его сам: pop_in, fade_in) лесенка не трогает.
## Попап собирается в инициализаторах полей, а не в _init(): их GDScript выполняет
## у каждого класса цепочки, поэтому наследник может завести свой _init() и без
## super() — и уже в нём пользоваться panel и content.

signal closed(result: Variant)

const IN_TIME := 0.25
const OUT_TIME := 0.16

## Закрывается ли тапом мимо панели, крестиком и кнопкой «назад».
var dismissable := true:
	set(v):
		dismissable = v
		if _close_btn:
			_close_btn.visible = v
var dim := ColorRect.new()
var panel: PanelContainer = UiKit.panel(&"glass")
var content := VBoxContainer.new()
var _close_btn: UiKit.IconButton = UiKit.icon_button(&"close", "", &"danger")
var _frame := _build()   # после частей, из которых рамка собирается
var _ribbon: UiKit.Ribbon
var _closing := false
var _armed := false      # затемнение ловит тапы только после появления
var _dim_down := false


func _build() -> PopupFrame:
	var frame := PopupFrame.new()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# попапы живут и поверх поставленной на паузу игры
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiKit.theme()
	dim.color = Color(0.03, 0.01, 0.09, 0.74)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	add_child(frame)
	panel.custom_minimum_size = Vector2(600, 0)
	frame.add_child(panel)
	frame.panel = panel
	content.add_theme_constant_override(&"separation", 22)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(content)
	_close_btn.pressed.connect(func() -> void: close(null))
	frame.add_child(_close_btn)
	frame.close_btn = _close_btn
	resized.connect(_layout)
	frame.minimum_size_changed.connect(_layout)
	return frame


## Пустой: всё собрано выше. Нужен, чтобы super() в _init() наследника был допустим.
func _init() -> void:
	pass


## Вызывается роутером после добавления в дерево. Наследник переопределяет.
func open(_args: Dictionary) -> void:
	pass


## Лента-заголовок над панелью; "" убирает её.
func set_title(text: String, style := &"secondary") -> void:
	var sb := panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	if text == "" or (_ribbon and _ribbon.style != style):
		if _ribbon:
			_ribbon.queue_free()
			_ribbon = null
			_frame.ribbon = null
		sb.content_margin_top = 28
		if text == "":
			return
	if _ribbon == null:
		_ribbon = UiKit.ribbon(text, style)
		# тап по заголовку — не «мимо панели»
		_ribbon.mouse_filter = Control.MOUSE_FILTER_STOP
		_frame.add_child(_ribbon)
		_frame.ribbon = _ribbon
		# крестик всегда поверх ленты
		_frame.move_child(_close_btn, -1)
	_ribbon.set_text(text)
	sb.content_margin_top = 64


func set_panel_width(px: float) -> void:
	panel.custom_minimum_size.x = px


## Анимированно закрыть; closed(result) приходит, когда попап уже исчез.
func close(result: Variant = null) -> void:
	if _closing:
		return
	_closing = true
	# панель больше не ловит нажатия (двойной тап по «Забрать» не сработает дважды);
	# крестик не выключаем — иначе он посереет, пока попап ещё виден
	_frame.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
	if not is_inside_tree():
		_finish(result)
		return
	var tw := create_tween().set_parallel()
	tw.tween_property(dim, ^"modulate:a", 0.0, OUT_TIME)
	tw.tween_property(_frame, ^"scale", Vector2.ONE * 0.86, OUT_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_frame, ^"modulate:a", 0.0, OUT_TIME).set_delay(0.04)
	tw.chain().tween_callback(_finish.bind(result))


## Кнопка «назад» закрывает попап (если можно) и дальше не идёт.
func on_back() -> bool:
	if dismissable:
		close(null)
	return true


func is_closing() -> bool:
	return _closing


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_animate_in()


func _animate_in() -> void:
	dim.modulate.a = 0.0
	_frame.modulate.a = 0.0
	_frame.scale = Vector2.ONE * 0.6
	var tw := create_tween().set_parallel()
	tw.tween_property(dim, ^"modulate:a", 1.0, 0.2)
	tw.tween_property(_frame, ^"modulate:a", 1.0, 0.1)
	tw.tween_property(_frame, ^"scale", Vector2.ONE, IN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# второй тап двойного касания по кнопке, открывшей попап, не должен его закрыть
	tw.chain().tween_callback(func() -> void: _armed = true)
	UiKit.sfx(&"ui_pop")
	# содержимое проявляется лесенкой — после open(), который роутер зовёт сразу
	_stagger.call_deferred()


func _stagger() -> void:
	var i := 0
	for c: Node in content.get_children():
		var ci := c as CanvasItem
		# к своей прозрачности (строка может быть нарочно приглушена)
		var a := ci.modulate.a if ci else 0.0
		if ci and ci.visible and a > 0.01:
			ci.modulate.a = 0.0
			create_tween().tween_property(ci, ^"modulate:a", a, 0.16).set_delay(0.08 + 0.045 * i)
			i += 1


func _layout() -> void:
	var ms := _frame.get_combined_minimum_size()
	_frame.size = ms
	# лента торчит над панелью — смещаем чуть вниз, чтобы композиция была по центру
	var shift := 18.0 if _ribbon else 0.0
	_frame.position = ((size - ms) * 0.5 + Vector2(0, shift)).floor()


func _on_dim_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_dim_down = _armed
	elif _dim_down:
		_dim_down = false
		if dismissable and not _closing:
			close(null)


func _finish(result: Variant) -> void:
	closed.emit(result)
	queue_free()


## Рамка: панель на всю площадь, крестик на правом верхнем углу, лента над верхним краем.
## Масштабируется при появлении целиком, поэтому не лежит в контейнере.
class PopupFrame extends Container:
	var panel: Control
	var close_btn: Control
	var ribbon: UiKit.Ribbon

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _get_minimum_size() -> Vector2:
		return panel.get_combined_minimum_size() if panel else Vector2.ZERO

	func _notification(what: int) -> void:
		if what != NOTIFICATION_SORT_CHILDREN or panel == null:
			return
		fit_child_in_rect(panel, Rect2(Vector2.ZERO, size))
		if close_btn:
			var cs := close_btn.get_combined_minimum_size()
			fit_child_in_rect(close_btn, Rect2(Vector2(size.x - cs.x * 0.72, -cs.y * 0.28), cs))
		if ribbon:
			# по центру и не заходя под крестик: длинный текст лента ужимает сама
			var room := size.x - 132.0
			ribbon.fit(room)
			var rs := ribbon.get_combined_minimum_size()
			rs.x = clampf(maxf(rs.x, size.x * 0.62), 0.0, room)
			fit_child_in_rect(ribbon, Rect2(Vector2((size.x - rs.x) * 0.5, -rs.y * 0.52), rs))
		pivot_offset = size * 0.5
