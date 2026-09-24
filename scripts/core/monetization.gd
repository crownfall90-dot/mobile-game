extends Node
## Автозагрузка "Monetization": места под рекламу и покупки без SDK (DESIGN §14).
## В версии 1.0 всё недоступно, поэтому кнопки, которые показываются только
## при rewarded_available() == true, не видны. Интернет-разрешения нет.

signal rewarded_finished(placement: StringName, completed: bool)

## Зарезервированные места для рекламы за награду.
const PLACEMENTS: Array[StringName] = [&"double_coins", &"free_hint", &"skip_level", &"daily_double"]
## Зарезервированные товары.
const PRODUCTS: Array[StringName] = [&"no_ads", &"starter_pack"]


func rewarded_available(_placement: StringName) -> bool:
	return false


## Всегда заканчивается без награды; сигнал идёт отложенно, после подписки вызывающего.
func show_rewarded(placement: StringName) -> void:
	rewarded_finished.emit.call_deferred(placement, false)


func iap_available() -> bool:
	return false


func purchase(_product_id: String) -> void:
	pass
