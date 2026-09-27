# Review — `feat/upgrading_project` (frontend vs `ios`, backend vs `dev`)

**Date:** 2026-09-25  
**Methods:** Bugbot, Security Review, manual code review  

| Side | Repo | Head | Base |
|------|------|------|------|
| **Frontend** | `/home/ademi/projects/timesheet/frontend` | `feat/upgrading_project` | `ios` |
| **Backend** | `/home/ademi/projects/timesheet/backend` | `feat/upgrading_project` | `dev` |

### Frontend branch context

**Merge-base:** `ab57173`  
**Divergence:** `ios` is **6** commits ahead (client archive / restore); `feat/upgrading_project` is **9** commits ahead (Tier A upgrade work). Frontend review covers **`ios...feat/upgrading_project`** only. Archive UI on `ios` is out of scope.  
**Diff scale:** ~85 files, +5475 / −400 (approx.)

### Backend branch context

**Diff:** `dev...feat/upgrading_project` (~40 files, +4352 / −133 approx.) — credential gate, billing ops (unclaimed/burn/PE/funds-risk), visit `invoice_status`, legal category, primary-site 409, late check-in + pay GPS helper.

---

## Summary

| Side | Source | Result |
|------|--------|--------|
| **Frontend** | Bugbot | **3** findings (1 high, 2 medium) |
| **Frontend** | Security Review | **No** medium+ security issues |
| **Frontend** | Code review | **1** medium (+ lows → below-threshold section) |
| **Backend** | Bugbot | **3** findings (2 high, 1 medium) |
| **Backend** | Security Review | **3** medium findings |
| **Backend** | Code review | **1** medium (+ lows → below-threshold section) |

**Highest priority (FE):** media-outbox retry must not create a new server document on every flush after a failed scan poll.  
**Highest priority (BE):** burn hard-block bypass on create-published paths; `time_based` burn qty wrong.

---

## Frontend — Bugbot

| Severity | Location | Finding |
|----------|----------|---------|
| **high** | `lib/features/documents/sync/media_sync_worker.dart:129` | `_pushOne` always calls `uploadEvidence`, even when the outbox item already has a `documentId` from a prior attempt. Retry after scan poll fail/timeout creates a **new** server document each flush instead of resuming poll on the existing upload. |
| **medium** | `lib/features/documents/sync/media_outbox_store.dart:73` | Confirmed logout / `clearDestructive` removes GetStorage metadata only — files under `media_outbox/` on disk are **not** deleted (orphans). |
| **medium** | `lib/features/billing/controllers/invoice_exports_controller.dart:106` | `onInit` fires `loadExports` and `loadUnclaimedAgeing` (and related loads) concurrently; both drive the same `isLoading` flag. First finisher clears loading while another request may still be in flight. |

### Bugbot detail — media retry re-upload

After a successful upload, the worker writes `documentId` then polls scan status. If poll fails (network / timeout), the item is marked failed **with** `documentId` set. The next flush path always re-uploads:

```129:174:frontend/lib/features/documents/sync/media_sync_worker.dart
  Future<bool> _pushOne(MediaOutboxItem item) async {
    // ...
      final doc = await pipeline.uploadEvidence(/* ... */);
      await store.update(
        item.copyWith(documentId: doc.id, stage: MediaOutboxStage.finalizing),
      );
      final polled = await pipeline.pollScanStatus(documentId: doc.id, /* ... */);
```

**Suggested fix:** If `item.documentId != null`, skip `uploadEvidence` and resume `pollScanStatus` (and only then ack + delete blob).

---

## Frontend — Security Review

**No medium, high, or critical security issues** found in the Flutter diff.

### Areas reviewed (clean)

| Area | Notes |
|------|--------|
| Billing tower APIs | Client gates `canViewBilling` / `canManage`; deep Create tab still requires manage |
| Credential / budget overrides | UI prompts for reason; empty override not sent on retry; server still enforces gates |
| Media outbox | Uploads via `DocumentPipeline` + server `can_write_document`; same-device path tampering contained by ACL |
| Route hydration | Credential / workforce detail resolve from tenant-scoped lists; no arbitrary ID fetch alone |
| Onboarding upload gate | Pickers disabled when `!canUploadDocs`; helper still throws `forbidden` |
| Invite / `existing_account` | Client `isBlocking` change matches BE; staff hard-split still server-enforced |
| API string display | `pace_message`, PE notes, burn lines via Flutter `Text` (escaped) |
| Schedule → visit stub | Temporary `geofenceMode: informational` until refresh; check-in still server-validated |

