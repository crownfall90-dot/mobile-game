#!/usr/bin/env bash
# Прогоняет каждый уровень по его полю "solution" без окна и проверяет победу.
# Использование: GODOT=/путь/к/godot tools/test_levels.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
count=$(python3 -c 'import json; print(len(json.load(open("levels/index.json"))["levels"]))')
fail=0
for ((i = 0; i < count; i++)); do
  out=$("$GODOT" --headless --path . --fixed-fps 60 -- --level="$i" --autoplay 2>&1 | grep "RESULT:" || true)
  echo "level $((i + 1)): ${out:-no result}"
  [[ "$out" == *WON* ]] || fail=1
done
exit $fail
