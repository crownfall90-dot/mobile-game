class_name HomeArt
extends Node2D
## Fixed drawing coordinates; the hub scales the complete room and touch targets together.

const WORN_STUDIO = preload("res://art/home/studio_worn.png")
const REPAIRED_STUDIO = preload("res://art/home/studio_repaired.png")
const REPAIR_SHADER = preload("res://art/home/repair_mix.gdshader")
const TEDDY = preload("res://art/home/teddy.png")
# ponytail: Two aligned room plates keep the APK small, but regional blends can
# show seams. Replace them with per-object layers if the final art needs it.

const IMAGE_SLOTS := {
	"tv": Rect2(566,397,154,210), "light": Rect2(300,0,120,166),
	"window": Rect2(0,78,166,296), "bed": Rect2(543,683,177,442),
	"sofa": Rect2(0,641,232,490), "kitchen": Rect2(0,270,260,276),
	"bath": Rect2(492,183,150,235), "toilet": Rect2(548,346,98,154),
	"walls": Rect2(379,177,108,207), "floor": Rect2(305,833,155,265),
}

const SLOTS := {
	"tv": Rect2(377,460,194,125), "light": Rect2(308,242,90,95),
	"window": Rect2(65,302,148,166), "bed": Rect2(56,854,229,128),
	"sofa": Rect2(60,693,220,137), "kitchen": Rect2(56,504,241,142),
	"bath": Rect2(483,694,179,133), "toilet": Rect2(555,861,103,119),
	"walls": Rect2(490,319,155,102), "floor": Rect2(316,914,133,83),
}
var repaired: Array[String] = []
var highlight := ""
var area := "flat"
var _image: Sprite2D
var _decor: Pen.Canvas


func _ready() -> void:
	if area != "flat":
		return
	_image = Sprite2D.new()
	_image.texture = WORN_STUDIO
	_image.centered = false
	_image.scale = Vector2(720.0,1280.0) / WORN_STUDIO.get_size()
	var mat := ShaderMaterial.new()
	mat.shader = REPAIR_SHADER
	mat.set_shader_parameter("restored",REPAIRED_STUDIO)
	_image.material = mat
	add_child(_image)
	_decor = Pen.Canvas.new()
	_decor.paint = _paint_overlay
	add_child(_decor)


