# Flutter Migration — Implementation Checklist

**Purpose:** Turn the migration plan phases into a day-to-day implementation checklist.  
**Sources:**
- [flutter-migration-impact-study.md](./flutter-migration-impact-study.md) §9
- [clarification-questions.md](./clarification-questions.md) (answers as of 2026-07-23)
- [development-backlog.md](./development-backlog.md)
- [frontend-api-wiring-guide.md](./frontend-api-wiring-guide.md) *(API shapes — use throughout Phase 2+)*
- [phase1/phase2-readiness.md](./phase1/phase2-readiness.md) *(go/no-go before Phase 2)*

**How to use:** Check items as you complete them. Do not start Phase 2 until [phase2-readiness.md](./phase1/phase2-readiness.md) is green. Do not start Phase 3 feature UI until Phase 1 exit items are checked and Phase 2 skeleton compiles.

---

## Decisions locked (from clarification answers)

Use these as implementation constraints — do not re-debate mid-sprint without product/backend change.

| Topic | Decision |
|-------|----------|
| App packaging | **One Flutter app, dual shells** (`tenant_member` admin + `contractor`) |
| JWT claims | Always: `sub`, `tenant_id`, `permissions[]`, `actor_type`, `iat`, `exp`, `typ=access`. + `contractor_id` or `tenant_member_id`. Optional `mcp=true` |
| Permissions source | **JWT only** (`/auth/me/context` has actor + engagements, not permissions) |
| Login body | Contractors get `engagements: [{id, tenant_id, tenant_name, status}]` on login/refresh/switch-tenant |
| First login | Keep `must_change_password` / `POST /v1/auth/complete_first_login` for both actors |
| Contractor register | **In Flutter scope** — `POST /v1/contractors/register` (required before invite) |
| Company / public register | **Out of Flutter** — `POST /v1/public/register` is **landing page only** (creates tenant + owner) |
| Subscriptions / billing | **Out of Flutter** — `/v1/subscription*` checkout/cancel/plans UI is **landing page only**; Flutter may still see lightweight `subscription` on login and handle `subscription_expired` defensively |
| Invite rule | Invite requires **existing contractor**; 404 `contractor_not_found` otherwise |
| Engagement accept | Authenticated in-app `POST /v1/engagements/{id}/accept` (no magic-link API) |
| `pending_docs` UX | Docs upload + visits read only (`auth.session`, `visits.read`, `documents.upload`) |
| Clients | Admin CRM only (no client login shell). Public invite acknowledge = **separate web** (out of mobile V1) |
| Job location | Always `branch_id XOR client_site_id` |
| GPS body | `{ lat, lng, accuracy_m? }` — no client timestamp |
| Documents | `upload-url` → PUT signed URL → `finalize` |
| Obsolete APIs | Employee / PIN / clock-in-out / scheduling / payroll periods → **404** |
| Weekly report | **Removed** — delete Flutter weekly report UI |
| Adjustments | Keep/rebuild against `POST /v1/attendance/adjustments` (visit-linked actions) |
| Rates | `GET/POST /v1/payroll/engagement-rates/{engagement_id}`, `PATCH .../{rate_id}` |
| Payments | Batches mix contractors OK; void posted allowed; no CSV export V1; contractor “own payments” via `GET /v1/visits?payment_status=` |
| Employee balance / periods | **Retired** — remove UI |
| Check-in | Online only; Idempotency-Key supported |
| Cutover | Fresh DB; wipe tokens; force re-login. No backend force-update API yet |
| platform.admin | Out of Flutter app |

### Known backend gaps (implement defensively)

| Gap | Implication for Flutter |
|-----|-------------------------|
| Suspended JWT strips `visits.complete` while service may allow checkout | Show suspended state; if complete returns 403, show clear copy (“Session limited — refresh or contact admin”). Track backend fix. |
| No dedicated contractor payment-batches list | Use contractor-scoped visits filtered by `payment_status` |
| No visit `status` / client / branch query filters yet | Client-side filter or request API later; list with `from`/`to`/`job_id`/`payment_status`/`limit` |
| No recurrence regenerate endpoint | Only expose **generate**, not regenerate |
| Staging seed = roles/perms only | Team must create staging fixtures manually |

