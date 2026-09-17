# librenms-skins

StarCraft-inspired skins for [LibreNMS](https://github.com/librenms/librenms).

Currently shipping **Terran**. Protoss and Zerg are planned.

All artwork is original CSS — gradients, shadows and generated geometry. No
Blizzard assets are used or redistributed. These are "inspired by" skins, not
asset ports.

---

## Status

| Skin | State | Notes |
|---|---|---|
| Terran | Working | Gunmetal plating, hazard striping, red LEDs, green phosphor |
| Protoss | Planned | Gold-on-blue crystalline, energy glow |
| Zerg | Planned | Organic carapace, purple-brown, creep textures |

Verified against LibreNMS master @ `63e0394` (2026-09-17).

---

## Install (Terran)

Terran is an **overlay on the stock dark theme**, not a replacement for it.
Set your theme to Dark first, or the skin will render on a light base and look
broken.

1. Set your site style to dark — *Preferences → Theme → Dark*.

2. Copy the skin into the update-safe custom CSS directory:

```bash
cp skins/terran/terran.css /opt/librenms/html/css/custom/
```

3. Register it:

```bash
lnms config:set webui.custom_css '["css/custom/terran.css"]'
```

4. Hard-refresh the browser.

`html/css/custom/` is gitignored by LibreNMS, so the skin survives `./daily.sh`
updates. Nothing in LibreNMS core is modified.

### Uninstall

```bash
lnms config:set webui.custom_css '[]'
```

---

## Retheming

The whole skin is driven by the token block at the top of
[`skins/terran/terran.css`](skins/terran/terran.css). Change the variables in
`:root` and nothing else — every rule below reads from them.

### Typography

Terran uses two voices: `--tn-font-chrome` (condensed caps) for the frame —
navbar, panel headers, table headers, buttons — and `--tn-font-data`
(monospace) for the readouts — device hostnames, table body cells, status
labels and badges. Body cells also get tabular figures so uptimes and counters
align down the column.

It works with system fonts and no setup. To self-host a real webfont — which
does work, and survives updates — see
[`skins/terran/FONTS.md`](skins/terran/FONTS.md).

---

## Why these are "skins" and not themes

LibreNMS has no theme installation system. There is no packaging format, no
distribution story, and no way to register a new theme without patching a core
file that updates overwrite. The two available hooks are:

- `webui.custom_css[]` — an array of stylesheets appended last. Instance-wide,
  not per-user. **This is what these skins use.**
- A `site_style` entry in `resources/definitions/config_definitions.json` —
  gives a per-user dropdown, but that file is core and is overwritten on update.

The plugin system cannot carry a theme. It exposes exactly five hooks
(`DeviceOverviewHook`, `MenuEntryHook`, `PortTabHook`, `SettingsHook`,
`SinglePageHook`), all of which inject content. None publish CSS or assets.

Building Terran surfaced concrete, measurable problems with theming LibreNMS as
it stands. Those are written up in **[docs/FINDINGS.md](docs/FINDINGS.md)** with
reproducible numbers — that document, not the skin, is the interesting output
of this project.

---

## Test harness

You can preview and verify a skin without a LibreNMS install.

```bash
# one-time: vendor the stylesheets from a LibreNMS checkout
./harness/sync-css.sh /path/to/librenms

python -m http.server 8777
# then open http://localhost:8777/harness/
```

The harness reproduces LibreNMS's real DOM and loads the real stylesheets in
the real order from `resources/views/layouts/librenmsv1.blade.php`. Vendored
CSS is gitignored — LibreNMS is GPLv3 and its stylesheets are not redistributed
here.
