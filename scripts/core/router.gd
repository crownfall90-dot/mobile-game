extends Node
## Автозагрузка "Router": стек экранов с затемнением, попапы, тосты,
## системная кнопка «назад» и сворачивание приложения.
##
## Экран — любой Node с open(args: Dictionary); по желанию on_back() -> bool
## (true — обработано), on_app_pause() и on_resume() (экран снова сверху после back()).
## Попап (UiPopup) — Control с сигналом closed(result), open(args) и on_back().

signal screen_changed(name: StringName)

const SCREENS := {
	&"novel": "res://scripts/screens/novel_screen.gd",
	&"loading": "res://scripts/screens/loading_screen.gd",
	&"hub": "res://scripts/screens/hub_screen.gd",
	&"game": "res://scripts/screens/game_screen.gd",
}
const POPUPS := {
	&"shop": "res://scripts/popups/shop_popup.gd",
	&"pause": "res://scripts/popups/pause_popup.gd",
	&"settings": "res://scripts/popups/settings_popup.gd",
	&"album": "res://scripts/popups/album_popup.gd",
	&"howto": "res://scripts/popups/howto_popup.gd",
	&"confirm": "res://scripts/popups/confirm_popup.gd",
}
const POPUP_DIR := "res://scripts/popups/"
const DEV_RUNNER := "res://scripts/dev/dev_runner.gd"

const FADE_TIME := 0.25
const FADE_COLOR := Color("120c24")
const POPUP_LAYER := 50
const TOAST_LAYER := 90
const FADE_LAYER := 100

## false: не передавать сворачивание экрану (dev-запуски, там пауза мешает).
var forward_app_pause := true

var _screens: Node
var _stack: Array[Node] = []
var _names: Array[StringName] = []
var _popups: CanvasLayer
var _fade: ColorRect
var _toasts: Toasts
var _busy := false
var _queued: Array = []
var _app_paused := false
var _exit_popup: Node


func _ready() -> void:
	# сам Router, попапы и тосты работают и на паузе; экраны — нет
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screens = Node.new()
	_screens.name = "Screens"
	_screens.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_screens)

	_popups = CanvasLayer.new()
	_popups.name = "Popups"
	_popups.layer = POPUP_LAYER
	add_child(_popups)

	_toasts = Toasts.new()
	_toasts.layer = TOAST_LAYER
	add_child(_toasts)

	var fade_layer := CanvasLayer.new()
	fade_layer.name = "Fade"
	fade_layer.layer = FADE_LAYER
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = FADE_COLOR
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade)
	_set_fade(0.0)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_request()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_on_app_pause()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_app_paused = false
		NOTIFICATION_EXIT_TREE:
			# экраны, снятые со сцены через push(), иначе утекут при выходе
			for s in _stack:
				if is_instance_valid(s) and not s.is_inside_tree():
					s.free()


func _unhandled_input(event: InputEvent) -> void:
	# Esc на компьютере работает как «назад» на телефоне
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_on_back_request()


# --- запуск ------------------------------------------------------------------

## С dev-флагами отдаёт управление DevRunner, иначе открывает загрузку.
func boot() -> void:
	var game := get_node_or_null(^"/root/Game")
	var dev: Dictionary = {}
	if game and game.get(&"dev") is Dictionary:
		dev = game.get(&"dev")
	if not dev.is_empty():
		forward_app_pause = false
		if _exists(DEV_RUNNER):
			var runner: Node = (load(DEV_RUNNER) as Script).new()
			runner.name = "DevRunner"
			get_tree().root.add_child(runner)
			runner.call(&"run", dev)
			return
		push_warning("Router: dev flags given, but %s is missing" % DEV_RUNNER)
	go(&"loading")


# --- экраны ------------------------------------------------------------------

## Заменить весь стек экраном screen.
func go(screen: StringName, args := {}) -> void:
	_change(&"go", screen, args)


## Открыть screen поверх текущего; back() вернёт прежний.
## Экрана ещё нет — тост «Скоро», текущий экран остаётся.
func push(screen: StringName, args := {}) -> void:
	if not _exists(SCREENS.get(screen, "")):
		push_warning("Router: screen '%s' is not available yet" % screen)
		toast(Loc.t("common.soon"))
		return
	_change(&"push", screen, args)


## Вернуться к предыдущему экрану; с последнего — в лабораторию, из лаборатории — «Выйти?».
func back() -> void:
	if _stack.size() > 1:
		_change(&"back", &"", {})
	elif current() != &"hub" and _exists(SCREENS[&"hub"]):
		go(&"hub")
	else:
		_ask_exit()


