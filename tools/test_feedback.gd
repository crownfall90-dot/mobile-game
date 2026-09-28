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
	var ok := same and retained and cleared
	print("FEEDBACK CHECK: ", "OK" if ok else "FAIL")
	return ok
