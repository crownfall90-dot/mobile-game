extends Control

var _canvas: Control
var _room: HomeArt
var _family: FamilyHero
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
	_label("Vita",Rect2(34,43,400,72),56,Color("fff0ce"))
	_label("МАЛЕНЬКИЕ ШАГИ К СЧАСТЬЮ",Rect2(38,111,620,32),18,Color("a8c3be"))
	var settings := UiKit.button("Настройки", &"secondary")
	settings.position = Vector2(483,60)
	settings.custom_minimum_size = Vector2(199,66)
	settings.size = Vector2(199,66)
	settings.add_theme_font_size_override("font_size",23)
	settings.pressed.connect(func() -> void: Router.popup(&"settings"))
	_canvas.add_child(settings)
	_label("АКТ 1  /  НАША КВАРТИРА",Rect2(38,173,460,28),21,Color("e7d9b6"))
	_label("%d / %d" % [Home.completed(),10],Rect2(564,168,120,38),25,Color("fff0ce"))
	var progress := ProgressBar.new()
	progress.position = Vector2(38,214)
	progress.size = Vector2(644,9)
	progress.max_value = 10
	progress.value = Home.completed()
	progress.show_percentage = false
	_canvas.add_child(progress)
	_room = HomeArt.new()
	for task in Home.TASKS:
		if Profile.flag("home."+task.id) and task.id != _repair:
			_room.repaired.append(task.id)
	_canvas.add_child(_room)
	_family = FamilyHero.new()
	_family.stage = Home.stage()
	_family.setup(Vector2(363,867),false)
	_family.scale = Vector2(1.5,1.5)
	_canvas.add_child(_family)
	var shop := UiKit.button("Магазин  ·  %d монет" % Profile.coins(), &"secondary")
	shop.position = Vector2(348,1190)
	shop.custom_minimum_size = Vector2(334,60)
	shop.size = Vector2(334,60)
	shop.add_theme_font_size_override("font_size",22)
	shop.pressed.connect(func() -> void:
		var popup := Router.popup(&"shop")
		popup.closed.connect(func(result: Variant) -> void:
			if result == true:
				Router.go(&"hub")))
	_canvas.add_child(shop)
	_label("★ %d  ·  Акт 1" % Profile.stars_total(),Rect2(38,1200,285,38),23,Color("edcf88"))
	var task := Home.next_task()
	if task.is_empty() or not Game.has_level(str(task.get("level",""))):
		_label("Здесь живёт счастье",Rect2(38,1050,644,52),34,Color("fff0ce"))
		_label("Вы подарили семье уютный дом.",Rect2(38,1110,644,70),25,Color("c3d5ca"))
		_family.celebrate()
	else:
		_label(task.title,Rect2(38,1050,644,49),32,Color("fff0ce"))
		_label(task.text,Rect2(38,1105,644,64),24,Color("c3d5ca"))
		
		var rect: Rect2 = HomeArt.SLOTS[task.id]
		var target := Button.new()
		target.position = rect.position
		target.size = rect.size
		target.flat = true
		target.tooltip_text = "Починить: " + task.name
		target.pressed.connect(_play)
		_canvas.add_child(target)
		_button = UiKit.button("Починить", &"primary")
		_button.position = Vector2(clampf(rect.get_center().x-90,40,500),rect.position.y-51)
		_button.custom_minimum_size = Vector2(180,60)
		_button.size = Vector2(180,60)
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
	_family.celebrate()
	Sfx.play(&"restore")
	Sfx.haptic(40)
	var fx := Fx.new()
	_room.add_child(fx)
	fx.burst(HomeArt.SLOTS[_repair].get_center(),Color("ffe5a3"),25,200,5,300,0.9)
	Router.toast("Дома стало немного счастливее")
	await get_tree().create_timer(0.9).timeout
	_room.highlight = str(Home.next_task().get("id","")) if Home.completed() < 10 else ""
	_room.queue_redraw()


func _play() -> void:
	var task := Home.next_task()
	if not task.is_empty() and not Router.is_busy():
		Router.go(&"game",{"id":task.level})


func _process(delta: float) -> void:
	_time += delta
	if _button:
		_button.modulate = Color.WHITE.lerp(Color("ffdc95"),(sin(_time*3.0)+1.0)*0.15)


func _layout() -> void:
	if _canvas == null:
		return
	var view := get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var window := DisplayServer.window_get_size()
	var top := maxf(0,safe.position.y)*view.y/maxf(1,window.y)
	var k := minf(view.x/720.0,(view.y-top)/1280.0)
	_canvas.scale = Vector2(k,k)
	_canvas.position = Vector2((view.x-720*k)*0.5,top+(view.y-top-1280*k)*0.5)


func _label(text: String, rect: Rect2, px: int, color: Color) -> Label:
	var label := UiKit.label(text,px,color)
	label.position = rect.position
	label.size = rect.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_canvas.add_child(label)
	return label
