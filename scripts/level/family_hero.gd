class_name FamilyHero
extends Hero
## Shared art for the apartment and rescue puzzles; Hero still owns animation and collision.
## Мультяшные реакции 0+: дрожат при опасности, при неудаче падают без сил — копоть от лавы,
## пузыри в воде, зелёные пузырьки от кислоты, слизь от слизня; над головами кружат звёздочки.

# Грузим только нужную картинку семьи, а не все три: экономим память на слабых телефонах.
const FAMILY_PATHS := ["res://art/home/family_worn.png", "res://art/home/family_worn.png",
	"res://art/home/family_happy.png", "res://art/home/family_clothed.png"]
const HEIGHT := 148.0
const FALL_ANGLE := -1.25        # лежат на боку, ногами к месту, где стояли
const TINT := {
	"lava": Color(0.58, 0.47, 0.45),
	"acid": Color(0.78, 1.0, 0.72),
	"water": Color(0.72, 0.86, 1.0),
	"enemy": Color(0.9, 0.8, 1.0),
}
const SWEAT := Color("8ce6ff")
const STAR := Color("ffd84a")
const BUBBLE := Color(0.8, 0.95, 1.0, 0.9)

var stage := 0
var walking := false
var _fall := 0.0
var _fall_tw: Tween
var _tex: Texture2D
var _bubble: Node2D


