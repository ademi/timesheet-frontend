# Backend / Product Clarification Questions

Companion to [flutter-migration-impact-study.md](./flutter-migration-impact-study.md).

Mark answers in-place as they are confirmed. Items labeled **Blocker** should be resolved before Phase 3 core UI work.

---

## Authentication and users

1. **Blocker:** What exact claims appear on access JWT after login for `tenant_member` vs `contractor` (`actor_type`, `contractor_id`, `tenant_member_id`, `tenant_id`, `permissions`, others)?
2. **Blocker:** Does login return an engagements list for contractors when multiple tenants exist, or must the client call `GET /auth/me/context` / `GET /contractor-me/engagements` first?
3. Is `must_change_password` / `complete_first_login` still required for both actor types?
4. Does `POST /auth/refresh` require the same `tenant_id` binding, and what happens if engagement was suspended mid-session?
5. Is `POST /contractors/register` in scope for the Flutter app, or web-only?
6. Can the same email exist as a user before engagement invite (invite existing user vs create)?
7. Are phone-based logins still supported unchanged?

## Roles and permissions

1. **Blocker:** Final permission key list and which role templates include which keys (owner/admin/supervisor/contractor)?
2. Will Flutter receive permissions only via JWT, or also via `/auth/me/context`?
3. How should the UI behave on `missing_permission` vs `wrong_actor_type` (global toast vs dedicated screen)?
4. Is `platform.admin` expected to use this Flutter app?
5. For supervisors: confirm read/manage boundaries for payments and contractor docs.

## Contractor / client relationship

1. **Blocker:** Mobile UX for engagement invite accept — in-app only, magic link deep link, or both?
2. While `pending_docs`, can contractors use any other screens besides document upload?
3. On `suspended`, confirm contractor can complete/check-out but not check-in — any other allowed APIs (timetable read, payments view)?
4. On `ended`, confirm historical visit/job doc read still allowed; profile docs hidden — any list APIs still available?
5. Clients have no login — does Flutter need any client-facing UI beyond admin CRUD + invite creation?
6. Is client invite acknowledge (`/v1/public/client-invites/...`) built in Flutter web, separate web app, or out of scope?
7. Can a contractor be invited to a tenant before registering an account?

## Job / project lifecycle

1. **Blocker:** Confirm normative job location rule: `branch_id XOR client_site_id` always required?
2. Standing job: UI enforcement for “one open standing job per client” — create vs reopen rules?
3. Recurrence generate: default `partial=false`; should mobile support `partial=true` with per-occurrence errors?
4. Who can cancel a visit, and can contractors cancel?
5. Task toggle: contractor and tenant member — any supervisor restrictions?
6. Visit `source=recurrence` regenerate rules — is regenerate exposed in V1 mobile admin?
7. Concurrent visits for same contractor across tenants allowed — should timetable UI warn?

## API contracts

1. **Blocker:** Publish OpenAPI (or equivalent) for all §16 endpoints with request/response examples.
2. **Blocker:** Exact GPS body schema for check-in/complete (lat/lng/accuracy/timestamp)?
3. Exact document upload flow: `upload-url` → client PUT → `finalize` fields and failure modes?
4. List/filter query params for `GET /visits` (status, contractor, client, payment_status, date range, branch)?
5. Pagination conventions (cursor vs offset) for new list endpoints?
6. Do obsolete employee/PIN/period endpoints return 404 or stay temporarily?
7. Attendance adjustment endpoints: paths, payloads, replacing `AdjustmentAction`?
8. Is there a replacement for `GET /v1/attendance/reports/weekly`?
9. Engagement rates: path under `/payroll` or `/engagements/{id}/rates`?
10. Payment batches: request body for create (visit id list), post, void — response shapes?

## Data migration

1. Confirm production expectation: **fresh DB**, no employee→contractor backfill (as written in spec §18)?
2. What happens to existing mobile users’ sessions on cutover date?
3. Is there a minimum app version / force-update mechanism?
4. Any seed data available for Flutter staging (sample tenant, contractor, standing job, visits)?

