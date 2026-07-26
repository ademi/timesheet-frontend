# Frontend Contractor-Domain Restructure — Design Spec

**Date:** 2026-07-23  
**Status:** Draft for review  
**Audience:** Implementing LLM / engineer with little prior context  
**App:** Flutter package `rostiq` at `/home/ademi/projects/timesheet/frontend`  
**Backend:** FastAPI modular monolith at `/home/ademi/projects/timesheet/backend/timesheet-backend` (APIs under `/v1`)

---

## 0. How to use this document

1. Implement **skeleton-first**, then **one vertical domain slice at a time** (see §9 delivery order).
2. Do **not** invent endpoints. Use only paths and permissions listed here or live backend routers under `backend/timesheet-backend/app/modules/*/router.py`.
3. Treat `backend/docs/RBAC_PERMISSIONS_AND_ROUTES.md` as a **partial** reference: it still contains **legacy employee** routes that no longer exist. Prefer live routers + §6–§7 of this doc.
4. Authoritative product designs (backend):
   - `backend/docs/superpowers/specs/2026-07-22-contractor-client-job-design.md`
   - `backend/docs/superpowers/specs/2026-07-23-ndis-contractor-privacy-security-legal-design.md`
   - `backend/docs/superpowers/specs/2026-07-23-engagement-rate-bands-design.md`
5. **Out of scope for this Flutter V1:** records-engine / NDIS **client** onboarding packs (`/v1/records/*` — not implemented), company registration UI, GoCardless checkout UI, retention/legal-hold admin UI, visual rebrand.

---

## 1. Decisions locked (do not reopen without human approval)

| # | Decision | Choice |
|---|----------|--------|
| D1 | Product model | **Contractor-only greenfield shell.** Do not preserve employee clock / employee CRUD / old shift board / employee payroll-period UX. |
| D2 | V1 product scope | **Full parity with shipped backend APIs** (identity, compliance onboarding, workforce, clients, jobs/visits, schedule, rates/payments, privacy ops). Defer records-engine only. |
| D3 | State / routing | **Keep GetX** (`GetMaterialApp`, `GetPage`, Bindings, `GetxController`). |
| D4 | Actors | **One app, two shells:** `StaffShell` vs `ContractorShell` after login from `actor_type`. |
| D5 | Platforms | **Web + mobile together** for every V1 screen. GPS check-in: real on mobile; degraded/unsupported messaging on web. |
| D6 | Landing vs Flutter | Flutter: contractor register + all authenticated product UI. Landing site: company register + GoCardless checkout. Flutter deep-links to billing on subscription gate. |
| D7 | Legacy code | **Delete** employee/attendance/old payroll/old scheduling as each replacement slice lands. No `lib/legacy/` quarantine. |
| D8 | Delivery strategy | **Skeleton-first**, then vertical domain slices. |

---

## 2. Current frontend vs target (gap summary)

### 2.1 What exists today (`frontend/lib`)

- Architecture: flat GetX under `lib/app/` (views / controllers / data), shared `lib/core/`.
- Domains: gateway (admin vs attendance), login, first-login, branches, **employees**, GPS **employee clock**, attendance reports/corrections, **shift scheduling board**, **employee payroll periods**, payments tied to payroll periods.
- Stack: Dio (`ApiClient` + `AttendanceApiClient`), GetX, `flutter_secure_storage`, Firebase messaging, ScreenUtil.
- ~211 Dart files; no contractors, clients, jobs, credentials, compliance, NDIS.

### 2.2 What backend already ships (must be covered by Flutter V1)

- Auth with `actor_type` (`tenant_member` | `contractor`), `switch-tenant`, `me/context`.
- Contractor register (Terms/Privacy versions), engagements lifecycle, sharing grants.
- Compliance legal docs, collection notices, legal events, rights, privacy export, access history, incidents.
- Credentials vault + reviews + eligibility gate on approve.
- Documents upload / finalize / scan / download-url vs **content proxy** for restricted evidence.
- Clients, sites, contacts, invites.
- Jobs, recurrence, visit generate, visit check-in/complete, tasks, form submissions.
- Contractor timetable / availability / leave.
- Engagement rate bands + payment batches.
- Subscription status APIs (checkout stays on landing).
- Notifications devices/events.

### 2.3 Explicitly removed from product (do not rebuild)

- Employee CRUD, PIN verify/set, employee clock-in/out portal.
- `/v1/scheduling/*` employee board/templates (gone from backend direction).
- Employee payroll periods / employee rates / payroll balance screens.
- Gateway choice `UserRole.admin` vs `UserRole.attendance`.

---

## 3. Architecture

### 3.1 Target folder layout

