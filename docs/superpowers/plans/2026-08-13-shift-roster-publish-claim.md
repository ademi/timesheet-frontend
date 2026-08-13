# Shift Roster (Publish Holes, Claim, Multi-Worker) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Staff can publish coverage windows (shifts) that still have unfilled slots; eligible contractors can claim an open slot; a shift can require N workers. Each filled slot becomes a visit so check-in, forms, and pay stay unchanged.

**Architecture:** Add `work.shifts` (planning) and `work.shift_assignments` (who took a slot). Assign and claim run in one transaction: lock the shift, enforce slot cap / overlap / eligibility (claim only) / leave (claim only), insert a `work.visits` row, insert the assignment. Recurrence generate writes published shifts (optional pre-assign from the rule). Legacy visits keep `shift_id NULL`. No Shift table rewrite of payments.

**Tech Stack:** PostgreSQL (`btree_gist` already in use), FastAPI + asyncpg + Pydantic v2, pytest + TestClient, Flutter/GetX/Dio, existing `evaluate_engagement_eligibility`, `assert_no_overlap`, `org.api_idempotency`, `log_domain_event`, `visit.assigned` notifications.

**Locked decisions:**
- D1-A: Shift + assignments; visit created on assign/claim; `required_slots` for 2:1; first-come claim.
- D2-B: Claim and open-shift list require `EligibilityReport.ok`. Staff assign does **not**. Leave hard-blocks claim only. Availability stays a hint (not a 409).
- Generate creates **published** shifts (same “live after generate” as today’s visits). Manual create may be `draft` then publish.
- Recurrence `contractor_id` becomes nullable; `required_slots` added (default 1). If contractor set, generate fills one slot and leaves the rest open.
- No backfill of existing visits into shifts. `visits.shift_id` nullable.
- No approval queue, no role labels (primary/backup), no shift time-edit after publish when any assignment exists (cancel + recreate).
- Open-shift payload is minimized: job title, client display name, suburb/postcode, window, open/required slots. No street address, diagnoses, forms, or contacts.
- Design-consultation scope: roster screens on existing `AppColors`. No product-wide `DESIGN.md`.

---

## Domain model

```text
Job (standing|ad_hoc)
  └── Shift (draft|published|cancelled)
        required_slots N
        └── Assignment* (active|released|cancelled)  0..N
              └── Visit (scheduled|checked_in|completed|cancelled)
                    └── time_entry / forms / payment   UNCHANGED
```

```text
Shift status
  draft ──publish──► published ──cancel──► cancelled
                         │
                         └── claim/assign while open_slots > 0
                         └── release/unassign if visit.status = scheduled
```

```text
Claim (one transaction)
  SELECT shift FOR UPDATE
  status=published AND not cancelled
  active_assignments < required_slots
  JWT contractor (never from body)
  engagement active in tenant
  EligibilityReport.ok
  no overlapping leave (shift dates)
  assert_no_overlap (existing visit exclusion)
  INSERT visit (source=claim, shift_id)
  INSERT assignment (source=claim, visit_id)
  emit visit.assigned
```

**open_slots** = `required_slots - count(assignments where status='active')`.

---

## Roster UX (design-consultation, screens only)

Memorable thing: **the holes are visible.** An unfilled published shift is a first-class card, not a missing row.

Reuse [frontend/lib/app/themes/app_colors.dart](frontend/lib/app/themes/app_colors.dart): cream background, charcoal text, white cards. Add one token only:

```dart
static const Color openSlot = Color(0xFFB45309); // warm amber, not error-red
static const Color openSlotBackground = Color(0xFFFFF7ED);
```

**Staff** — keep route `/staff/visits`. Retitle nav from “Visits” to “Roster”. Week range (existing ±7). Each shift is a card: job title, client name, time, slot pips (`●` filled `success` / `○` open `openSlot`). Tap → shift detail (assignments + assign picker + publish/cancel). Unfilled published cards use `openSlotBackground`. Draft cards are muted (`slate400`). Do not build an employee×hour grid in V1 (YAGNI). Existing visit detail stays for attendance.

**Contractor** — keep 5-tab shell. On “My visits”, add a 2-segment control: **Mine | Open**. Open lists claimable shifts (minimized PII) with a primary **Claim** button. After claim, the new visit appears under Mine and opens existing visit detail (check-in unchanged).

---

## Trust boundary (CSO)

New authenticated endpoints. Contractor self-serve write. Client PII on open list. Race on last slot.

| Threat | Control | Test |
|--------|---------|------|
| IDOR claim as another contractor | `contractor_id` from JWT only | claim with other id in body ignored/rejected |
| Cross-tenant shift | `tenant_id` from JWT on every query | other-tenant UUID → 404, not 403 leak |
| TOCTOU last slot | `SELECT … FOR UPDATE` + unique active assignment + count check | two claims, one 201 one 409 `shift_full` |
| Eligibility bypass | list + claim both call `evaluate_engagement_eligibility` | ineligible 404 on get-open, 409 on claim |
| Staff assign override | allowed; `log_domain_event` action=`shift.assign_override` when eligibility would fail | audit row present |
| PII overshare | open DTO has no `address_line1`, no forms | schema/test assert keys |
| Abuse | `limiter.limit("20/minute")` keyed by user id on claim | unit not required (limiter disabled in pytest); document |

No new public/unauthenticated routes.

---

## File Structure

| File | Responsibility (SRP) | Seam |
|------|----------------------|------|
| [backend/timesheet-db/migrations/V021__work_shifts.sql](backend/timesheet-db/migrations/V021__work_shifts.sql) | Tables, visit.shift_id, perms, recurrence null contractor + required_slots | DB |
| [backend/timesheet-backend/app/modules/shifts/schemas.py](backend/timesheet-backend/app/modules/shifts/schemas.py) | Request/response DTOs | HTTP/JSON |
| [backend/timesheet-backend/app/modules/shifts/guards.py](backend/timesheet-backend/app/modules/shifts/guards.py) | Eligibility, leave, slot count, actor resolve | Claim/assign policy |
| [backend/timesheet-backend/app/modules/shifts/service.py](backend/timesheet-backend/app/modules/shifts/service.py) | Create/publish/list/assign/claim/release/cancel | Transactions |
| [backend/timesheet-backend/app/modules/shifts/router.py](backend/timesheet-backend/app/modules/shifts/router.py) | `/v1/shifts*` routes + rate limit on claim | HTTP boundary |
| [backend/timesheet-backend/app/modules/jobs/overlap.py](backend/timesheet-backend/app/modules/jobs/overlap.py) | **Reuse** `assert_no_overlap` (DRY) | Overlap |
| [backend/timesheet-backend/app/modules/credentials/service_eligibility.py](backend/timesheet-backend/app/modules/credentials/service_eligibility.py) | **Reuse** `evaluate_engagement_eligibility` (DRY) | Docs gate |
| [backend/timesheet-backend/app/modules/jobs/service.py](backend/timesheet-backend/app/modules/jobs/service.py) | `_insert_visit(..., shift_id=)`; generate → shifts; manual visit wraps shift | Existing jobs |
| [backend/timesheet-backend/tests/shifts/conftest.py](backend/timesheet-backend/tests/shifts/conftest.py) | Shared seed (eligible + ineligible contractors) | Tests |
| [frontend/lib/features/shifts/…](frontend/lib/features/shifts/) | Models, datasource, repository, staff roster + contractor open/claim | Flutter |
| [frontend/lib/core/errors/app_failure.dart](frontend/lib/core/errors/app_failure.dart) | New error codes/messages | UX errors |

