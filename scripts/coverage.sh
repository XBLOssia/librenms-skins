#!/usr/bin/env bash
# Report which components LibreNMS's dark theme styles that the skins do not.
#
# tw_dark.css is the closest thing to a manifest of "things that need theming":
# if upstream bothered to give a component dark-mode treatment, a skin that
# ignores it will show stock dark-theme colours sitting in the middle of the
# skin. This finds those gaps.
#
#   ./scripts/coverage.sh /opt/librenms
#   ./scripts/coverage.sh /opt/librenms zerg     # single skin
#
# Exit status is 0 always - this is a report, not a gate.

set -uo pipefail

SRC="${1:-/opt/librenms}"
ONLY="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TW="$SRC/html/css/tw_dark.css"

if [ ! -f "$TW" ]; then
  echo "error: $TW not found - pass the path to a LibreNMS checkout" >&2
  echo "usage: $0 /path/to/librenms [skin]" >&2
  exit 1
fi

if [ -n "$ONLY" ]; then
  skins="$ONLY"
else
  skins="terran protoss zerg"
fi

# Distinct component selectors that tw_dark.css targets.
components=$(grep -ohE '\.dark [.#][a-zA-Z0-9_-]+' "$TW" | sed 's/^\.dark //' | awk '!seen[$0]++')
total=$(printf '%s\n' "$components" | grep -c .)

echo "LibreNMS dark-theme components: $total"
echo "Source: $TW"
echo

for skin in $skins; do
  css="$ROOT/skins/$skin/$skin.css"
  if [ ! -f "$css" ]; then
    echo "$skin: no stylesheet at $css - skipping"
    continue
  fi

  missing=""
  n=0
  while read -r c; do
    [ -z "$c" ] && continue
    if ! grep -qF -- "$c" "$css"; then
      missing="$missing $c"
      n=$((n + 1))
    fi
  done <<< "$components"

  covered=$((total - n))
  pct=$((covered * 100 / total))
  printf '%-9s %3d/%-3d covered (%d%%)\n' "$skin" "$covered" "$total" "$pct"

  if [ "$n" -gt 0 ]; then
    printf '%s\n' $missing | awk '{printf "            %s\n", $0}'
  fi
  echo
done