```
lib/
  main.dart
  core/
    constants/
      app_constants.dart          # baseUrl, apiV1, dart-defines
      api_paths.dart              # all /v1 path builders (no legacy paths)
      storage_keys.dart
    network/
      api_client.dart             # SINGLE Dio client (retire AttendanceApiClient)
      auth_interceptor.dart
      error_mapper.dart           # DioException → AppFailure
    services/
      token_storage.dart          # keep; extend JWT claim parsing for actor_type if not already stored
      session_service.dart        # me/context, actor, permissions, tenant switch
    responsive/
    validation/
    errors/
      app_failure.dart            # typed failures: unauthorized, forbidden, billingGate, eligibilityIncomplete, …
  features/
    auth/
    gateway/
    shell/                        # StaffShell, ContractorShell, nav models
    contractor_register/          # public register
    contractor_onboarding/        # legal → notices → consents → engagement accept
    credentials/
    documents/                    # shared upload/download helpers used by credentials + visits
    engagements/                  # staff invite/approve + contractor accept
    clients/
    jobs/
    visits/
    contractor_schedule/
    payroll/                      # engagement rate bands + payment batches (NOT employee payroll)
    compliance_ops/               # rights, export, access history, incidents
    subscription/                 # status + billing deep-link only
    notifications/
  shared/
    widgets/                      # PermissionGate, AppErrorBanner, EmptyState, MarkdownViewer, …
    utils/
```

**Rule:** Each feature owns:

```
features/<name>/
  data/
    models/
    datasources/<name>_remote_datasource.dart
    repositories/<name>_repository.dart
  controllers/
  bindings/
  views/
  <name>_routes.dart              # GetPage list + path constants
```

No new screens under the old flat `lib/app/views/` for contractor-domain work. During migration, old `lib/app/**` files are deleted when replaced (§9).

### 3.2 Shared infra rules

1. **One Dio client.** Delete `AttendanceApiClient` when attendance domain is deleted. All datasources take `ApiClient` / `dio`.
2. **Bindings:** register `ApiClient`, `TokenStorage`, `SessionService` once in `InitialBinding` (permanent). Feature bindings only register that feature’s datasource/repo/controller. Do not re-`Get.put(ApiClient)` in every module binding.
3. **SessionService** (new):
   - After login, refresh, switch-tenant, and app resume (if tokens valid): call `GET /v1/auth/me/context`.
   - Store: `actorType`, `tenantId`, `contractorId`, `tenantMemberId`, `engagements[]`, and permissions from JWT (via `TokenStorage`).
   - Expose: `bool get isStaff`, `bool get isContractor`, `bool hasPermission(String)`, `bool hasAny(List<String>)`.
   - Superuser: treat `platform.admin` or `*` as allowing any permission check in UI gates (mirror backend).
4. **Error mapper:**
   - `401` → refresh path (existing interceptor) or logout.
   - `403` with `detail` string → show mapped message (`missing_permission`, `wrong_actor_type`, `proxy_required`, `scan_blocked`, MFA failures, etc.).
   - `402` / subscription inactive / `require_active_subscription` failures → `AppFailure.billingGate` → show CTA to open `BILLING_URL`.
   - `409` with eligibility payload → parse `eligibility_incomplete` reasons and show itemised list (§5.4).
   - `429` → rate-limit snackbar.
5. **Compile-time defines:**
   - `API_BASE_URL` (existing; default `https://api.rostiq.co`)
   - `BILLING_URL` (new; landing billing page; required for subscription CTA)
   - Optional `LANDING_URL` for “create company account” link on gateway.
6. **Theming:** keep existing `AppColors` / themes. No rebrand in this project.
7. **Markdown:** legal docs and notices return `content_md`. Add `flutter_markdown` and render read-only. Do not claim documents are counsel-approved if `counsel_pending == true` — show blocking error from API and a clear “unavailable” state.

### 3.3 GetX conventions (mandatory)

| Layer | Responsibility |
|-------|----------------|
| View | Layout, bind to controller observables, no Dio calls |
| Controller | UI state, call repository, map failures to snackbars/dialogs |
| Repository | Model mapping, orchestration across datasources if needed |
| RemoteDataSource | Raw Dio calls, path constants only |

- Controllers: prefer `<200–300` LOC; split if larger.
- Use `Obx` / `.obs` consistently; avoid mixing with other state libraries.
- Named routes only; no ad-hoc `Get.to(Widget)` for primary flows (dialogs OK).

---

## 4. Information architecture & navigation

### 4.1 Public routes

| Path | Screen | Notes |
|------|--------|-------|
| `/gateway` | Gateway | Links: Sign in, Register as contractor, optional “Provider signup” → external `LANDING_URL` |
| `/login` | Login | `POST /v1/auth/login` |
| `/first-login` | First login password | Keep existing flow if backend still requires `must_change_password` / complete-first-login |
| `/contractor/register` | Contractor register | Public; see §6.2 |
| `/invites/client/:token` | Client invite acknowledge | In V1; `GET/POST /v1/public/client-invites/{token}` |

**Delete:** admin-vs-attendance role picker behavior.

### 4.2 Post-login routing algorithm

```
persist tokens
GET /v1/auth/me/context
IF actor_type == tenant_member → /staff/home
ELSE IF actor_type == contractor:
  IF has pending engagement accept OR legal/consent incomplete OR required credentials incomplete
    → /contractor/onboarding (funnel)
  ELSE → /contractor/home
ELSE → error + logout
```

“Incomplete” for contractors is determined by:

1. Engagements in statuses that require accept (e.g. invited) from `GET /v1/contractor-me/engagements`.
2. Missing current Terms/Privacy acceptance when backend rejects subsequent actions (surface errors; funnel should present docs via compliance APIs first).
3. Required categories on accepted engagements without satisfying credentials (show checklist from engagement `required_doc_categories` + credential list statuses).

