extends SceneTree
## Собирает иконки приложения из art/app/*.svg (растеризатор ThorVG, окно не нужно):
##   icon_fg_432 / icon_bg_432 / icon_mono_432.png — слои адаптивной иконки Android;
##   icon_192.png — старая иконка лаунчера: фон + рисунок, скруглённый квадрат;
##   icon_512.png — иконка Google Play: квадрат без скругления (маску накладывает Play);
##   res://icon.svg — иконка проекта.
## Запуск: godot --headless --path . --script res://tools/make_icons.gd

const DIR := "res://art/app/"
const FULL := Rect2(0, 0, 108, 108)
const LEGACY := Rect2(16, 16, 76, 76)   # видимая часть слоёв для 192 и icon.svg
const PLAY := Rect2(14, 14, 80, 80)


func _initialize() -> void:
	var bg := _inner("icon_bg.svg")
	var fg := _inner("icon_fg.svg")
	var mono := _inner("icon_mono.svg")
	if bg == "" or fg == "" or mono == "":
		quit(1)
		return
	# в скруглённых версиях полноразмерный фон заменяется скруглённым прямоугольником
	var re := RegEx.create_from_string("<rect id=\"bg\"[^>]*/>")
	var rounded := re.sub(bg, "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"15\" fill=\"url(#bgGrad)\"/>"
		% [LEGACY.position.x, LEGACY.position.y, LEGACY.size.x, LEGACY.size.y])
	var ok := _png(_svg(fg, FULL, 432), "icon_fg_432.png")
	ok = _png(_svg(bg, FULL, 432), "icon_bg_432.png") and ok
	ok = _png(_svg(mono, FULL, 432), "icon_mono_432.png") and ok
	ok = _png(_svg(rounded + fg, LEGACY, 192), "icon_192.png") and ok
	ok = _png(_svg(bg + fg, PLAY, 512), "icon_512.png") and ok
	var f := FileAccess.open("res://icon.svg", FileAccess.WRITE)
	if f:
		f.store_string(_svg(rounded + fg, LEGACY, 256) + "\n")
		f.close()
		print("icon: res://icon.svg")
	quit(0 if ok and f else 1)


## Содержимое корневого <svg> без самого тега.
func _inner(file: String) -> String:
	var s := FileAccess.get_file_as_string(DIR + file)
	var a := s.find(">", s.find("<svg"))
	var b := s.rfind("</svg>")
	if s == "" or a < 0 or b < a:
		push_error("make_icons: cannot read %s" % file)
		return ""
	return s.substr(a + 1, b - a - 1)


func _svg(body: String, view: Rect2, px: int) -> String:
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"%d %d %d %d\">%s</svg>" \
		% [px, px, view.position.x, view.position.y, view.size.x, view.size.y, body]


func _png(svg: String, file: String) -> bool:
	var img := Image.new()
	if img.load_svg_from_string(svg, 1.0) != OK:
		push_error("make_icons: cannot rasterize %s" % file)
		return false
	var px := file.get_slice("_", file.get_slice_count("_") - 1).to_int()
	if img.get_width() != px or img.get_height() != px:
		push_error("make_icons: %s rendered as %dx%d" % [file, img.get_width(), img.get_height()])
		return false
	var err := img.save_png(ProjectSettings.globalize_path(DIR + file))
	print("icon: %s %dx%d %s" % [file, px, px, "ok" if err == OK else error_string(err)])
	return err == OK
