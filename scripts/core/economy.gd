extends Node
## Автозагрузка "Economy": правила наград и покупок (data/economy.json, data/catalog.json).
## Пока заглушка с окончательными сигнатурами: тела заполняет поток Meta.
## Economy меняет Profile; Profile сам никаких правил не знает.

signal granted(breakdown: Dictionary)

const HINT_COINS := 60
const CHEST_EVERY := 5


## result: {won, stars, pieces, pieces_total, coins_pieces, gems, relic, first_try}.
## Уровень уже записан через Profile.record_result: first_clear и new_stars берём
## из result, иначе из Profile.last_record; если записи не было, пишем сами.
func level_reward(level_id: String, result: Dictionary, _mods: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = Profile.last_record
	if result.has("first_clear"):
		rec = result
	elif rec.get("id", "") != level_id:
		rec = Profile.record_result(level_id, int(result.get("stars", 0)))
	Profile.last_record = {}
	var coins := int(result.get("coins_pieces", 0))
	Profile.add_coins(coins, "level")
	var breakdown := {
		"lines": [{"key": "coins", "amount": coins}],
		"total": coins,
		"new_stars": int(rec.get("new_stars", 0)),
		"first_clear": bool(rec.get("first_clear", false)),
		"chest_ready": false,
		"streak": 0,
		"floor_completed": "",
		"grants": [],
	}
	granted.emit(breakdown)
	return breakdown


## Счётчик неудач (Profile.add_fail) ведёт GameScreen; здесь только статистика.
func level_lost(level_id: String, reason: String) -> void:
	Profile.stat_inc("lost.%s.%s" % [level_id, reason])


## x: сколько платных побед накоплено, y: сколько нужно для сундука.
func chest_progress() -> Vector2i:
	return Vector2i(int(Profile.data.get("chest", 0)), CHEST_EVERY)


func open_chest() -> Dictionary:
	return {"coins": 0, "hints": 0, "grants": []}


func outfit(_id: String) -> Dictionary:
	return {}


func outfits() -> Array:
	return []


func familiars() -> Array:
	return []


func price(_item_id: String) -> int:
	return 0


func buy(_item_id: String) -> bool:
	return false


func unlock_reason(_item_id: String) -> String:
	return ""


func lab_objects() -> Array:
	return []


func next_restore() -> String:
	return ""


func can_restore(_obj_id: String) -> bool:
	return false


func restore(_obj_id: String) -> Dictionary:
	return {}


func hint_cost(_level_id: String) -> Dictionary:
	return {"free": false, "potions": Profile.hints(), "coins": HINT_COINS}


## Тратит зелье-подсказку, а если их нет — монеты.
func take_hint(_level_id: String) -> bool:
	return Profile.spend_hint() or Profile.spend_coins(HINT_COINS, "hint")


func can_skip(_level_id: String) -> bool:
	return false


func skip(_level_id: String) -> bool:
	return false


func daily_state() -> Dictionary:
	return {"slot": 0, "cycle": 0, "can_claim": false, "rewards": []}


func claim_daily() -> Dictionary:
	return {}


func potion_of_day() -> Dictionary:
	return {"available": false, "level_id": "", "done_today": false}


## Новые страницы Гримуара по событию уровня (монеты уже начислены).
func discover_from_event(_id: StringName, _info: Dictionary) -> Array:
	return []


func badges() -> Dictionary:
	return {"lab": false, "wardrobe": false, "daily": false, "grimoire": false}


## Сообщения при запуске (сова, «с возвращением») для тостов.
func on_app_open() -> Array:
	return []
