# People×Day Roster Board (Steal 4–7) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Staff open Roster and see a people × day board (with an Unfilled row), can release a sick worker into a hole with notify, assign from a busy/free picker, edit this/future pattern windows, and read visit status on tiles — without rewriting Job/Shift/Visit tables.

**Architecture:** Keep `GET /v1/shifts` as the tile source. Add a staff-scoped roster overlay (leave + availability) and visit status on assignment DTOs. Flutter replaces the week `ListView` with a day-column grid built from the same `ShiftOut` list + engagements — **staff laptop/web primary**. Series edit (“this and future”) splits the recurrence rule (`until` + cancel old future + new rule + fill). Sick-day reuses `POST …/unassign`; open-slot notify is a new `shift.slot_opened` event to eligible contractors (**mobile** Open/claim). Staff interaction: tap/click assign + busy/free; no drag in this slice unless eng review reopens it.

**Tech Stack:** PostgreSQL, FastAPI + asyncpg + Pydantic v2, existing `limiter` / `require_permission` / notification events, Flutter/GetX/Dio/mocktail, existing `ShiftSlotPips` / `formatRosterStamp` / horizon fill.

**Locked decisions:**
- D1: This plan is steal 4–7 only. Steal 1–3 already shipped (language, composer, auto-horizon). No RecurrentShift. No Job/Shift/Visit table rewrite.
- D2: Day columns, not hour columns (V021 hour-grid stays YAGNI on phones). Desktop hour view is out of scope.
- D3: Unfilled is a first-class **row**, not only amber card colour. Tiles with `open_slots > 0` appear on Unfilled and also on each assigned worker’s row when partially filled.
- D4: Client filter is a first-class dropdown (not soft job_id only). Filter shifts client-side from `ShiftOut.clientId` (jobs already carry client).
- D5: Staff leave/availability for the visible week via new `GET /v1/workforce/roster-overlay` (`shifts.read`). Reuses `workforce.contractor_leave` + `contractor_availability_rules`. No contractor self-serve change.
- D6: Visit status on tiles = `visit_status` on each active `ShiftAssignmentOut` (join visits). Values: `scheduled | checked_in | completed | cancelled`. Empty hole = no visit badge.
- D7: Sick-day = staff **Unassign** (existing `POST /v1/shifts/{id}/unassign`) + emit `shift.slot_opened` to eligible contractors. Wire Flutter unassign. No drag-and-drop this slice (tap Assign with busy/free).
- D8: “This occurrence” edit/cancel = existing single-shift cancel / book-one recreate. “This and future” = set `rule.until` to day before occurrence (tenant TZ) + insert new rule from that date with edited windows. “Copy tile” = `POST /v1/shifts` on same job at chosen start/end.
- D9: Assign picker shows leave / unavailable / already assigned for that day (from overlay + existing assignments). Still blocks leave via server claim/assign guards.
- D10: Reuse `AppColors`. No DESIGN.md. Keep Jobs nav (demote still deferred). Tenant TZ for day chips: expose `timezone` from existing tenant/me payload (TODOS P2 folded here).
- D11: Horizontal scroll for day columns on phone; sticky first column (worker name). Week chevrons keep ±7d visible list; horizon fill stays `[today, +14d)` from steal 1–3.
- D12: `contractor_availability_rules.day_of_week` is **0=Monday … 6=Sunday** (Flutter `schedule_models.dart` API contract). Map with `int dowFromDate(DateTime d) => d.weekday - 1;` (`DateTime.monday == 1`).
- D13: Notify table is `org.notification_events` via `insert_event`. Count events with `event_type = 'shift.slot_opened'`.
- D14: Ship steals 4–7 as **one vertical slice / one branch** (eng review D1 → A). Parallel backend/frontend lanes OK; do not cut board-only first.
- D15: **This and future** = in one transaction: set old `rule.until` → **cancel** old-rule future shifts/visits from `from_date` (tenant TZ) whose visits are only `scheduled` (or unassigned holes) → insert new rule → `fill_rule_window` for new rule only. Past tiles untouched. If any old-rule occurrence from `from_date` has visit `checked_in`/`completed`, **409** and roll back (no silent half-edit). No back-compat / migration for live tenants — greenfield OK.
- D16: People rows = **all assignable engagements** (same set as Assign sheet: active/approved/pending_docs), sorted by name; Unfilled first. Overlay covers that set (cap 500 + `truncated`). Eng review D3 → A.
- D17: **Platform split** — Staff/admin Roster is **laptop/web primary**. Contractor Open/claim/notify is **mobile primary**. Staff board UI may use wider day columns and denser chrome; do not optimize staff grid for phone thumbs. Contractor-facing surfaces stay thumb-friendly (existing Open tab; no staff-board drag required for contractor).
- D18: **No drag** in steals 4–7 (eng review D4 → A). Staff uses click/tap + dialogs/sheets (Release, Assign Busy/Free/Leave, pattern actions). Drag deferred to a later plan.
- D19: Confirm **day columns only** (eng review D5 → A). No hour axis / AM-PM lanes / desktop Gantt in this slice. Tile time text is enough.
- D20: Overlay load is **best-effort** (eng review D6 → A). Shifts failure → board error. Overlay failure → empty overlay + soft banner “Leave/availability unavailable”; grid still renders from shifts. Do not `Future.wait` without per-future error isolation.
- D21: `shift.slot_opened` recipients = **eligible open-shift contractors only** (eng review D7 → A), exclude released worker, cap 50. Dedicated `OPEN_SHIFT_CONTRACTOR_EVENT_TYPES` policy branch — must not fall through to management or `notifications.receive` default. Staff rely on Unfilled row, not push.

---

## Out of scope

- Hour-level grid / Gantt
- Drag-and-drop reassign (D18 — deferred; tap/click assign covers Flow C)
- Demoting Jobs from staff nav
- Cron/worker for horizon (TODOS P3)
- Dropping `jobs_one_open_standing_per_client`
- Contractor Open-tab redesign / maps (steal 7 canvas “contractor list” maps fix deferred)
- Editing past / invoiced visits
- Multi-week infinite scroll

---

## Domain (unchanged nouns)

```text
Client → Ongoing support (standing job)
       → Patterns (recurrence rules)
       → Board tiles (published shifts)
            ├── Unfilled row (open_slots > 0)
            └── Person rows (active assignments)
                 └── Visit status on the assignment
```

**Sick-day flow (steal 6):**

```text
Jane's tile → Release
→ unassign (assignment released, visit cancelled if scheduled)
→ open_slots++
→ shift.slot_opened → eligible contractors
→ tile also on Unfilled; Assign Ali (busy/free picker) or wait for Claim
```

**This and future (steal 5):**

```text
Monday tile → Edit pattern → This and future
→ rule.until = day-before (tenant TZ)
→ new rule from that Monday with new windows/person
→ ensure_horizon for the new rule only (rule_ids)
→ past tiles untouched
```

---

## Trust boundary (CSO)

New staff reads (overlay) and writes (series split, unassign UI, notify). Crosses tenant data (leave, PII names). No public routes. No contractor self-serve change beyond receiving notify.

| Threat | Control | Test |
|--------|---------|------|
| IDOR roster-overlay other tenant | `tenant_id` from JWT on every SELECT; only engaged contractors of this tenant | other-tenant UUID never appears |
| Leave leak for non-engaged people | Overlay limited to contractors with active/approved engagement in tenant | ended engagement excluded |
| Unassign without manage | `shifts.manage` on unassign (already) | `shifts.read` → 403 |
| Series split without manage | `jobs.manage` on pattern split endpoint | 403 |
| Open-slot notify spam / IDOR | Emit only to eligible open-shift candidates (D21); rate limit unassign 10/min; policy branch before catch-all | contractor without eligibility gets no event; management-only user not in recipients |
| Slot_opened catch-all leak | Never rely on default `notifications.receive` list for this event type | unit/integration: resolve_recipients returns only eligible contractor user_ids |
| Client filter IDOR | Client filter is client-side on already-authorized shift list; no new cross-tenant path | — |
| Visit status over-share | Staff with `shifts.read` already see assignments; status is attendance not clinical notes | other-tenant shift 404 |

