@tool
extends EditorPlugin
## Ctrl+S в сцене комнаты → data/layout/<id>.json: игра ставит мебель так, как в редакторе.

const EXPORT := preload("res://scripts/dev/layout_export.gd")


func _enter_tree() -> void:
	scene_saved.connect(_on_saved)


func _exit_tree() -> void:
	if scene_saved.is_connected(_on_saved):
		scene_saved.disconnect(_on_saved)


func _on_saved(path: String) -> void:
	if not path.begins_with("res://scenes/locations/"):
		return
	var out := EXPORT.export_scene(path)
	if out != "":
		print("Vita: расстановка сохранена в ", out)
	else:
		push_warning("Vita: не удалось сохранить расстановку из " + path)
