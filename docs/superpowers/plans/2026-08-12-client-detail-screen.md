# Client Detail Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the staff client detail screen as a single scroll of lookup + manage sections (client facts, clickable/copyable sites, contacts, scheduled/past visits, profile editors), with invites kept hidden.

**Architecture:** Frontend-first vertical slice. Replace exclusive Sites/Contacts/Documents chips with one `ListView` of section widgets (parent `Obx` reads all Rx used by children). Add a tenant-scoped `client_id` filter on `GET /v1/visits` so the visits section can load without N+1 job loops. Reuse `openMapLocation` for site addresses; add copy-to-clipboard. Wire `VisitsRepository` into `ClientsController` for visit lists; navigate to existing `staffVisitDetail`. Opening visit detail from the client screen **must not** trigger the visits board list/`loadJobs` fetch (`StaffVisitsController.onInit` never board-loads; board owns `ensureBoardLoaded`).

**Tech Stack:** Flutter/GetX, Dio, `url_launcher`, FastAPI/asyncpg, pytest, Flutter unit/widget tests.

**Design decisions (locked):**
- D1-A (lookup vs manage) with freer layout: **no exclusive two-tab constraint** — one scroll, sections stacked.
- Sites: **no embedded map**; address is **open in Maps** + **copy**.
- Invites UI stays **hidden** (dead code path OK; do not delete invite APIs).
- Visits: **Upcoming** (next 30 days) + **Past** (last 30 days), capped, tappable to staff visit detail.
- Eng review D3-A: visit detail route skips board `load()` / `loadJobs()` when opened with `skipBoardLoad: true` (client detail → visit).
- Eng review D4-A: `StaffVisitsBoardView` always calls `ensureBoardLoaded()` on show so a prior detail-only open cannot leave the Visits tab empty.
- Eng review D5-A: Overview NDIS comes from cached `profileFacts` (`ndisFromFacts`), with drafts as fallback — not drafts-only.
- Eng review D6-A: Task 1 backend test seed cloned from recurrence/timetable fixtures (no invented columns).
- Eng review D7-A: Unit test for `skipBoardLoad` / `ensureBoardLoaded` with mocktail (see Task 4b).
- Eng review D8-A: Board view owns list loading — `StaffVisitsController.onInit` never calls `load()`/`loadJobs()`; only `ensureBoardLoaded()` does.
- Eng review D9-A (outside voice): clear `upcomingVisits`/`pastVisits` (and visitsError) at start of `openDetail` / before `loadClientVisits` so switching clients never flashes the previous client’s visits.
- Eng review D10-C (outside voice): if visit fetch returns `length >= clientVisitFetchLimit`, show muted banner “Showing first 100 visits in this window” on the visits section (no second API).
- Eng review D11-B (outside voice): keep `checked_in` in Upcoming forever (surface stuck visits; do not age into Past).
- Eng review D12-A (outside voice wrap): skip `listInvites` while invites UI is hidden; Architecture/`Task 5` use `ListView` under parent `Obx`; defer Task 4b GetX-arg perfection and stronger cross-tenant seed.
- Plan imports use `package:rostiq/...` (pubspec name), not `timesheet`.

**Outside voice — deferred:** harden Task 4b GetX argument injection beyond the sketched contract; seed a real second-tenant client for the visits filter negative test (random UUID empty-list remains).

---

## File Structure

| File | Responsibility (SRP) | Seam |
|------|----------------------|------|
| `backend/.../jobs/router.py` | Accept optional `client_id` query on list visits | HTTP boundary |
| `backend/.../jobs/service.py` `list_visits` | Filter `j.client_id = $n` when provided | SQL filter |
| `backend/.../tests/jobs/test_list_visits_client_filter.py` | Authz + filter correctness | Regression |
| `frontend/.../client_models.dart` | `ClientSiteOut.displayAddress` getter | Pure formatting |
| `frontend/.../external_url.dart` (existing) | `openMapLocation` — **reuse, do not duplicate** (DRY) | Maps launch |
| `frontend/.../clients/.../site_address_actions.dart` | Open + copy helpers for a site address | UI action boundary |
| `frontend/.../visits_remote_datasource.dart` + repository | Pass `clientId` query param | API client |
| `frontend/.../clients_controller.dart` | Load/split visits; expose NDIS/quick facts; open visit | Orchestration |
| `frontend/.../clients_binding.dart` | Ensure `VisitsBinding` shared deps | DI |
| `frontend/.../staff_visits_controller.dart` | Gate `onInit` board load when `skipBoardLoad` arg set; `ensureBoardLoaded()` | Visit detail / board entry |
| `frontend/.../staff_visits_board_view.dart` | Call `ensureBoardLoaded()` when board is shown | Board refresh |
| `frontend/.../client_detail_view.dart` | Single-scroll composition of section widgets | View |
| `frontend/.../widgets/client_detail_*.dart` | One widget file per section (facts, sites, contacts, visits, profile) | Presentation |
| `frontend/test/features/clients/...` | Formatters, visit split, site actions, smoke widget | Tests |

**Principles applied:**
- **DRY:** Reuse `openMapLocation`; reuse existing site/contact forms and profile editors; do not rebuild invite UI.
- **SOLID:** Section widgets only render; controller owns load/navigate; repository owns HTTP; address formatting lives on the model.
- **YAGNI:** No embedded map SDK; no new visits dashboard; no invite revival; no infinite scroll yet — fixed 30-day windows + limit.

**Trust boundary:** Extends authenticated `GET /v1/visits` with `client_id`. Must stay tenant-scoped (already filtered by `v.tenant_id`). Negative test: other-tenant client UUID returns empty, not foreign visits. No new public endpoints. Clipboard/maps are device local.