**Principles:**
- **DRY:** Do not copy overlap SQL or eligibility evaluation. Reuse `_insert_visit`, `_emit_visit_assigned`, `get_cached_response` / `store_response`, `parse_idempotency_header`. Shared pytest seed in `tests/shifts/conftest.py`.
- **SOLID:** `guards.py` is the only place claim policy lives. Router does authz + HTTP. Service owns transactions. Flutter repository owns Dio; views do not call Dio.
- **YAGNI:** No week-publish wizard, no grid roster, no skill matching, no visit backfill, no DESIGN.md, no primary/backup labels. `required_slots` max 8.

**Known duplication accepted:** Staff list DTO includes full location for assigned work; open-shift DTO is a separate slim type so PII cannot leak by reuse. Do not “DRY” those two into one model.

---

### Task 1: Migration V021 + RBAC

**Files:**
- Create: `backend/timesheet-db/migrations/V021__work_shifts.sql`
- Modify: `backend/timesheet-db/seed-v2/001_dev_seed.sql` (perm catalog + admin/supervisor/contractor role grants)
- Modify: `backend/timesheet-db/seed/001_dev_seed.sql` (same keys if that file is still applied)
- Modify: `frontend/docs/migration/phase1/app-permissions-catalog.md`
- Modify: `frontend/lib/app/constants/app_permissions.dart`

- [ ] **Step 1: Write the failing test**

```python
"""V021: shifts tables exist; recurrence contractor_id nullable; new perms present."""
import pytest


@pytest.mark.asyncio
async def test_v021_shifts_schema(db_conn):
    assert await db_conn.fetchval(
        """
        SELECT COUNT(*) FROM information_schema.tables
        WHERE table_schema = 'work' AND table_name IN ('shifts', 'shift_assignments')
        """
    ) == 2
    nullok = await db_conn.fetchval(
        """
        SELECT is_nullable FROM information_schema.columns
        WHERE table_schema = 'work' AND table_name = 'visit_recurrence_rules'
          AND column_name = 'contractor_id'
        """
    )
    assert nullok == "YES"
    for key in ("shifts.read", "shifts.manage", "shifts.claim"):
        assert await db_conn.fetchval(
            "SELECT 1 FROM auth.permissions WHERE key = $1", key
        )
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend/timesheet-backend && pytest tests/shifts/test_v021_schema.py::test_v021_shifts_schema -v`

Expected: FAIL (file missing or tables missing) until migration is applied by session autouse migrate.

- [ ] **Step 3: Write migration**

`backend/timesheet-db/migrations/V021__work_shifts.sql`:

```sql
BEGIN;

INSERT INTO public.schema_migrations(version)
VALUES ('V021__work_shifts.sql')
ON CONFLICT (version) DO NOTHING;

ALTER TABLE work.visits
  DROP CONSTRAINT IF EXISTS visits_source_check;
ALTER TABLE work.visits
  ADD CONSTRAINT visits_source_check
  CHECK (source IN ('manual', 'recurrence', 'claim', 'staff_assign'));

ALTER TABLE work.visits
  ADD COLUMN IF NOT EXISTS shift_id uuid;

CREATE TABLE work.shifts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES org.tenants(id) ON DELETE CASCADE,
  job_id uuid NOT NULL REFERENCES work.jobs(id) ON DELETE CASCADE,
  recurrence_rule_id uuid REFERENCES work.visit_recurrence_rules(id) ON DELETE SET NULL,
  scheduled_start timestamptz NOT NULL,
  scheduled_end timestamptz NOT NULL,
  required_slots integer NOT NULL DEFAULT 1,
  status text NOT NULL DEFAULT 'draft',
  location_geog geography(Point, 4326) NOT NULL,
  geofence_radius_m integer NOT NULL,
  geofence_mode text NOT NULL,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT shifts_status_check CHECK (status IN ('draft', 'published', 'cancelled')),
  CONSTRAINT shifts_geofence_mode_check CHECK (geofence_mode IN ('informational', 'enforce')),
  CONSTRAINT shifts_schedule_check CHECK (scheduled_end > scheduled_start),
  CONSTRAINT shifts_required_slots_check CHECK (required_slots >= 1 AND required_slots <= 8)
);

CREATE INDEX shifts_tenant_window_idx
  ON work.shifts (tenant_id, scheduled_start, scheduled_end);
CREATE INDEX shifts_job_idx ON work.shifts (job_id);
CREATE UNIQUE INDEX shifts_recurrence_occurrence_uidx
  ON work.shifts (recurrence_rule_id, scheduled_start)
  WHERE recurrence_rule_id IS NOT NULL AND status <> 'cancelled';

CREATE TABLE work.shift_assignments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES org.tenants(id) ON DELETE CASCADE,
  shift_id uuid NOT NULL REFERENCES work.shifts(id) ON DELETE CASCADE,
  contractor_id uuid NOT NULL REFERENCES workforce.contractors(id) ON DELETE RESTRICT,
  visit_id uuid NOT NULL UNIQUE REFERENCES work.visits(id) ON DELETE RESTRICT,
  source text NOT NULL,
  status text NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT shift_assignments_source_check CHECK (source IN ('staff_assign', 'claim')),
  CONSTRAINT shift_assignments_status_check CHECK (status IN ('active', 'released', 'cancelled'))
);

CREATE UNIQUE INDEX shift_assignments_active_contractor_uidx
  ON work.shift_assignments (shift_id, contractor_id)
  WHERE status = 'active';

ALTER TABLE work.visits
  ADD CONSTRAINT visits_shift_id_fkey
  FOREIGN KEY (shift_id) REFERENCES work.shifts(id) ON DELETE SET NULL;

CREATE INDEX visits_shift_idx ON work.visits (shift_id);

ALTER TABLE work.visit_recurrence_rules
  ALTER COLUMN contractor_id DROP NOT NULL;

ALTER TABLE work.visit_recurrence_rules
  ADD COLUMN IF NOT EXISTS required_slots integer NOT NULL DEFAULT 1;

ALTER TABLE work.visit_recurrence_rules
  ADD CONSTRAINT recurrence_required_slots_check
  CHECK (required_slots >= 1 AND required_slots <= 8);

INSERT INTO auth.permissions (key)
SELECT k FROM (VALUES
  ('shifts.read'),
  ('shifts.manage'),
  ('shifts.claim')
) AS v(k)
WHERE NOT EXISTS (SELECT 1 FROM auth.permissions p WHERE p.key = v.k);

INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT ro.id, p.id
FROM auth.roles ro
CROSS JOIN auth.permissions p
WHERE ro.tenant_id IS NULL
  AND ro.name IN ('owner', 'admin', 'supervisor')
  AND p.key IN ('shifts.read', 'shifts.manage')
  AND NOT EXISTS (
    SELECT 1 FROM auth.role_permissions rp
    WHERE rp.role_id = ro.id AND rp.permission_id = p.id
  );

INSERT INTO auth.role_permissions (role_id, permission_id)
SELECT ro.id, p.id
FROM auth.roles ro
CROSS JOIN auth.permissions p
WHERE ro.tenant_id IS NULL
  AND ro.name = 'contractor'
  AND p.key = 'shifts.claim'
  AND NOT EXISTS (
    SELECT 1 FROM auth.role_permissions rp
    WHERE rp.role_id = ro.id AND rp.permission_id = p.id
  );

COMMIT;
```

