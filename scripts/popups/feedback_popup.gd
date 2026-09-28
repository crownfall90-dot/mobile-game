extends UiPopup
## Manual feedback only; the player reviews public text before sending.

var _kind := OptionButton.new()
var _text := TextEdit.new()
var _device: UiKit.Toggle
var _status: Label
var _send: Button


func open(_args: Dictionary) -> void:
	set_title("Отзыв об игре")
	content.add_theme_constant_override("separation", 12)
	var note := UiKit.body("Сообщение будет видно в общей теме тестеров на GitHub. Не указывай личные данные.", 22)
	note.custom_minimum_size.x = 500
	content.add_child(note)
	_kind.add_item("Нашёл ошибку")
	_kind.add_item("Есть предложение")
	_kind.selected = 1 if Reports.feedback_draft.get("kind") == "idea" else 0
	_kind.custom_minimum_size = Vector2(500, 58)
	content.add_child(_kind)
	_text.placeholder_text = "Что произошло? Что ты нажимал? Для идеи — что хотелось бы изменить? От 10 до 1500 знаков."
	_text.custom_minimum_size = Vector2(500, 220)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 25)
	_text.add_theme_color_override("font_color", UiKit.INK)
	_text.add_theme_stylebox_override("normal", UiKit.panel_box(&"card"))
	_text.add_theme_stylebox_override("focus", UiKit.panel_box(&"card"))
	_text.text = str(Reports.feedback_draft.get("text", ""))
	content.add_child(_text)
	_device = UiKit.toggle("Добавить сведения о телефоне", bool(Reports.feedback_draft.get("device", false)), func(_on: bool) -> void: _save())
	_device.add_theme_font_size_override("font_size", 23)
	content.add_child(_device)
	var context := UiKit.body("Версия игры, экран и уровень добавятся сами. Сведения о телефоне — модель и версия системы.", 21)
	context.custom_minimum_size.x = 500
	content.add_child(context)
	_status = UiKit.body(Reports.feedback_message, 22)
	_status.custom_minimum_size.x = 500
	content.add_child(_status)
	_send = UiKit.button("Отправить")
	content.add_child(_send)
	_send.pressed.connect(_submit)
	_kind.item_selected.connect(func(_index: int) -> void: _save())
	_text.text_changed.connect(_save)
	Reports.feedback_finished.connect(_finished)
	_update()


func _save() -> void:
	if not Reports.save_feedback("idea" if _kind.selected == 1 else "bug", _text.text, _device.button_pressed):
		_status.text = "Текст пока только в памяти. Освободи место на телефоне."
	_update()


func _submit() -> void:
	_text.release_focus()
	_save()
	Reports.send_feedback()
	_status.text = Reports.feedback_message
	_update()


func _finished(ok: bool, message: String) -> void:
	_status.text = message
	if ok:
		_text.text = ""
	_update()


func _update() -> void:
	var busy := Reports.feedback_busy
	_send.disabled = busy or _text.text.strip_edges().length() < 10 or _text.text.length() > 1500
	_send.text = "Отправляем…" if busy else "Отправить"
	_text.editable = not busy
	_kind.disabled = busy
	_device.disabled = busy
