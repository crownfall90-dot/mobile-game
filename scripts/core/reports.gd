extends Node
## Reports: отзывы в тему тестеров и автоматические задачи о неожиданных закрытиях.
## Нативный процесс после вылета уже не работает: сохранённый отчёт отправляется при следующем запуске.
## Sentry остаётся необязательным дополнительным приёмником ошибок.
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
const LOG_TAIL := 16000          # сколько последних символов прошлого журнала приложить

signal feedback_finished(ok: bool, message: String)

const FEEDBACK_DRAFT := "user://feedback_draft.json"
const FEEDBACK_THREAD := "https://github.com/crownfall90-dot/mobile-game/issues/5"
var feedback_busy := false
var feedback_draft: Dictionary = {}
var feedback_message := ""
var _feedback_http: HTTPRequest
var feedback_events: Array[String] = []
var feedback_errors: Array[String] = []
var previous_run: Dictionary = {}
var _tracking := false
var _checkpoint: Timer
const CRASH_QUEUE := "user://crash_reports"
var _crash_http: HTTPRequest
var _crash_file := ""
var _run_id := _uuid()

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
	_tracking = not Profile.volatile and (OS.has_feature("android") or OS.get_environment("VITA_REPORT_TEST") == "1")
	if _tracking:
		var json := JSON.new()
		if FileAccess.file_exists(RUNNING) and json.parse(FileAccess.get_file_as_string(RUNNING)) == OK and json.data is Dictionary:
			previous_run = json.data
			previous_run["log"] = _previous_log_tail()
		_checkpoint = Timer.new()
		_checkpoint.wait_time = 5
		_checkpoint.timeout.connect(func() -> void: _mark_running(true))
		add_child(_checkpoint)
		_checkpoint.start()
		_queue_previous_run()
		var retry := Timer.new()
		retry.wait_time = 60
		retry.timeout.connect(_send_crash)
		add_child(retry)
		retry.start()
		_send_crash.call_deferred()
		_mark_running.call_deferred(true)
		OS.add_logger(Catcher.new(self))
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
	if not _tracking:
		OS.add_logger(Catcher.new(self))
	_check_last_run()
	_mark_running(true)


func _notification(what: int) -> void:
	if not enabled and not _tracking:
		return
	# свернули или закрыли — это не сбой; вернулись — снова «на экране»
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_PREDELETE]:
		if _checkpoint:
			_checkpoint.stop()
		_mark_running(false)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if _checkpoint:
			_checkpoint.start()
		_mark_running(true)


## Ошибка из журнала (вызывается из Catcher, возможно не из главного потока).
func report_error(text: String, where: String, trace: String) -> void:
	_record_error.call_deferred(text, where, trace)


func _record_error(text: String, where: String, trace: String) -> void:
	var error := (where + ": " + text + "\n" + trace).left(4000)
	if error in feedback_errors:
		return
	feedback_errors.append(error)
	if feedback_errors.size() > 4:
		feedback_errors.pop_front()
	if enabled:
		_add_event("error", text, where, trace)


func _input(event: InputEvent) -> void:
	if Router.top_popup() and Router.top_popup().name == "FeedbackPopup":
		return  # Never record typed feedback or keyboard input.
	if event is InputEventScreenTouch and event.pressed:
		note_feedback("Касание %s" % event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		note_feedback("Касание %s" % event.position)


func note_feedback(action: String) -> void:
	feedback_events.append("%.1fs %s: %s" % [Time.get_ticks_msec() / 1000.0, Router.current(), action.left(180)])
	if feedback_events.size() > 32:
		feedback_events.pop_front()


func capture_feedback() -> Dictionary:
	var screen := Router.current_screen()
	var name := str(Router.current())
	var detail: Dictionary = screen.feedback_context() if screen and screen.has_method("feedback_context") else {"where": name}
	var size := get_viewport().get_visible_rect().size
	var tech := {"engine": Engine.get_version_info().string, "uptime_s": Time.get_ticks_msec() / 1000.0,
		"fps": Engine.get_frames_per_second(), "memory_bytes": OS.get_static_memory_usage(),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"gpu": RenderingServer.get_video_adapter_name(), "gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"cpu": OS.get_processor_name(), "cpu_count": OS.get_processor_count(),
		"physics_fps": Engine.physics_ticks_per_second, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"router_busy": Router.is_busy(), "run_id": _run_id, "driver": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "gl_compatibility")),
		"screen_pixels": str(DisplayServer.window_get_size()), "locale": OS.get_locale(),
		"events": feedback_events.duplicate(), "errors": feedback_errors.duplicate(),
		"progress": Profile.data.duplicate(true)}
	if not previous_run.is_empty():
		var prior := previous_run.duplicate(true)
		prior.erase("diagnostics") # Avoid nesting checkpoints on repeated interrupted runs.
		tech["previous_interrupted_run"] = prior
	var diagnostics := JSON.stringify(tech, "  ")
	# Runtime logs can include a local user path. Keep paths anonymous in public feedback.
	var redact := RegEx.new()
	redact.compile(r"(?i)([A-Z]:[\\/]Users[\\/]|/home/|/Users/)[^\\/\n]+")
	diagnostics = redact.sub(diagnostics, "$1<user>", true)
	return {"version": str(ProjectSettings.get_setting("application/config/version", "")),
		"screen": name, "location": str(detail.get("location", "")), "level": str(detail.get("level", "")),
		"viewport": "%dx%d" % [size.x, size.y], "os": (OS.get_name() + " " + OS.get_version()).left(100),
		"model": OS.get_model_name().left(100), "context": JSON.stringify(detail, "  ").left(12000),
		"diagnostics": diagnostics.left(24000), "summary": str(detail.get("where", name)),
		"captured_at": Time.get_datetime_string_from_system(true)}


