extends Control
## Сюжет в стиле визуальной новеллы: фон (комната квартиры или ночная улица), большие фигуры
## семьи и Хмури, окно диалога с именем говорящего, текст печатается по буквам. Тап — допечатать
## строку или дальше; выбор ответа — кнопками; карточки письма и фото — поверх сцены.
## Сценарий: data/novel.json {"names": {...}, "scenes": {id: [шаг, ...]}}. Шаги:
##   {"bg": "<id локации>" | "night" | "story:<имя>", "tint": "dim"|"night"|"warm", "rain": bool,
##    "state": "broken"|"fixed"}   (state — комната как в тот момент, для повтора из альбома)
##   (не локация — картинка art/act1/story/<имя>.png; ночь без картинки рисует код)
##   {"show": ["family", "gloom"]}                 кто на сцене
##   {"say": "mother"|"daughter"|"gloom", "text": "…", "mood": "sad|calm|surprised|smile|happy"}
##   {"text": "…"}                                  слова рассказчика
##   {"choice": [{"text": "…", "then": [шаги]}, …]} ответ на выбор, потом сцена идёт дальше
##   {"cg": "letter", "text": "…"} | {"cg": "photo", "piece": 1..4} | {"hide": "cg"}
##   {"gloom": {"amount": 0..1, "friendly": bool}}
##   {"scene": "<id>"}                              продолжить другой сценой
## Открытие: Router.go(&"novel", {"scene": id, "next": {"screen": "hub", "args": {...}}}).
## Картинки художника подхватываются сами: art/act1/story/<имя>.png (фоны "story:", letter,
## photo_full), Хмурь — через gloom.gd. Пока их нет — рисует код.
## Для проверок: "auto" — всё листается само (выбор — первый), "step": N — начать с N-го шага.

signal _advance
signal _chosen(i: int)

const GLOOM := preload("res://scripts/art/gloom.gd")
const PHOTO := preload("res://scripts/ui/photo_card.gd")
const DATA := "res://data/novel.json"
const ART := "res://art/act1/"
const CPS := 40.0                 # букв в секунду
const MOODS := {"sad": 0, "calm": 1, "surprised": 1, "smile": 2, "happy": 3}
const NAME_COLORS := {"mother": Color("8e3b46"), "daughter": Color("3d6fb6"), "gloom": Color("6f7684")}
const PAPER := Color("fffaf0")
const INK := Color("4a3226")
const EDGE := Color("6b4a33")
const BOX_H := 270.0
const TINTS := {"dim": Color(0.04, 0.04, 0.1, 0.42), "night": Color(0.03, 0.06, 0.18, 0.55),
	"warm": Color(1.0, 0.78, 0.45, 0.1), "": Color(0, 0, 0, 0.16)}

var _data := {}
var _scene_id := "prologue"
var _next := {}
var _auto := false
var _start := 0
var _finished := false
var _skipping := false
var _typing := false
var _shown := 0.0
var _mood := 1                    # настроение пары мама+дочка 0..3 (картинки family_mood*)
var _on_stage := {}               # "family" / "gloom" -> true
var _u := 1.0                     # масштаб интерфейса: 720 px дизайна по меньшей стороне
var _h := 1280.0                  # высота экрана в единицах дизайна

var _bg_holder: Node2D
var _bg_node: Node2D
var _bg_key := ""
var _cold := false
var _family_x := 0.0
var _shade: ColorRect
var _rain: Node2D
var _ui: Control
var _cast: Node2D
var _family: Sprite2D
var _gloom: Node2D
var _box: Panel
var _plate: PanelContainer
var _name: Label
var _text: Label
var _more: Label
var _choices: VBoxContainer
var _card: Control
var _skip: Button
var _fade: ColorRect


func open(args: Dictionary) -> void:
	_scene_id = str(args.get("scene", "prologue"))
	_next = args.get("next", {}) if args.get("next", {}) is Dictionary else {}
	_auto = args.has("auto")
	_start = int(args.get("step", 0))
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_data = parsed if parsed is Dictionary else {}
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var base := ColorRect.new()
	base.color = Color("1b2238")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_bg_holder = Node2D.new()
	add_child(_bg_holder)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.color = TINTS[""]
	add_child(_shade)
	_rain = Rain.new()
	_rain.visible = false
	add_child(_rain)
	_build_ui()
	_fade = ColorRect.new()
	_fade.color = Color("120c24")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_play.call_deferred()


