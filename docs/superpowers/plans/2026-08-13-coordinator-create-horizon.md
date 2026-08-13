# Coordinator Create + Auto-Horizon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Staff can start ongoing support for a client (including unfilled repeating times) in one screen, and the roster silently fills the next 14 days of published shift holes. Schema nouns stay off the glass.

**Architecture:** No new tables. Add two staff-only write endpoints that compose existing `create_job` + `create_recurrence_rule` + `generate_visits_from_rule` (always `partial=True`). Flutter gets a client-scoped composer and a copy layer. Roster `ensureBoardLoaded` POSTs horizon in the background after the existing shift list paints. Jobs nav stays (templates still live there). People×day board, this/future edit, and sick-day notify are **out of scope**.

**Tech Stack:** PostgreSQL, FastAPI + asyncpg + Pydantic v2, existing `org.api_idempotency`, `limiter`, `require_permission`, Flutter/GetX/Dio/mocktail, `compileRecurrenceRrule`, `create_published_shift_for_job`, `shifts_recurrence_occurrence_uidx`.

**Locked decisions:**
- D1: This plan is steal 1–3 only (language, client-create, auto-horizon). Steal 4–7 are follow-up plans.
- D2: No `RecurrentShift` type. Unassigned pattern = nullable `contractor_id` (already shipped in V021).
- D3: One open standing job per client remains the product (`jobs_one_open_standing_per_client`).
- D4: Composite `POST /v1/jobs/ongoing-support` (client_id in JSON) creates job + first pattern + horizon for that rule in **one transaction**. Lives on the jobs router to avoid a clients↔jobs import cycle. Flutter does not orchestrate three writes.
- D5: `POST /v1/jobs/horizon` fills **all** active rules for the tenant in a capped window. Always `partial=True`. Window max **14 days** (stricter than `VISIT_GENERATE_MAX_DAYS=90`).
- D6: Horizon is a write. `shifts.read` users see existing shifts only. Only `jobs.manage` may call horizon.
- D7: Book one session uses existing `POST /v1/shifts` on the standing job. If none exists, CTA is disabled with “Start ongoing support first.”
- D8: Keep Jobs in staff nav this slice. Language-pass it. Do not hide it until templates have another home.
- D9: After successful ongoing-support, route to Roster with `client_id` filter (client-side via job ids). Do not land on Job detail.
- D10: Reuse `AppColors`. No DESIGN.md. No XOR / standing / Generate (14d) / partial in user-visible strings.
- D11: Default person on Start ongoing = Unfilled. Default title = `"{clientName} support"`.
- D12 (eng review 2B): Composer **keeps** `horizon_from` / `horizon_to`. Same ≤14-day validator as `HorizonRequest` (`horizon_window_too_large`). Flutter sends the rolling window; server does not invent a hidden range. Design doc said server-only — this review overrides it.
- D13 (eng review CQ1A): `fill_rule_window` is the only occurrence loop (expand + `generate_one_occurrence`). `generate_visits_from_rule` keeps idempotency + 90-day cap + engagement check, then calls it. `ensure_horizon` loads rules, then per-rule txn → `fill_rule_window`. Composite calls `fill_rule_window` inside its job+rule txn. Do not copy the expand loop.
- D14 (eng review P1A): `ensure_horizon` prefetches existing `(recurrence_rule_id, scheduled_start)` **once** for the selected rule ids + window. Passes that set into `fill_rule_window(..., existing=...)`. When `existing` is provided, skip the per-hole `SELECT id FROM work.shifts WHERE recurrence_rule_id AND scheduled_start` (today: `generate_visits_from_rule` ~1038). Composite may prefetch for the single new rule. Keep `assert_no_overlap` on assigned inserts.
- D15 (eng review OV1): Roster and job-detail Fill POST `[startOfToday, startOfToday+14d)` in the tenant TZ (device local is acceptable if tenant TZ is not on the client yet; do not use `_fromUtc`/`_toUtc`). Composer still sends `horizon_from`/`horizon_to` (D12). Week chevrons only reload the visible list; they do not change the horizon window.
- D16 (eng review OV2): Prefetch existing occurrences **including cancelled**. If `(rule_id, scheduled_start)` already has any shift, skip (`already_generated` or `already_cancelled`). Auto-horizon must not insert a new published row on top of a cancel. Unique index stays (manual republish via Book one session / future steal 5 still allowed).
- D17 (eng review OV8): Concurrent horizon is not a 500. `generate_one_occurrence` catches `UniqueViolationError` on the occurrence unique index and returns `already_generated` when `partial=True`. `ensure_horizon` does **not** sit inside one router transaction (that would abort every remaining rule). Per-rule: catch `engagement_not_active` and continue; do not raise out of `ensure_horizon`. Roster horizon `AppFailure` must not set `errorMessage` (list already painted). Composite assigned + inactive engagement still 409 + rollback (create path, not fill path).
- D18 (eng review OV9): Composer loads branches via `JobsRepository.listBranches()` (same source as `JobsController.loadJobs`). Empty branches disables the Branch option. Home still uses `ClientsRepository.listSites`.
- D19 (eng review OV10): Keep steal 1–3 including roster auto-horizon. Do not cut horizon to “Fill on job detail only.” Language + composer without auto-fill fails the design success “holes appear without Generate.”

---

## Out of scope (follow-up plans)

- People × day roster grid + Unfilled row (steal 4)
- Staff availability/leave list API
- This / all future / copy tile (steal 5)
- Sick-day notify + drag (steal 6)
- Visit status rollup on tiles (steal 7)
- Dropping `jobs_one_open_standing_per_client`
- Cron/worker for horizon (roster open by a manager is the trigger)
- Demoting Jobs nav

---

## Domain (unchanged)

```text
Client
  └── Job (standing, one open)     ← "ongoing support"
        └── Recurrence rule        ← "pattern" (contractor_id nullable)
              └── generate → Shift (published, N slots)
                    └── Assignment? → Visit
```

**Flow E (no workers yet):**

```text
Client → Start ongoing
  where: site | branch
  repeat: Mon 09:00–12:00
  needs: 1
  person: Unfilled
→ INSERT job + rule (contractor_id NULL)
→ horizon inserts published shifts, open_slots = required_slots
→ Roster cards (amber) until assign/claim
→ no visit rows yet
```

---

## Trust boundary (CSO)

New authenticated staff writes. Client PII already on job/shift DTOs for staff. No contractor self-serve change. No public routes.

| Threat | Control | Test |
|--------|---------|------|
| IDOR ongoing-support for another tenant's client | `client_id` + `tenant_id` from JWT on every SELECT; 404 not 403 | other-tenant UUID → 404 |
| Site/branch swap (site of client B on client A) | Site must belong to that client+tenant; branch to tenant | 404 `client_site_not_found` |
| Contractor assign without engagement | Reuse `_assert_active_engagement` when `contractor_id` set | 409 `engagement_not_active` |
| Horizon DoS (90-day explode) | Horizon window **≤14 days**; `10/minute` per user | 400 `horizon_window_too_large`; 429 |
| Horizon as GET side effect | Horizon is POST only; roster GET `/shifts` stays read | GET `/jobs/horizon` → 404/422 and **zero new shifts** |
| Duplicate standing job | Existing unique index; 409 `standing_job_exists` | 409 + friendly copy |
| Race two managers Start ongoing | Unique index; one 201 one 409 | parallel POST |
| Race two horizon calls | `shifts_recurrence_occurrence_uidx` + always partial | second call created_shift_ids empty |
| Read-only supervisor mutates roster | Horizon requires `jobs.manage` | `shifts.read` only → 403 |
| Orphan job if rule insert fails | Single transaction in composite | on rule fail, job rolled back |
| Actor type | Existing `ActorGuard` + JWT `actor_type` | contractor token → 403 |

---

## Efficiency

- Horizon **must not** call `generate_visits_from_rule` in a nested transaction per occurrence without a prefetch. Prefetch existing `(recurrence_rule_id, scheduled_start)` for the window in **one** query, then insert only misses.
- Reuse `create_published_shift_for_job` and the assign/`_insert_visit` path from generate (extract `_generate_one_occurrence`). Do not copy overlap SQL.
- Flutter: paint roster from `listShifts` first; POST horizon only if `jobs.manage`; ignore 429 (toast already mapped); refresh list once after horizon returns.
- Do not POST horizon on filter/status change or week-shift until the in-flight call finishes (`_horizonInFlight` guard).
- Cap rules processed: if >200 active rules, process 200 and return `truncated: true` (do not silently hang).

---

## Smooth UI

- One composer screen from client. Fields: title (prefilled), where (home/branch, no XOR), pattern (reuse weekday chips + times), needs N, person (Unfilled default).
- Errors stay on the composer (inline). `standing_job_exists` copy offers “Open existing support” → job detail.
- No site? Disable submit and show “Add a site for this client first” with a button back to client sites (trial note).
- No branches? Disable Branch in the where dropdown. Client with only a branch (no home site) can still Save.
- Horizon: 2px `LinearProgressIndicator` under roster week chrome. List remains interactive. Snackbar only if `created_shift_ids.length > 0`. Overlap / already_generated: no roster snackbar.
- Job list grouped by `clientName` (then untitled). Subtitle uses copy helpers.
- Job detail: hide Generate (14d), partial switch, Manual visit. Keep Patterns + Deactivate + “Book one session” (existing shift create dialog or small form).
- Dates on roster: `Mon 10 Aug 09:00`, not `2026-08-10 09:00`.
- Filter label: Job → still job titles this slice (client filter is steal 4). Optional: show `clientName · title` in dropdown.

---

## File structure

