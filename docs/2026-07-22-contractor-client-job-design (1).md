# Contractor / Client / Job Domain — Detailed Design Spec

**Date:** 2026-07-22  
**Status:** Ready for user review  
**Audience:** Implementers (including less powerful coding agents)  
**Scope:** `timesheet-db` migrations + `timesheet-backend` APIs/workflows  
**Companion:** [2026-07-22-contractor-client-job-approaches.md](./2026-07-22-contractor-client-job-approaches.md)  
**Back-compat:** Not required. Prefer clear breaks over dual-running old employee clocking.

---

## 0. How to use this document

1. Implement **data model first** (migrations), then **permissions seed**, then **modules** in the order in §16.  
2. Do **not** invent tables or endpoints not listed here without updating this spec.  
3. Every `SECURITY` note is mandatory. Every `EFFICIENCY` note is the preferred implementation.  
4. Pseudo-SQL and status lists are normative. Column types may use PostgreSQL idioms already used in this repo (`uuid`, `timestamptz`, `geography(Point,4326)`, `jsonb`).  
5. Backend pattern: FastAPI modular monolith, **asyncpg + raw SQL**, Pydantic v2 schemas — **no SQLAlchemy**. Follow existing module layout: `router.py` / `schemas.py` / `service.py`.

---

## 1. Goals and non-goals

### 1.1 Goals (V1)

- Service-provider **tenants** with **tenant_members** (admin staff only).  
- Global **contractors** who engage with many tenants.  
- Tenant-owned **clients** (artifacts, no login) with sites, contacts, docs, token consent.  
- **Jobs → Visits → Tasks**, one contractor per visit, concurrent visits allowed.  
- Visit GPS check-in/out; time entries require a visit.  
- Documents in **GCS**; contractor-owned profile docs with engagement consent.  
- Visit-based **payments** (no payroll periods).  
- SaaS billing via **billing_accounts** (tenant payer only).  
- Email/SMS **stubbed** (persist intent; do not send).

### 1.2 Non-goals (V1)

- Client accounts, client approval/reject, client uploads.  
- Shared global clients across tenants.  
- Contractor organizations / dispatch.  
- Same user as both `tenant_member` and `contractor`.  
- Employee PIN kiosk; free-floating time entries; payroll periods.  
- Real email/SMS providers; frontend/UX work.  
- Cross-tenant hard-block of overlapping visits (same contractor across tenants).

---

## 2. Glossary

| Term | Meaning |
|------|---------|
| **Tenant** | Paying service-provider company (`app.tenants`). |
| **Tenant member** | Admin/staff user of a tenant. Does not clock in. |
| **Contractor** | Global person profile; works via engagements. |
| **Engagement** | Link tenant ↔ contractor with lifecycle status. |
| **Client** | Tenant-owned service recipient record (not a user). |
| **Job** | Work container owned by tenant. `standing` or `ad_hoc`. |
| **Standing job** | At most one **open** standing job per client; holds recurrence rules + form catalog. |
| **Visit** | One scheduled work occurrence: **exactly one** `contractor_id`, task list, optional form requirements, location, time window. |
| **Task** | Checklist item on a visit. |
| **Visit recurrence rule** | RRULE on a standing job that generates visits (contractor + tasks + forms). |
| **Contractor schedule** | Availability windows + leave only; does **not** create visits. |
| **Billing account** | Payer record; V1 always `owner_type='tenant'`. |

---

## 3. Architecture overview

```text
auth.users
  ├── app.tenant_members     (staff; tenant-scoped)
  └── app.contractors        (global profile)

app.tenants
  ├── branches (+ radius geofence)
  ├── tenant_members
  ├── clients → sites, contacts, documents, invite tokens
  ├── form_templates (tenant-level and/or client-level)
  ├── contractor_engagements → rates, required doc categories, consent
  ├── jobs → job_form_catalog, visit_recurrence_rules, visits
  ├── visits → tasks, form_requirements, submissions, time_entry, payments
  └── billing_accounts → tenant_subscriptions

GCS bucket (one): object keys prefixed for audit
Notification pipeline: existing events + stub email/sms channel
```

### 3.1 Request context rules

| Actor | JWT `tenant_id` | Notes |
|-------|-----------------|-------|
| Tenant member | Required; their tenant | Standard today. |
| Contractor (most APIs) | Required; selected engagement’s tenant | Must switch tenant to operate in another. |
| Contractor schedule/timetable APIs | May be omitted or ignored | Resolve contractor from `sub`; aggregate across **active/approved** engagements. |
| Platform admin | Optional / any | Existing `platform.admin` behavior. |
| Public client token | No JWT | Token in path/query; rate-limit strictly. |

**SECURITY:** Never trust `tenant_id` from the request body for authorization. Use JWT claim (or engagement lookup for cross-tenant schedule APIs). For contractor tenant-scoped APIs, verify an engagement exists for `(contractor_id, jwt.tenant_id)` in allowed statuses before mutating.

**EFFICIENCY:** Cache resolved `contractor_id` / `tenant_member_id` from `auth.users.id` once per request (dependency), not per query.

---

## 4. Identity model

### 4.1 Hard split (V1)

A given `auth.users.id` MUST NOT appear in both `tenant_members` and `contractors`.

Enforce in application on create/link:

```text
IF user has tenant_members row OR contractors row of the other type → 409 conflict
```

Optional DB support: no single constraint spans both tables; application check is required. Add integration test.

