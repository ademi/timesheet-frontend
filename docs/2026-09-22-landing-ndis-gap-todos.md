# Unified app implementation backlog

**Audience:** Senior engineer unfamiliar with Australia / NDIS  
**Date:** 2026-09-22 (revised — todos + competitor research + **code verification of “shipped”**)  
**Purpose:** Single ordered list of **app work** (Flutter + backend). Low hanging fruit first, then features that make Rostiq stand apart / make `landing_page_example.html` honest.  
**Out of scope:** Landing HTML/Next.js redesign, pricing packaging, marketing copy.  
**Self-contained:** Other backlog/competitor docs may be deleted. Everything needed to implement open items (and to trust what is already done) lives here.

### Sources scanned (absorbed — files deleted 2026-09-22)

| Former source | Role before delete |
|---------------|-------------------|
| `landing_page_example.html` | Claims that must be dogfoodable (**kept**) |
| `TODOS.md` / `TODOS.yaml` | Historical open items |
| `docs/group_shifts_todo.md` | Group-shift requirements |
| Client-nav / onboard todo index / support-plan follow-ups | Follow-ups |
| Competitor + pain + tech reports | A/B/C/E/PM capabilities |
| `docs/superpowers/plans/2026-09-17-p0-*.md` | Credential gate + offline GPS plans |
| **2026-09-22 code audit** | Verified COMPLETE vs PARTIAL vs MISSING |

**Canonical backlog:** this file only.

---

## 0a. Shipped baseline (verified — do not rebuild)

Treat as **done** unless a residual bullet below says otherwise. Paths are under `/home/ademi/projects/timesheet/`.

### S1. Group-shift Phases 1–3 — COMPLETE

| Capability | Status | Where | Tests |
|------------|--------|-------|-------|
| Participants, equal split, `worker_count`, PUT replace, time windows | COMPLETE | BE `app/modules/shifts/`; FE `lib/features/shifts/group_book/` | `test_shift_participants_*`, `group_shift_group_controllers_test.dart` |
| Per-participant support item at publish (intensity = different catalogue codes) | COMPLETE | BE publish overrides; FE `group_publish/` | `test_publish_per_participant_support_item.py`, `group_shift_publish_controller_test.dart` |
| Price ÷ N hybrid (`ndis_group` / allocated_share) | COMPLETE | BE `billing/group_pricing.py`; FE `publish_estimate_math.dart` | `test_group_pricing.py`, `publish_estimate_math_test.dart` |
| Travel equal\|nominated + export | COMPLETE | BE `shift_travel_claims` + `travel_export.py`; FE `group_travel/` | `test_shift_travel_claims.py`, `group_shift_travel_controller_test.dart` |
| Budget remaining + export `budget_warnings` | COMPLETE | BE ledger + `budget_summary`; FE Care plan + export detail strip | `test_invoice_export_budget_ledger.py`, `client_budget_*_test.dart` |
| Invoice per-participant lines + “Group share” | COMPLETE | BE billing expand; FE export detail | `test_invoice_export_multi_participant.py`, `invoice_export_detail_view_test.dart` |
| Day-band pricing via catalogue sibling items | COMPLETE | BE export day-band path | `test_invoice_export_day_bands.py` |

**Not Phase 1–3 (still open elsewhere):** full category×intensity auto-map deferred (B13 MVP shipped). Mid-shift N (**B9**), attendance (**B10**), recurrence (**B4**), SIL ROC (**B3**) — **COMPLETE 2026-09-26**.

**Residual polish (optional):** travel **widget** radio test (controllers covered); House-12 manual dogfood checklist.

### S2. Offline GPS punch + honest sync — COMPLETE

| Capability | Status | Where | Tests |
|------------|--------|-------|-------|
| OutboxStore + SyncWorker + connectivity flush | COMPLETE | FE `lib/features/visits/sync/` | `outbox_store_test.dart`, `sync_worker_ordering_test.dart` |
| `tap_time` / `sync_time` / `client_event_id` / `device_offline` | COMPLETE | BE `V062`/`V065`, `jobs/schemas.py`, `clock_time.py` | `test_visit_clock_tap_sync.py`, `test_clock_time.py` |
| Pending→Synced UI (no false success toast) | COMPLETE | `contractor_visits_controller.dart`, visit detail chip | `contractor_check_in_outbox_test.dart`, `clock_sync_ui_test.dart` |
| AttendanceException on missing GPS | COMPLETE | BE `attendance/exceptions.py`, `V063` | `test_attendance_exceptions.py` |
| Staff attendance review + sync conflicts | COMPLETE | BE `sync_conflicts.py`; FE `attendance_review_*` | `test_sync_conflicts.py`, `attendance_review_*_test.dart` |
| Chaos / ordered flush | COMPLETE | — | `test_visit_clock_chaos.py`, FE ordering tests |

**Explicitly NOT shipped:** offline **notes** / form-draft autosave → open item **B2**.  
**Related:** approved exception ⇒ pay OK → **A15** (COMPLETE). Soft multi-point geofence → **B5** (**COMPLETE 2026-09-26**).

### S3. Invoice export glass T15/T17–T19/T21 — COMPLETE

| Capability | Status | Where | Tests |
|------------|--------|-------|-------|
| FE list/create/detail/CSV/void/preflight/Fix-on-visit | COMPLETE | `lib/features/billing/` | `invoice_exports_*_test.dart`, `visit_export_preflight_test.dart` |
| Void→re-export store | COMPLETE | `exported_visit_ids_store.dart` | `exported_visit_ids_store_test.dart` |
| MMM tier hybrid | COMPLETE | BE `billing/pricing.py`, `V030` | `test_invoice_export_mmm.py` |
| Multi-line task export | COMPLETE | BE billing + task minutes PATCH | `test_invoice_export_multiline.py` |
| Void + revert `invoice_status` | COMPLETE | BE void route | `test_invoice_export_void.py` |
| FE price-tier + task minutes on visit | COMPLETE | `staff_visit_detail_view.dart` | `staff_visits_support_item_controller_test.dart` |
| Catalogue picker | COMPLETE | `ndis_support_item_picker.dart` | `ndis_support_item_picker_test.dart` |

**Residuals → A8:** refresh exportable list after Fix return (A5 complete).  
**Not claimed:** PRODA; live MMM display on visit (resolved at export only).

### S4. T20 NDIS number prominence — COMPLETE (docs were stale)

| Capability | Status | Where | Tests |
|------------|--------|-------|-------|
| NDIS on client header + visit detail | COMPLETE | `client_detail_view.dart`, `staff_visit_detail_view.dart` | overview / unified-support tests |
| Soft capture prompt when missing | COMPLETE | `ndis_capture_prompt.dart` | `client_detail_overview_edit_test.dart` |

**Do not reopen as A4.** Optional: stronger typography only.

### S5. Client onboarding Approach B + 2026-09-21 slices — COMPLETE

Contacts merge, disability card dual-capture, wizard support split (NDIS/Care/SC/Specialists), legal other docs, AppFileField, finish→detail hydration — all on FE `master` / BE `dev` with flutter_test + pytest suites under `clients/` / `features/clients/`.

**Residuals:** Profile-side legal-other edit after finish (deferred). Device onboard E2E deferred under A14. Legal-accept category (**A7**) and primary-site 409 / upload picker gate (**A14**) shipped.

### S6. Support Plan Hard MVP + Funding/Consent + clinical + S&N + 7-step wizard — COMPLETE / MERGED

| Slice | Status | Notes |
|-------|--------|-------|
| Hard MVP + shift-brief | MERGED | `support_plan_service.py`, `V037` |
| Funding + Consent | MERGED | `V039` |
| Clinical flags | MERGED | `V040` |
| Strengths & Needs | MERGED | BE migration **V066** (not V041); FE on `master` |
| 7-step wizard shell | MERGED | `support_plan_wizard_shell.dart` |

**Do not reopen as B8 merge work.** Optional device smoke Care tab. Deep clinical checklists stay **D11**.

### S7. Credential vault + engagement eligibility — COMPLETE

| Capability | Status |
|------------|--------|
| Vault CRUD / reviews / claim eligibility hard-block | COMPLETE |
| Staff assign / publish hard gate | **COMPLETE** — `credentials/gate.py`; assign/batch/publish require `override_reason` for audited bypass |

→ Hard-gate scope closed as **A1** (2026-09-22).

### S8. Admin record visit (existing visits) — COMPLETE

