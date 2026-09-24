class_name FamilyHero
extends Hero
## Mother and daughter share the protected area. Reuse Hero's animation and moods.

var stage := 0


func _paint(ci: CanvasItem) -> void:
	_drawn_k = Pen.pixel_scale(self)
	Pen.begin(ci, Transform2D.IDENTITY, _drawn_k)
	_person(Vector2(-21, 0), 1.0, false)
	_person(Vector2(35, 0), 0.67, true)
	# Holding hands makes the pair read as a family, including at phone scale.
	Pen.line(Vector2(1, -49), Vector2(24, -35), SKIN, 7)
	Pen.end()


func _person(origin: Vector2, s: float, child: bool) -> void:
	Pen.push(Transform2D(0.0, Vector2(s, s), 0.0, origin))
	var shirt := Color("a89b8f") if stage == 0 else Color("478e98")
	if child:
		shirt = Color("b69c97") if stage == 0 else Color("e7a46b")
	if stage >= 2:
		shirt = Color("e99c74") if child else Color("508d83")
	if stage == 3:
		shirt = Color("de87a3") if child else Color("647da8")
	var hair := Color("593d39")
	var happy := mood == Mood.HAPPY or (stage > 0 and mood == Mood.IDLE)
	var sad := mood == Mood.OOPS or (stage == 0 and mood == Mood.IDLE)
	for x in [-10, 10]:
		Pen.line(Vector2(x, -28), Vector2(x, -4), Color("47515f"), 11)
		Pen.blob(Pen.oval(Vector2(x + 2, -3), Vector2(9, 5)), Color("493d3a"), 1.5)
	Pen.blob(Pen.rrect(Rect2(-23, -70, 46, 44), 10), shirt, 2)
	Pen.line(Vector2(-21, -59), Vector2(-29, -33), shirt.darkened(0.12), 10)
	Pen.dot(Vector2(-29, -31), 5, SKIN, 1)
	Pen.line(Vector2(21, -59), Vector2(27, -42), shirt, 10)
	Pen.dot(Vector2(27, -40), 5, SKIN, 1)
	Pen.blob(Pen.oval(Vector2(0, -86), Vector2(25, 29)), hair, 2)
	if child:
		for x in [-25, 25]:
			Pen.dot(Vector2(x, -82), 10, hair, 1.5)
			Pen.dot(Vector2(x * 0.85, -92), 4, shirt, 1)
	else:
		Pen.dot(Vector2(-19, -105), 12, hair, 1.5)
	Pen.blob(Pen.oval(Vector2(0, -84), Vector2(20, 24)), SKIN, 1.5)
	Pen.blob(PackedVector2Array([Vector2(-21,-91),Vector2(-17,-107),Vector2(12,-107),Vector2(22,-89),Vector2(3,-100),Vector2(-8,-91)]), hair, 1)
	for x in [-8, 8]:
		if _closed or happy:
			Pen.arc(Vector2(x,-84), 3.5, PI, TAU, INK, 2)
		else:
			Pen.dot(Vector2(x,-83), 2.5, INK, 0)
		Pen.line(Vector2(x-4,-91 if not sad else -89), Vector2(x+3,-90 if not sad else -93), hair, 1.5)
		Pen.soft(Pen.oval(Vector2(x*1.5,-75), Vector2(4,2)), Color("ecac99"))
	if happy:
		Pen.arc(Vector2(0,-74), 6, 0.1, PI-0.1, Color("a55754"), 2)
	elif sad:
		Pen.arc(Vector2(0,-69), 4, PI+0.2, TAU-0.2, Color("a55754"), 2)
	else:
		Pen.dot(Vector2(0,-72), 3, Color("a55754"), 0)
	if stage == 0:
		Pen.blob(Pen.rrect(Rect2(-13,-47,12,12),2), shirt.lightened(0.22), 1)
		Pen.line(Vector2(-15,-45),Vector2(1,-45),shirt.darkened(0.3),1)
	else:
		Pen.dot(Vector2(0,-53),2,Color("fff0cc"),0)


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
