# Code review: `feat/new-roster-ndis-catalogue-ux` vs `ios` (`frontend/`)

**Date:** 2026-08-26  
**Scope:** 21 commits, ~70 files, +5388/−665 lines  
**Main themes:** five-step unified support composer, multi-slot worker assignment, NDIS catalogue local filtering, tenant timezone from session, assign availability/conflict UX

**Tests:** 173 targeted tests pass. Coverage is strong for the new utilities and unified-support flows.

---

## High / medium

### 1. One-session submit can leave a partially created shift (medium)

`_submitOneSession` creates the shift first, then loops `assignShift` for each worker. If a later assignment fails (busy worker, network error, etc.), the shift already exists and the user sees an error with no rollback.

```1051:1069:frontend/lib/features/jobs/controllers/unified_support_controller.dart
    final created = await _shifts.createShift(
      ShiftCreateRequest(
        jobId: support.id,
        scheduledStart: oneSessionStart.value,
        scheduledEnd: oneSessionEnd.value,
        requiredSlots: requiredSlots.value,
        status: (publishImmediately.value || ids.isNotEmpty)
            ? 'published'
            : 'draft',
      ),
    );
    final tasks = List<TaskTemplateItem>.from(taskTemplate);
    for (final contractorId in ids) {
      await _shifts.assignShift(
        shiftId: created.id,
        contractorId: contractorId,
        taskTemplate: tasks.isEmpty ? null : tasks,
      );
    }
```

The partial-assignment dialog warns the user but does not prevent a mid-loop failure. Consider server-side batch assign, compensating delete, or per-worker error handling. No test covers this failure mode.

### 2. Recurring assign step: Free/Busy badge only reflects the first occurrence (medium)

`availabilityLabelForContractor` always uses `_assignAvailabilityWindow`, which is built from the **first** recurrence occurrence (`computeAssignScheduleWindow`). For weekly/fortnightly patterns, a worker can show **Free** in the dropdown while being **Busy** on later dates in the horizon.

Partial-assign preview catches this at submit time, but the assign-step labels are misleading for ongoing support. Either label against “next busy occurrence” or show a weaker hint (e.g. “Free on first date”).

### 3. NDIS catalogue hard cap at 1000 items (medium)

```17:24:frontend/lib/features/billing/data/repositories/ndis_catalogue_repository.dart
  Future<List<NdisCatalogueItemOut>> fetchAllActiveItems({int limit = 1000}) {
    final cached = _cachedItems;
    if (cached != null) {
      return Future<List<NdisCatalogueItemOut>>.value(cached);
    }

    return _inFlight ??= _remote
        .fetchAllActiveItems(limit: limit)
```

If the active catalogue exceeds 1000 rows, items are silently omitted from the picker with no explicit truncation warning. Consider pagination, a higher limit aligned with backend max, or surfacing “catalogue may be incomplete” when the response hits the limit.

### 5. Leave detection uses device local time, not tenant civil time (medium)

```16:33:frontend/lib/features/visits/utils/assign_availability.dart
  final dayLocal = day.toLocal();
  final civil = DateTime(dayLocal.year, dayLocal.month, dayLocal.day);
  ...
      final leaveStart = leave.startDate.toLocal();
      final leaveEnd = leave.endDate.toLocal();
```

Shift/visit overlap uses UTC instants (correct), but leave uses `toLocal()`. For staff whose device TZ ≠ tenant TZ (common for remote coordinators), leave can show as **Free** on the wrong civil day. This branch adds tenant TZ elsewhere; leave checks should use the same civil-time helpers.

---

## Low

### 6. `endDate` changes do not invalidate assign/conflict caches

`ever(...)` hooks cover start date, times, frequency, and weekdays, but not `endDate`. If a user goes back from assign and shortens the recurrence end date, partial-assign preview can include occurrences outside the new range until a full reload.

### 7. One-session auto-publish when workers are assigned

Shift status becomes `'published'` when `filledContractorIds.isNotEmpty`, even if `publishImmediately` is false. **Intentional (product D6):** assigning workers implies published status; documented in `unified_support_controller.dart` (`// D6 intentional: assigned workers ⇒ published even if toggle off.`). Behavior change from `the branch ios` is accepted.

### 8. Let's migrate Recurrence rule form, and any other form to reflect the latest changes
### 9. Task preset chips removed from unified support

Replacing `CarePlanTasksField` with free-text `VisitInstructionsField` removes quick-add presets (`Personal care`, etc.). Recurrence rule form still has presets. Minor UX regression unless intentional.

### 10. Multi-worker pre-assign only in unified support

`ongoing_support_view` / `recurrence_rule_form_view` still expose a single optional worker (disabled when `requiredSlots > 1`). API now sends `contractor_ids`, but legacy forms cannot pre-fill multiple slots. Product gap, not necessarily a bug.

### 11. `NdisCatalogueRepository.clearCache()` never wired to logout/tenant switch

Probably fine if catalogue is global reference data; if it ever becomes tenant-scoped, stale cache could leak across sessions.

---

## Security

No new auth bypasses or secret handling issues found. NDIS filter prefs in `GetStorage` are non-sensitive. Assign/conflict loads use existing authenticated repositories.

---

## Missing tests (notable gaps)

| Area | Gap |
|------|-----|
| One-session submit | `createShift` succeeds + `assignShift` fails mid-loop |
| Recurring availability | Label vs multi-occurrence busy state |
| `endDate` invalidation | Partial preview after end-date change |
| `RecurrenceRuleOut` | Fallback from `contractor_id` |
| Catalogue | Truncation when response length == limit |
| Leave + tenant TZ | `assign_availability` leave path with non-local device TZ |

---

## What looks solid

- Good extraction of pure helpers (`partial_assign_preview`, `schedule_conflict`, `assign_availability`, `tenant_civil_time`).
- Duplicate worker-in-slot rejection with UI refresh.
- Partial-assignment confirm dialog before submit.
- Lazy engagement loading on assign step.
- Staff roster now marks busy from visits (fixes prior shift-only blind spot).
- Broad widget/controller tests; five-step flow and catalogue cache tests are thorough.
- `VisitsBinding.ensureShared()` correctly added to `UnifiedSupportBinding`.
- One-session auto-publish when workers are assigned (finding #7) is intentional per product D6.

---

## Summary

The branch is well-tested and structurally sound for the new roster/NDIS UX. The main risks before merge are **partial one-session submit failures**, **misleading recurring availability labels**, and **timezone inconsistency in leave detection**. Confirm backend/API rollout for `contractor_ids` and whether the 1000-item catalogue cap matches production catalogue size.