func current() -> StringName:
	return _names.back() if not _names.is_empty() else &""


func current_screen() -> Node:
	return _stack.back() if not _stack.is_empty() else null


func is_busy() -> bool:
	return _busy


# --- попапы и тосты -----------------------------------------------------------

## Открывает попап на слое 50. null, если его скрипта ещё нет.
func popup(popup_name: StringName, args := {}) -> Node:
	var path := _popup_path(popup_name)
	if path == "":
		push_warning("Router: popup '%s' is not available yet" % popup_name)
		return null
	var script := load(path) as Script
	if script == null or not script.can_instantiate():
		push_error("Router: cannot load popup %s" % path)
		return null
	var node: Node = script.new()
	node.name = String(popup_name).to_pascal_case() + "Popup"
	_popups.add_child(node)
	if node.has_method(&"open"):
		node.call(&"open", args)
	return node


## Верхний открытый попап или null.
func top_popup() -> Node:
	for i in range(_popups.get_child_count() - 1, -1, -1):
		var p := _popups.get_child(i)
		if not p.is_queued_for_deletion():
			return p
	return null


## Короткое сообщение-«пилюля» сверху на 2 с; несколько встают в очередь.
func toast(text: String, icon: StringName = &"") -> void:
	_toasts.show_toast(text, icon)


## Выйти из игры, сохранив прогресс.
func quit() -> void:
	Profile.flush()
	get_tree().quit()


# --- внутреннее ---------------------------------------------------------------

func _change(mode: StringName, screen: StringName, args: Dictionary) -> void:
	if _busy:
		_queued = [mode, screen, args]
		return
	_busy = true
	# попапы старого экрана закрываются вместе с ним; открытые после вызова остаются
	var old_popups := _popups.get_children()
	if _stack.is_empty():
		_set_fade(1.0)
	else:
		await _fade_to(1.0)
	for p in old_popups:
		if is_instance_valid(p):
			p.queue_free()
	get_tree().paused = false
	await _swap(mode, screen, args)
	await _fade_to(0.0)
	_busy = false
	if not _queued.is_empty():
		var q := _queued
		_queued = []
		_change(q[0], q[1], q[2])


func _swap(mode: StringName, screen: StringName, args: Dictionary) -> void:
	if mode == &"back":
		if _stack.size() < 2:
			return
		var top: Node = _stack.pop_back()
		_names.pop_back()
		_drop(top)
		var prev: Node = _stack.back()
		_screens.add_child(prev)
		if prev.has_method(&"on_resume"):
			prev.call(&"on_resume")
		screen_changed.emit(current())
		return
	var path: String = SCREENS.get(screen, "")
	if not _exists(path):
		# go() на экран, которого ещё нет (загрузка, хаб): запускаемся во что-то играбельное
		push_warning("Router: screen '%s' is not available yet, opening the game" % screen)
		screen = &"game"
		args = {"id": Profile.current_level_id()}
		path = SCREENS[&"game"]
	var script := load(path) as Script if _exists(path) else null
	if script == null or not script.can_instantiate():
		push_error("Router: cannot load screen %s" % path)
		return
	if mode == &"push" and not _stack.is_empty():
		_screens.remove_child(_stack.back())
	else:
		for s in _stack:
			_drop(s)
		_stack.clear()
		_names.clear()
		# старый экран освобождается до создания нового: на слабых телефонах два экрана
		# с большими картинками в памяти одновременно могут уронить игру
		await get_tree().process_frame
	var node: Node = script.new()
	node.name = String(screen).to_pascal_case() + "Screen"
	_screens.add_child(node)
	_stack.append(node)
	_names.append(screen)
	if node.has_method(&"open"):
		node.call(&"open", args)
	screen_changed.emit(screen)


## Старый экран уходит из дерева сразу: две камеры и два уровня не живут вместе ни кадра.
func _drop(s: Node) -> void:
	if s.is_inside_tree():
		_screens.remove_child(s)
	s.queue_free()


func _fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_fade, _fade.color.a, a, FADE_TIME * 0.5)
	await tw.finished


func _set_fade(a: float) -> void:
	_fade.color.a = a
	_fade.visible = a > 0.0
	# пока идёт переход, нажатия не проходят к экрану
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP if a > 0.0 else Control.MOUSE_FILTER_IGNORE


func _on_back_request() -> void:
	if _busy:
		return
	var p := top_popup()
	if p:
		if p.has_method(&"on_back"):
			p.call(&"on_back")
		elif p.has_method(&"close"):
			p.call(&"close")
		else:
			p.queue_free()
		return
	var s := current_screen()
	if s and s.has_method(&"on_back") and s.call(&"on_back") == true:
		return
	back()


