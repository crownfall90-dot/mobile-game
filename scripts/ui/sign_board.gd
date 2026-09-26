extends Control
## Название локации — деревянная табличка на двух верёвочках: крупно название главы
## («Первая ночь»), над ним мелко «глава N». Табличка чуть покачивается; show_in() — опускается
## сверху с пружинкой (вход в новую локацию). Размер — по тексту (custom_minimum_size).

const WOOD := Color("9b6a43")
const WOOD_DARK := Color("6e4a2e")
const WOOD_LIGHT := Color("b98556")
const INK := Color("fff0ce")
const ROPE := Color("d9c3a0")
const TITLE_SIZE := 34
const SMALL_SIZE := 19
const PAD := Vector2(26, 12)

var title := ""
var small := ""
var _font: Font
var _t := 0.0


func setup(title_text: String, small_text: String) -> void:
	title = title_text
	small = small_text
	_font = UiKit.font(true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var sw := _font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
	custom_minimum_size = Vector2(maxf(tw, sw) + PAD.x * 2.0, TITLE_SIZE + SMALL_SIZE + PAD.y * 2.0 + 6.0)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x * 0.5, -60.0)


## Опускается сверху, покачиваясь (при входе в локацию).
func show_in() -> void:
	var y := position.y
	position.y = y - 160.0
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position:y", y, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.3)


func _process(delta: float) -> void:
	_t += delta
	rotation = sin(_t * 1.3) * 0.012
	queue_redraw()


func _draw() -> void:
	if _font == null:
		return
	var r := Rect2(Vector2.ZERO, size)
	# верёвочки к гвоздикам
	for x in [r.size.x * 0.18, r.size.x * 0.82]:
		draw_line(Vector2(x, -70), Vector2(x, 8), ROPE, 3.0, true)
	# доска: тень, тело, светлая кромка сверху, волокна
	var sb := StyleBoxFlat.new()
	sb.bg_color = WOOD
	sb.border_color = WOOD_DARK
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(14)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	draw_style_box(sb, r)
	draw_line(Vector2(14, 7), Vector2(r.size.x - 14, 7), Color(WOOD_LIGHT, 0.8), 3.0)
	for i in 3:
		var y := 18.0 + i * (r.size.y - 30.0) / 2.0
		draw_line(Vector2(18, y + 4), Vector2(r.size.x * (0.35 + 0.2 * i), y + 2), Color(WOOD_DARK, 0.25), 2.0)
	for x in [r.size.x * 0.18, r.size.x * 0.82]:
		draw_circle(Vector2(x, 10), 4.0, Color("5a4030"))
		draw_circle(Vector2(x - 1, 9), 1.5, Color(1, 1, 1, 0.4))
	# «глава N» мелко и название крупно, по центру
	var sw := _font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE).x
	draw_string(_font, Vector2((r.size.x - sw) * 0.5, PAD.y + SMALL_SIZE), small,
		HORIZONTAL_ALIGNMENT_LEFT, -1, SMALL_SIZE, Color(INK, 0.75))
	var tw := _font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	var base := Vector2((r.size.x - tw) * 0.5, PAD.y + SMALL_SIZE + 6.0 + TITLE_SIZE * 0.95)
	draw_string_outline(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, 6, Color(0.25, 0.15, 0.08, 0.8))
	draw_string(_font, base, title, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, INK)
