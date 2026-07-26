# API path inventory — Flutter V1

**Authoritative Flutter list:** [restructure design §7](../2026-07-23-frontend-contractor-domain-restructure-design.md)  
**Shapes helper:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md) · live `/docs`  
**Base:** `/v1`

Legend: **In** = Flutter · **Landing** = landing only · **Ban** = do not call

---

## Auth & session — In

`POST auth/login|refresh|logout` · `POST auth/switch-tenant` · `GET auth/me/context` · `GET me` · `POST auth/complete_first_login` (if required) · `GET/PATCH auth/users/me`

## Contractors / credentials / schedule — In

`POST contractors/register`  
`GET/PATCH contractor-me` · `GET contractor-me/engagements`  
`POST/GET/PATCH contractor-me/credentials` · `POST .../credentials/{id}/supersede`  
`POST contractor-me/privacy-export`  
`GET contractor-me/timetable` · `GET/PUT contractor-me/availability` · `GET/POST/DELETE contractor-me/leave`

## Engagements — In

`GET/POST tenants/current/engagements`  
`GET tenants/current/contractors/{id}/credentials`  
`POST engagements/{id}/accept|approve|activate|approve-and-activate|suspend|resume|end`  
`POST engagements/{id}/credential-reviews`

Accept body includes `{ "allow_source_evidence": false }`.

## Compliance — In

`GET compliance/legal-documents/current` · `GET compliance/collection-notices` · `POST compliance/legal-events`  
`POST/GET compliance/rights-requests` · `GET compliance/access-history` · `POST/GET/PATCH compliance/incidents`

## Documents — In

`POST documents/upload-url` · `POST documents/{id}/finalize` (body may include `credential_id`)  
`GET documents/{id}/download-url` · **`GET documents/{id}/content`** (proxy when `proxy_required`)  
`GET documents` (list)

## Clients / forms / jobs / visits — In

Clients + sites + contacts + invites  
`public/client-invites/{token}` (+ acknowledge) — **In Flutter**  
Form templates · Jobs · recurrence · generate · manual visits  
Visits list/detail/cancel/check-in/complete/tasks/form-submissions  

GPS: `{ "lat", "lng", "accuracy_m?" }`

## Payroll / payments — In

`payroll/engagement-rates/{engagementId}` · `.../{rateId}` (rate **bands**)  
`payment-batches` · post · void

## Subscription / notifications — In (limited)

`GET subscription` — status only  
`notifications/devices` · events · settings  

---

## Landing only — Ban from Flutter UI

| Path | Why |
|------|-----|
| `POST /v1/public/register` | Company + owner — landing |
| `/v1/subscription/checkout*` · cancel | GoCardless — landing; Flutter opens `BILLING_URL` |

---

## Ban — obsolete

`/employees` · PIN verify/set · employee clock · `/scheduling/*` · employee `/payroll/periods` · old employee payment report paths · free-floating punches

---

## Visit list query

`GET /visits?payment_status=&job_id=&from=&to=&limit=`

## Idempotency

Header on check-in, complete, generate, batch create/post, legal-event retries: `Idempotency-Key`
