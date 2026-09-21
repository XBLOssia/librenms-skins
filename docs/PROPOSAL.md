# Upstream proposal

Draft for the LibreNMS community forum. Post from `### A theme system for
LibreNMS` down — everything above that is internal.

**Venue:** [community.librenms.org → Projects](https://community.librenms.org/c/projects)
— GitHub Discussions is disabled on the repo (404), and Feature Requests has
1,198 topics with little maintainer traffic. Projects has 73 and is described as
"a space for discussing ongoing development work and initiatives", which is
exactly what this is.

**Before posting:** say hello on Discord first. murrant gave direct guidance on
[#19029](https://github.com/librenms/librenms/pull/19029) about sequencing, and
this is built on it. The PR template also warns that PRs may be closed without
explanation over LLM-generated submissions, so a human conversation first is
worth a lot.

---

## Suggested Discord opener

> Hi — I've been building third-party themes for LibreNMS and ended up mapping
> how colour is handled across the codebase. I'd like to propose working toward
> a proper theme system, in phases, starting with the legacy-colour cleanup
> murrant asked for on #19029. The early phases are pixel-identical refactors
> that are worth doing on their own merits even if the theme system never
> lands. Mind if I write it up in Projects?
>
> Being upfront: I'm using AI tooling for this — the measurement, the writing,
> and the code if it goes ahead. Every number comes with a command so you can
> check it rather than trust me, and I'll own and stand behind whatever PRs
> come out of it.

---

## Forum post

### A theme system for LibreNMS — a phased proposal

I want to be clear about the destination before asking for anything: **I'd like
LibreNMS to have a real theme system** — one where an admin can install a theme
from a file, users can pick it, and custom themes can be removed while the
built-ins stay protected.

I'm not asking anyone to approve that today. I'm asking whether the direction is
welcome, because the first phases are things murrant has already asked for, and
they're worth doing whether or not the rest ever happens.

The reason I think this is smaller than it sounds: **most of the work is the
cleanup, not the feature.** Once colour lives in tokens, a theme is just a set
of token values, and storing, validating and selecting them is ordinary CRUD
that LibreNMS already does elsewhere.

---

### Up front: how this was produced

I used AI tooling (Claude) to explore the codebase, take the measurements, and
draft this post. I'm saying so before anything else, because the PR template
warns about low-quality LLM-generated submissions and that warning is fair — a
large mechanical refactor looks exactly like the thing it defends against.

What I can actually commit to:

- **Every number is reproducible.** The commands are below. Please don't take
  my word for any of them — a figure you can check yourself is worth more than
  an assurance from me.
- **Small, single-concern PRs.** Review effort stays bounded, and anything
  claimed as pixel-identical comes with before/after evidence.
- **I'm accountable for what I submit.** I read the diff before it goes up, I
  answer review comments, and I don't open a PR and disappear.
- **The assistance is ongoing, not just the drafting.** I'll be using AI tooling
  to write these changes and to work through review feedback too. I'd rather
  say that now than have it inferred later. If that's a dealbreaker for this
  project, tell me and I'll stop here — no hard feelings, and the measurements
  are yours to use either way.

For what it's worth, writing the reproduction commands caught an error in my own
figures: I'd been quoting "468 distinct colours", which turned out to include
`html/js/` — essentially all vendored (`leaflet`, `esri-leaflet`, `overlib`).
Excluding code LibreNMS doesn't own, the real first-party figure is 264. That's
the method working, and it's why I'd rather hand you commands than ask you to
trust a number.

---

### Reproduce every number

From a checkout at `63e0394`. All of these run in under a second.

```bash
# 264 distinct first-party colours (4 non-vendor stylesheets + all PHP/Blade)
{ grep -ohE '#[0-9a-fA-F]{6}\b' html/css/{styles,tw_dark,mono,blue}.css
  grep -rohE '#[0-9a-fA-F]{6}\b' --include='*.php' includes app resources LibreNMS
} | tr 'A-F' 'a-f' | awk '!seen[$0]++' | wc -l

# 0 font-family rules in the dark theme, against 272 hex literals
grep -c 'font-family' html/css/tw_dark.css
grep -ohE '#[0-9a-fA-F]{3,8}' html/css/tw_dark.css | wc -l

# 595 inline tw: colour utilities in Blade templates
grep -rohE 'tw:(dark:)?(bg|text|border|ring|divide)-[a-z]+-[0-9]{2,3}' \
     --include='*.blade.php' . | wc -l

# 58 colour literals in the shared graph helpers
grep -cE '#[0-9A-Fa-f]{6}' includes/html/graphs/generic_*.inc.php

# ...and how many graph definitions reference each helper
grep -rhoE 'generic_[a-z_]+[.]inc[.]php' includes/html/graphs/ \
  | awk '{c[$0]++} END {for (k in c) print c[k], k}'

# 89 graph files already using the graph_colours.* palettes
grep -rl 'graph_colours' includes/html/graphs/ | wc -l
```

---

### Where colour lives today

Five places, none of which know about each other. This is the actual problem —
not any individual value.

1. **`styles.css`** — 331 hex literals.
2. **`tw_dark.css`** — 272 hex literals, the whole dark theme.
3. **Inline `tw:` utilities in Blade templates** — 595 uses.
4. **JavaScript template strings.** The dashboard widget title bar is built by
   string concatenation with utilities inline and no class at all
   (`resources/views/overview/default.blade.php:516`), so its colour isn't in a
   stylesheet.
5. **Graph rendering.** `rrdgraph_def_text_dark` for chrome, `graph_colours.*`
   for series, and 58 hardcoded literals in the shared `generic_*` helpers.
   Ten of those fifteen helpers do read `graph_colours`; **five read no config
   at all** — 40 literals, 169 graph definitions, including every port traffic
   graph in the application.

**264 distinct first-party colours.** That isn't a palette; it's accretion.
Consolidated, it's plausibly 40–60 real tokens.

For contrast: `tw_dark.css` contains **zero** `font-family` declarations. I gave
my themes a full typographic treatment and not one rule needed a workaround —
plain selectors, first try. Same stylesheet, same load order, same afternoon.
The only variable is whether core hard-codes the property.

---

### The phases

Each is independently shippable and useful on its own. Phases 0–2 are the
cleanup murrant asked for. Phases 3–4 are the theme system, and they're
comparatively small *because* of 0–2.

#### Phase 0 — four small fixes, no theme system required

**0a. Drop the `!` from inline colour utilities.** 9 files, no visual change.

A `tw:…!` utility written inline in a template compiles to `!important` inside
Tailwind's `utilities` cascade layer. `webui.custom_css[]` is injected last and
is unlayered — and for `!important` declarations the cascade reverses, so
earlier layers win and unlayered `!important` is the weakest of all. A
stylesheet cannot retroactively place itself in an earlier layer, because layer
order follows first declaration and `app.css` already declared them.

So a theme **cannot override these with `!important` of its own, at any
specificity.** Measured on `tw:dark:text-red-500!` — the red device links on
`/eventlog`, at 3.3:1, below WCAG AA.

It *can* override them two other ways, and I want to be straight about this
because an earlier draft of my notes claimed it couldn't:

- **Redefine the theme variable** the declaration reads —
  `--tw-color-red-500`. The `var()` resolves at use time against the inherited
  custom property, and that lookup doesn't care about layers or importance.
- **Re-open `@layer utilities`** from `custom_css` and use `!important` there.
  Same layer, same importance, later source — it wins, even at specificity
  (0,1,0).

I originally tested `--color-red-500`, without the `tw` prefix LibreNMS
configures. Nothing is defined under that name, so nothing happened, and I read
the null result as a property of the cascade rather than as my own typo. Worth
saying plainly rather than having someone find it later.

That makes this a weaker argument than I first thought, but not an empty one:

- Both workarounds are couplings to **Tailwind internals**, not to anything
  LibreNMS promises. Change the prefix or the layer name and every theme
  silently reverts to stock, with no error anywhere.
- The variable route is **all or nothing**. Retinting `red-500` changes it
  everywhere; there is no way to fix one usage. `!important` on an inline
  utility is precisely a declaration that no one downstream may disagree with.

So it isn't *impossible → possible*. It's *requires two undocumented Tailwind
facts → requires nothing*. Deleting a character where nothing depends on it
still looks like the cheaper side of that trade.

```bash
grep -rhoE 'tw:(dark:)?(text|bg|border|ring|divide)-[a-z0-9-]+!' \
     --include='*.blade.php' . | awk '!s[$0]++'
```

**71 uses, 22 distinct, across 9 files.** They include `tw:bg-white!` and
`tw:dark:bg-white!` on the date-range field at
`resources/views/graphs/show.blade.php:53` — a white input in dark mode, on
every graph page in the application.

Where the `!` is load-bearing it should stay; where it isn't, dropping it costs
nothing and is invisible. Where it genuinely is needed, moving the declaration
into a component class in `app.css` also fixes it, because `@apply` output is
unlayered and therefore reachable.

**0b. Give the dashboard widget header a class.** One line, no visual change.
`.dashboard-widget-title` is only the inner `<span>`, so the grey bar itself is
unreachable. Precedent: [#20294](https://github.com/librenms/librenms/pull/20294)
added `.widget-header` to a sibling element for exactly this reason.

**0c. Tokenise the 58 colour literals in the shared graph helpers.** 15 files.
Pixel-identical if defaults keep current values. These helpers are referenced by
1,322 graph definitions, so this is the best effort-to-impact ratio in the whole
proposal.

Five of the fifteen read **no config at all** — `generic_data`,
`generic_duplex`, `generic_simplex`, `generic_multi_data`,
`generic_multi_bits`, together 40 of the 58 literals and 169 of the
references. `generic_data.inc.php` is where `#90B040` and `#8080C0` live: the
green and lavender on every port traffic graph, with no config key that
reaches them.

| Helper | Literals | References |
|---|---|---|
| `generic_stats.inc.php` | **1** | **527** |
| `generic_multi_line.inc.php` | **1** | **422** |
| `generic_simplex.inc.php` | 5 | 120 |
| `generic_duplex.inc.php` | 7 | 28 |
| **`generic_data.inc.php`** | **18** | **20** (incl. `port_bits`) |
| …10 more | 26 | 205 |
| **Total** | **58 across 15 files** | **1,322** |

`generic_data.inc.php` is worth doing first within 0c — it renders `port_bits`,
the traffic graph on effectively every dashboard, and hardcodes:

```php
$rrd_options[] = 'AREA:in'   . $format . '#90B040' . $stacked['transparency'] . ':';
$rrd_options[] = 'LINE:in'   . $format . '#608720:In ';
$rrd_options[] = 'AREA:dout' . $format . '#8080C0' . $stacked['transparency'] . ':';
$rrd_options[] = 'LINE:dout' . $format . '#606090:Out';
```

Demonstration that this is unreachable today: I built two themes with completely
different palettes — one teal/gold, one acid-green/magenta — and they render
**byte-identical** port graphs.

This needs no new machinery. `graph_colours.*` already exists, is already
config-driven, and is already used by 89 graph files. It's applying an in-tree
pattern to the helpers that never got it.

**0d. Fix contextual table row contrast.** Four values, and not a theming ask at
all. `tw_dark.css` fills contextual rows with saturated mid-tones and leaves the
text dark:

| Row | Fill |
|---|---|
| `tr.success` | `#62c462` |
| `tr.info` | `#5bc0de` |
| `tr.warning` | `#ba6f05` |
| `tr.danger` | `#ee5f5b` |

On the alert rules page, where most rows carry one of these, that's dark body
text on bright fills — in the stock dark theme, with no custom CSS involved.

The same file has a second instance, and it's a cleaner illustration of why
Phase 1 matters:

```css
.dark .select2-container--bootstrap .select2-selection--single
  .select2-selection__placeholder { color: #272b30; }
```

`#272b30` is `--tw-color-dark-gray-500` — the **darkest surface** in the dark
ramp, used as a text colour. On `/eventlog` the "All Devices" and "All Types"
filter labels measure **1.2:1**. Both bugs are the same mistake: a surface
value used as ink. A token contract that separates the two makes it hard to
write, which is the argument for Phase 1 made by core's own stylesheet rather
than by me.

Worth fixing regardless of everything else here.

#### Phase 1 — define the token contract

Consolidate the 603 literals in `styles.css` and `tw_dark.css` onto named tokens
in the existing `@theme` block. Pixel-identical, area by area, one PR per area.

This is murrant's "clean up all the legacy colors first", done in a way that
produces something durable: **the resulting token list is the theming API.** A
theme can only control what core reads from a token, so this phase decides what
is themeable forever after. Worth designing deliberately rather than falling out
of a refactor.

While in there, `tw_dark.css` mixes selector depths — `.dark .x` (0,2,0),
`.dark .y .x` (0,3,0), `.dark .a.b .c > d` (0,4,2). There's no single prefix a
theme can use, so overriding anything means reading the stylesheet first to see
what you're fighting. Normalising that is cheap while the file is already open.

#### Phase 2 — one palette source for CSS and graphs

Make `rrdgraph_def_text*` and `graph_colours.*` derive from the same tokens as
the CSS layer, instead of being a parallel universe. After Phase 0b the graph
side is already config-driven; this just points both at one source.

End state: one palette definition drives the page and the graphs.

#### Phase 3 — themes as data

A theme becomes a **validated manifest of token values** — not a CSS file.

- A `themes` table, same shape as `custom_map`.
- Built-ins (`light`, `dark`, `mono`, `blue`) seeded from
  `resources/definitions/themes/*.json`, flagged non-deletable — the same
  pattern as `resources/definitions/alert_rules.json` backing the alert rule
  collection.
- `lnms theme:import <file.json>` / `theme:export` / `theme:delete`.
- `site_style` options become dynamic instead of a fixed enum in
  `config_definitions.json`.
- Rendering is a `<style>` block of custom properties in the layout head. No
  filesystem writes, so nothing to break on `daily.sh` and nothing for the
  webserver user to own.

#### Phase 4 — the UI

Upload and delete in the web UI, gated by a policy. Per-user selection already
works from Phase 3. This is the smallest phase.

---

### Security: a manifest, not a stylesheet

This is the part I'd most like scrutiny on, because "users can upload something
that becomes CSS" deserves suspicion.

**A theme is never arbitrary CSS.** It's a JSON manifest of known keys with
validated values, rendered only as custom properties:

- Whitelisted key set — unknown keys rejected, not ignored.
- Values validated by type: hex colours against a regex, numerics bounded, font
  families from an allow-list.
- Output is only `--token: value` pairs. No selectors, no `url()`, no `content`,
  no arbitrary declarations.

That matters because arbitrary CSS is genuinely dangerous: attribute selectors
plus `background-image: url(...)` can exfiltrate page data, absolute positioning
enables clickjacking, and remote fonts or images beacon on every page load. A
strict token whitelist removes all of it by construction.

Install gated by policy exactly like `CustomMapPolicy::create()`.

**Open question for v1:** web fonts. Allowing arbitrary font URLs reintroduces
the beacon problem, so my instinct is to restrict to families already bundled,
with self-hosted fonts as a later, separately-considered step. Interested in
other views.

---

### Why this fits how LibreNMS already works

I'm not proposing a new pattern — I'm proposing an existing one applied to
colour. **Custom maps** (`app/Http/Controllers/Maps/CustomMapController.php`,
2023) are already a user-created, DB-stored, JSON-configured, policy-gated,
deletable entity, with a `CustomMapSettingsRequest` doing strict validation
including regex closures. A theme is the same shape with a different payload.

And **alert rule templates** already ship built-in definitions as JSON in
`resources/definitions/` that users instantiate from — the same seeding pattern
Phase 3 needs for protected built-ins.

---

### What I'm asking for today

Not approval of the whole thing. Specifically:

1. **Is the direction welcome?** If a theme system is something LibreNMS
   doesn't want, I'd rather know now — Phase 0 is still worth doing and I'd
   happily stop there.
2. **Does the token contract in Phase 1 need a design discussion first?** It's
   the part that's hard to change later, and I'd rather agree the shape than
   present it finished.
3. **May I open Phase 0b?** One line, obviously correct, easy to review — a
   reasonable place to start building trust. I would then like to follow with
   0a, which is the one that actually unblocks third-party theming.

I'm aware [#4863](https://github.com/librenms/librenms/issues/4863) asked for
custom templates in 2016 and was closed, and that #19029 was closed this year. I
think #19029 was closed for the right reason — it changed appearance before the
cleanup existed. This proposal deliberately does the cleanup first and keeps
every early phase visually identical.

---

### What I'm not proposing

- **Arbitrary CSS upload.** Validated token manifests only.
- **A visual redesign.** Phases 0–2 are pixel-identical by construction.
- **Changing the existing themes' appearance.** Built-ins keep their current
  values; they just get expressed as tokens.
- **Retinting the multi-hue graph palettes** (`manycolours`, `rainbow`,
  `psychedelic`, `mixed`, `varied`). Those are multi-hue on purpose — hue is
  what distinguishes series on a busy graph.
- **Replacing `webui.custom_css[]`.** It keeps working for people who want raw
  CSS.

---

### Offer

Happy to do any or all of this, in whatever order suits, or to hand over the
measurements if someone else would rather own it. I can provide before/after
screenshots for anything claimed as pixel-identical.

I've been running one of these themes on a production instance for a while, so
this comes from using it rather than theorising about it.

---

## Notes for us, not for the post

**Fix before posting:**

- The `XBLOssia/librenms-skins` repo is **private**. Don't link it — the post is
  deliberately self-contained now. Either make it public first or leave the link
  out.
- The offer says "I can provide before/after screenshots" rather than claiming
  they exist. Generate them before anyone asks.
- The old draft disclosed the instance size (1,400+ devices). Removed — say it
  if you want, but it's your infrastructure detail.

**Sequencing:**

1. Discord first, using the opener above.
2. Post to Projects once someone's said "sure, write it up".
3. Open **Phase 0a only**. One line, trivially reviewable. A merged trivial PR
   buys standing for 0b, which is the one that actually matters.
4. Hold 0b until 0a merges — it's 15 files and wants a reviewer who already
   trusts you.
5. 0c can go any time; it's an accessibility fix independent of the rest.
6. Don't write a line of Phase 1 until question 2 gets an answer. The token
   contract is the part that's expensive to get wrong.

If 0a is rejected, stop and ask why before writing more code. That answer tells
you whether any of the rest is worth the effort.
