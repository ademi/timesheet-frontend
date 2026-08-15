# Client-First Support (Hide Jobs) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Staff work client-first — demote the Jobs nav, keep **Support** / **Ongoing support** as the standing-`job` noun for now, resolve/create support under a client (thin API), and keep a hidden advanced Supports list.

> **Eng review:** CLEAR (2026-08-15) — D1 Support noun · D2 auto-ensure · D3/D10 no-site 422 · D4/D11 closed→new open.

**Architecture:** Keep `work.jobs` and existing `/v1/jobs/*` (including `POST /v1/jobs/ongoing-support`). Add client-scoped **get/ensure ongoing-support** endpoints that wrap the standing open job for a client. Flutter removes Jobs from `StaffShellNav`, routes create/book through Clients + Roster with **client** as the primary control, and keeps existing Support copy in `job_copy.dart` (do not rename to Work arrangement in this slice). No DB rename.

**Tech Stack:** FastAPI + asyncpg + Pydantic, existing `jobs`/`clients` modules, Flutter/GetX, `job_copy.dart`, `StaffShellNav`, mocktail/widget tests.

**Locked decisions (from product Q&A 2026-08-15):**
- D1: Slice = **client-first create + demote Jobs nav** (not nav-only; not full route path rewrite of every `/staff/jobs/…` URL).
- D2: Global list = **hidden advanced** “Supports” (Settings link + deep route), not a primary tab.
- D3: Roster filters = **client primary**; show support/job filter **only when selected client has >1 open jobs** (else hide).
- D4: **Cancel TODOS T12** (job-centric create). Client-first is the product decision.
- D5: Backend = **thin client-scoped helpers** + keep `work.jobs`; no broad API rename.
- D6: Staff noun = **Support** / **Ongoing support** / list **Supports** (product: stick with Support for now; defer industry-neutral rename). **Not** “Engagement” (collides with `workforce.contractor_engagements`). **Not** “Job” in new staff chrome/copy. Eng-review D1: Support confirmed 2026-08-15.
- D7: Existing `POST /v1/jobs/ongoing-support` stays (creates support + first pattern + holes). New endpoints only for **read/ensure** the standing support without forcing a pattern.
- D9: **Auto-ensure** on book-one (eng-review): if client has no open standing support, `ensure` creates it via `create_job` before shift create. Pattern/recurrence still via Start ongoing support. Not B (require Start first) or C (ad-hoc-only book).
- D10: **Ensure without site/branch → 422** `site_or_branch_required` (eng-review): do not soft-create null site or invent a default Primary site. Book-one surfaces same error.
- D11: **Closed standing exists → ensure creates new open standing** (eng-review); do not reopen closed rows in this slice.
- D8: Internal code may still say `Job`/`JobsRepository`; user-facing strings go through copy helpers.

---

## Out of scope

- Renaming DB table `work.jobs` or Flutter class `JobOut`
- Contractor Open-tab / “job board” language (open shifts — different noun)
- Multi-support-per-client product expansion (constraint `jobs_one_open_standing_per_client` stays)
- Moving form-template routes off `/staff/jobs/…` paths (deep links OK; not linked from primary nav)
- Drag, hour grid, healthcare-specific “care plan” features

---

## Domain (staff-facing)

```text
Client
  └── Support / Ongoing support  (= standing work.jobs row)
        ├── Patterns (recurrence rules)
        └── Roster tiles (shifts / visits)
```

Create flows always start at **Client** (or Roster → pick client). The standing support is ensured under the hood.

---

## Trust boundary (CSO)

New staff reads/writes on `/v1/clients/{id}/ongoing-support*`. Crosses tenant client + job data. No public routes.

| Threat | Control | Test |
|--------|---------|------|
| IDOR other-tenant client | `tenant_id` from JWT on client + job SELECT | other-tenant client → 404 |
| Create support without jobs.manage | `jobs.manage` on ensure | `jobs.read` → 403 |
| Read without jobs.read | `jobs.read` or `jobs.manage` on GET | no permission → 403 |
| Ensure creates second standing job | Reuse `jobs_one_open_standing_per_client` / existing create_job conflict | second ensure returns existing; conflict path covered |

---

## File structure

