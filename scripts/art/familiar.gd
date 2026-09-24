class_name Familiar
extends Node2D
## Питомец рядом с Миррой: кот Уголёк, сова Тиса, лягушка Мастер Алембик.
## Без коллизий, только рисунок. Позиция узла = точка между лапками.

const INK := Pen.INK
const CAT := Color("362c4c")
const CAT_RIM := Color("8f7fc9")
const AMBER := Color("ffb31a")
const PINK := Color("ff8fb0")
const OWL := Color("8a7563")
const OWL_DARK := Color("65523f")
const OWL_BELLY := Color("e3d2b0")
const BEAK := Color("f59a2e")
const FROG := Color("5fbf4a")
const FROG_DARK := Color("3a8a2e")
const FROG_BELLY := Color("c9ec84")
const GOLD := Color("f5c542")
const MASTER_HAT := Color("3d46b8")

var kind: StringName = &"cat"
var state: StringName = &"idle"    # idle, danger, win, oops

var _rig: Pen.Canvas
var _t := 0.0
var _blink := 3.0
var _closed := false
var _hop := 0.0
var _tw: Tween
var _drawn_k := 0.0


func _init() -> void:
	_rig = Pen.Canvas.new()
	_rig.paint = _paint
	add_child(_rig)


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)


func setup(k: StringName) -> void:
	kind = k if k in [&"cat", &"owl", &"frog"] else &"cat"
	_rig.queue_redraw()


