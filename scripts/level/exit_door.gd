class_name ExitDoor
extends Node2D
## Дверь-выход: деревянная дверь в рамке, нижний край — на полу (position — середина порога).
## open() плавно распахивает её, когда семья дошла.

const W := 84.0
const H := 150.0
const FRAME := Color("7a5236")
const WOOD := Color("c98a52")
const WOOD_DARK := Color("a56d3d")
const GLOW := Color(1.0, 0.9, 0.55, 0.9)

var _open := 0.0
var _t := 0.0


func open() -> void:
	create_tween().tween_property(self, "_open", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-W * 0.5, -H, W, H)
	draw_rect(r.grow(8), FRAME)
	# свет из-за двери: зовёт семью, ярче, когда дверь открыта
	var pulse := 0.25 + 0.1 * sin(_t * 3.0) + _open * 0.6
	draw_rect(r, Color(GLOW, pulse))
	var w := W * (1.0 - _open * 0.8)
	var door := Rect2(r.position, Vector2(w, H))
	draw_rect(door, WOOD)
	draw_rect(Rect2(door.position + Vector2(w * 0.14, 14), Vector2(w * 0.72, H * 0.36)), WOOD_DARK, false, 3.0)
	draw_rect(Rect2(door.position + Vector2(w * 0.14, H * 0.5), Vector2(w * 0.72, H * 0.4)), WOOD_DARK, false, 3.0)
	draw_circle(door.position + Vector2(w * 0.82, H * 0.52), 5.0, Color("f5c542"))
	# стрелка «сюда», пока дверь закрыта
	if _open < 0.5:
		var y := -H - 34.0 + sin(_t * 4.0) * 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(-14, y - 12), Vector2(14, y - 12), Vector2(0, y + 8)]), Color("ffd84a"))