---

## Efficiency

- One `GET /shifts` + one `GET /roster-overlay` per week load (parallel). Do not N+1 leave per row.
- Overlay returns only contractors that appear in engagements for the tenant (cap 500).
- Grid builds in memory from `ShiftOut` — no per-cell API.
- Series split calls `fill_rule_window` / horizon with `rule_ids=[new_rule]` only (D14 from steal 1–3).
- Visit status joined in the existing assignment SELECT (one extra column), not a second query per shift.

## Smooth UI

- **Staff = laptop/web (D17):** board uses available width; day columns ~140–160px; sticky name column ~140px; mouse/trackpad scroll OK. Do not ship a phone-cramped staff layout.
- **Contractor = mobile (D17):** Open-tab / claim / slot_opened notify remain thumb-first; no change to require desktop for contractors.
- First paint: existing list path must not regress while grid lands; feature behind replacing the board body in the same route.
- Sticky worker column; day headers `Mon 10`; tiles show client short name + time + pips + visit chip.
- Unfilled row always first (amber tint via `AppColors`).
- Leave cells: muted “leave”; unavailable AM/PM as secondary text (from availability rules for that `day_of_week`).
- Release confirm sheet: “Release Jane? Hole opens for claim.” Then snackbar if notify sent.
- Assign sheet: list assignable engagements with trailing Busy / Leave / Free (keyboard-friendly list, not a tiny bottom sheet only — `Dialog`/`side` OK on wide web).
- Edit pattern sheet: This one / This and future / Copy to… (three actions, not a jargon form).
- Empty week: “No shifts this week.” Keep 2px horizon progress from steal 1–3.
- Trial note: do not show all jobs as if filters selected when none chosen — default filter **All clients** + **Live** (published) only; draft hidden unless status filter set.

---

## File structure

| File | SRP | Seam |
|------|-----|------|
| `backend/timesheet-backend/app/modules/workforce/schemas.py` (+ `service_roster.py`, `router.py`) | Staff week leave+availability DTO | `GET /v1/workforce/roster-overlay` |
| `backend/timesheet-backend/app/modules/shifts/schemas.py` + assignment SELECT | `visit_status` on `ShiftAssignmentOut` | List/detail JSON |
| `backend/timesheet-backend/app/modules/jobs/service.py` (+ schemas/router) | `split_recurrence_from` (until + new rule + fill) | `POST …/recurrence-rules/{id}/split-from` |
| `backend/timesheet-backend/app/modules/notifications/event_types.py` (+ shifts unassign path) | `shift.slot_opened` builder | Emit from unassign when open_slots becomes >0 |
| `frontend/lib/features/visits/roster/roster_grid_model.dart` | Pure: shifts+overlay → rows/cells | No GetX |
| `frontend/lib/features/visits/roster/roster_grid_view.dart` | People×day widgets | Takes model + callbacks |
| `frontend/lib/features/visits/controllers/staff_visits_controller.dart` | Load shifts+overlay; filters; actions | Existing controller |
| `frontend/lib/features/visits/views/staff_visits_board_view.dart` | Host grid + filters + sheets | Replace ListView body |
| `frontend/lib/features/shifts/data/models/shift_models.dart` | Parse `visitStatus` | DTO |
| `frontend/lib/features/shifts/data/datasources/shifts_remote_datasource.dart` | `unassignShift` | Wire existing path |

**DRY:** Reuse `_release_assignment`, claim open-shift eligibility SQL for notify recipients, `formatRosterStamp`, `ShiftSlotPips`, `fill_rule_window` via horizon `rule_ids`, engagements list for people rows.

**YAGNI:** No drag. No hour grid. No new occurrence table. No Jobs nav demotion.

---

## Task 1: Roster overlay API (leave + availability)

**Files:**
- Create: `backend/timesheet-backend/app/modules/workforce/schemas.py` (if module missing, put under `shifts/schemas.py` as `RosterOverlayOut` — prefer `workforce` package next to contractor_schedule tables)
- Create: `backend/timesheet-backend/app/modules/workforce/service_roster.py`
- Create: `backend/timesheet-backend/app/modules/workforce/router.py` (or extend an existing staff router; register in app)
- Test: `backend/timesheet-backend/tests/workforce/test_roster_overlay.py`

- [ ] **Step 1: Write failing tests**

```python
@pytest.mark.asyncio
async def test_roster_overlay_returns_leave_for_engaged_contractor(client, db_conn):
    fx = await seed_shift_world(db_conn)
    await db_conn.execute(
        """
        INSERT INTO workforce.contractor_leave (contractor_id, start_date, end_date, leave_type)
        VALUES ($1, '2026-08-13', '2026-08-13', 'sick')
        """,
        fx["eligible_contractor_id"],
    )
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['shifts.read'])}"
    }
    resp = client.get(
        "/v1/workforce/roster-overlay",
        headers=headers,
        params={"from": "2026-08-10T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert any(
        r["contractor_id"] == str(fx["eligible_contractor_id"])
        and any(l["leave_type"] == "sick" for l in r["leave"])
        for r in body["contractors"]
    )


@pytest.mark.asyncio
async def test_roster_overlay_excludes_other_tenant(client, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    await db_conn.execute(
        """
        INSERT INTO workforce.contractor_leave (contractor_id, start_date, end_date, leave_type)
        VALUES ($1, '2026-08-13', '2026-08-13', 'sick')
        """,
        b["eligible_contractor_id"],
    )
    headers = {
        "Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['shifts.read'])}"
    }
    resp = client.get(
        "/v1/workforce/roster-overlay",
        headers=headers,
        params={"from": "2026-08-10T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert resp.status_code == 200
    ids = {c["contractor_id"] for c in resp.json()["contractors"]}
    assert str(b["eligible_contractor_id"]) not in ids


@pytest.mark.asyncio
async def test_roster_overlay_requires_shifts_read(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    resp = client.get(
        "/v1/workforce/roster-overlay",
        headers=headers,
        params={"from": "2026-08-10T00:00:00+00:00", "to": "2026-08-17T00:00:00+00:00"},
    )
    assert resp.status_code == 403
```

- [ ] **Step 2: Run — expect FAIL (404 route)**

```bash
cd backend/timesheet-backend && python -m pytest tests/workforce/test_roster_overlay.py -q
```

- [ ] **Step 3: Minimal implementation**

```python
# schemas
class LeaveIntervalOut(BaseModel):
    start_date: date
    end_date: date
    leave_type: str

class AvailabilityRuleOut(BaseModel):
    day_of_week: int  # 0=Mon .. 6=Sun (match existing contractor-me; verify seed)
    start_time: time
    end_time: time

class ContractorRosterOverlay(BaseModel):
    contractor_id: UUID
    display_name: str
    leave: list[LeaveIntervalOut]
    availability: list[AvailabilityRuleOut]

class RosterOverlayOut(BaseModel):
    contractors: list[ContractorRosterOverlay]
    truncated: bool = False
```

