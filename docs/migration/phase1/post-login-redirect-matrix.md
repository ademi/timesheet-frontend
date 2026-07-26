# Post-login redirect matrix (Staff / Contractor)

**Sources:** [Flutter restructure design](../2026-07-23-frontend-contractor-domain-restructure-design.md) §4.2–4.5 · [design-delta-2026-07-26.md](../design-delta-2026-07-26.md)

Replace portal `user_role` and any `/v2/*` stubs with **StaffShell** / **ContractorShell**.

---

## Decision tree

```text
persist tokens
GET /v1/auth/me/context
        │
        ├─ must_change_password / mcp
        │     → /first-login → re-login → restart
        │
        ├─ actor_type == tenant_member
        │     → /staff/home
        │     → nav gated by JWT permissions
        │
        └─ actor_type == contractor
              │
              ├─ pending engagement accept
              │   OR legal/consent incomplete
              │   OR required credentials incomplete
              │     → /contractor/onboarding (funnel, outside tabs)
              │
              └─ else → /contractor/home
```

“Incomplete” uses:

1. Engagements needing accept (e.g. `invited`) from `GET /v1/contractor-me/engagements`
2. Missing current Terms/Privacy when backend rejects; funnel presents compliance APIs first
3. Required categories without satisfying credentials

Do **not** invent a dual actor — backend forbids same user as both.

---

## Guards

| Middleware | Behavior |
|------------|----------|
| AuthGuard | No token → `/gateway` |
| ActorGuard | `/staff/*` ⇒ `tenant_member`; `/contractor/*` ⇒ `contractor` |
| PermissionGuard | Route `anyOf` / `allOf` permissions; fail → shell home + snackbar |

Cold start with tokens: load `me/context` before resolving deep links.

---

## StaffShell (`/staff/...`)

| Nav | Route | Permission |
|-----|-------|------------|
| Home | `/staff/home` | `auth.session` |
| Workforce | `/staff/workforce` | `contractors.read` |
| Clients | `/staff/clients` | `clients.read` |
| Jobs | `/staff/jobs` | `jobs.read` |
| Visits | `/staff/visits` | `visits.read` |
| Payments | `/staff/payments` | `payments.view` |
| Compliance | `/staff/compliance` | any of credentials.review / compliance.rights.manage / compliance.incidents.manage / compliance.audit.view |
| Settings | `/staff/settings` | `auth.session` |

No in-app subscription checkout — billing deep-link only.

---

## ContractorShell (`/contractor/...`)

| Nav | Route |
|-----|-------|
| Home | `/contractor/home` |
| Visits | `/contractor/visits` |
| Schedule | `/contractor/schedule` |
| Credentials | `/contractor/credentials` |
| Profile | `/contractor/profile` |

Onboarding: `/contractor/onboarding/*` outside tab chrome until work-ready.

Tenant switch: Profile → engagements → `POST /v1/auth/switch-tenant` → new tokens → reload me/context.

---

## Public routes

| Path | Purpose |
|------|---------|
| `/gateway` | Sign in · Register as contractor · optional LANDING_URL |
| `/login` | Login |
| `/first-login` | Password set if required |
| `/contractor/register` | Public contractor register |
| `/invites/client/:token` | Client invite acknowledge |

---

## Persistence

| Key | Purpose |
|-----|---------|
| access + refresh | Secure storage |
| last tenant / engagement | Contractor restore |
| Cutover wipe | Clear tokens + old `user_role` + `payroll_settings` on upgrade |
