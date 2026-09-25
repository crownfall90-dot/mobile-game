class_name LevelSkin
extends RefCounted
## Головоломка «внутри» ремонтируемой вещи: у каждой темы уровня (поле "theme" в JSON) свой вид.
##   place  — надпись-заставка в начале уровня («Внутри раковины»);
##   outer  — цвет вокруг вещи (комната), inner — фон внутри вещи;
##   walls  — материал стенок: [верх, низ, кромка, узор] (узор: wood, pipe, tile, enamel, plain);
##   dirt   — материал того, что копаем: [основной, тёмный, кромка, контур] и его название.
## Картинка art/act1/levels/<theme>.png, если есть, заменяет нарисованный кодом фон целиком.

const SKINS := {
	"window": {"place": "В оконной раме", "outer": "e8dcc6", "inner": "8fb3c9",
		"walls": ["c89a66", "9c6e44", "f0cfa0", "wood"], "dirt": ["9aa7a0", "7b8781", "c9d4ce", "4a5550"], "dirt_name": "мокрая замазка"},
	"bed": {"place": "Под старой кроватью", "outer": "e6d7ec", "inner": "5b4a63",
		"walls": ["9a6b4a", "6e4a33", "d8ac80", "wood"], "dirt": ["b3a7bd", "958aa1", "ddd3e6", "5e5468"], "dirt_name": "пыль"},
	"floor": {"place": "Под половицами", "outer": "c79a6e", "inner": "6b4a33",
		"walls": ["7a5236", "553622", "b88a60", "wood"], "dirt": ["9e6b45", "7d5234", "d9a86c", "553622"], "dirt_name": "земля"},
	"walls": {"place": "Внутри стены", "outer": "f1e1d5", "inner": "a8664e",
		"walls": ["c98b4a", "8f5a28", "f3c48c", "pipe"], "dirt": ["c9b8a3", "a8957e", "eee2d2", "6e604f"], "dirt_name": "штукатурка"},
	"sink": {"place": "Внутри раковины", "outer": "f4efe4", "inner": "dfeef3",
		"walls": ["cfd8df", "8f9ca7", "ffffff", "pipe"], "dirt": ["7d7a5c", "5f5c43", "a9a57c", "3d3b2a"], "dirt_name": "засор"},
	"stove": {"place": "В духовке", "outer": "f2e6cf", "inner": "3a302c",
		"walls": ["6d6560", "45403c", "b8aea6", "plain"], "dirt": ["4a4038", "322a24", "7a6a5c", "1f1915"], "dirt_name": "нагар"},
	"fridge": {"place": "В холодильнике", "outer": "eef3f6", "inner": "d6ecf7",
		"walls": ["f7fbfd", "c9dbe6", "8fb0c4", "enamel"], "dirt": ["e8f6ff", "bfe0f2", "ffffff", "7fa9c4"], "dirt_name": "лёд"},
	"cabinet": {"place": "В кухонном шкафу", "outer": "f4efe4", "inner": "a87850",
		"walls": ["c08a58", "8d5f39", "ecc293", "wood"], "dirt": ["d9b37a", "b8904f", "f2d6a4", "7a5a2e"], "dirt_name": "крошки"},
	"ceiling": {"place": "Над потолком", "outer": "f6f1e8", "inner": "8a7a64",
		"walls": ["6e5a44", "4a3a2a", "a88f72", "wood"], "dirt": ["e8dcc4", "cbbd9f", "fff6e2", "8a7c62"], "dirt_name": "штукатурка"},
	"tub": {"place": "В ванне", "outer": "dff1f2", "inner": "f7fbfb",
		"walls": ["ffffff", "d3e2e6", "9fbcc4", "enamel"], "dirt": ["b7c9b0", "95a88e", "e2eedd", "5c6e57"], "dirt_name": "налёт"},
	"toilet": {"place": "В трубах санузла", "outer": "e7f0dc", "inner": "6f7a73",
		"walls": ["b9c3c8", "7e8a91", "eef4f6", "pipe"], "dirt": ["7d7a5c", "5f5c43", "a9a57c", "3d3b2a"], "dirt_name": "засор"},
}


static func get_skin(theme: String) -> Dictionary:
	return SKINS.get(theme, {})


static func place(theme: String) -> String:
	return str(get_skin(theme).get("place", ""))


static func wall_palette(theme: String) -> Array:
	var w: Array = get_skin(theme).get("walls", [])
	if w.is_empty():
		return []
	return [Color(w[0]), Color(w[1]), Color(w[2]), str(w[3])]


static func dirt_colors(theme: String) -> Array:
	var d: Array = get_skin(theme).get("dirt", [])
	var out: Array = []
	for c in d:
		out.append(Color(c))
	return out


static func backdrop_texture(theme: String) -> Texture2D:
	var path := "res://art/act1/levels/%s.png" % theme
	return load(path) if ResourceLoader.exists(path) else null
