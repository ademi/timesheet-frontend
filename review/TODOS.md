# TODOS

## Roster / horizon

### Expose tenant timezone to Flutter

**What:** Put tenant TZ on the session/me payload (or a tiny GET) and use it for roster `startOfToday+14d` instead of device local / UTC.

**Why:** `ensure_horizon` expands rrules in `_tenant_timezone`. An AU tenant opened from a UTC laptop POSTs a window that does not match the server. Holes near midnight get skipped or land on the wrong civil day.

**Context:** Locked as D15 interim (“device local is acceptable if tenant TZ is not on the client yet”). Start at `SessionService` / tenant settings DTO, then `_horizonFromUtc` in `staff_visits_controller.dart`. Composer already sends explicit `horizon_from`/`horizon_to` (D12) — same TZ source should feed those. Steal 4 date chips will want the same field.

**Effort:** M
**Priority:** P2
**Depends on:** Steal 1–3 (`ensure_horizon` + roster `_fillHorizon`) shipping first.

### Horizon cron / worker

**What:** A scheduled job that calls `ensure_horizon` per tenant (nightly + a few times a day) so holes exist without a manager opening Roster.

**Why:** This slice uses roster-open as the trigger. A tenant with no manager on the board over a long weekend has nothing for contractors to claim until Monday.

**Context:** Plan out-of-scope: “Cron/worker for horizon (roster open by a manager is the trigger).” Reuse `ensure_horizon` + 14-day cap + 200-rule truncation. Do not invent a second fill loop. Needs a tenant loop, a lock so two workers do not stampede, and the same UniqueViolation/engagement isolation as D17.

**Effort:** L
**Priority:** P3
**Depends on:** Steal 1–3 `POST /v1/jobs/horizon` and `fill_rule_window`.

## Trial UX (2026-08)


### T12 — Unify the ongoing support and book one session support forms:
**What:**
    let's use step system for clearer flow
    Start by choosing one or ongoing sessions
    Add the manage template section to the suitable step
    The + button on the roster should route to the same unified form
    Ongoing support:
        - Location to be editable, default to client location.
    Book one session:
        - Should show the client's locations
        - Should show forms templates.
    Start OnGoing Support:
        - Add a link to the Add site for this client when there is no site added.
        - Start and End dates should Time Picker.
    Required Workers should be editable numbers with a minimum of 1 and a plus and minus button.

## Contractor card follow-ups (2026-08-19 eng review)

### T13 — `client_name` on visit list rows

**What:** Add `client_name` to `GET /v1/visits` (`VisitOut`) and show it on contractor-card visit tiles.

**Why:** YAML V2 asks for “visits of the client”. Job titles are often `{Client} support`, but ad-hoc jobs may not name the client. Staff then have to open the visit to see who it is for.

**Context:** `_VISIT_COLUMNS` in `backend/timesheet-backend/app/modules/jobs/service.py` already joins `work.jobs` and could `LEFT JOIN clients.clients`. Flutter `VisitOut` has `jobTitle` / `contractorName` / `locationLabel` only. Notification helpers already fetch `client_name` in a side query. Do not sneak this into the tab-chrome slice.

**Depends on / blocked by:** None. Natural follow-up after contractor Visits tab ships.

**Effort:** M
**Priority:** P3

## NDIS support item (2026-08-21 eng review)

### T14 — Flutter UI for visit / job support item

**What:** Parse `support_item_code` / `support_item_name` on Flutter `JobOut` / `VisitOut`, call `PATCH /v1/jobs/{id}/support-item` and `PATCH /v1/visits/{id}/support-item`, and expose fields on ongoing-support (or job) form plus staff visit detail edit.

**Why:** Backend-only slice ships the audit stamp and API; coordinators and sales demos still need glass to set the NDIS line without raw API calls.

**Context:** Plan `docs/superpowers/plans/2026-08-21-visit-support-item-ndis-line.md` D8 deferred Tasks 6–7. Backend PATCH + catalogue validation (Phase A) **shipped**. Soft format `XX_XXX_XXXX_X_X`. Do not build price-guide catalogue UI or PRODA in this item.

**Depends on / blocked by:** ~~Backend support-item migration + PATCH routes~~ **done**.

**Effort:** M
**Priority:** P2

## NDIS get-paid loop (2026-08-22 plan)

