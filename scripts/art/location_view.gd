class_name LocationView
extends Node2D
## Сцена локации первого акта из отдельных слоёв (data/act1.json, docs/ART_BRIEF.md):
##   фон art/act1/<loc>/background.png — пустая архитектура;
##   цель <id>_broken.png / <id>_fixed.png в своём rect (без растяжения: вписывается по центру);
##   overlay-цель (дыра, порванные обои) — только слой повреждения поверх целой поверхности фона;
##   семья art/act1/family/family_mood<0..3>.png, ступни в family.pos, высота family.height;
##   props — отдельные слои сценки: {img: "family/mother_kitchen", rect, z} (мама у плиты,
##   дочка на стуле, стол). Если у локации нет "family", пара вместе не рисуется;
##   эффекты (дождь, ветер, капли, лужа, темнота) — код; исчезают вместе с ремонтом причины.
## Нет картинки — рисуется служебная рамка с подписью, чтобы логику можно было проверять.
## Всё в поле сцены 720×1560; hub масштабирует его равномерно (cover) и сдвигает.
## Порядок слоёв: фон, цели и props z 0–1, декор, семья, цели и props z ≥ 2 (по возрастанию z),
## эффекты и подсветка.

signal repair_finished(id: String)

const ART := "res://art/act1/"
const OLD_FAMILY := ["res://art/home/family_worn.png", "res://art/home/family_worn.png",
	"res://art/home/family_happy.png", "res://art/home/family_happy.png"]
const CLOTHED := "res://art/home/family_clothed.png"
const PLACE_BROKEN := Color(0.85, 0.35, 0.3)
const PLACE_FIXED := Color(0.3, 0.7, 0.4)
const GLOW := Color("ffe7a1")
const EXTEND_PAD := 1200.0
const WEAR_SHADER := preload("res://shaders/wear.gdshader")
const WEAR_SPEED := 0.5           # за сколько секунд комната светлеет после ремонта (~2 с)

var loc: Dictionary = {}
var size := Vector2(720, 1560)
var show_targets := true          # мягкая пульсация вокруг несделанных целей

var _bg: Texture2D
var _tex := {}                    # "<id>_broken" / "<id>_fixed" -> Texture2D или null
var _done := {}                   # id -> true
var _anim := {}                   # id -> 0..1, идёт анимация ремонта
var _family: Sprite2D
var _t := 0.0
var _font: Font
var _canvas: CanvasItem = self   # куда рисуют _layer/_fit/_draw_fx: фон или передний план
var _front: Node2D
var _bg_sprite: Sprite2D         # фон под износом (шейдер wear): светлеет с каждым ремонтом
var _wear := -1.0                # текущий общий износ; -1 — ещё не выставлен
var _spot := {}                  # id цели -> сила грязного пятна вокруг неё, 0..1
var _cracks := {}                # id цели -> ломаные трещин (считаются один раз)
var _flip := false               # слой с "flip": true рисуется отражённым (кровать к другой стене)
var _hop := {}                   # img отдельного слоя -> подскок (радость), px


class Front extends Node2D:
	var view: LocationView

	func _draw() -> void:
		view.paint_front(self)


func setup(location: Dictionary, scene_size: Vector2) -> void:
	loc = location
	size = scene_size
	_font = ThemeDB.fallback_font
	_bg = _load("background")
	if _bg:
		_setup_wear()
	for t in loc.get("targets", []):
		_tex[t["id"] + "_broken"] = _load(t["id"] + "_broken")
		_tex[t["id"] + "_fixed"] = _load(t["id"] + "_fixed")
		_done[t["id"]] = Home.is_done(t["id"])
	for pr: Dictionary in loc.get("props", []):
		_tex["prop_" + str(pr["img"])] = _load_path("%s%s.png" % [ART, pr["img"]])
	# картинки декора — заранее, не во время рисования
	for d: Dictionary in loc.get("decor", []):
		_tex["decor_" + str(d["id"])] = _load(str(d["id"]))
		HomeArt.preload_decor(str(d["id"]))
	_family = Sprite2D.new()
	_family.centered = false
	add_child(_family)
	_front = Front.new()
	_front.view = self
	add_child(_front)
	_update_family()