Do **not** invent a second actor. Backend forbids the same user being both `tenant_member` and `contractor`.

### 4.3 StaffShell (`/staff/...`)

Reuse responsive rail patterns from current `AdminShell`, renamed.

| Nav | Route | Show when user has |
|-----|-------|--------------------|
| Home | `/staff/home` | `auth.session` |
| Workforce | `/staff/workforce` | `contractors.read` |
| Clients | `/staff/clients` | `clients.read` |
| Jobs | `/staff/jobs` | `jobs.read` |
| Visits | `/staff/visits` | `visits.read` |
| Payments | `/staff/payments` | `payments.view` |
| Compliance | `/staff/compliance` | any of `credentials.review`, `compliance.rights.manage`, `compliance.incidents.manage`, `compliance.audit.view` |
| Settings | `/staff/settings` | `auth.session` |

**Staff home widgets:** pending approvals count, today’s visits, expiring credential reviews (from notifications/events if available), subscription status chip (`GET /v1/subscription` when `billing.view`).

### 4.4 ContractorShell (`/contractor/...`)

Mobile: bottom navigation. Wide web: rail.

| Nav | Route |
|-----|-------|
| Home | `/contractor/home` |
| Visits | `/contractor/visits` |
| Schedule | `/contractor/schedule` |
| Credentials | `/contractor/credentials` |
| Profile | `/contractor/profile` |

**Onboarding funnel** uses `/contractor/onboarding/*` **outside** tab chrome until the contractor can perform work (at least: legal accepted, engagement accepted if invited, required uploads started). Soft banners may remain on Home after partial completion.

### 4.5 Guards

Implement as GetX middlewares (extend current `AuthGuard`):

1. **AuthGuard** — no access token → `/gateway`.
2. **ActorGuard** — `/staff/*` requires `actor_type == tenant_member`; `/contractor/*` requires `contractor`.
3. **PermissionGuard** — route metadata lists required permissions (`anyOf` or `allOf`). On failure: redirect to shell home + snackbar. Never leave a blank screen.

Web refresh: keep `InitialBinding` + `PathUrlStrategy`; on cold start with tokens, load `me/context` before resolving deep link into the correct shell.

### 4.6 Tenant switch (contractor)

On Profile → Engagements:

1. List `GET /v1/contractor-me/engagements`.
2. User selects tenant → `POST /v1/auth/switch-tenant` `{ "tenant_id": "..." }`.
3. Persist new tokens; reload `me/context`; invalidate cached tenant-scoped lists; stay in ContractorShell.

Staff users typically have one tenant in JWT; no switch UI unless backend later exposes multi-tenant staff (not V1).

---

## 5. Compliance & copy rules (non-negotiable)

These come from the NDIS contractor privacy design. Violating them is a **spec bug**.

### 5.1 Separate legal actions

Never collapse into one “I agree to everything” checkbox.

| Step | API | Permission |
|------|-----|------------|
| Fetch Terms / Privacy | `GET /v1/compliance/legal-documents/current?doc_key=` | `compliance.legal.read` |
| Record presentation | `POST /v1/compliance/legal-events` `event_type=presented` | `compliance.legal.accept` |
| Record acceptance | `event_type=accepted` | `compliance.legal.accept` |
| Collection notices | `GET /v1/compliance/collection-notices` | `compliance.legal.read` |
| Notice ack | `event_type=acknowledged` (notice_key/version) | `compliance.legal.accept` |
| Sensitive consent | `event_type=consented` | `compliance.consent.manage` |
| Withdraw consent | `event_type=withdrawn` | `compliance.consent.manage` |

Legal event body fields (from backend schema): `event_type`, optional `doc_key`/`version`, `notice_key`/`notice_version`, `engagement_id`, `credential_type`, `data_class`, `presentation_source`, `correlation_id`, `idempotency_key`. Send `Idempotency-Key` header when retrying.

**UI sequence for a document:** show markdown → on first paint record `presented` → user taps Accept → record `accepted`. Same pattern for notices with `acknowledged`.

### 5.2 Counsel-pending

If API returns error because document/notice is `counsel_pending` (production fail-closed), show: “This legal document is not available yet.” Do not display stale draft content from cache. Do not allow register/accept to proceed without successful fetch + accept of required versions.

### 5.3 Metadata vs source evidence

- Default staff credential list: **metadata only** (`GET /v1/tenants/current/contractors/{id}/credentials`).
- Viewing/downloading source files requires grant + `credentials.source.read`.
- Restricted evidence categories (government ID / sensitive): if `GET /v1/documents/{id}/download-url` returns `403` with `detail=proxy_required`, the client **must** use `GET /v1/documents/{id}/content` (authenticated stream) instead of a signed URL. Never tell the user a signed URL “was viewed” when only issued.
- Scan states: show `pending` / `clean` / `blocked` / quarantine messaging. Do not treat unscanned files as ready for approval.

### 5.4 Eligibility language

When approve fails with `eligibility_incomplete`, show **itemised reasons** from the error payload (requirement + reason codes such as missing, expired, awaiting_scan, awaiting_review, rejected, consent_withdrawn, grant_revoked, etc.).

