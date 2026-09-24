extends Control

const FAMILY_WORN = preload("res://art/home/family_worn.png")
const FAMILY_HAPPY = preload("res://art/home/family_happy.png")
const FAMILY_CLOTHED = preload("res://art/home/family_clothed.png")
const REPAIR_LINES := {
	"tv":"Дочка: «Мама, мультики снова работают!»",
	"light":"Мама: «Теперь вечерами будет светло.»",
	"window":"Дочка: «Больше не дует!»",
	"bed":"Мама: «Сегодня мы выспимся.»",
	"sofa":"Дочка: «Почитаем сказку вместе?»",
	"kitchen":"Мама: «Приготовим тёплый ужин.»",
	"bath":"Дочка: «Вода снова тёплая!»",
	"toilet":"Мама: «Вот и здесь стало удобно.»",
	"walls":"Дочка: «Как красиво вокруг!»",
	"floor":"Мама: «Наш дом наконец-то уютный.»",
}

var _canvas: Control
var _room: HomeArt
var _family: Sprite2D
var _title: Label
var _act: Label
var _count: Label
var _progress: ProgressBar
var _top_shade: ColorRect
var _bottom_shade: ColorRect
var _bottom_title: Label
var _bottom_text: Label
var _stars: Label
var _settings: Button
var _shop: Button
var _target: Button
var _target_rect := Rect2()
var _repair := ""
var _button: Button
var _time := 0.0


func open(args: Dictionary) -> void:
	_repair = str(args.get("repaired", ""))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("203b42")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_canvas = Control.new()
	_canvas.size = Vector2(720,1280)
	add_child(_canvas)
	_title = _label("Vita",Rect2(505,20,180,60),48,Color("fff0ce"))
	_act = _label("АКТ 1  /  НАША КВАРТИРА",Rect2(20,52,440,28),21,Color("e7d9b6"))
	_count = _label("%d / 10 ремонтов" % Home.completed(),Rect2(20,91,270,38),23,Color("fff0ce"))
	_progress = ProgressBar.new()
	_progress.position = Vector2(20,137)
	_progress.size = Vector2(430,8)
	_progress.max_value = 10
	_progress.value = Home.completed()
	_progress.show_percentage = false
	_canvas.add_child(_progress)
	_room = HomeArt.new()
	for task in Home.TASKS:
		if Profile.flag("home."+task.id) and task.id != _repair:
			_room.repaired.append(task.id)
	_canvas.add_child(_room)
	_family = Sprite2D.new()
	_family.texture = FAMILY_CLOTHED if Home.stage() == 3 else (FAMILY_HAPPY if Home.stage() >= 2 else FAMILY_WORN)
	_family.centered = false
	var sprite_scale := 750.0 / _family.texture.get_height()
	_family.scale = Vector2(sprite_scale,sprite_scale)
	_family.position = Vector2(360.0 - _family.texture.get_width() * sprite_scale * 0.5,250)
	_canvas.add_child(_family)
	_canvas.move_child(_room,0)
	_canvas.move_child(_family,1)
	_top_shade = ColorRect.new()
	_top_shade.color = Color(0.05,0.09,0.12,0.42)
	_top_shade.size = Vector2(720,165)
	_top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_top_shade)
	_canvas.move_child(_top_shade,2)
	_bottom_shade = ColorRect.new()
	_bottom_shade.color = Color(0.05,0.09,0.12,0.78)
	_bottom_shade.position = Vector2(0,1050)
	_bottom_shade.size = Vector2(720,230)
	_bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(_bottom_shade)
	_canvas.move_child(_bottom_shade,3)
	_settings = UiKit.icon_button(&"gear","",&"glass")
	_settings.position = Vector2(614,170)
	_settings.tooltip_text = "Настройки"
	_settings.pressed.connect(func() -> void: Router.popup(&"settings"))
	_canvas.add_child(_settings)
	_shop = UiKit.icon_button(&"coin",str(Profile.coins()),&"glass")
	_shop.position = Vector2(614,270)
	_shop.tooltip_text = "Магазин · %d монет" % Profile.coins()
	_shop.pressed.connect(func() -> void:
		var popup := Router.popup(&"shop")
		popup.closed.connect(func(result: Variant) -> void:
			if result == true:
				Router.go(&"hub")))
	_canvas.add_child(_shop)
	_stars = _label("★ %d  ·  %d монет" % [Profile.stars_total(),Profile.coins()],Rect2(38,1200,350,38),23,Color("edcf88"))
	var task := Home.next_task()
	if task.is_empty() or not Game.has_level(str(task.get("level",""))):
		_bottom_title = _label("Здесь живёт счастье",Rect2(38,1070,644,52),34,Color("fff0ce"))
		_bottom_text = _label("Вы подарили семье уютный дом.",Rect2(38,1120,644,70),25,Color("c3d5ca"))
		_family.modulate = Color("fff0ca")
	else:
		var first_step := Home.completed() == 0
		_bottom_title = _label("Нажми на сломанный телевизор" if first_step else task.title,Rect2(38,1070,644,49),31,Color("fff0ce"))
		_bottom_text = _label("Спаси семью · получи монеты и звёзды" if first_step else task.text,Rect2(38,1120,644,64),24,Color("c3d5ca"))
		
		var screen_rect: Rect2 = HomeArt.IMAGE_SLOTS[task.id]
		var target := Button.new()
		_target = target
		_target_rect = screen_rect
		target.position = screen_rect.position
		target.size = screen_rect.size
		target.flat = true
		target.tooltip_text = "Починить: " + task.name
		target.pressed.connect(_play)
		_canvas.add_child(target)
		_button = UiKit.button("Починить", &"primary")
		var button_y := screen_rect.position.y-20 if task.id == "tv" else screen_rect.get_center().y-28
		_button.position = Vector2(clampf(screen_rect.get_center().x-75,18,480),clampf(button_y,195,980))
		_button.custom_minimum_size = Vector2(150,56)
		_button.size = Vector2(150,56)
		_button.add_theme_font_size_override("font_size",24)
		_button.pressed.connect(_play)
		_canvas.add_child(_button)
		_room.highlight = task.id
		if _repair != "":
			target.disabled = true
			_button.disabled = true
			_button.visible = false
			get_tree().create_timer(1.5).timeout.connect(func() -> void:
				if not is_instance_valid(target):
					return
				target.disabled = false
				_button.disabled = false
				_button.visible = true)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if _repair != "":
		_animate_repair()


