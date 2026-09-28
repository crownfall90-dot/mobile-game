extends RefCounted
## Сцена комнаты (scenes/locations/<id>.tscn, собрана tools/make_location_scenes.py) → расстановка
## data/layout/<id>.json. Каждый предмет — Sprite2D с метаданными kind (target/prop/family) и
## key (id вещи или путь картинки). Берутся положение, размер (масштаб), отражение, поворот и
## порядок «кто впереди» (z_index / 100). Масштаб всегда один на обе оси (меньший из Scale X/Y):
## игра картинки не растягивает. У семьи — только место, высота и отражение (поворот и Z игра не
## берёт: пара всегда между дальними и ближними вещами). Купленный декор без своей картинки —
## рамка ReferenceRect (kind "decor"), берутся её место, размер и отражение (метаданные flip).
## Вызывает плагин addons/vita_layout при Ctrl+S и DevRunner по --layout-export=<id>.


static func export_scene(scene_path: String) -> String:
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return ""
	var root := packed.instantiate()
	var loc_id := str(root.get_meta(&"location", scene_path.get_file().get_basename()))
	var out := {"targets": {}, "props": {}, "decor": {}}
	for n in root.get_children():
		if not n.has_meta(&"kind"):
			continue
		if n is Control and str(n.get_meta(&"kind")) == "decor":
			var c := n as Control
			out["decor"][str(c.get_meta(&"key"))] = {"rect": [roundi(c.position.x), roundi(c.position.y), roundi(c.size.x), roundi(c.size.y)],
				"flip": bool(c.get_meta(&"flip", false))}
			continue
		if not n is Sprite2D:
			continue
		var sp := n as Sprite2D
		if sp.texture == null:
			continue
		# растянутая по одной оси картинка в игре вписывается без растяжения — берём меньший масштаб
		var sz := sp.texture.get_size() * minf(absf(sp.scale.x), absf(sp.scale.y))
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
		# вид «спиной» (картинка *_back.png, подставлена в редакторе): игра берёт такие же для
		# сломанного и починенного состояния
		if sp.texture.resource_path.get_basename().ends_with("_back"):
			entry["view"] = "back"
		if absf(sp.rotation) > 0.001:
			entry["rot"] = snappedf(sp.rotation, 0.001)
			entry["draw"] = [roundi(sp.position.x), roundi(sp.position.y), roundi(sz.x), roundi(sz.y)]
		match str(sp.get_meta(&"kind")):
			"target":
				out["targets"][str(sp.get_meta(&"key"))] = entry
			"prop":
				out["props"][str(sp.get_meta(&"key"))] = entry
			"decor":
				entry.erase("view")
				out["decor"][str(sp.get_meta(&"key"))] = entry
			"family":
				out["family"] = {"pos": [roundi(sp.position.x), roundi(sp.position.y + sz.y * 0.5)], "height": roundi(sz.y),
					"flip": entry["flip"]}
	root.free()
	if out["decor"].is_empty():
		out.erase("decor")
	DirAccess.make_dir_recursive_absolute("res://data/layout")
	var path := "res://data/layout/%s.json" % loc_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(out, " ", false) + "\n")
	return path
