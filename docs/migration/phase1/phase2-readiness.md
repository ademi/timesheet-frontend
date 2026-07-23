# Phase 2 readiness gate

**Purpose:** Confirm everything Phase 2 needs is frozen and discoverable **before** scaffolding.  
**Primary API helper:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md)  
**Local API:** `http://localhost:8000` · Swagger `/docs` · OpenAPI `/openapi.json`

Use this as a go/no-go. Do not start Phase 2 coding until every **Required** row is ✅.

---

## Go / no-go checklist

| # | Required input for Phase 2 | Status | Where |
|---|----------------------------|--------|-------|
| 1 | Actors + JWT claims (`actor_type`, ids, `permissions`, `mcp`) | ✅ | Wiring guide §2.1 · `JwtClaims` already in code |
| 2 | Login / refresh / switch-tenant / me-context shapes | ✅ | Wiring guide §2 · OpenAPI `LoginResponse` / `MeContextResponse` |
| 3 | Permissions source = JWT only | ✅ | Decisions locked · Roles-2 |
| 4 | Full permission key catalog for `AppPermissions` | ✅ | [app-permissions-catalog.md](./app-permissions-catalog.md) |
| 5 | Engagement status → JWT narrowing | ✅ | Wiring guide §2.2 · catalog below |
| 6 | Error `detail` codes + toast vs screen | ✅ | [error-catalog.md](./error-catalog.md) · Wiring guide §18 |
| 7 | V1 In / Out / Later (incl. landing-only) | ✅ | [v1-scope-matrix.md](./v1-scope-matrix.md) |
| 8 | Flutter vs landing-page API ownership | ✅ | [api-path-inventory.md](./api-path-inventory.md) · Wiring guide Flutter notes |
| 9 | Obsolete paths to stop calling | ✅ | Wiring guide §1 · path inventory |
| 10 | Dual-shell destinations + post-login matrix | ✅ | [post-login-redirect-matrix.md](./post-login-redirect-matrix.md) |
| 11 | Document upload flow | ✅ | Wiring guide §11 · `DocumentRemoteDataSource` spike |
| 12 | Visit GPS body + Idempotency-Key | ✅ | Wiring guide §9 / §18 · `VisitGpsBody` |
| 13 | Cutover wipe rules | ✅ | [cutover-agreement.md](./cutover-agreement.md) |
| 14 | Module folder / datasource map | ✅ | This doc §Phase 2 scaffold map |
| 15 | Feature flag plan (`DOMAIN_V2`) | ✅ | This doc §Feature flag |
| 16 | Live OpenAPI reachable | ✅ | [openapi-review.md](./openapi-review.md) |

**Verdict:** Phase 2 may start.

---

## Wiring guide → Phase 2 crosswalk

| Wiring guide section | Phase 2 use | Flutter builds? |
|----------------------|-------------|-----------------|
| §1 Quick start / stop calling | `AppConstants` deprecations; ban obsolete Dio paths | Yes (ban list) |
| §2 Auth & session | `SessionController`, `TokenStorage`, AuthGuard | Yes |
| §2.2 Permission keys | `AppPermissions` constants | Yes |
| §3 Public (`/public/register`, client-invite, geocode) | **Landing / separate web** — not Flutter UI | No (except optional geocode later if sites need it — default map/pin In may use coords only) |
| §4 Contractors register + contractor-me | Contractor module stubs | Yes (`/contractors/register`, `/contractor-me`) |
| §5 Engagements | Engagement module stubs | Yes |
| §6 Tenant members | Team module stubs | Yes |
| §7 Clients / sites / contacts | Client module stubs | Yes; public acknowledge = Out |
| §8 Form templates | Form module (list/get/submit; **no builder**) | Consume + submit only |
| §9 Jobs / visits / check-in | Job + Visit stubs | Yes |
| §10 Contractor schedule | Timetable stubs under contractor shell | Yes |
| §11 Documents | `DocumentService` | Yes |
| §12 Attendance adjustments | Later Phase 3; stub path OK in constants | Yes (admin) |
| §13 Rates + payment batches | Payment module stubs | Yes |
| §14 Branches / tenants | Branches in admin settings | Yes (own tenant); platform tenant admin Out |
| §15 Notifications | Device register + later inbox | Yes |
| §16 Subscriptions | **Landing page only** | No UI; defensive `subscription_expired` only |
| §17 Recommended wiring order | Session + shell routing order | Yes (skip public register step) |
| §18 Errors + Idempotency | Typed failure mapper | Yes |
| §19 Endpoint index | Path constants inventory | Filtered by Flutter In |