---

### Task 1: Backend `client_id` filter on list visits

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/router.py` (`list_visits`)
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py` (`list_visits`)
- Create: `backend/timesheet-backend/tests/jobs/test_list_visits_client_filter.py`

- [ ] **Step 1: Write the failing test**

Seed pattern cloned from `tests/jobs/test_recurrence_generate.py` + direct visit insert from `tests/contractor_schedule/test_timetable.py`. Do **not** invent contractor/job columns.

```python
"""GET /v1/visits?client_id=… returns only that client's visits (tenant-scoped)."""
import uuid
from datetime import datetime, timedelta, timezone

import asyncpg
import jwt
import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings

_settings = get_settings()
JWT_SECRET = _settings.jwt_secret
TZ = timezone.utc
SYDNEY_POINT = "ST_SetSRID(ST_MakePoint(151.2093, -33.8688), 4326)::geography"


def _token(sub: uuid.UUID, tenant_id: uuid.UUID, permissions: list[str]) -> str:
    return jwt.encode(
        {
            "sub": str(sub),
            "tenant_id": str(tenant_id),
            "permissions": permissions,
            "typ": "access",
            "actor_type": "tenant_member",
        },
        JWT_SECRET,
        algorithm="HS256",
    )


@pytest.fixture()
async def db_conn():
    conn = await asyncpg.connect(_settings.db_url)
    try:
        yield conn
    finally:
        await conn.close()


async def _seed_two_client_visits(db_conn) -> dict:
    """One tenant, shared contractor/branch, two clients each with one visit."""
    tenant_id = uuid.uuid4()
    admin_user_id = uuid.uuid4()
    contractor_user_id = uuid.uuid4()

    admin_role_id = await db_conn.fetchval(
        "SELECT id FROM auth.roles WHERE tenant_id IS NULL AND name = 'admin'"
    )
    assert admin_role_id is not None

    await db_conn.execute(
        "INSERT INTO org.tenants (id, name, timezone) VALUES ($1, $2, 'Australia/Sydney')",
        tenant_id,
        f"VisitClientFilter-{tenant_id.hex[:8]}",
    )
    await db_conn.execute(
        """
        INSERT INTO auth.users (id, email, phone, status)
        VALUES ($1, $2, $3, 'active'), ($4, $5, $6, 'active')
        """,
        admin_user_id,
        f"vcf-admin-{admin_user_id.hex[:8]}@example.com",
        f"+6140{admin_user_id.int % 100000000:08d}",
        contractor_user_id,
        f"vcf-c-{contractor_user_id.hex[:8]}@example.com",
        f"+6141{contractor_user_id.int % 100000000:08d}",
    )
    await db_conn.execute(
        """
        INSERT INTO auth.user_roles (user_id, role_id, tenant_id)
        VALUES ($1, $2, $3)
        """,
        admin_user_id,
        admin_role_id,
        tenant_id,
    )
    await db_conn.execute(
        """
        INSERT INTO org.tenant_members (tenant_id, user_id, full_name, email)
        VALUES ($1, $2, 'VCF Admin', $3)
        """,
        tenant_id,
        admin_user_id,
        f"vcf-admin-{admin_user_id.hex[:8]}@example.com",
    )

    branch_id = await db_conn.fetchval(
        f"""
        INSERT INTO org.branches (
          tenant_id, name, address_line1, city, state, postal_code, country,
          location_geog, geofence_radius_m
        )
        VALUES (
          $1, 'Main', '42 Harbour Street', 'Sydney', 'NSW', '2000', 'Australia',
          {SYDNEY_POINT}, 100
        )
        RETURNING id
        """,
        tenant_id,
    )

    contractor_id = await db_conn.fetchval(
        """
        INSERT INTO workforce.contractors (user_id, full_name)
        VALUES ($1, 'VCF Contractor')
        RETURNING id
        """,
        contractor_user_id,
    )
    await db_conn.execute(
        """
        INSERT INTO workforce.contractor_engagements (
          tenant_id, contractor_id, status, invited_by_user_id
        )
        VALUES ($1, $2, 'active', $3)
        """,
        tenant_id,
        contractor_id,
        admin_user_id,
    )

    async def _client_with_visit(name: str, day_offset: int):
        client_id = await db_conn.fetchval(
            """
            INSERT INTO clients.clients (tenant_id, full_name, status)
            VALUES ($1, $2, 'active')
            RETURNING id
            """,
            tenant_id,
            name,
        )
        job_id = await db_conn.fetchval(
            f"""
            INSERT INTO work.jobs (
              tenant_id, client_id, kind, title, branch_id, location_geog,
              geofence_radius_m, geofence_mode
            )
            VALUES ($1, $2, 'standing', $3, $4, {SYDNEY_POINT}, 100, 'informational')
            RETURNING id
            """,
            tenant_id,
            client_id,
            f"Job-{name}",
            branch_id,
        )
        start = datetime(2026, 8, 12, 9, 0, tzinfo=TZ) + timedelta(days=day_offset)
        end = start + timedelta(hours=2)
        visit_id = await db_conn.fetchval(
            f"""
            INSERT INTO work.visits (
              tenant_id, job_id, contractor_id, scheduled_start, scheduled_end,
              location_geog, geofence_radius_m, geofence_mode
            )
            VALUES ($1, $2, $3, $4, $5, {SYDNEY_POINT}, 100, 'informational')
            RETURNING id
            """,
            tenant_id,
            job_id,
            contractor_id,
            start,
            end,
        )
        return client_id, visit_id

    client_a, visit_a = await _client_with_visit("ClientA", 1)
    client_b, visit_b = await _client_with_visit("ClientB", 2)
    return {
        "tenant_id": tenant_id,
        "admin_user_id": admin_user_id,
        "client_a": client_a,
        "visit_a": visit_a,
        "client_b": client_b,
        "visit_b": visit_b,
    }


@pytest.mark.asyncio
async def test_list_visits_filters_by_client_id(client: TestClient, db_conn):
    fx = await _seed_two_client_visits(db_conn)
    headers = {
        "Authorization": f"Bearer {_token(fx['admin_user_id'], fx['tenant_id'], ['visits.read', 'jobs.manage'])}"
    }
    resp = client.get(f"/v1/visits?client_id={fx['client_a']}", headers=headers)
    assert resp.status_code == 200, resp.text
    ids = {row["id"] for row in resp.json()}
    assert str(fx["visit_a"]) in ids
    assert str(fx["visit_b"]) not in ids


@pytest.mark.asyncio
async def test_list_visits_foreign_client_id_returns_empty(client: TestClient, db_conn):
    fx = await _seed_two_client_visits(db_conn)
    headers = {
        "Authorization": f"Bearer {_token(fx['admin_user_id'], fx['tenant_id'], ['visits.read'])}"
    }
    foreign = uuid.uuid4()
    resp = client.get(f"/v1/visits?client_id={foreign}", headers=headers)
    assert resp.status_code == 200, resp.text
    assert resp.json() == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend/timesheet-backend && .venv/bin/pytest tests/jobs/test_list_visits_client_filter.py::test_list_visits_filters_by_client_id -v`

