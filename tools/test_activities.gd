extends RefCounted
## Каталог бытовых сценок (data/activities.json) согласован с квартирой: ключ — существующая
## вещь или предмет своей локации, у каждого действия есть подпись и сценка с понятными шагами,
## условия after/need ссылаются на настоящие вещи и покупки, новелла находит каждую сценку.

const ACTIVITIES := preload("res://scripts/core/activities.gd")
const SPEAKERS := ["mother", "daughter", "gloom"]
const LABEL_MAX := 24


static func run() -> bool:
	var errors: Array[String] = []
	var targets := {}
	var props := {}
	var shop := {}
	for it: Dictionary in Home.SHOP:
		shop[str(it["id"])] = true
	for l: Dictionary in Home.data().get("locations", []):
		for t: Dictionary in l.get("targets", []):
			targets[str(t["id"])] = str(l["id"])
		for pr: Dictionary in l.get("props", []):
			props[ACTIVITIES.prop_key(str(l["id"]), str(pr["img"]))] = true
	var all := ACTIVITIES.all()
	if all.is_empty():
		errors.append("activities.json is empty or unreadable")
	for key: String in all:
		if not targets.has(key) and not props.has(key):
			errors.append("%s: no such repair target or prop" % key)
		var acts: Array = all[key].get("acts", [])
		if acts.is_empty():
			errors.append("%s: no acts" % key)
		for i in acts.size():
			var a: Dictionary = acts[i]
			var label := str(a.get("label", ""))
			if label == "" or label.length() > LABEL_MAX:
				errors.append("%s[%d]: label empty or longer than %d" % [key, i, LABEL_MAX])
			if a.has("after") and not targets.has(str(a["after"])):
				errors.append("%s[%d]: after '%s' is not a repair target" % [key, i, a["after"]])
			if a.has("need") and not shop.has(str(a["need"])):
				errors.append("%s[%d]: need '%s' is not a shop item" % [key, i, a["need"]])
			var steps: Array = a.get("scene", [])
			var lines := 0
			for st: Dictionary in steps:
				if st.has("say"):
					lines += 1
					if not str(st["say"]) in SPEAKERS:
						errors.append("%s[%d]: unknown speaker %s" % [key, i, st["say"]])
				if st.has("bg") and Home.location(str(st["bg"])).is_empty():
					errors.append("%s[%d]: bg '%s' is not a location" % [key, i, st["bg"]])
			if lines == 0:
				errors.append("%s[%d]: scene has no lines" % [key, i])
	var scenes := ACTIVITIES.scenes()
	for key: String in all:
		for i in all[key].get("acts", []).size():
			if not scenes.has(ACTIVITIES.scene_id(key, i)):
				errors.append("%s[%d]: scene id not built" % [key, i])
	for e in errors:
		print("ACTIVITIES: ", e)
	print("ACTIVITIES: %d items, %d scenes, %s" % [all.size(), scenes.size(), "OK" if errors.is_empty() else "FAIL"])
	return errors.is_empty()