func _draw() -> void:
	if area == "flat":
		var mask := 0
		for i in 10:
			if repaired.has(Home.OLD_ORDER[i]):
				mask |= 1 << i
		if _image:
			(_image.material as ShaderMaterial).set_shader_parameter("repair_mask",mask)
		if _decor:
			_decor.queue_redraw()
		return
	Pen.begin(self)
	var warm := repaired.size() >= 2
	var wall := Color("e9dcc7") if repaired.has("walls") else Color("b2b2a7")
	var floor_color := Color("b98d69") if repaired.has("floor") else Color("857768")
	_box(Rect2(26,247,668,766),18,Color("263d43"))
	Pen.grad(PackedVector2Array([Vector2(36,257),Vector2(367,275),Vector2(367,738),Vector2(36,738)]),PackedColorArray([wall.darkened(0.16),wall,wall.darkened(0.04),wall.darkened(0.21)]))
	Pen.grad(PackedVector2Array([Vector2(367,275),Vector2(684,257),Vector2(684,738),Vector2(367,738)]),PackedColorArray([wall,wall.lightened(0.09),wall.darkened(0.08),wall.darkened(0.04)]))
	Pen.line(Vector2(367,275),Vector2(367,738),wall.darkened(0.27),3)
	Pen.line(Vector2(36,273),Vector2(367,292),Color(1,1,1,0.17),3)
	Pen.line(Vector2(367,292),Vector2(684,273),Color(1,1,1,0.17),3)
	Pen.grad(PackedVector2Array([Vector2(36,738),Vector2(684,738),Vector2(684,1001),Vector2(36,1001)]),PackedColorArray([floor_color.lightened(0.1),floor_color.lightened(0.15),floor_color.darkened(0.2),floor_color.darkened(0.14)]))
	for y in range(765,1000,42):
		Pen.line(Vector2(37,y),Vector2(683,y),floor_color.darkened(0.25),2)
		for x in range(42+(y%3)*64,680,142):
			Pen.line(Vector2(x,y),Vector2(x+6,y+40),floor_color.darkened(0.2),1)
	Pen.line(Vector2(36,731),Vector2(682,731),Color("eee0cc") if warm else Color("77766d"),9)
	if not repaired.has("walls"):
		for p in [Vector2(457,345),Vector2(240,415),Vector2(602,605)]:
			Pen.pline(PackedVector2Array([p,p+Vector2(-9,18),p+Vector2(5,36),p+Vector2(-9,60)]),Color("888c80"),2)
	else:
		_box(Rect2(513,330,75,77),5,Color("bf9468"))
		_box(Rect2(520,337,61,63),2,Color("fff1d6"))
		Pen.blob(Pen.oval(Vector2(551,371),Vector2(19,21)),Color("71978c"),0)
		Pen.disc(Vector2(552,351),10,Color("e4b86e"))
	_window()
	_light()
	_kitchen()
	_tv()
	_sofa()
	_bed()
	_bathroom()
	if repaired.has("floor"):
		Pen.blob(Pen.oval(Vector2(369,933),Vector2(77,38)),Color("789d90"),4,Color("e4d9b5"))
		Pen.pline(PackedVector2Array([Vector2(322,933),Vector2(369,907),Vector2(416,933),Vector2(369,959),Vector2(322,933)]),Color("dbe3bd"),2)
	if Profile.owns("vita_plant"):
		_box(Rect2(312,617,31,39),5,Color("cb9672"))
		Pen.line(Vector2(328,619),Vector2(328,573),Color("446e54"),4)
		for p in [Vector2(314,592),Vector2(340,580),Vector2(342,610)]:
			Pen.soft(Pen.oval(p,Vector2(17,8),16,0.4),Color("6a9e71"))
	if Profile.owns("vita_teddy"):
		Pen.dot(Vector2(295,941),17,Color("c79c71"),2)
		Pen.dot(Vector2(295,918),14,Color("c79c71"),2)
		Pen.dot(Vector2(282,907),6,Color("c79c71"),1)
		Pen.dot(Vector2(308,907),6,Color("c79c71"),1)
		Pen.disc(Vector2(290,916),2,Color("424440"))
		Pen.disc(Vector2(300,916),2,Color("424440"))
	if Profile.owns("vita_picture"):
		_box(Rect2(238,362,57,68),4,Color("a67f54"))
		_box(Rect2(244,368,45,56),2,Color("f6e5c5"))
		Pen.dot(Vector2(257,391),9,Color("dfac8b"),1)
		Pen.dot(Vector2(276,399),7,Color("dfac8b"),1)
	if warm:
		Pen.glow(Vector2(354,414),Vector2(210,170),Color(1.0,0.87,0.59,0.06))
	if highlight != "" and SLOTS.has(highlight):
		Pen.loop(Pen.rrect(SLOTS[highlight].grow(7),16),Color("ffe7a1"),4)
	Pen.end()


## Купленный декор: крупно и на свободных местах, не за героинями (координаты 720×1280).
const DECOR_SLOTS := {
	"vita_plant": Rect2(22, 1000, 118, 190),
	"vita_teddy": Rect2(566, 1030, 136, 142),
	"vita_picture": Rect2(452, 118, 118, 96),
}


func _paint_overlay(ci: CanvasItem) -> void:
	for id in DECOR_SLOTS:
		if Profile.owns(id):
			draw_decor(ci, id, DECOR_SLOTS[id])
	Pen.begin(ci)
	if highlight != "" and IMAGE_SLOTS.has(highlight):
		Pen.loop(Pen.rrect(IMAGE_SLOTS[highlight].grow(4),14),Color("ffe7a1"),3)
	Pen.end()


