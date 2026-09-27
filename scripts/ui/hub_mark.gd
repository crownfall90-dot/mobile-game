extends Control
## Круглая кнопка у вещи в комнате — видно, куда можно нажать. kind: repair (золотая, сломано —
## починить), act (бирюзовая, есть занятие), lock (серая с замком, занятие откроется позже).
## Нажатие — сигнал tapped; сама кнопка ничего не решает, это делает главный экран.

signal tapped

const SIZE := 64.0          # поле нажатия
const R := 23.0             # видимый круг
const COLORS := {"repair": Color("f5c542"), "act": Color("3cc6b8"), "lock": Color("9b98a6")}
const ICONS := {"repair": &"hand", "act": &"play", "lock": &"lock"}

var kind := "act"
var _t := randf() * TAU
var _icon: Texture2D


func _init(k: String = "act") -> void:
	kind = k
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = Icons.tex(ICONS.get(kind, &"play"), 28)


func _gui_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed
	if down:
		accept_event()
		tapped.emit()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var col: Color = COLORS.get(kind, COLORS["act"])
	# сломанное зовёт сильнее: мягко «дышит»; занятия спокойнее, замок неподвижен
	var k := 1.0 + (0.09 if kind == "repair" else (0.04 if kind == "act" else 0.0)) * sin(_t * 3.0)
	draw_circle(c + Vector2(0, 3), R * k + 1.0, Color(0, 0, 0, 0.28), true, -1.0, true)
	draw_circle(c, R * k + 3.0, Color(0.14, 0.09, 0.1, 0.8), true, -1.0, true)
	draw_circle(c, R * k, col, true, -1.0, true)
	draw_circle(c + Vector2(-R * 0.3, -R * 0.35) * k, R * 0.28 * k, Color(1, 1, 1, 0.35), true, -1.0, true)
	if _icon:
		var s := Vector2(28, 28) * k
		draw_texture_rect(_icon, Rect2(c - s * 0.5, s), false, Color(0.16, 0.1, 0.1, 0.9) if kind != "lock" else Color(1, 1, 1, 0.95))