| File | SRP | Seam |
|------|-----|------|
| `backend/.../jobs/service.py` (+ thin clients router handlers or jobs router under clients prefix) | `get_ongoing_support` / `ensure_ongoing_support` | `GET/POST …/clients/{id}/ongoing-support` |
| `backend/.../jobs/schemas.py` | Reuse `JobOut` as response | Same DTO |
| `frontend/.../jobs/utils/job_copy.dart` | Staff labels for support/kind (keep existing) | Single copy source |
| `frontend/.../shell/staff_shell.dart` | Remove Jobs destination | Nav |
| `frontend/.../payroll/views/staff_tenant_settings_view.dart` | Link “Supports” | Advanced entry |
| `frontend/.../jobs/views/jobs_list_view.dart` | Title Supports; not in shell | Advanced list |
| `frontend/.../clients/widgets/client_detail_support_section.dart` | Support CTAs | Client detail |
| `frontend/.../visits/…` | Client-first book + conditional support filter | Roster |
| `TODOS.md` | Cancel T12 | Product backlog |

**DRY:** Reuse `create_job`, `JobOut`, `createOngoingSupport` for pattern start, keep `defaultOngoingTitle`.

**YAGNI:** No new occurrence store; no Jobs→Supports DB migration; no dual nav; no Support→Work arrangement rename in this slice.

---

## Task 1: Copy helpers — keep Support language (no Job in chrome)

**Files:**
- Verify: `frontend/lib/features/jobs/utils/job_copy.dart` (already uses Ongoing support)
- Modify only if any new chrome still says “Job” where staff should see Support
- Test: `frontend/test/features/jobs/job_copy_test.dart` (create if missing; else extend)

- [ ] **Step 1: Failing tests (lock current Support strings)**

```dart
test('kindLabel standing is Ongoing support', () {
  expect(kindLabel('standing'), 'Ongoing support');
});

test('defaultOngoingTitle uses client name', () {
  expect(defaultOngoingTitle('Pat Nguyen'), 'Pat Nguyen support');
  expect(defaultOngoingTitle('  '), 'Ongoing support');
});

test('jobListSubtitle uses support label', () {
  expect(
    jobListSubtitle(kind: 'standing', status: 'open', hasSite: true, hasBranch: false),
    contains('Ongoing support'),
  );
});
```

- [ ] **Step 2: Run — expect FAIL if tests missing; PASS if helpers already correct**

Run: `cd frontend && flutter test test/features/jobs/job_copy_test.dart`

- [ ] **Step 3: Implement only if needed**

Do **not** rename Support → Work arrangement in this slice. Keep:

```dart
String kindLabel(String kind) => switch (kind) {
      'standing' => 'Ongoing support',
      'ad_hoc' => 'One-off',
      _ => kind,
    };

String defaultOngoingTitle(String clientName) {
  final name = clientName.trim();
  return name.isEmpty ? 'Ongoing support' : '$name support';
}
```

Leave `app_failure.dart` “ongoing support” conflict copy as-is.

- [ ] **Step 4: Grep staff UI for user-visible “Job(s)” in create/book chrome introduced by this plan; replace with Support wording only where demoting Jobs nav leaves orphan “Job” labels. Do not wholesale rewrite Support → Arrangement.

- [ ] **Step 5: Commit**

```bash
cd frontend && flutter test test/features/jobs/job_copy_test.dart
git add lib/features/jobs/utils/job_copy.dart test/features/jobs/job_copy_test.dart
git commit -m "$(cat <<'EOF'
test: lock Ongoing support copy helpers

EOF
)"
```

---

## Task 2: Demote Jobs from staff shell; advanced Supports entry

**Files:**
- Modify: `frontend/lib/features/shell/staff_shell.dart`
- Modify: `frontend/test/features/shell/staff_shell_nav_test.dart`
- Modify: `frontend/lib/features/jobs/views/jobs_list_view.dart` (AppBar title `Supports`)
- Modify: `frontend/lib/features/payroll/views/staff_tenant_settings_view.dart` (ListTile → `AppRoutes.staffJobs`)
- Optional: `frontend/lib/app/routes/app_routes.dart` comment that `staffJobs` is advanced Supports list

- [ ] **Step 1: Failing nav test**

```dart
test('destinations do not include Jobs label', () {
  tokenStorage.claims = const JwtClaims(
    sub: 'u1',
    tenantId: 't1',
    permissions: ['auth.session', 'clients.read', 'jobs.read', 'shifts.read'],
  );
  final labels = StaffShellNav.destinations().map((d) => d.label).toList();
  expect(labels, isNot(contains('Jobs')));
  expect(labels, contains('Clients'));
  expect(labels, contains('Roster'));
});
```

- [ ] **Step 2: Run — expect FAIL** (Jobs still present)