## Рисует вещь магазина в прямоугольник r: в комнате и на карточке магазина.
static func draw_decor(ci: CanvasItem, id: String, r: Rect2) -> void:
	if id == "vita_teddy":
		ci.draw_texture_rect(TEDDY, r, false)
		return
	if id == "vita_clothes":
		var tex: Texture2D = load("res://art/home/family_clothed.png")
		var w := r.size.y * tex.get_width() / tex.get_height()
		ci.draw_texture_rect(tex, Rect2(r.get_center().x - w * 0.5, r.position.y, w, r.size.y), false)
		return
	# рисунки заданы в квадрате 100×100 и растягиваются в r
	var xf := Transform2D(0.0, r.size / 100.0, 0.0, r.position)
	Pen.begin(ci, xf)
	match id:
		"vita_plant":
			for leaf in [[Vector2(50, 40), 0.0], [Vector2(30, 34), -0.7], [Vector2(70, 34), 0.7],
					[Vector2(22, 52), -1.1], [Vector2(78, 52), 1.1], [Vector2(40, 18), -0.3], [Vector2(60, 18), 0.3]]:
				Pen.blob(Pen.oval(leaf[0], Vector2(9, 20), 18, leaf[1]), Color("5fae62"), 1.6, Color("2f6b3a"))
				Pen.line(leaf[0] + Vector2(0, 14).rotated(leaf[1]), Vector2(50, 66), Color("3f8a45"), 2.0)
			Pen.blob(PackedVector2Array([Vector2(28, 64), Vector2(72, 64), Vector2(64, 98), Vector2(36, 98)]), Color("d9825a"), 2.0, Color("8a4a2e"))
			Pen.blob(Pen.rrect(Rect2(24, 60, 52, 10), 3), Color("e89a6e"), 2.0, Color("8a4a2e"))
		"vita_picture":
			Pen.blob(Pen.rrect(Rect2(2, 2, 96, 96), 6), Color("b07a45"), 2.0, Color("6b4526"))
			Pen.soft(Pen.rrect(Rect2(12, 12, 76, 76), 3), Color("bfe3f2"))
			Pen.disc(Vector2(70, 30), 9, Color("ffd65a"))
			Pen.soft(PackedVector2Array([Vector2(12, 88), Vector2(12, 66), Vector2(40, 58), Vector2(88, 70), Vector2(88, 88)]), Color("8fcf78"))
			# мама и дочка держатся за руки
			Pen.disc(Vector2(38, 42), 8, Color("f2c9a8"))
			Pen.blob(PackedVector2Array([Vector2(30, 52), Vector2(46, 52), Vector2(50, 80), Vector2(26, 80)]), Color("c0506a"), 1.4, Color("6b2a3a"))
			Pen.disc(Vector2(62, 56), 6, Color("f2c9a8"))
			Pen.blob(PackedVector2Array([Vector2(56, 63), Vector2(68, 63), Vector2(71, 82), Vector2(53, 82)]), Color("4f86c6"), 1.4, Color("2a4a70"))
			Pen.line(Vector2(47, 64), Vector2(56, 68), Color("f2c9a8"), 2.5)
	Pen.end()


func _window() -> void:
	var good := repaired.has("window")
	_box(SLOTS.window,7,Color("f8e8cc") if good else Color("797970"))
	_box(Rect2(75,312,128,143),3,Color("abcfd1") if good else Color("788f97"))
	Pen.disc(Vector2(173,337),18,Color("ffe2a1"))
	for i in 4:
		_box(Rect2(80+i*31,383-i%2*14,24,68+i%2*14),0,Color("89a4a9"))
	Pen.line(Vector2(139,311),Vector2(139,457),Color("eee2c7"),7)
	Pen.line(Vector2(76,382),Vector2(202,382),Color("eee2c7"),6)
	if good:
		_box(Rect2(58,294,19,159),7,Color("dc9f7a"))
		_box(Rect2(200,294,19,159),7,Color("dc9f7a"))
		Pen.line(Vector2(52,294),Vector2(225,294),Color("65564a"),6)
	else:
		Pen.pline(PackedVector2Array([Vector2(166,319),Vector2(151,349),Vector2(181,363),Vector2(169,390)]),Color("e4e2cd"),2)
	_box(Rect2(55,457,169,12),3,Color("c4ac8c"))
	if good:
		_box(Rect2(95,439,23,19),3,Color("c28566"))
		Pen.line(Vector2(106,440),Vector2(105,405),Color("4c806a"),3)
		Pen.soft(Pen.oval(Vector2(98,420),Vector2(10,5),16,-0.4),Color("578a6d"))
		Pen.soft(Pen.oval(Vector2(114,411),Vector2(11,5),16,0.4),Color("689b76"))


