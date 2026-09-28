#!/usr/bin/env python3
"""Планировщик комнат: одна камера на все локации, реальные размеры → прямоугольники на экране.

Камера «с высоты взгляда, 45° к углу»: смотрит на дальний угол комнаты, глаз на высоте EYE,
горизонт — строка HORIZON сцены 720×1560. Пол: L — метры вдоль левой стены от угла (это же
расстояние от правой стены), R — вдоль правой стены (расстояние от левой). Предмет — коробка
L0..L1 × R0..R1 × H0..H1 (метры); настенный — тонкая коробка у стены.

  python3 tools/room_planner.py            # таблицы для docs/LAYOUT_PLAN.md
  python3 tools/room_planner.py --guides   # + каркасные эскизы art/act1/reviews/layout/<room>.png
  python3 tools/room_planner.py --apply room [--out копия.json]   # rect, z по глубине и тени в act1.json
  python3 tools/room_planner.py --item-guides room   # каркас каждого предмета в размер PNG

Экранный прямоугольник предмета — рамка его 8 проекций; PNG для ChatGPT — вдвое крупнее (2x).
"""
import json
import math
import os
import sys

W, H = 720, 1560          # сцена
SAFE = (20, 140, 680, 1280)  # видно на 16:9 и 20:9
EYE = 1.5                 # глаз камеры, м (глаза мамы 1,53 — на горизонте)
HORIZON = 700             # строка горизонта
FOCAL = 792.0             # px: мама 1,65 м в 2,4 м от камеры = 545 px
CEIL = 2.6                # высота потолка, м
S2 = math.sqrt(2.0)