## Цель показывается сломанной, пока не сыграна анимация ремонта (после возврата из уровня).
func hold_broken(id: String) -> void:
	_done[id] = false
	queue_redraw()


## Ремонт: сломанное дрожит и гаснет (дыра сжимается), целое появляется с «пружинкой», искры;
## эффекты причины (дождь, капли, лужа, темнота) гаснут вместе с ним.
func play_repair(id: String) -> void:
	var t := _target(id)
	if t.is_empty():
		return
	_anim[id] = 0.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _anim[id] = v, 0.0, 1.0, 1.1)
	tw.tween_callback(func() -> void:
		_anim.erase(id)
		_done[id] = true
		_update_family()
		repair_finished.emit(id))
	var fx := Fx.new()
	add_child(fx)
	var r := _rect(t)
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		fx.burst(r.get_center(), GLOW, 26, 240, 5, 260, 0.9)
		fx.ring(r.get_center(), GLOW, maxf(r.size.x, r.size.y) * 0.6, 0.45))


## Несделанная цель под точкой поля сцены (верхняя по z); {} — ничего.
func target_at(p: Vector2) -> Dictionary:
	var best := {}
	for t: Dictionary in loc.get("targets", []):
		if _done.get(t["id"], false) or _anim.has(t["id"]):
			continue
		var hit := _rect(t).grow(12).has_point(p)
		for extra: Array in t.get("more", []):
			hit = hit or Rect2(extra[0], extra[1], extra[2], extra[3]).grow(12).has_point(p)
		if hit and (best.is_empty() or int(t.get("z", 0)) >= int(best.get("z", 0))):
			best = t
	return best


func target_rect(id: String) -> Rect2:
	return _rect(_target(id))


func _process(delta: float) -> void:
	_t += delta
	_update_wear(delta)
	queue_redraw()
	_front.queue_redraw()


## Фон — отдельный спрайт позади всего с шейдером износа: выцветший, в пятнах сырости,
## вокруг каждой сломанной вещи грязнее. Пятна шума — маленькая текстура.
func _setup_wear() -> void:
	_bg_sprite = Sprite2D.new()
	_bg_sprite.centered = false
	_bg_sprite.texture = _bg
	var k := minf(size.x / _bg.get_width(), size.y / _bg.get_height())
	_bg_sprite.scale = Vector2(k, k)
	_bg_sprite.position = (size - _bg.get_size() * k) * 0.5
	_bg_sprite.show_behind_parent = true
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var mat := ShaderMaterial.new()
	mat.shader = WEAR_SHADER
	mat.set_shader_parameter("stains", tex)
	mat.set_shader_parameter("aspect", Vector2(1.0, size.y / size.x))
	_bg_sprite.material = mat
	add_child(_bg_sprite)


## Общий износ = доля несделанных целей локации; пятна у целей гаснут после их ремонта.
func _update_wear(delta: float) -> void:
	if _bg_sprite == null:
		return
	var targets: Array = loc.get("targets", [])
	if targets.is_empty():
		return
	var left := 0
	for t: Dictionary in targets:
		if not _done.get(t["id"], false):
			left += 1
	var goal := float(left) / targets.size()
	var first := _wear < 0.0
	_wear = goal if first else move_toward(_wear, goal, delta * WEAR_SPEED)
	var spots: Array[Vector4] = []
	for t: Dictionary in targets.slice(0, 8):
		var id: String = t["id"]
		var want := 0.0 if _done.get(id, false) else 1.0
		_spot[id] = want if first else move_toward(float(_spot.get(id, want)), want, delta * WEAR_SPEED)
		var r := _rect(t)
		spots.append(Vector4(r.get_center().x / size.x, r.get_center().y / size.y,
			maxf(r.size.x, r.size.y) / size.x * 0.9, _spot[id]))
	var mat := _bg_sprite.material as ShaderMaterial
	mat.set_shader_parameter("wear", _wear)
	mat.set_shader_parameter("spots", spots)
	mat.set_shader_parameter("spot_count", spots.size())