Add the three keys to both seed permission `VALUES` lists and to admin/supervisor (`shifts.read`, `shifts.manage`) and contractor (`shifts.claim`) grants in `001_dev_seed.sql` files.

Flutter:

```dart
static const shiftsRead = 'shifts.read';
static const shiftsManage = 'shifts.manage';
static const shiftsClaim = 'shifts.claim';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend/timesheet-backend && pytest tests/shifts/test_v021_schema.py -v`

Expected: PASS (autouse migrate applies V021).

- [ ] **Step 5: Commit**

```bash
git add backend/timesheet-db/migrations/V021__work_shifts.sql \
  backend/timesheet-db/seed-v2/001_dev_seed.sql \
  backend/timesheet-db/seed/001_dev_seed.sql \
  frontend/lib/app/constants/app_permissions.dart \
  frontend/docs/migration/phase1/app-permissions-catalog.md \
  backend/timesheet-backend/tests/shifts/test_v021_schema.py
git commit -m "$(cat <<'EOF'
feat: add shifts tables and RBAC for roster holes

EOF
)"
```

---

### Task 2: Shared shift test fixture

**Files:**
- Create: `backend/timesheet-backend/tests/shifts/conftest.py`
- Test: `backend/timesheet-backend/tests/shifts/test_fixture_sanity.py`

DRY: clone column usage from `tests/jobs/test_recurrence_generate.py` `_seed_standing_job`. Do not invent contractor columns.

- [ ] **Step 1: Write the failing test**

```python
import pytest


@pytest.mark.asyncio
async def test_seed_shift_world_has_eligible_and_ineligible(db_conn):
    from tests.shifts.conftest import seed_shift_world

    fx = await seed_shift_world(db_conn)
    assert fx["eligible_contractor_id"] != fx["ineligible_contractor_id"]
    assert fx["job_id"]
    assert fx["eligible_engagement_id"]
```

- [ ] **Step 2: Run to see import/seed fail**

Run: `pytest tests/shifts/test_fixture_sanity.py -v`

Expected: FAIL `seed_shift_world` not defined or import error.

- [ ] **Step 3: Implement `seed_shift_world`**

In `tests/shifts/conftest.py`:

- Insert tenant (timezone `UTC`), admin user + `auth.user_roles` admin, tenant_member.
- Insert eligible contractor user + contractor + **active** engagement with **no** `engagement_required_doc_categories` (eligibility ok).
- Insert ineligible contractor + active engagement with one required category `police_check` and **no** credentials.
- Insert branch with `SYDNEY_POINT`, client `full_name='Roster Client'`, site with `city='Sydney'`, `postal_code='2000'`, `address_line1='1 Secret St'`, standing job on that site.
- Return dict: `tenant_id`, `admin_user_id`, `eligible_user_id`, `ineligible_user_id`, `eligible_contractor_id`, `ineligible_contractor_id`, `eligible_engagement_id`, `ineligible_engagement_id`, `job_id`, `client_id`, `site_id`.

Also export helpers:

```python
def staff_token(user_id, tenant_id, perms=None):
    return jwt.encode(
        {
            "sub": str(user_id),
            "tenant_id": str(tenant_id),
            "permissions": perms or ["shifts.read", "shifts.manage", "jobs.manage", "visits.manage"],
            "typ": "access",
            "actor_type": "tenant_member",
        },
        JWT_SECRET,
        algorithm="HS256",
    )


def contractor_token(user_id, tenant_id, contractor_id, perms=None):
    return jwt.encode(
        {
            "sub": str(user_id),
            "tenant_id": str(tenant_id),
            "permissions": perms or ["visits.read", "shifts.claim", "visits.check_in"],
            "typ": "access",
            "actor_type": "contractor",
            "contractor_id": str(contractor_id),
        },
        JWT_SECRET,
        algorithm="HS256",
    )
```

Use the same `JWT_SECRET = get_settings().jwt_secret` pattern as jobs tests.

- [ ] **Step 4: Run test — PASS**

- [ ] **Step 5: Commit** `test: add shared shift roster seed fixture`

---

### Task 3: Create / publish / list staff shifts

**Files:**
- Create: `backend/timesheet-backend/app/modules/shifts/schemas.py`
- Create: `backend/timesheet-backend/app/modules/shifts/service.py`
- Create: `backend/timesheet-backend/app/modules/shifts/router.py`
- Modify: `backend/timesheet-backend/app/api/v1/routes.py` (include router)
- Test: `backend/timesheet-backend/tests/shifts/test_shift_crud.py`

- [ ] **Step 1: Write failing tests**

```python
@pytest.mark.asyncio
async def test_create_draft_then_publish(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    start = "2026-08-20T09:00:00+00:00"
    end = "2026-08-20T12:00:00+00:00"
    created = client.post(
        "/v1/shifts",
        headers=headers,
        json={
            "job_id": str(fx["job_id"]),
            "scheduled_start": start,
            "scheduled_end": end,
            "required_slots": 2,
        },
    )
    assert created.status_code == 201, created.text
    body = created.json()
    assert body["status"] == "draft"
    assert body["required_slots"] == 2
    assert body["open_slots"] == 2
    assert body["assignments"] == []

    pub = client.post(f"/v1/shifts/{body['id']}/publish", headers=headers)
    assert pub.status_code == 200
    assert pub.json()["status"] == "published"
    assert pub.json()["published_at"] is not None


@pytest.mark.asyncio
async def test_list_shifts_tenant_scoped(client: TestClient, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    client.post(
        "/v1/shifts",
        headers=headers,
        json={
            "job_id": str(fx["job_id"]),
            "scheduled_start": "2026-08-20T09:00:00+00:00",
            "scheduled_end": "2026-08-20T12:00:00+00:00",
            "required_slots": 1,
            "status": "published",
        },
    )
    listed = client.get(
        "/v1/shifts",
        headers=headers,
        params={"from": "2026-08-20T00:00:00+00:00", "to": "2026-08-21T00:00:00+00:00"},
    )
    assert listed.status_code == 200
    assert len(listed.json()) == 1


def test_contractor_cannot_create_shift(client: TestClient, db_conn):
    import asyncio
    fx = asyncio.get_event_loop().run_until_complete(seed_shift_world(db_conn))
    # use pytest.mark.asyncio instead — see below
```

