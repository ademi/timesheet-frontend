# Backend handoff log (Flutter → API)

**Audience:** API / backend developers  
**Branch context:** `contractor_workflow`  
**Maintained by:** Flutter migration work

> **Process:** From now on, any backend change needed for Flutter slices is recorded in this file.  
> Add a new **Issue** section (problem, expected behaviour, proposed/done change, verification).  
> Do not open separate one-off handoff files unless the topic is huge enough to split later.

---

## Issue index

| ID | Date | Status | Topic |
|----|------|--------|-------|
| BH-001 | 2026-07-26 | Proposed / applied in local tree — needs API restart + review | Contractor register nested transaction → opaque HTTP 500 |
| BH-002 | 2026-07-26 | Done — applied in local tree | Contractor login blocked when no engagement exists |
| BH-003 | 2026-07-26 | Done — applied in local tree | Pre-active engagement JWT lacks `compliance.legal.*` / consent perms (blocks S2 onboarding) |
| BH-004 | 2026-07-26 | Done — applied in local tree | Pre-active engagement JWT lacks `credentials.read` / `credentials.manage` (blocks S3) |
| BH-005 | 2026-07-26 | Done — applied in local tree | Client invite deep-link path mismatch (`/invite/{token}` vs `/invites/client/{token}`) |
| BH-006 | 2026-07-26 | Done — applied in local tree | Client site `latitude`/`longitude` optional server-side; Flutter requires them |
| BH-007 | 2026-07-26 | Done — applied in local tree | No `GET` list of client invites for staff Invites tab |
| BH-008 | 2026-07-26 | Done — applied in local tree | No `GET /v1/jobs/{id}` — job detail cannot reload after refresh |
| BH-009 | 2026-07-26 | Done — applied in local tree | No `GET /v1/jobs/{id}/form-catalog` — attach-only UX |
| BH-010 | 2026-07-26 | Done — applied in local tree | Engagement rate create: bands vs simple `hourly_rate` |
| BH-011 | 2026-07-27 | Done — applied in local tree | Visit form requirements not visible to contractors |

---

## BH-001 — Contractor register nested-transaction fix

**Date:** 2026-07-26  
**File changed:** `timesheet-backend/app/modules/contractors/service.py`  
**Related Flutter work:** S1 contractor public register (`POST /v1/contractors/register`)

### Summary

While wiring Flutter S1 (public contractor register), `POST /v1/contractors/register` was returning **HTTP 500 Internal Server Error** with an empty body against the local API (`http://localhost:8000`). Investigation pointed to **nested database transactions** inside `register_contractor`: the handler opened a transaction and then called `register_user`, which opens **its own** transaction on the same connection.

A small structural change was applied in the backend so `register_user` is no longer nested inside an outer `conn.transaction()` in `register_contractor`.

**Please review, restart the API process so the change is loaded, and confirm register returns 201 (or a proper 4xx) instead of 500.**

### Problem

#### Symptom

```http
POST /v1/contractors/register
Content-Type: application/json

{
  "full_name": "Probe User",
  "email": "probe@example.com",
  "password": "Contractor1!",
  "terms_version": "v0.1-placeholder",
  "privacy_version": "v0.1-placeholder"
}
```

**Observed:** `500 Internal Server Error` with body `Internal Server Error` (no structured `detail`).

**Expected:**

| Outcome | Status | Notes |
|---------|--------|--------|
| Success | `201` | `{ contractor_id, user_id, email }` — **no tokens** |
| Bad / unknown legal version | `4xx` | e.g. `legal_document_unavailable` |
| Email already registered | `409` | |
| Hard-split (tenant member) | `409` | `hard_split_violation` |
| Validation | `422` | password rules, missing fields |

Opaque 500s block Flutter dogfood of S1 (register → login).

#### Root cause (suspected / addressed)

**Before (nested transactions):**

```text
register_contractor:
  async with conn.transaction():          ← outer txn
      register_user(...):
          async with conn.transaction():  ← nested txn / savepoint
              INSERT auth.users
              INSERT auth.user_credentials
          log_security_event(...)
      INSERT workforce.contractors
      compliance legal_events (accepted ×2)
```

`register_user` (in `app/modules/auth/service.py`) always starts its own `async with conn.transaction()`. Calling it **inside** another open transaction on the same `asyncpg` connection is fragile: depending on runtime/driver behaviour, later steps (contractor insert / legal events / rollback on `HTTPException`) can surface as an unhandled error → FastAPI **500** with no useful client `detail`.