`admin_record_visit` + staff dialog + tests. From-scratch wizard → **D8**.

### S9. New Roster five-step composer core — COMPLETE

Unified Support five steps + catalogue filters + multi-slot assign. Follow-ups → **A11**, **A12**.

---

## 0b. Verification residuals folded into open backlog

| Finding | Action in this doc |
|---------|-------------------|
| T20 “open” in old TODOS | Removed from open list (see S4) |
| T14 visit-detail “open” | **Shipped (A5)** — completed unpaid unexported support-item (+ task) edit |
| S&N/wizard “ON FEAT” | Removed merge task; B8 = optional smoke only |
| Day-band “TODO” in group_shifts §4.2.E | Marked shipped (S1); B11 skip |
| Offline GPS plan markdown checkboxes unchecked | Code done (S2); ignore plan checkbox hygiene |
| No device airplane E2E for GPS | Optional under A14 / B2 chaos — not blocking S2 |
| “Ends in a year” open in YAML | **DONE** — removed from A10 residual |
| V034 “untracked” in YAML | **DONE** — removed from A14 residual |
| A15 “must not withhold pay” | No active GPS withhold today; keep as **explicit helper + regression tests** |
| group_shifts §4.2.D mixed plan “TODO” | **COMPLETE MVP 2026-09-26** (B12 registration rates + mixed-export test) |
| group_shifts §5 catalogue TODOs | **COMPLETE MVP 2026-09-26** (B13 hide legacy + hygiene; full auto-map/remap tooling deferred) |
| Soft assign test exists | A1 **DONE** — flipped to 409 unless override+reason |

---

## 0c. Short FE/BE wins (from verification — do first if cutting scope)

| ID | Why short | BE | FE | Tests to flip/add |
|----|-----------|----|----|-------------------|
| **A8** | Navigation `.then` reload | — | `openVisitForFix` await + `loadExportableVisits` | `invoice_exports_controller_test.dart` |
| **A5** | Align support-item with price-tier gate | `update_visit_support_item` (+ task) allow completed unpaid | `canEditVisitSupportItem` | Flip `rejects_completed` → 200; FE completed=true |
| **A15** | No active withhold — lock invariant | `attendance_location_ok_for_pay` helper + wire | optional preflight | **DONE** |
| **A16** | Semantics already in UI | — | — | **DONE** |
| **A10** | Copy + time picker | — | Rename + KeyboardTimeField on recurrence | **DONE** |
| **A9** | Batch attach | `form_template_ids` on catalog POST | Multi-select Manage templates | **DONE** |
| **A7** | One assert arg | `expected_category` on legal accept | — | Wrong category 4xx |
| **A14** UniqueViolation | Map exception | `create_client_site` | — | **DONE** |
| **A1** (core gate only) | **DONE** | `gate.py` + hard assign/publish + expiry/register | panel + override reason | flipped soft-assign; gate tests |

---

## 0. NDIS glossary (minimum)

| Term | Meaning |
|------|---------|
| **NDIS** | Australia’s disability funding scheme |
| **SIL** | Supported Independent Living — shared house, ratios, overnight |
| **0138** | SIL registration/claim group from 1 Jul 2026 |
| **Plan manager** | Pays invoices from a participant’s plan — we export **CSV**, not PRODA |
| **SCHADS** | Employment award (sleepover, broken shift, penalties) |
| **Plan burn** | Budget spend vs remaining envelope |
| **90-day claim window** | From 1 Dec 2026, lodge within 90 days of delivery |
| **Roster of care (ROC)** | Funded staffing pattern by time-of-day (e.g. day denser than overnight) |
| **WWCC / screening** | Mandatory worker checks |

---

## 1. Landing claim inventory (updated vs group-shift ship)

| Claim on example | Status | Notes |
|------------------|--------|-------|
| Mixed intensity / HI lines | **Shipped (S1)** | Per-participant support item at publish (no separate intensity enum) |
| One group shift → claim lines | **Mostly shipped (S1)** | Sleepover types (**B1**), ROC/ratio-drift (**B3**), recurrence of full participant set (**B4**) — **COMPLETE 2026-09-26** |
| Ratio 1:3 / ratio drift | **Shipped (B3 MVP)** | Soft funded-vs-published drift warnings + occupancy; C-08/C-10 deferred |
| Sleepover / active night | **Shipped (B1)** | Continuous `shift_kind`; dual-shift sleep templates rejected |
| Screening OK / can’t roster expired | **Shipped (A1)** | Hard assign/publish gate + audited override |
| Offline field notes | **Shipped (B2)** | Durable draft + queued submit; honest sync chips |
| Notes that actually sync | **Shipped (B2)** | Pending/Synced/Failed; clear only on ACK |
| Plan burn alerts | **Shipped (A3)** | Burn/PE tabs + publish strip + home banner + threshold styling |
| 90-day claim control | **Shipped (A2)** | `GET /v1/billing/unclaimed-ageing` + Billing 90-day tab |
| SIL 0138 ready | **Missing** | Catalogue group pick ≠ SIL readiness / same-story control |
| SCHADS cost before publish | **Missing** | Ship-gated on example |
| Upload/reject/fix | **Partial** | Export + preflight shipped; strengthen reject loops / amend still open |

---

## 2. Ordered implementation list

Numbering is global. Do in order within a tier; parallelize only where noted.

---

### Tier A — Low hanging fruit (S / XS–M, high leverage)

#### A1. Hard credential roster gate + expiry coverage + register export — **COMPLETE**  
**Unlocks:** Landing Proof 2, Screening OK; liability (E-01, E-05)  
**Verified gap (2026-09-22):** Vault + engagement eligibility + **claim** hard-block exist. Staff assign/publish still soft (`audit_override=True` in `shifts/service.py` ~611, ~1322). **`credentials/gate.py` does not exist.** Publish has no assignee eligibility check.  

**NDIS context:** Expired NDIS Worker Screening / WWCC has **no grace period**; rostering an expired worker is a Practice Standards breach.

