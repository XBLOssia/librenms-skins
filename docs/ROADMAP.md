# Roadmap

Where the project actually stands, and what to pick up next.

Last updated 2026-09-17, against LibreNMS master @ `63e0394`.

---

## Honest status

Three skins are complete, verified and installable. But "complete" means the
application frame — navbar, panels, tables, buttons, forms, alerts, labels,
tabs, modals. It does not mean every component.

Run `./scripts/coverage.sh /opt/librenms` for the current number. As of today:

| Skin | Coverage |
|---|---|
| Terran | 40 / 92 components (43%) |
| Protoss | 40 / 92 (43%) |
| Zerg | 40 / 92 (43%) |

The denominator is every component `tw_dark.css` gives dark-mode treatment to.
That file is the closest thing LibreNMS has to a manifest of "things that need
theming" — if upstream bothered to style it, a skin that ignores it will show
stock dark-theme colours sitting in the middle of the skin.

All three sit at the same number because they share structure. Fix a gap in one
and the same gap exists in the other two; the work is parallel by construction.

**This is the single most important thing to understand before continuing.**
The skins look finished in the harness because the harness only renders what
they already cover. They are not finished.

---

## Priority 1 — install on a real instance

Higher value than any amount of further CSS. The harness DOM is synthetic and
hand-written; it cannot surface what it does not contain.

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

## Priority 2 — close the contextual-variant gap

The largest and easiest win. These are Bootstrap's contextual variants, they
appear on nearly every page, and each is a handful of lines following patterns
the skins already establish.

**Panels** — the skins only style `.panel-default`. Everything else falls
through to stock dark:

```
.panel-primary  .panel-success  .panel-info  .panel-warning  .panel-danger
```

**Contextual text and backgrounds:**

```
.text-muted  .text-primary  .text-success  .text-danger  .text-warning  .text-info
.bg-success  .bg-info  .bg-danger  .mark
```

**Stragglers from sets already styled** — each skin styles most of these
families but missed one member:

```
.label-primary   .btn-info   .list-group-item   .list-group-item-danger
```

**Headings:** `.h1` … `.h6`

Do these three at a time, one component across all three skins, so the skins
stay in lockstep.

---

## Priority 3 — navigation and interaction chrome

```
.pagination          every paginated table
.close               modal and alert dismiss buttons
.navbar-toggle       the mobile menu - currently unstyled at narrow widths
.popover             hover detail
.table-bordered      .table-responsive
.with-nav-tabs
```

`.navbar-toggle` is the one to do first. It is invisible on a desktop and
obvious on a phone, which is exactly the kind of gap that ships.

---

## Priority 4 — third-party widgets

More work each, because the markup is generated and needs inspecting in a
browser first.

```
.select2-container  .select2-container--bootstrap    dropdowns, used widely
.grid-stack  .gs-w                                   dashboard widget grid
#overDiv  .overlib  .overlib-contents  .overlib-text  legacy tooltips
```

Also unstyled and not in the coverage list because `tw_dark.css` does not touch
them: `query-builder` (alert rules), `bootstrap-datetimepicker`,
`bootstrap-switch`, `jquery.bootgrid` beyond the header/footer already done.

---

## Priority 5 — LibreNMS-specific classes

```
.device-availability  .service-availability  .page-availability-report-select
.device-overview      .interface-upup        .expandable
.blue  .grey  .red                           legacy colour classes
.has-success  .has-error  .help-block        form validation states
```

The form validation states are worth doing early despite being last here — they
are the difference between a form that reports an error legibly and one that
does not.

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

**Repo licence.** There isn't one. The CSS is original work and the bundled
fonts are OFL (which is satisfied — notices ship alongside them), but with no
top-level licence nobody else can reuse the skins. MIT would be the
conventional pick for something like this. Deliberately left for you to choose
rather than assumed.

**Screenshots in the README.** There are none, and this is a visual project.
Three captures from a real instance would be worth more than any amount of
description — and should be taken *after* Priority 1, so they show real pages
rather than harness mockups.

**Upstream.** `docs/FINDINGS.md` is in a state where it could open a discussion
thread. It is now backed by three independent skins rather than one, which
makes the argument considerably harder to wave off. See the "What would
actually help" section there for the sequenced proposal, and note the PR
template's explicit warning about LLM-generated pull requests — coordinate on
Discord before writing any upstream code.

---

## Not planned

- **Per-user skin selection.** Needs a patch to
  `resources/definitions/config_definitions.json`, which updates overwrite.
  FINDINGS §6 has the detail.
- **Theming graph interiors.** Structurally impossible from CSS.
- **Supporting LibreNMS older than current master.** Selectors are verified
  against `63e0394` only.