| File | SRP | Seam |
|------|-----|------|
| `frontend/lib/features/jobs/utils/job_copy.dart` | User-visible labels for kind/status/location | Pure functions; no GetX |
| `frontend/lib/shared/utils/roster_time_format.dart` | Human roster timestamps | Pure |
| `backend/.../jobs/schemas.py` | `OngoingSupportCreate`, `HorizonRequest`, `HorizonOut` | HTTP/JSON |
| `backend/.../jobs/service.py` | Extract `_generate_one_occurrence`; add `create_ongoing_support`, `ensure_horizon` | Transactions |
| `backend/.../jobs/router.py` | Two new routes + limiter | Authz boundary |
| `frontend/.../jobs/data/models/job_models.dart` | DTOs | Parse only |
| `frontend/.../jobs/data/datasources/jobs_remote_datasource.dart` | Dio | No UI |
| `frontend/.../jobs/data/repositories/jobs_repository.dart` | Pass-through | |
| `frontend/.../jobs/controllers/ongoing_support_controller.dart` | Composer state + submit | Does not call Dio |
| `frontend/.../jobs/views/ongoing_support_view.dart` | Composer UI | |
| `frontend/.../clients/widgets/client_detail_support_section.dart` | CTAs on client | |
| Modify: copy on existing job/roster views, `app_failure.dart`, `api_paths.dart`, `app_routes.dart`, `jobs_routes.dart`, `staff_visits_controller.dart`, `staff_visits_board_view.dart` | | |

**DRY:** `_generate_one_occurrence` is the only insert path for recurrence holes. Horizon and per-rule generate both call it. Copy helpers are the only user-facing kind/status strings.

**SOLID:** Router = authz + HTTP. Service owns transactions. Composer controller owns form; view does not call Dio. Copy module has no I/O.

**YAGNI:** No grid, no cron, no nav removal, no client_id query on GET `/shifts` (filter client-side via jobs already loaded on roster).

**Known duplication accepted:** Composer repeats weekday chips from `recurrence_rule_form_view.dart` rather than extracting a shared widget this slice (steal 5 will own pattern edit). Do not “DRY” those into a package yet.

---

## Task 1: Copy helpers + failure messages

**Files:**
- Create: `frontend/lib/features/jobs/utils/job_copy.dart`
- Create: `frontend/lib/shared/utils/roster_time_format.dart`
- Modify: `frontend/lib/core/errors/app_failure.dart` (`standing_job_exists` message)
- Test: `frontend/test/features/jobs/job_copy_test.dart`
- Test: `frontend/test/shared/roster_time_format_test.dart`
- Test: `frontend/test/core/errors/app_failure_test.dart` (extend)

- [ ] **Step 1: Write the failing tests**

```dart
// frontend/test/features/jobs/job_copy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/jobs/utils/job_copy.dart';

void main() {
  test('kindLabel maps schema to coordinator words', () {
    expect(kindLabel('standing'), 'Ongoing support');
    expect(kindLabel('ad_hoc'), 'One-off');
    expect(kindLabel('other'), 'other');
  });

  test('statusLabel maps open/closed/cancelled', () {
    expect(jobStatusLabel('open'), 'Open');
    expect(jobStatusLabel('closed'), 'Ended');
    expect(jobStatusLabel('cancelled'), 'Cancelled');
  });

  test('locationModeLabel never says XOR', () {
    expect(locationModeLabel('site'), "Client's home");
    expect(locationModeLabel('branch'), 'Branch');
    expect(locationModeLabel('site').toLowerCase(), isNot(contains('xor')));
  });

  test('defaultOngoingTitle uses client name', () {
    expect(defaultOngoingTitle('Sam Lee'), 'Sam Lee support');
  });
}
```

```dart
// frontend/test/shared/roster_time_format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/shared/utils/roster_time_format.dart';

void main() {
  test('formats local window without ISO date', () {
    final start = DateTime(2026, 8, 10, 9, 0);
    expect(formatRosterStamp(start), 'Mon 10 Aug 09:00');
    expect(formatRosterStamp(start), isNot(contains('2026-08-10')));
  });
}
```

Add in `app_failure_test.dart` (existing file):

```dart
test('standing_job_exists is coordinator copy', () {
  expect(
    AppFailure.fromDio(
      DioException(
        requestOptions: RequestOptions(path: '/jobs'),
        response: Response(
          requestOptions: RequestOptions(path: '/jobs'),
          statusCode: 409,
          data: {'detail': 'standing_job_exists'},
        ),
        type: DioExceptionType.badResponse,
      ),
    ).message,
    contains('already has ongoing support'),
  );
});
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd frontend && flutter test test/features/jobs/job_copy_test.dart test/shared/roster_time_format_test.dart test/core/errors/app_failure_test.dart
```

Expected: FAIL (missing library / old message).

- [ ] **Step 3: Minimal implementation**

```dart
// frontend/lib/features/jobs/utils/job_copy.dart
String kindLabel(String kind) => switch (kind) {
      'standing' => 'Ongoing support',
      'ad_hoc' => 'One-off',
      _ => kind,
    };

String jobStatusLabel(String status) => switch (status) {
      'open' => 'Open',
      'closed' => 'Ended',
      'cancelled' => 'Cancelled',
      _ => status,
    };

String locationModeLabel(String mode) => switch (mode) {
      'site' => "Client's home",
      'branch' => 'Branch',
      _ => mode,
    };

String defaultOngoingTitle(String clientName) {
  final name = clientName.trim();
  return name.isEmpty ? 'Ongoing support' : '$name support';
}

String jobListSubtitle({
  required String kind,
  required String status,
  required bool hasSite,
  required bool hasBranch,
}) {
  final where = hasSite
      ? locationModeLabel('site')
      : hasBranch
          ? locationModeLabel('branch')
          : 'Location not set';
  return '${kindLabel(kind)} · ${jobStatusLabel(status)} · $where';
}
```

```dart
// frontend/lib/shared/utils/roster_time_format.dart
const _wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatRosterStamp(DateTime dt) {
  final l = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${_wd[l.weekday - 1]} ${l.day} ${_mo[l.month - 1]} ${two(l.hour)}:${two(l.minute)}';
}
```

In `app_failure.dart` `_userMessage`:

```dart
case 'standing_job_exists':
  return 'This client already has ongoing support. Open it, or book one extra session.';
case 'horizon_window_too_large':
  return 'Choose a window of 14 days or less.';
case 'horizon_truncated':
  return 'Filled as many upcoming shifts as allowed. Open roster again to continue.';
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
cd frontend && flutter test test/features/jobs/job_copy_test.dart test/shared/roster_time_format_test.dart test/core/errors/app_failure_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/jobs/utils/job_copy.dart \
  frontend/lib/shared/utils/roster_time_format.dart \
  frontend/lib/core/errors/app_failure.dart \
  frontend/test/features/jobs/job_copy_test.dart \
  frontend/test/shared/roster_time_format_test.dart \
  frontend/test/core/errors/app_failure_test.dart
git commit -m "$(cat <<'EOF'
feat: add coordinator copy for jobs and roster timestamps

EOF
)"
```

---

## Task 2: Language pass on existing screens

**Files:**
- Modify: `frontend/lib/features/jobs/views/job_form_view.dart`
- Modify: `frontend/lib/features/jobs/views/jobs_list_view.dart`
- Modify: `frontend/lib/features/jobs/views/job_detail_view.dart`
- Modify: `frontend/lib/features/jobs/views/recurrence_rule_form_view.dart`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart`
- Modify: `frontend/lib/features/jobs/controllers/jobs_controller.dart` (XOR error strings)
- Test: `frontend/test/features/jobs/job_copy_widgets_test.dart`

- [ ] **Step 1: Widget test that forbidden strings are gone from list subtitle helper**

```dart
test('jobListSubtitle never contains xor or standing', () {
  final s = jobListSubtitle(
    kind: 'standing',
    status: 'open',
    hasSite: true,
    hasBranch: false,
  );
  expect(s.toLowerCase(), isNot(contains('xor')));
  expect(s.toLowerCase(), isNot(contains('standing')));
  expect(s, contains('Ongoing support'));
});
```

(Add to `job_copy_test.dart` — no widget harness required.)

- [ ] **Step 2: Run — expect FAIL until list uses helper**

- [ ] **Step 3: Wire copy into views**

`jobs_list_view.dart` subtitle:

```dart
subtitle: Text(
  jobListSubtitle(
    kind: job.kind,
    status: job.status,
    hasSite: job.clientSiteId != null,
    hasBranch: job.branchId != null,
  ),
),
```

Group list by client (sort jobs by `clientName ?? 'No client'`, then title). Insert a section header `Text(group, style: titleMedium)` when the group changes.

`job_form_view.dart`:
- Kind items: `Text(kindLabel('standing'))` / `Text(kindLabel('ad_hoc'))` with values still `'standing'` / `'ad_hoc'`.
- Location items: `Text(locationModeLabel('site'))` / `Text(locationModeLabel('branch'))`.
- Remove helperText `Exactly one of client_site_id or branch_id`.
- Standing client label: `Client *` (drop “(standing)”).
- `jobs_controller.dart` validation: `'Select a client site.'` / `'Select a branch.'` (no XOR).

`job_detail_view.dart`:
- Header line: `'${kindLabel(job.kind)} · ${jobStatusLabel(job.status)}'`
- Recurrence section title: `Patterns`
- Empty standing: `Patterns need ongoing support.`
- **Remove** the `Generate with partial` Row/Switch.
- **Remove** the Generate (14d) button (horizon replaces it).
- **Remove** the Manual visit block (Book one session lands in Task 8).
- Keep Deactivate / Activate on each rule.
- Recurrence card second line: `'${rule.isActive ? 'Active' : 'Paused'} · ${rule.contractorName ?? 'Unfilled'}'`

`recurrence_rule_form_view.dart`:
- AppBar: `Add weekly pattern`
- Unassigned item: `Unfilled (leave open to claim)`
- Label: `Worker (optional)`
- Helper: `Creates upcoming shifts. Unfilled slots stay open to claim.`
- `Required workers` → `Needs how many people`

`staff_visits_board_view.dart`:
- Replace `_fmt` usage on cards with `formatRosterStamp`.
- Status dropdown labels: `Unpublished` / `Live` / `Cancelled` (values stay `draft` / `published` / `cancelled`).
- Empty: `No shifts this week.`

- [ ] **Step 4: Run**

```bash
cd frontend && flutter test test/features/jobs/job_copy_test.dart
```

Expected: PASS. Also run existing job/shift tests:

```bash
cd frontend && flutter test test/features/jobs test/features/shifts
```

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/jobs/views \
  frontend/lib/features/jobs/controllers/jobs_controller.dart \
  frontend/lib/features/visits/views/staff_visits_board_view.dart \
  frontend/test/features/jobs/job_copy_test.dart
git commit -m "$(cat <<'EOF'
feat: replace schema jargon on job and roster screens

EOF
)"
```

