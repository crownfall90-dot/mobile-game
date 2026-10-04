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
	print("ANDROID REPORTS OK: first-error stop at all 9 getters; reason mapping; nullable description; desktop guard")
	quit()
