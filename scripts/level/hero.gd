class_name Hero
extends Node2D
## Мирра, ученица алхимика. Позиция узла = точка между ступнями.
## Рисунок живёт в дочернем узле _rig: дыхание и прыжки меняют только его трансформ,
## а перерисовка нужна при смене позы, моргании и в анимированных состояниях.
## Тело для физики (капсула) осталось прежним, поэтому проверенные уровни не меняются.

enum Mood { IDLE, SCARED, HAPPY, OOPS }

const SKIN := Color("ffd9bd")
const CHAR := Color("75606b")        # лицо в копоти
const HAIR := Color("ff7a45")
const HAIR_LIGHT := Color("ffae7a")
const INK := Pen.INK
const BLUSH := Color(1.0, 0.42, 0.5, 0.45)
const BOOT := Color("4a2c3a")
const GEM := Color("ff4fd8")
const GLASS := Color("d8f4ff")
const GOO := Color("b561ff")
const TEAR := Color("8ce6ff")
const SMOKE := Color(0.62, 0.58, 0.68)
const LEAF := Color("3f9a3a")
const LEAF_LIGHT := Color("7fd35a")
const GOLD := Color("f5c542")
const HEAD := Vector2(0, -84)
const APPRENTICE := {
	"id": "apprentice", "hat": "pointy",
	"palette": {"robe": "3d7bff", "robe_dark": "1f3f9e", "hat": "8a4dff", "hat_dark": "5427b8", "trim": "f5c542"},
}
# правая половина мантии сверху вниз; левая получается зеркально
const ROBE_R: Array[Vector2] = [Vector2(0, -64), Vector2(8, -63.5), Vector2(14, -61), Vector2(17.5, -56),
	Vector2(20, -46), Vector2(23, -33), Vector2(27, -19), Vector2(30.5, -8), Vector2(29, -4.8),
	Vector2(20, -3.2), Vector2(10, -2.4), Vector2(0, -2)]
# кромка чёлки справа налево, потом сглаживается
const FRINGE: Array[Vector2] = [Vector2(19.5, -77), Vector2(17, -85), Vector2(13, -89), Vector2(9.5, -83.5),
	Vector2(5, -90), Vector2(-1, -84.5), Vector2(-6, -90.5), Vector2(-12, -85), Vector2(-16.5, -88),
	Vector2(-19.5, -77)]

var mood := Mood.IDLE:
	set(v):
		mood = v
		_refresh()
var reason := ""   # причина для Mood.OOPS: lava, acid, enemy, stuck
var outfit_id := "apprentice"
var hat_style := "pointy"
var robe := Color("3d7bff")
var robe_dark := Color("1f3f9e")
var hat := Color("8a4dff")
var hat_dark := Color("5427b8")
var trim := Color("f5c542")

var _rig: Pen.Canvas
var _shadow: Pen.Canvas
var _t := 0.0
var _blink := 2.5
var _closed := false
var _live := false          # анимированное состояние: перерисовка каждый кадр
var _drawn_k := 0.0         # масштаб пикселя, при котором рисовали
var _hop := 0.0
var _squash := 0.0
var _hop_tw: Tween


func _init() -> void:
	_shadow = Pen.Canvas.new()
	_shadow.paint = _paint_shadow
	add_child(_shadow)
	_rig = Pen.Canvas.new()
	_rig.paint = _paint
	add_child(_rig)


## with_body = false: превью без физики (хаб, гардероб, экран результата).
func setup(pos: Vector2, with_body := true) -> void:
	position = pos
	if not with_body:
		return
	var body := StaticBody2D.new()
	body.collision_layer = Substances.LAYER_WORLD
	body.collision_mask = 0
	var cap := CapsuleShape2D.new()
	cap.radius = 24.0
	cap.height = 120.0
	var cs := CollisionShape2D.new()
	cs.shape = cap
	cs.position = Vector2(0, -62)
	body.add_child(cs)
	add_child(body)


func _ready() -> void:
	# без экрана анимация не нужна; физику она не трогает
	if DisplayServer.get_name() == "headless":
		set_process(false)


