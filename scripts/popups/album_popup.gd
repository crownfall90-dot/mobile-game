extends UiPopup
## Альбом: фото прабабушки из найденных кусочков и повтор просмотренных сценок-новелл.
## Закрывается id сценки, которую хотят посмотреть снова (хаб открывает новеллу), или null.
## Сценки и их названия — data/novel.json "album": [[id, название], ...]; видна только
## просмотренная (флаг seen.novel.<id>), остальные — «Ещё впереди».

const PHOTO := preload("res://scripts/ui/photo_card.gd")
const DATA := "res://data/novel.json"


func open(_args: Dictionary) -> void:
	set_title("Альбом")
	Profile.set_flag("album.new", false)
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
	for entry: Array in _album():
		var id := str(entry[0])
		var seen := Profile.flag("seen.novel." + id)
		var b := UiKit.button(str(entry[1]) if seen else "Ещё впереди", &"secondary" if seen else &"disabled")
		b.custom_minimum_size = Vector2(480, 80)
		b.add_theme_font_size_override("font_size", 26)
		b.disabled = not seen
		b.pressed.connect(func() -> void: close(id))
		content.add_child(b)


static func _album() -> Array:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	return data.get("album", []) if data is Dictionary else []