func _build_ui() -> void:
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_cast = Node2D.new()
	_ui.add_child(_cast)
	_family = Sprite2D.new()
	_family.centered = false
	_family.modulate.a = 0.0
	_cast.add_child(_family)
	# мишка из магазина — у Виты в руке (как на главном экране)
	if Profile.owns("vita_teddy") and ResourceLoader.exists(LocationView.TEDDY):
		var teddy := Sprite2D.new()
		teddy.name = "Teddy"
		teddy.centered = false
		teddy.texture = load(LocationView.TEDDY)
		_family.add_child(teddy)
	_gloom = GLOOM.new()
	# в сценке Хмурь всегда серая: белой она становится только шагом {"gloom": {"friendly": true}}
	_gloom.setup(Vector2(540, 380), _gloom_default(), false)
	_gloom.scale = Vector2(1.9, 1.9)
	_gloom.modulate.a = 0.0
	_cast.add_child(_gloom)
	# окно диалога: бумага с рамкой, табличка с именем на верхнем краю
	_box = Panel.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = EDGE
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	_box.add_theme_stylebox_override("panel", sb)
	_ui.add_child(_box)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.label_settings = UiKit.text_style(32, INK, 0, false)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_text)
	_more = UiKit.label("▼", 26, EDGE)
	_more.label_settings = UiKit.text_style(26, EDGE, 0, false)
	_more.visible = false
	_box.add_child(_more)
	_plate = PanelContainer.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_plate)
	_name = UiKit.label("", 30, Color.WHITE)
	_plate.add_child(_name)
	_plate.visible = false
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 18)
	_ui.add_child(_choices)
	_skip = UiKit.button("Пропустить", &"ghost")
	_skip.custom_minimum_size = Vector2(200, 72)
	_skip.add_theme_font_size_override("font_size", 24)
	_skip.pressed.connect(_skip_all)
	_ui.add_child(_skip)


func _layout() -> void:
	var view := get_viewport_rect().size
	_u = minf(view.x / 720.0, view.y / 1280.0)
	_h = view.y / _u
	var w := view.x / _u
	_ui.scale = Vector2(_u, _u)
	_ui.size = Vector2(w, _h)
	_rain.set(&"size", view)
	_fit_bg()
	var bottom := _safe_bottom(view) / _u
	var top := _safe_top(view) / _u
	_box.position = Vector2(16, _h - BOX_H - 24 - bottom)
	_box.size = Vector2(w - 32, BOX_H)
	_text.position = Vector2(30, 34)
	_text.size = Vector2(_box.size.x - 60, BOX_H - 60)
	_more.position = Vector2(_box.size.x - 52, BOX_H - 46)
	_plate.position = Vector2(_box.position.x + 30, _box.position.y - 30)
	_skip.size = _skip.get_combined_minimum_size()
	_skip.position = Vector2(w - _skip.size.x - 16, top + 16)
	_choices.size = Vector2(560, 0)
	_choices.position = Vector2((w - 560) * 0.5, _box.position.y - 40 - _choices.get_combined_minimum_size().y)
	# семья слева стоит «за» окном диалога, Хмурь — справа повыше
	var tex := _family.texture
	if tex:
		var fh := minf(_h * 0.54, 780.0)
		var k := fh / tex.get_height()
		_family.scale = Vector2(k, k)
		_family.position = Vector2(w * 0.36 - tex.get_width() * k * 0.5, _box.position.y + 90 - fh)
		_family_x = _family.position.x
		var teddy := _family.get_node_or_null(^"Teddy") as Sprite2D
		if teddy:
			# в пикселях картинки пары: доли LocationView.TEDDY_ON_PAIR
			var box := Rect2(LocationView.TEDDY_ON_PAIR.position * tex.get_size(), LocationView.TEDDY_ON_PAIR.size * tex.get_size())
			var tk := minf(box.size.x / teddy.texture.get_width(), box.size.y / teddy.texture.get_height())
			teddy.scale = Vector2(tk, tk)
			teddy.position = box.position + (box.size - teddy.texture.get_size() * tk) * 0.5
	_gloom.position = Vector2(w * 0.74, _box.position.y - _h * 0.42)
	if _card:
		_card.position = Vector2((w - _card.size.x) * 0.5, maxf(top + 110, _box.position.y - 60 - _card.size.y))


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


