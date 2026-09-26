#!/usr/bin/env python3
"""G1 (DESIGN §5.5): проверка файлов уровней без движка.

Использование: tools/lint_levels.py [id или путь ...]
Без аргументов проверяет уровни из levels/index.json, остальные levels/*.json и levels/test/*.json.
Ошибки (ERROR) дают код выхода 1, предупреждения (WARNING) только печатаются.
Поля механик (grates, circles, сито, relic, magma) проверяются, только если они есть.
Геометрия повторяет движок: scripts/level/level.gd (_spawn_fill), pin.gd, substances.gd.
"""

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEVELS = ROOT / "levels"
INDEX = LEVELS / "index.json"
TEST_DIR = LEVELS / "test"

RADIUS = {"water": 9, "lava": 9, "acid": 9, "stone": 9, "gold": 11, "gem": 11, "relic": 12}
FLUIDS = {"water", "lava", "acid"}
GRID = 2.05                 # шаг укладки тел в fills: 2.05·r
PIN_HALF = 7.0              # половина толщины засова (Pin.THICKNESS 14)
HANDLE_R = 22.0             # Pin.HANDLE_R
ENEMY_R = 30.0
MAX_BODIES, MAX_FLUID, MAX_PINS = 160, 120, 5
FILL_GAP = (5.0, 8.0)       # низ fill над засовом
SUPPORT_RANGE = 40.0        # засов ниже fill не дальше этого считается его дном
GRATE_HP = (4, 12)
CIRCLE_R = (36, 60)
SIEVE_THICK = (8.0, 12.0)
LAVA_OVER_SIEVE = 60.0
GOAL_RATIO = (0.5, 0.8)
OVERLAP_TOL = 1.0           # на сколько px тело может заходить в стену при появлении
# потолок доли выигрышных порядков по месту на этаже (§5.4)
POSITION_CAP = {1: 0.50, 2: 0.34, 3: 0.34, 4: 0.34, 5: 0.17, 6: 0.25}
DEFAULT_CAP = 0.34

TUTORIALS = {"", "hand", "hint"}
INTROS = {"", "water_lava", "slime", "acid", "grate", "sieve", "circle", "magma"}
RELICS = {"star_mushroom", "phoenix_feather", "moon_dew", "dragon_scale", "frog_crown",
          "philosophers_pebble"}
ENEMY_KINDS = {"slime", "magma", "grime", "mold", "cockroach", "rat", "mouse", "spider", "moth"}
WALL_TYPES = {"solid", "sieve"}
TOP_KEYS = {"family", "format", "id", "floor", "title", "hint", "tutorial", "intro", "hard", "tower",
            "walls", "grates", "circles", "pins", "fills", "enemies", "hero", "goal", "theme",
            "dirt", "holes", "strokes", "exit", "receiver", "pipes", "source", "hazards", "rotate", "putty",
            "leak", "dishes", "plunger", "mirrors", "scripts", "solution", "fails", "verify"}
LEAK_EVENTS = ("move", "press", "up", "scare", "drop", "pump", "tap")
TIMED_KEYS = ("leak", "dishes", "plunger", "mirrors")
DISH_KINDS = {"plate", "cup", "bowl", "pot"}


# --- каталог ------------------------------------------------------------------