**Forbidden copy:**

- “Verified by Rostiq”
- “NDIS certified”
- “Compliant worker”
- Implying platform legal approval of the provider’s engagement decision

**Allowed copy:**

- “Eligible to approve based on current requirements”
- “Requirements incomplete”
- “Reviewer accepted / rejected this credential for this provider”

### 5.5 Sharing grant on engagement accept

`POST /v1/engagements/{id}/accept` body:

```json
{ "allow_source_evidence": false }
```

UI must:

1. Explain purpose: sharing credential metadata (and optionally source evidence) with **this named provider**.
2. Toggle for `allow_source_evidence` with plain-language warning.
3. Explain withdrawal / end-engagement effects before any withdraw action (blocks future platform-mediated access; provider may retain lawful copies).

### 5.6 MFA for credential review

`POST /v1/engagements/{id}/credential-reviews` may require MFA when backend `REQUIRE_MFA_FOR_CREDENTIAL_REVIEW=true`. If API returns MFA-required error, prompt re-auth / MFA step per backend contract; do not silently skip.

---

## 6. Domain modules (screens, APIs, permissions)

Each subsection is a vertical slice. Implement in §9 order.

### 6.0 Auth & session (`features/auth`)

**Screens:** Login, First-login (keep if still required), Logout action.

**APIs:**

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/auth/login` | public |
| POST | `/v1/auth/refresh` | public |
| POST | `/v1/auth/logout` | session |
| POST | `/v1/auth/switch-tenant` | `auth.session` |
| GET | `/v1/auth/me/context` | `auth.session` |
| GET | `/v1/me` | `auth.session` |

**Login response:** persist access + refresh tokens; parse JWT `permissions`, `actor_type`, `tenant_id`, `contractor_id`, `tenant_member_id`.

**Delete when done:** old gateway role enum usage; any employee PIN auth paths (`verify_pin`, `set_pin`) once attendance is removed.

---

### 6.1 Gateway (`features/gateway`)

**Screens:** Gateway with Sign in / Register as contractor / optional external provider signup link.

**Delete:** Admin vs Attendance cards.

---

### 6.2 Contractor register (`features/contractor_register`)

**Screen:** form `full_name`, `email`, `password`, optional `phone`, optional `dob`.

**Flow:**

1. Display Platform Terms and Privacy Policy content for the versions the user will accept.
   - **Exact `doc_key` values:** `platform_terms` and `privacy_policy` (not `terms` / `privacy`).
   - Authenticated fetch: `GET /v1/compliance/legal-documents/current?doc_key=platform_terms` (and `privacy_policy`) requires `compliance.legal.read`.
   - **Public register gap:** there is no public legal-document read today. Until backend adds one, V1 Flutter MUST use dart-defines `TERMS_VERSION` + `PRIVACY_VERSION` plus bundled markdown assets that match the DB current versions exactly, and send those version strings on register. After login, onboarding MUST re-fetch live docs via the authenticated compliance API and re-accept if versions differ.
2. User accepts Terms and Privacy separately (two steps or two explicit checkboxes tied to shown version).
3. `POST /v1/contractors/register` with `terms_version`, `privacy_version` (rate limit 5/min). Backend validates versions against `platform_terms` / `privacy_policy` current rows.
4. On success → navigate to **login** (response is `contractor_id`, `user_id`, `email` only — no tokens).

**Request body fields:** `full_name`, `email`, `password`, `phone?`, `dob?`, `terms_version`, `privacy_version`.

---

### 6.3 Contractor onboarding funnel (`features/contractor_onboarding`)

**Routes:** `/contractor/onboarding`, steps as sub-routes or a stepped controller.

**Steps (ordered):**

1. **Legal stack** — fetch + present + accept Terms/Privacy (and any other required `doc_key`s product requires).
2. **Collection notices** — list notices; present each; `acknowledged`.
3. **Sensitive consents** — for sensitive credential types before upload; `consented` with `credential_type` / `data_class` as required by backend.
4. **Engagement accept** — for each invited engagement: grant UI (§5.5) → `POST /v1/engagements/{id}/accept`.
5. **Required credentials** — checklist from `required_doc_categories` → deep-link into credentials create/upload (§6.4).

Keep progress indicator. Allow save-and-exit to Profile only after legal accept; otherwise block shell tabs.

---

### 6.4 Credentials & documents (`features/credentials`, `features/documents`)

#### Credential types (exact allowlist)

```
passport_id, drivers_licence, ndis_worker_screening, police_check, wwcc,
first_aid, cpr, infection_control, worker_orientation, abn, resume,
cert_iii, nursing_bachelor, nursing_diploma, other_health_qualification,
trade_certificate, insurance, other
```

Sensitive types (extra consent UX): `police_check`, `ndis_worker_screening`, `first_aid`, `cpr`, `infection_control`, `other_health_qualification`.  
Government ID (proxy download): `passport_id`, `drivers_licence`.

#### Contractor APIs

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/contractor-me/credentials` | `credentials.manage` |
| GET | `/v1/contractor-me/credentials` | `credentials.read` |
| PATCH | `/v1/contractor-me/credentials/{id}` | `credentials.manage` |
| POST | `/v1/contractor-me/credentials/{id}/supersede` | `credentials.manage` |

