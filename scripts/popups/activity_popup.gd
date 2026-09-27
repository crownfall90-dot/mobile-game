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
	# вещь уже починена: головоломку можно пройти снова ради недостающих звёзд
	var best := int(args.get("best", 0))
	var note := UiKit.body("Лучший результат: %s\n%s" % ["★".repeat(best) + "☆".repeat(3 - best),
		"Все звёзды собраны — можно сыграть просто так." if best >= 3 else "Ещё звезда — ещё монеты."],
		22, UiKit.TEXT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(note)
	var replay := UiKit.button("Сыграть ещё раз", &"secondary" if not acts.is_empty() else &"primary")
	content.add_child(replay)
	replay.pressed.connect(func() -> void: close("replay"))
