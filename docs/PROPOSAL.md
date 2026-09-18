# Upstream proposal

Draft for posting to the LibreNMS community forum. Everything below is
copy-pasteable.

**Venue:** [community.librenms.org → Projects](https://community.librenms.org/c/projects)
— GitHub Discussions is disabled on the repo (404), and Feature Requests has
1,198 topics and little maintainer traffic. Projects has 73 and is described as
"a space for discussing ongoing development work and initiatives", which is
what this is.

**Before posting:** say hello on Discord first. murrant gave direct guidance on
[#19029](https://github.com/librenms/librenms/pull/19029) about how this work
should be sequenced, and this proposal is built on it — worth a heads-up rather
than arriving cold. The PR template also warns that PRs may be closed without
explanation because of low-quality LLM-generated submissions, so a human
conversation first is worth a lot.

---

## Suggested Discord opener

> Hi — I've been building third-party themes for LibreNMS and ended up
> measuring how colour is handled across the codebase. I think I've found three
> small, independent fixes that would make third-party theming actually
> tractable, and they line up with what murrant asked for on #19029 (clean up
> legacy colours before touching the theme). Two of them are provably
> pixel-identical; one is an accessibility fix that stands on its own. Mind if
> I write it up in Projects before I open anything?
>
> Being upfront: I used AI tooling for the measurement and drafting. Every
> number comes with the command to reproduce it, I've checked them all by
> hand, and I'll own whatever PRs come out of it — happy to be held to that.

---

## Forum post

### Making LibreNMS themeable: three small fixes, measured

I've spent the last while building three third-party themes for LibreNMS and
running one of them on a production instance (1,400+ devices). Rather than open
PRs cold, I want to put the measurements somewhere first, because they changed
my mind about what the actual problem is.

**The short version:** the obstacle to theming LibreNMS isn't that theming is
hard. It's that colour currently lives in five places that don't know about each
other. Three small, independent changes would fix most of it, and none of them
require adopting a design-token system.

This builds directly on murrant's guidance in
[#19029](https://github.com/librenms/librenms/pull/19029):

> Not all colors are convert to tailwind yet. The colors in tailwind exist to
> exactly match the legacy colors scattered through-out the code base. You'll
> need to clean up all the legacy colors first.

That's what this is — cleanup first, no visual change, no theme system.

---

### Up front: how this was produced

I used AI tooling (Claude) to explore the codebase, take the measurements, and
draft this post. I'm saying so before anything else because the PR template
warns about low-quality LLM-generated submissions, and that warning is fair —
a large mechanical refactor looks exactly like the thing it's defending
against.

So here's my commitment on methodology:

- **Every number below is reproducible.** Commands are included. If a figure
  doesn't reproduce on your checkout, it's wrong and I want to know.
- **I've verified each one by hand** and I'll own any PRs that come out of
  this — review them as if I typed every character, because I'm accountable
  for them either way.
- **Nothing here is a bulk-generated patch.** These are three targeted changes
  I can explain line by line.

For what it's worth, writing the reproduction commands caught an error in my
own figures: I'd been quoting "468 distinct colours" repo-wide, which turned
out to include `html/js/` — essentially all vendored (`leaflet`,
`esri-leaflet`, `overlib`). Excluding code LibreNMS doesn't own, the real
first-party figure is 264. That's the methodology working, and it's why I'd
rather hand you the commands than ask you to trust a number.

---

### Reproduce every number

From a LibreNMS checkout at `63e0394`. All of these run in under a second.

```bash
# 264 distinct first-party colours (4 non-vendor stylesheets + all PHP/Blade)
{ grep -ohE '#[0-9a-fA-F]{6}' html/css/{styles,tw_dark,mono,blue}.css
  grep -rohE '#[0-9a-fA-F]{6}' --include='*.php' includes app resources LibreNMS
} | tr 'A-F' 'a-f' | awk '!seen[$0]++' | wc -l

# 0 font-family rules in the dark theme, against 272 hex literals
grep -c 'font-family' html/css/tw_dark.css
grep -ohE '#[0-9a-fA-F]{3,8}' html/css/tw_dark.css | wc -l

# 595 inline tw: colour utilities across Blade templates
grep -rohE 'tw:(dark:)?(bg|text|border|ring|divide)-[a-z]+-[0-9]{2,3}'      --include='*.blade.php' resources | wc -l

# 58 colour literals in the shared graph helpers
grep -cE '#[0-9A-Fa-f]{6}' includes/html/graphs/generic_*.inc.php

# ...and how many graph definitions each helper serves
grep -rhoE 'generic_[a-z_]+\.inc\.php' includes/html/graphs/ \
  | awk '{c[$0]++} END {for (k in c) printf "%5d  %s\n", c[k], k}'

# 89 graph files already using the graph_colours.* palettes
grep -rl 'graph_colours' includes/html/graphs/ | wc -l
```

---

### What I measured

Against master @ `63e0394`.

| | |
|---|---|
| Distinct first-party colours (CSS + PHP + Blade) | **264** |
| Hex literals in `styles.css` / `tw_dark.css` | 331 / 272 |
| `tw:` colour utilities inline in Blade templates | 595 uses, 116 distinct |
| `font-family` declarations in `tw_dark.css` | **0** |

That last row is the interesting one. I gave the themes a full typographic
treatment — two faces, tabular figures, the lot — and **not one rule needed a
workaround**. Plain selectors, first try. Because core has no opinion about
typography, there was nothing to fight.

Same stylesheet, same load order, same afternoon. The only variable is whether
core hard-codes the property.

---

### Proposal 1 — give the dashboard widget header a class

**Size:** one line. **Visual change:** none.

The grey bar above every dashboard widget has no semantic class. It's built by
string concatenation in `resources/views/overview/default.blade.php:516`:

```js
'<header class="tw:bg-gray-200 tw:dark:bg-dark-gray-200 tw:text-gray-800 ' +
'tw:dark:text-dark-white-100 tw:p-3 tw:text-center">' +
'<span class="dashboard-widget-title">' + data.title + '</span>'
```

`.dashboard-widget-title` is only the inner `<span>`, so styling it leaves the
bar grey. A theme's only handle is the bare element.

There's precedent for the fix:
[#20294](https://github.com/librenms/librenms/pull/20294) added `.widget-header`
to a sibling element for exactly this reason, noting mono's headers were
*"silently overridden by hard-coded Tailwind utilities."*

Adding a class here costs nothing and makes the most prominent element on the
landing page reachable.

---

### Proposal 2 — tokenise the 58 colour literals in the shared graph helpers

**Size:** 15 files, 58 literals. **Visual change:** none, if defaults keep
current values. **Impact:** 1,300+ graph types.

This is the highest leverage-to-effort item I found, and I had it badly wrong at
first. I originally counted "149 graph files hard-code hex", which makes the job
look enormous. It isn't — those files mostly *delegate* to a small set of shared
`generic_*` helpers, and the literals live in the helpers:

| Helper | Literals | Graph types served |
|---|---|---|
| `generic_stats.inc.php` | **1** | **527** |
| `generic_multi_line.inc.php` | **1** | **422** |
| `generic_simplex.inc.php` | 5 | 120 |
| `generic_duplex.inc.php` | 7 | 28 |
| **`generic_data.inc.php`** | **18** | **20** (incl. `port_bits`) |
| …10 more | 26 | ~190 |
| **Total** | **58 across 15 files** | **1,300+** |

`generic_data.inc.php` is worth doing first on its own. It renders `port_bits` —
the port traffic graph on effectively every dashboard — and hardcodes:

```php
$rrd_options[] = 'AREA:in'   . $format . '#90B040' . $stacked['transparency'] . ':';
$rrd_options[] = 'LINE:in'   . $format . '#608720:In ';
$rrd_options[] = 'AREA:dout' . $format . '#8080C0' . $stacked['transparency'] . ':';
$rrd_options[] = 'LINE:dout' . $format . '#606090:Out';
```

Demonstration: I built two themes with completely different palettes — one
teal/gold, one acid-green/magenta — and they render **byte-identical** port
graphs. Neither `graph_colours.*`, nor `rrdgraph_def_text_dark`, nor CSS can
reach those colours.

The fix doesn't need new machinery. `graph_colours.*` **already exists**, is
already config-driven, and is already used by 89 graph files. This is applying a
proven in-tree pattern to the helpers that never got it — and if the default
palette values equal today's literals, the change is provably pixel-identical.

---

### Proposal 3 — fix contextual table row contrast

**Size:** four values. **Visual change:** yes, and that's the point. **Not a
theming ask.**

`tw_dark.css` fills Bootstrap contextual rows with saturated mid-tones and
leaves the text dark:

| Row | Fill |
|---|---|
| `tr.success` | `#62c462` |
| `tr.info` | `#5bc0de` |
| `tr.warning` | `#ba6f05` |
| `tr.danger` | `#ee5f5b` |

On the alert rules page, where most rows carry one of these, the result is dark
body text on bright fills. It's the worst contrast in the application and it's
there in the stock dark theme with no custom CSS involved.

This is a plain accessibility fix. It's independent of everything else here and
worth doing regardless of whether theming ever goes anywhere.

---

### One structural observation, not an ask

For anyone who picks up the token work later: a theme currently has to beat
upstream selectors at **three different specificities** — `.dark .x` (0,2,0),
`.dark .y .x` (0,3,0), and `.dark .a.b .c > d` (0,4,2). There's no single prefix
that works, so overriding a component correctly means reading `tw_dark.css`
first to see what you're fighting.

Some colours also can't be overridden at any specificity, because `app.css`
compiles `@apply … tw:text-white!` into `!important` on unlayered rules.

Normalising selector depth would help third-party themes a lot. But it's bigger
than the three items above and I'd rather not bundle it in.

---

### What I'm deliberately not proposing

- **A theme system, theme packaging, or per-user theme selection.** Out of
  scope. `webui.custom_css[]` works fine for third-party themes.
- **A new palette or design-token architecture.** That's #19029's territory and
  it was rejected for good reason — the cleanup hadn't happened yet.
- **Any visual redesign.** Proposals 1 and 2 are intentionally no-ops visually.
- **Retinting the multi-hue palettes** (`manycolours`, `rainbow`,
  `psychedelic`, `mixed`, `varied`). They're multi-hue on purpose — hue is what
  distinguishes series on a busy graph.

---

### Offer

Happy to do any or all of these as separate PRs, in whatever order suits, or to
hand over the measurements if someone else would rather own it. Proposals 1 and
2 come with before/after screenshots showing no visual change; 3 obviously
changes appearance by design.

The full write-up with reproduction steps is at
`docs/FINDINGS.md` in [XBLOssia/librenms-skins](https://github.com/XBLOssia/librenms-skins).

---

## Notes for us, not for the post

Disclosure is now in the post itself, up front, before any of the asks.

Everything above the `## Forum post` heading is internal — venue reasoning and
the Discord opener. Post from `### Making LibreNMS themeable` down.

Sequencing that gives this the best chance:

1. Discord first, using the opener above. A human conversation before a wall of
   text, especially given the LLM warning.
2. Post to Projects once someone has said "sure, write it up".
3. Open **Proposal 1 only** first. One line, obviously correct, trivially
   reviewable. A merged trivial PR buys standing for Proposal 2, which is the
   one that actually matters.
4. Hold Proposal 2 until 1 is merged. It's 15 files, and it wants a reviewer
   who already trusts you.
5. Proposal 3 can go any time — it's an accessibility bug fix and doesn't
   depend on the others.

If Proposal 1 is rejected, stop and ask why before writing more code. That
answer determines whether any of the rest is worth the effort.
