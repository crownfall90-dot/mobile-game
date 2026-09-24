#!/usr/bin/env python3
"""Проверка уровней по воротам G1-G7 (DESIGN 5.5) через DevRunner без окна.

Использование:
  tools/verify.py [id или путь ...] [-j N] [--quick] [--no-cache] [--godot PATH]

  без аргументов   все уровни индекса (у которых есть файл), прочие levels/*.json и levels/test/*.json
  -j N             параллельных Godot (по умолчанию 2: машина общая)
  --quick          только G1-G4, для быстрой работы над уровнем
  --no-cache       не брать прошлые прогоны из .verify_cache/ (новые всё равно сохраняются)
  --godot PATH     движок; иначе $GODOT, иначе godot / godot4 из PATH

Ворота:
  G1  tools/lint_levels.py без ошибок
  G2  решение выигрывает: интервал 1.5 с при jitter 0, 1, 2; 0.8 с при 0; settle при 0
  G3  при 1.5 с и jitter 0: 3 звезды и ингредиент, если он есть
  G4  каждый порядок из fails проигрывает при jitter 0 и 1; у 2+ засовов fails не пуст
  G5  3+ засова: все засовы в одном кадре не выигрывают (jitter 0 и 1)
  G6  все перестановки засовов при jitter 0 и 1: доля выигрышных (хотя бы с одним seed)
      не выше потолка, «плавающих» (исход зависит от seed) не больше 10%, решение и fails не плавают;
      порядки, выигравшие с обоими seed, пишутся в levels/solutions/<id>.json (решение первым)
  G7  есть золото и verify.daily не false: с --mods=golden решение выигрывает на 3 звезды

Кэш: .verify_cache/, ключ — sha1 файла уровня, sha1 всего, что грузит прогон (все файлы res://,
кроме levels/, docs/, tools/ и скрытых папок; плюс levels/index.json), версия, размер и время
файла Godot; хранятся исходы отдельных прогонов.
Код выхода: 0 — всё прошло, 1 — есть провалы, 2 — нечем проверять.
"""

import argparse
import concurrent.futures as cf
import hashlib
import itertools
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path

sys.dont_write_bytecode = True   # без tools/__pycache__ в рабочей копии
sys.path.insert(0, str(Path(__file__).resolve().parent))
import lint_levels as lint  # noqa: E402

ROOT = lint.ROOT
LEVELS = lint.LEVELS
CACHE_DIR = ROOT / ".verify_cache"
SOLUTIONS_DIR = LEVELS / "solutions"
# Ключ кэша по коду: всё, что может загрузить прогон, а не выбранный вручную список —
# иначе ошибка в hud.gd или автозагрузке прячется за старым PASS.
# Файл уровня хешируется отдельно; index.json — здесь: по нему Game строит каталог.
CODE_SKIP_DIRS = {"levels", "docs", "tools", "build", "android"}
CODE_SKIP_SUFFIXES = (".md", ".tmp")
CODE_EXTRA = ["levels/index.json"]
RUN_TIMEOUT = 120
NORMAL = "1.5"
FLAKY_MAX = 0.10
WINS_SHOWN = 8
ERROR_RE = re.compile(r"^(SCRIPT ERROR|USER ERROR|ERROR|Parse Error)\b")
GATES = ["G1", "G2", "G3", "G4", "G5", "G6", "G7"]


# --- описание прогонов -------------------------------------------------------------

def spec(order, interval=NORMAL, seed=0, golden=False):
    """Прогон: order — кортеж id засовов или None (все в одном кадре)."""
    return (tuple(order) if order is not None else None, interval, seed, golden)


def spec_key(s):
    order, interval, seed, golden = s
    pins = "all" if order is None else ",".join(order)
    return f"{pins}|{interval}|{seed}|{'golden' if golden else ''}"


def _items(data, key):
    """Список из данных уровня; мусор (его ловит G1) — пустой список."""
    v = data.get(key) if isinstance(data, dict) else None
    return v if isinstance(v, list) else []


