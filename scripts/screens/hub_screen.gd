extends Control
## Главный экран первого акта: открытая локация целиком на экране телефона.
## Сцена 720×1560 масштабируется равномерно (cover) — без растяжения по одной оси; лишнее по краям
## обрезается, поэтому всё нажимаемое стоит в safe-области act1.json. Нажатие на сломанную вещь
## открывает её головоломку. После последнего ремонта локации — радостная сцена и новая локация.

const REPAIR_LINES := {
	"room_window": "Дочка: «Больше не дует!»",
	"room_bed": "Мама: «Сегодня мы выспимся.»",
	"room_floor": "Дочка: «Теперь можно бегать!»",
	"room_wall": "Мама: «Как светло стало!»",
	"kitchen_sink": "Мама: «Ни капли мимо!»",
	"kitchen_stove": "Дочка: «Мама, сваришь кашу?»",
	"kitchen_fridge": "Мама: «Теперь продукты не испортятся.»",
	"kitchen_cabinets": "Дочка: «Всё на своих местах!»",
	"kitchen_ceiling": "Мама: «Больше не капает.»",
	"bath_tub": "Дочка: «Можно купаться с пеной!»",
	"bath_toilet": "Мама: «Вот и здесь стало удобно.»",
	"bath_sink": "Дочка: «Кран больше не плачет!»",
	"bath_tiles": "Мама: «Чисто и красиво.»",
	"bath_light": "Дочка: «Светло-светло!»",
	"living_sofa": "Дочка: «Почитаем сказку вместе?»",
	"living_tv": "Дочка: «Мультики снова работают!»",
	"living_lamp": "Мама: «Тёплый вечерний свет.»",
	"living_wall": "Дочка: «Как красиво вокруг!»",
	"living_floor": "Мама: «Наш дом наконец-то уютный.»",
}

var _loc_id := ""
var _view: LocationView
var _k := 1.0
var _offset := Vector2.ZERO
var _ui: Control
var _title: Label
var _settings: Button
var _shop: Button
var _prev: Button
var _next: Button
var _tip: Label
var _repair := ""
var _busy := false
var _time := 0.0


func open(args: Dictionary) -> void:
	_repair = str(args.get("repaired", ""))
	_loc_id = str(args.get("location", ""))
	if _repair != "":
		_loc_id = str(Home.task(_repair).get("loc", ""))
	if _loc_id == "" or not Home.is_unlocked(_loc_id):
		_loc_id = Home.current_location()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("203b42")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var holder := Node2D.new()
	add_child(holder)
	_view = LocationView.new()
	_view.setup(Home.location(_loc_id), _scene_size())
	holder.add_child(_view)
	if _repair != "":
		_view.hold_broken(_repair)
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if _repair != "":
		_play_repair.call_deferred()
	elif str(args.get("bought", "")) != "":
		_show_bought(str(args["bought"]))
	elif args.get("unlocked", false):
		Router.toast("Новая локация: " + str(Home.location(_loc_id).get("name", "")))


func _build_ui() -> void:
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	# Сверху только название локации слева и две кнопки справа.
	_title = UiKit.label(str(Home.location(_loc_id).get("name", "Vita")), 40, Color("fff0ce"))
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.75))
	_ui.add_child(_title)
	_settings = UiKit.icon_button(&"gear", "", &"glass")
	_settings.tooltip_text = "Настройки"
	_settings.pressed.connect(func() -> void: Router.popup(&"settings"))
	_ui.add_child(_settings)
	_shop = UiKit.icon_button(&"coin", str(Profile.coins()), &"glass")
	_shop.tooltip_text = "Магазин · %d монет" % Profile.coins()
	_shop.pressed.connect(func() -> void:
		var popup := Router.popup(&"shop")
		popup.closed.connect(func(result: Variant) -> void:
			if result is String and result != "":
				Router.go(&"hub", {"bought": result, "location": _loc_id})))
	_ui.add_child(_shop)
	# Переход между открытыми локациями.
	var locs := Home.locations()
	var i := _loc_index()
	if i > 0:
		_prev = _nav_button("‹ " + str(locs[i - 1]["name"]), str(locs[i - 1]["id"]))
	if i + 1 < Home.unlocked_count():
		_next = _nav_button(str(locs[i + 1]["name"]) + " ›", str(locs[i + 1]["id"]))
	# Первая подсказка: что делать, пока ничего не починено.
	if Home.completed() == 0:
		_tip = UiKit.label("Нажми на сломанную вещь, чтобы её починить", 26, Color("fff0ce"))
		_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tip.add_theme_constant_override("outline_size", 10)
		_tip.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05, 0.8))
		_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(_tip)


func _nav_button(text: String, loc_id: String) -> Button:
	var b := UiKit.button(text, &"secondary")
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(0, 64)
	b.pressed.connect(func() -> void:
		if not _busy:
			Router.go(&"hub", {"location": loc_id}))
	_ui.add_child(b)
	return b


func _gui_input(event: InputEvent) -> void:
	if _busy or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = (event.position - _offset) / _k
	var t := _view.target_at(p)
	if t.is_empty():
		return
	accept_event()
	if not Game.has_level(str(t["level"])):
		Router.toast("%s — головоломка скоро появится" % t["name"])
		return
	if not Router.is_busy():
		Sfx.play(&"ui_tap")
		Router.go(&"game", {"id": t["level"]})