### Product still open (pick defaults for V1 mobile)

Check when product confirms; until then use recommended defaults:

- [x] Form template **builder** in mobile? → **Default: consume + submit only** (CRUD templates later / web)
- [x] Client CRM fully in mobile V1? → **Default: Yes** (needed for standing jobs)
- [x] Map/pin picker for sites/jobs? → **Default: Yes for sites** (lat/lng required)
- [x] Deep link for engagement invite? → **Default: in-app notification → accept screen** (no magic link)
- [x] Store force-update / min version? → **Default: store messaging + coordinated cutover**
- [x] Company public register in Flutter? → **No — landing page only**
- [x] Subscription / billing UI in Flutter? → **No — landing page only** (defensive `subscription_expired` handling OK)

---

## Phase 1 — Discovery and confirmation

**Goal:** Freeze contracts before mass Flutter coding.  
**Status:** Complete (2026-07-23) — see [phase1/](./phase1/).

### 1.1 Contract freeze

- [x] Walk clarification questions with backend/product *(answered 2026-07-23)*
- [x] Open live OpenAPI at staging `/docs` / `/openapi.json` and bookmark for team *(local `http://localhost:8000` — [openapi-review.md](./phase1/openapi-review.md))*
- [x] Spot-check critical paths in Swagger: login, switch-tenant, engagements, visits check-in/complete, documents, payment-batches, engagement-rates
- [x] Confirm error catalog strings used in UI mapper (`wrong_actor_type`, `engagement_not_active`, `geofence_rejected`, `forms_incomplete`, `scan_blocked`, `visit_overlap`, `standing_job_exists`, `contractor_not_found`, `hard_split_violation`, `invalid_visit_status`, …) — [error-catalog.md](./phase1/error-catalog.md)
- [x] Record final V1 mobile scope matrix (In / Out / Later) using defaults above — [v1-scope-matrix.md](./phase1/v1-scope-matrix.md)
- [x] Agree cutover window with backend (no dual-running; coordinated release) — [cutover-agreement.md](./phase1/cutover-agreement.md)

### 1.2 Spikes (must pass before Phase 3)

- [x] Spike: login as tenant_member → parse JWT claims → land admin shell stub
- [x] Spike: login as contractor → use `engagements` from login body → `switch-tenant` → new tokens persisted
- [x] Spike: `GET /v1/auth/me/context` vs login body parity
- [x] Spike: document `upload-url` → PUT → `finalize` on at least one mobile target
- [x] Spike: visit check-in with `{lat,lng,accuracy_m}` against a staging visit

> Contract spikes signed off via OpenAPI + unit/mock tests + `tool/phase1_spikes.dart`. Live authenticated runs need **manual/backend fixtures** (public company register is landing-page only, not Flutter) — [spike-signoff.md](./phase1/spike-signoff.md).

### Phase 1 exit criteria

- [x] OpenAPI reviewed by Flutter lead
- [x] V1 scope matrix written (In/Out/Later)
- [x] All five spikes above signed off
- [x] Cutover approach agreed (wipe storage + re-login)

---

## Phase 2 — Architecture preparation

**Goal:** Compiling skeleton + session layer; no production domain UI yet.  
**Prereq:** [phase1/phase2-readiness.md](./phase1/phase2-readiness.md) ✅ · keep [frontend-api-wiring-guide.md](./frontend-api-wiring-guide.md) open while coding.

### 2.1 Folder / module scaffolding

- [ ] Create model folders: `tenant_member/`, `contractor/`, `engagement/`, `client/`, `job/`, `form/`, `document/`, `payment/` (batches), retarget `scheduling/`
- [ ] Add empty remote datasources: `TenantMember`, `Contractor`, `Engagement`, `Client`, `Job`, `Visit`, `Form`, `Document`, `PaymentBatch`
- [ ] Add matching repositories
- [ ] Add module bindings stubs (`*ModuleBinding.ensureDependencies`)
- [ ] Add `DOMAIN_V2` (or equivalent) `dart-define` / feature flag wiring

