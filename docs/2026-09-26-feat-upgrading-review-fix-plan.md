# Fix plan — `feat/upgrading_project` review findings

**Date:** 2026-09-26  
**Source:** `docs/2026-09-25-frontend-feat-upgrading-vs-ios-review.md`  
**Related backlog:** `docs/2026-09-22-landing-ndis-gap-todos.md` (Tier A: A1, A2, A3, A18, A19)  
**Purpose:** Divide Ademi’s findings into **correctness**, **security/compliance**, and **hygiene / incomplete**, then turn each into scoped BE/FE tasks.

**Repos:**

| Side | Repo | Branch |
|------|------|--------|
| Frontend | `timesheet-frontend` | `feat/upgrading_project` |
| Backend | `timesheet-backend` | `feat/upgrading_project` |

---

## How to use this doc

1. Work **Division 1 (correctness)** before Division 2/3 — wrong burn math and duplicate media docs ship broken product.
2. Within a division, do **P0** tasks before **P1**.
3. Each task is tagged **BE** or **FE**. Do not start FE work that only papers over an unfixed BE gate.
4. Add/flip tests named in each task; manual smoke where noted against `docs/manual-test-tier-a.md`.

---

## Division 1 — Correctness / misbehavior / unlogical behavior

Issues that produce wrong data, wrong gates, wrong billing math, or misleading flows.

### Plan overview

| Priority | ID | Summary | Scope |
|----------|-----|---------|-------|
| P0 | C1 ✅ | Enforce burn (+ ideally credential) on create-published paths | **BE** |
| P0 | C2 ✅ | Fix `time_based` publish-burn qty (participant windows) | **BE** |
| P0 | C3 ✅ | Media sync: resume poll when `documentId` already set | **FE** |
| P1 | C4 ✅ | PACE: validate clients without release-period rows | **BE** |
| P1 | C5 ✅ | Billing tower `isLoading` race | **FE** |
| P1 | C6 ✅ | Staff visit publish: budget-specific override for burn block | **FE** |
| P1 | C7 ✅ | PE create: same-tenant `export_id` validation | **BE** (+ optional **FE** error surface) |

---

### C1 — Burn (and credential) gates on create-published — **BE** · P0 ✅ COMPLETE (2026-09-26)

**Problem:** `assert_publish_burn_allowed` only runs in `publish_shift`. `create_shift` (published) and `create_published_shift_for_job` can mark published with no burn evaluation — staff bypass A3 hard blocks.

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C1.1 | **BE** | In `create_shift` when creating as published (incl. empty `contractor_ids` path), call the same burn evaluation / `assert_publish_burn_allowed` used by `publish_shift`. | Creating published with over-envelope burn returns same block/warn as publish. | ✅ |
| C1.2 | **BE** | Apply the same gate in `create_published_shift_for_job`. | Job→published path cannot skip burn. | ✅ |
| C1.3 | **BE** | (Recommended) Run credential roster gate + `override_reason` on those create-published paths too, matching assign/publish. | Expired assignee cannot sneak in via create-published. | ✅ |
| C1.4 | **BE** | Tests: create-published over budget → 409/`budget_burn_blocked`; override+reason allowed if product allows; no bypass vs `publish_shift`. | New cases in `test_plan_burn_a3.py` (or sibling). | ✅ |

**Shipped notes**
- Shared helper `_apply_publish_burn_gate` / `_with_burn_warnings` used by `publish_shift`, `create_shift` (published branch), and `create_published_shift_for_job`.
- `create_published_shift_for_job` accepts optional `override_reason`.
- `create_manual_visit` now runs credential gate before attach + passes burn override through; `ManualVisitCreate.override_reason` added.
- Tests: `tests/billing/test_plan_burn_a3.py` (create-published block/override, publish parity, `create_published_shift_for_job`, create+ineligible contractor).

**FE:** None for gate logic. Existing burn/override UI should already surface BE errors; verify after C6.

**Manual:** Tier A A3 publish strip — also try “create already published” if UI exposes it.

---

### C2 — `time_based` burn qty — **BE** · P0 ✅ COMPLETE (2026-09-26)