class Level:
    def __init__(self, path, data, index, report):
        self.path = path
        self.data = data
        self.id = str(data.get("id") or path.stem) if data else path.stem
        self.lint = report
        self.info = index.get(path.stem) if data and path.parent == LEVELS.resolve() else None
        self.pins = [str(p["id"]) for p in _items(data, "pins") if isinstance(p, dict) and "id" in p]
        self.solution = tuple(str(x) for x in _items(data, "solution"))
        self.fails = [tuple(str(x) for x in o) for o in _items(data, "fails") if isinstance(o, list)]
        fills = _items(data, "fills")
        self.has_gold = any(isinstance(f, dict) and f.get("kind") == "gold" for f in fills)
        self.has_relic = any(isinstance(f, dict) and f.get("kind") == "relic" for f in fills)
        v = data.get("verify", {}) if data else {}
        self.daily = not (isinstance(v, dict) and v.get("daily") is False)
        self.cap = lint.cap_for(data, self.info) if data else lint.DEFAULT_CAP
        self.specs = {}          # key -> spec
        self.results = {}        # key -> исход
        self.meta = {}           # ключ кэша
        self.cached = 0
        self.pending = 0
        self.gates = {}          # G -> (статус, [строки])
        self.win_share = None
        self.flaky = None
        self.solid = []
        self.wrote = ""

    @property
    def flag(self):
        if self.path.parent == LEVELS.resolve() and self.path.stem == self.id:
            return f"--level={self.id}"
        try:
            return "--file=res://" + self.path.relative_to(ROOT).as_posix()
        except ValueError:
            return f"--file={self.path}"

    def add(self, s):
        self.specs.setdefault(spec_key(s), s)

    def res(self, s):
        return self.results.get(spec_key(s))


def plan(lv, quick):
    sol = lv.solution
    for s in (spec(sol, NORMAL, 0), spec(sol, NORMAL, 1), spec(sol, NORMAL, 2),
              spec(sol, "0.8", 0), spec(sol, "settle", 0)):
        lv.add(s)
    for f in lv.fails:
        lv.add(spec(f, NORMAL, 0))
        lv.add(spec(f, NORMAL, 1))
    if quick:
        return
    if len(lv.pins) >= 3:
        lv.add(spec(None, NORMAL, 0))
        lv.add(spec(None, NORMAL, 1))
    for perm in itertools.permutations(lv.pins):
        lv.add(spec(perm, NORMAL, 0))
        lv.add(spec(perm, NORMAL, 1))
    if lv.has_gold and lv.daily:
        lv.add(spec(sol, NORMAL, 0, True))


# --- запуск Godot ---------------------------------------------------------------------

_local = threading.local()
_worker_ids = itertools.count()


def run_one(godot, env, lv, s):
    order, interval, seed, golden = s
    if not hasattr(_local, "log"):
        _local.log = CACHE_DIR / "logs" / f"worker{next(_worker_ids)}.log"
    args = [godot, "--headless", "--path", str(ROOT), "--fixed-fps", "60", "--log-file", str(_local.log),
            "--", lv.flag, "--json", f"--interval={interval}", f"--jitter={seed}"]
    args.append("--all-at-once" if order is None else "--pins=" + ",".join(order))
    if golden:
        args.append("--mods=golden")
    t0 = time.monotonic()
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=RUN_TIMEOUT, env=env, cwd=ROOT)
    except subprocess.TimeoutExpired:
        return {"status": "error", "error": f"killed after {RUN_TIMEOUT} s", "wall": RUN_TIMEOUT}
    out = {"status": "ok", "wall": round(time.monotonic() - t0, 3)}
    for line in p.stdout.splitlines():
        if line.startswith("RESULT_JSON "):
            try:
                r = json.loads(line[len("RESULT_JSON "):])
            except ValueError:
                continue
            for k in ("won", "reason", "stars", "pieces", "total", "relic", "t"):
                out[k] = r.get(k)
    errors = [ln.strip() for ln in (p.stderr + "\n" + p.stdout).splitlines() if ERROR_RE.match(ln)]
    runner_error = next((ln for ln in p.stdout.splitlines() if ln.startswith("RESULT: ERROR")), "")
    if p.returncode == 2:
        out["status"] = "timeout"
    elif p.returncode != 0 or "won" not in out:
        out["status"] = "error"
        out["error"] = runner_error or (errors[0] if errors else f"exit code {p.returncode}, no RESULT_JSON")
    if errors and out["status"] != "error":
        out["status"] = "error"
        out["error"] = errors[0]
    if out.get("error", "").find("Parse Error") >= 0 or "not declared" in out.get("error", ""):
        out["error"] += "  (stale class cache? run: godot --headless --path . --import)"
    return out