### 2.2 Session and storage

- [ ] Extend JWT parse in `TokenStorage` (or new `JwtClaims`) for `actor_type`, `contractor_id`, `tenant_member_id`, `permissions`, `mcp`
- [ ] Add `SessionController` (permanent): actor, engagements list, selected engagement/tenant
- [ ] Replace portal `user_role` (`GatewayController` attendance/admin) with actor-based routing
- [ ] Persist last selected `tenant_id` / engagement id for contractors
- [ ] Implement cutover wipe: clear tokens, `user_role`, `payroll_settings` on version bump / first DOMAIN_V2 launch
- [ ] Keep access/refresh persist + refresh rotation on switch-tenant

### 2.3 Permissions and errors

- [ ] Add `AppPermissions` constants from seed catalog (owner/admin/supervisor/contractor keys)
- [ ] Replace `SchedulingPermissions`-only checks with shared `hasPermission` helpers
- [ ] Add `ActorGuard` / permission-aware empty states
- [ ] Map Dio failures → typed failures for known `detail` codes (toast vs dedicated screen: `wrong_actor_type` → screen; `missing_permission` → toast)

### 2.4 Navigation skeleton

- [ ] Draft dual route graphs: `AdminRoutes` + `ContractorRoutes` in `AppRoutes` / `app_pages.dart`
- [ ] Stub admin shell destinations: Hub, Team (members), Contractors/Engagements, Clients, Jobs/Visits, Payments, Forms (if In), Branches/Settings
- [ ] Stub contractor shell: Visits, Visit detail, Timetable, Documents, Payments (via visits), Switch tenant / Profile
- [ ] Update `AuthGuard` post-login redirect matrix (member vs contractor; `mcp` → first-login; `pending_docs` gate)

### 2.5 Shared infrastructure

- [ ] Add file/image picker dependency(ies) for documents + form file fields
- [ ] Implement shared `DocumentService` (upload-url / PUT / finalize / download-url)
- [ ] Centralize API path constants in `AppConstants` (new paths; mark old PIN/employee/period paths deprecated)
- [ ] Ban new controller-level raw Dio calls (repository-only rule)

### Phase 2 exit criteria

- [ ] App compiles with skeleton modules + dual shells stubs
- [ ] Session spike merged (login + switch-tenant + claim parse)
- [ ] DocumentService spike merged
- [ ] Feature flag / dart-define documented for team

---

## Phase 3 — Core implementation

**Goal:** Build domain features in dependency order. Check each subsection before moving on.

### 3.1 Auth / session / actor routing (P0)

- [ ] Update `AuthRemoteDataSource` + models: login/refresh/switch-tenant engagement payloads
- [ ] Implement `POST /v1/auth/switch-tenant` UI + repository
- [ ] Implement `GET /v1/auth/me/context` (and/or `GET /v1/me`) for session restore
- [ ] Keep first-login flow for both actors when `mcp` / `must_change_password`
- [ ] Remove gateway “Attendance vs Admin” portal role as primary auth split
- [ ] Post-login routing:
  - [ ] `tenant_member` → admin shell
  - [ ] `contractor` multi-engagement → tenant/engagement picker
  - [ ] `contractor` single engagement → contractor shell
  - [ ] `pending_docs` / `invited` → onboarding (docs / accept) before visit ops
- [ ] Handle refresh when suspended (limited perms) and ended (refresh fails → clear session)
- [ ] Unit tests: JWT claim parse, switch-tenant token persist

### 3.2 Tenant members (P0) — replace staff employees

- [ ] Models + datasource + repository for `/tenant-members` CRUD
- [ ] Admin Team list / detail / create / edit / deactivate screens
- [ ] Role assignment UI aligned with owner/admin/supervisor (no platform.admin)
- [ ] Remove staff usage of `EmployeeModel` for admin team
- [ ] Wire admin shell “Team” destination