# --- ход сцены ---------------------------------------------------------------

func _play() -> void:
	var steps := _steps(_scene_id)
	# для снимков: начало с шага N — предыдущие шаги только расставляют сцену
	for i in mini(_start, steps.size()):
		_apply_quiet(steps[i])
	create_tween().tween_property(_fade, "color:a", 0.0, 0.35)
	await _run(steps.slice(mini(_start, steps.size())))
	_finish()


func _chain(id: String, acc: Array) -> Array:
	if id in acc:
		return acc
	acc.append(id)
	var walk := func(steps: Array, self_ref: Callable) -> void:
		for st: Dictionary in steps:
			if st.has("scene"):
				_chain(str(st["scene"]), acc)
			for c: Dictionary in st.get("choice", []):
				self_ref.call(c.get("then", []), self_ref)
	walk.call(_steps(id), walk)
	return acc


func _steps(id: String) -> Array:
	var s: Variant = _data.get("scenes", {}).get(id, [])
	return s if s is Array else []


func _run(steps: Array) -> void:
	for st: Dictionary in steps:
		if _skipping or not is_inside_tree():
			return
		await _step(st)


func _step(st: Dictionary) -> void:
	if st.has("bg"):
		await _set_bg(st)
	if st.has("show"):
		_show(st["show"])
	if st.has("gloom"):
		_set_gloom(st["gloom"])
	if st.has("hide"):
		_hide_card()
	if st.has("cg"):
		await _show_card(st)
	if st.has("choice"):
		await _choose(st["choice"])
	if st.has("text"):
		await _line(str(st.get("say", "")), str(st["text"]), str(st.get("mood", "")))
	if st.has("scene"):
		await _run(_steps(str(st["scene"])))


## Шаг до стартового (проверки с "step"): сцена расставляется без ожиданий и анимаций.
func _apply_quiet(st: Dictionary) -> void:
	if st.has("bg"):
		_make_bg(st)
	if st.has("show"):
		_show(st["show"], true)
	if st.has("gloom"):
		_set_gloom(st["gloom"])
	if st.has("mood") and str(st.get("say", "")) in ["mother", "daughter"]:
		_set_mood(str(st["mood"]))


func _line(who: String, text: String, mood: String) -> void:
	if who in ["mother", "daughter"] and mood != "":
		_set_mood(mood)
	_focus(who)
	_plate.visible = who != ""
	if who != "":
		_name.text = str(_data.get("names", {}).get(who, who))
		var sb := StyleBoxFlat.new()
		sb.bg_color = NAME_COLORS.get(who, EDGE)
		sb.set_corner_radius_all(18)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		_plate.add_theme_stylebox_override("panel", sb)
		_plate.size = _plate.get_combined_minimum_size()
	# рассказчик — курсивом не умеем, поэтому мягче цветом
	_text.label_settings = UiKit.text_style(32, INK if who != "" else Color("6b5a4c"), 0, false)
	_text.text = text
	_shown = 0.0
	_text.visible_characters = 0
	_more.visible = false
	_typing = true
	if who == "gloom":
		_gloom.call(&"talk")
	if _auto:
		_end_typing()
		await get_tree().process_frame
		return
	await _advance


func _end_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_more.visible = true


func _process(delta: float) -> void:
	if _cold and not Profile.owns("vita_clothes"):
		# дрожь приступами: холодно и страшно (в тёплых нарядах — нет)
		var ph := fmod(Time.get_ticks_msec() * 0.001, 4.0)
		_family.position.x = _family_x + (sin(Time.get_ticks_msec() * 0.058) * 2.6 * sin(PI * ph / 0.9) if ph < 0.9 else 0.0)
	if _typing:
		_shown += delta * CPS
		_text.visible_characters = int(_shown)
		if _shown >= _text.get_total_character_count():
			_end_typing()
	if _more.visible:
		_more.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.006)


