#!/usr/bin/env bash
# Предпросмотр локации первого акта для художника: снимки квартиры «сломано» и «починено»
# на обычном (720×1280) и высоком (720×1600) экране — как игрок увидит сцену в Godot.
# Использование: GODOT=/путь/к/godot tools/preview_location.sh <room|kitchen|bath|living> [папка]
# Без своего дисплея запускается под xvfb-run. Профиль игрока не трогается.
set -uo pipefail
loc="${1:-room}"
out="${2:-build/preview}"
self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
if [[ -z "${DISPLAY:-}" ]]; then
  command -v xvfb-run >/dev/null || { echo "preview: нет DISPLAY и xvfb-run"; exit 2; }
  exec xvfb-run -a -s "-screen 0 720x1600x24" "$self" "$@"
fi
GODOT="${GODOT:-godot}"
cd "$(dirname "$self")/.."
mkdir -p "$out"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export XDG_DATA_HOME="$tmp"
# сколько ремонтов сделано до начала локации и после её окончания (порядок act1.json)
case "$loc" in
  room) before=0; after=4 ;;
  kitchen) before=4; after=9 ;;
  bath) before=9; after=14 ;;
  living) before=14; after=19 ;;
  *) echo "preview: локация room|kitchen|bath|living"; exit 2 ;;
esac
"$GODOT" --headless --path . --import >/dev/null 2>&1
for size in 720x1280 720x1600; do
  for state in broken fixed; do
    stage=$([[ $state == broken ]] && echo $before || echo $after)
    file="$out/${loc}_${state}_${size}.png"
    "$GODOT" --path . --fixed-fps 60 --resolution "$size" -- --screen=hub --home-stage="$stage" \
      --screen-args="location:$loc" --shot="$(cd "$out" && pwd)/$(basename "$file")@2.0" >/dev/null 2>&1
    [[ -f "$file" ]] && echo "preview: $file" || echo "preview: не получилось $file"
  done
done