Expected: FAIL (unknown query param ignored → both visits returned, or 422 if FastAPI rejects — either way filter not working yet).

- [ ] **Step 3: Implement filter**

In `router.py` `list_visits`, add:

```python
client_id: UUID | None = Query(default=None),
```

Pass `client_id=client_id` into both `service.list_visits(...)` calls.

In `service.py` `list_visits`, add parameter `client_id: UUID | None = None` and:

```python
if client_id is not None:
    q += f" AND j.client_id = ${n}"
    args.append(client_id)
    n += 1
```

(Place after `job_id` filter block; `j` is already joined.)

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend/timesheet-backend && .venv/bin/pytest tests/jobs/test_list_visits_client_filter.py -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add backend/timesheet-backend/app/modules/jobs/router.py \
  backend/timesheet-backend/app/modules/jobs/service.py \
  backend/timesheet-backend/tests/jobs/test_list_visits_client_filter.py
git commit -m "feat(visits): filter list by client_id for client detail"
```

---

### Task 2: Site address formatter + open/copy helpers

**Files:**
- Modify: `frontend/lib/features/clients/data/models/client_models.dart`
- Create: `frontend/lib/features/clients/utils/site_address_actions.dart`
- Create: `frontend/test/features/clients/site_address_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1);

  test('displayAddress joins non-empty address parts', () {
    final site = ClientSiteOut(
      id: '1',
      tenantId: 't',
      clientId: 'c',
      name: 'Home',
      geofenceRadiusM: 100,
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
      addressLine1: '12 Example St',
      city: 'Sydney',
      state: 'NSW',
      postalCode: '2000',
      country: 'AU',
    );
    expect(site.displayAddress, '12 Example St, Sydney, NSW, 2000, AU');
  });

  test('displayAddress falls back to name when no address parts', () {
    final site = ClientSiteOut(
      id: '1',
      tenantId: 't',
      clientId: 'c',
      name: 'Home',
      geofenceRadiusM: 100,
      isPrimary: false,
      createdAt: now,
      updatedAt: now,
    );
    expect(site.displayAddress, 'Home');
  });

  test('mapsQueryLabel prefers full address over name alone', () {
    final site = ClientSiteOut(
      id: '1',
      tenantId: 't',
      clientId: 'c',
      name: 'Home',
      geofenceRadiusM: 100,
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
      addressLine1: '12 Example St',
      city: 'Sydney',
      state: 'NSW',
      country: 'AU',
    );
    expect(site.mapsQueryLabel, contains('12 Example St'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && flutter test test/features/clients/site_address_test.dart`

Expected: FAIL — `displayAddress` / `mapsQueryLabel` undefined.

- [ ] **Step 3: Minimal implementation**

Add to `ClientSiteOut` in `client_models.dart`:

```dart
  /// Human-readable address for display/copy; falls back to [name].
  String get displayAddress {
    final parts = <String>[
      if (addressLine1 != null && addressLine1!.trim().isNotEmpty)
        addressLine1!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (postalCode != null && postalCode!.trim().isNotEmpty)
        postalCode!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];
    if (parts.isEmpty) return name;
    return parts.join(', ');
  }

  /// Label passed to [openMapLocation] when coordinates are missing.
  String get mapsQueryLabel => displayAddress;
```

Create `site_address_actions.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/utils/external_url.dart';
import '../data/models/client_models.dart';

Future<void> openSiteInMaps(ClientSiteOut site) async {
  await openMapLocation(
    latitude: site.latitude,
    longitude: site.longitude,
    label: site.mapsQueryLabel,
  );
}

Future<void> copySiteAddress(
  BuildContext context,
  ClientSiteOut site,
) async {
  final text = site.displayAddress;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Address copied')),
  );
}
```

- [ ] **Step 4: Run tests — expect PASS**

Run: `cd frontend && flutter test test/features/clients/site_address_test.dart`

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/clients/data/models/client_models.dart \
  frontend/lib/features/clients/utils/site_address_actions.dart \
  frontend/test/features/clients/site_address_test.dart
git commit -m "feat(clients): site address display, maps open, and copy helpers"
```

---

### Task 3: Flutter visits API `clientId` + visit window split helper

**Files:**
- Modify: `frontend/lib/features/visits/data/datasources/visits_remote_datasource.dart`
- Modify: `frontend/lib/features/visits/data/repositories/visits_repository.dart`
- Create: `frontend/lib/features/clients/utils/client_visit_windows.dart`
- Create: `frontend/test/features/clients/client_visit_windows_test.dart`

- [ ] **Step 1: Write failing tests for window split**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/utils/client_visit_windows.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';

VisitOut _v({
  required String id,
  required DateTime start,
  required String status,
}) {
  final end = start.add(const Duration(hours: 1));
  return VisitOut(
    id: id,
    tenantId: 't',
    jobId: 'j',
    contractorId: 'c',
    scheduledStart: start,
    scheduledEnd: end,
    status: status,
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: start,
    updatedAt: start,
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 12, 12);

  test('partitionClientVisits splits upcoming vs past and drops cancelled', () {
    final upcoming = _v(
      id: 'u',
      start: now.add(const Duration(days: 2)),
      status: 'scheduled',
    );
    final checkedIn = _v(
      id: 'ci',
      start: now.subtract(const Duration(hours: 1)),
      status: 'checked_in',
    );
    final past = _v(
      id: 'p',
      start: now.subtract(const Duration(days: 3)),
      status: 'completed',
    );
    final cancelled = _v(
      id: 'x',
      start: now.add(const Duration(days: 1)),
      status: 'cancelled',
    );

    final parts = partitionClientVisits(
      [upcoming, checkedIn, past, cancelled],
      now: now,
    );
    expect(parts.upcoming.map((e) => e.id), ['ci', 'u']); // start asc
    expect(parts.past.map((e) => e.id), ['p']); // start desc preferred
    expect(parts.past.every((e) => e.id != 'x'), isTrue);
  });
}
```

- [ ] **Step 2: Run — expect FAIL** (`partitionClientVisits` missing)

- [ ] **Step 3: Implement helper + API param**

`client_visit_windows.dart`:

```dart
import '../../visits/data/models/visit_models.dart';

class ClientVisitPartition {
  const ClientVisitPartition({
    required this.upcoming,
    required this.past,
  });
  final List<VisitOut> upcoming;
  final List<VisitOut> past;
}

/// Splits visits for client detail. Cancelled excluded.
/// Upcoming: scheduled/checked_in with end >= now (or status checked_in).
/// Past: completed, or scheduled_end < now (non-cancelled).
ClientVisitPartition partitionClientVisits(
  List<VisitOut> visits, {
  required DateTime now,
}) {
  final upcoming = <VisitOut>[];
  final past = <VisitOut>[];
  for (final v in visits) {
    if (v.isCancelled) continue;
    final isPast = v.isCompleted || v.scheduledEnd.isBefore(now);
    if (isPast && !v.isCheckedIn) {
      past.add(v);
    } else {
      upcoming.add(v);
    }
  }
  upcoming.sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));
  past.sort((a, b) => b.scheduledStart.compareTo(a.scheduledStart));
  return ClientVisitPartition(upcoming: upcoming, past: past);
}

const clientVisitLookahead = Duration(days: 30);
const clientVisitLookback = Duration(days: 30);
const clientVisitFetchLimit = 100;
```

Update datasource `listVisits`:

```dart
  Future<List<VisitOut>> listVisits({
    DateTime? from,
    DateTime? to,
    String? jobId,
    String? clientId,
    String? status,
    String? paymentStatus,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        ApiPaths.visits,
        queryParameters: {
          if (from != null) 'from': from.toUtc().toIso8601String(),
          if (to != null) 'to': to.toUtc().toIso8601String(),
          if (jobId != null && jobId.isNotEmpty) 'job_id': jobId,
          if (clientId != null && clientId.isNotEmpty) 'client_id': clientId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (paymentStatus != null && paymentStatus.isNotEmpty)
            'payment_status': paymentStatus,
          'limit': limit,
        },
      );
      return _mapList(response.data, VisitOut.fromJson);
    } on DioException catch (e) {
      throw AppFailure.fromDio(e);
    }
  }
