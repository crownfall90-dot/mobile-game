class_name FamilyHero
extends Hero
## Shared art for the apartment and rescue puzzles; Hero still owns animation and collision.

const FAMILY_WORN = preload("res://art/home/family_worn.png")
const FAMILY_HAPPY = preload("res://art/home/family_happy.png")

var stage := 0


func _paint(ci: CanvasItem) -> void:
	_drawn_k = Pen.pixel_scale(self)
	var picture: Texture2D = FAMILY_HAPPY if stage >= 2 else FAMILY_WORN
	var height := 148.0
	var width := height * picture.get_width() / picture.get_height()
	ci.draw_texture_rect(picture,Rect2(-width * 0.5,-height,width,height),false)


func _paint_fx(ci: CanvasItem) -> void:
	if mood != Mood.HAPPY:
		return
	Pen.begin(ci)
	Pen.sparkle(Vector2(-57,-91),6,Color("ffd88b"))
	Pen.sparkle(Vector2(66,-64),5,Color("ffd88b"))
	Pen.end()


func _paint_shadow(ci: CanvasItem) -> void:
	Pen.begin(ci)
	Pen.soft(Pen.oval(Vector2(4,0),Vector2(62,10)),Color(0,0,0,0.19))
	Pen.end()