func _draw() -> void:
	_canvas = self
	if _bg:
		_extend(_bg)
	else:
		_placeholder_bg()
	for t in _layers():
		if int(t.get("z", 0)) < 2:
			_draw_layer(t)
	for t: Dictionary in loc.get("targets", []):
		if not _done.get(t["id"], false):
			_draw_fx(t, 1.0 - float(_anim.get(t["id"], 0.0)), true)
	# купленный декор: свой PNG в локации или общий рисунок магазина
	for d: Dictionary in loc.get("decor", []):
		if Profile.owns(d["id"]):
			var v: Array = d["rect"]
			var r := Rect2(v[0], v[1], v[2], v[3])
			var tex: Texture2D = _tex.get("decor_" + str(d["id"]))
			if tex:
				_fit(tex, r)
			else:
				HomeArt.draw_decor(self, d["id"], r)


## Передний план поверх семьи: предметы z ≥ 2, эффекты причин и подсветка целей.
func paint_front(ci: Node2D) -> void:
	_canvas = ci
	for t: Dictionary in _layers():
		if int(t.get("z", 0)) >= 2:
			_draw_layer(t)
	var list := _sorted()
	for t: Dictionary in list:
		if not _done.get(t["id"], false):
			_draw_fx(t, 1.0 - float(_anim.get(t["id"], 0.0)))
	if show_targets:
		for t: Dictionary in list:
			if not _done.get(t["id"], false) and not _anim.has(t["id"]):
				var a := 0.35 + 0.35 * sin(_t * 3.0 + _rect(t).position.x * 0.01)
				if _tex.get(t["id"] + "_broken"):
					# у нарисованной вещи — мягкое кольцо с искрой: «нажми меня», без рамки поверх картинки
					var c := _rect(t).get_center()
					var pulse := 1.0 + 0.15 * sin(_t * 3.0 + c.x * 0.01)
					ci.draw_arc(c, 34.0 * pulse, 0.0, TAU, 32, Color(GLOW, a + 0.2), 5.0, true)
					ci.draw_circle(c, 9.0, Color(GLOW, a + 0.3))
				else:
					ci.draw_rect(_rect(t).grow(6), Color(GLOW, a), false, 4.0)
	_canvas = self


func _sorted() -> Array:
	var list: Array = loc.get("targets", []).duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("z", 0)) < int(b.get("z", 0)))
	return list


## Цели и отдельные слои сценки вместе, по возрастанию z; при равном z цель раньше.
func _layers() -> Array:
	var list: Array = []
	for t: Dictionary in loc.get("targets", []):
		list.append(t)
	for pr: Dictionary in loc.get("props", []):
		list.append(pr)
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var za := int(a.get("z", 0))
		var zb := int(b.get("z", 0))
		return za < zb or (za == zb and a.has("id") and not b.has("id")))
	return list


func _draw_layer(t: Dictionary) -> void:
	_flip = bool(t.get("flip", false))
	if t.has("id"):
		_draw_target(t)
		_flip = false
		return
	var tex: Texture2D = _tex.get("prop_" + str(t["img"]))
	var r := _rect(t)
	r.position.y -= float(_hop.get(str(t["img"]), 0.0))
	if tex:
		_fit(tex, r)
	else:
		_canvas.draw_rect(r, Color(0.3, 0.4, 0.8, 0.5), false, 3.0)
	_flip = false


func _draw_target(t: Dictionary) -> void:
	for extra: Array in t.get("more", []):
		_draw_target_at(t, Rect2(extra[0], extra[1], extra[2], extra[3]))
	_draw_target_at(t, _rect(t))


