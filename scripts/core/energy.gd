class_name Energy
extends RefCounted
## Энергия мамы: попытка ремонта стоит 2 (сложные — 3), 1 единица возвращается за 10 минут.
## Хранится в Profile.data["energy"] = {n, t}; t — unix-время, с которого идёт отсчёт.
## Списывается по итогу попытки (победа или поражение), а не при старте: вылет игры
## не сжигает энергию. Лимит проверяется перед входом в уровень и перед повтором.

const MAX := 5
const COST := 2
const HARD_COST := 3
const REGEN := 600.0
const AD_GRANT := 2
const PERFECT_BONUS := 1


static func _autoload(name: String) -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(name)


static func cost(level_id: String) -> int:
	var game := _autoload("Game")
	if game == null or not game.has_level(level_id):
		return COST
	return HARD_COST if bool(game.level_meta(level_id).get("hard", false)) else COST


## Текущее состояние с учётом прошедшего времени. Перевод часов назад энергию не даёт.
static func _state(now := -1.0) -> Dictionary:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var e: Variant = _autoload("Profile").data.get("energy")
	var n := MAX
	var t := now
	if e is Dictionary:
		n = clampi(int(e.get("n", MAX)), 0, MAX)
		t = float(e.get("t", now))
	if n >= MAX:
		return {"n": MAX, "t": now}
	if t > now:
		t = now
	var gained := int((now - t) / REGEN)
	if gained > 0:
		n = mini(MAX, n + gained)
		t += gained * REGEN
	if n >= MAX:
		t = now
	return {"n": n, "t": t}


static func current(now := -1.0) -> int:
	return int(_state(now).n)


## Секунд до следующей единицы; 0 — запас полон.
static func seconds_to_next(now := -1.0) -> int:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var s := _state(now)
	if int(s.n) >= MAX:
		return 0
	return maxi(1, int(ceil(float(s.t) + REGEN - now)))


## Секунд до того момента, когда хватит на попытку.
static func seconds_until(level_id: String, now := -1.0) -> int:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var need := cost(level_id) - current(now)
	if need <= 0:
		return 0
	return seconds_to_next(now) + (need - 1) * int(REGEN)


static func can_play(level_id: String, now := -1.0) -> bool:
	return current(now) >= cost(level_id)


static func _store(n: int, t: float) -> void:
	var profile := _autoload("Profile")
	profile.data["energy"] = {"n": clampi(n, 0, MAX), "t": t}
	profile.mark_changed(&"energy")


## Итог попытки. Возвращает, сколько снято.
static func spend(level_id: String, now := -1.0) -> int:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var s := _state(now)
	var take := mini(cost(level_id), int(s.n))
	var t := now if int(s.n) >= MAX else float(s.t)
	_store(int(s.n) - take, t)
	return take


static func grant(amount: int, now := -1.0) -> void:
	if now < 0.0:
		now = Time.get_unix_time_from_system()
	var s := _state(now)
	_store(int(s.n) + amount, float(s.t))


static func format_wait(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