# Комнаты: size — длина левой и правой стены (м); видно ~2,2 м каждой от угла. Предметы: kind: floor (стоит на полу), wall (на стене), hang (с потолка),
# person (фигура: ширина, высота).
ROOMS = {
    "room": {
        "title": "Маленькая комната", "size": [3.0, 3.0],
        "items": [
            {"act": "target:room_window", "id": "window", "kind": "wall", "wall": "L", "at": [0.2, 1.0], "h": [0.85, 2.1], "note": "цель room_window: рама, стекло, подоконник 0,85"},
            {"act": "prop:room/room_curtains", "id": "curtains", "kind": "wall", "wall": "L", "at": [0.08, 1.12], "h": [0.75, 2.3], "note": "шторы по краям окна"},
            {"act": "prop:room/room_chest", "id": "chest", "kind": "floor", "L": [0.16, 0.92], "R": [0.0, 0.42], "h": [0.0, 0.8], "note": "комод под окном (низ за Витой — доступ кнопкой)"},
            {"act": "prop:room/room_nightstand", "id": "nightstand", "kind": "floor", "L": [0.95, 1.35], "R": [0.62, 0.92], "h": [0.0, 0.55], "note": "тумбочка у изголовья со стороны комнаты (в углу её закрыло бы изголовье)"},
            {"act": "target:room_bed", "id": "bed", "kind": "floor", "L": [0.0, 0.9], "R": [0.32, 2.0], "h": [0.0, 0.5],
             "parts": [{"L": [0.0, 0.9], "R": [0.32, 0.36], "h": [0.0, 0.95]}, {"L": [0.0, 0.9], "R": [1.96, 2.0], "h": [0.0, 0.8]}], "note": "цель room_bed: кровать 1,7 м вдоль правой стены, изголовье к углу, матрас 0,5, спинки 0,9"},
            {"act": "target:room_wall", "id": "wall_patch", "kind": "wall", "wall": "R", "at": [1.0, 1.5], "h": [1.05, 1.55], "note": "цель room_wall: порванные обои над кроватью"},
            {"act": "prop:room/room_toybox", "id": "toybox", "kind": "floor", "L": [1.0, 1.42], "R": [1.38, 1.71], "h": [0.0, 0.35], "note": "ящик с игрушками у кровати"},
            {"act": "prop:room/room_table_lamp", "id": "table_lamp", "fill": True, "kind": "floor", "L": [1.04, 1.26], "R": [0.67, 0.87], "h": [0.55, 0.95], "note": "настольная лампа на тумбочке, тёплый абажур"},
            {"act": "prop:room/room_shelf_books", "id": "shelf_books", "fill": True, "kind": "wall", "wall": "R", "at": [1.45, 1.95], "h": [1.45, 1.75], "depth": 0.2, "note": "НОВОЕ: полка над изножьем — книжки и плюшевый зайчик"},
            {"act": "prop:room/room_drawings", "id": "drawings", "fill": True, "kind": "wall", "wall": "R", "at": [0.45, 0.85], "h": [1.2, 1.55], "note": "НОВОЕ: рисунки Виты на скотче над изголовьем"},
            {"act": "prop:room/room_slippers", "id": "slippers", "fill": True, "kind": "floor", "L": [1.28, 1.53], "R": [0.98, 1.28], "h": [0.0, 0.08], "note": "тапочки у кровати, перед тумбочкой"},
            {"act": "prop:room/room_blocks", "id": "blocks", "fill": True, "kind": "floor", "L": [1.52, 1.82], "R": [1.4, 1.7], "h": [0.0, 0.1], "note": "кубики между ковриком и ящиком"},
            {"act": "prop:room/room_suitcase", "id": "suitcase", "fill": True, "kind": "floor", "L": [0.95, 1.4], "R": [1.98, 2.26], "h": [0.0, 0.45], "note": "чемодан у изножья — только переехали"},
            {"act": "prop:room/room_rug", "id": "rug", "kind": "floor", "L": [1.72, 2.67], "R": [0.72, 1.67], "h": [0.0, 0.01], "note": "круглый коврик ~1 м под семьёй"},
            {"act": "target:room_floor", "id": "floor_holes", "kind": "floor", "L": [1.4, 1.8], "R": [1.98, 2.32], "h": [0.0, 0.01], "note": "цель room_floor: дыра на открытом полу справа спереди, не под ковриком и не под ногами"},
            {"act": "decor:vita_plant", "id": "plant_buy", "kind": "floor", "L": [0.2, 0.4], "R": [0.1, 0.3], "h": [0.8, 1.15], "note": "покупка «Зелёный друг»: цветок на комоде"},
            {"act": "decor:vita_picture", "id": "picture_buy", "kind": "wall", "wall": "L", "at": [1.4, 1.85], "h": [1.72, 2.08], "note": "покупка «Наши счастливые дни»: картина на левой стене"},
            {"act": "family", "id": "family_pair", "kind": "person", "L": 2.15, "R": 1.23, "size": [0.9, 1.65], "note": "мама и Вита держатся за руки на коврике — картинки настроения family_mood0..3 (в первой комнате — «приехали»)"},
        ],
    },
    "kitchen": {
        "title": "Кухня", "size": [3.0, 3.0],
        "items": [
            {"id": "fridge", "kind": "floor", "L": [0.0, 0.62], "R": [0.02, 0.62], "h": [0.0, 1.5], "note": "цель kitchen_fridge: невысокий старый холодильник в углу"},
            {"id": "sink", "kind": "floor", "L": [0.0, 0.6], "R": [0.65, 1.45], "h": [0.0, 0.88], "note": "цель kitchen_sink: тумба с мойкой вдоль правой стены"},
            {"id": "stove", "kind": "floor", "L": [0.0, 0.6], "R": [1.48, 2.0], "h": [0.0, 0.88], "note": "цель kitchen_stove: плита рядом с мойкой"},
            {"id": "kettle", "kind": "floor", "L": [0.12, 0.34], "R": [1.6, 1.85], "h": [0.88, 1.1], "note": "чайник на конфорке"},
            {"id": "cabinets", "kind": "wall", "wall": "R", "at": [0.65, 1.45], "h": [1.45, 2.05], "depth": 0.32, "note": "цель kitchen_cabinets: навесной шкафчик над мойкой"},
            {"id": "shelf_jars", "kind": "wall", "wall": "R", "at": [1.5, 1.98], "h": [1.5, 1.72], "depth": 0.2, "note": "полка с банками над плитой"},
            {"id": "window", "kind": "wall", "wall": "L", "at": [0.9, 1.9], "h": [0.9, 2.05], "note": "окно на левой стене (новое)"},
            {"id": "clock", "kind": "wall", "wall": "L", "at": [0.3, 0.6], "h": [1.75, 2.05], "note": "часы между углом и окном"},
            {"id": "table", "kind": "floor", "L": [0.95, 1.85], "R": [0.1, 0.8], "h": [0.0, 0.75], "note": "обеденный стол под окном"},
            {"id": "breadbox", "kind": "floor", "L": [1.15, 1.45], "R": [0.2, 0.42], "h": [0.75, 0.92], "note": "хлебница на столе"},
            {"id": "plates", "fill": True, "kind": "floor", "L": [1.4, 1.75], "R": [0.25, 0.65], "h": [0.75, 0.82], "note": "НОВОЕ: две тарелки и чашки на столе"},
            {"id": "fruit_bowl", "fill": True, "kind": "floor", "L": [1.02, 1.2], "R": [0.5, 0.7], "h": [0.75, 0.88], "note": "НОВОЕ: миска с яблоками на столе"},
            {"id": "window_plant", "fill": True, "kind": "wall", "wall": "L", "at": [1.25, 1.55], "h": [0.9, 1.25], "depth": 0.15, "note": "НОВОЕ: цветок в горшке на подоконнике"},
            {"id": "towel", "fill": True, "kind": "wall", "wall": "R", "at": [1.44, 1.5], "h": [0.95, 1.35], "note": "НОВОЕ: полотенце на крючке между мойкой и плитой"},
            {"id": "stool", "fill": True, "kind": "floor", "L": [1.65, 1.95], "R": [0.95, 1.25], "h": [0.0, 0.45], "note": "НОВОЕ: табурет"},
            {"id": "chair", "kind": "floor", "L": [1.2, 1.6], "R": [0.9, 1.3], "h": [0.0, 0.85], "note": "стул Виты у стола, сиденье 0,45"},
            {"id": "rug", "kind": "floor", "L": [0.7, 1.2], "R": [0.8, 2.0], "h": [0.0, 0.01], "note": "половик вдоль мойки и плиты"},
            {"id": "ceiling_hole", "kind": "hang", "L": [0.9, 1.5], "R": [0.9, 1.5], "h": [2.6, 2.6], "note": "цель kitchen_ceiling: дыра в потолке"},
            {"id": "mother", "kind": "person", "L": 0.95, "R": 1.75, "size": [0.5, 1.65], "note": "мама у плиты, 3/4 спиной, лицо в профиль"},
            {"id": "daughter", "kind": "person", "L": 1.4, "R": 1.1, "size": [0.4, 0.98], "note": "Вита сидит на стуле лицом к столу (сидя 0,98)"},
        ],
    },
    "bath": {
        "title": "Ванная с туалетом", "size": [2.3, 2.4],
        "items": [
            {"id": "tub", "kind": "floor", "L": [0.0, 0.72], "R": [0.3, 1.85], "h": [0.0, 0.58], "note": "цель bath_tub: ванна 1,55 × 0,72 вдоль правой стены"},
            {"id": "sink", "kind": "floor", "L": [0.4, 0.9], "R": [0.0, 0.45], "h": [0.0, 0.85], "note": "цель bath_sink: раковина на ножке у левой стены"},
            {"id": "mirror", "kind": "wall", "wall": "L", "at": [0.45, 0.85], "h": [1.2, 1.7], "note": "зеркало над раковиной"},
            {"id": "towel", "kind": "wall", "wall": "L", "at": [0.98, 1.2], "h": [1.0, 1.55], "note": "полотенце на крючке"},
            {"id": "toilet", "kind": "floor", "L": [1.3, 1.7], "R": [0.0, 0.68], "h": [0.0, 0.78], "note": "цель bath_toilet: унитаз с бачком у левой стены"},
            {"id": "basket", "kind": "floor", "L": [1.72, 2.05], "R": [0.05, 0.38], "h": [0.0, 0.42], "note": "корзина для белья"},
            {"id": "tiles_hole", "kind": "wall", "wall": "R", "at": [1.1, 1.5], "h": [0.7, 1.05], "note": "цель bath_tiles: отбитая плитка над ванной"},
            {"id": "shelf", "kind": "wall", "wall": "R", "at": [0.6, 1.1], "h": [1.5, 1.62], "depth": 0.15, "note": "полочка над ванной"},
            {"id": "duck", "kind": "floor", "L": [0.55, 0.7], "R": [1.6, 1.75], "h": [0.58, 0.68], "note": "уточка на бортике"},
            {"id": "toothbrushes", "fill": True, "kind": "floor", "L": [0.45, 0.56], "R": [0.04, 0.14], "h": [0.85, 0.99], "note": "НОВОЕ: стакан с двумя щётками на раковине"},
            {"id": "robe", "fill": True, "kind": "wall", "wall": "L", "at": [1.85, 2.1], "h": [0.9, 1.6], "note": "НОВОЕ: халат на крючке"},
            {"id": "light", "kind": "hang", "L": [0.95, 1.35], "R": [0.95, 1.35], "h": [2.45, 2.6], "note": "цель bath_light: плафон"},
            {"id": "mat", "kind": "floor", "L": [0.8, 1.25], "R": [0.8, 1.6], "h": [0.0, 0.01], "note": "коврик перед ванной"},
            {"id": "stool_basin", "kind": "floor", "L": [1.55, 1.95], "R": [1.6, 2.0], "h": [0.0, 0.55], "note": "табурет с тазом (стирка)"},
            {"id": "mother", "kind": "person", "L": 1.85, "R": 2.2, "size": [0.5, 1.65], "note": "мама стирает в тазу, чуть наклонилась"},
            {"id": "daughter", "kind": "person", "L": 0.95, "R": 1.45, "size": [0.4, 0.75], "note": "Вита на коленках у ванны с корабликом (0,75)"},
        ],
    },
    "living": {
        "title": "Гостиная", "size": [3.6, 3.6],
        "items": [
            {"id": "bookcase", "kind": "floor", "L": [0.02, 0.42], "R": [0.02, 0.36], "h": [0.0, 1.3], "note": "невысокий книжный шкаф в углу"},
            {"id": "reading_lamp", "kind": "floor", "L": [1.92, 2.14], "R": [0.08, 0.3], "h": [0.0, 1.5], "note": "торшер у ближнего края дивана — место для чтения"},
            {"id": "sofa", "kind": "floor", "L": [0.5, 1.95], "R": [0.0, 0.88], "h": [0.0, 0.85], "note": "цель living_sofa: диван спинкой к левой стене, сиденье 0,45"},
            {"id": "picture", "kind": "wall", "wall": "L", "at": [0.75, 1.35], "h": [1.3, 1.85], "note": "картина над диваном (покупка)"},
            {"id": "wall_patch", "kind": "wall", "wall": "L", "at": [1.7, 2.1], "h": [1.0, 1.55], "note": "цель living_wall: сырое пятно/порванные обои"},
            {"id": "window", "kind": "wall", "wall": "R", "at": [0.35, 1.3], "h": [0.85, 2.15], "note": "НОВОЕ окно на правой стене"},
            {"id": "tv", "kind": "floor", "L": [0.0, 0.55], "R": [1.4, 1.98], "h": [0.0, 1.05], "note": "цель living_tv: тумба 0,5 + телевизор, повёрнут к дивану (экран смотрит по диагонали на зрителя)"},
            {"id": "coffee_table", "kind": "floor", "L": [1.05, 1.6], "R": [1.05, 1.5], "h": [0.0, 0.45], "note": "столик перед диваном (цветок — покупка)"},
            {"id": "carpet", "fill": True, "kind": "floor", "L": [0.95, 1.95], "R": [0.95, 1.75], "h": [0.0, 0.01], "note": "НОВОЕ: ковёр под столиком"},
            {"id": "plant", "fill": True, "kind": "floor", "L": [0.05, 0.35], "R": [0.45, 0.72], "h": [0.0, 0.95], "note": "НОВОЕ: растение в кадке под окном"},
            {"id": "lamp", "kind": "hang", "L": [1.05, 1.55], "R": [1.05, 1.55], "h": [2.2, 2.6], "note": "цель living_lamp: люстра"},
            {"id": "floor_patch", "kind": "floor", "L": [1.6, 2.1], "R": [1.4, 1.85], "h": [0.0, 0.01], "note": "цель living_floor: вздувшийся паркет"},
            {"id": "mother", "kind": "person", "L": 1.6, "R": 0.45, "size": [0.55, 1.25], "note": "мама сидит на диване у торшера с книгой (сидя 1,25)"},
            {"id": "daughter", "kind": "person", "L": 1.7, "R": 1.75, "size": [0.45, 0.62], "note": "Вита рисует на полу у столика (сидя 0,62)"},
        ],
    },
}
D0 = 5.0     # от камеры до дальнего угла, м: видно ~2,2 м каждой стены
CX = 360     # угол посередине экрана


