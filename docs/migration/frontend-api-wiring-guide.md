# Frontend API Wiring Guide — Contractor Platform (V2)

**Audience:** Flutter / web frontend developers  
**Scope:** New contractor / client / job platform only (from commit `db8a2d5` onward)  
**Live docs:** Swagger UI at `{BASE_URL}/docs` · OpenAPI at `{BASE_URL}/openapi.json`  
**Local default (Flutter):** `http://localhost:8000`  
**Companion design:** [`docs/2026-07-22-contractor-client-job-design (1).md`](../2026-07-22-contractor-client-job-design%20(1).md)  
**Flutter Phase 1 freeze / Phase 2 gate:** [phase1/phase2-readiness.md](./phase1/phase2-readiness.md) · [phase1/api-path-inventory.md](./phase1/api-path-inventory.md) · [phase1/app-permissions-catalog.md](./phase1/app-permissions-catalog.md)

### Flutter vs landing page (product lock — 2026-07-23)

| Surface | Owns |
|---------|------|
| **Landing page** | `POST /v1/public/register` (company + owner), `/v1/subscription*` billing UI, public client-invite acknowledge |
| **Flutter app** | Login + dual shells; `POST /v1/contractors/register`; workforce APIs below. **No** company register UI, **no** subscription checkout UI |
| **Flutter defensive only** | Login `subscription` object; `403 subscription_expired` → “renew on the website” |

---

## 1. Quick start

| Item | Value |
|------|--------|
| Base path | `/v1` |
| Auth header | `Authorization: Bearer <access_token>` |
| Content type | `application/json` |
| Health | `GET /health` → `{ "status": "ok" }` |
| Ready | `GET /ready` → `{ "status": "ready" }` |

### Actors

| `actor_type` | Who | JWT extras |
|--------------|-----|------------|
| `tenant_member` | Tenant staff (owner/admin/supervisor) | `tenant_member_id` |
| `contractor` | Global contractor profile | `contractor_id` |

A user **cannot** be both. Clients have **no login**.

### What to stop calling (removed / unmounted)

Do **not** wire these anymore — they return **404**:

- `/v1/employees`, PIN verify/set, employee clock-in/out
- `/v1/scheduling/*`
- `/v1/geofence/*`
- `/v1/payroll/periods`, employee balance, period export
- Free-floating attendance punch APIs

---

## 2. Authentication & session

### 2.1 JWT access claims

Decode `access_token` (do not trust client-forged values for auth — server re-checks):

```json
{
  "sub": "11111111-1111-1111-1111-111111111111",
  "tenant_id": "22222222-2222-2222-2222-222222222222",
  "permissions": ["auth.session", "visits.check_in", "visits.complete"],
  "actor_type": "contractor",
  "contractor_id": "33333333-3333-3333-3333-333333333333",
  "iat": 1720000000,
  "exp": 1720003600,
  "typ": "access"
}
```

| Claim | When present |
|-------|----------------|
| `tenant_member_id` | Tenant member sessions |
| `contractor_id` | Contractor sessions |
| `mcp: true` | Must change password — only `POST /v1/auth/complete_first_login` is allowed |

### 2.2 Permission keys (role templates)

| Role | Typical permissions |
|------|---------------------|
| **owner** | Everything except `platform.admin` |
| **admin** | Broad tenant manage (no `rbac.manage` / `platform.admin`) |
| **supervisor** | Jobs/visits/clients manage; contractors read+invite; `payments.view` (not manage/approve/docs) |
| **contractor** | `visits.read/check_in/complete`, `documents.upload`, `payments.view_own`, `contractor.schedule.manage`, `notifications.receive` |

Contractor JWT is **narrowed by engagement status**:

| Engagement status | JWT permissions |
|-------------------|-----------------|
| `active` | Full contractor role |
| `invited` / `pending_docs` / `approved` | `auth.session`, `visits.read`, `documents.upload` |
| `suspended` | `auth.session`, `visits.read` only |
| `ended` | Cannot login to that tenant |

---

### `POST /v1/auth/login`

**Auth:** none · **Rate:** 20/min

**Request**

```json
{
  "identifier": "jane@contractor.example",
  "password": "SecretPass1!",
  "tenant_id": null
}
```

`identifier` = email **or** phone. Optional `tenant_id` selects engagement/tenant when the user has many.

**Response `200`**

```json
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "rt_...",
  "token_type": "bearer",
  "must_change_password": false,
  "subscription": {
    "status": "active",
    "is_active": true,
    "is_readonly": false,
    "trial_end_at": null,
    "days_left": null,
    "message": "Subscription active"
  },
  "actor_type": "contractor",
  "engagements": [
    {
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "tenant_id": "22222222-2222-2222-2222-222222222222",
      "tenant_name": "Acme Care",
      "status": "active"
    }
  ]
}
```

