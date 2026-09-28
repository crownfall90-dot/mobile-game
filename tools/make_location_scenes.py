#!/usr/bin/env python3
"""Собирает сцены комнат для расстановки мышкой: scenes/locations/<id>.tscn.

Каждая вещь — Sprite2D со своей картинкой (сломанной, если есть), в месте и размере из
data/act1.json (и data/layout/<id>.json, если там уже сохранена расстановка). Метаданные kind/key
связывают спрайт с вещью игры. Фон заблокирован, рамка «Видно на телефоне» — область, которую
видно на любом экране. Двигай, меняй размер (Shift — с пропорциями), отражай (Flip H),
поворачивай, порядок «кто впереди» — Z Index. Ctrl+S — плагин Vita сохранит расстановку в
data/layout/<id>.json, и игра поставит всё так же.

Купленный декор (цветок, картина) без своей картинки — розовая рамка с подписью: двигай и тяни
за края; отражение — галочка metadata/flip. У семьи игра берёт место, высоту и Flip H.

  python3 tools/make_location_scenes.py            # все комнаты
  python3 tools/make_location_scenes.py room       # одна; существующую сцену перезаписывает
  python3 tools/make_location_scenes.py room --as room_pilot   # в scenes/locations/room_pilot.tscn
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ART = "art/act1/"
DECOR_NAMES = {"vita_plant": "цветок (покупка)", "vita_picture": "картина (покупка)"}


def png_size(res_path):
    p = os.path.join(ROOT, res_path.replace("res://", ""))
    if not os.path.exists(p):
        return None
    with Image.open(p) as im:
        return im.size


def layout_for(loc):
    p = os.path.join(ROOT, "data/layout/%s.json" % loc["id"])
    if not os.path.exists(p):
        return loc
    lay = json.load(open(p, encoding="utf-8"))
    for t in loc["targets"]:
        t.update(lay.get("targets", {}).get(t["id"], {}))
    for pr in loc.get("props", []):
        pr.update(lay.get("props", {}).get(pr["img"], {}))
    for d in loc.get("decor", []):
        d.update(lay.get("decor", {}).get(d["id"], {}))
    if "family" in lay and "family" in loc:
        loc["family"].update(lay["family"])
    return loc


def build(loc):
    loc = layout_for(loc)
    ext = []
    nodes = []

    def tex(path):
        path = "res://" + path
        if path not in ext:
            ext.append(path)
        return 'ExtResource("%d")' % (ext.index(path) + 1)

    def sprite(name, path, rect, z, flip, kind, key, rot=None, draw=None):
        size = png_size("res://" + path)
        if size is None:
            return
        tw, th = size
        x, y, w, h = rect
        if draw:
            cx, cy, w, h = draw
            k = min(w / tw, h / th)
        else:
            k = min(w / tw, h / th)
            cx, cy = x + w / 2.0, y + h / 2.0
        lines = ['[node name="%s" type="Sprite2D" parent="."]' % name,
                 "z_index = %d" % max(-4000, min(4000, round(float(z) * 100))),
                 "position = Vector2(%g, %g)" % (round(cx, 1), round(cy, 1))]
        if rot:
            lines.append("rotation = %g" % rot)
        lines += ["scale = Vector2(%g, %g)" % (round(k, 4), round(k, 4)),
                  "texture = %s" % tex(path)]
        if flip:
            lines.append("flip_h = true")
        lines += ['metadata/kind = "%s"' % kind, 'metadata/key = "%s"' % key]
        nodes.append("\n".join(lines))

    bg = ART + "%s/background.png" % loc["id"]
    size = png_size("res://" + bg)
    if size:
        nodes.append("\n".join(['[node name="Фон" type="Sprite2D" parent="."]', "z_index = -1000",
                                "position = Vector2(360, 780)", "scale = Vector2(%g, %g)" % (720 / size[0], 720 / size[0]),
                                "texture = %s" % tex(bg), "metadata/_edit_lock_ = true"]))
    for t in loc["targets"]:
        name = t["id"]
        path = ART + "%s/%s_broken.png" % (loc["id"], name)
        if png_size("res://" + path) is None:
            path = ART + "%s/%s_fixed.png" % (loc["id"], name)
        sprite(name, path, t["rect"], t.get("z", 0), t.get("flip", False), "target", name, t.get("rot"), t.get("draw"))
    for pr in loc.get("props", []):
        name = pr["img"].replace("/", "__")
        sprite(name, ART + pr["img"] + ".png", pr["rect"], pr.get("z", 0), pr.get("flip", False), "prop", pr["img"],
               pr.get("rot"), pr.get("draw"))
    if "family" in loc:
        f = loc["family"]
        size = png_size("res://" + ART + "family/family_mood0.png")
        if size:
            h = f["height"]
            w = h * size[0] / size[1]
            sprite("семья", ART + "family/family_mood0.png", [f["pos"][0] - w / 2, f["pos"][1] - h, w, h], 1.5, f.get("flip", False),
                   "family", "family")
    for d in loc.get("decor", []):
        # декор магазина рисуется за семьёй; своя картинка — спрайтом, иначе рамка с подписью
        png = ART + "%s/%s.png" % (loc["id"], d["id"])
        if png_size("res://" + png):
            sprite("декор_" + d["id"], png, d["rect"], 1.5, d.get("flip", False), "decor", d["id"])
            continue
        x, y, w, h = d["rect"]
        nodes.append("\n".join(['[node name="декор_%s" type="ReferenceRect" parent="."]' % d["id"], "z_index = 150",
                                 "offset_left = %g" % x, "offset_top = %g" % y, "offset_right = %g" % (x + w),
                                 "offset_bottom = %g" % (y + h), "mouse_filter = 2", "border_color = Color(0.2, 0.7, 0.3, 1)",
                                 "border_width = 2.0", 'metadata/kind = "decor"', 'metadata/key = "%s"' % d["id"],
                                 "metadata/flip = %s" % ("true" if d.get("flip") else "false")]))
        nodes.append("\n".join(['[node name="подпись" type="Label" parent="декор_%s"]' % d["id"], "offset_right = %g" % max(w, 120),
                                 "offset_bottom = 23.0", 'text = "%s"' % DECOR_NAMES.get(d["id"], d["id"]),
                                 "theme_override_font_sizes/font_size = 14"]))
    frame = "\n".join(['[node name="Видно на телефоне" type="ReferenceRect" parent="."]', "offset_left = 20.0", "offset_top = 140.0",
                       "offset_right = 680.0", "offset_bottom = 1280.0", "mouse_filter = 2", "border_color = Color(1, 0, 0.6, 1)",
                       "border_width = 3.0", "metadata/_edit_lock_ = true"])
    head = "[gd_scene load_steps=%d format=3]\n\n" % (len(ext) + 1)
    res = "".join('[ext_resource type="Texture2D" path="%s" id="%d"]\n' % (p, i + 1) for i, p in enumerate(ext))
    root = '\n[node name="%s" type="Node2D"]\nmetadata/location = "%s"\n\n' % (loc["id"], loc["id"])
    return head + res + root + "\n\n".join(nodes + [frame]) + "\n"


def main():
    data = json.load(open(os.path.join(ROOT, "data/act1.json"), encoding="utf-8"))
    args = sys.argv[1:]
    name = None
    if "--as" in args:
        i = args.index("--as")
        name = args[i + 1]
        del args[i:i + 2]
    only = args or [l["id"] for l in data["locations"]]
    os.makedirs(os.path.join(ROOT, "scenes/locations"), exist_ok=True)
    for loc in data["locations"]:
        if loc["id"] in only:
            out = os.path.join(ROOT, "scenes/locations/%s.tscn" % (name or loc["id"]))
            open(out, "w", encoding="utf-8").write(build(loc))
            print("scene", out)


if __name__ == "__main__":
    main()
