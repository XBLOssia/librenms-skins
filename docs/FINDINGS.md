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
3. **22 colour utilities land `!important` inside a cascade layer.** A `tw:…!`
   written inline in a template compiles into Tailwind's `utilities` layer, and
   `webui.custom_css` — loaded last, unlayered — structurally cannot beat it
   with `!important` of its own, at any specificity. They *are* reachable, but
   only by redefining the Tailwind theme variable behind them, or by re-opening
   Tailwind's own layer. An earlier draft of this document said they were
   unreachable. **That was wrong, and it was wrong because of a typo in my own
   test** — section 2 keeps the correction and the bad test that caused it.
4. Graphs have **their own colour system**, unreachable from CSS and keyed off
   a two-value boolean. Graph *chrome* is configurable and themes cleanly; the
   *data series* often do not, because **5 shared helpers hard-code 40 hex
   literals and read no config at all** — and 169 graph files delegate to them.
5. ~~Some colour is not in a stylesheet at all.~~ **Retracted** — the widget
   title bar *is* themeable, and always was. What is true is narrower and only
   about auditing: its class list lives in a JavaScript string, so a
   stylesheet-reading audit cannot see the element. See §2b.
6. The stock dark theme has its **own contrast bug**: saturated row fills under
   dark text on the alert rules page. Any theme inherits it.
7. There is no theme packaging, distribution, or per-user selection mechanism.
8. **None of this applies to typography.** A full two-face typographic treatment
   needed zero workarounds, because core barely specifies `font-family`. The
   obstacle is not theming — it is 264 hard-coded color literals.

---

## Corrections ledger

Every claim in this document that has since been shown wrong, kept in one place
so a reader can see what to distrust without reading all of it. Several were
caught by our own later work rather than by review, which is the point: a
measurement is only as good as the last time anyone checked it.

| Claim | Status | How it broke |
|---|---|---|
| "468 distinct first-party colours" | **corrected → 264** | The count included `html/js/`, which this document itself calls vendored. Caught by writing the reproduction command. |
| "149 graph files hard-code hex" | **corrected → 58 literals in 15 helpers** | The files mostly delegate to shared helpers; the literals live in the helpers. |
| Coverage "100%" | **corrected → 83%** | Revised down twice. First the denominator omitted 123 `styles.css` classes; then substring matching over-counted. |
| §2: inline `tw:…!` utilities are "unreachable from `custom_css` by any means" | **retracted** | The test redefined `--color-red-500`; LibreNMS prefixes its theme variables, so the name is `--tw-color-red-500`. A typo read as a property of the cascade. |
| §2b: the widget header colour "is not in a stylesheet at all" | **retracted** | It is themeable, via the element selector or the theme variable — which §16 of every skin here now does. Flagged by a LibreNMS maintainer; our own later work had already disproved it. |
| `tw_dark.css` is "the whole dark theme" | **corrected** | Per a maintainer: legacy Bootstrap overrides kept for the Tailwind theme toggle, carrying a lot of dead CSS. Some of its 272 literals want deleting, not tokenising. |

**The pattern worth naming:** four of these six were true when written and
falsified later — three of them by work in this same repo. Nothing here
re-checks a finding once it is written down, so corrections only happen when
something forces them. If you are reading this document to decide whether to
act on it, weight the reproduction commands over the prose.

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

Those `!` suffixes compile to `!important`. No specificity beats an
`!important` declaration, so a skin has to answer with `!important` of its own.
That is why `terran.css` carries `!important` on every `.lnms-btn-*` and
`.device-link-*` rule — each annotated `[!]` in the source with the upstream
rule that forced it.

### But that only works for *half* of them

An earlier version of this document stopped there and said `!important` was the
answer. That is wrong, and the distinction matters more than the original
point.

**Where the `!` lives decides whether a theme can reach it at all:**

