class_name HomePuzzleBackdrop
extends Node2D

var bounds := Rect2()


func setup(rect: Rect2) -> void:
	bounds = rect


func _draw() -> void:
	var r := bounds
	draw_rect(r.grow(14),Color("4c6a6b"))
	draw_rect(r,Color("e6dfce"))
	for y in range(int(r.position.y)+28,int(r.end.y),38):
		draw_line(Vector2(r.position.x+5,y),Vector2(r.end.x-5,y),Color("d4d6c8"),2)
	for x in range(int(r.position.x)+17,int(r.end.x),65):
		draw_line(Vector2(x,r.position.y+6),Vector2(x,r.end.y-6),Color("f6ecda"),3)
	# Wood trim and domestic silhouettes retain depth without castle battlements.
	draw_rect(Rect2(r.position.x-20,r.position.y-18,r.size.x+40,23),Color("b98c66"))
	draw_line(Vector2(r.position.x-20,r.position.y+4),Vector2(r.end.x+20,r.position.y+4),Color("735f52"),4)
	for x in [r.position.x+36,r.end.x-36]:
		draw_rect(Rect2(x-15,r.position.y+45,30,59),Color("9cb7ad"))
		draw_rect(Rect2(x-11,r.position.y+49,22,51),Color("f0ddac"))
		draw_line(Vector2(x,r.position.y+49),Vector2(x,r.position.y+100),Color("a98f70"),3)
	draw_rect(Rect2(r.position.x-17,r.end.y-7,r.size.x+34,21),Color("aa8668"))