---

## Task 3: Extract `_generate_one_occurrence` (DRY seam)

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py` (`generate_visits_from_rule`)
- Test: `backend/timesheet-backend/tests/shifts/test_recurrence_generate_shifts.py` (must stay green)

- [ ] **Step 1: Run existing generate tests (baseline)**

```bash
cd backend/timesheet-backend && python -m pytest tests/shifts/test_recurrence_generate_shifts.py tests/jobs/test_recurrence_generate.py -q
```

Expected: PASS.

- [ ] **Step 2: Extract helper used by generate**

Pull the body of `_attempt_one` in `generate_visits_from_rule` to module-level:

```python
async def generate_one_occurrence(
    conn: asyncpg.Connection,
    *,
    tenant_id: UUID,
    job: asyncpg.Record,
    rule: asyncpg.Record,
    start: datetime,
    end: datetime,
    partial: bool,
) -> tuple[UUID | None, UUID | None, str | None]:
    """Return (shift_id, visit_id, skip_detail). skip_detail set when partial skip."""
    existing_shift = await conn.fetchval(
        """
        SELECT id FROM work.shifts
        WHERE recurrence_rule_id = $1
          AND scheduled_start = $2
        """,
        rule["id"],
        start,
    )
    if existing_shift is not None:
        if partial:
            return None, None, "already_generated"
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="visit_already_generated",
        )

    from app.modules.shifts import service as shifts_service
    from asyncpg.exceptions import UniqueViolationError

    try:
        shift_id = await shifts_service.create_published_shift_for_job(
            conn,
            tenant_id=tenant_id,
            job_id=job["id"],
            scheduled_start=start,
            scheduled_end=end,
            required_slots=rule["required_slots"],
            recurrence_rule_id=rule["id"],
        )
    except UniqueViolationError:
        if partial:
            return None, None, "already_generated"
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="visit_already_generated",
        ) from None
    if rule["contractor_id"] is None:
        return shift_id, None, None

    await assert_no_overlap(
        conn,
        tenant_id=tenant_id,
        contractor_id=rule["contractor_id"],
        start=start,
        end=end,
    )
    geofence_mode = job["geofence_mode"]
    geofence_radius = rule["geofence_radius_m_override"] or job["geofence_radius_m"]
    visit_id = await _insert_visit(
        conn,
        tenant_id=tenant_id,
        job_id=job["id"],
        contractor_id=rule["contractor_id"],
        scheduled_start=start,
        scheduled_end=end,
        geofence_radius_m=geofence_radius,
        geofence_mode=geofence_mode,
        source="recurrence",
        recurrence_rule_id=rule["id"],
        task_template=_parse_json_list(rule["task_template_json"]),
        form_requirements=_parse_json_list(rule["form_requirements_json"]),
        lng=float(rule["longitude"]) if rule["longitude"] is not None else None,
        lat=float(rule["latitude"]) if rule["latitude"] is not None else None,
        shift_id=shift_id,
    )
    await conn.execute(
        """
        INSERT INTO work.shift_assignments (
          tenant_id, shift_id, contractor_id, visit_id, source, status
        )
        VALUES ($1, $2, $3, $4, 'staff_assign', 'active')
        """,
        tenant_id,
        shift_id,
        rule["contractor_id"],
        visit_id,
    )
    await _emit_visit_assigned(conn, tenant_id=tenant_id, visit_id=visit_id)
    return shift_id, visit_id, None
```

Rewrite `_attempt_one` to call this helper. Catch `visit_overlap` the same way when `partial`.

Then extract `fill_rule_window` (CQ1A) so Task 4 does **not** copy the expand loop:

```python
@dataclass
class FillWindowResult:
    created_shift_ids: list[UUID]
    created_visit_ids: list[UUID]
    skipped: list[GenerateVisitsConflict]


async def fill_rule_window(
    conn: asyncpg.Connection,
    *,
    tenant_id: UUID,
    job,
    rule,
    window_from: datetime,
    window_to: datetime,
    tenant_tz: str,
    existing: set[tuple] | None = None,
    partial: bool = True,
) -> FillWindowResult:
    job = _job_view(job)
    rule = _rule_view(rule)
    if rule.get("contractor_id") is not None:
        await _assert_active_engagement(
            conn, tenant_id=tenant_id, contractor_id=rule["contractor_id"]
        )
    created_shifts: list[UUID] = []
    created_visits: list[UUID] = []
    skipped: list[GenerateVisitsConflict] = []
    local_existing = set(existing or [])

    if existing is None:
        rows = await conn.fetch(
            """
            SELECT scheduled_start FROM work.shifts
            WHERE recurrence_rule_id = $1
              AND scheduled_start >= $2 AND scheduled_start < $3
            """,
            rule["id"],
            window_from,
            window_to,
        )
        local_existing = {(rule["id"], r["scheduled_start"]) for r in rows}

    starts = recurrence_lib.expand_recurrence_starts(
        rrule_text=rule["rrule"],
        dtstart=rule["dtstart"],
        until=rule["until"],
        window_from=window_from,
        window_to=window_to,
        tenant_timezone=tenant_tz,
    )
    time_windows = sorted(
        _parse_json_list(rule["time_windows_json"]),
        key=lambda window: window["start_time"],
    )
    for occurrence in starts:
        for window in time_windows:
            start, end = recurrence_lib.occurrence_window(
                occurrence,
                start_time=window["start_time"],
                end_time=window["end_time"],
                tenant_timezone=tenant_tz,
            )
            if (rule["id"], start) in local_existing:
                continue
            try:
                shift_id, visit_id, skip = await generate_one_occurrence(
                    conn,
                    tenant_id=tenant_id,
                    job=job,
                    rule=rule,
                    start=start,
                    end=end,
                    partial=partial,
                )
            except HTTPException as exc:
                if partial and exc.detail == "visit_overlap":
                    skipped.append(
                        GenerateVisitsConflict(
                            scheduled_start=start, detail="visit_overlap"
                        )
                    )
                    continue
                raise
            if skip == "already_generated":
                local_existing.add((rule["id"], start))
                continue
            if skip:
                skipped.append(
                    GenerateVisitsConflict(scheduled_start=start, detail=skip)
                )
                continue
            if shift_id:
                created_shifts.append(shift_id)
                local_existing.add((rule["id"], start))
            if visit_id:
                created_visits.append(visit_id)
    return FillWindowResult(created_shifts, created_visits, skipped)
```

`generate_visits_from_rule` after idempotency + 90-day cap + engagement check: call `fill_rule_window`. Do not keep a second expand loop.

- [ ] **Step 3: Re-run generate tests — expect PASS (behavior unchanged)**

```bash
cd backend/timesheet-backend && python -m pytest tests/shifts/test_recurrence_generate_shifts.py tests/jobs/test_recurrence_generate.py -q
```

- [ ] **Step 4: Commit**

```bash
git add backend/timesheet-backend/app/modules/jobs/service.py
git commit -m "$(cat <<'EOF'
refactor: extract generate_one_occurrence for horizon reuse

EOF
)"
```

---

## Task 4: Horizon service + CSO tests

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/schemas.py`
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py`
- Test: `backend/timesheet-backend/tests/jobs/test_horizon.py`

- [ ] **Step 1: Write failing tests**

```python
"""POST /v1/jobs/horizon fills published holes for active rules."""
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

from tests.shifts.conftest import seed_shift_world, staff_token
from tests.shifts.test_recurrence_generate_shifts import TZ


@pytest.mark.asyncio
async def test_horizon_creates_holes_without_contractor(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage', 'shifts.manage', 'shifts.read'])}"
    }
    rule = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules",
        headers=headers,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "required_slots": 1,
        },
    )
    assert rule.status_code == 201, rule.text
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert len(body["created_shift_ids"]) >= 1
    assert body["created_visit_ids"] == []
    again = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert again.status_code == 200
    assert again.json()["created_shift_ids"] == []


@pytest.mark.asyncio
async def test_horizon_rejects_window_over_14_days(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={"from": "2026-08-01T00:00:00+00:00", "to": "2026-08-20T00:00:00+00:00"},
    )
    assert resp.status_code == 400
    assert resp.json()["detail"] == "horizon_window_too_large"


@pytest.mark.asyncio
async def test_horizon_requires_jobs_manage(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['shifts.read'])}"
    }
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-10T00:00:00+00:00"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_horizon_other_tenant_rules_not_filled(client: TestClient, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    headers_a = {
        "Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['jobs.manage'])}"
    }
    client.post(
        f"/v1/jobs/{b['job_id']}/recurrence-rules",
        headers={
            "Authorization": f"Bearer {staff_token(b['admin_user_id'], b['tenant_id'], ['jobs.manage'])}"
        },
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        },
    )
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers_a,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert resp.status_code == 200
    ids = resp.json()["created_shift_ids"]
    for sid in ids:
        row = await db_conn.fetchrow(
            "SELECT tenant_id FROM work.shifts WHERE id = $1", sid
        )
        assert row["tenant_id"] == a["tenant_id"]


@pytest.mark.asyncio
async def test_horizon_empty_rule_ids_422(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={
            "from": "2026-08-03T00:00:00+00:00",
            "to": "2026-08-10T00:00:00+00:00",
            "rule_ids": [],
        },
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_horizon_rule_ids_only_fills_named_rule(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage', 'shifts.read'])}"
    }
    r1 = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules",
        headers=headers,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        },
    )
    r2 = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules",
        headers=headers,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=WE",
            "dtstart": "2026-08-05T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        },
    )
    assert r1.status_code == 201 and r2.status_code == 201
    only = r1.json()["id"]
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={
            "from": "2026-08-03T00:00:00+00:00",
            "to": "2026-08-17T00:00:00+00:00",
            "rule_ids": [only],
        },
    )
    assert resp.status_code == 200
    for sid in resp.json()["created_shift_ids"]:
        row = await db_conn.fetchrow(
            "SELECT recurrence_rule_id FROM work.shifts WHERE id = $1", sid
        )
        assert str(row["recurrence_rule_id"]) == only