| `!` appears in | Compiles to | Can `custom_css` override it? |
|---|---|---|
| `@apply … tw:text-white!` inside `app.css` | `!important` on an **unlayered** rule | **Yes** — match the specificity and use `!important` |
| `tw:text-white!` inline in a Blade template | `!important` inside the **`utilities` cascade layer** | **Not with `!important`.** Only by redefining the theme variable, or re-opening the layer. |

The second row is a hard wall, and it is a consequence of load order rather
than a quirk:

- `app.css` is imported first and its line 2, `@import "tailwindcss"`,
  establishes Tailwind's layer order (`theme`, `base`, `components`,
  `utilities`).
- `webui.custom_css[]` is injected **last**
  (`librenmsv1.blade.php:47`), and is unlayered.
- For *normal* declarations, unlayered wins over layered — which is why
  ordinary theming works at all.
- For *`!important`* declarations the cascade **reverses**: earlier layers beat
  later ones, and unlayered `!important` is the weakest of all.
- A stylesheet cannot retroactively insert itself into an earlier layer. Layer
  order follows first declaration, and `app.css` already declared them.

So an `!important` in `custom_css` structurally cannot beat an `!important`
inside any `app.css` layer. That much is real, and it is worth knowing.

What it does *not* mean is that the declaration is unthemeable. See below.

### Verified — and then corrected

Tested against a live instance on the red device links on `/eventlog`
(`tw:dark:text-red-500!`, measured at **3.3:1** — below WCAG AA). Every result
is read back as normalised RGB rather than trusting the computed-value string,
**with CSS transitions suppressed** — see the warning below.

| Attempt | Result |
|---|---|
| Unlayered `!important`, specificity (0,2,1) vs upstream (0,1,0) | no change |
| Same rule inside `@layer utilities`, *without* `!important` | no change |
| Same rule inside a **new** layer declared after `utilities`, `!important` | no change |
| Redefining `--color-red-500` on `html.dark` | no change |
| **Redefining `--tw-color-red-500` on `html.dark`** | **overrides it** |
| **Re-opening `@layer utilities` with `!important`** | **overrides it** — even at specificity (0,1,0), on source order alone |

The rule being fought throughout:
`.tw\:dark\:text-red-500\!:where(.dark, .dark *)`, `!important`, layer
`utilities`.

#### The correction, and the mistake that caused it

An earlier draft of this document listed only the first four rows and concluded
that these declarations were **unreachable from `custom_css` by any means**. It
called that "the strongest single argument in this document".

It was wrong. Two things override them, and row 4 is why I missed both:

**LibreNMS configures Tailwind with the `tw` prefix, and that prefixes the
theme variables too.** The variable is `--tw-color-red-500`. I tested
`--color-red-500`, which is not defined by anything, so nothing happened — and
I read that null result as a property of the cascade rather than as a typo.

```bash
# the variable exists, under the prefixed name:
grep -o 'var(--tw-color-red-500)' html/css/app-*.css | head -1
```

The declaration resolves `var(--tw-color-red-500)` at **use** time, against the
custom property the element inherits. Custom property lookup does not care
about layers or importance — so redefining the variable retints the utility
regardless of the `!important` sitting in front of it.

**Second trap, for anyone reproducing this:** run it with transitions
suppressed. My first re-test appeared to show a *different* wrong answer,
because `getComputedStyle` caught a colour mid-transition and serialised it as
`oklab(…)` — the same colour, in different clothes.

```js
document.head.insertAdjacentHTML('beforeend',
  '<style>*,*::before,*::after{transition:none!important;animation:none!important}</style>');
```

#### What survives the correction

The cascade-layer wall is real. The conclusion drawn from it was not. What is
left is a smaller and more honest complaint:

- `!important` on an inline utility means a theme **cannot override one usage**.
  Retinting the variable changes `red-500` *everywhere*. There is no way to say
  "this particular badge should be a different red" — it is all or nothing.
- The only two mechanisms that work are both **couplings to Tailwind internals**
  — the prefixed theme-variable names, or the layer name Tailwind emits. Neither
  is a LibreNMS interface. Rename either and every theme silently reverts to
  stock, with no error.
