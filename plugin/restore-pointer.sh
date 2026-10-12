#!/bin/bash
# Hyprland warps the pointer to the middle of a window when that window takes
# focus on map. This holds cursor:no_warps on until OmaDeck has mapped, then
# always puts the previous setting back. If the pointer is still sitting on
# the window's middle afterwards, it is put back. A pointer that kept moving
# is left alone.
#
# The window stays hidden until this script writes /tmp/omadeck-nowarps-ready.
# Argument 1 is the summon generation, so an older run cannot turn warps back
# on under a newer one.

gen=${1:-}
case "$gen" in
  ''|*[!0-9]*) exit 0 ;;
esac

pos=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')
x=${pos%,*}
y=${pos#*,}
case "$x" in ''|*[!0-9]*) x=; y= ;; esac
case "$y" in ''|*[!0-9]*) x=; y= ;; esac

prev=$(hyprctl getoption cursor:no_warps 2>/dev/null | awk '/^bool:/{print $2; exit}')
case "$prev" in
  true|false) ;;
  *) prev=false ;;
esac

ready=/tmp/omadeck-nowarps-ready
token=/tmp/omadeck-nowarps-gen
shown=/tmp/omadeck-shown

restored=0
restore_warps() {
  [ "$restored" = 1 ] && return 0
  cur=$(cat "$token" 2>/dev/null || true)
  # A newer summon owns the setting now.
  [ "$cur" = "$gen" ] || return 0
  hyprctl eval "hl.config({ cursor = { no_warps = $prev } })" >/dev/null 2>&1 || true
  nowarp=$(hyprctl getoption cursor:no_warps 2>/dev/null | awk '/^bool:/{print $2; exit}')
  [ "$nowarp" = "$prev" ] || return 0
  restored=1
  if [ "$(cat "$shown" 2>/dev/null)" = "$gen" ]; then
    rm -f "$shown"
  fi
  rm -f "$token" "$ready"
}
trap restore_warps EXIT

rm -f "$shown" "$ready"
echo "$gen" > "$token"

hyprctl eval 'hl.config({ cursor = { no_warps = true } })' >/dev/null 2>&1 || exit 1

armed=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  if hyprctl getoption cursor:no_warps 2>/dev/null | grep -q 'bool: true'; then
    armed=1
    break
  fi
  sleep 0.02
done
[ "$armed" = 1 ] || exit 1
echo "$gen" > "$ready"

for _ in $(seq 1 40); do
  [ "$(cat "$shown" 2>/dev/null)" = "$gen" ] && break
  sleep 0.05
done
# The map warp lands within a couple of hundred milliseconds of the window
# becoming visible. Hold a little longer than that.
sleep 0.8

restore_warps

# no_warps stops the warp. If it did not, and the pointer is still on the
# window's middle, put it back where it was before the window opened.
[ -n "$x" ] || exit 0
sleep 0.12
now=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')
sleep 0.06
still=$(hyprctl cursorpos 2>/dev/null | tr -d ' ')
[ "$now" = "$still" ] || exit 0
[ "$now" != "$pos" ] || exit 0

center=$(hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys
try:
    clients = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for c in clients:
    if c.get("title") != "OmaDeck":
        continue
    at = c.get("at") or [0, 0]
    sz = c.get("size") or [0, 0]
    print("%d,%d" % (round(at[0] + sz[0] / 2), round(at[1] + sz[1] / 2)))
    break
')
[ -n "$center" ] || exit 0

nx=${now%,*}; ny=${now#*,}
cx=${center%,*}; cy=${center#*,}
dx=$((nx - cx)); dy=$((ny - cy))
[ "${dx#-}" -le 3 ] && [ "${dy#-}" -le 3 ] || exit 0
hyprctl dispatch "hl.dsp.cursor.move({ x = $x, y = $y })" >/dev/null 2>&1 || true
