class_name Receiver
extends Hero
## Приёмник головоломки «внутри вещи» вместо семьи: слив раковины, ведро, ящик для деталей,
## конфорка, дыра в полу; "art" — приёмник уже нарисован на фоне головоломки.
## Уровень задаёт его в "receiver": {rect, look, kind, bad, mode}.
## Стенки приёмника — обычные стены уровня; здесь только вид и реакции:
## bounce — принял порцию, celebrate — починено, oops — испорчено (дым, трещина).

const METAL := Color("b9c3c8")
const METAL_DARK := Color("6d777d")
const HOLE := Color("2e2a28")

var look := "drain"
var size := Vector2(160, 80)
var _glow := 0.0
var _crack := 0.0


func configure(rect: Rect2, receiver_look: String) -> void:
	look = receiver_look
	size = rect.size


func bounce() -> void:
	_glow = 1.0
	super.bounce()


func celebrate() -> void:
	super.celebrate()
	_live = true


func oops(why: String) -> void:
	super.oops(why)
	_live = true
	create_tween().tween_property(self, "_crack", 1.0, 0.4)


func set_scared(_value: bool) -> void:
	pass


func _process(delta: float) -> void:
	super._process(delta)
	_glow = maxf(0.0, _glow - delta * 2.5)
	if _glow > 0.0 or (mood == Mood.HAPPY and (look == "burner" or look == "radiator")):
		_rig.queue_redraw()


func _paint_shadow(_ci: CanvasItem) -> void:
	pass


