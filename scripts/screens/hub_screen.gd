extends Control
## Главный экран первого акта: открытая локация целиком на экране телефона.
## Сцена 720×1560 масштабируется равномерно; safe-область act1.json вписывается между
## верхними кнопками и нижними переходами. Нажатие на сломанную вещь
## открывает её головоломку. После последнего ремонта локации — радостная сцена и новая локация.

const BUBBLE := preload("res://scripts/ui/speech_bubble.gd")   # не зависит от кэша class_name
const SIGN := preload("res://scripts/ui/sign_board.gd")
const ALBUM := preload("res://scripts/popups/album_popup.gd")
const ACTIVITIES := preload("res://scripts/core/activities.gd")
const MARK := preload("res://scripts/ui/hub_mark.gd")
const IDLE_AFTER := 6.0      # столько секунд без нажатий — и Вита подсказывает, куда нажать
const IDLE_AGAIN := 14.0     # следующая подсказка — через столько

var _loc_id := ""
var _view: LocationView
var _k := 1.0
var _offset := Vector2.ZERO
var _ui: Control
var _marks: Control
var _acts: Button
var _title: Control           # табличка с названием главы
var _settings: Button
var _shop: Button
var _album: Button
var _prev: Button
var _next: Button
var _tip: Label
var _repair := ""
var _busy := false
var _energy: Button
var _arrange := false             # режим «Расстановка»
var _arrange_btn: Button
var _arrange_bar: Control        # «Готово» и «Сбросить» в режиме расстановки
var _arrange_layer: Control      # рамки вещей и подсветка перетаскиваемой
var _drag_key := ""
var _drag_grab := Vector2.ZERO
var _drag_from := Rect2()
var _drag_ok := true
var _drag_moved := false          # палец сдвинулся: иначе это нажатие — отразить вещь
var _drag_start := Vector2.ZERO
var _energy_tick := 0.0
var _time := 0.0
var _idle := 0.0
var _talking := false
var _leaving := false
var _delay: Timer
var _hand: TextureRect
var _bubbles := {}           # кто говорит -> SpeechBubble


func open(args: Dictionary) -> void:
	Reports.note_feedback("Hub open begin")
	_delay = Timer.new()
	_delay.one_shot = true
	add_child(_delay)
	_repair = str(args.get("repaired", ""))
	_loc_id = str(args.get("location", ""))
	if _repair != "":
		_loc_id = str(Home.task(_repair).get("loc", ""))
	if _loc_id == "" or not Home.is_unlocked(_loc_id):
		_loc_id = Home.current_location()
	Rearrange.apply(Home.location(_loc_id))
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
	Reports.note_feedback("LocationView setup complete " + _loc_id)
	if _repair != "":
		_view.hold_broken(_repair)
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
	if str(args.get("arrange", "")) in ["1", "true"]:
		get_tree().create_timer(1.2).timeout.connect(_set_arrange.bind(true))


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
	# круглые кнопки у вещей — под верхними кнопками и переходами
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_marks)
	_view.show_targets = false
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
	# «Занятия»: список всего, чем можно заняться в комнате, — и мелкие или закрытые вещи доступны
	_acts = UiKit.icon_button(&"play", "", &"glass")
	_acts.tooltip_text = "Занятия"
	_acts.pressed.connect(_offer_list)
	_ui.add_child(_acts)
	# энергия: сколько осталось и когда вернётся; нажатие — подробности
	_energy = UiKit.button("", &"secondary")
	_energy.custom_minimum_size = Vector2(300, 84)
	_energy.pressed.connect(func() -> void:
		if not Router.is_busy():
			Router.popup(&"energy", {"level": ""}))
	_ui.add_child(_energy)
	_refresh_energy()
	_build_arrange()
	# Переход между открытыми локациями.
	var locs := Home.locations()
	var i := _loc_index()
	if i > 0:
		_prev = _nav_button("‹ " + _loc_short(str(locs[i - 1]["id"])), str(locs[i - 1]["id"]))
	if i + 1 < Home.unlocked_count():
		_next = _nav_button(_loc_short(str(locs[i + 1]["id"])) + " ›", str(locs[i + 1]["id"]))
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
	if _arrange:
		_arrange_input(event)
		return
	if _busy or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = (event.position - _offset) / _k
	var t := _view.target_at(p)
	if t.is_empty():
		# мама с дочкой, починенная вещь или предмет в комнате: бытовые сценки (и повтор ремонта)
		var fam := ACTIVITIES.prop_key(_loc_id, "family")
		if _view.family_at(p) and not ACTIVITIES.available(fam).is_empty():
			accept_event()
			_offer_actions(fam, "", "")
			return
		var done := _view.target_at(p, true)
		if not done.is_empty():
			accept_event()
			_offer_actions(str(done["id"]), str(done["name"]), str(done["level"]))
			return
		var prop := _view.prop_at(p)
		if not prop.is_empty():
			var key := ACTIVITIES.prop_key(_loc_id, str(prop["img"]))
			if not ACTIVITIES.available(key).is_empty():
				accept_event()
				_offer_actions(key, "", "")
		return
	accept_event()
	_open_repair(t)