func _light() -> void:
	var good := repaired.has("light")
	Pen.line(Vector2(353,257),Vector2(353,282),Color("655b50"),4)
	Pen.blob(PackedVector2Array([Vector2(329,281),Vector2(376,281),Vector2(394,321),Vector2(311,321)]),Color("e6b76d") if good else Color("847e6b"),2)
	Pen.soft(Pen.oval(Vector2(353,321),Vector2(41,9)),Color("ffeac0") if good else Color("b3a58e"))
	if good:
		Pen.glow(Vector2(353,336),Vector2(59,49),Color(1,0.89,0.63,0.18))


func _tv() -> void:
	var good := repaired.has("tv")
	_box(Rect2(385,579,179,46),5,Color("b3916c"))
	for x in [397,548]:
		Pen.line(Vector2(x,612),Vector2(x,640),Color("6c5745"),7)
	Pen.line(Vector2(471,561),Vector2(471,582),Color("41484b"),8)
	_box(Rect2(447,578,49,5),2,Color("41484b"))
	_box(Rect2(380,463,185,108),9,Color("39484c") if good else Color("69665b"))
	_box(Rect2(389,471,166,88),5,Color("acdce2") if good else Color("424b50"))
	if good:
		Pen.disc(Vector2(527,493),13,Color("fff2b8"))
		Pen.soft(Pen.oval(Vector2(471,547),Vector2(78,12)),Color("8eae73"))
		Pen.dot(Vector2(466,515),18,Color("e7b175"),1.5)
		for x in [451,481]:
			Pen.dot(Vector2(x,499),8,Color("e7b175"),1.5)
		Pen.dot(Vector2(460,513),2,Color("39484c"),0)
		Pen.dot(Vector2(472,513),2,Color("39484c"),0)
		Pen.arc(Vector2(466,520),5,0,PI,Color("6b5346"),2)
	else:
		Pen.pline(PackedVector2Array([Vector2(482,472),Vector2(456,506),Vector2(493,521),Vector2(470,558)]),Color("9aabad"),3)
		Pen.line(Vector2(458,506),Vector2(411,491),Color("9aabad"),2)
	Pen.disc(Vector2(550,565),2,Color("9bcaa4") if good else Color("b5705b"))


func _kitchen() -> void:
	var good := repaired.has("kitchen")
	var color := Color("7b9e94") if good else Color("928e7f")
	_box(Rect2(58,533,235,102),5,color)
	_box(Rect2(52,522,248,15),4,Color("eee3cc") if good else Color("aaa18e"))
	for x in [62,140,218]:
		_box(Rect2(x,545,69,81),3,color.darkened(0.08))
		Pen.line(Vector2(x+48,556),Vector2(x+59,556),Color("ddcdb0"),3)
	Pen.blob(Pen.oval(Vector2(103,520),Vector2(29,9)),Color("637b7e"),2)
	Pen.pline(PackedVector2Array([Vector2(112,518),Vector2(112,494),Vector2(98,491),Vector2(94,499)]),Color("c4ceca"),5)
	_box(Rect2(215,505,72,20),3,Color("485257"))
	for x in [232,270]:
		Pen.ring(Vector2(x,512),7,Color("b4b7a8"),2)
	if good:
		_box(Rect2(165,501,25,21),4,Color("f1dca9"))
		Pen.arc(Vector2(193,510),6,-PI/2,PI/2,Color("f1dca9"),3)
	else:
		Pen.line(Vector2(153,565),Vector2(185,597),Color("6f7467"),2)