def load_index():
    """id -> {"floor": n, "pos": позиция на этаже с 1}; пустой словарь, если индекса нет."""
    try:
        index = json.loads(INDEX.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    out = {}
    for fl in index.get("floors", []):
        for i, level_id in enumerate(fl.get("levels", [])):
            out[str(level_id)] = {"floor": int(fl.get("n", 0)), "pos": i + 1}
    return out


def resolve(arg):
    """id уровня или путь к файлу -> Path (или None)."""
    p = Path(arg)
    if arg.endswith(".json"):
        for cand in (p, ROOT / p):
            if cand.is_file():
                return cand.resolve()
        return None
    for cand in (LEVELS / f"{arg}.json", TEST_DIR / f"{arg}.json"):
        if cand.is_file():
            return cand.resolve()
    return None


def default_paths(index=None, report_missing=True):
    """Уровни индекса (что есть), прочие levels/*.json и levels/test/*.json."""
    index = load_index() if index is None else index
    paths, missing = [], []
    for level_id in index:
        f = LEVELS / f"{level_id}.json"
        if f.is_file():
            paths.append(f.resolve())
        else:
            missing.append(level_id)
    for f in sorted(LEVELS.glob("*.json")):
        if f.name != "index.json" and f.resolve() not in paths:
            paths.append(f.resolve())
    paths += [f.resolve() for f in sorted(TEST_DIR.glob("*.json"))]
    if missing and report_missing:
        print(f"note: {len(missing)} index level(s) have no file yet: {', '.join(missing)}")
    return paths


def rel(path):
    try:
        return str(Path(path).resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def cap_for(data, info):
    """Потолок доли выигрышных порядков: verify.max_win_share, иначе по месту на этаже."""
    v = data.get("verify") if isinstance(data.get("verify"), dict) else {}
    if is_num(v.get("max_win_share")):
        return float(v["max_win_share"])
    return POSITION_CAP.get(info["pos"], DEFAULT_CAP) if info else DEFAULT_CAP


# --- геометрия ------------------------------------------------------------------

def one_of(v, allowed):
    return isinstance(v, str) and v in allowed


def is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def is_point(v):
    return isinstance(v, list) and len(v) == 2 and all(is_num(x) for x in v)


def is_rect(v):
    return isinstance(v, list) and len(v) == 4 and all(is_num(x) for x in v) and v[2] > 0 and v[3] > 0


def spawn_points(rect, count, r):
    """Те же позиции, что Level._spawn_fill: ряды снизу вверх, нечётные сдвинуты на четверть шага."""
    x, y, w, h = rect
    step = r * GRID
    cols = max(1, int(w / step))
    for i in range(count):
        cx, cy = i % cols, i // cols
        shift = step * 0.25 if cy % 2 == 1 else 0.0
        yield x + step * 0.5 + cx * step + shift, y + h - step * 0.5 - cy * step


def seg_dist(p, a, b):
    ax, ay = b[0] - a[0], b[1] - a[1]
    l2 = ax * ax + ay * ay
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * ay) / l2))
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - ay * t)


def inside(p, poly):
    hit = False
    for i in range(len(poly)):
        a, b = poly[i], poly[i - 1]
        if (a[1] > p[1]) != (b[1] > p[1]):
            if p[0] < a[0] + (p[1] - a[1]) * (b[0] - a[0]) / (b[1] - a[1]):
                hit = not hit
    return hit


def penetration(p, r, poly):
    """На сколько круг (p, r) заходит в многоугольник; <= 0 — не касается."""
    d = min(seg_dist(p, poly[i - 1], poly[i]) for i in range(len(poly)))
    return r + d if inside(p, poly) else r - d


def area(poly):
    return abs(sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))) / 2


def self_intersects(poly):
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        for j in range(i + 1, n):
            if j == i or (j + 1) % n == i or j == (i + 1) % n:
                continue  # соседние рёбра
            c, d = poly[j], poly[(j + 1) % n]
            if (cross(a, b, c) * cross(a, b, d) < 0) and (cross(c, d, a) * cross(c, d, b) < 0):
                return True
    return False


def bbox(poly):
    xs, ys = [p[0] for p in poly], [p[1] for p in poly]
    return min(xs), min(ys), max(xs), max(ys)


def pin_span(pin, x0, x1):
    """Верх и низ засова над отрезком [x0, x1]: (lo, hi, top(lo), top(hi), bottom(lo), bottom(hi))
    или None, если засов крутой (боковой) или не проходит под отрезком."""
    (fx, fy), (tx, ty) = pin["from"], pin["to"]
    dx, dy = tx - fx, ty - fy
    if abs(dy) > abs(dx):
        return None
    lo, hi = max(x0, min(fx, tx)), min(x1, max(fx, tx))
    if hi - lo < 1.0:
        return None
    half = PIN_HALF * math.hypot(dx, dy) / abs(dx)
    y = [fy + (xx - fx) * dy / dx for xx in (lo, hi)]
    return y[0] - half, y[1] - half, y[0] + half, y[1] + half


def pin_poly(pin):
    (fx, fy), (tx, ty) = pin["from"], pin["to"]
    ln = math.hypot(tx - fx, ty - fy) or 1.0
    nx, ny = -(ty - fy) / ln * PIN_HALF, (tx - fx) / ln * PIN_HALF
    return [[fx + nx, fy + ny], [tx + nx, ty + ny], [tx - nx, ty - ny], [fx - nx, fy - ny]]


# --- проверка одного файла ------------------------------------------------------------

class Report:
    def __init__(self):
        self.errors, self.warnings = [], []

    def err(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)