**Problem:** `evaluate_publish_burn` sets `qty` to full shift duration for every non-`percentage` participant. `time_based` must use participant time windows (mirror invoice export math).

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C2.1 | **BE** | In `app/modules/billing/burn.py` (`evaluate_publish_burn`), branch `time_based` qty from participant windows, not whole-shift hours. Reuse export/`group_pricing` window ∩ logic where possible. | Preview qty matches exportable hours for time_based. | ✅ |
| C2.2 | **BE** | Confirm soft warn + hard block thresholds use corrected qty. | Warn/block fire on correct burn, not inflated/deflated. | ✅ |
| C2.3 | **BE** | Tests: group shift `time_based` with partial windows → burn qty = window sum (not shift length); percentage path unchanged. | Regression in burn / plan-burn tests. | ✅ |

**Shipped notes**
- `_publish_burn_qty_hours`: percentage unchanged; `time_based` = `shift_hours × (own_window_hours / total_window_hours)` (mirrors `billing.service._allocated_minutes` whole-visit share).
- Loads windows from `work.shift_participant_allocations`.
- Tests in `tests/billing/test_plan_burn_a3.py` (unit qty helper, evaluate amounts $10+$20 not $30+$30, hard-block allows publish when window share fits envelope).

**FE:** None (numbers come from BE). Spot-check publish strip after fix.

---

### C3 — Media outbox retry must not re-upload — **FE** · P0 ✅ COMPLETE (2026-09-26)

**Problem:** After upload + `documentId` write, failed scan poll marks item failed **with** `documentId`. Next flush always calls `uploadEvidence` → new server document each retry (A18 broken).

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C3.1 | **FE** | In `media_sync_worker.dart` `_pushOne`: if `item.documentId != null`, **skip** `uploadEvidence`; resume `pollScanStatus` on existing id; then ack + delete blob. | Retry after poll fail does not create a second document. | ✅ |
| C3.2 | **FE** | Keep failure marking such that `documentId` is preserved on poll fail/timeout (already true — do not clear it on fail). | Second flush still has id. | ✅ |
| C3.3 | **FE** | Unit/regression test: upload once → poll fail → retry → **poll only** (mock pipeline: `uploadEvidence` called once). | Test named clearly for this path. | ✅ |

**Shipped notes**
- `_pushOne` branches on non-empty `documentId` → `finalizing` + `pollScanStatus` only.
- `markAttempt` already preserves `documentId` via `copyWith`; store test locks that in.
- Tests: `media_sync_worker_test.dart` (`upload once → poll fail → retry poll only`); `media_outbox_store_test.dart` (preserve id).

**BE:** None (idempotent upload would be extra hardening; not required if FE resumes poll).

**Manual:** A18 — upload evidence, kill network during scan poll, restore network, confirm one document on server.

---

### C4 — PACE clients without release-period rows — **BE** · P1 ✅ COMPLETE (2026-09-26)

**Problem:** `_pace_outside_release` falls back to plan start/end only when **no** `plan_release_periods` exist in the batch. If any participant has rows, participants **without** rows are never validated (treated in-plan).

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C4.1 | **BE** | Per-participant: if client has release-period rows → validate against them; if client has **no** rows → fall back to that client’s `plan_start_date` / `plan_end_date` (not “skip”). | Mixed batch: row-less clients still validated. | ✅ |
| C4.2 | **BE** | Tests: batch with one client with periods + one without → both evaluated correctly. | Burn/PACE test coverage. | ✅ |

**Shipped notes**
- `_pace_outside_release` now loops every client: periods if present, else that client’s plan date facts.
- Tests in `tests/billing/test_plan_burn_a3.py`: mixed batch plan-end flag, mixed batch release-period flag, all-without-periods fallback.

**FE:** None unless new error codes need copy in `app_failure` / publish strip.

---

### C5 — Billing `isLoading` race — **FE** · P1 ✅ COMPLETE (2026-09-26)

**Problem:** `invoice_exports_controller` `onInit` fires `loadExports` + `loadUnclaimedAgeing` (and related) concurrently; shared `isLoading` — first finisher clears spinner while others in flight.

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C5.1 | **FE** | Split loading flags **or** use in-flight counter / `Future.wait` for initial load so spinner stays until all critical loads finish (or per-section loaders). | UI never shows “ready” mid-flight for sibling loads. | ✅ |
| C5.2 | **FE** | Controller/widget test: slow ageing + fast exports → loading remains until both done (or sections load independently without global false-ready). | Regression in `invoice_exports_controller_test.dart`. | ✅ |

