extends UiPopup
## Что сделать у вещи: бытовые сценки (data/activities.json) и игра заново ради звёзд.
## args: {title, acts: [[индекс, подпись], ...], level: id уровня или "", best: звёзды 0..3}.
## Закрывается индексом сценки (int), "replay" или null.


func open(args: Dictionary) -> void:
	set_title(str(args.get("title", "Что будем делать?")))
	var acts: Array = args.get("acts", [])
	for a: Array in acts:
		var idx: int = int(a[0])
		var b := UiKit.button(str(a[1]))
		content.add_child(b)
		b.pressed.connect(func() -> void: close(idx))
	var level := str(args.get("level", ""))
	if level == "":
		return
	# вещь уже починена: лучшие звёзды крупно, под ними — сыграть ещё раз ради недостающих
	var best := int(args.get("best", 0))
	var card := UiKit.panel(&"inset")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var head := UiKit.label("Лучший результат", 26, UiKit.TEXT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var stars := UiKit.star_row(best, 96)
	stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(stars)
	var sub := UiKit.body("Все звёзды собраны!" if best >= 3 else "Ещё звезда — ещё монеты", 22)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	content.add_child(card)
	var replay := UiKit.button("Сыграть ещё раз", &"secondary" if not acts.is_empty() else &"primary", &"restart")
	content.add_child(replay)
	replay.pressed.connect(func() -> void: close("replay"))