### 4.2 `app.tenant_members`

Replaces admin use of `app.employees`.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL FK → tenants | ON DELETE CASCADE |
| `user_id` | uuid NOT NULL FK → auth.users | ON DELETE RESTRICT |
| `full_name` | text NOT NULL | |
| `email` | text | |
| `phone` | text | |
| `is_active` | boolean NOT NULL DEFAULT true | |
| `created_at` / `updated_at` | timestamptz | |

**Constraints:** `UNIQUE (tenant_id, user_id)`; optional unique phone/email per tenant if desired (match prior employee uniqueness where useful).  
**No** `employee_code`, PIN, rates, schedules, or time entries on this table.

### 4.3 `app.contractors`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `user_id` | uuid NOT NULL UNIQUE FK → auth.users | |
| `full_name` | text NOT NULL | |
| `email` | text | denormalized from user ok |
| `phone` | text | |
| `dob` | date | nullable |
| `metadata` | jsonb NOT NULL DEFAULT `{}` | industry extensions |
| `created_at` / `updated_at` | timestamptz | |

Contractors own their account; tenants cannot delete the contractor row. Tenants only end/suspend **engagements**.

### 4.4 Login and tenant switch

1. Login with email/phone + password (existing).  
2. If user is contractor: list engagements (id, tenant_id, tenant_name, status).  
3. Issue JWT with `sub`, `tenant_id` (selected), `permissions` (global contractor perms + any tenant-scoped grants), claim `actor_type=contractor` and `contractor_id`.  
4. **Switch tenant:** `POST /v1/auth/switch-tenant` `{ tenant_id }` → new access/refresh tokens if engagement allows access (`active`, and read-only rules for `ended`/`suspended` as in §7).  
5. If user is tenant_member: issue JWT with `actor_type=tenant_member`, `tenant_member_id`, `tenant_id`.

**SECURITY:** Refresh tokens remain bound to `tenant_id` for tenant-scoped sessions. Switching tenant rotates refresh token and revokes the old one. Cross-tenant schedule endpoints must re-verify `sub` → contractor and ignore forged tenant lists.

---

## 5. Engagements

### 5.1 `app.contractor_engagements`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `contractor_id` | uuid NOT NULL | |
| `status` | text NOT NULL | see machine |
| `consented_at` | timestamptz | set on accept |
| `consent_revoked_at` | timestamptz | set on `ended` |
| `invited_by_user_id` | uuid | |
| `approved_by_user_id` | uuid | |
| `created_at` / `updated_at` | timestamptz | |

**Constraints:** `UNIQUE (tenant_id, contractor_id)` (one engagement row per pair; status moves on same row).  
**Indexes:** `(tenant_id, status)`, `(contractor_id, status)`.

### 5.2 Status machine

**Normative statuses:** `invited | pending_docs | approved | active | suspended | ended`.

```text
invited → pending_docs → approved → active ⇄ suspended → ended
```

| Status | Meaning | Allowed actions |
|--------|---------|-----------------|
| `invited` | Tenant invited; contractor has not accepted | Contractor accept → `pending_docs`; tenant cancel → `ended` |
| `pending_docs` | Accepted; waiting for required doc categories | Contractor uploads docs; tenant may `approve` only when docs present |
| `approved` | Docs gate passed; not yet assignable | Tenant `activate` → `active`; tenant may `end` |
| `active` | Can be assigned visits; may check in | Tenant `suspend` → `suspended`; tenant `end` → `ended` |
| `suspended` | **Freeze** | No new visit assignment; no new check-in; **check-out allowed** if open time entry; tenant `resume` → `active` or `end` → `ended` |
| `ended` | Terminal | Consent revoked; cannot assign; read rules in §7 |

Transition `pending_docs → approved` requires:

1. Every **required** category in `engagement_required_doc_categories` has at least one contractor document with that `category` and `scan_status IN ('pending','clean')` (**blocked** does not count).  
2. Actor is tenant member with `contractors.approve`.

Optional convenience API: `POST .../approve-and-activate` performs `pending_docs → approved → active` in one transaction when docs pass the gate.

### 5.3 Required doc categories

`app.engagement_required_doc_categories`

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `engagement_id` | uuid NOT NULL |
| `category` | text NOT NULL |
| `is_required` | boolean NOT NULL DEFAULT true |

`UNIQUE (engagement_id, category)`.

Tenant configures on invite or while `pending_docs`. Categories examples: `passport_id`, `drivers_licence`, `trade_certificate`, `insurance`, `wwcc`, `police_check`, `other`.

### 5.4 Consent

- On contractor accept: set `consented_at=now()`, clear `consent_revoked_at`.  
- Blanket share: while consent active, tenant members with `contractors.docs.read` may read contractor profile documents.  
- On `ended`: set `consent_revoked_at=now()`. Profile doc access for that tenant stops.  
- On `suspended`: consent remains; profile docs still readable by tenant; work frozen.

---

## 6. Clients (artifacts)

### 6.1 `app.clients`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `full_name` | text NOT NULL | |
| `status` | text NOT NULL DEFAULT `active` | `active\|inactive` |
| `email` / `phone` | text | optional primary |
| `service_agreement_notes` | text | optional |
| `metadata` | jsonb NOT NULL DEFAULT `{}` | industry extensions |
| `created_at` / `updated_at` | timestamptz | |