Below-threshold items from this review are listed in **[Below the threshold issues](#below-the-threshold-issues)**.

---

## Frontend — Code review (reportable)

| Severity | Location | Finding |
|----------|----------|---------|
| **medium** | `lib/features/visits/controllers/staff_visits_controller.dart:701` | On `budget_burn_blocked`, staff publish reuses **`promptCredentialGateOverride`** (credential copy / reasons), not a budget-specific dialog. Group publish correctly uses `promptBudgetBurnOverride`. Misleads staff and conflates two override meanings on the same `override_reason` field. |

### Code review notes (non-findings)

- `openVisitForFix` correctly `await`s navigation then `loadExportableVisits` (A8).
- `canEditVisitSupportItem` correctly requires unpaid + not exported (A5).
- Media enqueue on visit forms + logout guard for pending media is directionally sound once retry/orphan issues are fixed.
- Prior-worker ranking / copy-last-pattern / multi-attach templates look covered by new unit tests.

Low-severity / incomplete-feature notes are under **[Below the threshold issues](#below-the-threshold-issues)**.

---

## Backend — Bugbot

| Severity | Location | Finding |
|----------|----------|---------|
| **high** | `app/modules/shifts/service.py:696` | Budget hard-block is only enforced in `publish_shift` via `assert_publish_burn_allowed`. `create_shift` still calls `_prepare_published_shift` and marks the shift published (including empty `contractor_ids`) with **no** burn evaluation. Staff can bypass plan budget blocks by creating a published shift directly (draft→publish). Same gap on `create_published_shift_for_job`. |
| **high** | `app/modules/billing/burn.py:419` | `evaluate_publish_burn` sets `qty` to full shift duration for every non-`percentage` participant. The other strategy is `time_based`, which bills from participant time windows — not whole-shift hours. Publish burn previews, warnings, and hard blocks are wrong for time-based group shifts. |
| **medium** | `app/modules/billing/burn.py:276` | `_pace_outside_release` only falls back to `plan_start_date` / `plan_end_date` profile facts when **no** `plan_release_periods` rows exist for the whole batch. If any participant has release-period rows, participants **without** rows are never validated and are treated as in-plan. |

---

## Backend — Security Review

| Severity | Location | Finding |
|----------|----------|---------|
| **medium** | `app/modules/billing/burn.py:492` / `app/modules/shifts/service.py:1334` | Budget hard-block override reuses credential `override_reason`, needs only `shifts.manage` (not `billing.manage`), and writes **no** domain audit. Finance/compliance thresholds set via billing can be bypassed at publish with a free-text reason. |
| **medium** | `app/modules/shifts/service.py:1316` | Publish-time credential gate override is **not** audited. Assign path logs `shift.assign_override`; `_assert_assignees_roster_gate` on publish only calls `assert_roster_gate_or_override` with no `log_domain_event`. |
| **medium** | `app/modules/credentials/service_employer.py:199` | Screening-register CSV writes raw `contractor_name` via `csv.DictWriter` with no formula neutralization. Opening in Excel/LibreOffice can execute formulas from contractor-controlled names (`=`, `+`, `-`, `@`, …). |

### Backend security — areas reviewed (clean / positive)

- New billing ops routes: JWT `tenant_id`, SQL scoped; RBAC (`billing.view` / `billing.manage` / `shifts.manage`) applied appropriately.
- No critical/high cross-tenant IDOR, injection, or auth-bypass on new routes.
- Legal document category enforcement is a hardening win.
- Credential hard-gate on staff assign is a net compliance improvement vs prior soft assign.
- Claim path still uses `assert_claim_eligible`; contractors cannot self-claim with expired screening.
- `ENFORCE_GPS_FOR_PAY = False` is a documented product default with tests for gate-on/off — not treated as auth bypass in this diff.

Below-threshold / optional hardening items are under **[Below the threshold issues](#below-the-threshold-issues)**.

---

## Backend — Code review (reportable)

| Severity | Location | Finding |
|----------|----------|---------|
| **medium** | `app/modules/billing/payment_enquiries.py:100` | `export_id` on PE create is not validated as belonging to the same tenant (integrity / cross-tenant UUID attach). Export download still enforces tenant on read. |

Low-severity notes are under **[Below the threshold issues](#below-the-threshold-issues)**.

---

## Combined priority list (above threshold)

1. **P0 / high (BE)** — Enforce burn (and ideally credential) gates on `create_shift` published path + `create_published_shift_for_job`, not only `publish_shift`.
2. **P0 / high (BE)** — Fix `evaluate_publish_burn` `time_based` qty to use participant windows (mirror invoice export math).
3. **P0 / high (FE)** — Media sync: resume poll when `documentId` already set; regression test “upload once → poll fail → retry poll only”.
4. **P1 / medium (BE)** — Separate budget override control (permission + audit + distinct field); audit publish-time credential overrides.
5. **P1 / medium (BE)** — Neutralize CSV formula injection in screening register export.
6. **P1 / medium (BE)** — PACE: validate clients without release-period rows (or fall back per-client).
7. **P1 / medium (BE)** — Validate PE `export_id` same-tenant on create.
8. **P1 / medium (FE)** — Billing `isLoading` race: separate flags or in-flight counter.
9. **P1 / medium (FE)** — On confirmed discard / dismiss terminal: delete blob files via `MediaBlobStore.delete`.
10. **P1 / medium (FE)** — Staff visit publish: budget-specific override prompt for `budget_burn_blocked`.

---

## Below the threshold issues

Items below were explicitly marked **below the reporting threshold** by Security Review, or are **low-severity** / incomplete-feature notes from code review. They are **not** blocking merge by themselves; track as follow-ups.

### Frontend — below the threshold issues

| Source | Location / area | Note |
|--------|-----------------|------|
| Security Review | `MediaOutboxStore.local_path` | Same-user local storage / path tampering on the device — same-host, same-user; server ACL contains impact. |
| Security Review | Onboarding soft-gate finish | Soft-gate “finish onboarding anyway” without legal PDFs — pre-existing product policy, not introduced by this diff. |
| Security Review | New `ApiPaths` vs backend | Client-only permission checks where matching backend `require_permission` already exists; full service-layer tenant pass was out of FE scope (covered in backend review). |
| Code review (low) | `lib/features/visits/services/visit_check_in_reminder_scheduler.dart` | Reminder **planner** + `NoOpLocalNotificationPort` ship with unit tests, but nothing in app bindings schedules real OS notifications — A19 incomplete end-to-end. |
| Code review (low) | `lib/features/documents/sync/media_outbox_store.dart:64` | `dismissTerminal` drops metadata without deleting the blob file (same orphan class as logout clear; paired with medium discard finding). |
| Code review (low) | `lib/features/contractor_schedule/data/models/schedule_models.dart:27` | `toVisitOutStub` hard-codes `geofenceMode: 'informational'` / radius `100` until `refreshSelected`. Brief wrong geofence chrome possible before hydrate; server still enforces punch. |

### Backend — below the threshold issues

| Source | Location / area | Note |
|--------|-----------------|------|
| Security Review | `payment_enquiries` create | Validate `export_id` belongs to the same tenant (also raised as medium in code review — listed there for action; kept here as security’s optional hardening note). |
| Security Review | Billing list endpoints | Add query-param validation for `status` filters (currently harmless empty results). |
| Security Review | Tests | Add tests for publish burn override behavior and audit expectations. |
| Security Review | `ENFORCE_GPS_FOR_PAY` | Documented product default `False`; gate exists for future enforcement and is tested — not an auth bypass. |
| Code review (low) | `tests/billing/test_plan_burn_a3.py` (and related) | No tests yet for create-published burn bypass, `time_based` burn qty, or publish override + audit expectations. |
| Code review (low) | `app/modules/credentials/gate.py:47` | `GateDecisionKind.WARN` is unused — all failures become `BLOCK` (dead API surface / misleading enum). |

---

## Branch context (frontend merge planning)

| Branch | Relative | Notable content |
|--------|----------|-----------------|
| `feat/upgrading_project` | +9 vs merge-base | Credential gate UX, billing ageing/burn/PE, media outbox, late check-in, route hydrate, roster micro-UX |
| `ios` | +6 vs merge-base | Client archive / restore UI + tests + design docs |

Merging upgrade into `ios` (or vice versa) will need a conflict pass around clients list/detail if both touched those surfaces.

---

## Related

- Progress tables: `docs/2026-09-22-landing-ndis-gap-todos.md` §0d; `docs/2026-09-22-ux-friction-inventory.md` §H.

---

## Agents

| Side | Role | Agent |
|------|------|--------|
| Frontend | Bugbot | [Bugbot](25ec6ad1-a18f-4c2c-9ead-cf4df1ee585d) |
| Frontend | Security Review | [Security Review](71b75591-1dc7-47de-a413-48977e084528) |
| Backend | Bugbot | [Bugbot](9331cf44-66dd-4378-832b-20ed991bf1e1) |
| Backend | Security Review | [Security Review](08b33ff2-87f4-4355-9497-3b3b17d95c78) |
