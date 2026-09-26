extends RefCounted
## Leaving during a line, choice, card or background fade must release awaits,
## without granting unseen story progress or starting the next screen.

static func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var cases := [
		[{"say": "mother", "text": "Interrupted line"}],
		[{"choice": [{"text": "Answer", "then": [{"text": "Must not run"}]}]}],
		[{"cg": "letter", "text": "Interrupted card"}],
		[{"bg": "room"}, {"bg": "kitchen"}, {"text": "Must not run"}],
	]
	for steps in cases:
		var scene = load("res://scripts/screens/novel_screen.gd").new()
		tree.root.add_child(scene)
		scene.open({"scene": "__exit_check"})
		# open schedules _play for the next frame: supply a minimal real scenario.
		scene._data["scenes"]["__exit_check"] = steps
		await tree.process_frame
		await tree.process_frame
		var waiting: int = scene.get_signal_connection_list("_advance").size() \
			+ scene.get_signal_connection_list("_chosen").size()
		var tween: Tween = scene._bg_tween
		if tween:
			waiting += tween.get_signal_connection_list("finished").size()
		tree.root.remove_child(scene)
		var released: bool = scene.get_signal_connection_list("_advance").is_empty() \
			and scene.get_signal_connection_list("_chosen").is_empty()
		if tween:
			released = released and tween.get_signal_connection_list("finished").is_empty()
		var ok: bool = waiting > 0 and released and not Profile.flag("seen.novel.__exit_check")
		scene.free()
		if not ok:
			push_error("Dialogue exit left a waiter or marked unseen story as seen: %s" % str(steps))
			return false
	var hub = load("res://scripts/screens/hub_screen.gd").new()
	var seen := Profile.flag("seen.room")
	Profile.set_flag("seen.room")
	tree.root.add_child(hub)
	hub.open({"location": "room"})
	hub._say_lines([["mother", "Interrupted"], ["daughter", "Must not run"]])
	var bubble: Node = hub._bubbles["mother"]
	var was_waiting := not bubble.get_signal_connection_list("finished").is_empty()
	tree.root.remove_child(hub)
	var released := bubble.get_signal_connection_list("finished").is_empty()
	var no_next: bool = not hub._bubbles.has("daughter")
	hub.free()
	Profile.set_flag("seen.room", seen)
	if not was_waiting or not released or not no_next:
		push_error("Hub exit did not cancel its dialogue")
		return false
	# Both the initial pause and the repair animation can be interrupted too.
	for during_animation in [false, true]:
		hub = load("res://scripts/screens/hub_screen.gd").new()
		tree.root.add_child(hub)
		hub.open({"location": "room", "repaired": "room_window"})
		await tree.process_frame
		await tree.process_frame
		if during_animation:
			hub._delay.timeout.emit()
		var source: Node = hub._view if during_animation else hub._delay
		var sig := "repair_finished" if during_animation else "timeout"
		was_waiting = not source.get_signal_connection_list(sig).is_empty()
		tree.root.remove_child(hub)
		released = source.get_signal_connection_list(sig).is_empty()
		hub.free()
		if not was_waiting or not released:
			push_error("Hub exit did not cancel its repair wait")
			return false
	# A delayed FX callback must not run against the freed repair scene.
	await tree.create_timer(0.6).timeout
	print("DIALOGUE EXIT CHECK OK (line, choice, card, fade, hub, repair delay/animation)")
	return true
