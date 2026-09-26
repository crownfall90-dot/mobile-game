extends UiPopup
## Альбом: фото прабабушки из найденных кусочков и повтор просмотренных сценок-новелл.
## Закрывается id сценки, которую хотят посмотреть снова (хаб открывает новеллу), или null.
## Сценки и их названия — data/novel.json "album": [[id, название], ...]. Сценку можно смотреть,
## если она просмотрена (флаг seen.novel.<id>) или её локация уже починена (<id> = <локация>_done:
## так и у тех, кто прошёл локацию до появления сценок); остальные — «Ещё впереди».

const PHOTO := preload("res://scripts/ui/photo_card.gd")
const DATA := "res://data/novel.json"


func open(_args: Dictionary) -> void:
	set_title("Альбом")
	var photo: Control = PHOTO.new()
	photo.custom_minimum_size = Vector2(480, 370)
	photo.call(&"collect")
	content.add_child(photo)
	var n: int = photo.call(&"found")
	var caption := "Бабушка Вера и маленькая Аня" if n >= 4 \
		else "Кусочков фото: %d из 4 — ищи в починенных комнатах" % n
	var note := UiKit.body(caption, 24, UiKit.TEXT)
	note.custom_minimum_size.x = 480
	content.add_child(note)
	# цели главы: сюжет и «Праздник новоселья» — все звёзды и все покупки
	var g := goals()
	var lines := "Ремонты %d/%d · Фото %d/4 · Звёзды %d/%d · Уют %d/%d" % [g.repairs, g.repairs_total,
		n, g.stars, g.stars_total, g.items, g.items_total]
	var goal := UiKit.body(lines, 22, UiKit.GOLD)
	goal.custom_minimum_size.x = 500
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(goal)
	if not available("housewarming"):
		var aim := UiKit.body("Главная цель: все звёзды и все покупки — «Праздник новоселья»", 22, UiKit.TEXT)
		aim.custom_minimum_size.x = 500
		aim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(aim)
	for entry: Array in _album():
		var id := str(entry[0])
		var open_ := available(id)
		var fresh := open_ and not Profile.flag("seen.novel." + id)
		var title := ("★ " if fresh else "") + str(entry[1])
		var b := UiKit.button(title if open_ else "Ещё впереди", &"secondary" if open_ else &"disabled")
		b.custom_minimum_size = Vector2(480, 80)
		b.add_theme_font_size_override("font_size", 26)
		b.disabled = not open_
		b.pressed.connect(func() -> void: close(id))
		content.add_child(b)


## Прогресс главы: ремонты, звёзды (по 3 за ремонт), покупки магазина.
static func goals() -> Dictionary:
	var g := {"repairs": Home.completed(), "repairs_total": Home.total(), "stars": 0,
		"stars_total": Home.total() * 3, "items": 0, "items_total": Home.SHOP.size()}
	for t: Dictionary in Home.tasks():
		g.stars += Profile.best_stars(str(t.get("level", "")))
	for item: Dictionary in Home.SHOP:
		if Profile.owns(item.id):
			g.items += 1
	return g


static func available(id: String) -> bool:
	if Profile.flag("seen.novel." + id):
		return true
	if id == "housewarming":
		var g := goals()
		return g.stars >= g.stars_total and g.items >= g.items_total
	return id.ends_with("_done") and Home.location_done(id.trim_suffix("_done"))


## Есть сценка, которую можно посмотреть, но ещё не смотрели (красная точка на кнопке альбома).
static func has_unseen() -> bool:
	for entry: Array in _album():
		var id := str(entry[0])
		if available(id) and not Profile.flag("seen.novel." + id):
			return true
	return false


static func _album() -> Array:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data.get("album", []) if data is Dictionary else []