Plan: `docs/superpowers/plans/2026-08-22-ndis-catalogue-get-paid-loop.md` (Phase A/B). Phase C backend: `docs/superpowers/plans/2026-08-23-ndis-export-phase-c-t17-t18-t19-backend.md` (**shipped 2026-08-23**).

### Locked decisions (Phase C — do not re-litigate without explicit reversal)

| ID | Decision |
|----|----------|
| D1 | Ship order was T19 → T17 → T18; all three backend slices landed in one branch. |
| D2 | **Hybrid price tier** at export: `visit.price_tier_override` (staff) **wins** → MMM postcode lookup → `national` default. Unknown postcode in MMM table → national (no hard block). |
| D3 | Blank delivery postcode → 422 `delivery_postcode_required` **unless** staff set `price_tier_override` (override-only path). |
| D4 | **Multi-line trigger:** ≥1 `visit_tasks` row with `support_item_code` → export uses **task lines only**; visit-level `support_item_code` **not required**. |
| D5 | Task quantities: explicit `billable_minutes` per coded task; sum **≤** visit billable minutes (under-assignment allowed). |
| D6 | Void: only `finalized` exports; no PRODA submission guard yet. |
| D7 | No Flutter in Phase C — glass deferred to T15 + T21. |

### Revisioned priorities (2026-08-23)

| Priority | Item | Rationale |
|----------|------|-----------|
| **P2 (now)** | T15 + T21 + T14 | Backend get-paid loop is complete through export void/tier/multi-line; **Flutter is the revenue-story blocker** for coordinators and demos. |
| **P2** | T20 | Demo parity (care-plan tasks + NDIS number) still wins mid-market RFP vocabulary. |
| **P3** | T16 | Catalogue refresh automation — ops can CLI-import until volume justifies cron. |
| **Done** | T17, T18, T19 backend | See shipped section below. |

### T15 — Flutter NDIS catalogue picker + invoice export UI

**What:** Typeahead against `GET /v1/ndis-catalogue/items`, strict name display on job/visit support item fields, and staff UI to create/download invoice exports (`POST /v1/billing/invoice-exports`, CSV download), **void** (`POST …/void`), and surface export errors clearly.

**Why:** Phase A/B/C backends are shipped; coordinators still need glass to pick valid NDIA lines, run tier-aware exports, void mistakes, and download CSV without raw API calls.

**Context:** Builds on T14 (support item fields) and T21 (tier + task minutes). Export API now returns `price_tier`, `visit_task_id` on lines; supports multi-line per coded task. Surface Phase B/C errors (`support_item_not_hourly`, `task_minutes_exceed_visit_hours`, `export_already_void`, etc.).

**Depends on / blocked by:** Phase A + B + C backend shipped; T14 + T21 natural to combine in one billing UX pass.

**Effort:** L
**Priority:** P2

### T16 — Scheduled NDIS catalogue refresh

**What:** Background job (or ops cron) that downloads the current NDIA Support Catalogue XLSX from a configured URL, compares SHA256 to the active release, and imports when changed. Implement `CatalogueUrlSource` in `ndis_catalogue/sources.py`.

**Why:** Phase A relies on manual platform-admin upload or CLI. Pricing updates each July (and occasional addenda); manual-only risks stale price limits at export time.

**Context:** NDIA does **not** publish a stable public API — this is fetch-the-official-XLSX + existing import pipeline, not a live NDIA feed. URL config must be updatable when NDIA moves media links. Idempotent SHA256 already in plan. Alert ops on import failure; do not auto-activate if parse row count drops sharply.

**Depends on / blocked by:** Phase A import service + CLI.

**Effort:** M
**Priority:** P3

### ~~T17 — MMM postcode tier~~ **SHIPPED (backend, 2026-08-23)**

**What:** Import postcode → MMM reference data; at export resolve delivery site postcode to `national` \| `remote` \| `very_remote` and pick matching catalogue price column; staff override via `PATCH /v1/visits/{id}/price-tier`.

**Shipped:**
- `V030__mmm_postcodes.sql` — `reference.mmm_postcodes`, `reference.mmm_isolated_towns`
- `reference/mmm/` + `python -m app.tools.import_mmm_postcodes`
- `billing/pricing.py` — hybrid tier resolution (override → MMM → national)
- Export lines store `price_tier`; tests in `test_invoice_export_mmm.py`

