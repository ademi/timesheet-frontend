# AppPermissions catalog (Phase 2 input)

**Sources:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md) §2.2 · clarification Roles-1 / Roles-5 · endpoint `Perm` columns in wiring guide  
**Use:** Copy into `lib/app/constants/app_permissions.dart` (or equivalent) in Phase 2.3.  
**Runtime source of truth:** JWT `permissions[]` only — never invent grants client-side.

---

## Permission keys (Flutter-relevant)

| Key | Typical use |
|-----|-------------|
| `auth.session` | Authenticated session; accept engagement; timetable read; me/context |
| `tenants.read` | Read own tenant |
| `tenants.manage` | Patch own tenant |
| `tenant_members.read` | Team list/detail |
| `tenant_members.manage` | Create/edit members |
| `contractors.read` | Engagements list (tenant) |
| `contractors.invite` | Invite engagement |
| `contractors.approve` | Approve / approve-and-activate |
| `contractors.manage` | Activate / suspend / resume / end |
| `contractors.docs.read` | Read contractor profile docs (owner/admin; **not** supervisor) |
| `clients.read` | Clients + form templates read |
| `clients.manage` | Clients/sites/contacts/forms write |
| `jobs.read` | Jobs + recurrence read |
| `jobs.manage` | Jobs/recurrence/generate/form-catalog |
| `visits.read` | Visits list/detail |
| `visits.manage` | Reschedule/cancel/tasks (tenant); board |
| `visits.check_in` | Check-in + task toggle (assignee) |
| `visits.complete` | Complete visit |
| `documents.upload` | upload-url / finalize |
| `payments.view` | Rates list + payment batches (admin) |
| `payments.manage` | Create/post/void batches; create/patch rates |
| `payments.view_own` | Contractor own payments (via visits filter until own-batches API) |
| `attendance.adjust` | Adjustments (owner/admin — **not** supervisor) |
| `notifications.receive` | FCM/inbox events |
| `notifications.manage` | Notification settings (if exposed) |
| `contractor.schedule.manage` | Availability PUT + leave write |
| `branches.read` | Branch read (often via session + alternate perms — see wiring §14) |
| `branches.manage` | Branch create/update |
| `audit.view` | Audit (supervisor+) — optional V1 surface |
| `rbac.manage` | Role assignment (owner-only; **not** admin template) |
| `subscription.view` | Landing/billing — **no Flutter UI** |
| `subscription.manage` | Landing/billing — **no Flutter UI** |
| `platform.admin` | Out of Flutter app |

---

## Role templates (who gets what)

| Role | Includes (summary) | Explicit exclusions |
|------|--------------------|---------------------|
| **owner** | All keys except `platform.admin` | `platform.admin` |
| **admin** | Broad tenant manage incl. payments.manage, contractors.approve, subscription.* on JWT if seeded | `rbac.manage`, `platform.admin` |
| **supervisor** | `auth.session`, `tenants.read`, `tenant_members.read`, `contractors.read`+`invite`, `clients.*`, `jobs.*`, `visits.read`+`manage`, `payments.view`, `notifications.receive`, `audit.view` | `contractors.approve` / `manage` / `docs.read`, `payments.manage`, `attendance.adjust` |
| **contractor** (active) | `auth.session`, `visits.read`/`check_in`/`complete`, `documents.upload`, `payments.view_own`, `notifications.receive`, `contractor.schedule.manage` | Tenant admin keys |
| **platform_admin** | `platform.admin`, `auth.session`, `subscription.view`/`manage` | Not a Flutter app user |

---

## Contractor engagement status → JWT narrowing

| Status | JWT permissions |
|--------|-----------------|
| `active` | Full contractor role |
| `invited` / `pending_docs` / `approved` | `auth.session`, `visits.read`, `documents.upload` |
| `suspended` | `auth.session`, `visits.read` only (complete may 403 — known gap) |
| `ended` | Cannot login to that tenant |

---

## UI gating hints (Phase 2)

| Check | Helper pattern |
|-------|----------------|
| Show admin destination | `actor_type == tenant_member` && `hasPermission(...)` |
| Show contractor destination | `actor_type == contractor` |
| `pending_docs` limited nav | Only docs + visits read (+ profile) |
| `wrong_actor_type` | Dedicated screen (not toast) |
| Missing permission | Toast / hide control |
| `subscription_expired` | Banner → “renew on website” (no checkout UI) |
