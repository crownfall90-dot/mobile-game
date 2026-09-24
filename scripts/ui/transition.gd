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
	var home := node.position
	var dist := node.size if node.size != Vector2.ZERO else node.get_combined_minimum_size()
	node.position = home + from * dist
	var tw := node.create_tween()
	tw.tween_property(node, ^"position", home, dur).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


static func slide_out(node: Control, to := Vector2(0, 1), dur := 0.22, and_free := false) -> Tween:
	var tw := node.create_tween()
	tw.tween_property(node, ^"position", node.position + to * node.size, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	if and_free:
		tw.tween_callback(node.queue_free)
	return tw


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


## Тряска «нельзя» (закрытый уровень, не хватает монет).
static func shake(node: Control, strength := 12.0, dur := 0.35) -> Tween:
	var home := node.position
	var tw := node.create_tween()
	tw.tween_method(func(t: float) -> void:
		node.position = home + Vector2(sin(t * TAU * 4.0) * strength * (1.0 - t), 0.0), 0.0, 1.0, dur)
	tw.tween_callback(func() -> void: node.position = home)
	return tw


## Бесконечная пульсация масштаба; у кнопок UiKit — их собственная (не спорит с нажатием).
static func pulse(node: Control, amount := 1.05, period := 1.2) -> Tween:
	if node.has_method(&"set_pulse"):
		node.call(&"set_pulse", true)
		return null
	var tw := node.create_tween().set_loops()
	tw.tween_method(_scale_centered.bind(node), 1.0, amount, period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_scale_centered.bind(node), amount, 1.0, period * 0.5).set_trans(Tween.TRANS_SINE)
	return tw


static func _scale_centered(s: float, node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(s, s)