func _draw_target_at(t: Dictionary, r: Rect2) -> void:
	var id: String = t["id"]
	var done: bool = _done.get(id, false)
	var k: float = _anim.get(id, -1.0)
	var broken: Texture2D = _tex.get(id + "_broken")
	var fixed: Texture2D = _tex.get(id + "_fixed")
	var overlay: bool = t.get("overlay", false)
	if k >= 0.0:
		# 0..0.55 — сломанное дрожит и гаснет (дыра сжимается к центру); с 0.4 проявляется целое
		var shake := sin(k * 60.0) * 4.0 * (1.0 - k)
		var close := clampf(1.0 - k / 0.55, 0.0, 1.0)
		if close > 0.0:
			var rb := r
			if overlay:
				rb = Rect2(r.get_center() - r.size * close * 0.5, r.size * close)
			_layer(broken, rb, id, false, Color(1, 1, 1, close), Vector2(shake, 0))
		var show := clampf((k - 0.4) / 0.6, 0.0, 1.0)
		if show > 0.0 and (fixed or not overlay):
			var pop := 1.0 + 0.08 * sin(show * PI)
			_layer(fixed, Rect2(r.get_center() - r.size * pop * 0.5, r.size * pop), id, true, Color(1, 1, 1, show), Vector2.ZERO)
		return
	if done:
		if fixed or not overlay:
			_layer(fixed, r, id, true, Color.WHITE, Vector2.ZERO)
	else:
		_layer(broken, r, id, false, Color.WHITE, Vector2.ZERO)


func _layer(tex: Texture2D, r: Rect2, id: String, fixed: bool, mod: Color, shift: Vector2) -> void:
	if tex:
		_fit(tex, Rect2(r.position + shift, r.size), mod)
		return
	# служебная рамка вместо картинки: видно, где будет слой и в каком он состоянии
	var c := PLACE_FIXED if fixed else PLACE_BROKEN
	_canvas.draw_rect(Rect2(r.position + shift, r.size), Color(c, 0.18 * mod.a))
	_canvas.draw_rect(Rect2(r.position + shift, r.size), Color(c, mod.a), false, 3.0)
	var label := "%s\n%s" % [str(_target(id).get("name", id)), "починено" if fixed else "сломано"]
	_canvas.draw_multiline_string(_font, r.position + shift + Vector2(8, 26), label, HORIZONTAL_ALIGNMENT_LEFT,
		r.size.x - 16, 20, 2, Color(0.15, 0.1, 0.1, mod.a))


## За краями сцены (широкий или очень высокий экран) — крайние ряды фона, чуть темнее,
## и мягкая тень у края: без пустых полос и без растяжения самой сцены.
func _extend(tex: Texture2D) -> void:
	var ts := tex.get_size()
	var pad := EXTEND_PAD
	# края того же оттенка, что и изношенный фон
	var dim := Color(0.82, 0.8, 0.84).lerp(Color(0.6, 0.55, 0.5), clampf(_wear, 0.0, 1.0) * 0.7)
	draw_texture_rect_region(tex, Rect2(-pad, 0, pad, size.y), Rect2(0, 0, 2, ts.y), dim)
	draw_texture_rect_region(tex, Rect2(size.x, 0, pad, size.y), Rect2(ts.x - 2, 0, 2, ts.y), dim)
	draw_texture_rect_region(tex, Rect2(0, -pad, size.x, pad), Rect2(0, 0, ts.x, 2), dim)
	draw_texture_rect_region(tex, Rect2(0, size.y, size.x, pad), Rect2(0, ts.y - 2, ts.x, 2), dim)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var dst := Rect2(Vector2(-pad if corner.x == 0.0 else size.x, -pad if corner.y == 0.0 else size.y), Vector2(pad, pad))
		draw_texture_rect_region(tex, dst, Rect2((ts - Vector2(2, 2)) * corner, Vector2(2, 2)), dim)
	for i in 6:
		var w := 6.0 * (i + 1)
		var c := Color(0, 0, 0, 0.05)
		draw_rect(Rect2(-w, 0, w, size.y), c)
		draw_rect(Rect2(size.x, 0, w, size.y), c)
		draw_rect(Rect2(0, -w, size.x, w), c)
		draw_rect(Rect2(0, size.y, size.x, w), c)


## Рисует картинку в прямоугольник без растяжения по одной оси: вписывает и центрирует.
func _fit(tex: Texture2D, r: Rect2, mod := Color.WHITE) -> void:
	var ts := tex.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	var s := ts * k
	var dst := Rect2(r.position + (r.size - s) * 0.5, s)
	if _flip:
		# отражение масштабом вокруг середины (отрицательный прямоугольник Godot рисует со сдвигом)
		_canvas.draw_set_transform(Vector2(dst.get_center().x * 2.0, 0.0), 0.0, Vector2(-1, 1))
		_canvas.draw_texture_rect(tex, dst, false, mod)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	_canvas.draw_texture_rect(tex, dst, false, mod)