def lint_file(path, index=None):
    """-> (Report, data | None). index — результат load_index()."""
    index = load_index() if index is None else index
    rep = Report()
    path = Path(path)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as e:
        rep.err(f"cannot read: {e}")
        return rep, None
    except ValueError as e:
        rep.err(f"broken JSON: {e}")
        return rep, None
    if not isinstance(data, dict):
        rep.err("top level must be an object")
        return rep, None
    _lint(data, path, index, rep)
    return rep, data


def _lint(d, path, index, rep):
    for k in d:
        if k not in TOP_KEYS and not k.startswith("_"):
            rep.warn(f"unknown key '{k}'")
    stem = path.stem
    level_id = d.get("id")
    in_tree = path.resolve().parent in (LEVELS.resolve(), TEST_DIR.resolve())
    info = index.get(stem) if path.resolve().parent == LEVELS.resolve() else None

    # --- шапка
    if d.get("format") != 2:
        rep.err(f"format must be 2 (got {d.get('format')!r})")
    if not isinstance(level_id, str) or not level_id:
        rep.err("id must be a non-empty string")
    elif level_id != stem:
        (rep.err if in_tree else rep.warn)(f"id '{level_id}' differs from the file name '{stem}'")
    if not isinstance(d.get("floor"), int) or isinstance(d.get("floor"), bool):
        rep.err("floor must be an integer")
    elif info and d["floor"] != info["floor"]:
        rep.err(f"floor {d['floor']} but the index puts it on floor {info['floor']}")
    for key in ("title", "hint"):
        _lint_text(d.get(key), key, rep, required=(key == "title"))
    if not one_of(d.get("tutorial", ""), TUTORIALS):
        rep.err(f"tutorial must be one of {sorted(TUTORIALS)}")
    if not one_of(d.get("intro", ""), INTROS):
        rep.warn(f"intro '{d.get('intro')}' is not a known card ({', '.join(sorted(INTROS - {''}))})")
    if "hard" in d and not isinstance(d["hard"], bool):
        rep.err("hard must be true or false")
    if info and bool(d.get("hard", False)) != (info["pos"] == 5):
        rep.warn(f"hard is {bool(d.get('hard', False))} but position {info['pos']} "
                 f"{'is' if info['pos'] == 5 else 'is not'} the Hard slot")

    # --- башня, стены
    tower = d.get("tower", {}).get("rect") if isinstance(d.get("tower"), dict) else None
    if not is_rect(tower):
        rep.err("tower.rect must be [x, y, w, h]")
        tower = None
    walls = []
    for i, w in enumerate(_list(d, "walls", rep)):
        where = f"walls[{i}]"
        if not isinstance(w, dict) or not isinstance(w.get("poly"), list) or len(w["poly"]) < 3 \
                or not all(is_point(p) for p in w["poly"]):
            rep.err(f"{where}: poly must be a list of 3+ [x, y] points")
            continue
        _unknown(w, {"poly", "type"}, where, rep)
        poly, kind = w["poly"], w.get("type", "solid")
        if not one_of(kind, WALL_TYPES):
            rep.err(f"{where}: type must be solid or sieve")
            continue
        if self_intersects(poly):
            rep.err(f"{where}: polygon crosses itself")
            continue
        if area(poly) < 1.0:
            rep.err(f"{where}: polygon has no area")
            continue
        if kind == "sieve":
            longest = max(math.dist(poly[k - 1], poly[k]) for k in range(len(poly)))
            thick = area(poly) / longest
            if not SIEVE_THICK[0] - 0.5 <= thick <= SIEVE_THICK[1] + 0.5:
                rep.warn(f"{where}: sieve is {thick:.1f} px thick (should be 8-12)")
        walls.append((where, poly, kind))

    # --- механики: решётки и круги
    for i, g in enumerate(_list(d, "grates", rep)):
        where = f"grates[{i}]"
        if not isinstance(g, dict) or not is_rect(g.get("rect")):
            rep.err(f"{where}: rect must be [x, y, w, h]")
            continue
        _unknown(g, {"rect", "hp"}, where, rep)
        hp = g.get("hp", 8)
        if not isinstance(hp, int) or isinstance(hp, bool) or not GRATE_HP[0] <= hp <= GRATE_HP[1]:
            rep.err(f"{where}: hp {hp!r} outside {GRATE_HP[0]}-{GRATE_HP[1]}")
    for i, c in enumerate(_list(d, "circles", rep)):
        where = f"circles[{i}]"
        if not isinstance(c, dict) or not is_point(c.get("pos")):
            rep.err(f"{where}: pos must be [x, y]")
            continue
        _unknown(c, {"pos", "r"}, where, rep)
        r = c.get("r", 48)
        if not is_num(r) or not CIRCLE_R[0] <= r <= CIRCLE_R[1]:
            rep.err(f"{where}: r {r!r} outside {CIRCLE_R[0]}-{CIRCLE_R[1]}")

    # --- засовы
    pins, pin_ids = [], []
    for i, p in enumerate(_list(d, "pins", rep)):
        where = f"pins[{i}]"
        if not isinstance(p, dict) or not isinstance(p.get("id"), str) or not p["id"] \
                or not is_point(p.get("from")) or not is_point(p.get("to")):
            rep.err(f"{where}: needs id, from [x, y] and to [x, y]")
            continue
        _unknown(p, {"id", "from", "to"}, where, rep)
        if p["id"] in pin_ids:
            rep.err(f"{where}: duplicate pin id '{p['id']}'")
        pin_ids.append(p["id"])
        if math.dist(p["from"], p["to"]) < 1.0:
            rep.err(f"{where} '{p['id']}': from and to are the same point")
            continue
        pins.append(p)
        if tower:
            hx, hy = p["from"]
            tx, ty, tw, th = tower
            if tx <= hx <= tx + tw and ty <= hy <= ty + th:
                rep.err(f"pin '{p['id']}': handle {p['from']} is inside the tower rect")
            elif tx - HANDLE_R < hx < tx + tw + HANDLE_R and ty - HANDLE_R < hy < ty + th + HANDLE_R:
                rep.warn(f"pin '{p['id']}': handle ring overlaps the tower rect")
    # мазки пальцем по земле — такие же ходы, как засовы
    strokes = d.get("strokes", {})
    if not isinstance(strokes, dict):
        rep.err("strokes must be an object {name: [[x, y], ...]}")
        strokes = {}
    for name, pts in strokes.items():
        if name in pin_ids:
            rep.err(f"stroke '{name}' has the same id as a pin")
        if not isinstance(pts, list) or not pts or not all(is_point(q) for q in pts):
            rep.err(f"stroke '{name}' must be a list of [x, y] points")
        pin_ids.append(name)
    if strokes and "dirt" not in d and "putty" not in d:
        rep.err("strokes need dirt to dig or putty to draw")
    # «живые трубы»: колено поворачивается тапом — тоже ход
    for i, pp in enumerate(_list(d, "pipes", rep)):
        where = f"pipes[{i}]"
        if not isinstance(pp, dict) or not isinstance(pp.get("id"), str) or not is_point(pp.get("pos")):
            rep.err(f"{where}: needs id and pos [x, y]")
            continue
        _unknown(pp, {"id", "pos", "right", "size"}, where, rep)
        if pp["id"] in pin_ids:
            rep.err(f"{where}: id '{pp['id']}' is already used")
        pin_ids.append(pp["id"])
    rot = d.get("rotate")
    if rot is not None:
        if not isinstance(rot, dict):
            rep.err("rotate must be an object {time}")
        else:
            _unknown(rot, {"time", "step", "max"}, "rotate", rep)
            pin_ids += ["cw", "ccw"]
    src = d.get("source")
    if src is not None:
        if not isinstance(src, dict) or not is_point(src.get("pos")) or not one_of(src.get("kind", "water"), FLUIDS) \
                or not isinstance(src.get("count"), int) or src["count"] < 1:
            rep.err("source needs pos [x, y], a fluid kind and count >= 1")
        else:
            _unknown(src, {"pos", "kind", "count", "rate", "delay", "x1"}, "source", rep)
    for i, hz in enumerate(_list(d, "hazards", rep)):
        if not isinstance(hz, dict) or not is_rect(hz.get("rect")) or hz.get("kind") not in ("socket", "sill", "wire", "leak", "mold", "spill"):
            rep.err(f"hazards[{i}]: needs rect [x, y, w, h] and kind socket, sill, wire, leak, mold or spill")
    # «лови капли»: труба с дырами и мышь; ходы — сценарии по времени в "scripts"
    leak = d.get("leak")
    if leak is not None:
        if not isinstance(leak, dict) or not isinstance(leak.get("holes"), list) or not leak["holes"]:
            rep.err("leak needs holes [{id, x, every, open}]")
        else:
            _unknown(leak, {"pipe_y", "pipe_top", "hold", "holes", "mouse", "rail", "drops", "auto"}, "leak", rep)
            for i, h in enumerate(leak["holes"]):
                if not isinstance(h, dict) or not isinstance(h.get("id"), str) or not is_num(h.get("x")):
                    rep.err(f"leak.holes[{i}]: needs id and x")
                    continue
                _unknown(h, {"id", "x", "every", "open", "grow"}, f"leak.holes[{i}]", rep)
            m = leak.get("mouse")
            if m is not None and not isinstance(m, dict):
                rep.err("leak.mouse must be an object")
            elif m is not None:
                _unknown(m, {"speed", "gnaw", "rest", "back", "scares", "from"}, "leak.mouse", rep)
        if "receiver" not in d:
            rep.err("leak needs a receiver (the bucket)")
    # «стопка посуды»: полки на одной опоре, посуда по одной
    dishes = d.get("dishes")
    if dishes is not None:
        if not isinstance(dishes, dict) or not isinstance(dishes.get("queue"), list) or not dishes["queue"] \
                or not all(k in DISH_KINDS for k in dishes["queue"]):
            rep.err(f"dishes needs queue [{'|'.join(sorted(DISH_KINDS))}, ...]")
        elif not isinstance(dishes.get("shelves"), list) or not dishes["shelves"]:
            rep.err("dishes needs shelves [{id, rect, pivot, stiff}]")
        else:
            _unknown(dishes, {"queue", "shelves", "spawn", "floor_y", "sides"}, "dishes", rep)
            for i, sh in enumerate(dishes["shelves"]):
                if not isinstance(sh, dict) or not is_rect(sh.get("rect")):
                    rep.err(f"dishes.shelves[{i}]: needs rect [x, y, w, h]")
                    continue
                _unknown(sh, {"id", "rect", "pivot", "stiff", "damp"}, f"dishes.shelves[{i}]", rep)
    # «вантуз»: путь засора по сифону
    plg = d.get("plunger")
    if plg is not None:
        if not isinstance(plg, dict) or not isinstance(plg.get("path"), list) or len(plg["path"]) < 2 \
                or not all(is_point(p) for p in plg["path"]):
            rep.err("plunger needs path [[x, y], ...] with 2+ points")
        else:
            _unknown(plg, {"path", "start", "push", "slide", "recover", "splashes", "overflow", "sink", "cup", "auto"},
                     "plunger", rep)
    # «луч и зеркальца»: поле клеток, фонарик, плафон, зеркальца и стены
    mir = d.get("mirrors")
    if mir is not None:
        if not isinstance(mir, dict) or not isinstance(mir.get("items"), list) or not isinstance(mir.get("lamp"), list) \
                or not isinstance(mir.get("source"), list) or len(mir["source"]) != 3:
            rep.err("mirrors needs source [c, r, dir], lamp [c, r] and items [{id, c, r, kind}]")
        else:
            _unknown(mir, {"origin", "cell", "cols", "rows", "source", "lamp", "items", "moth", "taps", "par", "scare",
                           "look"}, "mirrors", rep)
            if mir["source"][2] not in ("up", "down", "left", "right"):
                rep.err("mirrors.source direction must be up, down, left or right")
            for i, it in enumerate(mir["items"]):
                if not isinstance(it, dict) or it.get("kind") not in ("/", "\\", "wall") \
                        or not isinstance(it.get("c"), int) or not isinstance(it.get("r"), int):
                    rep.err(f"mirrors.items[{i}]: needs c, r and kind / or \\ or wall")
    scripts = d.get("scripts", {})
    if not isinstance(scripts, dict):
        rep.err("scripts must be an object {name: [[t, action, arg], ...]}")
        scripts = {}
    if scripts and not any(k in d for k in TIMED_KEYS):
        rep.err("scripts need leak, dishes, plunger or mirrors")
    for name, evs in scripts.items():
        if name in pin_ids:
            rep.err(f"scripts: id '{name}' is already used")
        pin_ids.append(name)
        if not isinstance(evs, list) or not all(isinstance(e, list) and len(e) >= 2 and is_num(e[0])
                                                and e[1] in LEAK_EVENTS for e in evs):
            rep.err(f"scripts.{name}: events must be [t, {'|'.join(LEAK_EVENTS)}, arg...]")
        elif any(evs[i][0] > evs[i + 1][0] for i in range(len(evs) - 1)):
            rep.err(f"scripts.{name}: event times must not go back")
    for key in ("dirt", "holes"):
        for i, sh in enumerate(d.get(key, [])):
            if not isinstance(sh, dict) or not (is_rect(sh.get("rect")) or "poly" in sh or "circle" in sh):
                rep.err(f"{key}[{i}]: needs rect [x, y, w, h], poly or circle [x, y, r]")
    if "exit" in d and not (isinstance(d["exit"], dict) and is_point(d["exit"].get("pos"))):
        rep.err("exit must be {\"pos\": [x, y]}")
    if not pin_ids:
        rep.err("a level needs at least one pin or stroke")
    elif len(pin_ids) > MAX_PINS:
        rep.err(f"{len(pin_ids)} pins (max {MAX_PINS})")

    # --- заполнение
    bodies = fluid = relics = pieces = 0
    for i, f in enumerate(_list(d, "fills", rep)):
        where = f"fills[{i}]"
        if not isinstance(f, dict) or not one_of(f.get("kind"), RADIUS) or not is_rect(f.get("rect")) \
                or not isinstance(f.get("count"), int) or isinstance(f.get("count"), bool) or f["count"] < 1:
            rep.err(f"{where}: needs kind ({', '.join(RADIUS)}), rect [x, y, w, h] and count >= 1")
            continue
        _unknown(f, {"kind", "rect", "count", "relic"}, where, rep)
        kind, rect, count = f["kind"], f["rect"], f["count"]
        where = f"{where} ({kind})"
        r = RADIUS[kind]
        step = r * GRID
        room = max(1, int(rect[2] / step)) * int(rect[3] / step)
        if count > room:
            rep.err(f"{where}: {count} bodies do not fit rect {rect[2]}x{rect[3]} (the grid holds {room})")
        bodies += count
        fluid += count if kind in FLUIDS else 0
        pieces += count if kind in ("gold", "gem") else 0
        if kind == "relic":
            relics += count
            if count != 1:
                rep.err(f"{where}: count must be 1")
            if not one_of(f.get("relic"), RELICS):
                rep.err(f"{where}: relic {f.get('relic')!r} is not one of {', '.join(sorted(RELICS))}")
        elif "relic" in f:
            rep.warn(f"{where}: 'relic' only means something for kind relic")
        if tower and not (tower[0] <= rect[0] and tower[1] <= rect[1]
                          and rect[0] + rect[2] <= tower[0] + tower[2] and rect[1] + rect[3] <= tower[1] + tower[3]):
            rep.warn(f"{where}: rect is not inside the tower rect")
        _lint_fill_support(where, rect, pins, rep)
        _lint_fill_overlap(where, kind, rect, min(count, room), r, walls, rep)
        if kind == "lava":
            _lint_lava_sieve(where, rect, walls, rep)
    if relics > 1:
        rep.err(f"{relics} relics (max 1)")
    n_enemies = 0
    for i, e in enumerate(_list(d, "enemies", rep)):
        where = f"enemies[{i}]"
        if not isinstance(e, dict) or not is_point(e.get("pos")):
            rep.err(f"{where}: pos must be [x, y]")
            continue
        _unknown(e, {"kind", "pos", "fixed", "swell"}, where, rep)
        n_enemies += 1
        if not one_of(e.get("kind", "slime"), ENEMY_KINDS):
            rep.err(f"{where}: kind must be one of {', '.join(sorted(ENEMY_KINDS))}")
        for wname, poly, _t in walls:
            depth = penetration(e["pos"], ENEMY_R, poly)
            if depth > OVERLAP_TOL:
                rep.warn(f"{where}: overlaps {wname} by {depth:.1f} px at spawn")
    if bodies + n_enemies > MAX_BODIES:
        rep.err(f"{bodies + n_enemies} dynamic bodies (max {MAX_BODIES})")
    if fluid > MAX_FLUID:
        rep.err(f"{fluid} fluid drops (max {MAX_FLUID})")

    # --- героиня и цель
    hero = d.get("hero")
    recv = d.get("receiver")
    if recv is not None:
        # головоломка внутри вещи: вместо героини приёмник {rect, look, kind, bad, mode}
        if not isinstance(recv, dict) or not is_rect(recv.get("rect")):
            rep.err("receiver needs rect [x, y, w, h]")
        elif recv.get("kind", "gold") not in RADIUS:
            rep.err(f"receiver kind must be one of {', '.join(RADIUS)}")
        elif recv.get("mode", "collect") not in ("collect", "fill"):
            rep.err("receiver mode must be collect or fill")
        if hero is not None:
            rep.err("a level has either hero or receiver")
    elif not isinstance(hero, dict) or not is_point(hero.get("pos")) or not is_rect(hero.get("zone")):
        rep.err("hero needs pos [x, y] and zone [x, y, w, h]")
    goal = d.get("goal")
    if not isinstance(goal, dict):
        rep.err('goal must be {"gold": 0.7} or {"pieces": N, "three_star": M}')
    elif "pieces" in goal:
        n, m = goal.get("pieces"), goal.get("three_star", goal.get("pieces"))
        if not all(isinstance(v, int) and not isinstance(v, bool) for v in (n, m)) or n < 1 or m < n:
            rep.err("absolute goal needs integers 1 <= pieces <= three_star")
    elif "gold" in goal:
        if not is_num(goal["gold"]) or not GOAL_RATIO[0] <= goal["gold"] <= GOAL_RATIO[1]:
            rep.err(f"ratio goal {goal['gold']!r} outside {GOAL_RATIO[0]}-{GOAL_RATIO[1]}")
        if pieces == 0:
            rep.warn("ratio goal but no gold or gems: every win gives 3 stars")
    else:
        rep.err('goal must be {"gold": 0.7} or {"pieces": N, "three_star": M}')

    # --- решение и проигрышные порядки
    sol = d.get("solution")
    if not isinstance(sol, list) or not sol or not all(isinstance(x, str) for x in sol):
        rep.err("solution must be a non-empty list of pin ids")
        sol = None
    else:
        _lint_order(sol, "solution", pin_ids, rep)
        if pin_ids and sorted(sol) != sorted(pin_ids) and not any(k in d for k in ("rotate", "putty") + TIMED_KEYS):
            rep.warn("solution does not pull every pin once, so it is not one of the searched orders")
    fails = d.get("fails", [])
    if not isinstance(fails, list) or not all(isinstance(o, list) and o and all(isinstance(x, str) for x in o)
                                              for o in fails):
        rep.err("fails must be a list of non-empty pin id lists")
        fails = []
    for i, o in enumerate(fails):
        _lint_order(o, f"fails[{i}]", pin_ids, rep)
        if sol and o == sol:
            rep.err(f"fails[{i}] is the solution")
        elif sol and o == sol[:len(o)]:
            rep.warn(f"fails[{i}] is a prefix of the solution")
    if len(pin_ids) >= 2 and not fails:
        rep.err("levels with 2+ pins need at least one fails order")

    # --- параметры проверки
    v = d.get("verify", {})
    if not isinstance(v, dict):
        rep.err("verify must be an object")
        v = {}
    _unknown(v, {"max_win_share", "daily", "live", "draw"}, "verify", rep)
    share = v.get("max_win_share")
    if share is not None:
        if not is_num(share) or not 0 < share <= 1:
            rep.err("verify.max_win_share must be in (0, 1]")
        elif info and len(pin_ids) > 1 and share > POSITION_CAP.get(info["pos"], 1.0) + 1e-9:
            rep.err(f"verify.max_win_share {share} is above the cap {POSITION_CAP[info['pos']]} "
                    f"for position {info['pos']} (DESIGN 5.4)")
    elif len(pin_ids) > 1:
        rep.warn(f"no verify.max_win_share: the verifier uses {cap_for(d, info)}")
    if "daily" in v and not isinstance(v["daily"], bool):
        rep.err("verify.daily must be true or false")