func _sofa() -> void:
	var good := repaired.has("sofa")
	var color := Color("749787") if good else Color("898879")
	_box(Rect2(68,708,201,92),18,color.darkened(0.12))
	_box(Rect2(71,752,197,60),14,color)
	for x in [62,248]:
		_box(Rect2(x,734,30,83),12,color.lightened(0.08))
	for x in [90,139,188]:
		_box(Rect2(x,754,49,45),8,color.lightened(0.08))
	for x in [79,251]:
		Pen.line(Vector2(x,817),Vector2(x,831),Color("5a4e42"),6)
	if good:
		_box(Rect2(99,726,43,42),8,Color("e2b083"))
		_box(Rect2(192,725,40,40),8,Color("e7d9b3"))
	else:
		Pen.pline(PackedVector2Array([Vector2(114,744),Vector2(133,751),Vector2(121,765)]),Color("534f43"),3)
		_box(Rect2(201,769,25,21),2,Color("b3a98d"))


func _bed() -> void:
	var good := repaired.has("bed")
	_box(Rect2(58,860,222,104),10,Color("a38363") if good else Color("746a5e"))
	_box(Rect2(66,871,205,81),7,Color("f5e7cb") if good else Color("b4ac94"))
	_box(Rect2(71,878,48,64),10,Color("fff5db") if good else Color("c5bca6"))
	_box(Rect2(129,872,142,81),5,Color("d99c7b") if good else Color("918f7b"))
	for x in range(145,270,25):
		Pen.line(Vector2(x,879),Vector2(x,945),Color(1,1,1,0.1),2)
	for x in [67,265]:
		Pen.line(Vector2(x,959),Vector2(x,985),Color("625344"),8)
	if not good:
		_box(Rect2(207,908,27,24),2,Color("b5a994"))


func _bathroom() -> void:
	_box(Rect2(464,654,210,339),5,Color("bec5ba"))
	for y in range(662,990,38):
		Pen.line(Vector2(472,y),Vector2(668,y),Color("a0aca5"),1)
	for x in range(474,670,38):
		Pen.line(Vector2(x,659),Vector2(x,990),Color("a0aca5"),1)
	Pen.line(Vector2(464,654),Vector2(464,994),Color("dfd7c4"),10)
	Pen.text(ThemeDB.fallback_font,Vector2(487,682),"ВАННАЯ",15,Color("536d69"))
	var good := repaired.has("bath")
	_box(Rect2(487,748,173,68),22,Color("edf0d9") if good else Color("a8aca0"))
	_box(Rect2(482,739,181,21),9,Color("fff5dd") if good else Color("bdbca9"))
	Pen.pline(PackedVector2Array([Vector2(505,739),Vector2(505,716),Vector2(522,716),Vector2(522,726)]),Color("718a8c"),6)
	if good:
		Pen.line(Vector2(530,745),Vector2(640,745),Color("a7d5d5"),7)
	else:
		Pen.soft(Pen.oval(Vector2(526,779),Vector2(21,10)),Color("9c7b58"))
	good = repaired.has("toilet")
	_box(Rect2(603,866,45,53),8,Color("f6efdb") if good else Color("abac9a"))
	_box(Rect2(589,936,40,38),7,Color("dddcca") if good else Color("969d91"))
	Pen.blob(Pen.oval(Vector2(606,929),Vector2(40,24)),Color("fbf5e3") if good else Color("bfc0ac"),2)
	Pen.blob(Pen.oval(Vector2(606,924),Vector2(28,14)),Color("a3bfbc") if good else Color("7d8a7e"),1)
	Pen.line(Vector2(631,880),Vector2(639,880),Color("849b97"),3)


func _box(rect: Rect2, radius: float, color: Color) -> void:
	Pen.blob(Pen.rrect(rect,radius),color,1.5,Color("4b5148"))
