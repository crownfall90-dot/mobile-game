extends Node
## Автозагрузка "Game": список уровней и сохранение прогресса.

const INDEX_PATH := "res://levels/index.json"
const SAVE_PATH := "user://progress.cfg"

var level_paths: PackedStringArray = []
var current_level := 0
var best_stars: Dictionary = {}


func _ready() -> void:
	var index = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
	if index is Dictionary:
		for p in index.get("levels", []):
			level_paths.append("res://levels/%s" % p)
	if level_paths.is_empty():
		push_error("No levels listed in %s" % INDEX_PATH)
	_load_progress()


func level_count() -> int:
	return level_paths.size()


func load_level(i: int) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(level_paths[i]))
	if parsed is Dictionary:
		return parsed
	push_error("Broken level file %s" % level_paths[i])
	return {}


func complete_level(i: int, stars: int) -> void:
	best_stars[i] = maxi(int(best_stars.get(i, 0)), stars)
	current_level = (i + 1) % maxi(1, level_count())
	_save_progress()


func _load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	current_level = clampi(int(cfg.get_value("progress", "current_level", 0)), 0, maxi(0, level_count() - 1))
	best_stars = cfg.get_value("progress", "best_stars", {})


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", current_level)
	cfg.set_value("progress", "best_stars", best_stars)
	cfg.save(SAVE_PATH)
