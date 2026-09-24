class_name HomeArt
extends Node2D
## Fixed drawing coordinates; the hub scales the complete room and touch targets together.

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


func _draw() -> void:
	Pen.begin(self)
	var warm := repaired.size() >= 2
	var wall := Color("e9dcc7") if repaired.has("walls") else Color("b2b2a7")
	var floor_color := Color("b98d69") if repaired.has("floor") else Color("857768")
	_box(Rect2(26,247,668,766),18,Color("263d43"))
	_box(Rect2(36,257,648,481),10,wall)
	for x in range(50,680,27):
		Pen.line(Vector2(x,262),Vector2(x,735),Color(1,1,1,0.07),2)
	_box(Rect2(36,735,648,266),3,floor_color)
	for y in range(747,1000,38):
		Pen.line(Vector2(37,y),Vector2(683,y),floor_color.darkened(0.2),2)
		for x in range(40+(y%3)*70,680,135):
			Pen.line(Vector2(x,y),Vector2(x,y+37),floor_color.darkened(0.15),1)
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
		Pen.soft(Pen.oval(Vector2(471,558),Vector2(95,31)),Color("8eae73"))
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