Use `@pytest.mark.asyncio` for all of these (same as jobs tests). Contractor create:

```python
headers = {
    "Authorization": (
        f"Bearer {contractor_token(fx['eligible_user_id'], fx['tenant_id'], fx['eligible_contractor_id'])}"
    )
}
resp = client.post("/v1/shifts", headers=headers, json={...})
assert resp.status_code == 403
```

- [ ] **Step 2: Run — FAIL** 404 router missing.

- [ ] **Step 3: Implement**

`schemas.py` (minimum):

```python
class ShiftCreate(BaseModel):
    job_id: UUID
    scheduled_start: datetime
    scheduled_end: datetime
    required_slots: int = Field(default=1, ge=1, le=8)
    status: Literal["draft", "published"] = "draft"

    @model_validator(mode="after")
    def validate_window(self) -> "ShiftCreate":
        if self.scheduled_end <= self.scheduled_start:
            raise ValueError("scheduled_end must be after scheduled_start")
        return self


class ShiftAssignmentOut(BaseModel):
    id: UUID
    contractor_id: UUID
    contractor_name: str
    visit_id: UUID
    source: Literal["staff_assign", "claim"]
    status: Literal["active", "released", "cancelled"]


class ShiftOut(BaseModel):
    id: UUID
    tenant_id: UUID
    job_id: UUID
    job_title: str
    client_id: UUID | None
    client_name: str | None
    scheduled_start: datetime
    scheduled_end: datetime
    required_slots: int
    open_slots: int
    status: Literal["draft", "published", "cancelled"]
    location_label: str | None = None
    suburb: str | None = None
    postal_code: str | None = None
    assignments: list[ShiftAssignmentOut] = Field(default_factory=list)
    published_at: datetime | None
    created_at: datetime
    updated_at: datetime
```

`service.create_shift`: load job via same pattern as `_get_job_or_404` (copy the 404 SQL into shifts service or import a small jobs helper — prefer importing `_get_job_or_404` from jobs.service; if that creates a circular import, duplicate the 8-line fetch). Copy location_geog/radius/mode from job. If `status==published`, set `published_at=now()`.

`service.list_shifts`: `WHERE tenant_id=$1 AND scheduled_start < $to AND scheduled_end > $from AND status <> 'cancelled'` unless `include_cancelled=true`.

Router:

```python
@router.post("/shifts", response_model=ShiftOut, status_code=201,
             dependencies=[Depends(require_active_subscription)])
async def create_shift(..., payload=Depends(require_permission("shifts.manage"))): ...

@router.get("/shifts", response_model=list[ShiftOut])
async def list_shifts(..., payload=Depends(require_any_permission("shifts.read", "shifts.manage"))): ...

@router.get("/shifts/{shift_id}", response_model=ShiftOut)
async def get_shift(..., payload=Depends(require_any_permission("shifts.read", "shifts.manage"))): ...

@router.post("/shifts/{shift_id}/publish", response_model=ShiftOut,
             dependencies=[Depends(require_active_subscription)])
async def publish_shift(..., payload=Depends(require_permission("shifts.manage"))): ...
```

Publish: 409 `invalid_shift_status` if not draft. 404 if wrong tenant.

Include router in `app/api/v1/routes.py` next to `jobs_router`.

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit** `feat: staff create, publish, and list shifts`

---

