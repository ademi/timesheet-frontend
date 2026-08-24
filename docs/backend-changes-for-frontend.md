# Backend Changes Summary for Frontend Integration

**Repository:** [ademi/timesheet](https://github.com/ademi/timesheet)  
**Commit range:** `7473a765` → `a90c6893` (HEAD as of 2026-08-23)  
**Audience:** Flutter / mobile / web frontend teams integrating against the FastAPI backend

This document summarizes **user-facing and API-facing changes** added after commit `7473a765` ("address github action issue"). It focuses on what the frontend must implement or adapt to — not internal test refactors.

---

## Table of contents

1. [Executive summary](#executive-summary)
2. [Database migrations (required)](#database-migrations-required)
3. [New RBAC permissions](#new-rbac-permissions)
4. [NDIS support items on jobs, visits, and tasks](#ndis-support-items-on-jobs-visits-and-tasks)
5. [NDIS Support Catalogue (reference data + search)](#ndis-support-catalogue-reference-data--search)
6. [Invoice export / billing (NDIS plan-manager CSV)](#invoice-export--billing-ndis-plan-manager-csv)
7. [MMM price tiers (remote / very remote pricing)](#mmm-price-tiers-remote--very-remote-pricing)
8. [Engagement ID on visits and shift assignments](#engagement-id-on-visits-and-shift-assignments)
9. [Legal version validation on contractor registration](#legal-version-validation-on-contractor-registration)
10. [Minor / infrastructure changes](#minor--infrastructure-changes)
11. [API quick reference](#api-quick-reference)
12. [Error codes to handle in UI](#error-codes-to-handle-in-ui)
13. [Suggested frontend work checklist](#suggested-frontend-work-checklist)

---

## Executive summary

Since `7473a765`, the backend gained a full **NDIS billing pipeline**:

| Area | What changed |
|------|----------------|
| **Support items** | Jobs, visits, and visit tasks can carry NDIS support item codes/names; validated against an imported catalogue |
| **Catalogue** | Staff can search items; platform admins can import NDIA XLSX releases |
| **Invoice export** | Staff export completed visits as NDIS invoice CSV for plan managers |
| **Pricing tiers** | Unit prices use national / remote / very_remote based on MMM postcode or staff override |
| **Multi-line billing** | Visits with task-level support items export one CSV line per task |
| **Engagements** | Visits and shift assignments now expose `engagement_id` |
| **Registration** | Contractor signup rejects unknown legal document versions |

---

## Database migrations (required)

Apply migrations **V024–V031** before testing new features locally or in staging:

| Migration | Purpose |
|-----------|---------|
| `V024__tenant_composite_fks_and_visit_engagement.sql` | Composite tenant FKs; `engagement_id` on visits & shift assignments |
| `V025__fix_composite_fk_set_null.sql` | FK constraint fixes |
| `V026__contractor_invite_email_lower.sql` | Invite emails must be lowercase at DB level |
| `V027__visit_support_item.sql` | `support_item_code` / `support_item_name` on jobs & visits |
| `V028__ndis_catalogue.sql` | Catalogue reference tables; `support_item_code` on visit tasks |
| `V029__invoice_export.sql` | Billing export tables; `invoice_status` on visits |
| `V030__mmm_postcodes.sql` | MMM postcode → tier reference data |
| `V031__invoice_export_phase_c.sql` | `price_tier_override`, `billable_minutes`, void support |

**Reference data:** An active NDIS catalogue release and MMM postcode data must exist in the environment before support-item validation and invoice export will succeed. Platform ops import these (see [Catalogue import](#ndis-support-catalogue-reference-data--search)).

---

## New RBAC permissions

| Permission | Used for |
|------------|----------|
| `billing.view` | List/get invoice exports, download CSV |
| `billing.manage` | Create and void invoice exports |
| `platform.admin` | Import NDIS catalogue (platform route only) |

Existing permissions still apply:

- `jobs.manage` — patch job support item, manage visits/tasks
- `visits.manage` — patch visit support item, price tier, task billing
- `jobs.read` / `visits.read` — read job/visit DTOs with new fields

Catalogue search accepts **`jobs.manage` OR `billing.view`**.

---

## NDIS support items on jobs, visits, and tasks

### Concept

- **Job default:** Optional default NDIS line item for all visits on that job.
- **Visit stamp:** Copied from job default when a visit is created (recurrence, manual, assign, claim). Can be overridden per visit while the visit is still `scheduled` and `unpaid`.
- **Task-level code:** Optional per-task support item on visit tasks and recurrence task templates. When any task has a code, **invoice export uses task lines** instead of the visit-level stamp.

### Support item code format

```
^[0-9]{2}_[0-9]{3}_[0-9]{4}_[0-9]_[0-9]$
```

Example: `01_011_0107_1_1`

### Validation rules (frontend must mirror UX)

| Rule | Detail string |
|------|---------------|
| Code and name must be paired | `support_item_pair` — cannot send name without code |
| Invalid code shape | `support_item_code` |
| Code not in active catalogue | `support_item_not_in_catalogue` |
| Name does not match catalogue | `support_item_name_mismatch` — if name is sent, it must exactly match the catalogue canonical name |
| Clear support item | Send **both** `support_item_code: null` and `support_item_name: null` |

Catalogue lookup runs on **create/update** of jobs, visits, manual visits, ongoing support, and tasks with codes.

### DTO changes

**`JobOut` / `JobCreate` / `OngoingSupportCreate`**

```json
{
  "support_item_code": "01_011_0107_1_1",
  "support_item_name": "Assistance With Self-Care Activities - Standard - Weekday Daytime"
}
```

**`VisitOut` / `ManualVisitCreate`**

Same fields plus:

```json
{
  "price_tier_override": "national" | "remote" | "very_remote" | null
}
```

**`VisitTaskOut` / `VisitTaskCreate` / `TaskTemplateItem`**

```json
{
  "support_item_code": "01_011_0107_1_1",
  "billable_minutes": 90
}
```

**`VisitOut`** also now includes:

```json
{
  "engagement_id": "uuid"
}
```

### New / updated endpoints

| Method | Path | Body | Notes |
|--------|------|------|-------|
| `PATCH` | `/v1/jobs/{job_id}/support-item` | `{ support_item_code, support_item_name }` | Updates job default; propagates to visits that still match the old default |
| `PATCH` | `/v1/visits/{visit_id}/support-item` | `{ support_item_code, support_item_name }` | Only when visit `status === "scheduled"` and `payment_status === "unpaid"`; else `409 invalid_visit_status` |
| `PATCH` | `/v1/visits/{visit_id}/price-tier` | `{ price_tier_override }` | Blocked after export (`409 visit_already_exported`) |
| `PATCH` | `/v1/visits/{visit_id}/tasks/{task_id}/support-item` | `{ support_item_code }` | Staff only; scheduled + unpaid; `null` clears (also clears billable minutes) |
| `PATCH` | `/v1/visits/{visit_id}/tasks/{task_id}/billing` | `{ billable_minutes }` | Staff only; `0–1440`; blocked after export |

**Existing create flows** that now accept support items:

- `POST /v1/jobs` — `JobCreate`
- `POST /v1/jobs/ongoing-support` — `OngoingSupportCreate` (bug fix: fields are now forwarded to the created job)
- `POST /v1/jobs/{job_id}/visits` — `ManualVisitCreate`
- Recurrence `task_template[]` entries — optional `support_item_code` per task

### Important: `invoice_status` not in API yet

Visits have an internal `invoice_status` (`pending` | `exported`) used by billing. **`VisitOut` does not expose this field today.** Frontend should:

- Treat export conflicts (`409 visit_already_exported`) as “already billed”
- Optionally track export state from billing export history
- Request a backend follow-up if the visit list needs a filter/badge for export status

---

## NDIS Support Catalogue (reference data + search)

### Staff search (tenant-authenticated)

```
GET /v1/ndis-catalogue/items?q={search}&limit=20
```

**Permissions:** `jobs.manage` or `billing.view`

**Response:**

```json
{
  "q": "self care",
  "limit": 20,
  "items": [
    {
      "support_item_number": "01_011_0107_1_1",
      "support_item_name": "Assistance With Self-Care Activities - Standard - Weekday Daytime",
      "support_category_number": "01",
      "support_category_name": "Assistance with Daily Life",
      "registration_group_number": "0107",
      "registration_group_name": "Daily Personal Activities",
      "unit": "H",
      "quote_required": false,
      "price_limit_national": "65.47",
      "price_limit_remote": "91.66",
      "price_limit_very_remote": "98.21"
    }
  ]
}
```

**Frontend UX:** Use this for autocomplete when picking support items on jobs, visits, or tasks. Store both `support_item_number` (as `support_item_code` in job/visit APIs) and the canonical `support_item_name`.

### Platform import (admin only — not a tenant/mobile feature)

```
POST /v1/platform/ndis-catalogue/import
Content-Type: multipart/form-data

file: (NDIA Support Catalogue .xlsx)
version_label: string
effective_from: date (YYYY-MM-DD)
```

**Permission:** `platform.admin`  
Returns `201` on new release, `200` if same SHA already imported.

Only **one active release** exists at a time; importing a new release deactivates the previous one.

---

## Invoice export / billing (NDIS plan-manager CSV)

Enables providers to export completed visits as CSV lines priced from the active Support Catalogue — intended for handoff to plan managers (not PRODA integration).

### Endpoints

| Method | Path | Permission | Description |
|--------|------|------------|-------------|
| `GET` | `/v1/billing/invoice-exports` | `billing.view` | List exports (`?limit=100`) |
| `POST` | `/v1/billing/invoice-exports` | `billing.manage` | Create export from visit IDs |
| `GET` | `/v1/billing/invoice-exports/{export_id}` | `billing.view` | Export detail + lines |
| `GET` | `/v1/billing/invoice-exports/{export_id}/csv` | `billing.view` | Download CSV attachment |
| `POST` | `/v1/billing/invoice-exports/{export_id}/void` | `billing.manage` | Void export; revert visits to billable |

### Create export

```http
POST /v1/billing/invoice-exports
Content-Type: application/json

{
  "visit_ids": ["uuid", "..."]
}
```

Exports are created in **`finalized`** status immediately (no draft/edit step).

### Export response shape

```json
{
  "id": "uuid",
  "tenant_id": "uuid",
  "status": "finalized",
  "line_count": 2,
  "total_amount": 130.94,
  "currency_code": "AUD",
  "catalogue_release_id": "uuid",
  "created_by_user_id": "uuid",
  "finalized_at": "2026-01-15T10:00:00Z",
  "created_at": "...",
  "updated_at": "...",
  "lines": [
    {
      "id": "uuid",
      "visit_id": "uuid",
      "visit_task_id": null,
      "client_id": "uuid",
      "client_name": "Jane Participant",
      "participant_ndis_number": "430000000",
      "support_item_number": "01_011_0107_1_1",
      "support_item_name": "...",
      "service_date": "2026-01-15",
      "quantity": 2.0,
      "unit": "H",
      "unit_price": 65.47,
      "line_amount": 130.94,
      "price_tier": "national"
    }
  ]
}
```

**Export status values:** `finalized`, `void`

### Export eligibility (per visit)

A visit is exportable only when **all** of the following hold:

1. `status === "completed"`
2. Internal `invoice_status !== "exported"`
3. Closed time entry exists (`clock_out_at` set, status `closed`)
4. Client has NDIS number in profile facts (`requirement_key: "ndis"`) — may be empty in CSV if missing
5. **Single-line mode** (no tasks with support item codes): visit must have `support_item_code`
6. **Multi-line mode** (one or more tasks with `support_item_code`): every such task must have `billable_minutes` set; sum of task minutes ≤ visit billable minutes

**Catalogue constraints for export:**

- Item must exist in active catalogue
- `unit` must be `"H"` (hourly)
- `quote_required` must be `false`

**Quantity calculation:**

- Single-line: billable hours from time entry (minus breaks)
- Multi-line: `billable_minutes / 60` per task

**Service date:** Local calendar date of `clock_in_at` in tenant timezone.

### Void export

`POST .../void` sets export status to `void` and resets affected visits' `invoice_status` back to `pending` so they can be re-exported.

Errors: `409 export_already_void`, `409 export_not_voidable` (only finalized exports can be voided).

### CSV columns

```
participant_ndis_number, service_date, support_item_number, support_item_name,
quantity, unit, unit_price, line_amount, visit_id, client_name
```

---

## MMM price tiers (remote / very remote pricing)

Unit price for invoice lines is resolved in this **priority order**:

1. **Staff override** — `visit.price_tier_override`: `national` | `remote` | `very_remote`
2. **MMM postcode** — from job location (`client_site.postal_code` or `branch.postal_code`)
3. **Fallback** — `national` if postcode maps to MMM but tier resolution returns null; error if no postcode at all

### Tier mapping (MMM category → price tier)

| MMM category | Price tier |
|--------------|------------|
| 1–4 | `national` |
| 5 | `remote` |
| 6–7 | `very_remote` |
| Isolated town list | `very_remote` (overrides postcode category) |

### Frontend

- Show/edit **price tier override** on visit detail (staff) via `PATCH /v1/visits/{id}/price-tier`
- Ensure jobs have a **postal code** on branch or client site; otherwise export fails with `422 delivery_postcode_required`
- Display resolved tier on export lines (`price_tier` on `InvoiceExportLineOut`)

There is **no public MMM lookup API** for the frontend; tier is applied server-side at export time.

---

## Engagement ID on visits and shift assignments

### Why

Visits and shift assignments are now tied to the contractor's **engagement** record (not just contractor ID). This supports compliance, payroll, and tenant isolation.

### API exposure

**`VisitOut`**

```json
{ "engagement_id": "uuid" }
```

**`ShiftAssignmentOut`**

```json
{ "engagement_id": "uuid" }
```

### Frontend impact

- No request body changes — backend sets `engagement_id` automatically at assign/claim time
- Display or cache `engagement_id` if linking to engagement-scoped screens (rates, credentials, compliance)
- Do not send `engagement_id` on visit/shift create unless a future API adds it (not supported today)

---

## Legal version validation on contractor registration

Contractor registration now validates that submitted legal document versions **exist** in the compliance tables before creating the auth user.

### Affected flow

`POST` contractor registration (public or authenticated register-with-invite) — when payload includes:

- `terms_version`
- `privacy_version`

### New failure mode

| HTTP | Detail | When |
|------|--------|------|
| `400` | `legal_document_unavailable` | Version string does not match a published `platform_terms` or `privacy_policy` version |

### Frontend action

- Fetch current legal versions from existing compliance/public endpoints **before** registration
- Submit exact version strings returned by the backend (do not hard-code stale versions)
- Show a friendly “terms updated, please refresh” message on `legal_document_unavailable`

---

## Minor / infrastructure changes

| Change | Frontend impact |
|--------|-----------------|
| Contractor invite emails stored lowercase (`V026`) | Normalize email to lowercase before invite/create flows |
| Composite tenant FKs (`V024–V025`) | None directly — prevents cross-tenant data bugs |
| Test/seed updates | New seed tenant `019_professional_health_care_tenant.sql` for dev scenarios |
| `engagement_id` DB trigger | Backfills engagement when omitted in seeds; app sets explicitly in production paths |

---

## API quick reference

### New routes (prefix `/v1`)

```
GET    /ndis-catalogue/items
POST   /platform/ndis-catalogue/import          # platform.admin only

GET    /billing/invoice-exports
POST   /billing/invoice-exports
GET    /billing/invoice-exports/{id}
GET    /billing/invoice-exports/{id}/csv
POST   /billing/invoice-exports/{id}/void

PATCH  /jobs/{job_id}/support-item
PATCH  /visits/{visit_id}/support-item
PATCH  /visits/{visit_id}/price-tier
PATCH  /visits/{visit_id}/tasks/{task_id}/billing
```

### Extended request/response fields (existing routes)

| Route | New fields |
|-------|------------|
| `POST /jobs`, `GET /jobs/{id}`, `GET /jobs` | `support_item_code`, `support_item_name` |
| `POST /jobs/ongoing-support` | `support_item_code`, `support_item_name` |
| `POST /jobs/{id}/visits` | `support_item_code`, `support_item_name` |
| `GET /visits`, `GET /visits/{id}` | `support_item_*`, `price_tier_override`, `engagement_id`; tasks include `support_item_code`, `billable_minutes` |
| Recurrence task templates | `support_item_code` on each task template item |
| Shift assignments in `GET /shifts/{id}` | `engagement_id` |

---

## Error codes to handle in UI

### Support items

| Detail | HTTP | Suggested UI |
|--------|------|--------------|
| `support_item_pair` | 422 | “Enter both code and name, or clear both” |
| `support_item_code` | 422 | “Invalid NDIS item number format” |
| `support_item_not_in_catalogue` | 422 | “Item not in current NDIS catalogue” |
| `support_item_name_mismatch` | 422 | “Name does not match catalogue — pick from search” |
| `invalid_visit_status` | 409 | “Cannot change support item after check-in or payment” |

### Invoice export

| Detail | HTTP | Suggested UI |
|--------|------|--------------|
| `visit_not_completed` | 400 | “Complete visit before exporting” |
| `visit_already_exported` | 409 | “Already included in an export — void export to rebill” |
| `time_entry_not_closed` | 400 | “Time entry must be closed” |
| `support_item_required` | 422 | “Set a support item on the visit” |
| `support_item_not_hourly` | 422 | “Only hourly (H) items can be exported” |
| `quote_required_not_exportable` | 422 | “Quote-required items cannot be auto-exported” |
| `task_billable_minutes_required` | 422 | “Set billable minutes on each billed task” |
| `task_minutes_exceed_visit_hours` | 422 | “Task minutes exceed visit duration” |
| `delivery_postcode_required` | 422 | “Job location needs a postcode for pricing” |
| `price_limit_missing_for_tier` | 422 | “Catalogue has no price for this tier” |
| `export_already_void` | 409 | “Export already voided” |
| `export_not_voidable` | 409 | “Only finalized exports can be voided” |

### Registration

| Detail | HTTP | Suggested UI |
|--------|------|--------------|
| `legal_document_unavailable` | 400 | “Legal documents updated — reload and accept current terms” |

---

## Suggested frontend work checklist

### Phase 1 — Data model & forms

- [ ] Extend job, visit, and task models with support item fields
- [ ] Add `engagement_id` to visit and shift assignment models
- [ ] Add `price_tier_override` and `billable_minutes` where applicable
- [ ] Implement NDIS item autocomplete via `GET /ndis-catalogue/items`
- [ ] Validate code format client-side before submit

### Phase 2 — Job & visit UX

- [ ] Job create/edit: optional default support item picker
- [ ] Ongoing support wizard: support item picker (fields now persist correctly)
- [ ] Visit detail (staff): edit support item while scheduled/unpaid
- [ ] Visit detail (staff): price tier override selector
- [ ] Task list: optional per-task support item + billable minutes editor
- [ ] Recurrence task templates: optional `support_item_code` per template row

### Phase 3 — Billing

- [ ] Visit list/filter: select completed, unexported visits for billing batch
- [ ] Invoice export list + detail screens (`billing.view`)
- [ ] Create export action (`billing.manage`) with error handling per visit
- [ ] CSV download / share sheet from `.../csv` endpoint
- [ ] Void export with confirmation (`billing.manage`)
- [ ] Handle `visit_already_exported` on price tier / task billing edits

### Phase 4 — Registration hardening

- [ ] Load current `platform_terms` / `privacy_policy` versions before contractor register
- [ ] Handle `legal_document_unavailable`

### Phase 5 — Permissions & roles

- [ ] Gate billing screens on `billing.view` / `billing.manage`
- [ ] Ensure admin roles in tenant include new billing permissions (seed already adds them for dev)

---

## Commit log (reference)

| Commit | Summary |
|--------|---------|
| `019fe5d` | Legal version validation on registration |
| `4f94dd5` | Test DB connection refactor (no API impact) |
| `4ef3ef2` / `e177623` | Composite FKs + `engagement_id` on visits/shift assignments |
| `038d36b` | DB: support item columns on jobs/visits |
| `52a63f2` | Support item pair validator |
| `9f0ea2c` | Expose support item on job/visit DTOs |
| `3d8ca1f` | Stamp visit support item from job default |
| `e477d48` | PATCH support item on job and visit |
| `0103f32` | Fix ongoing-support create forwarding support item |
| `d80f726` | NDIS catalogue import + validation |
| `9c72d6d` | Invoice export API (Phase B) |
| `a90c689` | Invoice export Phase C: void, MMM tiers, multi-line tasks |

---

*Generated from git history `7473a765..a90c6893`. For OpenAPI details, run the backend locally and open `/docs`.*