This is separate from (but often confused with):

- Missing seeded legal docs (`platform_terms` / `privacy_policy` versions)
- Wrong `terms_version` / `privacy_version` (should be **4xx**, not 500)
- `counsel_pending` fail-closed in **production** only

Those should remain proper HTTP errors after the transaction structure is sound.

### Change made

**File:** `app/modules/contractors/service.py`  
**Function:** `register_contractor`

**After (un-nested):**

```text
register_contractor:
  # hard-split checks (unchanged)
  register_user(...)                      ← owns its own transaction
  async with conn.transaction():          ← contractor + legal only
      INSERT workforce.contractors
      compliance legal_events (accepted ×2)
  return ContractorRegisterResponse
```

#### Behavioural notes / trade-off

| Topic | Detail |
|-------|--------|
| What improved | Avoids nested txn around `register_user`; clearer failure modes for contractor/legal steps |
| Atomicity | Auth user creation and contractor+legal are **no longer one atomic transaction**. If contractor/legal fails **after** `register_user` succeeds, an auth user may exist without a contractor row |
| Follow-up (recommended) | On failure after user create: compensate (delete user / mark incomplete) **or** refactor so user+contractor+legal share a **single** transaction without `register_user` opening a nested one (e.g. internal helper that inserts without starting its own txn) |
| API contract | Unchanged: same request/response schema for `POST /v1/contractors/register` |

No OpenAPI / route / schema changes were made. Rate limit (`5/minute`) and body fields are unchanged.

### Flutter / local env expectations (for verification)

Flutter S1 sends:

- `terms_version` / `privacy_version` from dart-defines (local defaults: **`v0.1-placeholder`**, matching `timesheet-db` seed `011_compliance_policy_placeholders.sql`)
- Bundled markdown is display-only until a public legal-read endpoint exists

Ensure DB has current, non-retired versions for:

- `doc_key = platform_terms`
- `doc_key = privacy_policy`

If versions are missing, the API should return a **structured 4xx**, not 500.

### Verification checklist (API)

1. **Restart** the backend process so `service.py` is loaded (debug sessions often do not hot-reload this).
2. Confirm legal rows exist (or seed them).
3. Call register with a fresh email and matching versions → expect **201**.
4. Call again with same email → expect **409**.
5. Call with unknown `terms_version` → expect **4xx** with a clear `detail` / code (not 500).
6. Optionally re-run existing contractor register tests:
   - `tests/contractors/test_register_legal.py`
   - smoke tests that call `/v1/contractors/register`

### Requested API review

Please confirm:

1. The un-nested structure is acceptable for V1, **or** propose a single-transaction refactor without nested `register_user`.
2. Whether compensation is required if contractor/legal fails after user insert.
3. That local seed versions (`v0.1-placeholder`) are the intended dogfood versions (or publish the canonical versions Flutter should send via `TERMS_VERSION` / `PRIVACY_VERSION`).

### Related Flutter docs

- [implementation-checklist.md](./implementation-checklist.md) — S1
- [domain-v2-flag.md](./domain-v2-flag.md) — dart-defines for legal versions
- [manual-qa-s0-s1.md](./manual-qa-s0-s1.md) — manual test steps
- Design §6.2 — contractor register contract (no tokens on success)

---

## BH-002 — Contractor login blocked when no engagement exists

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S1 / S2  
**Endpoint / area:** `POST /v1/auth/login` · `_resolve_login_actor` / `_issue_auth_session` in `app/modules/auth/service.py` · `app/modules/rbac/resolver.py` · `app/modules/auth/token.py`

### Problem

After `POST /v1/contractors/register`, the contractor has a user + contractor profile but **no** `workforce.contractor_engagements` row until a provider invites them.

Current login resolution for contractors:

1. Requires a pickable tenant from engagements (`pick_tenant_id_for_user`).
2. If none → **403** `"User has no engagement in any tenant"`.

**Flutter impact:** S1 exit “register → login” and S2 onboarding cannot be dogfooded for a brand-new contractor without a manual staff invite first.

### Expected

Allow contractor login **without** an engagement (tenant_id may be null / omitted) with at least:

