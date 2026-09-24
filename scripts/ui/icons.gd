class_name Icons
extends RefCounted
## Иконки интерфейса: art/icons/<name>.svg (viewBox 48), растеризуются в нужный
## размер при первом запросе и кэшируются по имени и размеру.
## SVG лежат как есть (импорт "keep"), чтобы читать их через FileAccess и в APK.

const DIR := "res://art/icons/"
const VIEWBOX := 48.0
const NAMES: Array[StringName] = [
	&"coin", &"star", &"gem", &"hint", &"gear", &"pause", &"restart", &"home", &"map",
	&"book", &"hanger", &"calendar", &"chest", &"lock", &"play", &"back", &"close",
	&"check", &"sound_on", &"sound_off", &"music", &"vibration", &"flame", &"relic", &"hand",
]
# запасная иконка, если файла нет: знак вопроса без текста (ThorVG не рисует текст)
const _MISSING := "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 48 48\"><circle cx=\"24\" cy=\"24\" r=\"20\" fill=\"#ff4fd8\" stroke=\"#1b1236\" stroke-width=\"3\"/><path d=\"M17,18 A7,7 0 1 1 24,25 V29\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"5\" stroke-linecap=\"round\"/><circle cx=\"24\" cy=\"36\" r=\"3\" fill=\"#ffffff\"/></svg>"

static var _cache: Dictionary = {}   # "name@px" -> ImageTexture
static var _src: Dictionary = {}     # name -> текст SVG


static func tex(name: StringName, px := 64) -> Texture2D:
	px = clampi(px, 8, 1024)
	var key := "%s@%d" % [name, px]
	var t: Texture2D = _cache.get(key)
	if t:
		return t
	var img := Image.new()
	if img.load_svg_from_string(_svg(name), px / VIEWBOX) != OK or img.is_empty():
		img.load_svg_from_string(_MISSING, px / VIEWBOX)
	# цвет под прозрачными краями, чтобы при масштабировании не было тёмной каймы
	img.fix_alpha_edges()
	t = ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


static func has(name: StringName) -> bool:
	return FileAccess.file_exists(DIR + String(name) + ".svg")


## Сбросить растры (например, при нехватке памяти); исходники SVG остаются.
static func clear_cache() -> void:
	_cache.clear()


static func _svg(name: StringName) -> String:
	if _src.has(name):
		return _src[name]
	var path := DIR + String(name) + ".svg"
	var s := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	if s == "":
		push_warning("Icons: no icon '%s'" % name)
		s = _MISSING
	_src[name] = s
	return s