### 3.3 Contractors + engagements + profile docs (P0)

- [ ] Contractor register screen (`POST /v1/contractors/register`)
- [ ] Contractor profile (`GET/PATCH /v1/contractor-me`)
- [ ] Admin: invite engagement (`POST /v1/tenants/current/engagements`) with required doc categories; handle `contractor_not_found`
- [ ] Admin: engagements list/detail (`GET /v1/tenants/current/engagements`)
- [ ] Contractor: engagements list (`GET /v1/contractor-me/engagements`)
- [ ] Lifecycle actions UI: accept, approve, activate, approve-and-activate, suspend, resume, end
- [ ] Status machine UX + disabled actions by status
- [ ] Required docs upload via `DocumentService` (owner contractor profile)
- [ ] Consent display; hide profile docs from tenant when ended/revoked
- [ ] `pending_docs` limited navigation (docs + visits read only)
- [ ] Engagement invite notification → accept screen (in-app)
- [ ] Tests: status action availability matrix

### 3.4 Clients + sites + contacts + invites (P1 — default In)

- [ ] Clients CRUD
- [ ] Sites CRUD with lat/lng (+ map/pin if product Yes)
- [ ] Contacts CRUD (email or phone required)
- [ ] Client documents upload (tenant member)
- [ ] Create client invite; show raw token / invite URL once
- [ ] Do **not** build public acknowledge inside contractor mobile (separate web)
- [ ] Wire admin shell Clients destination

### 3.5 Forms — consume + submit (P1)

- [ ] List/get form templates API models
- [ ] Job form catalog attach UI (tenant templates / client-scoped rules)
- [ ] Dynamic form renderer: `text`, `textarea`, `boolean`, `number`, `date`, `file`
- [ ] Visit form submission upsert + required-field validation
- [ ] File fields → document_id; handle `scan_blocked` / retry re-upload
- [ ] (Later / Out) Form template builder UI — skip unless product marks In

### 3.6 Jobs + visits + tasks + recurrence (P0)

- [ ] Jobs create/list/detail: `standing` | `ad_hoc`, status open/closed/cancelled
- [ ] Enforce location XOR (`branch_id` vs `client_site_id`) in form validation
- [ ] Standing job uniqueness UX (`standing_job_exists` 409)
- [ ] Manual visit create (`POST /jobs/{id}/visits`)
- [ ] Visits list (`GET /visits` with `from`/`to`/`job_id`/`payment_status`/`limit`) + client-side filters as needed
- [ ] Visit detail: status, assignee, window, location, payment_status
- [ ] Tasks list + toggle (`PATCH .../tasks/{tid}`) for assignee / `visits.manage`
- [ ] Recurrence rules create on standing jobs
- [ ] Generate visits UI (`partial=false` default; optional `partial=true` with skipped list)
- [ ] Visit cancel (tenant `visits.manage` only) — contractors cannot cancel
- [ ] Do **not** build regenerate UI (endpoint missing)
- [ ] Wire admin Jobs/Visits destinations

### 3.7 Visit check-in / complete — retire kiosk (P0)

- [ ] Contractor visit check-in: GPS → `POST /visits/{id}/check-in` with Idempotency-Key
- [ ] Geofence UX: `geofence_rejected` (enforce) vs informational outside allowed
- [ ] Complete flow: required forms gate → GPS → `POST /visits/{id}/complete`
- [ ] Handle `forms_incomplete`, `scan_blocked`, `engagement_not_active`, `invalid_visit_status`
- [ ] Concurrent check-in race → “Already checked in” / refresh
- [ ] Suspended: block check-in; handle complete 403 gap gracefully
- [ ] Remove PIN kiosk `/home`, PIN dialogs, `verify_pin` / `set_pin` / reset-pin
- [ ] Remove free-floating clock-in/out datasource methods
- [ ] Stop using `GET /employees/clocked-in-status` everywhere