**Create body:** `credential_type`, `notice_event_id` (UUID of prior notice legal-event), optional `jurisdiction` (default AU), `issuer`, `identifier`, dates.

**Screens (contractor):** list, create form, detail (status, provenance, evidence_presence), supersede flow, attach evidence.

#### Evidence upload pipeline (exact)

1. Ensure notice acknowledged / consent recorded; keep `notice_event_id`.
2. Create credential (or choose existing).
3. `POST /v1/documents/upload-url` with `owner_type=contractor`, `owner_id=<contractor_id>`, `filename`, `content_type`, `size_bytes`, `category=<credential_type>`. Perm: `documents.upload`.
4. HTTP PUT bytes to returned `upload_url` (not via API Dio base necessarily — use plain Dio/http without Bearer if signed URL).
5. `POST /v1/documents/{document_id}/finalize` body `{ "credential_id": "..." }`.
6. Poll credential/document until `scan_status` is `clean` or `blocked`. Show quarantine/pending UI.

#### Download

| Method | Path | When |
|--------|------|------|
| GET | `/v1/documents/{id}/download-url` | Non-restricted; open URL |
| GET | `/v1/documents/{id}/content` | Restricted / `proxy_required`; stream with Bearer; optional `X-Delivery-Id` header for retries |

#### Staff credential review

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/tenants/current/contractors/{contractor_id}/credentials` | `credentials.read` |
| POST | `/v1/engagements/{engagement_id}/credential-reviews` | `credentials.review` |

Review body: `credential_id`, `decision` ∈ `accepted|rejected|re_review_required`, optional `reason_code`.

**Screens (staff):** from Workforce engagement detail → credentials tab → review actions. Default metadata; source view behind permission + grant.

---

### 6.5 Engagements / workforce (`features/engagements`)

#### Staff

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/tenants/current/engagements` | `contractors.read` |
| POST | `/v1/tenants/current/engagements` | `contractors.invite` |
| POST | `/v1/engagements/{id}/approve` | `contractors.approve` |
| POST | `/v1/engagements/{id}/activate` | `contractors.manage` |
| POST | `/v1/engagements/{id}/approve-and-activate` | `contractors.approve` |
| POST | `/v1/engagements/{id}/suspend` | `contractors.manage` |
| POST | `/v1/engagements/{id}/resume` | `contractors.manage` |
| POST | `/v1/engagements/{id}/end` | `contractors.manage` |

**Invite body:** `email?`, `phone?`, `required_categories: string[]` (must be from credential allowlist).

**Screens:**

- Workforce list (status chips: invited, accepted, approved, active, suspended, ended — use exact backend status strings from API).
- Invite form with multi-select required categories.
- Detail: lifecycle actions, eligibility errors on approve, credentials review entry, rate-card link.

#### Contractor

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/contractor-me` | `auth.session` |
| PATCH | `/v1/contractor-me` | `auth.session` |
| GET | `/v1/contractor-me/engagements` | `auth.session` |
| POST | `/v1/engagements/{id}/accept` | `auth.session` |

---

### 6.6 Clients CRM (`features/clients`)

Mount prefix: `/v1/clients` (`APIRouter(prefix="/clients")` under `/v1`).

| Method | Path | Perm |
|--------|------|------|
| GET/POST | `/v1/clients` | read / `clients.manage` |
| GET/PATCH/DELETE | `/v1/clients/{id}` | read / manage |
| GET/POST | `/v1/clients/{id}/sites` | … |
| PATCH/DELETE | `/v1/clients/{id}/sites/{site_id}` | … |
| GET/POST | `/v1/clients/{id}/contacts` | … |
| PATCH/DELETE | `/v1/clients/{id}/contacts/{contact_id}` | … |
| POST | `/v1/clients/{id}/invites` | `clients.manage` |

**Screens:** list, create/edit, detail with Sites / Contacts / Invites tabs.  
**Not in V1:** NDIS client pack readiness (records engine).

**Delete target:** none directly; new feature.

---

### 6.7 Jobs (`features/jobs`)

| Method | Path | Perm |
|--------|------|------|
| POST/GET | `/v1/jobs` | manage / read |
| PATCH | `/v1/jobs/{id}` | `jobs.manage` (status update) |
| POST | `/v1/jobs/{id}/form-catalog` | `jobs.manage` |
| POST/GET | `/v1/jobs/{id}/recurrence-rules` | manage / read |
| PATCH | `/v1/jobs/{id}/recurrence-rules/{rule_id}` | `jobs.manage` |
| POST | `/v1/jobs/{id}/recurrence-rules/{rule_id}/generate` | `jobs.manage` (+ Idempotency-Key) |
| POST | `/v1/jobs/{id}/visits` | `visits.manage` (manual visit) |

**Screens:** job list, job create/edit, recurrence editor, generate visits action, link to visits filtered by `job_id`.

**Form templates (staff, used by jobs/visits):**

| Method | Path | Perm |
|--------|------|------|
| GET/POST | `/v1/form-templates` | clients/forms manage per router deps |
| GET/PATCH/DELETE | `/v1/form-templates/{template_id}` | per router |

Implement under `features/jobs` or a thin `features/forms` module; wire into job form-catalog and visit form submissions.

**Deletes / replaces:** Shift schedule templates & employee board UI.

---

### 6.8 Visits (`features/visits`)

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/visits` | `visits.read` (contractor auto-scoped to self) |
| GET | `/v1/visits/{id}` | read |
| PATCH | `/v1/visits/{id}` | `visits.manage` reschedule |
| POST | `/v1/visits/{id}/cancel` | `visits.manage` |
| POST | `/v1/visits/{id}/check-in` | `visits.check_in` + GPS body + Idempotency-Key |
| POST | `/v1/visits/{id}/complete` | `visits.complete` + GPS body + Idempotency-Key |
| PATCH | `/v1/visits/{id}/tasks/{task_id}` | manage or check_in |
| POST | `/v1/visits/{id}/form-submissions` | check_in or manage |