**Shipped notes**
- `_beginLoading` / `_endLoading` in-flight counter on `loadExports`, `loadUnclaimedAgeing`, `loadExportableVisits`.
- Test: `isLoading stays true until all concurrent loads finish (C5)`.

**BE:** None.

**Manual:** A2/A3 Billing tabs — throttle network; confirm no empty flash then populate.

---

### C6 — Budget override dialog on staff visit publish — **FE** · P1 ✅ COMPLETE (2026-09-26)

**Problem:** On `budget_burn_blocked`, staff publish reuses `promptCredentialGateOverride` (credential copy). Group publish correctly uses `promptBudgetBurnOverride`. Conflates two meanings on `override_reason`.

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C6.1 | **FE** | In `staff_visits_controller.dart`, route `budget_burn_blocked` to budget-specific override prompt (same pattern as group publish). | Staff see budget copy, not credential copy. | ✅ |
| C6.2 | **FE** | Keep credential gate path on `credential_gate_blocked` only. | No cross-wiring. | ✅ |
| C6.3 | **FE** | Test: mock burn block → budget dialog / reason sent; credential block still uses credential dialog. | Controller test. | ✅ |

**Shipped notes**
- `promptBudgetBurnOverride` on `StaffVisitsController` (injectable `promptBurnOverride` for tests).
- `budget_burn_blocked` → budget dialog; `credential_gate_blocked` unchanged.
- Tests: `test/features/visits/staff_publish_budget_burn_test.dart`.

**BE:** Unchanged until Division 2 S1 separates field/permission (FE can still send `override_reason` today).

**Manual:** Publish visit that hits burn hard-block; confirm dialog text.

---

### C7 — PE `export_id` same-tenant on create — **BE** · P1 ✅ COMPLETE (2026-09-26)

**Problem:** `export_id` on payment-enquiry create is not validated as belonging to the same tenant (download still tenant-scoped).

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| C7.1 | **BE** | In `payment_enquiries.py` create path: resolve export by id **and** `tenant_id`; 404/403 if missing or other tenant. | Cross-tenant UUID attach rejected. | ✅ |
| C7.2 | **BE** | API test: foreign `export_id` → reject; same-tenant → OK. | New/extended PE tests. | ✅ |
| C7.3 | **FE** | (Optional) Surface clear error if create fails on bad export link. | User sees actionable message. | ⏭ N/A — FE has no PE create client path yet; BE returns `export_not_found`. |

**Shipped notes**
- `create_payment_enquiry`: when `export_id` set, require row in `billing.invoice_exports` for caller `tenant_id` → else 404 `export_not_found`.
- Tests: `tests/billing/test_payment_enquiries_c7.py` (unknown, cross-tenant, same-tenant, null allowed).

---

## Division 2 — Security / compliance hardening

App often “works,” but overrides, audits, or exports are weaker than Tier A promises (A1/A3).

### Plan overview

| Priority | ID | Summary | Scope |
|----------|-----|---------|-------|
| P1 | S1 ✅ | Separate budget override control (permission + audit + distinct field) | **BE** (+ **FE** wire) |
| P1 | S2 ✅ | Audit publish-time credential overrides | **BE** |
| P1 | S3 ✅ | Neutralize CSV formula injection in screening register | **BE** |

---

### S1 — Budget override: permission, audit, distinct field — **BE** (+ **FE**) · P1 ✅ COMPLETE (2026-09-26)

**Problem:** Budget hard-block override reuses credential `override_reason`, needs only `shifts.manage` (not `billing.manage`), writes **no** domain audit. Finance thresholds bypassable without finance permission or trail.

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| S1.1 | **BE** | Introduce distinct budget override field (e.g. `budget_override_reason`) **or** clearly typed override payload; stop overloading credential reason semantically. | API contract distinguishes credential vs budget. | ✅ |
| S1.2 | **BE** | Require appropriate permission for hard burn override (product: prefer `billing.manage`, or dual-check documented). | `shifts.manage`-only cannot bypass burn hard-block. | ✅ |
| S1.3 | **BE** | `log_domain_event` (or equivalent) on successful budget override at publish/create-published. | Audit row exists with actor, shift, reason. | ✅ |
| S1.4 | **BE** | Tests: permission denied without billing manage; override audited; reason required. | Burn override + audit tests. | ✅ |
| S1.5 | **FE** | Send distinct field / use budget dialog (pairs with C6); parse new error codes if any. | Staff flow still works end-to-end. | ✅ |

