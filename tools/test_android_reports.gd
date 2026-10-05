extends SceneTree
## Exercise the shared exit-record decoder without pretending to execute Android JNI.

class ExitEntry extends RefCounted:
	var calls := 0
	var fail_at := -1
	var reason := 5
	func value(v: Variant) -> Variant:
		calls += 1
		return v
	func exception() -> Object:
		return self if calls == fail_at else null
	func getReason() -> Variant: return value(reason)
	func getStatus() -> Variant: return value(11)
	func getTimestamp() -> Variant: return value(12345)
	func getPss() -> Variant: return value(100)
	func getRss() -> Variant: return value(200)
	func getImportance() -> Variant: return value(100)
	func getPid() -> Variant: return value(123)
	func getProcessName() -> Variant: return value("com.crownfall90.vita.test")
	func getDescription() -> Variant: return value(null)

class Stream extends RefCounted:
	var bytes: PackedByteArray
	var closed := false
	func readAllBytes() -> Variant: return bytes
	func close() -> void: closed = true

class TraceEntry extends RefCounted:
	var stream: Stream
	func getTraceInputStream() -> Variant: return stream


static func _varint(v: int) -> PackedByteArray:
	var out := PackedByteArray()
	while true:
		var c := v & 0x7f
		v = v >> 7
		if v == 0:
			out.append(c)
			return out
		out.append(c | 0x80)
	return out


static func _vf(num: int, v: int) -> PackedByteArray:
	return _varint(num << 3) + _varint(v)


static func _lf(num: int, data: PackedByteArray) -> PackedByteArray:
	return _varint((num << 3) | 2) + _varint(data.size()) + data


static func _sf(num: int, s: String) -> PackedByteArray:
	return _lf(num, s.to_utf8_buffer())


static func _tombstone() -> PackedByteArray:
	var frame0 := _vf(1, 0x1a2b3c) + _sf(4, "AudioStreamPlaybackWAV::mix") + _vf(5, 88) + _sf(6, "/data/app/x/lib/arm64/libgodot_android.so") + _sf(8, "abcdef0123456789ffff")
	var frame1 := _vf(1, 0x4400) + _sf(6, "/system/lib64/libc.so")
	var crashed := _vf(1, 77) + _sf(2, "AudioThread") + _lf(4, frame0) + _lf(4, frame1)
	var other := _vf(1, 12) + _sf(2, "main") + _lf(4, _vf(1, 0x99) + _sf(6, "/system/lib64/libart.so"))
	var sig := _vf(1, 11) + _sf(2, "SIGSEGV") + _vf(3, 1) + _sf(4, "SEGV_MAPERR") + _vf(9, 0xdead)
	return _sf(2, "HONOR/DNY/16") + _vf(5, 4321) + _vf(6, 77) + _lf(10, sig) + _sf(14, "") \
		+ _lf(16, _vf(1, 12) + _lf(2, other)) + _lf(16, _vf(1, 77) + _lf(2, crashed))


func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var reports := root.get_node("Reports")
	for failed_call in range(1, 10):
		var entry := ExitEntry.new()
		entry.fail_at = failed_call
		assert(reports._read_exit_entry(entry, entry.exception).is_empty())
		assert(entry.calls == failed_call, "Called Java after a failed getter")
	for reason in [3, 4, 5, 999]:
		var entry := ExitEntry.new()
		entry.reason = reason
		var result: Dictionary = reports._read_exit_entry(entry, entry.exception)
		assert(result.reason == {3: "low_memory", 4: "java_crash", 5: "native_crash", 999: "code_999"}[reason])
		assert(result.status == 11 and result.description == "" and entry.calls == 9)
	assert(reports._android_exit_info().is_empty(), "Desktop must not call Android APIs")
	# tombstone: сигнал, упавший поток, кадры с библиотекой и функцией
	var summary: String = reports.trace_summary(_tombstone())
	assert("signal SIGSEGV SEGV_MAPERR fault 0xdead" in summary, summary)
	assert("thread AudioThread" in summary and not "libart.so" in summary, summary)
	assert("#00 pc 1a2b3c libgodot_android.so (AudioStreamPlaybackWAV::mix+88) [abcdef0123456789]" in summary, summary)
	assert("#01 pc 4400 libc.so" in summary, summary)
	# не protobuf (текст ANR) — печатные строки; мусор не роняет разбор
	assert("main thread blocked" in reports.trace_summary("----- pid 1 -----\nmain thread blocked\n".to_utf8_buffer()))
	var junk := PackedByteArray()
	for i in 5000:
		junk.append((i * 73 + 11) % 256)
	reports.trace_summary(junk)
	var te := TraceEntry.new()
	te.stream = Stream.new()
	te.stream.bytes = _tombstone()
	assert("AudioThread" in reports._read_trace(te, func() -> Object: return null) and te.stream.closed)
	assert(reports._read_trace(te, func() -> Object: return te) == "")
	print("ANDROID REPORTS OK: first-error stop at all 9 getters; reason mapping; nullable description; desktop guard; tombstone summary")
	quit()