## &"win" — прыгает, &"danger" — закрывает глаза, &"oops" — грустит, &"idle" — покой.
func react(what: StringName) -> void:
	state = what if what in [&"win", &"danger", &"oops"] else &"idle"
	if _tw:
		_tw.kill()
	_hop = 0.0
	if state == &"win":
		_tw = create_tween().set_loops(5)
		_tw.tween_property(self, "_hop", 14.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "_hop", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_rig.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var bob := sin(_t * 3.0) * 1.2 if state == &"idle" else 0.0
	var jit := sin(_t * 50.0) * 0.8 if state == &"danger" else 0.0
	_rig.position = Vector2(jit, bob - _hop)
	_rig.scale = Vector2(1.0 + sin(_t * 3.0) * 0.015, 1.0 - sin(_t * 3.0) * 0.015)
	_blink -= delta
	var redraw := absf(Pen.pixel_scale(self) - _drawn_k) > _drawn_k * 0.08
	if _blink <= 0.0 and not _closed:
		_closed = true
		redraw = true
	elif _closed and _blink < -0.12:
		_closed = false
		_blink = 2.5 + fmod(_t * 5.17, 2.5)
		redraw = true
	if redraw:
		_rig.queue_redraw()


func _paint(ci: CanvasItem) -> void:
	_drawn_k = Pen.pixel_scale(self)
	Pen.begin(ci, Transform2D.IDENTITY, _drawn_k)
	Pen.soft(Pen.oval(Vector2.ZERO, Vector2(18, 4.5), 16), Color(0, 0, 0, 0.28))
	match kind:
		&"owl":
			_owl()
		&"frog":
			_frog()
		_:
			_cat()
	Pen.end()


func _cat() -> void:
	var sway := sin(_t * 2.0) * 3.0
	var tail := Pen.smooth([Vector2(10, -4), Vector2(21, -8), Vector2(22 + sway * 0.3, -20), Vector2(16 + sway, -28)])
	Pen.pline(tail, CAT_RIM, 7.5)
	Pen.pline(tail, CAT, 4.5)
	var body := Pen.oval(Vector2(0, -14), Vector2(13, 14), 20)
	for i in body.size():
		body[i].y = minf(body[i].y, -1.0)
	Pen.blob(body, CAT, 2.2, CAT_RIM)
	Pen.soft(Pen.oval(Vector2(0, -12), Vector2(5, 7), 12), CAT.lightened(0.12))
	var ear := -4.0 if state == &"oops" else 0.0
	for s: float in [-1.0, 1.0]:
		Pen.blob(PackedVector2Array([Vector2(4.0 * s, -42), Vector2(12.0 * s, -38), Vector2((11.0 - ear * 0.5) * s, -52 - ear)]), CAT, 2.0, CAT_RIM)
		Pen.poly(PackedVector2Array([Vector2(7.0 * s, -41.5), Vector2(10.5 * s, -40), Vector2(10.5 * s, -47.5 - ear)]), PINK)
		Pen.dot(Vector2(5.0 * s, -2.5), 3.6, CAT, 1.8, CAT_RIM)
	Pen.dot(Vector2(0, -34), 12.5, CAT, 2.2, CAT_RIM)
	for s: float in [-1.0, 1.0]:
		Pen.line(Vector2(7.0 * s, -30), Vector2(17.0 * s, -32), Color(1, 1, 1, 0.5), 1.0)
		Pen.line(Vector2(7.0 * s, -29), Vector2(17.0 * s, -27), Color(1, 1, 1, 0.5), 1.0)
	Pen.poly(PackedVector2Array([Vector2(-1.8, -31.5), Vector2(1.8, -31.5), Vector2(0, -29.5)]), PINK)
	_face(Vector2(5, -35), AMBER, true, Vector2(0, -27.5), CAT)


func _owl() -> void:
	var up := state == &"win"
	for s: float in [-1.0, 1.0]:
		Pen.blob(PackedVector2Array([Vector2(4.0 * s, -36), Vector2(12.0 * s, -33), Vector2(14.0 * s, -46)]), OWL_DARK, 2.0)
	Pen.blob(Pen.oval(Vector2(0, -21), Vector2(15, 20), 22), OWL, 2.2)
	Pen.blob(Pen.oval(Vector2(0, -15), Vector2(9.5, 12), 16), OWL_BELLY, 0.0)
	for row in 3:
		for j in 3 - row % 2:
			var x := (j - (2 - row % 2) * 0.5) * 5.5
			Pen.arc(Vector2(x, -19.0 + row * 5.0), 2.4, 0.3, PI - 0.3, OWL_DARK, 1.2, 5)
	for s: float in [-1.0, 1.0]:
		var wing := Vector2(14.5 * s, -30 if up else -18)
		Pen.blob(Pen.oval(wing, Vector2(5, 11), 14, -0.9 * s if up else 0.15 * s), OWL_DARK, 2.0)
		Pen.dot(Vector2(4.5 * s, -1.5), 2.6, BEAK, 1.5)
		Pen.disc(Vector2(6.2 * s, -27.5), 7.4, Color("f3e6c8"))
		Pen.ring(Vector2(6.2 * s, -27.5), 7.4, OWL_DARK, 1.2)
	Pen.blob(PackedVector2Array([Vector2(-2.6, -24), Vector2(2.6, -24), Vector2(0, -19)]), BEAK, 1.5)
	_face(Vector2(6.2, -27.5), AMBER, false, Vector2(0, -16), OWL)


func _frog() -> void:
	for s: float in [-1.0, 1.0]:
		Pen.blob(Pen.oval(Vector2(14.0 * s, -6), Vector2(7, 6), 12), FROG_DARK, 2.0)
	Pen.blob(Pen.oval(Vector2(0, -13), Vector2(17, 12.5), 22), FROG, 2.2)
	Pen.soft(Pen.oval(Vector2(0, -9), Vector2(10, 6.5), 16), FROG_BELLY)
	for s: float in [-1.0, 1.0]:
		Pen.dot(Vector2(8.0 * s, -1.5), 3.4, FROG, 1.8)
		Pen.dot(Vector2(8.5 * s, -25), 7.0, FROG, 2.2)
	# шляпа Мастера между глаз
	Pen.blob(Pen.oval(Vector2(0, -28.5), Vector2(8, 2.2), 12), MASTER_HAT.darkened(0.3), 1.6)
	Pen.blob(PackedVector2Array([Vector2(-5, -29), Vector2(5, -29), Vector2(3, -37), Vector2(5, -44), Vector2(-1, -38)]), MASTER_HAT, 1.8)
	Pen.star(Vector2(0.5, -33), 2.2, GOLD, 0.0)
	Pen.disc(Vector2(-9.5, -15.5), 2.6, Color(1.0, 0.45, 0.5, 0.45))
	Pen.disc(Vector2(9.5, -15.5), 2.6, Color(1.0, 0.45, 0.5, 0.45))
	_face(Vector2(8.5, -25), Color.WHITE, false, Vector2(0, -12), FROG)
	if state != &"danger":
		for s: float in [-1.0, 1.0]:
			Pen.ring(Vector2(8.5 * s, -25), 5.2, GOLD, 1.4)
		Pen.arc(Vector2(0, -26), 3.0, PI + 0.4, TAU - 0.4, GOLD, 1.4, 6)


## Глаза и рот по состоянию. e — правый глаз, m — рот, fur — цвет лапок, которыми закрываются.
func _face(e: Vector2, iris: Color, slit: bool, m: Vector2, fur: Color) -> void:
	for s: float in [-1.0, 1.0]:
		var c := e * Vector2(s, 1)
		match state:
			&"win":
				Pen.arc(c + Vector2(0, 1.5), 3.2, PI + 0.5, TAU - 0.5, INK, 2.2, 8)
			&"oops":
				Pen.line(c + Vector2(-2.5, -2.5), c + Vector2(2.5, 2.5), INK, 2.0)
				Pen.line(c + Vector2(-2.5, 2.5), c + Vector2(2.5, -2.5), INK, 2.0)
			&"danger":
				Pen.dot(c + Vector2(-1.0 * s, 1.5), 4.6, fur.lightened(0.1), 1.8)
			_:
				if _closed:
					Pen.arc(c + Vector2(0, -1.5), 3.2, 0.5, PI - 0.5, INK, 2.0, 8)
				else:
					Pen.dot(c, 4.2, iris, 1.4)
					Pen.soft(Pen.oval(c, Vector2(1.0 if slit else 2.4, 3.2 if slit else 2.4), 10), INK)
					Pen.disc(c + Vector2(1.3, -1.4), 1.1, Color.WHITE)
	if state == &"oops":
		Pen.arc(m + Vector2(0, 2.5), 3.0, PI + 0.5, TAU - 0.5, INK, 1.8, 8)
	elif kind == &"frog":
		Pen.arc(m + Vector2(0, -5), 7.0, 0.4, PI - 0.4, INK, 1.8, 10)
	elif kind == &"cat":
		for s: float in [-1.0, 1.0]:
			Pen.arc(m + Vector2(2.0 * s, -1.0), 2.0, 0.3, PI - 0.3, INK, 1.6, 6)