**GPS body (exact):**

```json
{ "lat": -33.86, "lng": 151.21, "accuracy_m": 12.0 }
```

`accuracy_m` is optional. Field names are `lat` / `lng` (not `latitude` / `longitude`).

**Staff screens:** visit board (day/week filters via `from`/`to` query), detail, reschedule, cancel, assignment context.

**Contractor screens:** today’s list, visit detail, check-in / complete buttons, task checklist, required forms.

**Web GPS policy:** if `kIsWeb` or location permission denied, disable check-in/complete buttons with message “Check-in requires the mobile app with location enabled” (unless product later adds manual staff override — not V1 for contractors).

**Deletes / replaces:** `AttendanceView` employee clock portal; attendance report-as-clock product (visit history can show time entries if API returns them).

---

### 6.9 Contractor schedule (`features/contractor_schedule`)

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/contractor-me/timetable` | `auth.session` |
| GET/PUT | `/v1/contractor-me/availability` | read / `contractor.schedule.manage` |
| GET/POST | `/v1/contractor-me/leave` | read / manage |
| DELETE | `/v1/contractor-me/leave/{id}` | manage |

**Important:** availability/leave do **not** create visits. UI copy must say schedule preferences only.

**Screens:** timetable view, availability editor, leave list/create.

**Staff:** may show leave/availability context on visit board if scheduling permissions exist (`scheduling.read`) — only if backend exposes staff-side read; do not call contractor-me as staff.

---

### 6.10 Payroll & payments (`features/payroll`)

**Not** employee periods. New model:

#### Rate bands

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/payroll/engagement-rates/{engagement_id}` | `payments.view` |
| POST | `/v1/payroll/engagement-rates/{engagement_id}` | `payments.manage` |
| PATCH | `/v1/payroll/engagement-rates/{rate_id}` | `payments.manage` |

UI: editor for bands `base`, `evening`, `night`, `saturday`, `sunday`, `public_holiday` with evening/night windows; tenant timezone / `public_holiday_jurisdiction` in Settings when `tenants.manage` available.

#### Payment batches

| Method | Path | Perm |
|--------|------|------|
| GET/POST | `/v1/payment-batches` | view / manage |
| POST | `/v1/payment-batches/{id}/post` | manage |
| POST | `/v1/payment-batches/{id}/void` | manage |

Show `band_breakdown` on lines when present.

**Delete:** all `features` equivalent of old payroll periods, employee rates, payroll summary tied to employees, old `/payments` create-against-period flows.

---

### 6.11 Compliance ops (`features/compliance_ops`)

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/compliance/rights-requests` | `auth.session` or `compliance.rights.manage` |
| GET | `/v1/compliance/rights-requests/{id}` | `auth.session` |
| POST | `/v1/contractor-me/privacy-export` | `auth.session` (contractor) |
| GET | `/v1/compliance/access-history` | `compliance.audit.view` |
| POST/GET/PATCH | `/v1/compliance/incidents[/{id}]` | `compliance.incidents.manage` |

**Contractor Profile:** request access/correction/deletion/export; run privacy export; withdraw consents (with explanation dialog).

**Staff Compliance section:** rights queue (if manage), access history, incidents list/detail with NDB assessment clock messaging (30-day concept — display dates from API fields; do not invent legal advice).

**Not in V1 UI:** `compliance.retention.manage` (no dedicated HTTP routes).

---

### 6.12 Subscription (`features/subscription`)

| Method | Path | Notes |
|--------|------|-------|
| GET | `/v1/subscription` | Status/usage for staff with billing view |
| — | checkout/cancel | **Do not implement in Flutter** — open `BILLING_URL` |

On `AppFailure.billingGate`, show modal: “Subscription inactive” + button launching external billing URL (`url_launcher`).

---

### 6.13 Notifications (`features/notifications`)

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/notifications/devices` | receive |
| DELETE | `/v1/notifications/devices/{token}` | |
| GET | `/v1/notifications/events` | |
| GET | `/v1/notifications/settings` | |

Retarget existing `PushNotificationService` to register device after login for both actors. Surface compliance-related events (expiring credentials, review rejected, outstanding docs) on Home.

---

### 6.14 Settings (staff)