- [ ] **Step 3: Remove Jobs `_StaffDest` from `StaffShellNav._all`. Keep route registered in `JobsPages` / `shell_routes`.

Settings:

```dart
ListTile(
  leading: const Icon(Icons.work_outline),
  title: const Text('Supports'),
  subtitle: const Text('Advanced list of ongoing support'),
  onTap: () => Get.toNamed(AppRoutes.staffJobs),
),
```

`JobsListView` title: `Supports`.

- [ ] **Step 4: Pass + commit**

```bash
cd frontend && flutter test test/features/shell/staff_shell_nav_test.dart
git commit -m "$(cat <<'EOF'
feat: demote Jobs nav to Settings Supports list

EOF
)"
```

---

## Task 3: Backend GET + ensure client ongoing-support

**Files:**
- Modify: `backend/timesheet-backend/app/modules/jobs/service.py`
- Modify: `backend/timesheet-backend/app/modules/clients/router.py` (or jobs router with clients prefix — prefer clients router calling jobs service)
- Test: `backend/timesheet-backend/tests/jobs/test_client_ongoing_support.py` (new; do not overwrite existing `test_ongoing_support.py`)

- [ ] **Step 1: Failing tests**

```python
@pytest.mark.asyncio
async def test_get_ongoing_support_returns_standing_job(client, db_conn):
    fx = await seed_shift_world(db_conn)  # or seed with standing job + client
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.read', 'jobs.manage'])}"
    }
    # Assume fx has client_id with open standing job job_id
    resp = client.get(f"/v1/clients/{fx['client_id']}/ongoing-support", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["id"] == str(fx["job_id"])
    assert resp.json()["kind"] == "standing"


@pytest.mark.asyncio
async def test_get_ongoing_support_missing_404(client, db_conn):
    fx = await seed_shift_world(db_conn)
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.read'])}"
    }
    # client with no standing job — use a fresh client id from fixture or insert
    resp = client.get(f"/v1/clients/{fx['client_without_job_id']}/ongoing-support", headers=headers)
    assert resp.status_code == 404
    assert resp.json()["detail"] == "ongoing_support_not_found"


@pytest.mark.asyncio
async def test_ensure_ongoing_support_creates_once(client, db_conn):
    fx = await seed_client_without_job(db_conn)  # helper: client + primary site
    headers = {
        "Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.manage'])}"
    }
    r1 = client.post(f"/v1/clients/{fx['client_id']}/ongoing-support/ensure", headers=headers, json={})
    assert r1.status_code == 200
    r2 = client.post(f"/v1/clients/{fx['client_id']}/ongoing-support/ensure", headers=headers, json={})
    assert r2.status_code == 200
    assert r1.json()["id"] == r2.json()["id"]


@pytest.mark.asyncio
async def test_ensure_ongoing_support_other_tenant_404(client, db_conn):
    a = await seed_shift_world(db_conn)
    b = await seed_shift_world(db_conn)
    resp = client.post(
        f"/v1/clients/{b['client_id']}/ongoing-support/ensure",
        headers={"Authorization": f"Bearer {staff_token(a['admin_user_id'], a['tenant_id'], ['jobs.manage'])}"},
        json={},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_ensure_requires_jobs_manage(client, db_conn):
    fx = await seed_client_without_job(db_conn)
    resp = client.post(
        f"/v1/clients/{fx['client_id']}/ongoing-support/ensure",
        headers={"Authorization": f"Bearer {staff_token(fx['admin_user_id'], fx['tenant_id'], ['jobs.read'])}"},
        json={},
    )
    assert resp.status_code == 403
```

If `seed_shift_world` already has a client+job, reuse it; add a small helper in the test file for client-without-job (mirror payments/seed patterns: insert client + site).

- [ ] **Step 2: Run — expect FAIL** (route missing)

- [ ] **Step 3: Implement**

