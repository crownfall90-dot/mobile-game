extends RefCounted
## Сцена комнаты (scenes/locations/<id>.tscn, собрана tools/make_location_scenes.py) → расстановка
## data/layout/<id>.json. Каждый предмет — Sprite2D с метаданными kind (target/prop/family) и
## key (id вещи или путь картинки). Берутся положение, размер (масштаб), отражение, поворот и
## порядок «кто впереди» (z_index / 100). Вызывает плагин addons/vita_layout при Ctrl+S и
## DevRunner по --layout-export=<id>.


static func export_scene(scene_path: String) -> String:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return ""
	var root := packed.instantiate()
	var loc_id := str(root.get_meta(&"location", scene_path.get_file().get_basename()))
	var out := {"targets": {}, "props": {}}
	for n in root.get_children():
		if not n is Sprite2D or not n.has_meta(&"kind"):
			continue
		var sp := n as Sprite2D
		if sp.texture == null:
			continue
		var sz := sp.texture.get_size() * sp.scale.abs()
		# прямоугольник по границам повёрнутой картинки — по нему кнопки и нажатия
		var rect := Rect2(sp.position - sz * 0.5, sz)
		if absf(sp.rotation) > 0.001:
			var xf := Transform2D(sp.rotation, sp.position)
			var box := Rect2(xf * (-sz * 0.5), Vector2.ZERO)
			for c in [Vector2(sz.x, -sz.y), sz, Vector2(-sz.x, sz.y)]:
				box = box.expand(xf * (c * 0.5))
			rect = box
		var entry := {
			"rect": [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)],
			"z": sp.z_index / 100.0,
			"flip": sp.flip_h != (sp.scale.x < 0.0),
		}
		if absf(sp.rotation) > 0.001:
			entry["rot"] = snappedf(sp.rotation, 0.001)
			entry["draw"] = [roundi(sp.position.x), roundi(sp.position.y), roundi(sz.x), roundi(sz.y)]
		match str(sp.get_meta(&"kind")):
			"target":
				out["targets"][str(sp.get_meta(&"key"))] = entry
			"prop":
				out["props"][str(sp.get_meta(&"key"))] = entry
			"family":
				out["family"] = {"pos": [roundi(sp.position.x), roundi(sp.position.y + sz.y * 0.5)], "height": roundi(sz.y)}
	root.free()
	DirAccess.make_dir_recursive_absolute("res://data/layout")
	var path := "res://data/layout/%s.json" % loc_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(out, " ", false) + "\n")
	return path
