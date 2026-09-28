extends Node
## Автозагрузка "Reports": отчёты о сбоях в Sentry из скачанных APK, без нативных библиотек.
## - Ошибки скриптов и движка ловит свой Logger; каждая уходит событием (одна и та же — один раз
##   за запуск, не больше MAX_EVENTS за запуск).
## - Если прошлый запуск оборвался, пока игра была на экране (метка user://running не снята),
##   при следующем запуске уходит событие «игра закрылась аварийно» с хвостом прошлого журнала.
## Ключ проекта — data/telemetry.json {"sentry_dsn": "https://<ключ>@<хост>/<проект>"}; пусто —
## отчёты выключены. Отправляет только на Android (не в редакторе, не в проверках); для проверки
## на компьютере — переменная окружения VITA_REPORT_TEST=1. Личных данных нет: версия игры,
## модель и версия Android, экран и уровень, текст ошибки.

const CONFIG := "res://data/telemetry.json"
const RUNNING := "user://running"
const MAX_EVENTS := 5
const LOG_TAIL := 6000          # сколько последних символов прошлого журнала приложить

signal feedback_finished(ok: bool, message: String)

const FEEDBACK_DRAFT := "user://feedback_draft.json"
const FEEDBACK_THREAD := "https://github.com/crownfall90-dot/mobile-game/issues/5"
var feedback_busy := false
var feedback_draft: Dictionary = {}
var feedback_message := ""
var _feedback_http: HTTPRequest

var enabled := false
var _key := ""
var _url := ""
var _dsn := ""
var _sent := {}                 # отпечаток ошибки -> true
var _count := 0
var _queue: Array[Dictionary] = []
var _http: HTTPRequest
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Profile.volatile and FileAccess.file_exists(FEEDBACK_DRAFT):
		var draft: Variant = JSON.parse_string(FileAccess.get_file_as_string(FEEDBACK_DRAFT))
		if draft is Dictionary and draft.get("text") is String:
			feedback_draft = draft
	_dsn = _read_dsn()
	var allowed := OS.has_feature("android") or OS.get_environment("VITA_REPORT_TEST") == "1"
	if _dsn == "" or not allowed:
		return
	# https://<key>@<host>/<project>
	var scheme := "http" if _dsn.begins_with("http://") else "https"
	var rest := _dsn.trim_prefix("https://").trim_prefix("http://")
	var at := rest.find("@")
	var slash := rest.rfind("/")
	if at <= 0 or slash <= at:
		return
	_key = rest.substr(0, at)
	var host := rest.substr(at + 1, slash - at - 1)
	var project := rest.substr(slash + 1)
	_url = "%s://%s/api/%s/envelope/" % [scheme, host, project]
	enabled = true
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_sent)
	OS.add_logger(Catcher.new(self))
	_check_last_run()
	_mark_running(true)


