# Roadmap

Where the project actually stands, and what to pick up next.

Last updated 2026-09-18, against LibreNMS master @ `63e0394`.

---

## Honest status

Three skins are complete, verified and installable. But "complete" means the
application frame — navbar, panels, tables, buttons, forms, alerts, labels,
tabs, modals. It does not mean every component.

Run `./scripts/coverage.sh /opt/librenms` for the current number. As of today:

| Skin | Coverage |
|---|---|
| Terran | 183 / 218 (83%) |
| Protoss | 183 / 218 (83%) |
| Zerg | 183 / 218 (83%) |

That number went *down* from a previously reported 85%, twice, because the
measurement was wrong both times — see below. Group A is 92/92; the remainder
is group B legacy.

There are **two** denominators, and using only the first hid a real gap for
several rounds:

- **A — `tw_dark.css` (92):** components upstream gives dark-mode treatment.
  All three skins cover 92/92.
- **B — `styles.css` (123):** colour-bearing classes `tw_dark.css` *never*
  overrides, so they render identically in light and dark. Skins cover 92/123.

Measuring against A alone reported **100%** while the navbar search dropdown was
`#fff`, device-overview rows were `#f9f9f9`, and the availability map boxes were
stock Bootstrap. `scripts/coverage.sh` now reports both.

The ~31 still uncovered in B are overwhelmingly dead Observium-era classes
(`.datacell`, `.body-1`, `.shadetabs`, `.dropdown_3columns`) with zero
references in `resources/views`. Deliberately not chased; run
`coverage.sh <path> <skin> -v` to see them.

All three sit at the same number because they share structure. Fix a gap in one
and the same gap exists in the other two; the work is parallel by construction.

Coverage counts *selectors answered*, which is not the same as *correct*. It
cannot see contrast failures, elements whose colour comes from a JavaScript
string, vendored stylesheets like `MarkerCluster.Default.css`, or a rule of the
skin's own that breaks something else. Every one of those happened, and every
one was caught by **[harness/audit.js](../harness/audit.js)** run against a
live page — not by this number.

Treat coverage as a floor, and the live audit as the actual test.

---

## Done — deployed and walked

Zerg, Protoss and Terran have all run on a live instance (`REDACTED-HOST`,
LibreNMS `26.8.1-147-g63e0394bd1` — the exact commit the skins were built
against). Deployment tooling is in `scripts/install.sh` and
[DEPLOYMENT.md](DEPLOYMENT.md).

Walking real pages is what produced everything in the Completed section below,
and it found things the harness structurally could not:

- **Dashboard widget title bars** had no class at all — the colour lives in a
  JavaScript template string, so no stylesheet-based audit could see it.
- **Scrollbars**, which upstream never styles, so every scrollable widget
  showed bright browser chrome.
- **Alert-rule row contrast**, which turned out to be an upstream bug rather
  than a gap in the skins.
- **Port graphs**, which no skin can theme at all — see Not planned below.

Still worth a look when convenient: the rule builder (`query-builder` is
unstyled upstream), a datetimepicker, and the narrow/mobile layout.

---

## Completed — the coverage pass

The original priorities 2–5 are done, generated from a single template so the
three skins could not drift. Closed: contextual panels,
`.text-*` / `.bg-*`, headings, `.label-primary`, `.btn-info`, list groups,
pagination, `.close`, popovers, `.navbar-toggle`, bordered/responsive tables,
form validation states, LibreNMS-specific classes, legacy `.blue/.grey/.red`,
select2 and overlib.

Two additions not on the original list, both found by looking at a real
instance rather than the harness:

- **Scrollbars.** LibreNMS styles none, so every scrollable widget rendered a
  bright browser-default trough against a dark UI. The single most conspicuous
  stock element on a dashboard, and free to fix — upstream never touches it.
- **Map tiles.** `html.dark .leaflet-tile` is the same specificity the skins
  use, so source order lets custom_css retune the filter per skin.

Still stock because `tw_dark.css` never styled them, so they are outside the
coverage denominator: `query-builder` (alert rules), `bootstrap-datetimepicker`,
`bootstrap-switch`.

---

## Verifying a skin

Two tools, and the order matters.

**1. `harness/audit.js` — run this first.** Paste into devtools on a logged-in
page with the skin active. Reports light surfaces that shouldn't exist and any
text below WCAG AA. This is what actually finds problems: the widget header
built in a JS string, the vendored Leaflet cluster markers, 77 icon buttons
whose font-family the skin had clobbered, and five contrast failures the skins
themselves introduced. None were visible to a stylesheet-based check.

