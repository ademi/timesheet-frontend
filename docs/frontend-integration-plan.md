# Frontend Integration Plan — Backend Changes (Roster + NDIS Billing)

**Created:** 2026-08-23  
**Status:** Draft — awaiting green light before implementation  
**Sources:**

- `docs/backend-changes-for-frontend.md` (NDIS billing, V024–V031)
- `review/TODOS.md` / `review/TODOS.yaml` (roster UX, unified forms, demo parity)
- Gap analysis vs current Flutter codebase (Aug 2026)

**Rule:** Implement **one task at a time** after explicit approval. Check off tasks here as they ship.

---

## Executive summary

| Track | Backend ready? | Flutter today | Priority |
|-------|----------------|---------------|----------|
| **A — Foundation** (models, API paths, errors, permissions) | Yes | ~0% | P0 — blocks everything |
| **B — Roster correctness** (tenant TZ, recurrence defaults, validation) | Yes | ~70% core, gaps in TZ/UX | P1 |
| **C — NDIS support items** (T14) | Yes | 0% | P2 |
| **D — Billing / invoice export** (T15 + T21) | Yes | 0% | P2 |
| **E — Unified support UX** (T12 + T20 partial) | Partial | Separate flows | P2 |
| **F — Registration hardening** | Yes | Partial | P2 |
| **G — Follow-ups** (backend-dependent) | Partial | N/A | P3 |

---

## Phase 0 — Prerequisites (no Flutter code)

- [x] **0.1** Apply backend migrations **V024–V031** on local/staging DB — **done 2026-08-23** on `rostiq@localhost:5432`
- [x] **0.2** Import active NDIS catalogue + MMM postcode reference data — **done** via dev fixtures (`ndis_support_catalogue_sample.xlsx`, `mmm_postcodes_sample.csv`)
- [x] **0.3** Confirm dev tenant has `billing.view` / `billing.manage` on admin role — **confirmed** on `admin` + `owner` roles (`001_dev_seed.sql`)
- [x] **0.4** Smoke-test backend — **passed** (login, horizon, catalogue search, billing list; export POST returns 404 for fake visit id as expected)

See backend runbook: `timesheet/docs/phase-0-local-setup.md` (backend repo).

---

## Phase 1 — Foundation (data layer + shared infra)

> **Goal:** Flutter can parse and call all new APIs without UI yet.  
> **Depends on:** Phase 0  
> **Estimated effort:** M

### Task 1.1 — API paths & permissions ✅

- [x] Add routes to `lib/core/constants/api_paths.dart`
- [x] Add `billing.manage` to `lib/app/constants/app_permissions.dart`
- [x] Gate helpers on `SessionService`: `canViewBilling`, `canManageBilling`, `canSearchNdisCatalogue`

**Files:** `api_paths.dart`, `app_permissions.dart`, `session_service.dart`  
**Tests:** `test/core/constants/api_paths_test.dart`, `session_service_test.dart`

---

### Task 1.2 — Extend DTO models ✅

- [x] **`JobOut` / `JobCreate` / `OngoingSupportCreateRequest`** — `supportItemCode`, `supportItemName`
- [x] **`VisitOut`** — `engagementId`, `shiftId`, support item + `priceTierOverride`
- [x] **`VisitTaskOut`** — `supportItemCode`, `billableMinutes`
- [x] **`ShiftAssignmentOut`** — `engagementId`
- [x] **`TaskTemplateItem`** + recurrence task template support
- [x] **`billing_models.dart`** — catalogue, invoice export, patch bodies
- [x] **`VisitTaskCreateItem`** on manual visit create

**Files:** `job_models.dart`, `visit_models.dart`, `shift_models.dart`, `lib/features/billing/data/models/billing_models.dart`  
**Tests:** `billing_models_test.dart`, `job_models_test.dart`, `shift_models_test.dart`

---

### Task 1.3 — Remote datasources & repositories ✅

- [x] **`NdisCatalogueRemoteDataSource`** — `searchItems(q, limit)`
- [x] **`BillingRemoteDataSource`** — list, create, get, downloadCsv, void
- [x] Extend **`JobsRemoteDataSource`** — `patchJobSupportItem`
- [x] Extend **`VisitsRemoteDataSource`** — support item, price tier, task billing
- [x] Repositories + **`BillingBinding`** for GetX registration

**Files:** `lib/features/billing/`, extended jobs/visits datasources + repositories  
**Tests:** `billing_remote_datasource_test.dart`, `ndis_catalogue_remote_datasource_test.dart`, `visits_remote_datasource_test.dart`, extended `jobs_remote_datasource_test.dart`

---

### Task 1.4 — Error codes in `AppFailure` ✅

- [x] Support item codes + user-facing copy
- [x] Invoice export codes + user-facing copy
- [x] Inline presentation for form/billing validation errors

**Files:** `app_failure.dart`, `app_failure_test.dart`

---

## Phase 2 — Roster correctness & polish