func _placeholder_bg() -> void:
	var floor_y := size.y * 0.66
	_canvas.draw_rect(Rect2(0, 0, size.x, floor_y), Color("d9c9ad"))
	_canvas.draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color("a88364"))
	_canvas.draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), Color("6b5140"), 4)
	_canvas.draw_string(_font, Vector2(30, floor_y - 20), "фон: %s (нет art/act1/%s/background.png)" % [loc.get("name", ""), loc.get("id", "")],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.3, 0.25, 0.2))


## Эффекты причины: исчезают вместе с ремонтом (k — сила, 1 → 0 во время анимации).
## Эффекты у пола (лужи, капли, трещины) рисуются позади людей, остальные — поверх.
const FLOOR_FX := ["puddle", "drip", "ceiling_drip", "cracks"]


func _draw_fx(t: Dictionary, k: float, floor_pass := false) -> void:
	if k <= 0.0:
		return
	var r := _rect(t)
	for fx in t.get("fx", []):
		if (fx in FLOOR_FX) != floor_pass:
			continue
		match fx:
			"cracks":
				_draw_cracks(t, k)
			"rain":
				for i in 14:
					var ph := fmod(_t * 1.6 + i * 0.137, 1.0)
					var x := r.position.x + fmod(i * 37.0, r.size.x) + ph * 40.0
					var y := r.position.y + ph * (r.size.y + 260.0)
					_canvas.draw_line(Vector2(x, y), Vector2(x + 8, y + 26), Color(0.6, 0.8, 1.0, 0.7 * k), 3.0)
			"wind":
				for i in 3:
					var ph := fmod(_t * 0.7 + i * 0.33, 1.0)
					var c := Vector2(r.end.x + ph * 260.0, r.position.y + 60.0 + i * 70.0)
					_canvas.draw_arc(c, 22.0, PI * 0.2, PI * 1.6, 12, Color(1, 1, 1, 0.55 * k * (1.0 - ph)), 4.0)
					_canvas.draw_line(c + Vector2(-70, 22), c + Vector2(0, 22), Color(1, 1, 1, 0.5 * k * (1.0 - ph)), 4.0)
			"drip", "ceiling_drip":
				var from := Vector2(r.get_center().x, r.position.y + (r.size.y if fx == "ceiling_drip" else r.size.y * 0.35))
				# капля падает до своей лужи, если она задана, иначе на 380 px
				var fall := 380.0
				if t.has("puddle_at"):
					fall = maxf(60.0, float(t["puddle_at"][1]) - from.y)
				for i in 2:
					var ph := fmod(_t * 0.9 + i * 0.5, 1.0)
					_canvas.draw_circle(from + Vector2(0, ph * fall), 7.0, Color(0.55, 0.78, 1.0, 0.85 * k))
			"puddle":
				var at: Array = t.get("puddle_at", [r.get_center().x, r.end.y + 20.0])
				var below := Vector2(at[0], at[1])
				_canvas.draw_set_transform(below, 0.0, Vector2(1.0, 0.28))
				_canvas.draw_circle(Vector2.ZERO, 90.0 * k, Color(0.55, 0.75, 0.95, 0.55))
				_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"dark":
				var flicker := 0.35 + 0.1 * sin(_t * 23.0) * sin(_t * 7.0)
				_canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.12, flicker * k))


func _update_family() -> void:
	_family.visible = loc.has("family")
	if not _family.visible:
		return
	var fam: Dictionary = loc.get("family", {})
	var mood := Home.mood()
	var tex: Texture2D = null
	if Profile.owns("vita_clothes") and ResourceLoader.exists(CLOTHED):
		tex = load(CLOTHED)
	else:
		# та же пара во всех сценах: если нужного настроения ещё нет, берём ближайшее из новых
		# картинок семьи; старую картинку — только если новых нет совсем
		for d: int in [0, -1, 1, -2, 2, -3, 3]:
			var m: int = mood + d
			var path := "%sfamily/family_mood%d.png" % [ART, m]
			if m >= 0 and m <= 3 and ResourceLoader.exists(path):
				tex = load(path)
				break
		if tex == null:
			tex = load(OLD_FAMILY[mood])
	_family.texture = tex
	var h: float = fam.get("height", 560.0)
	var k := h / tex.get_height()
	_family.scale = Vector2(k, k)
	var feet: Array = fam.get("pos", [360, 1300])
	_family.position = Vector2(feet[0] - tex.get_width() * k * 0.5, feet[1] - h)