def project(room, L, R, h):
    z = D0 - (L + R) / S2
    x = (R - L) / S2
    return (room.get("cx", CX) + FOCAL * x / z, HORIZON + FOCAL * (EYE - h) / z), z


def box_points(it):
    if it["kind"] == "person":
        # фигура — плоский щит лицом к камере: ступни в (L, R), ширина поперёк взгляда
        d = it["size"][0] / (2.0 * S2)
        L, R = it["L"], it["R"]
        return [(L + s * d, R - s * d, h) for s in (-1, 1) for h in (0.0, it["size"][1])]
    if it["kind"] == "wall":
        d = it.get("depth", 0.03)
        a0, a1 = it["at"]
        if it["wall"] == "L":
            Ls, Rs = (a0, a1), (0.0, d)
        else:
            Ls, Rs = (0.0, d), (a0, a1)
    else:
        Ls, Rs = it["L"], it["R"]
    return [(L, R, h) for L in Ls for R in Rs for h in it["h"]]


def rect(room, it):
    pts = [project(room, *p)[0] for p in box_points(it)]
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return [round(min(xs)), round(min(ys)), round(max(xs) - min(xs)), round(max(ys) - min(ys))]


def scale_at(room, L, R):
    """px на метр для предмета, стоящего в точке пола (L, R)."""
    z = D0 - (L + R) / S2
    return FOCAL / z


