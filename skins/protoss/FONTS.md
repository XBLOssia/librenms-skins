# Fonts — Protoss

**Read this one.** Terran degrades gracefully without webfonts. Protoss does
not. Its character lives in the typography, and both intended faces are Google
Fonts with no close system equivalent.

| Token | Voice | Applied to |
|---|---|---|
| `--pr-font-chrome` | Ancient ceremonial caps — the Khalai-inscription voice | Navbar, panel headers, table **headers**, buttons, tabs |
| `--pr-font-data` | Futuristic but readable | Device hostnames, table **body cells**, labels, badges, inputs |
| `--pr-font-code` | Monospace | `pre` / `code` only |

The design intent is a deliberate collision: Protoss are simultaneously ancient
and hyper-advanced, so the frame is carved-stone Roman capitals and the data is
clean technical sans. That contrast *is* the skin. Lose it and you have a blue
and gold color swap.

---

## What you get without webfonts

Measured, not guessed — by probing whether a stack renders identically with and
without its first choice:

| Declared | Typically falls through to | Verdict |
|---|---|---|
| `Cinzel` (chrome) | `Georgia` | Acceptable. Serif caps still read as ceremonial, and Georgia is on virtually every machine. Noticeably less carved. |
| `Rajdhani` (data) | `Segoe UI` / `system-ui` | **Weak.** This is a normal UI sans. All the futurism is gone. |
| `Space Mono` (code) | `Consolas` / generic mono | Fine. Code blocks are a small surface. |

So: the frame survives, the data does not. If you install only one face,
install **Rajdhani**.

> The screenshots in this repo were captured *without* the webfonts installed —
> they show the Georgia/Segoe fallback. The real thing looks meaningfully
> different, and better.

---

## Self-hosting (recommended)

Font files in `html/css/custom/` are served correctly: LibreNMS's rewrite to
`index.php` is guarded by `RewriteCond %{REQUEST_FILENAME} !-f`, so a file that
exists bypasses it. That directory is gitignored upstream, so the fonts survive
`./daily.sh`.

1. Download the `.woff2` files (both OFL-licensed, free to self-host):
   - [Cinzel](https://fonts.google.com/specimen/Cinzel) — SemiBold 600
   - [Rajdhani](https://fonts.google.com/specimen/Rajdhani) — Medium 500, Bold 700

2. Drop them beside the stylesheet:

```bash
cp Cinzel-SemiBold.woff2 Rajdhani-Medium.woff2 Rajdhani-Bold.woff2 \
   /opt/librenms/html/css/custom/
```

3. Uncomment the `@font-face` block in section **1b** of `protoss.css`. It is
   already written for exactly these three files.

`font-display: swap` is set, so text paints in the fallback immediately and
upgrades when the font lands — no invisible-text flash on a slow poller box.

Paths in `url()` resolve relative to the stylesheet, so no `base_url` juggling.

---

## Why not Google Fonts `@import`

It works and it is one line. It is also an external network dependency inside a
tool whose entire job is to keep working when the network is broken — an
air-gapped or egress-filtered NOC gets the fallback anyway — plus a third-party
request per operator per page load. Self-hosting is the same result without
either problem.

---

## Going further

If you want more esoteric and are willing to trade legibility:

- **Chrome:** [Cormorant SC](https://fonts.google.com/specimen/Cormorant+SC) —
  higher contrast, more arcane. Gets fragile below 13px.
- **Data:** [Orbitron](https://fonts.google.com/specimen/Orbitron) — maximum
  sci-fi. Genuinely hard to read as a dense device list; consider scoping it to
  the navbar and panel headers and leaving table cells on Rajdhani:

```css
:root { --pr-font-chrome: "Orbitron", sans-serif; }
html.dark .table > tbody > tr > td { font-family: "Rajdhani", system-ui, sans-serif; }
```

Resist putting a display face in table cells. A device list is something people
stare at for eight hours.