### 6.2 `app.client_sites`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | denormalized for RLS-style filters |
| `client_id` | uuid NOT NULL | |
| `name` | text NOT NULL | |
| `address_line1`, `city`, `state`, `country`, `postal_code` | text | |
| `location_geog` | geography(Point,4326) | from geocode/pin |
| `geofence_radius_m` | integer NOT NULL DEFAULT 100 | |
| `is_primary` | boolean NOT NULL DEFAULT false | |
| `created_at` / `updated_at` | timestamptz | |

**Index:** GiST on `location_geog`.

### 6.3 `app.client_contacts`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `client_id` | uuid NOT NULL | |
| `name` | text | |
| `email` | text | |
| `phone` | text | |
| `is_primary` | boolean NOT NULL DEFAULT false | display only |
| `notify_visit_complete` | boolean NOT NULL DEFAULT true | |

At least one of email/phone required at API validation.

### 6.4 Client documents

Store via unified `app.documents` with `owner_type='client'`, `owner_id=client_id`, `tenant_id` set. Uploaded **only** by tenant members.

### 6.5 Client invite tokens

`app.client_invite_tokens`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `client_id` | uuid NOT NULL | |
| `token_hash` | text NOT NULL UNIQUE | store hash only |
| `expires_at` | timestamptz NOT NULL | e.g. 72h |
| `consumed_at` | timestamptz | single-use |
| `created_by_user_id` | uuid | |

Public endpoints:

- `GET /v1/public/client-invites/{token}` — show client summary (minimal PII).  
- `POST /v1/public/client-invites/{token}/acknowledge` — body: accept consent flag; sets acknowledgment on client (`metadata.consent_acknowledged_at` or dedicated column `consent_acknowledged_at`).

**SECURITY:**

- Store only `sha256(token)`; return raw token once on create.  
- Rate-limit by IP + token prefix.  
- Do not expose other clients, documents download URLs, or contractor data on public routes.  
- On consume, set `consumed_at`; reject reuse.  
- Short TTL mandatory.

**EFFICIENCY:** Lookup by `token_hash` unique index only.

---

## 7. Documents and GCS

### 7.1 `app.documents`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid | NULL for pure contractor-global docs; set for client/job/visit docs |
| `owner_type` | text NOT NULL | `contractor` \| `client` \| `job` \| `visit` \| `form_submission` |
| `owner_id` | uuid NOT NULL | |
| `category` | text | required for contractor profile docs |
| `filename` | text NOT NULL | |
| `content_type` | text NOT NULL | allowlist |
| `size_bytes` | bigint NOT NULL | |
| `gcs_bucket` | text NOT NULL | |
| `gcs_object_key` | text NOT NULL UNIQUE | |
| `scan_status` | text NOT NULL DEFAULT `pending` | `pending\|clean\|blocked` |
| `verification_status` | text | nullable; `unverified\|verified\|rejected` optional V1 |
| `verified_by_user_id` | uuid | nullable |
| `uploaded_by_user_id` | uuid NOT NULL | |
| `created_at` | timestamptz | |

**Indexes:** `(owner_type, owner_id)`, `(tenant_id, created_at DESC)`, contractor category lookup via owner.

### 7.2 GCS key layout (audit-friendly)

```text
contractors/{contractor_id}/docs/{document_id}/{safe_filename}
tenants/{tenant_id}/clients/{client_id}/docs/{document_id}/{safe_filename}
tenants/{tenant_id}/jobs/{job_id}/docs/{document_id}/{safe_filename}
tenants/{tenant_id}/visits/{visit_id}/docs/{document_id}/{safe_filename}
tenants/{tenant_id}/form_submissions/{submission_id}/{document_id}/{safe_filename}
```

**SECURITY:**

- Uploads via **signed URL** (PUT) or backend streaming with authz check first; never make bucket public.  
- Downloads via short-lived signed GET after authz.  
- Content-type allowlist: `application/pdf`, `image/jpeg`, `image/png`, `image/webp`, common office types if needed; reject executables.  
- Max size e.g. 20 MiB (config).  
- After upload complete callback: enqueue virus scan; set `scan_status`. Block download of `blocked`. Allow download of `pending` only to uploader + tenant admins (configurable); **V1:** tenant and owner may read `pending`; nobody except platform may read `blocked` payload.  
- Sanitize filenames; do not use user filename alone as object key final segment without `document_id`.

**EFFICIENCY:** Direct-to-GCS signed upload avoids backend bandwidth. Persist metadata in one transaction after client confirms upload (or use resumable upload + finalize endpoint).

### 7.3 Access control matrix (normative)

| Document owner | Who can read | Who can write |
|----------------|--------------|---------------|
| Contractor profile | Owner always; tenant members if engagement consent active (`consented_at` set, `consent_revoked_at` null) and perm `contractors.docs.read` | Contractor only |
| Client | Tenant members with `clients.docs.manage` / `read` | Tenant members only |
| Job / visit / form_submission | Tenant members with jobs perms; contractor if they are/were the visit assignee on that visit/job (**read** after engagement ended still allowed for those visit/job docs) | Create: assignee contractor or tenant member while engagement `active` and visit not locked; after `ended` engagement contractor **read-only** |

**SECURITY:** For contractor read of job/visit docs after `ended`, authorize by historical assignment (`visits.contractor_id = me` OR existence of time_entry), NOT by engagement consent.

---

## 8. Form templates