func _paint(ci: CanvasItem) -> void:
	_drawn_k = Pen.pixel_scale(self)
	var w := size.x
	var h := size.y
	var r := Rect2(-w * 0.5, -h, w, h)
	match look:
		"drain":
			# воронка слива: хромированный край, тёмное отверстие, труба уходит вниз
			ci.draw_rect(Rect2(-w * 0.2, -h * 0.4, w * 0.4, h * 0.4 + 60.0), METAL_DARK)
			ci.draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
				Vector2(w * 0.2, -h * 0.4), Vector2(-w * 0.2, -h * 0.4)]), METAL)
			ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color.WHITE, 3.0)
			ci.draw_rect(Rect2(-w * 0.14, -h * 0.4, w * 0.28, 14), HOLE)
		"bucket":
			ci.draw_colored_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y),
				Vector2(w * 0.4, 0), Vector2(-w * 0.4, 0)]), Color("a9b4bb"))
			ci.draw_line(r.position + Vector2(0, 10), Vector2(r.end.x, r.position.y + 10), METAL_DARK, 4.0)
			ci.draw_line(Vector2(-w * 0.42, -h * 0.3), Vector2(w * 0.42, -h * 0.3), METAL_DARK, 4.0)
			ci.draw_arc(Vector2(0, -h), w * 0.5, PI, TAU, 16, METAL_DARK, 4.0)
		"toolbox":
			ci.draw_rect(Rect2(-w * 0.5, -h * 0.7, w, h * 0.7), Color("d9483b"))
			ci.draw_rect(Rect2(-w * 0.5, -h * 0.7, w, 12), Color("a8322a"))
			ci.draw_rect(Rect2(-w * 0.5, -h * 0.7, w, h * 0.7), Color("6e1f1a"), false, 3.0)
			ci.draw_rect(Rect2(-w * 0.15, -h * 0.45, w * 0.3, 10), Color("f2c14e"))
		"burner":
			ci.draw_rect(Rect2(-w * 0.5, -18, w, 18), Color("3a3230"))
			if mood == Mood.HAPPY:
				# починенная конфорка горит ровным голубым газовым пламенем
				for i in 7:
					var x := -w * 0.36 + i * w * 0.12
					var hgt := 16.0 + 6.0 * sin(_t * 9.0 + i * 1.7)
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, -22), Vector2(x, -22 - hgt), Vector2(x + 6, -22)]), Color(0.35, 0.6, 1.0, 0.9))
					ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3, -22), Vector2(x, -22 - hgt * 0.55), Vector2(x + 3, -22)]), Color(0.85, 0.95, 1.0, 0.95))
			for k in [0.42, 0.3]:
				ci.draw_arc(Vector2(0, -24), w * k, PI, TAU, 24, Color(1.0, 0.45 + 0.3 * _glow, 0.1, 0.35 + 0.65 * _glow) if _glow > 0.0 else Color("5a524e"), 6.0)
		"sewer":
			# выход трубы в канализацию: тёмный круг с решёткой в конце трубы
			var c := Vector2(0, -h * 0.5)
			ci.draw_circle(c, minf(w, h) * 0.5, METAL_DARK)
			ci.draw_circle(c, minf(w, h) * 0.4, HOLE)
			for k in [-0.2, 0.0, 0.2]:
				ci.draw_line(c + Vector2(k * w, -h * 0.35), c + Vector2(k * w, h * 0.35), METAL, 3.0)
		"radiator":
			# батарея отопления: рёбра; наполняется горячей водой — теплеет (оранжевый отсвет)
			var fins := 6
			var fw := w / fins
			var warm := Color(1.0, 0.55, 0.25, 0.35 + 0.35 * _glow) if mood == Mood.HAPPY or _glow > 0.0 else Color(0, 0, 0, 0)
			for i in fins:
				var fr := Rect2(-w * 0.5 + i * fw + 3.0, -h, fw - 6.0, h - 10.0)
				ci.draw_rect(fr, Color("ece6dc"))
				ci.draw_rect(fr, Color("9aa0a3"), false, 3.0)
				if warm.a > 0.0:
					ci.draw_rect(fr.grow(-4.0), warm)
			ci.draw_rect(Rect2(-w * 0.5, -h * 0.18, w, 10.0), Color("b9b1a4"))
			ci.draw_rect(Rect2(-w * 0.5 - 6.0, -h + 10.0, 10.0, 12.0), Color("8d969b"))
		"hole":
			# дыра в полу: неровный тёмный край; камни, упавшие сюда, её заделывают
			ci.draw_rect(r, Color(0.12, 0.08, 0.05, 0.35))
			ci.draw_line(r.position, Vector2(r.end.x, r.position.y), Color("7a5236"), 5.0)
		"art":
			pass    # приёмник нарисован на картинке художника (art/act1/levels/<тема>.png)
		_:
			ci.draw_rect(r, Color(1, 1, 1, 0.15), false, 3.0)
	if _glow > 0.0 and look == "art":
		ci.draw_arc(r.get_center(), minf(w, h) * 0.5 + 4.0, 0.0, TAU, 32, Color(1, 1, 0.8, 0.5 * _glow), 5.0, true)
	elif _glow > 0.0 and look != "burner":
		ci.draw_rect(r.grow(4), Color(1, 1, 0.8, 0.35 * _glow), false, 4.0)


func _paint_fx(ci: CanvasItem) -> void:
	Pen.begin(ci)
	match mood:
		Mood.HAPPY:
			for i in 5:
				var ph := fmod(_t * 0.6 + i * 0.2, 1.0)
				Pen.sparkle(Vector2(-size.x * 0.5 + i * size.x * 0.25, -size.y - 20.0 - ph * 60.0), 6.0 * (1.0 - ph) + 2.0,
					Color(1.0, 0.85, 0.45, 1.0 - ph))
		Mood.OOPS:
			for i in 4:
				var ph := fmod(_t * 0.6 + i / 4.0, 1.0)
				Pen.disc(Vector2(sin(ph * 6.0 + i) * 12.0 + (i - 1.5) * 20.0, -size.y * 0.5 - ph * 90.0),
					6.0 + ph * 12.0, Color(0.55, 0.52, 0.55, (1.0 - ph) * 0.7))
			if _crack > 0.0:
				var c := Color(0.1, 0.08, 0.06, _crack)
				Pen.line(Vector2(-20, -size.y * 0.8), Vector2(0, -size.y * 0.5), c, 3.0)
				Pen.line(Vector2(0, -size.y * 0.5), Vector2(14, -size.y * 0.3), c, 3.0)
	Pen.end()