func begin_feedback(captured: Dictionary) -> void:
	if not feedback_busy and (not feedback_draft.has("context") or (str(feedback_draft.get("text", "")).is_empty() and not feedback_draft.has("packet"))):
		feedback_message = ""
		feedback_draft["context"] = captured.duplicate(true)
		feedback_draft["device"] = true


func new_feedback(captured: Dictionary) -> void:
	if not feedback_busy:
		feedback_message = ""
		feedback_draft = {"context": captured.duplicate(true), "kind": "bug", "text": "", "device": true}
		save_feedback("bug", "", true)


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
		var context := capture_feedback()
		context.erase("summary")
		context["id"] = _run_id
		_atomic_json(RUNNING, context)
	elif FileAccess.file_exists(RUNNING):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUNNING))


func _atomic_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(JSON.stringify(data)) and file.get_error() == OK
	file.close()
	return stored and DirAccess.rename_absolute(path + ".tmp", path) == OK


func _queue_previous_run() -> void:
	if previous_run.is_empty():
		return
	var packet := previous_run.duplicate(true)
	packet["id"] = str(packet.get("id", _uuid()))
	packet["kind"] = "crash"
	packet["automatic"] = true
	# A native crash and a foreground OS kill both leave a marker; don't claim certainty.
	packet["text"] = "Автоматический отчёт: предыдущий запуск неожиданно оборвался на экране. Возможен вылет или завершение системой."
	packet["context"] = (str(packet.get("context", "")) + "\nМомент: " + str(packet.get("captured_at", ""))).left(12288)
	var system_exit := _android_exit_info()
	var redact := RegEx.new()
	redact.compile(r"(?i)([A-Z]:[\\/]Users[\\/]|/home/|/Users/)[^\\/\n]+")
	packet["diagnostics"] = redact.sub(("Причина завершения Android:\n" + JSON.stringify(system_exit) +
		"\nПоследний журнал:\n" + str(packet.get("log", "")) + "\n" + str(packet.get("diagnostics", ""))).left(32000), "$1<user>", true)
	packet.erase("log")
	packet.erase("captured_at")
	DirAccess.make_dir_recursive_absolute(CRASH_QUEUE)
	if _atomic_json(CRASH_QUEUE + "/" + packet.id + ".json", packet):
		DirAccess.remove_absolute(RUNNING)


## Android 11+ knows why our previous process died, even when Godot had no time to log it.
func _android_exit_info() -> Dictionary:
	if not OS.has_feature("android") or not Engine.has_singleton("AndroidRuntime"):
		return {}
	var version_class := JavaClassWrapper.wrap("android.os.Build$VERSION")
	if JavaClassWrapper.get_exception() != null or version_class == null:
		return {}
	var sdk: Variant = version_class.get("SDK_INT")
	if JavaClassWrapper.get_exception() != null or sdk == null or int(sdk) < 30:
		return {}
	var runtime := Engine.get_singleton("AndroidRuntime")
	var context: Object = runtime.call("getApplicationContext")
	if JavaClassWrapper.get_exception() != null or context == null:
		return {}
	var manager: Object = context.call("getSystemService", "activity")
	if JavaClassWrapper.get_exception() != null or manager == null:
		return {}
	var package: Variant = context.call("getPackageName")
	if JavaClassWrapper.get_exception() != null or package == null:
		return {}
	var history: Object = manager.call("getHistoricalProcessExitReasons", package, 0, 1)
	if JavaClassWrapper.get_exception() != null or history == null:
		return {}
	var count: Variant = history.call("size")
	if JavaClassWrapper.get_exception() != null or count == null or int(count) == 0:
		return {}
	var entry: Object = history.call("get", 0)
	if JavaClassWrapper.get_exception() != null or entry == null:
		return {}
	return _read_exit_entry(entry, JavaClassWrapper.get_exception)


