extends UiPopup


func open(args: Dictionary) -> void:
	set_title(str(args.get("title","Выйти из Vita?")))
	content.add_child(UiKit.label(str(args.get("text","Семья будет ждать тебя дома.")),26))
	var yes := UiKit.button(str(args.get("ok","Выйти")))
	content.add_child(yes)
	yes.pressed.connect(func() -> void: close(true))
	var no := UiKit.button(str(args.get("cancel","Остаться")),&"secondary")
	content.add_child(no)
	no.pressed.connect(func() -> void: close(false))