Run it on at least `/`, `/devices` and `/alert-rules`. All three currently
return zero findings on all three skins.

**2. `scripts/coverage.sh` — run this second**, as a floor. It answers "did I
forget a component", not "does it look right".

### Harness gaps

`harness/index.html` renders roughly what the skins already cover, so it is a
weak regression net on its own. Worth adding:

1. The components from the coverage pass — contextual panels, `.text-*`,
   pagination, list groups, popovers, `.close`
2. A narrow-viewport view so `navbar-toggle` is exercised
3. A real select2 and a datetimepicker
4. Form validation states
5. Dashboard widget markup (`grid-stack-item-content > header`), and an
   icon-on-a-button (`<button class="btn fa fa-x">`) — the two shapes that
   caused the most rework

A `?compare` mode rendering all three skins side by side would make drift
obvious at a glance.

---

## Open decisions

**Screenshots in the README.** There are none, and this is a visual project.
Three captures from a real instance would be worth more than any amount of
description — and should be taken *after* Priority 1, so they show real pages
rather than harness mockups.

**Upstream.** *Status: a deliberately non-specific message has gone out on
Discord; the full plan has not been posted anywhere yet.* Nothing below is
public, so it can still change freely.

Drafted — see [PROPOSAL.md](PROPOSAL.md). Scoped to a phased
**theme system**: admin installs a theme from a validated JSON manifest, users
select it, custom themes are deletable and built-ins protected. Five phases,
each independently shippable:

- **0** — four small fixes (drop the `!` from 22 inline colour utilities,
  widget header class, tokenise the 58 graph-helper literals, contextual row
  contrast). No theme system required.
- **1** — define the token contract from the 603 literals in `styles.css` +
  `tw_dark.css`. Pixel-identical. This list *is* the theming API.
- **2** — one palette source for both CSS and graphs.
- **3** — themes as data: a `themes` table shaped like `custom_map`, built-ins
  seeded from `resources/definitions/`, `lnms theme:import`.
- **4** — upload/delete UI, policy-gated.

Security model is the load-bearing part: a theme is a validated token manifest,
never arbitrary CSS, because arbitrary CSS enables exfiltration via
`url()`, clickjacking, and remote beacons.

Venue is the forum's Projects category (GitHub Discussions is disabled on the
repo). AI tooling is disclosed up front in the post.

Still to decide before posting:

- Whether to make this repo public. The post is self-contained and deliberately
  doesn't link it, but "here are three working themes" is decent evidence that
  the problem is real.
- Whether to generate the before/after screenshots first. The post offers them
  rather than claiming they exist.
- Don't write a line of Phase 1 until the token contract question gets an
  answer — that list becomes the theming API and is the expensive thing to get
  wrong.

---

## Not planned *here*

These are deliberately out of scope for this repo. Two of them are out of scope
because they belong upstream, not because they're unwanted — see
[PROPOSAL.md](PROPOSAL.md).

- **Per-user theme selection, as a local hack.** It would need a patch to
  `resources/definitions/config_definitions.json`, which updates overwrite, so
  doing it downstream means re-patching forever (FINDINGS §6). Upstream this is
  the *goal*, not a non-goal: Phase 3 makes `site_style` options dynamic and
  Phase 4 adds the UI.

- **Theming graph interiors beyond what config allows.** Worth stating
  precisely, because an earlier version of this file got it wrong:

  | Surface | Themeable? |
  |---|---|
  | Graph chrome — background, grid, frame, arrows | **Yes**, via `rrdgraph_def_text_dark`. Done. |
  | Series colours on palette-driven graphs | **Yes**, via `graph_colours.*`. Done. |
  | Series colours on `generic_*` helper graphs, incl. `port_bits` | **No.** 58 hardcoded literals, no config path. |

  CSS can't reach any of it — RRDtool renders server-side — but "unthemeable"
  was too strong. The last row is what Phase 0b of the proposal targets, and
  it's why port graphs still render stock green/lavender under every skin.

- **Supporting LibreNMS older than current master.** Selectors are verified
  against `63e0394` only.

- **Arbitrary-CSS theme upload.** Not planned anywhere, including upstream. A
  theme should be a validated token manifest; arbitrary CSS enables
  exfiltration via `url()`, clickjacking and remote beacons. PROPOSAL.md has
  the reasoning.