- `actor_type=contractor`
- `contractor_id` on JWT
- Baseline permissions sufficient for onboarding: `auth.session`, `compliance.legal.read`, `compliance.legal.accept`, `compliance.consent.manage` (see BH-003)

Or document an official “invite-before-login” product rule and provide a seed/fixture path for QA.

### Change made

**Product decision:** Allow pre-engagement contractor login (not invite-before-login).

**Files:**

- `app/modules/auth/service.py` — `_resolve_login_actor`, `_issue_auth_session`, `_store_refresh_token`, `refresh_session`
- `app/modules/auth/token.py` — `create_access_token` accepts nullable `tenant_id`
- `app/modules/rbac/resolver.py` — `_CONTRACTOR_PRE_ENGAGEMENT_PERMISSIONS` + `pre_engagement_contractor_permissions()`
- `tests/auth/test_login_jwt.py` — `test_contractor_login_without_engagement_issues_pre_engagement_session`

**Behaviour:**

1. If `workforce.contractors` exists and no eligible engagement / tenant can be picked → still return `actor_type=contractor` with `tenant_id=None` and empty `engagements`.
2. Session issue path uses baseline pre-engagement permissions (not tenant RBAC):
   - `auth.session`
   - `compliance.legal.read`
   - `compliance.legal.accept`
   - `compliance.consent.manage`
3. JWT `tenant_id` claim is JSON `null`; refresh tokens store `tenant_id NULL` (column already nullable).
4. Refresh of a null-tenant token is allowed **only** for contractors (pre-engagement sessions). Tenant members still require a tenant-bound refresh row.
5. Requesting a specific `tenant_id` without an engagement in that tenant still returns **403** `"User has no engagement in requested tenant"`.

### Verification

1. Register contractor (unique email).
2. Login with same credentials **before** any invite → **200** tokens, `actor_type=contractor`.
3. `GET /v1/auth/me/context` returns contractor with empty engagements and `tenant_id: null`.
4. Pytest: `tests/auth/test_login_jwt.py::test_contractor_login_without_engagement_issues_pre_engagement_session` (passed).

### Requested from API

Confirm intended product behaviour and implement or provide fixtures. → **Implemented** as pre-engagement login with null tenant + baseline compliance permissions.

---

## BH-003 — Pre-active engagement JWT lacks compliance permissions

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S2  
**Endpoint / area:** `app/modules/rbac/resolver.py` · `resolve_permissions_for_tenant`

### Problem

For contractors with engagement status `invited` / `pending_docs` / `approved`, permissions are limited to:

```text
auth.session, visits.read, documents.upload
```

(`_CONTRACTOR_LIMITED_PERMISSIONS`)

Full system `contractor` role permissions (including `compliance.legal.read`, `compliance.legal.accept`, `compliance.consent.manage`) are only granted when status is **`active`**.

**Flutter impact:** S2 onboarding calls:

- `GET /v1/compliance/legal-documents/current`
- `GET /v1/compliance/collection-notices`
- `POST /v1/compliance/legal-events` (`presented` / `accepted` / `acknowledged` / `consented`)

These require compliance permissions → **403 `missing_permission`** during the exact statuses when onboarding must run.

### Expected

Engagements in `invited`, `pending_docs`, and `approved` should include at least:

- `compliance.legal.read`
- `compliance.legal.accept`
- `compliance.consent.manage`

Credential keys for S3 are tracked separately as **BH-004**.

Keep tighter limits for `suspended` if needed.

### Change made

**File:** `app/modules/rbac/resolver.py`  
**Constant:** `_CONTRACTOR_LIMITED_PERMISSIONS`

Expanded the limited (pre-active) set to:

```text
auth.session, visits.read, documents.upload,
compliance.legal.read, compliance.legal.accept, compliance.consent.manage
```

This applies whenever engagement status is `invited`, `pending_docs`, or `approved` (same branch as before in `resolve_permissions_for_tenant`).

**Unchanged:**

- `active` → full system `contractor` role permissions
- `suspended` → still only `auth.session`, `visits.read` (`_CONTRACTOR_SUSPENDED_PERMISSIONS`)

**Test:** `tests/rbac/test_rbac_tenant_isolation.py::test_contractor_pre_active_engagement_includes_compliance_permissions` — asserts compliance keys for `invited` / `pending_docs` / `approved`, and that `visits.check_in` stays absent.

### Verification