func _notification(what: int) -> void:
	if not enabled:
		return
	# свернули или закрыли — это не сбой; вернулись — снова «на экране»
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE]:
		_mark_running(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_mark_running(true)


## Ошибка из журнала (вызывается из Catcher, возможно не из главного потока).
func report_error(text: String, where: String, trace: String) -> void:
	_add_event.call_deferred("error", text, where, trace)


func _add_event(level: String, text: String, where: String, extra: String) -> void:
	var print_key := text + "|" + where
	if _sent.has(print_key) or _count >= MAX_EVENTS:
		return
	_sent[print_key] = true
	_count += 1
	_queue.append(_event(level, text, where, extra))
	_pump()


func _event(level: String, text: String, where: String, extra: String) -> Dictionary:
	var router := get_node_or_null(^"/root/Router")
	var screen := str(router.call(&"current")) if router and router.has_method(&"current") else ""
	return {
		"event_id": _uuid(),
		"timestamp": Time.get_unix_time_from_system(),
		"platform": "other",
		"level": level,
		"logger": "vita",
		"release": "vita@" + str(ProjectSettings.get_setting("application/config/version", "")),
		"environment": "apk",
		"message": {"formatted": text},
		"culprit": where,
		"tags": {"screen": screen, "os": OS.get_name(), "os_version": OS.get_version(),
			"model": OS.get_model_name()},
		"extra": {"where": where, "details": extra},
	}


func _pump() -> void:
	if _busy or _queue.is_empty() or _http == null:
		return
	_busy = true
	var ev: Dictionary = _queue.pop_front()
	var head := {"event_id": ev["event_id"], "dsn": _dsn}
	var body := "%s\n%s\n%s\n" % [JSON.stringify(head), JSON.stringify({"type": "event"}), JSON.stringify(ev)]
	var auth := "Sentry sentry_version=7, sentry_client=vita-reports/1.0, sentry_key=" + _key
	var err := _http.request(_url, ["Content-Type: application/x-sentry-envelope", "X-Sentry-Auth: " + auth],
		HTTPClient.METHOD_POST, body)
	if err != OK:
		_busy = false


func _on_sent(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_busy = false
	_pump()


## Прошлый запуск оборвался на экране: отправляем хвост его журнала.
func _check_last_run() -> void:
	if not FileAccess.file_exists(RUNNING):
		return
	_add_event("fatal", "Игра закрылась аварийно в прошлый раз", "previous run", _previous_log_tail())


func _mark_running(on: bool) -> void:
	if on:
		var f := FileAccess.open(RUNNING, FileAccess.WRITE)
		if f:
			f.store_string(str(Time.get_unix_time_from_system()))
	elif FileAccess.file_exists(RUNNING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUNNING))


## Godot хранит журналы в user://logs: godot.log — текущий, прошлые — с датой в имени.
func _previous_log_tail() -> String:
	var dir := DirAccess.open("user://logs")
	if dir == null:
		return ""
	var files: Array = []
	for f in dir.get_files():
		if f.ends_with(".log") and f != "godot.log":
			files.append(f)
	if files.is_empty():
		return ""
	files.sort()
	var file := FileAccess.open("user://logs/" + str(files.back()), FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	return text.substr(maxi(0, text.length() - LOG_TAIL))


func _read_dsn() -> String:
	var f := FileAccess.open(CONFIG, FileAccess.READ)
	if f == null:
		return ""
	var data: Variant = JSON.parse_string(f.get_as_text())
	return str(data.get("sentry_dsn", "")).strip_edges() if data is Dictionary else ""


static func _uuid() -> String:
	var s := ""
	for i in 16:
		s += "%02x" % (randi() & 0xff)
	return s


func feedback_url() -> String:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var url := str(parsed.get("feedback_url", "")) if parsed is Dictionary else ""
	return url if url.begins_with("https://") and url.ends_with("/feedback") else ""


func save_feedback(kind: String, text: String, device: bool) -> bool:
	if feedback_busy:
		return false
	if feedback_draft.get("kind") != kind or feedback_draft.get("text") != text or feedback_draft.get("device") != device:
		feedback_draft = {"kind": kind, "text": text, "device": device}
	if Profile.volatile:
		return true
	var tmp := FEEDBACK_DRAFT + ".tmp"
	var data := JSON.stringify(feedback_draft)
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(data) and file.get_error() == OK
	file.close()
	return stored and FileAccess.get_file_as_string(tmp) == data and DirAccess.rename_absolute(tmp, FEEDBACK_DRAFT) == OK


func send_feedback() -> void:
	if feedback_busy:
		return
	var text := str(feedback_draft.get("text", "")).strip_edges()
	var kind := str(feedback_draft.get("kind", ""))
	if text.length() < 10 or text.length() > 1500 or kind not in ["bug", "idea"]:
		_feedback_result(false, "Опиши подробнее: от 10 до 1500 знаков.")
		return
	var url := feedback_url()
	if url == "":
		_feedback_result(false, "Отправка пока недоступна. Текст сохранён — попробуй после обновления игры.")
		return
	# Keep the same packet/ID on retry, even after restarting or changing rooms.
	if not feedback_draft.has("packet"):
		var screen := Router.current_screen()
		var name := str(Router.current())
		var device := bool(feedback_draft.get("device", false))
		var size := get_viewport().get_visible_rect().size
		feedback_draft["packet"] = {"id": _uuid(), "kind": kind, "text": text,
			"version": str(ProjectSettings.get_setting("application/config/version", "")),
			"screen": name, "location": str(screen.get("_loc_id")) if name == "hub" and screen else "",
			"level": str(screen.get("level_id")) if name == "game" and screen else "",
			"viewport": "%dx%d" % [size.x, size.y],
			"os": (OS.get_name() + " " + OS.get_version()).left(100) if device else "", "model": OS.get_model_name().left(100) if device else ""}
	if not save_feedback(kind, str(feedback_draft["text"]), bool(feedback_draft.get("device", false))):
		_feedback_result(false, "Не удалось сохранить текст на телефоне. Освободи немного места и повтори.")
		return
	if _feedback_http == null:
		_feedback_http = HTTPRequest.new()
		_feedback_http.timeout = 25.0
		_feedback_http.body_size_limit = 2048
		_feedback_http.max_redirects = 0
		add_child(_feedback_http)
		_feedback_http.request_completed.connect(_on_feedback_sent)
	feedback_busy = true
	feedback_message = "Отправляем…"
	var error := _feedback_http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify(feedback_draft["packet"]))
	if error != OK:
		_feedback_result(false, "Не удалось подключиться. Текст сохранён — попробуй ещё раз.")


func _on_feedback_sent(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var accepted: bool = result == HTTPRequest.RESULT_SUCCESS and code in [200, 201] and parsed is Dictionary \
		and parsed.get("ok") == true and str(parsed.get("url", "")).begins_with(FEEDBACK_THREAD + "#issuecomment-")
	if accepted:
		feedback_draft = {}
		if not Profile.volatile and FileAccess.file_exists(FEEDBACK_DRAFT):
			DirAccess.remove_absolute(FEEDBACK_DRAFT)
		_feedback_result(true, "Спасибо! Сообщение появилось в теме тестеров.")
	else:
		var message := "Не удалось подтвердить отправку. Текст сохранён — повторная отправка проверит, дошёл ли он."
		if code == 429:
			message = "Слишком много сообщений. Текст сохранён — попробуй позже."
		_feedback_result(false, message)


func _feedback_result(ok: bool, message: String) -> void:
	feedback_busy = false
	feedback_message = message
	feedback_finished.emit(ok, message)


## Ловит ошибки движка и скриптов (предупреждения — нет).
class Catcher extends Logger:
	var owner_node: Node

	func _init(n: Node) -> void:
		owner_node = n

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING or not is_instance_valid(owner_node):
			return
		var trace := ""
		for bt in script_backtraces:
			trace += bt.format() + "\n"
		owner_node.call(&"report_error", rationale if rationale != "" else code,
			"%s:%d %s" % [file.get_file(), line, function], trace)

	func _log_message(_message: String, _error: bool) -> void:
		pass
