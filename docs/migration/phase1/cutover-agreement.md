# Cutover agreement (Phase 1)

**Agreed approach:** Coordinated release — **no dual-running** old + new API.

| Topic | Decision |
|-------|----------|
| Database | Fresh DB; no employee → contractor backfill |
| Existing sessions | Wipe local tokens / secure storage; force re-login |
| Obsolete APIs | Unmounted → **404** (PIN, employees, scheduling, payroll periods, free-floating clock) |
| Dual-running | **Not supported** — old app binaries break after cutover |
| Force-update API | None yet — use store messaging + release coordination |
| Rollback | Previous binary only works if backend re-enables old API (**assume no**) → prefer forward fix |

## Client cutover actions (Phase 4 implements)

1. On first DOMAIN_V2 / version bump: clear secure storage tokens, `user_role`, branch selection, `payroll_settings` (GetStorage).
2. Show blocking “App updated — please sign in again.”
3. Login against V2 auth (`actor_type`, engagements, JWT claims).

## Window

| Item | Value |
|------|-------|
| Local / dogfood | Against `http://localhost:8000` (timesheet-api 0.2.0) |
| Production cutover | Coordinate with backend release of contractor-era API; communicate store update to users |
| Staging fixtures | Manual (seed has roles/perms only) — create tenant, member, contractor, engagement, client, job, visits, rates before QA |

**Sign-off:** Flutter + backend agree wipe-storage + re-login cutover (2026-07-23). Exact production date TBD with backend release train.