1. Invite contractor → login while `invited`.
2. Decode JWT `permissions` includes `compliance.legal.read` and `compliance.legal.accept`.
3. `GET /v1/compliance/legal-documents/current?doc_key=platform_terms` → **200** (or structured counsel error, not 403 missing_permission).
4. `POST /v1/compliance/legal-events` presented/accepted → **201**.
5. Pytest above (passed).

### Requested from API

Approve permission matrix for onboarding statuses and ship the resolver change. → **Shipped** (compliance keys only; credentials remain BH-004).

---

## BH-004 — Pre-active engagement JWT lacks credential permissions

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S3  
**Endpoint / area:** `app/modules/rbac/resolver.py` · `_CONTRACTOR_LIMITED_PERMISSIONS`

### Problem

Same limited set as BH-003 for `invited` / `pending_docs` / `approved` (before this change):

```text
auth.session, visits.read, documents.upload,
compliance.legal.read, compliance.legal.accept, compliance.consent.manage
```

S3 contractor flows require:

| Action | Permission |
|--------|------------|
| `GET /v1/contractor-me/credentials` | `credentials.read` |
| `POST/PATCH .../credentials` · supersede | `credentials.manage` |
| `POST /v1/documents/upload-url` · finalize | `documents.upload` (already present) |

**Flutter impact:** Onboarding credentials step and `/contractor/credentials` show permission errors until the engagement is **`active`** — too late for the pending-docs funnel.

### Expected

Expand `_CONTRACTOR_LIMITED_PERMISSIONS` to include at least:

- `credentials.read`
- `credentials.manage`

(alongside BH-003 compliance keys).

### Change made

**File:** `app/modules/rbac/resolver.py`  
**Constant:** `_CONTRACTOR_LIMITED_PERMISSIONS`

Added `credentials.read` and `credentials.manage` to the pre-active limited set. Full set for `invited` / `pending_docs` / `approved` is now:

```text
auth.session, visits.read, documents.upload,
compliance.legal.read, compliance.legal.accept, compliance.consent.manage,
credentials.read, credentials.manage
```

**Unchanged:** `suspended` still excludes credentials; `active` still gets full contractor role.

**Test:** extended `test_contractor_pre_active_engagement_includes_compliance_permissions` to assert credential keys (passed).

### Verification

1. Contractor with `pending_docs` engagement logs in.
2. JWT includes `credentials.read` and `credentials.manage`.
3. `GET /v1/contractor-me/credentials` → **200**.
4. After a valid `presented` notice event + consent (if sensitive): `POST /v1/contractor-me/credentials` → **201**.
5. Pytest above (passed).

### Requested from API

Ship resolver change with BH-003 (same permission matrix for pre-active statuses). → **Shipped**.

---

## BH-005 — Client invite deep-link path mismatch

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S5  
**Endpoint / area:** `app/modules/clients/service.py` · `create_client_invite` · notification `invite_url`

### Problem

Flutter design (§4.1 / §6.6) and app routes use:

```text
/invites/client/{token}
```

Wired to:

- `GET /v1/public/client-invites/{token}`
- `POST /v1/public/client-invites/{token}/acknowledge`

Backend `create_client_invite` builds the emailed URL as:

```text
{public_app_base_url}/invite/{raw_token}
```

**Flutter impact:** Email / notification links open a path that does not match the design route. Flutter temporarily registers **both** `/invites/client/:token` and `/invite/:token` to the same acknowledge screen, but email deep-links and docs will diverge until the API is aligned.

### Expected

Use a single canonical path everywhere (prefer design):

```text
{public_app_base_url}/invites/client/{token}
```

Update `invite_url` construction in `create_client_invite` (and any notification templates / landing redirects).

If landing hosts the page instead of Flutter, document the host + path contract explicitly.

### Change made

**File:** `app/modules/clients/service.py` · `create_client_invite`

```text
Before: {public_app_base_url}/invite/{raw_token}
After:  {public_app_base_url}/invites/client/{raw_token}
```

Notification `client.invite` payload `invite_url` now uses the Flutter design path. Stub notification fixtures updated to match.

**Test:** `tests/clients/test_client_invite.py::test_client_crud_and_invite_happy_path` asserts the stored notification payload contains `/invites/client/<token>` (passed).

### Verification