### 8.1 `app.form_templates`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `client_id` | uuid NULL | NULL = **tenant-level** template; non-null = client-specific |
| `name` | text NOT NULL | |
| `schema_json` | jsonb NOT NULL | see format below |
| `is_active` | boolean NOT NULL DEFAULT true | |
| `created_at` / `updated_at` | timestamptz | |

### 8.2 Schema format (V1)

Use a **custom field list** (simpler than full JSON Schema):

```json
{
  "fields": [
    { "id": "notes", "type": "text", "label": "Progress notes", "required": true },
    { "id": "incident", "type": "textarea", "label": "Incident details", "required": false },
    { "id": "photo", "type": "file", "label": "Photo", "required": false, "accept": ["image/jpeg", "image/png"] },
    { "id": "severity", "type": "boolean", "label": "Client appeared well", "required": true }
  ]
}
```

Supported `type`: `text`, `textarea`, `boolean`, `number`, `date`, `file`.

### 8.3 Job catalog and visit selection

`app.job_form_catalog`

| Column | Type |
|--------|------|
| `job_id` | uuid NOT NULL |
| `form_template_id` | uuid NOT NULL |
| PK | `(job_id, form_template_id)` |

Templates added to catalog must belong to same tenant and (`client_id` IS NULL OR `client_id` = job.client_id).

`app.visit_form_requirements`

| Column | Type |
|--------|------|
| `visit_id` | uuid NOT NULL |
| `form_template_id` | uuid NOT NULL |
| `is_required` | boolean NOT NULL |
| PK | `(visit_id, form_template_id)` |

Every `form_template_id` on a visit MUST exist in that visit’s job catalog.

`app.form_submissions`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `visit_id` | uuid NOT NULL | |
| `form_template_id` | uuid NOT NULL | |
| `submitted_by_user_id` | uuid NOT NULL | |
| `payload_json` | jsonb NOT NULL | field id → value (file fields store `document_id`) |
| `created_at` / `updated_at` | timestamptz | |

**UNIQUE (visit_id, form_template_id)** — one submission per template per visit (upsert allowed).

**Complete visit gate:** for each `visit_form_requirements` where `is_required`, a submission must exist; any file `document_id` referenced must have `scan_status != 'blocked'`.

---

## 9. Jobs, visits, tasks

### 9.1 `app.jobs`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `client_id` | uuid NULL | required if `kind='standing'` |
| `kind` | text NOT NULL | `standing` \| `ad_hoc` |
| `status` | text NOT NULL DEFAULT `open` | `open\|closed\|cancelled` |
| `title` | text NOT NULL | |
| `branch_id` | uuid NULL | XOR location target with site |
| `client_site_id` | uuid NULL | |
| `location_geog` | geography(Point,4326) | resolved center |
| `geofence_radius_m` | integer NOT NULL | |
| `geofence_mode` | text NOT NULL DEFAULT `informational` | `informational` \| `enforce` |
| `created_at` / `updated_at` | timestamptz | |

**Constraints:**

- CHECK: exactly one of (`branch_id`, `client_site_id`) is non-null **OR** both null only if `location_geog` set explicitly (prefer requiring one of branch/site). **Normative:** require `branch_id IS NOT NULL XOR client_site_id IS NOT NULL` for V1 clarity; copy geog/radius from branch or site on create (overridable).  
- Partial unique: **at most one** job where `kind='standing' AND status='open'` per `client_id`.  
- Standing jobs require `client_id IS NOT NULL`.

**Defaults:** Tenant setting `tenants.default_geofence_mode` (add column, default `informational`) copied to job unless overridden.

### 9.2 Branches geofence (radius model)

Replace polygon-centric branch zones for punch/job use with radius fields on `app.branches` (or keep `geofence_zones` but change shape):

**Normative V1:** add to `app.branches`:

| Column | Type |
|--------|------|
| `location_geog` | geography(Point,4326) NULL |
| `geofence_radius_m` | integer NULL |

Deprecate polygon `geofence_zones` for new visit check-in path. Migration may drop or leave unused; **do not** require polygons for new features.

### 9.3 `app.visit_recurrence_rules`

Attached to **standing** jobs only.

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `job_id` | uuid NOT NULL | standing job |
| `contractor_id` | uuid NOT NULL | must have `active` engagement |
| `rrule` | text NOT NULL | iCal RRULE string, e.g. `FREQ=WEEKLY;BYDAY=MO,WE` |
| `dtstart` | timestamptz NOT NULL | first occurrence anchor (timezone = tenant tz) |
| `until` | timestamptz NULL | |
| `duration_minutes` | integer NOT NULL | |
| `task_template_json` | jsonb NOT NULL | list of `{title, sort_order}` |
| `form_requirements_json` | jsonb NOT NULL | list of `{form_template_id, is_required}` |
| `location_override_geog` | geography(Point,4326) NULL | |
| `geofence_radius_m_override` | integer NULL | |
| `is_active` | boolean NOT NULL DEFAULT true | |
| `created_at` / `updated_at` | timestamptz | |

**Generate visits:** `POST /v1/jobs/{id}/recurrence/{rule_id}/generate` with `{ from, to }` window.

Algorithm:

1. Expand RRULE occurrences in `[from, to]` in tenant timezone.  
2. For each occurrence start `s`, end `s+duration`.  
3. **Hard-block** if contractor has another visit overlapping `[s,end)` in **this tenant** with status not `cancelled`.  
4. Insert visit + tasks + visit_form_requirements.  
5. Skip or error on conflict — **V1: fail the conflicting occurrence with error detail; continue others in same request only if `partial=true`, else abort transaction**. Default `partial=false` (all-or-nothing).