---

## Phase 2 scaffold map (folders ↔ APIs)

Create under `lib/app/data/models/` (+ matching datasources / repositories / bindings):

| Folder | Primary paths (see path inventory) | Shell |
|--------|--------------------------------------|-------|
| `auth/` (exists) | `/v1/auth/*`, `/v1/me` | Both |
| `tenant_member/` | `/v1/tenant-members` | Admin |
| `contractor/` | `/v1/contractors/register`, `/v1/contractor-me` | Both |
| `engagement/` | `/v1/tenants/current/engagements`, `/v1/engagements/{id}/*`, `/v1/contractor-me/engagements` | Both |
| `client/` | `/v1/clients`, sites, contacts, invites | Admin |
| `form/` | `/v1/form-templates`, visit form-submissions | Both |
| `job/` | `/v1/jobs`, recurrence-rules, form-catalog | Admin |
| `visit/` (started) | `/v1/visits`, check-in/complete/tasks | Both |
| `document/` (started) | `/v1/documents/*` | Both |
| `payment/` | `/v1/payment-batches`, `/v1/payroll/engagement-rates` | Admin (+ contractor via visits) |
| `scheduling/` (retarget) | Prefer `/v1/contractor-me/timetable\|availability\|leave` — **not** old `/v1/scheduling/*` | Contractor |

**Do not scaffold Flutter UI modules for:** `/v1/public/register`, `/v1/subscription*`, public client-invite acknowledge, `platform.admin` tenants CRUD.

---

## Feature flag

| Item | Value |
|------|--------|
| Dart define | `DOMAIN_V2=true` (default `false` until cutover binary) |
| First launch when true | Run cutover wipe (tokens, `user_role`, branch, `payroll_settings`) then force login |
| Docs | Document in Phase 2 PR / team README when wiring lands |

---

## Already landed in Phase 1 (reuse in Phase 2)

| Artifact | Path |
|----------|------|
| `JwtClaims` | `lib/core/auth/jwt_claims.dart` |
| `TokenStorage.jwtClaims` | `lib/core/services/token_storage.dart` |
| Login `actor_type` + `engagements` | `lib/app/data/models/auth/auth_token_model.dart` |
| `switchTenant` / `getMeContext` | `lib/app/data/datasources/remote/auth_remote_datasource.dart` |
| Document upload spike DS | `lib/app/data/datasources/remote/document_remote_datasource.dart` |
| Visit check-in spike DS | `lib/app/data/datasources/remote/visit_remote_datasource.dart` |
| Spike runner | `tool/phase1_spikes.dart` |

---

## Remaining gaps (OK to start Phase 2 — track, don’t block)

| Gap | Handling |
|-----|----------|
| No live authenticated fixtures without landing-page tenants | Use seeded accounts for dogfood; contract spikes already signed |
| Exact exhaustive seed permission list may drift from SQL | Prefer live JWT + OpenAPI; catalog below is seed-derived |
| Suspended + `visits.complete` 403 | Defensive copy (known backend gap) |
| No own payment-batches list | Contractor uses `GET /visits?payment_status=` |

---

*Gate prepared 2026-07-23. Update if wiring guide or OpenAPI drifts.*