@pytest.mark.asyncio
async def test_horizon_foreign_rule_id_not_filled(client: TestClient, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    b_rule = client.post(
        f"/v1/jobs/{b['job_id']}/recurrence-rules",
        headers={
            "Authorization": f"Bearer {staff_token(b['admin_user_id'], b['tenant_id'], ['jobs.manage'])}"
        },
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        },
    )
    assert b_rule.status_code == 201
    resp = client.post(
        "/v1/jobs/horizon",
        headers={
            "Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['jobs.manage'])}"
        },
        json={
            "from": "2026-08-03T00:00:00+00:00",
            "to": "2026-08-17T00:00:00+00:00",
            "rule_ids": [b_rule.json()["id"]],
        },
    )
    assert resp.status_code == 200
    assert resp.json()["created_shift_ids"] == []
    assert resp.json()["rules_processed"] == 0


@pytest.mark.asyncio
async def test_horizon_get_does_not_create_shifts(client: TestClient, db_conn):
    """OV5: GET /jobs/horizon hits GET /jobs/{job_id} (422), not 405. Prove it does not write."""
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    before = await db_conn.fetchval(
        "SELECT count(*) FROM work.shifts WHERE tenant_id = $1", fx["tenant_id"]
    )
    resp = client.get("/v1/jobs/horizon", headers=headers)
    assert resp.status_code in (404, 422)
    after = await db_conn.fetchval(
        "SELECT count(*) FROM work.shifts WHERE tenant_id = $1", fx["tenant_id"]
    )
    assert after == before


@pytest.mark.asyncio
async def test_horizon_contractor_token_403(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {contractor_token(fx['eligible_user_id'], fx['tenant_id'], fx['eligible_contractor_id'])}"
    }
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-10T00:00:00+00:00"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_horizon_inactive_engagement_skips_that_rule(client: TestClient, db_conn):
    """D17: one dead assigned rule must not 500 the tenant fill."""
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    bad = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules",
        headers=headers,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "contractor_id": str(fx["ineligible_contractor_id"]),
        },
    )
    good = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules",
        headers=headers,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=WE",
            "dtstart": "2026-08-05T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        },
    )
    assert bad.status_code == 201 and good.status_code == 201
    resp = client.post(
        "/v1/jobs/horizon",
        headers=headers,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert resp.status_code == 200
    details = {s["detail"] for s in resp.json()["skipped"]}
    assert "engagement_not_active" in details
    assert resp.json()["created_shift_ids"]  # unfilled Wednesday still filled


@pytest.mark.asyncio
async def test_generate_one_occurrence_unique_violation_is_skip(db_conn, monkeypatch):
    """D17: race on shifts_recurrence_occurrence_uidx → already_generated, not 500."""
    from asyncpg.exceptions import UniqueViolationError
    from app.modules.jobs import service as jobs_service
    from app.modules.shifts import service as shifts_service

    async def boom(*_a, **_k):
        raise UniqueViolationError()

    monkeypatch.setattr(
        shifts_service, "create_published_shift_for_job", boom
    )
    fx = await seed_shift_world(db_conn)
    job = {"id": fx["job_id"], "geofence_mode": "informational", "geofence_radius_m": 100}
    rule = {
        "id": fx.get("rule_id") or fx["job_id"],  # use a real rule id from seed if present
        "contractor_id": None,
        "required_slots": 1,
        "geofence_radius_m_override": None,
        "task_template_json": [],
        "form_requirements_json": [],
        "longitude": None,
        "latitude": None,
    }
    # If seed has no rule_id, insert a dummy rule id UUID — UniqueViolation fires before FK on shift insert.
    shift_id, visit_id, skip = await jobs_service.generate_one_occurrence(
        db_conn,
        tenant_id=fx["tenant_id"],
        job=job,
        rule=rule,
        start=datetime(2026, 8, 10, 9, 0, tzinfo=timezone.utc),
        end=datetime(2026, 8, 10, 12, 0, tzinfo=timezone.utc),
        partial=True,
    )
    assert shift_id is None and visit_id is None
    assert skip == "already_generated"
```

Import `contractor_token` from `tests.shifts.conftest`. If seed has no `rule_id`, create one recurrence rule in the test before monkeypatch (the boom only replaces the insert). Prefer a real `rule["id"]` from a 201 create so the existing-shift SELECT is well-formed.

**Truncation (no 201 inserts):** in `test_horizon.py` monkeypatch or call `ensure_horizon` with a fake `conn.fetch` that returns 201 rule rows — assert `truncated is True` and only 200 processed. Do **not** insert 201 rules in CI.

- [ ] **Step 2: Run — expect FAIL (404 route)**

```bash
cd backend/timesheet-backend && python -m pytest tests/jobs/test_horizon.py -q
```

- [ ] **Step 3: Implement schemas + `ensure_horizon`**

```python
# schemas.py
HORIZON_MAX_DAYS = 14

class HorizonRequest(BaseModel):
    from_: datetime = Field(alias="from")
    to: datetime
    rule_ids: list[UUID] | None = None

    @model_validator(mode="after")
    def validate_window(self) -> "HorizonRequest":
        if self.to <= self.from_:
            raise ValueError("to must be after from")
        if self.rule_ids is not None and len(self.rule_ids) == 0:
            raise ValueError("rule_ids_empty")
        if self.rule_ids is not None and len(self.rule_ids) > 200:
            raise ValueError("rule_ids_too_many")
        return self


class HorizonOut(BaseModel):
    created_shift_ids: list[UUID]
    created_visit_ids: list[UUID]
    skipped: list[GenerateVisitsConflict]
    rules_processed: int
    truncated: bool = False
```

```python
HORIZON_MAX_DAYS = 14
HORIZON_MAX_RULES = 200

async def ensure_horizon(
    conn: asyncpg.Connection,
    *,
    tenant_id: UUID,
    body: HorizonRequest,
) -> HorizonOut:
    window_from = ensure_utc(body.from_)
    window_to = ensure_utc(body.to)
    if window_to - window_from > timedelta(days=HORIZON_MAX_DAYS):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="horizon_window_too_large",
        )

    # OV6: if body.rule_ids is not None, add AND r.id = ANY($ids::uuid[])
    # (still AND r.tenant_id = $1). Cap at HORIZON_MAX_RULES; truncated if more.
    # Never SELECT tenant-wide then filter — a named id older than the newest
    # 200 would vanish. Omitted rule_ids → tenant-wide LIMIT 201 as below.
    rules = await conn.fetch(
        """
        SELECT
          r.id, r.tenant_id, r.job_id, r.contractor_id, r.required_slots,
          r.rrule, r.dtstart, r.until, r.time_windows_json,
          r.task_template_json, r.form_requirements_json,
          r.geofence_radius_m_override, r.is_active,
          ST_Y(r.location_override_geog::geometry) AS latitude,
          ST_X(r.location_override_geog::geometry) AS longitude,
          j.id AS job_pk, j.geofence_mode, j.geofence_radius_m
        FROM work.visit_recurrence_rules r
        JOIN work.jobs j ON j.id = r.job_id AND j.tenant_id = r.tenant_id
        WHERE r.tenant_id = $1
          AND r.is_active
          AND j.status = 'open'
          AND ($3::uuid[] IS NULL OR r.id = ANY($3::uuid[]))
        ORDER BY r.created_at, r.id
        LIMIT $2
        """,
        tenant_id,
        HORIZON_MAX_RULES + 1,
        body.rule_ids,
    )
    truncated = len(rules) > HORIZON_MAX_RULES
    rules = rules[:HORIZON_MAX_RULES]
    if not rules:
        return HorizonOut(
            created_shift_ids=[],
            created_visit_ids=[],
            skipped=[],
            rules_processed=0,
            truncated=False,
        )

    rule_ids = [r["id"] for r in rules]
    existing_rows = await conn.fetch(
        """
        SELECT recurrence_rule_id, scheduled_start
        FROM work.shifts
        WHERE tenant_id = $1
          AND recurrence_rule_id = ANY($2::uuid[])
          AND scheduled_start >= $3
          AND scheduled_start < $4
          -- OV2: include cancelled so we do not resurrect cancels
        """,
        tenant_id,
        rule_ids,
        window_from,
        window_to,
    )
    existing = {(row["recurrence_rule_id"], row["scheduled_start"]) for row in existing_rows}

    tenant_tz = await _tenant_timezone(conn, tenant_id)
    created_shifts: list[UUID] = []
    created_visits: list[UUID] = []
    skipped: list[GenerateVisitsConflict] = []

    # CQ1A + OV8: one fill loop. No expand copy here.
    # D17: no wrapping transaction — UniqueViolation on one hole must not
    # abort the connection for the remaining rules.
    for rule in rules:
        job_view = _job_view({
            "id": rule["job_id"],
            "geofence_mode": rule["geofence_mode"],
            "geofence_radius_m": rule["geofence_radius_m"],
        })
        try:
            part = await fill_rule_window(
                conn,
                tenant_id=tenant_id,
                job=job_view,
                rule=rule,
                window_from=window_from,
                window_to=window_to,
                tenant_tz=tenant_tz,
                existing=existing,
                partial=True,
            )
        except HTTPException as exc:
            if exc.detail == "engagement_not_active":
                skipped.append(
                    GenerateVisitsConflict(
                        scheduled_start=window_from,
                        detail="engagement_not_active",
                    )
                )
                continue
            raise
        created_shifts.extend(part.created_shift_ids)
        created_visits.extend(part.created_visit_ids)
        skipped.extend(part.skipped)
        for sid_start in part.created_shift_ids:
            pass  # fill_rule_window already mutated `existing` when passed in

    return HorizonOut(
        created_shift_ids=created_shifts,
        created_visit_ids=created_visits,
        skipped=skipped,
        rules_processed=len(rules),
        truncated=truncated,
    )
