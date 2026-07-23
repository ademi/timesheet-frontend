# Post-login redirect matrix (Phase 2 AuthGuard)

**Sources:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md) §2 + §17 · [v1-scope-matrix.md](./v1-scope-matrix.md) · clarification Eng-2 / Auth-3

Replace portal `user_role` (Attendance vs Admin gateway) with **actor-based** routing.

---

## Decision tree

```text
login / refresh / restore session
        │
        ├─ must_change_password OR JWT mcp=true
        │     → FirstLogin / change-password screen
        │     → after success: re-login → restart tree
        │
        ├─ actor_type == tenant_member
        │     → Admin shell (Hub)
        │     → destinations gated by JWT permissions
        │
        └─ actor_type == contractor
              │
              ├─ engagements empty → error / contact support
              │     (login usually already fails: no engagement)
              │
              ├─ engagements.length == 1
              │     → ensure token tenant matches (switch-tenant if needed)
              │     → contractor status gate (below)
              │
              └─ engagements.length > 1
                    → Tenant / engagement picker
                    → POST /auth/switch-tenant { tenant_id }
                    → persist new access+refresh
                    → contractor status gate
```

---

## Contractor status gate (after tenant context)

| Engagement `status` | Allowed Flutter destinations | Blocked |
|---------------------|------------------------------|---------|
| `invited` | Accept engagement screen (+ limited profile) | Visits ops, timetable manage, payments |
| `pending_docs` | Documents upload + visits **read** + profile | Check-in/complete, schedule manage, payments |
| `approved` | Same limited set as pending_docs until activate | Check-in/complete (no `visits.check_in` in JWT) |
| `active` | Full contractor shell | — |
| `suspended` | Visits read + profile; attempt complete only if already checked_in (may 403) | Check-in; docs upload; payments |
| `ended` | Cannot hold token for that tenant — pick another or re-login | — |

Permission narrowing matches wiring guide §2.2 — prefer JWT `permissions` over re-deriving from status, but status drives onboarding screens (accept / docs).

---

## Admin shell stub destinations

| Destination | Gate (permission) |
|-------------|-------------------|
| Hub | `auth.session` |
| Team (members) | `tenant_members.read` |
| Contractors / Engagements | `contractors.read` |
| Clients | `clients.read` |
| Jobs / Visits | `jobs.read` or `visits.read` |
| Payments | `payments.view` |
| Forms (catalog attach / templates list) | `clients.read` (templates) / `jobs.manage` (attach) |
| Branches / Settings | `branches.manage` or `tenants.read` |

No subscription / billing destination.

---

## Contractor shell stub destinations

| Destination | Gate |
|-------------|------|
| Visits | `visits.read` |
| Visit detail | `visits.read` |
| Timetable | `auth.session` |
| Documents | `documents.upload` (and list via auth.session) |
| Payments (via visits `payment_status`) | `payments.view_own` or `visits.read` |
| Switch tenant / Profile | `auth.session` |

---

## Persistence keys (Phase 2.2)

| Key | Purpose |
|-----|---------|
| access + refresh tokens | Existing secure storage |
| last `tenant_id` / engagement id | Contractor restore |
| Clear on DOMAIN_V2 cutover | tokens, `user_role`, branch, `payroll_settings` |

Do **not** persist old portal `user_role` as primary auth split after DOMAIN_V2.
