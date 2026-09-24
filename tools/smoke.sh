#!/usr/bin/env bash
# Smoke: DevRunner --smoke без окна открывает по очереди все готовые экраны и попапы Router.
# Падает, если Godot вышел не с 0 или в выводе есть SCRIPT ERROR / Parse Error.
# Профиль игрока не трогается: user:// во временной папке, каждый раз «первый запуск».
# Использование: GODOT=/путь/к/godot tools/smoke.sh
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
TO=$(command -v timeout || true)   # на macOS timeout может не быть: у DevRunner есть свой предел

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

XDG_DATA_HOME="$tmp" ${TO:+$TO 120} "$GODOT" --headless --path . --fixed-fps 60 -- --smoke \
  >"$tmp/out.txt" 2>&1
code=$?

grep -E '^(SMOKE|RESULT)' "$tmp/out.txt"
errors=$(grep -E 'SCRIPT ERROR|Parse Error' "$tmp/out.txt" || true)
if [[ $code -ne 0 || -n "$errors" ]]; then
  [[ -n "$errors" ]] && printf '%s\n' "$errors"
  [[ $code -eq 124 ]] && echo "(killed after 120 s)"
  echo "smoke: FAIL (exit $code, $(printf '%s' "$errors" | grep -c . || true) script error line(s))"
  exit 1
fi
echo "smoke: OK"