## Облачко над головами: короткая реплика мамы или дочки; следующая заменяет прежнюю.
class Bubble extends Node2D:
	var text := ""
	var font: Font

	func _draw() -> void:
		var fs := 24
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 36.0
		var r := Rect2(-w * 0.5, -58.0, w, 50.0)
		var box := StyleBoxFlat.new()
		box.bg_color = Color("fffaf0")
		box.border_color = Color("6b4a33")
		box.set_border_width_all(3)
		box.set_corner_radius_all(22)
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -10), Vector2(12, -10), Vector2(0, 8)]), Color("6b4a33"))
		draw_style_box(box, r)
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -11), Vector2(8, -11), Vector2(0, 3)]), Color("fffaf0"))
		draw_string(font, Vector2(r.position.x + 18.0, r.position.y + 34.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("4a3226"))


func say(line: String, hold := 1.8) -> void:
	if line == "":
		return
	if _bubble:
		_bubble.queue_free()
	var b := Bubble.new()
	b.text = line
	b.font = ThemeDB.fallback_font
	b.position = Vector2(0, -HEIGHT - 8.0)
	b.scale = Vector2(0.6, 0.6)
	b.modulate.a = 0.0
	# у краёв поля облачко не должно уходить за экран
	b.position.x = clampf(b.position.x, 200.0 - position.x, 520.0 - position.x)
	add_child(b)
	_bubble = b
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.tween_callback(b.queue_free)


## Картинка семьи грузится один раз и заранее, не во время рисования.
func _enter_tree() -> void:
	_picture()


func _picture() -> Texture2D:
	if _tex == null:
		var mood_path := "res://art/act1/family/family_mood%d.png" % Home.mood()
		_tex = load(mood_path if stage < 3 and ResourceLoader.exists(mood_path) else FAMILY_PATHS[clampi(stage, 0, 3)])
	return _tex


func oops(why: String) -> void:
	super.oops(why)
	reason = why if why in ["lava", "acid", "enemy", "stuck", "water"] else "stuck"
	walking = false
	_live = true
	if _fall_tw:
		_fall_tw.kill()
	_fall_tw = create_tween()
	_fall_tw.tween_interval(0.25)
	_fall_tw.tween_property(self, "_fall", 1.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	if _rig:
		_rig.modulate = TINT.get(reason, Color.WHITE)
		_rig.queue_redraw()


func set_scared(value: bool) -> void:
	super.set_scared(value)
	_live = mood == Mood.SCARED or mood == Mood.OOPS or mood == Mood.HAPPY


func celebrate() -> void:
	super.celebrate()
	walking = false
	_live = true


func _process(delta: float) -> void:
	super._process(delta)
	if walking:
		_rig.position.y -= absf(sin(_t * 9.0)) * 5.0
		_rig.rotation = sin(_t * 9.0) * 0.04
	else:
		_rig.rotation = FALL_ANGLE * _fall
	# при падении они ещё и оседают: ноги остаются на полу
	_rig.position.y += _fall * 10.0
	if _fall > 0.0 and _fall < 1.0:
		_shadow.queue_redraw()


func _paint(ci: CanvasItem) -> void:
	_drawn_k = Pen.pixel_scale(self)
	var picture := _picture()
	var width := HEIGHT * picture.get_width() / picture.get_height()
	ci.draw_texture_rect(picture, Rect2(-width * 0.5, -HEIGHT, width, HEIGHT), false)


func _paint_fx(ci: CanvasItem) -> void:
	Pen.begin(ci)
	match mood:
		Mood.HAPPY:
			Pen.sparkle(Vector2(-57, -91), 6, Color("ffd88b"))
			Pen.sparkle(Vector2(66, -64), 5, Color("ffd88b"))
			for i in 4:
				var ph := fmod(_t * 0.5 + i * 0.25, 1.0)
				Pen.sparkle(Vector2(-60.0 + i * 40.0, -150.0 - ph * 40.0), 4.0 + 3.0 * (1.0 - ph),
					Color(1.0, 0.85, 0.45, 1.0 - ph))
		Mood.SCARED:
			for s: float in [-1.0, 1.0]:
				var ph := fmod(_t * 1.6 + (0.5 if s > 0.0 else 0.0), 1.0)
				_drop(Vector2(30.0 * s, -128.0 + ph * 22.0), 3.0, Color(SWEAT, 1.0 - ph))
			Pen.pline(PackedVector2Array([Vector2(-8, -165), Vector2(0, -180), Vector2(8, -165)]), Color("ff6b5b"), 3.0)
			Pen.disc(Vector2(0, -158), 2.5, Color("ff6b5b"))
		Mood.OOPS:
			_paint_down()
	Pen.end()


## Эффекты поверх упавшей семьи: головы после поворота — сбоку от ступней.
func _paint_down() -> void:
	var head := Vector2(0, -HEIGHT * 0.78).rotated(FALL_ANGLE * _fall) + Vector2(0, _fall * 10.0)
	match reason:
		"lava":
			for i in 4:
				var ph := fmod(_t * 0.6 + i / 4.0, 1.0)
				Pen.disc(head + Vector2(sin(ph * 6.0 + i) * 8.0 + i * 12.0 - 18.0, -20.0 - ph * 60.0),
					5.0 + ph * 10.0, Color(SMOKE, (1.0 - ph) * 0.7))
		"water":
			for i in 6:
				var ph := fmod(_t * 0.9 + i * 0.29, 1.0)
				Pen.ring(head + Vector2(-25.0 + i * 10.0 + sin(ph * 7.0 + i) * 4.0, -10.0 - ph * 70.0),
					2.5 + ph * 3.0, Color(BUBBLE, 1.0 - ph), 1.8)
		"acid":
			for i in 5:
				var ph := fmod(_t * 0.8 + i * 0.37, 1.0)
				Pen.ring(head + Vector2(-24.0 + i * 12.0 + sin(ph * 8.0 + i) * 3.0, -10.0 - ph * 55.0),
					2.0 + ph * 2.5, Color(0.71, 1.0, 0.42, 1.0 - ph), 1.5)
		"enemy":
			for d: Vector3 in [Vector3(-14, -6, 10), Vector3(4, -12, 13), Vector3(20, -4, 9)]:
				Pen.disc(head + Vector2(d.x, d.y), d.z, GOO)
		"stuck":
			for s: float in [-1.0, 1.0]:
				var ty := fmod(_t * 0.9 + (0.5 if s > 0.0 else 0.0), 1.0)
				_drop(head + Vector2(10.0 * s, ty * 14.0), 2.6, Color(TEAR, 1.0 - ty))
			return
	# кружащиеся звёздочки: им плохо, но они живы
	for i in 3:
		var a := _t * 3.0 + i * TAU / 3.0
		Pen.sparkle(head + Vector2(cos(a) * 30.0, -26.0 + sin(a) * 9.0), 5.0, STAR)


func _paint_shadow(ci: CanvasItem) -> void:
	Pen.begin(ci)
	Pen.soft(Pen.oval(Vector2(4 - _fall * 40.0, 0), Vector2(62 + _fall * 30.0, 10)), Color(0, 0, 0, 0.19))
	Pen.end()
