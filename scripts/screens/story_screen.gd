extends Control
## A short, skippable three-panel transition; no damage to the old apartment save.

const CARDS := [
	["Новая глава","Мама нашла хорошую работу.\nПосле долгих трудов у семьи появился большой дом."],
	["Однажды вечером…","Пока семья была в гостях, дом ограбили.\nВещи пропали, дверь сломана. К счастью, никто не пострадал."],
	["Мы справимся вместе","Дом можно восстановить.\nГлавное — мама и дочка снова рядом."],
]
var _page := 0
var _title: Label
var _text: Label
var _art: HomeArt
var _family: FamilyHero
var _next: Button


func open(_args: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("203b42")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 620
	col.add_theme_constant_override("separation",26)
	center.add_child(col)
	_title = UiKit.label("",42,Color("fff0ce"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	var scene := Control.new()
	scene.custom_minimum_size = Vector2(620,595)
	col.add_child(scene)
	_art = HomeArt.new()
	_art.area = "house"
	_art.position = Vector2(15,-130)
	_art.scale = Vector2(0.82,0.72)
	scene.add_child(_art)
	_family = FamilyHero.new()
	_family.setup(Vector2(300,451),false)
	_family.stage = 2
	_family.scale = Vector2(1.5,1.5)
	scene.add_child(_family)
	_text = UiKit.label("",26)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(610,112)
	col.add_child(_text)
	_next = UiKit.button("Далее")
	col.add_child(_next)
	_next.pressed.connect(func() -> void:
		_page += 1
		if _page == CARDS.size():
			_finish()
		else:
			_show_card())
	var skip := UiKit.button("Пропустить историю",&"ghost")
	skip.custom_minimum_size.y = 64
	skip.add_theme_font_size_override("font_size",22)
	col.add_child(skip)
	skip.pressed.connect(_finish)
	_show_card()


func _show_card() -> void:
	_title.text = CARDS[_page][0]
	_text.text = CARDS[_page][1]
	_art.repaired.assign(["tv","light","kitchen","sofa","bed","bath","window","walls","floor","toilet"] if _page == 0 else ["window","walls","floor","toilet"])
	_art.queue_redraw()
	_family.mood = Hero.Mood.HAPPY if _page == 0 else (Hero.Mood.OOPS if _page == 1 else Hero.Mood.IDLE)
	_next.text = "Начать второй акт" if _page == 2 else "Далее"


func _finish() -> void:
	Profile.set_flag("home.moved")
	Profile.flush()
	Router.go(&"hub",{"area":"house"})