def _lint_text(v, key, rep, required):
    if isinstance(v, str):
        if required and not v:
            rep.warn(f"{key} is empty")
        return
    if isinstance(v, dict):
        for lang in ("ru", "en"):
            if not isinstance(v.get(lang), str) or (required and not v.get(lang)):
                rep.warn(f"{key}.{lang} is missing")
        return
    if v is None and not required:
        return
    rep.err(f'{key} must be a string or {{"ru": ..., "en": ...}}')


def _lint_order(order, where, pin_ids, rep):
    for pid in order:
        if pid not in pin_ids:
            rep.err(f"{where}: no pin '{pid}'")
    # повороты «Поверни» повторяются, засовы — нет
    once = [pid for pid in order if pid not in ("cw", "ccw")]
    if len(set(once)) != len(once):
        rep.err(f"{where}: a pin is pulled twice")


def _lint_fill_support(where, rect, pins, rep):
    """Низ fill на 5–8 px выше засова под ним; засов не должен проходить сквозь fill."""
    x, y, w, h = rect
    bottom = y + h
    best = None
    for p in pins:
        span = pin_span(p, x, x + w)
        if span is None:
            continue
        top0, top1, bot0, bot1 = span
        if min(top0, top1) < bottom and max(bot0, bot1) > y:
            rep.err(f"{where}: pin '{p['id']}' passes through the fill rect")
            continue
        gap = min(top0, top1) - bottom
        if 0.0 <= gap + 0.5 and gap <= SUPPORT_RANGE and (best is None or gap < best[0]):
            best = (gap, p["id"])
    if best and not FILL_GAP[0] - 0.05 <= best[0] <= FILL_GAP[1] + 0.05:
        rep.err(f"{where}: bottom is {best[0]:.1f} px above pin '{best[1]}' "
                f"(should be {FILL_GAP[0]:g}-{FILL_GAP[1]:g})")


