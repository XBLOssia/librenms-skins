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
| Terran | 92 / 92 components (100%) |
| Protoss | 92 / 92 (100%) |
| Zerg | 92 / 92 (100%) |

The denominator is every component `tw_dark.css` gives dark-mode treatment to.
That file is the closest thing LibreNMS has to a manifest of "things that need
theming" — if upstream bothered to style it, a skin that ignores it will show
stock dark-theme colours sitting in the middle of the skin.

All three sit at the same number because they share structure. Fix a gap in one
and the same gap exists in the other two; the work is parallel by construction.

Reaching 100% does **not** mean pixel-perfect. It means every component
`tw_dark.css` styles is now answered by each skin. Components upstream never
themed (query-builder, datetimepicker, bootstrap-switch) are still stock, and
only walking real pages will find those.

---

## Priority 1 — install on a real instance

Deployment tooling is ready — `scripts/install.sh` and
[DEPLOYMENT.md](DEPLOYMENT.md). What remains is walking the real UI, which is
worth more than any amount of further CSS: the harness DOM is synthetic and
hand-written, so it cannot surface what it does not contain.

Pages worth walking with each skin active:

- Global dashboard with real widgets (`grid-stack` / `gs-w` are unstyled)
- Device list and a device's overview page
- Alert rules and the rule builder (query-builder is unstyled)
- Ports, health/sensors, syslog
- The world map (Leaflet has its own dark filter in `app.css`)
- Any page with a select2 dropdown — unstyled, and select2 is used widely
- Settings, and the mobile/narrow layout (`navbar-toggle` is unstyled)

Expect the graph pages to look wrong in a way no skin can fix — RRDtool renders
PNGs server-side. That is documented in FINDINGS §5, not a bug to chase.

---

## Completed (2026-09-18)

Priorities 2–5 are done. Coverage went 43% → 100% in one pass, generated from a
single template so the three skins could not drift. Closed: contextual panels,
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

## Harness gaps

`harness/index.html` renders roughly what the skins already cover, which makes
it a poor regression net. Worth adding, in rough order of value:

1. Contextual panel and text variants (Priority 2 above)
2. Pagination, list groups, popovers, `.close`
3. A narrow-viewport view so `navbar-toggle` is visible
4. A real select2 and a datetimepicker
5. Form validation states

A `?compare` mode rendering all three skins side by side in iframes would make
drift between them obvious at a glance.

---

## Open decisions

**Screenshots in the README.** There are none, and this is a visual project.
Three captures from a real instance would be worth more than any amount of
description — and should be taken *after* Priority 1, so they show real pages
rather than harness mockups.

**Upstream.** Drafted — see [PROPOSAL.md](PROPOSAL.md). Three small,
independent changes (widget header class; tokenise 58 literals in 15 shared
graph helpers; fix contextual row contrast), two of them provably
pixel-identical. Venue is the community forum's Projects category, since GitHub
Discussions is disabled on the repo. Open question left for you: whether to
disclose AI tooling up front — PROPOSAL.md argues for yes and explains why.
Coordinate on Discord before opening anything.

---

## Not planned

- **Per-user skin selection.** Needs a patch to
  `resources/definitions/config_definitions.json`, which updates overwrite.
  FINDINGS §6 has the detail.
- **Theming graph interiors.** Structurally impossible from CSS.
- **Supporting LibreNMS older than current master.** Selectors are verified
  against `63e0394` only.
