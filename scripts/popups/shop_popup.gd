extends UiPopup


func open(_args: Dictionary) -> void:
	set_title("Магазин уюта")
	var balance := UiKit.label("Монеты: %d" % Profile.coins(),28,UiKit.GOLD)
	content.add_child(balance)
	for item in Home.SHOP:
		var button := UiKit.button("", &"secondary")
		button.custom_minimum_size = Vector2(500,100)
		button.add_theme_font_size_override("font_size",24)
		button.text = "%s · %s\n%s" % [item.name,"Куплено" if Profile.owns(item.id) else str(item.price)+" монет",item.text]
		button.disabled = Profile.owns(item.id) or Profile.coins() < item.price
		content.add_child(button)
		button.pressed.connect(func() -> void:
			if Home.buy(item.id):
				Sfx.play(&"restore")
				close(true))
	content.add_child(UiKit.label("Монеты — за первую победу.\nРемонт бесплатный. Покупки остаются при переезде.",19))