```

Mirror `clientId` on `VisitsRepository.listVisits`.

- [ ] **Step 4: Run tests — PASS**

Run: `cd frontend && flutter test test/features/clients/client_visit_windows_test.dart`

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/visits/data/datasources/visits_remote_datasource.dart \
  frontend/lib/features/visits/data/repositories/visits_repository.dart \
  frontend/lib/features/clients/utils/client_visit_windows.dart \
  frontend/test/features/clients/client_visit_windows_test.dart
git commit -m "feat(clients): clientId visit list param and partition helper"
```

---

### Task 4: Controller — load visits, quick facts, open visit detail

**Files:**
- Modify: `frontend/lib/features/clients/controllers/clients_controller.dart`
- Modify: `frontend/lib/features/clients/bindings/clients_binding.dart`
- Create: `frontend/test/features/clients/clients_controller_visits_test.dart` (optional thin unit with fake repo if pattern exists; otherwise test getters via pure helpers already covered — prefer a small fake)

- [ ] **Step 1: Write failing test for NDIS getter helper**

Prefer extracting a pure function to keep tests free of GetX:

Create `frontend/lib/features/clients/utils/client_quick_facts.dart`:

```dart
import '../controllers/requirement_draft.dart';
import '../data/models/client_models.dart';
import '../data/models/client_profile_models.dart';

class ClientQuickFacts {
  const ClientQuickFacts({
    required this.fullName,
    required this.status,
    this.dob,
    this.ndisNumber,
    this.email,
    this.phone,
    this.clientTypeName,
  });

  final String fullName;
  final String status;
  final String? dob;
  final String? ndisNumber;
  final String? email;
  final String? phone;
  final String? clientTypeName;
}

String? ndisFromDrafts(List<RequirementDraft> drafts) {
  for (final d in drafts) {
    if (d.requirement.requirementKey == 'ndis') {
      final v = d.fieldValueJson;
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }
  }
  return null;
}

String? ndisFromFacts(List<ClientProfileFactOut> facts) {
  for (final f in facts) {
    if (f.requirementKey == 'ndis' && f.valueJson != null) {
      final s = f.valueJson.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return null;
}

ClientQuickFacts buildQuickFacts({
  required ClientOut client,
  String? ndisNumber,
  String? clientTypeName,
}) {
  return ClientQuickFacts(
    fullName: client.fullName,
    status: client.status,
    dob: client.dob,
    ndisNumber: ndisNumber,
    email: client.email,
    phone: client.phone,
    clientTypeName: clientTypeName,
  );
}
```