func _gui_input(event: InputEvent) -> void:
	# мышь в проекте эмулирует касание (emulate_touch_from_mouse): слушаем только касания
	if not (event is InputEventScreenTouch and event.pressed) or _choices.get_child_count() > 0:
		return
	accept_event()
	if _typing:
		_end_typing()
	else:
		_advance.emit()


func on_back() -> bool:
	_skip_all()
	return true


func _skip_all() -> void:
	if _skipping:
		return
	_skipping = true
	_advance.emit()
	_chosen.emit(0)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	# просмотрена (или пропущена) сцена и все, что идут в ней продолжением: living_done → act1_end
	for id in _chain(_scene_id, []):
		Profile.set_flag("seen.novel." + id)
	if _scene_id == "prologue":
		Profile.set_flag("seen.prologue")
	Profile.flush()
	Router.go(StringName(str(_next.get("screen", "hub"))), _next.get("args", {}))


# --- фон ---------------------------------------------------------------------

func _set_bg(st: Dictionary) -> void:
	# сцена-продолжение с тем же фоном (living_done → act1_end) не мигает затемнением
	var key := "%s|%s" % [st["bg"], st.get("tint", "")]
	if key == _bg_key:
		return
	_bg_key = key
	if _auto or _bg_node == null:
		_make_bg(st)
		return
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.3)
	await tw.finished
	_make_bg(st)
	tw = create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	await tw.finished


func _make_bg(st: Dictionary) -> void:
	_bg_key = "%s|%s" % [st["bg"], st.get("tint", "")]
	if _bg_node:
		_bg_node.queue_free()
	var id := str(st["bg"])
	var loc := Home.location(id)
	var story := "%sstory/%s.png" % [ART, id.trim_prefix("story:")]
	if not loc.is_empty():
		# комната как на главном экране, только без семьи (она здесь — большими фигурами)
		var l := loc.duplicate(true)
		l.erase("family")
		l["props"] = l.get("props", []).filter(func(p: Dictionary) -> bool:
			return not str(p.get("img", "")).begins_with("family/"))
		var v := LocationView.new()
		v.show_targets = false
		v.setup(l, Vector2(720, 1560))
		# повтор из альбома: пролог — квартира сломана, сценка конца — починена, как тогда
		var state := str(st.get("state", ""))
		for t: Dictionary in l.get("targets", []):
			if state == "broken":
				v.hold_broken(str(t["id"]))
			elif state == "fixed":
				v._done[str(t["id"])] = true
		_bg_node = v
	elif ResourceLoader.exists(story):
		var s := Sprite2D.new()
		s.centered = false
		s.texture = load(story)
		_bg_node = s
	else:
		_bg_node = NightBg.new()
	_bg_holder.add_child(_bg_node)
	_shade.color = TINTS.get(str(st.get("tint", "")), TINTS[""])
	_rain.visible = bool(st.get("rain", false))
	# ночь под дождём и тёмная сырая комната: слышен дождь с ветром или сквозняк, семья дрожит
	_cold = _rain.visible or str(st.get("tint", "")) in ["dim", "night"]
	Sfx.ambience(&"storm" if _rain.visible else (&"wind" if _cold else &""))
	_fit_bg()


## Фон на весь экран одним масштабом (cover), излишек поровну обрезается.
func _fit_bg() -> void:
	if _bg_node == null:
		return
	var view := get_viewport_rect().size
	var src := Vector2(720, 1560)
	if _bg_node is Sprite2D and (_bg_node as Sprite2D).texture:
		src = (_bg_node as Sprite2D).texture.get_size()
	elif _bg_node is NightBg:
		_bg_node.set(&"size", view)
		_bg_holder.position = Vector2.ZERO
		_bg_holder.scale = Vector2.ONE
		return
	var k := maxf(view.x / src.x, view.y / src.y)
	_bg_holder.scale = Vector2(k, k)
	_bg_holder.position = (view - src * k) * 0.5


# --- герои -------------------------------------------------------------------

func _show(who: Array, quiet := false) -> void:
	var want := {}
	for w in who:
		want[str(w)] = true
	for key: String in ["family", "gloom"]:
		var node: CanvasItem = _family if key == "family" else _gloom
		var on := want.has(key)
		if on == _on_stage.has(key):
			continue
		if on:
			_on_stage[key] = true
		else:
			_on_stage.erase(key)
		if key == "family" and on:
			_set_mood_index(_mood)
		if quiet or _auto:
			node.modulate.a = 1.0 if on else 0.0
		else:
			create_tween().tween_property(node, "modulate:a", 1.0 if on else 0.0, 0.4)