def facing(it):
    if it["kind"] == "person":
        return "фигура"
    if it["kind"] == "hang":
        return "снизу-сбоку, по оси угла"
    if it["kind"] == "wall":
        return "плоско на левой стене: вид 45° справа" if it["wall"] == "L" else "плоско на правой стене: вид 45° слева"
    L0, L1 = it["L"]
    R0, R1 = it["R"]
    if L0 <= 0.05 and R0 > 0.05:
        return "у правой стены: фасад смотрит влево-вниз, видны фасад и левый бок, 45°"
    if R0 <= 0.05 and L0 > 0.05:
        return "у левой стены: фасад смотрит вправо-вниз, видны фасад и правый бок, 45°"
    if L0 <= 0.05 and R0 <= 0.05:
        return "в углу: видны два фасада под 45°"
    return "посреди комнаты, стороны параллельны стенам: ребро к зрителю, 45°"


def table(name):
    room = ROOMS[name]
    rows = []
    for it in room["items"]:
        r = rect(room, it)
        cL = sum(it["L"]) / 2 if isinstance(it.get("L"), list) else it.get("L", 0)
        cR = sum(it["R"]) / 2 if isinstance(it.get("R"), list) else it.get("R", 0)
        out = r[0] < SAFE[0] or r[0] + r[2] > SAFE[2] or r[1] < 0 or (it["kind"] != "hang" and r[1] + r[3] > SAFE[3])
        if out:
            print("WARN %s/%s вне видимой области: %s" % (name, it["id"], r), file=sys.stderr)
        rows.append({"id": it["id"], "rect": r, "png2x": [r[2] * 2, r[3] * 2],
                     "px_per_m": round(scale_at(room, cL, cR)), "view": facing(it), "note": it.get("note", "")})
    return rows