**Depends on:** C1 (create-published must hit same override path).

**Notes (2026-09-26):** `budget_override_reason` on ShiftCreate / ShiftPublishRequest / ManualVisitCreate; `billing.manage` required (`budget_override_forbidden` otherwise); `shift.budget_override` domain audit; credential `override_reason` no longer opens burn gate; FE sends `budget_override_reason` and gates dialog on `billing.manage`.

---

### S2 — Audit publish-time credential overrides — **BE** · P1 ✅ COMPLETE (2026-09-26)

**Problem:** Assign logs `shift.assign_override`; `_assert_assignees_roster_gate` on publish calls gate with override but **no** `log_domain_event`.

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| S2.1 | **BE** | On publish (and create-published if gated) successful credential override, emit domain audit analogous to assign. | Audit parity assign ↔ publish. | ✅ |
| S2.2 | **BE** | Tests: publish with override → audit event; publish without need → no override event. | Credential gate / shift tests. | ✅ |

**FE:** None (reason already collected). Confirm reason still required in UI.

**Notes (2026-09-26):** `publish_shift` calls `_assert_assignees_roster_gate(..., audit_overrides=True)` → `shift.publish_override` domain audit per overridden assignee. Create-published re-check leaves `audit_overrides=False` (assign path already logs `shift.assign_override`).

---

### S3 — Screening register CSV formula neutralization — **BE** · P1 ✅ COMPLETE (2026-09-26)

**Problem:** Screening-register CSV writes raw `contractor_name` via `csv.DictWriter`. Names starting with `=`, `+`, `-`, `@` can become Excel formulas.

**Tasks**

| # | Scope | Task | Done when | Status |
|---|--------|------|-----------|--------|
| S3.1 | **BE** | Neutralize formula-leading cells (prefix `'` or tab / standard CSV injection escape) for `contractor_name` and any other free-text columns. | Opening in Excel shows text, does not execute formula. | ✅ |
| S3.2 | **BE** | Unit test: name `=CMD|...` / `+1+1` exported safely. | Credentials export test. | ✅ |

**FE:** None (server builds CSV).

**Notes (2026-09-26):** `neutralize_csv_cell` prefixes `'` when a cell’s first non-whitespace char is `=+-@` / tab / CR; applied to all screening-register CSV columns in `render_screening_register_csv`.

---

## Division 3 — Hygiene / incomplete / below-threshold

Not merge-blockers alone; track so A18/A19 and disk cleanup don’t rot.

### Plan overview

| Priority | ID | Summary | Scope |
|----------|-----|---------|-------|
| P1 | H1 | Delete media blob files on discard / logout clear / dismiss terminal | **FE** |
| Low | H2 | A19: real OS local notifications (or document NoOp as intentional) | **FE** |
| Low | H3 | Schedule→visit stub geofence chrome until hydrate | **FE** |
| Low | H4 | `GateDecisionKind.WARN` dead surface | **BE** |
| Low | H5 | Optional hardening: billing list `status` query validation; more burn-override tests | **BE** |

---

### H1 — Media outbox orphan files — **FE** · P1

**Problem:** Confirmed logout / `clearDestructive` / `dismissTerminal` remove GetStorage metadata but leave files under `media_outbox/` on disk.

**Tasks**

| # | Scope | Task | Done when |
|---|--------|------|-----------|
| H1.1 | **FE** | On confirmed discard / logout clear: call `MediaBlobStore.delete` (or equivalent) for each pending item path before/with metadata clear. | No orphan files after discard. |
| H1.2 | **FE** | `dismissTerminal`: delete blob when dropping terminal metadata. | Same orphan class fixed. |
| H1.3 | **FE** | Test: enqueue file → clearDestructive / dismiss → blob gone. | Media outbox / clearSession tests. |

**Do after or with C3** so retry logic and cleanup don’t fight.

---

### H2 — A19 reminders end-to-end — **FE** · Low

