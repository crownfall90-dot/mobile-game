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
	var reset := UiKit.button("Сбросить весь прогресс",&"danger")
	content.add_child(reset)
	reset.pressed.connect(_confirm_reset)
	var ok := UiKit.button("Готово")
	content.add_child(ok)
	ok.pressed.connect(func() -> void: Profile.flush(); close())


func _confirm_reset() -> void:
	var confirm := Router.popup(&"confirm",{
		"title":"Начать заново?",
		"text":"Ремонты, монеты, звёзды и покупки будут удалены безвозвратно.",
		"ok":"Сбросить прогресс",
		"cancel":"Отмена",
	})
	if confirm:
		confirm.closed.connect(func(yes: Variant) -> void:
			if yes == true:
				Profile.reset_progress()
				Profile.flush()
				Router.go(&"hub"))