def guide(name, path):
    from PIL import Image, ImageDraw, ImageFont
    room = ROOMS[name]
    img = Image.new("RGB", (W, H), (245, 240, 230))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    except OSError:
        font = None

    def P(L, R, h):
        return project(room, L, R, h)[0]
    span = 3.2
    # пол: сетка 0,5 м
    for i in range(0, 7):
        t = i * 0.5
        d.line([P(t, 0, 0), P(t, span, 0)], fill=(200, 180, 150), width=1)
        d.line([P(0, t, 0), P(span, t, 0)], fill=(200, 180, 150), width=1)
    # стены и потолок
    for t in [x * 0.5 for x in range(0, 7)]:
        d.line([P(t, 0, 0), P(t, 0, CEIL)], fill=(215, 205, 190), width=1)
        d.line([P(0, t, 0), P(0, t, CEIL)], fill=(215, 205, 190), width=1)
    d.line([P(0, 0, 0), P(0, 0, CEIL)], fill=(90, 70, 60), width=3)
    for a, b in (((0, 0, 0), (span, 0, 0)), ((0, 0, 0), (0, span, 0)), ((0, 0, CEIL), (span, 0, CEIL)), ((0, 0, CEIL), (0, span, CEIL))):
        d.line([P(*a), P(*b)], fill=(90, 70, 60), width=3)
    d.line([(0, HORIZON), (W, HORIZON)], fill=(80, 160, 255), width=1)
    d.text((4, HORIZON - 20), "горизонт = глаза мамы", fill=(40, 110, 220), font=font)
    d.rectangle(SAFE, outline=(255, 0, 200), width=2)
    d.text((SAFE[0] + 4, SAFE[1] + 4), "видно на 16:9 и 20:9", fill=(200, 0, 160), font=font)
    colors = {"floor": (60, 140, 90), "wall": (60, 100, 200), "hang": (160, 110, 40), "person": (220, 60, 60)}
    for it in room["items"]:
        pts = box_points(it)
        c = colors[it["kind"]]
        if it["kind"] == "person":
            r = rect(room, it)
            d.rectangle([r[0], r[1], r[0] + r[2], r[1] + r[3]], outline=c, width=3)
            d.text((r[0] + 3, r[1] + 2), it["id"], fill=c, font=font)
            continue
        pp = [P(*p) for p in pts]
        # рёбра коробки: точки отличаются одной координатой
        for i in range(len(pts)):
            for j in range(i + 1, len(pts)):
                diff = sum(1 for k in range(3) if abs(pts[i][k] - pts[j][k]) > 1e-9)
                if diff == 1:
                    d.line([pp[i], pp[j]], fill=c, width=2)
        r = rect(room, it)
        d.text((r[0] + 3, r[1] + 2), it["id"], fill=c, font=font)
    img.save(path)


