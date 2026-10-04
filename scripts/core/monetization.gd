extends Node
## Автозагрузка "Monetization": места под рекламу и покупки без SDK (DESIGN §14).
## В версии 1.0 всё недоступно, поэтому кнопки, которые показываются только
## при rewarded_available() == true, не видны. Интернет-разрешения нет.

signal rewarded_finished(placement: StringName, completed: bool)

## Зарезервированные места для рекламы за награду.
const PLACEMENTS: Array[StringName] = [&"double_coins", &"free_hint", &"skip_level", &"daily_double", &"energy_refill"]
## Зарезервированные товары.
const PRODUCTS: Array[StringName] = [&"no_ads", &"starter_pack"]


## Пока нет рекламного SDK: тестовая «реклама» за энергию только в отладочной сборке
## (или VITA_TEST_ADS=1). Остальные места остаются недоступными.
func test_ads() -> bool:
	return OS.has_feature("debug") or OS.get_environment("VITA_TEST_ADS") == "1"


func rewarded_available(placement: StringName) -> bool:
	return placement == &"energy_refill" and test_ads()


## Без SDK заканчивается без награды; сигнал идёт отложенно, после подписки вызывающего.
## Тестовая энергия-реклама «просматривается» 1,5 с и засчитывается.
func show_rewarded(placement: StringName) -> void:
	if rewarded_available(placement):
		get_tree().create_timer(1.5).timeout.connect(
			func() -> void: rewarded_finished.emit(placement, true))
		return
	rewarded_finished.emit.call_deferred(placement, false)


func iap_available() -> bool:
	return false


func purchase(_product_id: String) -> void:
	pass