**EFFICIENCY:** Cap generate window (e.g. max 90 days). Use bulk insert for tasks. Index visits `(contractor_id, scheduled_start, scheduled_end)` for overlap queries using range overlap (`tstzrange &&`).

Changing a rule does **not** auto-mutate past visits. `regenerate` endpoint updates only future visits with `status='scheduled'` and `source='recurrence'` if explicitly requested.

### 9.4 `app.visits`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `job_id` | uuid NOT NULL | |
| `contractor_id` | uuid NOT NULL | **exactly one** |
| `scheduled_start` | timestamptz NOT NULL | |
| `scheduled_end` | timestamptz NOT NULL | |
| `status` | text NOT NULL | see machine |
| `source` | text NOT NULL DEFAULT `manual` | `manual` \| `recurrence` |
| `recurrence_rule_id` | uuid NULL | |
| `location_geog` | geography(Point,4326) NOT NULL | default from job |
| `geofence_radius_m` | integer NOT NULL | default from job |
| `geofence_mode` | text NOT NULL | inherit job unless override |
| `payment_status` | text NOT NULL DEFAULT `unpaid` | `unpaid` \| `paid` |
| `completed_at` | timestamptz | |
| `created_at` / `updated_at` | timestamptz | |

**Overlap constraint (same contractor, same tenant):** prevent overlapping scheduled ranges for non-cancelled visits.

Implement with exclusion constraint if possible:

```sql
EXCLUDE USING gist (
  contractor_id WITH =,
  tenant_id WITH =,
  tstzrange(scheduled_start, scheduled_end, '[)') WITH &&
) WHERE (status <> 'cancelled')
```

Requires `btree_gist`. Add migration `CREATE EXTENSION IF NOT EXISTS btree_gist`.

**Cross-tenant overlap:** not enforced in V1.

### 9.5 Visit status machine

```text
scheduled → checked_in → completed
    │            │
    └────────────┴→ cancelled
```

| From | To | Who / rules |
|------|-----|-------------|
| `scheduled` | `checked_in` | Assignee contractor; engagement `active`; GPS rules; creates time_entry |
| `checked_in` | `completed` | Assignee; required forms done; check-out GPS; close time_entry |
| `scheduled`/`checked_in` | `cancelled` | Tenant member with manage perm; if checked_in, force close time_entry with note |
| `checked_in` | `checked_in` | Suspended engagement: still allow check-out path via complete or dedicated check-out then complete |

On check-in notify tenant (event). On complete: stub notify client contacts + tenant.

### 9.6 `app.visit_tasks`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `visit_id` | uuid NOT NULL | |
| `title` | text NOT NULL | |
| `sort_order` | integer NOT NULL DEFAULT 0 | |
| `is_done` | boolean NOT NULL DEFAULT false | |
| `done_at` | timestamptz | |
| `created_at` / `updated_at` | timestamptz | |

Only the visit assignee (or tenant member with manage) may toggle `is_done`. No `completed_by` column.

---

## 10. Attendance (visit check-in/out)

### 10.1 `app.time_entries` (reshaped)

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `visit_id` | uuid NOT NULL UNIQUE | **one entry per visit** |
| `contractor_id` | uuid NOT NULL | denormalized = visit.contractor_id |
| `engagement_id` | uuid NOT NULL | |
| `clock_in_at` | timestamptz NOT NULL | |
| `clock_out_at` | timestamptz | |
| `status` | text NOT NULL | `open` \| `closed` |
| `created_at` / `updated_at` | timestamptz | |

Keep `time_entry_locations` (clock_in/out points + verdict). Keep breaks table keyed by `time_entry_id` if still needed.

Remove `employee_id`. Remove PIN flows from attendance module.

### 10.2 Check-in algorithm

1. Authz: JWT contractor matches `visit.contractor_id`; engagement status `active`.  
2. Visit status `scheduled`.  
3. Evaluate GPS: `ST_DWithin(visit.location_geog, punch_geog, radius_m)`.  
4. If `geofence_mode='enforce'` and outside → **400** reject. If `informational`, store verdict `outside` but allow.  
5. Insert time_entry + location; set visit `checked_in`.

### 10.3 Check-out / complete

1. If engagement `suspended` or `active`, allow if time_entry open.  
2. GPS same as check-in.  
3. Validate required forms.  
4. Close time_entry; set visit `completed`, `completed_at=now()`.  
5. Emit notifications (stub email/sms + in-app).

**SECURITY:** Contractors cannot check in to another contractor’s visit. Tenant members do not use contractor check-in endpoint; use admin adjustment APIs if correcting times.

**EFFICIENCY:** Single transaction for status + time_entry + location. Use `SELECT … FOR UPDATE` on visit row to prevent double check-in races.

---

## 11. Contractor availability schedule (not visit generation)

Retarget scheduling tables from employees → contractors:

- `app.schedule_templates` — keep tenant-scoped named windows (optional).  
- `app.contractor_availability` (rename from employee_schedules conceptually): recurring availability for a contractor **within a tenant engagement** OR global?

**Normative V1:** availability is **per contractor globally** (cross-tenant timetable), leave is **per contractor globally**.

Tables:

`app.contractor_availability_rules` — contractor_id, rrule/windows, timezone  
`app.contractor_leave` — contractor_id, start_date, end_date, leave_type, notes  