> **Goal:** Fix timezone / validation gaps; align with TODOS.yaml roster items.  
> **Depends on:** Phase 1 optional (can run in parallel with 1.2 if no billing fields on roster)  
> **Estimated effort:** M

### Task 2.1 — Tenant timezone for horizon window (TODOS P2)

- [ ] Prefer tenant `timezone` from session/me payload when backend exposes it; until then keep payroll/settings fetch
- [ ] Add IANA timezone package (`timezone` or equivalent) — replace device-local fallback in `tenant_civil_time.dart`
- [ ] Fix `_horizonFromUtc` / `_horizonToUtc` in `StaffVisitsController` → tenant civil start-of-today + 14d
- [ ] Same horizon source in `OngoingSupportController` and split-recurrence calls
- [ ] Week chevrons: reload list only; do **not** re-trigger horizon with a different window

**Files:**

- `lib/core/time/tenant_civil_time.dart`
- `lib/features/visits/controllers/staff_visits_controller.dart`
- `lib/features/jobs/controllers/ongoing_support_controller.dart`
- `pubspec.yaml` (timezone dependency)

**Tests:** `staff_roster_horizon_test.dart`, extend `tenant_civil_time` tests

---

### Task 2.2 — Recurrence defaults & validation (TODOS.yaml)

- [ ] Default `until` / end date to **start + 1 year** (ongoing support + recurrence rule form) — not open-ended null
- [ ] Client-side **overnight block**: `end_time` must be same civil day and after `start_time` (V018 mirror)
- [ ] Handle **one open standing job per client** — friendly error when second ongoing-support create fails
- [ ] Normalize **invite email to lowercase** before submit (V026)

**Files:**

- `ongoing_support_controller.dart`, `ongoing_support_view.dart`
- `recurrence_rule_form_controller.dart`
- `lib/features/jobs/utils/time_window_utils.dart`
- `workforce_invite_view.dart` / invite datasource

---

### Task 2.3 — Terminology pass (light)

- [ ] Staff roster surfaces: prefer **“Participant shift”** / **“Shift”** over “Visit” where user-facing (board, release dialog, snackbars)
- [ ] Keep internal model names (`VisitOut`) unchanged

**Files:** `staff_visits_board_view.dart`, `roster_grid_view.dart`, `staff_visits_controller.dart` strings only

---

## Phase 3 — NDIS support items UI (T14)

> **Goal:** Coordinators can set NDIS lines without raw API.  
> **Depends on:** Phase 1 complete  
> **Estimated effort:** M

### Task 3.1 — Shared NDIS catalogue picker widget

- [ ] Debounced typeahead against `GET /ndis-catalogue/items`
- [ ] Display canonical name; store `support_item_number` as code
- [ ] Client-side format check: `^\d{2}_\d{3}_\d{4}_\d_\d$`
- [ ] Clear action sends both code + name null

**Files:** `lib/shared/widgets/ndis_support_item_picker.dart` (new)

---

### Task 3.2 — Job & ongoing support

- [ ] Optional support item on **ongoing support** form (fields now persist on backend)
- [ ] Optional default on **job create/edit** (if staff job form exists)
- [ ] `PATCH /jobs/{id}/support-item` on job detail when default changes

**Files:** `ongoing_support_view.dart`, `ongoing_support_controller.dart`, job detail views

---

### Task 3.3 — Visit & task level (staff)

- [ ] Visit detail: edit support item while `status == scheduled` && `paymentStatus == unpaid`
- [ ] Task rows: optional per-task `supportItemCode` on templates and live visit tasks
- [ ] Handle 409 `invalid_visit_status`, 422 catalogue errors via `AppFailure`

**Files:** Staff visit detail view/controller, recurrence task template UI

---

## Phase 4 — Billing: tier override + task minutes (T21)

> **Goal:** Pre-export staff controls for Phase C backend.  
> **Depends on:** Phase 3 (task codes) recommended  
> **Estimated effort:** M

### Task 4.1 — Price tier override on visit detail

- [ ] Selector: `national` | `remote` | `very_remote` | clear (auto)
- [ ] `PATCH /visits/{id}/price-tier`
- [ ] Show hint: override wins over MMM postcode; postcode still needed if no override
- [ ] Block edits on 409 `visit_already_exported`

---

### Task 4.2 — Task billable minutes

- [ ] When task has `supportItemCode`, show minutes editor (0–1440)
- [ ] `PATCH /visits/{id}/tasks/{task_id}/billing`
- [ ] Validate sum of task minutes ≤ visit billable duration (client-side warning; server enforces)
- [ ] Copy explaining multi-line export mode (tasks with codes → one CSV line each)

**Files:** Staff visit detail, `visit_models.dart` (already in Phase 1)

---

## Phase 5 — Invoice export UI (T15)

> **Goal:** Create, download, void NDIS plan-manager CSV exports.  
> **Depends on:** Phases 1, 3, 4  
> **Estimated effort:** L

### Task 5.1 — Billing feature shell

