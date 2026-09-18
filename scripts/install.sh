#!/usr/bin/env bash
#
# Install a skin onto a LibreNMS host.
#
#   ./scripts/install.sh <skin> [--librenms DIR] [--mode link|copy] [--dry-run]
#
#   ./scripts/install.sh zerg
#   ./scripts/install.sh terran --mode copy
#   ./scripts/install.sh protoss --librenms /opt/librenms --dry-run
#
# MODES
#   link  (default) symlink html/css/custom/<skin> -> this repo's skins/<skin>.
#         The canonical copy stays OUTSIDE the LibreNMS tree, so updating the
#         skin is `git pull` here and nothing is ever edited under LibreNMS.
#         Apache's html/.htaccess sets `Options +FollowSymlinks`, and nginx
#         follows symlinks by default, so this serves correctly.
#   copy  copy the directory in. Use if the repo lives somewhere the webserver
#         user cannot read, or if you would rather not depend on symlinks.
#
# Everything this does is reversible with scripts/uninstall.sh.
#
set -euo pipefail

SKIN=""
LIBRENMS="/opt/librenms"
MODE="link"
DRY=0

die() { echo "error: $*" >&2; exit 1; }
run() { if [ "$DRY" -eq 1 ]; then echo "  [dry-run] $*"; else eval "$@"; fi; }

while [ $# -gt 0 ]; do
  case "$1" in
    --librenms) LIBRENMS="${2:-}"; shift 2 ;;
    --mode)     MODE="${2:-}"; shift 2 ;;
    --dry-run)  DRY=1; shift ;;
    -h|--help)  sed -n '2,25p' "$0"; exit 0 ;;
    -*)         die "unknown option: $1" ;;
    *)          SKIN="$1"; shift ;;
  esac
done

REPO="$(cd "$(dirname "$0")/.." && pwd)"

[ -n "$SKIN" ] || die "no skin given. usage: $0 <terran|protoss|zerg> [options]"
[ -d "$REPO/skins/$SKIN" ] || die "no such skin: $SKIN (looked in $REPO/skins/)"
[ -f "$REPO/skins/$SKIN/$SKIN.css" ] || die "missing $REPO/skins/$SKIN/$SKIN.css"
[ -d "$LIBRENMS/html/css" ] || die "$LIBRENMS does not look like a LibreNMS install (no html/css)"
case "$MODE" in link|copy) ;; *) die "--mode must be 'link' or 'copy'" ;; esac

CUSTOM="$LIBRENMS/html/css/custom"
TARGET="$CUSTOM/$SKIN"
CSSPATH="css/custom/$SKIN/$SKIN.css"

echo "Installing '$SKIN'"
echo "  repo:      $REPO"
echo "  librenms:  $LIBRENMS"
echo "  mode:      $MODE"
echo "  target:    $TARGET"
[ "$DRY" -eq 1 ] && echo "  DRY RUN - nothing will be changed"
echo

# --- record the current custom_css so uninstall can restore it -------------
if command -v lnms >/dev/null 2>&1 || [ -x "$LIBRENMS/lnms" ]; then
  LNMS="$(command -v lnms || echo "$LIBRENMS/lnms")"
else
  die "lnms not found. Run this on the LibreNMS host."
fi

CURRENT="$("$LNMS" config:get webui.custom_css 2>/dev/null || echo '')"
echo "Current webui.custom_css:"
echo "  ${CURRENT:-<empty>}"
if [ -n "$CURRENT" ] && ! printf '%s' "$CURRENT" | grep -q '^\[\s*\]$'; then
  echo
  echo "  NOTE: custom_css is not empty. This script REPLACES it, because"
  echo "        loading two skins at once cascades them into mush. The value"
  echo "        above is saved to $CUSTOM/.previous-custom_css so"
  echo "        uninstall.sh can put it back."
fi
echo

# --- place the files -------------------------------------------------------
run "mkdir -p '$CUSTOM'"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  echo "Removing existing $TARGET (reinstall)"
  run "rm -rf '$TARGET'"
fi

if [ "$MODE" = "link" ]; then
  run "ln -s '$REPO/skins/$SKIN' '$TARGET'"
else
  run "cp -r '$REPO/skins/$SKIN' '$TARGET'"
fi