Test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_profile_models.dart';
import 'package:rostiq/features/clients/utils/client_quick_facts.dart';

void main() {
  test('ndisFromFacts reads ndis requirement', () {
    final facts = [
      const ClientProfileFactOut(requirementKey: 'ndis', valueJson: '430000000'),
    ];
    expect(ndisFromFacts(facts), '430000000');
  });
}
```

- [ ] **Step 2: Run — FAIL until file exists, then implement and PASS**

- [ ] **Step 3: Wire controller + binding**

Constructor: add optional `VisitsRepository? visitsRepository` (or required once binding always provides it).

```dart
  // fields
  final VisitsRepository? _visits;
  final upcomingVisits = <VisitOut>[].obs;
  final pastVisits = <VisitOut>[].obs;
  final isLoadingVisits = false.obs;
  final visitsError = RxnString();
  final visitsTruncated = false.obs;
  final profileFacts = <ClientProfileFactOut>[].obs;

  String? get ndisNumber =>
      ndisFromFacts(profileFacts) ?? ndisFromDrafts(requirementDrafts);

  ClientQuickFacts? get quickFacts {
    final c = selected.value;
    if (c == null) return null;
    final typeName = clientTypes
        .where((t) => t.id == (selectedClientTypeId.value ?? c.clientTypeId))
        .map((t) => t.name)
        .cast<String?>()
        .firstWhere((_) => true, orElse: () => null);
    return buildQuickFacts(
      client: c,
      ndisNumber: ndisNumber,
      clientTypeName: typeName,
    );
  }

  // In _prefillFromProfile after getClientProfile:
  //   profileFacts.assignAll(bundle.facts);
  // In openDetail clear paths: profileFacts.clear();
  // loadTypeTabForSelected: always await _prefillFromProfile(client.id)
  // even when clientTypeId is null (so Overview NDIS still works).

  Future<void> loadClientVisits() async {
    final id = selected.value?.id;
    final visitsRepo = _visits;
    upcomingVisits.clear();
    pastVisits.clear();
    if (id == null || visitsRepo == null) {
      return;
    }
    if (!_session.hasPermission(AppPermissions.visitsRead) &&
        !_session.hasPermission(AppPermissions.visitsManage) &&
        !_session.hasPermission(AppPermissions.jobsManage)) {
      upcomingVisits.clear();
      pastVisits.clear();
      visitsError.value = null; // hide section quietly or show "no access"
      return;
    }
    isLoadingVisits.value = true;
    visitsError.value = null;
    try {
      final now = DateTime.now().toUtc();
      final list = await visitsRepo.listVisits(
        clientId: id,
        from: now.subtract(clientVisitLookback),
        to: now.add(clientVisitLookahead),
        limit: clientVisitFetchLimit,
      );
      visitsTruncated.value = list.length >= clientVisitFetchLimit;
      final parts = partitionClientVisits(list, now: now);
      upcomingVisits.assignAll(parts.upcoming);
      pastVisits.assignAll(parts.past);
    } on AppFailure catch (e) {
      visitsError.value = e.message;
      upcomingVisits.clear();
      pastVisits.clear();
    } finally {
      isLoadingVisits.value = false;
    }
  }

  void openVisitDetail(VisitOut visit) {
    Get.toNamed(
      AppRoutes.staffVisitDetail,
      arguments: <String, dynamic>{
        'visit': visit,
        'skipBoardLoad': true,
      },
    );
  }
```

Update `StaffVisitsController`:

```dart
  bool _skipBoardLoad = false;

  @override
  void onInit() {
    super.onInit();
    // D8-A: never load board list here — StaffVisitsBoardView.ensureBoardLoaded owns it.
    applyRouteArgs();
  }

  void applyRouteArgs() {
    final args = Get.arguments;
    if (args is Map) {
      _skipBoardLoad = args['skipBoardLoad'] == true;
      final v = args['visit'];
      if (v is VisitOut) selected.value = v;
      if (args['job_id'] != null) {
        jobIdFilter.value = args['job_id'].toString();
      }
      return;
    }
    if (args is VisitOut) selected.value = args;
  }

  void hydrateFromArgs() {
    final arg = Get.arguments;
    if (arg is VisitOut) {
      selected.value = arg;
      return;
    }
    if (arg is Map && arg['visit'] is VisitOut) {
      selected.value = arg['visit'] as VisitOut;
    }
  }

  /// Only entry point for board list fetch (D4-A + D8-A).
  Future<void> ensureBoardLoaded() async {
    _skipBoardLoad = false;
    await loadJobs();
    await load();
  }