```python
async def get_roster_overlay(conn, *, tenant_id: UUID, window_from: datetime, window_to: datetime) -> RosterOverlayOut:
    if window_to <= window_from:
        raise HTTPException(status_code=400, detail="invalid_window")
    if window_to - window_from > timedelta(days=31):
        raise HTTPException(status_code=400, detail="overlay_window_too_large")
    d_from = window_from.date()
    d_to = window_to.date()
    people = await conn.fetch(
        """
        SELECT c.id AS contractor_id,
               COALESCE(NULLIF(trim(c.full_name), ''), 'Worker') AS display_name
        FROM payroll.engagements e
        JOIN workforce.contractors c ON c.id = e.contractor_id
        WHERE e.tenant_id = $1
          AND e.status IN ('active', 'approved', 'pending_docs')
        ORDER BY display_name, c.id
        LIMIT 501
        """,
        tenant_id,
    )
    truncated = len(people) > 500
    people = people[:500]
    ids = [r["contractor_id"] for r in people]
    if not ids:
        return RosterOverlayOut(contractors=[], truncated=False)
    leave_rows = await conn.fetch(
        """
        SELECT contractor_id, start_date, end_date, leave_type
        FROM workforce.contractor_leave
        WHERE contractor_id = ANY($1::uuid[])
          AND start_date < $3::date
          AND end_date >= $2::date
        """,
        ids,
        d_from,
        d_to,
    )
    avail_rows = await conn.fetch(
        """
        SELECT contractor_id, day_of_week, start_time, end_time
        FROM workforce.contractor_availability_rules
        WHERE contractor_id = ANY($1::uuid[])
        """,
        ids,
    )
    leave_by: dict[UUID, list] = {}
    for row in leave_rows:
        leave_by.setdefault(row["contractor_id"], []).append(
            LeaveIntervalOut(
                start_date=row["start_date"],
                end_date=row["end_date"],
                leave_type=row["leave_type"],
            )
        )
    avail_by: dict[UUID, list] = {}
    for row in avail_rows:
        avail_by.setdefault(row["contractor_id"], []).append(
            AvailabilityRuleOut(
                day_of_week=row["day_of_week"],
                start_time=row["start_time"],
                end_time=row["end_time"],
            )
        )
    return RosterOverlayOut(
        contractors=[
            ContractorRosterOverlay(
                contractor_id=p["contractor_id"],
                display_name=p["display_name"],
                leave=leave_by.get(p["contractor_id"], []),
                availability=avail_by.get(p["contractor_id"], []),
            )
            for p in people
        ],
        truncated=truncated,
    )
```

DRY: contractor label is `workforce.contractors.full_name` (same as `_SHIFT_SELECT` assignment join).

Router: `require_any_permission("shifts.read", "shifts.manage")`, `limiter` 30/minute.

- [ ] **Step 4: Tests pass + commit**

```bash
cd backend/timesheet-backend && python -m pytest tests/workforce/test_roster_overlay.py -q
git add timesheet-backend/app/modules/workforce timesheet-backend/tests/workforce
git commit -m "$(cat <<'EOF'
feat: add staff roster overlay for leave and availability

EOF
)"
```

---

## Task 2: Visit status on shift assignments

**Files:**
- Modify: `backend/timesheet-backend/app/modules/shifts/schemas.py`
- Modify: `backend/timesheet-backend/app/modules/shifts/service.py` (assignment SELECT)
- Test: `backend/timesheet-backend/tests/shifts/test_shift_list_visit_status.py`

- [ ] **Step 1: Failing test**

```python
@pytest.mark.asyncio
async def test_list_shifts_includes_visit_status_on_assignments(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['shifts.manage', 'shifts.read'])}"
    }
    shift = client.post(
        "/v1/shifts",
        headers=headers,
        json={
            "job_id": str(fx["job_id"]),
            "scheduled_start": "2026-08-20T09:00:00+00:00",
            "scheduled_end": "2026-08-20T12:00:00+00:00",
            "required_slots": 1,
            "status": "published",
        },
    ).json()
    assigned = client.post(
        f"/v1/shifts/{shift['id']}/assign",
        headers=headers,
        json={"contractor_id": str(fx["eligible_contractor_id"])},
    )
    assert assigned.status_code == 201
    resp = client.get(
        "/v1/shifts",
        headers=headers,
        params={"from": "2026-08-01T00:00:00+00:00", "to": "2026-08-31T00:00:00+00:00"},
    )
    assert resp.status_code == 200
    row = next(s for s in resp.json() if s["id"] == shift["id"])
    assert row["assignments"][0]["visit_status"] == "scheduled"
```

- [ ] **Step 2: Run — expect FAIL (key missing)**

- [ ] **Step 3: Implementation**

```python
class ShiftAssignmentOut(BaseModel):
    id: UUID
    contractor_id: UUID
    contractor_name: str
    visit_id: UUID
    source: AssignmentSource
    status: AssignmentStatus
    visit_status: Literal["scheduled", "checked_in", "completed", "cancelled"] | None = None
```

Join `v.status AS visit_status` in the assignment lateral/select used by `_shift_out` / list.

Also expose `recurrence_rule_id: UUID | None` on `ShiftOut` (column already on `work.shifts`) so Task 9’s “This and future” can find the rule from a tile without a second fetch. Add assert in the same list test:

```python
assert "recurrence_rule_id" in row  # may be null for book-one
```

- [ ] **Step 4: Pass + commit**

```bash
git commit -m "$(cat <<'EOF'
feat: expose visit_status on shift assignment DTOs

EOF
)"
```

---

## Task 3: Flutter DTOs + overlay client + unassign

**Files:**
- Modify: `frontend/lib/features/shifts/data/models/shift_models.dart`
- Modify: `frontend/lib/core/constants/api_paths.dart`
- Modify: `frontend/lib/features/shifts/data/datasources/shifts_remote_datasource.dart`
- Modify: `frontend/lib/features/shifts/data/repositories/shifts_repository.dart`
- Create: `frontend/lib/features/visits/data/models/roster_overlay_models.dart`
- Create or extend datasource for overlay (visits or workforce remote)
- Test: `frontend/test/features/shifts/shift_models_test.dart`
- Test: `frontend/test/features/visits/roster_overlay_models_test.dart`

- [ ] **Step 1: Parse tests**

```dart
test('ShiftOut parses recurrenceRuleId and visitStatus on assignments', () {
  final s = ShiftOut.fromJson({
    'id': 's1',
    'tenant_id': 't',
    'job_id': 'j',
    'job_title': 'Support',
    'client_id': 'c',
    'client_name': 'Pat',
    'scheduled_start': '2026-08-20T09:00:00+00:00',
    'scheduled_end': '2026-08-20T12:00:00+00:00',
    'required_slots': 1,
    'open_slots': 0,
    'status': 'published',
    'recurrence_rule_id': 'rule-1',
    'assignments': [
      {
        'id': 'a1',
        'contractor_id': 'c1',
        'contractor_name': 'Jane',
        'visit_id': 'v1',
        'source': 'staff_assign',
        'status': 'active',
        'visit_status': 'checked_in',
      },
    ],
    'created_at': '2026-08-01T00:00:00+00:00',
    'updated_at': '2026-08-01T00:00:00+00:00',
  });
  expect(s.recurrenceRuleId, 'rule-1');
  expect(s.assignments.first.visitStatus, 'checked_in');
});

test('RosterOverlayOut parses leave', () {
  final o = RosterOverlayOut.fromJson({
    'contractors': [
      {
        'contractor_id': 'c1',
        'display_name': 'Jane',
        'leave': [
          {'start_date': '2026-08-13', 'end_date': '2026-08-13', 'leave_type': 'sick'},
        ],
        'availability': [
          {'day_of_week': 0, 'start_time': '09:00:00', 'end_time': '17:00:00'},
        ],
      },
    ],
    'truncated': false,
  });
  expect(o.contractors.first.leave.first.leaveType, 'sick');
});
```

- [ ] **Step 2: Implement models + `unassignShift` + `fetchRosterOverlay`**

```dart
// api_paths.dart
static const workforceRosterOverlay = '$_v1/workforce/roster-overlay';
// shiftsUnassign already exists — wire remote:

Future<ShiftOut> unassignShift(String shiftId, String contractorId) async {
  final response = await _dio.post<Map<String, dynamic>>(
    ApiPaths.shiftUnassign(shiftId),
    data: {'contractor_id': contractorId},
  );
  return ShiftOut.fromJson(_require(response.data));
}
```