1. Staff `POST /v1/clients/{id}/invites` → 201 `{ token, expires_at }`.
2. Notification / logged `invite_url` ends with `/invites/client/<token>`.
3. Opening that URL in the Flutter web app loads the public acknowledge screen and `GET /v1/public/client-invites/<token>` succeeds.
4. Pytest above (passed).

### Requested from API

Align `invite_url` path with Flutter design (or confirm landing owns `/invite/` and Flutter should not). → **Aligned** to `/invites/client/{token}`.

---

## BH-006 — Client site lat/lng should be required

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S5  
**Endpoint / area:** `ClientSiteCreate` / `ClientSiteUpdate` · `create_client_site`

### Problem

Flutter S5 checklist / design: **lat/lng required** for sites (geofence check-in later).

Backend `ClientSiteCreate` treats `latitude` / `longitude` as **optional**. Sites can be created with `location_geog = NULL`.

**Flutter impact:** UI enforces lat/lng client-side, but other clients / scripts can still create coordinate-less sites that will break visit geofence in S7.

### Expected

- Reject create (and preferably patch that clears both coords) without valid `latitude` + `longitude` — e.g. `422` validation or `400` with a clear `detail` code such as `site_coordinates_required`.
- Keep `geofence_radius_m` defaults as today (`100`, range 10–5000).

### Change made

**Files:**

- `app/modules/clients/schemas.py` — `ClientSiteCreate` / `ClientSiteUpdate`
- `app/modules/clients/service.py` — `create_client_site` always writes `location_geog`
- `tests/clients/test_client_sites.py` — create without/partial/with coords + reject clear-on-patch

**Behaviour:**

1. `ClientSiteCreate.latitude` / `longitude` are **required** (still `ge=-90..90` / `ge=-180..180`). Missing → FastAPI **422**.
2. Create always inserts `ST_SetSRID(ST_MakePoint(lon, lat), 4326)::geography` (no null location path).
3. `ClientSiteUpdate`: if either coord is present in the request body, both must be non-null together; clearing with `null`/`null` → **422** (`site_coordinates_required` in validation message). Omitting both leaves existing coords unchanged.
4. `geofence_radius_m` default `100`, range 10–5000 unchanged.

### Verification

1. `POST /v1/clients/{id}/sites` without lat/lng → **422**.
2. With valid lat/lng → **201** and GET returns both fields.
3. Patch with `latitude: null, longitude: null` → **422**.
4. Pytest `tests/clients/test_client_sites.py` (passed).

### Requested from API

Make coordinates required on site create (and document update rules). → **Done**.

---

## BH-007 — No staff list of client invites

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S5  
**Endpoint / area:** `GET /v1/clients/{id}/invites` (new) · `POST /v1/clients/{id}/invites`

### Problem

Staff Invites tab can **create** a token (`POST .../invites` → `{ token, expires_at }`) but there is **no** `GET /v1/clients/{id}/invites` (or similar) to list outstanding / consumed invites.

**Flutter impact:** UI shows only the last invite created in the current session. Staff cannot audit expiry / consumption after leaving the screen. Raw token is only returned once (hash stored) — listing would need metadata only (created_at, expires_at, consumed_at), not the raw token again.

### Product decision

**Ship the list endpoint for V1.** Staff need invite history to audit outstanding vs consumed invites; “last created in session” is not enough. Raw tokens remain create-only (security).

### Change made

**API:**

```http
GET /v1/clients/{client_id}/invites
Permission: clients.read
```

Response item (`ClientInviteOut`):

```json
{
  "id": "...",
  "expires_at": "...",
  "consumed_at": null,
  "created_at": "...",
  "created_by_user_id": "..."
}
```

**Do not** return raw tokens on list (only on create). Ordered newest-first (`created_at DESC`).

**Files:**

- `timesheet-db/migrations/V014__client_invite_tokens_created_at.sql` — adds `created_at` (+ index) to `clients.client_invite_tokens`
- `app/modules/clients/schemas.py` — `ClientInviteOut`
- `app/modules/clients/service.py` — `list_client_invites`
- `app/modules/clients/router.py` — `GET /{client_id}/invites`
- `tests/clients/test_client_invite.py` — list metadata + consumed_at after acknowledge

### Verification

1. Create two invites → GET list returns two metadata rows (no `token`).
2. After acknowledge → one row has `consumed_at` set.
3. Pytest `test_list_client_invites_returns_metadata_without_token` (passed).

### Requested from API