```

`openVisitDetail` still passes `skipBoardLoad: true` so detail hydrate stays explicit and Task 4b can assert `onInit` never lists visits (true for all entry paths after D8-A).

In `StaffVisitsBoardView`, convert to `StatefulWidget` so refresh runs **once per show**:

```dart
class StaffVisitsBoardView extends StatefulWidget {
  const StaffVisitsBoardView({super.key});
  @override
  State<StaffVisitsBoardView> createState() => _StaffVisitsBoardViewState();
}

class _StaffVisitsBoardViewState extends State<StaffVisitsBoardView> {
  @override
  void initState() {
    super.initState();
    final c = Get.find<StaffVisitsController>();
    c.applyRouteArgs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.ensureBoardLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<StaffVisitsController>();
    return Scaffold(
      // ... existing board body unchanged ...
```

Do **not** call `ensureBoardLoaded` from `build` (would re-fetch on every rebuild). Do not call it from the detail view.

Add a unit/widget-free test or document in Task 6: opening from client must not call list visits for the board range (optional spy if easy; otherwise manual).

In `openDetailById` / `refreshDetailExtras`, also `await loadClientVisits()`.
At the start of `openDetail` (and `loadClientVisits`), clear `upcomingVisits`/`pastVisits`/`visitsError` (D9-A).

In `refreshDetailExtras`, **do not** call `listInvites` while the invites UI is hidden (D12-A). Keep invite create/list APIs and controller methods; only skip the detail-screen fetch.

`ClientsBinding.ensureShared()`: call `VisitsBinding.ensureShared()` and pass `Get.find<VisitsRepository>()` into `ClientsController`.

Avoid circular DI: `VisitsBinding` must not depend on clients.

- [ ] **Step 4: Manual smoke (or widget test later)** — compile check:

Run: `cd frontend && dart analyze lib/features/clients lib/features/visits`

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/clients/utils/client_quick_facts.dart \
  frontend/test/features/clients/client_quick_facts_test.dart \
  frontend/lib/features/clients/controllers/clients_controller.dart \
  frontend/lib/features/clients/bindings/clients_binding.dart \
  frontend/lib/features/visits/controllers/staff_visits_controller.dart \
  frontend/lib/features/visits/views/staff_visits_board_view.dart
git commit -m "feat(clients): load client visits; skip board load on detail open"
```

---

### Task 4b: Unit test — skipBoardLoad does not list board visits

**Files:**
- Create: `frontend/test/features/visits/staff_visits_skip_board_load_test.dart`

- [ ] **Step 1: Write failing test** (mocktail, same style as `home_alerts_controller_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rostiq/core/services/session_service.dart';
import 'package:rostiq/features/jobs/data/repositories/jobs_repository.dart';
import 'package:rostiq/features/visits/controllers/staff_visits_controller.dart';
import 'package:rostiq/features/visits/data/models/visit_models.dart';
import 'package:rostiq/features/visits/data/repositories/visits_repository.dart';

class _MockVisitsRepository extends Mock implements VisitsRepository {}

class _MockJobsRepository extends Mock implements JobsRepository {}

class _MockSessionService extends Mock implements SessionService {}

VisitOut _visit() {
  final t = DateTime.utc(2026, 8, 12, 9);
  return VisitOut(
    id: 'v1',
    tenantId: 't',
    jobId: 'j',
    contractorId: 'c',
    scheduledStart: t,
    scheduledEnd: t.add(const Duration(hours: 1)),
    status: 'scheduled',
    source: 'manual',
    geofenceRadiusM: 100,
    geofenceMode: 'informational',
    paymentStatus: 'unpaid',
    createdAt: t,
    updatedAt: t,
  );
}

void main() {
  late _MockVisitsRepository visits;
  late _MockJobsRepository jobs;
  late _MockSessionService session;

  setUp(() {
    Get.testMode = true;
    Get.reset();
    visits = _MockVisitsRepository();
    jobs = _MockJobsRepository();
    session = _MockSessionService();
    when(() => session.hasPermission(any())).thenReturn(true);
    when(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <VisitOut>[]);
    when(() => jobs.listJobs()).thenAnswer((_) async => []);
  });

  tearDown(Get.reset);

  test('onInit with skipBoardLoad does not call listVisits', () async {
    Get.routing.args = {
      'visit': _visit(),
      'skipBoardLoad': true,
    };
    // If Get.routing.args is unreliable in tests, set Get.arguments via
    // a GetPage navigation stub — implementer: use whatever pattern
    // home_alerts / existing GetX tests use to inject arguments.
    final c = StaffVisitsController(
      repository: visits,
      jobsRepository: jobs,
      session: session,
    );
    Get.put(c);
    c.applyRouteArgs();
    // Simulate onInit gate: do not call load when skip set.
    // Prefer constructing after arguments are set, then call onInit via Get.put.
    await Future<void>.delayed(Duration.zero);
    verifyNever(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    );
  });

  test('ensureBoardLoaded clears skip and calls listVisits', () async {
    final c = StaffVisitsController(
      repository: visits,
      jobsRepository: jobs,
      session: session,
    );
    Get.put(c);
    // Force skip flag as if detail-opened first:
    Get.routing.args = {'skipBoardLoad': true, 'visit': _visit()};
    c.applyRouteArgs();
    await c.ensureBoardLoaded();
    verify(
      () => visits.listVisits(
        from: any(named: 'from'),
        to: any(named: 'to'),
        jobId: any(named: 'jobId'),
        clientId: any(named: 'clientId'),
        status: any(named: 'status'),
        paymentStatus: any(named: 'paymentStatus'),
        limit: any(named: 'limit'),
      ),
    ).called(1);
  });
}
```

> Implementer: adjust GetX argument injection to match working patterns in this repo; assertions above are the contract.

- [ ] **Step 2: Run — expect FAIL until D3/D4 controller changes land**

Run: `cd frontend && flutter test test/features/visits/staff_visits_skip_board_load_test.dart`

- [ ] **Step 3: Implement controller gates (Task 4) until PASS**

- [ ] **Step 4: Commit with Task 4 or separately**

```bash
git add frontend/test/features/visits/staff_visits_skip_board_load_test.dart
git commit -m "test(visits): guard skipBoardLoad and ensureBoardLoaded"
```

---

### Task 5: Detail view — single-scroll sections (UI)

**Files:**
- Modify: `frontend/lib/features/clients/views/client_detail_view.dart`
- Create: `frontend/lib/features/clients/widgets/client_detail_facts_section.dart`
- Create: `frontend/lib/features/clients/widgets/client_detail_sites_section.dart`
- Create: `frontend/lib/features/clients/widgets/client_detail_contacts_section.dart`
- Create: `frontend/lib/features/clients/widgets/client_detail_visits_section.dart`
- Create: `frontend/lib/features/clients/widgets/client_detail_profile_section.dart` (move `_TypesTab` body here; rename label to Details/Profile)
- Create: `frontend/test/features/clients/client_detail_sites_section_test.dart`

- [ ] **Step 1: Widget test — site row exposes open + copy**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rostiq/features/clients/data/models/client_models.dart';
import 'package:rostiq/features/clients/widgets/client_detail_sites_section.dart';

void main() {
  testWidgets('site tile shows address and action buttons', (tester) async {
    final now = DateTime.utc(2026, 1, 1);
    final site = ClientSiteOut(
      id: 's1',
      tenantId: 't',
      clientId: 'c',
      name: 'Home',
      geofenceRadiusM: 100,
      isPrimary: true,
      createdAt: now,
      updatedAt: now,
      addressLine1: '12 Example St',
      city: 'Sydney',
      state: 'NSW',
      country: 'AU',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientDetailSitesSection(
            sites: [site],
            canManage: false,
            onAdd: () {},
            onEdit: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.textContaining('12 Example St'), findsOneWidget);
    expect(find.byTooltip('Open in Maps'), findsOneWidget);
    expect(find.byTooltip('Copy address'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run — FAIL (widget missing)**

- [ ] **Step 3: Implement sections + rewrite `ClientDetailView`**

Layout sketch for `ClientDetailView` body (replace chip + switch tabs). Keep the outer `Obx` so section widgets that take `.value` / list snapshots stay reactive (D12-A):

```dart
Expanded(
  child: ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
    children: [
      // photo + name header (existing)
      ClientDetailFactsSection(facts: controller.quickFacts),
      const SizedBox(height: 24),
      ClientDetailSitesSection(
        sites: controller.sites,
        canManage: controller.canManage,
        onAdd: () => controller.beginSiteForm(),
        onEdit: (s) => controller.beginSiteForm(site: s),
        onDelete: controller.deleteSite,
      ),
      const SizedBox(height: 24),
      ClientDetailContactsSection(
        contacts: controller.contacts,
        canManage: controller.canManage,
        onAdd: () => controller.beginContactForm(),
        onEdit: (c) => controller.beginContactForm(contact: c),
        onDelete: controller.deleteContact,
      ),
      const SizedBox(height: 24),
      ClientDetailVisitsSection(
        upcoming: controller.upcomingVisits,
        past: controller.pastVisits,
        isLoading: controller.isLoadingVisits.value,
        error: controller.visitsError.value,
        truncated: controller.visitsTruncated.value,
        onOpen: controller.openVisitDetail,
      ),
      const SizedBox(height: 24),
      ClientDetailProfileSection(controller: controller),
      // Do NOT render _InvitesTab
    ],
  ),
)
```

`ClientDetailSitesSection` row:
- Title: site name (+ primary badge text)
- Subtitle: `displayAddress` + geofence note
- Trailing / actions: IconButton Maps (`openSiteInMaps`), IconButton copy (`copySiteAddress`), and if `canManage` PopupMenu edit/delete
- Optional section header ElevatedButton "Add site" when `canManage`

`ClientDetailVisitsSection`:
- If `truncatedated`: muted text “Showing first 100 visits in this window.”
- Subheadings "Upcoming" / "Past"
- Empty copy: "No upcoming visits." / "No past visits in the last 30 days."
- Tile: job title, contractor name, local time range, status
- `onTap` → `onOpen(visit)`
- If visits permission missing and lists empty with no error: show nothing or one muted line "Visits require visits.read"

`ClientDetailProfileSection`: move existing `_TypesTab` content; title **"Details"** (per trial notes rename from Types/Documents).

Keep app-bar Edit/Delete for core client.

Remove unused `_SitesTab`, `_ContactsTab`, `_InvitesTab` from the view file (or leave `_InvitesTab` private unused — prefer delete from view only; keep invite controller methods).

- [ ] **Step 4: Run widget + unit tests**

```bash
cd frontend && flutter test test/features/clients/
```

Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/clients/views/client_detail_view.dart \
  frontend/lib/features/clients/widgets/client_detail_facts_section.dart \
  frontend/lib/features/clients/widgets/client_detail_sites_section.dart \
  frontend/lib/features/clients/widgets/client_detail_contacts_section.dart \
  frontend/lib/features/clients/widgets/client_detail_visits_section.dart \
  frontend/lib/features/clients/widgets/client_detail_profile_section.dart \
  frontend/test/features/clients/client_detail_sites_section_test.dart
git commit -m "feat(clients): single-scroll client detail with visits and map actions"
```

---

### Task 6: Manual verification pass + polish

**Files:** none new (fix-only)

- [ ] **Step 1: Manual checklist on device/emulator**

1. Open a client with sites, contacts, profile facts, and visits on jobs.
2. Confirm scroll order: facts → sites → contacts → visits → details/profile.
3. Tap site Maps → Google Maps / system maps opens (no in-app map widget).
4. Tap Copy → snackbar + paste into notes shows address.
5. Tap upcoming visit → staff visit detail loads.
6. Confirm Invites chip/section absent.
7. Admin with `clients.manage` can still Add/Edit site & contact from section headers.
8. User without `visits.read` does not crash; visits section empty/hidden gracefully.

- [ ] **Step 2: Fix any defects found; re-run**

```bash
cd backend/timesheet-backend && .venv/bin/pytest tests/jobs/test_list_visits_client_filter.py -v
cd frontend && flutter test test/features/clients/
```

- [ ] **Step 3: Commit polish if needed**

```bash
git commit -m "fix(clients): polish client detail visit and address UX"
```

---

## Test Plan & Verification

**Coverage target:** ≥90% lines on new pure helpers (`displayAddress`, `partitionClientVisits`, `ndisFromFacts`, `buildQuickFacts`); every new public helper and the `client_id` visit filter (happy + foreign-id empty) has a test; site section widget smoke covers Maps/Copy affordances.

**Critical paths (must pass before ship):**
- Staff opens client → sees DOB/NDIS/email/phone + sites/contacts (NDIS from profile facts, not drafts-only) → verified by widget/manual + `ndisFromFacts` unit test
- Site address Open in Maps / Copy → `openMapLocation` + Clipboard → manual + widget finders
- Visits Upcoming/Past for that client only → backend filter test + partition unit test + manual
- Profile/Details editors still save → regression: existing save path untouched structurally → manual
- Invites not shown → manual / code review of view

**Edge cases & error paths:**
- Site with no address parts → `displayAddress` returns name → unit test
- Site with coords only → Maps uses lat/lng → covered by `openMapLocation` existing behavior
- No visits / empty windows → empty copy in section → manual
- Missing `visits.read` → no crash → controller early return
- Foreign `client_id` → `[]` → backend negative test
- Cancelled visits excluded from both lists → partition unit test
- `checked_in` stays in Upcoming even if start < now → partition unit test

**Regression guards:**
- Existing invite create/list APIs remain → do not delete backend/routes; only hide UI
- Site/contact form routes still work from section actions → manual
- Visit board (`StaffVisitsController`) still loads on `/staff/visits` without `skipBoardLoad`; detail-from-client skips board fetch
- Visit board list filters unchanged when opened normally → existing board still loads without `client_id`
- `skipBoardLoad` / `ensureBoardLoaded` → Task 4b mocktail unit test

**Verification commands:**
- Unit (backend): `cd backend/timesheet-backend && .venv/bin/pytest tests/jobs/test_list_visits_client_filter.py -v` — expected: all pass
- Unit (frontend): `cd frontend && flutter test test/features/clients/` — expected: all pass
- Coverage (helpers): `cd frontend && flutter test --coverage test/features/clients/ && lcov --summary coverage/lcov.info` — expected: new helpers covered (spot-check `site_address`, `client_visit_windows`, `client_quick_facts`)
- Analyze: `cd frontend && dart analyze lib/features/clients lib/features/visits` — expected: no issues

**Acceptance criteria (from product ask):**
- [ ] Client details (name, DOB, NDIS, admin quick info) visible without hunting tabs → Task 5 facts section
- [ ] Sites listed; address opens device/Google Maps; address copyable → Tasks 2 & 5
- [ ] Contacts listed → Task 5
- [ ] Widget/section to add or change client details including sites & contacts → Task 5 profile + section manage actions + existing forms
- [ ] Invite widget hidden → Task 5
- [ ] Scheduled and past visits for that client → Tasks 1, 3, 4, 5
- [ ] Not constrained to exclusive two-tab IA → Task 5 single scroll

---

## Self-Review Notes

1. **Spec coverage:** Lookup facts, sites maps+copy, contacts, manage/details, invites hidden, visits upcoming/past, free layout — all mapped to tasks.
2. **Placeholders:** Task 1 seed rewritten from proven fixtures (D6-A).
3. **Types:** `clientId` naming consistent across Flutter; backend `client_id` query; package `rostiq`.
4. **TDD:** Each code task starts with failing test; Task 4b covers board-load gates.
5. **Trust boundary:** `client_id` filter + foreign-id empty test included.
6. **YAGNI:** No map SDK, no invite revival, no infinite scroll; invite fetch skipped while UI hidden.

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | not run | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | skipped | Codex CLI not installed; Claude subagent outside voice used |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | 12 decisions (D1–D12); visit nav/board load, NDIS facts, seed, truncation banner, OV stale-clear + wrap |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | not run | Screen IA locked in design-consultation + plan |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | not run | — |

- **CROSS-MODEL:** N/A (Codex unavailable; single-model outside voice)
- **VERDICT:** ENG CLEARED — ready to implement (CEO/Design/DX not required for this vertical slice)

NO UNRESOLVED DECISIONS