**Problem:** Reminder planner + `NoOpLocalNotificationPort` ship with unit tests; app bindings do not schedule real OS notifications.

**Tasks**

| # | Scope | Task | Done when |
|---|--------|------|-----------|
| H2.1 | **FE** | Product DECIDE: ship real notifications this slice **or** document NoOp as intentional + UI copy that reminders are not device-pushed yet. | Explicit decision in PR/docs. |
| H2.2 | **FE** | If shipping: bind real `LocalNotificationPort` implementation in app DI; request permissions; schedule from planner. | Device receives reminder before scheduled start. |
| H2.3 | **FE** | Smoke / integration note in `manual-test-tier-a.md` A19. | QA path updated. |

**BE:** Late reason / exception path already shipped — no change unless new fields needed.

---

### H3 — Geofence stub chrome — **FE** · Low

**Problem:** `toVisitOutStub` hard-codes `geofenceMode: 'informational'` / radius `100` until `refreshSelected`.

**Tasks**

| # | Scope | Task | Done when |
|---|--------|------|-----------|
| H3.1 | **FE** | Prefer omit geofence chrome until hydrated, **or** pass through timetable fields if available. | No misleading fence UI flash (or flash minimized). |
| H3.2 | **FE** | Keep server punch enforcement as source of truth (no FE-only soften). | Still correct punch behavior. |

---

### H4 — Unused `WARN` gate kind — **BE** · Low

**Tasks**

| # | Scope | Task | Done when |
|---|--------|------|-----------|
| H4.1 | **BE** | Either implement warn path or remove/document `GateDecisionKind.WARN` so API is not misleading. | Enum matches behavior. |

---

### H5 — Optional BE hardening / tests — **BE** · Low

**Tasks**

| # | Scope | Task | Done when |
|---|--------|------|-----------|
| H5.1 | **BE** | Validate billing list `status` query params (reject unknown → 422). | Bad filter ≠ silent empty only. |
| H5.2 | **BE** | Add tests called out in review: create-published burn bypass (C1), `time_based` qty (C2), publish override + audit (S1/S2). | Covered if not already done under those IDs. |

**Out of scope for this plan (pre-existing / accepted):** onboarding soft-gate without legal PDFs; same-device media path tampering (ACL-contained); `ENFORCE_GPS_FOR_PAY=False` product default.

---

## Suggested execution order

```
Week slice 1 — stop wrong money / wrong docs
  C1 (BE)  create-published burn gate
  C2 (BE)  time_based burn qty
  C3 (FE)  media resume poll
  C1.4 / C2.3 / C3.3 tests

Week slice 2 — remaining correctness
  C4 (BE)  PACE per-client fallback
  C7 (BE)  PE export_id tenant
  C5 (FE)  billing loading
  C6 (FE)  budget override dialog

Week slice 3 — compliance
  S2 (BE)  audit publish credential override   (smaller)
  S3 (BE)  CSV formula neutralize              (smaller)
  S1 (BE+FE) budget override permission + audit + field  (larger; after C1/C6)

Hygiene anytime after C3
  H1 (FE)  delete blobs on discard
  H2–H5    as capacity
```

---

## Scope cheat sheet

| Scope | Task IDs |
|-------|----------|
| **Backend only** | C1, C2, C4, C7.1–C7.2, S2, S3, H4, H5 |
| **Frontend only** | C3, C5, C6, H1, H2, H3 |
| **Both** | S1 (BE contract + FE wire), C7.3 optional FE |

---

## Definition of done (this plan)

- [x] All **P0** correctness tasks (C1–C3) merged with tests. *(C1–C3 done 2026-09-26)*
- [x] All **P1** correctness tasks (C4–C7) merged or explicitly deferred with owner. *(C4–C7 done 2026-09-26; C7.3 FE N/A)*
- [ ] Security S1–S3 merged or scheduled with compliance owner (A1/A3 story).
- [ ] H1 done or ticketed with A18 residual.
- [ ] H2 decision recorded (real notifications vs documented NoOp).

---

## Related

- Review: `docs/2026-09-25-frontend-feat-upgrading-vs-ios-review.md`
- Backlog: `docs/2026-09-22-landing-ndis-gap-todos.md` § Tier A
- Manual QA: `docs/manual-test-tier-a.md`