def find_godot(arg):
    for cand in (arg, os.environ.get("GODOT"), shutil.which("godot"), shutil.which("godot4")):
        if cand and (Path(cand).is_file() or shutil.which(cand)):
            return cand
    return None


def godot_version(godot):
    p = subprocess.run([godot, "--version"], capture_output=True, text=True, timeout=60)
    return p.stdout.strip().splitlines()[-1] if p.stdout.strip() else "unknown"


def godot_id(godot, version):
    """Версия плюс размер и время файла: пересобранный движок той же версии — другой ключ."""
    try:
        st = Path(shutil.which(godot) or godot).resolve().stat()
    except OSError:
        return version
    return f"{version} {st.st_size} {int(st.st_mtime)}"


def code_files():
    """Файлы res://, от которых зависит прогон: без уровней, документов, инструментов,
    скрытых папок (.git, .godot, .verify_cache) и папок с .gdignore."""
    files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        here = Path(dirpath)
        top = here == ROOT
        dirnames[:] = [d for d in dirnames if not d.startswith(".")
                       and not (top and d in CODE_SKIP_DIRS)
                       and not (here / d / ".gdignore").exists()]
        files += [here / n for n in filenames
                  if not n.startswith(".") and not n.endswith(CODE_SKIP_SUFFIXES)]
    files += [ROOT / f for f in CODE_EXTRA if (ROOT / f).is_file()]
    return sorted(set(files))


def code_sha():
    h = hashlib.sha1()
    for f in code_files():
        h.update(f.relative_to(ROOT).as_posix().encode())
        h.update(f.read_bytes())
    return h.hexdigest()


# --- кэш ------------------------------------------------------------------------------

def cache_path(lv):
    tag = hashlib.sha1(str(lv.path).encode()).hexdigest()[:8]
    return CACHE_DIR / f"{re.sub(r'[^A-Za-z0-9_.-]', '_', lv.id)}-{tag}.json"


def cache_meta(lv, code, version):
    return {"level_sha1": hashlib.sha1(lv.path.read_bytes()).hexdigest(), "code_sha1": code, "godot": version}