```python
async def get_ongoing_support(
    conn, *, tenant_id: UUID, client_id: UUID
) -> JobOut:
    client = await conn.fetchval(
        "SELECT id FROM clients.clients WHERE id = $1 AND tenant_id = $2",
        client_id, tenant_id,
    )
    if client is None:
        raise HTTPException(status_code=404, detail="client_not_found")
    row = await conn.fetchrow(
        """
        SELECT id FROM work.jobs
        WHERE tenant_id = $1 AND client_id = $2 AND kind = 'standing' AND status = 'open'
        ORDER BY created_at ASC
        LIMIT 1
        """,
        tenant_id, client_id,
    )
    if row is None:
        raise HTTPException(status_code=404, detail="ongoing_support_not_found")
    return await get_job(conn, tenant_id=tenant_id, job_id=row["id"])


async def ensure_ongoing_support(
    conn, *, tenant_id: UUID, client_id: UUID, title: str | None = None
) -> JobOut:
    try:
        return await get_ongoing_support(conn, tenant_id=tenant_id, client_id=client_id)
    except HTTPException as exc:
        if exc.status_code != 404 or exc.detail != "ongoing_support_not_found":
            raise
    client_name = await conn.fetchval(
        "SELECT full_name FROM clients.clients WHERE id = $1 AND tenant_id = $2",
        client_id, tenant_id,
    )
    # primary site if any
    site_id = await conn.fetchval(
        """
        SELECT id FROM clients.client_sites
        WHERE client_id = $1 AND tenant_id = $2
        ORDER BY is_primary DESC, created_at ASC
        LIMIT 1
        """,
        client_id, tenant_id,
    )
    if site_id is None:
        # D10: also check branch if product allows branch-only clients later; today fail hard
        raise HTTPException(status_code=422, detail="site_or_branch_required")
    job = await create_job(
        conn,
        tenant_id=tenant_id,
        body=JobCreate(
            kind="standing",
            title=title or f"{(client_name or '').strip() or 'Client'} support",
            client_id=client_id,
            client_site_id=site_id,
        ),
    )
    return job
```

Add test: ensure with client that has no sites → 422 `site_or_branch_required`.

Router on clients:

```python
@router.get("/{client_id}/ongoing-support", response_model=JobOut)
async def get_client_ongoing_support(
    request: Request,
    client_id: UUID,
    payload: Annotated[dict, Depends(require_any_permission("jobs.read", "jobs.manage"))],
    conn: ...,
):
    return await jobs_service.get_ongoing_support(
        conn, tenant_id=UUID(payload["tenant_id"]), client_id=client_id
    )

@router.post("/{client_id}/ongoing-support/ensure", response_model=JobOut)
async def ensure_client_ongoing_support(
    request: Request,
    client_id: UUID,
    payload: Annotated[dict, Depends(require_permission("jobs.manage"))],
    conn: ...,
    body: EnsureOngoingSupportIn | None = None,
):
    return await jobs_service.ensure_ongoing_support(
        conn,
        tenant_id=UUID(payload["tenant_id"]),
        client_id=client_id,
        title=(body.title if body else None),
    )
```

```python
class EnsureOngoingSupportIn(BaseModel):
    title: str | None = Field(default=None, max_length=200)
```

Limiter: 30/min get, 10/min ensure. Import `JobOut` from jobs schemas into clients router (or re-export). Avoid circular imports: keep service functions in `jobs/service.py`, call from clients router.

- [ ] **Step 4: Pass + commit**

```bash
cd backend/timesheet-backend && DOTENV_PATH=../.env uv run pytest tests/jobs/test_client_ongoing_support.py -q
git commit -m "$(cat <<'EOF'
feat: get and ensure client ongoing-support endpoints

EOF
)"
```

---

## Task 4: Flutter client ongoing-support get/ensure

**Files:**
- Modify: `frontend/lib/core/constants/api_paths.dart`
- Modify: `frontend/lib/features/jobs/data/datasources/jobs_remote_datasource.dart` (or clients remote — prefer jobs remote calling client paths to keep JobOut parsing)
- Modify: `frontend/lib/features/jobs/data/repositories/jobs_repository.dart`
- Test: `frontend/test/features/jobs/job_models_test.dart` or datasource unit with mock Dio if pattern exists; at minimum repository method wired + path constants test via usage in controller tests in Task 5

- [ ] **Step 1: Path + parse smoke**

```dart
// api_paths.dart
static String clientOngoingSupport(String clientId) =>
    '$_v1/clients/$clientId/ongoing-support';
static String clientOngoingSupportEnsure(String clientId) =>
    '$_v1/clients/$clientId/ongoing-support/ensure';
```

```dart
Future<JobOut> getOngoingSupport(String clientId) async {
  final response = await _dio.get<Map<String, dynamic>>(
    ApiPaths.clientOngoingSupport(clientId),
  );
  return JobOut.fromJson(_require(response.data));
}

Future<JobOut> ensureOngoingSupport(String clientId, {String? title}) async {
  final response = await _dio.post<Map<String, dynamic>>(
    ApiPaths.clientOngoingSupportEnsure(clientId),
    data: {if (title != null && title.trim().isNotEmpty) 'title': title.trim()},
  );
  return JobOut.fromJson(_require(response.data));
}
```