```

`fill_rule_window` must add each created `(rule_id, start)` into the shared `existing` set so later rules in the same POST do not double-insert. Pass the same set object (do not copy) — the `set(existing or [])` in the Task 3 snippet is only when `existing is None`; when provided, mutate in place:

```python
local_existing = existing if existing is not None else set()
```

- [ ] **Step 4: Router**

```python
@router.post(
    "/jobs/horizon",
    response_model=HorizonOut,
    dependencies=[Depends(require_active_subscription)],
)
@limiter.limit("10/minute", key_func=authenticated_user_limit_key)
async def post_horizon(
    request: Request,
    body: HorizonRequest,
    pool: Annotated[asyncpg.Pool, Depends(db_pool)],
    payload: Annotated[dict, Depends(require_permission("jobs.manage"))],
) -> HorizonOut:
    tenant_id = tenant_id_from_payload(payload)
    async with pool.acquire() as conn:
        # D17: do NOT wrap ensure_horizon in one transaction.
        return await service.ensure_horizon(
            conn, tenant_id=tenant_id, body=body
        )
```

Import `Request`, `limiter`, `authenticated_user_limit_key` like `shifts/router.py`.

**Transaction choice:** One transaction for the whole horizon can hold locks too long. **Use per-rule transactions** (no outer transaction). Unique index handles races. Update the router to **not** wrap in one transaction; `ensure_horizon` starts `async with conn.transaction():` per rule.

- [ ] **Step 5: Run tests — expect PASS**

```bash
cd backend/timesheet-backend && python -m pytest tests/jobs/test_horizon.py tests/shifts/test_recurrence_generate_shifts.py -q
```

- [ ] **Step 6: Commit**

```bash
git add backend/timesheet-backend/app/modules/jobs/schemas.py \
  backend/timesheet-backend/app/modules/jobs/service.py \
  backend/timesheet-backend/app/modules/jobs/router.py \
  backend/timesheet-backend/tests/jobs/test_horizon.py
git commit -m "$(cat <<'EOF'
feat: add staff horizon endpoint to fill 14 days of shift holes

EOF
)"
```

---

## Task 5: Composite ongoing-support endpoint

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/schemas.py`
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py`
- Modify: `backend/timesheet-backend/app/modules/jobs/router.py`
- Test: `backend/timesheet-backend/tests/jobs/test_ongoing_support.py`

`seed_shift_world` **already inserts one standing job** for `fx["client_id"]`. Happy-path tests must insert a **second** client+site in that tenant with no job. The 409 test uses the fixture client as-is.

Helper in `test_ongoing_support.py`:

```python
async def _extra_client_site(db_conn, tenant_id: uuid.UUID) -> tuple[uuid.UUID, uuid.UUID]:
    client_id = await db_conn.fetchval(
        """
        INSERT INTO clients.clients (tenant_id, full_name, status)
        VALUES ($1, 'Horizon Client', 'active')
        RETURNING id
        """,
        tenant_id,
    )
    site_id = await db_conn.fetchval(
        """
        INSERT INTO clients.client_sites (
          tenant_id, client_id, name, address_line1, city, postal_code, country,
          location_geog
        )
        VALUES ($1, $2, 'Home', '1 Test St', 'Sydney', '2000', 'AU',
                ST_SetSRID(ST_MakePoint(151.2093, -33.8688), 4326)::geography)
        RETURNING id
        """,
        tenant_id,
        client_id,
    )
    return client_id, site_id
```

Match column list to the insert in `seed_shift_world` (copy that INSERT exactly; do not invent columns).

- [ ] **Step 1: Failing tests**

```python
@pytest.mark.asyncio
async def test_ongoing_support_unfilled_creates_job_rule_and_holes(client, db_conn):
    fx = await seed_shift_world(db_conn)
    client_id, site_id = await _extra_client_site(db_conn, fx["tenant_id"])
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage', 'shifts.read'])}"
    }
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(client_id),
            "title": "Sam support",
            "client_site_id": str(site_id),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "required_slots": 2,
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-17T00:00:00+00:00",
        },
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["job"]["kind"] == "standing"
    assert body["job"]["client_id"] == str(client_id)
    assert body["rule"]["contractor_id"] is None
    assert body["rule"]["required_slots"] == 2
    assert len(body["horizon"]["created_shift_ids"]) >= 1
    assert body["horizon"]["created_visit_ids"] == []


@pytest.mark.asyncio
async def test_ongoing_support_assigned_creates_visit_per_occurrence(client, db_conn):
    """Eng review T1A: chosen person → one visit on every hole in the window."""
    fx = await seed_shift_world(db_conn)
    client_id, site_id = await _extra_client_site(db_conn, fx["tenant_id"])
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(client_id),
            "title": "Alex on Sam",
            "client_site_id": str(site_id),
            "contractor_id": str(fx["eligible_contractor_id"]),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "required_slots": 2,
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-17T00:00:00+00:00",
        },
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    shifts = body["horizon"]["created_shift_ids"]
    visits = body["horizon"]["created_visit_ids"]
    assert len(shifts) >= 1
    assert len(visits) == len(shifts)
    for vid in visits:
        row = await db_conn.fetchrow(
            "SELECT contractor_id FROM work.visits WHERE id = $1", vid
        )
        assert row["contractor_id"] == fx["eligible_contractor_id"]


@pytest.mark.asyncio
async def test_ongoing_support_second_call_409(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    before = await db_conn.fetchval(
        "SELECT count(*) FROM work.jobs WHERE client_id = $1 AND kind = 'standing' AND status = 'open'",
        fx["client_id"],
    )
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(fx["client_id"]),
            "title": "Duplicate",
            "client_site_id": str(fx["site_id"]),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-10T00:00:00+00:00",
        },
    )
    assert resp.status_code == 409
    assert resp.json()["detail"] == "standing_job_exists"
    after = await db_conn.fetchval(
        "SELECT count(*) FROM work.jobs WHERE client_id = $1 AND kind = 'standing' AND status = 'open'",
        fx["client_id"],
    )
    assert after == before


@pytest.mark.asyncio
async def test_ongoing_support_site_must_belong_to_client(client, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    extra_id, _ = await _extra_client_site(db_conn, a["tenant_id"])
    headers = {
        "Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(extra_id),
            "title": "Nope",
            "client_site_id": str(b["site_id"]),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-10T00:00:00+00:00",
        },
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_ongoing_support_rolls_back_job_if_rule_invalid(client, db_conn):
    fx = await seed_shift_world(db_conn)
    client_id, site_id = await _extra_client_site(db_conn, fx["tenant_id"])
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(client_id),
            "title": "Bad windows",
            "client_site_id": str(site_id),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [
                {"start_time": "09:00", "end_time": "12:00"},
                {"start_time": "11:00", "end_time": "13:00"},
            ],
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-10T00:00:00+00:00",
        },
    )
    assert resp.status_code == 422
    count = await db_conn.fetchval(
        "SELECT count(*) FROM work.jobs WHERE client_id = $1 AND kind = 'standing'",
        client_id,
    )
    assert count == 0


@pytest.mark.asyncio
async def test_ongoing_support_other_tenant_client_404(client, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    extra_id, extra_site = await _extra_client_site(db_conn, b["tenant_id"])
    headers = {
        "Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(extra_id),
            "title": "Nope",
            "client_site_id": str(extra_site),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-10T00:00:00+00:00",
        },
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_ongoing_support_inactive_engagement_409(client, db_conn):
    fx = await seed_shift_world(db_conn)
    client_id, site_id = await _extra_client_site(db_conn, fx["tenant_id"])
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.post(
        "/v1/jobs/ongoing-support",
        headers=headers,
        json={
            "client_id": str(client_id),
            "title": "Ineligible",
            "client_site_id": str(site_id),
            "contractor_id": str(fx["ineligible_contractor_id"]),
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "horizon_from": "2026-08-03T00:00:00+00:00",
            "horizon_to": "2026-08-10T00:00:00+00:00",
        },
    )
    assert resp.status_code == 409
    count = await db_conn.fetchval(
        "SELECT count(*) FROM work.jobs WHERE client_id = $1 AND kind = 'standing'",
        client_id,
    )
    assert count == 0
```

- [ ] **Step 2: Run — FAIL 404**

- [ ] **Step 3: Schema + service + route**

```python
class OngoingSupportCreate(BaseModel):
    title: str = Field(min_length=1, max_length=512)
    client_site_id: UUID | None = None
    branch_id: UUID | None = None
    geofence_mode: GeofenceMode | None = None
    geofence_radius_m: int | None = Field(default=None, ge=10, le=5000)
    contractor_id: UUID | None = None
    rrule: str = Field(min_length=1)
    dtstart: datetime
    until: datetime | None = None
    required_slots: int = Field(default=1, ge=1, le=8)
    time_windows: list[TimeWindowItem] = Field(min_length=1, max_length=4)
    horizon_from: datetime
    horizon_to: datetime

    @model_validator(mode="after")
    def validate_location_and_horizon(self) -> "OngoingSupportCreate":
        if (self.branch_id is None) == (self.client_site_id is None):
            raise ValueError("exactly one of branch_id or client_site_id is required")
        if self.horizon_to <= self.horizon_from:
            raise ValueError("horizon_to must be after horizon_from")
        return self


class OngoingSupportOut(BaseModel):
    job: JobOut
    rule: RecurrenceRuleOut
    horizon: HorizonOut
```

Reuse `RecurrenceRuleCreate` validators for overlapping windows by constructing one inside the service from the body fields.

```python
async def create_ongoing_support(
    conn: asyncpg.Connection,
    *,
    tenant_id: UUID,
    client_id: UUID,
    body: OngoingSupportCreate,
    actor_user_id: UUID,
) -> OngoingSupportOut:
    client = await conn.fetchval(
        "SELECT id FROM clients.clients WHERE id = $1 AND tenant_id = $2",
        client_id,
        tenant_id,
    )
    if client is None:
        raise HTTPException(status_code=404, detail="client_not_found")

    job_body = JobCreate(
        kind="standing",
        title=body.title,
        client_id=client_id,
        client_site_id=body.client_site_id,
        branch_id=body.branch_id,
        geofence_mode=body.geofence_mode,
        geofence_radius_m=body.geofence_radius_m,
    )
    async with conn.transaction():
        job = await create_job(conn, tenant_id=tenant_id, body=job_body)
        rule_body = RecurrenceRuleCreate(
            contractor_id=body.contractor_id,
            rrule=body.rrule,
            dtstart=body.dtstart,
            until=body.until,
            required_slots=body.required_slots,
            time_windows=body.time_windows,
        )
        rule = await create_recurrence_rule(
            conn,
            tenant_id=tenant_id,
            job_id=job.id,
            body=rule_body,
        )
        window_from = ensure_utc(body.horizon_from)
        window_to = ensure_utc(body.horizon_to)
        if window_to - window_from > timedelta(days=HORIZON_MAX_DAYS):
            raise HTTPException(status_code=400, detail="horizon_window_too_large")
        horizon = await fill_rule_window(
            conn,
            tenant_id=tenant_id,
            job=job,
            rule=rule,
            window_from=window_from,
            window_to=window_to,
        )
    return OngoingSupportOut(job=job, rule=rule, horizon=horizon)
```

**Eng review 1A (locked):** Do **not** call `ensure_horizon` from the composite. That function is tenant-wide and uses per-rule transactions. Nested txn + refill-everyone is the bug. Composite calls `fill_rule_window` for the new rule only.

**OV7:** `fill_rule_window` / `generate_one_occurrence` must not assume asyncpg `Record`. Build a small view first:

```python
def _rule_view(rule) -> dict:
    if isinstance(rule, dict) or hasattr(rule, "keys"):
        get = rule.__getitem__ if not hasattr(rule, "time_windows") else None
    if hasattr(rule, "time_windows"):  # RecurrenceRuleOut
        return {
            "id": rule.id,
            "job_id": rule.job_id,
            "contractor_id": rule.contractor_id,
            "required_slots": rule.required_slots,
            "rrule": rule.rrule,
            "dtstart": rule.dtstart,
            "until": rule.until,
            "time_windows_json": [w.model_dump() for w in rule.time_windows],
        }
    return dict(rule)

def _job_view(job) -> dict:
    if hasattr(job, "geofence_mode"):
        return {"id": job.id, "geofence_mode": job.geofence_mode, "geofence_radius_m": job.geofence_radius_m}
    return {"id": job["id"] if "id" in job else job["job_id"], "geofence_mode": job["geofence_mode"], "geofence_radius_m": job["geofence_radius_m"]}
```

Use `_job_view` / `_rule_view` at the start of `fill_rule_window`. Task 4's inlined expand loop is **deleted** in favor of calling `fill_rule_window` (CQ1A + OV8).

`ensure_horizon` still takes optional `rule_ids`:
- omitted / `null` → tenant-wide active rules (`is_active` + parent job `status='open'`), order `created_at, id`, first 200, `truncated`
- `[]` → 422 `rule_ids_empty` (never treat as tenant-wide)
- explicit list → those ids if they belong to this tenant; same 200 cap; job-detail Fill sends that job's active rule ids

Route (mount on **jobs router** so we do not create a clients/jobs cycle):

`POST /v1/jobs/ongoing-support` with `client_id` in the body is simpler than `/clients/{id}/...` (clients router would import jobs). **Lock D4 amendment:** path is `POST /v1/jobs/ongoing-support` with `client_id` in JSON. Same authz. Tests use this path. Avoids router cycles.

```python
@router.post(
    "/jobs/ongoing-support",
    response_model=OngoingSupportOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_active_subscription)],
)
@limiter.limit("10/minute", key_func=authenticated_user_limit_key)
async def post_ongoing_support(...):
    ...
