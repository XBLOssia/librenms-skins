# Fonts

Terran uses two typographic voices:

| Token | Role | Applied to |
|---|---|---|
| `--tn-font-chrome` | Condensed caps — "stencilled on the hull" | Navbar, panel headers, table **headers**, buttons, tabs, alerts |
| `--tn-font-data` | Monospace — "CRT terminal readout" | Device hostnames, table **body cells**, labels, badges, `pre`/`code` |

Table body cells and status bugs also get `font-variant-numeric: tabular-nums`,
so uptimes, counters and port numbers align into columns instead of drifting.

Both tokens are plain CSS variables at the top of `terran.css`. Change them
there and every rule follows.

---

## Option 1 — system fonts (default, zero setup)

Out of the box the skin uses fallback chains only:

```css
--tn-font-chrome: "Saira Condensed", "Oswald", "Roboto Condensed",
                  "DIN Alternate", "Arial Narrow", system-ui, sans-serif;
--tn-font-data:   "JetBrains Mono", "IBM Plex Mono", "DejaVu Sans Mono",
                  "Consolas", "SF Mono", "Menlo", ui-monospace, monospace;
```

Nothing to install and no network egress. The monospace chain is reliable —
`Consolas` ships on Windows, `SF Mono`/`Menlo` on macOS, `DejaVu Sans Mono` on
most Linux distributions (LibreNMS itself even bundles `DejaVuSans.ttf`).

The condensed chain is less reliable. `Arial Narrow` is broadly present on
Windows and macOS; on a bare Linux desktop you will likely fall through to
`system-ui`, which is not condensed. If the headers look wrong, that is why —
use option 2.

---

## Option 2 — self-hosted webfont (recommended)

**Font files placed in `html/css/custom/` are served correctly.** LibreNMS's
rewrite rule is guarded by `RewriteCond %{REQUEST_FILENAME} !-f`, so a file that
exists on disk bypasses the rewrite to `index.php` and is served directly. That
directory is also gitignored upstream, so the fonts survive `./daily.sh`.

1. Download the `.woff2` files. Suggested pairing:
   - **Data:** [JetBrains Mono](https://www.jetbrains.com/lp/mono/) (OFL) — designed for
     long reading at small sizes, which is what a device list is.
   - **Chrome:** [Saira Condensed](https://fonts.google.com/specimen/Saira+Condensed) (OFL)
     — the squared-off industrial condensed the skin is designed around.

2. Drop them next to the stylesheet:

```bash
cp JetBrainsMono-Regular.woff2 JetBrainsMono-Bold.woff2 \
   SairaCondensed-SemiBold.woff2 /opt/librenms/html/css/custom/
```

3. Uncomment the `@font-face` block in section **1b** of `terran.css` and
   extend it for the chrome face:

```css
@font-face {
  font-family: "Terran Data";
  src: url("JetBrainsMono-Regular.woff2") format("woff2");
  font-weight: 400; font-display: swap;
}
@font-face {
  font-family: "Terran Data";
  src: url("JetBrainsMono-Bold.woff2") format("woff2");
  font-weight: 700; font-display: swap;
}
@font-face {
  font-family: "Terran Chrome";
  src: url("SairaCondensed-SemiBold.woff2") format("woff2");
  font-weight: 600; font-display: swap;
}
:root {
  --tn-font-data:   "Terran Data", ui-monospace, monospace;
  --tn-font-chrome: "Terran Chrome", "Arial Narrow", system-ui, sans-serif;
}
```

`font-display: swap` means text renders in the fallback immediately and
upgrades when the font arrives — no invisible-text flash on a slow poller box.

Paths in `url()` are relative to the stylesheet, so no `base_url` juggling.

---

## Option 3 — Google Fonts `@import`

Works, and is one line:

```css
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap');
```

**Not recommended for a monitoring box.** It adds an external network
dependency to a tool whose entire job is to keep working when the network is
having a bad day — an air-gapped or egress-filtered NOC will simply render the
fallback. It also leaks a request to a third party on every page load for every
operator. Option 2 is the same result without either problem.

---

## Going harder on the CRT look

If you want full phosphor-terminal rather than clean monospace, swap
`--tn-font-data` for something like
[Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono) or
[VT323](https://fonts.google.com/specimen/VT323).

Be warned: both are considerably less legible at 12px, and a device list is
something people stare at for eight hours. Consider scoping the novelty face to
low-density chrome only, and leaving table cells on a workhorse mono:

```css
:root { --tn-font-data: "Share Tech Mono", ui-monospace, monospace; }
html.dark .table > tbody > tr > td {
  font-family: "JetBrains Mono", ui-monospace, monospace;
}
```