- [ ] **Step 2: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat: add Flutter client ongoing-support get/ensure client

EOF
)"
```

(If the repo requires a failing test first for datasource: add a small mocktail test that verifies path + method; otherwise Task 5 controller tests cover it.)

---

## Task 5: Roster + client detail — client-first resolve support

**Files:**
- Modify: `frontend/lib/features/visits/controllers/staff_visits_controller.dart`
- Modify: `frontend/lib/features/visits/views/staff_visits_board_view.dart`
- Modify: `frontend/lib/features/clients/controllers/clients_controller.dart` (open support via get/ensure as needed)
- Test: `frontend/test/features/visits/staff_roster_client_first_test.dart`

- [ ] **Step 1: Controller tests**

```dart
test('openJobsForClientFilter empty when one support', () {
  final jobs = [
    JobOut(/* clientId: 'c1', id: 'j1', kind standing open */),
  ];
  expect(jobsForClientFilter(jobs, clientId: 'c1').length, 1);
  expect(shouldShowSupportFilter(jobs, clientId: 'c1'), isFalse);
});

test('shouldShowSupportFilter true when two open jobs same client', () {
  // rare today but D3 requires the gate
  expect(shouldShowSupportFilter(twoJobsSameClient, clientId: 'c1'), isTrue);
});

test('bookOneForClient ensures support then creates shift', () async {
  when(() => jobs.ensureOngoingSupport('c1')).thenAnswer((_) async => support);
  when(() => shifts.createShift(any())).thenAnswer((_) async => created);
  await controller.bookOneForClient(
    clientId: 'c1',
    start: DateTime(2026, 8, 20, 9),
    end: DateTime(2026, 8, 20, 12),
  );
  verify(() => jobs.ensureOngoingSupport('c1')).called(1);
  final req = verify(() => shifts.createShift(captureAny())).captured.single as ShiftCreate;
  expect(req.jobId, support.id);
});
```

Pure helpers live next to controller or in `lib/features/visits/roster/support_filter.dart`:

```dart
List<JobOut> jobsForClientFilter(List<JobOut> jobs, {required String clientId}) =>
    jobs.where((j) => j.clientId == clientId && j.status == 'open').toList();

bool shouldShowSupportFilter(List<JobOut> jobs, {required String? clientId}) {
  if (clientId == null || clientId.isEmpty) return false;
  return jobsForClientFilter(jobs, clientId: clientId).length > 1;
}
```

- [ ] **Step 2: UI**

- Roster filters: keep **All clients** dropdown; hide job/support dropdown unless `shouldShowSupportFilter`.
- Book-one sheet: pick **client** (required); call `ensureOngoingSupport` then existing create shift; do not ask user for “job”.
- Client detail: “Start ongoing support” → existing ongoing-support composer; “Open support” → job detail via `getOngoingSupport`; “Book one” → ensure + book sheet.

- [ ] **Step 3: Pass + commit**

```bash
cd frontend && flutter test test/features/visits/ test/features/clients/client_detail_support_section_test.dart
git commit -m "$(cat <<'EOF'
feat: resolve ongoing support from client on roster and client detail

EOF
)"
```

---

## Task 6: Cancel T12 + README/TODO note

**Files:**
- Modify: `TODOS.md` — mark T12 cancelled with pointer to this plan
- Optional one-line in `frontend/docs/superpowers/plans/2026-08-14-people-day-roster-board.md` out-of-scope note that Jobs demote is this plan (no large rewrite)

- [ ] **Step 1: Edit TODOS**

```markdown
### T12 — CANCELLED — Roster/create: shifts from jobs not clients

**Cancelled 2026-08-15:** Product decision is client-first (Support under Client).
See `frontend/docs/superpowers/plans/2026-08-15-client-first-work-arrangements.md`.
```

- [ ] **Step 2: Commit** (in repo that owns TODOS — parent or frontend; if TODOS is only in parent monorepo folder `/home/ademi/projects/timesheet/TODOS.md`, commit where that file is tracked)

```bash
git add TODOS.md
git commit -m "$(cat <<'EOF'
docs: cancel T12 job-centric create in favour of client-first