## Notifications

1. Which events are delivered via FCM vs in-app inbox only?
2. Payload schema for `visit.assigned`, `engagement.invited`, etc.?
3. Should stubbed email/sms appear anywhere in the Flutter UI (delivery log)?
4. Does device registration endpoint remain `POST /v1/notifications/devices` unchanged?

## Payments (and rates)

1. **Blocker:** Is employee balance concept retired completely?
2. Can batches mix contractors, or one contractor per batch?
3. Currency: always engagement rate currency, or tenant default?
4. Contractor `payments.view_own` — list by visit or by batch line?
5. Void after post: allowed in V1 UI?
6. Are Excel/CSV exports planned for batches?

## UI / UX behavior

1. **Blocker:** One Flutter app with dual shells, two flavors, or admin web + contractor mobile?
2. Is form **template builder** in mobile V1, or consume/submit only?
3. Is client CRM fully in mobile V1?
4. Branch gateway: required for contractors? for all tenant members?
5. Map/pin picker for sites and job locations — required V1?
6. Offline / poor-network expectations for check-in?
7. Localization / timezone display rules (tenant tz vs device tz)?

## Edge cases

1. Contractor checks in just as engagement is suspended — expected API error and UI recovery?
2. Required form file scanned as `blocked` after upload — retry UX?
3. Visit complete with informational geofence outside — any admin flag shown?
4. Overlapping generate conflicts — how are error details structured for UI?
5. Token storage on web refresh after switch-tenant — any cookie differences?
6. User deleted / engagement ended while app backgrounded — next API call behavior?
7. Multiple devices same contractor — concurrent check-in race (`FOR UPDATE`) — UX message?

---

## Answer log