## Stop on the first failed JNI call: a later successful call can replace its exception.
func _read_exit_entry(entry: Object, exception: Callable) -> Dictionary:
	var info := {}
	var methods := {"reason_code": "getReason", "status": "getStatus",
		"time_ms": "getTimestamp", "pss_kb": "getPss", "rss_kb": "getRss",
		"importance": "getImportance", "pid": "getPid", "process": "getProcessName",
		"description": "getDescription"}
	for key in methods:
		var value: Variant = entry.call(methods[key])
		if exception.call() != null:
			return {}
		if value == null and key not in ["process", "description"]:
			return {}
		info[key] = value
	var reason := int(info.reason_code)
	var reasons := ["unknown", "exit_self", "signaled", "low_memory", "java_crash",
		"native_crash", "anr", "initialization_failure", "permission_change",
		"excessive_resource_usage", "user_requested", "user_stopped", "dependency_died",
		"other", "freezer", "package_state_change", "package_updated", "memory_limiter"]
	info.reason = reasons[reason] if reason >= 0 and reason < reasons.size() else "code_%d" % reason
	info.process = str(info.process).left(200) if info.process != null else ""
	info.description = str(info.description).left(500) if info.description != null else ""
	return info


func _send_crash() -> void:
	if not _tracking or not _crash_file.is_empty() or feedback_url().is_empty():
		return
	var dir := DirAccess.open(CRASH_QUEUE)
	if dir == null:
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var path := CRASH_QUEUE + "/" + file
		var packet: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not packet is Dictionary:
			continue
		if _crash_http == null:
			_crash_http = HTTPRequest.new()
			_crash_http.timeout = 25
			_crash_http.body_size_limit = 2048
			_crash_http.max_redirects = 0
			add_child(_crash_http)
			_crash_http.request_completed.connect(_on_crash_sent)
		_crash_file = path
		if _crash_http.request(feedback_url(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(packet)) != OK:
			_crash_file = ""
		return


func _on_crash_sent(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parsed: Variant = null
	if result == HTTPRequest.RESULT_SUCCESS and code in [200, 201]:
		var json := JSON.new()
		if json.parse(body.get_string_from_utf8()) == OK:
			parsed = json.data
	var accepted: bool = result == HTTPRequest.RESULT_SUCCESS and code in [200, 201] and parsed is Dictionary and parsed.get("ok") == true
	var url := str(parsed.get("url", "")) if parsed is Dictionary else ""
	var prefix := "https://github.com/crownfall90-dot/mobile-game/issues/"
	accepted = accepted and url.begins_with(prefix) and url.trim_prefix(prefix).is_valid_int()
	if accepted:
		DirAccess.remove_absolute(_crash_file)
	_crash_file = ""
	if accepted:
		_send_crash.call_deferred()


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
		feedback_draft.erase("packet")
		feedback_draft.merge({"kind": kind, "text": text, "device": device}, true)
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
	if text.length() > 1500 or kind not in ["bug", "crash", "idea"]:
		_feedback_result(false, "Описание может содержать до 1500 знаков.")
		return
	var url := feedback_url()
	if url == "":
		_feedback_result(false, "Отправка пока недоступна. Текст сохранён — попробуй после обновления игры.")
		return
	# Keep the same packet/ID on retry, even after restarting or changing rooms.
	if not feedback_draft.has("packet"):
		var captured: Dictionary = (feedback_draft["context"] if feedback_draft.has("context") else capture_feedback()).duplicate(true)
		captured.erase("summary")
		captured["context"] += "\nМомент: " + str(captured.get("captured_at", ""))
		captured.erase("captured_at")
		if not bool(feedback_draft.get("device", true)):
			captured["os"] = ""
			captured["model"] = ""
			captured.erase("diagnostics")
		captured.merge({"id": _uuid(), "kind": kind, "text": text}, true)
		feedback_draft["packet"] = captured

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
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(body.get_string_from_utf8()) == OK else null
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
