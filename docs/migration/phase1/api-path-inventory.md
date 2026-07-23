# API path inventory — Flutter vs landing vs obsolete

**Source of truth for shapes:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md)  
**Local try-it-out:** `http://localhost:8000/docs`  
**Base:** `/v1` · Header `Authorization: Bearer <access_token>`

Legend: **In** = Flutter V1 · **Landing** = landing page only · **Out** = not Flutter V1 · **Ban** = unmounted / must not call (404)

---

## Auth & session — In

| Method | Path | Notes |
|--------|------|-------|
| POST | `/v1/auth/login` | `identifier` email/phone; optional `tenant_id` |
| POST | `/v1/auth/refresh` | Rotates tokens; same login shape |
| POST | `/v1/auth/logout` | |
| POST | `/v1/auth/switch-tenant` | `{ tenant_id }` → new tokens |
| GET | `/v1/auth/me/context` | Actor + engagements; **no** permissions |
| GET | `/v1/me` | Mirrors JWT subset; prefer me/context for actor |
| POST | `/v1/auth/complete_first_login` | When `mcp` / must_change_password |
| POST | `/v1/auth/change_password` | |
| GET/PATCH | `/v1/auth/users/me` | Profile |

## Contractors & engagements — In

| Method | Path | Notes |
|--------|------|-------|
| POST | `/v1/contractors/register` | Flutter contractor signup (public) |
| GET/PATCH | `/v1/contractor-me` | Contractor profile |
| GET | `/v1/contractor-me/engagements` | |
| GET | `/v1/contractor-me/timetable` | Query `from`/`to` |
| GET/PUT | `/v1/contractor-me/availability` | |
| GET/POST/DELETE | `/v1/contractor-me/leave` | |
| GET/POST | `/v1/tenants/current/engagements` | Tenant list/invite |
| POST | `/v1/engagements/{id}/accept` | Contractor |
| POST | `/v1/engagements/{id}/approve` | Tenant |
| POST | `/v1/engagements/{id}/activate` | Tenant |
| POST | `/v1/engagements/{id}/approve-and-activate` | Tenant |
| POST | `/v1/engagements/{id}/suspend\|resume\|end` | Tenant |

## Tenant members, clients, forms, jobs, visits — In

| Area | Prefix / paths |
|------|----------------|
| Members | `/v1/tenant-members` |
| Clients | `/v1/clients`, `.../sites`, `.../contacts`, `.../invites` (create token only) |
| Forms | `/v1/form-templates` (consume); visit `.../form-submissions` |
| Jobs | `/v1/jobs`, `.../form-catalog`, `.../recurrence-rules`, `.../generate`, `.../visits` |
| Visits | `/v1/visits`, `.../check-in`, `.../complete`, `.../tasks/{tid}`, `.../cancel` |
| Documents | `/v1/documents/upload-url`, `.../{id}/finalize`, list, `.../download-url` |
| Adjustments | `/v1/attendance/adjustments`, `.../time-entries/{id}/adjustments` |
| Rates | `/v1/payroll/engagement-rates/{engagement_id}`, `.../{rate_id}` |
| Payments | `/v1/payment-batches`, `.../post`, `.../void` |
| Branches | `/v1/branches` |
| Notifications | `/v1/notifications/devices`, events (optional inbox) |
| Tenants (own) | `GET/PATCH /v1/tenants/{tenant_id}` with tenants.* |

### Visit list query (In)

`GET /v1/visits?payment_status=&job_id=&from=&to=&limit=` — no status/client/branch filters yet.

### GPS body (In)

```json
{ "lat": -33.8688, "lng": 151.2093, "accuracy_m": 12.5 }
```

Optional header: `Idempotency-Key` on check-in, complete, generate, batch create/post.

---

## Landing page only — do not build in Flutter

| Method | Path | Why |
|--------|------|-----|
| POST | `/v1/public/register` | Company + owner signup — **landing page** |
| * | `/v1/subscription` | Checkout / plans / cancel — **landing page** |
| * | `/v1/subscription/plans` | Landing |
| * | `/v1/subscription/checkout` | Landing |
| * | `/v1/subscription/checkout/status` | Landing |
| * | `/v1/subscription/cancel` | Landing |
| GET/POST | `/v1/public/client-invites/{token}` (+ `/acknowledge`) | Separate web (Out of mobile V1) |

Flutter may still:

- Read lightweight `subscription` on login/refresh
- Show defensive UI on `subscription_expired` → send user to website

---

## Ban — obsolete (expect 404)

Do **not** wire or keep calling:

- `/v1/employees`, PIN verify/set, employee clock-in/out
- `/v1/scheduling/*`
- `/v1/geofence/*`
- `/v1/payroll/periods`, employee balance, period export
- Free-floating attendance punch APIs
- Weekly attendance report endpoint

Mark corresponding `AppConstants` entries **deprecated** in Phase 2.5.

---

## Phase 2 `AppConstants` priority (add first)

```
/v1/auth/login
/v1/auth/refresh
/v1/auth/logout
/v1/auth/switch-tenant
/v1/auth/me/context
/v1/auth/complete_first_login
/v1/contractors/register
/v1/contractor-me
/v1/contractor-me/engagements
/v1/contractor-me/timetable
/v1/tenants/current/engagements
/v1/engagements/{id}/accept|approve|activate|...
/v1/tenant-members
/v1/clients
/v1/form-templates
/v1/jobs
/v1/visits
/v1/documents/upload-url
/v1/documents/{id}/finalize
/v1/documents/{id}/download-url
/v1/payment-batches
/v1/payroll/engagement-rates/{engagement_id}
/v1/attendance/adjustments
/v1/branches
/v1/notifications/devices
```
