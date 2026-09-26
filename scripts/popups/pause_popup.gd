extends UiPopup


func open(args: Dictionary) -> void:
	set_title("Небольшая пауза")
	# за что звёзды и сколько монет даст уровень
	for key in ["stars", "reward"]:
		if str(args.get(key, "")) != "":
			var l := UiKit.body(str(args[key]), 24, UiKit.GOLD if key == "stars" else UiKit.TEXT)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size.x = 500
			content.add_child(l)
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
