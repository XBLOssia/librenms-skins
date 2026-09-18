# Theming LibreNMS: what actually gets in the way

Findings from building three skins and deploying one to a production LibreNMS
instance. Everything here is measured against master @ `63e0394` and is
reproducible.

This is not a complaint. The lead maintainer has already identified the same
root cause and asked for it to be fixed — see [Prior art](#prior-art). The point
of this document is to supply the numbers.

---

## TL;DR

1. A theme author's first instinct — write `.panel-heading { ... }` in a custom
   stylesheet — **fails silently half the time**, because `tw_dark.css` styles
   everything at higher specificity.
2. Worse, there is **no single specificity that works**. Upstream selectors run
   two *and* three classes deep, so each component must be checked against the
   rule it is fighting. Getting this wrong left the **dashboard** — the landing
   page — unthemed on a live install.
3. Some colors **cannot be overridden without `!important`**, because core
   ships `!important` on them via Tailwind's `@apply ... !` syntax.
4. Graphs have **their own colour system**, unreachable from CSS, keyed off a
   two-value boolean, and bypassed by 149 graph files that hard-code hex anyway.
5. There is no theme packaging, distribution, or per-user selection mechanism.
6. **None of this applies to typography.** A full two-face typographic treatment
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

### Strategy B is not sufficient either

Found the hard way, on a live install. `tw_dark.css` is not uniformly two
selectors deep:

```css
.dark .gs-w,
.dark .grid-stack .grid-stack-item-content {   /* (0,3,0) */
    background-color: #353a41;
}
```

The second selector is **three** classes deep, so it beats `html.dark .thing`
(0,2,1). A skin that had internalised "prefix everything with `html.dark`" —
the rule this document recommended — still silently lost on dashboard widgets,
and the *dashboard is the landing page*. The most-viewed screen in the
application was the one that looked least themed.

There is no single specificity that is correct. `html.dark .thing` covers most
of `tw_dark.css`, but every rule has to be checked against the upstream
selector it is fighting, and the answer changes per component. The full
descendant chain has to be mirrored:

```css
html.dark .grid-stack .grid-stack-item-content { … }   /* (0,3,1) */
```

The same element also carries `tw:ring-gray-200 tw:dark:ring-dark-gray-200`
inline in the Blade template. So one element's appearance is defined in two
places at two specificities, and a theme author must beat both.

**This is the strongest single argument in this document.** Overriding a
component correctly requires reading upstream's stylesheet first. That is not
theming; it is reverse-engineering.

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

## 5. Graphs: a third, parallel colour system

**Correction to an earlier version of this document**, which claimed graph
interiors were unthemeable. They are themeable — just not from CSS, and not
from anywhere a theme author would think to look.

LibreNMS renders graphs server-side to PNG with RRDtool, so CSS genuinely
cannot reach the ink. But `LibreNMS/Data/Graphing/GraphParameters.php`
(`graphColors()`) reads the palette from config:

```php
$style = $this->style ?: session('applied_site_style');
$def_colors = LibrenmsConfig::get($style == 'dark'
    ? 'rrdgraph_def_text_dark' : 'rrdgraph_def_text');
```

Those two keys hold a **string of RRDtool flags**:

```
-c BACK#2e3338 -c SHADEA#EEEEEE00 -c SHADEB#EEEEEE00 -c CANVAS#FFFFFF00
-c GRID#292929 -c MGRID#2f343e -c FRAME#5e5e5e -c ARROW#5e5e5e
```

parsed back out with a regex (`/-c ([A-Z]+)#([0-9A-Fa-f]{6,8})/`). So graph
colour is configurable, which is good — the skins in this repo now ship a
`graph.conf` per skin and the installer applies it.

What makes this a finding rather than a feature:

1. **It is a third colour system.** CSS custom properties, `tw:` utilities and
   hex literals govern the page; these flag-strings govern graphs; and neither
   knows the other exists. Setting a skin's background means editing both, in
   two unrelated formats, with no mechanism keeping them consistent.
2. **It is keyed off a boolean.** `$style == 'dark'` selects one of exactly two
   palettes. A third theme cannot have its own graph colours without
   overwriting the dark one — which is precisely what this repo's installer has
   to do, and why it must save and restore the previous values.
3. **Individual graph files bypass it anyway.** For example
   `includes/html/graphs/sensor/generic.inc.php`:

```php
$sensor_color     = session('applied_site_style') == 'dark' ? '#f2f2f2' : '#272b30';
$background_color = session('applied_site_style') == 'dark' ? '#272b30' : '#ffffff';
$variance_color   = session('applied_site_style') == 'dark' ? '#3e444c' : '#c5c5c5';
```

   Three more literals, hardcoded inline, ignoring `rrdgraph_def_text_dark`
   entirely. 149 graph files hard-code hex this way while 89 use the
   `graph_colours.*` palettes that already exist.

| | Count |
|---|---|
| Graph definition files (`includes/html/graphs/`) | 1835 |
| …that use the `graph_colours.*` config palettes | 89 |
| …that hard-code hex directly | **149** |

Migrating the 149 stragglers onto the palette system that already exists is
mechanical, independent of the CSS work, and would make graphs theme-aware for
the first time in a way a theme could actually drive.

### Papercut: the value cannot be set via LibreNMS's own CLI

```console
$ lnms config:set rrdgraph_def_text_dark '-c BACK#1d1019 -c GRID#2e1b28'
The "-c" option does not exist.
```

Symfony's console parser reads the leading `-c` as a short option. A `--`
separator before the arguments is required. Since the shipped default for this
key has exactly that shape, **LibreNMS cannot round-trip its own default value
through its own CLI** without a flag that nothing documents. Any tooling that
sets this key has to know.

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
   The same pass should retire the inline
   `session('applied_site_style') == 'dark' ? '#x' : '#y'` ternaries (see §5)
   in favour of `rrdgraph_def_text*`, so graphs have one colour source rather
   than three.
2. **Replace the arbitrary-value literals** (`tw:bg-[#337ab7]` etc.) in
   `app.css` component classes with `@theme` tokens. Small, contained, high
   symbolic value.
3. **Drop the `!` modifiers** from `@apply` in component classes, once nothing
   depends on them. This alone would let skins stop using `!important`.
4. **Fold `tw_dark.css`'s 272 literals into the `@theme` block**, area by area,
   each PR pixel-identical.
5. **Normalise `tw_dark.css` to a consistent selector depth.** Today it mixes
   `.dark .x` and `.dark .y .x`, which is what makes overriding it require
   reading it first. Even without tokens, a predictable depth would make
   third-party theming tractable.
6. **Then**, and only then, palette changes and a real theme system become
   cheap.

Steps 1–4 are unglamorous and involve no visible change. That is the point —
and it is exactly the order the maintainer asked for.

---

## Reproducing

`harness/` contains a static page that loads LibreNMS's real stylesheets in the
real order against representative DOM. The specificity experiments above were
run against it in a browser. See the repo README for setup.
