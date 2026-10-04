extends SceneTree
## Энергия: стоимость, восстановление, защита от перевода часов, реклама, UI-ворота.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var profile: Node = root.get_node("Profile")
	var was: bool = profile.volatile
	var saved: Dictionary = profile.data.duplicate(true)
	profile.volatile = true
	profile.data = profile.defaults()
	var t := 1_000_000.0
	assert(Energy.current(t) == 5 and Energy.seconds_to_next(t) == 0)
	assert(Energy.cost("home_01") == 2 and Energy.can_play("home_01", t))
	assert(Energy.spend("home_01", t) == 2 and Energy.current(t) == 3)
	assert(Energy.spend("home_01", t) == 2 and Energy.current(t) == 1)
	assert(not Energy.can_play("home_01", t))
	assert(Energy.spend("home_01", t) == 1 and Energy.current(t) == 0)
	assert(Energy.seconds_to_next(t) == 600)
	assert(Energy.seconds_until("home_01", t) == 1200)
	assert(Energy.current(t + 599) == 0 and Energy.current(t + 600) == 1)
	assert(Energy.can_play("home_01", t + 1200) and Energy.current(t + 1200) == 2)
	assert(Energy.current(t + 99999) == 5 and Energy.seconds_to_next(t + 99999) == 0)
	# часы назад ничего не дают, и таймер не «воскресает»
	assert(Energy.current(t - 5000) == 0 and Energy.seconds_to_next(t - 5000) == 600)
	# частичный прогресс сохраняется при списании
	Energy.grant(3, t + 700)           # 1 за время + 3 = 4
	assert(Energy.current(t + 700) == 4)
	assert(Energy.seconds_to_next(t + 700) == 500)
	Energy.grant(9, t + 700)
	assert(Energy.current(t + 700) == 5)
	# мусор в сохранении не ломает
	profile.data["energy"] = {"n": "x", "t": "y"}
	assert(Energy.current(t) in range(0, 6))
	profile.data["energy"] = {"n": 99, "t": -5}
	assert(Energy.current(t) == 5)
	assert(Energy.format_wait(75) == "1:15")
	# реклама: только место energy_refill и только в отладке/тесте
	var mon: Node = root.get_node("Monetization")
	assert(not mon.rewarded_available(&"skip_level"))
	assert(mon.rewarded_available(&"energy_refill") == mon.test_ads())
	profile.volatile = was
	profile.data = saved
	print("ENERGY OK: cost, regen, clock rewind, grant, junk save, ad placement")
	quit()
