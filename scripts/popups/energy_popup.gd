extends UiPopup
## Энергия: сколько есть, когда вернётся, «реклама» вместо ожидания.
## Результат close(): &"refilled" — энергии хватает на попытку; иначе null.

var _level := ""
var _left: Label
var _wait: Label
var _ad: Button
var _watching := false


func open(args: Dictionary) -> void:
	_level = str(args.get("level", ""))
	set_title("Энергия мамы")
	_left = UiKit.label("", 34)
	content.add_child(_left)
	_wait = UiKit.body("", 24)
	_wait.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wait.custom_minimum_size.x = 470
	content.add_child(_wait)
	if Monetization.rewarded_available(&"energy_refill"):
		var test := " (тест)" if Monetization.test_ads() else ""
		_ad = UiKit.button("Реклама: +%d энергии%s" % [Energy.AD_GRANT, test], &"primary")
		content.add_child(_ad)
		_ad.pressed.connect(_watch)
	var ok := UiKit.button("Подожду", &"secondary")
	content.add_child(ok)
	ok.pressed.connect(func() -> void: close())
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	_refresh()


func _refresh() -> void:
	var n := Energy.current()
	_left.text = "Энергия: %d из %d" % [n, Energy.MAX]
	var need := 0 if _level == "" else Energy.cost(_level)
	var text := "Одна попытка ремонта стоит %d. Единица возвращается за %d минут." % [
		need if need > 0 else Energy.COST, int(Energy.REGEN / 60.0)]
	var next := Energy.seconds_to_next()
	if next > 0:
		text += "\nСледующая через %s." % Energy.format_wait(next)
	if _level != "" and not Energy.can_play(_level):
		text += "\nНа эту попытку хватит через %s." % Energy.format_wait(Energy.seconds_until(_level))
	_wait.text = text
	if _ad and not _watching:
		_ad.disabled = n >= Energy.MAX
	if _level != "" and Energy.can_play(_level) and not _watching:
		close(&"refilled")


func _watch() -> void:
	if _watching:
		return
	_watching = true
	_ad.disabled = true
	_ad.text = "Смотрим…"
	Monetization.rewarded_finished.connect(_on_ad, CONNECT_ONE_SHOT)
	Monetization.show_rewarded(&"energy_refill")


func _on_ad(placement: StringName, completed: bool) -> void:
	_watching = false
	if placement != &"energy_refill":
		return
	if completed:
		Energy.grant(Energy.AD_GRANT)
		Sfx.play(&"ui_tap")
	elif is_instance_valid(_ad):
		_ad.disabled = false
		_ad.text = "Реклама недоступна"
	_refresh()