```

`OngoingSupportCreate` includes `client_id: UUID`.

- [ ] **Step 4: Tests pass**

```bash
cd backend/timesheet-backend && python -m pytest tests/jobs/test_ongoing_support.py tests/jobs/test_horizon.py -q
```

- [ ] **Step 5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: add ongoing-support composite to create job, pattern, and holes

EOF
)"
```

---

## Task 6: Flutter API client for new endpoints

**Files:**
- Modify: `frontend/lib/core/constants/api_paths.dart`
- Modify: `frontend/lib/features/jobs/data/models/job_models.dart`
- Modify: `frontend/lib/features/jobs/data/datasources/jobs_remote_datasource.dart`
- Modify: `frontend/lib/features/jobs/data/repositories/jobs_repository.dart`
- Test: `frontend/test/features/jobs/job_models_test.dart`

- [ ] **Step 1: Parse tests for `HorizonOut` / `OngoingSupportOut`**

```dart
test('parses horizon and ongoing-support payloads', () {
  final horizon = HorizonOut.fromJson({
    'created_shift_ids': ['s1'],
    'created_visit_ids': <String>[],
    'skipped': [
      {'scheduled_start': '2026-08-10T09:00:00Z', 'detail': 'visit_overlap'},
    ],
    'rules_processed': 1,
    'truncated': false,
  });
  expect(horizon.createdShiftIds, ['s1']);
  expect(horizon.skipped.first.detail, 'visit_overlap');
});
```

- [ ] **Step 2: Implement paths + Dio**

```dart
// api_paths.dart
static const jobsHorizon = '$_v1/jobs/horizon';
static const jobsOngoingSupport = '$_v1/jobs/ongoing-support';
```

Repository methods: `ensureHorizon`, `createOngoingSupport`. Dio POST, map errors through existing interceptor/`AppFailure`.

- [ ] **Step 3: Tests pass + commit**

```bash
cd frontend && flutter test test/features/jobs/job_models_test.dart
```

---

## Task 7: Ongoing support composer (UI)

**Files:**
- Create: `frontend/lib/features/jobs/controllers/ongoing_support_controller.dart`
- Create: `frontend/lib/features/jobs/views/ongoing_support_view.dart`
- Modify: `frontend/lib/app/routes/app_routes.dart` (`staffOngoingSupport = '/staff/jobs/ongoing-support'`)
- Modify: `frontend/lib/features/jobs/jobs_routes.dart`
- Modify: `frontend/lib/features/jobs/bindings/jobs_binding.dart` if needed
- Test: `frontend/test/features/jobs/ongoing_support_controller_test.dart`

- [ ] **Step 1: Controller test (mocktail)**

```dart
test('submit posts unfilled ongoing support and does not call createJob', () async {
  when(() => jobs.createOngoingSupport(any())).thenAnswer((_) async => fakeOut);
  await controller.submit();
  verify(() => jobs.createOngoingSupport(any())).called(1);
  verifyNever(() => jobs.createJob(any()));
});

test('submit blocked when client has no sites and mode is home', () async {
  controller.sites.clear();
  await controller.submit();
  expect(controller.errorMessage.value, contains('Add a site'));
  verifyNever(() => jobs.createOngoingSupport(any()));
});

test('submit with branch posts branchId and no clientSiteId', () async {
  controller.locationMode.value = 'branch';
  controller.selectedBranchId.value = 'branch-1';
  when(() => jobs.createOngoingSupport(any())).thenAnswer((_) async => fakeOut);
  await controller.submit();
  final captured = verify(() => jobs.createOngoingSupport(captureAny())).captured.single
      as OngoingSupportCreateRequest;
  expect(captured.branchId, 'branch-1');
  expect(captured.clientSiteId, isNull);
});

test('branch mode blocked when branches empty', () async {
  controller.locationMode.value = 'branch';
  controller.branches.clear();
  await controller.submit();
  expect(controller.errorMessage.value, contains('branch'));
  verifyNever(() => jobs.createOngoingSupport(any()));
});
```

Register fallback values for `OngoingSupportCreateRequest`.

- [ ] **Step 2: Implement controller**

Constructor args: `JobsRepository`, `ClientsRepository`, `EngagementsRepository` (optional worker list), `SessionService`. `onInit` reads `Get.arguments` as `ClientOut` (required). Loads sites via `ClientsRepository.listSites(client.id)`. Loads branches via `JobsRepository.listBranches()` (D18, same as `JobsController.loadJobs`). Catch branch load failure → `branches.clear()`.

Fields: titleCtrl (seed `defaultOngoingTitle(client.fullName)`), locationMode (`site` default), selectedSiteId, selectedBranchId, frequency/weekdays/start/end (copy from `RecurrenceRuleFormController` field types), requiredSlots=1, selectedContractorId=null, isSaving, errorMessage.

`horizonFrom` = now UTC, `horizonTo` = now+14d.

Submit: validate site/branch; `compileRecurrenceRrule`; POST `createOngoingSupport`; `Get.offNamed(AppRoutes.staffVisits, arguments: {'client_id': client.id})`.

- [ ] **Step 3: View**

Scaffold AppBar `Start ongoing support`. ListView: error box, title, where dropdown (copy helpers), site or branch dropdown, repeats + weekday chips (copy from recurrence form), start/end `TextField` `09:00` / `12:00`, needs N, worker optional Unfilled, primary button `Save and fill roster`.

No XOR helper text. If sites empty and mode home: amber box + no submit. If branches empty: Branch item disabled or hidden; amber “No branches in this organisation” when mode is branch.

- [ ] **Step 4: Tests pass + commit**

```bash
cd frontend && flutter test test/features/jobs/ongoing_support_controller_test.dart
```

---

## Task 8: Client CTAs + book one session

**Files:**
- Create: `frontend/lib/features/clients/widgets/client_detail_support_section.dart`
- Modify: `frontend/lib/features/clients/views/client_detail_view.dart`
- Modify: `frontend/lib/features/clients/controllers/clients_controller.dart`
- Modify: `frontend/lib/features/jobs/views/job_detail_view.dart` (Book one session)
- Modify: `frontend/lib/features/shifts/...` already has create shift — reuse roster dialog or a small method on `StaffVisitsController`
- Test: `frontend/test/features/clients/client_detail_support_section_test.dart`

- [ ] **Step 1: Widget test**

```dart
testWidgets('shows Start ongoing when no standing job', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: ClientDetailSupportSection(
      hasOngoing: false,
      canManage: true,
      onStartOngoing: () {},
      onBookOne: () {},
      onOpenOngoing: () {},
    ),
  ));
  expect(find.text('Start ongoing support'), findsOneWidget);
  expect(find.text('Book one session'), findsNothing);
});

testWidgets('book one session enabled when ongoing exists', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: ClientDetailSupportSection(
      hasOngoing: true,
      canManage: true,
      onStartOngoing: () {},
      onBookOne: () {},
      onOpenOngoing: () {},
    ),
  ));
  expect(find.text('Book one session'), findsOneWidget);
  expect(find.text('Start ongoing support'), findsNothing);
  expect(find.text('Open support'), findsOneWidget);
});
```

- [ ] **Step 2: ClientsController loads standing job**

