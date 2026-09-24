#!/usr/bin/env bash
# Скриншоты для просмотра глазами (720x1280, GL Compatibility, как на телефоне):
#   <id>_start.png   уровень через 0.3 с после открытия;
#   <id>_end.png     решение (--autoplay, интервал 1.5 с) через 3 с после последнего засова;
#   screen_<имя>.png каждый готовый экран и попап из реестра Router (--screen).
# Без своего дисплея перезапускается под xvfb-run. Время игровое (--fixed-fps 60),
# поэтому кадры одинаковые на любой машине. Профиль игрока не трогается (временный user://).
# Использование: GODOT=/путь/к/godot tools/shots.sh <папка> [id ...]
#   без id — все уровни индекса, у которых есть файл; id из levels/test/ тоже можно.
#   SHOTS_LANG=ru|en — язык интерфейса (по умолчанию как в системе).
set -uo pipefail
if [[ $# -lt 1 ]]; then
  echo "usage: tools/shots.sh <out_dir> [level ids...]"
  exit 2
fi
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
if [[ -z "${DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null || { echo "shots: no DISPLAY and no xvfb-run"; exit 2; }
  exec xvfb-run -a -s "-screen 0 720x1280x24" "$self" "$@"
fi
GODOT="${GODOT:-godot}"
mkdir -p "$1" || exit 2
out="$(cd "$1" && pwd)"
shift
cd "$(dirname "$self")/.."
TO=$(command -v timeout || true)

START_DELAY=1.0   # DevRunner.START_DELAY
INTERVAL=1.5      # DevRunner.INTERVAL
AFTER_LAST=3.0
SCREEN_AT=2.5
LOADING_AT=0.6

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_DATA_HOME="$tmp/userdata"
case "${SHOTS_LANG:-}" in
  ru) export LANG=ru_RU.UTF-8 ;;
  en) export LANG=en_US.UTF-8 ;;
esac

# "флаг уровня|id|засовов в решении" для каждого уровня
levels=$(python3 -B - "$@" <<'EOF'
import json, sys
sys.path.insert(0, "tools")
import lint_levels as lint
args = sys.argv[1:]
paths = [lint.resolve(a) for a in args] if args else \
    [lint.LEVELS / f"{i}.json" for i in lint.load_index() if (lint.LEVELS / f"{i}.json").is_file()]
for a, p in zip(args or paths, paths):
    if p is None:
        print(f"MISSING|{a}|0")
        continue
    d = json.loads(p.read_text(encoding="utf-8"))
    flag = f"--level={p.stem}" if p.parent == lint.LEVELS.resolve() or p.parent == lint.LEVELS \
        else "--file=res://" + p.resolve().relative_to(lint.ROOT).as_posix()
    print(f"{flag}|{p.stem}|{len(d.get('solution', []))}")
EOF
)
# готовые экраны и попапы: имена из Router.SCREENS / POPUPS, у которых есть скрипт
screens=$(python3 -B - <<'EOF'
import re
src = open("scripts/core/router.gd", encoding="utf-8").read()
import os
for block in ("SCREENS", "POPUPS"):
    m = re.search(r"const %s := \{(.*?)\n\}" % block, src, re.S)
    for name, path in re.findall(r'&"(\w+)":\s*"res://([^"]+)"', m.group(1) if m else ""):
        if os.path.isfile(path):
            print(name)
EOF
)

fail=0
n=0
# shot <файл> <секунды> <флаги DevRunner...>
shot() {
  local file="$1" at="$2"
  shift 2
  rm -f "$file"
  ${TO:+$TO 120} "$GODOT" --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 \
    -- "$@" --shot="$file@$at" >"$tmp/log.txt" 2>&1
  local errs
  errs=$(grep -E 'SCRIPT ERROR|Parse Error' "$tmp/log.txt" | head -3)
  if [[ ! -s "$file" ]]; then
    echo "FAIL $(basename "$file"): no image ($(grep -E '^RESULT|ERROR' "$tmp/log.txt" | head -1))"
    fail=1
  elif [[ -n "$errs" ]]; then
    echo "FAIL $(basename "$file"): $errs"
    fail=1
  else
    echo "ok   $(basename "$file")  $(grep -E '^RESULT:' "$tmp/log.txt" | head -1)"
    n=$((n + 1))
  fi
}

while IFS='|' read -r flag id pins; do
  [[ -z "$flag" ]] && continue
  if [[ "$flag" == MISSING ]]; then
    echo "FAIL $id: no such level"
    fail=1
    continue
  fi
  shot "$out/${id}_start.png" 0.3 "$flag"
  if [[ "$pins" -gt 0 ]]; then
    at=$(python3 -c "print($START_DELAY + ($pins - 1) * $INTERVAL + $AFTER_LAST)")
    shot "$out/${id}_end.png" "$at" "$flag" --autoplay --interval=$INTERVAL
  fi
done <<<"$levels"

for name in $screens; do
  at=$SCREEN_AT
  [[ "$name" == loading ]] && at=$LOADING_AT
  shot "$out/screen_$name.png" "$at" --screen="$name"
done

echo "shots: $n saved to $out: $([[ $fail == 0 ]] && echo OK || echo FAIL)"
exit $fail
