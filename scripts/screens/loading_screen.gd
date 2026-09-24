extends Control

var _progress: ProgressBar
var _elapsed := 0.0
var _done := false


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
	col.custom_minimum_size.x = 480
	col.add_theme_constant_override("separation",24)
	center.add_child(col)
	var icon := TextureRect.new()
	icon.texture = preload("res://icon.svg")
	icon.custom_minimum_size = Vector2(190,190)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(icon)
	for pair in [["Vita",88],["Каждой семье нужен дом",28],["Помоги маме и дочке начать заново",21]]:
		var label := UiKit.label(pair[0],pair[1],Color("fff0ce"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size.y = 12
	_progress.show_percentage = false
	col.add_child(_progress)


func _process(delta: float) -> void:
	if _progress == null or _done:
		return
	_elapsed += delta
	var ready_audio := Sfx.prepare(4)
	_progress.value = minf(95,_elapsed/1.6*100)
	if ready_audio and _elapsed >= 1.6:
		_done = true
		_progress.value = 100
		Router.go(&"hub")