### Task 4: Staff assign creates visit

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py` (`_insert_visit` add `shift_id: UUID | None = None`)
- Modify: `backend/timesheet-backend/app/modules/jobs/schemas.py` (`VisitSource` add `claim`, `staff_assign`; `VisitOut.shift_id: UUID | None = None`)
- Modify: `_VISIT_COLUMNS` to select `v.shift_id`
- Modify: `shifts/service.py` `assign_contractor`
- Modify: `shifts/router.py` `POST /shifts/{id}/assign`
- Modify: `shifts/guards.py` `resolve_active_engagement`
- Test: `tests/shifts/test_shift_assign.py`

- [ ] **Step 1: Failing tests**

```python
@pytest.mark.asyncio
async def test_assign_creates_visit_and_decrements_open_slots(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    shift = client.post("/v1/shifts", headers=headers, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-20T09:00:00+00:00",
        "scheduled_end": "2026-08-20T12:00:00+00:00",
        "required_slots": 2,
        "status": "published",
    }).json()
    resp = client.post(
        f"/v1/shifts/{shift['id']}/assign",
        headers=headers,
        json={"contractor_id": str(fx["eligible_contractor_id"])},
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["open_slots"] == 1
    assert len(body["assignments"]) == 1
    visit_id = body["assignments"][0]["visit_id"]
    visit = client.get(f"/v1/visits/{visit_id}", headers=headers)
    assert visit.status_code == 200
    assert visit.json()["shift_id"] == shift["id"]
    assert visit.json()["source"] == "staff_assign"
    assert visit.json()["contractor_id"] == str(fx["eligible_contractor_id"])


@pytest.mark.asyncio
async def test_assign_ineligible_still_allowed_and_audited(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    shift = client.post("/v1/shifts", headers=headers, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-21T09:00:00+00:00",
        "scheduled_end": "2026-08-21T12:00:00+00:00",
        "required_slots": 1,
        "status": "published",
    }).json()
    resp = client.post(
        f"/v1/shifts/{shift['id']}/assign",
        headers=headers,
        json={"contractor_id": str(fx["ineligible_contractor_id"])},
    )
    assert resp.status_code == 201, resp.text
    row = await db_conn.fetchrow(
        """
        SELECT payload FROM org.domain_audit_events
        WHERE tenant_id = $1 AND entity_type = 'shift' AND entity_id = $2
        ORDER BY created_at DESC LIMIT 1
        """,
        fx["tenant_id"],
        uuid.UUID(shift["id"]),
    )
    assert row is not None
    payload = row["payload"]
    if isinstance(payload, str):
        payload = json.loads(payload)
    assert payload["action"] == "shift.assign_override"


@pytest.mark.asyncio
async def test_assign_overlap_409(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    payload = {
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-22T09:00:00+00:00",
        "scheduled_end": "2026-08-22T12:00:00+00:00",
        "required_slots": 1,
        "status": "published",
    }
    a = client.post("/v1/shifts", headers=headers, json=payload).json()
    b = client.post("/v1/shifts", headers=headers, json=payload).json()
    first = client.post(
        f"/v1/shifts/{a['id']}/assign",
        headers=headers,
        json={"contractor_id": str(fx["eligible_contractor_id"])},
    )
    assert first.status_code == 201
    second = client.post(
        f"/v1/shifts/{b['id']}/assign",
        headers=headers,
        json={"contractor_id": str(fx["eligible_contractor_id"])},
    )
    assert second.status_code == 409
    assert "visit_overlap" in second.text
```

- [ ] **Step 2: Run — FAIL** 404 assign route.

- [ ] **Step 3: Implement assign**

`guards.py`:

```python
async def active_engagement_id(conn, *, tenant_id, contractor_id) -> UUID:
    # same SQL as jobs.service._assert_active_engagement; prefer calling that function
    from app.modules.jobs.service import _assert_active_engagement
    return await _assert_active_engagement(
        conn, tenant_id=tenant_id, contractor_id=contractor_id
    )


async def assert_shift_has_capacity(conn, *, shift_id: UUID, required_slots: int) -> None:
    n = await conn.fetchval(
        """
        SELECT COUNT(*) FROM work.shift_assignments
        WHERE shift_id = $1 AND status = 'active'
        """,
        shift_id,
    )
    if n >= required_slots:
        raise HTTPException(status_code=409, detail="shift_full")
```

`assign_contractor` transaction:

1. `SELECT * FROM work.shifts WHERE id=$1 AND tenant_id=$2 FOR UPDATE`
2. 404 if missing; 409 `invalid_shift_status` if not `published`
3. `active_engagement_id`
4. `evaluate_engagement_eligibility`; if not ok → still assign, `log_domain_event(..., action="shift.assign_override", payload={"reason":"eligibility_incomplete", "contractor_id": str(...)})`
5. `assert_shift_has_capacity`
6. Copy tasks/forms from job catalog? V1: empty tasks + job form catalog as visit form requirements (match manual visit: caller/body can be empty; copy `work.job_form_catalog` as required=false unless we already copy nothing on manual visits). **YAGNI:** assign uses empty tasks and empty form requirements unless shift was generated from a rule (then copy rule JSON). Manual assign: empty is OK; staff can still complete visit.
7. `_insert_visit(..., source="staff_assign", shift_id=shift.id, contractor_id=...)`
8. INSERT assignment `source='staff_assign', status='active'`
9. `_emit_visit_assigned`

Extend `_insert_visit` INSERT to include `shift_id` column (`$12` or named). Default NULL for old callers.

- [ ] **Step 4: Tests PASS**

- [ ] **Step 5: Commit** `feat: staff assign fills a shift slot with a visit`

---

### Task 5: Claim (eligibility, leave, race) + open list

**Files:**
- Modify: `shifts/guards.py`, `shifts/service.py`, `shifts/router.py`, `shifts/schemas.py`
- Modify: `app/core/limiter.py` (user-id key helper)
- Test: `tests/shifts/test_shift_claim.py`

- [ ] **Step 1: Failing tests** (all asyncio)

```python
async def test_eligible_contractor_claims_open_shift(client, db_conn):
    fx = await seed_shift_world(db_conn)
    staff = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    shift = client.post("/v1/shifts", headers=staff, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-23T09:00:00+00:00",
        "scheduled_end": "2026-08-23T12:00:00+00:00",
        "required_slots": 2,
        "status": "published",
    }).json()
    token = contractor_token(
        fx["eligible_user_id"], fx["tenant_id"], fx["eligible_contractor_id"]
    )
    headers = {"Authorization": f"Bearer {token}"}
    opened = client.get("/v1/shifts/open", headers=headers,
                        params={"from": "2026-08-23T00:00:00+00:00", "to": "2026-08-24T00:00:00+00:00"})
    assert opened.status_code == 200
    assert len(opened.json()) == 1
    card = opened.json()[0]
    assert "address_line1" not in card
    assert card["suburb"] == "Sydney"
    assert card["open_slots"] == 2
    claimed = client.post(f"/v1/shifts/{shift['id']}/claim", headers=headers)
    assert claimed.status_code == 201, claimed.text
    assert claimed.json()["open_slots"] == 1
    assert claimed.json()["assignments"][0]["source"] == "claim"


async def test_ineligible_contractor_open_list_empty_and_claim_409(client, db_conn):
    fx = await seed_shift_world(db_conn)
    staff = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    shift = client.post("/v1/shifts", headers=staff, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-24T09:00:00+00:00",
        "scheduled_end": "2026-08-24T12:00:00+00:00",
        "required_slots": 1,
        "status": "published",
    }).json()
    headers = {"Authorization": f"Bearer {contractor_token(fx['ineligible_user_id'], fx['tenant_id'], fx['ineligible_contractor_id'])}"}
    opened = client.get("/v1/shifts/open", headers=headers,
                        params={"from": "2026-08-24T00:00:00+00:00", "to": "2026-08-25T00:00:00+00:00"})
    assert opened.json() == []
    claimed = client.post(f"/v1/shifts/{shift['id']}/claim", headers=headers)
    assert claimed.status_code == 409
    assert "eligibility_incomplete" in claimed.text


async def test_leave_blocks_claim(client, db_conn):
    fx = await seed_shift_world(db_conn)
    await db_conn.execute(
        """
        INSERT INTO workforce.contractor_leave (contractor_id, start_date, end_date, leave_type)
        VALUES ($1, DATE '2026-08-25', DATE '2026-08-25', 'annual')
        """,
        fx["eligible_contractor_id"],
    )
    staff = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    shift = client.post("/v1/shifts", headers=staff, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-25T09:00:00+00:00",
        "scheduled_end": "2026-08-25T12:00:00+00:00",
        "required_slots": 1,
        "status": "published",
    }).json()
    headers = {"Authorization": f"Bearer {contractor_token(fx['eligible_user_id'], fx['tenant_id'], fx['eligible_contractor_id'])}"}
    claimed = client.post(f"/v1/shifts/{shift['id']}/claim", headers=headers)
    assert claimed.status_code == 409
    assert "contractor_on_leave" in claimed.text


async def test_draft_not_in_open_list(client, db_conn):
    fx = await seed_shift_world(db_conn)
    staff = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    client.post("/v1/shifts", headers=staff, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-26T09:00:00+00:00",
        "scheduled_end": "2026-08-26T12:00:00+00:00",
        "required_slots": 1,
        "status": "draft",
    })
    headers = {"Authorization": f"Bearer {contractor_token(fx['eligible_user_id'], fx['tenant_id'], fx['eligible_contractor_id'])}"}
    opened = client.get("/v1/shifts/open", headers=headers,
                        params={"from": "2026-08-26T00:00:00+00:00", "to": "2026-08-27T00:00:00+00:00"})
    assert opened.json() == []