Confirm whether V1 needs invite history; if yes, add list endpoint. If no, Flutter keeps “last created only” UX. → **Decision: yes; endpoint shipped.** Apply `V014` on non-test DBs before dogfood.

---

## BH-008 — No GET job by id

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S6  
**Endpoint / area:** `GET /v1/jobs/{job_id}`

### Problem
Staff job detail is loaded from list selection / navigation args only. There is no `GET /v1/jobs/{id}`, so web refresh on `/staff/jobs/detail` cannot rehydrate the job (Flutter shows an empty “not loaded” state).

### Change made
Added `GET /v1/jobs/{job_id}` returning the same `JobOut` shape as list items.

**Permission:** `jobs.read`  
**404:** `detail: "job_not_found"` when missing or wrong tenant

**Files:**

- `app/modules/jobs/service.py` — `get_job` (uses existing `_get_job_or_404` + `_row_to_job`)
- `app/modules/jobs/router.py` — `GET /jobs/{job_id}`
- `tests/jobs/test_get_job.py` — create → get by id; unknown id → 404

### Verification
1. Create a job → `GET /v1/jobs/{id}` returns 200 with matching fields.  
2. Flutter can open detail by id after refresh.
3. Pytest `tests/jobs/test_get_job.py` (passed).

### Requested from API
Confirm and implement GET-by-id (or document intentional omission). → **Implemented**.

---

## BH-009 — No GET job form-catalog

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S6  
**Endpoint / area:** `GET /v1/jobs/{job_id}/form-catalog` (POST already existed)

### Problem
Flutter can `POST` attach a form template to a job, but cannot list attached catalog entries. Staff UI tracks “attached this session” only and cannot show true catalog state after reload.

### Change made
Added `GET /v1/jobs/{job_id}/form-catalog` returning attached template refs.

**Permission:** `jobs.read`  
**404:** same as other job routes (`job_not_found`) when job missing / wrong tenant

Response item (`JobFormCatalogOut`):

```json
{
  "form_template_id": "...",
  "name": "...",
  "is_active": true,
  "client_id": "..."
}
```

Note: `work.job_form_catalog` has no `required` column — required flags live on recurrence `form_requirements`, not on the job catalog attach list.

**Files:**

- `app/modules/jobs/schemas.py` — `JobFormCatalogOut`
- `app/modules/jobs/service.py` — `list_job_form_catalog`
- `app/modules/jobs/router.py` — `GET /jobs/{job_id}/form-catalog`
- `tests/jobs/test_job_form_catalog.py`

### Verification
1. Attach two templates → GET returns both.  
2. Flutter detail screen shows catalog without session-only memory.
3. Pytest `tests/jobs/test_job_form_catalog.py` (passed).

### Requested from API
Add list endpoint (or nest catalog on JobOut). → **List endpoint shipped** (not nested on JobOut).

---

## BH-010 — Engagement rate create body (bands vs hourly)

**Date:** 2026-07-26  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S9  
**Endpoint / area:** `POST /v1/payroll/engagement-rates/{engagement_id}` · `GET` list · payment batch lines

### Problem
Flutter design locks **rate bands** (`base`, `evening`, `night`, `saturday`, `sunday`, `public_holiday` + evening/night windows). The older wiring guide still documents a single `hourly_rate`. Flutter S9 sends **both**: `hourly_rate` (= base) and `bands` + window fields.

### Product / schema decision

**Bands are the source of truth.** Flat `*_rate` columns remain the DB storage. `hourly_rate` is a back-compat alias of `base_rate` on create/update/response.

### Change made

**File:** `app/modules/payroll/schemas.py`

**Create body (accepted shapes):**

1. Compat-only:
```json
{ "effective_from": "2026-01-01", "hourly_rate": 55.0, "currency_code": "AUD" }
```

2. Flutter S9 (preferred):
```json
{
  "effective_from": "2026-03-01",
  "hourly_rate": 30.0,
  "bands": {
    "base": 30.0,
    "evening": 36.0,
    "night": 42.0,
    "saturday": 45.0,
    "sunday": 50.0,
    "public_holiday": 60.0
  },
  "evening_start": "18:00:00",
  "night_start": "22:00:00",
  "night_end": "06:00:00",
  "currency_code": "AUD"
}
```

When `bands.*` keys are present they win over flat `*_rate` / `hourly_rate` for those keys. Base is required via `bands.base`, `base_rate`, or `hourly_rate`.