**Locked:** Staff `price_tier_override` beats MMM; unknown postcode → national; isolated towns → `very_remote`.

**Flutter:** T21 (tier override UI).

### ~~T18 — Per-task multi-line NDIS invoice export~~ **SHIPPED (backend, 2026-08-23)**

**What:** When visit tasks carry distinct `support_item_code` values, export one line per coded task with explicit `billable_minutes` quantities (sum ≤ visit clocked hours).

**Shipped:**
- `V031` — `visit_tasks.billable_minutes`, export line `visit_task_id`, relaxed unique constraint
- `PATCH /v1/visits/{id}/tasks/{task_id}/billing`
- Multi-line export when any task has code; visit-level stamp skipped in that mode
- Tests in `test_invoice_export_multiline.py`

**Locked:** No equal-split guessing; under-assigned minutes allowed; coded tasks require minutes at export.

**Flutter:** T21 (task minutes UI) + T15 (multi-line export preview).

### ~~T19 — Void invoice export + revert visit `invoice_status`~~ **SHIPPED (backend, 2026-08-23)**

**What:** `POST /v1/billing/invoice-exports/{id}/void` marks export void and sets linked visits `invoice_status` back to `pending`.

**Shipped:**
- Void route + `invoice_export_voided` audit event
- Re-export after void works; lines preserved for audit
- Tests in `test_invoice_export_void.py`

**Locked:** Only `finalized` → `void`; no PRODA guard yet.

**Flutter:** T15 (void action in export UI).

### T21 — Flutter visit price tier override + task billable minutes

**What:** Staff UI to set `PATCH /v1/visits/{id}/price-tier` (`national` | `remote` | `very_remote`) and `PATCH /v1/visits/{id}/tasks/{task_id}/billing` (`billable_minutes`) before invoice export.

**Why:** Phase C backend (plan `docs/superpowers/plans/2026-08-23-ndis-export-phase-c-t17-t18-t19-backend.md`) adds hybrid tier resolution and multi-line export quantities; coordinators need glass, not raw API calls.

**Context:** Staff override wins over MMM auto tier. Task minutes required when tasks carry `support_item_code`. Show tier source (override / MMM / default) on visit detail. Pairs with T15 export UI and T14 task support item fields.

**Depends on / blocked by:** ~~Phase C backend~~ **done** — ship with T15.

**Effort:** M
**Priority:** P2

## Care plan demo parity (competitor rec #3, 2026-08-21)

### T20 — Shift care-plan tasks + participant NDIS number (demo parity)

**What:** Productise what the stack already supports so sales demos match buyer vocabulary — without building a full care-plan OS.

- **NDIS number:** Surface `client_profile_facts` (`requirement_key = ndis`) prominently on client header / visit detail (and export preview when T15 lands); optional soft prompt when Patient type has no number captured.
- **Tasks per shift:** Add task titles to **ongoing support** and the unified book flow (T12); staff can add/edit visit tasks before check-in; contractor toggle unchanged.
- **Copy:** Label as “Care plan tasks” / “Shift tasks” in UI; optional read-only link to intake `support_goals` or support-plan form — not a new goals/budget domain.

**Why:** Competitor research #3 — mid-market RFPs expect task lists per shift and participant NDIS ID as first-class facts. Ongoing support today creates visits with **empty tasks**; NDIS number is captured but easy to miss in demos.

**Context:** Backend already has `work.visit_tasks`, recurrence `task_template_json`, `PUT /profile/ndis`, and invoice export joins NDIS number. Recurrence rule form and manual visit already accept task titles — wire the same pattern into `OngoingSupportCreateRequest` / `ongoing_support_view.dart`. Explicitly **out of scope:** plan budgets, goal tracking, care-plan versioning, PRODA. Pairs naturally with T4 (client detail tabs) and T12 (unified support forms). Deferred from `docs/superpowers/plans/2026-08-21-visit-support-item-ndis-line.md` out-of-scope list. Competitor research: [rec #3](competitor-research-ndis-management-2026-08-21.md#prioritized-recommendations).

**Depends on / blocked by:** None for backend task insert path; T12 if unified book flow is the only entry point you want to touch once.

**Effort:** M
**Priority:** P2

