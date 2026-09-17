# librenms-skins

StarCraft-inspired skins for [LibreNMS](https://github.com/librenms/librenms).

Currently shipping **Terran**. Protoss and Zerg are planned.

All artwork is original CSS — gradients, shadows and generated geometry. No
Blizzard assets are used or redistributed. These are "inspired by" skins, not
asset ports.

---

## Status

| Skin | Geometry | Palette | Type |
|---|---|---|---|
| **Terran** | Square, riveted, symmetric | Gunmetal + hazard yellow, red LEDs, green phosphor | Saira Condensed + JetBrains Mono |
| **Protoss** | Chamfered, gold-bracketed | Void blue + keratinous gold, psionic flame | Cinzel + Rajdhani |
| **Zerg** | Asymmetric, grown, uneven | Creep purple + bone, ichor green, ember orange | Metamorphous + Chakra Petch |

All three are complete and verified.

Verified against LibreNMS master @ `63e0394` (2026-09-17).

---

## Install

Every skin is an **overlay on the stock dark theme**, not a replacement for it.
Set your theme to Dark first, or the skin will render on a light base and look
broken.

1. Set your site style to dark — *Preferences → Theme → Dark*.

2. Copy one skin directory into the update-safe custom CSS directory. Copy the
   whole directory — the webfonts live inside it:

```bash
cp -r skins/terran /opt/librenms/html/css/custom/
```

3. Register it:

```bash
lnms config:set webui.custom_css '["css/custom/terran/terran.css"]'
```

4. Hard-refresh the browser.

Substitute `protoss` or `zerg` for `terran` in both commands to use those.
Load **one skin at a time** — `webui.custom_css` is an array and listing two
will cascade them into mush.

**Nothing else to install.** Each skin bundles its own webfonts (~61–77KB of
Latin-subset woff2, all SIL Open Font License). No system fonts to chase, and
no request ever leaves the box.

> `webui.custom_css` is instance-wide. Every user on the instance gets the same
> skin; LibreNMS has no per-user custom theme selection. See
> [docs/FINDINGS.md](docs/FINDINGS.md) §6.

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

Protoss uses the same split, but louder: carved ceremonial capitals for the
frame against a clean futuristic sans for the data. Zerg puts a gnarled organic
display face on the frame and keeps a readable angular sans on the data — the
weirdness lives in the geometry instead, which is what keeps it usable.

Both skins bundle their faces, so this works with no setup and no external
requests — which matters on an air-gapped NOC box, where a Google Fonts
`@import` would silently degrade exactly where it is least convenient to
debug. Details, sizes and licensing:
[`skins/terran/FONTS.md`](skins/terran/FONTS.md) ·
[`skins/protoss/FONTS.md`](skins/protoss/FONTS.md).

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

Switch skins with `?skin=terran` / `?skin=protoss` / `?skin=zerg`, or the
buttons at the top of the page.

The harness reproduces LibreNMS's real DOM and loads the real stylesheets in
the real order from `resources/views/layouts/librenmsv1.blade.php`. Vendored
CSS is gitignored — LibreNMS is GPLv3 and its stylesheets are not redistributed
here.