- [ ] **Step 3: Pass + commit**

```bash
cd frontend && flutter test test/features/shifts/shift_models_test.dart test/features/visits/roster_overlay_models_test.dart
git commit -m "$(cat <<'EOF'
feat: add roster overlay and visitStatus Flutter DTOs

EOF
)"
```

---

## Task 4: Pure roster grid model (TDD)

**Files:**
- Create: `frontend/lib/features/visits/roster/roster_grid_model.dart`
- Test: `frontend/test/features/visits/roster_grid_model_test.dart`

- [ ] **Step 1: Failing tests**

```dart
test('builds Unfilled row first and places open-slot tiles', () {
  final monday = DateTime(2026, 8, 10, 9);
  final shift = ShiftOut(
    id: 's1',
    tenantId: 't',
    jobId: 'j',
    jobTitle: 'Sam support',
    clientId: 'cl',
    clientName: 'Sam',
    scheduledStart: monday,
    scheduledEnd: monday.add(const Duration(hours: 3)),
    requiredSlots: 2,
    openSlots: 1,
    status: 'published',
    assignments: [
      ShiftAssignmentOut(
        id: 'a1',
        contractorId: 'jane',
        contractorName: 'Jane',
        visitId: 'v1',
        source: 'staff_assign',
        status: 'active',
        visitStatus: 'scheduled',
      ),
    ],
    createdAt: monday,
    updatedAt: monday,
  );
  final grid = buildRosterGrid(
    rangeStart: DateTime(2026, 8, 10),
    dayCount: 5,
    shifts: [shift],
    people: const [
      RosterPerson(contractorId: 'jane', displayName: 'Jane'),
      RosterPerson(contractorId: 'ali', displayName: 'Ali'),
    ],
    overlay: RosterOverlayOut(contractors: const []),
  );
  expect(grid.rows.first.id, 'unfilled');
  expect(grid.rows.first.cells[0].tiles, isNotEmpty);
  final jane = grid.rows.firstWhere((r) => r.id == 'jane');
  expect(jane.cells[0].tiles.single.clientName, 'Sam');
});

test('leave marks cell on person row', () {
  final grid = buildRosterGrid(
    rangeStart: DateTime(2026, 8, 10),
    dayCount: 5,
    shifts: const [],
    people: const [RosterPerson(contractorId: 'jane', displayName: 'Jane')],
    overlay: RosterOverlayOut(contractors: [
      ContractorRosterOverlay(
        contractorId: 'jane',
        displayName: 'Jane',
        leave: [
          LeaveInterval(startDate: DateTime(2026, 8, 13), endDate: DateTime(2026, 8, 13), leaveType: 'sick'),
        ],
        availability: const [],
      ),
    ]),
  );
  final jane = grid.rows.firstWhere((r) => r.id == 'jane');
  expect(jane.cells[3].onLeave, isTrue); // Thu 13
});

test('client filter drops other clients', () {
  // two shifts different clientId; filter 'cl-a' → only those tiles
});
```

- [ ] **Step 2: Run — expect FAIL**

```bash
cd frontend && flutter test test/features/visits/roster_grid_model_test.dart
```

- [ ] **Step 3: Implement pure model**

```dart
class RosterPerson {
  const RosterPerson({required this.contractorId, required this.displayName});
  final String contractorId;
  final String displayName;
}

class RosterTile {
  const RosterTile({
    required this.shiftId,
    required this.clientName,
    required this.start,
    required this.end,
    required this.openSlots,
    required this.requiredSlots,
    this.visitStatus,
    this.assignmentContractorId,
  });
  final String shiftId;
  final String clientName;
  final DateTime start;
  final DateTime end;
  final int openSlots;
  final int requiredSlots;
  final String? visitStatus;
  final String? assignmentContractorId;
}

class RosterCell {
  const RosterCell({this.tiles = const [], this.onLeave = false, this.availabilityHint});
  final List<RosterTile> tiles;
  final bool onLeave;
  final String? availabilityHint;
}

class RosterRow {
  const RosterRow({required this.id, required this.label, required this.cells, this.isUnfilled = false});
  final String id;
  final String label;
  final List<RosterCell> cells;
  final bool isUnfilled;
}

class RosterGrid {
  const RosterGrid({required this.dayStarts, required this.rows});
  final List<DateTime> dayStarts;
  final List<RosterRow> rows;
}

RosterGrid buildRosterGrid({
  required DateTime rangeStart,
  required int dayCount,
  required List<ShiftOut> shifts,
  required List<RosterPerson> people,
  required RosterOverlayOut overlay,
  String? clientIdFilter,
}) {
  // 1. dayStarts = startOfDay for rangeStart .. +dayCount
  // 2. filter published (+ optional clientId)
  // 3. Unfilled row: tiles where openSlots > 0 placed by day index
  // 4. Person rows: tiles where assignment.contractorId matches; partially filled also on Unfilled
  // 5. overlay leave / availability hints per cell
}
```

- [ ] **Step 4: Pass + commit**

```bash
git commit -m "$(cat <<'EOF'
feat: add pure people-by-day roster grid model

EOF
)"
```

---

## Task 5: Board UI — grid + client filter + visit chips

**Files:**
- Create: `frontend/lib/features/visits/roster/roster_grid_view.dart`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart`
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`
- Test: `frontend/test/features/visits/roster_grid_view_test.dart`
- Test: extend `staff_roster_horizon_test.dart` / board tests (paint-first still holds)

- [ ] **Step 1: Widget test — Unfilled label visible**

```dart
testWidgets('shows Unfilled row and day headers', (tester) async {
  final monday = DateTime(2026, 8, 10);
  final grid = buildRosterGrid(
    rangeStart: monday,
    dayCount: 5,
    shifts: const [],
    people: const [RosterPerson(contractorId: 'jane', displayName: 'Jane')],
    overlay: const RosterOverlayOut(contractors: []),
  );
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: RosterGridView(
        grid: grid,
        onTileTap: (_) {},
      ),
    ),
  ));
  expect(find.text('Unfilled'), findsOneWidget);
  expect(find.textContaining('Mon'), findsWidgets);
});
```

- [ ] **Step 2: Controller — load overlay in parallel with shifts; clientIdFilter; default status published**

```dart
final clientIdFilter = ''.obs;
final overlay = Rxn<RosterOverlayOut>();
final overlayWarning = RxnString(); // soft banner when overlay fails
// Change default: statusFilter.value = 'published';

Future<void> load() async {
  isLoading.value = true;
  errorMessage.value = null;
  overlayWarning.value = null;
  try {
    final from = _fromUtc;
    final to = _toUtc;
    // D20: isolate overlay failure from shifts
    final shiftsFuture = _shiftsRepository.listShifts(
      from: from,
      to: to,
      jobId: jobIdFilter.value.trim().isEmpty ? null : jobIdFilter.value.trim(),
    );
    final overlayFuture = _overlayRepository
        .fetchRosterOverlay(from: from, to: to)
        .then<RosterOverlayOut?>((v) => v)
        .catchError((Object _) {
      overlayWarning.value = 'Leave/availability unavailable';
      return null;
    });
    final listRaw = await shiftsFuture;
    var list = listRaw;
    if (statusFilter.value.isNotEmpty) {
      list = list.where((s) => s.status == statusFilter.value).toList();
    }
    list.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
    shifts.assignAll(list);
    overlay.value = await overlayFuture ?? const RosterOverlayOut(contractors: []);
  } on AppFailure catch (e) {
    errorMessage.value = e.message;
  } finally {
    isLoading.value = false;
  }
}

RosterGrid get grid {
  final start = DateTime(rangeStart.value.year, rangeStart.value.month, rangeStart.value.day);
  final people = assignableEngagements
      .map((e) => RosterPerson(contractorId: e.contractorId, displayName: e.contractorName))
      .toList()
    ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return buildRosterGrid(
    rangeStart: start,
    dayCount: 7,
    shifts: shifts.toList(),
    people: people,
    overlay: overlay.value ?? const RosterOverlayOut(contractors: []),
    clientIdFilter: clientIdFilter.value.isEmpty ? null : clientIdFilter.value,
  );
}
```