For tenant members, `engagements` is `[]`.

**Errors:** `401` `"Invalid email, phone, or password"` · `403` no engagement/role in tenant.

---

### `POST /v1/auth/refresh`

**Request**

```json
{ "refresh_token": "rt_..." }
```

**Response:** same shape as login (new access + rotated refresh). Bound to the refresh token’s `tenant_id`.

---

### `POST /v1/auth/logout`

```json
{ "refresh_token": "rt_..." }
```

**Response:** `{ "message": "ok" }`

---

### `POST /v1/auth/switch-tenant`

**Auth:** `auth.session`

```json
{ "tenant_id": "22222222-2222-2222-2222-222222222222" }
```

**Response:** same as login (new tokens for that tenant). Contractor needs a login-eligible engagement; tenant member needs membership/role.

---

### `GET /v1/auth/me/context`

**Auth:** `auth.session`

**Response**

```json
{
  "actor_type": "contractor",
  "tenant_id": "22222222-2222-2222-2222-222222222222",
  "contractor_id": "33333333-3333-3333-3333-333333333333",
  "tenant_member_id": null,
  "engagements": [
    {
      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "tenant_id": "22222222-2222-2222-2222-222222222222",
      "tenant_name": "Acme Care",
      "status": "active"
    }
  ]
}
```

---

### `POST /v1/auth/complete_first_login`

**Auth:** `auth.session` (allowed even when `mcp=true`)

```json
{ "new_password": "NewSecretPass1!" }
```

**Response:** `{ "message": "Password set. Please log in again." }` — then re-login.

---

### `POST /v1/auth/change_password`

**Auth:** `auth.session`

```json
{
  "email": "jane@example.com",
  "current_password": "OldPass1!",
  "new_password": "NewPass1!"
}
```

Revokes all refresh tokens for the user.

---

### `POST /v1/auth/register`

Creates a bare auth user (not a contractor profile). Prefer `POST /v1/contractors/register` for contractors, or company register under `/v1/public/register` for tenants.

```json
{
  "email": "user@example.com",
  "password": "SecretPass1!",
  "phone": "+61400000000"
}
```

**Response `201`:** `{ "user_id": "...", "email": "...", "message": "User registered successfully" }`

---

### `GET /v1/me`

**Auth:** `auth.session`

```json
{
  "sub": "11111111-1111-1111-1111-111111111111",
  "tenant_id": "22222222-2222-2222-2222-222222222222",
  "permissions": ["auth.session", "jobs.manage"]
}
```

Prefer `/v1/auth/users/me` for profile and `/v1/auth/me/context` for actor context.

---

### Profile — `/v1/auth/users`

| Method | Path | Perm | Notes |
|--------|------|------|-------|
| GET | `/v1/auth/users/me` | `auth.session` | Own profile |
| PATCH | `/v1/auth/users/me` | `auth.session` | Body: `{ "email"?, "phone"? }` |
| GET | `/v1/auth/users/{user_id}` | self / `rbac.manage` / `platform.admin` | |
| PATCH | `/v1/auth/users/{user_id}/status` | `platform.admin` | `{ "status": "active" \| "suspended" }` |

**UserProfile example**

```json
{
  "id": "11111111-1111-1111-1111-111111111111",
  "email": "jane@example.com",
  "phone": "+61400000000",
  "status": "active",
  "created_at": "2026-07-01T00:00:00Z",
  "updated_at": "2026-07-01T00:00:00Z"
}
```

---

## 3. Public (no JWT)

> **Flutter:** Do **not** build company signup (`POST /v1/public/register`) or public client-invite acknowledge in the app — those are **landing / separate web**. Optional later: `POST /v1/public/geocode` if address→coords is needed for site create (sites also accept lat/lng directly).

Public errors use `{ "message": "..." }` (not `detail`).

### `POST /v1/public/register` — company signup

Creates tenant + primary branch + owner tenant_member + billing account + tokens.

Optional header: `Idempotency-Key: <8-128 chars [A-Za-z0-9_-]>`

**Request (shape)**

```json
{
  "company": {
    "name": "Acme Care",
    "industry": "healthcare",
    "default_currency_code": "AUD"
  },
  "branches": [
    {
      "name": "Sydney HQ",
      "address_line1": "1 George St",
      "city": "Sydney",
      "state": "NSW",
      "country": "AU",
      "geofence": { "lat": -33.8688, "lng": 151.2093, "radius_meters": 100 },
      "is_primary": true
    }
  ],
  "admin": {
    "full_name": "Sam Owner",
    "email": "sam@acme.example",
    "phone": "+61411111111",
    "password": "SecretPass1!"
  }
}
```

