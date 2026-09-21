#!/usr/bin/env bash
#
# Remove skins from a LibreNMS host and restore the previous custom_css.
#
#   ./scripts/uninstall.sh [--librenms DIR] [--skin NAME] [--purge] [--dry-run]
#
#   ./scripts/uninstall.sh                      # remove all skins, restore config
#   ./scripts/uninstall.sh --skin zerg          # remove one skin's files only
#   ./scripts/uninstall.sh --purge              # also clear custom_css entirely
#   ./scripts/uninstall.sh --dry-run            # show what would happen
#
# This touches nothing outside html/css/custom/ and the webui.custom_css
# setting. No LibreNMS core file is modified by install, so there is nothing
# else to undo.
#
# Your theme preference (Preferences -> Theme) is a per-user setting that the
# installer never changed, so it is deliberately left alone. Switch back to
# Light yourself if you want to.
#
set -euo pipefail

LIBRENMS="/opt/librenms"
ONLY=""
PURGE=0
DRY=0

die() { echo "error: $*" >&2; exit 1; }
run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else eval "$@"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --librenms) LIBRENMS="${2:-}"; shift 2 ;;
    --skin)     ONLY="${2:-}"; shift 2 ;;
    --purge)    PURGE=1; shift ;;
    --dry-run)  DRY=1; shift ;;
    -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
    *)          die "unknown argument: $1" ;;
  esac
done

[ -d "$LIBRENMS/html/css" ] || die "$LIBRENMS does not look like a LibreNMS install"

CUSTOM="$LIBRENMS/html/css/custom"
if command -v lnms >/dev/null 2>&1 || [ -x "$LIBRENMS/lnms" ]; then
  LNMS="$(command -v lnms || echo "$LIBRENMS/lnms")"
else
  die "lnms not found. Run this on the LibreNMS host."
fi

echo "Uninstalling from $LIBRENMS"
[ "$DRY" -eq 1 ] && echo "  DRY RUN - nothing will be changed"
echo

# --- remove skin files -----------------------------------------------------
if [ -n "$ONLY" ]; then
  candidates="$ONLY"
else
  candidates="terran protoss zerg"
fi

found=0
for s in $candidates; do
  t="$CUSTOM/$s"
  if [ -L "$t" ]; then
    echo "Removing symlink $t"
    run "rm -f '$t'"
    found=$((found + 1))
  elif [ -d "$t" ]; then
    echo "Removing directory $t"
    run "rm -rf '$t'"
    found=$((found + 1))
  fi
done

# Older layout: a bare stylesheet dropped straight into custom/
for s in $candidates; do
  if [ -f "$CUSTOM/$s.css" ]; then
    echo "Removing legacy $CUSTOM/$s.css"
    run "rm -f '$CUSTOM/$s.css'"
    found=$((found + 1))
  fi
done

[ "$found" -eq 0 ] && echo "No skin files found - nothing to remove."

# --- restore configuration -------------------------------------------------
echo
CURRENT="$("$LNMS" config:get webui.custom_css 2>/dev/null || echo '')"
echo "webui.custom_css is currently: ${CURRENT:-<empty>}"

if [ "$PURGE" -eq 1 ]; then
  echo "Clearing webui.custom_css (--purge)"
  run "'$LNMS' config:clear webui.custom_css"
elif [ -n "$ONLY" ]; then
  echo "Leaving webui.custom_css alone (--skin given; set it yourself if needed)."
elif [ -f "$CUSTOM/.previous-custom_css" ]; then
  PREV="$(cat "$CUSTOM/.previous-custom_css")"
  if [ -z "$PREV" ] || printf '%s' "$PREV" | grep -q '^\[\s*\]$'; then
    echo "Restoring webui.custom_css to empty (its value before install)"
    run "'$LNMS' config:clear webui.custom_css"
  else
    echo "Restoring webui.custom_css to its pre-install value: $PREV"
    run "'$LNMS' config:set webui.custom_css '$PREV'"
  fi
  run "rm -f '$CUSTOM/.previous-custom_css'"
else
  echo "No saved pre-install value found. Clearing webui.custom_css."
  echo "  (If you had your own custom CSS before installing a skin, re-add it.)"
  run "'$LNMS' config:clear webui.custom_css"
fi

# --- restore graph colours -------------------------------------------------
if [ -f "$CUSTOM/.previous-graph" ] && [ -z "$ONLY" ]; then
  echo
  echo "Restoring RRDtool graph colours"
  # Restore by SETTING, not clearing: `lnms config:clear` does not reliably
  # revert these keys (verified on a live host - a cleared graph_colours.*
  # kept the overridden value).
  while IFS= read -r line; do
    case "$line" in ''|\#*) continue ;; esac
    k="${line%%=*}"; v="${line#*=}"
    if [ -n "$v" ]; then run "'$LNMS' config:set -- '$k' '$v'"
    else run "'$LNMS' config:clear '$k'"; fi
  done < "$CUSTOM/.previous-graph"
  run "rm -f '$CUSTOM/.previous-graph'"
fi

echo
if [ "$DRY" -eq 1 ]; then
  echo "Dry run complete. Nothing changed."
  exit 0
fi

echo "Verifying:"
left=0
for s in $candidates; do
  if [ -e "$CUSTOM/$s" ] || [ -L "$CUSTOM/$s" ]; then echo "  FAIL $CUSTOM/$s still present"; left=1; fi
done
[ "$left" -eq 0 ] && echo "  OK   no skin files remain"
echo "  OK   webui.custom_css -> $("$LNMS" config:get webui.custom_css 2>/dev/null || echo '<empty>')"

cat <<'EOF'

Done. Hard-refresh the browser (Ctrl-Shift-R) to drop the cached stylesheet.
EOF

# Core is only modified if the optional port-graph patch was applied, which is
# a separate, opt-in step. Say so accurately rather than claiming either way.
if grep -q 'graph_colours.port_in' "$LIBRENMS/includes/html/graphs/generic_data.inc.php" 2>/dev/null; then
  cat <<'EOF'
NOTE: the optional core patch IS still applied to
  includes/html/graphs/generic_data.inc.php
Port graphs now fall back to their stock colours (the patch defaults to them),
so nothing looks wrong, but core is still modified. To restore it fully:

  ./scripts/patch-core.sh revert
EOF
else
  echo "LibreNMS core was not modified, so there is nothing further to revert."
fi
