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
var _success := VBoxContainer.new()
var _heading: Label

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
	_heading = UiKit.body("Момент сохранён: " + str(context.get("summary", "")), 25, UiKit.GOLD)
	_heading.custom_minimum_size.x = 500
	_body.add_child(_heading)
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
					_heading.text = "Момент сохранён: " + str(_captured.get("summary", ""))
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
	_success.add_theme_constant_override("separation", 20)
	content.add_child(_success)
	var check := UiKit.label("✓", 80, UiKit.GOLD)
	check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_child(check)
	var title := UiKit.body("Сообщение отправлено", 30, UiKit.GOLD)
	title.custom_minimum_size.x = 500
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_child(title)
	var thanks := UiKit.body("Спасибо! Отзыв получен разработчиками.\n\nЕсли это был баг или вылет, техническая информация поможет найти причину.", 25)
	thanks.custom_minimum_size.x = 500
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_success.add_child(thanks)
	var done := UiKit.button("Готово")
	_success.add_child(done)
	done.pressed.connect(close)
	var again := UiKit.button("Написать ещё", &"secondary")
	again.add_theme_font_size_override("font_size", 22)
	again.custom_minimum_size = Vector2(300, 60)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_success.add_child(again)
	again.pressed.connect(_write_again)
	_success.hide()
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
	if Reports.feedback_busy or _success.visible:
		return
	if not Reports.save_feedback(KINDS[_kind.selected], _text.text, _device.button_pressed):
		_status.text = "Текст пока только в памяти. Освободи место на телефоне."
	_update()

func _submit() -> void:
	if _closing or Reports.feedback_busy or _success.visible:
		return
	_text.release_focus()
	_save()
	Reports.send_feedback()
	_status.text = Reports.feedback_message
	_update()

func _finished(ok: bool, message: String) -> void:
	if _closing:
		return
	_status.text = message
	if ok:
		_scroll.hide()
		_status.hide()
		_send.hide()
		_success.show()
		set_title("Отправлено")
		_layout.call_deferred()
	_update()


func _write_again() -> void:
	if _closing:
		return
	Reports.new_feedback(_captured)
	_heading.text = "Момент сохранён: " + str(_captured.get("summary", ""))
	_text.set_block_signals(true)
	_text.text = ""
	_text.set_block_signals(false)
	_kind.selected = 0
	_device.set_pressed_no_signal(true)
	_success.hide()
	_scroll.show()
	_status.show()
	_status.text = ""
	_send.show()
	set_title("Написать нам")
	_refresh_preview()
	_update()
	_layout.call_deferred()


func _exit_tree() -> void:
	if Reports.feedback_finished.is_connected(_finished):
		Reports.feedback_finished.disconnect(_finished)

func _update() -> void:
	var busy := Reports.feedback_busy
	_send.disabled = busy or _text.text.length() > 1500 or Reports.feedback_draft.is_empty()
	_send.text = "Отправляем…" if busy else "Отправить разработчикам"
	_text.editable = not busy
	_kind.disabled = busy
	_device.disabled = busy