def load_cache(lv, meta):
    try:
        c = json.loads(cache_path(lv).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return c.get("runs", {}) if c.get("meta") == meta else {}


def save_cache(lv, meta):
    runs = {k: r for k, r in lv.results.items() if r.get("status") == "ok"}
    old = load_cache(lv, meta)
    if not runs and not old:
        return   # прогон весь с ошибками: не затираем кэш прошлого (рабочего) кода
    old.update(runs)
    CACHE_DIR.mkdir(exist_ok=True)
    tmp = cache_path(lv).with_suffix(".tmp")
    tmp.write_text(json.dumps({"meta": meta, "path": str(lv.path), "runs": old}, indent=0), encoding="utf-8")
    tmp.replace(cache_path(lv))


# --- ворота ---------------------------------------------------------------------------

def outcome(r):
    if r is None:
        return "not run"
    if r["status"] == "timeout":
        return "TIMEOUT (no result)"
    if r["status"] == "error":
        return "ERROR " + r.get("error", "")
    if r["won"]:
        return f"WON {r['stars']} star(s) {r['pieces']}/{r['total']}"
    return f"LOST {r['reason']}"


def ok_run(r):
    return r is not None and r["status"] == "ok"


def won(r):
    return ok_run(r) and bool(r["won"])


def lost(r):
    return ok_run(r) and not r["won"]


def orders_str(order):
    return "all-at-once" if order is None else ",".join(order)


def judge(lv, quick):
    g = lv.gates
    sol = lv.solution
    # G2
    bad = []
    for s, label in ((spec(sol, NORMAL, 0), "1.5 s seed 0"), (spec(sol, NORMAL, 1), "1.5 s seed 1"),
                     (spec(sol, NORMAL, 2), "1.5 s seed 2"), (spec(sol, "0.8", 0), "0.8 s seed 0"),
                     (spec(sol, "settle", 0), "settle seed 0")):
        r = lv.res(s)
        if not won(r):
            bad.append(f"solution {label}: {outcome(r)}")
    g["G2"] = ("FAIL", bad) if bad else ("ok", ["solution won 5/5"])
    # G3
    r = lv.res(spec(sol, NORMAL, 0))
    bad = []
    if not won(r) or r["stars"] != 3:
        bad.append(f"solution 1.5 s seed 0: {outcome(r)}, needs 3 stars")
    if lv.has_relic and not (won(r) and r["relic"]):
        bad.append("relic not collected")
    g["G3"] = ("FAIL", bad) if bad else ("ok", [outcome(r) + (", relic" if lv.has_relic else "")])
    # G4
    bad = []
    if len(lv.pins) >= 2 and not lv.fails:
        bad.append("no fails orders (a level with 2+ pins needs one)")
    for f in lv.fails:
        for seed in (0, 1):
            r = lv.res(spec(f, NORMAL, seed))
            if not lost(r):
                bad.append(f"fail order {orders_str(f)} seed {seed}: {outcome(r)}, must lose")
    g["G4"] = ("FAIL", bad) if bad else ("ok", [f"{len(lv.fails)} fail order(s) lost with seeds 0 and 1"]
                                         if lv.fails else ["n/a (1 pin)"])
    if quick:
        for k in ("G5", "G6", "G7"):
            g[k] = ("-", ["skipped (--quick)"])
        return
    # G5
    if len(lv.pins) >= 3:
        bad = [f"all pins in one frame seed {seed}: {outcome(lv.res(spec(None, NORMAL, seed)))}, must lose"
               for seed in (0, 1) if not lost(lv.res(spec(None, NORMAL, seed)))]
        g["G5"] = ("FAIL", bad) if bad else ("ok", ["all pins in one frame: " + outcome(lv.res(spec(None, NORMAL, 0)))])
    else:
        g["G5"] = ("-", ["n/a (fewer than 3 pins)"])
    # G6
    perms = list(itertools.permutations(lv.pins))
    bad, info = [], []
    any_win, flaky, errors = [], [], []
    solid = []
    for perm in perms:
        r0, r1 = lv.res(spec(perm, NORMAL, 0)), lv.res(spec(perm, NORMAL, 1))
        for seed, r in ((0, r0), (1, r1)):
            if not ok_run(r):
                errors.append(f"{orders_str(perm)} seed {seed}: {outcome(r)}")
        w0, w1 = won(r0), won(r1)
        if w0 or w1:
            any_win.append(perm)
        if w0 and w1:
            solid.append(perm)
        if ok_run(r0) and ok_run(r1) and w0 != w1:
            flaky.append((perm, 0 if w0 else 1))
    n = len(perms)
    lv.win_share = len(any_win) / n if n else 0.0
    lv.flaky = (len(flaky), n)
    exempt = len(lv.pins) <= 1
    info.append(f"win share {len(any_win)}/{n} = {lv.win_share:.3f} (cap {lv.cap:g}{', exempt: 1 pin' if exempt else ''}),"
                f" {len(solid)} win with both seeds")
    if not exempt and lv.win_share > lv.cap + 1e-9:
        bad.append(f"win share {lv.win_share:.3f} above the cap {lv.cap:g}")
    if len(flaky) > FLAKY_MAX * n + 1e-9:
        bad.append(f"{len(flaky)}/{n} flaky orders (max {FLAKY_MAX:.0%})")
    for perm, seed in flaky:
        tag = ""
        if perm == sol:
            tag = " <- the solution"
            bad.append(f"the solution {orders_str(perm)} is flaky")
        elif perm in lv.fails:
            tag = " <- a fails order"
            bad.append(f"fail order {orders_str(perm)} is flaky")
        info.append(f"flaky: {orders_str(perm)} wins only with seed {seed}{tag}")
    bad += errors
    for perm in any_win[:WINS_SHOWN]:
        info.append(f"wins: {orders_str(perm)}{'' if perm in solid else ' (one seed)'}")
    if len(any_win) > WINS_SHOWN:
        info.append(f"... and {len(any_win) - WINS_SHOWN} more winning orders")
    g["G6"] = ("FAIL", bad + info) if bad else ("ok", info)
    lv.solid = ([sol] if won(lv.res(spec(sol, NORMAL, 0))) and won(lv.res(spec(sol, NORMAL, 1))) else []) \
        + [p for p in solid if p != sol]
    # G7
    if lv.has_gold and lv.daily:
        r = lv.res(spec(sol, NORMAL, 0, True))
        if won(r) and r["stars"] == 3:
            g["G7"] = ("ok", ["golden: " + outcome(r)])
        elif ok_run(r):
            g["G7"] = ("FAIL", [f"golden: {outcome(r)}, needs 3 stars; if this stays, set "
                                '"verify": {"daily": false} in the level (leaves the Potion of the Day pool)'])
        else:
            g["G7"] = ("FAIL", [f"golden: {outcome(r)}"])
    else:
        g["G7"] = ("-", ["n/a (no gold)" if not lv.has_gold else "n/a (verify.daily is false)"])


def write_solutions(lv):
    """levels/solutions/<id>.json: порядки, выигравшие с обоими seed, решение первым."""
    if lv.path.parent != LEVELS.resolve() or lv.path.stem != lv.id or not lv.solid:
        return
    text = "[\n" + ",\n".join("  " + json.dumps(list(o), ensure_ascii=False) for o in lv.solid) + "\n]\n"
    out = SOLUTIONS_DIR / f"{lv.id}.json"
    if out.is_file() and out.read_text(encoding="utf-8") == text:
        lv.wrote = f"{lint.rel(out)} unchanged ({len(lv.solid)} order(s))"
        return
    SOLUTIONS_DIR.mkdir(exist_ok=True)
    out.write_text(text, encoding="utf-8")
    lv.wrote = f"wrote {lint.rel(out)} ({len(lv.solid)} order(s))"


def passed(lv):
    return all(lv.gates.get(k, ("-",))[0] != "FAIL" for k in GATES)


# --- вывод ----------------------------------------------------------------------------

def run_time(lv):
    """(сумма, среднее) времени прогонов уровня; для кэшированных — время исходного прогона."""
    walls = [r.get("wall", 0.0) for r in lv.results.values()]
    return sum(walls), (sum(walls) / len(walls) if walls else 0.0)


def level_line(lv):
    gates = " ".join(f"{k}:{lv.gates.get(k, ('-',))[0]}" for k in GATES)
    total, per = run_time(lv)
    return (f"{lv.id}: {'PASS' if passed(lv) else 'FAIL'}  {gates}  "
            f"[{len(lv.specs)} runs, {lv.cached} cached, {total:.1f} s run time, {per:.2f} s/run]")


def print_table(levels):
    head = ["level", "result"] + GATES + ["win share", "cap", "flaky", "runs", "cached", "run s", "s/run"]
    rows = []
    for lv in levels:
        total, per = run_time(lv)
        rows.append([
            lv.id, "PASS" if passed(lv) else "FAIL",
            *[lv.gates.get(k, ("-",))[0] for k in GATES],
            f"{lv.win_share:.3f}" if lv.win_share is not None else "-",
            f"{lv.cap:g}",
            f"{lv.flaky[0]}/{lv.flaky[1]}" if lv.flaky else "-",
            str(len(lv.specs)), str(lv.cached),
            f"{total:.1f}", f"{per:.2f}" if lv.results else "-",
        ])
    widths = [max(len(str(r[i])) for r in [head] + rows) for i in range(len(head))]
    for r in [head] + rows:
        print("  ".join(str(c).ljust(w) for c, w in zip(r, widths)).rstrip())


def print_details(lv):
    print(f"\n{lv.id} ({lint.rel(lv.path)}): {'PASS' if passed(lv) else 'FAIL'}")
    for m in lv.lint.errors:
        print(f"  G1 ERROR {m}")
    for m in lv.lint.warnings:
        print(f"  G1 warning {m}")
    for k in GATES[1:]:
        status, lines = lv.gates.get(k, ("-", ["skipped (G1 failed)"]))
        for i, line in enumerate(lines):
            print(f"  {k} {status.ljust(4) if i == 0 else '    '} {line}")
    if lv.wrote:
        print(f"  {lv.wrote}")


# --- main -----------------------------------------------------------------------------

def main(argv):
    if hasattr(signal, "SIGPIPE"):
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)   # verify.py | head не падает
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("levels", nargs="*", help="level ids or JSON paths (default: index + levels/test)")
    ap.add_argument("-j", type=int, default=2, help="parallel Godot processes (default 2)")
    ap.add_argument("--quick", action="store_true", help="only G1-G4")
    ap.add_argument("--no-cache", action="store_true", help="ignore cached runs")
    ap.add_argument("--godot", help="Godot binary (default: $GODOT, then godot or godot4 in PATH)")
    a = ap.parse_args(argv)

    godot = find_godot(a.godot)
    if not godot:
        print("verify: no Godot binary: pass --godot PATH or set GODOT")
        return 2
    index = lint.load_index()
    paths = []
    for arg in a.levels:
        p = lint.resolve(arg)
        if p is None:
            print(f"verify: no such level: {arg}")
            return 2
        if p not in paths:
            paths.append(p)
    if not a.levels:
        paths = lint.default_paths(index)
    if not paths:
        print("verify: no levels")
        return 2

    version = godot_version(godot)
    engine = godot_id(godot, version)
    code = code_sha()
    jobs = max(1, a.j)
    print(f"verify: {len(paths)} level(s), {version}, {jobs} worker(s), "
          f"{'G1-G4 (--quick)' if a.quick else 'G1-G7'}, cache {'off' if a.no_cache else lint.rel(CACHE_DIR)}")

    # G1 для всех сразу: так ловятся и одинаковые id в разных файлах
    linted = lint.lint_paths(paths, index, echo=False)
    levels = []
    for p in paths:
        rep, data = linted[p]
        lv = Level(p, data, index, rep)
        lv.gates["G1"] = ("FAIL", []) if rep.errors else ("ok", [])
        levels.append(lv)

    (CACHE_DIR / "logs").mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["XDG_DATA_HOME"] = str(CACHE_DIR / "userdata")   # user:// игрока не трогаем
    t_start = time.monotonic()
    pool = cf.ThreadPoolExecutor(max_workers=jobs)
    try:
        futures = {}
        ready = []
        for lv in levels:
            if lv.gates["G1"][0] == "FAIL":
                continue
            plan(lv, a.quick)
            lv.meta = cache_meta(lv, code, engine)
            cached = {} if a.no_cache else load_cache(lv, lv.meta)
            for key, s in lv.specs.items():
                if key in cached:
                    lv.results[key] = cached[key]
                    lv.cached += 1
                else:
                    lv.pending += 1
                    futures[pool.submit(run_one, godot, env, lv, s)] = (lv, key)
            if lv.pending == 0:
                ready.append(lv)
        for lv in ready:
            finish(lv, a.quick)
        for fut in cf.as_completed(futures):
            lv, key = futures[fut]
            r = fut.result()
            lv.results[key] = r
            lv.pending -= 1
            if lv.pending == 0:
                finish(lv, a.quick)
    finally:
        # Ctrl+C: новые Godot не запускать, уже идущие доработают сами
        pool.shutdown(wait=True, cancel_futures=True)
    for lv in levels:
        if lv.gates["G1"][0] == "FAIL":
            print(level_line(lv))

    print()
    print_table(levels)
    for lv in levels:
        print_details(lv)
    failed = [lv.id for lv in levels if not passed(lv)]
    print(f"\nverify: {len(levels) - len(failed)}/{len(levels)} passed in {time.monotonic() - t_start:.1f} s"
          + (f"; FAILED: {', '.join(failed)}" if failed else ""))
    return 1 if failed else 0


def finish(lv, quick):
    judge(lv, quick)
    save_cache(lv, lv.meta)
    if not quick:
        write_solutions(lv)
    print(level_line(lv), flush=True)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("\nverify: interrupted")
        sys.exit(130)