func _set_mood(mood: String) -> void:
	_set_mood_index(int(MOODS.get(mood, _mood)))


## Пара мама+дочка — картинки family_mood0..3; если нужной нет, ближайшая.
func _set_mood_index(m: int) -> void:
	_mood = m
	for d: int in [0, -1, 1, -2, 2, -3, 3]:
		var path := "%sfamily/family_mood%d.png" % [ART, m + d]
		var alt := path.trim_suffix(".png") + "_teddy.png"
		if Profile.owns("vita_teddy") and ResourceLoader.exists(alt):
			# нарисована дочка с мишкой — мишку поверх прячем
			path = alt
		if m + d >= 0 and m + d <= 3 and ResourceLoader.exists(path):
			_family.texture = load(path)
			var teddy := _family.get_node_or_null(^"Teddy") as CanvasItem
			if teddy:
				teddy.visible = not path.ends_with("_teddy.png")
			break
	_layout()


## Говорящий ярче и подпрыгивает, остальные чуть в тени.
func _focus(who: String) -> void:
	var fam := who in ["mother", "daughter"]
	var dim := Color(0.62, 0.62, 0.7)
	_family.self_modulate = Color.WHITE if fam or who == "" else dim
	_gloom.self_modulate = Color.WHITE if who == "gloom" or who == "" else dim
	if fam and _on_stage.has("family") and not _auto:
		var y := _family.position.y
		var tw := create_tween()
		tw.tween_property(_family, "position:y", y - 14.0, 0.1).set_ease(Tween.EASE_OUT)
		tw.tween_property(_family, "position:y", y, 0.16).set_ease(Tween.EASE_IN)


func _gloom_default() -> float:
	return clampf(1.0 - float(Home.completed()) / maxf(1.0, Home.total()), 0.3, 1.0)


func _set_gloom(g: Dictionary) -> void:
	if g.has("amount"):
		_gloom.set(&"amount", float(g["amount"]))
	if bool(g.get("friendly", false)) and not bool(_gloom.get(&"friendly")):
		_gloom.call(&"befriend")
		if not _auto:
			var fx := Fx.new()
			_ui.add_child(fx)
			fx.burst(_gloom.position, Color("fff4c8"), 36, 320, 6, 200, 1.2)
			fx.ring(_gloom.position, Color("fff4c8"), 150.0, 0.6)
			Sfx.play(&"restore")


# --- выбор -------------------------------------------------------------------

func _choose(options: Array) -> void:
	if options.is_empty():
		return
	_focus("daughter")
	_text.label_settings = UiKit.text_style(32, Color("6b5a4c"), 0, false)
	_text.text = "Что ответит Вита?"
	_text.visible_characters = -1
	_typing = false
	_more.visible = false
	_plate.visible = false
	var pick := 0
	if not _auto:
		for i in options.size():
			var b := UiKit.button(str(options[i].get("text", "…")), &"secondary")
			b.custom_minimum_size = Vector2(560, 96)
			b.add_theme_font_size_override("font_size", 28)
			b.pressed.connect(func() -> void:
				Sfx.play(&"ui_tap")
				_chosen.emit(i))
			_choices.add_child(b)
			b.modulate.a = 0.0
			create_tween().tween_property(b, "modulate:a", 1.0, 0.25).set_delay(0.1 * i)
		_layout()
		pick = await _chosen
		for b in _choices.get_children():
			b.queue_free()
		await get_tree().process_frame
	if _skipping:
		return
	var then: Variant = options[clampi(pick, 0, options.size() - 1)].get("then", [])
	if then is Array:
		await _run(then)


# --- карточки: письмо и фото -------------------------------------------------