Default `statusFilter` = `published` (fixes trial “all statuses appear”). Client dropdown built from unique non-null `clientId`/`clientName` on `jobs` and `shifts`.

Expose tenant TZ if available on session; else device local for day boundaries (Task 10).

- [ ] **Step 3: Replace ListView body with `RosterGridView`**

Layout: horizontal `SingleChildScrollView` with sticky name column (~112px) + day columns (~120px). Tile: client name, `formatRosterStamp` time-only or `09:00`, `ShiftSlotPips`, visit chip (`Live`/`In`/`Done` from visit_status). Tap → existing shift detail.

Keep week chrome, horizon 2px bar, FAB book-one.

- [ ] **Step 4: Pass tests + commit**

```bash
cd frontend && flutter test test/features/visits/
git commit -m "$(cat <<'EOF'
feat: replace roster list with people-by-day board

EOF
)"
```

---

## Task 6: Release (unassign) + slot-opened notify

**Files:**
- Modify: `backend/timesheet-backend/app/modules/notifications/event_types.py`
- Modify: `backend/timesheet-backend/app/modules/notifications/service.py` (+ recipient policy)
- Modify: `backend/timesheet-backend/app/modules/shifts/service.py` (`unassign_contractor` / `_release_assignment`)
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart` (tile Release action)
- Test: `backend/timesheet-backend/tests/shifts/test_unassign_notifies_open_slot.py`
- Test: `frontend/test/features/visits/staff_release_test.dart`

- [ ] **Step 1: Backend failing test**

```python
@pytest.mark.asyncio
async def test_unassign_emits_slot_opened_when_hole_remains(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['shifts.manage'])}"
    }
    shift = client.post(
        "/v1/shifts",
        headers=headers,
        json={
            "job_id": str(fx["job_id"]),
            "scheduled_start": "2026-08-20T09:00:00+00:00",
            "scheduled_end": "2026-08-20T12:00:00+00:00",
            "required_slots": 1,
            "status": "published",
        },
    ).json()
    assert client.post(
        f"/v1/shifts/{shift['id']}/assign",
        headers=headers,
        json={"contractor_id": str(fx["eligible_contractor_id"])},
    ).status_code == 201
    before = await db_conn.fetchval(
        "SELECT count(*) FROM org.notification_events WHERE event_type = 'shift.slot_opened' AND tenant_id = $1",
        fx["tenant_id"],
    )
    resp = client.post(
        f"/v1/shifts/{shift['id']}/unassign",
        headers=headers,
        json={"contractor_id": str(fx["eligible_contractor_id"])},
    )
    assert resp.status_code == 200
    assert resp.json()["open_slots"] >= 1
    after = await db_conn.fetchval(
        "SELECT count(*) FROM org.notification_events WHERE event_type = 'shift.slot_opened' AND tenant_id = $1",
        fx["tenant_id"],
    )
    assert after == before + 1
```

Also add (D21):

```python
@pytest.mark.asyncio
async def test_slot_opened_recipients_eligible_contractors_only(db_conn):
    fx = await seed_shift_world(db_conn)
    # Arrange: published open shift after release; build payload as unassign would.
    # Act:
    from app.modules.notifications.recipient_policies import resolve_recipients_for_event
    recipients = await resolve_recipients_for_event(
        db_conn,
        tenant_id=fx["tenant_id"],
        _event_type="shift.slot_opened",
        payload={
            "shift_id": str(fx["open_shift_id"]),
            "released_contractor_id": str(fx["eligible_contractor_id"]),
        },
        entity_id=fx["open_shift_id"],
    )
    assert fx["admin_user_id"] not in recipients
    assert all(uid != fx.get("released_user_id") for uid in recipients)
    assert len(recipients) <= 50
```

Use seed fields available in `seed_shift_world` (adjust names to fixture). Run with the unassign integration test so an event exists if delivery rows are asserted.

- [ ] **Step 2: Implement `shift.slot_opened` (event + recipient policy)**

Existing notify stack: `insert_event` → `resolve_recipients_for_event` → push. Recipients are **not** passed on the event create — they come from policy. `visit.assigned` today fans out to **management** (`VISIT_TENANT_EVENT_TYPES`), not the assignee. Slot-opened must **not** fall through to “everyone with notifications.receive”.

```python
# event_types.py
NotificationEventType.SHIFT_SLOT_OPENED = "shift.slot_opened"
OPEN_SHIFT_CONTRACTOR_EVENT_TYPES = frozenset({NotificationEventType.SHIFT_SLOT_OPENED.value})

def build_shift_slot_opened_event(
    *,
    shift_id: UUID,
    job_title: str,
    client_name: str | None,
    scheduled_start: datetime,
    released_contractor_id: UUID,
) -> NotificationEventCreate:
    return NotificationEventCreate(
        event_type=NotificationEventType.SHIFT_SLOT_OPENED.value,
        entity_type="shift",
        entity_id=shift_id,
        actor_user_id=None,
        payload={
            "shift_id": str(shift_id),
            "job_title": job_title,
            "scheduled_start": scheduled_start.isoformat(),
            "released_contractor_id": str(released_contractor_id),
            **({"client_name": client_name} if client_name else {}),
        },
    )
```

```python
# recipient_policies.py — new branch BEFORE the default catch-all
if _event_type in OPEN_SHIFT_CONTRACTOR_EVENT_TYPES:
    shift_id = entity_id or UUID(str(payload["shift_id"]))
    released = UUID(str(payload["released_contractor_id"]))
    user_ids = await _eligible_open_shift_user_ids(conn, tenant_id=tenant_id, shift_id=shift_id)
    return [u for u in user_ids if u != await _contractor_user_id(conn, released)][:50]
```

```python
# shifts/service.py after successful unassign when open_slots > 0:
await insert_event(
    conn,
    tenant_id=tenant_id,
    event=build_shift_slot_opened_event(
        shift_id=shift_id,
        job_title=meta["job_title"],
        client_name=meta["client_name"],
        scheduled_start=meta["scheduled_start"],
        released_contractor_id=released_contractor_id,
    ),
)
```

DRY: `_eligible_open_shift_user_ids` shares eligibility filters with `list_open_shifts` (factor helper; do not duplicate SQL). Cap 50. Confirm unassign limiter ≥10/min.

- [ ] **Step 3: Flutter Release action**

Tile menu / detail: **Release** if `shifts.manage` and active assignment. Confirm dialog. Call `unassignShift`. Refresh board. Snackbar: “Hole opened — eligible workers notified.” On 409 `invalid_visit_status`: “Already checked in — cancel visit first.”

- [ ] **Step 4: Pass + commit**

```bash
git commit -m "$(cat <<'EOF'
feat: release to Unfilled and notify eligible contractors

EOF
)"
```

---

## Task 7: Assign picker shows busy / leave / free

**Files:**
- Modify: `frontend/lib/features/visits/views/staff_shift_detail_view.dart` (or sheet from grid)
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`
- Test: `frontend/test/features/visits/assign_picker_busy_test.dart`

- [ ] **Step 1: Unit test ranking**