**Response (`EngagementRateOut`):**

- Canonical flat fields: `base_rate`, `saturday_rate`, `sunday_rate`, `evening_rate`, `night_rate`, `public_holiday_rate`, window times
- Compat: `hourly_rate` (= `base_rate`)
- Nested: `bands` object mirroring the flat rates (for Flutter)

**Payment batch lines:** `band_breakdown` already on `PaymentBatchLineOut` (`band`, `minutes`, `hours`, `rate`, `amount`, optional `local_start` / `local_end`) — unchanged; covered by existing saturday premium test.

**Also:** update path merges nested `bands` the same way; `bands` is excluded from SQL SET columns.

**Tests:** extended `test_engagement_rate_crud`; added `test_engagement_rate_create_with_nested_bands`; rate segmentation + saturday `band_breakdown` still pass.

### Published schema (wiring §13)

| Field | Create | Response | Notes |
|-------|--------|----------|-------|
| `effective_from` | required | yes | date |
| `effective_to` | optional | yes | |
| `hourly_rate` | optional alias | yes (computed) | = base |
| `base_rate` | optional | yes | canonical base |
| `bands` | optional object | yes (computed) | preferred Flutter shape |
| `saturday_rate` … `public_holiday_rate` | optional flat | yes | DB columns |
| `evening_start` / `night_start` / `night_end` | optional (defaults 18:00 / 22:00 / 06:00) | yes | |
| `currency_code` | default `AUD` | yes | |

### Verification
1. POST rate with nested `bands` → 201; GET returns bands + flat fields.  
2. POST with only `hourly_rate` → 201; response has `hourly_rate` + `base_rate` + `bands.base`.  
3. Payment batch line includes `band_breakdown` when multi-band hours apply (existing test).  
4. Pytest suite above (passed).

### Requested from API
Publish final EngagementRate create/response schema; update wiring guide §13. → **Published in this section**; OpenAPI reflects the Pydantic models.

---

## BH-011 — Visit form requirements not visible to contractors

**Date:** 2026-07-27  
**Status:** Done — applied in local tree  
**Related Flutter slice:** S7 / MVP delivery  
**Endpoint / area:** `GET /v1/visits/{id}`, `GET /v1/visits` · `VisitOut`

### Problem

Contractor completes a visit after check-in and gets `required_forms_incomplete`, but `GET /v1/visits/{id}` (and list) did **not** include form requirements or submission summaries. Contractors could not discover required templates without staff UUID paste; job form-catalog and form-templates remain staff-only (`jobs.read`).

### Change made (preferred option)

Extended `VisitOut` with:

**`form_requirements`** — from `work.visit_form_requirements` joined to template name:

```json
{
  "form_template_id": "...",
  "name": "Progress report",
  "is_required": true
}
```

**`form_submissions`** — summary from `work.form_submissions` (no payload body):

```json
{
  "id": "...",
  "form_template_id": "...",
  "created_at": "...",
  "updated_at": "..."
}
```

Populated on `GET /v1/visits/{id}`, `GET /v1/visits`, and other visit returns that use the shared visit mapper (`create_manual_visit`, `reschedule_visit`).

**Files:**

- `app/modules/jobs/schemas.py` — `VisitFormRequirementOut`, `VisitFormSubmissionSummaryOut`; fields on `VisitOut`
- `app/modules/jobs/service.py` — batch loaders + `_visit_out_from_row`
- `tests/jobs/test_visit_form_requirements.py`

**Not changed:** staff-only `GET /v1/jobs/{id}/form-catalog` (contractors get requirements via visit payload).

### Verification

1. Generate visit with required form on recurrence.  
2. Contractor GET visit → sees required form name/id.  
3. Submit form → `form_submissions` populated; complete succeeds.  
4. Pytest `tests/jobs/test_visit_form_requirements.py` (passed).

---

## Template for new issues

Copy below when Flutter needs another backend change:

```markdown
## BH-00N — <short title>

**Date:** YYYY-MM-DD  
**Status:** Open | Proposed change applied | Waiting on API | Done  
**Related Flutter slice:** Sx  
**Endpoint / area:**  

### Problem
(symptom, expected vs actual, how Flutter is blocked)

### Proposed or applied change
(file, behaviour, API contract impact)

### Verification
(steps / curl / tests)

### Requested from API
(decision / merge / seed / docs)
```