## Сломанная вещь: в головоломку ремонта.
func _open_repair(t: Dictionary) -> void:
	if not Game.has_level(str(t["level"])):
		Router.toast("%s — головоломка скоро появится" % t["name"])
		return
	if not Router.is_busy():
		Sfx.play(&"ui_tap")
		_start_level(str(t["level"]))


## В уровень, если хватает энергии; иначе окно энергии (после рекламы — сразу в уровень).
func _start_level(level: String) -> void:
	if Energy.can_play(level):
		Router.go(&"game", {"id": level})
		return
	var popup := Router.popup(&"energy", {"level": level})
	if popup:
		popup.closed.connect(func(result: Variant) -> void:
			if result == &"refilled" and not _leaving:
				Router.go(&"game", {"id": level}))


## Круглые кнопки у всего, что можно нажать: сломанное (ремонт), занятия у вещей, предметов и
## семьи, замок — занятие откроется позже. Кнопки не наезжают друг на друга и на края.
func _rebuild_marks() -> void:
	if _marks == null:
		return
	for c in _marks.get_children():
		c.queue_free()
	var view := get_viewport_rect().size
	var ui_k := minf(view.x / 720.0, view.y / 1280.0)
	var area := Rect2(0, _safe_top(view) + 116 * ui_k, view.x,
		view.y - _safe_top(view) - _safe_bottom(view) - 210 * ui_k).grow(-34 * ui_k)
	var placed: Array[Vector2] = []
	for m: Dictionary in _mark_list():
		var p := _free_spot(_to_screen(m["at"]), placed, area, 62.0 * ui_k)
		placed.append(p)
		var b: Control = MARK.new(str(m["kind"]))
		_marks.add_child(b)
		b.scale = Vector2(ui_k, ui_k)
		b.position = p - b.size * 0.5
		b.tapped.connect(m["do"])


func _mark_list() -> Array:
	var out := []
	var later := []
	var loc := Home.location(_loc_id)
	for t: Dictionary in loc.get("targets", []):
		var id := str(t["id"])
		var level := str(t.get("level", ""))
		var at := _view.target_rect(id).get_center()
		if not Home.is_done(id):
			out.append({"kind": "repair", "at": at, "do": _open_repair.bind(t)})
		elif not ACTIVITIES.available(id).is_empty() or Game.has_level(level):
			later.append({"kind": "act", "at": at, "do": _offer_actions.bind(id, str(t["name"]), level)})
	for pr: Dictionary in loc.get("props", []):
		var img := str(pr.get("img", ""))
		var key := ACTIVITIES.prop_key(_loc_id, img)
		if img.begins_with("family/") or not ACTIVITIES.has_animation(key):
			continue
		var v: Array = pr["rect"]
		later.append(_act_mark(key, Rect2(v[0], v[1], v[2], v[3]).get_center()))
	var fam := ACTIVITIES.prop_key(_loc_id, "family")
	if ACTIVITIES.has_animation(fam) and _view.family_mark() != Vector2.ZERO:
		later.append(_act_mark(fam, _view.family_mark()))
	out.append_array(later)
	return out


## Список «Занятия»: починенные вещи, предметы и семья, у которых сейчас есть занятие.
func _offer_list() -> void:
	if _busy or Router.is_busy():
		return
	var items := []
	for t: Dictionary in Home.location(_loc_id).get("targets", []):
		var id := str(t["id"])
		if Home.is_done(id) and not ACTIVITIES.available(id).is_empty():
			items.append([id, str(t["name"]), str(t.get("level", ""))])
	for pr: Dictionary in Home.location(_loc_id).get("props", []):
		var key := ACTIVITIES.prop_key(_loc_id, str(pr.get("img", "")))
		if not str(pr.get("img", "")).begins_with("family/") and not ACTIVITIES.available(key).is_empty():
			items.append([key, ACTIVITIES.title(key), ""])
	var fam := ACTIVITIES.prop_key(_loc_id, "family")
	if not ACTIVITIES.available(fam).is_empty():
		items.append([fam, ACTIVITIES.title(fam), ""])
	if items.is_empty():
		Router.toast("Почини что-нибудь — и появятся занятия")
		return
	var acts := []
	for i in items.size():
		acts.append([i, items[i][1]])
	Sfx.play(&"ui_tap")
	var popup := Router.popup(&"activity", {"title": "Занятия", "acts": acts})
	if popup:
		popup.closed.connect(func(choice: Variant) -> void:
			if choice is int:
				var it: Array = items[choice]
				_offer_actions.call_deferred(it[0], it[1], it[2]))


