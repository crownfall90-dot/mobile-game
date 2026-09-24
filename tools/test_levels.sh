#!/usr/bin/env bash
# Проходит каждый уровень из levels/index.json по его полю "solution" без окна
# и падает, если хоть один не напечатал RESULT: WON.
# Уровни, у которых ещё нет файла, пропускаются (как и в игре); STRICT=1 считает их ошибкой.
# Использование: GODOT=/путь/к/godot tools/test_levels.sh
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
TO=$(command -v timeout || true)   # на macOS timeout может не быть: у DevRunner есть свой предел

ids=$(python3 -c '
import json
index = json.load(open("levels/index.json"))
for floor in index.get("floors", []):
    for level_id in floor.get("levels", []):
        print(level_id)
')

fail=0
tested=0
missing=0
for id in $ids; do
  if [[ ! -f "levels/$id.json" ]]; then
    echo "$id: SKIP (no file)"
    missing=$((missing + 1))
    [[ "${STRICT:-0}" == 1 ]] && fail=1
    continue
  fi
  out=$(${TO:+$TO 120} "$GODOT" --headless --path . --fixed-fps 60 -- --level="$id" --autoplay 2>&1 \
    | grep "^RESULT:" || true)
  echo "$id: ${out:-no result}"
  tested=$((tested + 1))
  [[ "$out" == *WON* ]] || fail=1
done
echo "tested $tested, missing $missing: $([[ $fail == 0 ]] && echo OK || echo FAIL)"
exit $fail