func _ask_exit() -> void:
	if is_instance_valid(_exit_popup):
		return
	_exit_popup = popup(&"confirm", {
		"title": Loc.t("app.exit_title"), "text": Loc.t("app.exit_text"),
		"ok": Loc.t("common.yes"), "cancel": Loc.t("common.no"),
	})
	if _exit_popup == null:
		quit()
		return
	_exit_popup.connect(&"closed", func(result: Variant) -> void:
		if result == true:
			quit())


func _on_app_pause() -> void:
	if _app_paused or not forward_app_pause:
		return
	_app_paused = true
	var s := current_screen()
	if s and s.has_method(&"on_app_pause"):
		s.call(&"on_app_pause")


func _popup_path(popup_name: StringName) -> String:
	var path: String = POPUPS.get(popup_name, "")
	if _exists(path):
		return path
	# запасные имена: &"intro" -> intro_card.gd, &"story" -> story_card.gd
	for suffix in ["_popup", "_card", ""]:
		path = POPUP_DIR + String(popup_name) + suffix + ".gd"
		if _exists(path):
			return path
	return ""


func _exists(path: String) -> bool:
	return path != "" and ResourceLoader.exists(path)


## Очередь тостов: по одному, сверху по центру.
class Toasts extends CanvasLayer:
	const HOLD := 2.0
	const HOLD_BUSY := 1.3
	const MAX_W := 600.0
	## Под верхней панелью экрана (88 px кнопки + отступ), чтобы не закрывать счётчики.
	const TOP := 124.0
	const FONT_SIZE := 30
	const ICONS := "res://scripts/ui/icons.gd"

	var _queue: Array = []
	var _showing := false
	var _icons: Script
	var _icons_checked := false

	func _init() -> void:
		name = "Toasts"

	func show_toast(text: String, icon: StringName) -> void:
		_queue.append([text, icon])
		if not _showing:
			_next()

	func _next() -> void:
		if _queue.is_empty():
			_showing = false
			return
		_showing = true
		var item: Array = _queue.pop_front()
		var pill := _make(item[0], item[1])
		add_child(pill)
		var top := _safe_top() + TOP
		pill.position.y = top - 24.0
		pill.modulate.a = 0.0
		var tw := pill.create_tween()
		tw.set_parallel()
		tw.tween_property(pill, "modulate:a", 1.0, 0.18)
		tw.tween_property(pill, "position:y", top, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_interval(HOLD_BUSY if _queue.size() > 0 else HOLD)
		tw.chain().tween_property(pill, "modulate:a", 0.0, 0.2)
		tw.parallel().tween_property(pill, "position:y", top - 16.0, 0.2)
		tw.chain().tween_callback(func() -> void:
			pill.queue_free()
			_next())

	func _make(text: String, icon: StringName) -> Control:
		var pill := PanelContainer.new()
		pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill.set_anchors_preset(Control.PRESET_CENTER_TOP)
		pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.165, 0.13, 0.28, 0.95)
		sb.border_color = Color("9d8fd0")
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(40)
		sb.content_margin_left = 30
		sb.content_margin_right = 30
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		sb.shadow_color = Color(0, 0, 0, 0.4)
		sb.shadow_size = 14
		sb.shadow_offset = Vector2(0, 6)
		pill.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 14)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		pill.add_child(row)
		var tex := _icon(icon)
		if tex:
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(44, 44)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tr)
		var label := Label.new()
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var ls := LabelSettings.new()
		ls.font_size = FONT_SIZE
		ls.font_color = Color.WHITE
		ls.outline_size = 6
		ls.outline_color = Color("1b1236")
		label.label_settings = ls
		# длинный текст переносится, короткий — пилюля по размеру текста
		var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		if w > MAX_W:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = MAX_W
		row.add_child(label)
		return pill

	func _icon(icon: StringName) -> Texture2D:
		if icon == &"":
			return null
		if not _icons_checked:
			_icons_checked = true
			if ResourceLoader.exists(ICONS):
				var s := load(ICONS) as Script
				if s:
					for m in s.get_script_method_list():
						if m.get("name") == "tex":
							_icons = s
							break
		if _icons == null:
			return null
		return _icons.call(&"tex", icon, 44) as Texture2D

	func _safe_top() -> float:
		var vs := get_viewport().get_visible_rect().size
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		if win.y <= 0:
			return 0.0
		return maxf(0.0, safe.position.y) * vs.y / win.y