- Tenant profile fields available via tenants API (`timezone`, `public_holiday_jurisdiction` if exposed).
- Tenant members list if `tenant_members.read` / manage.
- Branches if still used for sites/geofence — keep branch APIs only where jobs/clients need them; remove “branch gateway as admin home” pattern in favor of StaffShell home.
- Billing status deep-link.

---

## 7. API path registry (Flutter `api_paths.dart`)

Implementers must centralize paths. Canonical list (all prefixed with `/v1` via `AppConstants.apiV1`):

```
auth/login, auth/refresh, auth/logout, auth/switch-tenant, auth/me/context
me
contractors/register
contractor-me, contractor-me/engagements, contractor-me/credentials,
  contractor-me/credentials/{id}, contractor-me/credentials/{id}/supersede,
  contractor-me/privacy-export, contractor-me/timetable,
  contractor-me/availability, contractor-me/leave, contractor-me/leave/{id}
tenants/current/engagements
tenants/current/contractors/{contractorId}/credentials
engagements/{id}/accept|approve|activate|approve-and-activate|suspend|resume|end
engagements/{id}/credential-reviews
compliance/legal-documents/current
compliance/collection-notices
compliance/legal-events
compliance/rights-requests, compliance/rights-requests/{id}
compliance/access-history
compliance/incidents, compliance/incidents/{id}
documents/upload-url, documents, documents/{id}/finalize,
  documents/{id}/download-url, documents/{id}/content
clients, clients/{id}, clients/{id}/sites, clients/{id}/sites/{siteId},
  clients/{id}/contacts, clients/{id}/contacts/{contactId}, clients/{id}/invites
form-templates, form-templates/{templateId}
jobs, jobs/{id}, jobs/{id}/form-catalog,
  jobs/{id}/recurrence-rules, jobs/{id}/recurrence-rules/{ruleId},
  jobs/{id}/recurrence-rules/{ruleId}/generate, jobs/{id}/visits
visits, visits/{id}, visits/{id}/cancel, visits/{id}/check-in, visits/{id}/complete,
  visits/{id}/tasks/{taskId}, visits/{id}/form-submissions
payroll/engagement-rates/{engagementId}, payroll/engagement-rates/{rateId}
payment-batches, payment-batches/{id}/post, payment-batches/{id}/void
subscription
notifications/devices, notifications/devices/{token}, notifications/events, notifications/settings
public/client-invites/{token}
```

**Do not add** to Flutter: `/employees`, `/scheduling/*`, `/attendance/clock-*`, employee `/payroll/periods`, old `/payments` employee report paths.

When unsure of request/response JSON, open the matching `schemas.py` beside the router and copy field names exactly.

---

## 8. Permission → UI matrix (quick reference)

| UI area | Permissions (any unless noted) |
|---------|--------------------------------|
| Staff shell | `actor_type=tenant_member` |
| Contractor shell | `actor_type=contractor` |
| Workforce list | `contractors.read` |
| Invite | `contractors.invite` |
| Approve | `contractors.approve` |
| Suspend/end/activate | `contractors.manage` |
| Credential review | `credentials.review` |
| Source evidence | `credentials.source.read` (+ grant) |
| Clients | `clients.read` / `clients.manage` |
| Jobs | `jobs.read` / `jobs.manage` |
| Visits board | `visits.read` / `visits.manage` |
| Check-in / complete | `visits.check_in` / `visits.complete` |
| Rate cards / batches | `payments.view` / `payments.manage` |
| Legal read/accept | `compliance.legal.read` / `compliance.legal.accept` |
| Consent | `compliance.consent.manage` |
| Incidents | `compliance.incidents.manage` |
| Access history | `compliance.audit.view` |
| Rights admin | `compliance.rights.manage` |

Hide nav items the user cannot access. Still harden every mutating button with a permission check before calling API.

---

## 9. Delivery order (skeleton-first slices)

Each slice must leave the app **runnable**. Delete listed legacy files at the end of the slice that replaces them.

| Slice | Deliverable | Delete when done |
|-------|-------------|------------------|
| **S0** | Folder layout; single `ApiClient`; `SessionService`; `api_paths.dart`; empty StaffShell + ContractorShell; Gateway + Login wired to `me/context` routing; guards | Gateway admin/attendance role model |
| **S1** | Contractor register + login path for contractors | — |
| **S2** | Compliance legal/notice/consent widgets + onboarding funnel shell | — |
| **S3** | Credentials vault + document upload/finalize/poll + proxy download helper | — |
| **S4** | Engagements staff invite/approve/activate + contractor accept + eligibility UI | Employee management screens/controllers/repos |
| **S5** | Clients CRM | — |
| **S6** | Jobs + recurrence + generate | Shift schedule feature |
| **S7** | Visits board + contractor check-in/complete/tasks/forms | Attendance clock + old attendance report/corrections **product** screens (keep only if still calling visit adjustment APIs — prefer new visit adjustment UI if `attendance.adjust` remains) |
| **S8** | Contractor schedule (timetable/availability/leave) | — |
| **S9** | Engagement rates + payment batches | Old payroll periods/rates/payments employee flows |
| **S10** | Compliance ops (rights, export, access history, incidents) + notifications retarget + subscription status/deep-link | Remaining dead `lib/app` employee leftovers; `AttendanceApiClient`; unused PIN APIs |

