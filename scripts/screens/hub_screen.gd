extends Control
## Главный экран первого акта: открытая локация целиком на экране телефона.
## Сцена 720×1560 масштабируется равномерно; safe-область act1.json вписывается между
## верхними кнопками и нижними переходами. Нажатие на сломанную вещь
## открывает её головоломку. После последнего ремонта локации — радостная сцена и новая локация.

const BUBBLE := preload("res://scripts/ui/speech_bubble.gd")   # не зависит от кэша class_name
const GLOOM := preload("res://scripts/art/gloom.gd")
const SIGN := preload("res://scripts/ui/sign_board.gd")
const ALBUM := preload("res://scripts/popups/album_popup.gd")
const IDLE_AFTER := 6.0      # столько секунд без нажатий — и Вита подсказывает, куда нажать
const IDLE_AGAIN := 14.0     # следующая подсказка — через столько

var _loc_id := ""
var _view: LocationView
var _k := 1.0
var _offset := Vector2.ZERO
var _ui: Control
var _title: Control           # табличка с названием главы
var _settings: Button
var _shop: Button
var _album: Button
var _prev: Button
var _next: Button
var _tip: Label
var _repair := ""
var _busy := false
var _time := 0.0
var _idle := 0.0
var _talking := false
var _leaving := false
var _delay: Timer
var _hand: TextureRect
var _bubbles := {}           # кто говорит -> SpeechBubble
var _gloom: Node2D           # Хмурь под потолком локации


func open(args: Dictionary) -> void:
	_delay = Timer.new()
	_delay.one_shot = true
	add_child(_delay)
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
	# Хмурь: чем больше несделанного в локации, тем она больше; после акта — облачко-друг
	var g: Dictionary = Home.location(_loc_id).get("gloom", {})
	var gp: Array = g.get("pos", [600, 320])
	_gloom = GLOOM.new()
	_gloom.setup(Vector2(gp[0], gp[1]), _gloom_share(_repair), _act_over())
	holder.add_child(_gloom)
	_build_ui()
	# заранее и понемногу — картинки следующей локации (переход туда будет без задержки)
	var locs := Home.locations()
	var i := _loc_index()
	if i + 1 < locs.size():
		Assets.want(Assets.location_paths(str(locs[i + 1]["id"])))
	get_viewport().size_changed.connect(_layout)
	_layout()
	# фон места: дождь с ветром, пока окно разбито; сквозняк в запущенной комнате
	Sfx.ambience(_view.ambience())
	# новая глава: табличка опускается сверху
	if args.get("unlocked", false) or not Profile.flag("seen." + _loc_id):
		_title.call(&"show_in")
	if _repair != "":
		_play_repair.call_deferred()
	elif str(args.get("bought", "")) != "":
		_show_bought(str(args["bought"]))
	else:
		_greet.call_deferred(args.get("unlocked", false))


func _exit_tree() -> void:
	_leaving = true
	if _delay:
		_delay.stop()
		_delay.timeout.emit()
	if _view:
		_view.repair_finished.emit("")
	for b in _bubbles.values():
		if is_instance_valid(b):
			b.emit_signal(&"finished")


func _build_ui() -> void:
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	# Сверху только название локации слева и две кнопки справа.
	# вместо «Маленькая комната» — табличка с названием главы по сюжету
	_title = SIGN.new()
	_title.call(&"setup", _loc_title(_loc_id), "глава %d" % (_loc_index() + 1))
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
	# альбом: кусочки фото прабабушки и повтор сценок; точка — есть сценка, которую ещё не смотрели
	_album = UiKit.icon_button(&"book", "", &"glass")
	_album.tooltip_text = "Альбом"
	if ALBUM.has_unseen():
		var dot := UiKit.red_dot()
		dot.position = Vector2(66, 2)
		_album.add_child(dot)
	_album.pressed.connect(func() -> void:
		var popup := Router.popup(&"album")
		popup.closed.connect(func(scene: Variant) -> void:
			if scene is String and scene != "":
				Router.go(&"novel", {"scene": scene, "next": {"screen": "hub", "args": {"location": _loc_id}}})))
	_ui.add_child(_album)
	# Переход между открытыми локациями.
	var locs := Home.locations()
	var i := _loc_index()
	if i > 0:
		_prev = _nav_button("‹ " + _loc_title(str(locs[i - 1]["id"])), str(locs[i - 1]["id"]))
	if i + 1 < Home.unlocked_count():
		_next = _nav_button(_loc_title(str(locs[i + 1]["id"])) + " ›", str(locs[i + 1]["id"]))
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


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_idle = 0.0
		_hide_hand()