func _animate_repair() -> void:
	_room.highlight = _repair
	_room.queue_redraw()
	await get_tree().create_timer(0.55).timeout
	_room.repaired.append(_repair)
	_room.queue_redraw()
	var y := _family.position.y
	var jump := create_tween()
	jump.tween_property(_family,"position:y",y-14,0.17)
	jump.tween_property(_family,"position:y",y,0.23)
	Sfx.play(&"restore")
	Sfx.haptic(40)
	var fx := Fx.new()
	_room.add_child(fx)
	fx.burst(HomeArt.IMAGE_SLOTS[_repair].get_center(),Color("ffe5a3"),25,200,5,300,0.9)
	Router.toast(REPAIR_LINES.get(_repair,"Дома стало немного счастливее"))
	await get_tree().create_timer(0.9).timeout
	_room.highlight = str(Home.next_task().get("id","")) if Home.completed() < 10 else ""
	_room.queue_redraw()


func _play() -> void:
	var task := Home.next_task()
	if not task.is_empty() and not Router.is_busy():
		Router.go(&"game",{"id":task.level})


func _process(delta: float) -> void:
	_time += delta
	if _family:
		_family.offset.y = sin(_time*1.5)*3.0
	if _button:
		_button.modulate = Color.WHITE.lerp(Color("ffdc95"),(sin(_time*3.0)+1.0)*0.35)


func _layout() -> void:
	if _canvas == null:
		return
	var view := get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	var k := view.x / 720.0
	var h := view.y / k
	var top := maxf(0,safe.position.y)*view.y/maxf(1,window.y)/k
	var bottom := maxf(0,window.y-safe.end.y)*view.y/maxf(1,window.y)/k
	_canvas.size = Vector2(720,h)
	_canvas.scale = Vector2(k,k)
	_canvas.position = Vector2.ZERO
	_room.scale.y = h / 1280.0
	_family.position.y = 250.0 * h / 1280.0
	_top_shade.size.y = top + 165
	_title.position.y = top + 20
	_act.position.y = top + 52
	_count.position.y = top + 91
	_progress.position.y = top + 137
	_settings.position.y = top + 170
	_shop.position.y = top + 270
	_bottom_shade.position.y = h - bottom - 230
	_bottom_title.position.y = h - bottom - 210
	_bottom_text.position.y = h - bottom - 160
	_stars.position.y = h - bottom - 73
	if _target:
		_target.position.y = _target_rect.position.y * _room.scale.y
		_target.size.y = _target_rect.size.y * _room.scale.y
		var button_y := _target_rect.position.y - 20 if Home.next_task().id == "tv" else _target_rect.get_center().y - 28
		_button.position.y = clampf(button_y * _room.scale.y,top + 355,h - bottom - 300)


func _label(text: String, rect: Rect2, px: int, color: Color) -> Label:
	var label := UiKit.label(text,px,color)
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_canvas.add_child(label)
	return label
