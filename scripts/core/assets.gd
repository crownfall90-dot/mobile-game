extends Node
## Автозагрузка "Assets": размеренная фоновая подгрузка картинок. Очередь путей грузится в
## фоновом потоке не больше MAX_ACTIVE за раз (игра не подтормаживает); готовые ресурсы держатся
## в памяти, пока нужны, поэтому обычный load() потом отдаёт их сразу. Держим не больше KEEP —
## старые отпускаем (память телефона).
## Экран загрузки ждёт картинки текущей локации (и пролога при первом запуске); хаб в фоне
## подгружает следующую локацию.

const MAX_ACTIVE := 2
const KEEP := 40            # ~2 локации: фон 1440×3120 в памяти ≈ 18 МБ
const ART := "res://art/act1/"

var _queue: Array[String] = []
var _active: Array[String] = []
var _held := {}                 # путь -> Resource
var _order: Array[String] = []  # порядок загрузки, для отпускания старых
var _asked := 0
var _done := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Поставить пути в очередь (уже загруженные и повторы пропускаются).
func want(paths: Array) -> void:
	for p in paths:
		var path := str(p)
		if path == "" or _held.has(path) or path in _queue or path in _active or not ResourceLoader.exists(path):
			continue
		_queue.append(path)
		_asked += 1


## Доля готового из всего, что просили с последнего reset_progress(): 0..1.
func progress() -> float:
	return 1.0 if _asked == 0 else float(_done) / _asked


func idle() -> bool:
	return _queue.is_empty() and _active.is_empty()


func reset_progress() -> void:
	_asked = _queue.size() + _active.size()
	_done = 0


func _process(_delta: float) -> void:
	for path in _active.duplicate():
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		_active.erase(path)
		_done += 1
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			_keep(path, ResourceLoader.load_threaded_get(path))
	while _active.size() < MAX_ACTIVE and not _queue.is_empty():
		var next: String = _queue.pop_front()
		if ResourceLoader.load_threaded_request(next) == OK:
			_active.append(next)
		else:
			_done += 1


func _keep(path: String, res: Resource) -> void:
	if res == null:
		return
	_held[path] = res
	_order.append(path)
	while _order.size() > KEEP:
		_held.erase(_order.pop_front())


## Картинки локации: фон, вещи (сломано/починено), слои семьи и предметов, декор, семья.
static func location_paths(loc_id: String) -> Array:
	var loc: Dictionary = Home.location(loc_id)
	if loc.is_empty():
		return []
	var out: Array = ["%s%s/background.png" % [ART, loc_id]]
	for t: Dictionary in loc.get("targets", []):
		out.append("%s%s/%s_broken.png" % [ART, loc_id, t["id"]])
		out.append("%s%s/%s_fixed.png" % [ART, loc_id, t["id"]])
	for p: Dictionary in loc.get("props", []):
		out.append("%s%s.png" % [ART, p["img"]])
	if loc.has("family"):
		for m in 4:
			out.append("%sfamily/family_mood%d.png" % [ART, m])
	return out


## Что нужно прологу-новелле: комната, семья, Хмурь.
static func prologue_paths() -> Array:
	var out := location_paths("room")
	out.append_array([ART + "story/gloom_grey.png", ART + "story/night.png", ART + "story/letter.png"])
	return out