```dart
test('assign candidates mark leave and overlapping shift as busy', () {
  final day = DateTime(2026, 8, 13);
  final shiftStart = DateTime(2026, 8, 13, 9);
  final shiftEnd = DateTime(2026, 8, 13, 12);
  final overlay = RosterOverlayOut(contractors: [
    ContractorRosterOverlay(
      contractorId: 'jane',
      displayName: 'Jane',
      leave: [
        LeaveInterval(startDate: day, endDate: day, leaveType: 'sick'),
      ],
      availability: const [],
    ),
  ]);
  final busyShift = ShiftOut(
    id: 's-busy',
    tenantId: 't',
    jobId: 'j',
    jobTitle: 'Other',
    clientId: 'c',
    clientName: 'Pat',
    scheduledStart: shiftStart,
    scheduledEnd: shiftEnd,
    requiredSlots: 1,
    openSlots: 0,
    status: 'published',
    assignments: [
      ShiftAssignmentOut(
        id: 'a',
        contractorId: 'ali',
        contractorName: 'Ali',
        visitId: 'v',
        source: 'staff_assign',
        status: 'active',
      ),
    ],
    createdAt: day,
    updatedAt: day,
  );
  expect(
    assignAvailabilityLabel(
      contractorId: 'jane',
      day: day,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      overlay: overlay,
      shifts: [busyShift],
    ),
    'Leave',
  );
  expect(
    assignAvailabilityLabel(
      contractorId: 'ali',
      day: day,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      overlay: overlay,
      shifts: [busyShift],
    ),
    'Busy',
  );
  expect(
    assignAvailabilityLabel(
      contractorId: 'mo',
      day: day,
      shiftStart: shiftStart,
      shiftEnd: shiftEnd,
      overlay: overlay,
      shifts: [busyShift],
    ),
    'Free',
  );
});
```

- [ ] **Step 2: Implement pure helper + wire Assign sheet**

```dart
String assignAvailabilityLabel({
  required String contractorId,
  required DateTime day,
  required DateTime shiftStart,
  required DateTime shiftEnd,
  required RosterOverlayOut overlay,
  required List<ShiftOut> shifts,
}) {
  final civil = DateTime(day.year, day.month, day.day);
  for (final c in overlay.contractors) {
    if (c.contractorId != contractorId) continue;
    for (final leave in c.leave) {
      final start = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final end = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      if (!civil.isBefore(start) && !civil.isAfter(end)) return 'Leave';
    }
  }
  for (final s in shifts) {
    if (s.status == 'cancelled') continue;
    final overlaps = s.scheduledStart.isBefore(shiftEnd) && s.scheduledEnd.isAfter(shiftStart);
    if (!overlaps) continue;
    for (final a in s.assignments) {
      if (a.status == 'active' && a.contractorId == contractorId) return 'Busy';
    }
  }
  return 'Free';
}
```

Sheet: ListTile name + trailing label; Leave/Busy still tappable but confirm “Assign anyway?” (server remains source of truth for leave 409).
- [ ] **Step 3: Pass + commit**

```bash
git commit -m "$(cat <<'EOF'
feat: show leave and busy state in roster assign picker

EOF
)"
```

---

## Task 8: Copy tile + this-occurrence cancel (steal 5 partial)

**Files:**
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart` (tile action sheet)
- Reuse: existing `createShift` / `cancelShift` on shifts repository
- Test: `frontend/test/features/visits/staff_copy_cancel_test.dart`

- [ ] **Step 1: Tests**

```dart
test('copyTile posts new shift on same job', () async {
  when(() => shifts.createShift(any())).thenAnswer((_) async => copied);
  await controller.copyTile(
    source: shift,
    start: DateTime(2026, 8, 14, 9),
    end: DateTime(2026, 8, 14, 12),
  );
  final req = verify(() => shifts.createShift(captureAny())).captured.single as ShiftCreate;
  expect(req.jobId, shift.jobId);
  expect(req.status, 'published');
  expect(req.requiredSlots, shift.requiredSlots);
});

test('cancelThisOccurrence calls cancelShift', () async {
  when(() => shifts.cancelShift(shift.id)).thenAnswer((_) async {});
  await controller.cancelThisOccurrence(shift.id);
  verify(() => shifts.cancelShift(shift.id)).called(1);
});
```

- [ ] **Step 2: UI — sheet actions “Cancel this one”, “Copy to…”**

```dart
Future<void> copyTile({
  required ShiftOut source,
  required DateTime start,
  required DateTime end,
}) async {
  await _shiftsRepository.createShift(ShiftCreate(
    jobId: source.jobId,
    scheduledStart: start.toUtc(),
    scheduledEnd: end.toUtc(),
    requiredSlots: source.requiredSlots,
    status: 'published',
  ));
  await load();
}

Future<void> cancelThisOccurrence(String shiftId) async {
  await _shiftsRepository.cancelShift(shiftId);
  await load();
}
```

Sheet: three actions labeled for coordinators — “Cancel this one”, “Copy to…”, “This and future…” (latter opens Task 9). Date/time pickers for copy. No RRULE jargon.

- [ ] **Step 3: Pass + commit**

```bash
cd frontend && flutter test test/features/visits/staff_copy_cancel_test.dart
git commit -m "$(cat <<'EOF'
feat: cancel this occurrence and copy roster tiles

EOF
)"
```

---

## Task 9: This and future pattern split

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/schemas.py`
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py`
- Modify: `backend/timesheet-backend/app/modules/jobs/router.py`
- Modify: Flutter jobs remote + controller sheet
- Test: `backend/timesheet-backend/tests/jobs/test_split_recurrence.py`

- [ ] **Step 1: Failing API tests**

```python
@pytest.mark.asyncio
async def test_split_recurrence_from_sets_until_and_creates_new_rule(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    created = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules",
        headers=headers,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
            "required_slots": 1,
        },
    )
    assert created.status_code == 201
    rule_id = created.json()["id"]
    resp = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules/{rule_id}/split-from",
        headers=headers,
        json={
            "from_date": "2026-08-17",
            "time_windows": [{"start_time": "10:00", "end_time": "13:00"}],
            "contractor_id": None,
            "required_slots": 1,
            "horizon_from": "2026-08-17T00:00:00+00:00",
            "horizon_to": "2026-08-31T00:00:00+00:00",
        },
    )
    assert resp.status_code == 200
    old = await db_conn.fetchrow(
        "SELECT until, is_active FROM work.visit_recurrence_rules WHERE id = $1",
        uuid.UUID(rule_id),
    )
    assert old["until"] is not None
    assert resp.json()["new_rule"]["id"] != rule_id
    new_id = resp.json()["new_rule"]["id"]
    holes = await db_conn.fetch(
        """
        SELECT scheduled_start FROM work.shifts
        WHERE recurrence_rule_id = $1 AND status = 'published'
        ORDER BY scheduled_start
        """,
        uuid.UUID(new_id),
    )
    assert holes
    assert all(r["scheduled_start"].hour == 10 for r in holes)