func _act_mark(key: String, at: Vector2) -> Dictionary:
	if ACTIVITIES.available(key).is_empty():
		return {"kind": "lock", "at": at, "do": func() -> void: Router.toast(ACTIVITIES.locked_reason(key))}
	return {"kind": "act", "at": at, "do": _offer_actions.bind(key, "", "")}


## Ближайшее к p место, где кнопка не наезжает на уже поставленные (не ближе gap) и не выходит
## за area: пробуем сдвиги вокруг, иначе остаёмся на месте.
static func _free_spot(p: Vector2, placed: Array[Vector2], area: Rect2, gap: float) -> Vector2:
	var tries: Array[Vector2] = [Vector2.ZERO]
	for ring in [1.0, 1.7]:
		for a in 8:
			tries.append(Vector2.from_angle(PI * 0.5 + TAU * a / 8.0) * gap * ring)
	for d: Vector2 in tries:
		var q := (p + d).clamp(area.position, area.end)
		var ok := true
		for o: Vector2 in placed:
			ok = ok and o.distance_to(q) >= gap
		if ok:
			return q
	return p.clamp(area.position, area.end)


func _play_repair() -> void:
	_busy = true
	Reports.note_feedback("repair flow begin " + _repair)
	# пока вещь чинится — без кнопок поверх анимации
	_marks.visible = false
	_delay.start(0.5)
	await _delay.timeout
	if _leaving:
		return
	_view.play_repair(_repair)
	Reports.note_feedback("repair broken layer hidden " + _repair)
	Sfx.play(&"restore")
	Sfx.haptic(40)
	await _view.repair_finished
	if _leaving:
		return
	Sfx.ambience(_view.ambience())
	Reports.note_feedback("repair tween complete " + _repair)
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
	_marks.visible = true
	_rebuild_marks()
	if Home.location_done(_loc_id):
		# итог локации рассказывает сценка-новелла (data/novel.json, <локация>_done)
		_celebrate()


## Локация готова: радостная сцена семьи и переход в следующую открывшуюся локацию.
func _celebrate() -> void:
	_busy = true
	Reports.note_feedback("celebrate begin " + _loc_id)
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
	_energy_tick += delta
	if _arrange:
		_arrange_layer.queue_redraw()
	if _energy_tick >= 1.0:
		_energy_tick = 0.0
		_refresh_energy()
	if _tip:
		_tip.modulate.a = 1.0 if UiKit.low_fx() else 0.75 + 0.25 * sin(_time * 3.0)
	if _busy or _talking or _arrange or Router.is_busy():
		_idle = 0.0
		return
	_idle += delta
	if _idle >= IDLE_AFTER:
		_idle = IDLE_AFTER - IDLE_AGAIN
		_idle_hint()


# --- реплики семьи -------------------------------------------------------------------

func _to_screen(p: Vector2) -> Vector2:
	return _offset + p * _k


## Реплика в облачке над головой: mother или daughter. Прежнее облачко того же героя уходит.
func _say(who: String, line: String, hold := 2.2) -> Node2D:
	if _bubbles.has(who) and is_instance_valid(_bubbles[who]):
		# прежнее облачко этого героя уходит; кто его ждал — не зависнет
		_bubbles[who].emit_signal(&"finished")
		_bubbles[who].queue_free()
	var b: Node2D = BUBBLE.new()
	add_child(b)
	b.position = _to_screen(_view.speaker_point(who))
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


