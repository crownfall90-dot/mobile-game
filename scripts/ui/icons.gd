class_name Icons
extends RefCounted
## Иконки интерфейса: art/icons/<name>.svg (viewBox 48), растеризуются в нужный
## размер при первом запросе и кэшируются по имени и размеру.
## SVG лежат как есть (импорт "keep"), чтобы читать их через FileAccess и в APK.
##
## Растр делается в физических пикселях экрана (px × масштаб окна), а размер
## текстуры остаётся px: на телефоне 1080 или 1440 иконки такие же чёткие, как текст.

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
static var _k := 0.0                 # масштаб окна, под который сделаны растры; 0 — ещё не знаем


static func tex(name: StringName, px := 64) -> Texture2D:
	px = clampi(px, 8, 1024)
	var key := "%s@%d" % [name, px]
	var t: ImageTexture = _cache.get(key)
	if t:
		return t
	if _k == 0.0:
		_k = _screen_scale()
		_watch_resize()
	t = ImageTexture.create_from_image(_raster(name, px))
	t.set_size_override(Vector2i(px, px))
	_cache[key] = t
	return t


static func has(name: StringName) -> bool:
	return FileAccess.file_exists(DIR + String(name) + ".svg")


## Сбросить растры (например, при нехватке памяти); исходники SVG остаются.
static func clear_cache() -> void:
	_cache.clear()


static func _raster(name: StringName, px: int) -> Image:
	# ceil: лучше чуть крупнее экрана (сжатие почти не мылит), чем растянуть
	var real := ceili(px * _k - 0.01)
	var img := Image.new()
	if img.load_svg_from_string(_svg(name), real / VIEWBOX) != OK or img.is_empty():
		img.load_svg_from_string(_MISSING, real / VIEWBOX)
	# цвет под прозрачными краями, чтобы при масштабировании не было тёмной каймы
	img.fix_alpha_edges()
	return img


## Во сколько раз окно больше дизайна 720×1280 (stretch canvas_items); не меньше 1.
static func _screen_scale() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return 1.0
	return maxf(1.0, tree.root.get_final_transform().get_scale().x)


static func _watch_resize() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and not tree.root.size_changed.is_connected(_on_resize):
		tree.root.size_changed.connect(_on_resize)


## Окно сменило размер (сплит-экран, раскладушка, окно на ПК): перерисовать уже
## выданные текстуры на месте — виджеты держат те же объекты и сразу станут чёткими.
static func _on_resize() -> void:
	var k := _screen_scale()
	if absf(k - _k) < 0.05:
		return
	_k = k
	for key: String in _cache:
		var t: ImageTexture = _cache[key]
		var px := int(key.get_slice("@", 1))
		t.set_image(_raster(StringName(key.get_slice("@", 0)), px))
		t.set_size_override(Vector2i(px, px))


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