**Response `201`**

```json
{
  "tenant_id": "22222222-2222-2222-2222-222222222222",
  "message": "Registration successful.",
  "admin_must_change_password": false,
  "access_token": "eyJ...",
  "refresh_token": "rt_...",
  "token_type": "bearer"
}
```

### `POST /v1/public/geocode`

```json
{
  "address_line1": "1 George St",
  "city": "Sydney",
  "state": "NSW",
  "country": "AU"
}
```

**Response:** `{ "latitude": -33.86, "longitude": 151.20, "formatted_address": "...", "confidence": "high" }`

### Client invite (token in URL)

| Method | Path | Body | Response |
|--------|------|------|----------|
| GET | `/v1/public/client-invites/{token}` | — | `{ "tenant_name", "client_first_name", "expires_at", "consent_acknowledged" }` |
| POST | `/v1/public/client-invites/{token}/acknowledge` | `{ "accept": true }` | `{ "message", "consent_acknowledged_at" }` |

---

## 4. Contractors

### `POST /v1/contractors/register` — public

Contractor must register **before** a tenant can invite them.

```json
{
  "full_name": "Jane Contractor",
  "email": "jane@contractor.example",
  "password": "SecretPass1!",
  "phone": "+61422222222",
  "dob": "1990-05-01"
}
```

**Response `201`**

```json
{
  "contractor_id": "33333333-3333-3333-3333-333333333333",
  "user_id": "11111111-1111-1111-1111-111111111111",
  "email": "jane@contractor.example"
}
```

### `GET /v1/contractor-me` · `PATCH /v1/contractor-me`

**Auth:** `auth.session` · **Actor:** contractor only (`wrong_actor_type` otherwise)

**PATCH body**

```json
{
  "full_name": "Jane C.",
  "phone": "+61422222222",
  "dob": "1990-05-01",
  "metadata": { "trade": "plumbing" }
}
```

**Response**

```json
{
  "id": "33333333-3333-3333-3333-333333333333",
  "user_id": "11111111-1111-1111-1111-111111111111",
  "full_name": "Jane C.",
  "email": "jane@contractor.example",
  "phone": "+61422222222",
  "dob": "1990-05-01",
  "metadata": { "trade": "plumbing" },
  "created_at": "2026-07-01T00:00:00Z",
  "updated_at": "2026-07-22T00:00:00Z"
}
```

---

## 5. Engagements (tenant ↔ contractor)

### Status machine

```text
invited → pending_docs → approved → active ⇄ suspended → ended
```

| Transition | Endpoint | Who | Perm |
|------------|----------|-----|------|
| Invite | `POST /v1/tenants/current/engagements` | tenant | `contractors.invite` |
| Accept | `POST /v1/engagements/{id}/accept` | contractor | `auth.session` |
| Approve | `POST /v1/engagements/{id}/approve` | tenant | `contractors.approve` |
| Activate | `POST /v1/engagements/{id}/activate` | tenant | `contractors.manage` |
| Approve+activate | `POST /v1/engagements/{id}/approve-and-activate` | tenant | `contractors.approve` |
| Suspend / Resume / End | `POST /v1/engagements/{id}/suspend\|resume\|end` | tenant | `contractors.manage` |

### Invite existing contractor

```http
POST /v1/tenants/current/engagements
Authorization: Bearer <tenant_jwt>
```

```json
{
  "email": "jane@contractor.example",
  "phone": null,
  "required_categories": ["passport_id", "wwcc"]
}
```

**Response `201` — `EngagementOut`**

```json
{
  "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "tenant_id": "22222222-2222-2222-2222-222222222222",
  "tenant_name": "Acme Care",
  "contractor_id": "33333333-3333-3333-3333-333333333333",
  "contractor_name": "Jane Contractor",
  "status": "invited",
  "consented_at": null,
  "consent_revoked_at": null,
  "invited_by_user_id": "...",
  "approved_by_user_id": null,
  "required_doc_categories": [
    { "category": "passport_id", "is_required": true },
    { "category": "wwcc", "is_required": true }
  ],
  "created_at": "2026-07-22T10:00:00Z",
  "updated_at": "2026-07-22T10:00:00Z"
}
```

**Errors:** `404` `contractor_not_found` · `409` `engagement_already_exists` · `409` `hard_split_violation`

### Lists

| Method | Path | Perm | Actor |
|--------|------|------|-------|
| GET | `/v1/tenants/current/engagements` | `contractors.read` | tenant |
| GET | `/v1/contractor-me/engagements` | `auth.session` | contractor |