### 3.8 Contractor timetable / availability / leave (P1)

- [ ] `GET /v1/contractor-me/timetable`
- [ ] Availability get/put
- [ ] Leave CRUD
- [ ] Optional UI warn for cross-tenant overlapping visits (backend allows)
- [ ] Admin busy/leave signals on visits board (read leave)

### 3.9 Engagement rates + payment batches (P1)

- [ ] Engagement rates list/create/edit (`/v1/payroll/engagement-rates/...`)
- [ ] Unpaid completed visits picker → create batch `{visit_ids, period_label?, currency_code}`
- [ ] Batch detail with lines (hours, rate, amount, contractor_id)
- [ ] Post batch / void batch (including void after post)
- [ ] Admin payments hub replaces payroll periods hub
- [ ] Contractor “my payments”: filter own visits by `payment_status`
- [ ] Remove employee balance, payroll periods, settings, results, summary report UIs
- [ ] Remove period-linked create payment flow

### 3.10 Admin schedule / visits board redesign (P1)

- [ ] Replace employee shift assignment board with visits-centric board
- [ ] Remove employee-schedules / assignment / copy-week client usage (404)
- [ ] Show contractor leave as busy where applicable
- [ ] Permission gates: `jobs.*` / `visits.*` / supervisor limits (no payments.manage, no contractors.docs.read)

### 3.11 Corrections (P1) — reports out

- [ ] Rebuild corrections against `POST /v1/attendance/adjustments` + history GET
- [ ] Support actions: `admin_add_clock_out`, `admin_close_clock_out`, `admin_create_manual_entry`, `admin_edit_entry` (visit-linked)
- [ ] Gate with `attendance.adjust` (owner/admin — not supervisor)
- [ ] **Delete** weekly attendance report feature (API removed)
- [ ] Remove `AttendanceReportController` direct Dio weekly call

### 3.12 Remove obsolete code (P0 cleanup)

- [ ] Delete/disable routes: kiosk home, employee CRUD as workforce, payroll period tree, PIN flows
- [ ] Delete obsolete models/controllers/bindings/tests for PIN, periods, employee clock
- [ ] Clean `AdminShellRoutes` labels (no “Employees” / old Payroll period IA)
- [ ] Remove dead path constants from `AppConstants`

### 3.13 Notifications polish (P2)

- [ ] Keep `POST /v1/notifications/devices` (+ DELETE)
- [ ] Handle FCM / inbox payloads: `engagement.*`, `visit.assigned|checked_in|completed`
- [ ] Ignore unknown event types safely
- [ ] Optional inbox screen via `GET /v1/notifications/events`
- [ ] Do **not** build stub email/sms delivery log UI

### Phase 3 exit criteria

- [ ] Tenant member can manage team, clients, jobs, visits, batches
- [ ] Contractor can register, accept engagement, upload docs, check in/complete visits
- [ ] PIN kiosk and payroll periods gone from navigation
- [ ] Dual shells usable on staging

---

## Phase 4 — Data and cache migration

- [ ] Implement one-shot migration on upgrade: wipe secure storage tokens + branch + old `user_role`
- [ ] Delete `payroll_settings` from GetStorage
- [ ] Show blocking “App updated — please sign in again” when wipe runs
- [ ] Verify no offline SQLite/workforce cache needs migration (none today)
- [ ] Document: store rollback only works if backend still serves old API (it will not) → coordinated cutover only
- [ ] (Product) Decide store min-version / force-update messaging (backend has none)

### Phase 4 exit criteria

- [ ] Fresh install and upgrade-from-old-binary both force clean login against new API

---

## Phase 5 — Testing and QA

### 5.1 Automated tests

- [ ] Unit: JWT/session parsing, permission helpers, engagement status guards
- [ ] Unit: repositories for visits check-in/complete error mapping
- [ ] Unit: payment batch selection rules (completed + unpaid)
- [ ] Widget: login gates, engagement actions, visit detail, dynamic form, batch create
- [ ] Remove obsolete PIN / period / employee-payment tests
- [ ] Update auth datasource tests (no PIN; add switch-tenant)