func _show_card(st: Dictionary) -> void:
	_hide_card()
	var kind := str(st["cg"])
	if kind == "photo":
		var p: Control = PHOTO.new()
		p.size = Vector2(540, 420)
		p.call(&"collect", int(st.get("piece", 0)) - 1)
		_card = p
		Sfx.play(&"restore")
	else:
		_card = _letter(str(st.get("text", "")))
	_ui.add_child(_card)
	_ui.move_child(_card, _box.get_index())
	_card.pivot_offset = _card.size * 0.5
	_layout()
	_focus("")
	_plate.visible = false
	_text.text = ""
	_more.visible = true
	if _auto:
		return
	_card.scale = Vector2(0.6, 0.6)
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fx := Fx.new()
	_ui.add_child(fx)
	fx.burst(_card.position + _card.size * 0.5, Color("ffe5a3"), 28, 300, 5, 250, 1.0)
	await _advance


func _hide_card() -> void:
	if _card == null:
		return
	var c := _card
	_card = null
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 0.0, 0.25)
	tw.tween_callback(c.queue_free)


func _letter(text: String) -> Control:
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size = Vector2(576, 440)
	var path := ART + "story/letter.png"
	if ResourceLoader.exists(path):
		var st := StyleBoxTexture.new()
		st.texture = load(path)
		card.add_theme_stylebox_override("panel", st)
	else:
		var flat := StyleBoxFlat.new()
		flat.bg_color = Color("f6e7c4")
		flat.border_color = Color("c9a878")
		flat.set_border_width_all(3)
		flat.set_corner_radius_all(6)
		flat.shadow_color = Color(0, 0, 0, 0.35)
		flat.shadow_size = 14
		flat.shadow_offset = Vector2(4, 8)
		card.add_theme_stylebox_override("panel", flat)
	# у Label в контейнере с переносом строк размер считается неверно: задаём его сами
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.label_settings = UiKit.text_style(32, Color("5a3a22"), 0, false)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(48, 40)
	l.size = card.size - Vector2(96, 80)
	card.add_child(l)
	card.rotation = -0.03
	return card


## Ночная улица под дождём: старый дом, одно окно светится. Пока нет картинки story/*.png.
class NightBg extends Node2D:
	var size := Vector2(720, 1280):
		set(v):
			size = v
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([Color("141a2e"), Color("141a2e"), Color("35405c"), Color("35405c")]))
		draw_circle(Vector2(w * 0.8, h * 0.1), 46.0, Color(0.9, 0.92, 1.0, 0.25))
		# дом
		var house := Rect2(w * 0.12, h * 0.2, w * 0.76, h * 0.6)
		draw_colored_polygon(PackedVector2Array([Vector2(house.position.x - 20, house.position.y),
			Vector2(house.get_center().x, house.position.y - h * 0.09),
			Vector2(house.end.x + 20, house.position.y)]), Color("1f1b29"))
		draw_rect(house, Color("2a2636"))
		for row in 4:
			for col in 3:
				var wr := Rect2(house.position + Vector2(40 + col * (house.size.x - 80) / 3.0 + 18, 40 + row * house.size.y / 4.6),
					Vector2((house.size.x - 80) / 3.0 - 36, house.size.y / 7.0))
				var lit := row == 2 and col == 1
				if lit:
					draw_circle(wr.get_center(), wr.size.x * 0.9, Color(1.0, 0.8, 0.45, 0.18))
				draw_rect(wr, Color("ffcf7a") if lit else Color("3b3a4d"))
				draw_line(Vector2(wr.get_center().x, wr.position.y), Vector2(wr.get_center().x, wr.end.y), Color("2a2636"), 3.0)
		var door := Rect2(house.get_center().x - 50, house.end.y - 150, 100, 150)
		draw_rect(door, Color("4a3426"))
		draw_rect(Rect2(0, house.end.y, w, h - house.end.y), Color("232a3c"))
		for i in 3:
			draw_circle(Vector2(w * (0.2 + i * 0.3), house.end.y + 70 + i * 40), 40.0, Color(0.6, 0.7, 0.9, 0.12))


class Rain extends Node2D:
	var size := Vector2(720, 1280)
	var _t := 0.0

	func _process(delta: float) -> void:
		if visible:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		for i in 70:
			var x := fmod(i * 97.3, size.x + 100.0) - 50.0
			var y := fmod(i * 53.1 + _t * 900.0, size.y + 60.0) - 30.0
			draw_line(Vector2(x, y), Vector2(x - 8.0, y + 28.0), Color(0.75, 0.82, 1.0, 0.35), 2.0)
