# AppPermissions catalog (Flutter V1)

**Sources:** [Flutter restructure design](../2026-07-23-frontend-contractor-domain-restructure-design.md) §8 · prior Roles-1 · wiring guide  
**Use:** `AppPermissions` + `SessionService.hasPermission` / `PermissionGuard`  
**Runtime source of truth:** JWT `permissions[]` (also treat `*` or `platform.admin` as allow-all in UI gates)

---

## Keys (Flutter-relevant)

### Core / tenants
`auth.session` · `tenants.read` · `tenants.manage` · `tenant_members.read` · `tenant_members.manage` · `branches.read` · `branches.manage` · `rbac.manage` · `audit.view` · `platform.admin`

### Contractors / credentials
`contractors.read` · `contractors.invite` · `contractors.approve` · `contractors.manage` · `contractors.docs.read`  
`credentials.read` · `credentials.manage` · `credentials.review` · `credentials.source.read`

### Clients / jobs / visits
`clients.read` · `clients.manage` · `jobs.read` · `jobs.manage` · `visits.read` · `visits.manage` · `visits.check_in` · `visits.complete`

### Documents / payments / schedule
`documents.upload` · `payments.view` · `payments.manage` · `payments.view_own` · `contractor.schedule.manage` · `attendance.adjust`

### Compliance
`compliance.legal.read` · `compliance.legal.accept` · `compliance.consent.manage` · `compliance.rights.manage` · `compliance.incidents.manage` · `compliance.audit.view`

### Billing / notifications (UI limited)
`billing.view` (subscription status chip) · `subscription.view` / `subscription.manage` (landing checkout — not Flutter UI)  
`notifications.receive` · `notifications.manage`

---

## Role templates (summary)

| Role | Notes |
|------|-------|
| owner | Broad tenant keys except `platform.admin` |
| admin | Broad manage; typically no `rbac.manage` |
| supervisor | Jobs/visits/clients; contractors read+invite; payments.view; **no** approve/docs/payments.manage/attendance.adjust unless seed says otherwise — verify live seed |
| contractor (active) | visits read/check_in/complete, documents.upload, credentials.*, payments.view_own, contractor.schedule.manage, compliance self-service, notifications.receive |
| platform_admin | Out of Flutter product shells |

### Contractor JWT narrowing by engagement status

| Status | Typical JWT |
|--------|-------------|
| active | Full contractor role |
| invited / pending_docs / approved | Narrowed (session, visits.read, documents/credentials upload paths as seed defines) |
| suspended | Very limited (session + visits.read) — complete may 403 |
| ended | Cannot login that tenant |

---

## UI gating hints

| Check | Pattern |
|-------|---------|
| Staff destination | `actor_type == tenant_member` && permission |
| Contractor destination | `actor_type == contractor` |
| Onboarding funnel | Incomplete legal/accept/credentials → force `/contractor/onboarding` |
| Source evidence | `credentials.source.read` + grant; proxy if required |
| Billing gate | `AppFailure.billingGate` → open `BILLING_URL` |
| Missing permission | Hide control; deep-link → snackbar + home |