func _gui_input(event: InputEvent) -> void:
	if _busy or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = (event.position - _offset) / _k
	var t := _view.target_at(p)
	if t.is_empty():
		# ремонт важнее: Хмурь отвечает, только если под пальцем нет сломанной вещи
		if _gloom and _gloom.hit(p):
			accept_event()
			_gloom_talk()
			return
		var done := _view.target_at(p, true)
		if not done.is_empty():
			accept_event()
			_offer_replay(done)
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
	_delay.start(0.5)
	await _delay.timeout
	if _leaving:
		return
	_view.play_repair(_repair)
	Sfx.play(&"restore")
	Sfx.haptic(40)
	await _view.repair_finished
	if _leaving:
		return
	_gloom.set_amount(_gloom_share(""))
	Sfx.ambience(_view.ambience())
	# радость: подпрыгнули, искры над головами, «Ура!» и реплика про починенную вещь
	_view.cheer()
	Sfx.play(&"win")
	var fx := Fx.new()
	add_child(fx)
	for who in ["daughter", "mother"]:
		fx.burst(_to_screen(_view.speaker_point(who)), Color("ffe5a3"), 16, 260, 5, 300, 0.9)
	await _say_lines(Home.task(_repair).get("cheer", []))
	if _leaving:
		return
	_busy = false
	if Home.location_done(_loc_id):
		# итог локации рассказывает сценка-новелла (data/novel.json, <локация>_done)
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
	_delay.start(2.4)
	await _delay.timeout
	if _leaving:
		return
	# сценка-новелла локации: находится кусочек фото прабабушки (он есть у каждой готовой
	# локации); потом — следующая локация
	# (после последней — финал акта внутри сценки и снова гостиная)
	var locs := Home.locations()
	var i := _loc_index()
	var next_loc := str(locs[i + 1]["id"]) if i + 1 < locs.size() else _loc_id
	Router.go(&"novel", {"scene": _loc_id + "_done",
		"next": {"screen": "hub", "args": {"location": next_loc, "unlocked": i + 1 < locs.size()}}})


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
	if _busy or _talking or Router.is_busy():
		_idle = 0.0
		return
	_idle += delta
	if _idle >= IDLE_AFTER:
		_idle = IDLE_AFTER - IDLE_AGAIN
		_idle_hint()


# --- реплики семьи -------------------------------------------------------------------

func _to_screen(p: Vector2) -> Vector2:
	return _offset + p * _k


## Реплика в облачке над головой: mother, daughter или gloom. Прежнее облачко того же героя уходит.
func _say(who: String, line: String, hold := 2.2) -> Node2D:
	if _bubbles.has(who) and is_instance_valid(_bubbles[who]):
		# прежнее облачко этого героя уходит; кто его ждал — не зависнет
		_bubbles[who].emit_signal(&"finished")
		_bubbles[who].queue_free()
	var b: Node2D = BUBBLE.new()
	add_child(b)
	var from_gloom := who == "gloom" and _gloom != null
	b.position = _to_screen(_gloom.speech_point() if from_gloom else _view.speaker_point(who))
	b.set(&"below", from_gloom)   # Хмурь под потолком: реплика ниже неё, не под панелью сверху
	var ui_k := minf(size.x / 720.0, size.y / 1280.0)
	b.call(&"show_line", line, hold, Vector2(16.0, size.x - 16.0), ui_k)
	_bubbles[who] = b
	return b


## Диалог по очереди: [[кто, текст], ...]; время на строку — по длине.
func _say_lines(lines: Array) -> void:
	_talking = true
	for l: Array in lines:
		var hold := clampf(0.9 + str(l[1]).length() * 0.045, 1.4, 3.2)
		var b := _say(str(l[0]), str(l[1]), hold)
		await Signal(b, &"finished")
		if _leaving:
			return
	_talking = false


## Доля несделанных ремонтов локации (только что починенная вещь ещё считается сломанной).
func _gloom_share(holding: String) -> float:
	var targets: Array = Home.location(_loc_id).get("targets", [])
	if targets.is_empty():
		return 0.0
	var left := 0
	for t: Dictionary in targets:
		if not Home.is_done(t["id"]) or t["id"] == holding:
			left += 1
	return float(left) / targets.size()


## Починенная вещь: показать звёзды и предложить сыграть ещё раз (новые звёзды — монеты).
func _offer_replay(t: Dictionary) -> void:
	if Router.is_busy() or not Game.has_level(str(t["level"])):
		return
	Sfx.play(&"ui_tap")
	var best := Profile.best_stars(str(t["level"]))
	var stars := "★".repeat(best) + "☆".repeat(3 - best)
	var text := "Уже на все звёзды — можно сыграть просто так." if best >= 3 \
		else "Ещё звезда — ещё монеты. Сыграть ещё раз?"
	var popup := Router.popup(&"confirm", {"title": "%s %s" % [str(t["name"]), stars], "text": text,
		"ok": "Играть", "cancel": "Позже"})
	if popup:
		popup.closed.connect(func(yes: Variant) -> void:
			if yes == true:
				Router.go(&"game", {"id": t["level"]}))


