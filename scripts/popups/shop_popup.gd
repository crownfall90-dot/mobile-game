extends UiPopup
## Магазин уюта: карточка на каждую вещь — картинка, название, что она даёт и цена.
## Купленная вещь сразу появляется в квартире: hub получает {"bought": id} и показывает её.


class Preview extends Control:
	var id := ""

	func _draw() -> void:
		HomeArt.draw_decor(self, id, Rect2(Vector2(6, 6), size - Vector2(12, 12)))


func open(_args: Dictionary) -> void:
	set_title("Магазин уюта")
	var balance := UiKit.label("У вас %d монет" % Profile.coins(), 30, UiKit.GOLD)
	balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(balance)
	for item in Home.SHOP:
		content.add_child(_card(item))
	var note := UiKit.label("Монеты дают за победы. Ремонт всегда бесплатный,\nа покупки остаются с семьёй навсегда.", 19)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)


func _card(item: Dictionary) -> Control:
	var card := UiKit.panel(&"card")
	card.custom_minimum_size = Vector2(540, 128)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	card.add_child(row)
	var pic := Preview.new()
	pic.id = item.id
	pic.custom_minimum_size = Vector2(112, 112)
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)
	col.add_child(UiKit.label(item.name, 26, Color("fff0ce")))
	var text := UiKit.label(item.text, 19, Color("d9cdb8"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var owned := Profile.owns(item.id)
	var buy := UiKit.button("Есть" if owned else "%d" % item.price, &"primary" if not owned else &"secondary")
	buy.custom_minimum_size = Vector2(120, 72)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy.add_theme_font_size_override("font_size", 26)
	buy.disabled = owned or Profile.coins() < item.price
	if not owned and Profile.coins() < item.price:
		buy.tooltip_text = "Не хватает %d монет" % (item.price - Profile.coins())
	buy.pressed.connect(func() -> void:
		if Home.buy(item.id):
			Sfx.play(&"restore")
			close(item.id))
	row.add_child(buy)
	return card