Tenant-scoped board for admins: show availability **intersected** with engagement, plus visits for that tenant.

**Cross-tenant APIs (contractor):**

- `GET /v1/contractor-me/timetable?from&to` — merges leave, availability, and visits across all engagements (each visit labeled with `tenant_id`).  
- `GET/PUT /v1/contractor-me/availability`  
- `GET/POST/DELETE /v1/contractor-me/leave`  

**SECURITY:** Timetable must only return visits/engagements for `contractor_id` of `sub`. Never accept `contractor_id` from query for these routes.

**EFFICIENCY:** Parallel queries per tenant are OK for V1 if engagement count is small; prefer one SQL with `WHERE contractor_id=$1 AND scheduled_start/end overlap` plus separate leave query.

Admin tenant scheduling board: list visits + show contractor leave as busy (read global leave).

---

## 12. Rates and payments

### 12.1 `payroll.engagement_rates` (or `app.engagement_rates`)

Prefer schema `payroll` for money:

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `tenant_id` | uuid NOT NULL | |
| `engagement_id` | uuid NOT NULL | |
| `effective_from` | date NOT NULL | |
| `effective_to` | date NULL | |
| `hourly_rate` | numeric NOT NULL | simplify V1 to hourly; drop complex OT bands unless needed |
| `currency_code` | text NOT NULL DEFAULT `AUD` | |

`UNIQUE (engagement_id, effective_from)`.

**Rate for a visit:** rate where `effective_from <= visit.scheduled_start::date` and (`effective_to` is null or `>= that date`), order by `effective_from DESC` limit 1.

### 12.2 Payment batches

`payroll.payment_batches`

| Column | Type |
|--------|------|
| `id` | uuid PK |
| `tenant_id` | uuid NOT NULL |
| `status` | text NOT NULL `draft\|posted\|void` |
| `period_label` | text | optional display e.g. `2026-01-01..2026-01-15` |
| `currency_code` | text NOT NULL |
| `total_amount` | numeric NOT NULL DEFAULT 0 |
| `created_by_user_id` | uuid |
| `posted_at` | timestamptz |
| `created_at` / `updated_at` | timestamptz |

`payroll.payment_batch_visits`

| Column | Type | Notes |
|--------|------|-------|
| `batch_id` | uuid NOT NULL | |
| `visit_id` | uuid NOT NULL | |
| `contractor_id` | uuid NOT NULL | |
| `hours` | numeric NOT NULL | from time_entry |
| `rate` | numeric NOT NULL | snapshot |
| `amount` | numeric NOT NULL | |
| PK | `(batch_id, visit_id)` | |

**Rules:**

- Visit must be `completed` and `payment_status='unpaid'` to add.  
- On batch `posted`: set each visit `payment_status='paid'`; write immutable snapshots.  
- On `void`: set visits back to `unpaid` only if business allows; **V1: void only before payout integration — mark batch void and visits unpaid**.  
- Partial unique: at most one non-void batch membership per visit:

```sql
-- enforce in app + partial unique via visit.payment_status
```

**SECURITY:** Only tenant members with `payments.manage`. Contractors may `payments.view_own` for their paid visits.

**EFFICIENCY:** Compute hours in SQL from time_entries; bulk insert batch lines; one update for visit payment_status.

Remove dependency on `payroll.periods` / `payroll.results` for new flows. Migration may drop those tables in the domain rebuild.

---

## 13. Billing accounts (SaaS)

`app.billing_accounts`

| Column | Type | Notes |
|--------|------|-------|
| `id` | uuid PK | |
| `owner_type` | text NOT NULL | V1 only `tenant` |
| `owner_id` | uuid NOT NULL | tenant_id |
| `created_at` | timestamptz | |

`UNIQUE (owner_type, owner_id)`.

Migrate `tenant_subscriptions.tenant_id` usage: add `billing_account_id` FK; backfill 1:1 account per tenant; keep `tenant_id` denormalized optional or drop after cutover.

Entitlement checks: resolve billing_account from JWT tenant.

---

## 14. Notifications (stub channels)

Reuse `notification_events` / deliveries.

New event types (string constants):

- `engagement.invited`, `engagement.accepted`, `engagement.activated`, `engagement.suspended`, `engagement.ended`  
- `visit.assigned`, `visit.checked_in`, `visit.completed`  
- `client.invite`, `client.visit_completed` (email/sms stub)  
- `docs.required_reminder` (optional)

**Stub email/sms:** `notification_deliveries` row with `channel='email'|'sms'`, `status='stubbed'`, payload includes to/body; **no provider call**.

**SECURITY:** Do not put secrets in payloads. Minimize PII in push bodies.

---

## 15. RBAC

### 15.1 Roles (system templates)

| Role | Actor |
|------|--------|
| `platform_admin` | keep |
| `owner`, `admin`, `supervisor` | tenant_members |
| `contractor` | global (`tenant_id` NULL system role) assigned to contractor users |

Remove workforce meaning of `employee` role (delete or keep unused).

### 15.2 Permission keys (add)

```
tenants.read tenants.manage
tenant_members.read tenant_members.manage
contractors.read contractors.invite contractors.approve contractors.manage
contractors.docs.read
clients.read clients.manage clients.docs.manage
jobs.read jobs.manage
visits.read visits.manage visits.check_in visits.complete
scheduling.read scheduling.manage
attendance.adjust
payments.view payments.manage payments.view_own
documents.upload
billing.view billing.manage
notifications.receive
auth.session
platform.admin
```