## Починенная вещь: показать звёзды и предложить сыграть ещё раз (новые звёзды — монеты).
func _offer_actions(key: String, item_name: String, level: String) -> void:
	if _busy or Router.is_busy():
		return
	if level != "" and not Game.has_level(level):
		level = ""
	var acts := ACTIVITIES.available(key)
	if acts.is_empty() and level == "":
		return
	Sfx.play(&"ui_tap")
	var popup := Router.popup(&"activity", {"title": ACTIVITIES.title(key, item_name), "acts": acts,
		"level": level, "best": Profile.best_stars(level) if level != "" else 0})
	if popup:
		popup.closed.connect(func(choice: Variant) -> void:
			if choice is String and choice == "replay":
				_start_level(level)
			elif choice is int:
				var clip := ACTIVITIES.animation(key, choice)
				if not clip.is_empty():
					_play_activity.call_deferred(key, clip)
				# Архивные scene в каталоге не используются как замена анимации.
			)


func _play_activity(key: String, clip: Dictionary) -> void:
	if _busy or _leaving:
		return
	Reports.note_feedback("Занятие начато: %s (%s)" % [key, str(clip.get("kind", ""))])
	_busy = true
	_marks.hide()
	if _hand:
		_hand.hide()
	for bubble in _bubbles.values():
		if is_instance_valid(bubble):
			bubble.queue_free()
	await _view.play_activity(key, clip)
	if _leaving:
		return
	Reports.note_feedback("Занятие завершено: " + key)
	_busy = false
	_idle = 0.0
	_rebuild_marks()
	_marks.show()


## Короткое название комнаты для переходов внизу: «Кухня», «Санузел».
func _loc_short(loc_id: String) -> String:
	var loc := Home.location(loc_id)
	return str(loc.get("short", loc.get("name", "")))


## Название главы локации для таблички (нет — название комнаты).
func _loc_title(loc_id: String) -> String:
	var loc := Home.location(loc_id)
	return str(loc.get("title", loc.get("name", "Vita")))


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
	_acts.scale = Vector2(ui_k, ui_k)
	_settings.position = Vector2(view.x - (22 + 88) * ui_k, top + 12 * ui_k)
	_shop.position = Vector2(view.x - (22 + 88 * 2 + 12) * ui_k, top + 12 * ui_k)
	_album.position = Vector2(view.x - (22 + 88 * 3 + 24) * ui_k, top + 12 * ui_k)
	_acts.position = Vector2(view.x - (22 + 88 * 4 + 36) * ui_k, top + 12 * ui_k)
	# длинное название локации не заезжает под кнопки: ужимается до свободного места
	var room_w := _acts.position.x - _title.position.x - 10 * ui_k
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
	if _arrange_btn:
		_arrange_btn.scale = Vector2(ui_k, ui_k)
		_arrange_btn.size = _arrange_btn.get_combined_minimum_size()
		_arrange_btn.position = Vector2(18 * ui_k, top + 92 * ui_k)
	if _arrange_bar:
		_arrange_bar.scale = Vector2(ui_k, ui_k)
		_arrange_bar.size = _arrange_bar.get_combined_minimum_size()
		_arrange_bar.position = Vector2((view.x - _arrange_bar.size.x * ui_k) * 0.5, bottom - 40 * ui_k)
	if _energy:
		_energy.scale = Vector2(ui_k, ui_k)
		_energy.size = _energy.get_combined_minimum_size()
		_energy.position = Vector2((view.x - _energy.size.x * ui_k) * 0.5, bottom)
	_rebuild_marks()


# --- расстановка -------------------------------------------------------------

class ArrangeLayer extends Control:
	var hub: Node

	func _draw() -> void:
		hub.call(&"_draw_arrange", self)


func _build_arrange() -> void:
	_arrange_btn = UiKit.button("Расставить", &"glass")
	_arrange_btn.add_theme_font_size_override("font_size", 24)
	_arrange_btn.custom_minimum_size = Vector2(190, 64)
	_arrange_btn.pressed.connect(func() -> void: _set_arrange(true))
	_ui.add_child(_arrange_btn)
	_arrange_layer = ArrangeLayer.new()
	_arrange_layer.set(&"hub", self)
	_arrange_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrange_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_arrange_layer.visible = false
	add_child(_arrange_layer)
	_arrange_bar = HBoxContainer.new()
	_arrange_bar.add_theme_constant_override("separation", 14)
	var done := UiKit.button("Готово", &"primary")
	done.pressed.connect(func() -> void: _set_arrange(false))
	_arrange_bar.add_child(done)
	var reset := UiKit.button("Сбросить", &"secondary")
	reset.pressed.connect(_reset_arrange)
	_arrange_bar.add_child(reset)
	_arrange_bar.visible = false
	_ui.add_child(_arrange_bar)


