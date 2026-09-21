#!/usr/bin/env bash
# Vendor the stylesheets the harness needs from a LibreNMS checkout.
# These are GPLv3 and are NOT redistributed in this repo - harness/css/ is gitignored.
#
#   ./harness/sync-css.sh /opt/librenms
set -euo pipefail

SRC="${1:-/opt/librenms}"
DEST="$(cd "$(dirname "$0")" && pwd)/css"

if [ ! -d "$SRC/html/css" ]; then
  echo "error: $SRC does not look like a LibreNMS checkout (no html/css)" >&2
  exit 1
fi

mkdir -p "$DEST"

# --- the Vite bundle --------------------------------------------------------
# app-<hash>.css is the real first stylesheet on every page. It bundles
# Bootstrap AND Tailwind, which matters for two reasons the harness cannot fake:
#
#  1. It declares the cascade LAYERS (theme / base / components / utilities).
#     The inline `tw:...!` utilities compile into the utilities layer carrying
#     !important, and that layering is the whole subject of FINDINGS section 2.
#  2. It defines the `--tw-color-*` theme variables the skins retint. Without
#     it, `tw:dark:bg-dark-gray-200` on a widget header resolves to nothing and
#     the harness silently shows a colour the real page never renders.
#
# An earlier version of this script vendored html/css/bootstrap.min.css instead
# and the harness hand-compiled approximations of the .lnms-btn-* classes. That
# file still exists on disk but the application does not load it.
APP="$(ls -1 "$SRC"/html/build/assets/app-*.css 2>/dev/null | head -1 || true)"
if [ -n "$APP" ]; then
  cp -v "$APP" "$DEST/app.css"
else
  echo "warning: no html/build/assets/app-*.css found." >&2
  echo "         Run 'npm run build' in the checkout, or the harness will be" >&2
  echo "         missing Bootstrap, the cascade layers and the theme variables." >&2
fi

# --- everything else, in the order librenmsv1.blade.php loads it ------------
for f in fontawesome.min.css v4-shims.min.css \
         leaflet.css MarkerCluster.css MarkerCluster.Default.css \
         select2.min.css select2-bootstrap.min.css \
         styles.css tw_dark.css; do
  if [ -f "$SRC/html/css/$f" ]; then
    cp -v "$SRC/html/css/$f" "$DEST/"
  else
    echo "  (skipped, not present: $f)"
  fi
done

# fontawesome.min.css references ../webfonts/, relative to harness/css/ -
# without these the nav icons render as empty boxes.
mkdir -p "$DEST/../webfonts"
cp -v "$SRC"/html/webfonts/*.woff2 "$SRC"/html/webfonts/*.ttf "$DEST/../webfonts/"

echo
echo "Done. Now run:  python -m http.server 8777"
echo "Then open:      http://localhost:8777/harness/          (component fixtures)"
echo "                http://localhost:8777/harness/mockup.html (dashboard mockup)"