Map roughly:

- owner/admin: broad manage  
- supervisor: jobs/visits/clients read+manage, contractors read/invite, payments view  
- contractor: `auth.session`, `visits.check_in`, `visits.complete`, `visits.read` (own), `documents.upload`, `payments.view_own`, `notifications.receive`, plus schedule self-manage permissions e.g. `contractor.schedule.manage`

### 15.3 Enforcement helpers

Implement service-layer helpers:

- `require_tenant_member(conn, user_id, tenant_id)`  
- `require_contractor_engagement(conn, user_id, tenant_id, allowed_statuses)`  
- `assert_visit_assignee(...)`  
- `assert_no_visit_overlap(...)`

Do not rely on permissions alone for row ownership.

---

## 16. API surface (implement these)

Prefix `/v1` unless public.

### 16.1 Auth additions

| Method | Path | Perm | Notes |
|--------|------|------|-------|
| POST | `/auth/switch-tenant` | auth.session | contractor or multi-tenant member |
| GET | `/auth/me/context` | auth.session | actor_type, contractor_id/tenant_member_id, engagements list |

### 16.2 Tenant members

CRUD under `/tenant-members` replacing `/employees` for staff. No PIN endpoints.

### 16.3 Contractors & engagements

| Method | Path | Actor |
|--------|------|-------|
| POST | `/contractors/register` | public or auth | create user+contractor |
| GET/PATCH | `/contractor-me` | contractor | profile |
| POST | `/tenants/current/engagements` | tenant invite | body: email/phone + required categories |
| POST | `/engagements/{id}/accept` | contractor | |
| POST | `/engagements/{id}/approve` | tenant | pending_docs→approved |
| POST | `/engagements/{id}/activate` | tenant | approved→active |
| POST | `/engagements/{id}/approve-and-activate` | tenant | convenience |
| POST | `/engagements/{id}/suspend` | tenant | |
| POST | `/engagements/{id}/resume` | tenant | |
| POST | `/engagements/{id}/end` | tenant | |
| GET | `/tenants/current/engagements` | tenant | |
| GET | `/contractor-me/engagements` | contractor | |

### 16.4 Clients

CRUD `/clients`, `/clients/{id}/sites`, `/contacts`, docs upload, `POST /clients/{id}/invites`.

### 16.5 Forms

CRUD `/form-templates` (filter by client_id null/tenant).

### 16.6 Jobs & visits

| Method | Path | Notes |
|--------|------|-------|
| POST/GET | `/jobs` | |
| POST | `/jobs/{id}/form-catalog` | add templates |
| POST | `/jobs/{id}/recurrence-rules` | standing only |
| POST | `/jobs/{id}/recurrence-rules/{rid}/generate` | |
| POST | `/jobs/{id}/visits` | manual visit |
| GET | `/visits` | tenant filterable |
| GET | `/visits/{id}` | |
| PATCH | `/visits/{id}/tasks/{tid}` | toggle done |
| POST | `/visits/{id}/form-submissions` | |
| POST | `/visits/{id}/check-in` | GPS body |
| POST | `/visits/{id}/complete` | GPS + forms gate |
| POST | `/visits/{id}/cancel` | tenant |

### 16.7 Contractor cross-tenant schedule

| Method | Path |
|--------|------|
| GET | `/contractor-me/timetable` |
| GET/PUT | `/contractor-me/availability` |
| CRUD | `/contractor-me/leave` |

### 16.8 Payments

| Method | Path |
|--------|------|
| GET | `/visits?payment_status=unpaid&from&to` |
| POST | `/payment-batches` | create draft from visit ids |
| POST | `/payment-batches/{id}/post` | |
| POST | `/payment-batches/{id}/void` | |

### 16.9 Documents

| Method | Path |
|--------|------|
| POST | `/documents/upload-url` | returns signed PUT + document id draft |
| POST | `/documents/{id}/finalize` | |
| GET | `/documents/{id}/download-url` | authz |

### 16.10 Public

Client invite acknowledge routes (§6.5). Existing public tenant register adapted to create `tenant_members` + `billing_accounts`.

---

## 17. Module map (backend files)

| New/changed module | Path under `app/modules/` | Responsibility |
|--------------------|---------------------------|----------------|
| Replace employees | `tenant_members/` | Staff CRUD |
| New | `contractors/` | Profile, register, me |
| New | `engagements/` | Lifecycle |
| New | `clients/` | Clients, sites, contacts, invites |
| New | `documents/` | GCS signed URLs, scan stub |
| New | `forms/` | Templates, submissions |
| New | `jobs/` | Jobs, catalog, recurrence, visits, tasks |
| Change | `attendance/` | Visit check-in/out only |
| Change | `scheduling/` | Admin view of visits + contractor leave; generation stays in jobs |
| Change | `payroll/` or `payments/` | Engagement rates + payment batches |
| Change | `subscriptions/` | billing_accounts |
| Change | `auth/`, `rbac/` | switch-tenant, actor claims, perms |
| Change | `geofence/` | Radius helpers; branch point+radius |
| Change | `notifications/` | New events + stub channel |
| Change | `public/` | Client invite + register |

Mount routers in `app/api/v1/routes.py`.

---

## 18. Migration strategy

