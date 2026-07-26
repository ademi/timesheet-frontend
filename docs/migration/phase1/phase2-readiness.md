# Phase 2 readiness → superseded by S0

**Update 2026-07-26:** Prior Phase 2 exit is treated as a **partial prototype**.  
Authoritative next step is **S0** in [implementation-checklist.md](../implementation-checklist.md), driven by [Flutter restructure design](../2026-07-23-frontend-contractor-domain-restructure-design.md).

See [design-delta-2026-07-26.md](../design-delta-2026-07-26.md) for the full comparison.

## Still useful from Phase 1 freeze

| Artifact | Use in S0+ |
|----------|------------|
| [openapi-review.md](./openapi-review.md) | Bookmarks |
| [v1-scope-matrix.md](./v1-scope-matrix.md) | Updated to Staff/Contractor + compliance |
| [api-path-inventory.md](./api-path-inventory.md) | Updated path registry |
| [app-permissions-catalog.md](./app-permissions-catalog.md) | Extended credentials/compliance |
| [post-login-redirect-matrix.md](./post-login-redirect-matrix.md) | Staff/Contractor algorithm |
| [error-catalog.md](./error-catalog.md) | eligibility / proxy / billingGate |
| [cutover-agreement.md](./cutover-agreement.md) | Wipe + re-login |
| JwtClaims / switch-tenant / DocumentService spike code | Port into `features/` + `SessionService` |

## Do not carry forward blindly

- `/v2/admin/*` and `/v2/contractor/*` route names → replace with `/staff/*`, `/contractor/*`
- Flat `lib/app` growth → move to `lib/features/<domain>/`
- Dual Dio clients as permanent design → retire `AttendanceApiClient` by S10
- “Client invite out of Flutter” → **In** V1 per new design