`GET /v1/jobs` already returns all; filter `kind==standing && status==open && clientId==selected.id`. YAGNI: no new list filter this slice unless list is huge. If `jobs.length == 100` and standing is old, it can miss — **add `client_id` query on GET /v1/jobs`** (small, do it here).

Backend:

```python
@router.get("/jobs")
async def list_jobs(..., client_id: UUID | None = None, kind: str | None = None, job_status: str | None = Query(default=None, alias="status")):
```

Service adds `AND ($3::uuid IS NULL OR j.client_id = $3)` etc.

Test: list with `client_id` returns only that client's jobs.

Flutter: `listJobs(clientId: id, kind: 'standing')`.

- [ ] **Step 3: Wire section into client detail** above visits section.

`onStartOngoing` → `Get.toNamed(AppRoutes.staffOngoingSupport, arguments: client)`.
`onOpenOngoing` → existing `JobsController.openDetail`.
`onBookOne` → `Get.toNamed(AppRoutes.staffVisits)` then open create-shift dialog with `jobId` preselected **or** navigate to roster with args `{job_id, create: true}`. Extend `_showCreateShiftDialog` to read args. Default status `published`.

- [ ] **Step 4: Tests + commit**

```bash
cd frontend && flutter test test/features/clients/client_detail_support_section_test.dart
cd backend/timesheet-backend && python -m pytest tests/jobs/test_list_jobs_filters.py -q
```

---

## Task 9: Roster calls horizon (background)

**Files:**
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart`
- Modify: `frontend/lib/features/visits/bindings/visits_binding.dart` (inject JobsRepository if missing)
- Test: `frontend/test/features/visits/staff_roster_horizon_test.dart`

- [ ] **Step 1: Controller test**

```dart
test('ensureBoardLoaded posts horizon when jobs.manage and does not block empty list', () async {
  when(() => session.hasPermission(AppPermissions.jobsManage)).thenReturn(true);
  when(() => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to'), jobId: any(named: 'jobId')))
      .thenAnswer((_) async => <ShiftOut>[]);
  when(() => jobs.ensureHorizon(any())).thenAnswer((_) async => HorizonOut.empty);
  await controller.ensureBoardLoaded();
  verify(() => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to'), jobId: any(named: 'jobId'))).called(1);
  verify(() => jobs.ensureHorizon(any())).called(1);
});

test('ensureBoardLoaded skips horizon without jobs.manage', () async {
  when(() => session.hasPermission(AppPermissions.jobsManage)).thenReturn(false);
  when(() => shifts.listShifts(from: any(named: 'from'), to: any(named: 'to'), jobId: any(named: 'jobId')))
      .thenAnswer((_) async => <ShiftOut>[]);
  await controller.ensureBoardLoaded();
  verifyNever(() => jobs.ensureHorizon(any()));
});

test('second ensureBoardLoaded while horizon in flight does not double POST', () async {
  final gate = Completer<HorizonOut>();
  when(() => jobs.ensureHorizon(any())).thenAnswer((_) => gate.future);
  unawaited(controller.ensureBoardLoaded());
  unawaited(controller.ensureBoardLoaded());
  await Future<void>.delayed(Duration.zero);
  verify(() => jobs.ensureHorizon(any())).called(1);
  gate.complete(HorizonOut(createdShiftIds: [], createdVisitIds: [], skipped: [], rulesProcessed: 0, truncated: false));
});

test('skipHorizonOnce from composer land does not POST', () async {
  controller.skipHorizonOnce = true;
  await controller.ensureBoardLoaded();
  verifyNever(() => jobs.ensureHorizon(any()));
  expect(controller.skipHorizonOnce, isFalse);
});

test('cooldown skips a second POST within 60s', () async {
  when(() => jobs.ensureHorizon(any())).thenAnswer(
    (_) async => HorizonOut(createdShiftIds: [], createdVisitIds: [], skipped: [], rulesProcessed: 0, truncated: false),
  );
  await controller.ensureBoardLoaded();
  await controller.ensureBoardLoaded();
  verify(() => jobs.ensureHorizon(any())).called(1);
});

test('snackbar only when createdShiftIds is non-empty', () async {
  when(() => jobs.ensureHorizon(any())).thenAnswer(
    (_) async => HorizonOut(
      createdShiftIds: [],
      createdVisitIds: [],
      skipped: [GenerateVisitsConflict(scheduledStart: DateTime.utc(2026, 8, 10), detail: 'visit_overlap')],
      rulesProcessed: 1,
      truncated: false,
    ),
  );
  var snackbars = 0;
  // inject a snackbar spy on the controller (or wrap Get.snackbar behind _notifyRosterUpdated)
  await controller.ensureBoardLoaded();
  expect(controller.horizonSnackCount, 0); // listShifts already ran once in load(); no second load
  expect(snackbars, 0);
});

test('horizon 5xx does not set errorMessage after list painted', () async {
  when(() => jobs.ensureHorizon(any())).thenThrow(
    AppFailure(code: 'server_error', message: 'horizon exploded'),
  );
  await controller.ensureBoardLoaded();
  expect(controller.errorMessage.value, isNull);
});
```

Expose `horizonSnackCount` only in tests, or extract `_notifyRosterUpdated(int created)` and verify it was not called when `created == 0`. Prefer a tiny method over GetX snackbar mocking.

- [ ] **Step 2: Implement**

```dart
final isFillingHorizon = false.obs;
bool _horizonInFlight = false;
bool skipHorizonOnce = false;
DateTime? _horizonLastAttempt;

Future<void> ensureBoardLoaded() async {
  await loadJobs();
  await loadEngagements();
  await load(); // existing listShifts paints first
  if (skipHorizonOnce) {
    skipHorizonOnce = false;
    return;
  }
  unawaited(_fillHorizon());
}

Future<void> _fillHorizon() async {
  if (_horizonInFlight) return;
  if (!_session.hasPermission(AppPermissions.jobsManage)) return;
  final last = _horizonLastAttempt;
  if (last != null && DateTime.now().difference(last) < const Duration(seconds: 60)) {
    return;
  }
  _horizonInFlight = true;
  isFillingHorizon.value = true;
  _horizonLastAttempt = DateTime.now();
  try {
    final result = await _jobsRepository.ensureHorizon(
      HorizonRequest(
        from: _horizonFromUtc, // start of today UTC (or tenant TZ once exposed)
        to: _horizonToUtc, // +14d half-open; NOT _fromUtc/_toUtc (visible week)
      ),
    );
    final created = result.createdShiftIds.length;
    if (created > 0) {
      await load();
      Get.snackbar('Roster updated', '$created new time${created == 1 ? '' : 's'} added.');
    }
  } on AppFailure catch (e) {
    // OV8: do not set errorMessage — listShifts already painted.
    // 429: existing mapped toast only. Other failures: silent + optional debug log.
    if (e.code != 'rate_limited') {
      // leave errorMessage alone
    }
  } finally {
    _horizonInFlight = false;
    isFillingHorizon.value = false;
  }
}
```

Composer success: `Get.offNamed(AppRoutes.staffVisits, arguments: {'skipHorizonOnce': true, 'job_id': createdJobId, 'client_id': clientId})`. Do **not** `Get.find<StaffVisitsController>()` before the roster binding exists.

`applyRouteArgs` (extend existing job_id reader in `staff_visits_controller.dart:75-85`):

```dart
if (args['skipHorizonOnce'] == true) skipHorizonOnce = true;
if (args['client_id'] != null) {
  // D9: filter job dropdown / list to this client's jobs (ids already on loadJobs)
  pendingClientIdFilter = args['client_id'].toString();
}
```

Job-detail "Fill next 14 days" calls `ensureHorizon(HorizonRequest(..., ruleIds: jobActiveRuleIds))`. Hide the button if the job has no active rules.

Board: under the week chrome, `if (controller.isFillingHorizon.value) const LinearProgressIndicator(minHeight: 2)`.

Week chevrons: `shiftRange` → `load` then `_fillHorizon` (same in-flight + 60s cooldown).

- [ ] **Step 3: Tests pass + commit**

```bash
cd frontend && flutter test test/features/visits/staff_roster_horizon_test.dart test/features/shifts
```

---

## Task 10: Manual smoke (no new code)

- [ ] Staff with `jobs.manage`: new client with a site → Start ongoing → Unfilled Mondays → land on Roster → amber cards appear (after progress bar).
- [ ] Same client → Start ongoing again → inline “already has ongoing support”.
- [ ] Staff with only `shifts.read`: roster lists existing shifts, no horizon POST (proxy/log).
- [ ] Contractor Open tab: new holes appear and Claim still works (existing claim tests + one manual).
- [ ] Job form / list: no “XOR”, “standing”, “Generate (14d)”.
- [ ] No site on client: composer blocks with add-site message.

---

## Test Plan & Verification

**Coverage target:** ≥90% lines on new `ensure_horizon`, `create_ongoing_support`, `generate_one_occurrence`; every new public route has authz + window + tenant tests. Flutter: copy helpers 100%; composer submit/block paths; horizon in-flight + permission skip.

**Critical paths (must pass before ship):**
- Unfilled ongoing support → published holes, zero visits → `test_ongoing_support_unfilled_creates_job_rule_and_holes` + contractor claim still green
- Assigned ongoing support → visit per occurrence → `test_ongoing_support_assigned_creates_visit_per_occurrence`
- Second ongoing support → 409, one standing job → `test_ongoing_support_second_call_409`
- Horizon idempotent → `test_horizon_creates_holes_without_contractor` second POST empty
- Read-only cannot mutate → `test_horizon_requires_jobs_manage`
- Cross-tenant site → 404 → `test_ongoing_support_site_must_belong_to_client`
- Roster does not wait on horizon → controller test paints list first

**Edge cases & error paths:**
- Window >14d → 400 `horizon_window_too_large` → horizon test
- Overlapping time_windows on create → 422 + no job row → rollback test
- Overlap skip → skipped `visit_overlap`, other rules still fill
- 201st active rule → `truncated: true`
- 429 on horizon → roster stays usable, no error banner
- Empty sites → composer does not POST
- Empty branches + mode branch → composer does not POST
- `contractor_id` set + inactive engagement on **composite** → 409, transaction rolls back
- Inactive engagement on **one horizon rule** → 200, that rule skipped, others fill → `test_horizon_inactive_engagement_skips_that_rule`
- UniqueViolation on occurrence insert → `already_generated`, HTTP 200 → `test_generate_one_occurrence_unique_violation_is_skip`
- Horizon 5xx after paint → `errorMessage` stays null → `horizon 5xx does not set errorMessage`

