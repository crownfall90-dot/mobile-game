#!/usr/bin/env python3
"""Приводит пустой фон комнаты (угол 45°) к точной камере из tools/room_planner.py.

Фон состоит из четырёх плоскостей: левая стена, правая стена, пол, потолок. Для каждой строится
перспективное преобразование «черновик → план» по опорным точкам, и каждый пиксель результата
берётся из черновика через обратное преобразование своей плоскости. Обои, доски, плинтусы
остаются нарисованными художником — меняется только перспектива.

Опорные точки черновика (в пикселях файла): x угла, стык потолка и пола у угла и у обоих краёв:
  python3 tools/warp_room.py room art/act1/room/pilot/background-draft-v1.png out.png \\
      --draft '{"cx":720,"ceil_c":984,"floor_c":1848,"ceil_l":754,"floor_l":2018,"ceil_r":756,"floor_r":2022}'
Стены: угол и края → угол и края плана. Пол и потолок: угол и две точки схода стен (доски и
потолок сходятся в точки схода плана), масштаб вдоль диагонали — так, чтобы край пола у кромки
кадра брался с кромки черновика.
"""
import json
import math
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, __file__.rsplit("/", 1)[0])
import room_planner as rp  # noqa: E402


def homography(src, dst):
    """3×3 H: dst ~ H·src по четырём парам точек (DLT)."""
    a = []
    for (x, y), (u, v) in zip(src, dst):
        a.append([x, y, 1, 0, 0, 0, -u * x, -u * y, -u])
        a.append([0, 0, 0, x, y, 1, -v * x, -v * y, -v])
    _, _, vt = np.linalg.svd(np.array(a, dtype=float))
    h = vt[-1].reshape(3, 3)
    return h / h[2, 2]


def meet(p1, p2, q1, q2):
    """Точка пересечения прямых p1p2 и q1q2."""
    x1, y1 = p1
    x2, y2 = p2
    x3, y3 = q1
    x4, y4 = q2
    d = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / d
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))


def _plane(tc, tvl, tvr, sc, svl, svr, tcx, scx, edge_y, t_edge, s_edge):
    """Пол/потолок: угол и точки схода стен задают всё, кроме масштаба вдоль диагонали. Его
    подбираем так, чтобы край стены плана у левой кромки кадра брался ровно с кромки черновика."""
    def make(sy):
        return homography([tc, tvl, tvr, (tcx, edge_y)], [sc, svl, svr, (scx, sy)])

    def err(sy):
        v = make(sy) @ np.array([t_edge[0], t_edge[1], 1.0])
        return v[0] / v[2] - s_edge[0]
    lo, hi = (sc[1] + 1.0, edge_y * 3.0 + 10.0) if edge_y > sc[1] else (-abs(sc[1]) * 3.0 - 10.0, sc[1] - 1.0)
    best = None
    for _ in range(200):
        mid = (lo + hi) / 2.0
        e = err(mid)
        best = mid
        if abs(e) < 0.01:
            break
        # ошибка меняется монотонно с масштабом: сдвигаем границу по знаку
        if (e > 0) == (err(lo) > 0):
            lo = mid
        else:
            hi = mid
    return make(best)


def plan_points(room, w, h):
    """Опорные точки плана в пикселях файла w×h (сцена 720×1560)."""
    k = w / rp.W
    cx = room.get("cx", rp.CX)
    P = lambda L, R, hh: tuple(c * k for c in rp.project(room, L, R, hh)[0])  # noqa: E731
    # где стены уходят за левый/правый край: ищем длину стены, при которой x = 0 / W
    def edge(side):
        lo, hi = 0.0, 4.0
        for _ in range(60):
            mid = (lo + hi) / 2
            x = P(mid, 0, 0)[0] if side == "L" else P(0, mid, 0)[0]
            if (side == "L" and x > 0) or (side == "R" and x < w):
                lo = mid
            else:
                hi = mid
        return lo
    eL, eR = edge("L"), edge("R")
    pts = {
        "cc": P(0, 0, rp.CEIL), "fc": P(0, 0, 0),
        "cl": P(eL, 0, rp.CEIL), "fl": P(eL, 0, 0),
        "cr": P(0, eR, rp.CEIL), "fr": P(0, eR, 0),
        "cx": cx * k,
    }
    return pts


