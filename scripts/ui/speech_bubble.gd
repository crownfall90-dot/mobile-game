class_name SpeechBubble
extends Node2D
## Облачко реплики над головой: мягкая рамка, хвостик вниз к говорящему (или вверх, below), перенос строк.
## position — кончик хвостика (над головой). Появляется «пружинкой», держится hold секунд и тает;
## сигнал finished — когда исчезло. Ширина ограничена, края экрана учитывает вызывающий (clamp_x).

signal finished

const FONT_SIZE := 28
const MAX_W := 440.0
const PAD := Vector2(22, 14)
const PAPER := Color("fffaf0")
const INK := Color("4a3226")
const EDGE := Color("6b4a33")

var text := ""
var below := false         # рамка под хвостиком (хвостик вверх) — для говорящих под потолком
var _font: Font
var _box := Vector2.ZERO
var _shift := 0.0          # сдвиг рамки вбок, чтобы не вылезала за экран (хвостик остаётся на месте)


func show_line(line: String, hold := 2.2, clamp_x := Vector2(-INF, INF), base := 1.0) -> void:
	text = line
	global_scale = Vector2(base, base)
	_font = ThemeDB.fallback_font
	var s := _font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, MAX_W, FONT_SIZE)
	_box = s + PAD * 2.0
	# рамка по центру над хвостиком, но в пределах экрана
	var left := -_box.x * 0.5
	var right := _box.x * 0.5
	var world_x := global_position.x
	if world_x + left * global_scale.x < clamp_x.x:
		_shift = (clamp_x.x - (world_x + left * global_scale.x)) / global_scale.x
	elif world_x + right * global_scale.x > clamp_x.y:
		_shift = (clamp_x.y - (world_x + right * global_scale.x)) / global_scale.x
	scale = Vector2(base, base) * 0.6
	modulate.a = 0.0
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(self, "scale", Vector2(base, base), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _draw() -> void:
	if _font == null:
		return
	var r := Rect2(Vector2(-_box.x * 0.5 + _shift, 18.0 if below else -_box.y - 18.0), _box)
	var d := -1.0 if below else 1.0
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = EDGE
	box.set_border_width_all(3)
	box.set_corner_radius_all(24)
	box.shadow_color = Color(0, 0, 0, 0.18)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 3)
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -21 * d), Vector2(14, -21 * d), Vector2.ZERO]), EDGE)
	draw_style_box(box, r)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, -22 * d), Vector2(9, -22 * d), Vector2(0, -5 * d)]), PAPER)
	draw_multiline_string(_font, r.position + Vector2(PAD.x, PAD.y + FONT_SIZE * 0.8), text,
		HORIZONTAL_ALIGNMENT_CENTER, _box.x - PAD.x * 2.0, FONT_SIZE, -1, INK)