**BE**
- [x] Add `app/modules/credentials/gate.py` — map `EligibilityReport` → `CredentialGateDecision` {allow|block|warn, reasons[]}  
- [x] Hard-block `_fill_slot` / batch assign / `publish_shift` when required WSC/WWCC/FA/CPR expired/missing/revoked  
- [x] Audited override only with reason string + audit event (no silent `audit_override=True`)  
- [x] Employer expiry digest **90/60/30/7** + coverage-risk count (high-demand shifts with N workers expiring in 60d)  
- [x] Metadata-only screening register export (application #, clearance, expiry, NWSD-link status) — no evidence blobs  
- [x] Tests: `test_gate_decision.py`, `test_assign_credential_gate.py` — expired→409 block; satisfied→allow; override audited  

**FE**
- [x] Surface structured gate reasons on assign/publish failure (reuse `eligibility_incomplete_panel.dart` — today used on workforce review, **not** assign)  
- [x] Override dialog: reason required → send `override_reason` on assign/batch  
- [x] `app_failure.dart`: parse `credential_gate_blocked` + requirements  
- [x] flutter_test: assign blocked panel; override path  

**HTTP target (block):** 409 `detail: { code: "credential_gate_blocked", gate: { decision, reasons[] } }`  
**Flip test:** `test_assign_ineligible_still_allowed_and_audited` → expect **409** unless override+reason — **DONE**  

**Effort:** M · **Priority:** P0  
**Reuse:** `credentials/service_eligibility.py`, `shifts/guards.py` (`assert_claim_eligible` pattern)  
**Shipped:** 2026-09-22

#### A2. Ageing unclaimed / 90-day risk list — **COMPLETE**  
**Unlocks:** Chip “90-day claim control”, reform Dec 2026  
**Verified (2026-09-22):** No ageing-unclaimed list UI or API. Export list is “ready now,” not risk-aged.  

**NDIS context:** From 1 Dec 2026, claims generally must be lodged within **90 days of delivery**. Unexported completed visits are cash + compliance risk.

**BE**
- [x] Query: completed + billable + `invoice_status != exported` (+ unpaid), with `days_since_completed`  
- [x] Optional filters: client, house, >N days, approaching 90  
- [x] Endpoint e.g. `GET /v1/billing/unclaimed-ageing` (or extend exportable visits with age fields)  

**FE**
- [x] Staff Billing/home list sorted by age; badge when any >threshold (e.g. 60/75/90)  
- [x] Deep link into Fix / export  

**Tests:** BE fixture ages correctly; FE sorts + badge; empty state  

**Effort:** S–M · **Priority:** P1  
**Shipped:** 2026-09-22

#### A3. Plan burn alerts + funds-risk / PE tracker — **COMPLETE**  
**Unlocks:** Chip “Plan burn alerts”; PM-TOP-02 cash survival  
**Verified (2026-09-22):** Budget **remaining** + export `budget_warnings` shipped (S1). No staff/home threshold alerts, no PE tracker, no publish hard-warn control tower.  

**BE**
- [x] Threshold rules on remaining / projected burn (soft warn vs hard block config)  
- [x] Soft/hard warn when roster/publish would blow envelope (reuse ledger math)  
- [x] Funds-risk workflow: utilisation vs known statements (not fake NDIA balance); SC/participant check prompts  
- [x] Payment Enquiry (PE) tracker with ageing bands — PE ≠ 5-day invoice  
- [x] Period-aware rostering where PACE release periods bite  

**FE**
- [x] Client + staff home burn alerts  
- [x] Publish strip warning when envelope would blow  
- [x] Shared-shift cost by participant burn report  

**Tests:** threshold fires; publish warn path; PE ageing bands  

**Effort:** M–L · **Priority:** P1  
**Shipped:** 2026-09-22

#### A4. ~~T20 NDIS number prominence~~ **SHIPPED (S4)** — do not reopen  
Optional polish only: stronger header hierarchy than muted 13px line.

#### A5. Fix-on-visit: edit support item on **completed unpaid** visits — **COMPLETE**  
**Why open:** Visit-detail support-item edit works for `scheduled`/`checked_in` only. Export Fix path cannot unblock missing codes on completed visits.  
**Verified (2026-09-22):**
- BE `update_visit_support_item` (`jobs/service.py` ~1016): `status not in {scheduled, checked_in}` → 409 `invalid_visit_status`
- FE `canEditVisitSupportItem` (`staff_visits_controller.dart` ~104): same statuses only
- Contrast: `update_visit_price_tier` already allows any status except `invoice_status == exported`
- Tests assert completed is **false**/409 today (`staff_visits_support_item_controller_test.dart`, `test_support_item_patch.py`)

**BE**
- [x] Allow `PATCH /v1/visits/{id}/support-item` when `status ∈ {scheduled, checked_in, completed}` **and** `payment_status == unpaid` **and** `invoice_status != exported` (align with price-tier)  
- [x] Task PATCH `update_visit_task_support_item`: today allows **scheduled only** — also allow `checked_in` + `completed` when unpaid + not exported  
- [x] Keep 409 `invalid_visit_status` / `visit_already_exported` for paid / exported / cancelled  

**FE**
- [x] `canEditVisitSupportItem` true for completed + unpaid (VisitOut may need `invoiceStatus` or use local export store)  
- [x] Flip tests: completed unpaid → **true**; flip BE `test_patch_visit_support_item_rejects_completed` → expect **200** when unexported  

**Effort:** S · **Priority:** P2 · **Pairs with:** A8  
**Shipped:** 2026-09-22

#### A6. Client / workforce route-id for web refresh — **COMPLETE**  
**Why:** Detail screens hydrate from GetX args; browser refresh / deep link loses id (hydration ship is S5).  
**FE**
- [x] Put client id in `GetPage` route `parameters` (and read on bind)  
- [x] Engagement + credential id in route parameters  
- [x] Delete or repair dead `isCreateFlow` save branch  
**Tests:** widget/controller: open with parameters only (no args) still loads  

**Effort:** S–M · **Priority:** P2–P3  
**Shipped:** 2026-09-22

#### A7. Enforce legal-accept document category — **COMPLETE**  
**Why:** Accepting a legal doc should reject wrong `document.category`.  
**BE**
- [x] Pass `expected_category` into `_assert_document_for_client` on `accept_client_legal`  
- [x] Map: `consent_agreement→consent`, `service_agreement`, `acknowledgement` (prefer `requirement.document_category` when set)  
- [x] Test: wrong category → 4xx; matching → OK  

**Effort:** S · **Priority:** P3  
**Shipped:** 2026-09-22

#### A8. Invoice export list refresh after Fix-on-visit — **COMPLETE**  
**Why open:** `openVisitForFix` is fire-and-forget `Get.toNamed(...)` — no reload on pop. Void/create already call `loadExportableVisits()`.  

**FE only**
- [x] `await Get.toNamed(...)` then `lastVisitErrors.clear()` + `await loadExportableVisits()`  
- [x] Extend `invoice_exports_controller_test.dart`: after Fix return, reload invoked / visit eligible  

**Effort:** XS · **Priority:** P2 · **Depends on:** A5 for completed-visit codes  
**Shipped:** 2026-09-22

#### A9. Multi-select attach forms on visit window — **COMPLETE**  
**Status:** Manage templates multi-select + one batch POST; scoped pending (not shared `isSaving`).  

**BE**
- [x] Batch `POST …/form-catalog` accepts `form_template_ids` (legacy `form_template_id` still ok)  
**FE**
- [x] Multi-select on `job_manage_templates_view.dart` + one request; stop whole-list spinner  
**Tests:** `test_job_form_catalog.py` batch; `jobs_form_catalog_attach_test.dart`  

**Effort:** S–M · **Priority:** P2  
**Shipped:** 2026-09-22

#### A10. New Roster micro-UX — **COMPLETE**  
**Status:** Core composer shipped (S9); residuals below shipped.  

| Sub-bullet | Status |
|------------|--------|
| “Ends in a year” default | **DONE** — `defaultRecurrenceEndDate` + `time_window_utils_test.dart` |
| Rename Visit Window → Participant Shift | **DONE** — recurrence form + overlap copy |
| Spacing between composer fields | **DONE** — light Details spacing (`20`→`16`) |
| Time picker polish | **DONE** — recurrence uses `KeyboardTimeField` |

**FE residual**
- [x] Rename copy Visit Window → Participant Shift  
- [x] Spacing pass on `unified_support_view.dart`  
- [x] Align recurrence time UI with `KeyboardTimeField`  

**Effort:** S · **Priority:** P3  
**Shipped:** 2026-09-22

#### A11. Suggest workers who visited this client before — **COMPLETE**  
**Status:** Assign ranks prior contractors first + “Worked with client” badge (FE via visits lookback).  

**FE**
- [x] Rank/badge “Worked with client” on Assign  
**Tests:** `prior_client_workers_test.dart` + controller ranking  

**Effort:** M · **Priority:** P3  
**Shipped:** 2026-09-22

#### A12. Copy last recurrence pattern into composer — **COMPLETE**  
**Status:** Schedule CTA maps latest job recurrence → frequency/weekdays/windows/slots/endDate.  

**FE**
- [x] CTA on Schedule; map latest rule  
**BE:** reuse list-recurrence APIs  
**Tests:** `recurrence_rule_composer_prefill_test.dart` + controller copy/empty  

**Effort:** M · **Priority:** P3 · **Coordinate with:** recurrence / autocreate (D3)  
**Shipped:** 2026-09-22

#### A13. Ops / invite leftovers — **COMPLETE** (code) / ops checklist  
**Invite core:** **SHIPPED** (path-token register, pending list, re-email, HTML email).  

| Sub-bullet | Status |
|------------|--------|
| Ops: staging/prod `PUBLIC_APP_BASE_URL` + SPA rewrite | **Ops checklist** — see `docs/web-deploy-gcs-cloudflare.md` §8/§10 + `deploy/env.example`; confirm live env outside this repo |
| Product: invite when email already registered | **DONE** — create contractor + engagement (`existing_account`); no registration token |
| Optional work location / service-area | **DEFERRED** — no schema yet |

**Effort:** S–M · **Priority:** P3  
**Shipped (product):** 2026-09-23

#### A14. Onboarding polish leftovers — **COMPLETE** (code residuals)  
**Status:** Approach B onboard = S5; residuals below.  

| Sub-bullet | Status |
|------------|--------|
| `V034__interpreter_language.sql` | **DONE** |
| Device `integration_test` onboard | **DEFERRED** — only `shift_brief_e2e_test.dart` today; flutter_test covers onboard |
| Soft NDIS-capture banner | **DONE** (S4) — optional typography polish only |
| Primary-site UniqueViolation → 409 | **DONE** — `primary_site_already_exists` |
| Gate Identity/Legal on `canUploadDocs` | **DONE** — pickers disabled when missing upload perm |

**Residual**
- [x] Map primary-site UniqueViolation → 409 + API test  
- [x] Disable Identity/Legal pickers when `!canUploadDocs`  
- [ ] Device `integration_test` for onboard *(deferred)*  
- [ ] Optional NDIS banner polish *(non-blocking)*  

**Effort:** S–M · **Priority:** P3  
**Shipped:** 2026-09-23

#### A15. AttendanceException approved ⇒ pay/export OK — **COMPLETE**  
**Verified (2026-09-22):** Exception open/ack **shipped** (S2). Billing + pay-batch **do not** currently withhold for missing GPS — so unpaid-for-GPS is not an active bug. Gap was **missing explicit invariant + tests**.  

**BE**
- [x] Helper `attendance_location_ok_for_pay` + `ENFORCE_GPS_FOR_PAY=False` (approved ⇒ OK; pending/rejected block only when gate on)  
- [x] Wire into `billing/service.py` + `payments/service.py`  
- [x] Do not invent a second attendance ledger  

**FE (optional):** preflight skipped — product does not block on `pending_ack` today  

**Tests**
- [x] `test_invoice_export_attendance_exception.py` — missing GPS + approved → 201; pending → 201 while gate off; pending → 400 when gate on  
- [x] `test_payment_batch_attendance_exception.py` — same for pay-batch  

**Effort:** S–M · **Priority:** P2 · **Note:** Soft captured-outside punch → **B5** (**COMPLETE 2026-09-26**)  
**Shipped:** 2026-09-23

#### A16. Record Visit a11y widget tests — **COMPLETE**  
**Was PARTIAL:** Semantics existed; tests asserted text only.  
- [x] flutter_test: `bySemanticsLabel` liveRegion warning + CTA Semantics(button) + focus-order doc on dialog  

**Effort:** S · **Priority:** P3  
**Shipped:** 2026-09-23

#### A17. Contractor schedule → visit args polish — **COMPLETE**  
**Was:** `openVisit` passed `visit.id` String only; detail accepts `VisitOut` but schedule never did.  
- [x] `TimetableVisitOut.toVisitOutStub` + `openVisit` passes stub `VisitOut`  
- [x] Detail empty state shows spinner when `resolvedVisitId` set (String deep link)  
- [x] Nav args regression: String-id still OK (`contractor_visits_resolved_visit_id_test`); schedule stub test added  

**Effort:** XS · **Priority:** P4  
**Shipped:** 2026-09-23

#### A18. Media upload retry queue (notes / incidents) — **COMPLETE** (notes) / residual incidents owner  
**FE**
- [x] Durable `MediaOutboxStore` + `MediaBlobStore` + `MediaSyncWorker` (GetStorage metadata, disk/memory bytes, progress)  
- [x] Visit form file fields enqueue evidence (`owner_type: visit`); never silent-fail; clear on ACK  
- [x] Logout discard prompt / `clearSession` rules like GPS outbox  
**Tests:** enqueue → fail → retry → ACK; GetStorage restore; media clearSession  
**Residual:** incident `owner_type` not in documents API yet — queue is ready; attach UI deferred until BE  
**Pairs with:** B2  

**Effort:** S–M · **Priority:** P2  
**Shipped:** 2026-09-23

#### A19. Late check-in reminders + reason-coded late punch — **COMPLETE**  
**FE/BE**
- [x] Reminders before scheduled start — `planCheckInReminders` + `LocalNotificationPort` (no-op OS adapter; unit-tested)  
- [x] Late check-in with reason codes; preserve best-effort GPS — `late_reason_code` on `VisitGpsBody`; `late_check_in` attendance exception; FE reason dialog  
**Tests:** late punch stores reason; reminder scheduling unit test; FE grace + JSON  

**Effort:** S–M · **Priority:** P2  
**Shipped:** 2026-09-23

#### A20. In-app location / permission / sync health diagnostics — **COMPLETE**  
**FE**
- [x] Worker-facing diagnostics on Profile: GPS denial, accuracy, pending clock + media sync counts  
**Tests:** widget shows pending count from OutboxStore  

**Effort:** S · **Priority:** P3  
**Shipped:** 2026-09-23

---

### Tier B — Landing honesty + SIL wedge (most crucial product)

#### B1. Sleepover / active night as first-class continuous shift (post–1 Jun 2026 SCHADS) — **COMPLETE**  
**Unlocks:** Hero sleepover pill; night supports pain; SCHADS prerequisite  
**Verified (2026-09-22):** was MISSING; **shipped 2026-09-26**.

**NDIS / SCHADS context:** Sleepover is **one continuous shift** (pre/sleep/post), not two shifts with a fake break. Active night ≠ sleepover for pay and often for claim path.

**BE**
- [x] Model `standard` \| `sleepover` \| `active_night` (and no-overnight policy) — `V075__shift_kind.sql`, `shift_kind.py`  
- [x] Sleepover = one continuous shift with pre/sleep/post segments — block dual-shift sleep templates (`dual_shift_sleep_template`)  
- [x] Migration + schemas; map type → suggested NDIS items; persist through visits → export  
- [x] Claim + pay path hooks for C2 (sleepover unit-`E` export qty=1; live cost delta can stay thin)  

**FE**
- [x] Composer type picker; overnight calendar rendering; versioned house templates  
- [x] Contractor view: continuous overnight, not split cards  

**Tests:** create sleepover spans midnight as one object; active_night ≠ sleepover; reject dual-shift sleep template (`test_shift_kind_sleepover.py`, `test_shift_kind_helpers.py`, FE `overnight_format_test.dart`)  

**Effort:** M–L · **Priority:** P0/P1 for landing · **Blocks:** C2, C3, C6  
**Shipped:** 2026-09-26

#### B2. Offline multi-participant field notes (form-draft autosave) — **COMPLETE**  
**Unlocks:** Chip “Offline field notes”; Proof 3; competitor false-save wounds  
**Verified (2026-09-22):** GPS outbox **S2 COMPLETE**. Forms remain online-only `POST …/form-submissions` — no GetStorage draft. (`syncFormDraftsFromOverview` is **client onboard** drafts, not visit notes.)  
**Shipped:** 2026-09-26  

**NDIS context:** Progress notes are claim/audit evidence. Competitors show “saved” then lose notes (B-06).

**FE**
- [x] Durable local draft keyed by `visitId` + form template id (GetStorage / same durability as OutboxStore) — `FormDraftStore` (`visit_form_draft_v1`)  
- [x] Restore after process kill; clear only on successful ACK  
- [x] Honest Pending/Synced/Failed — never toast success without server ACK  
- [x] Non-destructive: logout/clean-sync must not wipe unsent drafts without export prompt  
- [x] Multi-participant SIL: group-level default (`participantId` null); draft key supports per-participant scope via `formNoteParticipantId`  
- [x] Preserve support-item identity roster → notes → claim (`supportItemCode` on draft)  

**BE**
- [x] Reuse existing form-submission endpoints  
- [x] Idempotent `client_event_id` on form POST (mirror clock) — `V076__form_submission_client_event_id.sql`  

**Tests**
- [x] flutter_test: draft persist / restore / clear-on-ACK / crash mid-note — `form_draft_store_test.dart`  
- [x] Chaos: airplane write → online flush — `form_sync_worker_test.dart`  
- [ ] Optional device `integration_test`  

**Effort:** L · **Priority:** P0/P1 · **Reuse:** `lib/features/visits/sync/outbox_store.dart` conventions  
**Shipped:** 2026-09-26

#### B3. Funded roster of care + ratio-drift + occupancy (SIL house) — **COMPLETE (MVP)**
**Unlocks:** Ratio 1:3 claim; SIL wedge; C4  
**Verified (2026-09-26):** **COMPLETE (MVP)**. Soft drift only; C-08/C-10 deferred.  

**BE**
- [x] House / shared-living site context (`clients.sil_houses`, members, occupancy)  
- [x] ROC: day/evening/overnight funded W:P; shifts stamp `roc_block_id` on publish  
- [x] Warn when published staffing richer/thinner than funded (C-01 soft codes)  
- [x] Occupancy-aware drift when housemate vacant/hospital (C-02 soft)  
- [ ] Own RoC structure / FY rate lock after NDIA ROC Excel removal (C-08) — deferred  
- [ ] Immutable published roster ↔ RoC mapping as audit export (C-10) — deferred (stamp only)  
- [ ] Distinguish shared vs individual supports in same house — deferred  

**FE**
- [x] ROC editor (`/staff/sil/houses`); publish strip humanized ROC warnings; occupancy on house detail  

**Tests:** `tests/sil/test_sil_roc_b3.py`; FE `sil_warning_label_test.dart`  

**Shipped:** 2026-09-26 · Migrations **V078** · API `/v1/sil/*`

**Effort:** L · **Priority:** P0 differentiation · **Blocks:** C4, B19

#### B4. Recurrence copies full group participant set — **COMPLETE**
**Unlocks:** Weekly community groups  
**Verified (2026-09-26):** **COMPLETE**. Pattern on rule; copy before host seed.  

**BE**
- [x] Persist participants + equal_split + `worker_count` on `visit_recurrence_rules` (percentage MVP)  
- [x] Copy onto each occurrence **before** host auto-seed; skip host seed when pattern has a set  
- [x] Instance edits = existing draft participant APIs; series = new rule / recreate pattern (split path unchanged)  

**FE**
- [x] "Repeat this group weekly" on group book review (percentage groups)  

**Tests:** `tests/jobs/test_recurrence_group_participants_b4.py`  

**Shipped:** 2026-09-26 · Migration **V077**

**Effort:** L · **Priority:** P1

#### B5. Soft multi-point geofence + exception workflow — **COMPLETE**
**Unlocks:** Soft outside punches; community multi-stop; early clock-out visibility  
**Verified (2026-09-26):** **COMPLETE**. Soft default; tenant `geofence_outside_policy` hard|soft; multi-stop nearest; early clock-out exception.  

**BE**
- [x] Soft path: captured-outside → allow punch + `geofence_outside` `pending_ack`; tenant hard/soft (`V079`, `jobs/geofence.py`)  
- [x] Multi-point / multi-stop sites (`clients.client_site_stops` + CRUD)  
- [x] Soft end-geofence / early clock-out (`early_clock_out` kind, 300s grace)  

**FE**
- [x] Attendance & variance labels + Variance filter (`attendance_review_*`)  
- [x] Multi-stop site UI (client Places)  
- [x] Tenant outside-geofence policy setting  
- [x] Job form geofence mode sends `enforce` (not `enforced`)  

**Tests:** `tests/jobs/test_soft_geofence_b5.py`; FE attendance variance + sites stops tests  

**Shipped:** 2026-09-26 · Migration **V079**

**Effort:** M–L · **Priority:** P2

#### B6. Modular actual-clock overlap checks — **COMPLETE**
**Verified (2026-09-26):** **COMPLETE**. Shared `assert_no_clock_overlap` on `time_entries`; 409 `clock_overlap`; adjacent touch OK; open entries use unbounded end.

**BE**
- [x] Shared predicate (`attendance/clock_overlap.py`); half-open ranges  
- [x] Wire GPS check-in / complete / cancel + all admin adjustments + sync force-accept  

**FE**
- [x] `clock_overlap` in `app_failure` + sync terminal classifier  

**Tests:** `tests/attendance/test_clock_overlap_b6.py`  

**Shipped:** 2026-09-26

**Effort:** L · **Priority:** P2

#### B7. Plan-managed invoice pre-flight + PM profiles + reject amend — **COMPLETE (MVP)**
**Unlocks:** Claims pain; PM-TOP-03/04  
**Verified (2026-09-26):** **COMPLETE (MVP)**. Expanded export gates; PM destination profiles; rejection taxonomy + same-week resubmit link. PDF / per-PM CSV dialects deferred.

**BE/FE**
- [x] Expand preflight: >24h/day, group allocation integrity, provider ABN when plan_managed; existing catalogue/attendance gates retained  
- [x] Clear fix CTAs into visit (S3) — still primary path  
- [x] Per-tenant Plan Manager destination profiles (`billing.pm_destination_profiles`, attach on export)  
- [x] Rejection reason taxonomy + open/resubmit queue (`billing.invoice_export_rejections`)  
- [ ] Machine-readable PDF/CSV layouts per PM profile — deferred (`template_key=generic_csv` stub only)  

**Tests:** `tests/billing/test_pm_profiles_b7.py`; FE preflight 24h block  

**Shipped:** 2026-09-26 · Migration **V080**

**Effort:** M–L · **Priority:** P1 / P0 cash

#### B8. ~~Merge Strengths & Needs + Support Plan wizard~~ **SHIPPED / MERGED (S6)**  
Optional only:
- [ ] Device smoke Care tab: Funding / Clinical / S&N / wizard  
Do **not** re-litigate V041 — S&N landed as **V066**.

#### B9. Mid-shift membership / N pricing decision + implement — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. Locked rule: **N = billable active participants at export** (soft-remove + no-show). Mid-shift join/leave does **not** create overlapping membership ÷N time segments — use `time_based` / allocated_share for partial windows.

**BE**
- [x] Document + enforce N-at-export in `group_pricing.py` + `_active_shift_participants`  
- [x] Soft-remove already reduces N for whole claim (existing claim-path tests)

**FE**
- [x] Remove-from-group copy explains export N (not mid-shift ÷N segments)

**Tests:** `test_group_pricing.py` (active N); `test_group_shift_claim_path.py` soft-remove; `test_group_attendance_b9_b10.py`

**Shipped:** 2026-09-26

**Effort:** M · **Priority:** P2

#### B10. Per-participant attendance (present / no-show / partial) — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. `attendance` independent of membership `status`. `no_show` stays active but drops from N/lines; `partial` uses `attended_minutes` (clamped). One worker clock for N≥2 unchanged.

**BE**
- [x] `V081__shift_participant_attendance.sql`; PATCH `…/participants/{id}/attendance`  
- [x] Export billable filter + `_participant_line_minutes`

**FE**
- [x] Attendance screen + shift-detail Attendance action; one-clock copy for N≥2  
- [x] Models / datasource / repository

**Tests:** `tests/billing/test_group_attendance_b9_b10.py`; FE `group_shift_group_controllers_test.dart` attendance group

**Shipped:** 2026-09-26 · Migration **V081**

**Effort:** M · **Priority:** P2

#### B11. ~~Day-band catalogue sibling pricing~~ **SHIPPED (S1)** — `test_invoice_export_day_bands.py`  
Only reopen if a specific band/edge case fails dogfood. Prefer B9 for mid-shift interaction.

#### B12. Mixed plan-management + registration-status rates — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. Plan-management snapshot/cap/override already shipped; added tenant NDIS registration → **0.9× catalogue ceilings from 2027-01-01** (all items; SCCP-only scope deferred). Mixed plan types confirmed on one export.

**BE**
- [x] `V082__ndis_provider_registration_status.sql` on `org.tenants`  
- [x] Publish applies `registration_price_factor` to snapshotted `price_limit_*` / default `base_rate`  
- [x] Tenant GET/PATCH exposes status  

**FE**
- [x] Settings dropdown (Registered / Unregistered) next to provider ABN  

**Tests:** `tests/billing/test_registration_rates_b12.py` (factor matrix, pre/post-2027, reduced-cap reject, mixed plan export); FE `tenant_settings_registration_b12_test.dart`

**Deferred:** SCCP registration-group-only −10%; PRODA sync of registration

**Shipped:** 2026-09-26 · Migration **V082**

**Effort:** L · **Priority:** P2–P3

#### B13. Catalogue mapping hygiene for group shifts — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. Manual item + ÷N + BE legacy STA forbid + day-band siblings already shipped. Added picker hide of STA ratio SKUs, draft/publish hygiene warn+clear, and shift-kind auto-suggest when job has no item.

**BE/FE**
- [x] FE+BE catalogue search/cache exclude legacy STA ratio codes/names (`legacy_sta.py` / `LegacyStaRatio`)  
- [x] Publish hygiene: clear legacy or inactive job prefill + warn strip; auto-map first `suggested_support_item_codes` hit in active catalogue  
- [x] `legacy_sta_ratio_item_forbidden` mapped in `app_failure.dart`  
- [ ] Full auto-map category + day-type + intensity + registration → item — deferred  
- [ ] Versioned catalogue remap tooling / import remap matrix — deferred  

**Tests:** `test_legacy_sta.py` (search filter); FE `ndis_catalogue_local_filter_test`, `catalogue_hygiene_b13_test`, publish controller hygiene/suggest  

**Shipped:** 2026-09-26

**Effort:** M–L · **Priority:** P2

#### B14. Group-shift invoice filters + void-after-allocation DECIDE — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. Void+rebill already shipped. **Locked DECIDE:** after any visit on the shift is `invoice_status=exported`, soft-remove / rebalance → **409 `membership_locked_exported`** (same pattern as attendance). Path: void → mutate → rebill. Create export filters: host client + participant + job/support + period.

**BE/FE**
- [x] Soft-remove export lock (`membership_locked_exported`)  
- [x] Create-tab filters: participant (`participant_id`) + job (`job_id`) alongside host client  
- [x] FE `app_failure` mapping  
- [ ] Support-item filter on visits list — deferred  
- [ ] Filters on export history list — deferred  

**Tests:** `tests/billing/test_membership_locked_exported_b14.py`; FE `invoice_exports_controller_test` filter params  

**Shipped:** 2026-09-26

**Effort:** S–M · **Priority:** P3

#### B15. Shift brief multi-participant privacy — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. **Locked DECIDE:** brief is **host-only** (`jobs.client_id` Care plan / allergies / access). Other participants' clinical PII is not merged. Visit-complete notifications and form submissions stay host- or visit-scoped.

**BE/FE**
- [x] Document host-anchor in `clients/shift_brief.py`  
- [x] `brief_scope=host` + `active_participant_count` on brief response  
- [x] Contractor `ShiftBriefPanel` copy: host brief + group count note  
- [ ] Per-participant brief tabs / `?participant_id=` — deferred  

**Tests:** FE `shift_brief_panel_test` host/group copy  

**Shipped:** 2026-09-26

**Effort:** M · **Priority:** P3

#### B16. AR ageing by plan manager + delay-reason tags — **COMPLETE (MVP)**
**From:** PM-TOP-01; PM-01, PM-02, PM-10, PM-15; tech P0-4
**Verified (2026-09-26):** **COMPLETE (MVP)**.

- [x] Unpaid finalized invoices aged with day-5/7/14 SLA (GET /v1/billing/ar-ageing)
- [x] Delay reason enum: pm_queue | participant_hold | ndia_review | pe | rejected (PATCH .../ar)
- [x] Filter AR by management type (ndia / plan_managed / self_managed); snapshot on export create
- [x] FE Invoice exports AR tab (distinct from PE / 90d unclaimed)

**Shipped:** V083 ar_payment_status + delay_reason + management_type; ar_ageing.py; FE AR tab

**Tests:** test_ar_ageing_b16.py

**Effort:** M · **Priority:** P1 · **Pairs with:** B7

#### B17. Mobile trip kms → timesheet / claims auto-flow — **COMPLETE (MVP)**
**Verified (2026-09-26):** **COMPLETE (MVP)**. Staff shift travel claims (equal|nominated) + export remain S1. Contractor/mobile typed trip-kms now upserts shift_travel_claims without re-key.

**FE mobile:** Trip kms editor on contractor visit detail (group-shift visits)
**BE:** PUT /v1/visits/{id}/trip-kms → work.visits.trip_kms + linked shift_travel_claims (equal, default travel E code)
**Tests:** test_trip_kms_b17.py — capture → export line qty; update reuses same claim (no dual entry)

**Shipped:** V083 visit trip_kms columns; trip_kms.py; contractor UI

**Effort:** M · **Priority:** P2 · **Do not confuse with:** §8 staff travel DONE

#### B18. Short-notice cancellation → redeploy → pay → NDIS claim — **COMPLETE (MVP)**
**From:** pain C-06
**Verified (2026-09-26):** **COMPLETE (MVP)** — pytest test_cancel_short_notice_b18.py green on rostiq_test after V084. Guided cancel checklist + queue + claimable export without clocks. Full SCHADS make-up amounts deferred to C2.

- [x] Guided cancel: reason + redeploy (keep_open / cancel_shift / skip) + claim/pay eligible flags
- [x] Cancellation event with short_notice (<7d), claim_status / pay_status / redeploy_status
- [x] Queue GET /v1/cancellations (open pay/claim/redeploy items)
- [x] Claim-eligible cancelled visits exportable on invoice CSV (marks claim exported)
- [x] FE staff cancel dialog captures checklist

**Shipped:** V084 visit_cancellation_events; jobs/cancellations.py; billing cancel claim branch; staff cancel dialog

**Tests:** test_cancel_short_notice_b18.py (3/3 passed)

**Deferred:** SCHADS award make-up amounts (C2); auto payment-batch insert; cancellation catalogue sibling map

**Effort:** M–L · **Priority:** P2

#### B19. Vacancy overlay + shift-creep flags — **COMPLETE (MVP)**
**From:** pain C-07
**Verified (2026-09-26):** **COMPLETE (MVP)** — pytest test_sil_vacancy_b19.py green on rostiq_test after V084. Built on B3 house model.

- [x] Bed capacity + fixed weekly cost on SIL houses
- [x] Overlay: vacancy_bed_underfilled / member absent / creep staffing / unfunded shift / cost_occupancy_gap
- [x] Draft fill-vacancy shift on house-linked job
- [x] FE house detail strip + capacity/cost editor + Draft fill shift

**Shipped:** V084 sil_houses columns; GET overlay + POST fill-vacancy + PATCH house; SIL FE strip

**Tests:** test_sil_vacancy_b19.py (1/1 passed)

**Deferred:** SCHADS margin (C2); auto-fill worker matching (B20); blocking publish on creep

**Effort:** M · **Priority:** P2 · **Depends on:** B3 house model

#### B20. Competency / skills + housemate compatibility assign gates — **COMPLETE (MVP)**
**From:** pain C-12
**Verified (2026-09-26):** **COMPLETE (MVP)** — pytest test_assign_gates_b20.py green on rostiq_test after V085.

- [x] Soft warn: mealtime / BSP via profile facts + worker_competencies
- [x] Hard block: medication_admin credential + SIL sil_compat_rules (vacant housemate ignored)
- [x] Staff assign/publish override audited; claim cannot override hard blocks
- [x] Soft codes on ShiftOut.warnings (ssign_soft:*); FE override + SIL compat CRUD

**Deferred:** full training matrix role×topic (C8); preference matching beyond SIL rules

**Effort:** M · **Priority:** P3

---

### Tier C — Stand-apart / reform control towers

#### C1. House-12 dogfood path (landing acceptance)  
**From:** landing demo CTA  
- [ ] Fixture: 1 worker, 3 participants, intensity, sleepover, screening OK  
- [ ] Publish → attendance/notes → CSV matches story  
- [ ] Checklist or automated dogfood gate  

**Effort:** M · **Depends on:** A1, B1–B4  

#### C2. SCHADS award engine + cost before publish (dual ledger)  
**Unlocks:** Landing Proof 1; pain A-01, A-10, C-05  
**Verified (2026-09-22):** **MISSING** — zero `schads` / `award` / `cost_preview` / `broken_shift` / dual-ledger code under BE or FE.  

**BE**
- [ ] Award cost preview at publish: sleepover, broken shift, travel, night/weekend, PH  
- [ ] Dual ledger: award-pay duration may exceed claimable delivery minutes  
- [ ] Versionable rate tables (feeds C7)  

**FE**
- [ ] Staff **cost** vs NDIS claim margin strip before publish  
- [ ] Contractor remittance parity with same shift objects (travel, sleepover, weekend)  

**Tests:** FWO fixtures; sleepover vs active overnight delta; must pass before marketing “award engine”  

**Effort:** L · **Priority:** P0 if employed ICP; else P1 · **Depends on:** B1 for overnight types

#### C3. Broken shift + paid inter-client travel + minima on cost path  
**From:** landing Proof 1; pain A-03, A-04, A-07; tech P0-3  
- [ ] Auto-detect broken-shift patterns; allowance + 2h minima in preview (A-03, A-07)  
- [ ] Inter-client **paid travel segments** from map-aware sequencing → remittance (A-04)  
- [ ] Travel on publish estimate alongside night types (claim travel already exists)  
- [ ] Min engagement validation at roster (2h disability/home care; sleepover floors)  

**Effort:** M–L · **Depends on:** B1, C2

#### C4. SIL 0138 “same story” control tower  
**Unlocks:** Chip SIL 0138 ready; Jul 2026 reform  
**From:** landing; group_shifts §9; pain C-01…C-10 cluster  
- [ ] Org/house SIL registration status (manual OK)  
- [ ] Prefer/validate 0138 items for post–1 Jul SIL delivery  
- [ ] One view: funded ratio + delivered + claim lines for a house week  
- [ ] Irregular SIL supports → correct participant budget  
- [ ] Multi-worker shared claiming rules  
- [ ] Never claim PRODA submit  

**Effort:** L · **Depends on:** B3, intensity/export shipped

#### C5. SIL overnight monitoring pack  
**From:** support-plan roadmap backlog; group_shifts SIL; Commission sleepover guidance  
- [ ] SIL-specific body_json / brief sections for overnight monitoring  

**Effort:** M–L · **Priority:** P2 after B3 · **DECIDE:** MVP vs later

#### C6. Sleepover disturbance OT + active-minutes escalator  
**From:** pain A-06, C-11; NDIS Commission ~2h active guidance  
- [ ] Log disturbance / call-to-duty episodes on continuous sleepover → OT (min 1h)  
- [ ] Cumulative active minutes on sleepover → funding-review flag when exceeding guidance  

**Effort:** M · **Depends on:** B1, C2

#### C7. Versioned SCHADS rules + pay-batch exception queue + FWO evidence pack  
**From:** pain A-08, A-09, A-11; tech P1-7  
- [ ] Versioned award/EA rate tables with effective dates; block pay batch if uplift missing  
- [ ] Pre-export SCHADS exception queue before Xero/MYOB/STP lock  
- [ ] Roster + timesheet + allowance + remittance **evidence pack** export  

**Effort:** L · **Depends on:** C2 · **Priority:** P1 after cost preview

#### C8. Training matrix + competency roster gate  
**From:** pain E-06; tech P1-8  
- [ ] Role × topic matrix; competency Y/N; expiry on FA/CPR  
- [ ] Same hard/soft gate pattern as credentials (A1)  
- [ ] Gap analysis report  

**Effort:** M · **Priority:** P1–P2 · **Pairs with:** B20

#### C9. Weekly five-number reconciliation (rostered → worked → billable → claimed → paid)  
**From:** pain C-09; Priority1  
- [ ] Staff report tying publish-and-claim through remittance  
- [ ] Surfaces dual-ledger and PM/AR gaps in one place  

**Effort:** M · **Depends on:** export, B16, C2 · **Priority:** P2

#### C10. Handover paid both ways + FTE coverage warnings  
**From:** pain C-13  
- [ ] Handover overlap claimable/paid both directions  
- [ ] Lean FTE coverage warnings for 24/7 houses  

**Effort:** M · **Priority:** P3 · **Depends on:** B3

---

### Tier D — Parity, scale, parked (keep visible; do not jump the queue)

#### D1. Horizon cron / worker  
**From:** `TODOS.md`  
- [ ] Scheduled `ensure_horizon` per tenant (lock, 14-day cap, no second fill loop)  

**Effort:** L · **Priority:** P3

#### D2. Long-range assign availability (parked revisit)  
**From:** `TODOS.md`  
- [ ] Pick: longer series / availability calendar / virtual expand / cron-first  
- [ ] Do not only bump `HORIZON_MAX_DAYS`  

**Effort:** M–L · **Priority:** P3 parked · **After:** export glass (done)

#### D3. Autocreate shifts + past-date fill  
**From:** `TODOS.yaml` Roster / create ongoing  
- [ ] Autocreate shifts  
- [ ] Filling past support items from a past start date fills past roster  

**Effort:** L · **Priority:** P3 · **Coordinate with:** D1, B4

#### D4. Roster board performance + filter completeness  
**From:** `TODOS.yaml`  
- [ ] Stop slow full reload every week switch  
- [ ] “I can’t see all clients on the filter”  

**Effort:** M · **Priority:** P3

#### D5. Edit / add / remove contractor visits by tenant or contractor  
**From:** `TODOS.yaml` Roster  
- [ ] Clear staff flows for muting membership on visits (beyond group soft-remove)  

**Effort:** M · **Priority:** P3

#### D6. One open standing job per client?  
**From:** `TODOS.yaml`  
- [ ] Product DECIDE + enforce or document  

**Effort:** S–M · **Priority:** P3 · **DECIDE**

#### D7. T16 — Scheduled NDIS catalogue refresh  
**From:** `TODOS.md`  
- [ ] Fetch official XLSX, SHA256 compare, import; alert on failure  

**Effort:** M · **Priority:** P3

#### D8. From-scratch admin “record a visit” wizard  
**From:** `TODOS.md`  
- [ ] Pick client+contractor, create job/visit if needed, then clocks (reuse create paths)  

**Effort:** L · **Priority:** P3

#### D9. Export invoice to worker + plan manager; payment every 14 days  
**From:** `TODOS.yaml` user feedback  
- [ ] Worker-facing invoice/export path if still missing  
- [ ] Payment cadence every 14 days  

**Effort:** M · **Priority:** P3

#### D10. Inline multi-address on onboard  
**From:** `TODOS.yaml` deferred_explicitly  
- [ ] Inline SiteDraft / additional sites (today: `openAddLocation` after primary)  

**Effort:** M · **Priority:** P3 deferred

#### D11. Clinical / compliance deep backlog (separate plans when pulled)  
**From:** support-plan roadmap backlog; `TODOS.yaml` deferred lighter  
Do **not** start without `/write-plan`. Catalog only:  
- [ ] Full PHC services matrix  
- [ ] Full nutrition / hazard checklist UIs  
- [ ] High intensity care risk + medication management forms  
- [ ] Immutable support-plan version history  
- [ ] Role-gated sensitive S&N  
- [ ] Restrictive practices register  
- [ ] Goal progress ↔ progress notes  
- [ ] Service Delivery Checklist as hard pre-commencement gate  
- [ ] Full daily routine time-blocked UI  
- [ ] Dignity-of-risk assessments  
- [ ] Advocate as first-class contact relationship  
- [ ] Incident history timeline on plan  
- [ ] Coordination-of-supports multi-provider referral  

**Priority:** Backlog · **Rule:** one plan at a time

#### D12. Extra NDIS budget lines (SC / plan-manager / employment)  
**From:** onboarding index N1b deferred  
- [ ] Only if ops asks  

**Priority:** Deferred

#### D13. PRODA / marketplace / multi-client jobs / live NDIA balance  
**From:** group_shifts non-goals; cashflow “do not build yet”; competitor rec #5  
- [ ] Explicit non-goals for now — do not build  
- [ ] Decide later: build PRODA vs partner Careview/Entiprius-class PM tools  

#### D14. Xero / MYOB / STP accounting integrations  
**From:** competitor gap matrix P1; pain A-09  
- [ ] After SCHADS exception queue (C7) — gate exports into accounting  

**Effort:** L · **Priority:** P2–P3

#### D15. Participant / family / nominee portal  
**From:** competitor gap (GoodHuman / Rostery)  
- [ ] Out of wedge until SIL + get-paid loop dominates  

**Priority:** P2 enterprise

#### D16. eMAR / clinical SIL medication  
**From:** competitor gap (Rostery)  
- [ ] Niche SIL RFP — after C5 overnight pack  

**Priority:** P2–P3

#### D17. Dual NDIS reportable + aged-care SIRS incident tagging  
**From:** pain E-07; tech P2-10; batch2 B2-10  
- [ ] One incident register → dual tags/timers; report-once map-twice  

**Effort:** M · **Priority:** P2 dual-registered ICP only

#### D18. Continuous Practice-Standards audit evidence pack  
**From:** pain E-04, E-10; tech P2-11; batch2 B2-12/13 SME audit cost  
- [ ] Always-ready mapped pack (<60s retrieve); prevent-NC ROI for SMEs  

**Effort:** M · **Priority:** P2

#### D19. Pathway-aware cash forecast (NDIA vs PM vs self)  
**From:** PM-09, PM-10; tech P2-12  
- [ ] 13-week forecast by pathway mix; stop-service notice helpers (PM-13)  

**Effort:** M · **Depends on:** B16 · **Priority:** P2

#### D20. In-app fillable Consent / SA + e-sign  
**From:** competitor P2; onboard v1 is upload + mark complete  
- [ ] Replace Drive/PDF-only for common path when volume demands  

**Effort:** L · **Priority:** P3

#### D21. AI rostering / note assist / smart match  
**From:** competitor gap (Lumary, ShiftCare, Imploy, Rostery)  
- [ ] Do not chase AI theatre before reliability (B) + SCHADS (A) + RoC (C)  

**Priority:** P3 / opportunistic

#### D22. Aged Care / Support at Home dual funding  
**From:** competitor gap (FlowLogic, AlayaCare, Rostery add-on)  
- [ ] Separate wedge — not NDIS SIL first beachhead  

**Priority:** Deferred

#### D23. Multi-entity consolidated reporting  
**From:** competitor P2  
- [ ] Franchises / multi-ABN groups  

**Priority:** Deferred

#### D24. Daily + weekly OT engines + PH midnight split  
**From:** pain A-05  
- [ ] Extends C2 award engine depth  

**Effort:** M · **Depends on:** C2 · **Priority:** P2

#### D25. Incident → reportable timeframe workflows  
**From:** competitor P1 gap; pain E-09 register close-out  
- [ ] Close-out + CI linkage; Commission clocks  

**Effort:** M · **Priority:** P2

---

## 3. Suggested sequence (compressed)

```
Short FE/BE wins first (§0c)
  A8 Fix return → reload export list                         [COMPLETE 2026-09-22]
  A5 completed unpaid support-item edit                      [COMPLETE 2026-09-22]
  A15 lock approved-exception ⇒ pay/export invariant         [COMPLETE 2026-09-23]
  A7 legal-accept category                                   [COMPLETE 2026-09-22]
  A16 Record a11y Semantics tests                            [COMPLETE 2026-09-23]
  A9 multi-attach forms                                      [COMPLETE 2026-09-22]
  A10 New Roster micro-UX residuals                          [COMPLETE 2026-09-22]
  A13 invite existing-account + ops checklist                [COMPLETE 2026-09-23]
  A14 primary-site 409 + upload picker gate                  [COMPLETE 2026-09-23]

Week-scale / landing honesty
  A1 credential hard gate + expiry bands + register export   [COMPLETE 2026-09-22]
  A2 90-day unclaimed list                                   [COMPLETE 2026-09-22]
  A18 media retry queue                                      [COMPLETE 2026-09-23]
  A3 plan burn + funds-risk / PE tracker                     [COMPLETE 2026-09-22]
  A19 late check-in                                          [COMPLETE 2026-09-23]
  A6 route-id refresh                                        [COMPLETE 2026-09-22]
  A11 prior-worker Assign ranking                            [COMPLETE 2026-09-22]
  A12 copy last recurrence pattern                           [COMPLETE 2026-09-22]
  A13 invite existing-account + ops checklist                [COMPLETE 2026-09-23]
  A14 primary-site 409 + upload picker gate                  [COMPLETE 2026-09-23]
  A17 schedule → VisitOut args                               [COMPLETE 2026-09-23]
  A20 sync/GPS diagnostics                                   [COMPLETE 2026-09-23]
  (A4 T20 NDIS = SHIPPED S4 — skip)

Landing wedge + cash
  B1 continuous sleepover / active night                     [COMPLETE 2026-09-26]
  B2 offline notes (honest sync)                             [COMPLETE 2026-09-26]
  B16 AR ageing by PM                                    [COMPLETE MVP 2026-09-26]
  B4 group recurrence participants                           [COMPLETE 2026-09-26]
  B3 ROC + ratio drift + occupancy                           [COMPLETE MVP 2026-09-26]
  B5 soft multi-point geofence                               [COMPLETE 2026-09-26]
  B6 actual clock overlap                                     [COMPLETE 2026-09-26]
  B7 PM preflight + profiles + reject amend                   [COMPLETE MVP 2026-09-26]
  B17 mobile kms auto-flow                                   [COMPLETE MVP 2026-09-26]
  B18–B19 cancellation / vacancy
  B9 mid-shift N lock (export billable N)                     [COMPLETE MVP 2026-09-26]
  B10 present/no_show/partial attendance                      [COMPLETE MVP 2026-09-26]
  B12 mixed plan + registration rates                     [COMPLETE MVP 2026-09-26]
  B13 catalogue mapping hygiene                            [COMPLETE MVP 2026-09-26]
  B14 invoice filters + export membership lock             [COMPLETE MVP 2026-09-26]
  B15 host-only shift brief                                [COMPLETE MVP 2026-09-26]
  B20 as DECIDEs unlock
  (B8 S&N+wizard = MERGED S6 — optional smoke only)
  (B11 day-band = SHIPPED S1 — skip)

Stand apart
  C1 House-12 dogfood
  C2–C3 SCHADS cost preview + dual ledger + broken/travel/minima  [C2 MISSING]
  C6 disturbance OT + active minutes
  C7 versioned rules + pay-batch exceptions + FWO pack
  C8 training matrix gate
  C4 SIL 0138 control tower
  C5 SIL overnight pack
  C9 five-number reconciliation
  C10 handover / FTE coverage

Parked / later
  D1–D25 (Xero, portals, eMAR, dual SIRS, audit pack, cash forecast, e-sign, AI, …)
```

---

## 4. Definition of done — example page honest

- [x] A1 Screening cannot publish without audited override  
- [x] A2 Unclaimed ageing list live  
- [x] A3 Burn alerts visible to staff (not only export warnings)  
- [ ] B1 Sleepover vs active night changes claim path  
- [ ] B2 Notes survive offline / crash with honest sync  
- [x] B3 Ratio drift warns on publish  
- [ ] C1 House-12 path ≤15 min ending in correct CSV  
- [ ] C2 (only if Proof 1 shown) SCHADS cost preview before publish  
- [ ] C4 (only if 0138 chip shown) house week same-story view  

Until green, keep that chip/proof off public landing or mark coming.

---

## 5. Self-contained reference (other docs may be deleted)

Pain/competitor IDs cited above (A-01…E-12, PM-*, B2-*) are **labels only** for why work matters. Implement from the checklists in §2; do not require the source PDFs/MDs.

### Key code anchors (absolute under repo root)

| Area | Backend | Frontend |
|------|---------|----------|
| Credential eligibility | `app/modules/credentials/service_eligibility.py`, `shifts/guards.py` | `eligibility_incomplete_panel.dart` |
| Soft assign (gap A1) | **CLOSED** — `_fill_slot` hard gate + `override_reason` | Assign/publish surfaces `credential_gate_blocked` + override dialog |
| Offline GPS (S2) | `jobs/schemas.py` tap/sync fields; `clock_time.py`; `V062`/`V065` | `lib/features/visits/sync/` |
| Offline notes (B2 gap) | form-submission POST (online today) | No GetStorage draft yet |
| Group pricing (S1) | `billing/group_pricing.py`, `travel_export.py` | `group_book/`, `group_publish/`, `group_travel/` |
| Invoice export (S3) | `app/modules/billing/` | `lib/features/billing/` |
| Support item PATCH | visit support-item routes | `staff_visit_detail_view.dart`, support-item controller |
| Support plan (S6) | `support_plan_service.py`, `V037`/`V039`/`V040`/`V066` | Care tab + `support_plan_wizard_shell.dart` |
| Attendance exceptions | `attendance/exceptions.py`, `V063` | `attendance_review_*` |

### Test command hints

```bash
# Backend (from backend/)
pytest app/modules/billing/tests/ app/modules/shifts/tests/ app/modules/credentials/ -q
pytest -k "group_pricing or travel_claim or day_band or clock_tap or attendance_exception" -q

# Frontend (from frontend/)
flutter test test/features/billing/ test/features/shifts/ test/features/visits/
flutter test test/features/clients/  # onboard / detail
```

### Deleted historical sources (2026-09-22)

Absorbed into §0a–§2, then removed:

- Root: `TODOS.md`, `TODOS.yaml`, `competitor-research-ndis-management-2026-08-21.md`
- `docs/group_shifts_todo.md`, `docs/client-detail-navigation-todo.md`
- `docs/rostiq-pain-*.md`, `docs/rostiq-developer-tech-report.md`
- `docs/superpowers/plans/2026-09-21-client-onboarding-todo-index.md`
- `docs/superpowers/plans/2026-08-30-support-plan-follow-ups-roadmap.md`
- `docs/superpowers/plans/2026-09-17-p0-*.md` (credential gate + offline GPS)
- Frontend mirrors: `frontend/docs/client-detail-navigation-todo.md`, `frontend/docs/superpowers/plans/2026-09-21-client-onboarding-todo-index.md`

**Kept:** `landing_page_example.html`, and other `docs/superpowers/plans/*` slice write-plans (shipped implementation archaeology — not the product backlog).
