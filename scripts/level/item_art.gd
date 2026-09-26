class_name ItemArt
extends RefCounted
## Картинки монет, самоцветов и камней. Каждая один раз растеризуется из SVG,
## дальше тело рисует одну текстуру: движок склеивает одинаковые в один draw call.
## Без экрана (headless) ничего не создаётся.

const RASTER := 3.0   # растр крупнее поля: чётко и на экранах 1440p
const STONE_LOOKS := 6
const GEM_COLORS: Array[Color] = [Color("39d6ff"), Color("ff4fd8"), Color("4dff9a")]
const COIN_R := 11.0  # радиус, под который нарисованы монета и самоцвет
const STONE_R := 9.0
const BOX := 14.0     # половина стороны картинки при таком радиусе

const UPRIGHT_SHADER := """
shader_type canvas_item;
// Картинка не крутится вместе с телом: поворот модели снимается в вершинах.
void vertex() {
	vec2 x = normalize(MODEL_MATRIX[0].xy);
	VERTEX = mat2(vec2(x.x, -x.y), vec2(x.y, x.x)) * VERTEX;
}
"""

static var _cache: Dictionary = {}
static var _upright: ShaderMaterial


## null для жидкостей и в headless.
static func texture(kind: int, look: int) -> Texture2D:
	if DisplayServer.get_name() == "headless":
		return null
	var key := -1
	match kind:
		Substances.Kind.GOLD:
			key = 0
		Substances.Kind.GEM:
			key = 10 + posmod(look, GEM_COLORS.size())
		Substances.Kind.STONE:
			key = 20 + posmod(look, STONE_LOOKS)
		_:
			return null
	if not _cache.has(key):
		_cache[key] = _rasterize(_svg(kind, key))
	return _cache[key]


## Половина стороны квадрата, в который рисуется текстура тела радиуса r.
static func half_size(kind: int, r: float) -> float:
	return BOX * r / (STONE_R if kind == Substances.Kind.STONE else COIN_R)


static func upright_material() -> ShaderMaterial:
	if _upright == null:
		var sh := Shader.new()
		sh.code = UPRIGHT_SHADER
		_upright = ShaderMaterial.new()
		_upright.shader = sh
	return _upright


## Заранее готовит все картинки (экран загрузки), чтобы уровень не дёргался.
static func warm_up() -> void:
	texture(Substances.Kind.GOLD, 0)
	for i in GEM_COLORS.size():
		texture(Substances.Kind.GEM, i)
	for i in STONE_LOOKS:
		texture(Substances.Kind.STONE, i)
	upright_material()


static func _rasterize(svg: String) -> Texture2D:
	var img := Image.new()
	if img.load_svg_from_string(svg, RASTER) != OK:
		push_error("ItemArt: bad SVG")
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _svg(kind: int, key: int) -> String:
	var body := ""
	match kind:
		Substances.Kind.GOLD:
			body = _coin()
		Substances.Kind.GEM:
			body = _gem(GEM_COLORS[key - 10])
		Substances.Kind.STONE:
			body = _stone(key - 20)
	var s := BOX * 2.0
	return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%d %d %d %d">%s</svg>'
		% [s, s, -BOX, -BOX, s, s, body])


static func _coin() -> String:
	return ('<defs><radialGradient id="f" cx="-3" cy="-4.5" r="12" gradientUnits="userSpaceOnUse">'
		+ '<stop offset="0" stop-color="#ffe27a"/><stop offset="1" stop-color="#f5b52c"/></radialGradient></defs>'
		+ '<circle r="11" fill="#b8741a" stroke="#6e3f0c" stroke-width="1"/>'
		+ '<circle cy="-0.8" r="9" fill="url(#f)"/>'
		+ '<circle cy="-0.8" r="6" fill="none" stroke="#d9941f" stroke-width="1.5"/>'
		+ '<circle cx="-3.5" cy="-4" r="2.4" fill="#ffffff" fill-opacity="0.8"/>')


static func _gem(c: Color) -> String:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var p := Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * 12.1
		outer.append(p)
		inner.append(p * 0.55 + Vector2(0, -1.5))
	# верхние грани светлее нижних: камень освещён сверху
	var facets := ""
	for i in [3, 4]:
		facets += '<polygon points="%s" fill="#%s"/>' % [
			_pts([outer[i], outer[i + 1], inner[i + 1], inner[i]]), c.to_html(false)]
	return ('<polygon points="%s" fill="#%s" stroke="#%s" stroke-width="1" stroke-linejoin="round"/>'
			% [_pts(outer), c.darkened(0.35).to_html(false), c.darkened(0.7).to_html(false)]
		+ facets
		+ '<polygon points="%s" fill="#%s"/>' % [_pts(inner), c.lightened(0.3).to_html(false)]
		+ '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#ffffff" stroke-opacity="0.75" stroke-width="1.5" stroke-linecap="round"/>'
			% [outer[3].x * 0.85, outer[3].y * 0.85, outer[4].x * 0.85, outer[4].y * 0.85])


static func _stone(look: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = look + 1
	var pts := PackedVector2Array()
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
		pts.append(Vector2.from_angle(a) * STONE_R * rng.randf_range(0.85, 1.2))
	return ('<defs><linearGradient id="s" x1="0" y1="-9" x2="0" y2="9" gradientUnits="userSpaceOnUse">'
		+ '<stop offset="0" stop-color="#8d8aa3"/><stop offset="1" stop-color="#4a4760"/></linearGradient></defs>'
		+ '<polygon points="%s" fill="url(#s)" stroke="#2c2a3a" stroke-width="1.5" stroke-linejoin="round"/>' % _pts(pts)
		+ '<circle cx="-2.5" cy="-3" r="2.2" fill="#ffffff" fill-opacity="0.25"/>')


static func _pts(pts: PackedVector2Array) -> String:
	var parts := PackedStringArray()
	for p in pts:
		parts.append("%.2f,%.2f" % [p.x, p.y])
	return " ".join(parts)
