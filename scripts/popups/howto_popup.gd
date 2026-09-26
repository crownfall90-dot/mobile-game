extends UiPopup
## «Как играть»: при первой встрече с механикой. Рука показывает жест (провести, нажать,
## удержать, качать в ритм), две короткие строки, кнопка «Понятно!». Пока открыто — уровень
## на паузе. args: {"kind": ключ механики}; после закрытия ставится флаг tut.<kind>.

## ключ -> [жест, заголовок, текст]
const TIPS := {
	"putty": ["drag", "Замазка", "Проведи пальцем — ляжет дорожка замазки.\nВода побежит по ней."],
	"dirt": ["drag", "Копай пальцем", "Проведи по грязи — откроешь путь.\nПотом тяни засовы."],
	"pins": ["swipe", "Засовы", "Тяни засовы по одному.\nПорядок важен — подумай, что польётся первым."],
	"pipes": ["tap", "Трубы", "Нажми на трубу — она повернётся.\nВеди воду куда нужно."],
	"rotate": ["tap_side", "Наклоняй", "Жми стрелки внизу — наклоняй вещь,\nчтобы всё стекло куда надо."],
	"dishes": ["drag", "Посуда на полку", "Веди посуду пальцем к полке и отпусти.\nТяжёлое — ближе к винту."],
	"leak": ["hold", "Лови капли", "Води ведро под капли, а на дыре держи палец —\nзаклеишь. Мышь спугни тапом."],
	"plunger": ["rhythm", "Вантуз", "Жми, когда кольцо стало жёлтым.\nРаньше — брызги!"],
	"mirrors": ["tap", "Контакты", "Нажимай контакты — они поворачиваются.\nДоведи ток до цели."],
	"sew": ["zigzag", "Шьём диван", "Нажимай дырки зигзагом: слева, справа…\nПружину спрячь тапом."],
}


## Какая механика в уровне (по данным уровня); "" — показывать нечего.
static func kind_of(data: Dictionary) -> String:
	for k in ["leak", "dishes", "plunger", "mirrors", "sew", "rotate", "pipes", "putty", "dirt"]:
		if data.has(k):
			return k
	return "pins" if data.has("pins") else ""


func open(args: Dictionary) -> void:
	var kind := str(args.get("kind", "pins"))
	var tip: Array = TIPS.get(kind, TIPS["pins"])
	set_title(str(tip[1]))
	get_tree().paused = true
	closed.connect(func(_v: Variant) -> void:
		get_tree().paused = false
		Profile.set_flag("tut." + kind))
	var demo := Demo.new()
	demo.gesture = str(tip[0])
	demo.custom_minimum_size = Vector2(420, 220)
	content.add_child(demo)
	var text := UiKit.body(str(tip[2]), 27, UiKit.TEXT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.custom_minimum_size.x = 500
	content.add_child(text)
	var ok := UiKit.button("Понятно!")
	content.add_child(ok)
	ok.pressed.connect(func() -> void: close())


## Показ жеста: рука и след пальца на тёмной карточке.
class Demo extends Control:
	var gesture := "tap"
	var _t := 0.0
	var _hand: Texture2D

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_hand = Icons.tex(&"hand", 96)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0, 0, 0, 0.25))
		var c := r.get_center()
		var ph := fmod(_t, 1.8) / 1.8
		var p := c
		var press := false
		match gesture:
			"drag", "swipe":
				var a := c + Vector2(-140, 30)
				var b := c + Vector2(140, -30 if gesture == "drag" else 30)
				var k := clampf(ph / 0.7, 0.0, 1.0)
				p = a.lerp(b, k)
				press = ph < 0.75
				draw_line(a, p, Color(1.0, 0.85, 0.3, 0.8), 12.0, true)
			"tap", "tap_side":
				p = c + (Vector2(120, 40) if gesture == "tap_side" else Vector2.ZERO)
				press = ph > 0.3 and ph < 0.5
				if gesture == "tap_side":
					for side in [-1.0, 1.0]:
						var ac := c + Vector2(120 * side, 40)
						draw_circle(ac, 34.0, Color(1, 1, 1, 0.2))
						draw_string(ThemeDB.fallback_font, ac + Vector2(-12, 14), "↻" if side > 0 else "↺",
							HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 1, 0.8))
			"hold":
				p = c
				press = ph > 0.15
				var k := clampf((ph - 0.15) / 0.7, 0.0, 1.0)
				draw_arc(c, 46.0, -PI * 0.5, -PI * 0.5 + TAU * k, 32, Color("ffd66e"), 8.0, true)
			"rhythm":
				p = c + Vector2(90, 0)
				var ring := clampf(fmod(_t, 0.9) / 0.6, 0.0, 1.0)
				draw_arc(c + Vector2(-80, 0), 40.0, -PI * 0.5, -PI * 0.5 + TAU * ring, 32,
					Color("f2c14e") if ring >= 1.0 else Color(1, 1, 1, 0.8), 8.0, true)
				press = ring >= 1.0
			"zigzag":
				var pts := [c + Vector2(-60, -70), c + Vector2(60, -35), c + Vector2(-60, 0), c + Vector2(60, 35)]
				for q: Vector2 in pts:
					draw_circle(q, 12.0, Color("e8d4a8"))
				var i := int(ph * 4.0) % 4
				for j in i:
					draw_line(pts[j], pts[j + 1], Color("c7433a"), 5.0, true)
				p = pts[i]
				press = fmod(ph * 4.0, 1.0) > 0.4
		if press:
			draw_circle(p, 26.0, Color(1.0, 0.85, 0.3, 0.45))
		if _hand:
			var hs := Vector2(96, 96) * (0.9 if press else 1.0)
			draw_texture_rect(_hand, Rect2(p - Vector2(hs.x * 0.3, 0), hs), false)
