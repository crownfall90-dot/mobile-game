#!/usr/bin/env python3
"""Собирает сцены комнат для расстановки мышкой: scenes/locations/<id>.tscn.

Каждая вещь — Sprite2D со своей картинкой (сломанной, если есть), в месте и размере из
data/act1.json (и data/layout/<id>.json, если там уже сохранена расстановка). Метаданные kind/key
связывают спрайт с вещью игры. Фон заблокирован, рамка «Видно на телефоне» — область, которую
видно на любом экране. Двигай, меняй размер (Shift — с пропорциями), отражай (Flip H),
поворачивай, порядок «кто впереди» — Z Index. Ctrl+S — плагин Vita сохранит расстановку в
data/layout/<id>.json, и игра поставит всё так же.

  python3 tools/make_location_scenes.py            # все комнаты
  python3 tools/make_location_scenes.py room       # одна; существующую сцену перезаписывает
"""
import json
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ART = "art/act1/"


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
    if "family" in lay:
        loc["family"] = lay["family"]
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
            sprite("семья", ART + "family/family_mood0.png", [f["pos"][0] - w / 2, f["pos"][1] - h, w, h], 1.5, False, "family", "family")
    frame = "\n".join(['[node name="Видно на телефоне" type="ReferenceRect" parent="."]', "offset_left = 20.0", "offset_top = 140.0",
                       "offset_right = 680.0", "offset_bottom = 1280.0", "mouse_filter = 2", "border_color = Color(1, 0, 0.6, 1)",
                       "border_width = 3.0", "metadata/_edit_lock_ = true"])
    head = "[gd_scene load_steps=%d format=3]\n\n" % (len(ext) + 1)
    res = "".join('[ext_resource type="Texture2D" path="%s" id="%d"]\n' % (p, i + 1) for i, p in enumerate(ext))
    root = '\n[node name="%s" type="Node2D"]\nmetadata/location = "%s"\n\n' % (loc["id"], loc["id"])
    return head + res + root + "\n\n".join(nodes + [frame]) + "\n"


def main():
    data = json.load(open(os.path.join(ROOT, "data/act1.json"), encoding="utf-8"))
    only = sys.argv[1:] or [l["id"] for l in data["locations"]]
    os.makedirs(os.path.join(ROOT, "scenes/locations"), exist_ok=True)
    for loc in data["locations"]:
        if loc["id"] in only:
            out = os.path.join(ROOT, "scenes/locations/%s.tscn" % loc["id"])
            open(out, "w", encoding="utf-8").write(build(loc))
            print("scene", out)


if __name__ == "__main__":
    main()
