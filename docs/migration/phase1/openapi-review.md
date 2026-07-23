# Phase 1 — OpenAPI review

**Reviewed:** 2026-07-23  
**Base URL (local):** `http://localhost:8000`  
**API title / version:** `timesheet-api` **0.2.0**  
**Path count:** 98  
**Snapshot:** [openapi-snapshot.json](./openapi-snapshot.json) (fetched from local `/openapi.json`)

## Team bookmarks

| Resource | URL |
|----------|-----|
| Swagger UI | http://localhost:8000/docs |
| OpenAPI JSON | http://localhost:8000/openapi.json |
| Health | http://localhost:8000/health → `{ "status": "ok" }` |
| Ready | http://localhost:8000/ready → `{ "status": "ready" }` |
| Wiring guide | [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md) |

> Production / shared staging (when used): replace host with `https://api.rostiq.co` — same path layout.

## Critical path spot-check (Swagger / OpenAPI)

| Path | Method | Present | Notes |
|------|--------|---------|-------|
| `/v1/auth/login` | POST | Yes | `LoginResponse` includes `actor_type`, `engagements[]` |
| `/v1/auth/refresh` | POST | Yes | Same response shape as login |
| `/v1/auth/switch-tenant` | POST | Yes | Body `{ tenant_id }` |
| `/v1/auth/me/context` | GET | Yes | `MeContextResponse` — actor + engagements, **no** permissions |
| `/v1/tenants/current/engagements` | * | Yes | Tenant invite/list |
| `/v1/engagements/{engagement_id}/accept` | POST | Yes | Contractor accept |
| `/v1/visits/{visit_id}/check-in` | POST | Yes | Body `VisitGpsBody` `{ lat, lng, accuracy_m? }` |
| `/v1/visits/{visit_id}/complete` | POST | Yes | Same GPS body |
| `/v1/documents/upload-url` | POST | Yes | Returns signed `upload_url` |
| `/v1/documents/{document_id}/finalize` | POST | Yes | After client PUT |
| `/v1/payment-batches` | POST | Yes | `{ visit_ids, period_label?, currency_code }` |
| `/v1/payroll/engagement-rates/{engagement_id}` | GET | Yes | Rates under `/payroll` |
| `/v1/contractors/register` | POST | Yes | Public |
| `/v1/contractor-me` | GET | Yes | Contractor profile |
| `/v1/tenant-members` | GET | Yes | Replaces employees |

## Schema freeze (used by Flutter spikes)

Confirmed against live OpenAPI components:

- **LoginResponse:** `access_token`, `refresh_token`, `token_type`, `must_change_password`, `subscription?`, `actor_type?`, `engagements?`
- **EngagementSummary:** `id`, `tenant_id`, `tenant_name`, `status`
- **MeContextResponse:** `actor_type`, `tenant_id?`, `contractor_id?`, `tenant_member_id?`, `engagements[]`
- **VisitGpsBody:** `lat`, `lng`, `accuracy_m?` (no client timestamp)
- **UploadUrlRequest / Response:** upload-url → PUT → finalize flow
- **VisitCheckInOut:** `visit_id`, `status`, `time_entry_id`

## Reviewer sign-off

| Role | Name / note | Date |
|------|-------------|------|
| Flutter lead | OpenAPI reviewed against local `0.2.0`; contracts match wiring guide | 2026-07-23 |

Re-fetch snapshot after backend schema drifts:

```powershell
Invoke-WebRequest -Uri "http://localhost:8000/openapi.json" -OutFile "docs/migration/phase1/openapi-snapshot.json"
```
