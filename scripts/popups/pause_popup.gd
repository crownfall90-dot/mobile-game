extends UiPopup


func open(_args: Dictionary) -> void:
	set_title("Небольшая пауза")
	get_tree().paused = true
	closed.connect(func(_v: Variant) -> void: get_tree().paused = false)
	for entry in [["Продолжить","resume"],["Начать заново","restart"],["Настройки","settings"],["Вернуться домой","home"]]:
		var button := UiKit.button(entry[0], &"secondary" if entry[1] == "restart" else &"primary")
		content.add_child(button)
		button.pressed.connect(func() -> void:
			if entry[1] == "resume":
				close()
			elif entry[1] == "restart":
				close("restart")   # экран уровня перезапускает попытку
			elif entry[1] == "settings":
				Router.popup(&"settings")
			else:
				get_tree().paused = false
				Router.go(&"hub"))