def _lint_fill_overlap(where, kind, rect, count, r, walls, rep):
    """Тела появляются в стенах — физика вытолкнет их непредсказуемо."""
    for wname, poly, wtype in walls:
        if wtype == "sieve" and kind in FLUIDS:
            continue  # жидкость проходит сквозь сито
        x0, y0, x1, y1 = bbox(poly)
        for n, pt in enumerate(spawn_points(rect, count, r)):
            if not (x0 - r <= pt[0] <= x1 + r and y0 - r <= pt[1] <= y1 + r):
                continue
            depth = penetration(pt, r, poly)
            if depth > OVERLAP_TOL:
                rep.err(f"{where}: body {n} at ({pt[0]:.0f}, {pt[1]:.0f}) spawns {depth:.1f} px inside {wname}")
                break


def _lint_lava_sieve(where, rect, walls, rep):
    x, y, w, h = rect
    for wname, poly, wtype in walls:
        if wtype != "sieve":
            continue
        x0, y0, x1, _y1 = bbox(poly)
        if x0 < x + w and x1 > x and -h < y0 - (y + h) <= LAVA_OVER_SIEVE:
            rep.warn(f"{where}: lava within {LAVA_OVER_SIEVE:g} px above sieve {wname} "
                     "(stone cooling inside the mesh is ejected unpredictably)")


