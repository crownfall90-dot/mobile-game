extends UiPopup


func open(_args: Dictionary) -> void:
	set_title("Настройки")
	for entry in [["sfx","Звуки"],["music","Музыка"],["vibration","Вибрация"],["low_fx","Меньше эффектов"]]:
		# крупный переключатель UiKit: системный CheckButton на телефоне слишком мелкий для пальца
		var key: String = entry[0]
		var toggle := UiKit.toggle(entry[1], bool(Profile.setting(key)), func(on: bool) -> void: Profile.set_setting(key, on))
		toggle.custom_minimum_size.x = 470
		content.add_child(toggle)
	var note := UiKit.label("Vita %s · прогресс сохраняется сам" % ProjectSettings.get_setting("application/config/version", ""),21)
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
				# история заново: загрузка, пролог-новелла, первая комната
				Router.go(&"loading"))