### 5.2 Manual QA — Auth / session

- [ ] Tenant member login → admin shell + correct permission-gated destinations
- [ ] Contractor one engagement → auto tenant context
- [ ] Contractor multi engagement → switch-tenant; old refresh unusable
- [ ] `mcp` / first-login works for both actors
- [ ] Suspended engagement refresh → limited UI
- [ ] Ended engagement → cannot refresh that tenant; pick another or re-login
- [ ] Upgrade wipe forces re-login

### 5.3 Manual QA — Engagements

- [ ] Register contractor → admin invite → accept → upload docs → approve → activate
- [ ] Invite unknown email → `contractor_not_found`
- [ ] Approve blocked when required docs missing/blocked
- [ ] Suspend blocks check-in
- [ ] End: tenant loses profile doc access; assignee keeps historical visit docs

### 5.4 Manual QA — Visits / attendance

- [ ] Check-in inside radius OK
- [ ] Enforce outside → `geofence_rejected`
- [ ] Informational outside allowed
- [ ] Complete blocked without required forms
- [ ] Blocked scan file → retry upload → complete
- [ ] Task toggle by assignee and by `visits.manage` member
- [ ] Cancel by tenant only
- [ ] Double check-in race message

### 5.5 Manual QA — Payments

- [ ] Multi-contractor unpaid visits in one batch
- [ ] Post → visits `paid`
- [ ] Void posted → visits `unpaid`
- [ ] Contractor sees own paid visits via visits filter
- [ ] No balance / period UI reachable

### 5.6 Manual QA — Regression

- [ ] Token proactive refresh still works
- [ ] Push device registration works
- [ ] Responsive admin shell wide/narrow
- [ ] Hard-split / wrong_actor_type dedicated handling
- [ ] Online-only check-in fails clearly offline

### Phase 5 exit criteria

- [ ] P0 automated tests green
- [ ] Manual QA checklist completed on staging with ad-hoc fixtures
- [ ] Known gaps (suspended complete, missing visit filters) documented for release notes

---

## Phase 6 — Rollout

- [ ] Create staging fixtures manually (tenant, member, contractor, engagement active, client, standing job, visits, rates)
- [ ] Dogfood: one admin device + one contractor device for ≥1 full visit lifecycle + one payment batch
- [ ] Confirm monitoring signals: auth failure rate, check-in errors, batch post failures
- [ ] Coordinated production cutover with backend (old app will break — communicate update)
- [ ] Store release (iOS/Android/Web as applicable)
- [ ] Post-release watch window + hotfix plan
- [ ] Rollback plan = previous binary **only if** backend can temporarily re-enable old API (assume **no**) → prefer forward fix

### Phase 6 exit criteria

- [ ] Production users on new binary
- [ ] No critical auth/check-in/payment regressions in watch window

---

## Progress tracker

| Phase | Name | Exit criteria met? |
|-------|------|--------------------|
| 1 | Discovery and confirmation | [x] |
| 2 | Architecture preparation | [ ] |
| 3 | Core implementation | [ ] |
| 4 | Data and cache migration | [ ] |
| 5 | Testing and QA | [ ] |
| 6 | Rollout | [ ] |

---

## Suggested start-this-week order

1. [x] Finish Phase 1 OpenAPI spot-check + scope matrix  
2. [x] Run auth + documents + check-in spikes  
3. [ ] Phase 2 session/`TokenStorage`/`SessionController` + dual shell stubs  
4. [ ] Phase 2 `DocumentService` + `AppPermissions` + error mapper  
5. [ ] Begin Phase 3.1 auth routing, then 3.2 members, then 3.3 engagements  

---

*Update this file as tasks complete. When product resolves the open defaults (form builder, map picker, deep links, force-update), tick those items under “Product still open” and adjust Phase 3 scope.*
