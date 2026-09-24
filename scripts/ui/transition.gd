class_name UiTransition
extends RefCounted
## Движение интерфейса: смена экранов через шторку, появление и уход узлов,
## «печать», тряска, пульс. Всё на твинах; ничего не ждёт отрисовки.

const COVER_LAYER := 100


## Шторка цвета фона: за dur/2 закрывает экран, вызывает swap (смена экрана),
## за dur/2 открывает. Пока шторка видна, нажатия не проходят.
static func cover(swap: Callable, dur := 0.25, color := UiKit.BG_TOP) -> void:
	var layer := CanvasLayer.new()
	layer.layer = COVER_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.modulate.a = 0.0
	layer.add_child(rect)
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(layer)
	var tw := rect.create_tween()
	tw.tween_property(rect, ^"modulate:a", 1.0, dur * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(swap)
	tw.tween_property(rect, ^"modulate:a", 0.0, dur * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(layer.queue_free)


## Сдвиг двух экранов: incoming въезжает со стороны dir (1 — справа), old уезжает и
## по желанию удаляется. Оба должны быть Control во весь экран.
static func slide_swap(old: Control, incoming: Control, dir := 1.0, dur := 0.3, free_old := true) -> Tween:
	var w := incoming.get_viewport_rect().size.x if incoming.is_inside_tree() else 720.0
	var tw := incoming.create_tween().set_parallel()
	incoming.position.x = w * dir
	tw.tween_property(incoming, ^"position:x", 0.0, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(old):
		tw.tween_property(old, ^"position:x", -w * 0.3 * dir, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(old, ^"modulate:a", 0.0, dur)
		if free_old:
			tw.chain().tween_callback(old.queue_free)
	return tw


static func fade_in(node: CanvasItem, dur := 0.25, delay := 0.0) -> Tween:
	node.modulate.a = 0.0
	var tw := node.create_tween()
	tw.tween_property(node, ^"modulate:a", 1.0, dur).set_delay(delay)
	return tw


static func fade_out(node: CanvasItem, dur := 0.2, and_free := false) -> Tween:
	var tw := node.create_tween()
	tw.tween_property(node, ^"modulate:a", 0.0, dur)
	if and_free:
		tw.tween_callback(node.queue_free)
	return tw


## Въезд со стороны from (в долях собственного размера): (0, 1) — снизу, как нижняя шторка.
static func slide_in(node: Control, from := Vector2(0, 1), dur := 0.3, delay := 0.0) -> Tween:
	var home := _home(node)
	var dist := node.size if node.size != Vector2.ZERO else node.get_combined_minimum_size()
	node.position = home + from * dist
	var tw := node.create_tween()
	tw.tween_property(node, ^"position", home, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return _moving(node, tw, home, true)


static func slide_out(node: Control, to := Vector2(0, 1), dur := 0.22, and_free := false) -> Tween:
	var home := _home(node)
	var tw := node.create_tween()
	tw.tween_property(node, ^"position", home + to * node.size, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if and_free:
		tw.tween_callback(node.queue_free)
	# узел остаётся снаружи, «дом» помним: следующий slide_in вернёт его на место
	return _moving(node, tw, home, false)


## Появление с пружинкой от центра (scale from → 1).
static func pop_in(node: Control, delay := 0.0, from := 0.6, dur := 0.28) -> Tween:
	node.modulate.a = 0.0
	_scale_centered(from, node)
	var tw := node.create_tween().set_parallel()
	tw.tween_property(node, ^"modulate:a", 1.0, dur * 0.4).set_delay(delay)
	tw.tween_method(_scale_centered.bind(node), from, 1.0, dur).set_delay(delay) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## «Печать»: влетает крупной (1.6) и садится на место — звёзды, штампы, награды.
static func stamp(node: Control, delay := 0.0) -> Tween:
	return pop_in(node, delay, 1.6, 0.32)


## Тряска «нельзя» (закрытый уровень, не хватает монет). Частые тапы не сдвигают узел.
static func shake(node: Control, strength := 12.0, dur := 0.35) -> Tween:
	var home := _home(node)
	var tw := node.create_tween()
	tw.tween_method(func(t: float) -> void:
		node.position = home + Vector2(sin(t * TAU * 4.0) * strength * (1.0 - t), 0.0), 0.0, 1.0, dur)
	return _moving(node, tw, home, true)


## Бесконечная пульсация масштаба; у кнопок UiKit — их собственная (не спорит с нажатием).
## Повторный вызов заменяет прежнюю пульсацию, а не добавляет вторую.
static func pulse(node: Control, amount := 1.05, period := 1.2) -> Tween:
	if node.has_method(&"set_pulse"):
		node.call(&"set_pulse", true)
		return null
	_kill_meta(node, &"_ui_pulse")
	var tw := node.create_tween().set_loops()
	tw.tween_method(_scale_centered.bind(node), 1.0, amount, period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_scale_centered.bind(node), amount, 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
	node.set_meta(&"_ui_pulse", tw)
	return tw


## Остановить pulse() и вернуть масштаб 1.
static func stop_pulse(node: Control) -> void:
	if node.has_method(&"set_pulse"):
		node.call(&"set_pulse", false)
		return
	_kill_meta(node, &"_ui_pulse")
	_scale_centered(1.0, node)


# --- «дом» узла для сдвигов: новая анимация посреди старой не копит смещение ---

## Где узел стоит на самом деле: запомненный «дом», пока идёт сдвиг или узел
## уехал через slide_out (прошлый сдвиг останавливается), иначе текущая позиция.
static func _home(node: Control) -> Vector2:
	_kill_meta(node, &"_ui_move")
	return node.get_meta(&"_ui_home", node.position)


## Запомнить дом на время сдвига tw; at_home — сдвиг кончается дома (узел ставится
## точно на место, память стирается).
static func _moving(node: Control, tw: Tween, home: Vector2, at_home: bool) -> Tween:
	node.set_meta(&"_ui_home", home)
	node.set_meta(&"_ui_move", tw)
	tw.tween_callback(_settled.bind(node, at_home))
	return tw


static func _settled(node: Control, at_home: bool) -> void:
	if at_home:
		node.position = node.get_meta(&"_ui_home", node.position)
		node.remove_meta(&"_ui_home")
	node.remove_meta(&"_ui_move")


## Остановить твин, запомненный в метаданных узла под ключом key.
static func _kill_meta(node: Node, key: StringName) -> void:
	if node.has_meta(key):
		var tw: Tween = node.get_meta(key)
		tw.kill()
		node.remove_meta(key)


static func _scale_centered(s: float, node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(s, s)