EOF
)"
```

---

## Task 7: Manual smoke

- [ ] Staff shell: no Jobs tab; Clients + Roster present.
- [ ] Settings → Supports opens former jobs list titled Supports.
- [ ] Client without support → Start ongoing support → pattern composer still works (`POST /jobs/ongoing-support`).
- [ ] Client with support → Book one from client/roster without seeing “Job”.
- [ ] Roster client filter works; support dropdown hidden for single standing job.
- [ ] `jobs.read` only: can GET support; ensure 403.
- [ ] Other-tenant client ensure → 404.

---

## Test Plan & Verification

**Coverage target:** ≥90% lines on `get_ongoing_support` / `ensure_ongoing_support`; every new route has authz + tenant tests; Flutter: support filter helpers 100% branches; shell nav test asserts Jobs absent.

**Critical paths (must pass before ship):**
- Client → ensure support → book shift → Task 5 test + smoke
- Demote Jobs nav → `staff_shell_nav_test`
- GET/ensure tenant isolation → `test_client_ongoing_support.py`
- Pattern start still via ongoing-support → existing `test_ongoing_support.py` green

**Edge cases & error paths:**
- Client with no site/branch on ensure → **422** `site_or_branch_required` (D10) → assert friendly copy on Flutter book-one
- Second ensure → same id
- Closed standing only → ensure creates **new** open id (D11); GET still 404 until ensure
- Client filter All → no support dropdown
- Two open jobs same client → dropdown appears (synthetic test)

**Regression guards:**
- `tests/jobs/test_ongoing_support.py` — pattern composer unchanged
- Horizon / roster board tests still pass
- `jobs_one_open_standing_per_client` — ensure does not insert duplicate

**Verification commands:**
- Unit backend: `cd backend/timesheet-backend && DOTENV_PATH=../.env uv run pytest tests/jobs/test_client_ongoing_support.py tests/jobs/test_ongoing_support.py -q`
- Unit Flutter: `cd frontend && flutter test test/features/shell/staff_shell_nav_test.dart test/features/jobs/job_copy_test.dart test/features/visits/ test/features/clients/client_detail_support_section_test.dart`
- E2E: Task 7 manual on `flutter run`

**Acceptance criteria:**
- [ ] No Jobs in primary staff nav → Task 2
- [ ] Advanced Supports list from Settings → Task 2
- [ ] Staff copy says Ongoing support, not Job/Engagement → Task 1
- [ ] Create/book starts from client; support ensured → Tasks 3–5
- [ ] Client filter primary; support filter only if >1 job → Task 5 / D3
- [ ] T12 cancelled → Task 6
- [ ] Thin API get/ensure; `work.jobs` unchanged → Task 3 / D5

---

## Self-review notes

- Spec coverage: Q1B–Q5B + naming D6 mapped to tasks.
- Placeholders: none intentional; test fixtures may use `seed_shift_world` field names — implementer aligns to real fixture keys.
- Trust boundary: CSO table + Task 3 negative tests.
- DRY/SOLID/YAGNI: copy centralized; ensure reuses `create_job`; no DB rename.

---

## Eng review appendix (2026-08-15) — CLEAR

### NOT in scope (deferred with rationale)
- Industry-neutral rename Support → Work arrangement / Placement — product stick with Support for now
- Reopen closed standing on ensure — D11 chooses new open row
- Multi open standing per client — DB constraint stays
- Relocate form-template URLs off `/staff/jobs/…` — deep links OK
- Soft-null or invent Primary site on ensure — D10 forbids

### What already exists (reuse)
- `create_job`, `JobOut`, `POST /v1/jobs/ongoing-support`, `job_copy.dart` Ongoing support strings, client detail support section, roster board create/book paths, `jobs_one_open_standing_per_client`

### Failure modes
| Path | Failure | Test | UX |
|------|---------|------|-----|
| ensure no site | 422 site_or_branch_required | Task 3 | Snackbar / form error on book-one |
| ensure other tenant | 404 | Task 3 | No leak |
| ensure jobs.read only | 403 | Task 3 | Permission message |
| concurrent double ensure | unique open standing | reuse create_job conflict / second ensure same id | Idempotent |
| GET missing | 404 ongoing_support_not_found | Task 3 | Client detail Start CTA |

### Parallelization
Sequential preferred: Task 1–2 (FE copy/nav) can run parallel to Task 3 (BE) in worktrees; Task 4–5 wait on Task 3; Task 6 anytime; Task 7 last. Lanes FE+BE both touch product language only via contracts — low merge conflict if API paths locked (`/clients/{id}/ongoing-support`).

### Data flow (book-one)

```text
Staff picks Client
  → POST …/clients/{id}/ongoing-support/ensure
       → open standing? return it
       → else site? create_job standing : 422
  → create shift with job_id
```