1. Move current `migrations/V001__baseline.sql` to `migrations/archive/` (keep for comparison).  
2. Add new baseline or ordered rebuild:  
   - `V001__archive_note.md` or keep archive only  
   - `V002__domain_restructure.sql` — drop/replace app workforce tables; create new tables; alter branches; billing_accounts; reshape time_entries; drop payroll periods/results or leave unused.  
3. Update `seed/001_dev_seed.sql` permissions/roles.  
4. Do **not** write data backfill for old employees→contractors (back-compat not required). Fresh DB expected for V1 of this domain.

**EFFICIENCY:** One transactional migration where possible; create indexes concurrently only if online prod requires (dev can be blocking).

---

## 19. Validation and error catalog (use consistently)

| Code/detail | HTTP | When |
|-------------|------|------|
| `missing_permission` | 403 | RBAC |
| `wrong_actor_type` | 403 | contractor hitting member-only route |
| `engagement_inactive` | 403 | assignment/check-in |
| `visit_overlap` | 409 | same contractor overlapping visit |
| `geofence_rejected` | 400 | enforce mode outside |
| `forms_incomplete` | 400 | complete blocked |
| `scan_blocked` | 400 | required file blocked |
| `payment_already_paid` | 409 | add to batch |
| `standing_job_exists` | 409 | second open standing job |
| `hard_split_violation` | 409 | member∩contractor |
| `invite_token_invalid` | 404/410 | public invite |

---

## 20. Security checklist (global)

1. Authorize every row by tenant and/or ownership; never IDOR via UUID guessing.  
2. Hash invite tokens; single-use; TTL.  
3. Signed GCS URLs; private bucket; content allowlist; size caps; virus scan status.  
4. Separate ACLs for profile docs (consent) vs job docs (assignee history).  
5. Rate-limit public and login endpoints.  
6. Audit: write `domain_audit_events` for engagement transitions, visit complete, payment post, doc verify.  
7. Refresh token rotation on tenant switch.  
8. Do not log GPS precision beyond need; still store for compliance.  
9. Stub notifications must not call external providers accidentally (feature flag `EMAIL_SMS_STUB=true` default).  
10. SQL: parameterized queries only (asyncpg `$1` style).

---

## 21. Efficiency checklist (global)

1. Indexes: engagement `(contractor_id,status)`, visits overlap gist, documents `(owner_type,owner_id)`, unpaid visits `(tenant_id, payment_status, scheduled_start)`.  
2. `SELECT FOR UPDATE` on visit check-in.  
3. Bulk generate visits with capped window.  
4. Signed GCS uploads.  
5. Denormalize `tenant_id` on child tables for simple filtering (match existing style).  
6. Avoid N+1: list visits with tasks via SQL aggregation or two-query pattern (`visits` then `tasks WHERE visit_id = ANY(...)`).  
7. Cross-tenant timetable: one visits query by `contractor_id` + date range.  
8. Payment batch: single transaction compute+insert+update.

---

## 22. Testing requirements (minimum)

1. Engagement happy path invite→accept→docs→active.  
2. Suspend freezes check-in; allows check-out.  
3. Visit overlap hard-block same tenant.  
4. Concurrent visits different contractors same time OK.  
5. Geofence enforce vs informational.  
6. Complete blocked without required form.  
7. Consent revoke hides profile docs; assignee can still read own past visit docs.  
8. Payment batch posts and sets paid; double-pay blocked.  
9. Standing job uniqueness per client.  
10. Hard split member/contractor.  
11. Client invite token reuse rejected.  
12. Contractor timetable returns multi-tenant visits.  
13. Switch-tenant issues new JWT bound to engagement.

---

## 23. Explicit removal list (do not reimplement)

- `employees` workforce clocking, `employee_code`, PIN verify/set for punch  
- Time entry without `visit_id`  
- Payroll periods calculate/close  
- Client approval workflows  
- Job-level multi assignee table  
- Polygon-only geofence as the check-in mechanism  
- Real SMTP/SMS providers in V1  

---

## 24. Implementation order (for agents)

1. Archive baseline; write `V002` schema for all tables above.  
2. Seed permissions/roles.  
3. Auth claims + switch-tenant + hard-split checks.  
4. `tenant_members` module; adapt public register + billing_accounts.  
5. `contractors` + `engagements` + documents upload for profile.  
6. `clients` + invites + client docs.  
7. `form_templates` + job catalog.  
8. `jobs` + visits + tasks + recurrence generate.  
9. Attendance check-in/complete + geofence radius.  
10. Contractor availability/leave/timetable (cross-tenant).  
11. Engagement rates + payment batches.  
12. Notifications stub events.  
13. Delete/disable obsolete employee attendance/payroll period endpoints.  
14. Update RBAC docs under `backend/docs/`.

---

## 25. Open items intentionally deferred (do not block V1)

- Contractor organizations  
- Dual-hat users  
- Shared clients  
- Real email/SMS  
- Cross-tenant visit overlap detection  
- Rich OT/weekend rate bands (start with single hourly rate)  
- Client as paying customer  

---

## 26. Spec self-review notes

- Engagement statuses match locked lifecycle: `invited|pending_docs|approved|active|suspended|ended`.  
- Visit assignee is singular; forms selected per visit; catalog on job.  
- Branch and visit geofence both radius-based.  
- Schedule ≠ visit generation; timetable APIs are cross-tenant for contractors.  
- Payments ≠ periods.  
- No TBD/optional forks left for V1 implementers except deferred §25 items.  
- Security and efficiency notes embedded in relevant sections and summarized in §20–21.