async def test_second_claim_when_full_is_409(client, db_conn):
    fx = await seed_shift_world(db_conn)
    staff = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'])}"}
    shift = client.post("/v1/shifts", headers=staff, json={
        "job_id": str(fx["job_id"]),
        "scheduled_start": "2026-08-27T09:00:00+00:00",
        "scheduled_end": "2026-08-27T12:00:00+00:00",
        "required_slots": 1,
        "status": "published",
    }).json()
    h1 = {"Authorization": f"Bearer {contractor_token(fx['eligible_user_id'], fx['tenant_id'], fx['eligible_contractor_id'])}"}
    assert client.post(f"/v1/shifts/{shift['id']}/claim", headers=h1).status_code == 201
    # second eligible worker: add contractor3 in this test via SQL (active, no required docs)
    ...
```

For the second-claim test, extend `seed_shift_world` with `eligible2_*` **or** insert a third contractor inline in that test (keep fixture at two contractors; third only in this test).

Cross-tenant: create second tenant, claim with foreign shift id → 404.

Idempotency: two POSTs with same `Idempotency-Key` return the same visit/assignment (use `get_cached_response` route_key=`POST /v1/shifts/claim`).

- [ ] **Step 2: Run — FAIL**

- [ ] **Step 3: Implement**

`OpenShiftOut` (slim): `id, job_title, client_name, scheduled_start, scheduled_end, required_slots, open_slots, suburb, postal_code`. No `location_label`, no assignments’ personal extra, no street.

`list_open_shifts`:
- actor contractor from JWT (`payload["contractor_id"]` or lookup like jobs router `_contractor_id_for_user` — **reuse jobs.router helper by moving `_contractor_id_for_user` to a shared auth helper if both need it**; smallest path: duplicate the 15-line lookup in shifts/router to avoid a drive-by refactor, accepted DRY exception of 15 lines).
- engagement must be active
- `evaluate_engagement_eligibility`; if not ok return `[]` (do not 409 the list)
- SQL: published, tenant, window overlap, `required_slots > (SELECT count(*) active assignments)`, contractor does not already have active assignment, and not on leave for the shift local dates

Leave helper in `guards.py`:

```python
async def assert_not_on_leave(conn, *, contractor_id, start, end) -> None:
    hit = await conn.fetchval(
        """
        SELECT 1 FROM workforce.contractor_leave
        WHERE contractor_id = $1
          AND start_date <= ($3::timestamptz AT TIME ZONE 'UTC')::date
          AND end_date >= ($2::timestamptz AT TIME ZONE 'UTC')::date
        LIMIT 1
        """,
        contractor_id,
        start,
        end,
    )
    if hit:
        raise HTTPException(status_code=409, detail="contractor_on_leave")
```

Use tenant timezone for the date conversion in a follow-up if UTC date-skew appears in tests (tests use UTC tenants).

`claim_shift`:
1. Resolve contractor from JWT only. If body contains `contractor_id` and it differs → 400 `contractor_id_not_allowed` (or ignore body entirely — **ignore body**, no field on `ClaimShiftRequest` empty model).
2. FOR UPDATE shift
3. published, capacity, engagement, eligibility (409 `eligibility_incomplete`), leave, overlap
4. insert visit `source='claim'`, assignment `source='claim'`
5. emit `visit.assigned`
6. store idempotency

Router:

```python
@router.get("/shifts/open", response_model=list[OpenShiftOut])
async def list_open_shifts(..., payload=Depends(require_permission("shifts.claim"))): ...

@router.post("/shifts/{shift_id}/claim", response_model=ShiftOut, status_code=201,
             dependencies=[Depends(require_active_subscription)])
@limiter.limit("20/minute", key_func=authenticated_user_limit_key)
async def claim_shift(...): ...
```

Add `authenticated_user_limit_key` in `app/core/limiter.py`: `sub` from JWT if present else IP. Pytest has `limiter.enabled = False`.

Declare `/shifts/open` **before** `/shifts/{shift_id}` so `open` is not parsed as a UUID.

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: contractors claim published open shifts`

---

### Task 6: Release, unassign, cancel shift

**Files:** `shifts/service.py`, `shifts/router.py`, `tests/shifts/test_shift_release_cancel.py`

- [ ] **Step 1: Failing tests**

- Contractor `POST /v1/shifts/{id}/release` when their visit is `scheduled` → assignment `released`, visit cancelled (reuse `cancel_visit` logic or `UPDATE visits SET status='cancelled'` + existing cancel endpoint internals). Slot reopens (`open_slots` +1).
- Contractor release after check-in → 409 `invalid_visit_status`.
- Staff `POST /v1/shifts/{id}/unassign` `{contractor_id}` same rules.
- Staff `POST /v1/shifts/{id}/cancel` cancels shift + all scheduled visits + assignments; 409 if any visit `checked_in` or `completed`.
- Other contractor cannot release someone else’s assignment → 404/403.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement**

Prefer calling existing `service.cancel_visit` from jobs if it is import-safe. If cancel_visit also emits events and closes time entries, use it. If it requires visits.manage, call the inner SQL helper — extract only if needed (YAGNI: duplicate the scheduled-visit cancel UPDATE in shifts service, 10 lines, plus `status='cancelled'` on assignment).

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: release slots and cancel unpublished coverage`

---

### Task 7: Recurrence generate writes shifts

**Files:**
- Modify: `jobs/schemas.py` `RecurrenceRuleCreate.contractor_id: UUID | None = None`, add `required_slots: int = 1`
- Modify: `jobs/service.py` `create_recurrence_rule` INSERT nullable contractor + required_slots
- Modify: `generate_visits_from_rule` → insert shift per occurrence/window; assign if `contractor_id` set
- Modify: `GenerateVisitsResponse` add `created_shift_ids: list[UUID]`
- Modify: `tests/jobs/test_recurrence_generate.py` (still expects visits when contractor set)
- Test: `tests/shifts/test_recurrence_generate_shifts.py`

- [ ] **Step 1: Failing tests**

```python
async def test_generate_without_contractor_creates_published_holes(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage', 'shifts.manage'])}"}
    rule = client.post(f"/v1/jobs/{fx['job_id']}/recurrence-rules", headers=headers, json={
        "rrule": "FREQ=WEEKLY;BYDAY=MO",
        "dtstart": "2026-08-03T00:00:00+00:00",
        "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        "required_slots": 2,
        "task_template": [],
        "form_requirements": [],
    })
    assert rule.status_code == 201, rule.text
    assert rule.json()["contractor_id"] is None
    gen = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules/{rule.json()['id']}/generate",
        headers=headers,
        json={"from": "2026-08-03T00:00:00+00:00", "to": "2026-08-10T00:00:00+00:00"},
    )
    assert gen.status_code == 200, gen.text
    assert len(gen.json()["created_shift_ids"]) >= 1
    assert gen.json()["created_visit_ids"] == []
    shift = client.get(f"/v1/shifts/{gen.json()['created_shift_ids'][0]}", headers=headers)
    assert shift.json()["status"] == "published"
    assert shift.json()["open_slots"] == 2