# Save the prior value, but ONLY the first time. Installing zerg over terran
# would otherwise record terran's path as "the original", and uninstall would
# then restore a stylesheet that is no longer there.
if [ "$DRY" -eq 0 ] && [ ! -f "$CUSTOM/.previous-custom_css" ]; then
  printf '%s\n' "$CURRENT" > "$CUSTOM/.previous-custom_css"
fi

# --- register it -----------------------------------------------------------
run "'$LNMS' config:set webui.custom_css '[\"$CSSPATH\"]'"

ok=1

# --- graph colours ---------------------------------------------------------
# RRDtool renders graph interiors server-side to PNG, so CSS cannot reach them.
# LibreNMS does expose the palette as config, so a skin can still match.
GRAPHCONF="$REPO/skins/$SKIN/graph.conf"
if [ -f "$GRAPHCONF" ]; then
  echo
  echo "Applying graph colours from skins/$SKIN/graph.conf"

  if [ "$DRY" -eq 0 ] && [ ! -f "$CUSTOM/.previous-graph" ]; then
    {
      printf 'RRDGRAPH_DEF_TEXT_DARK=%s\n' "$("$LNMS" config:get rrdgraph_def_text_dark 2>/dev/null)"
      printf 'RRDGRAPH_DEF_TEXT_COLOR_DARK=%s\n' "$("$LNMS" config:get rrdgraph_def_text_color_dark 2>/dev/null)"
    } > "$CUSTOM/.previous-graph"
  fi

  gtext="$(grep '^RRDGRAPH_DEF_TEXT_DARK=' "$GRAPHCONF" | cut -d= -f2-)"
  gcolor="$(grep '^RRDGRAPH_DEF_TEXT_COLOR_DARK=' "$GRAPHCONF" | cut -d= -f2-)"

  # The `--` is REQUIRED. The value begins with `-c`, which Symfony's console
  # parser otherwise treats as a short option and aborts with
  #   The "-c" option does not exist.
  # LibreNMS's own shipped default for this key has the same shape, so the
  # setting cannot be round-tripped through `lnms config:set` without it.
  [ -n "$gtext" ]  && run "'$LNMS' config:set -- rrdgraph_def_text_dark '$gtext'"
  [ -n "$gcolor" ] && run "'$LNMS' config:set -- rrdgraph_def_text_color_dark '$gcolor'"

  if [ "$DRY" -eq 0 ] && [ -n "$gtext" ]; then
    if [ "$("$LNMS" config:get rrdgraph_def_text_dark 2>/dev/null)" = "$gtext" ]; then
      echo "  OK   graph colours applied"
    else
      echo "  FAIL graph colours did not take - graphs will keep stock colours"
      ok=0
    fi
  fi
fi

echo
if [ "$DRY" -eq 1 ]; then
  echo "Dry run complete. Nothing changed."
  exit 0
fi

# --- verify ----------------------------------------------------------------
echo "Verifying:"
if [ -f "$TARGET/$SKIN.css" ]; then echo "  OK   stylesheet readable at $TARGET/$SKIN.css"
else echo "  FAIL stylesheet not readable at $TARGET/$SKIN.css"; ok=0; fi

fonts=$(ls "$TARGET/fonts/"*.woff2 2>/dev/null | grep -c . || true)
if [ "${fonts:-0}" -gt 0 ]; then echo "  OK   $fonts bundled webfonts present"
else echo "  WARN no webfonts found - the skin will fall back to system fonts"; fi

now="$("$LNMS" config:get webui.custom_css 2>/dev/null || echo '')"
if printf '%s' "$now" | grep -qF "$CSSPATH"; then echo "  OK   webui.custom_css -> $now"
else echo "  FAIL webui.custom_css is '$now'"; ok=0; fi

echo
if [ "$ok" -eq 1 ]; then
  cat <<EOF
Done.

Two things left, both in the browser:
  1. Set your theme to Dark (Preferences -> Theme -> Dark). These skins are an
     overlay on the stock dark theme; on the light base they look broken.
  2. Hard-refresh (Ctrl-Shift-R). The stylesheet is cache-busted by LibreNMS
     but your browser may hold the old one.

To remove:  ./scripts/uninstall.sh --librenms '$LIBRENMS'
EOF
else
  echo "Install did not verify cleanly. See FAIL lines above."
  echo "To back out: ./scripts/uninstall.sh --librenms '$LIBRENMS'"
  exit 1
fi