**Regression guards:**
- Generate-with-contractor still fills one slot → `test_generate_with_contractor_fills_one_slot`
- Claim TOCTOU / eligibility → existing `tests/shifts/test_shift_claim.py`
- Job XOR still enforced in DB → existing create_job tests
- Manual `POST /v1/shifts` still works for book-one-session

**Verification commands:**
- Unit backend: `cd backend/timesheet-backend && python -m pytest tests/jobs/test_horizon.py tests/jobs/test_ongoing_support.py tests/shifts/test_recurrence_generate_shifts.py tests/shifts/test_shift_claim.py tests/jobs/test_recurrence_generate.py -q` — expected: all pass
- Coverage: `cd backend/timesheet-backend && python -m pytest tests/jobs/test_horizon.py tests/jobs/test_ongoing_support.py --cov=app.modules.jobs.service --cov-report=term-missing` — expected: ≥90% on new functions
- Unit Flutter: `cd frontend && flutter test test/features/jobs test/features/visits/staff_roster_horizon_test.dart test/features/clients/client_detail_support_section_test.dart test/core/errors/app_failure_test.dart` — expected: all pass
- E2E: Task 10 manual on the running `flutter run` + API

**Acceptance criteria (from spec):**
- [ ] Coordinator can start repeating unfilled support without saying Job / Recurrence / Generate → Tasks 7–9
- [ ] No RecurrentShift type → D2, no migration
- [ ] Holes appear on roster without Generate (14d) → Tasks 4, 9
- [ ] Schema jargon gone from job/roster glass → Tasks 1–2
- [ ] Read-only staff cannot fill horizon → Task 4 authz test
- [ ] Composite is one transaction (no orphan standing job) → Task 5 rollback test
- [ ] People grid / this-future / sick-day not built → out of scope

---

## What already exists

| Need | Existing | Plan |
|------|----------|------|
| Insert published hole | `create_published_shift_for_job` + `shifts_recurrence_occurrence_uidx` | Reuse via `generate_one_occurrence` |
| Expand rrule | `recurrence_lib.expand_recurrence_starts` + `generate_visits_from_rule` | `fill_rule_window` wraps this; Generate stays a thin wrapper |
| Unfilled N slots | V021 `required_slots` + nullable `contractor_id` | No new type |
| One standing job | `jobs_one_open_standing_per_client` | 409 `standing_job_exists` |
| Overlap | `assert_no_overlap` | Assigned path only |
| Rate limit | `limiter` + `authenticated_user_limit_key` on shifts | Same 10/minute on both new POSTs |
| Authz | `require_permission("jobs.manage")` | Both new routes |
| Book one session | `POST /v1/shifts` | Reuse; no new create |
| Copy/XOR | Hardcoded in `job_form_view` / `jobs_controller` | `job_copy.dart` + language pass |
| Client list of jobs | `GET /v1/jobs` has no `client_id` today | Add query in Task 8 |

Do not rebuild claim, pay, or visit insert.

## Failure modes

| Path | Production failure | Test | Handling | User sees |
|------|--------------------|------|----------|-----------|
| Composite | Rule validators fail mid-txn | rollback test | txn abort | Inline 422, no job |
| Composite | Second manager 409 | unique index + 409 test | no second job | Open existing support |
| Composite assigned | Inactive engagement | 409 test | txn abort | Friendly copy |
| Horizon | Two managers same second | occurrence uidx + partial | second created=[] | Nothing / skipOnce |
| Horizon | Window >14d | 400 test | reject | Mapped toast |
| Horizon | 201+ rules | truncated stub | first 200 | No “all filled” toast |
| Horizon | 429 | skipped (T2A) | AppFailure rate_limited | Existing toast, roster usable |
| Roster | Horizon 5xx after paint | controller catch | list stays | No banner (D17) |
| Roster | User leaves mid-fill | ignore if disposed | no setState | Nothing |
| GET horizon | Accidental read-write | no-write test | not a write route | 404/422, zero shifts |
| Horizon race | UniqueViolation | catch → already_generated | 200 | Nothing |
| Horizon assigned dead | engagement_not_active | skip that rule | 200 + others fill | Nothing |

No silent-and-untested critical gap remaining except 429 (explicitly skipped).

## Worktree parallelization

| Step | Modules | Depends on |
|------|---------|------------|
| Copy helpers + language pass | `frontend/lib/features/jobs`, `shared/utils` | — |
| Extract `fill_rule_window` + horizon + composite | `backend/.../jobs` | — |
| Flutter DTOs + composer + client CTAs | `frontend/lib/features/jobs`, `clients` | backend routes for integration |
| Roster `_fillHorizon` | `frontend/lib/features/visits` | Flutter jobs repository |

Lane A: Task 1 → Task 2 (frontend copy; sequential, shared jobs views)
Lane B: Task 3 → Task 4 → Task 5 (backend; sequential, shared jobs/service.py)
Lane C: Task 6 → Task 7 → Task 8 (frontend composer; waits on B for live API, not for unit tests)
Lane D: Task 9 roster (touches visits; after Task 6 repository)

Execution: Launch A + B in parallel. Merge B. Then C + D. Conflict flag: C and A both touch job views — merge A first or keep language pass off composer files.

Sequential implementation is also fine (one worktree): Tasks 1–10 as written.

## Implementation Tasks

Synthesized from this review's findings. Each task derives from a specific
finding above. Run with Claude Code or Codex; checkbox as you ship.

_No new tasks from scope challenge (D1 + D19 keep steal 1–3)._

- [ ] **T1 (P1, human: ~2h / CC: ~20min)** — jobs/service — Extract `fill_rule_window` as the only expand loop
  - Surfaced by: Code quality CQ1A + OV8 — Task 4 must not copy expand; Generate becomes a thin wrapper
  - Files: `backend/timesheet-backend/app/modules/jobs/service.py`
  - Verify: `python -m pytest tests/shifts/test_recurrence_generate_shifts.py tests/jobs/test_recurrence_generate.py -q`

- [ ] **T2 (P1, human: ~1h / CC: ~15min)** — jobs/service — `_job_view` / `_rule_view` adapter
  - Surfaced by: Outside voice OV7 — `fill_rule_window` must accept Record or Pydantic
  - Files: `backend/timesheet-backend/app/modules/jobs/service.py`
  - Verify: composite + horizon tests both call the same helper

- [ ] **T3 (P1, human: ~2h / CC: ~20min)** — horizon — Prefetch including cancelled; `rule_ids` via `ANY($3)`
  - Surfaced by: Performance P1A + OV2 + OV6 — no per-hole SELECT; do not resurrect cancels; named ids must not vanish past LIMIT 200
  - Files: `backend/timesheet-backend/app/modules/jobs/service.py`, `tests/jobs/test_horizon.py`
  - Verify: `python -m pytest tests/jobs/test_horizon.py -q`

- [ ] **T4 (P1, human: ~1.5h / CC: ~15min)** — horizon — UniqueViolation → skip; no router txn; dead engagement skips that rule
  - Surfaced by: Outside voice OV8 / D17 — concurrent 500 and one inactive worker aborting 199 rules
  - Files: `backend/timesheet-backend/app/modules/jobs/service.py`, `backend/timesheet-backend/app/modules/jobs/router.py`, `tests/jobs/test_horizon.py`
  - Verify: `test_generate_one_occurrence_unique_violation_is_skip` + `test_horizon_inactive_engagement_skips_that_rule`

- [ ] **T5 (P1, human: ~45min / CC: ~10min)** — jobs/router — GET `/jobs/horizon` must not write
  - Surfaced by: CSO + OV5 — FastAPI UUID route returns 422, not 405
  - Files: `backend/timesheet-backend/tests/jobs/test_horizon.py`
  - Verify: `test_horizon_get_does_not_create_shifts`

- [ ] **T6 (P1, human: ~2h / CC: ~20min)** — composer — Load branches like `JobsController`; home still `listSites`
  - Surfaced by: Outside voice OV9 / D18 — branch-only clients cannot Save
  - Files: `frontend/lib/features/jobs/controllers/ongoing_support_controller.dart`, `frontend/lib/features/jobs/views/ongoing_support_view.dart`, `frontend/test/features/jobs/ongoing_support_controller_test.dart`
  - Verify: `flutter test test/features/jobs/ongoing_support_controller_test.dart`

- [ ] **T7 (P1, human: ~1.5h / CC: ~15min)** — roster — Paint first; `[startOfToday, +14d)`; skipOnce + job_id + client_id; no `errorMessage` on horizon 5xx
  - Surfaced by: Smooth UI 4A + OV1 + OV3 + OV4 + D17
  - Files: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`, `frontend/test/features/visits/staff_roster_horizon_test.dart`
  - Verify: `flutter test test/features/visits/staff_roster_horizon_test.dart`

- [ ] **T8 (P2, human: ~30min / CC: ~5min)** — composite — Call `fill_rule_window` for the new rule only; never nest `ensure_horizon`
  - Surfaced by: Architecture 1A — nested txn + refill-everyone
  - Files: `backend/timesheet-backend/app/modules/jobs/service.py`, `tests/jobs/test_ongoing_support.py`
  - Verify: `python -m pytest tests/jobs/test_ongoing_support.py -q`

_P3 follow-ups live in `TODOS.md` (tenant TZ on Flutter, horizon cron). Not this PR._

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 2 | CLEAR (PLAN) | 16 issues, 0 critical gaps; D12–D19 folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | Office-hours design approved 2026-08-13 (not this skill) |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |
| Outside Voice | `/plan-eng-review` | Independent plan critique | 1 | issues_found → walked | OV1–OV10 folded or rejected (wedge kept) |

- **VERDICT:** ENG CLEARED — ready to implement. Design already approved via office-hours. CEO optional for the product wedge, not required to code.

NO UNRESOLVED DECISIONS