- [ ] Routes: e.g. `/staff/billing/exports`, `/staff/billing/exports/:id`
- [ ] Nav entry gated on `billing.view`
- [ ] List exports (`GET /billing/invoice-exports`)

---

### Task 5.2 — Create export flow

- [ ] Select completed visits (filter: `status == completed`; exclude known-exported via 409 feedback)
- [ ] Pre-flight checklist UI: support item set, tasks have minutes if coded, postcode or tier override
- [ ] `POST /billing/invoice-exports` with `visit_ids`
- [ ] Surface per-visit errors from batch response / failed state clearly

---

### Task 5.3 — Export detail, CSV, void

- [ ] Detail screen: lines with `price_tier`, `participant_ndis_number`, amounts
- [ ] Download/share CSV from `GET .../csv`
- [ ] Void with confirmation (`billing.manage`) → `POST .../void`
- [ ] Note: `invoice_status` not on `VisitOut` — track state via export history + 409 handling

**Files:** New `lib/features/billing/` views + controllers

---

## Phase 6 — Unified support UX (T12 + T20 partial)

> **Goal:** Single stepped flow for ongoing vs one session; demo parity.  
> **Depends on:** Phases 2–3 recommended  
> **Estimated effort:** L

### Task 6.1 — Unified step form

- [ ] Step 1: One session vs ongoing
- [ ] Step 2: Location (client sites; link to add site if empty)
- [ ] Step 3: Pattern / date-time (**time pickers**, required workers +/-)
- [ ] Step 4: Templates + optional NDIS line (Phase 3 picker)
- [ ] Roster **+** button routes to same form
- [ ] After save → roster with `client_id` filter (existing pattern)

---

### Task 6.2 — Care plan demo parity (T20)

- [ ] **NDIS number** on client header / visit detail (from `client_profile_facts`, key `ndis`)
- [ ] **Shift tasks** on ongoing support + book-one: task titles before check-in
- [ ] Label: “Care plan tasks” / “Shift tasks”
- [ ] Soft prompt when Patient type has no NDIS number

**Out of scope:** plan budgets, goal tracking, PRODA

---

## Phase 7 — Registration hardening (backend doc Phase 4)

> **Depends on:** None (can parallel Phase 3+)  
> **Estimated effort:** S

### Task 7.1 — Live legal versions on contractor register

- [ ] Fetch current `platform_terms` / `privacy_policy` versions from compliance API (same as onboarding)
- [ ] Submit exact version strings on register — remove reliance on stale `AppEnv.termsVersion`
- [ ] Handle `legal_document_unavailable` with “Terms updated — refresh and accept”

**Files:** `contractor_register_controller.dart`, `contractor_register_view.dart`

---

## Phase 8 — Follow-ups (blocked or lower priority)

| Task | Blocker | Notes |
|------|---------|-------|
| **8.1** `client_name` on contractor visit tiles (T13) | Backend must add to `VisitOut` | Roster already uses shift/job `clientName` |
| **8.2** Visit list export-status badge | Backend may add `invoice_status` to `VisitOut` | Until then use billing export list |
| **8.3** Horizon cron / worker (TODOS P3) | Backend job | No Flutter work |
| **8.4** Scheduled NDIS catalogue refresh (T16) | Backend cron | No Flutter work |
| **8.5** Platform admin catalogue import UI | `platform.admin` only | CLI/API sufficient for now |

---

## Suggested implementation order (when approved)

```text
Phase 0 (ops)
    ↓
Phase 1.1 → 1.2 → 1.3 → 1.4     ← foundation first
    ↓
Phase 2.1 + 2.2 (parallel)       ← roster correctness (quick wins)
    ↓
Phase 3 → Phase 4 → Phase 5      ← NDIS revenue story
    ↓
Phase 6 + Phase 7 (parallel OK)  ← UX polish
    ↓
Phase 8 as backend ships
```

**First task to implement on green light:** **Task 1.1** (API paths & permissions) — smallest, unblocks all datasources.

---

## Task approval log

| Task | Approved | Implemented | Notes |
|------|----------|-------------|-------|
| Phase 0 | ✅ | 2026-08-23 | Migrations, reference import, smoke tests |
| 1.1 | ✅ | 2026-08-23 | API paths, billing.manage, session gates |
| 1.2 | ✅ | 2026-08-23 | DTO models for NDIS billing + engagement |
| 1.4 | ✅ | 2026-08-23 | NDIS support item + export error codes |
| … | | | |

*(Fill in dates when user approves each task.)*

---

## Out of scope (this plan)

- PRODA / NDIA submission integration
- Full care-plan OS (budgets, goals, versioning)
- Hour-level roster grid / drag-and-drop
- Demoting Jobs from staff nav
- Flutter subscription billing UI (`subscription.view` only)
- Backend changes (T13 `client_name`, session timezone field, horizon cron)

---

*Review this plan and reply with which task to start (recommended: **1.1**). No code changes until explicit green light.*
