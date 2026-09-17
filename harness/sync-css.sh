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
for f in bootstrap.min.css styles.css tw_dark.css fontawesome.min.css; do
  cp -v "$SRC/html/css/$f" "$DEST/"
done

# fontawesome.min.css references ../webfonts/, relative to harness/css/ -
# without these the nav icons render as empty boxes.
mkdir -p "$DEST/../webfonts"
cp -v "$SRC"/html/webfonts/*.woff2 "$SRC"/html/webfonts/*.ttf "$DEST/../webfonts/"

echo
echo "Done. Now run:  python -m http.server 8777"
echo "Then open:      http://localhost:8777/harness/"
