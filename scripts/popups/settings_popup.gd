extends UiPopup


func open(_args: Dictionary) -> void:
	set_title("Настройки")
	for entry in [["sfx","Звуки"],["music","Музыка"],["vibration","Вибрация"],["low_fx","Меньше эффектов"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[1]
		toggle.custom_minimum_size = Vector2(470,68)
		toggle.add_theme_font_size_override("font_size",28)
		toggle.button_pressed = bool(Profile.setting(entry[0]))
		toggle.toggled.connect(func(on: bool) -> void: Profile.set_setting(entry[0],on))
		content.add_child(toggle)
	var note := UiKit.label("Vita · История одной семьи\nПрогресс сохраняется автоматически",21)
	content.add_child(note)
	var ok := UiKit.button("Готово")
	content.add_child(ok)
	ok.pressed.connect(func() -> void: Profile.flush(); close())