## Название главы локации для таблички и кнопок перехода (нет — название комнаты).
func _loc_title(loc_id: String) -> String:
	var loc := Home.location(loc_id)
	return str(loc.get("title", loc.get("name", "Vita")))


## Акт пройден и финальная сценка показана: Хмурь — белое облачко-друг.
func _act_over() -> bool:
	return Home.completed() >= Home.total() and Profile.flag("seen.novel.act1_end")


## Нажали на Хмурь: она вздыхает, семья отвечает; после акта — облачко-друг.
func _gloom_talk() -> void:
	if _talking:
		return
	_gloom.talk()
	Sfx.play(&"ui_tap")
	var lines: Array = Home.data().get("gloom_friend", []) if _act_over() \
		else Home.location(_loc_id).get("gloom", {}).get("lines", [])
	await _say_lines(lines)


## Вход в локацию: при первом визите — короткий диалог по сюжету.
func _greet(unlocked: bool) -> void:
	var flag := "seen." + _loc_id
	if Profile.flag(flag) and not unlocked:
		return
	Profile.set_flag(flag)
	_delay.start(0.6)
	await _delay.timeout
	if _leaving:
		return
	await _say_lines(Home.location(_loc_id).get("lines", {}).get("enter", []))


## Долго не нажимают: пальчик стучит по следующей сломанной вещи, Вита или мама подсказывает.
func _idle_hint() -> void:
	var target := {}
	for t: Dictionary in Home.location(_loc_id).get("targets", []):
		if not Home.is_done(t["id"]) and Game.has_level(str(t["level"])):
			target = t
			break
	if target.is_empty():
		return
	var lines: Array = Home.location(_loc_id).get("lines", {}).get("idle", [])
	if not lines.is_empty():
		var l: Array = lines[randi() % lines.size()]
		_say(str(l[0]), str(l[1]), 2.4)
	_show_hand(_to_screen(_view.target_rect(target["id"]).get_center()))


func _show_hand(at: Vector2) -> void:
	_hide_hand()
	_hand = TextureRect.new()
	_hand.texture = Icons.tex(&"hand", 112)
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand.size = Vector2(112, 112)
	_hand.pivot_offset = Vector2(20, 10)
	_hand.position = at + Vector2(-8, 6)
	add_child(_hand)
	var tw := _hand.create_tween().set_loops(4)
	tw.tween_property(_hand, "scale", Vector2(0.85, 0.85), 0.18)
	tw.tween_property(_hand, "scale", Vector2.ONE, 0.22)
	tw.tween_interval(0.3)
	var gone := _hand.create_tween()
	gone.tween_interval(2.9)
	gone.tween_property(_hand, "modulate:a", 0.0, 0.3)
	gone.tween_callback(_hide_hand)


func _hide_hand() -> void:
	if _hand and is_instance_valid(_hand):
		_hand.queue_free()
	_hand = null


func _layout() -> void:
	if _view == null:
		return
	var view := get_viewport_rect().size
	var scene := _scene_size()
	# Сначала оставляем место кнопкам: иначе потолочные цели попадают под них на 16:9.
	var safe := _safe_rect()
	var top := _safe_top(view)
	var ui_k := minf(view.x / 720.0, view.y / 1280.0)
	var available := Rect2(0, top + 112 * ui_k, view.x,
		view.y - top - _safe_bottom(view) - 204 * ui_k)
	_k = minf(maxf(view.x / scene.x, view.y / scene.y),
		minf(available.size.x / safe.size.x, available.size.y / safe.size.y))
	_offset = available.get_center() - safe.get_center() * _k
	_view.get_parent().position = _offset
	_view.get_parent().scale = Vector2(_k, _k)
	# кнопки и надписи — по меньшей стороне, чтобы на широком экране не раздувались
	_title.position = Vector2(18 * ui_k, top + 8 * ui_k)
	_title.scale = Vector2(ui_k, ui_k)
	_settings.scale = Vector2(ui_k, ui_k)
	_shop.scale = Vector2(ui_k, ui_k)
	_album.scale = Vector2(ui_k, ui_k)
	_settings.position = Vector2(view.x - (22 + 88) * ui_k, top + 12 * ui_k)
	_shop.position = Vector2(view.x - (22 + 88 * 2 + 12) * ui_k, top + 12 * ui_k)
	_album.position = Vector2(view.x - (22 + 88 * 3 + 24) * ui_k, top + 12 * ui_k)
	# длинное название локации не заезжает под кнопки: ужимается до свободного места
	var room_w := _album.position.x - _title.position.x - 10 * ui_k
	var title_w := _title.get_combined_minimum_size().x * ui_k
	if title_w > room_w:
		_title.scale = Vector2(ui_k, ui_k) * (room_w / title_w)
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