- None of it is discoverable. Getting to something true took a wrong answer, a
  misread null result, and a transition artefact.

**The fix is still trivial upstream, and cheaper than any of the above:** drop
the `!` where nothing depends on it, or move the declaration into a component
class. Neither needs a theme system, a token system, or any visual change.

### How much of it there is

```bash
grep -rhoE 'tw:(dark:)?(text|bg|border|ring|divide)-[a-z0-9-]+!' \
  --include='*.blade.php' . | sort -u
```

**22 distinct colour utilities** carrying `!`, across 9 Blade files. They
include `tw:bg-white!` and `tw:dark:bg-white!` — a forced white background in
dark mode, on the date-range field that sits on every graph page
(`resources/views/graphs/show.blade.php:53`). That is the most visible single
item in this document, and a one-character fix upstream.

For scale, these are the colour surfaces a theme has to reach *at all*, `!` or
not:

| Utility family | Uses in Blade | What it is |
|---|---|---|
| `tw:dark:text-dark-white-{100..400}` | 110 | core's dark-mode text ramp |
| `tw:dark:bg-dark-gray-{100..500}` | 77 | core's dark-mode surface ramp |
| `tw:dark:border-dark-gray-*` | 62 | seams |
| **total** | **249** | |

Those ramps are LibreNMS's *own* semantic palette, which is the good news: all
249 come from nine variables, and `bg-` and `border-` share the same five, so a
skin remaps the lot by redefining nine custom properties. This repo's skins do
exactly that — see section 16 of any skin stylesheet.

```bash
grep -rhoE 'tw:dark:(text-dark-white|bg-dark-gray|border-dark-gray)-[0-9]+'   --include='*.blade.php' . | wc -l
```

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

## 2b. A stylesheet audit cannot see the widget header *(claim corrected)*