def draft_points(d):
    return {"cc": (d["cx"], d["ceil_c"]), "fc": (d["cx"], d["floor_c"]),
            "cl": (0.0, d["ceil_l"]), "fl": (0.0, d["floor_l"]),
            "cr": (d["w"], d["ceil_r"]), "fr": (d["w"], d["floor_r"]), "cx": d["cx"]}


def warp(room_name, src_path, out_path, d):
    img = Image.open(src_path).convert("RGB")
    w, h = img.size
    d = dict(d, w=float(w))
    room = rp.ROOMS[room_name]
    S = draft_points(d)
    T = plan_points(room, w, h)
    # точки схода стен (левая стена сходится вправо, правая — влево)
    vS_l = meet(S["cc"], S["cl"], S["fc"], S["fl"])
    vS_r = meet(S["cc"], S["cr"], S["fc"], S["fr"])
    vT_l = meet(T["cc"], T["cl"], T["fc"], T["fl"])
    vT_r = meet(T["cc"], T["cr"], T["fc"], T["fr"])
    Hs = {
        "left": homography([T["cc"], T["fc"], T["fl"], T["cl"]], [S["cc"], S["fc"], S["fl"], S["cl"]]),
        "right": homography([T["cc"], T["fc"], T["fr"], T["cr"]], [S["cc"], S["fc"], S["fr"], S["cr"]]),
        "floor": _plane(T["fc"], vT_l, vT_r, S["fc"], vS_l, vS_r, T["cx"], S["cx"], h, T["fl"], S["fl"]),
        "ceil": _plane(T["cc"], vT_l, vT_r, S["cc"], vS_l, vS_r, T["cx"], S["cx"], 0.0, T["cl"], S["cl"]),
    }
    ys, xs = np.mgrid[0:h, 0:w].astype(float)
    # плоскость каждого пикселя по линиям плана
    def line_y(a, b, x):
        return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
    left = xs < T["cx"]
    ceil_y = np.where(left, line_y(T["cc"], T["cl"], xs), line_y(T["cc"], T["cr"], xs))
    floor_y = np.where(left, line_y(T["fc"], T["fl"], xs), line_y(T["fc"], T["fr"], xs))
    plane = np.where(ys < ceil_y, 3, np.where(ys > floor_y, 2, np.where(left, 0, 1)))
    src = np.array(img, dtype=float)
    out = np.zeros_like(src)
    for i, name in enumerate(["left", "right", "floor", "ceil"]):
        m = plane == i
        if not m.any():
            continue
        H = Hs[name]
        px, py = xs[m], ys[m]
        den = H[2, 0] * px + H[2, 1] * py + H[2, 2]
        sx = (H[0, 0] * px + H[0, 1] * py + H[0, 2]) / den
        sy = (H[1, 0] * px + H[1, 1] * py + H[1, 2]) / den
        sx = np.clip(sx, 0, w - 1.001)
        sy = np.clip(sy, 0, h - 1.001)
        x0 = np.floor(sx).astype(int)
        y0 = np.floor(sy).astype(int)
        fx = (sx - x0)[:, None]
        fy = (sy - y0)[:, None]
        c = (src[y0, x0] * (1 - fx) * (1 - fy) + src[y0, x0 + 1] * fx * (1 - fy)
             + src[y0 + 1, x0] * (1 - fx) * fy + src[y0 + 1, x0 + 1] * fx * fy)
        if name == "ceil":
            # потолок почти однотонный: плавный градиент от цвета у молдинга к цвету верха черновика
            near = src[int(S["cc"][1]) - 70:int(S["cc"][1]) - 30, int(w * 0.3):int(w * 0.7)].reshape(-1, 3).mean(axis=0)
            far = src[:40].reshape(-1, 3).mean(axis=0)
            t = np.clip((ceil_y[m] - py) / np.maximum(ceil_y[m], 1.0), 0.0, 1.0)[:, None]
            c = near * (1 - t) + far * t
        out[m] = c
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(out_path)
    return T


if __name__ == "__main__":
    if len(sys.argv) < 5 or sys.argv[4] != "--draft":
        print(__doc__)
        sys.exit(1)
    t = warp(sys.argv[1], sys.argv[2], sys.argv[3], json.loads(sys.argv[5]))
    print("plan points:", {k: (round(v[0]), round(v[1])) if isinstance(v, tuple) else round(v) for k, v in t.items()})