async def test_generate_with_contractor_fills_one_slot(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage', 'shifts.manage'])}"}
    rule = client.post(f"/v1/jobs/{fx['job_id']}/recurrence-rules", headers=headers, json={
        "contractor_id": str(fx["eligible_contractor_id"]),
        "rrule": "FREQ=WEEKLY;BYDAY=TU",
        "dtstart": "2026-08-04T00:00:00+00:00",
        "time_windows": [{"start_time": "09:00", "end_time": "12:00"}],
        "required_slots": 2,
        "task_template": [{"title": "Meds", "sort_order": 0}],
        "form_requirements": [],
    })
    gen = client.post(
        f"/v1/jobs/{fx['job_id']}/recurrence-rules/{rule.json()['id']}/generate",
        headers=headers,
        json={"from": "2026-08-04T00:00:00+00:00", "to": "2026-08-05T00:00:00+00:00"},
    )
    assert gen.status_code == 200, gen.text
    assert len(gen.json()["created_visit_ids"]) == 1
    shift = client.get(f"/v1/shifts/{gen.json()['created_shift_ids'][0]}", headers=headers).json()
    assert shift["open_slots"] == 1
    assert shift["assignments"][0]["contractor_id"] == str(fx["eligible_contractor_id"])
```

Update existing `test_generate_two_weeks_weekly_visits` to still pass: it sends `contractor_id`; expect both `created_visit_ids` and `created_shift_ids`. Dedup key becomes shift `(recurrence_rule_id, scheduled_start)` not visit.

If contractor on rule overlaps, `partial=true` still creates the shift with an open hole (skip assign, record skipped `visit_overlap`). `partial=false` abort whole txn. **This is the hole-friendly generate.**

When `contractor_id` is null, skip `_assert_active_engagement` on generate.

- [ ] **Step 2: FAIL** (contractor required)

- [ ] **Step 3: Implement generate loop**

Replace `_attempt_one` visit insert with:

1. Upsert/insert shift published (on unique recurrence occurrence conflict → already_generated)
2. If rule.contractor_id: try assign (overlap → skip or abort per `partial`)
3. Copy `task_template_json` / `form_requirements_json` onto the visit when assigning

Keep idempotency cache on generate.

- [ ] **Step 4: PASS** including old recurrence test

- [ ] **Step 5: Commit** `feat: recurrence generate publishes shifts with optional holes`

---

### Task 8: Manual visit wraps a one-slot published shift

**Files:** `jobs/service.py` `create_manual_visit`, `tests/jobs/test_manual_visit.py` (create if missing) + `tests/shifts/test_manual_visit_wraps_shift.py`

- [ ] **Step 1: Failing test**

Create manual visit as today. Assert a `work.shifts` row exists with `required_slots=1`, `status=published`, one assignment, `visit.shift_id` set, `source='manual'` on visit (keep source manual for back-compat; assignment source `staff_assign`).

- [ ] **Step 2: FAIL** (no shift row)

- [ ] **Step 3: Implement**

In `create_manual_visit` transaction: insert shift (copy job geofence) then `_insert_visit(..., shift_id=..., source='manual')` then assignment `staff_assign`.

- [ ] **Step 4: PASS** (existing smoke tests still pass)

- [ ] **Step 5: Commit** `feat: manual visits create a backing published shift`

---

### Task 9: Error catalog (Flutter)

**Files:** `frontend/lib/core/errors/app_failure.dart`, `frontend/test` if an error-code unit test exists

- [ ] **Step 1: Failing test** (add cases to existing failure parser test if present; else `frontend/test/core/errors/app_failure_shift_codes_test.dart`)

Codes: `shift_full`, `invalid_shift_status`, `contractor_on_leave`, `eligibility_incomplete` (already exists — map claim 409 to same inline message), `shift_not_found`.

Messages:
- `shift_full` → “This shift is already filled.”
- `invalid_shift_status` → “This shift can’t be changed in its current state.”
- `contractor_on_leave` → “You’re on leave for this day.”
- `shift_not_found` → “Shift not found.”

Presentation: all `inline`.

- [ ] **Step 2–4:** implement + PASS + commit `fix: map shift claim errors for contractors`

---

### Task 10: Flutter data layer

**Files:**
- Create: `frontend/lib/features/shifts/data/models/shift_models.dart`
- Create: `frontend/lib/features/shifts/data/datasources/shifts_remote_datasource.dart`
- Create: `frontend/lib/features/shifts/data/repositories/shifts_repository.dart`
- Modify: `frontend/lib/core/constants/api_paths.dart`
- Test: `frontend/test/features/shifts/shift_models_test.dart`

- [ ] **Step 1: Failing test** parse sample JSON for `ShiftOut` and `OpenShiftOut` (suburb present, address_line1 absent).

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement models + Dio calls**

Paths:

```dart
static const shifts = '$_v1/shifts';
static const shiftsOpen = '$_v1/shifts/open';
static String shift(String id) => '$shifts/$id';
static String shiftPublish(String id) => '${shift(id)}/publish';
static String shiftClaim(String id) => '${shift(id)}/claim';
static String shiftAssign(String id) => '${shift(id)}/assign';
static String shiftRelease(String id) => '${shift(id)}/release';
static String shiftUnassign(String id) => '${shift(id)}/unassign';
static String shiftCancel(String id) => '${shift(id)}/cancel';
```

Repository methods: `listStaff`, `get`, `create`, `publish`, `assign`, `listOpen`, `claim`, `release`. Wrap Dio in `AppFailure.fromDio`.

- [ ] **Step 4: PASS** `flutter test test/features/shifts/shift_models_test.dart`

- [ ] **Step 5: Commit** `feat: Flutter shifts API client`

---

### Task 11: Staff roster board

**Files:**
- Modify: `frontend/lib/features/shell/staff_shell.dart` label `Roster`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart` (or new `staff_roster_board_view.dart` used by same route)
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart` **or** new `staff_roster_controller.dart`
- Create: `frontend/lib/features/shifts/views/staff_shift_detail_view.dart`
- Modify: `visits_routes.dart` / `app_routes.dart` add `staffShiftDetail`
- Modify: `app_colors.dart` `openSlot` / `openSlotBackground`
- Test: `frontend/test/features/shifts/staff_roster_slot_pips_test.dart`

- [ ] **Step 1: Failing widget test** — given a `ShiftOut` with `required_slots=2`, `open_slots=1`, a pip row shows one filled and one open (find by `Key('slot-pip-filled')` / `Key('slot-pip-open')`).

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement**

Controller loads `ShiftsRepository.listStaff(from, to)` for the same 7-day window as today’s visits board. Keep job filter. Cards: title, client, time, pips. FAB or AppBar action: create shift (job picker + start/end + slots + draft/publish). Detail: assignments list, assign dropdown of active engagements (`contractors.read` already on staff), publish if draft, cancel if no in-progress visits.

Do not call visits board `load()` for this screen (reuse `ensureBoardLoaded` lesson: roster controller `onInit` only loads if this view is shown).

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: staff roster shows open and filled shift slots`

---

### Task 12: Contractor Mine | Open + claim

**Files:**
- Modify: `contractor_visits_list_view.dart`
- Modify: `contractor_visits_controller.dart`
- Modify: `visits_binding.dart` to put `ShiftsRepository` in GetX
- Test: `frontend/test/features/shifts/contractor_open_shifts_claim_test.dart`

- [ ] **Step 1: Failing test** — `ContractorVisitsController.selectTab('open')` calls repository `listOpen` (mocktail). `claim(id)` on success inserts the visit into `visits` and switches tab to mine.

- [ ] **Step 2: FAIL**

- [ ] **Step 3: Implement**

`SegmentedButton` Mine/Open. Open cards: job title, client name, suburb, time, “1 of 2 open”, Claim. Errors via existing `errorMessage` + `AppFailure` inline. After claim, `Get.toNamed(contractorVisitDetail)` with the new `visit_id` from assignment.

Permission: hide Open segment if `!hasPermission(shiftsClaim)` (invited/narrow JWT).

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: contractors browse and claim open shifts`

---

### Task 13: Recurrence form — optional contractor + slots

**Files:** `frontend/lib/features/jobs/views/recurrence_rule_form_view.dart` (and controller/models)

- [ ] **Step 1: Failing widget/unit test** — submit without contractor sends `contractor_id: null` and `required_slots: 2`.

- [ ] **Step 2: FAIL** (field required today)

- [ ] **Step 3: Implement**

Contractor dropdown includes “Unassigned (publish holes)”. Number field `Required workers` 1–8 default 1. Generate copy: “Creates published shifts for this window. Unfilled slots stay open for claim.” Remove “Generate with Partial” from the primary button label if still present (trial note); keep `partial` as a checkbox default off.

- [ ] **Step 4: PASS**

- [ ] **Step 5: Commit** `feat: recurrence can publish unassigned multi-worker shifts`

---

### Task 14: Security regression pack

**Files:** `tests/shifts/test_shift_security.py`

- [ ] **Step 1: Write tests first** (they fail until Task 5 exists; if Task 5 already landed, this is the hardening pack)

1. Contractor A cannot assign (403).
2. Contractor JWT from tenant B claiming tenant A shift id → 404.
3. `GET /v1/shifts/{id}` as contractor with `shifts.claim` only → 403 (staff list/get is not for contractors). Open list is the contractor read path.
4. Open JSON has no `address_line1`, `latitude`, `longitude`, `location_label`.
5. Claim body `{"contractor_id": "<victim>"}` still claims the JWT contractor (ignore field) — send extra field, assert assignment contractor is JWT’s id.

- [ ] **Step 2–4:** implement any gaps + PASS

- [ ] **Step 5: Commit** `test: lock down shift claim IDOR and open-shift PII`

---

## Test Plan & Verification

**Coverage target:** ≥90% lines on `app/modules/shifts/`; every new public function and error path has a test. Flutter: model parse + roster pip widget + claim controller mocktail.

**Critical paths (must pass before ship):**
- Staff create draft → publish 2-slot shift → assign one → eligible contractor claims remaining → both visits check-in path unchanged (`GET /v1/visits/{id}` works) → verified by Task 4 + 5 + existing visit check-in tests still green.
- Recurrence without contractor → published holes → claim → verified by Task 7 + 5.
- Recurrence with contractor + `required_slots=2` → 1 visit + 1 hole → verified by Task 7.
- Ineligible contractor: empty open list + claim 409 → Task 5.
- Leave: claim 409 → Task 5.
- Overlap: assign/claim 409 `visit_overlap` → Task 4/5.
- Full shift: second claim 409 `shift_full` → Task 5.
- Manual visit still creates a payable visit → Task 8 + existing payment tests.

**Edge cases & error paths:**
- Draft not claimable → Task 5 `test_draft_not_in_open_list`
- Cancel blocked when checked_in → Task 6
- Release after check-in 409 → Task 6
- Cross-tenant 404 → Task 14
- Idempotent claim replay → Task 5
- Generate `partial=false` overlap aborts; `partial=true` creates hole → Task 7
- `required_slots` 0 or 9 → 422 pydantic

**Regression guards:**
- `tests/jobs/test_recurrence_generate.py` still creates visits when contractor set
- `tests/jobs/test_visit_overlap.py` exclusion still fires
- `tests/payments/test_visit_payment_batch.py` unpaid completed visits still batch
- Staff visits board `ensureBoardLoaded` tests remain green (roster is additive)

**Verification commands:**
- Unit: `cd backend/timesheet-backend && pytest tests/shifts tests/jobs/test_recurrence_generate.py tests/jobs/test_visit_overlap.py -v` — expected: all pass
- Coverage: `cd backend/timesheet-backend && pytest tests/shifts --cov=app.modules.shifts --cov-report=term-missing --cov-fail-under=90` — expected: ≥90%
- Flutter: `cd frontend && flutter test test/features/shifts test/core/errors test/features/visits/staff_visits_skip_board_load_test.dart` — expected: all pass
- E2E: not in repo as a single command; smoke with demo tenant: publish 2-slot shift, claim as contractor1, assign contractor2 as staff

**Acceptance criteria (from spec):**
- [ ] Staff can publish a shift with unfilled slots → Task 3 + 11
- [ ] Eligible contractor can claim an open slot; visit appears for check-in → Task 5 + 12
- [ ] Ineligible contractor cannot see or claim → Task 5 + 14
- [ ] Multi-worker: `required_slots=N` yields N visits max → Task 4 + 5 + 7
- [ ] Leave hard-blocks claim; availability does not → Task 5
- [ ] Check-in / forms / pay still keyed to visits → Task 4 + 8 + payment regression
- [ ] Open-shift PII minimized → Task 5 + 14
- [ ] Recurrence can generate holes (null contractor) → Task 7 + 13
- [ ] Roster UI shows holes as first-class cards → Task 11

---

## Self-review

1. **Spec coverage:** Publish holes, claim, multi-worker, eligibility gate, leave, staff override, recurrence, manual wrap, Flutter staff+contractor, security pack — each has a task.
2. **Placeholders:** none. Fixture third contractor for full-shift test is inline SQL, not TBD.
3. **Types:** `ShiftOut`, `OpenShiftOut`, `required_slots`, `open_slots`, sources `claim`/`staff_assign` used consistently.
4. **TDD:** every task starts with a failing test. Coverage target 90% on new module.
5. **DRY/SOLID/YAGNI:** guards reuse eligibility + overlap; slim open DTO not shared with staff DTO; no grid/wizard/backfill.
6. **Trust boundary:** Task 5 + 14 + rate limit + JWT contractor + FOR UPDATE + audit override.