**This section originally argued the widget header was unreachable. That was
wrong.** It is reachable, it was always reachable, and this repo's own skins
have been theming it successfully for most of the project's life. Corrected
after a LibreNMS maintainer pointed it out
([thread](https://community.librenms.org/t/a-theme-system-for-librenms-a-phased-proposal/29463)); the honest response is that our own later work had already
disproved it and we did not propagate the correction.

What survives is a real but much narrower observation about **auditing**, not
about theming. Read it as that.

---

The grey bar above every dashboard widget has no *semantic* class. It is
emitted by JavaScript string concatenation inside a Blade file
(`resources/views/overview/default.blade.php:516`):

```js
'<header class="tw:bg-gray-200 tw:dark:bg-dark-gray-200 tw:text-gray-800 ' +
'tw:dark:text-dark-white-100 tw:p-3 tw:text-center">' +
'<span class="dashboard-widget-title">' + data.title + '</span>'
```

`.dashboard-widget-title` — the one named hook — is only the inner `<span>`,
so styling *that* leaves the bar grey. But look at the string above: the header
carries `tw:dark:bg-dark-gray-200`, and that utility reads
`var(--tw-color-dark-gray-200)`. **Two independent handles exist:**

- the element itself, `html.dark .grid-stack-item-content > header`
- redefining `--tw-color-dark-gray-200`, which §2 establishes works and which
  section 16 of every skin in this repo now does

The maintainer's phrasing was *"it doesn't matter at all as the theme is
covered by the parent html css"*, and that is correct. The original
conclusion here — that the bar needed a new class before it could be themed —
does not follow and should never have been drawn.

**How the error survived:** this section was written early, when the skins
styled the bar via the element selector and the utility mechanism had not been
found yet. Section 16 later proved the theme-variable route, which falsifies
this section, and nobody came back to reconcile it. That is the same failure
mode as the retraction in §2 — a finding that was true when written, falsified
by our own later work, left standing because nothing re-checks old claims.

What *is* worth keeping: **an audit based on reading stylesheets cannot find
this element**, because its class list is assembled at runtime from a string in
a template. `scripts/coverage.sh` in this repo reported 100% coverage while the
most prominent element on the landing page was still stock grey — not because
the element was unthemeable, but because the tool had no way to know it existed.

That is an argument about tooling, and it generalises: coverage counts
selectors answered, and cannot count selectors it never sees. It is not an
argument about LibreNMS's theming surface, which is what this section
originally tried to make it.

The fix upstream is trivial and already has precedent: give it a class.
[PR #20294](https://github.com/librenms/librenms/pull/20294) did exactly that
for a different element, adding `.widget-header` so the mono theme could reach
it. The same treatment here would cost one line.

---

## 2c. The stock dark theme has a contrast bug of its own

Not a theming obstacle — a straightforward accessibility defect that any theme
inherits. `tw_dark.css` fills Bootstrap's contextual table rows with saturated
mid-tones:

| Row | Fill |
|---|---|
| `tr.success` | `#62c462` |
| `tr.info` | `#5bc0de` |
| `tr.warning` | `#ba6f05` |
| `tr.danger` | `#ee5f5b` |

and leaves the text colour alone, so dark body text sits on bright fills. On
the **alert rules page**, where most rows carry one of these classes, this is
the worst contrast in the application — and it is that way in the stock dark
theme, with no custom CSS involved.

### A second instance: the select2 placeholder

`tw_dark.css` also ships:

```css
.dark .select2-container--bootstrap .select2-selection--single
  .select2-selection__placeholder { color: #272b30; }
```

`#272b30` is not a text colour. It is `--tw-color-dark-gray-500`, the **darkest
surface** in core's own dark ramp, used here as `color`. The result on
`/eventlog` is a filter whose "All Devices" and "All Types" labels measure
**1.2:1** against the field behind them — effectively invisible, in the stock
dark theme, with no custom CSS involved.

Measured on a live instance:

```js
const el = document.querySelector('.select2-selection__placeholder');
getComputedStyle(el).color            // rgb(39, 43, 48)  == #272b30
```

Both of these are the same underlying mistake — a **surface** value used as an
**ink** value — which is the thing a real token contract would make hard to get
wrong. That is the argument for section "What would actually help", made by
core's own stylesheet rather than by me.

Worth fixing upstream independently of any theming work. A theme can only paper
over it, which is what this repo's skins now do (section 15 of each skin).

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
| **Distinct first-party colors** | **264** |
| Blade templates total | 303 |

A note on scope: **JavaScript is not a problem.** `html/js/` contains 629 hex
literals, but they are essentially all vendored (`esri-leaflet-vector`,
`leaflet`, `overlib_mini`). First-party JS carries almost no color.

264 distinct colors is the headline. That is not a palette; it is an accretion.
Consolidated, it is plausibly 40–60 real tokens.

> **Correction.** An earlier version of this document said 468. That figure
> included `html/js/`, which the paragraph directly above it correctly
> identifies as essentially all vendored — so it counted ~228 colours from
> `esri-leaflet`, `leaflet` and `overlib` that LibreNMS does not own and nobody
> would ever theme. The document contradicted itself. 264 is first-party only:
> the four non-vendor stylesheets plus all PHP and Blade. Caught by writing the
> reproduction commands in `PROPOSAL.md` and running them.

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
override. It has 264 distinct opinions about color, most of them literals, and
overriding any of them is a brawl.

This is a clean natural experiment. Same stylesheet, same load order, same
author, same application, same afternoon. The only variable is whether core
hard-codes the property. Where it stays out of the way, theming is trivial.
Where it scatters literals, theming requires defensive CSS that is nowhere
documented.

The problem is not that theming is hard. The problem is 264 literals.

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
3. **The graphs people actually look at bypass it entirely.** `port_bits` —
   the most-viewed graph in the product — resolves to
   `includes/html/graphs/generic_data.inc.php`, which hardcodes every colour:

```php
$rrd_options[] = 'AREA:in'   . $format . '_max#D7FFC7' . $stacked['transparency'] . ':';
$rrd_options[] = 'AREA:in'   . $format . '#90B040'     . $stacked['transparency'] . ':';
$rrd_options[] = 'LINE:in'   . $format . '#608720:In ';
$rrd_options[] = 'AREA:dout' . $format . '_max#E0E0FF' . $stacked['transparency'] . ':';
$rrd_options[] = 'AREA:dout' . $format . '#8080C0'     . $stacked['transparency'] . ':';
$rrd_options[] = 'LINE:dout' . $format . '#606090:Out';
```

   No config, no palette. That green and lavender is unreachable from
   `graph_colours.*`, from `rrdgraph_def_text_dark`, and from CSS. **Verified
   empirically**: two skins with completely different palettes — one teal/gold,
   one acid-green/magenta — render byte-identical port graphs.

### Which graphs are actually stuck

Graph *chrome* — background, grid, frame, arrows — is configurable via
`rrdgraph_def_text_dark` and themes cleanly on every graph. The *data series*
are a different story, and the split is sharp:

| | Helpers | Hex literals | Graph files delegating to them |
|---|---|---|---|
| Read `graph_colours` config | 10 | 18 | — |
| **Read no config at all** | **5** | **40** | **169** |

The five with no config path whatsoever:

| Helper | Literals | Included by | Notable colours |
|---|---|---|---|
| `generic_simplex.inc.php` | 5 | 120 | `#ffffff`, `#c5c5c5` |
| `generic_duplex.inc.php` | 7 | 28 | `#666666`, `#999999` |
| `generic_data.inc.php` | 18 | 20 | `#90B040`, `#8080C0` |
| `generic_multi_data.inc.php` | 6 | 1 | `#999999`, `#666666` |
| `generic_multi_bits.inc.php` | 4 | 0 | `#999999` |

`#90B040` and `#8080C0` are the green and lavender on every port traffic graph
in the application. `port_bits` resolves to `generic_data.inc.php`, which names
them directly. No config key reaches them.

```bash
# helpers that hard-code but never consult config
for f in includes/html/graphs/generic_*.php; do
  n=$(grep -coE '#[0-9A-Fa-f]{6}' "$f"); c=$(grep -c graph_colours "$f")
  [ "$c" -eq 0 ] && echo "$(basename $f) literals=$n"
done
```

Verified the only way that settles it: two skins with completely different
palettes render **byte-identical** port graphs.

#### It is the graph *type*, not the page

Worth stating explicitly, because the dashboard makes it look like a
dashboard problem. It isn't. Every graph in the application — dashboard
widget, device page, standalone graph page — is the same endpoint:

```
/graph/id=<id>?type=<type>&from=…&to=…&width=…&height=…
```

There is no dashboard-specific rendering path. The widget passes a `type`, and
the server renders it exactly as it would anywhere else. What differs is which
helper that `type` resolves to.

Sampling the actual PNG pixels on a live instance with the Protoss skin
active, whose `graph.conf` sets `greens` to a teal ramp and `purples` to a
blue one:

| Graph | Dominant colours in the rendered PNG |
|---|---|
| `type=port_bits` (dashboard widget) | `#0f1a2e` 83614px · **`#90b040`** 18827px · **`#8080c0`** 2912px |
| `type=device_bits` ("Overall Traffic", device page) | **`#3fb8f5`** 95101px · **`#218c6e`** 77361px · `#0f1a2e` 76560px · **`#2cb08a`** · **`#3ad6a8`** |

Read that carefully, because it separates two things that look like one:

- **`#0f1a2e` is dominant in *both*.** That is the skin's hull colour, arriving
  via `rrdgraph_def_text_dark`. Graph **chrome is themed on port graphs too** —
  the config does reach the graph.
- `#3fb8f5`, `#3ad6a8`, `#2cb08a`, `#218c6e` are `graph_colours.purples[2]` and
  `graph_colours.greens[2..4]` verbatim. `device_bits` resolves to
  `generic_multi_bits_separated.inc.php`, which reads the config.
- `#90b040` and `#8080c0` are the literals at `generic_data.inc.php` lines 150
  and 158, unchanged. `port_bits` resolves there, and that file contains zero
  references to `graph_colours`.

A dashboard built mostly from port widgets therefore looks entirely unthemed
while the device pages look fine — same config, same endpoint, different
helper.

```js
// paste on any page with graphs; reports the PNG's own colour histogram
const hist = async (src) => {
  const img = new Image(); img.crossOrigin = 'anonymous';
  await new Promise(r => { img.onload = r; img.src = src; });
  const c = document.createElement('canvas');
  c.width = img.naturalWidth; c.height = img.naturalHeight;
  c.getContext('2d').drawImage(img, 0, 0);
  const d = c.getContext('2d').getImageData(0, 0, c.width, c.height).data, n = {};
  for (let i = 0; i < d.length; i += 4)
    { const h = ((1<<24)+(d[i]<<16)+(d[i+1]<<8)+d[i+2]).toString(16).slice(1); n[h] = (n[h]||0)+1; }
  return Object.entries(n).sort((a,b) => b[1]-a[1]).slice(0, 6);
};
await hist(document.querySelector('img[src*="/graph/"]').src);
```

#### Is there an architectural roadblock?

No. `generic_data.inc.php` sits in the same directory as
`generic_multi_bits_separated.inc.php`, which already does the right thing:

```php
$colour_in  = \App\Facades\LibrenmsConfig::get("graph_colours.$colours_in.$iter");
$colour_out = \App\Facades\LibrenmsConfig::get("graph_colours.$colours_out.$iter");
```

The in/out series a port graph actually shows are six literals on six lines
(149–151 and 157–159). The remaining twelve in that file are percentile rules,
port-speed lines and prediction overlays, which are arguably *meant* to be
fixed and can stay. Nothing about the file's structure resists this — it builds
an `$rrd_options[]` array of strings exactly like its siblings do.

So the honest answer is that this is not blocked by anything. It is simply a
helper that predates the config mechanism and never got converted, and it
happens to be the one behind the most-used graph in the product.


### Correction: it is 58 literals, not 149 files

An earlier version of this document said 149 graph files hard-code hex, which
made the cleanup look far larger than it is. That count is real but misleading:
those files mostly *delegate* to a small set of shared `generic_*` helpers, and
the literals live in the helpers.

| Helper | Literals | References (as the command counts them) |
|---|---|---|
| `generic_stats.inc.php` | 1 | **527** |
| `generic_multi_line.inc.php` | 1 | **422** |
| `generic_simplex.inc.php` | 5 | 120 |
| `generic_v3_multiline.inc.php` | 1 | 59 |
| `generic_multi_line_exact_numbers.inc.php` | 1 | 56 |
| `generic_multi_simplex_seperated.inc.php` | 2 | 46 |
| `generic_duplex.inc.php` | 7 | 28 |
| `generic_v3_multiline_float.inc.php` | 1 | 23 |
| **`generic_data.inc.php`** | **18** | **20** (incl. `port_bits`) |
| `generic_multi_bits_separated.inc.php` | 1 | 9 |
| …5 more | 20 | 12 |
| **Total** | **58 across 15 files** | **1,322** |

**Tokenising 58 literals in 15 files would make essentially every graph in
LibreNMS theme-aware.** That is an afternoon's mechanical work, not a migration
of 149 files — and `generic_data.inc.php` alone, at 18 literals, covers the port
traffic graph that dominates every dashboard.

This is the highest leverage-to-effort item in this entire document.

The `graph_colours.*` palette system already exists and 89 graph files use it,
so the abstraction is proven — it simply was never applied to the shared
helpers.

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

### Verified on a live instance, not inferred

The bullet above was originally read out of one Blade conditional and one JS
function. It is correct, but the mechanism is worth stating precisely, because
"there is no dark slot" and "the setting has only one dimension" are different
claims and only the second is true.

Tested with `webui.custom_css` cleared, so no skin could mask the behaviour:

| Action | `.dark` on `<html>` | scheme file | `site_style` |
|---|---|---|---|
| baseline (`default`) | yes | none | `dark` |
| select **Blue** | **removed** | `blue.css` loads | `blue` |
| click **Dark Mode** button | restored | `blue.css` **unloads** | `dark` |
| select **Mono** | **removed** | `mono.css` loads | `mono` |
| click **Dark Mode** button | restored | `mono.css` **unloads** | `dark` |

Two things follow, and the second is the one that matters:

1. `light` and `dark` load no stylesheet at all — they are the `.dark` class
   plus `tw_dark.css`. `blue` and `mono` are **light-base** schemes.
2. **The Preferences dropdown and the Light / Dark / Device buttons are the
   same setting, not two axes.** Clicking *Dark Mode* while Blue was selected
   changed the dropdown itself to `dark`. So `light | dark | device | blue |
   mono` are mutually exclusive values of one enum, and *"dark base plus an
   accent"* is not expressible — not because a slot is missing, but because
   there is only one dimension to express it in.

Adding a built-in scheme is otherwise cheap: the layout loads
`css/<name>.css` for any value that is not `light` or `dark`, so it costs one
stylesheet and one key in the `site_style` options map. No Blade or controller
change.

> **Methodology note, recorded because it nearly became a false bug report.**
> An earlier run appeared to show `mono.css` still loaded *with* `.dark`
> active — which would have been a real defect. It was an artefact: that run
> set the dropdown with `select.value = 'mono'` plus a synthetic `change`
> event, which bypasses the handler that removes the stylesheet link. Driven
> through the actual form control, it unloads correctly every time. Anything
> in this table that was produced by scripting a control rather than operating
> it should be assumed wrong until repeated the slow way.

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

1. **Drop the `!` from the 22 inline colour utilities** (§2). 9 files, no
   visual change, and it is the difference between "a theme author works
   harder" and "a theme author cannot do it". Nothing else in this list
   unlocks as much for as little.
2. **Give the dashboard widget header a class** and fix the contextual-row
   contrast (§2b, §2c). Both are small, neither needs the token work, and the
   second is an accessibility fix that stands on its own.
3. **Tokenise the 58 hex literals in the 15 shared `generic_*` graph helpers**
   (§5). This is the best effort-to-impact ratio available: 15 files, one
   afternoon, and 1,322 graph references become theme-aware. Start with
   `generic_data.inc.php` — 18 literals, and it renders the port traffic graph
   on every dashboard. The same pass should retire the inline
   `session('applied_site_style') == 'dark' ? '#x' : '#y'` ternaries so graphs
   have one colour source rather than three.
4. **Replace the arbitrary-value literals** (`tw:bg-[#337ab7]` etc.) in
   `app.css` component classes with `@theme` tokens. Small, contained, high
   symbolic value.
5. **Drop the remaining `!` modifiers** from `@apply` in component classes, once nothing
   depends on them. This alone would let skins stop using `!important`.
6. **Triage `tw_dark.css`'s 272 literals, then fold the survivors into the
   `@theme` block**, area by area. Per a maintainer, this file is not "the dark
   theme" but legacy Bootstrap overrides kept so the old markup works with the
   Tailwind theme toggle — and it is bloated because a previous convention had
   themes copy the entire Bootstrap stylesheet and recolour it. So an unknown
   share of those 272 literals should be **deleted rather than tokenised**.
   This repo found the same thing from the other end: ~31 colour-bearing
   classes with zero references in `resources/views`, mostly Observium-era.
   each PR pixel-identical.
7. **Normalise `tw_dark.css` to a consistent selector depth.** Today it mixes
   `.dark .x` and `.dark .y .x`, which is what makes overriding it require
   reading it first. Even without tokens, a predictable depth would make
   third-party theming tractable.
8. **Then**, and only then, palette changes and a real theme system become
   cheap.

Steps 3–6 are unglamorous and involve no visible change. That is the point —
and it is exactly the order the maintainer asked for.

---

## Reproducing

`harness/` contains a static page that loads LibreNMS's real stylesheets in the
real order against representative DOM. The specificity experiments above were
run against it in a browser. See the repo README for setup.