func _set_arrange(on: bool) -> void:
	if _busy or _leaving or Router.is_busy() or on == _arrange:
		return
	_arrange = on
	_drag_key = ""
	Sfx.play(&"ui_tap")
	_marks.visible = not on
	_arrange_layer.visible = on
	_arrange_bar.visible = on
	for c: Control in [_arrange_btn, _energy, _prev, _next, _acts, _shop, _album, _settings, _tip]:
		if c:
			c.visible = not on
	if on:
		_hide_hand()
		Router.toast("Перетащи вещь; нажми — повернётся другим боком")
	else:
		Profile.flush()
		_rebuild_marks()


func _reset_arrange() -> void:
	if _drag_key != "":
		return
	Rearrange.reset(Home.location(_loc_id))
	Sfx.play(&"ui_tap")
	_arrange_layer.queue_redraw()


func _arrange_input(event: InputEvent) -> void:
	var loc := Home.location(_loc_id)
	if event is InputEventScreenTouch:
		var p: Vector2 = (event.position - _offset) / _k
		if event.pressed:
			var key := Rearrange.hit(loc, p)
			if key == "":
				return
			accept_event()
			_drag_key = key
			_drag_from = Rearrange.rect_of(Rearrange.raw_item(loc, key))
			_drag_grab = p - Rearrange.foot_of(_drag_from)
			_drag_ok = true
			_drag_moved = false
			_drag_start = event.position
			Sfx.haptic(12)
		elif _drag_key != "":
			accept_event()
			_finish_drag(loc)
	elif event is InputEventScreenDrag and _drag_key != "":
		accept_event()
		if not _drag_moved and event.position.distance_to(_drag_start) < 14.0:
			return
		_drag_moved = true
		var p: Vector2 = (event.position - _offset) / _k
		var it := Rearrange.raw_item(loc, _drag_key)
		var foot := Rearrange.clamp_foot(_loc_id, _drag_key, it, p - _drag_grab)
		var r := Rearrange.rect_at(_loc_id, _drag_key, it, foot)
		Rearrange.place(it, r, bool(it.get("flip", false)))
		_drag_ok = Rearrange.fits(loc, _drag_key, r)


func _finish_drag(loc: Dictionary) -> void:
	var key := _drag_key
	_drag_key = ""
	var it := Rearrange.raw_item(loc, key)
	if not _drag_moved:
		# нажатие без перетаскивания — повернуть вещь другим боком (отражение)
		Rearrange.place(it, _drag_from, not bool(it.get("flip", false)))
		Rearrange.save(loc, key)
		Sfx.play(&"ui_tap")
		return
	if Rearrange.fits(loc, key, Rearrange.rect_of(it)):
		Rearrange.save(loc, key)
		Sfx.play(&"ui_tap")
		Sfx.haptic(20)
	else:
		Rearrange.place(it, _drag_from, bool(it.get("flip", false)))
		Router.toast("Здесь не поставить")


func _draw_arrange(layer: Control) -> void:
	var loc := Home.location(_loc_id)
	var ui_k := minf(layer.size.x / 720.0, layer.size.y / 1280.0)
	for key in Rearrange.movable(loc):
		var r := Rearrange.rect_of(Rearrange.raw_item(loc, key))
		var sr := Rect2(r.position * _k + _offset, r.size * _k)
		var color := Color(1, 1, 1, 0.55)
		var width := 2.0 * ui_k
		if key == _drag_key:
			color = Color("5fd26a") if _drag_ok else Color("e8574a")
			width = 5.0 * ui_k
		layer.draw_rect(sr, color, false, width)


func _refresh_energy() -> void:
	if _energy == null:
		return
	var next := Energy.seconds_to_next()
	_energy.text = "Энергия %d/%d" % [Energy.current(), Energy.MAX] + ("" if next == 0 else "  " + Energy.format_wait(next))


func _safe_top(_view: Vector2) -> float:
	return UiKit.safe_insets(get_viewport()).x


func _safe_bottom(_view: Vector2) -> float:
	return UiKit.safe_insets(get_viewport()).y


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


func feedback_context() -> Dictionary:
	var actions := []
	if _view:
		for child in _view.get_children():
			if child.get_script() == preload("res://scripts/art/activity_player.gd"):
				actions.append({"phase": child.phase, "item": _view.activity_prop})
	return {"where": str(Home.location(_loc_id).get("name", _loc_id)), "location": _loc_id,
		"repair": _repair, "busy": _busy, "talking": _talking, "completed_repairs": Home.completed(),
		"actions": actions}