func _play_repair() -> void:
	_busy = true
	await get_tree().create_timer(0.5).timeout
	_view.play_repair(_repair)
	Sfx.play(&"restore")
	Sfx.haptic(40)
	await _view.repair_finished
	Router.toast(REPAIR_LINES.get(_repair, "Дома стало немного уютнее"))
	_busy = false
	if Home.location_done(_loc_id):
		await get_tree().create_timer(1.2).timeout
		_celebrate()


## Локация готова: радостная сцена семьи и переход в следующую открывшуюся локацию.
func _celebrate() -> void:
	_busy = true
	var loc := Home.location(_loc_id)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.08, 0.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var text := UiKit.label(str(loc.get("done_text", "Готово!")), 38, Color("fff0ce"))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.position = Vector2(40, size.y * 0.12)
	text.size = Vector2(size.x - 80, 200)
	text.modulate.a = 0.0
	add_child(text)
	var fx := Fx.new()
	add_child(fx)
	var tw := create_tween()
	tw.tween_property(shade, "color:a", 0.45, 0.5)
	tw.parallel().tween_property(text, "modulate:a", 1.0, 0.5)
	for i in 4:
		tw.tween_callback(func() -> void:
			fx.burst(Vector2(size.x * (0.2 + 0.2 * i), size.y * 0.3), Color("ffe5a3"), 30, 320, 6, 400, 1.2))
		tw.tween_interval(0.35)
	Sfx.play(&"win")
	await get_tree().create_timer(3.2).timeout
	var locs := Home.locations()
	var i := _loc_index()
	if i + 1 < locs.size():
		Router.go(&"hub", {"location": str(locs[i + 1]["id"]), "unlocked": true})
	else:
		_busy = false
		shade.queue_free()


## Только что купленная вещь: вспышка и короткая реплика.
func _show_bought(id: String) -> void:
	var fx := Fx.new()
	add_child(fx)
	var at := Vector2(size.x * 0.5, size.y * 0.55)
	fx.burst(at, Color("ffe5a3"), 30, 260, 5, 300, 1.0)
	fx.ring(at, Color("ffe5a3"), 90.0, 0.5)
	Sfx.haptic(30)
	var lines := {
		"vita_plant": "Дочка: «Я буду его поливать!»",
		"vita_teddy": "Дочка: «Мишка, ты теперь наш!»",
		"vita_clothes": "Мама: «Какие мы нарядные!»",
		"vita_picture": "Мама: «Наши счастливые дни — на стене.»",
	}
	Router.toast(lines.get(id, "Новая вещь дома!"))


func _process(delta: float) -> void:
	_time += delta
	if _tip:
		_tip.modulate.a = 0.75 + 0.25 * sin(_time * 3.0)


func _layout() -> void:
	if _view == null:
		return
	var view := get_viewport_rect().size
	var scene := _scene_size()
	# cover: заполняем экран целиком одним масштабом, излишек поровну обрезаем. Но safe-область
	# со всеми целями видна всегда: на планшете, раскладушке или 21:9 масштаб меньше cover,
	# а за краем сцены тянется продолжение фона (LocationView рисует его сам).
	var safe := _safe_rect()
	_k = minf(maxf(view.x / scene.x, view.y / scene.y), minf(view.x / safe.size.x, view.y / safe.size.y))
	_offset = (view - scene * _k) * 0.5
	_view.get_parent().position = _offset
	_view.get_parent().scale = Vector2(_k, _k)
	var top := _safe_top(view)
	# кнопки и надписи — по меньшей стороне, чтобы на широком экране не раздувались
	var ui_k := minf(view.x / 720.0, view.y / 1280.0)
	_title.position = Vector2(22 * ui_k, top + 14 * ui_k)
	_title.scale = Vector2(ui_k, ui_k)
	_settings.scale = Vector2(ui_k, ui_k)
	_shop.scale = Vector2(ui_k, ui_k)
	_settings.position = Vector2(view.x - (22 + 88) * ui_k, top + 12 * ui_k)
	_shop.position = Vector2(view.x - (22 + 88 * 2 + 12) * ui_k, top + 12 * ui_k)
	var bottom := view.y - _safe_bottom(view) - 84 * ui_k
	for b in [_prev, _next]:
		if b:
			b.scale = Vector2(ui_k, ui_k)
			b.size = b.get_combined_minimum_size()
	if _prev:
		_prev.position = Vector2(16 * ui_k, bottom)
	if _next:
		_next.position = Vector2(view.x - (_next.size.x + 16) * ui_k, bottom)
	if _tip:
		_tip.scale = Vector2(ui_k, ui_k)
		_tip.size = Vector2(620, 80)
		_tip.position = Vector2(50 * ui_k, bottom - 100 * ui_k)


func _safe_top(view: Vector2) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	return maxf(0, safe.position.y) * view.y / maxf(1, window.y)


func _safe_bottom(view: Vector2) -> float:
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	if safe.size.y <= 0:
		return 0.0
	return maxf(0, window.y - safe.end.y) * view.y / maxf(1, window.y)


func _loc_index() -> int:
	var locs := Home.locations()
	for i in locs.size():
		if locs[i]["id"] == _loc_id:
			return i
	return 0


static func _safe_rect() -> Rect2:
	var v: Array = Home.data().get("scene", {}).get("safe", [0, 0, 720, 1560])
	return Rect2(v[0], v[1], v[2], v[3])


static func _scene_size() -> Vector2:
	var s: Array = Home.data().get("scene", {}).get("size", [720, 1560])
	return Vector2(s[0], s[1])
