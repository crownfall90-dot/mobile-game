extends Control

const FAMILY_WORN = preload("res://art/home/family_worn.png")
const FAMILY_HAPPY = preload("res://art/home/family_happy.png")

var _canvas: Control
var _room: HomeArt
var _family: Sprite2D
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
	_label("Vita",Rect2(34,23,400,72),56,Color("fff0ce"))
	var settings := UiKit.button("Настройки", &"secondary")
	settings.position = Vector2(475,39)
	settings.custom_minimum_size = Vector2(167,56)
	settings.size = Vector2(167,56)
	settings.add_theme_font_size_override("font_size",23)
	settings.pressed.connect(func() -> void: Router.popup(&"settings"))
	_canvas.add_child(settings)
	_label("АКТ 1  /  НАША КВАРТИРА",Rect2(38,124,460,28),21,Color("e7d9b6"))
	_label("%d / %d" % [Home.completed(),10],Rect2(564,119,120,38),25,Color("fff0ce"))
	var progress := ProgressBar.new()
	progress.position = Vector2(38,165)
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
	_family = Sprite2D.new()
	_family.texture = FAMILY_HAPPY if Home.stage() >= 2 else FAMILY_WORN
	_family.centered = false
	var sprite_scale := 750.0 / _family.texture.get_height()
	_family.scale = Vector2(sprite_scale,sprite_scale)
	_family.position = Vector2(360.0 - _family.texture.get_width() * sprite_scale * 0.5,250)
	_canvas.add_child(_family)
	_canvas.move_child(_room,0)
	_canvas.move_child(_family,1)
	var top_shade := ColorRect.new()
	top_shade.color = Color(0.05,0.09,0.12,0.56)
	top_shade.position = Vector2.ZERO
	top_shade.size = Vector2(720,190)
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(top_shade)
	_canvas.move_child(top_shade,2)
	var bottom_shade := ColorRect.new()
	bottom_shade.color = Color(0.05,0.09,0.12,0.82)
	bottom_shade.position = Vector2(0,1050)
	bottom_shade.size = Vector2(720,230)
	bottom_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(bottom_shade)
	_canvas.move_child(bottom_shade,3)
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
		_label("Здесь живёт счастье",Rect2(38,1070,644,52),34,Color("fff0ce"))
		_label("Вы подарили семье уютный дом.",Rect2(38,1120,644,70),25,Color("c3d5ca"))
		_family.modulate = Color("fff0ca")
	else:
		_label(task.title,Rect2(38,1070,644,49),32,Color("fff0ce"))
		_label(task.text,Rect2(38,1120,644,64),24,Color("c3d5ca"))
		
		var screen_rect: Rect2 = HomeArt.IMAGE_SLOTS[task.id]
		var target := Button.new()
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
	if _family:
		_family.offset.y = sin(_time*1.5)*3.0
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