| ID | Question (short) | Answer | Date | Answered by |
|----|------------------|--------|------|-------------|
| Auth-1 | JWT claims tenant_member vs contractor | Access JWT always: `sub`, `tenant_id`, `permissions[]`, `actor_type`, `iat`, `exp`, `typ=access`. Contractor adds `contractor_id`. Tenant member adds `tenant_member_id` when present. If password must change: `mcp=true`. No separate permissions claim beyond the array. | 2026-07-23 | Backend (post-db8a2d5) |
| Auth-2 | Login engagements list vs /me/context | Login/refresh/switch-tenant **return** `engagements: [{id, tenant_id, tenant_name, status}]` for contractors (empty for tenant_members). Client can also call `GET /v1/auth/me/context` or `GET /v1/contractor-me/engagements`. Not required before first paint if login body is used. | 2026-07-23 | Backend |
| Auth-3 | must_change_password / complete_first_login | Yes for both actor types. Flag from `auth.user_credentials.must_change_password`; JWT may include `mcp`. `POST /v1/auth/complete_first_login` still required when set. | 2026-07-23 | Backend |
| Auth-4 | Refresh tenant binding + mid-session suspend | Refresh is bound to stored refresh-token `tenant_id` (same tenant). Re-issues permissions for that tenant. If engagement **suspended**, new JWT gets limited perms (`auth.session`, `visits.read` only). If **ended**, permission resolve fails → refresh fails (no engagement). | 2026-07-23 | Backend |
| Auth-5 | POST /contractors/register Flutter vs web | Public API (`POST /v1/contractors/register`). Backend does not restrict client; Flutter **can** use it (contractor must exist before tenant invite). Not web-only. | 2026-07-23 | Backend |
| Auth-6 | Invite existing user vs create | Invite (`POST /v1/tenants/current/engagements`) requires an **existing contractor** (lookup by email/phone) → 404 `contractor_not_found` otherwise. Same email as plain user without contractor row cannot be invited until they register as contractor. Hard-split: cannot invite a tenant_member user. | 2026-07-23 | Backend |
| Auth-7 | Phone login | Yes unchanged: `POST /v1/auth/login` `identifier` = email **or** phone + password. | 2026-07-23 | Backend |
| Roles-1 | Permission keys + role templates | Catalog in `seed/001_dev_seed.sql`. **owner:** all keys except `platform.admin`. **admin:** broad manage (no `rbac.manage` / `platform.admin`; includes billing/subscription/payments.manage/contractor approve). **supervisor:** `auth.session`, `tenants.read`, `tenant_members.read`, `contractors.read/invite`, `clients.read/manage`, `jobs.read/manage`, `visits.read/manage`, `payments.view`, `notifications.receive`, `audit.view` — **no** `contractors.approve/manage/docs.read`, **no** `payments.manage`, **no** `attendance.adjust`. **contractor:** `auth.session`, `visits.read/check_in/complete`, `documents.upload`, `payments.view_own`, `notifications.receive`, `contractor.schedule.manage`. **platform_admin:** `platform.admin`, `auth.session`, `subscription.view/manage`. | 2026-07-23 | Backend |
| Roles-2 | Permissions via JWT and/or me/context | Primary source is JWT `permissions`. `/auth/me/context` returns actor + engagements, **not** a permissions list. Also mirrored on `GET /v1/me`. | 2026-07-23 | Backend |
| Roles-3 | missing_permission vs wrong_actor_type UX | Both HTTP **403**. `detail` string is `missing_permission`-style from RBAC, or exact `wrong_actor_type` when actor guard fails. Backend does not prescribe toast vs screen — recommend dedicated screen for `wrong_actor_type`, toast/retry for missing_permission. | 2026-07-23 | Backend + product note |
| Roles-4 | platform.admin on Flutter | Not intended for contractor/tenant Flutter app. Platform ops only; role is sparsely assigned. | 2026-07-23 | Spec/seed |
| Roles-5 | Supervisor payments + contractor docs | Supervisor: `payments.view` only (no manage). **No** `contractors.docs.read` / approve / manage — invite+read contractors only. Owner/admin have docs.read + payments.manage. | 2026-07-23 | Seed |
| Eng-1 | Invite accept UX (in-app / deep link) | Backend: authenticated `POST /v1/engagements/{id}/accept` (contractor JWT). No magic-link accept endpoint. Delivery is notification `engagement.invited` (FCM/inbox). **Deep-link UX is product choice**; API is in-app token accept. | 2026-07-23 | Backend |
| Eng-2 | pending_docs allowed screens | Login allowed. JWT limited to `auth.session`, `visits.read`, `documents.upload`. Practical: profile/docs upload + read visits; no check-in/complete/schedule manage/payments. | 2026-07-23 | Backend (rbac resolver) |
| Eng-3 | suspended allowed APIs | Spec: no assign/check-in; complete/check-out allowed. JWT when suspended: only `auth.session` + `visits.read` → **complete currently 403** (`visits.complete` stripped) despite service allowing `active|suspended`. Timetable OK (`auth.session`). Payments/docs upload not in JWT. After refresh, same limited set. | 2026-07-23 | Backend (gap noted) |
| Eng-4 | ended historical access | `ended` not login-eligible for that tenant. Consent revoked → tenant cannot read contractor **profile** docs. Contractor can still read **job/visit/form_submission** docs if historically assigned (ACL by assignment). List APIs for that tenant engagement will not issue tokens. | 2026-07-23 | Spec + ACL |
| Eng-5 | Client-facing Flutter UI | Clients have **no login**. Flutter needs tenant-member CRM (CRUD clients/sites/contacts/docs/invites) only — no client app shell. | 2026-07-23 | Spec |
| Eng-6 | Public client-invite acknowledge | Public: `GET/POST /v1/public/client-invites/{token}[/acknowledge]`. Backend-agnostic host (web/Flutter web). Not required inside contractor mobile; can be separate web page. | 2026-07-23 | Backend |
| Eng-7 | Invite before account | **No.** Invite requires existing `workforce.contractors` row. Flow: `POST /contractors/register` then invite. | 2026-07-23 | Backend |
| Job-1 | branch_id XOR client_site_id | **Yes, always.** DB CHECK + Pydantic: exactly one of `branch_id` / `client_site_id`. | 2026-07-23 | Migration V005 + API |
| Job-2 | One open standing job per client | Enforced by unique partial index + API `standing_job_exists` (409). Create second open standing → fail. Reopen: only if no other open standing for that client. | 2026-07-23 | Backend |
| Job-3 | Recurrence partial=true | Default `partial=false` (all-or-nothing). `partial=true` supported: returns `created_visit_ids` + `skipped[{scheduled_start, detail}]` (`visit_overlap`, `already_generated`). Mobile may support it. | 2026-07-23 | Backend |
| Job-4 | Who can cancel visits | Tenant members with `visits.manage` via `POST /v1/visits/{id}/cancel`. Contractors **cannot** cancel (no route for them). | 2026-07-23 | Backend |
| Job-5 | Task toggle who | Assignee contractor (`visits.check_in`) or tenant member with `visits.manage`. Supervisors with visits.manage can toggle; no extra restriction. | 2026-07-23 | Backend |
| Job-6 | Recurrence regenerate in V1 mobile | Spec mentions regenerate for future `source=recurrence` visits; **no regenerate endpoint implemented**. Only `POST .../recurrence-rules/{rid}/generate`. | 2026-07-23 | Backend |
| Job-7 | Cross-tenant concurrent visits | Allowed (not hard-blocked). Timetable is cross-tenant; UI **may** warn — backend will not reject. | 2026-07-23 | Spec |
| API-1 | OpenAPI for §16 | FastAPI serves live OpenAPI at `/openapi.json` and Swagger at `/docs` (title timesheet-api 0.2.0). No separate static OpenAPI file required. | 2026-07-23 | Backend |
| API-2 | GPS body schema | `VisitGpsBody`: `{ "lat": float, "lng": float, "accuracy_m": float|null }` — no client timestamp field. Used by check-in and complete. | 2026-07-23 | Backend |
| API-3 | Document upload flow | `POST /v1/documents/upload-url` → `{document_id, upload_url, gcs_object_key, expires_in_seconds}` → client PUT to signed URL → `POST /v1/documents/{id}/finalize` → scan_status. Failures: ACL deny, content-type/size, blocked scan on complete forms (`scan_blocked` / forms gate). | 2026-07-23 | Backend |
| API-4 | GET /visits filters | Query: `payment_status`, `job_id`, `from`, `to`, `limit` (1–500, default 100). Contractors auto-scoped to own visits. **No** status/contractor/client/branch query params yet. | 2026-07-23 | Backend |
| API-5 | Pagination | **Offset/limit style**, not cursor. `limit` on visits/jobs/batches lists. | 2026-07-23 | Backend |
| API-6 | Obsolete employee/PIN/period endpoints | Unmounted from `routes.py` (employees, scheduling, geofence, clock-in/out, payroll periods). Expect **404**. Dead module files may remain but are not live. | 2026-07-23 | Backend |
| API-7 | Attendance adjustments | `POST /v1/attendance/adjustments` + `GET /v1/attendance/time-entries/{id}/adjustments`. Actions: `admin_add_clock_out`, `admin_close_clock_out`, `admin_create_manual_entry`, `admin_edit_entry`. Requires `attendance.adjust`. Visit-linked (`visit_id` for manual). Replaces employee AdjustmentAction flow. | 2026-07-23 | Backend |
| API-8 | Weekly attendance report | **Removed** from live attendance router. No replacement weekly report endpoint in contractor era. | 2026-07-23 | Backend |
| API-9 | Engagement rates path | Under payroll: `GET/POST /v1/payroll/engagement-rates/{engagement_id}`, `PATCH /v1/payroll/engagement-rates/{rate_id}`. Not under `/engagements/{id}/rates`. | 2026-07-23 | Backend |
| API-10 | Payment batch shapes | Create `POST /v1/payment-batches` body: `{visit_ids:[], period_label?, currency_code=AUD}` → `PaymentBatchOut` with `lines[{visit_id, contractor_id, hours, rate, amount}]`. Post: `POST .../{id}/post`. Void: `POST .../{id}/void` (works on draft or posted; posted resets visits to unpaid). | 2026-07-23 | Backend |
| Data-1 | Fresh DB / no employee backfill | **Confirmed** (spec §18): fresh rebuild, no employee→contractor backfill. | 2026-07-23 | Spec |
| Data-2 | Existing sessions on cutover | Old JWTs/refresh tokens invalid against new schema/claims. Users must re-login. | 2026-07-23 | Implied |
| Data-3 | Min app version / force-update | **Not implemented** in backend. Product/store decision. | 2026-07-23 | Backend |
| Data-4 | Staging seed data | `seed/001_dev_seed.sql` seeds **permissions/roles only** — no sample tenant/contractor/job fixtures. Tests create data ad hoc. | 2026-07-23 | Seed |
| Notif-1 | FCM vs inbox | In-app inbox: `GET /v1/notifications/events`. Push via FCM when devices registered. Stub **email/sms** for `client.invite` and `client.visit_completed` only (`status=stubbed`, no provider). Engagement/visit events go through notification pipeline (push+inbox). | 2026-07-23 | Backend |
| Notif-2 | Payload schema examples | `visit.assigned`: `{visit_id, job_title, client_name?}`. `visit.checked_in`: `{visit_id, job_title, checked_in_at?}`. `visit.completed`: `{visit_id, job_title, client_name?, completed_at?}`. `engagement.*`: engagement_id + related ids in payload. `client.invite`: `{invite_url, client_name, contact_email?, contact_phone?}`. | 2026-07-23 | Backend |
| Notif-3 | Stub email/sms in Flutter UI | No admin delivery-log UI required. Stub rows exist in DB for ops/tests; not a Flutter V1 surface. | 2026-07-23 | Spec |
| Notif-4 | Device registration path | Yes unchanged: `POST /v1/notifications/devices`, `DELETE /v1/notifications/devices/{token}` (`auth.session`). | 2026-07-23 | Backend |
| Pay-1 | Employee balance retired | **Yes.** No payroll periods/results/employee balance APIs. Visit payment batches + engagement rates only. | 2026-07-23 | Spec + code |
| Pay-2 | Mix contractors in batch | **Yes.** Batch lines are per visit with `contractor_id`; no one-contractor-per-batch rule. | 2026-07-23 | Backend |
| Pay-3 | Currency | Batch `currency_code` on create (default AUD). Rate snapshot from engagement rate at visit date. Not a separate tenant-default currency field in V1. | 2026-07-23 | Backend |
| Pay-4 | payments.view_own list shape | Permission exists on contractor role, but **no dedicated** `/payment-batches` own-list (batches require `payments.view`). Use contractor-scoped `GET /v1/visits?payment_status=paid` (or unpaid) until an own-payments endpoint is added. | 2026-07-23 | Backend (gap) |
| Pay-5 | Void after post in V1 | **Yes, allowed.** Void of posted batch sets visits back to `unpaid` and deletes lines. | 2026-07-23 | Backend |
| Pay-6 | Excel/CSV batch export | **Not implemented** in V1. | 2026-07-23 | Backend |
| UI-1 | One app vs flavors | Backend is dual-actor one API (`actor_type`). Spec does not mandate app packaging — product choice: one Flutter app with dual shells is compatible. | 2026-07-23 | Product (API supports dual) |
| UI-2 | Form template builder mobile V1 | Backend supports full CRUD `/v1/form-templates`. Whether mobile builds templates vs consume/submit only is **product**. Contractor path is submit on visits. | 2026-07-23 | Product |
| UI-3 | Client CRM in mobile V1 | Backend ready (`/v1/clients`, sites, contacts, invites). Scope for mobile V1 is **product**. | 2026-07-23 | Product |
| UI-4 | Branch gateway required | Branches used as job location XOR site; geofence radius on branch. Not a separate “gateway login” for contractors. Tenant members manage branches with `branches.*`. | 2026-07-23 | Backend |
| UI-5 | Map/pin picker V1 | Sites/jobs store lat/lng geog. API accepts coordinates; map UI is **product** (recommended for sites). | 2026-07-23 | Product |
| UI-6 | Offline check-in | Online required. Idempotency-Key supported on check-in/complete. No offline queue protocol. | 2026-07-23 | Backend |
| UI-7 | Timezone display | Tenant timezone used for recurrence/notifications display helpers. Store/API use timestamptz UTC. Display: prefer tenant tz for admin; device tz OK for contractor UX — product. | 2026-07-23 | Backend + product |
| UI-8 | Company public register in Flutter | **No.** `POST /v1/public/register` is **landing page only**. Flutter assumes tenant/owner already exists; app entry is gateway (sign in + contractor register). | 2026-07-23 | Product |
| UI-9 | Subscriptions in Flutter | **No in-app checkout.** Landing owns GoCardless. Flutter: `GET /subscription` status + **billingGate** deep-link to `BILLING_URL` (updated 2026-07-26 Flutter design). | 2026-07-26 | Flutter design |
| UI-10 | Client invite acknowledge in Flutter | **In V1.** Public route `/invites/client/:token` (supersedes earlier “separate web only”). | 2026-07-26 | Flutter design |
| UI-11 | Folder / shell IA | **`lib/features/*`**, StaffShell `/staff/*`, ContractorShell `/contractor/*`; delete legacy as slices land. | 2026-07-26 | Flutter design |
| UI-12 | Compliance / credentials in Flutter V1 | **In.** Legal events, notices, consents, credentials vault, reviews, eligibility, rights/export/incidents. | 2026-07-26 | Flutter design |
| UI-13 | Rate model | Engagement **rate bands** (base/evening/night/weekend/PH), not only single hourly rate. | 2026-07-26 | Flutter design |
| UI-14 | Delivery order | Skeleton-first slices **S0–S10** (replace Phase 3–6 coding order). | 2026-07-26 | Flutter design |
| Edge-1 | Check-in while suspended | Check-in requires engagement `active` → **409** `engagement_not_active` (or 403 missing `visits.check_in` after refresh). UI: show suspended state, block check-in, allow viewing visit / attempt complete if already checked_in (see Eng-3 gap). | 2026-07-23 | Backend |
| Edge-2 | Required form file blocked | Complete gated on forms; blocked scan fails complete. Retry: re-upload clean file + resubmit form, then complete. | 2026-07-23 | Spec/API |
| Edge-3 | Informational geofence outside | Allowed; stores location verdict `outside`. No dedicated admin “flag” field on visit list — inspect time_entry_locations if needed. | 2026-07-23 | Backend |
| Edge-4 | Overlapping generate errors | `partial=false`: 409 `visit_overlap` aborts. `partial=true`: response `skipped: [{scheduled_start, detail: "visit_overlap"|"already_generated"}]`. | 2026-07-23 | Backend |
| Edge-5 | Web token storage after switch-tenant | Switch-tenant returns new access+refresh (old refresh revoked for prior tenant). Cookie vs secure storage is **client** concern; API is Bearer tokens, no cookie auth. | 2026-07-23 | Backend |
| Edge-6 | User deleted / engagement ended backgrounded | Next API: 401/403. Refresh fails if engagement ended. Clear session and re-login / pick another engagement. | 2026-07-23 | Backend |
| Edge-7 | Concurrent check-in race | Visit row `SELECT FOR UPDATE`; loser gets 409 `invalid_visit_status` (or conflict). UX: “Already checked in” / refresh visit. | 2026-07-23 | Backend |