## o = наряд из каталога: {id, palette: {robe, robe_dark, hat, hat_dark, trim}, hat}.
func set_outfit(o: Dictionary) -> void:
	var p: Dictionary = o.get("palette", {}) if o.get("palette") is Dictionary else {}
	var d: Dictionary = APPRENTICE["palette"]
	robe = _color(p.get("robe"), d["robe"])
	robe_dark = _color(p.get("robe_dark"), d["robe_dark"])
	hat = _color(p.get("hat"), d["hat"])
	hat_dark = _color(p.get("hat_dark"), d["hat_dark"])
	trim = _color(p.get("trim"), d["trim"])
	hat_style = str(o.get("hat", "pointy"))
	outfit_id = str(o.get("id", ""))
	_refresh()


func set_scared(value: bool) -> void:
	if mood == Mood.IDLE or mood == Mood.SCARED:
		var m := Mood.SCARED if value else Mood.IDLE
		if m != mood:
			mood = m


## Маленький подскок, когда в зону падает монета.
func bounce() -> void:
	if mood != Mood.OOPS:
		_jump(10.0, 0.08, 0.14, 0.05)


## Прыжок по тапу (хаб, гардероб).
func hop() -> void:
	if not (_hop_tw and _hop_tw.is_running()):
		_jump(24.0 if mood != Mood.OOPS else 8.0, 0.18, 0.2, 0.12)


