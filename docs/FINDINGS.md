# Theming LibreNMS: what actually gets in the way

Findings from building the Terran skin. Everything here is measured against
LibreNMS master @ `63e0394` (2026-09-17) and is reproducible.

This is not a complaint. The lead maintainer has already identified the same
root cause and asked for it to be fixed — see [Prior art](#prior-art). The point
of this document is to supply the numbers.

---

## TL;DR

1. A theme author's first instinct — write `.panel-heading { ... }` in a custom
   stylesheet — **fails silently half the time**, because `tw_dark.css` styles
   everything at higher specificity.
2. Some colors **cannot be overridden without `!important`**, because core
   ships `!important` on them via Tailwind's `@apply ... !` syntax.
3. Graph ink **cannot be themed from CSS at all**. RRDtool renders PNGs
   server-side.
4. There is no theme packaging, distribution, or per-user selection mechanism.
5. **None of this applies to typography.** A full two-face typographic treatment
   needed zero workarounds, because core barely specifies `font-family`. The
   obstacle is not theming — it is 468 hard-coded color literals.

---

## 1. The specificity landscape

LibreNMS loads stylesheets in this order
([`resources/views/layouts/librenmsv1.blade.php:41-49`](https://github.com/librenms/librenms/blob/master/resources/views/layouts/librenmsv1.blade.php#L41-L49)):

```
styles.css  →  tw_dark.css  →  css/<site_style>.css  →  webui.custom_css[]
```

A custom stylesheet loads **last**, which sounds decisive. It isn't. Source
order only breaks ties at *equal* specificity, and the dark theme is written
as `.dark .thing` — specificity (0,2,0). A theme author writing `.thing`
(0,1,0) loses every time, with no error and no warning.

### Experiment

20 representative elements, styled from a stylesheet loaded last, using plain
class selectors and no `!important` — i.e. what a theme author writes on day one:

| Result | Count |
|---|---|
| Rule took effect | 10 |
| **Rule silently lost** | **10** |

The ten that lost: `.navbar-default`, `.panel-default > .panel-heading`,
`.form-control`, `.dropdown-menu`, `.btn-default`, `.alert-danger`,
`.label-success`, `.well`, `.nav-tabs > li.active > a`, `.panel-footer`.

That is the navigation bar, every panel header, every form input, every
dropdown and every alert — the entire visual frame of the application.

### Isolating what it takes to win

Same 14 *contested* elements, three escalating strategies:

| Strategy | Rules that lost |
|---|---|
| **A.** `.thing { }` — bare selector | **14 / 14** |
| **B.** `html.dark .thing { }` — specificity bumped to (0,2,1) | **4 / 14** |
| **C.** `html.dark .thing { ... !important }` | **0 / 14** |

Strategy B is the minimum viable approach, and it is entirely non-obvious. It
is not documented anywhere. You discover it by wondering why your CSS does
nothing.

The four that survive even strategy B are the subject of the next section.

---

## 2. Core ships `!important` on colors

`resources/css/app.css` builds its button and device-link components with
Tailwind's `@apply`, using the `!` important modifier:

```css
.lnms-btn-default {
  @apply tw:bg-[#3a3f44] tw:hover:bg-[#1e2023] tw:text-white!
         tw:dark:bg-dark-gray-400 tw:dark:hover:bg-dark-gray-300
         tw:dark:border tw:dark:border-dark-gray-100
         tw:dark:text-dark-white-100!;
}

.device-link-down {
  @apply tw:font-bold tw:text-red-600 tw:visited:text-red-600
         tw:dark:text-red-500! tw:dark:visited:text-red-500!;
}
```

Those `!` suffixes compile to `color: … !important` on unlayered rules. **No
specificity beats an `!important` declaration.** A skin has exactly one
available response: `!important` of its own. That is why `terran.css` contains
`!important` on every `.lnms-btn-*` and `.device-link-*` rule — each one is
annotated `[!]` in the source with the upstream rule that forced it.

This is the mechanism behind
[PR #20294](https://github.com/librenms/librenms/pull/20294), where the mono
theme's widget headers were *"silently overridden by hard-coded Tailwind
utilities."* Same root cause, different symptom.

### Hard-coded hex inside the component layer

The same block shows the deeper problem. These are Bootstrap 3's palette
re-hardcoded as Tailwind *arbitrary values* — not tokens, not theme colors,
just literals in a different syntax:

```
tw:bg-[#3a3f44]   tw:bg-[#5cb85c]   tw:bg-[#d9534f]
tw:bg-[#337ab7]   tw:bg-[#f0ad4e]   tw:text-[#232628]
```

A `@theme` block does exist in the same file, defining
`--color-dark-gray-100..500` and `--color-dark-white-100..400`. So a partial
token system is already in place — it just coexists with the literals rather
than replacing them.

---

## 3. Inventory

How much hard-coded color there is, and where.

| Surface | Count |
|---|---|
| Hex literals in `styles.css` | 331 |
| Hex literals in `tw_dark.css` | 272 |
| Hex literals in `mono.css` + `blue.css` | 25 |
| Hex literals in Blade templates | 78 (across 18 files) |
| Inline `style=""` attributes in Blades | 191 (15 set color/background) |
| `tw:` color utilities in Blades | **595 uses, 116 distinct** |
| `tw:dark:` variants in Blades | 538 |
| **Distinct colors repo-wide** | **468** |
| Blade templates total | 303 |

A note on scope: **JavaScript is not a problem.** `html/js/` contains 629 hex
literals, but they are essentially all vendored (`esri-leaflet-vector`,
`leaflet`, `overlib_mini`). First-party JS carries almost no color.

468 distinct colors is the headline. That is not a palette; it is an accretion.
Consolidated, it is plausibly 40–60 real tokens.

---

## 4. The control experiment: typography

The claims above would be easy to dismiss as "theming is just hard." It isn't —
and the same codebase proves it.

While building Terran, the skin was also given a full typographic treatment: two
faces, one condensed for the application frame (navbar, panel headers, table
headers, buttons, tabs) and one monospace for the data (device hostnames, table
body cells, status labels, badges), plus tabular figures throughout the tables.

**Not one of those rules needed a specificity workaround.** No `html.dark`
prefix, no `!important`, no fighting. Plain class selectors in a stylesheet
loaded last simply worked, first try.

The reason is visible in the inventory:

| | Color | Typography |
|---|---|---|
| Declarations in `tw_dark.css` | 272 hex literals | **0** `font-family` |
| Declarations in `styles.css` | 331 hex literals | 5 `font-family` |
| Inline in Blade templates | 595 `tw:` color utilities | ~16 `font-family` |

LibreNMS has essentially **no opinion about typography**, so there is nothing to
override. It has 468 distinct opinions about color, most of them literals, and
overriding any of them is a brawl.

This is a clean natural experiment. Same stylesheet, same load order, same
author, same application, same afternoon. The only variable is whether core
hard-codes the property. Where it stays out of the way, theming is trivial.
Where it scatters literals, theming requires defensive CSS that is nowhere
documented.

The problem is not that theming is hard. The problem is 468 literals.

---

## 5. Graphs are a separate, harder problem

LibreNMS renders RRDtool graphs **server-side to PNG**. CSS variables are
structurally incapable of touching the ink inside them. A skin can style the
frame around a graph and nothing else.

| | Count |
|---|---|
| Graph definition files (`includes/html/graphs/`) | 1835 |
| …that use the `graph_colours.*` config palettes | 89 |
| …that hard-code hex directly | **149** |

The good news is that the abstraction already exists — `graph_colours.blues`,
`.greens`, `.default`, `.mixed`, `.psychedelic` and others are defined in
`config_definitions.json` and are config-driven. It is simply unevenly adopted.
Migrating the 149 stragglers onto the existing palette system is mechanical,
independent of the CSS work, and would make graphs theme-aware for the first
time.

---

## 6. No installation story

- `webui.custom_css[]` is instance-wide. Every user on the instance gets the
  same skin. There is no per-user custom theme.
- Per-user selection requires adding an option to `site_style` in
  `resources/definitions/config_definitions.json` — a core file, overwritten on
  every update. `ConfigRepository.php:91` reads that one path; there is no
  custom-definitions merge.
- The plugin system cannot help. Its five hooks (`DeviceOverviewHook`,
  `MenuEntryHook`, `PortTabHook`, `SettingsHook`, `SinglePageHook`) all inject
  content. None publish CSS or assets.
- Custom styles never receive the `.dark` class. `applySiteStyle()`
  (`html/js/librenms.js:851`) only sets it when the style string is literally
  `"dark"`, so a registered custom theme renders on the **light** base and must
  re-implement the entire dark layer itself.

---

## Prior art

[PR #19029](https://github.com/librenms/librenms/pull/19029) (Feb 2026) proposed
replacing the dark palette with a token-based system using CSS custom
properties. It was closed unmerged. The maintainer's reasoning:

> "Not all colors are convert to tailwind yet. The colors in tailwind exist to
> exactly match the legacy colors scattered through-out the code base. You'll
> need to clean up all the legacy colors first."

and:

> "I think a good approach would be finding old color references and updating
> them to use tailwind classes. After things are modernized, it will be much
> more realistic to tweak the theme."

The refactor is *wanted*. The rejection was about sequencing: the PR changed
appearance and structure simultaneously, on top of unmigrated legacy colors, and
the visual payoff didn't justify the churn ("these colors look nearly identical
to me").

Note also the stated direction is **consolidate onto Tailwind**, not introduce
a parallel CSS-custom-property system. A proposal should follow that.

---

## What would actually help

In dependency order. Each is independently shippable and provably
pixel-identical, which is what makes them reviewable.

1. **Migrate the 149 hard-coded graph files onto `graph_colours.*`.** Entirely
   separate from the CSS work, mechanical, and the abstraction already exists.
2. **Replace the arbitrary-value literals** (`tw:bg-[#337ab7]` etc.) in
   `app.css` component classes with `@theme` tokens. Small, contained, high
   symbolic value.
3. **Drop the `!` modifiers** from `@apply` in component classes, once nothing
   depends on them. This alone would let skins stop using `!important`.
4. **Fold `tw_dark.css`'s 272 literals into the `@theme` block**, area by area,
   each PR pixel-identical.
5. **Then**, and only then, palette changes and a real theme system become
   cheap.

Steps 1–4 are unglamorous and involve no visible change. That is the point —
and it is exactly the order the maintainer asked for.

---

## Reproducing

`harness/` contains a static page that loads LibreNMS's real stylesheets in the
real order against representative DOM. The specificity experiments above were
run against it in a browser. See the repo README for setup.
