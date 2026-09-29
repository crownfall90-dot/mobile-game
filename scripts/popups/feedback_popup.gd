extends UiPopup
## The moment is captured before pausing. Sending and retries keep that same moment.
const KINDS := ["bug", "crash", "idea"]
var _kind := OptionButton.new()
var _text := TextEdit.new()
var _device: UiKit.Toggle
var _status: Label
var _send: Button
var _scroll := ScrollContainer.new()
var _body := VBoxContainer.new()
var _preview := TextEdit.new()
var _captured: Dictionary
var _keyboard := -1

func open(args: Dictionary) -> void:
	set_title("Написать нам")
	content.add_theme_constant_override("separation", 12)
	_captured = args["captured"] if args.has("captured") else Reports.capture_feedback()
	Reports.begin_feedback(_captured)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(500, 500)
	content.add_child(_scroll)
	_body.custom_minimum_size.x = 500
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 14)
	_scroll.add_child(_body)
	var context: Dictionary = Reports.feedback_draft.get("context", _captured)
	var heading := UiKit.body("Момент сохранён: " + str(context.get("summary", "")), 25, UiKit.GOLD)
	heading.custom_minimum_size.x = 500
	_body.add_child(heading)
	var note := UiKit.body("Игра на паузе. Место и событие уже записаны — можно сразу отправить или добавить описание.", 21)
	note.custom_minimum_size.x = 500
	_body.add_child(note)
	for title in ["Баг — что-то работает неправильно", "Вылет — игра закрылась", "Улучшение — моя идея"]:
		_kind.add_item(title)
	_kind.selected = maxi(0, KINDS.find(Reports.feedback_draft.get("kind", "bug")))
	_kind.custom_minimum_size = Vector2(500, 64)
	_kind.add_theme_font_size_override("font_size", 24)
	_kind.add_theme_stylebox_override("normal", UiKit.panel_box(&"card"))
	_kind.add_theme_stylebox_override("hover", UiKit.panel_box(&"card"))
	_kind.add_theme_stylebox_override("focus", UiKit.panel_box(&"card"))
	_body.add_child(_kind)
	_text.placeholder_text = "Что заметил? Что ожидал увидеть? Можно оставить пустым. До 1500 знаков."
	_text.custom_minimum_size = Vector2(500, 180)
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_size_override("font_size", 25)
	_text.add_theme_color_override("font_color", UiKit.TEXT)
	_text.add_theme_color_override("font_placeholder_color", UiKit.TEXT_MUTED)
	_text.add_theme_stylebox_override("normal", UiKit.panel_box(&"card"))
	_text.add_theme_stylebox_override("focus", UiKit.panel_box(&"card"))
	_text.text = str(Reports.feedback_draft.get("text", ""))
	_body.add_child(_text)
	_device = UiKit.toggle("Приложить технические данные", bool(Reports.feedback_draft.get("device", true)), func(_on: bool) -> void:
		_save()
		_refresh_preview())
	_device.add_theme_font_size_override("font_size", 23)
	_body.add_child(_device)
	var info := UiKit.body("Телефон, графика, прогресс, последние действия и ошибки. Можно посмотреть перед отправкой.", 20)
	info.custom_minimum_size.x = 500
	_body.add_child(info)
	var inspect := UiKit.button("Посмотреть, что отправится", &"secondary")
	inspect.add_theme_font_size_override("font_size", 23)
	_body.add_child(inspect)
	_preview.custom_minimum_size = Vector2(500, 200)
	_preview.editable = false
	_preview.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_preview.add_theme_font_size_override("font_size", 18)
	_refresh_preview()
	_preview.visible = false
	_body.add_child(_preview)
	inspect.pressed.connect(func() -> void: _preview.visible = not _preview.visible)
	if not str(Reports.feedback_draft.get("text", "")).is_empty() or Reports.feedback_draft.has("packet"):
		var new_moment := UiKit.button("Новый отзыв о текущем моменте", &"secondary")
		new_moment.add_theme_font_size_override("font_size", 22)
		_body.add_child(new_moment)
		new_moment.pressed.connect(func() -> void:
			var confirm := Router.popup(&"confirm", {"title": "Новый отзыв?", "text": "Текущий черновик будет заменён. Сохранённый при открытии момент останется новым местом отзыва.", "ok": "Новый отзыв", "cancel": "Оставить черновик"})
			confirm.closed.connect(func(yes: Variant) -> void:
				if yes == true and not Reports.feedback_busy:
					Reports.new_feedback(_captured)
					_kind.selected = 0
					_text.text = ""
					heading.text = "Момент сохранён: " + str(_captured.get("summary", ""))
					_refresh_preview()))
	var privacy := UiKit.body("Отзывы публичные в GitHub. Не пиши пароли и личные данные. После неожиданного закрытия при следующем запуске отдельно отправится отчёт о сбое.", 20)
	privacy.custom_minimum_size.x = 500
	_body.add_child(privacy)
	_status = UiKit.body(Reports.feedback_message, 21)
	_status.custom_minimum_size.x = 500
	content.add_child(_status)
	_send = UiKit.button("Отправить разработчикам")
	_send.add_theme_font_size_override("font_size", 26)
	content.add_child(_send)
	_send.pressed.connect(_submit)
	_kind.item_selected.connect(func(_index: int) -> void: _save())
	_text.text_changed.connect(_save)
	Reports.feedback_finished.connect(_finished)
	_save()
	_update()
	_layout.call_deferred()

func _refresh_preview() -> void:
	var context: Dictionary = Reports.feedback_draft.get("context", _captured)
	_preview.text = str(context.get("context", ""))
	if _device.button_pressed:
		_preview.text += "\n\n" + str(context.get("diagnostics", ""))

func _keyboard_height() -> int:
	return DisplayServer.virtual_keyboard_get_height() if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) else 0

func _process(_delta: float) -> void:
	var height := _keyboard_height()
	if height != _keyboard:
		_keyboard = height
		_layout()

func _layout() -> void:
	var inset := UiKit.safe_insets(get_viewport())
	var keyboard := maxf(0, _keyboard_height()) * size.x / maxf(1, DisplayServer.window_get_size().x)
	var available := maxf(260, size.y - inset.x - inset.y - keyboard)
	_scroll.custom_minimum_size.y = clampf(available - 340, 70, 640)
	var ms := _frame.get_combined_minimum_size()
	_frame.size = ms
	_frame.position = Vector2((size.x - ms.x) * 0.5, inset.x + maxf(26, (available - ms.y) * 0.5))

func _save() -> void:
	if not Reports.save_feedback(KINDS[_kind.selected], _text.text, _device.button_pressed):
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
		_text.set_block_signals(true)
		_text.text = ""
		_text.set_block_signals(false)
	_update()

func _update() -> void:
	var busy := Reports.feedback_busy
	_send.disabled = busy or _text.text.length() > 1500 or Reports.feedback_draft.is_empty()
	_send.text = "Отправляем…" if busy else "Отправить разработчикам"
	_text.editable = not busy
	_kind.disabled = busy
	_device.disabled = busy