Lifecycle POSTs take **empty body** and return updated `EngagementOut`.

Doc gate: approve fails with `400` `docs_incomplete` until each required category has a contractor doc with `scan_status` in (`pending`, `clean`).

---

## 6. Tenant members (staff)

Replaces `/employees`. No PIN.

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/tenant-members` | `tenant_members.read` |
| POST | `/v1/tenant-members` | `tenant_members.manage` |
| GET | `/v1/tenant-members/{member_id}` | `tenant_members.read` |
| PATCH | `/v1/tenant-members/{member_id}` | `tenant_members.manage` |

**Create**

```json
{
  "full_name": "Alex Supervisor",
  "phone": "+61433333333",
  "email": "alex@acme.example",
  "role_id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
}
```

(`tenant_id` from JWT — ignore body tenant if present.)

**Response**

```json
{
  "id": "...",
  "tenant_id": "...",
  "user_id": "...",
  "full_name": "Alex Supervisor",
  "phone": "+61433333333",
  "email": "alex@acme.example",
  "is_active": true,
  "role_id": "...",
  "role_name": "supervisor"
}
```

---

## 7. Clients, sites, contacts, invites

**Perms:** read `clients.read` · write `clients.manage`

### Clients

| Method | Path |
|--------|------|
| GET/POST | `/v1/clients` |
| GET/PATCH/DELETE | `/v1/clients/{client_id}` |

**Create**

```json
{
  "full_name": "River Nursing Home",
  "status": "active",
  "email": "admin@river.example",
  "phone": "+61290000000",
  "service_agreement_notes": "Weekly cleaning",
  "metadata": {}
}
```

### Sites

| Method | Path |
|--------|------|
| GET/POST | `/v1/clients/{client_id}/sites` |
| PATCH/DELETE | `/v1/clients/{client_id}/sites/{site_id}` |

**Create**

```json
{
  "name": "Main building",
  "address_line1": "10 River Rd",
  "city": "Sydney",
  "state": "NSW",
  "country": "AU",
  "postal_code": "2000",
  "latitude": -33.87,
  "longitude": 151.21,
  "geofence_radius_m": 120,
  "is_primary": true
}
```

### Contacts

| Method | Path |
|--------|------|
| GET/POST | `/v1/clients/{client_id}/contacts` |
| PATCH/DELETE | `/v1/clients/{client_id}/contacts/{contact_id}` |

```json
{
  "name": "Pat Manager",
  "email": "pat@river.example",
  "phone": "+61444444444",
  "is_primary": true,
  "notify_visit_complete": true
}
```

### Invite token (for public acknowledge page)

```http
POST /v1/clients/{client_id}/invites
```

**Response `201`:** `{ "token": "raw-once-only-token", "expires_at": "2026-07-25T10:00:00Z" }`

---

## 8. Form templates

**Perms:** read `clients.read` · write `clients.manage`

| Method | Path | Query |
|--------|------|-------|
| GET | `/v1/form-templates` | `client_id?`, `tenant_level=true` for tenant-wide (`client_id` null) |
| POST | `/v1/form-templates` | |
| GET/PATCH/DELETE | `/v1/form-templates/{template_id}` | |

**Create**

```json
{
  "name": "Progress notes",
  "client_id": null,
  "is_active": true,
  "schema_json": {
    "fields": [
      { "id": "notes", "type": "text", "label": "Progress notes", "required": true },
      { "id": "well", "type": "boolean", "label": "Client appeared well", "required": true },
      { "id": "photo", "type": "file", "label": "Photo", "required": false, "accept": ["image/jpeg", "image/png"] }
    ]
  }
}
```

Supported field `type`: `text`, `textarea`, `boolean`, `number`, `date`, `file`.

---

## 9. Jobs, visits, check-in

### Job location rule

Exactly one of `branch_id` **XOR** `client_site_id`. Standing jobs require `client_id`. At most **one open standing job per client** (`409` `standing_job_exists`).

### Jobs

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/jobs` | `jobs.manage` |
| GET | `/v1/jobs` | `jobs.read` · query `limit` (1–500, default 100) |
| PATCH | `/v1/jobs/{job_id}` | `jobs.manage` · body `{ "status": "closed" \| "cancelled" }` |
| POST | `/v1/jobs/{job_id}/form-catalog` | `jobs.manage` · `{ "form_template_id": "..." }` → **204** |

**Create standing job**

```json
{
  "kind": "standing",
  "title": "Weekly cleaning — River",
  "client_id": "cccccccc-cccc-cccc-cccc-cccccccccccc",
  "client_site_id": "dddddddd-dddd-dddd-dddd-dddddddddddd",
  "geofence_mode": "informational",
  "geofence_radius_m": 100
}
```

