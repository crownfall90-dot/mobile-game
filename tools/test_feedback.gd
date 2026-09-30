extends RefCounted
## Manual feedback never claims delivery on an HTTP error or loses the retry packet.

static func run() -> bool:
	var before := Reports.feedback_draft.duplicate(true)
	var busy := Reports.feedback_busy
	var message := Reports.feedback_message
	var packet := {"id": "a".repeat(32), "text": "Кнопка не работает", "kind": "bug"}
	Reports.feedback_draft = {"kind": "bug", "text": "Кнопка не работает", "device": false, "packet": packet}
	Reports.feedback_busy = false
	Reports.save_feedback("bug", "Кнопка не работает", false)
	var same: bool = Reports.feedback_draft.get("packet") == packet
	Reports._on_feedback_sent(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":false}'.to_utf8_buffer())
	var retained: bool = Reports.feedback_draft.get("packet") == packet
	Reports._on_feedback_sent(HTTPRequest.RESULT_TIMEOUT, 0, [], PackedByteArray())
	retained = retained and Reports.feedback_draft.get("packet") == packet
	Reports._on_feedback_sent(HTTPRequest.RESULT_SUCCESS, 502, [], '<html>Bad gateway</html>'.to_utf8_buffer())
	retained = retained and Reports.feedback_draft.get("packet") == packet
	Reports._on_feedback_sent(HTTPRequest.RESULT_SUCCESS, 429, [], '{}'.to_utf8_buffer())
	retained = retained and Reports.feedback_draft.get("packet") == packet
	Reports._on_feedback_sent(HTTPRequest.RESULT_SUCCESS, 200, [], '{"ok":true,"url":"https://example.com/"}'.to_utf8_buffer())
	retained = retained and Reports.feedback_draft.get("packet") == packet
	Reports._on_feedback_sent(HTTPRequest.RESULT_SUCCESS, 201, [], JSON.stringify({"ok": true,
		"url": Reports.FEEDBACK_THREAD + "#issuecomment-123"}).to_utf8_buffer())
	var cleared := Reports.feedback_draft.is_empty()
	Reports.feedback_draft = before
	Reports.feedback_busy = busy
	Reports.feedback_message = message
	Reports.feedback_draft = {}
	var first := {"summary": "Пролог", "context": "Первая реплика"}
	var second := {"summary": "Уровень", "context": "Засов a"}
	Reports.begin_feedback(first)
	Reports.save_feedback("crash", "", true)
	Reports.begin_feedback(second)
	var moment: bool = Reports.feedback_draft.context == second # Empty unopened drafts don't pin an old moment.
	Reports.save_feedback("idea", "Моя идея", true)
	Reports.begin_feedback(first)
	moment = moment and Reports.feedback_draft.context == second
	Reports.save_feedback("idea", "Моя идея", false)
	moment = moment and Reports.feedback_draft.context == second
	var prior := Reports.previous_run
	assert(Reports._android_exit_info().is_empty(), "Desktop must not invent an Android exit reason")
	var crash_file := Reports.CRASH_QUEUE + "/" + "e".repeat(32) + ".json"
	Reports.previous_run = {"id": "e".repeat(32), "version": "test", "screen": "game", "location": "room", "level": "home_01", "viewport": "720x1280", "os": "test", "model": "test", "context": "Возвращение домой", "diagnostics": "GPU test", "log": "D:/Users/Tester/log.txt"}
	Reports._queue_previous_run()
	var queued: Variant = JSON.parse_string(FileAccess.get_file_as_string(crash_file))
	var automatic: bool = queued is Dictionary and queued.get("automatic") == true and queued.get("kind") == "crash" and not str(queued.get("diagnostics")).contains("Tester")
	Reports._crash_file = crash_file
	Reports._on_crash_sent(HTTPRequest.RESULT_TIMEOUT, 0, [], '{}'.to_utf8_buffer())
	automatic = automatic and FileAccess.file_exists(crash_file)
	Reports._crash_file = crash_file
	Reports._on_crash_sent(HTTPRequest.RESULT_SUCCESS, 201, [], '{"ok":true,"url":"https://example.com/issues/123"}'.to_utf8_buffer())
	automatic = automatic and FileAccess.file_exists(crash_file)
	Reports._crash_file = crash_file
	Reports._on_crash_sent(HTTPRequest.RESULT_SUCCESS, 201, [], '{"ok":true,"url":"https://github.com/crownfall90-dot/mobile-game/issues/123"}'.to_utf8_buffer())
	automatic = automatic and not FileAccess.file_exists(crash_file)
	Reports.previous_run = prior
	Reports.feedback_draft = before
	var ok: bool = same and retained and cleared and moment and automatic
	print("FEEDBACK CHECK: ", "OK" if ok else "FAIL")
	return ok


static func context_checks() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var saved := Reports.feedback_draft.duplicate(true)
	Reports.feedback_draft = {}
	Router.go(&"novel", {"id": "prologue"})
	await _idle(tree)
	var popup := Router.popup(&"feedback")
	assert((popup.get("_text") as TextEdit).get_theme_color(&"font_color") == UiKit.TEXT,
		"Feedback text must contrast with the dark card")
	var captured: Dictionary = Reports.feedback_draft.context.duplicate(true)
	assert(captured.screen == "novel" and JSON.parse_string(captured.context).scene == "prologue")
	assert(tree.paused)
	await tree.create_timer(0.3).timeout
	assert(Reports.feedback_draft.context == captured)
	popup.close()
	await tree.create_timer(0.3).timeout
	assert(not tree.paused)
	var edge_ids := []
	for i in 4:
		Router.go(&"game", {"id": "home_01"})
		await _idle(tree)
		var level_packet := Reports.capture_feedback()
		assert(level_packet.level == "home_01" and JSON.parse_string(level_packet.context).has("pins"))
		var pause := Router.popup(&"pause")
		Reports.feedback_draft = {}
		popup = Router.popup(&"feedback")
		assert(tree.paused)
		popup.close()
		await tree.create_timer(0.3).timeout
		assert(tree.paused) # Closing feedback over a pause must not resume the level.
		pause.close()
		await tree.create_timer(0.3).timeout
		assert(not tree.paused)
		Router.current_screen()._go_next()
		await _idle(tree)
		assert(Router.current() == &"hub")
		var view = Router.current_screen()._view
		var now := [view._side_tex[0].get_instance_id(), view._side_tex[1].get_instance_id()]
		if not edge_ids.is_empty():
			assert(now == edge_ids) # Returning home reuses the small edge textures, no background readback.
		edge_ids = now
		assert(Router._screens.get_child_count() == 1)
	Reports.feedback_draft = saved
	assert(run())
	print("FEEDBACK CONTEXT CHECK OK: prologue snapshot, pause, level state, four returns home, reused edges, crash queue")
	return true


static func _idle(tree: SceneTree) -> void:
	while Router.is_busy():
		await tree.process_frame
	await tree.process_frame
