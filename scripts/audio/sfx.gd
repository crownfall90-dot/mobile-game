extends Node
## Автозагрузка "Sfx": синтезированные звуки (DESIGN §12), вибрация и музыка.
## prepare() на экране загрузки по кусочкам синтезирует таблицу sfx_bank.gd; play() берёт
## плеер из пула. Без окна (headless) всё молчит, чтобы проверки уровней оставались чистыми.

const Synth := preload("res://scripts/audio/synth.gd")
const Bank := preload("res://scripts/audio/sfx_bank.gd")
const Music := preload("res://scripts/audio/music.gd")

const POOL := 8
const PITCH_JITTER := 0.04
const MUSIC_DB := -15.0          # пик музыки −3 дБFS, в миксе −18 дБ
const MUSIC_DELAY := 1.0         # музыку считаем, когда хаб уже на экране
const TICK_GAP_MS := 150         # короткие «тики» вибрации (превращения) не чаще

var _enabled := false
var _streams := {}               # id -> AudioStreamWAV
var _order: Array = []
var _prep := 0
var _prepared := false
var _job_buf := PackedFloat32Array()
var _job_layers: Array = []
var _job_step := 0
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _last_ms := {}               # id -> время последнего запуска, мс
var _warned := {}
var _rng := RandomNumberGenerator.new()
var _sfx_on := true
var _music_on := true
var _vibration_on := true
var _suspended := false
var _last_tick_ms := -100000
var _music_player: AudioStreamPlayer
var _music_task := -1
var _music_pcm := PackedByteArray()
var _music_tween: Tween
var _sfx_bus := -1


func _ready() -> void:
	_enabled = DisplayServer.get_name() != "headless"
	if not _enabled:
		return
	# звуки кнопок в паузе тоже должны играть
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	_rng.randomize()
	_order = Bank.TABLE.keys()
	_sfx_bus = _ensure_bus(&"SFX")
	_ensure_bus(&"Music")
	if AudioServer.get_bus_effect_count(0) == 0:
		AudioServer.add_bus_effect(0, AudioEffectHardLimiter.new())
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	_music_player.volume_db = -60.0
	add_child(_music_player)
	var profile := get_node_or_null(^"/root/Profile")
	if profile and profile.has_signal(&"changed"):
		profile.connect(&"changed", _on_profile_changed)
	_read_settings()


## Зовётся каждый кадр загрузки, пока не вернёт true. Считает слои по одному,
## чтобы кадр не выходил за budget_ms.
func prepare(budget_ms: int) -> bool:
	if not _enabled or _prepared:
		return true
	var deadline := Time.get_ticks_usec() + budget_ms * 1000
	while _prep < _order.size():
		var id: StringName = _order[_prep]
		if _streams.has(id):
			_prep += 1
			_job_layers = []
			_job_step = 0
			continue
		if _job_step == 0:
			_job_buf = Synth.buffer(Bank.TABLE[id][0])
			_job_layers = Bank.layers(id)
		while _job_step < _job_layers.size():
			Bank.apply(_job_buf, _job_layers[_job_step])
			_job_step += 1
			if Time.get_ticks_usec() >= deadline:
				return false
		_streams[id] = Synth.to_stream(_job_buf)
		_job_buf = PackedFloat32Array()
		_job_layers = []
		_job_step = 0
		_prep += 1
		if Time.get_ticks_usec() >= deadline:
			break
	if _prep < _order.size():
		return false
	_prepared = true
	if _music_on:
		get_tree().create_timer(MUSIC_DELAY, true).timeout.connect(_on_music_delay)
	return true