**`JobOut`**

```json
{
  "id": "...",
  "tenant_id": "...",
  "client_id": "...",
  "kind": "standing",
  "status": "open",
  "title": "Weekly cleaning — River",
  "branch_id": null,
  "client_site_id": "...",
  "latitude": -33.87,
  "longitude": 151.21,
  "geofence_radius_m": 100,
  "geofence_mode": "informational",
  "created_at": "...",
  "updated_at": "..."
}
```

### Recurrence (standing jobs)

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/jobs/{job_id}/recurrence-rules` | `jobs.manage` |
| GET | `/v1/jobs/{job_id}/recurrence-rules` | `jobs.read` |
| PATCH | `/v1/jobs/{job_id}/recurrence-rules/{rule_id}` | `jobs.manage` · `{ "is_active": false }` |
| POST | `/v1/jobs/{job_id}/recurrence-rules/{rule_id}/generate` | `jobs.manage` |

**Create rule**

```json
{
  "contractor_id": "33333333-3333-3333-3333-333333333333",
  "rrule": "FREQ=WEEKLY;BYDAY=MO,WE",
  "dtstart": "2026-08-03T09:00:00+10:00",
  "until": "2026-12-31T00:00:00+11:00",
  "duration_minutes": 120,
  "task_template": [
    { "title": "Clean kitchen", "sort_order": 0 },
    { "title": "Clean bathroom", "sort_order": 1 }
  ],
  "form_requirements": [
    { "form_template_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "is_required": true }
  ]
}
```

**Generate**

```json
{
  "from": "2026-08-01T00:00:00Z",
  "to": "2026-08-31T00:00:00Z",
  "partial": false
}
```

Optional header: `Idempotency-Key: generate-aug-2026-01`

**Response**

```json
{
  "created_visit_ids": ["..."],
  "skipped": [
    { "scheduled_start": "2026-08-11T23:00:00Z", "detail": "visit_overlap" }
  ]
}
```

`partial=false` (default): overlap → **409** `visit_overlap` (all-or-nothing).  
`partial=true`: continues; overlaps appear in `skipped`.

### Manual visit

```http
POST /v1/jobs/{job_id}/visits
```

```json
{
  "contractor_id": "33333333-3333-3333-3333-333333333333",
  "scheduled_start": "2026-08-04T09:00:00+10:00",
  "scheduled_end": "2026-08-04T11:00:00+10:00",
  "tasks": [{ "title": "Clean kitchen", "sort_order": 0 }],
  "form_requirements": [
    { "form_template_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "is_required": true }
  ]
}
```

**`VisitOut` (includes nested tasks)**

```json
{
  "id": "...",
  "tenant_id": "...",
  "job_id": "...",
  "contractor_id": "...",
  "scheduled_start": "...",
  "scheduled_end": "...",
  "status": "scheduled",
  "source": "manual",
  "recurrence_rule_id": null,
  "latitude": -33.87,
  "longitude": 151.21,
  "geofence_radius_m": 100,
  "geofence_mode": "informational",
  "payment_status": "unpaid",
  "completed_at": null,
  "tasks": [
    {
      "id": "...",
      "tenant_id": "...",
      "visit_id": "...",
      "title": "Clean kitchen",
      "sort_order": 0,
      "is_done": false,
      "done_at": null,
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "created_at": "...",
  "updated_at": "..."
}
```

### List / get visits

```http
GET /v1/visits?payment_status=unpaid&job_id=...&from=2026-08-01T00:00:00Z&to=2026-08-31T00:00:00Z&limit=100
```

**Perm:** any of `visits.read`, `visits.manage`, `jobs.manage`.  
Contractors without `visits.manage` only see **their** visits.

### Visit workflow (contractor)

```text
scheduled → checked_in → completed
         ↘ cancelled (tenant only)
```

#### Check-in

```http
POST /v1/visits/{visit_id}/check-in
Authorization: Bearer <contractor_jwt>
Idempotency-Key: checkin-<visit_id>
```

```json
{
  "lat": -33.8688,
  "lng": 151.2093,
  "accuracy_m": 12.5
}
```

**Response**

```json
{
  "visit_id": "...",
  "status": "checked_in",
  "time_entry_id": "..."
}
```

Requires engagement **`active`**.  
`geofence_mode=enforce` + outside → **400** `geofence_rejected`.  
Informational mode: allowed; location stored with outside verdict.

#### Toggle task

```http
PATCH /v1/visits/{visit_id}/tasks/{task_id}
```

```json
{ "is_done": true }
```

Perm: `visits.check_in` (assignee) or `visits.manage`.

#### Form submission

```http
POST /v1/visits/{visit_id}/form-submissions
```

```json
{
  "form_template_id": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
  "payload_json": {
    "notes": "All good",
    "well": true,
    "photo": "<document_id UUID after upload>"
  }
}
```

#### Complete

```http
POST /v1/visits/{visit_id}/complete
```

Same GPS body as check-in. Requires required forms submitted; blocked scan files fail complete.

```json
{
  "visit_id": "...",
  "status": "completed",
  "completed_at": "2026-08-04T11:05:00Z"
}
```

Service allows complete when engagement is `active` **or** `suspended`. Note: suspended JWT currently omits `visits.complete` — expect **403** until backend grants that perm on suspend (see clarification Eng-3).

#### Reschedule / cancel (tenant)

| Method | Path | Body | Perm |
|--------|------|------|------|
| PATCH | `/v1/visits/{visit_id}` | `{ "scheduled_start", "scheduled_end" }` | `visits.manage` |
| POST | `/v1/visits/{visit_id}/cancel` | empty | `visits.manage` |

Contractors **cannot** cancel.

---

## 10. Contractor schedule (cross-tenant)

All require `actor_type=contractor`. Timetable ignores any query `contractor_id` (always JWT).

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/contractor-me/timetable?from=...&to=...` | `auth.session` |
| GET | `/v1/contractor-me/availability` | `auth.session` |
| PUT | `/v1/contractor-me/availability` | `contractor.schedule.manage` |
| GET | `/v1/contractor-me/leave` | `auth.session` |
| POST | `/v1/contractor-me/leave` | `contractor.schedule.manage` |
| DELETE | `/v1/contractor-me/leave/{leave_id}` | `contractor.schedule.manage` |

**Timetable response**

```json
{
  "from": "2026-08-01T00:00:00Z",
  "to": "2026-08-08T00:00:00Z",
  "visits": [
    {
      "id": "...",
      "tenant_id": "...",
      "tenant_name": "Acme Care",
      "job_id": "...",
      "scheduled_start": "...",
      "scheduled_end": "...",
      "status": "scheduled"
    }
  ],
  "availability": [
    {
      "id": "...",
      "day_of_week": 1,
      "start_time": "09:00:00",
      "end_time": "17:00:00",
      "created_at": "...",
      "updated_at": "..."
    }
  ],
  "leave": []
}
```

**PUT availability**

```json
{
  "rules": [
    { "day_of_week": 1, "start_time": "09:00:00", "end_time": "17:00:00" },
    { "day_of_week": 3, "start_time": "09:00:00", "end_time": "17:00:00" }
  ]
}
```

`day_of_week`: 0=Monday … 6=Sunday (confirm against product UX; API accepts 0–6).

**POST leave**

```json
{
  "start_date": "2026-09-01",
  "end_date": "2026-09-05",
  "leave_type": "annual",
  "notes": "Holiday"
}
```

---

## 11. Documents (GCS signed URL)

Flow: **upload-url → client PUT → finalize → download-url**.

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/documents/upload-url` | `documents.upload` |
| POST | `/v1/documents/{id}/finalize` | `documents.upload` |
| GET | `/v1/documents?owner_type=...&owner_id=...&limit=100` | `auth.session` |
| GET | `/v1/documents/{id}/download-url` | `auth.session` |

**1. Request upload URL**

```json
{
  "owner_type": "contractor",
  "owner_id": "33333333-3333-3333-3333-333333333333",
  "filename": "passport.pdf",
  "content_type": "application/pdf",
  "size_bytes": 245760,
  "category": "passport_id"
}
```

`owner_type`: `contractor` | `client` | `job` | `visit` | `form_submission`  
`category` required for contractor profile docs.

**Response `201`**

```json
{
  "document_id": "...",
  "upload_url": "https://storage.googleapis.com/...",
  "gcs_object_key": "contractors/.../passport.pdf",
  "expires_in_seconds": 900
}
```

**2.** `PUT` binary bytes to `upload_url` with matching `Content-Type`.

**3. Finalize**

```http
POST /v1/documents/{document_id}/finalize
```

```json
{
  "id": "...",
  "owner_type": "contractor",
  "owner_id": "...",
  "category": "passport_id",
  "filename": "passport.pdf",
  "content_type": "application/pdf",
  "size_bytes": 245760,
  "scan_status": "pending",
  "created_at": "..."
}
```

`scan_status`: `pending` | `clean` | `blocked`. Blocked files cannot be downloaded; required form files that are blocked block visit complete.

---

## 12. Attendance adjustments (tenant admin)

No punch APIs. Corrections only:

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/attendance/adjustments` | `attendance.adjust` |
| GET | `/v1/attendance/time-entries/{time_entry_id}/adjustments` | `attendance.adjust` |

**Actions**

| `action` | Required fields |
|----------|-----------------|
| `admin_add_clock_out` / `admin_close_clock_out` | `time_entry_id`, `clock_out_at`, `reason` |
| `admin_create_manual_entry` | `visit_id`, `clock_in_at`, `clock_out_at`, `reason` |
| `admin_edit_entry` | `time_entry_id`, `reason`, and `clock_in_at` and/or `clock_out_at` |

```json
{
  "action": "admin_create_manual_entry",
  "visit_id": "...",
  "clock_in_at": "2026-08-04T09:05:00Z",
  "clock_out_at": "2026-08-04T11:00:00Z",
  "reason": "Missed GPS complete; contractor confirmed hours"
}
```

---

## 13. Engagement rates & payment batches

### Rates — `/v1/payroll`

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/payroll/engagement-rates/{engagement_id}` | `payments.view` |
| POST | `/v1/payroll/engagement-rates/{engagement_id}` | `payments.manage` |
| PATCH | `/v1/payroll/engagement-rates/{rate_id}` | `payments.manage` |

**Create**

```json
{
  "effective_from": "2026-07-01",
  "effective_to": null,
  "hourly_rate": 45.5,
  "currency_code": "AUD"
}
```

Creating a new rate auto-ends prior open rates for that engagement.

### Batches — `/v1/payment-batches`

| Method | Path | Perm | Notes |
|--------|------|------|-------|
| GET | `/v1/payment-batches?status=draft&limit=100` | `payments.view` | |
| POST | `/v1/payment-batches` | `payments.manage` | Optional `Idempotency-Key` |
| POST | `/v1/payment-batches/{id}/post` | `payments.manage` | Sets visits `paid` |
| POST | `/v1/payment-batches/{id}/void` | `payments.manage` | Allowed after post; resets visits to `unpaid` |

**Create**

```json
{
  "visit_ids": ["vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv"],
  "period_label": "2026-08-01..2026-08-15",
  "currency_code": "AUD"
}
```

Visits must be `completed` and `unpaid`. May mix contractors.

**Response**

```json
{
  "id": "...",
  "tenant_id": "...",
  "status": "draft",
  "period_label": "2026-08-01..2026-08-15",
  "currency_code": "AUD",
  "total_amount": 91.0,
  "created_by_user_id": "...",
  "posted_at": null,
  "created_at": "...",
  "updated_at": "...",
  "lines": [
    {
      "visit_id": "...",
      "contractor_id": "...",
      "hours": 2.0,
      "rate": 45.5,
      "amount": 91.0
    }
  ]
}
```

**Note:** Contractor `payments.view_own` exists, but list batches requires `payments.view`. Until an own-payments endpoint exists, contractors should use `GET /v1/visits?payment_status=paid`.

---

## 14. Branches & tenants

### Branches — `/v1/branches`

Write: `branches.manage`. Read: `auth.session` plus any of `branches.read`, `tenant_members.read`, `visits.read`, `attendance.adjust`, or `platform.admin`.

**Create**

```json
{
  "tenant_id": "22222222-2222-2222-2222-222222222222",
  "name": "Sydney HQ",
  "location": "1 George St",
  "lat": -33.8688,
  "lng": 151.2093,
  "geofence_radius_m": 100
}
```

Point + radius replaces polygon geofence zones.

### Tenants — `/v1/tenants`

| Method | Path | Perm |
|--------|------|------|
| POST/GET/DELETE | `/v1/tenants` / `/{id}` | mostly `platform.admin` |
| GET/PATCH | `/v1/tenants/{tenant_id}` | own tenant: `tenants.read` / `tenants.manage` |

---

## 15. Notifications

| Method | Path | Perm |
|--------|------|------|
| POST | `/v1/notifications/devices` | `auth.session` |
| DELETE | `/v1/notifications/devices/{token}` | `auth.session` |
| GET | `/v1/notifications/events?limit=100` | `notifications.receive` |
| GET | `/v1/notifications/settings` | `notifications.manage` |

**Register device**

```json
{
  "token": "fcm-or-apns-device-token-min-16-chars",
  "platform": "android"
}
```

`platform`: `android` | `ios` | `web`.

**Event types (payload examples)**

| `event_type` | Typical payload keys |
|--------------|----------------------|
| `engagement.invited` | engagement / contractor ids |
| `visit.assigned` | `visit_id`, `job_title`, `client_name?` |
| `visit.checked_in` | `visit_id`, `job_title`, `checked_in_at?` |
| `visit.completed` | `visit_id`, `job_title`, `completed_at?` |
| `client.invite` | `invite_url`, `client_name`, contacts (stub email/sms) |

Email/SMS for client events are **stubbed** (persisted, not sent). Do not build a delivery-log UI for V1 unless product asks.

---

## 16. Subscriptions (tenant billing)

> **Flutter:** **Out of scope.** Checkout / plans / cancel live on the **landing page**. Do not add subscription screens to admin or contractor shells. Flutter may read the lightweight `subscription` object on login/refresh and show a blocking/banner state on `subscription_expired` that points users to the website.

Mounted under `/v1/subscription` (and GoCardless webhook). Use for SaaS billing UI on the landing page, not workforce Flutter.

| Method | Path | Perm |
|--------|------|------|
| GET | `/v1/subscription` | `subscription.view` |
| GET | `/v1/subscription/plans` | `subscription.view` |
| POST | `/v1/subscription/checkout` | `subscription.manage` |
| GET | `/v1/subscription/checkout/status` | `subscription.view` |
| POST | `/v1/subscription/cancel` | `subscription.manage` |

Mutating workforce endpoints often require an **active** subscription; expired → **403** `{ "code": "subscription_expired", "message": "..." }`.

Login/refresh already embed a lightweight `subscription` object.

---

## 17. Recommended client wiring order

### Contractor app shell (Flutter)

1. `POST /contractors/register` (first time) → `POST /auth/login`
2. If `must_change_password` → `complete_first_login` → login again
3. Store access + refresh; read `actor_type`, `engagements`, `permissions`
4. Multi-tenant → `switch-tenant` or pick from engagements
5. `GET /contractor-me/engagements` · upload docs while `pending_docs`
6. `GET /contractor-me/timetable` · `GET /visits`
7. Check-in → tasks/forms → complete
8. Register `POST /notifications/devices`

### Tenant admin shell (Flutter)

1. **Login** as member (tenant already created on **landing page** via `POST /v1/public/register` — not in Flutter)
2. Staff: `/tenant-members` · Branches · Clients/sites/contacts
3. Invite contractor → approve/activate engagement → set rates
4. Jobs + form catalog + recurrence generate / manual visits
5. Adjustments if needed · payment batches · post/void

Billing / subscription renewals: landing page only.

---

## 18. Common HTTP errors

| HTTP | `detail` / body | Meaning |
|------|-----------------|---------|
| 401 | Invalid credentials / refresh | Re-login |
| 403 | `wrong_actor_type` | Wrong shell (contractor vs member) |
| 403 | `must_change_password` | Force password screen |
| 403 | Missing permission | Hide UI / show upgrade |
| 403 | `subscription_expired` | Banner / block mutating ops — renew on **landing page** (no Flutter checkout) |
| 400 | `geofence_rejected` | Move closer or admin relax mode |
| 400 | `required_forms_incomplete` / `docs_incomplete` | Finish forms/docs |
| 409 | `visit_overlap` / `standing_job_exists` / `invalid_visit_status` / `engagement_not_active` | Conflict UX |
| 409 | `payment_already_paid` / `visit_already_in_batch` | Payments |
| 404 | `visit_not_found` / `contractor_not_found` | |

Non-public APIs: `{ "detail": "..." }` or structured detail.  
Public APIs: `{ "message": "..." }`.

### Idempotency

Optional header on check-in, complete, generate, payment-batch create/post:

```http
Idempotency-Key: my-key-8-to-128-chars
```

Pattern: `[A-Za-z0-9_-]{8,128}`.

---

## 19. Endpoint index (mounted V2)

| Area | Prefix |
|------|--------|
| Auth / users | `/v1/auth/*`, `/v1/me` |
| Public | `/v1/public/*` |
| Contractors | `/v1/contractors/register`, `/v1/contractor-me` |
| Engagements | `/v1/tenants/current/engagements`, `/v1/engagements/{id}/*`, `/v1/contractor-me/engagements` |
| Tenant members | `/v1/tenant-members` |
| Clients | `/v1/clients` |
| Forms | `/v1/form-templates` |
| Jobs / visits | `/v1/jobs`, `/v1/visits` |
| Schedule | `/v1/contractor-me/timetable\|availability\|leave` |
| Documents | `/v1/documents` |
| Attendance | `/v1/attendance/adjustments` |
| Rates | `/v1/payroll/engagement-rates` |
| Payments | `/v1/payment-batches` |
| Notifications | `/v1/notifications` |
| Branches / tenants | `/v1/branches`, `/v1/tenants` |
| Subscription | `/v1/subscription` |

For field-level OpenAPI schemas and try-it-out, use **`/docs`** against your environment.

---

*Generated from the contractor-era backend after `db8a2d5` (migrations V001–V009 + mounted FastAPI modules). Prefer live `/openapi.json` if a field drifts.*