def footprint(room, it):
    """След основания на полу (для тени): 4 угла у напольной вещи, эллипс под ступнями фигуры."""
    if it["kind"] == "person":
        w = it["size"][0] / 2.0
        pts = []
        for a in range(14):
            t = 2.0 * math.pi * a / 14.0
            u, v = math.cos(t) * w, math.sin(t) * 0.2
            pts.append(project(room, it["L"] + (u + v) / S2, it["R"] + (v - u) / S2, 0.0)[0])
        return pts
    if it["kind"] != "floor" or it["h"][1] <= 0.02 or it["h"][0] > 0.02:
        return []
    (L0, L1), (R0, R1) = it["L"], it["R"]
    return [project(room, L, R, 0.0)[0] for L, R in ((L0, R0), (L1, R0), (L1, R1), (L0, R1))]


def near_z(room, it):
    """Расстояние от камеры до ближней точки основания (меньше — ближе, рисуется позже)."""
    if it["kind"] == "person":
        return project(room, it["L"], it["R"], 0.0)[1]
    if it["kind"] == "wall":
        return 99.0
    (L0, L1), (R0, R1) = it["L"], it["R"]
    return min(project(room, L, R, 0.0)[1] for L in (L0, L1) for R in (R0, R1))


def apply(name, path="data/act1.json"):
    """Прямоугольники, z по глубине и тени комнаты — в act1.json (ключ "act" у предмета плана).
    z: настенное и лежащее на полу — самые дальние; остальное по глубине; у маленькой комнаты
    пара героев — спрайт между слоями z < 2 и z >= 2: что ближе пары, получает z от 2."""
    room = ROOMS[name]
    data = json.load(open(path, encoding="utf-8"))
    loc = next(l for l in data["locations"] if l["id"] == name)
    items = [it for it in room["items"] if "act" in it]
    for it in [it for it in items if it["act"].startswith("decor:")]:
        # покупки магазина: только место; рисуются за семьёй
        d = next((d for d in loc.get("decor", []) if d["id"] == it["act"][6:]), None)
        if d is not None:
            d["rect"] = rect(room, it)
    items = [it for it in items if not it["act"].startswith("decor:")]
    pair = next((it for it in items if it["act"] == "family"), None)
    pair_z = near_z(room, pair) if pair else -1.0
    order = sorted([it for it in items if it["act"] != "family"], key=lambda it: -near_z(room, it))
    back, front = 0, 0
    objs = {}
    for it in order:
        r = rect(room, it)
        flat = it["kind"] == "wall" or it["h"][1] <= 0.02
        if flat:
            # на стене — сразу за фоном; на полу: коврики 0,05, повреждения пола поверх них 0,06
            z = 0.02 if it["kind"] == "wall" else (0.06 if it["act"].startswith("target:") else 0.05)
        elif pair and near_z(room, it) < pair_z:
            front += 1
            z = 2.0 + front * 0.01
        else:
            back += 1
            z = 0.1 + back * 0.01
        kind, _, key = it["act"].partition(":")
        if kind == "target":
            obj = next(t for t in loc["targets"] if t["id"] == key)
            obj.pop("more", None)
        else:
            obj = next((p for p in loc["props"] if p["img"] == key), None)
            if obj is None:
                # новый предмет наполнения — добавляем в props
                obj = {"img": key}
                loc["props"].append(obj)
        obj["rect"] = r
        obj["z"] = round(z, 3)
        objs[it["id"]] = obj
        fp = footprint(room, it)
        if fp:
            obj["shadow"] = [[round(x), round(y)] for x, y in fp]
        else:
            obj.pop("shadow", None)
    # стоящее на другой вещи (лампа на тумбочке) рисуется сразу поверх опоры
    for it in order:
        if it["kind"] != "floor" or it["h"][0] <= 0.05:
            continue
        for sup in order:
            if sup is not it and abs(sup["h"][1] - it["h"][0]) < 0.03 and sup["L"][0] <= it["L"][0] and it["L"][1] <= sup["L"][1] \
                    and sup["R"][0] <= it["R"][0] and it["R"][1] <= sup["R"][1]:
                objs[it["id"]]["z"] = round(objs[sup["id"]]["z"] + 0.005, 3)
    if pair:
        r = rect(room, pair)
        feet = project(room, pair["L"], pair["R"], 0.0)[0]
        loc["family"] = {"pos": [round(feet[0]), round(feet[1])], "height": r[3],
                         "shadow": [[round(x), round(y)] for x, y in footprint(room, pair)]}
    open(path, "w", encoding="utf-8").write(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    print("applied %s: %d items" % (name, len(items)))


def item_guides(name, out_dir):
    """Каркас каждого предмета ровно в размер его PNG (2x rect): рёбра коробки (и частей — спинки
    кровати), след на полу, точки ножек, линии стен. Рисовать поверх — и предмет встанет на место."""
    from PIL import Image, ImageDraw
    room = ROOMS[name]
    os.makedirs(out_dir, exist_ok=True)
    for it in room["items"]:
        if it["kind"] == "person":
            continue
        r = rect(room, it)
        img = Image.new("RGBA", (max(2, r[2] * 2), max(2, r[3] * 2)), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)

        def Q(L, R, h):
            x, y = project(room, L, R, h)[0]
            return ((x - r[0]) * 2, (y - r[1]) * 2)
        boxes = [it] + [dict(p, kind="floor") for p in it.get("parts", [])]
        for bx in boxes:
            pts = box_points(bx)
            pp = [Q(*p) for p in pts]
            for i in range(len(pts)):
                for j in range(i + 1, len(pts)):
                    if sum(1 for k in range(3) if abs(pts[i][k] - pts[j][k]) > 1e-9) == 1:
                        d.line([pp[i], pp[j]], fill=(255, 0, 150, 255), width=3)
        fp = footprint(room, it)
        if fp:
            d.polygon([((x - r[0]) * 2, (y - r[1]) * 2) for x, y in fp], fill=(0, 120, 255, 60))
            for x, y in fp:
                q = ((x - r[0]) * 2, (y - r[1]) * 2)
                d.ellipse([q[0] - 6, q[1] - 6, q[0] + 6, q[1] + 6], fill=(0, 90, 255, 255))
        img.save(os.path.join(out_dir, "%s.png" % it["id"]))


def main():
    if "--item-guides" in sys.argv:
        name = sys.argv[sys.argv.index("--item-guides") + 1]
        item_guides(name, "art/act1/reviews/layout/%s_items" % name)
        return
    if "--apply" in sys.argv:
        i = sys.argv.index("--apply")
        out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else "data/act1.json"
        if out != "data/act1.json":
            import shutil
            shutil.copy("data/act1.json", out)
        apply(sys.argv[i + 1], out)
        return
    guides = "--guides" in sys.argv
    out = {}
    for name in ROOMS:
        out[name] = table(name)
        if guides:
            os.makedirs("art/act1/reviews/layout", exist_ok=True)
            guide(name, "art/act1/reviews/layout/%s.png" % name)
    if "--json" in sys.argv:
        print(json.dumps(out, ensure_ascii=False, indent=1))
        return
    for name, rows in out.items():
        print("\n## %s" % ROOMS[name]["title"])
        print("| предмет | rect x,y,w,h | PNG 2x | px/м | ракурс | что это |")
        print("|---|---|---|---|---|---|")
        for r in rows:
            print("| %s | %s | %d×%d | %d | %s | %s |" % (r["id"], ", ".join(map(str, r["rect"])), r["png2x"][0], r["png2x"][1],
                                                      r["px_per_m"], r["view"], r["note"]))


if __name__ == "__main__":
    main()