func play(id: StringName, semitones := 0.0, volume_db := 0.0) -> void:
	if not _enabled or not _sfx_on or _suspended:
		return
	var row: Array = Bank.TABLE.get(id, [])
	if row.is_empty():
		if not _warned.has(id):
			_warned[id] = true
			push_warning("Sfx: нет звука %s" % id)
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(id, -100000)) < int(row[2]):
		return
	_last_ms[id] = now
	var stream: AudioStreamWAV = _streams.get(id)
	if stream == null:
		# prepare() ещё не дошёл до этого звука — синтезируем один сейчас
		stream = Bank.render(id)
		_streams[id] = stream
	var p := _free_player()
	p.stream = stream
	p.volume_db = float(row[1]) + volume_db
	if semitones != 0.0 or row[3]:
		p.pitch_scale = pow(2.0, clampf(semitones, -24.0, 24.0) / 12.0)
	else:
		p.pitch_scale = 1.0 + _rng.randf_range(-PITCH_JITTER, PITCH_JITTER)
	p.play()


func haptic(ms: int) -> void:
	if not _enabled or not _vibration_on or _suspended or OS.get_name() != "Android":
		return
	if ms <= 10:
		var now := Time.get_ticks_msec()
		if now - _last_tick_ms < TICK_GAP_MS:
			return
		_last_tick_ms = now
	Input.vibrate_handheld(ms, 0.5)


func set_music(on: bool) -> void:
	_music_on = on
	if not _enabled:
		return
	if on and _prepared and not _suspended:
		_start_music()
	elif not on:
		_fade_music(false)


func _on_music_delay() -> void:
	if _music_on and not _suspended:
		_start_music()


func _free_player() -> AudioStreamPlayer:
	for k in POOL:
		var i := (_next_player + k) % POOL
		if not _players[i].playing:
			_next_player = (i + 1) % POOL
			return _players[i]
	# все заняты — перезапускаем самый давний по кругу
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % POOL
	return p


func _start_music() -> void:
	if _music_player.stream != null:
		if not _music_player.playing:
			_music_player.play()
		_fade_music(true)
		return
	if _music_task == -1:
		_music_task = WorkerThreadPool.add_task(_render_music, false, "music")
		set_process(true)


func _render_music() -> void:
	_music_pcm = Music.load_or_render()


func _process(_delta: float) -> void:
	if _music_task == -1 or not WorkerThreadPool.is_task_completed(_music_task):
		return
	WorkerThreadPool.wait_for_task_completion(_music_task)
	_music_task = -1
	set_process(false)
	if _music_pcm.is_empty():
		return
	_music_player.stream = Synth.from_pcm16(_music_pcm, true)
	_music_pcm = PackedByteArray()
	if _music_on and not _suspended:
		_start_music()


func _fade_music(fade_in: bool) -> void:
	if _music_tween:
		_music_tween.kill()
	if not _music_player.playing:
		return
	_music_tween = create_tween()
	if fade_in:
		_music_tween.tween_property(_music_player, "volume_db", MUSIC_DB, 2.0)
	else:
		_music_tween.tween_property(_music_player, "volume_db", -60.0, 0.6)
		_music_tween.tween_callback(_music_player.stop)


func _read_settings() -> void:
	_sfx_on = _setting(&"sfx")
	_vibration_on = _setting(&"vibration")
	AudioServer.set_bus_mute(_sfx_bus, not _sfx_on)
	set_music(_setting(&"music"))


func _setting(key: StringName) -> bool:
	var profile := get_node_or_null(^"/root/Profile")
	if profile == null or not profile.has_method(&"setting"):
		return true
	var v: Variant = profile.call(&"setting", key)
	return true if v == null else bool(v)


func _on_profile_changed(key: Variant) -> void:
	if str(key) == "settings":
		_read_settings()


func _ensure_bus(bus_name: StringName) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	return idx


func _notification(what: int) -> void:
	if not _enabled:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_suspend(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_suspend(false)


## Свернули приложение или потеряли фокус: глушим всё сразу, музыку потом продолжаем.
func _suspend(v: bool) -> void:
	if _suspended == v:
		return
	_suspended = v
	AudioServer.set_bus_mute(0, v)
	if not v and _music_on and _prepared:
		_start_music()


func _exit_tree() -> void:
	if _music_task != -1:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
