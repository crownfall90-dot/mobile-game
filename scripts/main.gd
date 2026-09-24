extends Node
## Корневая сцена: фон, уровень, интерфейс, переходы между уровнями.
##
## Параметры запуска для разработки (после "--" в командной строке):
##   --level=N        открыть уровень N (с нуля)
##   --autoplay       пройти уровень по полю "solution" и выйти с кодом 0 при победе
##   --pins=a,b,c     пройти уровень, дёргая штыри в указанном порядке
##   --shot=путь.png[@сек]  сохранить скриншот (по умолчанию через 2.5 с; нужен графический режим)

const BG_SHADER := preload("res://shaders/background.gdshader")
const LOSE_TEXT := {
	"lava": "Ученица обожглась о лаву.",
	"acid": "Кислота добралась до ученицы.",
	"enemy": "Слизень добрался до ученицы.",
	"stuck": "Не хватило золота или враг ещё жив.",
}

var _world: Node2D
var _camera: Camera2D
var _level: Level
var _hud: Hud
var _index := 0
var _script_pins := PackedStringArray()
var _scripted := false
var _shot_pending := false


func _ready() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	bg.material = mat
	bg_layer.add_child(bg)

	_world = Node2D.new()
	add_child(_world)
	# Уровень всегда живёт в координатах 720x1280; под экран его подгоняет камера,
	# а не масштаб узлов, чтобы не трогать физику.
	_camera = Camera2D.new()
	_camera.position = Level.DESIGN_SIZE * 0.5
	add_child(_camera)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	_hud = Hud.new()
	ui.add_child(_hud)
	_hud.restart_requested.connect(func() -> void: _load(_index))
	_hud.next_requested.connect(func() -> void: _load(Game.current_level))

	get_viewport().size_changed.connect(_layout)
	_index = Game.current_level
	_parse_args()
	_load(_index)
	_layout()


func _load(i: int) -> void:
	_index = i
	if _level:
		_level.queue_free()
	_level = Level.new()
	_world.add_child(_level)
	var data := Game.load_level(i)
	_level.camera = _camera
	_level.build(data)
	_level.gold_changed.connect(_hud.set_gold)
	_level.pin_pulled.connect(func(_p: Pin) -> void: _hud.hide_hint())
	_level.won.connect(_on_won)
	_level.lost.connect(_on_lost)
	_hud.set_level("Уровень %d" % (i + 1), str(data.get("hint", "")))
	_world.modulate.a = 0.0
	create_tween().tween_property(_world, "modulate:a", 1.0, 0.35)
	if _scripted:
		_play_script()


func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var s := minf(vs.x / Level.DESIGN_SIZE.x, vs.y / Level.DESIGN_SIZE.y)
	_camera.zoom = Vector2(s, s)
	# отступ под вырез камеры / статус-бар
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y > 0:
		_hud.set_safe_top(maxf(0.0, safe.position.y) * vs.y / win.y)


func _on_won(stars: int) -> void:
	Game.complete_level(_index, stars)
	_hud.show_result(true, stars, "Золото: %d из %d" % [_level.gold_collected, _level.gold_total])
	if _scripted:
		_finish_script(0, "WON stars=%d gold=%d/%d" % [stars, _level.gold_collected, _level.gold_total])


func _on_lost(reason: String) -> void:
	_hud.show_result(false, 0, LOSE_TEXT.get(reason, "Попробуй другой порядок."))
	if _scripted:
		_finish_script(1, "LOST reason=%s" % reason)


# --- инструменты разработки ------------------------------------------------

func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_index = clampi(int(arg.get_slice("=", 1)), 0, Game.level_count() - 1)
		elif arg == "--autoplay":
			_scripted = true
		elif arg.begins_with("--pins="):
			_scripted = true
			_script_pins = arg.get_slice("=", 1).split(",")
		elif arg.begins_with("--shot="):
			_shot_pending = true
			_take_shot(arg.get_slice("=", 1))


func _play_script() -> void:
	var order := _script_pins
	if order.is_empty():
		for id in _level.data.get("solution", []):
			order.append(str(id))
	await get_tree().create_timer(1.0).timeout
	for id in order:
		print("pull ", id)
		_level.pull_pin(_level.pin_by_id(id))
		await get_tree().create_timer(1.5).timeout
	await get_tree().create_timer(12.0).timeout
	_finish_script(2, "TIMEOUT")


func _finish_script(code: int, text: String) -> void:
	print("RESULT: ", text)
	while _shot_pending:
		await get_tree().process_frame
	get_tree().quit(code)


func _take_shot(spec: String) -> void:
	var path := spec.get_slice("@", 0)
	var delay := float(spec.get_slice("@", 1)) if spec.contains("@") else 2.5
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	_shot_pending = false
