# Phase 1 artifacts

Contract freeze completed against local API **`http://localhost:8000`**.

**Before Phase 2:** read **[phase2-readiness.md](./phase2-readiness.md)** (go/no-go).  
**API helper:** [frontend-api-wiring-guide.md](../frontend-api-wiring-guide.md)

| File | Purpose |
|------|---------|
| [phase2-readiness.md](./phase2-readiness.md) | **Go/no-go** + wiring-guide crosswalk + scaffold map |
| [openapi-review.md](./openapi-review.md) | Bookmarks + critical path spot-check |
| [openapi-snapshot.json](./openapi-snapshot.json) | Frozen OpenAPI from local `/openapi.json` |
| [v1-scope-matrix.md](./v1-scope-matrix.md) | In / Out / Later for mobile V1 |
| [api-path-inventory.md](./api-path-inventory.md) | Flutter In vs landing-only vs ban list |
| [app-permissions-catalog.md](./app-permissions-catalog.md) | Keys + role templates for `AppPermissions` |
| [post-login-redirect-matrix.md](./post-login-redirect-matrix.md) | AuthGuard actor routing |
| [error-catalog.md](./error-catalog.md) | UI mapper `detail` codes |
| [cutover-agreement.md](./cutover-agreement.md) | Wipe storage + re-login; no dual-run |
| [spike-signoff.md](./spike-signoff.md) | Five spike results |

Runner: `dart run tool/phase1_spikes.dart health`