**S0 acceptance:** cold start, login as staff → StaffShell home; login as contractor → ContractorShell home; logout → gateway; web refresh keeps session.

**Final acceptance:** every §6 module has list+detail or funnel screens on web and mobile; no route remains to deleted employee features; `flutter analyze` clean; critical flows smoke-tested (§10).

---

## 10. Testing requirements

### 10.1 Automated (minimum)

- Unit: `SessionService` actor routing; permission helper (`*` / `platform.admin`); error mapper for `proxy_required`, `eligibility_incomplete`, billing gate.
- Unit: document download chooser (restricted → content proxy).
- Widget/controller tests for onboarding step gating (cannot skip accept).
- Repository tests with mocked Dio for register, accept engagement, upload finalize.

Keep using `mocktail` (already in pubspec). Prefer testing repositories/controllers over pixel-perfect golden tests.

### 10.2 Manual smoke checklist

1. Staff login → workforce invite → contractor register → login → onboarding legal → accept engagement (grant off) → upload credential evidence → staff reviews → approve (see eligibility) → activate.
2. Create client + site → job + recurrence generate → contractor sees visit → mobile check-in/complete.
3. Rate card edit → payment batch create/post; band breakdown visible.
4. Contractor privacy export + rights request.
5. Subscription inactive tenant → mutating call shows billing CTA.
6. Web: all staff screens usable; contractor check-in disabled with message.
7. Restricted doc: download uses `/content`, not signed URL.

### 10.3 Explicit non-tests

Do not write tests for deleted employee clock/PIN/scheduling board.

---

## 11. Error & empty-state catalogue

| Situation | UX |
|-----------|-----|
| No engagements (contractor) | Empty home: “Waiting for a provider invite” |
| Eligibility incomplete | Dialog/list of requirement + reason; no approve |
| Scan pending | Disable “ready” badges; show spinner state |
| Scan blocked | Error; allow re-upload / supersede |
| counsel_pending | Hard stop message |
| Missing permission | Hide control; if deep-linked, snackbar + home |
| Offline / network | Retry banner |
| Rate limit 429 | “Too many attempts — try again shortly” |

---

## 12. Dependencies

**Keep:** `get`, `dio`, `flutter_secure_storage`, `geolocator`, `permission_handler`, `firebase_messaging`, `flutter_screenutil`, `data_table_2` (staff tables OK).

**Add (required):** `url_launcher` (billing + landing links), `flutter_markdown` (legal/notice display).

**Remove when unused:** `get_storage` if fully replaced; any employee-only packages.

**Do not add:** Riverpod, BLoC, GoRouter (stay on GetX).

---

## 13. Cross-repo references

| Topic | Path |
|-------|------|
| Contractor domain | `backend/docs/superpowers/specs/2026-07-22-contractor-client-job-design.md` |
| Privacy/compliance | `backend/docs/superpowers/specs/2026-07-23-ndis-contractor-privacy-security-legal-design.md` |
| Rate bands | `backend/docs/superpowers/specs/2026-07-23-engagement-rate-bands-design.md` |
| RBAC (verify vs live routers) | `backend/docs/RBAC_PERMISSIONS_AND_ROUTES.md` |
| Landing registration | `backend/docs/registration-api-frontend-guide.md` |
| Landing billing | `backend/docs/flutter-billing-subscription-frontend-guide.md` |
| **Deprecated** employee schedule guide | `backend/docs/flutter-employee-shift-schedule-screen-guide.md` — do not follow |

---

## 14. Explicit non-goals (V1)

- Records engine / NDIS client onboarding packs.
- Company self-registration inside Flutter.
- In-app GoCardless checkout/cancel (deep-link only).
- Retention / legal-hold admin UI.
- Platform admin tenant console (beyond what staff settings need).
- Migrating off GetX.
- Visual rebrand / new marketing site.
- Claiming NDIS certification or legal compliance in UI copy.
- Biometric ID matching, screening registry integrations.
- Preserving employee attendance product.

---

## 15. Known backend gap (Flutter workaround is mandatory)

**Public legal document fetch for contractor register:** authenticated `GET /v1/compliance/legal-documents/current` requires `compliance.legal.read`. Public `POST /v1/contractors/register` requires `terms_version` + `privacy_version` validated against `doc_key`s `platform_terms` and `privacy_policy`.

**V1 Flutter approach (locked):** dart-define `TERMS_VERSION` / `PRIVACY_VERSION` + bundled markdown assets that match DB current versions; after login, re-fetch via authenticated compliance API. Prefer a follow-up backend public legal-read endpoint, but do not block Flutter S1 on it.

Do not silently send invented version strings.

---

## 16. Success criteria

The frontend restructure is done when:

1. No navigable employee clock/employee CRUD/old shift/old payroll-period UI remains.
2. Staff and contractor shells cover all §6 domains against live `/v1` APIs.
3. Compliance flows record separate legal events; eligibility and proxy rules are respected.
4. Web + mobile both run; GPS gated correctly on web.
5. Billing checkout remains on landing; Flutter only deep-links.
6. Analyze/tests for new session/compliance/document helpers pass; smoke checklist §10.2 completed.

---

*End of design spec.*