@pytest.mark.asyncio
async def test_split_recurrence_other_tenant_404(client, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    headers_b = {
        "Authorization": f"Bearer {staff_token(b['admin_user_id'], b['tenant_id'], ['jobs.manage'])}"
    }
    rule = client.post(
        f"/v1/jobs/{b['job_id']}/recurrence-rules",
        headers=headers_b,
        json={
            "rrule": "FREQ=WEEKLY;BYDAY=MO",
            "dtstart": "2026-08-03T00:00:00+00:00",
            "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        },
    )
    assert rule.status_code == 201
    resp = client.post(
        f"/v1/jobs/{b['job_id']}/recurrence-rules/{rule.json()['id']}/split-from",
        headers={
            "Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['jobs.manage'])}"
        },
        json={
            "from_date": "2026-08-17",
            "time_windows": [{"start_time": "10:00", "end_time": "13:00"}],
            "horizon_from": "2026-08-17T00:00:00+00:00",
            "horizon_to": "2026-08-31T00:00:00+00:00",
        },
    )
    assert resp.status_code == 404
```

- [ ] **Step 2: Implement**

```python
class SplitRecurrenceRequest(BaseModel):
    from_date: date
    time_windows: list[TimeWindowItem] = Field(min_length=1, max_length=4)
    contractor_id: UUID | None = None
    required_slots: int = Field(default=1, ge=1, le=8)
    horizon_from: datetime
    horizon_to: datetime

    @model_validator(mode="after")
    def validate_horizon(self) -> "SplitRecurrenceRequest":
        if self.horizon_to <= self.horizon_from:
            raise ValueError("horizon_to must be after horizon_from")
        if self.horizon_to - self.horizon_from > timedelta(days=14):
            raise ValueError("horizon_window_too_large")
        return self


class SplitRecurrenceOut(BaseModel):
    old_rule: RecurrenceRuleOut
    new_rule: RecurrenceRuleOut
    horizon: HorizonOut
```

```python
async def split_recurrence_from(
    conn: asyncpg.Connection,
    *,
    tenant_id: UUID,
    job_id: UUID,
    rule_id: UUID,
    body: SplitRecurrenceRequest,
) -> SplitRecurrenceOut:
    async with conn.transaction():
        rule = await conn.fetchrow(
            """
            SELECT * FROM work.visit_recurrence_rules
            WHERE id = $1 AND job_id = $2 AND tenant_id = $3
            FOR UPDATE
            """,
            rule_id,
            job_id,
            tenant_id,
        )
        if rule is None:
            raise HTTPException(status_code=404, detail="recurrence_rule_not_found")
        if body.contractor_id is not None:
            await _assert_active_engagement(
                conn, tenant_id=tenant_id, contractor_id=body.contractor_id
            )
        tenant_tz = await _tenant_timezone(conn, tenant_id)
        from_start = _start_of_civil_day(body.from_date, tenant_tz)

        # D15: refuse if any non-cancellable future occurrence exists
        blocked = await conn.fetchval(
            """
            SELECT 1
            FROM work.shifts s
            LEFT JOIN work.visits v
              ON v.shift_id = s.id AND v.tenant_id = s.tenant_id
             AND v.status NOT IN ('cancelled')
            WHERE s.tenant_id = $1
              AND s.recurrence_rule_id = $2
              AND s.scheduled_start >= $3
              AND s.status != 'cancelled'
              AND v.status IN ('checked_in', 'completed')
            LIMIT 1
            """,
            tenant_id,
            rule_id,
            from_start,
        )
        if blocked:
            raise HTTPException(status_code=409, detail="split_blocked_by_active_visit")

        # Cancel old-rule future holes + scheduled visits (reuse cancel helpers where possible)
        await _cancel_rule_occurrences_from(
            conn,
            tenant_id=tenant_id,
            rule_id=rule_id,
            from_start=from_start,
        )

        until = _end_of_day_before(body.from_date, tenant_tz)
        await conn.execute(
            "UPDATE work.visit_recurrence_rules SET until = $2, updated_at = now() WHERE id = $1",
            rule_id,
            until,
        )
        new_rule = await create_recurrence_rule(
            conn,
            tenant_id=tenant_id,
            job_id=job_id,
            body=RecurrenceRuleCreate(
                rrule=rule["rrule"],
                dtstart=_dtstart_on_or_after(rule["dtstart"], body.from_date, tenant_tz),
                until=rule["until"],
                time_windows=body.time_windows,
                contractor_id=body.contractor_id,
                required_slots=body.required_slots,
            ),
        )
        job = await _get_job_or_404(conn, tenant_id=tenant_id, job_id=job_id)
        horizon = await fill_rule_window(
            conn,
            tenant_id=tenant_id,
            job=job,
            rule=new_rule,
            window_from=ensure_utc(body.horizon_from),
            window_to=ensure_utc(body.horizon_to),
            tenant_tz=tenant_tz,
            existing=None,
            partial=True,
        )
        old_out = await get_recurrence_rule(conn, tenant_id=tenant_id, job_id=job_id, rule_id=rule_id)
        return SplitRecurrenceOut(
            old_rule=old_out,
            new_rule=new_rule,
            horizon=HorizonOut(
                created_shift_ids=horizon.created_shift_ids,
                created_visit_ids=horizon.created_visit_ids,
                skipped=horizon.skipped,
                rules_processed=1,
                truncated=False,
            ),
        )
```

Add test: after horizon fill of old 09:00 windows, split to 10:00 → old future 09:00 rows `cancelled`; new 10:00 published; past Monday before `from_date` still 09:00. Add test: checked_in next week → 409, `until` unchanged.

Reuse existing `create_recurrence_rule` / get helpers if named differently — call the same path the POST recurrence-rules route uses. Helpers `_end_of_day_before`, `_start_of_civil_day`, `_dtstart_on_or_after`, `_cancel_rule_occurrences_from` live in `jobs/service.py` (cancel = set shift cancelled + cancel scheduled visits / release assignments — mirror single-shift cancel path, scoped by `recurrence_rule_id` + `scheduled_start >= from_start`).

CSO: engagement check if contractor_id set; window ≤14d; rate limit 10/min; 404 not 403 cross-tenant.

- [ ] **Step 3: Flutter “This and future” sheet → POST split-from → refresh board**

```dart
// jobs_remote_datasource.dart
Future<SplitRecurrenceOut> splitRecurrenceFrom({
  required String jobId,
  required String ruleId,
  required SplitRecurrenceRequest body,
}) async {
  final response = await _dio.post<Map<String, dynamic>>(
    ApiPaths.jobRecurrenceSplitFrom(jobId, ruleId),
    data: body.toJson(),
  );
  return SplitRecurrenceOut.fromJson(_require(response.data));
}

// controller sheet action
Future<void> editThisAndFuture({
  required ShiftOut tile,
  required List<TimeWindowItem> windows,
  String? contractorId,
}) async {
  final ruleId = tile.recurrenceRuleId;
  if (ruleId == null) {
    errorMessage.value = 'This visit is not part of a pattern.';
    return;
  }
  final fromDate = DateTime(tile.scheduledStart.year, tile.scheduledStart.month, tile.scheduledStart.day);
  await _jobsRepository.splitRecurrenceFrom(
    jobId: tile.jobId,
    ruleId: ruleId,
    body: SplitRecurrenceRequest(
      fromDate: fromDate,
      timeWindows: windows,
      contractorId: contractorId,
      requiredSlots: tile.requiredSlots,
      horizonFrom: fromDate.toUtc(),
      horizonTo: fromDate.add(const Duration(days: 14)).toUtc(),
    ),
  );
  await load();
}
```

Requires `ShiftOut.recurrenceRuleId` if not already on DTO — add nullable field + parse test in Task 3 if missing from list payload (join `work.shifts.recurrence_rule_id`).

- [ ] **Step 4: Pass + commit**

```bash
cd backend/timesheet-backend && python -m pytest tests/jobs/test_split_recurrence.py -q
cd frontend && flutter test test/features/visits/
git commit -m "$(cat <<'EOF'
feat: split recurrence from a date for this-and-future edits

EOF
)"
```

---

## Task 10: Tenant timezone on roster (folded TODOS P2)

**Files:**
- Reuse: `GET` tenant settings already used by `StaffTenantSettingsController` (`timezone` on tenant DTO)
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart` to load tenant timezone once and use it for civil day bounds / week chrome
- Optional: cache timezone on auth/session controller if a single shared fetch already exists — prefer DRY over a second settings call every week load
- Test: `frontend/test/features/visits/staff_visits_timezone_test.dart`

- [ ] **Step 1: Failing test**

```dart
test('week rangeStart stays on tenant civil Monday when timezone set', () {
  final ctrl = StaffVisitsController(/* mocks */);
  ctrl.tenantTimezone.value = 'Australia/Sydney';
  // Pin a UTC instant that is still Sunday evening in US but Monday in Sydney
  ctrl.alignRangeToTenantWeek(DateTime.utc(2026, 8, 9, 16)); // Sun 16:00Z = Mon 02:00 AEST
  expect(ctrl.rangeStart.value.weekday, DateTime.monday);
});
```

(If full timezone package is not in pubspec, document fallback: use device local and show existing jobs-form copy “device timezone while tenant timezone unavailable” — do **not** add a heavy TZ package in this slice unless already present. Grep `timezone` / `flutter_timezone` in pubspec first.)

- [ ] **Step 2: Wire** — fetch timezone from existing tenant settings endpoint once in `onInit` / first `load`; if null/empty, device local.

- [ ] **Step 3: Commit**

```bash
cd frontend && flutter test test/features/visits/staff_visits_timezone_test.dart
git commit -m "$(cat <<'EOF'
feat: align roster day boundaries with tenant timezone when available

EOF
)"
```

---

## Task 11: Manual smoke

- [ ] Staff: Roster shows Unfilled + people rows; client filter; leave chip on a sick day.
- [ ] Release Jane → hole on Unfilled; contractor Open tab sees shift; Assign Ali with Free/Busy labels.
- [ ] Copy tile to Thursday; Cancel this one.
- [ ] This and future: Monday 09–12 → 10–13 from next week; past Monday unchanged.
- [ ] Tile shows checked_in chip after contractor check-in.
- [ ] `shifts.read` only: grid visible, no Release/Assign/Split.
- [ ] Horizon 2px bar still works after grid swap.

---

## Test Plan & Verification

**Coverage target:** ≥90% lines on `buildRosterGrid`, `get_roster_overlay`, `split_recurrence_from`, unassign→notify path; every new public route has authz + tenant tests. Flutter: grid model 100% of branches (unfilled, leave, client filter, partial fill).

**Critical paths (must pass before ship):**
- People×day board renders Unfilled + person tiles from existing shifts → grid model + widget tests
- Overlay tenant isolation → `test_roster_overlay_excludes_other_tenant`
- Release opens hole + notify → `test_unassign_emits_slot_opened_when_hole_remains`
- Slot_opened recipients are eligible contractors only (not management / not default receive-all) → `test_slot_opened_recipients_eligible_contractors_only`
- This-and-future split → `test_split_recurrence_from_sets_until_and_creates_new_rule`
- Visit status on tile DTO → `test_list_shifts_includes_visit_status_on_assignments`
- Steal 1–3 horizon paint-first still green → existing `staff_roster_horizon_test`

**Edge cases & error paths:**
- Overlay window >31d → 400
- Overlay request fails → board still shows shifts; soft banner (D20)
- Unassign after check-in → 409 `invalid_visit_status` → friendly copy
- Split with inactive engagement contractor → 409 + no until change (txn)
- Split with checked_in future occurrence → 409 `split_blocked_by_active_visit`; old until unchanged
- Split after horizon fill → old future tiles cancelled; new windows filled (D15)
- Client filter empty → all clients
- Default status filter published → drafts hidden (trial note)
- Partially filled 2:1 → tile on Jane **and** Unfilled
- `shifts.read` cannot unassign/split → 403

**Regression guards:**
- Claim TOCTOU / leave block → `tests/shifts/test_shift_claim.py`
- Horizon cancelled not resurrected → existing horizon tests
- Assign still works from detail → existing assign tests

**Verification commands:**
- Unit backend: `cd backend/timesheet-backend && python -m pytest tests/workforce/test_roster_overlay.py tests/shifts/test_shift_list_visit_status.py tests/shifts/test_unassign_notifies_open_slot.py tests/jobs/test_split_recurrence.py tests/jobs/test_horizon.py tests/shifts/test_shift_claim.py -q`
- Coverage: `python -m pytest tests/workforce/test_roster_overlay.py tests/jobs/test_split_recurrence.py --cov=app.modules.workforce --cov=app.modules.jobs.service --cov-report=term-missing`
- Unit Flutter: `cd frontend && flutter test test/features/visits/ test/features/shifts/shift_models_test.dart`
- E2E: Task 11 manual on `flutter run`

**Acceptance criteria (from canvas steal 4–7):**
- [ ] People × day board + Unfilled row + client filter → Tasks 4–5
- [ ] Leave/availability painted from staff API → Tasks 1, 5
- [ ] This / all future / copy → Tasks 8–9
- [ ] Sick-day release + notify + busy/free assign → Tasks 6–7
- [ ] Tile visit status → Tasks 2–3, 5
- [ ] No drag / no hour grid / no table rewrite → D2, D7, D1

---

## What already exists

| Need | Existing | Plan |
|------|----------|------|
| Shift tiles data | `GET /v1/shifts` + `ShiftOut` | Reuse; add visit_status |
| Unfilled signal | `open_slots` + pips | Unfilled **row** |
| Leave tables | `workforce.contractor_leave` | Staff overlay read |
| Availability rules | `contractor_availability_rules` | Overlay read |
| Unassign API | `POST …/unassign` | Wire Flutter + notify |
| Assign API | `POST …/assign` | Picker labels only |
| Claim / Open tab | contractor claim | Keep as wait path |
| visit.assigned notify | `_emit_visit_assigned` | Mirror for slot_opened |
| Pattern deactivate | PATCH `is_active` | Keep; split-from is additive |
| Horizon fill one rule | `rule_ids` on POST horizon | Used after split |
| Day stamp copy | `formatRosterStamp` | Reuse |

## Failure modes

| Path | Failure | Test | Handling | User sees |
|------|---------|------|----------|-----------|
| Overlay | Missing permission | 403 test | reject | Existing toast |
| Overlay | Other-tenant leak | isolation test | empty | Nothing |
| Unassign | Checked-in visit | 409 test | no release | Inline copy |
| Notify | No eligible contractors | emit 0 recipients | ok | “Hole opened” without “notified” |
| Split | Mid-txn rule fail | rollback test | no until change | Inline error |
| Grid | Empty engagements | model test | Unfilled-only rows | Unfilled + empty people |
| Grid | Stale job filter | steal 1–3 dropdown harden | null value | All clients |

## Worktree parallelization

| Step | Modules | Depends on |
|------|---------|------------|
| Overlay API + visit_status | workforce + shifts | — |
| Grid model + Flutter DTOs | roster + shift models | — |
| Board UI | `frontend/lib/features/visits` | DTOs + model |
| Unassign notify | shifts + notifications | — |
| Split-from | jobs service | fill_rule_window |
| Assign picker + copy/cancel UI | frontend visits | board UI |
| Tenant TZ | visits + tenant settings | board UI |

Lane A: Task 1 → Task 2 → Task 6 → Task 9 (backend)  
Lane B: Task 3 → Task 4 → Task 5 → Task 7 → Task 8 → Task 10 (frontend; B waits on A for live overlay/visit_status/split)

Conflict flag: Task 5 and Task 6 both touch board actions — merge board UI first, then release entry points.

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | CODEX_MODE=not_installed (skipped) |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | D1–D7 → D14–D21 folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | Canvas + D17 staff laptop / contractor mobile |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |
| Outside Voice | `/plan-eng-review` | Independent plan critique | 0 | skipped | Codex CLI not installed |

### Eng decisions locked this review
- **D14** (D1→A): One vertical slice for steals 4–7
- **D15** (D2→A): Split cancels old future from `from_date` then fills new rule; 409 if checked_in/completed; no back-compat
- **D16** (D3→A): People rows = all assignable engagements
- **D17**: Staff laptop/web; contractor mobile
- **D18** (D4→A): No drag this slice
- **D19** (D5→A): Day columns only
- **D20** (D6→A): Overlay best-effort degrade
- **D21** (D7→A): slot_opened → eligible contractors only (cap 50)

- **VERDICT:** ENG CLEARED — ready to implement. Outside voice skipped (codex not installed).

NO UNRESOLVED DECISIONS