## Трещины вокруг дыр: 5 ломаных от центра каждого места, по перспективе пола сплюснуты.
func _draw_cracks(t: Dictionary, k: float) -> void:
	var id: String = t["id"]
	if not _cracks.has(id):
		var lines: Array = []
		var rects: Array[Rect2] = [_rect(t)]
		for extra: Array in t.get("more", []):
			rects.append(Rect2(extra[0], extra[1], extra[2], extra[3]))
		for r: Rect2 in rects:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(r.position.x * 31.0 + r.position.y)
			for i in 5:
				var a := rng.randf_range(0.0, TAU)
				var p := r.get_center()
				var line := PackedVector2Array([p])
				var step := r.size.x * rng.randf_range(0.5, 1.0) / 6.0
				for j in 6:
					a += rng.randf_range(-0.6, 0.6)
					p += Vector2(cos(a), sin(a) * 0.45) * step
					line.append(p)
				lines.append(line)
		_cracks[id] = lines
	for line: PackedVector2Array in _cracks[id]:
		_canvas.draw_polyline(line, Color(0.24, 0.14, 0.08, 0.9 * k), 4.0, true)
		_canvas.draw_polyline(line, Color(0.95, 0.75, 0.5, 0.35 * k), 1.5, true)


## Точка над головой говорящего (mother / daughter) в поле сцены — для облачка реплики.
## Отдельные слои сценки (props: family/mother_*, family/daughter_*) или общая пара family_mood*.
func speaker_point(who: String) -> Vector2:
	for pr: Dictionary in loc.get("props", []):
		var img := str(pr["img"])
		if img.begins_with("family/" + who):
			var tex: Texture2D = _tex.get("prop_" + img)
			var d := _fit_rect(tex, _rect(pr)) if tex else _rect(pr)
			return Vector2(d.get_center().x, d.position.y + d.size.y * 0.03)
	if _family.visible and _family.texture:
		var sz := _family.texture.get_size() * _family.scale
		# на картинке пары мама слева (голова ~38 % ширины), дочка справа ниже (~72 %, ~40 % высоты)
		var at := Vector2(0.38, 0.07) if who == "mother" else Vector2(0.72, 0.40)
		return _family.position + sz * at
	return Vector2(size.x * 0.5, size.y * 0.5)


## Радость: подпрыгнуть (вся пара или отдельные мама и дочка), дважды.
func cheer() -> void:
	var tw := create_tween()
	if _family.visible:
		var base := _family.position
		for i in 2:
			tw.tween_property(_family, "position:y", base.y - 34.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(_family, "position:y", base.y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		return
	for pr: Dictionary in loc.get("props", []):
		var img := str(pr["img"])
		if img.begins_with("family/"):
			var h := 40.0 if img.contains("daughter") else 22.0
			var hop := create_tween()
			for i in 2:
				hop.tween_method(func(v: float) -> void: _hop[img] = v, 0.0, h, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				hop.tween_method(func(v: float) -> void: _hop[img] = v, h, 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _fit_rect(tex: Texture2D, r: Rect2) -> Rect2:
	var ts := tex.get_size()
	var k := minf(r.size.x / ts.x, r.size.y / ts.y)
	return Rect2(r.position + (r.size - ts * k) * 0.5, ts * k)


func _target(id: String) -> Dictionary:
	for t in loc.get("targets", []):
		if t["id"] == id:
			return t
	return {}


static func _rect(t: Dictionary) -> Rect2:
	var v: Array = t.get("rect", [0, 0, 0, 0])
	return Rect2(v[0], v[1], v[2], v[3])


func _load(name: String) -> Texture2D:
	var path := "%s%s/%s.png" % [ART, loc.get("id", ""), name]
	return load(path) if ResourceLoader.exists(path) else null


func _load_path(path: String) -> Texture2D:
	return load(path) if ResourceLoader.exists(path) else null