def _list(d, key, rep):
    v = d.get(key, [])
    if not isinstance(v, list):
        rep.err(f"{key} must be a list")
        return []
    return v


def _unknown(obj, known, where, rep):
    for k in obj:
        if k not in known and not str(k).startswith("_"):
            rep.warn(f"{where}: unknown key '{k}'")


# --- запуск ----------------------------------------------------------------------

def lint_paths(paths, index=None, echo=True):
    """-> {path: (Report, data | None)}; с echo печатает отчёт по каждому файлу.
    Здесь же ловятся одинаковые id в разных файлах."""
    index = load_index() if index is None else index
    out, seen = {}, {}
    for path in paths:
        rep, data = lint_file(path, index)
        if data and isinstance(data.get("id"), str):
            other = seen.setdefault(data["id"], path)
            if other != path:
                rep.err(f"id '{data['id']}' is also used by {rel(other)}")
        out[path] = (rep, data)
        if echo:
            status = "ok" if not rep.errors and not rep.warnings else \
                f"{len(rep.errors)} error(s), {len(rep.warnings)} warning(s)"
            print(f"{rel(path)}: {status}")
            for m in rep.errors:
                print(f"  ERROR {m}")
            for m in rep.warnings:
                print(f"  WARNING {m}")
    return out


def main(argv):
    if any(a in ("-h", "--help") for a in argv):
        print(__doc__.strip())
        return 0
    paths = []
    for a in argv:
        p = resolve(a)
        if p is None:
            print(f"{a}: ERROR no such level")
            return 1
        paths.append(p)
    if not argv:
        paths = default_paths()
    results = lint_paths(paths)
    n_err = sum(len(rep.errors) for rep, _d in results.values())
    n_warn = sum(len(rep.warnings) for rep, _d in results.values())
    print(f"lint: {len(paths)} file(s), {n_err} error(s), {n_warn} warning(s)")
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