func celebrate() -> void:
	mood = Mood.HAPPY
	_kill_hop()
	_hop_tw = create_tween().set_loops(4)
	_hop_tw.tween_property(self, "_squash", 0.12, 0.07)
	_hop_tw.tween_property(self, "_hop", 26.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tw.parallel().tween_property(self, "_squash", -0.08, 0.12)
	_hop_tw.tween_property(self, "_hop", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tw.parallel().tween_property(self, "_squash", 0.0, 0.2)


## Мультяшная неудача: копоть (lava), пушистые волосы (acid), слизь (enemy), грусть (stuck).
## Мирра никогда не падает и не «умирает».
func oops(why: String) -> void:
	reason = why if why in ["lava", "acid", "enemy", "stuck"] else "stuck"
	_kill_hop()
	_hop = 0.0
	mood = Mood.OOPS
	_squash = -0.1
	create_tween().tween_property(self, "_squash", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func die() -> void:
	oops("lava")


func _jump(height: float, up: float, down: float, squash: float) -> void:
	_kill_hop()
	_hop_tw = create_tween()
	_hop_tw.tween_property(self, "_squash", squash, 0.06)
	_hop_tw.tween_property(self, "_hop", height, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tw.parallel().tween_property(self, "_squash", -squash * 0.7, up)
	_hop_tw.tween_property(self, "_hop", 0.0, down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tw.parallel().tween_property(self, "_squash", 0.0, down)
	_hop_tw.tween_property(self, "_squash", squash * 0.6, 0.05)
	_hop_tw.tween_property(self, "_squash", 0.0, 0.1)


func _kill_hop() -> void:
	if _hop_tw:
		_hop_tw.kill()
	_squash = 0.0


func _refresh() -> void:
	_live = mood == Mood.OOPS or hat_style == "flame"
	if _rig:
		_rig.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var breath := sin(_t * 2.4) * 0.018
	var jit := sin(_t * 45.0) * 1.2 if mood == Mood.SCARED else 0.0
	_rig.position = Vector2(jit, -_hop)
	_rig.scale = Vector2(1.0 - breath + _squash, 1.0 + breath - _squash)
	_shadow.scale = Vector2.ONE * clampf(1.0 - _hop * 0.012, 0.6, 1.0)
	_blink -= delta
	var redraw := _live or absf(Pen.pixel_scale(self) - _drawn_k) > _drawn_k * 0.08
	if _blink <= 0.0 and not _closed:
		_closed = true
		redraw = true
	elif _closed and _blink < -0.12:
		_closed = false
		_blink = 2.0 + fmod(_t * 7.31, 2.5)   # без глобального RNG
		redraw = true
	if redraw:
		_rig.queue_redraw()
		_shadow.queue_redraw()


# --- рисование ---------------------------------------------------------------

func _paint_shadow(ci: CanvasItem) -> void:
	Pen.begin(ci, Transform2D.IDENTITY, Pen.pixel_scale(self))
	Pen.soft(Pen.oval(Vector2.ZERO, Vector2(32, 8.5), 24), Color(0, 0, 0, 0.3))
	Pen.end()


func _paint(ci: CanvasItem) -> void:
	_drawn_k = Pen.pixel_scale(self)
	Pen.begin(ci, Transform2D.IDENTITY, _drawn_k)
	var dim := 0.35 if mood == Mood.OOPS and reason == "lava" else 0.0
	var r_top := robe.darkened(dim)
	var r_bot := robe_dark.darkened(dim)
	var tr := trim.darkened(dim)

	# сапожки и мантия
	for s: float in [-1.0, 1.0]:
		Pen.blob(Pen.oval(Vector2(9.0 * s, -2.5), Vector2(8, 4.5), 14), BOOT, 2.0)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	for i in ROBE_R.size() * 2 - 2:
		var p := ROBE_R[i] if i < ROBE_R.size() else ROBE_R[2 * ROBE_R.size() - 2 - i] * Vector2(-1, 1)
		pts.append(p)
		cols.append(r_top.lerp(r_bot, clampf((p.y + 64.0) / 62.0, 0.0, 1.0) * 0.85).lightened(0.07 if p.x < 0.0 else 0.0))
	Pen.grad(pts, cols)
	Pen.loop(pts, INK, 2.5)
	Pen.pline(PackedVector2Array([Vector2(-29, -8.5), Vector2(-19, -6), Vector2(0, -5), Vector2(19, -6), Vector2(29, -8.5)]), tr, 3.5)
	for sp: Vector3 in [Vector3(-14, -21, 3.0), Vector3(13, -14, 2.5), Vector3(7, -29, 2.0)]:
		Pen.sparkle(Vector2(sp.x, sp.y), sp.z, Color(tr, 0.9))
	Pen.blob(PackedVector2Array([Vector2(-20.7, -43), Vector2(20.7, -43), Vector2(22.1, -37), Vector2(-22.1, -37)]), r_bot.darkened(0.15), 1.5)
	Pen.dot(Vector2(0, -40), 3.8, GEM, 1.5)
	Pen.disc(Vector2(-1.2, -41.3), 1.2, Color(1, 1, 1, 0.8))
	Pen.blob(PackedVector2Array([Vector2(-9.5, -63.5), Vector2(0, -60.5), Vector2(9.5, -63.5), Vector2(0, -53.5)]), tr, 1.5)

	# рукава и ладони; в покое в правой руке пузырёк
	var hands := _hands()
	for i in 2:
		var sh := Vector2(-13.0 if i == 0 else 13.0, -56)
		var h: Vector2 = hands[i]
		var d := (h - sh).normalized()
		var n := d.orthogonal()
		var cuff := h - d * 3.0
		Pen.blob(PackedVector2Array([sh + n * 5.5, sh.lerp(cuff, 0.6) + n * 6.5, cuff + n * 8.5, cuff - n * 8.5,
			sh.lerp(cuff, 0.6) - n * 6.5, sh - n * 5.5]), r_top.darkened(0.08), 2.2)
		Pen.line(cuff + n * 7.5, cuff - n * 7.5, tr, 3.0)
		if mood == Mood.IDLE and i == 1:
			Pen.line(h + Vector2(0.5, 1), h + Vector2(1.5, 6), INK, 5.5)
			Pen.line(h + Vector2(0.5, 1), h + Vector2(1.5, 6), GLASS, 2.5)
			Pen.dot(h + Vector2(2, 12), 6.2, GEM, 2.0)
			Pen.disc(h + Vector2(0, 10), 1.8, Color(1, 1, 1, 0.85))
		if mood != Mood.SCARED:
			Pen.dot(h, 5.5, SKIN.darkened(dim * 0.6), 2.0)

	_paint_head(dim)
	_paint_hat(dim)
	if mood == Mood.SCARED:
		for h: Vector2 in hands:
			Pen.dot(h, 5.5, SKIN, 2.0)
		_drop(Vector2(21, -97), 4.2, TEAR)
	elif mood == Mood.OOPS:
		_paint_oops()
	Pen.end()


func _hands() -> Array[Vector2]:
	match mood:
		Mood.SCARED:
			return [Vector2(-15, -73), Vector2(15, -73)]
		Mood.HAPPY:
			return [Vector2(-31, -106), Vector2(31, -106)]
		Mood.OOPS:
			return [Vector2(-21, -21), Vector2(21, -21)]
	return [Vector2(-25, -29), Vector2(22, -36)]


func _paint_head(dim: float) -> void:
	var hair := HAIR.darkened(dim)
	var hood := hat_style == "hood"
	if hood:
		# хвост капюшона с помпоном и сам капюшон за головой
		Pen.blob(PackedVector2Array([Vector2(8, -106), Vector2(26, -102), Vector2(37, -84), Vector2(31, -79), Vector2(19, -93)]),
			hat_dark.darkened(dim), 2.5)
		Pen.dot(Vector2(34, -79), 6.0, trim.darkened(dim), 2.0)
		Pen.blob(Pen.oval(HEAD + Vector2(0, -1), Vector2(27, 26), 28), hat.lerp(hat_dark, 0.5).darkened(dim), 2.5)
	elif mood == Mood.OOPS and reason == "acid":
		var spikes := PackedVector2Array()
		for i in 36:
			spikes.append(HEAD + Vector2(0, -3) + Vector2.from_angle(TAU * i / 36.0) * (31.0 if i % 2 == 0 else 22.0))
		Pen.blob(spikes, hair, 2.5)
	else:
		for s: float in [-1.0, 1.0]:
			Pen.dot(Vector2(22.0 * s, -71), 8.5, hair, 2.5)
			Pen.arc(Vector2(22.0 * s, -71), 5.0, PI + 0.6, PI + 1.8, HAIR_LIGHT.darkened(dim), 2.0, 6)
		Pen.dot(HEAD + Vector2(0, -1), 22.0, hair, 2.5)
		for s: float in [-1.0, 1.0]:
			Pen.dot(Vector2(18.5 * s, -77.5), 2.8, trim.darkened(dim), 1.5)
	var sooty := mood == Mood.OOPS and reason == "lava"
	Pen.dot(HEAD + Vector2(0, 1), 19.5, CHAR if sooty else SKIN, 2.5)
	# чёлка: верх головы и мягкие пряди
	var bangs := PackedVector2Array()
	for i in 12:
		bangs.append(HEAD + Vector2(0, -1) + Vector2.from_angle(lerpf(PI + 0.25, TAU - 0.25, i / 11.0)) * 21.0)
	bangs.append_array(Pen.smooth(FRINGE, 3))
	Pen.blob(bangs, hair, 2.5)
	Pen.arc(HEAD + Vector2(0, -1), 16.0, PI + 0.8, PI + 1.5, HAIR_LIGHT.darkened(dim), 2.5, 6)
	_paint_face()
	if hood:
		var fur: Array[Vector2] = []
		for i in 15:
			fur.append(HEAD + Vector2(0, 1) + Vector2.from_angle(lerpf(PI * 0.74, PI * 2.26, i / 14.0)) * Vector2(22.5, 22.0))
		for p in fur:
			Pen.disc(p, 4.9, INK)
		for p in fur:
			Pen.disc(p, 3.9, trim.darkened(dim))
		for p in fur:
			Pen.disc(p + Vector2(-0.8, -1.0), 1.6, Color(1, 1, 1, 0.8))


func _paint_face() -> void:
	var e := Vector2(7.5, -79)
	var m := Vector2(0, -71.5)
	if not (mood == Mood.OOPS and reason == "lava"):
		for s: float in [-1.0, 1.0]:
			Pen.disc(Vector2(13.5 * s, -73), 4.2, BLUSH)
	match mood:
		Mood.HAPPY:
			for s: float in [-1.0, 1.0]:
				Pen.arc(e * Vector2(s, 1) + Vector2(0, 2), 4.0, PI + 0.5, TAU - 0.5, INK, 2.6, 8)
			var smile := PackedVector2Array()
			for i in 9:
				smile.append(m + Vector2(0, -1.5) + Vector2.from_angle(lerpf(0.0, PI, i / 8.0)) * 6.0)
			Pen.blob(smile, Color("7a1f3d"), 2.0)
			Pen.disc(m + Vector2(0, 2.4), 2.6, Color("ff7a9a"))
		Mood.SCARED:
			for s: float in [-1.0, 1.0]:
				Pen.dot(e * Vector2(s, 1), 4.7, Color.WHITE, 1.8)
				Pen.disc(e * Vector2(s, 1) + Vector2(0, 0.6), 2.1, INK)
				Pen.line(Vector2(4.0 * s, -86.5), Vector2(11.0 * s, -88.5), INK, 2.0)
			Pen.blob(Pen.oval(m + Vector2(0, 1), Vector2(3.2, 3.8), 12), Color("7a1f3d"), 2.0)
		Mood.OOPS:
			_paint_oops_face(e, m)
		_:
			for s: float in [-1.0, 1.0]:
				if _closed:
					Pen.arc(e * Vector2(s, 1) + Vector2(0, -2), 4.0, 0.5, PI - 0.5, INK, 2.4, 8)
				else:
					_eye(e * Vector2(s, 1))
			Pen.arc(m + Vector2(0, -2.2), 3.4, 0.5, PI - 0.5, INK, 1.9, 8)


func _eye(c: Vector2) -> void:
	Pen.soft(Pen.oval(c, Vector2(3.6, 4.7), 16), INK)
	Pen.disc(c + Vector2(1.2, -1.7), 1.6, Color.WHITE)
	Pen.disc(c + Vector2(-1.0, 2.0), 0.85, Color(1, 1, 1, 0.7))
	var out := signf(c.x)
	Pen.line(c + Vector2(2.8 * out, -3.2), c + Vector2(5.4 * out, -4.8), INK, 1.8)


func _paint_oops_face(e: Vector2, m: Vector2) -> void:
	match reason:
		"lava":
			# «обугленная» мордашка: тёмное лицо, белые глаза-спиральки
			for s: float in [-1.0, 1.0]:
				var c := e * Vector2(s, 1)
				Pen.dot(c, 5.0, Color.WHITE, 1.6)
				var sw := PackedVector2Array()
				for i in 14:
					var u := i / 13.0
					sw.append(c + Vector2.from_angle(_t * 5.0 * s + u * TAU * 1.6) * (0.5 + u * 3.4))
				Pen.pline(sw, INK, 1.5)
			Pen.blob(Pen.oval(m + Vector2(0, 0.5), Vector2(2.6, 3.0), 10), Color("2a1a2e"), 1.2)
			for p: Vector3 in [Vector3(-12, -93, 2.2), Vector3(11, -70, 1.6), Vector3(-15, -70, 1.4)]:
				Pen.disc(Vector2(p.x, p.y), p.z, Color(1, 1, 1, 0.35))
		"acid":
			for s: float in [-1.0, 1.0]:
				Pen.dot(e * Vector2(s, 1), 4.4, Color.WHITE, 1.8)
				Pen.disc(e * Vector2(s, 1) + Vector2(1.5 * s, -1.0), 1.7, INK)
			Pen.pline(PackedVector2Array([m + Vector2(-5, 0), m + Vector2(-2.5, -2), m + Vector2(0, 0),
				m + Vector2(2.5, -2), m + Vector2(5, 0)]), INK, 2.0)
		"enemy":
			for s: float in [-1.0, 1.0]:
				var c := e * Vector2(s, 1)
				Pen.pline(PackedVector2Array([c + Vector2(-3.0 * s, -3.5), c + Vector2(3.0 * s, 0), c + Vector2(-3.0 * s, 3.5)]), INK, 2.4)
			Pen.pline(PackedVector2Array([m + Vector2(-5, 0), m + Vector2(-2.5, -1.8), m + Vector2(0, 0),
				m + Vector2(2.5, -1.8), m + Vector2(5, 0)]), INK, 2.0)
		_:
			for s: float in [-1.0, 1.0]:
				var c := e * Vector2(s, 1)
				_eye(c + Vector2(0, 1))
				# грустное веко
				Pen.poly(PackedVector2Array([c + Vector2(-5, -6), c + Vector2(5, -6), c + Vector2(5, -1.2 + 1.5 * s),
					c + Vector2(-5, -1.2 - 1.5 * s)]), SKIN)
				Pen.line(c + Vector2(-4.5, -1.2 - 1.3 * s), c + Vector2(4.5, -1.2 + 1.3 * s), INK, 2.0)
				var ty := fmod(_t * 0.9 + (0.5 if s > 0.0 else 0.0), 1.0)
				_drop(c + Vector2(3.5 * s, 5.0 + ty * 14.0), 2.3, Color(TEAR, 1.0 - ty))
			Pen.arc(m + Vector2(0, 3), 4.0, PI + 0.5, TAU - 0.5, INK, 2.2, 8)


## Наклон вокруг макушки (шляпа приподнята от кислоты, корона набекрень).
func _tilt(rot: float, lift := 0.0) -> void:
	Pen.push(Transform2D(rot, Vector2(0, -100 - lift)) * Transform2D(0.0, Vector2(0, 100)))


func _paint_hat(dim: float) -> void:
	var h := hat.darkened(dim)
	var hd := hat_dark.darkened(dim)
	var tr := trim.darkened(dim)
	var frizz := mood == Mood.OOPS and reason == "acid"
	if frizz:
		_tilt(0.2, 8.0)
	match hat_style:
		"hood":
			pass
		"wreath":
			for i in 12:
				var a := TAU * i / 12.0
				var c := Vector2(cos(a) * 21.0, -100.0 + sin(a) * 6.0)
				Pen.blob(Pen.oval(c, Vector2(5.5, 2.8), 10, a + PI / 2.0), LEAF if i % 2 == 0 else LEAF_LIGHT, 1.5)
			for a: float in [0.25, 0.9, 1.6, 2.3, 2.95]:
				var c := Vector2(cos(a) * 21.0, -100.0 + sin(a) * 6.0)
				Pen.disc(c, 5.8, INK)
				for q in 5:
					Pen.disc(c + Vector2.from_angle(TAU * q / 5.0 + a) * 2.6, 2.6, tr)
				Pen.disc(c, 1.8, Color("ffe27a"))
		"bandana":
			var cap := PackedVector2Array()
			for i in 13:
				cap.append(HEAD + Vector2(0, -1) + Vector2.from_angle(lerpf(PI + 0.12, TAU - 0.12, i / 12.0)) * 22.5)
			cap.append_array(PackedVector2Array([Vector2(14, -91), Vector2(0, -93), Vector2(-14, -91)]))
			Pen.blob(cap, h, 2.5)
			for c: Vector2 in [Vector2(-9, -98), Vector2(3, -102), Vector2(12, -96), Vector2(-15, -93)]:
				Pen.disc(c, 2.1, Color(1, 1, 1, 0.9))
			Pen.blob(PackedVector2Array([Vector2(19, -93), Vector2(31, -86), Vector2(27, -80), Vector2(18, -88)]), hd, 2.0)
			Pen.blob(PackedVector2Array([Vector2(19, -91), Vector2(33, -94), Vector2(34, -88), Vector2(20, -87)]), hd, 2.0)
			Pen.dot(Vector2(20, -90), 4.2, h, 2.0)
		"crown":
			_tilt(-0.1 + (0.2 if frizz else 0.0), 8.0 if frizz else 0.0)
			var pts := PackedVector2Array([Vector2(-16, -96), Vector2(16, -96), Vector2(19, -116), Vector2(9, -106),
				Vector2(0, -121), Vector2(-9, -106), Vector2(-19, -116)])
			Pen.grad(pts, PackedColorArray([hd, hd, h, h.lerp(hd, 0.3), h, h.lerp(hd, 0.3), h]))
			Pen.loop(pts, INK, 2.2)
			for c: Vector2 in [Vector2(19, -117), Vector2(0, -122), Vector2(-19, -117)]:
				Pen.dot(c, 2.8, h, 1.5)
			Pen.dot(Vector2(0, -102), 3.2, GEM, 1.4)
			for s: float in [-1.0, 1.0]:
				Pen.dot(Vector2(9.5 * s, -101.5), 2.2, Color("39d6ff"), 1.2)
		"slime_crown":
			_paint_slime_pet(h, hd, tr, frizz)
		_:
			var tall := 22.0 if hat_style == "tall_stars" else 0.0
			var droop := 0.0
			if mood == Mood.OOPS:
				droop = 1.0 if reason == "stuck" else (0.55 if reason == "lava" else 0.0)
			_paint_cone(h, hd, tr, tall, droop)
	Pen.push(Transform2D.IDENTITY)


## Королева слизней: на голове сидит малыш-слизень в золотой короне.
func _paint_slime_pet(h: Color, hd: Color, tr: Color, frizz: bool) -> void:
	_tilt(0.08 + (0.2 if frizz else 0.0), 8.0 if frizz else 0.0)
	var body := PackedVector2Array()
	var cols := PackedColorArray()
	for i in 20:
		var p := Vector2(0, -104) + Vector2.from_angle(TAU * i / 20.0) * Vector2(18, 13)
		p.y = minf(p.y, -97.0)
		body.append(p)
		cols.append(h.lerp(hd, clampf((p.y + 117.0) / 20.0, 0.0, 1.0)))
	Pen.grad(body, cols)
	Pen.loop(body, INK, 2.2)
	for s: float in [-1.0, 1.0]:
		Pen.line(Vector2(13.0 * s, -98), Vector2(14.0 * s, -92), hd, 4.0)
		Pen.disc(Vector2(14.0 * s, -92), 2.3, hd)
		Pen.dot(Vector2(5.5 * s, -105), 3.3, Color.WHITE, 1.3)
		Pen.disc(Vector2(5.5 * s + 0.6, -104.5), 1.9, INK)
		Pen.disc(Vector2(5.5 * s + 1.2, -105.5), 0.7, Color.WHITE)
	Pen.arc(Vector2(0, -101.5), 2.6, 0.3, PI - 0.3, INK, 1.6, 6)
	Pen.disc(Vector2(-10, -110), 2.4, Color(1, 1, 1, 0.55))
	var crown := PackedVector2Array([Vector2(-7, -115), Vector2(7, -115), Vector2(9, -125), Vector2(4, -120),
		Vector2(0, -127), Vector2(-4, -120), Vector2(-9, -125)])
	Pen.blob(crown, GOLD, 1.6)
	Pen.dot(Vector2(0, -118), 1.8, tr, 1.0)


func _paint_cone(h: Color, hd: Color, tr: Color, tall: float, droop: float) -> void:
	Pen.blob(Pen.oval(Vector2(0, -101), Vector2(30, 7), 28), hd, 2.5)
	var rim := PackedVector2Array()
	for i in 9:
		var a := lerpf(0.45, PI - 0.45, i / 8.0)
		rim.append(Vector2(cos(a) * 26.0, -101.0 + sin(a) * 4.2))
	Pen.pline(rim, h.lerp(hd, 0.4), 2.0)
	var tip := Vector2(lerpf(16.0, 33.0, droop), lerpf(-152.0 - tall, -118.0, droop))
	var cl := Vector2(lerpf(-8.0, 6.0, droop), lerpf(-138.0 - tall * 0.8, -152.0, droop))
	var cr := Vector2(lerpf(12.0, 22.0, droop), lerpf(-122.0 - tall * 0.5, -126.0, droop))
	var bl := Vector2(-18.5, -102)
	var br := Vector2(18.5, -102)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var hl := h.lightened(0.28)
	for i in 10:
		var u := i / 9.0
		pts.append(Pen.qbez(bl, cl, tip, u))
		cols.append(hd.lerp(h, minf(u * 1.8, 1.0)).lerp(hl, maxf(0.0, u - 0.6) * 1.2))
	for i in range(8, -1, -1):
		var u := i / 9.0
		pts.append(Pen.qbez(br, cr, tip, u))
		cols.append(hd.lerp(h, minf(u * 1.8, 1.0)).darkened(0.12))
	Pen.grad(pts, cols)
	Pen.loop(pts, INK, 2.5)
	Pen.blob(PackedVector2Array([bl, br, Pen.qbez(br, cr, tip, 0.12), Pen.qbez(bl, cl, tip, 0.12)]), tr, 1.8)
	var mid := (Pen.qbez(bl, cl, tip, 0.32) + Pen.qbez(br, cr, tip, 0.32)) * 0.5
	match hat_style:
		"crescent":
			_crescent(mid + Vector2(-1, 0), 6.8, tr)
			Pen.star(Pen.qbez(bl, cl, tip, 0.62) + Vector2(5, 1), 2.8, tr, 0.0)
			Pen.star(Pen.qbez(br, cr, tip, 0.45) + Vector2(-4, 0), 2.2, tr, 0.0)
		"tall_stars":
			Pen.star(mid, 6.5, tr, 1.5)
			for u: float in [0.55, 0.78]:
				Pen.star(Pen.qbez(bl, cl, tip, u) * 0.4 + Pen.qbez(br, cr, tip, u) * 0.6, 3.8 - u * 1.5, tr, 1.2)
			Pen.star(Pen.qbez(bl, cl, tip, 0.45) + Vector2(4, 0), 2.6, tr, 0.0)
		_:
			Pen.star(mid, 6.5, tr, 1.5)
	if hat_style == "flame":
		var f := sin(_t * 13.0) * 1.6 + sin(_t * 7.0) * 1.0
		Pen.glow(tip + Vector2(0, -6), Vector2(15, 15), Color(1.0, 0.6, 0.2, 0.45), 16)
		_flame(tip + Vector2(0, 1), 7.5, 24.0, f, Color("ff5a1f"))
		_flame(tip + Vector2(0, 0), 5.2, 16.0, f * 0.7, Color("ffb02e"))
		_flame(tip + Vector2(0, -1), 2.8, 8.0, f * 0.4, Color("fff1b8"))


func _paint_oops() -> void:
	match reason:
		"lava":
			var top := Vector2(0, -122)
			match hat_style:
				"pointy", "flame", "crescent", "tall_stars":
					top = Vector2(27, -124)
				"hood", "wreath", "bandana":
					top = Vector2(0, -108)
			for i in 3:
				var ph := fmod(_t * 0.7 + i / 3.0, 1.0)
				Pen.disc(top + Vector2(sin(ph * 6.0 + i) * 5.0 + ph * 6.0, -ph * 44.0), 4.0 + ph * 8.0, Color(SMOKE, (1.0 - ph) * 0.75))
		"acid":
			for i in 5:
				var ph := fmod(_t * 0.8 + i * 0.37, 1.0)
				Pen.ring(Vector2(-30.0 + i * 15.0 + sin(ph * 8.0 + i) * 3.0, -70.0 - ph * 60.0), 2.0 + ph * 2.5,
					Color(0.71, 1.0, 0.42, 1.0 - ph), 1.5)
		"enemy":
			var dark := GOO.darkened(0.45)
			var blobs: Array[Vector3] = [Vector3(-10, -106, 13), Vector3(6, -110, 15), Vector3(18, -100, 10), Vector3(-19, -99, 9)]
			for b in blobs:
				Pen.disc(Vector2(b.x, b.y), b.z + 2.2, dark)
			for d: Vector3 in [Vector3(-21, -94, 16), Vector3(-2, -96, 7), Vector3(20, -93, 12)]:
				var len := d.z + sin(_t * 2.2 + d.x) * 3.0
				Pen.line(Vector2(d.x, d.y), Vector2(d.x, d.y + len), dark, 8.5)
				Pen.disc(Vector2(d.x, d.y + len), 5.2, dark)
			for b in blobs:
				Pen.disc(Vector2(b.x, b.y), b.z, GOO)
			for d: Vector3 in [Vector3(-21, -94, 16), Vector3(-2, -96, 7), Vector3(20, -93, 12)]:
				var len := d.z + sin(_t * 2.2 + d.x) * 3.0
				Pen.line(Vector2(d.x, d.y), Vector2(d.x, d.y + len), GOO, 4.5)
				Pen.disc(Vector2(d.x, d.y + len), 3.2, GOO)
			Pen.dot(Vector2(15, -57), 6.5, GOO, 2.0)
			for c: Vector2 in [Vector2(-9, -112), Vector2(7, -117), Vector2(13, -58.5)]:
				Pen.disc(c, 2.5, Color(1, 1, 1, 0.6))


# --- мелкие фигуры --------------------------------------------------------------

## Язычок пламени: круглый низ и вершина, которую качает sway.
func _flame(c: Vector2, r: float, h: float, sway: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var up := cos(a) > 0.0
		var y := -cos(a) * (h - r if up else r)
		var x := r * sin(a) * pow(absf(sin(a * 0.5)), 1.3)
		pts.append(c + Vector2(x + sway * pow(maxf(0.0, -y) / h, 2.0), y - r * 0.2))
	Pen.soft(pts, col)


func _drop(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r * 2.2)])
	for i in 9:
		pts.append(c + Vector2.from_angle(lerpf(-0.35, PI + 0.35, i / 8.0)) * r)
	Pen.poly(pts, col)
	Pen.loop(pts, Color(INK, col.a), 1.5)


## Полумесяц: внешняя дуга и дуга смещённого круга сходятся в точках пересечения кругов.
func _crescent(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		pts.append(c + Vector2.from_angle(lerpf(0.829, TAU - 0.829, i / 13.0)) * r)
	for i in range(1, 10):
		pts.append(c + Vector2(r * 0.42, 0) + Vector2.from_angle(lerpf(TAU - 1.237, 1.237, i / 10.0)) * r * 0.78)
	Pen.soft(pts, col)


static func _color(v: Variant, fallback: String) -> Color:
	if v is Color:
		return v
	if v is String and Color.html_is_valid(v):
		return Color.html(v)
	return Color.html(fallback)
